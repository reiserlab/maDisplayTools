classdef test_log_command < matlab.unittest.TestCase
    % TEST_LOG_COMMAND - Unit tests for the universal log command feature
    %
    % Tests ExperimentLogger, PluginManager.logCustomMessage(), and
    % CommandExecutor log command routing.
    %
    % Run: run(test_log_command)
    
    properties
        testRoot
        repoRoot
        logger
        experimentDir
    end
    
    methods (TestClassSetup)
        function setupTestEnvironment(testCase)
            % Setup: temp directory for log files
            testCase.testRoot = fullfile(tempdir, 'test_log_command');
            if isfolder(testCase.testRoot)
                rmdir(testCase.testRoot, 's');
            end
            mkdir(testCase.testRoot);
            
            % Get repo root
            testCase.repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(testCase.repoRoot, 'experimentExecution'));
        end
    end
    
    methods (TestClassTeardown)
        function cleanupTestEnvironment(testCase)
            % Clean up temp directory
            if isfolder(testCase.testRoot)
                rmdir(testCase.testRoot, 's');
            end
        end
    end
    
    methods (TestMethodSetup)
        function setupEachTest(testCase)
            % Create fresh logger and experiment dir for each test
            testCase.experimentDir = fullfile(testCase.testRoot, ...
                sprintf('exp_%s', datestr(now, 'HHMMSS_FFF')));
            mkdir(testCase.experimentDir);
            
            logFile = fullfile(testCase.experimentDir, 'test.log');
            testCase.logger = ExperimentLogger(logFile, false, 'DEBUG');
        end
    end
    
    methods (TestMethodTeardown)
        function cleanupEachTest(testCase)
            % Close logger after each test
            if ~isempty(testCase.logger)
                testCase.logger.close();
            end
        end
    end
    
    methods (Test)
        function testLoggerWritesCorrectFormat(testCase)
            % Test that ExperimentLogger writes correct format at each level
            testCase.logger.log('DEBUG', 'debug message');
            testCase.logger.log('INFO', 'info message');
            testCase.logger.log('WARNING', 'warning message');
            testCase.logger.log('ERROR', 'error message');
            testCase.logger.close();
            
            % Read log file and verify format
            logFile = fullfile(testCase.experimentDir, 'test.log');
            content = fileread(logFile);
            
            testCase.verifySubstring(content, 'DEBUG: debug message', 'Missing DEBUG entry');
            testCase.verifySubstring(content, 'INFO: info message', 'Missing INFO entry');
            testCase.verifySubstring(content, 'WARNING: warning message', 'Missing WARNING entry');
            testCase.verifySubstring(content, 'ERROR: error message', 'Missing ERROR entry');
            
            % Verify timestamp format [YYYY-MM-DD HH:MM:SS.FFF]
            testCase.verifyMatches(content, '\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\]', ...
                'Missing timestamp in expected format');
        end
        
        function testPluginManagerLogFormatting(testCase)
            % Test PluginManager.logCustomMessage() formatting
            pm = PluginManager(testCase.logger, testCase.experimentDir);
            pm.logCustomMessage('my_plugin', 'User says hello', 'INFO');
            testCase.logger.close();
            
            logFile = fullfile(testCase.experimentDir, 'test.log');
            content = fileread(logFile);
            
            testCase.verifySubstring(content, '[PLUGIN: my_plugin] USER LOG: User says hello', ...
                'Log message not formatted correctly');
        end
        
        function testLogCommandRouting(testCase)
            % Test log command routes through CommandExecutor
            pm = PluginManager(testCase.logger, testCase.experimentDir);
            
            % CommandExecutor needs an arenaController - pass [] since we
            % won't execute controller commands in this test
            executor = CommandExecutor([], pm, testCase.logger);
            
            % Build log command struct matching YAML format
            cmd = struct();
            cmd.type = 'plugin';
            cmd.plugin_name = 'test_plugin';
            cmd.command_name = 'log';
            cmd.params = struct('message', 'Custom log from YAML', 'level', 'INFO');
            
            executor.execute(cmd);
            testCase.logger.close();
            
            logFile = fullfile(testCase.experimentDir, 'test.log');
            content = fileread(logFile);
            
            testCase.verifySubstring(content, '[PLUGIN: test_plugin] USER LOG: Custom log from YAML', ...
                'Log command did not route correctly through CommandExecutor');
        end
        
        function testLogLevels(testCase)
            % Test log command with explicit WARNING and ERROR levels
            pm = PluginManager(testCase.logger, testCase.experimentDir);
            executor = CommandExecutor([], pm, testCase.logger);
            
            % WARNING level
            cmd_warn = struct();
            cmd_warn.type = 'plugin';
            cmd_warn.plugin_name = 'my_device';
            cmd_warn.command_name = 'log';
            cmd_warn.params = struct('message', 'Temp is high', 'level', 'WARNING');
            executor.execute(cmd_warn);
            
            % ERROR level
            cmd_err = struct();
            cmd_err.type = 'plugin';
            cmd_err.plugin_name = 'my_device';
            cmd_err.command_name = 'log';
            cmd_err.params = struct('message', 'Sensor offline', 'level', 'ERROR');
            executor.execute(cmd_err);
            
            testCase.logger.close();
            
            logFile = fullfile(testCase.experimentDir, 'test.log');
            content = fileread(logFile);
            
            testCase.verifySubstring(content, 'WARNING: [PLUGIN: my_device] USER LOG: Temp is high', ...
                'WARNING level not respected');
            testCase.verifySubstring(content, 'ERROR: [PLUGIN: my_device] USER LOG: Sensor offline', ...
                'ERROR level not respected');
        end
        
        function testMissingMessageParameter(testCase)
            % Test log command with missing params.message
            pm = PluginManager(testCase.logger, testCase.experimentDir);
            executor = CommandExecutor([], pm, testCase.logger);
            
            % Build command with command_name='log' but no params.message
            cmd = struct();
            cmd.type = 'plugin';
            cmd.plugin_name = 'test_plugin';
            cmd.command_name = 'log';
            cmd.params = struct('level', 'INFO');  % message is missing
            
            errored = false;
            errorMsg = '';
            try
                executor.execute(cmd);
            catch ME
                errored = true;
                errorMsg = ME.message;
            end
            
            testCase.verifyTrue(errored, 'Should error when params.message is missing');
            testCase.verifySubstring(errorMsg, 'message', ...
                'Error message should mention missing message field');
        end
        
        function testDefaultLevel(testCase)
            % Test log command with no level -> defaults to INFO
            pm = PluginManager(testCase.logger, testCase.experimentDir);
            executor = CommandExecutor([], pm, testCase.logger);
            
            cmd = struct();
            cmd.type = 'plugin';
            cmd.plugin_name = 'sensor';
            cmd.command_name = 'log';
            cmd.params = struct('message', 'No level specified');
            
            executor.execute(cmd);
            testCase.logger.close();
            
            logFile = fullfile(testCase.experimentDir, 'test.log');
            content = fileread(logFile);
            
            testCase.verifySubstring(content, 'INFO: [PLUGIN: sensor] USER LOG: No level specified', ...
                'Should default to INFO level');
        end
    end
end

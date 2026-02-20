classdef test_log_command < matlab.unittest.TestCase
    % TEST_LOG_COMMAND - Unit tests for ExperimentLogger formatting
    %
    % Tests ExperimentLogger log output format and levels.
    %
    % Note: Tests for PluginManager.logCustomMessage() and CommandExecutor
    % log command routing were removed — those features were removed from
    % the codebase in the V2 protocol integration.
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
    end
end

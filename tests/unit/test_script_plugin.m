classdef test_script_plugin < matlab.unittest.TestCase
    % TEST_SCRIPT_PLUGIN - Unit tests for ScriptPlugin
    %
    % Tests initialization, execution, config extraction, error handling,
    % and cleanup of the ScriptPlugin class using temporary dummy scripts.
    %
    % Run: run(test_script_plugin)
    
    properties
        testRoot
        repoRoot
        logger
        scriptsDir
    end
    
    methods (TestClassSetup)
        function setupTestEnvironment(testCase)
            % Setup: temp directory for dummy scripts and logs
            testCase.testRoot = fullfile(tempdir, 'test_script_plugin');
            if isfolder(testCase.testRoot)
                rmdir(testCase.testRoot, 's');
            end
            mkdir(testCase.testRoot);
            testCase.scriptsDir = fullfile(testCase.testRoot, 'scripts');
            mkdir(testCase.scriptsDir);
            
            % Get repo root
            testCase.repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(testCase.repoRoot, 'experimentExecution'));
            
            % Create a logger for tests
            logFile = fullfile(testCase.testRoot, 'logs', 'script_plugin_test.log');
            testCase.logger = ExperimentLogger(logFile, false, 'DEBUG');
        end
    end
    
    methods (TestClassTeardown)
        function cleanupTestEnvironment(testCase)
            % Clean up temp directory
            if ~isempty(testCase.logger)
                testCase.logger.close();
            end
            if isfolder(testCase.testRoot)
                rmdir(testCase.testRoot, 's');
            end
        end
    end
    
    methods (Test)
        function testInitializeWithValidFunction(testCase)
            % Test initialize ScriptPlugin with valid dummy function
            
            % Create dummy function file
            scriptPath = fullfile(testCase.scriptsDir, 'dummy_func.m');
            testCase.createDummyFunction(scriptPath, 'dummy_func', true);
            
            definition = struct();
            definition.type = 'script';
            definition.script_path = scriptPath;
            definition.script_type = 'function';
            definition.config = struct('experimentDir', testCase.testRoot);
            
            plugin = ScriptPlugin('test_script', definition, testCase.logger);
            plugin.initialize();
            
            % Verify function name extracted
            status = plugin.getStatus();
            testCase.verifyEqual(status.functionName, 'dummy_func', 'Wrong function name');
            testCase.verifyEqual(plugin.getPluginType(), 'script', 'Wrong plugin type');
            
            plugin.cleanup();
        end
        
        function testExecuteDummyFunction(testCase)
            % Test execute dummy function via plugin
            scriptPath = fullfile(testCase.scriptsDir, 'exec_func.m');
            testCase.createDummyFunction(scriptPath, 'exec_func', true);
            
            definition = struct();
            definition.type = 'script';
            definition.script_path = scriptPath;
            definition.config = struct('experimentDir', testCase.testRoot);
            
            plugin = ScriptPlugin('exec_test', definition, testCase.logger);
            plugin.initialize();
            
            params = struct('value', 42);
            result = plugin.execute(params);
            
            testCase.verifyTrue(isstruct(result), 'Result should be a struct');
            testCase.verifyEqual(result.success, true, 'Result should indicate success');
            
            plugin.cleanup();
        end
        
        function testExperimentDirInConfig(testCase)
            % Test ScriptPlugin with experimentDir in config
            scriptPath = fullfile(testCase.scriptsDir, 'dummy_func.m');
            if ~isfile(scriptPath)
                testCase.createDummyFunction(scriptPath, 'dummy_func', true);
            end
            
            customDir = fullfile(testCase.testRoot, 'custom_experiment');
            mkdir(customDir);
            
            definition = struct();
            definition.type = 'script';
            definition.script_path = scriptPath;
            definition.config = struct('experimentDir', customDir);
            
            % Should not error - experimentDir should be extracted
            plugin = ScriptPlugin('config_test', definition, testCase.logger); %#ok<NASGU>
            
            % If we got here without error, test passes
            testCase.verifyTrue(true, 'Construction with experimentDir config succeeded');
        end
        
        function testWithoutExperimentDir(testCase)
            % Test ScriptPlugin without config.experimentDir -> defaults to pwd
            scriptPath = fullfile(testCase.scriptsDir, 'dummy_func.m');
            if ~isfile(scriptPath)
                testCase.createDummyFunction(scriptPath, 'dummy_func', true);
            end
            
            definition = struct();
            definition.type = 'script';
            definition.script_path = scriptPath;
            % No config field at all
            
            % Should not error - defaults to pwd internally
            plugin = ScriptPlugin('default_dir_test', definition, testCase.logger); %#ok<NASGU>
            
            testCase.verifyTrue(true, 'Construction without config succeeded');
        end
        
        function testNonexistentScriptPath(testCase)
            % Test ScriptPlugin with nonexistent script path -> error
            definition = struct();
            definition.type = 'script';
            definition.script_path = fullfile(testCase.testRoot, 'nonexistent_script.m');
            definition.config = struct('experimentDir', testCase.testRoot);
            
            plugin = ScriptPlugin('bad_path_test', definition, testCase.logger);
            
            % Should error on initialize when trying to access nonexistent script
            testCase.verifyError(@() plugin.initialize(), 'ScriptPlugin:FileNotFound', ...
                'Should error on nonexistent script path');
        end
        
        function testCleanupRemovesPath(testCase)
            % Test cleanup removes added path
            scriptDir = fullfile(testCase.testRoot, 'scripts_cleanup_test');
            mkdir(scriptDir);
            scriptPath = fullfile(scriptDir, 'cleanup_func.m');
            testCase.createDummyFunction(scriptPath, 'cleanup_func', false);
            
            definition = struct();
            definition.type = 'script';
            definition.script_path = scriptPath;
            definition.config = struct('experimentDir', testCase.testRoot);
            
            plugin = ScriptPlugin('cleanup_test', definition, testCase.logger);
            plugin.initialize();
            
            % Verify path was added
            testCase.verifySubstring(path, scriptDir, 'Script dir should be on path after init');
            
            % Cleanup
            plugin.cleanup();
            
            % Verify path was removed
            testCase.verifyFalse(contains(path, scriptDir), ...
    'Script dir should be removed from path after cleanup');
        end
    end
    
    methods (Access = private)
        function createDummyFunction(~, filepath, funcName, hasOutput)
            % Helper: create a dummy function file for testing
            fid = fopen(filepath, 'w');
            if hasOutput
                fprintf(fid, 'function result = %s(params)\n', funcName);
                fprintf(fid, '    result = struct(''success'', true, ''input'', params);\n');
            else
                fprintf(fid, 'function %s(params)\n', funcName);
                fprintf(fid, '    %% No output\n');
            end
            fprintf(fid, 'end\n');
            fclose(fid);
        end
    end
end

classdef test_class_plugin < matlab.unittest.TestCase
    % TEST_CLASS_PLUGIN - Unit tests for ClassPlugin infrastructure
    %
    % Tests ClassPlugin using DummyTestPlugin (a minimal test class that
    % implements the required interface). Validates construction, delegation,
    % interface validation, error handling, and config extraction.
    %
    % Run: run(test_class_plugin)
    
    properties
        testRoot
        repoRoot
        logger
        logFile
    end
    
    methods (TestClassSetup)
        function setupTestEnvironment(testCase)
            % Setup: temp directory for logs
            testCase.testRoot = fullfile(tempdir, 'test_class_plugin');
            if isfolder(testCase.testRoot)
                rmdir(testCase.testRoot, 's');
            end
            mkdir(testCase.testRoot);
            
            % Get repo root and add paths
            testCase.repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(testCase.repoRoot, 'experimentExecution'));
            addpath(fullfile(testCase.repoRoot, 'tests', 'fixtures'));  % For DummyTestPlugin
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
            % Create fresh logger for each test
            testCase.logFile = fullfile(testCase.testRoot, 'logs', ...
                sprintf('test_%s.log', datestr(now, 'HHMMSS_FFF')));
            testCase.logger = ExperimentLogger(testCase.logFile, false, 'DEBUG');
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
        function testInstantiateWithDummyPlugin(testCase)
            % Test instantiate ClassPlugin with DummyTestPlugin
            definition = struct();
            definition.type = 'class';
            definition.matlab = struct('class', 'DummyTestPlugin');
            definition.config = struct('experimentDir', testCase.testRoot, 'port', 'COM6');
            
            plugin = ClassPlugin('test_dummy', definition, testCase.logger);
            
            testCase.verifyEqual(plugin.getPluginType(), 'class', ...
                'Plugin type should be "class"');
        end
        
        function testInitializeDelegation(testCase)
            % Test Initialize delegates to DummyTestPlugin.initialize()
            definition = struct();
            definition.type = 'class';
            definition.matlab = struct('class', 'DummyTestPlugin');
            definition.config = struct('experimentDir', testCase.testRoot);
            
            plugin = ClassPlugin('init_test', definition, testCase.logger);
            plugin.initialize();
            
            % Verify via log output that initialization was called
            testCase.logger.close();
            content = fileread(testCase.logFile);
            testCase.verifySubstring(content, 'DummyTestPlugin initialized', ...
                'DummyTestPlugin.initialize() should have been called');
        end
        
        function testExecuteDelegation(testCase)
            % Test Execute delegates to DummyTestPlugin.execute()
            definition = struct();
            definition.type = 'class';
            definition.matlab = struct('class', 'DummyTestPlugin');
            definition.config = struct('experimentDir', testCase.testRoot);
            
            plugin = ClassPlugin('exec_test', definition, testCase.logger);
            plugin.initialize();
            
            params = struct('power', 5, 'pattern', '1010');
            result = plugin.execute('setRedLED', params);
            
            testCase.verifyTrue(isstruct(result), 'Should return a struct');
            testCase.verifyEqual(result.success, true, 'Should indicate success');
            testCase.verifyEqual(result.command, 'setRedLED', 'Command should be passed through');
        end
        
        function testCleanupDelegation(testCase)
            % Test Cleanup delegates to DummyTestPlugin.cleanup()
            definition = struct();
            definition.type = 'class';
            definition.matlab = struct('class', 'DummyTestPlugin');
            definition.config = struct('experimentDir', testCase.testRoot);
            
            plugin = ClassPlugin('cleanup_test', definition, testCase.logger);
            plugin.initialize();
            plugin.cleanup();
            
            % Verify via log that cleanup was called
            testCase.logger.close();
            content = fileread(testCase.logFile);
            testCase.verifySubstring(content, 'DummyTestPlugin cleaned up', ...
                'DummyTestPlugin.cleanup() should have been called');
        end
        
        function testGetPluginType(testCase)
            % Test getPluginType returns 'class'
            definition = struct();
            definition.type = 'class';
            definition.matlab = struct('class', 'DummyTestPlugin');
            definition.config = struct('experimentDir', testCase.testRoot);
            
            plugin = ClassPlugin('type_test', definition, testCase.logger);
            ptype = plugin.getPluginType();
            
            testCase.verifyEqual(ptype, 'class', 'Expected "class"');
        end
        
        function testMissingRequiredMethod(testCase)
            % Test ClassPlugin with class missing required method -> error
            
            % Create a temporary class file that's missing cleanup()
            incompleteDir = fullfile(testCase.testRoot, 'incomplete_class');
            mkdir(incompleteDir);
            classFile = fullfile(incompleteDir, 'IncompletePlugin.m');
            fid = fopen(classFile, 'w');
            fprintf(fid, 'classdef IncompletePlugin < handle\n');
            fprintf(fid, '    methods\n');
            fprintf(fid, '        function self = IncompletePlugin(name, config, logger)\n');
            fprintf(fid, '        end\n');
            fprintf(fid, '        function initialize(self)\n');
            fprintf(fid, '        end\n');
            fprintf(fid, '        function result = execute(self, command, params)\n');
            fprintf(fid, '            result = [];\n');
            fprintf(fid, '        end\n');
            fprintf(fid, '        %% NOTE: cleanup() is intentionally missing\n');
            fprintf(fid, '    end\n');
            fprintf(fid, 'end\n');
            fclose(fid);
            addpath(incompleteDir);
            
            definition = struct();
            definition.type = 'class';
            definition.matlab = struct('class', 'IncompletePlugin');
            definition.config = struct('experimentDir', testCase.testRoot);
            
            % Should error on missing cleanup method
            testCase.verifyError(@() ClassPlugin('incomplete_test', definition, testCase.logger), 'ClassPlugin:MissingMethod', ...
                'Should error on missing cleanup method');
            
            rmpath(incompleteDir);
        end
        
        function testNonexistentClass(testCase)
            % Test ClassPlugin with nonexistent class name -> error
            definition = struct();
            definition.type = 'class';
            definition.matlab = struct('class', 'NonexistentClass12345');
            definition.config = struct('experimentDir', testCase.testRoot);
            
            testCase.verifyError(@() ClassPlugin('noclass_test', definition, testCase.logger), 'ClassPlugin:ClassNotFound', ...
                'Should error on nonexistent class');
        end
        
        function testExperimentDirExtraction(testCase)
            % Test experimentDir extracted from config
            customDir = fullfile(testCase.testRoot, 'custom_exp_dir');
            mkdir(customDir);
            
            definition = struct();
            definition.type = 'class';
            definition.matlab = struct('class', 'DummyTestPlugin');
            definition.config = struct('experimentDir', customDir);
            
            plugin = ClassPlugin('dir_test', definition, testCase.logger);
            
            % getStatus() returns class status which includes the config
            status = plugin.getStatus();
            testCase.verifyTrue(status.hasInstance, 'Should have created an instance');
        end
    end
end

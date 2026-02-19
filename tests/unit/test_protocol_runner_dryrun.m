classdef test_protocol_runner_dryrun < matlab.unittest.TestCase
    % TEST_PROTOCOL_RUNNER_DRYRUN - Unit tests for ProtocolRunner construction & dry-run
    %
    % Tests ProtocolRunner construction (YAML parsing, experiment directory
    % creation, timestamp generation) without needing hardware.
    % NOTE: run() with DryRun=false requires a real G4.1 arena connection -
    % use the manual checklist for that.
    %
    % Run: run(test_protocol_runner_dryrun)
    
    properties
        testRoot
        repoRoot
        testYaml
    end
    
    methods (TestClassSetup)
        function setupTestEnvironment(testCase)
            % Setup
            testCase.testRoot = fullfile(tempdir, 'test_protocol_runner');
            if isfolder(testCase.testRoot)
                rmdir(testCase.testRoot, 's');
            end
            mkdir(testCase.testRoot);
            
            % Get repo root
            testCase.repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(testCase.repoRoot, 'experimentExecution'));
            addpath(fullfile(testCase.repoRoot, 'yamlSupport'));
            
            % Verify we have a valid YAML file for construction tests
            testCase.testYaml = fullfile(testCase.repoRoot, 'tests', 'fixtures', 'test_g41_controller_only.yaml');
            testCase.assumeTrue(isfile(testCase.testYaml), ...
                'test_g41_controller_only.yaml not found - cannot run tests');
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
    
    methods (Test)
        function testConstructWithValidYaml(testCase)
            % Test construct ProtocolRunner with valid YAML and dummy IP
            outputDir = fullfile(testCase.testRoot, 'output1');
            mkdir(outputDir);
            
            runner = ProtocolRunner(testCase.testYaml, '0.0.0.0', ...
                'OutputDir', outputDir, 'Verbose', false, 'DryRun', true); %#ok<NASGU>
            
            % If we got here without error, construction succeeded
            testCase.verifyTrue(true, 'Construction succeeded');
        end
        
        function testExperimentDirectoryNaming(testCase)
            % Test experiment directory is created as outputDir/yamlName_timestamp
            outputDir = fullfile(testCase.testRoot, 'output2');
            mkdir(outputDir);
            
            runner = ProtocolRunner(testCase.testYaml, '0.0.0.0', ...
                'OutputDir', outputDir, 'Verbose', false, 'DryRun', true); %#ok<NASGU>
            
            % Check that a directory was created inside outputDir
            dirContents = dir(outputDir);
            dirContents = dirContents(~ismember({dirContents.name}, {'.', '..'}));
            dirContents = dirContents([dirContents.isdir]);
            
            testCase.verifyNotEmpty(dirContents, 'No experiment directory was created');
            
            % Verify naming: should start with yaml filename
            [~, yamlName, ~] = fileparts(testCase.testYaml);
            expDirName = dirContents(1).name;
            testCase.verifyTrue(startsWith(expDirName, yamlName), ...
                sprintf('Experiment dir should start with YAML filename. Got: %s', expDirName));
            
            % Verify timestamp portion (after the yaml name + underscore)
            timestampPart = expDirName(length(yamlName)+2:end);
            testCase.verifyEqual(length(timestampPart), 15, ...  % yyyyMMdd_HHmmss = 15 chars
                sprintf('Timestamp should be 15 characters (yyyyMMdd_HHmmss). Got: %s', timestampPart));
            testCase.verifyMatches(timestampPart, '^\d{8}_\d{6}$', ...
                sprintf('Timestamp should match yyyyMMdd_HHmmss format. Got: %s', timestampPart));
        end
        
        function testTimestampUniqueness(testCase)
            % Test startTime timestamp format and uniqueness
            outputDir = fullfile(testCase.testRoot, 'output3');
            mkdir(outputDir);
            
            % Create two runners ~1 second apart to verify timestamps differ
            runner1 = ProtocolRunner(testCase.testYaml, '0.0.0.0', ...
                'OutputDir', outputDir, 'Verbose', false, 'DryRun', true); %#ok<NASGU>
            
            pause(1.5);
            
            runner2 = ProtocolRunner(testCase.testYaml, '0.0.0.0', ...
                'OutputDir', outputDir, 'Verbose', false, 'DryRun', true); %#ok<NASGU>
            
            % Both should have created experiment directories
            dirContents = dir(outputDir);
            dirContents = dirContents(~ismember({dirContents.name}, {'.', '..'}));
            dirContents = dirContents([dirContents.isdir]);
            
            testCase.verifyGreaterThanOrEqual(length(dirContents), 2, ...
                sprintf('Expected at least 2 experiment directories, got %d', length(dirContents)));
            
            % They should have different names (different timestamps)
            names = sort({dirContents.name});
            testCase.verifyNotEqual(names{1}, names{2}, ...
                'Two runners should create directories with different timestamps');
        end
        
        function testInvalidYamlFilePath(testCase)
            % Test construct with invalid YAML file path -> error
            outputDir = fullfile(testCase.testRoot, 'output4');
            mkdir(outputDir);

             % Use try-catch to verify error occurred
            errored = false;
            errorMsg = '';
            try
                ProtocolRunner(fullfile(testCase.testRoot, 'nonexistent.yaml'), '0.0.0.0', ...
                'OutputDir', outputDir, 'Verbose', false)
            catch ME
                errored = true;
                errorMsg = ME.message;
            end

            testCase.verifyTrue(errored, 'Should error on nonexistent YAML file');
            testCase.verifySubstring(errorMsg, 'protocol', ...
            'Error message should mention protocol it failed to parse');
        end

        
        function testYamlValidationFailure(testCase)
            % Test construct with YAML that fails validation -> error propagated
            outputDir = fullfile(testCase.testRoot, 'output5');
            mkdir(outputDir);
            
            % Write a YAML missing required 'block' section
            bad_yaml = fullfile(testCase.testRoot, 'bad_protocol.yaml');
            fid = fopen(bad_yaml, 'w');
            fprintf(fid, 'version: 1\n');
            fprintf(fid, 'experiment_info:\n');
            fprintf(fid, '  name: "Bad Protocol"\n');
            fprintf(fid, 'arena_info:\n');
            fprintf(fid, '  num_rows: 2\n');
            fprintf(fid, '  num_cols: 12\n');
            fprintf(fid, '  generation: "G4.1"\n');
            fprintf(fid, 'experiment_structure:\n');
            fprintf(fid, '  repetitions: 1\n');
            fclose(fid);
            
            try
                runner = ProtocolRunner(bad_yaml, '0.0.0.0', ...
                    'OutputDir', outputDir, 'Verbose', false); %#ok<NASGU>
                testCase.verifyFail('Should have errored on invalid YAML');
            catch ME
                % Verify error message mentions the problem
                testCase.verifyTrue(contains(ME.message, 'block') || ...
                                  contains(ME.message, 'validation') || ...
                                  contains(ME.message, 'parse'), ...
                    'Error should mention missing block section or validation failure');
            end
        end
    end
end

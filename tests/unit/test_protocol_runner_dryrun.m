classdef test_protocol_runner_dryrun < matlab.unittest.TestCase
    % TEST_PROTOCOL_RUNNER_DRYRUN - Unit tests for ProtocolRunner construction & dry-run
    %
    % Tests ProtocolRunner construction (YAML parsing, error handling)
    % without needing hardware.
    %
    % Note: Tests for timestamped experiment directory naming were removed —
    % ProtocolRunner now derives experimentDir from the protocol file path
    % instead of creating timestamped subdirectories.
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

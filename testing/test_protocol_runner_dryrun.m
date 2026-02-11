%% TEST_PROTOCOL_RUNNER_DRYRUN - Tests for ProtocolRunner construction & dry-run
%
% Tests ProtocolRunner construction (YAML parsing, experiment directory
% creation, timestamp generation) without needing hardware.
% NOTE: run() with DryRun=false requires a real G4.1 arena connection -
% use the manual checklist for that.
%
% Run: run('testing/test_protocol_runner_dryrun.m')

clearvars;
close all;
clc;

fprintf('=== ProtocolRunner Dry-Run Test Suite ===\n\n');

% Track results
numTests = 0;
numPassed = 0;

% Setup
test_root = fullfile(tempdir, 'test_protocol_runner');
if isfolder(test_root)
    rmdir(test_root, 's');
end
mkdir(test_root);

% Get repo root
[repo_root, ~, ~] = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repo_root, 'experimentExecution'));
addpath(fullfile(repo_root, 'yamlSupport'));

% We need a valid YAML file for construction tests
test_yaml = fullfile(repo_root, 'testing', 'test_g41_controller_only.yaml');
if ~isfile(test_yaml)
    error('test_g41_controller_only.yaml not found - run test creation first');
end

%% TEST 1: Construct ProtocolRunner with valid YAML
numTests = numTests + 1;
fprintf('TEST 1: Construct ProtocolRunner with valid YAML and dummy IP...\n');
try
    outputDir = fullfile(test_root, 'output1');
    mkdir(outputDir);

    runner = ProtocolRunner(test_yaml, '0.0.0.0', ...
        'OutputDir', outputDir, 'Verbose', false, 'DryRun', true);

    fprintf('  PASS (construction succeeded)\n\n');
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 2: Verify experiment directory is created as outputDir/yamlName_timestamp
numTests = numTests + 1;
fprintf('TEST 2: Experiment directory created with correct naming...\n');
try
    outputDir = fullfile(test_root, 'output2');
    mkdir(outputDir);

    runner = ProtocolRunner(test_yaml, '0.0.0.0', ...
        'OutputDir', outputDir, 'Verbose', false, 'DryRun', true);

    % Check that a directory was created inside outputDir
    dirContents = dir(outputDir);
    dirContents = dirContents(~ismember({dirContents.name}, {'.', '..'}));
    dirContents = dirContents([dirContents.isdir]);

    assert(~isempty(dirContents), 'No experiment directory was created');

    % Verify naming: should start with yaml filename
    [~, yamlName, ~] = fileparts(test_yaml);
    expDirName = dirContents(1).name;
    assert(startsWith(expDirName, yamlName), ...
        'Experiment dir should start with YAML filename. Got: %s', expDirName);

    % Verify timestamp portion (after the yaml name + underscore)
    timestampPart = expDirName(length(yamlName)+2:end);
    assert(length(timestampPart) == 15, ...  % yyyyMMdd_HHmmss = 15 chars
        'Timestamp should be 15 characters (yyyyMMdd_HHmmss). Got: %s', timestampPart);
    assert(~isempty(regexp(timestampPart, '^\d{8}_\d{6}$', 'once')), ...
        'Timestamp should match yyyyMMdd_HHmmss format. Got: %s', timestampPart);

    fprintf('  PASS (dir: %s)\n\n', expDirName);
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 3: Verify startTime timestamp format
numTests = numTests + 1;
fprintf('TEST 3: startTime timestamp format yyyyMMdd_HHmmss...\n');
try
    outputDir = fullfile(test_root, 'output3');
    mkdir(outputDir);

    % Create two runners ~1 second apart to verify timestamps differ
    runner1 = ProtocolRunner(test_yaml, '0.0.0.0', ...
        'OutputDir', outputDir, 'Verbose', false, 'DryRun', true);

    pause(1.5);

    runner2 = ProtocolRunner(test_yaml, '0.0.0.0', ...
        'OutputDir', outputDir, 'Verbose', false, 'DryRun', true);

    % Both should have created experiment directories
    dirContents = dir(outputDir);
    dirContents = dirContents(~ismember({dirContents.name}, {'.', '..'}));
    dirContents = dirContents([dirContents.isdir]);

    assert(length(dirContents) >= 2, ...
        'Expected at least 2 experiment directories, got %d', length(dirContents));

    % They should have different names (different timestamps)
    names = sort({dirContents.name});
    assert(~strcmp(names{1}, names{2}), 'Two runners should create directories with different timestamps');

    fprintf('  PASS (two distinct timestamps)\n\n');
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 4: Construct with invalid YAML file path -> error
numTests = numTests + 1;
fprintf('TEST 4: Invalid YAML file path -> error...\n');
try
    outputDir = fullfile(test_root, 'output4');
    mkdir(outputDir);

    errored = false;
    try
        runner = ProtocolRunner(fullfile(test_root, 'nonexistent.yaml'), '0.0.0.0', ...
            'OutputDir', outputDir, 'Verbose', false); %#ok<NASGU>
    catch
        errored = true;
    end

    assert(errored, 'Should have errored on nonexistent YAML file');

    fprintf('  PASS\n\n');
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 5: Construct with YAML that fails validation -> error
numTests = numTests + 1;
fprintf('TEST 5: YAML that fails validation -> error propagated...\n');
try
    outputDir = fullfile(test_root, 'output5');
    mkdir(outputDir);

    % Write a YAML missing required 'block' section
    bad_yaml = fullfile(test_root, 'bad_protocol.yaml');
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

    errored = false;
    errorMsg = '';
    try
        runner = ProtocolRunner(bad_yaml, '0.0.0.0', ...
            'OutputDir', outputDir, 'Verbose', false); %#ok<NASGU>
    catch ME_inner
        errored = true;
        errorMsg = ME_inner.message;
    end

    assert(errored, 'Should have errored on invalid YAML');
    assert(contains(errorMsg, 'block') || contains(errorMsg, 'validation') || ...
           contains(errorMsg, 'parse'), ...
        'Error should mention missing block section');

    fprintf('  PASS (error: %s)\n\n', errorMsg);
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% Summary
fprintf('\n=== TEST SUMMARY ===\n');
fprintf('Passed: %d / %d\n', numPassed, numTests);
if numPassed == numTests
    fprintf('ALL TESTS PASSED\n');
else
    fprintf('SOME TESTS FAILED\n');
end

fprintf('\nTo clean up: rmdir(''%s'', ''s'')\n', test_root);

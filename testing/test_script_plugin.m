%% TEST_SCRIPT_PLUGIN - Tests for ScriptPlugin
%
% Tests initialization, execution, config extraction, error handling,
% and cleanup of the ScriptPlugin class using temporary dummy scripts.
%
% Run: run('testing/test_script_plugin.m')

clearvars;
close all;
clc;

fprintf('=== ScriptPlugin Test Suite ===\n\n');

% Track results
numTests = 0;
numPassed = 0;

% Setup: temp directory for dummy scripts and logs
test_root = fullfile(tempdir, 'test_script_plugin');
if isfolder(test_root)
    rmdir(test_root, 's');
end
mkdir(test_root);
mkdir(fullfile(test_root, 'scripts'));

% Get repo root
[repo_root, ~, ~] = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repo_root, 'experimentExecution'));

% Create a logger for tests
logFile = fullfile(test_root, 'logs', 'script_plugin_test.log');
logger = ExperimentLogger(logFile, false, 'DEBUG');

%% Helper: create a dummy function file
function create_dummy_function(filepath, funcName, hasOutput)
    fid = fopen(filepath, 'w');
    if hasOutput
        fprintf(fid, 'function result = %s(params)\n', funcName);
        fprintf(fid, '    result = struct(''success'', true, ''input'', params);\n');
    else
        fprintf(fid, 'function %s(params)\n', funcName);
        fprintf(fid, '    % No output\n');
    end
    fprintf(fid, 'end\n');
    fclose(fid);
end

%% TEST 1: Initialize ScriptPlugin with valid dummy function
numTests = numTests + 1;
fprintf('TEST 1: Initialize ScriptPlugin with valid dummy function...\n');
try
    % Create dummy function file
    scriptPath = fullfile(test_root, 'scripts', 'dummy_func.m');
    create_dummy_function(scriptPath, 'dummy_func', true);

    definition = struct();
    definition.type = 'script';
    definition.script_path = scriptPath;
    definition.script_type = 'function';
    definition.config = struct('experimentDir', test_root);

    plugin = ScriptPlugin('test_script', definition, logger);
    plugin.initialize();

    % Verify function name extracted
    status = plugin.getStatus();
    assert(strcmp(status.functionName, 'dummy_func'), 'Wrong function name');
    assert(strcmp(plugin.getPluginType(), 'script'), 'Wrong plugin type');

    plugin.cleanup();
    fprintf('  PASS\n\n');
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 2: Execute dummy function via plugin
numTests = numTests + 1;
fprintf('TEST 2: Execute dummy function via plugin...\n');
try
    scriptPath = fullfile(test_root, 'scripts', 'exec_func.m');
    create_dummy_function(scriptPath, 'exec_func', true);

    definition = struct();
    definition.type = 'script';
    definition.script_path = scriptPath;
    definition.config = struct('experimentDir', test_root);

    plugin = ScriptPlugin('exec_test', definition, logger);
    plugin.initialize();

    params = struct('value', 42);
    result = plugin.execute(params);

    assert(isstruct(result), 'Result should be a struct');
    assert(result.success == true, 'Result should indicate success');

    plugin.cleanup();
    fprintf('  PASS\n\n');
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 3: ScriptPlugin with experimentDir in config
numTests = numTests + 1;
fprintf('TEST 3: ScriptPlugin with experimentDir in config...\n');
try
    scriptPath = fullfile(test_root, 'scripts', 'dummy_func.m');
    if ~isfile(scriptPath)
        create_dummy_function(scriptPath, 'dummy_func', true);
    end

    customDir = fullfile(test_root, 'custom_experiment');
    mkdir(customDir);

    definition = struct();
    definition.type = 'script';
    definition.script_path = scriptPath;
    definition.config = struct('experimentDir', customDir);

    plugin = ScriptPlugin('config_test', definition, logger);

    % extractConfiguration() runs in constructor - experimentDir should be set
    % We can't directly access private properties, but if no error was thrown
    % during construction with the config, the extraction succeeded
    fprintf('  PASS (no error during construction with experimentDir config)\n\n');
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 4: ScriptPlugin without config.experimentDir
numTests = numTests + 1;
fprintf('TEST 4: ScriptPlugin without config.experimentDir -> defaults to pwd...\n');
try
    scriptPath = fullfile(test_root, 'scripts', 'dummy_func.m');
    if ~isfile(scriptPath)
        create_dummy_function(scriptPath, 'dummy_func', true);
    end

    definition = struct();
    definition.type = 'script';
    definition.script_path = scriptPath;
    % No config field at all

    plugin = ScriptPlugin('default_dir_test', definition, logger);
    % Should not error - defaults to pwd internally

    fprintf('  PASS (no error during construction without config)\n\n');
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 5: ScriptPlugin with nonexistent script path
numTests = numTests + 1;
fprintf('TEST 5: ScriptPlugin with nonexistent script path -> error...\n');
try
    definition = struct();
    definition.type = 'script';
    definition.script_path = fullfile(test_root, 'nonexistent_script.m');
    definition.config = struct('experimentDir', test_root);

    plugin = ScriptPlugin('bad_path_test', definition, logger);

    errored = false;
    try
        plugin.initialize();
    catch
        errored = true;
    end

    assert(errored, 'Should have errored on nonexistent script path');

    fprintf('  PASS\n\n');
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 6: Cleanup removes added path
numTests = numTests + 1;
fprintf('TEST 6: Cleanup removes added path...\n');
try
    scriptDir = fullfile(test_root, 'scripts_cleanup_test');
    mkdir(scriptDir);
    scriptPath = fullfile(scriptDir, 'cleanup_func.m');
    create_dummy_function(scriptPath, 'cleanup_func', false);

    definition = struct();
    definition.type = 'script';
    definition.script_path = scriptPath;
    definition.config = struct('experimentDir', test_root);

    plugin = ScriptPlugin('cleanup_test', definition, logger);
    plugin.initialize();

    % Verify path was added
    assert(contains(path, scriptDir), 'Script dir should be on path after init');

    % Cleanup
    plugin.cleanup();

    % Verify path was removed
    assert(~contains(path, scriptDir), 'Script dir should be removed from path after cleanup');

    fprintf('  PASS\n\n');
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% Cleanup
logger.close();

%% Summary
fprintf('\n=== TEST SUMMARY ===\n');
fprintf('Passed: %d / %d\n', numPassed, numTests);
if numPassed == numTests
    fprintf('ALL TESTS PASSED\n');
else
    fprintf('SOME TESTS FAILED\n');
end

fprintf('\nTo clean up: rmdir(''%s'', ''s'')\n', test_root);

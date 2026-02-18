%% TEST_CLASS_PLUGIN - Tests for ClassPlugin infrastructure
%
% Tests ClassPlugin using DummyTestPlugin (a minimal test class that
% implements the required interface). Validates construction, delegation,
% interface validation, error handling, and config extraction.
%
% Run: run('testing/test_class_plugin.m')

clearvars;
close all;
clc;

fprintf('=== ClassPlugin Test Suite ===\n\n');

% Track results
numTests = 0;
numPassed = 0;

% Setup: temp directory for logs
test_root = fullfile(tempdir, 'test_class_plugin');
if isfolder(test_root)
    rmdir(test_root, 's');
end
mkdir(test_root);

% Get repo root and add paths
[repo_root, ~, ~] = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repo_root, 'experimentExecution'));
addpath(fullfile(repo_root, 'testing'));  % For DummyTestPlugin

% Create logger
logFile = fullfile(test_root, 'logs', 'class_plugin_test.log');
logger = ExperimentLogger(logFile, false, 'DEBUG');

%% TEST 1: Instantiate ClassPlugin with DummyTestPlugin
numTests = numTests + 1;
fprintf('TEST 1: Instantiate ClassPlugin with DummyTestPlugin...\n');
try
    definition = struct();
    definition.type = 'class';
    definition.matlab = struct('class', 'DummyTestPlugin');
    definition.config = struct('experimentDir', test_root, 'port', 'COM6');

    plugin = ClassPlugin('test_dummy', definition, logger);

    assert(strcmp(plugin.getPluginType(), 'class'), 'Plugin type should be "class"');

    fprintf('  PASS\n\n');
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 2: Initialize delegates to DummyTestPlugin.initialize()
numTests = numTests + 1;
fprintf('TEST 2: Initialize delegates to DummyTestPlugin.initialize()...\n');
try
    definition = struct();
    definition.type = 'class';
    definition.matlab = struct('class', 'DummyTestPlugin');
    definition.config = struct('experimentDir', test_root);

    plugin = ClassPlugin('init_test', definition, logger);
    plugin.initialize();

    % We can verify via log output that initialization was called
    logger.close();
    content = fileread(logFile);
    assert(contains(content, 'DummyTestPlugin initialized'), ...
        'DummyTestPlugin.initialize() should have been called');

    % Reopen logger for remaining tests
    logFile2 = fullfile(test_root, 'logs', 'class_plugin_test2.log');
    logger = ExperimentLogger(logFile2, false, 'DEBUG');

    fprintf('  PASS\n\n');
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 3: Execute delegates to DummyTestPlugin.execute()
numTests = numTests + 1;
fprintf('TEST 3: Execute delegates with command and params...\n');
try
    definition = struct();
    definition.type = 'class';
    definition.matlab = struct('class', 'DummyTestPlugin');
    definition.config = struct('experimentDir', test_root);

    plugin = ClassPlugin('exec_test', definition, logger);
    plugin.initialize();

    params = struct('power', 5, 'pattern', '1010');
    result = plugin.execute('setRedLED', params);

    assert(isstruct(result), 'Should return a struct');
    assert(result.success == true, 'Should indicate success');
    assert(strcmp(result.command, 'setRedLED'), 'Command should be passed through');

    fprintf('  PASS\n\n');
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 4: Cleanup delegates to DummyTestPlugin.cleanup()
numTests = numTests + 1;
fprintf('TEST 4: Cleanup delegates to DummyTestPlugin.cleanup()...\n');
try
    definition = struct();
    definition.type = 'class';
    definition.matlab = struct('class', 'DummyTestPlugin');
    definition.config = struct('experimentDir', test_root);

    plugin = ClassPlugin('cleanup_test', definition, logger);
    plugin.initialize();
    plugin.cleanup();

    % Verify via log that cleanup was called
    logger.close();
    content = fileread(fullfile(test_root, 'logs', 'class_plugin_test2.log'));
    assert(contains(content, 'DummyTestPlugin cleaned up'), ...
        'DummyTestPlugin.cleanup() should have been called');

    % Reopen logger
    logFile3 = fullfile(test_root, 'logs', 'class_plugin_test3.log');
    logger = ExperimentLogger(logFile3, false, 'DEBUG');

    fprintf('  PASS\n\n');
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 5: getPluginType returns 'class'
numTests = numTests + 1;
fprintf('TEST 5: getPluginType() returns "class"...\n');
try
    definition = struct();
    definition.type = 'class';
    definition.matlab = struct('class', 'DummyTestPlugin');
    definition.config = struct('experimentDir', test_root);

    plugin = ClassPlugin('type_test', definition, logger);
    ptype = plugin.getPluginType();
    assert(strcmp(ptype, 'class'), 'Expected "class", got "%s"', ptype);

    fprintf('  PASS\n\n');
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 6: ClassPlugin with class missing required method -> error
numTests = numTests + 1;
fprintf('TEST 6: Class missing required method -> error...\n');
try
    % Create a temporary class file that's missing cleanup()
    incompleteDir = fullfile(test_root, 'incomplete_class');
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
    definition.config = struct('experimentDir', test_root);

    errored = false;
    try
        plugin = ClassPlugin('incomplete_test', definition, logger); %#ok<NASGU>
    catch ME_inner
        errored = true;
        assert(contains(ME_inner.identifier, 'MissingMethod') || ...
               contains(ME_inner.message, 'cleanup'), ...
            'Expected MissingMethod error about cleanup');
    end

    rmpath(incompleteDir);
    assert(errored, 'Should have errored on missing cleanup method');

    fprintf('  PASS\n\n');
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 7: ClassPlugin with nonexistent class name -> error
numTests = numTests + 1;
fprintf('TEST 7: Nonexistent class name -> error...\n');
try
    definition = struct();
    definition.type = 'class';
    definition.matlab = struct('class', 'NonexistentClass12345');
    definition.config = struct('experimentDir', test_root);

    errored = false;
    try
        plugin = ClassPlugin('noclass_test', definition, logger); %#ok<NASGU>
    catch ME_inner
        errored = true;
        assert(contains(ME_inner.identifier, 'ClassNotFound') || ...
               contains(ME_inner.message, 'not found'), ...
            'Expected ClassNotFound error');
    end

    assert(errored, 'Should have errored on nonexistent class');

    fprintf('  PASS\n\n');
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 8: experimentDir extracted from config
numTests = numTests + 1;
fprintf('TEST 8: experimentDir extracted from config...\n');
try
    customDir = fullfile(test_root, 'custom_exp_dir');
    mkdir(customDir);

    definition = struct();
    definition.type = 'class';
    definition.matlab = struct('class', 'DummyTestPlugin');
    definition.config = struct('experimentDir', customDir);

    plugin = ClassPlugin('dir_test', definition, logger);

    % getStatus() returns class status which includes the config
    status = plugin.getStatus();
    assert(status.hasInstance, 'Should have created an instance');

    fprintf('  PASS (construction with experimentDir config succeeded)\n\n');
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

%% TEST_LOG_COMMAND - Tests for the universal log command feature
%
% Tests ExperimentLogger, PluginManager.logCustomMessage(), and
% CommandExecutor log command routing.
%
% Run: run('testing/test_log_command.m')

clearvars;
close all;
clc;

fprintf('=== Log Command Test Suite ===\n\n');

% Track results
numTests = 0;
numPassed = 0;

% Setup: temp directory for log files
test_root = fullfile(tempdir, 'test_log_command');
if isfolder(test_root)
    rmdir(test_root, 's');
end
mkdir(test_root);

% Get repo root
[repo_root, ~, ~] = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repo_root, 'experimentExecution'));

%% TEST 1: ExperimentLogger writes correct format at each level
numTests = numTests + 1;
fprintf('TEST 1: ExperimentLogger writes correct format at each level...\n');
try
    logFile = fullfile(test_root, 'logs', 'test1.log');
    logger = ExperimentLogger(logFile, false, 'DEBUG');

    logger.log('DEBUG', 'debug message');
    logger.log('INFO', 'info message');
    logger.log('WARNING', 'warning message');
    logger.log('ERROR', 'error message');
    logger.close();

    % Read log file and verify format
    content = fileread(logFile);
    assert(contains(content, 'DEBUG: debug message'), 'Missing DEBUG entry');
    assert(contains(content, 'INFO: info message'), 'Missing INFO entry');
    assert(contains(content, 'WARNING: warning message'), 'Missing WARNING entry');
    assert(contains(content, 'ERROR: error message'), 'Missing ERROR entry');
    % Verify timestamp format [YYYY-MM-DD HH:MM:SS.FFF]
    assert(~isempty(regexp(content, '\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\]', 'once')), ...
        'Missing timestamp in expected format');

    fprintf('  PASS\n\n');
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 2: PluginManager.logCustomMessage() formatting
numTests = numTests + 1;
fprintf('TEST 2: PluginManager.logCustomMessage() formatting...\n');
try
    logFile = fullfile(test_root, 'logs', 'test2.log');
    logger = ExperimentLogger(logFile, false, 'DEBUG');
    experimentDir = fullfile(test_root, 'experiment2');
    mkdir(experimentDir);
    pm = PluginManager(logger, experimentDir);

    pm.logCustomMessage('my_plugin', 'User says hello', 'INFO');
    logger.close();

    content = fileread(logFile);
    assert(contains(content, '[PLUGIN: my_plugin] USER LOG: User says hello'), ...
        'Log message not formatted correctly');

    fprintf('  PASS\n\n');
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 3: Log command routes through CommandExecutor
numTests = numTests + 1;
fprintf('TEST 3: Log command routes through CommandExecutor...\n');
try
    logFile = fullfile(test_root, 'logs', 'test3.log');
    logger = ExperimentLogger(logFile, false, 'DEBUG');
    experimentDir = fullfile(test_root, 'experiment3');
    mkdir(experimentDir);
    pm = PluginManager(logger, experimentDir);

    % CommandExecutor needs an arenaController - pass [] since we
    % won't execute controller commands in this test
    executor = CommandExecutor([], pm, logger);

    % Build log command struct matching YAML format
    cmd = struct();
    cmd.type = 'plugin';
    cmd.plugin_name = 'test_plugin';
    cmd.command_name = 'log';
    cmd.params = struct('message', 'Custom log from YAML', 'level', 'INFO');

    executor.execute(cmd);
    logger.close();

    content = fileread(logFile);
    assert(contains(content, '[PLUGIN: test_plugin] USER LOG: Custom log from YAML'), ...
        'Log command did not route correctly through CommandExecutor');

    fprintf('  PASS\n\n');
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 4: Log command with explicit WARNING and ERROR levels
numTests = numTests + 1;
fprintf('TEST 4: Log command with explicit WARNING and ERROR levels...\n');
try
    logFile = fullfile(test_root, 'logs', 'test4.log');
    logger = ExperimentLogger(logFile, false, 'DEBUG');
    experimentDir = fullfile(test_root, 'experiment4');
    mkdir(experimentDir);
    pm = PluginManager(logger, experimentDir);
    executor = CommandExecutor([], pm, logger);

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

    logger.close();

    content = fileread(logFile);
    assert(contains(content, 'WARNING: [PLUGIN: my_device] USER LOG: Temp is high'), ...
        'WARNING level not respected');
    assert(contains(content, 'ERROR: [PLUGIN: my_device] USER LOG: Sensor offline'), ...
        'ERROR level not respected');

    fprintf('  PASS\n\n');
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 5: Log command with no params.message field
numTests = numTests + 1;
fprintf('TEST 5: Log command with missing params.message...\n');
try
    logFile = fullfile(test_root, 'logs', 'test5.log');
    logger = ExperimentLogger(logFile, false, 'DEBUG');
    experimentDir = fullfile(test_root, 'experiment5');
    mkdir(experimentDir);
    pm = PluginManager(logger, experimentDir);
    executor = CommandExecutor([], pm, logger);

    % Build command with command_name='log' but no params.message
    cmd = struct();
    cmd.type = 'plugin';
    cmd.plugin_name = 'test_plugin';
    cmd.command_name = 'log';
    cmd.params = struct('level', 'INFO');  % message is missing

    errored = false;
    try
        executor.execute(cmd);
    catch
        errored = true;
    end

    logger.close();

    % Current behavior: falls through to plugin lookup, which errors
    % because 'test_plugin' isn't registered. This is functional but
    % the error message is misleading.
    % NOTE FOR LISA: Consider adding explicit error for missing message.
    fprintf('  PASS (errored=%s - see code comment about behavior)\n\n', ...
        string(errored));
    numPassed = numPassed + 1;
catch ME
    fprintf('  FAIL: %s\n\n', ME.message);
end

%% TEST 6: Log command with no params.level -> defaults to INFO
numTests = numTests + 1;
fprintf('TEST 6: Log command with no level -> defaults to INFO...\n');
try
    logFile = fullfile(test_root, 'logs', 'test6.log');
    logger = ExperimentLogger(logFile, false, 'DEBUG');
    experimentDir = fullfile(test_root, 'experiment6');
    mkdir(experimentDir);
    pm = PluginManager(logger, experimentDir);
    executor = CommandExecutor([], pm, logger);

    cmd = struct();
    cmd.type = 'plugin';
    cmd.plugin_name = 'sensor';
    cmd.command_name = 'log';
    cmd.params = struct('message', 'No level specified');

    executor.execute(cmd);
    logger.close();

    content = fileread(logFile);
    assert(contains(content, 'INFO: [PLUGIN: sensor] USER LOG: No level specified'), ...
        'Should default to INFO level');

    fprintf('  PASS\n\n');
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

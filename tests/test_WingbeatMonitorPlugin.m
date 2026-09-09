% TEST_WINGBEATMONITORPLUGIN  No-hardware test of WingbeatMonitorPlugin.
%
% Exercises extractConfig, the scan callback (voltage->Hz conversion,
% buffering), trimBuffer, getLatest, getTime, getDataForInterval,
% getPlotData, and the air-puffer config/validation/test-mode path, using
% synthetic scan data fed in via simulateScan() and puffer calls run in
% testMode via initializeForTest(), instead of a real DAQ session. Run as
% a script (not a function) so failures stop at the offending assertion
% and leave the workspace inspectable.
%
% Requires: WingbeatMonitorPlugin.m on the MATLAB path. Does NOT require
% the Data Acquisition Toolbox or any NI hardware/driver.

clear; clc;

% Minimal stand-in logger so this script has no other dependencies.
% WingbeatMonitorPlugin only ever calls logger.log(level, msg); a struct
% with a function-handle field satisfies that without needing the real
% ExperimentLogger class from the main codebase.
logger = struct('log', @(level, msg) fprintf('    [%s] %s\n', level, msg));

fprintf('--- Test 1: config resolution, WBF-only ---\n');
config = struct('device_id', 'cDAQ1Mod2', 'wbf_channel', 'ai3');
wb = WingbeatMonitorPlugin('wingbeat', config, logger);
status = wb.getStatus();
assert(status.scaleFactor == 100, 'Default scale factor should be 100');
assert(status.hasLmr == false && status.hasLeft == false && status.hasRight == false, ...
    'No optional channels should be flagged when none are configured');
assert(status.hasPuffer == false, 'No puffer should be flagged without puff_channel');
fprintf('  OK: defaults resolved correctly, no optional channels flagged\n\n');

fprintf('--- Test 2: config resolution, all channels + override ---\n');
config2 = struct( ...
    'device_id', 'cDAQ1Mod2', ...
    'wbf_channel', 'ai3', ...
    'lmr_channel', 'ai0', ...
    'left_channel', 'ai1', ...
    'right_channel', 'ai2', ...
    'wbf_scale_factor', 150, ...
    'sample_rate', 500, ...
    'buffer_duration', 10);
wb2 = WingbeatMonitorPlugin('wingbeat_full', config2, logger);
status2 = wb2.getStatus();
assert(status2.scaleFactor == 150, 'wbf_scale_factor override should take effect');
assert(status2.hasLmr && status2.hasLeft && status2.hasRight, ...
    'All three optional channels should be flagged when configured');
fprintf('  OK: overrides and optional-channel flags resolved correctly\n\n');

fprintf('--- Test 3: voltage->Hz conversion and getLatest ---\n');
wb2.initializeForTest();
% One scan, 4 channels in order [wbf, lmr, left, right]; WBF voltage of
% 1.5 V should become 1.5 * 150 = 225 Hz.
t = [0.0; 0.1; 0.2];
data = [1.5, 0.10, 0.60, 0.55; ...
        1.6, 0.11, 0.61, 0.54; ...
        1.7, 0.12, 0.62, 0.53];
wb2.simulateScan(t, data);
latest = wb2.execute('getLatest');
assert(abs(latest.hz - 1.7*150) < 1e-9, ...
    sprintf('Expected latest WBF = %.3f Hz, got %.3f', 1.7*150, latest.hz));
assert(abs(latest.t - 0.2) < 1e-9, 'Expected latest timestamp = 0.2s');
fprintf('  OK: latest WBF = %.1f Hz at t=%.2fs (expected %.1f Hz)\n\n', ...
    latest.hz, latest.t, 1.7*150);

fprintf('--- Test 4: getDataForInterval (WBF only) ---\n');
window = wb2.execute('getDataForInterval', struct('t_start', 0.05, 't_end', 0.15));
assert(numel(window.t) == 1 && abs(window.t(1) - 0.1) < 1e-9, ...
    'Expected exactly one sample at t=0.1 in [0.05, 0.15]');
assert(abs(window.values(1) - 1.6*150) < 1e-9, 'Windowed WBF value mismatch');
fprintf('  OK: interval query returned %d sample(s) as expected\n\n', numel(window.t));

fprintf('--- Test 5: getPlotData includes raw channels, unscaled ---\n');
plotData = wb2.execute('getPlotData', struct('t_start', 0, 't_end', 1));
assert(isfield(plotData, 'lmr') && isfield(plotData, 'left') && isfield(plotData, 'right'), ...
    'getPlotData should include lmr/left/right fields when configured');
assert(numel(plotData.wbf) == 3, 'Expected all 3 samples in the full window');
assert(abs(plotData.left(2) - 0.61) < 1e-9, 'left-channel value should be raw volts, unscaled');
fprintf('  OK: getPlotData returned %d samples with lmr/left/right present\n\n', numel(plotData.t));

fprintf('--- Test 6: WBF-only plugin has no optional fields in getPlotData ---\n');
wb.initializeForTest();
wb.simulateScan([0.0; 0.1], [1.0; 1.1]);
plotDataWbfOnly = wb.execute('getPlotData', struct('t_start', 0, 't_end', 1));
assert(~isfield(plotDataWbfOnly, 'lmr') && ~isfield(plotDataWbfOnly, 'left') && ~isfield(plotDataWbfOnly, 'right'), ...
    'getPlotData should omit lmr/left/right fields when not configured');
fprintf('  OK: unconfigured channels correctly absent from getPlotData\n\n');

fprintf('--- Test 7: trimBuffer drops samples older than buffer_duration ---\n');
config3 = struct('device_id', 'cDAQ1Mod2', 'wbf_channel', 'ai3', 'buffer_duration', 1);
wb3 = WingbeatMonitorPlugin('wingbeat_trim', config3, logger);
wb3.initializeForTest();
wb3.simulateScan([0.0; 0.5], [1.0; 1.0]);      % t = 0.0, 0.5
wb3.simulateScan([2.0; 2.5], [1.0; 1.0]);      % t = 2.0, 2.5 -> cutoff becomes 1.5
allData = wb3.execute('getDataForInterval', struct('t_start', -inf, 't_end', inf));
assert(numel(allData.t) == 2, ...
    sprintf('Expected 2 samples remaining after trim (buffer_duration=1s), got %d', numel(allData.t)));
assert(all(allData.t >= 1.5), 'Remaining samples should all be within buffer_duration of the latest sample');
fprintf('  OK: buffer correctly trimmed to %d sample(s) after exceeding buffer_duration\n\n', numel(allData.t));

fprintf('--- Test 8: getTime advances with wall clock ---\n');
t1 = wb.execute('getTime');
pause(0.2);
t2 = wb.execute('getTime');
assert(t2 > t1, 'getTime should increase between calls');
fprintf('  OK: getTime advanced by %.3fs over a 0.2s pause\n\n', t2 - t1);

fprintf('--- Test 9: puffer config resolution (defaults + overrides) ---\n');
config4 = struct('device_id', 'cDAQ1Mod2', 'wbf_channel', 'ai3', ...
    'puff_channel', 'port0/line0');
wb4 = WingbeatMonitorPlugin('wingbeat_puff', config4, logger);
status4 = wb4.getStatus();
assert(status4.hasPuffer == true, 'hasPuffer should be true when puff_channel is configured');
assert(abs(status4.puffDuration - 0.1) < 1e-9, 'Default puff_duration should be 0.1s');
assert(status4.puffActiveHigh == true, 'Default puff_active_high should be true');
fprintf('  OK: puffer defaults resolved (duration=0.1s, active_high=true)\n\n');

config5 = struct('device_id', 'cDAQ1Mod2', 'wbf_channel', 'ai3', ...
    'puff_channel', 'port0/line0', 'puff_duration', 0.25, 'puff_active_high', false);
wb5 = WingbeatMonitorPlugin('wingbeat_puff_custom', config5, logger);
status5 = wb5.getStatus();
assert(abs(status5.puffDuration - 0.25) < 1e-9, 'puff_duration override should take effect');
assert(status5.puffActiveHigh == false, 'puff_active_high override should take effect');
fprintf('  OK: puffer overrides (duration=0.25s, active_high=false) resolved correctly\n\n');

fprintf('--- Test 10: puff() without puff_channel configured should error ---\n');
% wb (Test 1/6/8) has no puff_channel configured.
threw = false;
try
    wb.execute('puff');
catch ME
    threw = true;
    assert(contains(ME.message, 'puff_channel'), ...
        'Error message should mention the missing puff_channel config');
end
assert(threw, 'execute(''puff'') should error when no puff_channel is configured');
fprintf('  OK: puff() correctly errors without a configured puff_channel\n\n');

fprintf('--- Test 11: puff() in test mode (no hardware) uses default and override duration ---\n');
wb4.initializeForTest();
wb4.execute('puff');                                    % should use default 0.1s, no error
wb4.execute('puff', struct('duration', 0.05));           % should use override, no error
fprintf('  OK: puff() ran in test mode with default and overridden duration, no hardware required\n\n');

fprintf('All tests passed.\n');

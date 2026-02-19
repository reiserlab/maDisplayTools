%% test_g41_experiment_patterns.m — Mode 2 playback test for G4.1 experiment patterns
%
% Simple test script: plays each pattern for 10 seconds at 10 fps (Mode 2).
% See also: run_lab_test('lab_test_g41_experiment.yaml') for YAML-driven version.
% Use after deploying patterns to SD card via prepare_g41_experiment_sd.m.
%
% SD card pattern mapping:
%   1.  sq_grating_30deg_gs2        — 16 frames
%   2.  sq_grating_30deg_gs16       — 16 frames
%   3.  sq_grating_60deg_gs2        — 32 frames
%   4.  sq_grating_60deg_gs16       — 32 frames
%   5.  sine_grating_30deg_gs16     — 16 frames
%   6.  sine_grating_60deg_gs16     — 32 frames
%   7.  sine_grating_30deg_fine_gs16 — 64 frames
%   8.  sine_grating_60deg_fine_gs16 — 128 frames
%   9.  counter_0000_1000_gs2       — 1001 frames
%   10. counter_0000_1000_gs16      — 1001 frames
%   11. luminance_levels_gs2        — 2 frames
%   12. luminance_levels_gs16       — 16 frames
%
% Usage:
%   1. Deploy patterns to SD card (see prepare_g41_experiment_sd.m)
%   2. Insert SD card into controller
%   3. Update ip_addr below
%   4. Run this script

%% Configuration
ip_addr = '10.102.40.209';  % *** UPDATE for your lab ***
fps = 10;                    % Frame rate for Mode 2
dur_sec = 10;                % Trial duration in seconds
pause_sec = 2;               % Pause between patterns

% Which patterns to test (SD card slot IDs)
% Default: all 12. Uncomment a subset for faster testing.
pat_ids = 1:12;
% pat_ids = [1 2 5 6 9 10 11 12];  % Quick subset

pat_names = {
    'sq_grating_30deg_gs2 (GS2, 16f)'
    'sq_grating_30deg_gs16 (GS16, 16f)'
    'sq_grating_60deg_gs2 (GS2, 32f)'
    'sq_grating_60deg_gs16 (GS16, 32f)'
    'sine_grating_30deg_gs16 (GS16, 16f)'
    'sine_grating_60deg_gs16 (GS16, 32f)'
    'sine_grating_30deg_fine_gs16 (GS16, 64f)'
    'sine_grating_60deg_fine_gs16 (GS16, 128f)'
    'counter_0000_1000_gs2 (GS2, 1001f)'
    'counter_0000_1000_gs16 (GS16, 1001f)'
    'luminance_levels_gs2 (GS2, 2f)'
    'luminance_levels_gs16 (GS16, 16f)'
};

%% Setup
cd(project_root());
addpath(genpath('.'));

fprintf('=== G4.1 Experiment Pattern Test (Mode 2) ===\n');
fprintf('IP: %s, FPS: %d, Duration: %d sec\n\n', ip_addr, fps, dur_sec);

%% Connect
pc = PanelsController(ip_addr);
pc.open(false);

% Quick sanity check
fprintf('Sanity check: allOn...');
pc.allOn(); pause(1);
pc.allOff(); pause(0.5);
fprintf(' OK\n\n');

%% Run each pattern
deciSec = dur_sec * 10;
results = cell(length(pat_ids), 1);

for i = 1:length(pat_ids)
    pid = pat_ids(i);
    fprintf('Test %2d/%2d: [SD %2d] %s\n', i, length(pat_ids), pid, pat_names{pid});

    try
        % Mode 2: constant rate playback, 10 fps, blocks until done
        success = pc.trialParams(2, pid, fps, 1, 0, deciSec, true);
        if success
            results{i} = 'PASS';
            fprintf('  PASS (completed %d sec)\n', dur_sec);
        else
            results{i} = 'FAIL (trialParams returned false)';
            fprintf('  FAIL (trialParams returned false)\n');
        end
    catch e
        results{i} = sprintf('ERROR: %s', e.message);
        fprintf('  ERROR: %s\n', e.message);
    end

    if i < length(pat_ids)
        pc.allOff();
        pause(pause_sec);
    end
end

%% Cleanup
pc.allOff();
pc.close();

%% Summary
fprintf('\n=== Results ===\n');
for i = 1:length(pat_ids)
    pid = pat_ids(i);
    fprintf('  [SD %2d] %-50s %s\n', pid, pat_names{pid}, results{i});
end
fprintf('\nDone.\n');

%% Lab checklist (print for manual verification)
fprintf('\n=== Lab Verification Checklist ===\n');
fprintf('[ ] Gratings: Bars move smoothly left-to-right?\n');
fprintf('[ ] 30° vs 60°: Wider bars for 60°?\n');
fprintf('[ ] GS2 vs GS16: GS16 gratings have visible ON/OFF only (no gray)?\n');
fprintf('[ ] Sine vs square: Sine has smooth brightness transitions?\n');
fprintf('[ ] Fine sine: Smoother motion than regular sine?\n');
fprintf('[ ] Counter GS2: Numbers visible, polarity alternates?\n');
fprintf('[ ] Counter GS16: Numbers visible, brightness ramps up/down?\n');
fprintf('[ ] Luminance GS2: One frame off, one frame on?\n');
fprintf('[ ] Luminance GS16: Brightness steps from black to full bright?\n');
fprintf('[ ] All panels active? No dead panels?\n');

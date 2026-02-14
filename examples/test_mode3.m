%% test_mode3.m — Mode 3 (Stream Pattern Position) lab test
%
% Self-contained test script for validating Mode 3 on the G4.1 arena.
% Run this in the lab after verifying that Mode 2 playback works.
%
% Prerequisites:
%   - SD card prepared with create_lab_test_patterns.m + prepare_sd_card.m
%   - Arena powered and connected
%   - Mode 2 playback verified (patterns display correctly)
%
% Pattern IDs used (from create_lab_test_patterns.m):
%   6 = Multi-frame digits (GS16, 16 frames) — for stepping/jump tests
%   7 = Multi-frame digits (GS2, 16 frames) — for GS2 stepping test
%   8 = Sine grating (GS16, 16 frames) — for smooth motion/timing test
%
% Uses trialParams() for all controller commands.

%% Configuration
ip_addr = '10.102.40.61';
pat_digits_gs16 = 6;  % Multi-frame number digits (GS16)
pat_digits_gs2 = 7;   % Multi-frame number digits (GS2)
pat_sine = 8;         % Sine grating for smooth motion
num_frames = 16;      % All test patterns have 16 frames

fprintf('=== Mode 3 Test Suite ===\n');
fprintf('Arena IP: %s\n\n', ip_addr);

%% Connect
fprintf('Test 1: Connection\n');
pc = PanelsController(ip_addr);
pc.open(false);
pc.allOn(); pause(1);
pc.allOff(); pause(0.5);
fprintf('  PASS: Connected and verified\n\n');

%% Test 2: Basic Mode 3 — display a single frame
fprintf('Test 2: Basic Mode 3 — single frame display\n');
fprintf('  Starting mode 3 with digit pattern, frame 1...\n');
pc.trialParams(3, pat_digits_gs16, 0, 1, 0, 100, false);  % 10 sec
pause(2);
fprintf('  Jumping to frame 8...\n');
pc.setPositionX(8);
pause(2);
fprintf('  Jumping to frame 1...\n');
pc.setPositionX(1);
pause(2);
pc.stopDisplay();
fprintf('  DONE — Did you see the pattern change between frames?\n');
fprintf('  Press any key to continue...\n');
pause;
fprintf('\n');

%% Test 3: Frame-by-frame stepping (manual)
fprintf('Test 3: Frame-by-frame stepping (manual)\n');
fprintf('  Press any key to advance to each frame.\n');
fprintf('  Verify the displayed pattern matches the frame number.\n\n');
pc.trialParams(3, pat_digits_gs16, 0, 1, 0, 600, false);  % 60 sec
for f = 1:num_frames
    pc.setPositionX(f);
    fprintf('  Frame %2d/%d — press any key\n', f, num_frames);
    pause;
end
pc.stopDisplay();
fprintf('  DONE\n\n');

%% Test 4: Jump test (non-sequential frames)
fprintf('Test 4: Non-sequential frame jumps\n');
fprintf('  Jumping to arbitrary frames. Verify correct display.\n\n');
jump_sequence = [1, 8, 16, 4, 12, 1, 16, 1];
pc.trialParams(3, pat_digits_gs16, 0, 1, 0, 300, false);  % 30 sec
for j = 1:length(jump_sequence)
    target = jump_sequence(j);
    pc.setPositionX(target);
    fprintf('  Jumped to frame %2d — press any key\n', target);
    pause;
end
pc.stopDisplay();
fprintf('  DONE\n\n');

%% Test 5: GS2 mode 3 stepping
fprintf('Test 5: Mode 3 with GS2 pattern\n');
fprintf('  Same stepping test but with binary (GS2) pattern.\n\n');
pc.trialParams(3, pat_digits_gs2, 0, 1, 0, 300, false);
for f = [1, 4, 8, 12, 16]
    pc.setPositionX(f);
    fprintf('  Frame %2d — press any key\n', f);
    pause;
end
pc.stopDisplay();
fprintf('  DONE\n\n');

%% Test 6: Timing — streaming at various rates
fprintf('Test 6: Position streaming timing\n');
fprintf('  Testing streaming rates. Watch for smooth motion.\n\n');

rates = [10, 20, 50];
for r = 1:length(rates)
    target_hz = rates(r);
    dur_sec = 5;
    num_updates = target_hz * dur_sec;

    fprintf('  Testing %d Hz (%d updates over %d sec)...\n', target_hz, num_updates, dur_sec);
    pc.trialParams(3, pat_sine, 0, 1, 0, (dur_sec + 2) * 10, false);
    pause(0.2);  % Let controller settle

    t0 = tic;
    for i = 1:num_updates
        frameIdx = mod(i - 1, num_frames) + 1;
        pc.setPositionX(frameIdx);
        pause(1 / target_hz);
    end
    elapsed = toc(t0);
    actual_hz = num_updates / elapsed;

    pc.stopDisplay();
    fprintf('    Target: %d Hz, Actual: %.1f Hz (%.0f%% achieved)\n', ...
        target_hz, actual_hz, 100 * actual_hz / target_hz);

    pause(0.5);
end
fprintf('  DONE\n\n');

%% Test 7: Rapid back-and-forth (stress test)
fprintf('Test 7: Rapid back-and-forth stress test\n');
fprintf('  Alternating between frame 1 and frame 9 at 50 Hz for 3 sec.\n');
fprintf('  Should see rapid flicker between two distinct frames.\n\n');

pc.trialParams(3, pat_digits_gs16, 0, 1, 0, 50, false);
t0 = tic;
while toc(t0) < 3
    pc.setPositionX(1);
    pause(0.01);
    pc.setPositionX(9);
    pause(0.01);
end
pc.stopDisplay();
fprintf('  DONE — Did you see rapid alternation?\n');
fprintf('  Press any key to continue...\n');
pause;
fprintf('\n');

%% Cleanup
pc.allOff();
pc.close();

fprintf('=== Mode 3 Test Suite Complete ===\n');
fprintf('Record your observations:\n');
fprintf('  Test 2 (basic):     [PASS/FAIL]\n');
fprintf('  Test 3 (stepping):  [PASS/FAIL]\n');
fprintf('  Test 4 (jumping):   [PASS/FAIL]\n');
fprintf('  Test 5 (GS2):       [PASS/FAIL]\n');
fprintf('  Test 6 (timing):    Max reliable rate = _____ Hz\n');
fprintf('  Test 7 (stress):    [PASS/FAIL]\n');

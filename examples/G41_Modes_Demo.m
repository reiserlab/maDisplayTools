%% G41_Modes_Demo.m — Demo of trial modes 2, 3, and 4
%
% Demonstrates pattern playback using trialParams() for a G4.1 arena.
% Requires patterns loaded on the SD card (use prepare_sd_card.m).
%
% Modes:
%   2 — Constant Rate Playback (auto-advance frames at fps)
%   3 — Stream Pattern Position (MATLAB controls which frame is displayed)
%   4 — Closed Loop: ADC (analog input controls frame position)
%
% trialParams(controlMode, patternID, fps, initPos, gain, deciSeconds, waitForEnd)
%   controlMode: 0-7
%   patternID:   pattern slot on SD card (1-indexed)
%   fps:         frame rate (signed; negative = reverse direction)
%   initPos:     initial frame position (signed)
%   gain:        gain for closed-loop modes (0 for modes 2-3)
%   deciSeconds: trial duration in 0.1 s units
%   waitForEnd:  true = block until done, false = return immediately

%% Configuration
ip_addr = '10.102.40.209';  % Arena IP address
patIDs = [1 2 3 4 5];          % Pattern IDs to cycle through
mode = 2;                  % Default mode (change to 3 or 4 to test)
fps = 10;                  % Frame rate (mode 2 only)
initPos = 1;               % Starting frame
gain = 0;                  % Gain (mode 4 only)
dur_sec = 5;               % Trial duration in seconds

%% Connect
pc = PanelsController(ip_addr);
pc.open(false);

%% Sanity check
pc.allOn(); pause(1);
pc.allOff(); pause(0.5);
fprintf('Connection verified.\n');

%% Run trials
for i = 1:length(patIDs)
    patID = patIDs(i);
    fprintf('Trial %d: mode=%d, patID=%d, fps=%d, dur=%ds\n', ...
        i, mode, patID, fps, dur_sec);

    switch mode
        case 2
            % Constant Rate Playback — controller advances frames at fps
            % waitForEnd=true: blocks until controller signals completion
            success = pc.trialParams(2, patID, fps, initPos, 0, 50, true);
            fprintf('  Result: %s\n', string(success));

        case 3
            % Stream Pattern Position — MATLAB controls frame position
            % Use waitForEnd=false so we can send position updates
            pc.trialParams(3, patID, 0, initPos, 0, dur_sec * 10, false);
            % Stream frames at ~10 Hz for the trial duration
            for f = 1:(fps * dur_sec)
                frameIdx = mod(f - 1, 16) + 1;
                pc.setPositionX(frameIdx);
                pause(1 / fps);
            end
            pc.stopDisplay();

        case 4
            % Closed Loop: ADC — analog input controls frame position
            success = pc.trialParams(4, patID, fps, initPos, gain, dur_sec * 10, true);
            fprintf('  Result: %s\n', string(success));
    end

    pause(0.5);  % Brief pause between trials
end

%% Cleanup
pc.allOff();
pc.close();
fprintf('Demo complete.\n');

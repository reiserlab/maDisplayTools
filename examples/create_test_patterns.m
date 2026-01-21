% CREATE_TEST_PATTERNS.m
% Creates two sets of test patterns for a 2-row x 12-col arena (32x192 pixels)
% All patterns are binary (gs_val = 2)
%
% Set 1: Numbers 0-9 (each number fills display, 16 frames for horizontal scrolling)
% Set 2: Gratings at 10 spatial frequencies (asymmetric duty cycle for motion)

%% Setup
rows = 32;   % 2 panel rows × 16 pixels
cols = 192;  % 12 panel cols × 16 pixels
frames = 16; % 16 frames for periodicity
gs_val = 2;  % Binary

save_dir = fullfile(pwd, 'test_patterns');
if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

%% Define 8x8 digit bitmaps (0-9)
% Each digit is an 8x8 binary pattern
digits = zeros(8, 8, 10, 'uint8');

% 0
digits(:,:,1) = [
    0 0 1 1 1 1 0 0
    0 1 1 0 0 1 1 0
    0 1 1 0 0 1 1 0
    0 1 1 0 0 1 1 0
    0 1 1 0 0 1 1 0
    0 1 1 0 0 1 1 0
    0 1 1 0 0 1 1 0
    0 0 1 1 1 1 0 0
];

% 1
digits(:,:,2) = [
    0 0 0 1 1 0 0 0
    0 0 1 1 1 0 0 0
    0 1 1 1 1 0 0 0
    0 0 0 1 1 0 0 0
    0 0 0 1 1 0 0 0
    0 0 0 1 1 0 0 0
    0 0 0 1 1 0 0 0
    0 1 1 1 1 1 1 0
];

% 2
digits(:,:,3) = [
    0 0 1 1 1 1 0 0
    0 1 1 0 0 1 1 0
    0 0 0 0 0 1 1 0
    0 0 0 0 1 1 0 0
    0 0 0 1 1 0 0 0
    0 0 1 1 0 0 0 0
    0 1 1 0 0 0 0 0
    0 1 1 1 1 1 1 0
];

% 3
digits(:,:,4) = [
    0 0 1 1 1 1 0 0
    0 1 1 0 0 1 1 0
    0 0 0 0 0 1 1 0
    0 0 0 1 1 1 0 0
    0 0 0 0 0 1 1 0
    0 0 0 0 0 1 1 0
    0 1 1 0 0 1 1 0
    0 0 1 1 1 1 0 0
];

% 4
digits(:,:,5) = [
    0 0 0 0 1 1 0 0
    0 0 0 1 1 1 0 0
    0 0 1 1 1 1 0 0
    0 1 1 0 1 1 0 0
    0 1 1 1 1 1 1 0
    0 0 0 0 1 1 0 0
    0 0 0 0 1 1 0 0
    0 0 0 0 1 1 0 0
];

% 5
digits(:,:,6) = [
    0 1 1 1 1 1 1 0
    0 1 1 0 0 0 0 0
    0 1 1 0 0 0 0 0
    0 1 1 1 1 1 0 0
    0 0 0 0 0 1 1 0
    0 0 0 0 0 1 1 0
    0 1 1 0 0 1 1 0
    0 0 1 1 1 1 0 0
];

% 6
digits(:,:,7) = [
    0 0 1 1 1 1 0 0
    0 1 1 0 0 0 0 0
    0 1 1 0 0 0 0 0
    0 1 1 1 1 1 0 0
    0 1 1 0 0 1 1 0
    0 1 1 0 0 1 1 0
    0 1 1 0 0 1 1 0
    0 0 1 1 1 1 0 0
];

% 7
digits(:,:,8) = [
    0 1 1 1 1 1 1 0
    0 0 0 0 0 1 1 0
    0 0 0 0 1 1 0 0
    0 0 0 0 1 1 0 0
    0 0 0 1 1 0 0 0
    0 0 0 1 1 0 0 0
    0 0 0 1 1 0 0 0
    0 0 0 1 1 0 0 0
];

% 8
digits(:,:,9) = [
    0 0 1 1 1 1 0 0
    0 1 1 0 0 1 1 0
    0 1 1 0 0 1 1 0
    0 0 1 1 1 1 0 0
    0 1 1 0 0 1 1 0
    0 1 1 0 0 1 1 0
    0 1 1 0 0 1 1 0
    0 0 1 1 1 1 0 0
];

% 9
digits(:,:,10) = [
    0 0 1 1 1 1 0 0
    0 1 1 0 0 1 1 0
    0 1 1 0 0 1 1 0
    0 0 1 1 1 1 1 0
    0 0 0 0 0 1 1 0
    0 0 0 0 0 1 1 0
    0 1 1 0 0 1 1 0
    0 0 1 1 1 1 0 0
];

%% SET 1: Number patterns (0-9)
fprintf('\n=== Creating Set 1: Number Patterns ===\n');

for d = 0:9
    % Get the 8x8 digit bitmap
    digit_8x8 = digits(:,:,d+1);
    
    % Scale to 16x16 by doubling each pixel
    digit_16x16 = zeros(16, 16, 'uint8');
    for r = 1:8
        for c = 1:8
            digit_16x16((r-1)*2+1:r*2, (c-1)*2+1:c*2) = digit_8x8(r, c);
        end
    end
    
    % Create base frame: tile the digit across all 12 panels (2 rows of panels)
    base_frame = zeros(rows, cols, 'uint8');
    for panel_row = 0:1
        for panel_col = 0:11
            r_start = panel_row * 16 + 1;
            c_start = panel_col * 16 + 1;
            base_frame(r_start:r_start+15, c_start:c_start+15) = digit_16x16;
        end
    end
    
    % Create 16 frames by shifting horizontally (1 pixel per frame)
    Pats = zeros(rows, cols, frames, 1, 'uint8');
    for f = 1:frames
        Pats(:,:,f,1) = circshift(base_frame, [0, f-1]);
    end
    
    % Save pattern
    patName = sprintf('num%d_2x12', d);
    stretch = ones(frames, 1, 'uint8');
    maDisplayTools.generate_pattern_from_array(Pats, save_dir, patName, gs_val, stretch, 0);
    fprintf('Created: %s (%d frames)\n', patName, frames);
end

%% SET 2: Grating patterns (10 spatial frequencies)
fprintf('\n=== Creating Set 2: Grating Patterns ===\n');

% Spatial frequencies: bar widths from wide to narrow
% Using 2:1 duty cycle (2 pixels ON, 1 pixel OFF) for asymmetry
% Wavelengths (pixels per cycle): 48, 36, 24, 18, 12, 9, 6, 5, 4, 3
wavelengths = [48, 36, 24, 18, 12, 9, 6, 5, 4, 3];

for idx = 1:10
    wl = wavelengths(idx);
    
    % Asymmetric duty cycle: ~67% ON, ~33% OFF
    on_width = ceil(wl * 2/3);
    off_width = wl - on_width;
    
    % Create one row of the grating pattern
    grating_row = zeros(1, cols, 'uint8');
    pos = 1;
    while pos <= cols
        % ON pixels
        end_on = min(pos + on_width - 1, cols);
        grating_row(pos:end_on) = 1;
        pos = end_on + 1;
        
        % OFF pixels
        if pos <= cols
            end_off = min(pos + off_width - 1, cols);
            grating_row(pos:end_off) = 0;
            pos = end_off + 1;
        end
    end
    
    % Tile vertically
    base_frame = repmat(grating_row, rows, 1);
    
    % Create frames by shifting horizontally
    % Use wavelength as frame count for smooth looping, capped at 48
    num_frames = min(wl, 48);
    shift_per_frame = max(1, floor(wl / num_frames));
    
    Pats = zeros(rows, cols, num_frames, 1, 'uint8');
    for f = 1:num_frames
        Pats(:,:,f,1) = circshift(base_frame, [0, (f-1) * shift_per_frame]);
    end
    
    % Save pattern
    patName = sprintf('grating_wl%02d_2x12', wl);
    stretch = ones(num_frames, 1, 'uint8');
    maDisplayTools.generate_pattern_from_array(Pats, save_dir, patName, gs_val, stretch, 0);
    fprintf('Created: %s (wavelength=%d px, %d frames)\n', patName, wl, num_frames);
end

%% Summary
fprintf('\n=== Done! ===\n');
fprintf('Created 20 patterns in: %s\n', save_dir);
fprintf('  - 10 number patterns (num0-num9)\n');
fprintf('  - 10 grating patterns (wavelengths: %s)\n', mat2str(wavelengths));

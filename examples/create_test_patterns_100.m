% CREATE_TEST_PATTERNS_100.m
% Creates 100 number patterns (00-99) for a 2-row x 12-col arena (32x192 pixels)
% All patterns are binary (gs_val = 2)
%
% Uses smaller 4x6 digit font to fit two digits per 16x16 panel

%% Setup
rows = 32;   % 2 panel rows × 16 pixels
cols = 192;  % 12 panel cols × 16 pixels
frames = 16; % 16 frames for periodicity
gs_val = 2;  % Binary

save_dir = fullfile(pwd, 'test_patterns_100');
if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

%% Define 4x6 digit bitmaps (0-9) - small font
% Each digit is 4 wide x 6 tall
digits = zeros(6, 4, 10, 'uint8');

% 0
digits(:,:,1) = [
    0 1 1 0
    1 0 0 1
    1 0 0 1
    1 0 0 1
    1 0 0 1
    0 1 1 0
];

% 1
digits(:,:,2) = [
    0 0 1 0
    0 1 1 0
    0 0 1 0
    0 0 1 0
    0 0 1 0
    0 1 1 1
];

% 2
digits(:,:,3) = [
    0 1 1 0
    1 0 0 1
    0 0 0 1
    0 0 1 0
    0 1 0 0
    1 1 1 1
];

% 3
digits(:,:,4) = [
    0 1 1 0
    1 0 0 1
    0 0 1 0
    0 0 0 1
    1 0 0 1
    0 1 1 0
];

% 4
digits(:,:,5) = [
    0 0 1 0
    0 1 1 0
    1 0 1 0
    1 1 1 1
    0 0 1 0
    0 0 1 0
];

% 5
digits(:,:,6) = [
    1 1 1 1
    1 0 0 0
    1 1 1 0
    0 0 0 1
    1 0 0 1
    0 1 1 0
];

% 6
digits(:,:,7) = [
    0 1 1 0
    1 0 0 0
    1 1 1 0
    1 0 0 1
    1 0 0 1
    0 1 1 0
];

% 7
digits(:,:,8) = [
    1 1 1 1
    0 0 0 1
    0 0 1 0
    0 0 1 0
    0 1 0 0
    0 1 0 0
];

% 8
digits(:,:,9) = [
    0 1 1 0
    1 0 0 1
    0 1 1 0
    1 0 0 1
    1 0 0 1
    0 1 1 0
];

% 9
digits(:,:,10) = [
    0 1 1 0
    1 0 0 1
    1 0 0 1
    0 1 1 1
    0 0 0 1
    0 1 1 0
];

%% Helper function to create two-digit image for a panel
% Creates a 16x16 image with two digits centered
    function panel_img = make_two_digit_panel(tens, ones, digit_font)
        panel_img = zeros(16, 16, 'uint8');
        
        % Get digit bitmaps (6 rows x 4 cols each)
        d1 = digit_font(:,:,tens+1);  % tens digit
        d2 = digit_font(:,:,ones+1);  % ones digit
        
        % Place digits with 1 pixel gap between them
        % Total width: 4 + 1 + 4 = 9 pixels, centered in 16 = start at col 4
        % Total height: 6 pixels, centered in 16 = start at row 6
        row_start = 6;
        col_start = 4;
        
        % Tens digit
        panel_img(row_start:row_start+5, col_start:col_start+3) = d1;
        
        % Ones digit (with 1 pixel gap)
        panel_img(row_start:row_start+5, col_start+5:col_start+8) = d2;
    end

%% Create 100 number patterns (00-99)
fprintf('\n=== Creating 100 Number Patterns (00-99) ===\n');

for num = 0:99
    tens_digit = floor(num / 10);
    ones_digit = mod(num, 10);
    
    % Create 16x16 panel with two digits
    panel_16x16 = make_two_digit_panel(tens_digit, ones_digit, digits);
    
    % Tile across all 12 panels (2 rows of panels)
    base_frame = zeros(rows, cols, 'uint8');
    for panel_row = 0:1
        for panel_col = 0:11
            r_start = panel_row * 16 + 1;
            c_start = panel_col * 16 + 1;
            base_frame(r_start:r_start+15, c_start:c_start+15) = panel_16x16;
        end
    end
    
    % Create 16 frames by shifting horizontally (1 pixel per frame)
    Pats = zeros(rows, cols, frames, 1, 'uint8');
    for f = 1:frames
        Pats(:,:,f,1) = circshift(base_frame, [0, f-1]);
    end
    
    % Save pattern
    patName = sprintf('pat%04d_num%02d_2x12', num+1, num);
    stretch = ones(frames, 1, 'uint8');
    maDisplayTools.generate_pattern_from_array(Pats, save_dir, patName, gs_val, stretch, 0);
    
    if mod(num, 10) == 0
        fprintf('Created: %s ... \n', patName);
    end
end

%% Summary
fprintf('\n=== Done! ===\n');
fprintf('Created 100 patterns in: %s\n', save_dir);
fprintf('  - pat0001_num00_2x12.pat through pat0100_num99_2x12.pat\n');
fprintf('  - Each pattern: %dx%d pixels, %d frames\n', rows, cols, frames);

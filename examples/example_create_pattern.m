% EXAMPLE_CREATE_PATTERN.m
% Example script demonstrating how to create patterns using the pattern
% generation functions. This creates a 3D grating pattern that shifts
% horizontally across frames.

%% Define pattern dimensions
rows = 64;  % 48 for 3 row arena, 64 for 4 row arena
cols = 192;
pix_per_panel = 16;
frames = 24;

%% Create the pattern array
% This example creates a vertical grating that shifts horizontally

% Create the base pattern for one row of a single frame
pattern_row = zeros(1, cols, 'uint8');
for i = 0:(cols/pix_per_panel - 1)
    if mod(i, 2) == 0
        val = 1;
    else
        val = 0;
    end
    pattern_row((i*pix_per_panel + 1):(i*pix_per_panel + pix_per_panel)) = val;
end

% Initialize the full 3D array
pattern_array_3d = zeros(rows, cols, frames, 'uint8');

% Create each frame by circularly shifting the previous frame
for f = 1:frames
    shifted_row = circshift(pattern_row, f-1);
    pattern_array_3d(:, :, f) = repmat(shifted_row, rows, 1);
end

% Expand to 4D by adding a singleton dimension (4D not yet fully implemented)
Pats = reshape(pattern_array_3d, [rows, cols, frames, 1]);

%% Set up parameters
save_dir = pwd;
patName = '4row_gs2_sqGrate';
gs_val = 2;   %       2  = Binary pattern (1 bit per pixel, values 0-1)
            %       16 = Grayscale pattern (4 bits per pixel, values 0-15)          
stretch = ones(frames, 1, 'uint8');
arena_pitch = 0;

%% Generate and save the pattern
maDisplayTools.generate_pattern_from_array(Pats, save_dir, patName, gs_val, stretch, arena_pitch);

fprintf('\nPattern created successfully!\n');
fprintf('Dimensions: %d rows x %d cols x %d frames\n', rows, cols, frames);

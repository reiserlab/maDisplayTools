function save_pattern(Pats, param, save_dir, filename, Pats2, arena_file)
% SAVE_PATTERN Save pattern to .mat and .pat files (multi-generation support)
%
% Saves the Pats variable to both .mat and .pat files, the former of which
% can be easily read back into Matlab and the latter a binary file which is
% used to display the pattern on the LED arena.
%
% Supports G3, G4, G4.1, and G6 generations. Generation is determined from
% param.generation if present, otherwise defaults to G4 behavior.
%
% Inputs:
%   Pats       - Array of brightness values for each pixel in the arena
%   param      - Full parameters struct with fields:
%                  .gs_val     - Grayscale value (1 or 4 for G4, 2 or 16 for G6)
%                  .stretch    - Stretch values per frame
%                  .generation - (optional) 'G3', 'G4', 'G4.1', or 'G6'
%   save_dir   - Directory to store the pattern files
%   filename   - Desired base name for the pattern file
%   Pats2      - (optional) For checkerboard layouts
%   arena_file - (optional) Arena parameters file path
%
% Outputs:
%   G4/G3: Creates two files:
%     - [filename]_[GEN].mat  (MATLAB structure with metadata)
%     - [filename]_[GEN].pat  (Binary pattern file for controller)
%   G6: Creates one file:
%     - [filename]_G6.pat     (Binary pattern file with embedded metadata)

% Determine generation
if isfield(param, 'generation')
    generation = upper(strrep(param.generation, '.', ''));
else
    generation = 'G4';  % Default for backward compatibility
end

% Rearrange pattern if using checkerboard layout
if isfield(param,'checker_layout')
    if param.checker_layout==1
        if nargin<5 || isempty(Pats2)
            Pats2 = Pats;
        end
        if nargin >= 6 && ~isempty(arena_file)
            Pats = checkerboard_pattern(Pats, Pats2, arena_file);
        else
            Pats = checkerboard_pattern(Pats, Pats2);
        end
    end
else
    param.checker_layout = 0;
end

% Create save directory if it doesn't exist
if ~exist(save_dir,'dir')
    mkdir(save_dir)
end

% Route to appropriate save method based on generation
switch generation
    case 'G6'
        save_pattern_g6(Pats, param, save_dir, filename);
    otherwise
        % G3, G4, G4.1 all use the same G4 binary format
        save_pattern_g4(Pats, param, save_dir, filename, generation);
end

end

%% G4/G3/G4.1 Save Function (original format)
function save_pattern_g4(Pats, param, save_dir, filename, generation)
% Save pattern in G4 binary format (works for G3, G4, G4.1)

pattern.Pats = Pats;
pattern.x_num = size(Pats, 3);
pattern.y_num = size(Pats, 4);
if pattern.y_num == 0
    pattern.y_num = 1;
end

% Convert gs_val from Pattern Generator convention (1=binary, 4=grayscale)
% to maDisplayTools convention (2=binary, 16=grayscale)
if param.gs_val == 1
    pattern.gs_val = 2;   % Binary
elseif param.gs_val == 4
    pattern.gs_val = 16;  % Grayscale
else
    pattern.gs_val = param.gs_val;  % Pass through if already in correct format
end

pattern.stretch = param.stretch;
pattern.param = param;

% Get the vector data for each pattern using maDisplayTools
pattern.data = maDisplayTools.make_pattern_vector_g4(pattern);

% Create file name strings
gen_suffix = generation;
if strcmp(gen_suffix, 'G41')
    gen_suffix = 'G4';  % G4.1 uses same suffix as G4
end
matFileName = fullfile(save_dir, sprintf('%s_%s.mat', filename, gen_suffix));
if exist(matFileName,'file')
    error('Pattern .mat file already exists in save folder with that name: %s', matFileName)
end
patFileName = fullfile(save_dir, sprintf('%s_%s.pat', filename, gen_suffix));
if exist(patFileName,'file')
    error('Pattern .pat file already exists in save folder with that name: %s', patFileName)
end

% Save pattern .mat file
save(matFileName, 'pattern');
fprintf('Saved: %s\n', matFileName);

% Save the corresponding binary pat file
fileID = fopen(patFileName, 'w');
fwrite(fileID, pattern.data);
fclose(fileID);
fprintf('Saved: %s\n', patFileName);

end

%% G6 Save Function
function save_pattern_g6(Pats, param, save_dir, filename)
% Save pattern in G6 binary format (.pat file only)
%
% Note: G6 saves only .pat binary files (no .mat). The .pat format includes
% all necessary metadata in its header. This differs from G4 which saves
% both .mat and .pat for backwards compatibility with existing tooling.

% Determine grayscale mode
if param.gs_val == 1
    gs_val_internal = 1;  % GS2
elseif param.gs_val == 4
    gs_val_internal = 2;  % GS16
else
    % Direct mode specification
    if param.gs_val == 2
        gs_val_internal = 1;  % GS2
    else
        gs_val_internal = 2;  % GS16
    end
end

% Build pattern structure (for binary encoding)
[total_rows, total_cols, num_frames] = size(Pats);

% Calculate row/col counts from pixel dimensions
pixels_per_panel = 20;  % G6 is always 20x20
row_count = total_rows / pixels_per_panel;
col_count = total_cols / pixels_per_panel;

stretch = uint8(param.stretch(:));

% Check for existing .pat file
patFileName = fullfile(save_dir, sprintf('%s_G6.pat', filename));
if exist(patFileName,'file')
    error('Pattern .pat file already exists: %s', patFileName)
end

% Build and save binary data
data = build_g6_binary(Pats, stretch, row_count, col_count, gs_val_internal);

% Save binary file
fileID = fopen(patFileName, 'w');
fwrite(fileID, data, 'uint8');
fclose(fileID);
fprintf('Saved: %s\n', patFileName);

end

%% G6 Binary Builder
function data = build_g6_binary(Pats, stretch, row_count, col_count, gs_val)
% Build G6 binary pattern data
%
% gs_val: 1 = GS2 (binary), 2 = GS16 (grayscale)

num_frames = size(Pats, 3);
num_panels = row_count * col_count;

% Determine mode string for g6_encode_panel
if gs_val == 1
    mode = 'GS2';
    panel_bytes = 53;   % g6_encode_panel returns 53 bytes for GS2
else
    mode = 'GS16';
    panel_bytes = 203;  % g6_encode_panel returns 203 bytes for GS16
end

% Header: 4 bytes
% [gs_val (1 byte), num_frames_low (1 byte), num_frames_high (1 byte), reserved (1 byte)]
header = uint8([gs_val, mod(num_frames, 256), floor(num_frames / 256), 0]);

% Pre-allocate data (header + frames)
% Each frame has (panel_bytes * num_panels) bytes
% Note: stretch is embedded in g6_encode_panel output, not separate
frame_bytes = num_panels * panel_bytes;
total_bytes = 4 + num_frames * frame_bytes;
data = zeros(total_bytes, 1, 'uint8');

% Write header
data(1:4) = header;
offset = 5;

% Write each frame
for f = 1:num_frames
    frame_data = Pats(:, :, f);
    frame_stretch = stretch(f);

    % Encode each panel
    for pr = 0:(row_count-1)
        for pc = 0:(col_count-1)
            % Extract panel pixels (20x20)
            row_start = pr * 20 + 1;
            row_end = row_start + 19;
            col_start = pc * 20 + 1;
            col_end = col_start + 19;

            panel_pixels = frame_data(row_start:row_end, col_start:col_end);

            % Encode panel with stretch and mode
            panel_data = g6_encode_panel(panel_pixels, frame_stretch, mode);

            % Write to data array
            data(offset:offset+panel_bytes-1) = panel_data;
            offset = offset + panel_bytes;
        end
    end
end

end

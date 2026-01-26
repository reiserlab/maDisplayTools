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
%                  .ID         - Pattern ID number
%                  .generation - (optional) 'G3', 'G4', 'G4.1', or 'G6'
%   save_dir   - Directory to store the pattern files
%   filename   - Desired name for the pattern file
%   Pats2      - (optional) For checkerboard layouts
%   arena_file - (optional) Arena parameters file path
%
% Outputs:
%   Creates two files:
%     - [ID]_[filename]_[GEN].mat  (MATLAB structure with metadata)
%     - pat[ID].pat                (Binary pattern file for controller)

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
pattern.gs_val = param.gs_val;
pattern.stretch = param.stretch;
pattern.param = param;

% Get the vector data for each pattern
if exist('make_pattern_vector_g4','file')
    pattern.data = make_pattern_vector_g4(pattern);
    has_binary = true;
else
    warning('save_pattern:noBinary', ...
        'Could not save binary .pat file; missing make_pattern_vector_g4 from PControl');
    has_binary = false;
end

% Create file name strings
gen_suffix = generation;
if strcmp(gen_suffix, 'G41')
    gen_suffix = 'G4';  % G4.1 uses same suffix as G4
end
matFileName = fullfile(save_dir, sprintf('%04d_%s_%s.mat', param.ID, filename, gen_suffix));
if exist(matFileName,'file')
    error('Pattern .mat file already exists in save folder with that name: %s', matFileName)
end
patFileName = fullfile(save_dir, sprintf('pat%04d.pat', param.ID));
if exist(patFileName,'file')
    error('Pattern .pat file already exists in save folder with that name: %s', patFileName)
end

% Save pattern .mat file
save(matFileName, 'pattern');
fprintf('Saved: %s\n', matFileName);

% Save the corresponding binary pat file
if has_binary
    fileID = fopen(patFileName,'w');
    fwrite(fileID, pattern.data);
    fclose(fileID);
    fprintf('Saved: %s\n', patFileName);
end

end

%% G6 Save Function
function save_pattern_g6(Pats, param, save_dir, filename)
% Save pattern in G6 binary format

% Determine grayscale mode
if param.gs_val == 1
    mode = 'GS2';
    gs_val_internal = 1;
elseif param.gs_val == 4
    mode = 'GS16';
    gs_val_internal = 2;
else
    % Direct mode specification
    if param.gs_val == 2
        mode = 'GS2';
        gs_val_internal = 1;
    else
        mode = 'GS16';
        gs_val_internal = 2;
    end
end

% Build pattern structure
[total_rows, total_cols, num_frames] = size(Pats);

% Calculate row/col counts from pixel dimensions
pixels_per_panel = 20;  % G6 is always 20x20
row_count = total_rows / pixels_per_panel;
col_count = total_cols / pixels_per_panel;

pattern = struct();
pattern.Pats = Pats;
pattern.num_frames = num_frames;
pattern.version = 1;
pattern.row_count = row_count;
pattern.col_count = col_count;
pattern.gs_val = gs_val_internal;
pattern.stretch = uint8(param.stretch(:));
pattern.param = param;

% File names
matFileName = fullfile(save_dir, sprintf('%04d_%s_G6.mat', param.ID, filename));
if exist(matFileName,'file')
    error('Pattern .mat file already exists: %s', matFileName)
end
patFileName = fullfile(save_dir, sprintf('pat%04d.pat', param.ID));
if exist(patFileName,'file')
    error('Pattern .pat file already exists: %s', patFileName)
end

% Save .mat file
save(matFileName, 'pattern');
fprintf('Saved: %s\n', matFileName);

% Build binary data
% Check if g6_encode_panel exists (from maDisplayTools g6 module)
if exist('g6_encode_panel', 'file')
    % Use G6 encoding
    data = build_g6_binary(Pats, pattern.stretch, row_count, col_count, gs_val_internal);

    % Save binary file
    fileID = fopen(patFileName, 'w');
    fwrite(fileID, data, 'uint8');
    fclose(fileID);
    fprintf('Saved: %s\n', patFileName);
else
    warning('save_pattern:noG6Encoder', ...
        'Could not save G6 binary .pat file; g6_encode_panel not found. Add g6/ to path.');
end

end

%% G6 Binary Builder
function data = build_g6_binary(Pats, stretch, row_count, col_count, gs_val)
% Build G6 binary pattern data

num_frames = size(Pats, 3);
num_panels = row_count * col_count;

% Calculate bytes per frame
if gs_val == 1
    % GS2: 50 bytes per panel (400 pixels / 8 bits)
    panel_bytes = 50;
else
    % GS16: 200 bytes per panel (400 pixels * 4 bits / 8)
    panel_bytes = 200;
end
frame_bytes = num_panels * panel_bytes;

% Header: 4 bytes
% [gs_val (1 byte), num_frames_low (1 byte), num_frames_high (1 byte), reserved (1 byte)]
header = uint8([gs_val, mod(num_frames, 256), floor(num_frames / 256), 0]);

% Pre-allocate data
total_bytes = 4 + num_frames * (frame_bytes + 1);  % +1 for stretch per frame
data = zeros(total_bytes, 1, 'uint8');

% Write header
data(1:4) = header;
offset = 5;

% Write each frame
for f = 1:num_frames
    frame_data = Pats(:, :, f);

    % Encode each panel
    for pr = 0:(row_count-1)
        for pc = 0:(col_count-1)
            % Extract panel pixels (20x20)
            row_start = pr * 20 + 1;
            row_end = row_start + 19;
            col_start = pc * 20 + 1;
            col_end = col_start + 19;

            panel_pixels = frame_data(row_start:row_end, col_start:col_end);

            % Encode panel
            panel_data = g6_encode_panel(panel_pixels, gs_val);

            % Write to data array
            data(offset:offset+panel_bytes-1) = panel_data;
            offset = offset + panel_bytes;
        end
    end

    % Write stretch value for this frame
    data(offset) = stretch(f);
    offset = offset + 1;
end

end

function g6_save_pattern(Pats, stretch, arena_config, save_dir, filename, varargin)
% G6_SAVE_PATTERN Save pattern to G6 .pat and .mat files
%
% Inputs:
%   Pats         - 3D array (total_rows, total_cols, num_frames)
%                  For 2×10 arena: (40, 200, num_frames)
%   stretch      - [num_frames × 1] uint8 stretch values per frame
%   arena_config - Arena config struct from g6_arena_config(), or [rows, cols]
%   save_dir     - Directory to save files
%   filename     - Base filename (will create .mat and .pat)
%
% Optional Name-Value:
%   'Mode'       - 'GS2' (binary) or 'GS16' (grayscale), default: 'GS2'
%   'Overwrite'  - true/false, allow overwriting existing files
%
% Outputs:
%   Creates two files:
%     - filename_G6.mat  (MATLAB structure with metadata)
%     - filename.pat     (Binary pattern file for controller)
%
% Example:
%   % Quick usage with [rows, cols]
%   Pats = zeros(40, 200, 10, 'uint8');
%   Pats(1:20, :, :) = 1;  % Top row lit
%   stretch = ones(10, 1) * 192;
%   g6_save_pattern(Pats, stretch, [2, 10], './patterns', 'test');
%
%   % With explicit arena config
%   config = g6_arena_config(2, 10);
%   g6_save_pattern(Pats, stretch, config, './patterns', 'test');
%
%   % Grayscale pattern
%   Pats = uint8(randi([0 15], 40, 200, 10));
%   g6_save_pattern(Pats, stretch, [2,10], './patterns', 'gradient', 'Mode', 'GS16');

% Parse optional arguments
p = inputParser;
addParameter(p, 'Mode', 'GS2', @(x) ismember(upper(x), {'GS2', 'GS16'}));
addParameter(p, 'Overwrite', false, @islogical);
parse(p, varargin{:});
mode = upper(p.Results.Mode);
overwrite = p.Results.Overwrite;

% Handle arena_config as [rows, cols] shorthand
if isnumeric(arena_config) && numel(arena_config) == 2
    arena_config = g6_arena_config(arena_config(1), arena_config(2));
end

% Validate inputs
expected_rows = arena_config.total_rows;
expected_cols = arena_config.total_cols;
[act_rows, act_cols, num_frames] = size(Pats);

assert(act_rows == expected_rows, ...
    sprintf('Pats rows (%d) must match arena (%d)', act_rows, expected_rows));
assert(act_cols == expected_cols, ...
    sprintf('Pats cols (%d) must match arena (%d)', act_cols, expected_cols));
assert(length(stretch) == num_frames, ...
    'stretch must have one value per frame');
assert(num_frames > 0 && num_frames <= 65535, ...
    'num_frames must be 1-65535');

% Validate pixel values
if strcmp(mode, 'GS2')
    assert(all(Pats(:) == 0 | Pats(:) == 1), 'GS2 mode: pixel values must be 0 or 1');
    gs_val = 1;
else
    assert(all(Pats(:) >= 0 & Pats(:) <= 15), 'GS16 mode: pixel values must be 0-15');
    gs_val = 2;
end

stretch = uint8(stretch(:));

% Build pattern structure
pattern = struct();
pattern.Pats = Pats;
pattern.num_frames = num_frames;
pattern.version = 1;
pattern.row_count = arena_config.row_count;
pattern.col_count = arena_config.col_count;
pattern.num_panels = arena_config.num_panels;
pattern.panel_mask = arena_config.panel_mask;
pattern.stretch = stretch;
pattern.gs_val = gs_val;
pattern.mode = mode;
pattern.arena_config = arena_config;
pattern.filename = filename;
pattern.created = datestr(now);

% Generate binary pattern file
pattern.data = make_pattern_binary(pattern, mode);

% Create save directory if needed
if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

% Create filenames
mat_file = fullfile(save_dir, [filename '_G6.mat']);
pat_file = fullfile(save_dir, [filename '.pat']);

% Check for existing files
if ~overwrite
    if exist(mat_file, 'file')
        error('File exists (use ''Overwrite'', true): %s', mat_file);
    end
    if exist(pat_file, 'file')
        error('File exists (use ''Overwrite'', true): %s', pat_file);
    end
end

% Save .mat file
save(mat_file, 'pattern');
fprintf('Saved: %s\n', mat_file);

% Save binary .pat file
fid = fopen(pat_file, 'w');
fwrite(fid, pattern.data, 'uint8');
fclose(fid);
fprintf('Saved: %s (%d bytes)\n', pat_file, length(pattern.data));

end

%% ========== Local Functions ==========

function arena_config = g6_arena_config(row_count, col_count, missing_panels)
% Create arena configuration structure
%
% Inputs:
%   row_count      - Number of panel rows
%   col_count      - Number of panel columns
%   missing_panels - (optional) Array of absent panel IDs

if nargin < 3
    missing_panels = [];
end

assert(row_count > 0 && row_count <= 255, 'row_count must be 1-255');
assert(col_count > 0 && col_count <= 255, 'col_count must be 1-255');
assert(row_count * col_count <= 48, 'Maximum 48 panels');

arena_config = struct();
arena_config.row_count = uint8(row_count);
arena_config.col_count = uint8(col_count);
arena_config.num_panels = uint8(row_count * col_count);
arena_config.missing_panels = missing_panels;
arena_config.panel_mask = create_panel_mask(row_count, col_count, missing_panels);
arena_config.total_rows = row_count * 20;
arena_config.total_cols = col_count * 20;

% TODO: Add these fields in Step 3
% arena_config.generation = 'G6';
% arena_config.panel_size = 20;
% arena_config.gs_mode = mode;

end

function panel_mask = create_panel_mask(row_count, col_count, missing_panels)
% Create panel presence bitmask (6 bytes for up to 48 panels)

num_panels = row_count * col_count;
panel_mask = zeros(1, 6, 'uint8');

% Set all panels present
for panel_id = 0:(num_panels-1)
    byte_idx = floor(panel_id / 8) + 1;
    bit_idx = mod(panel_id, 8);
    panel_mask(byte_idx) = bitset(panel_mask(byte_idx), bit_idx + 1, 1);
end

% Clear missing panels
for i = 1:length(missing_panels)
    panel_id = missing_panels(i);
    byte_idx = floor(panel_id / 8) + 1;
    bit_idx = mod(panel_id, 8);
    panel_mask(byte_idx) = bitset(panel_mask(byte_idx), bit_idx + 1, 0);
end

end

function file_data = make_pattern_binary(pattern, mode)
% Generate complete binary .pat file

num_frames = pattern.num_frames;
row_count = pattern.row_count;
col_count = pattern.col_count;
panel_mask = pattern.panel_mask;
gs_val = pattern.gs_val;
stretch = pattern.stretch;
Pats = pattern.Pats;

% Create header (17 bytes)
header = zeros(1, 17, 'uint8');
header(1:4) = uint8('G6PT');           % Magic
header(5) = uint8(1);                   % Version
header(6) = uint8(gs_val);              % GS mode (1=GS2, 2=GS16)
header(7) = uint8(mod(num_frames, 256));
header(8) = uint8(floor(num_frames / 256));
header(9) = row_count;
header(10) = col_count;
header(11) = 0;                         % Checksum placeholder
header(12:17) = panel_mask(1:6);

% Generate all frames
all_frames = [];

for frame_idx = 0:(num_frames-1)
    % Frame header
    frame_header = zeros(1, 4, 'uint8');
    frame_header(1:2) = uint8('FR');
    frame_header(3) = uint8(mod(frame_idx, 256));
    frame_header(4) = uint8(floor(frame_idx / 256));
    
    full_frame = Pats(:, :, frame_idx+1);
    stretch_val = stretch(frame_idx+1);
    
    panel_blocks = [];
    
    for panel_row = 0:(row_count-1)
        for panel_col = 0:(col_count-1)
            row_start = panel_row * 20 + 1;
            row_end = row_start + 19;
            col_start = panel_col * 20 + 1;
            col_end = col_start + 19;
            
            panel_pixels = full_frame(row_start:row_end, col_start:col_end);
            panel_block = g6_encode_panel(panel_pixels, stretch_val, mode);
            panel_blocks = [panel_blocks, panel_block];
        end
    end
    
    all_frames = [all_frames, frame_header, panel_blocks];
end

% Compute checksum
checksum = uint8(0);
for i = 1:length(all_frames)
    checksum = bitxor(checksum, all_frames(i));
end
header(11) = checksum;

file_data = [header, all_frames];

end

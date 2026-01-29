function g6_save_pattern(Pats, stretch, arena_config, save_dir, filename, varargin)
% G6_SAVE_PATTERN Save pattern to G6 .pat file (v2 format)
%
% Inputs:
%   Pats         - 3D array (total_rows, total_cols, num_frames)
%                  For 2×10 arena: (40, 200, num_frames)
%                  For 2×8of10 partial arena: (40, 160, num_frames)
%   stretch      - [num_frames × 1] uint8 stretch values per frame
%   arena_config - Arena config struct from g6_arena_config(), or [rows, cols]
%   save_dir     - Directory to save files
%   filename     - Base filename (will create filename_G6.pat)
%
% Optional Name-Value:
%   'Mode'       - 'GS2' (binary) or 'GS16' (grayscale), default: 'GS2'
%   'Overwrite'  - true/false, allow overwriting existing files
%
% Outputs:
%   Creates one file:
%     - filename_G6.pat  (Binary pattern file with embedded metadata)
%
% G6 v2 Header (18 bytes):
%   Bytes 1-4:   Magic "G6PT"
%   Byte 5:      Version (2)
%   Byte 6:      gs_val (1=GS2, 2=GS16)
%   Bytes 7-8:   num_frames (little-endian uint16)
%   Byte 9:      row_count (panel rows)
%   Byte 10:     col_count (FULL grid columns)
%   Byte 11:     checksum (XOR of frame data)
%   Bytes 12-17: panel_mask (6 bytes)
%   Byte 18:     installed_cols (number of installed columns in file)
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

% Handle arena_config in various formats:
%   - [row_count, col_count] shorthand -> all panels present
%   - Local g6_arena_config struct -> use as-is
%   - Full YAML arena config struct -> extract info and compute missing panels
if isnumeric(arena_config) && numel(arena_config) == 2
    % Simple shorthand: [row_count, col_count]
    arena_config = g6_arena_config(arena_config(1), arena_config(2));
elseif isstruct(arena_config) && isfield(arena_config, 'arena')
    % Full YAML arena config from load_arena_config()
    yaml_config = arena_config;
    row_count = yaml_config.arena.num_rows;
    full_col_count = yaml_config.arena.num_cols;

    % Determine installed columns
    if isfield(yaml_config.arena, 'columns_installed') && ...
       ~isempty(yaml_config.arena.columns_installed)
        installed_cols = yaml_config.arena.columns_installed;
    else
        installed_cols = 0:(full_col_count-1);  % All columns installed
    end
    num_installed_cols = length(installed_cols);

    % Compute missing panels from columns_installed
    all_cols = 0:(full_col_count-1);
    missing_cols = setdiff(all_cols, installed_cols);
    missing_panels = [];

    % Convert missing columns to missing panel IDs
    % Panel ID = row * num_cols + col (for the FULL grid)
    for row = 0:(row_count-1)
        for col = missing_cols
            panel_id = row * full_col_count + col;
            missing_panels = [missing_panels, panel_id];
        end
    end

    % Create arena config using INSTALLED column count (not full grid)
    % This ensures panel_mask only contains bits for installed panels
    arena_config = g6_arena_config(row_count, num_installed_cols, []);
    arena_config.installed_cols = installed_cols;
    arena_config.num_installed_cols = num_installed_cols;
    arena_config.full_col_count = full_col_count;  % Keep for reference
    % total_cols matches Pats dimensions (installed columns only)
    arena_config.total_cols = num_installed_cols * 20;
end
% Otherwise assume it's already a valid g6_arena_config struct

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

% Create filename (G6 only creates .pat, no .mat file)
pat_file = fullfile(save_dir, [filename '_G6.pat']);

% Check for existing file
if ~overwrite && exist(pat_file, 'file')
    error('File exists (use ''Overwrite'', true): %s', pat_file);
end

% Save binary .pat file (all metadata embedded in header)
fid = fopen(pat_file, 'w');
fwrite(fid, pattern.data, 'uint8');
fclose(fid);

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

% Validate installed panel count (not full grid)
num_installed = row_count * col_count - length(missing_panels);
assert(num_installed <= 48, ...
    sprintf('Maximum 48 installed panels (got %d)', num_installed));

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

function panel_mask = create_panel_mask(row_count, col_count, ~)
% Create panel presence bitmask for INSTALLED panels (6 bytes for up to 48 panels)
%
% Note: col_count should be the INSTALLED column count, not full grid.
% This ensures panel IDs stay within the 48-bit mask capacity.

num_panels = row_count * col_count;
panel_mask = zeros(1, 6, 'uint8');

% Set bits for all installed panels (contiguous 0 to num_panels-1)
for panel_id = 0:(num_panels-1)
    byte_idx = floor(panel_id / 8) + 1;
    bit_idx = mod(panel_id, 8);
    panel_mask(byte_idx) = bitset(panel_mask(byte_idx), bit_idx + 1, 1);
end

end

function file_data = make_pattern_binary(pattern, mode)
% Generate complete binary .pat file

num_frames = pattern.num_frames;
row_count = pattern.row_count;
col_count = pattern.col_count;  % Full grid column count (for header)
panel_mask = pattern.panel_mask;
gs_val = pattern.gs_val;
stretch = pattern.stretch;
Pats = pattern.Pats;
arena_config = pattern.arena_config;

% Determine which columns are installed (for partial arenas)
if isfield(arena_config, 'installed_cols')
    installed_cols = arena_config.installed_cols;
else
    installed_cols = 0:(col_count-1);  % All columns
end

% Create header (17 bytes)
header = zeros(1, 17, 'uint8');
header(1:4) = uint8('G6PT');           % Magic
header(5) = uint8(1);                   % Version
header(6) = uint8(gs_val);              % GS mode (1=GS2, 2=GS16)
header(7) = uint8(mod(num_frames, 256));
header(8) = uint8(floor(num_frames / 256));
header(9) = row_count;
header(10) = length(installed_cols);   % Installed columns (matches pattern data)
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

    % Iterate over installed columns only
    % Pats dimensions match installed columns, so we use local indexing
    for panel_row = 0:(row_count-1)
        for local_col_idx = 1:length(installed_cols)
            % local_col_idx is 1-indexed into the Pats array
            row_start = panel_row * 20 + 1;
            row_end = row_start + 19;
            col_start = (local_col_idx - 1) * 20 + 1;
            col_end = col_start + 19;

            panel_pixels = full_frame(row_start:row_end, col_start:col_end);
            try
                panel_block = g6_encode_panel(panel_pixels, stretch_val, mode);
            catch ME
                % Provide detailed diagnostics if the call fails
                fprintf('Error in g6_encode_panel call:\n');
                fprintf('  panel_pixels size: %s\n', mat2str(size(panel_pixels)));
                fprintf('  stretch_val: %d (class: %s)\n', stretch_val, class(stretch_val));
                fprintf('  mode: %s\n', mode);
                fprintf('  g6_encode_panel location: %s\n', which('g6_encode_panel'));
                rethrow(ME);
            end
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

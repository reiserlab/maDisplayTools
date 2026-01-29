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
        % Ensure g6 folder is at TOP of path to take precedence
        [thisDir, ~, ~] = fileparts(mfilename('fullpath'));
        g6Folder = fullfile(fileparts(thisDir), 'g6');
        if contains(path, g6Folder)
            rmpath(g6Folder);  % Remove first so addpath puts it at top
        end
        addpath(g6Folder);

        % Force MATLAB to recognize the current g6_save_pattern function
        % (clears any cached old versions with different signatures)
        rehash path;
        clear g6_save_pattern g6_encode_panel;

        % Use the canonical g6_save_pattern from g6/ folder
        % Determine mode from gs_val
        if param.gs_val == 1 || param.gs_val == 2
            mode = 'GS2';
        else
            mode = 'GS16';
        end

        % Pass arena config if available (for proper panel_mask in partial arenas)
        % Otherwise fall back to [row_count, col_count] shorthand
        if isfield(param, 'arena_config') && ~isempty(param.arena_config)
            arena_config = param.arena_config;
        else
            % Derive from Pats dimensions (assumes all panels present)
            [total_rows, total_cols, ~] = size(Pats);
            row_count = total_rows / 20;
            col_count = total_cols / 20;
            arena_config = [row_count, col_count];
        end

        g6_save_pattern(Pats, param.stretch(:), arena_config, ...
            save_dir, filename, 'Mode', mode, 'Overwrite', false);
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
% Debug output removed - info now displayed in GUI
% fprintf('Saved: %s\n', matFileName);

% Save the corresponding binary pat file
fileID = fopen(patFileName, 'w');
fwrite(fileID, pattern.data);
fclose(fileID);
% Debug output removed - info now displayed in GUI
% fprintf('Saved: %s\n', patFileName);

end

% Note: G6 patterns are saved using g6_save_pattern() from the g6/ folder.
% This ensures a single, canonical G6 binary format with proper 17-byte header.

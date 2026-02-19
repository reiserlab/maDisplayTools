function [frames, meta, arena_config] = load_pattern_with_config(filepath)
% LOAD_PATTERN_WITH_CONFIG Load pattern and auto-detect arena config from filename
%
% Combines maDisplayTools.load_pat with arena config detection from filename.
% If the filename includes an arena config prefix (e.g., "G6_2x10_grating.pat"),
% the corresponding arena config is automatically loaded.
%
% Usage:
%   [frames, meta, config] = load_pattern_with_config('G6_2x10_grating_20px.pat')
%
% Input:
%   filepath - Path to .pat file
%
% Output:
%   frames       - 4D pattern array (from maDisplayTools.load_pat)
%   meta         - Pattern metadata struct (from maDisplayTools.load_pat)
%   arena_config - Arena config struct (from load_arena_config), or [] if not found
%
% The function looks for arena configs in these locations (in order):
%   1. configs/arenas/{config_name}.yaml (relative to maDisplayTools root)
%   2. ../configs/arenas/{config_name}.yaml (if in a subdirectory)
%   3. Returns [] if config file not found (pattern still loads)
%
% Example:
%   [frames, meta, config] = load_pattern_with_config('patterns/G6_2x10_sine.pat');
%   if ~isempty(config)
%       fprintf('Arena: %s (%d x %d panels)\n', ...
%           config.arena.generation, config.arena.num_rows, config.arena.num_cols);
%   end
%
% See also: maDisplayTools.load_pat, parse_arena_from_filename, load_arena_config

%% Load the pattern
[frames, meta] = maDisplayTools.load_pat(filepath);

%% Try to parse arena config from filename
[config_name, ~] = parse_arena_from_filename(filepath);

arena_config = [];

if ~isempty(config_name)
    % Try to find the config file
    % First, determine maDisplayTools root
    this_file = mfilename('fullpath');
    utils_dir = fileparts(this_file);
    ma_root = fileparts(utils_dir);

    % Look for config file
    config_paths = {
        fullfile(ma_root, 'configs', 'arenas', [config_name '.yaml']),
        fullfile(ma_root, 'configs', 'arenas', [config_name '.yml'])
    };

    for i = 1:length(config_paths)
        if isfile(config_paths{i})
            try
                arena_config = load_arena_config(config_paths{i});
                fprintf('Auto-detected arena config: %s\n', config_name);
            catch ME
                warning('Found config file but failed to load: %s\n%s', ...
                    config_paths{i}, ME.message);
            end
            break;
        end
    end

    if isempty(arena_config)
        warning('Arena config "%s" referenced in filename but config file not found.', config_name);
    end
end

end

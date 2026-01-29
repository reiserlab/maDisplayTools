function [valid, info] = validate_pattern_arena(pattern_path, arena_config_path)
% VALIDATE_PATTERN_ARENA Validate that a pattern matches an arena configuration
%
% Usage:
%   [valid, info] = validate_pattern_arena(pattern_path)
%   [valid, info] = validate_pattern_arena(pattern_path, arena_config_path)
%
% Inputs:
%   pattern_path      - Path to pattern .mat file
%   arena_config_path - (Optional) Path to arena config YAML file
%                       If omitted, infers from parent directory name
%
% Outputs:
%   valid - true if pattern dimensions match arena config
%   info  - Struct with validation details:
%       .pattern_rows     - Pattern array row count
%       .pattern_cols     - Pattern array column count
%       .expected_rows    - Expected rows from arena config
%       .expected_cols    - Expected cols from arena config
%       .arena_name       - Arena config name
%       .message          - Human-readable result message
%
% Pattern Library Convention:
%   Patterns should be organized in directories named after arena configs:
%     patterns/G6_2x10/my_pattern_G6.mat
%     patterns/G41_2x12_ccw/my_pattern_G4.mat
%
%   When arena_config_path is omitted, this function extracts the arena name
%   from the pattern's parent directory and looks for the corresponding YAML
%   in configs/arenas/.
%
% Examples:
%   % Validate pattern using directory convention
%   [valid, info] = validate_pattern_arena('patterns/G6_2x10/grating_G6.mat');
%
%   % Validate pattern against explicit arena config
%   [valid, info] = validate_pattern_arena('my_pattern.mat', 'configs/arenas/G6_2x10.yaml');
%
% See also: load_arena_config, load_pattern

%% Load pattern
if ~isfile(pattern_path)
    error('Pattern file not found: %s', pattern_path);
end

try
    data = load(pattern_path);
    if isfield(data, 'pattern')
        pattern = data.pattern;
    else
        error('Pattern file does not contain a ''pattern'' struct');
    end
catch ME
    error('Failed to load pattern file: %s\nError: %s', pattern_path, ME.message);
end

% Get pattern dimensions
if isfield(pattern, 'Pats')
    [pattern_rows, pattern_cols, ~] = size(pattern.Pats);
else
    error('Pattern struct does not contain ''Pats'' field');
end

%% Determine arena config path
if nargin < 2 || isempty(arena_config_path)
    % Infer from parent directory name
    [parent_dir, ~, ~] = fileparts(pattern_path);
    [~, arena_name, ~] = fileparts(parent_dir);

    if isempty(arena_name)
        error('Cannot infer arena name: pattern is not in a subdirectory');
    end

    % Look for arena config in standard location
    % Try relative to project root first
    possible_paths = {
        fullfile('configs', 'arenas', [arena_name '.yaml']),
        fullfile('configs', 'arenas', [arena_name '.yml']),
        fullfile(fileparts(fileparts(pattern_path)), 'configs', 'arenas', [arena_name '.yaml']),
    };

    arena_config_path = '';
    for i = 1:length(possible_paths)
        if isfile(possible_paths{i})
            arena_config_path = possible_paths{i};
            break;
        end
    end

    if isempty(arena_config_path)
        error('Arena config not found for ''%s''. Looked in:\n  %s', ...
            arena_name, strjoin(possible_paths, '\n  '));
    end
else
    [~, arena_name, ~] = fileparts(arena_config_path);
end

%% Load arena config
try
    config = load_arena_config(arena_config_path);
catch ME
    error('Failed to load arena config: %s\nError: %s', arena_config_path, ME.message);
end

%% Validate dimensions
expected_rows = config.derived.total_pixels_y;
expected_cols = config.derived.total_pixels_x;

valid = (pattern_rows == expected_rows) && (pattern_cols == expected_cols);

%% Build info struct
info = struct();
info.pattern_rows = pattern_rows;
info.pattern_cols = pattern_cols;
info.expected_rows = expected_rows;
info.expected_cols = expected_cols;
info.arena_name = arena_name;
info.arena_config_path = arena_config_path;
info.pattern_path = pattern_path;

if valid
    info.message = sprintf('VALID: Pattern (%dx%d) matches arena ''%s'' (%dx%d)', ...
        pattern_rows, pattern_cols, arena_name, expected_rows, expected_cols);
else
    info.message = sprintf('INVALID: Pattern (%dx%d) does not match arena ''%s'' (expected %dx%d)', ...
        pattern_rows, pattern_cols, arena_name, expected_rows, expected_cols);
end

%% Display result if no output requested
if nargout == 0
    if valid
        fprintf('✓ %s\n', info.message);
    else
        fprintf('✗ %s\n', info.message);
    end
    clear valid info;
end

end

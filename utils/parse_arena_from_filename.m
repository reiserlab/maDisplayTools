function [config_name, pattern_name] = parse_arena_from_filename(filename)
% PARSE_ARENA_FROM_FILENAME Extract arena config name from pattern filename
%
% Patterns saved from the web Pattern Editor include the arena config name
% as a prefix in the filename, e.g., "G6_2x10_grating_20px.pat"
%
% Usage:
%   [config_name, pattern_name] = parse_arena_from_filename('G6_2x10_grating_20px.pat')
%   % Returns: config_name = 'G6_2x10', pattern_name = 'grating_20px.pat'
%
%   config_name = parse_arena_from_filename(filepath)
%   % Also accepts full file paths
%
% Input:
%   filename - Pattern filename or full path (e.g., 'G6_2x10_grating_20px.pat')
%
% Output:
%   config_name  - Arena config name (e.g., 'G6_2x10') or empty if not found
%   pattern_name - Pattern name without config prefix (e.g., 'grating_20px.pat')
%
% Config Name Patterns Recognized:
%   - G6_2x10        (generation_rowsxcols)
%   - G6_2x8of10     (partial arena: 8 of 10 columns)
%   - G6_3x12of18    (partial arena)
%   - G41_2x12_cw    (G4.1 with column order)
%   - G41_2x12_ccw   (G4.1 counter-clockwise)
%   - G4_3x12        (G4 arena)
%   - G3_4x12        (G3 arena)
%
% Example:
%   [cfg, pat] = parse_arena_from_filename('G6_2x10_sine_40px.pat');
%   if ~isempty(cfg)
%       config = load_arena_config(['configs/arenas/' cfg '.yaml']);
%   end
%
% See also: load_arena_config, maDisplayTools.load_pat

%% Extract just the filename if a full path was given
[~, name, ext] = fileparts(filename);
basename = [name ext];

%% Define regex pattern for arena config prefixes
% Matches: G{gen}_{rows}x{cols}[of{total}][_{order}]_
% Examples: G6_2x10_, G41_2x12_cw_, G6_2x8of10_
config_pattern = '^(G\d+\.?\d*_\d+x\d+(of\d+)?(_cw|_ccw)?)_';

%% Try to match
tokens = regexp(basename, config_pattern, 'tokens', 'once');

if ~isempty(tokens)
    config_name = tokens{1};
    % Remove the config prefix from basename
    pattern_name = regexprep(basename, config_pattern, '');
else
    config_name = '';
    pattern_name = basename;
end

end

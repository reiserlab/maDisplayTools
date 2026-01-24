function config = load_experiment_config(filepath)
% LOAD_EXPERIMENT_CONFIG Load experiment configuration with full hierarchy resolution
%
% Usage:
%   config = load_experiment_config('experiments/my_experiment/protocol.yaml')
%   config = load_experiment_config()  % Opens file dialog
%
% This function loads an experiment YAML file and automatically resolves
% the entire config hierarchy: experiment -> rig -> arena
%
% Input:
%   filepath - Path to experiment YAML file (optional, opens dialog if omitted)
%
% Output:
%   config - Struct with fields:
%       .version         - Protocol version
%       .experiment_info - Experiment metadata
%       .rig             - Resolved rig config (includes arena, controller, plugins)
%       .arena           - Shortcut to rig.arena
%       .derived         - Derived properties from arena
%       .experiment_structure - Repetitions, randomization settings
%       .pretrial        - Pretrial commands
%       .block           - Block conditions
%       .intertrial      - Intertrial commands
%       .posttrial       - Posttrial commands
%       .plugins         - Plugin definitions (from experiment level)
%       .source_file     - Path to experiment file
%       .rig_file        - Path to resolved rig file
%       .arena_file      - Path to resolved arena file
%
% Example:
%   config = load_experiment_config('experiments/optomotor/protocol.yaml');
%   fprintf('Experiment: %s\n', config.experiment_info.name);
%   fprintf('Arena: %s (%dx%d)\n', config.arena.generation, ...
%       config.arena.num_rows, config.arena.num_cols);
%   show_resolved_config(config);
%
% See also: load_arena_config, load_rig_config, show_resolved_config

%% Handle file selection
if nargin < 1 || isempty(filepath)
    [filename, pathname] = uigetfile({'*.yaml;*.yml', 'YAML Files (*.yaml, *.yml)'}, ...
        'Select Experiment Configuration');
    if isequal(filename, 0)
        error('No file selected');
    end
    filepath = fullfile(pathname, filename);
end

%% Verify file exists
if ~isfile(filepath)
    error('Experiment config file not found: %s', filepath);
end

%% Read YAML file
try
    % Use the project's yamlread (requires yamlSupport on path)
    raw = yamlread(filepath);
catch ME
    error('Failed to load YAML file: %s\nError: %s\nEnsure yamlSupport is on the path (addpath yamlSupport).', ...
        filepath, ME.message);
end

%% Build config struct
config = struct();
config.source_file = filepath;

% Version
config.version = getFieldOrDefault(raw, 'version', 1);

% Experiment info
if isfield(raw, 'experiment_info')
    config.experiment_info = raw.experiment_info;
else
    config.experiment_info = struct();
end

%% Resolve rig reference
if isfield(raw, 'rig')
    rig_ref = raw.rig;

    if ischar(rig_ref) || isstring(rig_ref)
        % Rig is a file path reference - resolve it
        rig_path = resolve_relative_path(filepath, rig_ref);

        if ~isfile(rig_path)
            error('Rig config file not found: %s (referenced from %s)', rig_path, filepath);
        end

        rig_config = load_rig_config(rig_path);
        config.rig = rig_config;
        config.rig_file = rig_path;
        config.arena_file = rig_config.arena_file;
    elseif isstruct(rig_ref)
        % Inline rig config (not recommended)
        warning('Inline rig config detected. Consider using file reference instead.');
        config.rig = rig_ref;
        config.rig_file = '';
        config.arena_file = '';
    else
        error('Invalid rig field: must be a file path string or inline struct');
    end

    % Create shortcut to arena and derived for convenience
    if isfield(config.rig, 'arena')
        config.arena = config.rig.arena;
    end
    if isfield(config.rig, 'derived')
        config.derived = config.rig.derived;
    end
else
    % No rig field - check for legacy arena_info
    if isfield(raw, 'arena_info')
        error(['Experiment uses inline arena_info which is no longer supported.\n' ...
               'Please migrate to hierarchical config:\n' ...
               '1. Create arena config in configs/arenas/\n' ...
               '2. Create rig config in configs/rigs/ referencing the arena\n' ...
               '3. Replace arena_info with: rig: "path/to/rig.yaml"']);
    else
        error('Missing required field: rig (file path to rig configuration)');
    end
end

%% Copy experiment structure fields
structure_fields = {'experiment_structure', 'pretrial', 'block', 'intertrial', 'posttrial', 'plugins'};
for i = 1:length(structure_fields)
    field = structure_fields{i};
    if isfield(raw, field)
        config.(field) = raw.(field);
    end
end

end

%% Helper: Get field with default value
function value = getFieldOrDefault(s, field, default)
    if isfield(s, field) && ~isempty(s.(field))
        value = s.(field);
    else
        value = default;
    end
end

%% Helper: Resolve relative path from reference file location
function resolved = resolve_relative_path(ref_file, rel_path)
    ref_dir = fileparts(ref_file);

    % Handle absolute paths
    if isAbsolutePath(rel_path)
        resolved = rel_path;
    else
        resolved = fullfile(ref_dir, rel_path);
    end

    % Normalize path
    resolved = char(java.io.File(resolved).getCanonicalPath());
end

%% Helper: Check if path is absolute
function result = isAbsolutePath(p)
    if ispc()
        result = length(p) >= 2 && (p(2) == ':' || startsWith(p, '\\'));
    else
        result = startsWith(p, '/');
    end
end


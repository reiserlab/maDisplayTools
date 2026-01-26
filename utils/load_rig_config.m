function config = load_rig_config(filepath)
% LOAD_RIG_CONFIG Load rig configuration with arena resolution
%
% Usage:
%   config = load_rig_config('configs/rigs/my_rig.yaml')
%   config = load_rig_config()  % Opens file dialog
%
% This function loads a rig configuration file and automatically resolves
% the arena reference, merging the arena config into the rig struct.
%
% Input:
%   filepath - Path to rig config YAML file (optional, opens dialog if omitted)
%
% Output:
%   config - Struct with fields:
%       .format_version  - Schema version
%       .name            - Rig name
%       .description     - Rig description
%       .arena           - Resolved arena config (from arena file)
%       .derived         - Derived properties from arena
%       .controller      - Controller settings struct:
%           .host        - Controller IP address
%           .port        - Controller port (default: 62222)
%       .plugins         - Plugin configurations struct
%       .source_file     - Path to the rig config file
%       .arena_file      - Path to the resolved arena config file
%
% Example:
%   config = load_rig_config('configs/rigs/example_rig.yaml');
%   fprintf('Controller: %s:%d\n', config.controller.host, config.controller.port);
%   fprintf('Arena: %s (%s)\n', config.arena.generation, config.name);
%
% See also: get_generation_specs, load_arena_config, load_experiment_config

%% Handle file selection
if nargin < 1 || isempty(filepath)
    [filename, pathname] = uigetfile({'*.yaml;*.yml', 'YAML Files (*.yaml, *.yml)'}, ...
        'Select Rig Configuration');
    if isequal(filename, 0)
        error('No file selected');
    end
    filepath = fullfile(pathname, filename);
end

%% Verify file exists
if ~isfile(filepath)
    error('Rig config file not found: %s', filepath);
end

%% Read YAML file
try
    % Use the project's yamlread (requires yamlSupport on path)
    raw = yamlread(filepath);
catch ME
    error('Failed to load YAML file: %s\nError: %s\nEnsure yamlSupport is on the path (addpath yamlSupport).', ...
        filepath, ME.message);
end

%% Validate required fields
if ~isfield(raw, 'format_version')
    error('Missing required field: format_version');
end
if ~isfield(raw, 'arena')
    error('Missing required field: arena');
end

%% Build config struct
config = struct();
config.format_version = raw.format_version;
config.name = getFieldOrDefault(raw, 'name', '');
config.description = getFieldOrDefault(raw, 'description', '');

%% Resolve arena reference
arena_ref = raw.arena;
if ischar(arena_ref) || isstring(arena_ref)
    % Arena is a file path reference - resolve it
    arena_path = resolve_relative_path(filepath, arena_ref);

    if ~isfile(arena_path)
        error('Arena config file not found: %s (referenced from %s)', arena_path, filepath);
    end

    arena_config = load_arena_config(arena_path);
    config.arena = arena_config.arena;
    config.derived = arena_config.derived;
    config.arena_file = arena_path;
elseif isstruct(arena_ref)
    % Arena is inline (not recommended but supported)
    warning('Inline arena config detected. Consider using file reference instead.');
    config.arena = arena_ref;
    config.derived = compute_arena_derived(arena_ref);
    config.arena_file = '';
else
    error('Invalid arena field: must be a file path string or inline struct');
end

%% Controller settings
if isfield(raw, 'controller') && isstruct(raw.controller)
    config.controller = struct();
    config.controller.host = getFieldOrDefault(raw.controller, 'host', '');
    config.controller.port = getFieldOrDefault(raw.controller, 'port', 62222);
else
    config.controller = struct('host', '', 'port', 62222);
end

%% Plugin settings
if isfield(raw, 'plugins') && isstruct(raw.plugins)
    config.plugins = raw.plugins;
else
    config.plugins = struct();
end

%% Store source file
config.source_file = filepath;

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
        % Windows: starts with drive letter or UNC path
        result = length(p) >= 2 && (p(2) == ':' || startsWith(p, '\\'));
    else
        % Unix: starts with /
        result = startsWith(p, '/');
    end
end

%% Helper: Compute derived properties for inline arena
function derived = compute_arena_derived(arena)
    % Get generation specs from single source of truth
    specs = get_generation_specs(arena.generation);

    derived = struct();
    derived.pixels_per_panel = specs.pixels_per_panel;
    derived.panel_width_mm = specs.panel_width_mm;
    derived.total_pixels_x = arena.num_cols * specs.pixels_per_panel;
    derived.total_pixels_y = arena.num_rows * specs.pixels_per_panel;
    derived.num_panels = arena.num_rows * arena.num_cols;

    if isfield(arena, 'panels_installed') && ~isempty(arena.panels_installed)
        derived.num_panels_installed = length(arena.panels_installed);
    else
        derived.num_panels_installed = derived.num_panels;
    end

    if arena.num_cols > 0
        alpha = 2 * pi / arena.num_cols;
        derived.inner_radius_mm = specs.panel_width_mm / (2 * tan(alpha / 2));
    else
        derived.inner_radius_mm = 0;
    end
end

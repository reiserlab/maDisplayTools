function config = load_arena_config(filepath)
% LOAD_ARENA_CONFIG Load arena configuration from YAML file
%
% Usage:
%   config = load_arena_config('configs/arenas/G6_2x10.yaml')
%   config = load_arena_config()  % Opens file dialog
%
% Input:
%   filepath - Path to arena config YAML file (optional, opens dialog if omitted)
%
% Output:
%   config - Struct with fields:
%       .format_version  - Schema version
%       .name            - Configuration name
%       .description     - Configuration description
%       .arena           - Arena specification struct:
%           .generation        - 'G3', 'G4', 'G4.1', or 'G6'
%           .num_rows          - Number of panel rows
%           .num_cols          - Number of panel columns (full grid)
%           .columns_installed - Array of installed column indices (0-indexed), or [] for all
%           .orientation       - 'normal' or 'flipped'
%           .column_order      - 'cw' or 'ccw'
%           .angle_offset_deg  - Rotation offset in degrees
%       .derived         - Computed properties struct:
%           .pixels_per_panel      - Pixels per panel side (8, 16, or 20)
%           .num_columns_installed - Number of installed columns
%           .total_pixels_x        - Total horizontal pixels (installed columns only)
%           .total_pixels_y        - Total vertical pixels
%           .panel_width_mm        - Panel width in mm
%           .inner_radius_mm       - Inner arena radius in mm
%           .num_panels            - Total panel count in full grid
%           .num_panels_installed  - Count of installed panels
%           .azimuth_coverage_deg  - Angular coverage in degrees
%       .source_file     - Path to the loaded file
%
% Example:
%   config = load_arena_config('configs/arenas/G6_2x10.yaml');
%   fprintf('Grid size: %d x %d pixels\n', config.derived.total_pixels_x, config.derived.total_pixels_y);
%
% See also: get_generation_specs, load_rig_config, load_experiment_config

%% Handle file selection
if nargin < 1 || isempty(filepath)
    [filename, pathname] = uigetfile({'*.yaml;*.yml', 'YAML Files (*.yaml, *.yml)'}, ...
        'Select Arena Configuration');
    if isequal(filename, 0)
        error('No file selected');
    end
    filepath = fullfile(pathname, filename);
end

%% Verify file exists
if ~isfile(filepath)
    error('Arena config file not found: %s', filepath);
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

arena = raw.arena;
required_arena_fields = {'generation', 'num_rows', 'num_cols'};
for i = 1:length(required_arena_fields)
    if ~isfield(arena, required_arena_fields{i})
        error('Missing required arena field: %s', required_arena_fields{i});
    end
end

%% Validate generation
valid_generations = {'G3', 'G4', 'G4.1', 'G6'};
if ~ismember(arena.generation, valid_generations)
    if strcmpi(arena.generation, 'G5')
        error('G5 is deprecated and no longer supported. Use G6 for 20x20 pixel panels.');
    else
        error('Invalid generation: %s. Valid options: %s', ...
            arena.generation, strjoin(valid_generations, ', '));
    end
end

%% Build config struct with defaults
config = struct();
config.format_version = raw.format_version;
config.name = getFieldOrDefault(raw, 'name', '');
config.description = getFieldOrDefault(raw, 'description', '');

% Arena fields
config.arena = struct();
config.arena.generation = arena.generation;
config.arena.num_rows = arena.num_rows;
config.arena.num_cols = arena.num_cols;

% Handle columns_installed (null = all installed)
% Also support legacy panels_installed for backward compatibility
if isfield(arena, 'columns_installed') && ~isempty(arena.columns_installed)
    if iscell(arena.columns_installed)
        config.arena.columns_installed = cell2mat(arena.columns_installed);
    else
        config.arena.columns_installed = arena.columns_installed;
    end
elseif isfield(arena, 'panels_installed') && ~isempty(arena.panels_installed)
    % Legacy support: interpret as column indices if count matches column range
    warning('load_arena_config:legacyField', ...
        'Using legacy field "panels_installed". Please update to "columns_installed".');
    if iscell(arena.panels_installed)
        config.arena.columns_installed = cell2mat(arena.panels_installed);
    else
        config.arena.columns_installed = arena.panels_installed;
    end
else
    config.arena.columns_installed = [];  % Empty means all columns installed
end

config.arena.orientation = getFieldOrDefault(arena, 'orientation', 'normal');
config.arena.column_order = getFieldOrDefault(arena, 'column_order', 'cw');
config.arena.angle_offset_deg = getFieldOrDefault(arena, 'angle_offset_deg', 0);

%% Compute derived properties
config.derived = compute_derived_properties(config.arena);

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

%% Helper: Compute derived properties
function derived = compute_derived_properties(arena)
    % Get generation specs from single source of truth
    specs = get_generation_specs(arena.generation);

    % Compute derived values
    derived = struct();
    derived.pixels_per_panel = specs.pixels_per_panel;
    derived.panel_width_mm = specs.panel_width_mm;

    % Number of installed columns
    if isempty(arena.columns_installed)
        derived.num_columns_installed = arena.num_cols;
    else
        derived.num_columns_installed = length(arena.columns_installed);
    end

    % Total pixels based on INSTALLED columns (for pattern dimensions)
    derived.total_pixels_x = derived.num_columns_installed * specs.pixels_per_panel;
    derived.total_pixels_y = arena.num_rows * specs.pixels_per_panel;

    % Panel counts
    derived.num_panels = arena.num_rows * arena.num_cols;  % Full grid
    derived.num_panels_installed = arena.num_rows * derived.num_columns_installed;

    % Compute inner radius (based on full grid num_cols for correct geometry)
    % Formula: inner_radius = panel_width / (2 * tan(pi / num_cols))
    if arena.num_cols > 0
        alpha = 2 * pi / arena.num_cols;  % Angle per panel in full grid
        derived.inner_radius_mm = specs.panel_width_mm / (2 * tan(alpha / 2));
    else
        derived.inner_radius_mm = 0;
    end

    % Compute azimuthal coverage based on installed columns
    if isempty(arena.columns_installed)
        derived.azimuth_coverage_deg = 360;
    else
        derived.azimuth_coverage_deg = 360 * (derived.num_columns_installed / arena.num_cols);
    end

    % Compute latitude range (based on number of rows and panel size)
    % Assumes arena is centered at horizon (equator)
    if arena.num_cols > 0 && derived.inner_radius_mm > 0
        % Each row spans: panel_height / inner_radius radians
        panel_height_mm = specs.panel_width_mm;  % Panels are square
        row_span_rad = panel_height_mm / derived.inner_radius_mm;
        total_lat_span_rad = arena.num_rows * row_span_rad;
        derived.latitude_span_deg = rad2deg(total_lat_span_rad);
        % Assume symmetric around horizon
        derived.latitude_min_deg = -derived.latitude_span_deg / 2;
        derived.latitude_max_deg = derived.latitude_span_deg / 2;
    else
        derived.latitude_span_deg = 180;
        derived.latitude_min_deg = -90;
        derived.latitude_max_deg = 90;
    end
end

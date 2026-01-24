function [arena_info, fig_handle] = design_arena(config, varargin)
% DESIGN_ARENA - Generate arena layout visualization from arena config
%
% Usage:
%   design_arena(config)                            % Config struct from load_arena_config
%   design_arena('path/to/arena.yaml')              % YAML file path
%   design_arena(config, 'units', 'inches')         % With display options
%   design_arena(config, 'save_pdf', true)          % Export to PDF
%
% Inputs:
%   config - Either:
%            - Config struct from load_arena_config()
%            - Path to arena YAML file (string ending in .yaml/.yml)
%
% Display Options:
%   'units'            - 'inches' or 'mm' (default: 'mm')
%   'show_pins'        - true/false to show pin locations (default: true)
%   'save_pdf'         - true/false to save as PDF (default: false)
%   'pdf_filename'     - Custom filename for PDF (default: auto-generated)
%   'figure_visible'   - 'on' or 'off' (default: 'on')
%
% Outputs:
%   arena_info  - Struct with computed values:
%                   .c_radius         - Center radius (in selected units)
%                   .back_c_radius    - Back radius (in selected units)
%                   .degs_per_pixel   - Angular resolution
%                   .azimuth_coverage - Total azimuthal coverage (degrees)
%                   .azimuth_gap      - Gap in coverage (degrees)
%                   .panel_specs      - Panel specification struct
%                   .config           - Original config struct
%   fig_handle  - Handle to the generated figure
%
% Panel Specifications (from hardware documentation):
%   G3:   32mm panel, 8x8 pixels, 8-pin header
%   G4:   40.45mm panel, 16x16 pixels, 15-pin header
%   G4.1: 40mm panel, 16x16 pixels, 15-pin header (thinner depth)
%   G6:   45.4mm panel, 20x20 pixels, dual 5-pin headers (from KiCad)
%   Note: G5 is deprecated and no longer supported
%
% Examples:
%   % From YAML config struct
%   config = load_arena_config('configs/arenas/G6_2x10_full.yaml');
%   design_arena(config);
%
%   % Directly from YAML file path
%   design_arena('configs/arenas/G6_2x10_full.yaml');
%
%   % With display options
%   design_arena(config, 'units', 'inches', 'save_pdf', true);
%
% See also: load_arena_config, load_rig_config
%
% Author: Reiser Lab
% Repository: https://github.com/reiserlab/maDisplayTools
% G6 Hardware: https://github.com/iorodeo/LED-Display_G6_Hardware_Panel

%% Load config if path provided
if (ischar(config) || isstring(config)) && ...
   (endsWith(config, '.yaml', 'IgnoreCase', true) || endsWith(config, '.yml', 'IgnoreCase', true))
    config = load_arena_config(config);
end

% Validate config struct
if ~isstruct(config) || ~isfield(config, 'arena')
    error('design_arena:InvalidInput', ...
        'Input must be a config struct from load_arena_config() or a YAML file path');
end

%% Extract arena parameters from config
arena = config.arena;
panel_type = arena.generation;
num_panels = arena.num_cols;
num_rows = arena.num_rows;
column_order = arena.column_order;

% angle_offset (convert from degrees to radians)
if isfield(arena, 'angle_offset_deg')
    angle_offset = deg2rad(arena.angle_offset_deg);
else
    angle_offset = 0;
end

% panels_installed (convert from 0-indexed to 1-indexed column indices)
if isfield(arena, 'panels_installed') && ~isempty(arena.panels_installed)
    panel_indices = arena.panels_installed;
    columns_0idx = mod(panel_indices, num_panels);
    unique_cols = unique(columns_0idx);
    panels_installed = unique_cols + 1;  % Convert to 1-indexed
else
    panels_installed = 1:num_panels;
end

%% Parse display options
p = inputParser;
addParameter(p, 'units', 'mm', @(x) ismember(lower(x), {'inches', 'mm'}));
addParameter(p, 'show_pins', true, @islogical);
addParameter(p, 'save_pdf', false, @islogical);
addParameter(p, 'pdf_filename', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'figure_visible', 'on', @(x) ismember(lower(x), {'on', 'off'}));

parse(p, varargin{:});
opts = p.Results;

% Copy arena parameters to opts for compatibility with existing code
opts.panels_installed = panels_installed;
opts.angle_offset = angle_offset;
opts.column_order = column_order;
opts.num_rows = num_rows;

%% Get panel specifications
panel_specs = get_panel_specs(panel_type);

%% Unit conversion
if strcmpi(opts.units, 'mm')
    unit_scale = 1;
    unit_label = 'mm';
else
    unit_scale = 1/25.4;  % mm to inches
    unit_label = 'inches';
end

% Convert to working units
panel_width = panel_specs.panel_width_mm * unit_scale;
panel_depth = panel_specs.panel_depth_mm * unit_scale;
pin_dist = panel_specs.pin_dist_mm * unit_scale;
pin_spacing = panel_specs.pin_spacing_mm * unit_scale;

%% Calculate arena geometry
alpha = 2*pi/num_panels;  % angle subtended by one panel from center
c_radius = panel_width / (tan(alpha/2)) / 2;
back_c_radius = c_radius + panel_depth;

% Angular positions
alphas = (0:alpha:2*pi-0.01) + opts.angle_offset;
P_angle = alphas + pi/2;

% Resolution and coverage calculations
degs_per_pixel = 360 / (num_panels * panel_specs.pixels_per_panel);
azimuth_coverage = 360 * (length(opts.panels_installed) / num_panels);
azimuth_gap = 360 - azimuth_coverage;

%% Create figure
fig_handle = figure('Visible', opts.figure_visible);
hold on;

% Determine figure size based on arena size
fig_size = max(back_c_radius * 1.3, 3 * unit_scale * 25.4);  % At least 3 inches equivalent
set(gcf, 'Position', [100 100 700 700]);

% Draw axes
plot([-fig_size fig_size], [0 0], 'k', 'LineWidth', 0.5);
plot([0 0], [-fig_size fig_size], 'k', 'LineWidth', 0.5);

%% Draw panels
for j = opts.panels_installed
    % Panel front (LED surface) - green
    P_center = [c_radius*cos(alphas(j)), c_radius*sin(alphas(j))];
    V(1,:) = [P_center(1) - panel_width/2*cos(P_angle(j)), P_center(2) - panel_width/2*sin(P_angle(j))];
    V(2,:) = [P_center(1) + panel_width/2*cos(P_angle(j)), P_center(2) + panel_width/2*sin(P_angle(j))];
    plot(V(:,1), V(:,2), 'g', 'LineWidth', 2);

    % Panel back - black
    back_P_center = [back_c_radius*cos(alphas(j)), back_c_radius*sin(alphas(j))];
    back_V(1,:) = [back_P_center(1) - panel_width/2*cos(P_angle(j)), back_P_center(2) - panel_width/2*sin(P_angle(j))];
    back_V(2,:) = [back_P_center(1) + panel_width/2*cos(P_angle(j)), back_P_center(2) + panel_width/2*sin(P_angle(j))];
    plot(back_V(:,1), back_V(:,2), 'k', 'LineWidth', 1);

    % Panel sides - black
    plot([back_V(1,1) V(1,1)], [back_V(1,2) V(1,2)], 'k', 'LineWidth', 1);
    plot([back_V(2,1) V(2,1)], [back_V(2,2) V(2,2)], 'k', 'LineWidth', 1);

    % Draw pins if enabled
    if opts.show_pins
        draw_pins(c_radius, pin_dist, alphas(j), P_angle(j), panel_specs, pin_spacing, opts);
    end
end

%% Format figure
axis equal;
lim = fig_size * 1.05;
xlim([-lim lim]);
ylim([-lim lim]);
grid on;

% Title with arena info
title_str = sprintf('%d of %d Panel (%s) Arena Layout', ...
    length(opts.panels_installed), num_panels, upper(panel_type));
title(title_str, 'FontSize', 12, 'FontWeight', 'bold');

% X-axis label with coverage info
xlabel_str = sprintf('%.1f%s azimuthal coverage, %.1f%s gap', ...
    azimuth_coverage, char(176), azimuth_gap, char(176));
xlabel(xlabel_str, 'FontSize', 10);

% Y-axis label with radius and dimensions
ylabel_str = sprintf('Radius: %.2f %s | Dimensions in %s', ...
    c_radius, unit_label, unit_label);
ylabel(ylabel_str, 'FontSize', 10);

%% Add resolution info box (upper right - prominent)
azimuthal_pixels = num_panels * panel_specs.pixels_per_panel;
resolution_text = sprintf(['AZIMUTHAL RESOLUTION\n' ...
                           '(from center)\n' ...
                           '%.2f%s / pixel\n' ...
                           '(%d pixels around)'], ...
    degs_per_pixel, char(176), azimuthal_pixels);

annotation('textbox', [0.70, 0.72, 0.28, 0.18], ...
    'String', resolution_text, ...
    'FontSize', 10, ...
    'FontWeight', 'bold', ...
    'BackgroundColor', [0.95 1 0.95], ...
    'EdgeColor', [0 0.5 0], ...
    'LineWidth', 1.5, ...
    'HorizontalAlignment', 'center', ...
    'FitBoxToText', 'on');

%% Add panel info text box (lower left)
info_text = sprintf(['Panel: %s (%.1f mm)\n' ...
                     'Inner radius: %.2f %s\n' ...
                     'Outer radius: %.2f %s'], ...
    upper(panel_type), panel_specs.panel_width_mm, ...
    c_radius, unit_label, back_c_radius, unit_label);

annotation('textbox', [0.02, 0.02, 0.25, 0.12], ...
    'String', info_text, ...
    'FontSize', 8, ...
    'BackgroundColor', 'white', ...
    'EdgeColor', 'black', ...
    'FitBoxToText', 'on');

%% Save PDF if requested
if opts.save_pdf
    if isempty(opts.pdf_filename)
        pdf_filename = sprintf('%s_%d_of_%d_panel_arena.pdf', ...
            upper(panel_type), length(opts.panels_installed), num_panels);
    else
        pdf_filename = opts.pdf_filename;
    end

    set(fig_handle, 'PaperPositionMode', 'auto');
    print(fig_handle, pdf_filename, '-dpdf', '-bestfit');
    fprintf('Saved: %s\n', pdf_filename);
end

%% Prepare output struct
arena_info = struct();
arena_info.c_radius = c_radius;
arena_info.back_c_radius = back_c_radius;
arena_info.degs_per_pixel = degs_per_pixel;
arena_info.azimuth_coverage = azimuth_coverage;
arena_info.azimuth_gap = azimuth_gap;
arena_info.units = unit_label;
arena_info.panel_specs = panel_specs;
arena_info.num_panels = num_panels;
arena_info.num_rows = opts.num_rows;
arena_info.panels_installed = opts.panels_installed;
arena_info.angle_offset = opts.angle_offset;
arena_info.column_order = opts.column_order;
arena_info.config = config;  % Include original config

end

%% Helper function: Get panel specifications
function specs = get_panel_specs(panel_type)
    % Panel specifications database
    % Sources:
    %   G6: KiCad files from https://github.com/iorodeo/LED-Display_G6_Hardware_Panel
    %   G4/G4.1/G5: Historical measurements from arena layout scripts
    %   G3: Legacy panel specifications

    panel_db = struct();

    % G3 - Legacy 32mm panels
    panel_db.G3.panel_width_mm = 32;
    panel_db.G3.panel_depth_mm = 18;      % ~0.7 inches
    panel_db.G3.pixels_per_panel = 8;
    panel_db.G3.num_pins = 8;
    panel_db.G3.pin_dist_mm = 15.24;      % ~0.6 inches
    panel_db.G3.pin_spacing_mm = 2.54;
    panel_db.G3.pin_config = 'single';
    panel_db.G3.pins_to_plot = [];

    % G4 - 40.45mm panels (original G4)
    panel_db.G4.panel_width_mm = 40.45;
    panel_db.G4.panel_depth_mm = 18;      % ~0.7 inches
    panel_db.G4.pixels_per_panel = 16;
    panel_db.G4.num_pins = 15;
    panel_db.G4.pin_dist_mm = 13;         % ~0.51 inches
    panel_db.G4.pin_spacing_mm = 2.54;
    panel_db.G4.pin_config = 'single';
    panel_db.G4.pins_to_plot = [];

    % G4.1 - 40mm panels (thinner, updated design)
    % Also known as "G41" in some contexts
    panel_db.G41.panel_width_mm = 40;
    panel_db.G41.panel_depth_mm = 6.35;   % ~0.25 inches (thinner)
    panel_db.G41.pixels_per_panel = 16;
    panel_db.G41.num_pins = 15;
    panel_db.G41.pin_dist_mm = 4.57;      % ~0.18 inches
    panel_db.G41.pin_spacing_mm = 2.54;
    panel_db.G41.pin_config = 'single';
    panel_db.G41.pins_to_plot = [];

    % G5 - DEPRECATED (removed from supported types)
    % G5 panels are no longer functional and not supported

    % G6 - 45.4mm panels with 20x20 pixels, dual 5-pin headers
    % Dimensions from KiCad: board outline (49.8,49.8) to (95.2,95.2) = 45.4mm
    % Headers: J2/J3 at y=90.135 (bottom), J4/J5 at y=53.9 (top)
    %          J2/J4 at x=87.9 (right), J3/J5 at x=57.1 (left)
    % Header separation: 30.8mm between left/right headers
    panel_db.G6.panel_width_mm = 45.4;
    panel_db.G6.panel_depth_mm = 3.45;    % Estimated from comment in original
    panel_db.G6.pixels_per_panel = 20;
    panel_db.G6.num_pins = 10;            % 2 x 5-pin headers
    panel_db.G6.pin_dist_mm = 4.57;       % ~0.18 inches (estimated)
    panel_db.G6.pin_spacing_mm = 2.54;
    panel_db.G6.pin_config = 'dual';
    panel_db.G6.header_separation_mm = 30.8;  % Distance between the two headers
    panel_db.G6.pins_to_plot = [1:5];     % Plot 5 pins per header (will be mirrored)

    % Lookup panel type
    type_upper = upper(strrep(panel_type, '.', ''));

    if isfield(panel_db, type_upper)
        specs = panel_db.(type_upper);
    elseif strcmpi(type_upper, 'G5')
        error('G5 panels are deprecated and no longer supported. Use G6 for 20x20 pixel panels.');
    else
        error('Unknown panel type: %s. Valid types: G3, G4, G4.1, G6', panel_type);
    end

    specs.panel_type = panel_type;
end

%% Helper function: Draw pins
function draw_pins(c_radius, pin_dist, alpha_j, P_angle_j, panel_specs, pin_spacing, opts)

    if strcmpi(panel_specs.pin_config, 'dual')
        % Dual header configuration (G6)
        % Two separate 5-pin headers on each side of the panel
        header_sep = panel_specs.header_separation_mm;
        if strcmpi(opts.units, 'inches')
            header_sep = header_sep / 25.4;
        end

        pins_per_header = 5;
        pin_width_single = (pins_per_header - 1) * pin_spacing;

        % Left header (offset from center)
        offset_left = -header_sep/2;
        P_center = [(c_radius + pin_dist)*cos(alpha_j), (c_radius + pin_dist)*sin(alpha_j)];

        % Offset perpendicular to radial direction
        P_center_left = [P_center(1) + offset_left*cos(P_angle_j), P_center(2) + offset_left*sin(P_angle_j)];

        P_left = zeros(pins_per_header, 2);
        P_left(1,:) = [P_center_left(1) - pin_width_single/2*cos(P_angle_j), ...
                       P_center_left(2) - pin_width_single/2*sin(P_angle_j)];
        for i = 2:pins_per_header
            P_left(i,:) = [P_left(i-1,1) + pin_spacing*cos(P_angle_j), ...
                           P_left(i-1,2) + pin_spacing*sin(P_angle_j)];
        end
        plot(P_left(:,1), P_left(:,2), '.k', 'MarkerSize', 8);

        % Right header
        offset_right = header_sep/2;
        P_center_right = [P_center(1) + offset_right*cos(P_angle_j), P_center(2) + offset_right*sin(P_angle_j)];

        P_right = zeros(pins_per_header, 2);
        P_right(1,:) = [P_center_right(1) - pin_width_single/2*cos(P_angle_j), ...
                        P_center_right(2) - pin_width_single/2*sin(P_angle_j)];
        for i = 2:pins_per_header
            P_right(i,:) = [P_right(i-1,1) + pin_spacing*cos(P_angle_j), ...
                            P_right(i-1,2) + pin_spacing*sin(P_angle_j)];
        end
        plot(P_right(:,1), P_right(:,2), '.k', 'MarkerSize', 8);

    else
        % Single header configuration (G3, G4, G4.1, G5)
        num_pins = panel_specs.num_pins;
        pin_width = (num_pins - 1) * pin_spacing;

        P = zeros(num_pins, 2);
        P_center = [(c_radius + pin_dist)*cos(alpha_j), (c_radius + pin_dist)*sin(alpha_j)];
        P(1,:) = [P_center(1) - pin_width/2*cos(P_angle_j), P_center(2) - pin_width/2*sin(P_angle_j)];

        for i = 2:num_pins
            P(i,:) = [P(i-1,1) + pin_spacing*cos(P_angle_j), P(i-1,2) + pin_spacing*sin(P_angle_j)];
        end

        % Plot all pins or selected pins
        if ~isempty(panel_specs.pins_to_plot)
            plot(P(panel_specs.pins_to_plot, 1), P(panel_specs.pins_to_plot, 2), '.k', 'MarkerSize', 8);
        else
            plot(P(:,1), P(:,2), '.k', 'MarkerSize', 8);
        end
    end
end


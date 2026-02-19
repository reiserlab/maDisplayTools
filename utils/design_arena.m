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
% Column Order Convention:
%   'cw'  - Clockwise: c0 is just LEFT of south, columns increase CCW
%           (G6 default, matches G6 protocol document)
%   'ccw' - Counter-clockwise: c0 is just RIGHT of south, columns increase CW
%           (G4.1 historical default, mirror image of CW)
%   In both cases, the c0/cN-1 boundary is at south (straight down, -Y axis)
%
% Examples:
%   % From YAML config struct
%   config = load_arena_config('configs/arenas/G6_2x10.yaml');
%   design_arena(config);
%
%   % Directly from YAML file path
%   design_arena('configs/arenas/G6_2x10.yaml');
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

% columns_installed (convert from 0-indexed to 1-indexed for rendering)
if isfield(arena, 'columns_installed') && ~isempty(arena.columns_installed)
    columns_0idx = arena.columns_installed;
    columns_installed = columns_0idx + 1;  % Convert to 1-indexed for rendering
else
    columns_installed = 1:num_panels;
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
opts.columns_installed = columns_installed;
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

% Angular positions - c0/cN-1 boundary at south (-pi/2)
% CW: c0 just LEFT of south (CCW from S), columns increase counter-clockwise
% CCW: c0 just RIGHT of south (CW from S), columns increase clockwise (mirror)
% Offset by half a panel so c0 starts at the boundary, not centered on south
half_panel = alpha / 2;

if strcmpi(opts.column_order, 'cw')
    % CW order: c0 starts just LEFT of south, columns increase CCW (going left)
    start_angle = -pi/2 - half_panel;  % c0 center is just right of south line
    alphas = start_angle - (0:num_panels-1) * alpha + opts.angle_offset;
else
    % CCW order: c0 starts just RIGHT of south, columns increase CW (going right)
    start_angle = -pi/2 + half_panel;  % c0 center is just left of south line
    alphas = start_angle + (0:num_panels-1) * alpha + opts.angle_offset;
end
P_angle = alphas + pi/2;

% Resolution and coverage calculations
degs_per_pixel = 360 / (num_panels * panel_specs.pixels_per_panel);
azimuth_coverage = 360 * (length(opts.columns_installed) / num_panels);
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
for j = opts.columns_installed
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

%% Draw column labels outside the ring
label_radius = back_c_radius * 1.15;  % Position labels outside the panels
label_color = [0 0.53 0.48];  % Teal color matching G6 protocol doc

for j = 1:num_panels
    % Only label installed columns
    if ismember(j, opts.columns_installed)
        label_x = label_radius * cos(alphas(j));
        label_y = label_radius * sin(alphas(j));
        col_num = j - 1;  % Convert to 0-indexed column number
        text(label_x, label_y, sprintf('c%d', col_num), ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'FontSize', 9, ...
            'FontWeight', 'bold', ...
            'Color', 'white', ...
            'BackgroundColor', label_color, ...
            'Margin', 2, ...
            'EdgeColor', label_color);
    end
end

%% Draw compass indicators
compass_radius = fig_size * 0.95;
text(0, compass_radius, 'N', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'bottom', 'FontSize', 12, 'FontWeight', 'bold');
text(0, -compass_radius, 'S', 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'top', 'FontSize', 12, 'FontWeight', 'bold');

%% Format figure
axis equal;
lim = fig_size * 1.05;
xlim([-lim lim]);
ylim([-lim lim]);
grid on;

% Title with arena info
title_str = sprintf('%d of %d Panel (%s) ring, in %s; resolution of %.1f%s per pixel', ...
    length(opts.columns_installed), num_panels, upper(panel_type), ...
    unit_label, degs_per_pixel, char(176));
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
            upper(panel_type), length(opts.columns_installed), num_panels);
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
arena_info.columns_installed = opts.columns_installed;
arena_info.angle_offset = opts.angle_offset;
arena_info.column_order = opts.column_order;
arena_info.config = config;  % Include original config

end

%% Helper function: Get panel specifications
function specs = get_panel_specs(panel_type)
    % Get panel specs from single source of truth
    specs = get_generation_specs(panel_type);
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


%% Generate Web Reference Data
% This script generates reference data for validating the web arena editor.
% Output: docs/arena-designs/reference_data.json
%
% Author: Reiser Lab

%% Setup
close all;
clear;

if ~exist('design_arena', 'file')
    addpath(fileparts(mfilename('fullpath')));
end

output_folder = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'docs', 'arena-designs');
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

%% Define test configurations (full arenas only for validation)
configs = {
    % Type, num_panels (full ring)
    'G3', 12;
    'G3', 24;
    'G4', 12;
    'G4', 18;
    'G4.1', 12;
    'G4.1', 18;
    'G5', 8;
    'G6', 8;
    'G6', 10;
    'G6', 12;
    'G6', 18;
};

%% Generate reference data
reference_data = struct();
reference_data.generated = datestr(now, 'yyyy-mm-dd HH:MM:SS');
reference_data.source = 'MATLAB design_arena.m';
reference_data.arenas = {};

fprintf('Generating reference data for %d configurations...\n\n', size(configs, 1));

for i = 1:size(configs, 1)
    ptype = configs{i, 1};
    npanels = configs{i, 2};

    % Generate arena (full ring)
    [info, fig] = design_arena(ptype, npanels, 'figure_visible', 'off');
    close(fig);

    % Create arena record
    arena = struct();
    arena.panel_type = ptype;
    arena.num_panels = npanels;
    arena.panels_installed = info.panels_installed;

    % Geometry (store in both units for convenience)
    arena.c_radius_inches = info.c_radius;
    arena.c_radius_mm = info.c_radius * 25.4;
    arena.back_c_radius_inches = info.back_c_radius;
    arena.back_c_radius_mm = info.back_c_radius * 25.4;

    % Resolution
    arena.degs_per_pixel = info.degs_per_pixel;
    arena.azimuthal_pixels = npanels * info.panel_specs.pixels_per_panel;

    % Coverage
    arena.azimuth_coverage = info.azimuth_coverage;
    arena.azimuth_gap = info.azimuth_gap;

    % Panel specs
    arena.panel_width_mm = info.panel_specs.panel_width_mm;
    arena.panel_depth_mm = info.panel_specs.panel_depth_mm;
    arena.pixels_per_panel = info.panel_specs.pixels_per_panel;

    reference_data.arenas{end+1} = arena;

    fprintf('%-6s %2d panels: r=%.3f in, %.2f deg/px, %d pixels\n', ...
        ptype, npanels, arena.c_radius_inches, arena.degs_per_pixel, arena.azimuthal_pixels);
end

%% Also store panel specifications for the web app
panel_specs = struct();

panel_specs.G3.panel_width_mm = 32;
panel_specs.G3.panel_depth_mm = 18;
panel_specs.G3.pixels_per_panel = 8;
panel_specs.G3.num_pins = 8;
panel_specs.G3.pin_dist_mm = 15.24;
panel_specs.G3.pin_config = 'single';

panel_specs.G4.panel_width_mm = 40.45;
panel_specs.G4.panel_depth_mm = 18;
panel_specs.G4.pixels_per_panel = 16;
panel_specs.G4.num_pins = 15;
panel_specs.G4.pin_dist_mm = 13;
panel_specs.G4.pin_config = 'single';

panel_specs.G41.panel_width_mm = 40;
panel_specs.G41.panel_depth_mm = 6.35;
panel_specs.G41.pixels_per_panel = 16;
panel_specs.G41.num_pins = 15;
panel_specs.G41.pin_dist_mm = 4.57;
panel_specs.G41.pin_config = 'single';

panel_specs.G5.panel_width_mm = 40;
panel_specs.G5.panel_depth_mm = 6.35;
panel_specs.G5.pixels_per_panel = 20;
panel_specs.G5.num_pins = 10;
panel_specs.G5.pin_dist_mm = 4.57;
panel_specs.G5.pin_config = 'single';

panel_specs.G6.panel_width_mm = 45.4;
panel_specs.G6.panel_depth_mm = 3.45;
panel_specs.G6.pixels_per_panel = 20;
panel_specs.G6.num_pins = 10;
panel_specs.G6.pin_dist_mm = 4.57;
panel_specs.G6.pin_config = 'dual';
panel_specs.G6.header_separation_mm = 30.8;

reference_data.panel_specs = panel_specs;

%% Write JSON file
json_path = fullfile(output_folder, 'reference_data.json');
json_str = jsonencode(reference_data);

% Pretty print (add newlines after braces/brackets for readability)
json_str = strrep(json_str, ',"', sprintf(',\n"'));
json_str = strrep(json_str, '{', sprintf('{\n'));
json_str = strrep(json_str, '}', sprintf('\n}'));
json_str = strrep(json_str, '[{', sprintf('[\n{'));
json_str = strrep(json_str, '}]', sprintf('}\n]'));

fid = fopen(json_path, 'w');
fprintf(fid, '%s', json_str);
fclose(fid);

fprintf('\nReference data saved to: %s\n', json_path);

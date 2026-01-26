function generate_baseline_patterns()
% GENERATE_BASELINE_PATTERNS - Create reference patterns for validation
%
% This script generates baseline patterns using the original G4_Pattern_Generator
% BEFORE any refactoring. These patterns serve as reference for validating
% that the multi-generation update produces identical output.
%
% Run this from the maDisplayTools directory with G4_Display_Tools on path.
%
% Generates 5 pattern types:
%   1. Square grating (30 deg spatial freq, 3 deg step)
%   2. Sine grating (45 deg spatial freq, 2 deg step)
%   3. Edge (5 deg step)
%   4. Starfield (100 dots, 5 deg radius)
%   5. Off-on (simple toggle)

%% Setup paths
thisDir = fileparts(mfilename('fullpath'));
baselineDir = fullfile(thisDir, 'pattern_baseline');

% Check for G4_Display_Tools on path
if ~exist('G4_Pattern_Generator', 'file')
    error(['G4_Display_Tools not on path. Add it with:\n' ...
           '  addpath(genpath(''/path/to/G4_Display_Tools''))']);
end

% Create output directory
if ~exist(baselineDir, 'dir')
    mkdir(baselineDir);
end

%% Setup arena configuration (standard G4 3x12)
% Create handles struct that G4_Pattern_Generator expects
handles.arena_folder = fullfile(baselineDir, 'arena');
handles.arena_file = 'arena_parameters.mat';

if ~exist(handles.arena_folder, 'dir')
    mkdir(handles.arena_folder);
end

% Generate default G4 arena coordinates (3 rows, 12 cols, 16 pixels/panel)
arena_fullfile = fullfile(handles.arena_folder, handles.arena_file);
arena_coordinates(16, 12, 3, 18, 0, 'poly', [0 0 0], [0 0 0], arena_fullfile);
fprintf('Created arena configuration: %s\n', arena_fullfile);

%% Common parameters for all patterns
base_param = struct();
base_param.gs_val = 4;                  % 4-bit grayscale
base_param.levels = [15 0 7];           % [high, low, background]
base_param.pole_coord = [0 0];          % Pattern pole at center
base_param.motion_angle = 0;            % Rightward motion
base_param.arena_pitch = 0;             % No pitch
base_param.sa_mask = [0 0 pi 0];        % No solid angle mask
base_param.long_lat_mask = [-pi pi -pi/2 pi/2 0]; % No lat/long mask
base_param.aa_samples = 15;             % Anti-aliasing samples
base_param.aa_poles = 1;                % Anti-alias poles
base_param.back_frame = 0;              % No background frame
base_param.flip_right = 0;              % Don't flip right half
base_param.phase_shift = 0;             % No phase shift
base_param.checker_layout = 0;          % Standard layout
base_param.dot_size = 'static';         % For starfield
base_param.dot_occ = 'closest';         % For starfield
base_param.dot_re_random = 1;           % Randomize dots
base_param.dot_level = 0;               % Fixed dot brightness
base_param.snap_dots = 0;               % Don't snap dots
base_param.num_dots = 100;              % For starfield
base_param.dot_radius = deg2rad(5);     % For starfield
base_param.duty_cycle = 50;             % For gratings

%% Generate patterns

% 1. Square grating
fprintf('\n--- Generating square grating ---\n');
param = base_param;
param.pattern_type = 'square grating';
param.motion_type = 'rotation';
param.pattern_fov = 'full-field';
param.spat_freq = deg2rad(30);
param.step_size = deg2rad(3);
handles.param = param;

[Pats_square, true_step, rot180] = G4_Pattern_Generator(handles);
baseline.square_grating.Pats = Pats_square;
baseline.square_grating.param = param;
baseline.square_grating.true_step_size = true_step;
baseline.square_grating.rot180 = rot180;
fprintf('  Generated %d frames, size [%d x %d]\n', size(Pats_square,3), size(Pats_square,1), size(Pats_square,2));

% 2. Sine grating
fprintf('\n--- Generating sine grating ---\n');
param = base_param;
param.pattern_type = 'sine grating';
param.motion_type = 'rotation';
param.pattern_fov = 'full-field';
param.spat_freq = deg2rad(45);
param.step_size = deg2rad(2);
handles.param = param;

[Pats_sine, true_step, rot180] = G4_Pattern_Generator(handles);
baseline.sine_grating.Pats = Pats_sine;
baseline.sine_grating.param = param;
baseline.sine_grating.true_step_size = true_step;
baseline.sine_grating.rot180 = rot180;
fprintf('  Generated %d frames, size [%d x %d]\n', size(Pats_sine,3), size(Pats_sine,1), size(Pats_sine,2));

% 3. Edge
fprintf('\n--- Generating edge ---\n');
param = base_param;
param.pattern_type = 'edge';
param.motion_type = 'rotation';
param.pattern_fov = 'full-field';
param.spat_freq = deg2rad(360);  % Full rotation for edge
param.step_size = deg2rad(5);
handles.param = param;

[Pats_edge, true_step, rot180] = G4_Pattern_Generator(handles);
baseline.edge.Pats = Pats_edge;
baseline.edge.param = param;
baseline.edge.true_step_size = true_step;
baseline.edge.rot180 = rot180;
fprintf('  Generated %d frames, size [%d x %d]\n', size(Pats_edge,3), size(Pats_edge,1), size(Pats_edge,2));

% 4. Starfield
fprintf('\n--- Generating starfield ---\n');
param = base_param;
param.pattern_type = 'starfield';
param.motion_type = 'rotation';
param.pattern_fov = 'full-field';
param.spat_freq = deg2rad(360);
param.step_size = deg2rad(3);
param.num_dots = 100;
param.dot_radius = deg2rad(5);
handles.param = param;

% Set random seed for reproducibility
rng(42);
[Pats_star, true_step, rot180] = G4_Pattern_Generator(handles);
baseline.starfield.Pats = Pats_star;
baseline.starfield.param = param;
baseline.starfield.true_step_size = true_step;
baseline.starfield.rot180 = rot180;
fprintf('  Generated %d frames, size [%d x %d]\n', size(Pats_star,3), size(Pats_star,1), size(Pats_star,2));

% 5. Off-on
fprintf('\n--- Generating off-on ---\n');
param = base_param;
param.pattern_type = 'off-on';
param.motion_type = 'rotation';  % Not really used for off-on
param.pattern_fov = 'full-field';
param.spat_freq = deg2rad(360);
param.step_size = deg2rad(1);    % Not really used for off-on
handles.param = param;

[Pats_offon, true_step, rot180] = G4_Pattern_Generator(handles);
baseline.off_on.Pats = Pats_offon;
baseline.off_on.param = param;
baseline.off_on.true_step_size = true_step;
baseline.off_on.rot180 = rot180;
fprintf('  Generated %d frames, size [%d x %d]\n', size(Pats_offon,3), size(Pats_offon,1), size(Pats_offon,2));

%% Save baseline data
baseline.generation = 'G4';
baseline.created = datestr(now, 'yyyy-mm-dd HH:MM:SS');
baseline.matlab_version = version;

baselineFile = fullfile(baselineDir, 'baseline_patterns.mat');
save(baselineFile, 'baseline', '-v7.3');
fprintf('\n=== Saved baseline to: %s ===\n', baselineFile);

%% Also save as YAML for documentation
yamlFile = fullfile(baselineDir, 'baseline_parameters.yaml');
fid = fopen(yamlFile, 'w');
fprintf(fid, '# Baseline pattern parameters for validation\n');
fprintf(fid, '# Generated: %s\n', baseline.created);
fprintf(fid, '# MATLAB version: %s\n\n', baseline.matlab_version);

fprintf(fid, 'generation: G4\n');
fprintf(fid, 'arena:\n');
fprintf(fid, '  pixels_per_panel: 16\n');
fprintf(fid, '  num_rows: 3\n');
fprintf(fid, '  num_cols: 12\n');
fprintf(fid, '  panels_in_circle: 18\n\n');

fprintf(fid, 'common_parameters:\n');
fprintf(fid, '  gs_val: 4\n');
fprintf(fid, '  levels: [15, 0, 7]\n');
fprintf(fid, '  aa_samples: 15\n\n');

patterns = {'square_grating', 'sine_grating', 'edge', 'starfield', 'off_on'};
for i = 1:length(patterns)
    pname = patterns{i};
    p = baseline.(pname).param;
    fprintf(fid, '%s:\n', pname);
    fprintf(fid, '  pattern_type: "%s"\n', p.pattern_type);
    fprintf(fid, '  motion_type: "%s"\n', p.motion_type);
    fprintf(fid, '  spat_freq_deg: %.1f\n', rad2deg(p.spat_freq));
    fprintf(fid, '  step_size_deg: %.1f\n', rad2deg(p.step_size));
    fprintf(fid, '  num_frames: %d\n', size(baseline.(pname).Pats, 3));
    if strcmp(pname, 'starfield')
        fprintf(fid, '  num_dots: %d\n', p.num_dots);
        fprintf(fid, '  dot_radius_deg: %.1f\n', rad2deg(p.dot_radius));
        fprintf(fid, '  random_seed: 42\n');
    end
    fprintf(fid, '\n');
end

fclose(fid);
fprintf('Saved parameters to: %s\n', yamlFile);

fprintf('\n=== Baseline generation complete ===\n');

end

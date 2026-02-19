%% visualize_standard_arenas.m - Visualize all standard arena configurations
%
% This script loads each standard arena YAML config and visualizes it
% using design_arena.m to verify the configurations are correct.
%
% Usage:
%   >> cd /path/to/maDisplayTools
%   >> visualize_standard_arenas
%
% Each arena will be displayed in a separate figure window.

%% Setup paths
[script_dir, ~, ~] = fileparts(mfilename('fullpath'));
project_root = fileparts(script_dir);

% Ensure required folders are on path
addpath(fullfile(project_root, 'utils'));
addpath(fullfile(project_root, 'yamlSupport'));

fprintf('\n');
fprintf('========================================\n');
fprintf('Standard Arena Visualizations\n');
fprintf('========================================\n\n');

%% Get all arena config files
arena_dir = fullfile(project_root, 'configs', 'arenas');
arena_files = dir(fullfile(arena_dir, '*.yaml'));

if isempty(arena_files)
    error('No arena config files found in: %s', arena_dir);
end

fprintf('Found %d arena configurations\n\n', length(arena_files));

%% Visualize each arena
for i = 1:length(arena_files)
    filepath = fullfile(arena_files(i).folder, arena_files(i).name);
    fprintf('Loading: %s\n', arena_files(i).name);

    try
        % Visualize directly from YAML file - design_arena handles everything
        [arena_info, fig] = design_arena(filepath);

        % Get config from output for display
        config = arena_info.config;

        % Create figure title
        fig_title = sprintf('%s: %s %dx%d (%s)', ...
            config.name, config.arena.generation, ...
            config.arena.num_rows, config.arena.num_cols, ...
            upper(config.arena.column_order));
        set(fig, 'Name', fig_title, 'NumberTitle', 'off');

        % Print summary
        fprintf('  Generation: %s\n', config.arena.generation);
        fprintf('  Grid: %d rows x %d cols\n', config.arena.num_rows, config.arena.num_cols);
        fprintf('  Column order: %s\n', config.arena.column_order);
        fprintf('  Pixels: %d x %d\n', config.derived.total_pixels_x, config.derived.total_pixels_y);
        fprintf('  Inner radius: %.1f mm\n', config.derived.inner_radius_mm);
        fprintf('  Panels installed: %d of %d\n', ...
            config.derived.num_panels_installed, config.derived.num_panels);
        fprintf('\n');

    catch ME
        fprintf('  ERROR: %s\n\n', ME.message);
    end
end

fprintf('========================================\n');
fprintf('Visualization complete!\n');
fprintf('========================================\n');

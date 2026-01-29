%% test_arena_config.m - Test the hierarchical YAML config system
%
% Run this script to verify the arena config loading functions work correctly.
%
% Prerequisites:
%   - yamlSupport folder on path (contains yamlread.m using SnakeYAML)
%
% Usage:
%   >> cd /path/to/maDisplayTools
%   >> addpath('utils', 'configs', 'experimentExecution', 'yamlSupport')
%   >> test_arena_config
%
% Expected output: All tests should pass with green checkmarks

%% Determine project root and set up paths
[script_dir, ~, ~] = fileparts(mfilename('fullpath'));
project_root = fileparts(script_dir);  % Go up from testing/

% Ensure yamlSupport is on the path
if ~exist('yamlread', 'file')
    yaml_support_path = fullfile(project_root, 'yamlSupport');
    if exist(yaml_support_path, 'dir')
        addpath(yaml_support_path);
        fprintf('Added yamlSupport to path: %s\n', yaml_support_path);
    else
        error(['yamlSupport not found. Please add it to the MATLAB path:\n' ...
               '  addpath(''yamlSupport'')']);
    end
end

% Ensure utils is on the path
if ~exist('load_arena_config', 'file')
    utils_path = fullfile(project_root, 'utils');
    addpath(utils_path);
    fprintf('Added utils to path: %s\n', utils_path);
end

% Helper to get absolute path from project-relative path
get_path = @(rel) fullfile(project_root, rel);

fprintf('\n');
fprintf('========================================\n');
fprintf('Arena Config System Tests\n');
fprintf('========================================\n\n');

% Track test results
tests_passed = 0;
tests_failed = 0;

%% Test 1: Load a standard arena config
fprintf('Test 1: Load standard arena config (G6_2x10.yaml)\n');
try
    config = load_arena_config(get_path('configs/arenas/G6_2x10.yaml'));

    % Verify expected values
    assert(strcmp(config.arena.generation, 'G6'), 'Generation should be G6');
    assert(config.arena.num_rows == 2, 'num_rows should be 2');
    assert(config.arena.num_cols == 10, 'num_cols should be 10');
    assert(strcmp(config.arena.column_order, 'cw'), 'column_order should be cw');
    assert(config.derived.pixels_per_panel == 20, 'pixels_per_panel should be 20');
    assert(config.derived.total_pixels_x == 200, 'total_pixels_x should be 200');
    assert(config.derived.total_pixels_y == 40, 'total_pixels_y should be 40');

    fprintf('  ✓ Arena loaded successfully\n');
    fprintf('  ✓ Generation: %s\n', config.arena.generation);
    fprintf('  ✓ Grid: %dx%d panels = %dx%d pixels\n', ...
        config.arena.num_rows, config.arena.num_cols, ...
        config.derived.total_pixels_x, config.derived.total_pixels_y);
    fprintf('  ✓ Inner radius: %.2f mm\n', config.derived.inner_radius_mm);
    tests_passed = tests_passed + 1;
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    tests_failed = tests_failed + 1;
end
fprintf('\n');

%% Test 2: Load G4.1 arena with CCW column order
fprintf('Test 2: Load G4.1 arena with CCW column order\n');
try
    config = load_arena_config(get_path('configs/arenas/G41_2x12_ccw.yaml'));

    assert(strcmp(config.arena.generation, 'G4.1'), 'Generation should be G4.1');
    assert(strcmp(config.arena.column_order, 'ccw'), 'column_order should be ccw');
    assert(config.derived.pixels_per_panel == 16, 'pixels_per_panel should be 16');

    fprintf('  ✓ G4.1 arena loaded\n');
    fprintf('  ✓ Column order: %s\n', config.arena.column_order);
    tests_passed = tests_passed + 1;
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    tests_failed = tests_failed + 1;
end
fprintf('\n');

%% Test 3: Load partial arena (G6 walking arena with missing columns)
fprintf('Test 3: Load partial arena (G6_2x8of10.yaml)\n');
try
    config = load_arena_config(get_path('configs/arenas/G6_2x8of10.yaml'));

    assert(config.arena.num_cols == 10, 'num_cols should be 10 (grid size)');
    assert(~isempty(config.arena.columns_installed), 'columns_installed should not be empty');
    assert(config.derived.num_columns_installed == 8, 'Should have 8 columns installed');
    assert(config.derived.num_panels_installed == 16, 'Should have 16 panels installed');
    assert(config.derived.num_panels == 20, 'Total panel slots should be 20');
    assert(config.derived.total_pixels_x == 160, 'total_pixels_x should be 160 (8 cols * 20 px)');

    fprintf('  ✓ Partial arena loaded\n');
    fprintf('  ✓ Columns installed: %d of %d\n', ...
        config.derived.num_columns_installed, config.arena.num_cols);
    fprintf('  ✓ Panels installed: %d of %d\n', ...
        config.derived.num_panels_installed, config.derived.num_panels);
    tests_passed = tests_passed + 1;
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    tests_failed = tests_failed + 1;
end
fprintf('\n');

%% Test 4: Load rig config with arena resolution
fprintf('Test 4: Load rig config (example_rig.yaml)\n');
try
    config = load_rig_config(get_path('configs/rigs/example_rig.yaml'));

    % Check rig fields
    assert(~isempty(config.name), 'Rig should have a name');
    assert(~isempty(config.controller.host), 'Controller host should be set');
    assert(config.controller.port == 62222, 'Controller port should be 62222');

    % Check arena was resolved
    assert(isfield(config, 'arena'), 'Arena should be resolved');
    assert(strcmp(config.arena.generation, 'G4.1'), 'Arena generation should be G4.1');
    assert(~isempty(config.arena_file), 'Arena file path should be stored');

    fprintf('  ✓ Rig config loaded: %s\n', config.name);
    fprintf('  ✓ Controller: %s:%d\n', config.controller.host, config.controller.port);
    fprintf('  ✓ Arena resolved: %s\n', config.arena.generation);
    fprintf('  ✓ Arena file: %s\n', config.arena_file);
    tests_passed = tests_passed + 1;
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    tests_failed = tests_failed + 1;
end
fprintf('\n');

%% Test 5: show_resolved_config output
fprintf('Test 5: show_resolved_config display\n');
try
    config = load_arena_config(get_path('configs/arenas/G6_2x10.yaml'));
    fprintf('--- Output from show_resolved_config ---\n');
    show_resolved_config(config);
    fprintf('--- End output ---\n');
    fprintf('  ✓ show_resolved_config executed without error\n');
    tests_passed = tests_passed + 1;
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    tests_failed = tests_failed + 1;
end
fprintf('\n');

%% Test 6: Verify G5 is rejected
fprintf('Test 6: Verify G5 generation is rejected\n');
try
    % Create a temporary G5 config to test rejection
    temp_file = tempname;
    temp_file = [temp_file '.yaml'];
    fid = fopen(temp_file, 'w');
    fprintf(fid, 'format_version: "1.0"\n');
    fprintf(fid, 'name: "test_g5"\n');
    fprintf(fid, 'arena:\n');
    fprintf(fid, '  generation: "G5"\n');
    fprintf(fid, '  num_rows: 2\n');
    fprintf(fid, '  num_cols: 10\n');
    fclose(fid);

    % This should throw an error
    try
        config = load_arena_config(temp_file);
        fprintf('  ✗ FAILED: G5 should have been rejected\n');
        tests_failed = tests_failed + 1;
    catch ME
        if contains(ME.message, 'G5') || contains(ME.message, 'deprecated')
            fprintf('  ✓ G5 correctly rejected: %s\n', ME.message);
            tests_passed = tests_passed + 1;
        else
            fprintf('  ✗ FAILED: Wrong error: %s\n', ME.message);
            tests_failed = tests_failed + 1;
        end
    end

    % Clean up temp file
    delete(temp_file);
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    tests_failed = tests_failed + 1;
end
fprintf('\n');

%% Test 7: Load all standard arena configs
fprintf('Test 7: Load all standard arena configs\n');
arena_files = dir(get_path('configs/arenas/*.yaml'));
all_loaded = true;
for i = 1:length(arena_files)
    filepath = fullfile(arena_files(i).folder, arena_files(i).name);
    try
        config = load_arena_config(filepath);
        fprintf('  ✓ %s: %s %dx%d\n', arena_files(i).name, ...
            config.arena.generation, config.arena.num_rows, config.arena.num_cols);
    catch ME
        fprintf('  ✗ %s: %s\n', arena_files(i).name, ME.message);
        all_loaded = false;
    end
end
if all_loaded
    tests_passed = tests_passed + 1;
else
    tests_failed = tests_failed + 1;
end
fprintf('\n');

%% Test 8: Derived properties calculation
fprintf('Test 8: Verify derived properties calculations\n');
try
    % Test G6 inner radius calculation
    % Formula: inner_radius = panel_width / (2 * tan(pi / num_cols))
    config = load_arena_config(get_path('configs/arenas/G6_2x10.yaml'));

    expected_radius = 45.4 / (2 * tan(pi / 10));
    actual_radius = config.derived.inner_radius_mm;

    tolerance = 0.01;
    assert(abs(expected_radius - actual_radius) < tolerance, ...
        sprintf('Inner radius mismatch: expected %.2f, got %.2f', expected_radius, actual_radius));

    fprintf('  ✓ Inner radius calculation correct: %.2f mm\n', actual_radius);

    % Test G4.1 values
    config = load_arena_config(get_path('configs/arenas/G41_2x12_ccw.yaml'));
    assert(config.derived.total_pixels_x == 12 * 16, 'G4.1 total_pixels_x should be 192');
    assert(config.derived.total_pixels_y == 2 * 16, 'G4.1 total_pixels_y should be 32');

    fprintf('  ✓ G4.1 pixel calculations correct: %dx%d\n', ...
        config.derived.total_pixels_x, config.derived.total_pixels_y);

    tests_passed = tests_passed + 1;
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    tests_failed = tests_failed + 1;
end
fprintf('\n');

%% Summary
fprintf('========================================\n');
fprintf('Test Summary\n');
fprintf('========================================\n');
fprintf('Passed: %d\n', tests_passed);
fprintf('Failed: %d\n', tests_failed);
if tests_failed == 0
    fprintf('\n✓ All tests passed!\n');
else
    fprintf('\n✗ Some tests failed. Please review the output above.\n');
end
fprintf('========================================\n\n');

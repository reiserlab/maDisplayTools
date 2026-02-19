function results = validate_arena_config()
%VALIDATE_ARENA_CONFIG Test the hierarchical YAML arena config system
%
%   results = validate_arena_config() tests arena config loading, partial
%   arenas, rig config resolution, G5 rejection, derived properties, etc.
%
%   Returns:
%       results - struct with fields:
%           passed (logical): true if all tests passed
%           num_passed (int): number of tests passed
%           num_total (int): total number of tests
%           details (cell array): detailed results for each test
%
%   Example:
%       cd(project_root()); clear classes; addpath(genpath('.'));
%       results = validate_arena_config();

    fprintf('=== Arena Config Validation ===\n\n');

    project_dir = fileparts(fileparts(mfilename('fullpath')));
    get_path = @(rel) fullfile(project_dir, rel);

    num_tests = 8;
    test_results = false(num_tests, 1);
    test_details = cell(num_tests, 1);

    %% Test 1: Load standard arena config
    fprintf('Test 1: Load standard arena config (G6_2x10.yaml)\n');
    try
        config = load_arena_config(get_path('configs/arenas/G6_2x10.yaml'));
        assert(strcmp(config.arena.generation, 'G6'), 'Generation should be G6');
        assert(config.arena.num_rows == 2, 'num_rows should be 2');
        assert(config.arena.num_cols == 10, 'num_cols should be 10');
        assert(strcmp(config.arena.column_order, 'cw'), 'column_order should be cw');
        assert(config.derived.pixels_per_panel == 20, 'pixels_per_panel should be 20');
        assert(config.derived.total_pixels_x == 200, 'total_pixels_x should be 200');
        assert(config.derived.total_pixels_y == 40, 'total_pixels_y should be 40');
        test_results(1) = true;
        test_details{1} = 'G6_2x10 loaded: 200x40 px';
        fprintf('  PASS\n');
    catch ME
        test_details{1} = sprintf('G6_2x10 load failed: %s', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 2: G4.1 arena with CW column order
    fprintf('Test 2: Load G4.1 arena with CW column order\n');
    try
        config = load_arena_config(get_path('configs/arenas/G41_2x12_cw.yaml'));
        assert(strcmp(config.arena.generation, 'G4.1'), 'Generation should be G4.1');
        assert(strcmp(config.arena.column_order, 'cw'), 'column_order should be cw');
        assert(config.arena.angle_offset_deg == 15, 'angle_offset_deg should be 15');
        assert(config.derived.pixels_per_panel == 16, 'pixels_per_panel should be 16');
        test_results(2) = true;
        test_details{2} = 'G41_2x12_cw loaded: CW, 15 deg offset';
        fprintf('  PASS\n');
    catch ME
        test_details{2} = sprintf('G41 load failed: %s', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 3: Partial arena
    fprintf('Test 3: Load partial arena (G6_2x8of10.yaml)\n');
    try
        config = load_arena_config(get_path('configs/arenas/G6_2x8of10.yaml'));
        assert(config.arena.num_cols == 10, 'num_cols should be 10 (grid size)');
        assert(~isempty(config.arena.columns_installed), 'columns_installed should not be empty');
        assert(config.derived.num_columns_installed == 8, 'Should have 8 columns installed');
        assert(config.derived.num_panels_installed == 16, 'Should have 16 panels installed');
        assert(config.derived.num_panels == 20, 'Total panel slots should be 20');
        assert(config.derived.total_pixels_x == 160, 'total_pixels_x should be 160');
        test_results(3) = true;
        test_details{3} = 'G6_2x8of10 loaded: 8 of 10 cols, 160 px wide';
        fprintf('  PASS\n');
    catch ME
        test_details{3} = sprintf('Partial arena failed: %s', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 4: Rig config with arena resolution
    fprintf('Test 4: Load rig config (example_rig.yaml)\n');
    try
        config = load_rig_config(get_path('configs/rigs/example_rig.yaml'));
        assert(~isempty(config.name), 'Rig should have a name');
        assert(~isempty(config.controller.host), 'Controller host should be set');
        assert(config.controller.port == 62222, 'Controller port should be 62222');
        assert(isfield(config, 'arena'), 'Arena should be resolved');
        assert(strcmp(config.arena.generation, 'G4.1'), 'Arena generation should be G4.1');
        test_results(4) = true;
        test_details{4} = sprintf('Rig loaded: %s, arena resolved', config.name);
        fprintf('  PASS\n');
    catch ME
        test_details{4} = sprintf('Rig config failed: %s', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 5: show_resolved_config output
    fprintf('Test 5: show_resolved_config display\n');
    try
        config = load_arena_config(get_path('configs/arenas/G6_2x10.yaml'));
        show_resolved_config(config);
        test_results(5) = true;
        test_details{5} = 'show_resolved_config executed without error';
        fprintf('  PASS\n');
    catch ME
        test_details{5} = sprintf('show_resolved_config failed: %s', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 6: G5 rejection
    fprintf('Test 6: Verify G5 generation is rejected\n');
    try
        temp_file = [tempname '.yaml'];
        fid = fopen(temp_file, 'w');
        fprintf(fid, 'format_version: "1.0"\nname: "test_g5"\narena:\n  generation: "G5"\n  num_rows: 2\n  num_cols: 10\n');
        fclose(fid);
        try
            load_arena_config(temp_file);
            test_details{6} = 'G5 should have been rejected but was not';
            fprintf('  FAIL: G5 not rejected\n');
        catch ME
            if contains(ME.message, 'G5') || contains(ME.message, 'deprecated')
                test_results(6) = true;
                test_details{6} = sprintf('G5 correctly rejected: %s', ME.message);
                fprintf('  PASS\n');
            else
                test_details{6} = sprintf('Wrong error for G5: %s', ME.message);
                fprintf('  FAIL: wrong error\n');
            end
        end
        delete(temp_file);
    catch ME
        test_details{6} = sprintf('G5 test failed: %s', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 7: Load all standard arena configs
    fprintf('Test 7: Load all standard arena configs\n');
    arena_files = dir(get_path('configs/arenas/*.yaml'));
    all_loaded = true;
    names = {};
    for i = 1:length(arena_files)
        filepath = fullfile(arena_files(i).folder, arena_files(i).name);
        try
            config = load_arena_config(filepath);
            names{end+1} = arena_files(i).name; %#ok<AGROW>
        catch ME
            fprintf('  FAIL: %s: %s\n', arena_files(i).name, ME.message);
            all_loaded = false;
        end
    end
    if all_loaded
        test_results(7) = true;
        test_details{7} = sprintf('All %d arena configs loaded', length(arena_files));
        fprintf('  PASS: %d configs loaded\n', length(arena_files));
    else
        test_details{7} = 'Some arena configs failed to load';
    end

    %% Test 8: Derived properties calculation
    fprintf('Test 8: Verify derived properties calculations\n');
    try
        config = load_arena_config(get_path('configs/arenas/G6_2x10.yaml'));
        expected_radius = 45.4 / (2 * tan(pi / 10));
        actual_radius = config.derived.inner_radius_mm;
        assert(abs(expected_radius - actual_radius) < 0.01, ...
            sprintf('Inner radius mismatch: expected %.2f, got %.2f', expected_radius, actual_radius));

        config = load_arena_config(get_path('configs/arenas/G41_2x12_cw.yaml'));
        assert(config.derived.total_pixels_x == 192, 'G4.1 total_pixels_x should be 192');
        assert(config.derived.total_pixels_y == 32, 'G4.1 total_pixels_y should be 32');

        test_results(8) = true;
        test_details{8} = 'Derived properties correct (inner radius, pixel totals)';
        fprintf('  PASS\n');
    catch ME
        test_details{8} = sprintf('Derived properties failed: %s', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Summary
    num_passed = sum(test_results);
    fprintf('\n=== Summary ===\n');
    fprintf('Passed: %d / %d\n', num_passed, num_tests);

    if num_passed == num_tests
        fprintf('All tests PASSED!\n');
    else
        fprintf('FAILED tests:\n');
        for i = 1:num_tests
            if ~test_results(i)
                fprintf('  - Test %d: %s\n', i, test_details{i});
            end
        end
    end

    results = struct(...
        'passed', num_passed == num_tests, ...
        'num_passed', num_passed, ...
        'num_total', num_tests, ...
        'details', {test_details});
end

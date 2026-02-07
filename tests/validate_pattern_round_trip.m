function results = validate_pattern_round_trip()
%VALIDATE_PATTERN_ROUND_TRIP Test pattern generation → save → load → verify
%
%   results = validate_pattern_round_trip() tests the full workflow:
%   1. Generate patterns using Pattern_Generator
%   2. Save to disk
%   3. Load back
%   4. Verify pixel-identical match
%
%   Tests all generations (G4, G4.1, G6) × both grayscale modes (GS2, GS16)
%
%   Returns:
%       results - struct with fields:
%           passed (logical): true if all tests passed
%           num_passed (int): number of tests passed
%           num_total (int): total number of tests
%           details (cell array): detailed results for each test

    fprintf('=== Pattern Round-Trip Validation ===\n\n');

    % Get maDisplayTools root
    maDisplayToolsRoot = fileparts(fileparts(mfilename('fullpath')));

    % Create temp directory for test patterns
    tempDir = fullfile(maDisplayToolsRoot, 'tests', 'temp_roundtrip');
    % Clean up any previous run
    if exist(tempDir, 'dir')
        rmdir(tempDir, 's');
    end
    mkdir(tempDir);

    % Define test cases: [generation, arena_config, gs_val, test_name]
    test_cases = {
        'G4', 'G4_4x12.yaml', 2, 'G4 full arena GS2';
        'G4', 'G4_4x12.yaml', 16, 'G4 full arena GS16';
        'G41', 'G41_2x12_cw.yaml', 2, 'G4.1 treadmill GS2';
        'G41', 'G41_2x12_cw.yaml', 16, 'G4.1 treadmill GS16';
        'G6', 'G6_2x10.yaml', 2, 'G6 full arena GS2';
        'G6', 'G6_2x10.yaml', 16, 'G6 full arena GS16';
    };

    num_tests = size(test_cases, 1);
    test_results = false(num_tests, 1);
    test_details = cell(num_tests, 1);

    % Run tests
    for i = 1:num_tests
        generation = test_cases{i, 1};
        arena_yaml = test_cases{i, 2};
        gs_val = test_cases{i, 3};
        test_name = test_cases{i, 4};

        fprintf('Test %d/%d: %s... ', i, num_tests, test_name);

        try
            % Load arena config
            arena_config_path = fullfile(maDisplayToolsRoot, 'configs', 'arenas', arena_yaml);
            arena_config = load_arena_config(arena_config_path);

            % Get pixel dimensions from derived properties
            total_rows = arena_config.derived.total_pixels_y;
            total_cols = arena_config.derived.total_pixels_x;

            % Generate simple test pattern (grating)
            param = struct();
            param.x_num = 1;  % 1 frame
            param.gs_val = gs_val;
            param.stretch = 1;  % No stretch (1:1 mapping)
            param.arena_config = arena_config;
            param.generation = generation;  % Specify generation explicitly

            Pats = uint8(zeros(total_rows, total_cols, 1));
            % Create vertical stripes
            stripe_width = 10;
            for col = 1:total_cols
                if mod(floor((col-1)/stripe_width), 2) == 0
                    if gs_val == 2
                        Pats(:, col, 1) = 1;  % Binary: 0 or 1
                    else
                        Pats(:, col, 1) = 15;  % Grayscale: 0-15
                    end
                end
            end

            % Save pattern (include gs_val in name to avoid conflicts)
            gs_suffix = sprintf('gs%d', gs_val);
            pattern_name = sprintf('roundtrip_test_%s_%s_%s', generation, ...
                replace(arena_config.name, '.yaml', ''), gs_suffix);
            save_pattern(Pats, param, tempDir, pattern_name);

            % Load pattern back
            % G4.1 uses G4 suffix (line 131-132 in save_pattern.m)
            if strcmp(generation, 'G6')
                pattern_file = fullfile(tempDir, [pattern_name '_G6.pat']);
            elseif strcmp(generation, 'G41')
                pattern_file = fullfile(tempDir, [pattern_name '_G4.pat']);
            else
                pattern_file = fullfile(tempDir, [pattern_name '_' generation '.pat']);
            end

            [frames_loaded, meta] = maDisplayTools.load_pat(pattern_file);

            % Extract pattern from frames (frames are 4D: NumPatsY, NumPatsX, rows, cols)
            % For single-frame patterns: reshape to 3D (rows, cols, 1)
            Pats_loaded = squeeze(frames_loaded);
            if ndims(Pats_loaded) == 2
                Pats_loaded = reshape(Pats_loaded, [size(Pats_loaded), 1]);
            end

            % Verify dimensions match
            if ~isequal(size(Pats), size(Pats_loaded))
                error('Dimension mismatch: original %s vs loaded %s', ...
                    mat2str(size(Pats)), mat2str(size(Pats_loaded)));
            end

            % Verify grayscale mode matches (meta.vmax is 1 for binary, 15 for GS16)
            if gs_val == 2 || gs_val == 1
                expected_vmax = 1;
            else
                expected_vmax = 15;
            end
            if meta.vmax ~= expected_vmax
                error('Grayscale mode mismatch: expected vmax=%d, got vmax=%d', ...
                    expected_vmax, meta.vmax);
            end

            % Verify pixel values match exactly
            if ~isequal(Pats, Pats_loaded)
                max_diff = max(abs(double(Pats(:)) - double(Pats_loaded(:))));
                error('Pixel mismatch: max difference = %d', max_diff);
            end

            test_results(i) = true;
            test_details{i} = sprintf('%s: OK (%dx%d, gs=%d)', test_name, ...
                size(Pats, 1), size(Pats, 2), gs_val);
            fprintf('PASS\n');

        catch ME
            test_results(i) = false;
            test_details{i} = sprintf('%s: FAIL - %s', test_name, ME.message);
            fprintf('FAIL: %s\n', ME.message);
        end
    end

    % Clean up temp directory
    try
        rmdir(tempDir, 's');
    catch
        warning('Could not remove temp directory: %s', tempDir);
    end

    % Summary
    num_passed = sum(test_results);
    fprintf('\n=== Summary ===\n');
    fprintf('Passed: %d / %d\n', num_passed, num_tests);

    if num_passed == num_tests
        fprintf('All tests PASSED!\n');
    else
        fprintf('FAILED tests:\n');
        for i = 1:num_tests
            if ~test_results(i)
                fprintf('  - %s\n', test_details{i});
            end
        end
    end

    % Return results structure
    results = struct(...
        'passed', num_passed == num_tests, ...
        'num_passed', num_passed, ...
        'num_total', num_tests, ...
        'details', {test_details});
end

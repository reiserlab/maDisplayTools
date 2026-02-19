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

    %% ================================================================
    %  Part 2: Header V2 Validation (absorbed from validate_header_v2)
    %  ================================================================

    header_tests = run_header_v2_tests();
    header_count = length(header_tests);

    % Merge header results into main results
    all_results = test_results;
    all_details = test_details;
    for h = 1:header_count
        all_results(end+1) = header_tests(h).passed;  %#ok<AGROW>
        all_details{end+1} = header_tests(h).detail;   %#ok<AGROW>
    end

    % Final summary
    total_tests = length(all_results);
    total_passed = sum(all_results);
    fprintf('\n=== Combined Summary (Pattern + Header) ===\n');
    fprintf('Passed: %d / %d\n', total_passed, total_tests);

    if total_passed == total_tests
        fprintf('All tests PASSED!\n');
    else
        fprintf('FAILED tests:\n');
        for i = 1:total_tests
            if ~all_results(i)
                fprintf('  - %s\n', all_details{i});
            end
        end
    end

    % Return results structure
    results = struct(...
        'passed', total_passed == total_tests, ...
        'num_passed', total_passed, ...
        'num_total', total_tests, ...
        'details', {all_details});
end


function header_tests = run_header_v2_tests()
%RUN_HEADER_V2_TESTS Test G4 and G6 Header V2 bit-packing
%   Returns struct array with fields: passed (logical), detail (string)

    fprintf('\n--- Header V2 Validation ---\n\n');
    header_tests = struct('passed', {}, 'detail', {});
    idx = 0;

    %% H1: G4 V1 Header (Backward Compatibility)
    idx = idx + 1;
    test_name = 'G4 V1 header (legacy format)';
    fprintf('Header %d: %s\n', idx, test_name);
    try
        header = write_g4_header_v2(96, 1, 16, 2, 12);
        info = read_g4_header(header);
        assert(info.version == 1, 'Should detect V1');
        assert(info.NumPatsX == 96, 'NumPatsX mismatch');
        assert(info.NumPatsY == 1, 'NumPatsY mismatch');
        assert(info.GSLevels == 16, 'GSLevels mismatch');
        assert(info.RowN == 2, 'RowN mismatch');
        assert(info.ColN == 12, 'ColN mismatch');
        assert(info.generation_id == 0, 'generation_id should be 0 for V1');
        assert(info.arena_id == 0, 'arena_id should be 0 for V1');
        fprintf('  PASS\n');
        header_tests(idx) = struct('passed', true, 'detail', [test_name ': OK']);
    catch ME
        fprintf('  FAIL: %s\n', ME.message);
        header_tests(idx) = struct('passed', false, 'detail', [test_name ': ' ME.message]);
    end

    %% H2: G4.1 V2 Header with Generation
    idx = idx + 1;
    test_name = 'G4.1 V2 header with generation ID';
    fprintf('Header %d: %s\n', idx, test_name);
    try
        gen_id = get_generation_id('G4.1');
        header = write_g4_header_v2(96, 1, 16, 2, 12, gen_id, 0);
        info = read_g4_header(header);
        assert(info.version == 2, 'Should detect V2');
        assert(info.NumPatsX == 96, 'NumPatsX mismatch');
        assert(info.GSLevels == 16, 'GSLevels mismatch');
        assert(info.generation_id == gen_id, 'generation_id mismatch');
        assert(strcmp(info.generation, 'G4.1'), 'generation name mismatch');
        assert(info.arena_id == 0, 'arena_id should be 0');
        fprintf('  PASS\n');
        header_tests(idx) = struct('passed', true, 'detail', [test_name ': OK']);
    catch ME
        fprintf('  FAIL: %s\n', ME.message);
        header_tests(idx) = struct('passed', false, 'detail', [test_name ': ' ME.message]);
    end

    %% H3: G4.1 V2 Header with Arena ID
    idx = idx + 1;
    test_name = 'G4.1 V2 header with arena ID';
    fprintf('Header %d: %s\n', idx, test_name);
    try
        gen_id = get_generation_id('G4.1');
        arena_id = 4;
        header = write_g4_header_v2(96, 1, 2, 2, 10, gen_id, arena_id);
        info = read_g4_header(header);
        assert(info.version == 2, 'Should detect V2');
        assert(info.generation_id == gen_id, 'generation_id mismatch');
        assert(info.arena_id == arena_id, 'arena_id mismatch');
        assert(info.GSLevels == 2, 'GSLevels mismatch');
        fprintf('  PASS\n');
        header_tests(idx) = struct('passed', true, 'detail', [test_name ': OK']);
    catch ME
        fprintf('  FAIL: %s\n', ME.message);
        header_tests(idx) = struct('passed', false, 'detail', [test_name ': ' ME.message]);
    end

    %% H4: All Generation IDs
    idx = idx + 1;
    test_name = 'G4 V2 all generation IDs';
    fprintf('Header %d: %s\n', idx, test_name);
    try
        gen_names = {'G3', 'G4', 'G4.1', 'G6'};
        expected_ids = [1, 2, 3, 4];
        for i = 1:length(gen_names)
            gen_id = get_generation_id(gen_names{i});
            assert(gen_id == expected_ids(i), 'ID mismatch for %s', gen_names{i});
            header = write_g4_header_v2(48, 1, 16, 2, 12, gen_id, 0);
            info = read_g4_header(header);
            assert(info.generation_id == gen_id, 'Round-trip failed for %s', gen_names{i});
            assert(strcmp(info.generation, gen_names{i}), 'Name mismatch for %s', gen_names{i});
        end
        fprintf('  PASS\n');
        header_tests(idx) = struct('passed', true, 'detail', [test_name ': OK']);
    catch ME
        fprintf('  FAIL: %s\n', ME.message);
        header_tests(idx) = struct('passed', false, 'detail', [test_name ': ' ME.message]);
    end

    %% H5: G6 V2 Header Basic
    idx = idx + 1;
    test_name = 'G6 V2 header basic';
    fprintf('Header %d: %s\n', idx, test_name);
    try
        header = zeros(1, 18, 'uint8');
        header(1:4) = uint8('G6PT');
        header(5) = bitshift(2, 4);  % Version 2, arena_id upper = 0
        header(6) = 0;
        header(7:8) = [10, 0];
        header(9) = 2; header(10) = 10; header(11) = 2;
        header(12:17) = [255, 255, 255, 0, 0, 0];
        header(18) = 0;
        info = read_g6_header(header);
        assert(info.version == 2, 'Should detect V2');
        assert(info.arena_id == 0, 'arena_id should be 0');
        assert(info.observer_id == 0, 'observer_id should be 0');
        assert(info.num_frames == 10, 'num_frames mismatch');
        assert(info.row_count == 2, 'row_count mismatch');
        assert(info.col_count == 10, 'col_count mismatch');
        fprintf('  PASS\n');
        header_tests(idx) = struct('passed', true, 'detail', [test_name ': OK']);
    catch ME
        fprintf('  FAIL: %s\n', ME.message);
        header_tests(idx) = struct('passed', false, 'detail', [test_name ': ' ME.message]);
    end

    %% H6: G6 V2 Header with IDs
    idx = idx + 1;
    test_name = 'G6 V2 header with arena_id and observer_id';
    fprintf('Header %d: %s\n', idx, test_name);
    try
        arena_id = 15; observer_id = 42;
        header = zeros(1, 18, 'uint8');
        header(1:4) = uint8('G6PT');
        version = 2;
        arena_upper = bitshift(arena_id, -2);
        header(5) = bitor(bitshift(version, 4), bitand(arena_upper, 15));
        arena_lower = bitand(arena_id, 3);
        header(6) = bitor(bitshift(arena_lower, 6), bitand(observer_id, 63));
        header(7:8) = [5, 0]; header(9) = 2; header(10) = 10; header(11) = 1;
        header(12:17) = [255, 255, 255, 0, 0, 0]; header(18) = 0;
        info = read_g6_header(header);
        assert(info.version == 2, 'Version mismatch');
        assert(info.arena_id == arena_id, sprintf('arena_id: got %d, expected %d', info.arena_id, arena_id));
        assert(info.observer_id == observer_id, sprintf('observer_id: got %d, expected %d', info.observer_id, observer_id));
        fprintf('  PASS\n');
        header_tests(idx) = struct('passed', true, 'detail', [test_name ': OK']);
    catch ME
        fprintf('  FAIL: %s\n', ME.message);
        header_tests(idx) = struct('passed', false, 'detail', [test_name ': ' ME.message]);
    end

    %% H7: G6 V2 Boundary Values
    idx = idx + 1;
    test_name = 'G6 V2 boundary values (max 63/63)';
    fprintf('Header %d: %s\n', idx, test_name);
    try
        arena_id = 63; observer_id = 63;
        header = zeros(1, 18, 'uint8');
        header(1:4) = uint8('G6PT');
        version = 2;
        arena_upper = bitshift(arena_id, -2);
        header(5) = bitor(bitshift(version, 4), bitand(arena_upper, 15));
        arena_lower = bitand(arena_id, 3);
        header(6) = bitor(bitshift(arena_lower, 6), bitand(observer_id, 63));
        header(7:8) = [1, 0]; header(9) = 1; header(10) = 1; header(11) = 1;
        header(12:17) = [1, 0, 0, 0, 0, 0]; header(18) = 0;
        info = read_g6_header(header);
        assert(info.arena_id == 63, 'Max arena_id failed');
        assert(info.observer_id == 63, 'Max observer_id failed');
        fprintf('  PASS\n');
        header_tests(idx) = struct('passed', true, 'detail', [test_name ': OK']);
    catch ME
        fprintf('  FAIL: %s\n', ME.message);
        header_tests(idx) = struct('passed', false, 'detail', [test_name ': ' ME.message]);
    end

    %% H8: G6 V1 Backward Compatibility
    idx = idx + 1;
    test_name = 'G6 V1 header (backward compat)';
    fprintf('Header %d: %s\n', idx, test_name);
    try
        header = zeros(1, 17, 'uint8');
        header(1:4) = uint8('G6PT');
        header(5) = 1; header(6) = 2;
        header(7:8) = [10, 0]; header(9) = 2; header(10) = 10; header(11) = 0;
        header(12:17) = [255, 255, 255, 0, 0, 0];
        info = read_g6_header(header);
        assert(info.version == 1, 'Should detect V1');
        assert(info.arena_id == 0, 'V1 should have arena_id=0');
        assert(info.observer_id == 0, 'V1 should have observer_id=0');
        fprintf('  PASS\n');
        header_tests(idx) = struct('passed', true, 'detail', [test_name ': OK']);
    catch ME
        fprintf('  FAIL: %s\n', ME.message);
        header_tests(idx) = struct('passed', false, 'detail', [test_name ': ' ME.message]);
    end
end

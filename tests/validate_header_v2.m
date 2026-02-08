function results = validate_header_v2()
% VALIDATE_HEADER_V2 Test G4.1 and G6 Header V2 implementation
%
% Tests header write/read round-trip for both G4.1 and G6 patterns.
% Verifies bit-packing, version detection, and backward compatibility.
%
% Returns:
%   results - Structure with test results

fprintf('=== Header V2 Validation ===\n\n');

results = struct();
results.tests = {};
results.passed = 0;
results.failed = 0;

%% Test 1: G4 V1 Header (Backward Compatibility)
test_name = 'G4 V1 header (legacy format)';
fprintf('Testing: %s\n', test_name);
try
    header = write_g4_header_v2(96, 1, 16, 2, 12);  % No generation/arena
    info = read_g4_header(header);

    assert(info.version == 1, 'Should detect V1');
    assert(info.NumPatsX == 96, 'NumPatsX mismatch');
    assert(info.NumPatsY == 1, 'NumPatsY mismatch');
    assert(info.GSLevels == 16, 'GSLevels mismatch');
    assert(info.RowN == 2, 'RowN mismatch');
    assert(info.ColN == 12, 'ColN mismatch');
    assert(info.generation_id == 0, 'generation_id should be 0 for V1');
    assert(info.arena_id == 0, 'arena_id should be 0 for V1');

    fprintf('  PASS: V1 format detected, all fields correct\n');
    results.passed = results.passed + 1;
    results.tests{end+1} = struct('name', test_name, 'status', 'PASS');
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    results.failed = results.failed + 1;
    results.tests{end+1} = struct('name', test_name, 'status', 'FAIL', 'error', ME.message);
end

%% Test 2: G4.1 V2 Header with Generation
test_name = 'G4.1 V2 header with generation ID';
fprintf('Testing: %s\n', test_name);
try
    gen_id = get_generation_id('G4.1');  % Should be 3
    header = write_g4_header_v2(96, 1, 16, 2, 12, gen_id, 0);
    info = read_g4_header(header);

    assert(info.version == 2, 'Should detect V2');
    assert(info.NumPatsX == 96, 'NumPatsX mismatch');
    assert(info.GSLevels == 16, 'GSLevels mismatch');
    assert(info.generation_id == gen_id, 'generation_id mismatch');
    assert(strcmp(info.generation, 'G4.1'), 'generation name mismatch');
    assert(info.arena_id == 0, 'arena_id should be 0');

    fprintf('  PASS: V2 detected, generation=%s (id=%d)\n', info.generation, gen_id);
    results.passed = results.passed + 1;
    results.tests{end+1} = struct('name', test_name, 'status', 'PASS');
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    results.failed = results.failed + 1;
    results.tests{end+1} = struct('name', test_name, 'status', 'FAIL', 'error', ME.message);
end

%% Test 3: G4.1 V2 Header with Arena ID
test_name = 'G4.1 V2 header with arena ID';
fprintf('Testing: %s\n', test_name);
try
    gen_id = get_generation_id('G4.1');
    arena_id = 4;  % Example arena
    header = write_g4_header_v2(96, 1, 2, 2, 10, gen_id, arena_id);
    info = read_g4_header(header);

    assert(info.version == 2, 'Should detect V2');
    assert(info.generation_id == gen_id, 'generation_id mismatch');
    assert(info.arena_id == arena_id, 'arena_id mismatch');
    assert(info.GSLevels == 2, 'GSLevels mismatch');

    fprintf('  PASS: V2 with arena_id=%d\n', arena_id);
    results.passed = results.passed + 1;
    results.tests{end+1} = struct('name', test_name, 'status', 'PASS');
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    results.failed = results.failed + 1;
    results.tests{end+1} = struct('name', test_name, 'status', 'FAIL', 'error', ME.message);
end

%% Test 4: G4 V2 All Generations
test_name = 'G4 V2 all generation IDs';
fprintf('Testing: %s\n', test_name);
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

    fprintf('  PASS: All 4 generations encode/decode correctly\n');
    results.passed = results.passed + 1;
    results.tests{end+1} = struct('name', test_name, 'status', 'PASS');
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    results.failed = results.failed + 1;
    results.tests{end+1} = struct('name', test_name, 'status', 'FAIL', 'error', ME.message);
end

%% Test 5: G6 V2 Header Basic
test_name = 'G6 V2 header basic (arena_id=0, observer_id=0)';
fprintf('Testing: %s\n', test_name);
try
    % Create minimal V2 header manually
    header = zeros(1, 18, 'uint8');
    header(1:4) = uint8('G6PT');
    header(5) = bitshift(2, 4);  % Version 2, arena_id upper = 0
    header(6) = 0;  % Arena lower = 0, observer = 0
    header(7:8) = [10, 0];  % 10 frames
    header(9) = 2;   % 2 rows
    header(10) = 10; % 10 cols
    header(11) = 2;  % GS16
    header(12:17) = [255, 255, 255, 0, 0, 0];  % Panel mask
    header(18) = 0;  % Checksum

    info = read_g6_header(header);

    assert(info.version == 2, 'Should detect V2');
    assert(info.arena_id == 0, 'arena_id should be 0');
    assert(info.observer_id == 0, 'observer_id should be 0');
    assert(info.num_frames == 10, 'num_frames mismatch');
    assert(info.row_count == 2, 'row_count mismatch');
    assert(info.col_count == 10, 'col_count mismatch');
    assert(info.gs_val == 2, 'gs_val mismatch');

    fprintf('  PASS: V2 header parsed correctly\n');
    results.passed = results.passed + 1;
    results.tests{end+1} = struct('name', test_name, 'status', 'PASS');
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    results.failed = results.failed + 1;
    results.tests{end+1} = struct('name', test_name, 'status', 'FAIL', 'error', ME.message);
end

%% Test 6: G6 V2 Header with IDs
test_name = 'G6 V2 header with arena_id and observer_id';
fprintf('Testing: %s\n', test_name);
try
    arena_id = 15;    % 6-bit value (0-63)
    observer_id = 42; % 6-bit value (0-63)

    % Create V2 header manually
    header = zeros(1, 18, 'uint8');
    header(1:4) = uint8('G6PT');

    % Byte 5: [VVVV][AAAA] - Version 2, arena upper 4 bits
    version = 2;
    arena_upper = bitshift(arena_id, -2);  % Upper 4 bits
    header(5) = bitor(bitshift(version, 4), bitand(arena_upper, 15));

    % Byte 6: [AA][OOOOOO] - Arena lower 2 bits, observer 6 bits
    arena_lower = bitand(arena_id, 3);
    header(6) = bitor(bitshift(arena_lower, 6), bitand(observer_id, 63));

    header(7:8) = [5, 0];  % 5 frames
    header(9) = 2;
    header(10) = 10;
    header(11) = 1;  % GS2
    header(12:17) = [255, 255, 255, 0, 0, 0];
    header(18) = 0;

    info = read_g6_header(header);

    assert(info.version == 2, 'Version mismatch');
    assert(info.arena_id == arena_id, 'arena_id mismatch: got %d, expected %d', ...
        info.arena_id, arena_id);
    assert(info.observer_id == observer_id, 'observer_id mismatch: got %d, expected %d', ...
        info.observer_id, observer_id);

    fprintf('  PASS: arena_id=%d, observer_id=%d decoded correctly\n', arena_id, observer_id);
    results.passed = results.passed + 1;
    results.tests{end+1} = struct('name', test_name, 'status', 'PASS');
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    results.failed = results.failed + 1;
    results.tests{end+1} = struct('name', test_name, 'status', 'FAIL', 'error', ME.message);
end

%% Test 7: G6 V2 Boundary Values
test_name = 'G6 V2 boundary values (max arena_id, max observer_id)';
fprintf('Testing: %s\n', test_name);
try
    arena_id = 63;    % Max 6-bit value
    observer_id = 63; % Max 6-bit value

    header = zeros(1, 18, 'uint8');
    header(1:4) = uint8('G6PT');

    version = 2;
    arena_upper = bitshift(arena_id, -2);
    header(5) = bitor(bitshift(version, 4), bitand(arena_upper, 15));

    arena_lower = bitand(arena_id, 3);
    header(6) = bitor(bitshift(arena_lower, 6), bitand(observer_id, 63));

    header(7:8) = [1, 0];
    header(9) = 1;
    header(10) = 1;
    header(11) = 1;
    header(12:17) = [1, 0, 0, 0, 0, 0];
    header(18) = 0;

    info = read_g6_header(header);

    assert(info.arena_id == 63, 'Max arena_id failed');
    assert(info.observer_id == 63, 'Max observer_id failed');

    fprintf('  PASS: Boundary values (63, 63) encoded/decoded\n');
    results.passed = results.passed + 1;
    results.tests{end+1} = struct('name', test_name, 'status', 'PASS');
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    results.failed = results.failed + 1;
    results.tests{end+1} = struct('name', test_name, 'status', 'FAIL', 'error', ME.message);
end

%% Test 8: G6 V1 Backward Compatibility
test_name = 'G6 V1 header (backward compatibility)';
fprintf('Testing: %s\n', test_name);
try
    % Create V1 header (17 bytes)
    header = zeros(1, 17, 'uint8');
    header(1:4) = uint8('G6PT');
    header(5) = 1;  % Version 1
    header(6) = 2;  % gs_val = 2 (GS16)
    header(7:8) = [10, 0];
    header(9) = 2;
    header(10) = 10;
    header(11) = 0;  % Checksum
    header(12:17) = [255, 255, 255, 0, 0, 0];

    info = read_g6_header(header);

    assert(info.version == 1, 'Should detect V1');
    assert(info.arena_id == 0, 'V1 should have arena_id=0');
    assert(info.observer_id == 0, 'V1 should have observer_id=0');
    assert(info.gs_val == 2, 'gs_val mismatch');

    fprintf('  PASS: V1 format detected correctly\n');
    results.passed = results.passed + 1;
    results.tests{end+1} = struct('name', test_name, 'status', 'PASS');
catch ME
    fprintf('  FAIL: %s\n', ME.message);
    results.failed = results.failed + 1;
    results.tests{end+1} = struct('name', test_name, 'status', 'FAIL', 'error', ME.message);
end

%% Summary
fprintf('\n=== Summary ===\n');
fprintf('Passed: %d / %d\n', results.passed, results.passed + results.failed);
if results.failed == 0
    fprintf('All tests PASSED!\n');
else
    fprintf('FAILURES detected - review above\n');
end

results.total = results.passed + results.failed;
results.success = (results.failed == 0);

end

function results = validate_g6_encoding()
%VALIDATE_G6_ENCODING Test G6 panel encoding at the byte level
%
%   results = validate_g6_encoding() tests g6_encode_panel() for correct
%   pixel coordinate mapping, GS2 bit packing, and GS16 nibble packing.
%
%   Coordinate convention:
%     - Panel origin (0,0) is at BOTTOM-LEFT
%     - Row-major ordering: pixel_num = row_from_bottom * 20 + col
%     - MATLAB array: row 1 = top, row 20 = bottom
%     - So MATLAB(20,1) = panel(0,0) = pixel_num 0
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
%       results = validate_g6_encoding();

    fprintf('=== G6 Encoding Validation ===\n\n');

    num_tests = 11;
    test_results = false(num_tests, 1);
    test_details = cell(num_tests, 1);

    %% Test 1: Single pixel at bottom-left (0,0)
    fprintf('Test 1: Single pixel at (0,0) bottom-left\n');
    try
        pixels = zeros(20, 20, 'uint8');
        pixels(20, 1) = 1;
        block = g6_encode_panel(pixels, 192, 'GS2');
        assert(block(3) == 128, 'byte 3 should be 128 (0x80)');
        test_results(1) = true;
        test_details{1} = 'Pixel (0,0): byte 3 = 128';
        fprintf('  PASS\n');
    catch ME
        test_details{1} = sprintf('Pixel (0,0) failed: %s', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 2: Single pixel at (0,1)
    fprintf('Test 2: Single pixel at (0,1)\n');
    try
        pixels = zeros(20, 20, 'uint8');
        pixels(20, 2) = 1;
        block = g6_encode_panel(pixels, 192, 'GS2');
        assert(block(3) == 64, 'byte 3 should be 64 (0x40)');
        test_results(2) = true;
        test_details{2} = 'Pixel (0,1): byte 3 = 64';
        fprintf('  PASS\n');
    catch ME
        test_details{2} = sprintf('Pixel (0,1) failed: %s', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 3: Two pixels at (0,0) and (0,1)
    fprintf('Test 3: Two pixels at (0,0) and (0,1)\n');
    try
        pixels = zeros(20, 20, 'uint8');
        pixels(20, 1) = 1; pixels(20, 2) = 1;
        block = g6_encode_panel(pixels, 192, 'GS2');
        assert(block(3) == 192, 'byte 3 should be 192 (0xC0)');
        test_results(3) = true;
        test_details{3} = 'Two pixels (0,0)+(0,1): byte 3 = 192';
        fprintf('  PASS\n');
    catch ME
        test_details{3} = sprintf('Two pixels failed: %s', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 4: Top-left pixel (19,0) in panel coords
    fprintf('Test 4: Single pixel at (19,0) top-left\n');
    try
        pixels = zeros(20, 20, 'uint8');
        pixels(1, 1) = 1;
        block = g6_encode_panel(pixels, 192, 'GS2');
        byte_idx = 47 + 2 + 1;  % +2 header/cmd, +1 MATLAB indexing
        assert(block(byte_idx) == 8, sprintf('byte %d should be 8 (0x08)', byte_idx));
        test_results(4) = true;
        test_details{4} = sprintf('Pixel (19,0): byte %d = 8', byte_idx);
        fprintf('  PASS\n');
    catch ME
        test_details{4} = sprintf('Pixel (19,0) failed: %s', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 5: Bottom-right pixel (0,19)
    fprintf('Test 5: Single pixel at (0,19) bottom-right\n');
    try
        pixels = zeros(20, 20, 'uint8');
        pixels(20, 20) = 1;
        block = g6_encode_panel(pixels, 192, 'GS2');
        byte_idx = 2 + 2 + 1;
        assert(block(byte_idx) == 16, sprintf('byte %d should be 16 (0x10)', byte_idx));
        test_results(5) = true;
        test_details{5} = sprintf('Pixel (0,19): byte %d = 16', byte_idx);
        fprintf('  PASS\n');
    catch ME
        test_details{5} = sprintf('Pixel (0,19) failed: %s', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 6: Bottom row lit
    fprintf('Test 6: Bottom row lit\n');
    try
        pixels = zeros(20, 20, 'uint8');
        pixels(20, :) = 1;
        block = g6_encode_panel(pixels, 192, 'GS2');
        assert(block(3) == 255 && block(4) == 255 && block(5) == 240, ...
            sprintf('bytes 3,4,5 should be 255,255,240, got %d,%d,%d', block(3), block(4), block(5)));
        test_results(6) = true;
        test_details{6} = 'Bottom row: bytes 3,4,5 = 255,255,240';
        fprintf('  PASS\n');
    catch ME
        test_details{6} = sprintf('Bottom row failed: %s', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 7: Left column lit
    fprintf('Test 7: Left column lit\n');
    try
        pixels = zeros(20, 20, 'uint8');
        pixels(:, 1) = 1;
        block = g6_encode_panel(pixels, 192, 'GS2');
        assert(block(3) == 128, 'byte 3 should be 128 (pixel 0)');
        assert(block(5) == 8, 'byte 5 should be 8 (pixel 20)');
        test_results(7) = true;
        test_details{7} = 'Left column: correct bit positions';
        fprintf('  PASS\n');
    catch ME
        test_details{7} = sprintf('Left column failed: %s', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 8: All pixels on
    fprintf('Test 8: All pixels on\n');
    try
        pixels = ones(20, 20, 'uint8');
        block = g6_encode_panel(pixels, 192, 'GS2');
        assert(all(block(3:52) == 255), 'All 50 data bytes should be 255');
        test_results(8) = true;
        test_details{8} = 'All on: 50 data bytes = 255';
        fprintf('  PASS\n');
    catch ME
        test_details{8} = sprintf('All on failed: %s', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 9: GS16 single pixel at (0,0)
    fprintf('Test 9: GS16 single pixel at (0,0) val=15\n');
    try
        pixels = zeros(20, 20, 'uint8');
        pixels(20, 1) = 15;
        block = g6_encode_panel(pixels, 192, 'GS16');
        assert(block(3) == 240, 'byte 3 should be 240 (0xF0)');
        test_results(9) = true;
        test_details{9} = 'GS16 pixel (0,0)=15: byte 3 = 240';
        fprintf('  PASS\n');
    catch ME
        test_details{9} = sprintf('GS16 pixel (0,0) failed: %s', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 10: GS16 two adjacent pixels
    fprintf('Test 10: GS16 two adjacent pixels (15, 10)\n');
    try
        pixels = zeros(20, 20, 'uint8');
        pixels(20, 1) = 15; pixels(20, 2) = 10;
        block = g6_encode_panel(pixels, 192, 'GS16');
        assert(block(3) == 250, 'byte 3 should be 250 (0xFA)');
        test_results(10) = true;
        test_details{10} = 'GS16 (15,10): byte 3 = 250';
        fprintf('  PASS\n');
    catch ME
        test_details{10} = sprintf('GS16 adjacent failed: %s', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 11: GS16 gradient on bottom row
    fprintf('Test 11: GS16 gradient on bottom row\n');
    try
        pixels = zeros(20, 20, 'uint8');
        pixels(20, :) = [0:15, 0:3];
        block = g6_encode_panel(pixels, 192, 'GS16');
        assert(block(3) == 1, 'byte 3 should be 1 (0x01)');
        assert(block(4) == 35, 'byte 4 should be 35 (0x23)');
        assert(block(5) == 69, 'byte 5 should be 69 (0x45)');
        test_results(11) = true;
        test_details{11} = 'GS16 gradient: bytes 3,4,5 = 1,35,69';
        fprintf('  PASS\n');
    catch ME
        test_details{11} = sprintf('GS16 gradient failed: %s', ME.message);
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

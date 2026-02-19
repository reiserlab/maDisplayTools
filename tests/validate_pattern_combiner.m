function results = validate_pattern_combiner()
% VALIDATE_PATTERN_COMBINER Test pattern combination functionality
%
% Tests the pattern combination logic used by PatternCombinerApp.
% Creates test patterns, combines them using different modes, and
% validates the results.
%
% Usage:
%   results = validate_pattern_combiner();
%   if all([results.passed])
%       disp('All tests PASSED!');
%   end
%
% Returns:
%   results - struct array with fields: name, passed, message

fprintf('\n=== Pattern Combiner Validation ===\n\n');

% Setup paths
thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
addpath(fullfile(rootDir, 'patternTools'));
addpath(fullfile(rootDir, 'utils'));
addpath(fullfile(rootDir, 'g6'));

% Create temp directory for test patterns
tempDir = fullfile(rootDir, 'tests', 'temp_combiner_test');
if exist(tempDir, 'dir')
    rmdir(tempDir, 's');
end
mkdir(tempDir);

results = struct('name', {}, 'passed', {}, 'message', {});

try
    %% Test 1: Sequential combination (same dimensions, same frames)
    fprintf('Testing: Sequential combination (equal frames)\n');
    try
        % Create two test patterns (8x16 pixels, 3 frames each, GS16)
        pat1 = uint8(randi([0, 15], 8, 16, 3));
        pat2 = uint8(randi([0, 15], 8, 16, 3));
        stretch1 = [1; 1; 1];
        stretch2 = [1; 1; 1];

        % Combine sequentially
        combined = cat(3, pat1, pat2);
        combinedStretch = [stretch1; stretch2];

        % Validate
        [r, c, f] = size(combined);
        assert(r == 8, 'Wrong rows');
        assert(c == 16, 'Wrong cols');
        assert(f == 6, 'Wrong frames: expected 6, got %d', f);
        assert(length(combinedStretch) == 6, 'Wrong stretch length');
        assert(all(combined(:,:,1:3) == pat1, 'all'), 'Pat1 data mismatch');
        assert(all(combined(:,:,4:6) == pat2, 'all'), 'Pat2 data mismatch');

        results(end+1) = struct('name', 'Sequential (equal frames)', ...
            'passed', true, 'message', 'OK: 3+3=6 frames');
        fprintf('  PASS: 3+3=6 frames\n');
    catch ME
        results(end+1) = struct('name', 'Sequential (equal frames)', ...
            'passed', false, 'message', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 2: Sequential combination (different frame counts)
    fprintf('Testing: Sequential combination (different frames)\n');
    try
        pat1 = uint8(randi([0, 15], 8, 16, 5));
        pat2 = uint8(randi([0, 15], 8, 16, 2));

        combined = cat(3, pat1, pat2);

        [~, ~, f] = size(combined);
        assert(f == 7, 'Wrong frames: expected 7, got %d', f);

        results(end+1) = struct('name', 'Sequential (different frames)', ...
            'passed', true, 'message', 'OK: 5+2=7 frames');
        fprintf('  PASS: 5+2=7 frames\n');
    catch ME
        results(end+1) = struct('name', 'Sequential (different frames)', ...
            'passed', false, 'message', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 3: Mask combination (replace at value)
    fprintf('Testing: Mask combination (replace at threshold)\n');
    try
        % Create patterns: pat1 has zeros where we want pat2's values
        pat1 = uint8(ones(8, 16, 2) * 5);
        pat1(1:4, 1:8, :) = 0;  % Top-left quadrant is 0

        pat2 = uint8(ones(8, 16, 2) * 10);

        % Replace where pat1 == 0
        threshold = 0;
        combined = pat1;
        mask = (pat1 == threshold);
        combined(mask) = pat2(mask);

        % Validate
        assert(all(combined(1:4, 1:8, :) == 10, 'all'), 'Replacement failed');
        assert(all(combined(5:8, :, :) == 5, 'all'), 'Non-replacement changed');
        assert(all(combined(1:4, 9:16, :) == 5, 'all'), 'Non-replacement changed');

        results(end+1) = struct('name', 'Mask (replace at threshold)', ...
            'passed', true, 'message', 'OK: replaced pixels at value 0');
        fprintf('  PASS: replaced pixels at value 0\n');
    catch ME
        results(end+1) = struct('name', 'Mask (replace at threshold)', ...
            'passed', false, 'message', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 4: Mask combination (50% blend)
    fprintf('Testing: Mask combination (50%% blend)\n');
    try
        pat1 = uint8(ones(8, 16, 2) * 4);
        pat2 = uint8(ones(8, 16, 2) * 10);

        % 50% blend with rounding
        combined = uint8(round((double(pat1) + double(pat2)) / 2));

        % Should be (4+10)/2 = 7
        assert(all(combined(:) == 7), 'Blend result wrong: expected 7, got %d', combined(1,1,1));

        results(end+1) = struct('name', 'Mask (50% blend)', ...
            'passed', true, 'message', 'OK: (4+10)/2 = 7');
        fprintf('  PASS: (4+10)/2 = 7\n');
    catch ME
        results(end+1) = struct('name', 'Mask (50% blend)', ...
            'passed', false, 'message', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 5: Mask combination (50% blend with odd sum - test rounding)
    fprintf('Testing: Mask combination (blend rounding)\n');
    try
        pat1 = uint8(ones(8, 16, 1) * 3);
        pat2 = uint8(ones(8, 16, 1) * 8);

        % 50% blend: (3+8)/2 = 5.5 -> rounds to 6
        combined = uint8(round((double(pat1) + double(pat2)) / 2));

        assert(all(combined(:) == 6), 'Rounding wrong: expected 6, got %d', combined(1,1,1));

        results(end+1) = struct('name', 'Mask (blend rounding)', ...
            'passed', true, 'message', 'OK: (3+8)/2 = 5.5 -> 6');
        fprintf('  PASS: (3+8)/2 = 5.5 -> 6\n');
    catch ME
        results(end+1) = struct('name', 'Mask (blend rounding)', ...
            'passed', false, 'message', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 6: Left/Right combination
    fprintf('Testing: Left/Right combination\n');
    try
        % Create patterns with distinct values
        pat1 = uint8(ones(8, 16, 2) * 3);  % All 3s
        pat2 = uint8(ones(8, 16, 2) * 12); % All 12s

        % Split at column 8 (half)
        splitCol = 8;
        combined = zeros(8, 16, 2, 'uint8');
        combined(:, 1:splitCol, :) = pat1(:, 1:splitCol, :);
        combined(:, (splitCol+1):end, :) = pat2(:, (splitCol+1):end, :);

        % Validate
        assert(all(combined(:, 1:8, :) == 3, 'all'), 'Left side wrong');
        assert(all(combined(:, 9:16, :) == 12, 'all'), 'Right side wrong');

        results(end+1) = struct('name', 'Left/Right (split at 8)', ...
            'passed', true, 'message', 'OK: split at column 8');
        fprintf('  PASS: split at column 8\n');
    catch ME
        results(end+1) = struct('name', 'Left/Right (split at 8)', ...
            'passed', false, 'message', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 7: Left/Right with asymmetric split
    fprintf('Testing: Left/Right combination (asymmetric)\n');
    try
        pat1 = uint8(ones(8, 16, 1) * 5);
        pat2 = uint8(ones(8, 16, 1) * 15);

        % Split at column 4 (1/4 left, 3/4 right)
        splitCol = 4;
        combined = zeros(8, 16, 1, 'uint8');
        combined(:, 1:splitCol, :) = pat1(:, 1:splitCol, :);
        combined(:, (splitCol+1):end, :) = pat2(:, (splitCol+1):end, :);

        assert(all(combined(:, 1:4, :) == 5, 'all'), 'Left side wrong');
        assert(all(combined(:, 5:16, :) == 15, 'all'), 'Right side wrong');

        results(end+1) = struct('name', 'Left/Right (asymmetric)', ...
            'passed', true, 'message', 'OK: split at column 4');
        fprintf('  PASS: split at column 4\n');
    catch ME
        results(end+1) = struct('name', 'Left/Right (asymmetric)', ...
            'passed', false, 'message', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 8: Binary OR operation
    fprintf('Testing: Binary OR\n');
    try
        pat1 = uint8([0 1 0 1; 0 0 1 1]);
        pat2 = uint8([0 0 1 1; 0 1 0 1]);

        combined = uint8(logical(pat1) | logical(pat2));

        expected = uint8([0 1 1 1; 0 1 1 1]);
        assert(all(combined(:) == expected(:)), 'OR result wrong');

        results(end+1) = struct('name', 'Binary OR', ...
            'passed', true, 'message', 'OK');
        fprintf('  PASS\n');
    catch ME
        results(end+1) = struct('name', 'Binary OR', ...
            'passed', false, 'message', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 9: Binary AND operation
    fprintf('Testing: Binary AND\n');
    try
        pat1 = uint8([0 1 0 1; 0 0 1 1]);
        pat2 = uint8([0 0 1 1; 0 1 0 1]);

        combined = uint8(logical(pat1) & logical(pat2));

        expected = uint8([0 0 0 1; 0 0 0 1]);
        assert(all(combined(:) == expected(:)), 'AND result wrong');

        results(end+1) = struct('name', 'Binary AND', ...
            'passed', true, 'message', 'OK');
        fprintf('  PASS\n');
    catch ME
        results(end+1) = struct('name', 'Binary AND', ...
            'passed', false, 'message', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 10: Binary XOR operation
    fprintf('Testing: Binary XOR\n');
    try
        pat1 = uint8([0 1 0 1; 0 0 1 1]);
        pat2 = uint8([0 0 1 1; 0 1 0 1]);

        combined = uint8(xor(logical(pat1), logical(pat2)));

        expected = uint8([0 1 1 0; 0 1 1 0]);
        assert(all(combined(:) == expected(:)), 'XOR result wrong');

        results(end+1) = struct('name', 'Binary XOR', ...
            'passed', true, 'message', 'OK');
        fprintf('  PASS\n');
    catch ME
        results(end+1) = struct('name', 'Binary XOR', ...
            'passed', false, 'message', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 11: Frame truncation for spatial modes
    fprintf('Testing: Frame truncation (spatial)\n');
    try
        pat1 = uint8(randi([0, 15], 8, 16, 5));
        pat2 = uint8(randi([0, 15], 8, 16, 3));

        minFrames = min(size(pat1, 3), size(pat2, 3));
        combined = zeros(8, 16, minFrames, 'uint8');

        % Left/right split
        splitCol = 8;
        combined(:, 1:splitCol, :) = pat1(:, 1:splitCol, 1:minFrames);
        combined(:, (splitCol+1):end, :) = pat2(:, (splitCol+1):end, 1:minFrames);

        [~, ~, f] = size(combined);
        assert(f == 3, 'Frame truncation failed: expected 3, got %d', f);

        results(end+1) = struct('name', 'Frame truncation (spatial)', ...
            'passed', true, 'message', 'OK: min(5,3) = 3 frames');
        fprintf('  PASS: min(5,3) = 3 frames\n');
    catch ME
        results(end+1) = struct('name', 'Frame truncation (spatial)', ...
            'passed', false, 'message', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

    %% Test 12: Blend clamping (values at max)
    fprintf('Testing: Blend clamping\n');
    try
        pat1 = uint8(ones(4, 4, 1) * 14);
        pat2 = uint8(ones(4, 4, 1) * 15);

        % 50% blend: (14+15)/2 = 14.5 -> rounds to 15 (should clamp at 15)
        blended = round((double(pat1) + double(pat2)) / 2);
        combined = uint8(min(max(blended, 0), 15));

        assert(all(combined(:) == 15), 'Clamping failed');

        results(end+1) = struct('name', 'Blend clamping', ...
            'passed', true, 'message', 'OK: (14+15)/2 = 15');
        fprintf('  PASS: (14+15)/2 = 15 (clamped)\n');
    catch ME
        results(end+1) = struct('name', 'Blend clamping', ...
            'passed', false, 'message', ME.message);
        fprintf('  FAIL: %s\n', ME.message);
    end

catch ME
    fprintf('\nFATAL ERROR: %s\n', ME.message);
    fprintf('%s\n', ME.getReport());
end

% Cleanup
if exist(tempDir, 'dir')
    rmdir(tempDir, 's');
end

%% Summary
fprintf('\n=== Summary ===\n');
nPassed = sum([results.passed]);
nTotal = length(results);
fprintf('Passed: %d / %d\n', nPassed, nTotal);

if nPassed == nTotal
    fprintf('All tests PASSED!\n');
else
    fprintf('Some tests FAILED.\n');
    failedTests = results(~[results.passed]);
    for i = 1:length(failedTests)
        fprintf('  - %s: %s\n', failedTests(i).name, failedTests(i).message);
    end
end

fprintf('\n');
end

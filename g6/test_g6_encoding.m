%% G6 Encoding Test Script
% Tests the simplified row-major encoding with (0,0) at bottom-left
%
% Coordinate convention:
%   - Panel origin (0,0) is at BOTTOM-LEFT
%   - Row-major ordering: pixel_num = row_from_bottom * 20 + col
%   - MATLAB array: row 1 = top, row 20 = bottom
%   - So MATLAB(20,1) = panel(0,0) = pixel_num 0

%% Setup
clear; clc;
addpath('../g6');  % Adjust path as needed

fprintf('=== G6 Encoding Tests ===\n\n');

%% Test 1: Single pixel at bottom-left (0,0)
% pixel_num = 0 → byte 0, bit 7 → byte value = 0x80 = 128
fprintf('Test 1: Single pixel at (0,0) bottom-left\n');
pixels = zeros(20, 20, 'uint8');
pixels(20, 1) = 1;  % MATLAB row 20, col 1 = panel (0,0)

block = g6_encode_panel(pixels, 192, 'GS2');
fprintf('  Expected: byte 3 = 128 (0x80)\n');
fprintf('  Actual:   byte 3 = %d (0x%02X)\n', block(3), block(3));
assert(block(3) == 128, 'Test 1 FAILED');
fprintf('  PASSED ✓\n\n');

%% Test 2: Single pixel at bottom-left (0,1)
% pixel_num = 1 → byte 0, bit 6 → byte value = 0x40 = 64
fprintf('Test 2: Single pixel at (0,1)\n');
pixels = zeros(20, 20, 'uint8');
pixels(20, 2) = 1;  % MATLAB row 20, col 2 = panel (0,1)

block = g6_encode_panel(pixels, 192, 'GS2');
fprintf('  Expected: byte 3 = 64 (0x40)\n');
fprintf('  Actual:   byte 3 = %d (0x%02X)\n', block(3), block(3));
assert(block(3) == 64, 'Test 2 FAILED');
fprintf('  PASSED ✓\n\n');

%% Test 3: Two pixels at (0,0) and (0,1)
% pixel_num 0 and 1 → byte 0, bits 7 and 6 → byte value = 0xC0 = 192
fprintf('Test 3: Two pixels at (0,0) and (0,1)\n');
pixels = zeros(20, 20, 'uint8');
pixels(20, 1) = 1;  % panel (0,0)
pixels(20, 2) = 1;  % panel (0,1)

block = g6_encode_panel(pixels, 192, 'GS2');
fprintf('  Expected: byte 3 = 192 (0xC0)\n');
fprintf('  Actual:   byte 3 = %d (0x%02X)\n', block(3), block(3));
assert(block(3) == 192, 'Test 3 FAILED');
fprintf('  PASSED ✓\n\n');

%% Test 4: Single pixel at top-left (19,0) in panel coords
% row_from_bottom = 19, col = 0 → pixel_num = 380
% 380 / 8 = 47.5 → byte 47, bit 7 - (380 mod 8) = 7 - 4 = 3
% byte 47 value = 0x08 = 8
fprintf('Test 4: Single pixel at (19,0) top-left\n');
pixels = zeros(20, 20, 'uint8');
pixels(1, 1) = 1;  % MATLAB row 1, col 1 = panel (19,0)

block = g6_encode_panel(pixels, 192, 'GS2');
byte_idx = 47 + 2 + 1;  % +2 for header/cmd, +1 for MATLAB indexing
fprintf('  Expected: byte %d (index %d) = 8 (0x08)\n', 47, byte_idx);
fprintf('  Actual:   byte %d (index %d) = %d (0x%02X)\n', 47, byte_idx, block(byte_idx), block(byte_idx));
assert(block(byte_idx) == 8, 'Test 4 FAILED');
fprintf('  PASSED ✓\n\n');

%% Test 5: Single pixel at bottom-right (0,19)
% row_from_bottom = 0, col = 19 → pixel_num = 19
% 19 / 8 = 2.375 → byte 2, bit 7 - (19 mod 8) = 7 - 3 = 4
% byte 2 value = 0x10 = 16
fprintf('Test 5: Single pixel at (0,19) bottom-right\n');
pixels = zeros(20, 20, 'uint8');
pixels(20, 20) = 1;  % MATLAB row 20, col 20 = panel (0,19)

block = g6_encode_panel(pixels, 192, 'GS2');
byte_idx = 2 + 2 + 1;  % +2 for header/cmd, +1 for MATLAB indexing
fprintf('  Expected: byte %d (index %d) = 16 (0x10)\n', 2, byte_idx);
fprintf('  Actual:   byte %d (index %d) = %d (0x%02X)\n', 2, byte_idx, block(byte_idx), block(byte_idx));
assert(block(byte_idx) == 16, 'Test 5 FAILED');
fprintf('  PASSED ✓\n\n');

%% Test 6: Bottom row lit (all of row 0 in panel coords)
% pixel_num 0-19, bytes 0-2
fprintf('Test 6: Bottom row lit\n');
pixels = zeros(20, 20, 'uint8');
pixels(20, :) = 1;  % MATLAB row 20 = panel row 0 (bottom)

block = g6_encode_panel(pixels, 192, 'GS2');
% Pixels 0-7 → byte 0 = 0xFF = 255
% Pixels 8-15 → byte 1 = 0xFF = 255
% Pixels 16-19 → byte 2 bits 7-4 = 0xF0 = 240
fprintf('  Expected: bytes 3,4,5 = 255, 255, 240\n');
fprintf('  Actual:   bytes 3,4,5 = %d, %d, %d\n', block(3), block(4), block(5));
assert(block(3) == 255 && block(4) == 255 && block(5) == 240, 'Test 6 FAILED');
fprintf('  PASSED ✓\n\n');

%% Test 7: Left column lit (col 0 in panel coords)
% pixel_num = 0, 20, 40, 60, ... 380 (every 20th pixel)
fprintf('Test 7: Left column lit\n');
pixels = zeros(20, 20, 'uint8');
pixels(:, 1) = 1;  % MATLAB col 1 = panel col 0

block = g6_encode_panel(pixels, 192, 'GS2');
% Each pixel is at pixel_num = row*20, so bits are spread across bytes
% pixel 0 → byte 0, bit 7
% pixel 20 → byte 2, bit 3
% pixel 40 → byte 5, bit 7
% etc.
fprintf('  Byte 3 (pixels 0-7):   %d (0x%02X)\n', block(3), block(3));
fprintf('  Byte 5 (pixels 16-23): %d (0x%02X)\n', block(5), block(5));
fprintf('  Byte 8 (pixels 40-47): %d (0x%02X)\n', block(8), block(8));
% Just check a few key bytes
assert(block(3) == 128, 'Test 7 FAILED - byte 0');  % pixel 0
assert(block(5) == 8, 'Test 7 FAILED - byte 2');    % pixel 20
fprintf('  PASSED ✓\n\n');

%% Test 8: All pixels on
fprintf('Test 8: All pixels on\n');
pixels = ones(20, 20, 'uint8');

block = g6_encode_panel(pixels, 192, 'GS2');
% All 50 data bytes should be 0xFF = 255
all_ff = all(block(3:52) == 255);
fprintf('  Expected: all data bytes = 255\n');
fprintf('  Actual:   all data bytes = 255? %s\n', string(all_ff));
assert(all_ff, 'Test 8 FAILED');
fprintf('  PASSED ✓\n\n');

%% Test 9: GS16 single pixel at (0,0)
% pixel_num = 0 → byte 0, high nibble
fprintf('Test 9: GS16 single pixel at (0,0) with value 15\n');
pixels = zeros(20, 20, 'uint8');
pixels(20, 1) = 15;  % Max brightness

block = g6_encode_panel(pixels, 192, 'GS16');
fprintf('  Expected: byte 3 = 240 (0xF0) - high nibble\n');
fprintf('  Actual:   byte 3 = %d (0x%02X)\n', block(3), block(3));
assert(block(3) == 240, 'Test 9 FAILED');
fprintf('  PASSED ✓\n\n');

%% Test 10: GS16 two adjacent pixels
% pixel 0 = 15 (high nibble), pixel 1 = 10 (low nibble)
% byte 0 = 0xFA = 250
fprintf('Test 10: GS16 two adjacent pixels (15, 10)\n');
pixels = zeros(20, 20, 'uint8');
pixels(20, 1) = 15;  % pixel 0
pixels(20, 2) = 10;  % pixel 1

block = g6_encode_panel(pixels, 192, 'GS16');
fprintf('  Expected: byte 3 = 250 (0xFA)\n');
fprintf('  Actual:   byte 3 = %d (0x%02X)\n', block(3), block(3));
assert(block(3) == 250, 'Test 10 FAILED');
fprintf('  PASSED ✓\n\n');

%% Test 11: GS16 gradient (bottom row 0-15, repeated)
fprintf('Test 11: GS16 gradient on bottom row\n');
pixels = zeros(20, 20, 'uint8');
pixels(20, :) = [0:15, 0:3];  % 0-15, then 0-3

block = g6_encode_panel(pixels, 192, 'GS16');
% Byte 0: pixels 0,1 = 0x01
% Byte 1: pixels 2,3 = 0x23
% Byte 2: pixels 4,5 = 0x45
% etc.
fprintf('  Byte 3 (pixels 0,1):  %d (0x%02X) - expected 1 (0x01)\n', block(3), block(3));
fprintf('  Byte 4 (pixels 2,3):  %d (0x%02X) - expected 35 (0x23)\n', block(4), block(4));
fprintf('  Byte 5 (pixels 4,5):  %d (0x%02X) - expected 69 (0x45)\n', block(5), block(5));
assert(block(3) == 1, 'Test 11 FAILED - byte 0');
assert(block(4) == 35, 'Test 11 FAILED - byte 1');
assert(block(5) == 69, 'Test 11 FAILED - byte 2');
fprintf('  PASSED ✓\n\n');

%% Summary
fprintf('=== All tests passed! ===\n');

%% Helper: Print block bytes for debugging
function print_block_bytes(block, n)
    fprintf('First %d data bytes: ', n);
    for i = 3:(3+n-1)
        fprintf('%d ', block(i));
    end
    fprintf('\n');
end

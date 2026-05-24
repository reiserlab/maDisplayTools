function panel_block = g6_encode_panel(pixel_data, stretch, mode)
% G6_ENCODE_PANEL Encode 20x20 pixel data to G6 panel block
%
% Inputs:
%   pixel_data - 20x20 array (row 0 = top, col 0 = left in MATLAB convention)
%                GS2:  logical or uint8 (0=off, 1=on)
%                GS16: uint8 (0-15 intensity levels)
%   stretch    - uint8 scalar (0-255), brightness/timing value
%   mode       - 'GS2' (1-bit) or 'GS16' (4-bit)
%
% Output:
%   panel_block - uint8 array ready for SPI transmission
%                 GS2:  1x53 bytes  [header, cmd, 50 data, stretch]
%                 GS16: 1x203 bytes [header, cmd, 200 data, stretch]
%
% Encoding Convention:
%   - Row-major ordering: pixel_num = row * 20 + col
%   - Origin (0,0) at bottom-left of panel
%   - MATLAB array row 1 = top, so we flip: row_from_bottom = 19 - row
%
% Example:
%   % Binary pattern
%   pixels = rand(20,20) > 0.5;
%   block = g6_encode_panel(pixels, 192, 'GS2');
%
%   % Grayscale pattern
%   pixels = uint8(randi([0 15], 20, 20));
%   block = g6_encode_panel(pixels, 192, 'GS16');

% Validate inputs
assert(isequal(size(pixel_data), [20, 20]), 'pixel_data must be 20x20');
assert(isscalar(stretch) && stretch >= 0 && stretch <= 255, 'stretch must be 0-255');

switch upper(mode)
    case 'GS2'
        panel_block = encode_gs2(pixel_data, stretch);
    case 'GS16'
        panel_block = encode_gs16(pixel_data, stretch);
    otherwise
        error('mode must be ''GS2'' or ''GS16''');
end

end

%% Local Functions

function panel_block = encode_gs2(pixel_mask, stretch)
% Encode 20x20 binary data to 53-byte GS2 block
% Row-major order, (0,0) at bottom-left

pixel_mask = logical(pixel_mask);
panel_block = zeros(1, 53, 'uint8');

% Command byte (0x10 for GS2)
panel_block(2) = uint8(hex2dec('10'));

% Pack pixels into 50 bytes (1 bit per pixel, 400 bits = 50 bytes)
pixel_bytes = zeros(1, 50, 'uint8');

for row = 0:19
    for col = 0:19
        if pixel_mask(row+1, col+1)
            % Flip row so (0,0) is at bottom-left
            row_from_bottom = 19 - row;
            pixel_num = row_from_bottom * 20 + col;
            
            byte_idx = floor(pixel_num / 8) + 1;
            bit_pos = 7 - mod(pixel_num, 8);
            pixel_bytes(byte_idx) = bitset(pixel_bytes(byte_idx), bit_pos + 1);
        end
    end
end

panel_block(3:52) = pixel_bytes;
panel_block(53) = uint8(stretch);

% Compute header with parity
panel_block(1) = compute_header(panel_block, 53);

end

function panel_block = encode_gs16(pixel_data, stretch)
% Encode 20x20 grayscale data to 203-byte GS16 block
% Row-major order, (0,0) at bottom-left

assert(all(pixel_data(:) >= 0 & pixel_data(:) <= 15), 'Pixel values must be 0-15');
pixel_data = uint8(pixel_data);
panel_block = zeros(1, 203, 'uint8');

% Command byte (0x30 for GS16)
panel_block(2) = uint8(hex2dec('30'));

% Pack pixels into 200 bytes (4 bits per pixel, 2 pixels per byte)
pixel_bytes = zeros(1, 200, 'uint8');

for row = 0:19
    for col = 0:19
        pixel_val = pixel_data(row+1, col+1);
        
        % Flip row so (0,0) is at bottom-left
        row_from_bottom = 19 - row;
        pixel_num = row_from_bottom * 20 + col;
        
        byte_idx = floor(pixel_num / 2) + 1;
        if mod(pixel_num, 2) == 0  % Even -> high nibble
            pixel_bytes(byte_idx) = bitor(pixel_bytes(byte_idx), bitshift(pixel_val, 4));
        else  % Odd -> low nibble
            pixel_bytes(byte_idx) = bitor(pixel_bytes(byte_idx), pixel_val);
        end
    end
end

panel_block(3:202) = pixel_bytes;
panel_block(203) = uint8(stretch);

% Compute header with parity
panel_block(1) = compute_header(panel_block, 203);

end

function header = compute_header(panel_block, block_len)
% Compute header byte with version and parity bit per
% docs/development/g6_01-panel-protocol.md § Parity Calculation:
% parity = (count of '1' bits in {version bits 0-6 of byte 0,
%                                 all bits of byte 1,
%                                 all bits of bytes 2..N}) mod 2.

version = uint8(1);                       % v1 protocol; bits 0-6 of byte 0

% Count '1' bits in version's bits 0..6 (exclude bit 7 = parity slot).
% MATLAB bitget is 1-indexed: bits 1..7 == bits 0..6.
% NOTE: use double for the running sum — bitget returns the input class
% (uint8), and a uint8 accumulator saturates at 255. For GS16 panels the
% popcount can reach ~800 and the saturation breaks the parity bit.
total_ones = double(0);
for bit_idx = 1:7
    total_ones = total_ones + double(bitget(version, bit_idx));
end

% Add '1' bits from cmd + payload (bytes 2..block_len in MATLAB 1-indexing).
for byte_idx = 2:block_len
    for bit_idx = 1:8
        total_ones = total_ones + double(bitget(panel_block(byte_idx), bit_idx));
    end
end

if mod(total_ones, 2) == 0
    header = version;
else
    header = bitor(version, uint8(128));  % Set parity bit (bit 7)
end

end

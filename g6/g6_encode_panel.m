function panel_block = g6_encode_panel(pixel_data, stretch, mode)
% G6_ENCODE_PANEL Encode 20x20 pixel data to G6 panel block
%
% Inputs:
%   pixel_data - 20x20 array
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

% LED Mapping Table (G6 Panel v0.1 PCB)
% Maps logical (row, col) to physical LED number (D1-D400)
% Row 0 = top, Col 0 = left
led_map = get_led_map();

switch upper(mode)
    case 'GS2'
        panel_block = encode_gs2(pixel_data, stretch, led_map);
    case 'GS16'
        panel_block = encode_gs16(pixel_data, stretch, led_map);
    otherwise
        error('mode must be ''GS2'' or ''GS16''');
end

end

%% Local Functions

function panel_block = encode_gs2(pixel_mask, stretch, led_map)
% Encode 20x20 binary data to 53-byte GS2 block

pixel_mask = logical(pixel_mask);
panel_block = zeros(1, 53, 'uint8');

% Command byte (0x10 for GS2)
panel_block(2) = uint8(hex2dec('10'));

% Pack pixels into 50 bytes (1 bit per pixel, 400 bits = 50 bytes)
pixel_bytes = zeros(1, 50, 'uint8');

for row = 0:19
    for col = 0:19
        if pixel_mask(row+1, col+1)
            led_num = led_map(row+1, col+1);
            k = led_num - 1;  % 0-indexed
            byte_idx = floor(k / 8) + 1;
            bit_pos = 7 - mod(k, 8);
            pixel_bytes(byte_idx) = bitset(pixel_bytes(byte_idx), bit_pos+1);
        end
    end
end

panel_block(3:52) = pixel_bytes;
panel_block(53) = uint8(stretch);

% Compute header with parity
panel_block(1) = compute_header(panel_block, 53);

end

function panel_block = encode_gs16(pixel_data, stretch, led_map)
% Encode 20x20 grayscale data to 203-byte GS16 block

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
        led_num = led_map(row+1, col+1);
        k = led_num - 1;  % 0-indexed
        
        byte_idx = floor(k / 2) + 1;
        if mod(k, 2) == 0  % Even -> high nibble
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
% Compute header byte with version and parity bit

total_ones = 0;
for byte_idx = 2:block_len
    for bit_idx = 1:8
        total_ones = total_ones + bitget(panel_block(byte_idx), bit_idx);
    end
end

version = uint8(1);
if mod(total_ones, 2) == 0
    header = version;
else
    header = bitor(version, uint8(128));  % Set parity bit
end

end

function led_map = get_led_map()
% LED mapping for G6 Panel v0.1 PCB
% led_map(row+1, col+1) = physical LED number (D1-D400)

led_map = [
50,70,51,71,130,150,131,151,210,230,211,231,290,310,291,311,370,390,371,391;
10,30,11,31,90,110,91,111,170,190,171,191,250,270,251,271,330,350,331,351;
49,69,52,72,129,149,132,152,209,229,212,232,289,309,292,312,369,389,372,392;
9,29,12,32,89,109,92,112,169,189,172,192,249,269,252,272,329,349,332,352;
48,68,53,73,128,148,133,153,208,228,213,233,288,308,293,313,368,388,373,393;
8,28,13,33,88,108,93,113,168,188,173,193,248,268,253,273,328,348,333,353;
47,67,54,74,127,147,134,154,207,227,214,234,287,307,294,314,367,387,374,394;
7,27,14,34,87,107,94,114,167,187,174,194,247,267,254,274,327,347,334,354;
46,66,55,75,126,146,135,155,206,226,215,235,286,306,295,315,366,386,375,395;
6,26,15,35,86,106,95,115,166,186,175,195,246,266,255,275,326,346,335,355;
45,65,56,76,125,145,136,156,205,225,216,236,285,305,296,316,365,385,376,396;
5,25,16,36,85,105,96,116,165,185,176,196,245,265,256,276,325,345,336,356;
44,64,57,77,124,144,137,157,204,224,217,237,284,304,297,317,364,384,377,397;
4,24,17,37,84,104,97,117,164,184,177,197,244,264,257,277,324,344,337,357;
43,63,58,78,123,143,138,158,203,223,218,238,283,303,298,318,363,383,378,398;
3,23,18,38,83,103,98,118,163,183,178,198,243,263,258,278,323,343,338,358;
42,62,59,79,122,142,139,159,202,222,219,239,282,302,299,319,362,382,379,399;
2,22,19,39,82,102,99,119,162,182,179,199,242,262,259,279,322,342,339,359;
41,61,60,80,121,141,140,160,201,221,220,240,281,301,300,320,361,381,380,400;
1,21,20,40,81,101,100,120,161,181,180,200,241,261,260,280,321,341,340,360];

end

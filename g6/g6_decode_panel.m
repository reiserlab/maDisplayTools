function [pixel_data, stretch] = g6_decode_panel(panel_block, mode)
% G6_DECODE_PANEL Decode G6 panel block back to 20x20 pixel data
%
% Inputs:
%   panel_block - uint8 array from binary .pat file
%                 GS2:  1x53 bytes  [header, cmd, 50 data, stretch]
%                 GS16: 1x203 bytes [header, cmd, 200 data, stretch]
%   mode        - 'GS2' (1-bit) or 'GS16' (4-bit)
%
% Outputs:
%   pixel_data - 20x20 array of pixel values
%                GS2:  logical or uint8 (0=off, 1=on)
%                GS16: uint8 (0-15 intensity levels)
%   stretch    - uint8 scalar (0-255), brightness/timing value
%
% Decoding Convention:
%   - Row-major ordering: pixel_num = panel_row * 20 + panel_col
%   - Origin (0,0) at bottom-left of panel
%   - Output is for display with YDir='normal' (row 1 at bottom):
%     Panel row 0 (bottom) -> MATLAB row 1 (displays at bottom)
%     Panel row 19 (top) -> MATLAB row 20 (displays at top)
%
% Example:
%   % Decode a GS16 panel block
%   [pixels, stretch] = g6_decode_panel(panel_block, 'GS16');
%
% See also: g6_encode_panel

switch upper(mode)
    case 'GS2'
        pixel_data = decode_gs2(panel_block);
        stretch = panel_block(53);
    case 'GS16'
        pixel_data = decode_gs16(panel_block);
        stretch = panel_block(203);
    otherwise
        error('mode must be ''GS2'' or ''GS16''');
end

end

%% Local Functions

function pixel_data = decode_gs2(panel_block)
% Decode 53-byte GS2 block to 20x20 binary data
% Row-major order, (0,0) at bottom-left of PANEL
%
% The encoder flips rows (row_from_bottom = 19 - row), so we must flip back.
% For display with YDir='normal' (row 1 at bottom):
%   Panel row 0 (encoded as bottom) -> MATLAB row 20 (top in original)
%   Panel row 19 (encoded as top) -> MATLAB row 1 (bottom in original)

pixel_data = zeros(20, 20, 'uint8');
pixel_bytes = panel_block(3:52);

for panel_row = 0:19
    for panel_col = 0:19
        pixel_num = panel_row * 20 + panel_col;

        byte_idx = floor(pixel_num / 8) + 1;
        bit_pos = 7 - mod(pixel_num, 8);
        pixel_val = bitget(pixel_bytes(byte_idx), bit_pos + 1);

        % Map panel coords to MATLAB coords, compensating for encoder flip
        % panel_row 0 was originally row 19 (top), so map to MATLAB row 20
        matlab_row = 20 - panel_row;
        matlab_col = panel_col + 1;
        pixel_data(matlab_row, matlab_col) = pixel_val;
    end
end

end

function pixel_data = decode_gs16(panel_block)
% Decode 203-byte GS16 block to 20x20 grayscale data
% Row-major order, (0,0) at bottom-left of PANEL
%
% The encoder flips rows (row_from_bottom = 19 - row), so we must flip back.
% For display with YDir='normal' (row 1 at bottom):
%   Panel row 0 (encoded as bottom) -> MATLAB row 20 (top in original)
%   Panel row 19 (encoded as top) -> MATLAB row 1 (bottom in original)

pixel_data = zeros(20, 20, 'uint8');
pixel_bytes = panel_block(3:202);

for panel_row = 0:19
    for panel_col = 0:19
        pixel_num = panel_row * 20 + panel_col;

        byte_idx = floor(pixel_num / 2) + 1;
        if mod(pixel_num, 2) == 0  % Even -> high nibble
            pixel_val = bitshift(pixel_bytes(byte_idx), -4);
        else  % Odd -> low nibble
            pixel_val = bitand(pixel_bytes(byte_idx), 15);
        end

        % Map panel coords to MATLAB coords, compensating for encoder flip
        % panel_row 0 was originally row 19 (top), so map to MATLAB row 20
        matlab_row = 20 - panel_row;
        matlab_col = panel_col + 1;
        pixel_data(matlab_row, matlab_col) = pixel_val;
    end
end

end

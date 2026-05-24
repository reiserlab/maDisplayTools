function crc = crc16_ccitt_false(bytes)
% CRC16_CCITT_FALSE Compute CRC-16/CCITT-FALSE over a byte sequence.
%
% Used for the G6 .pat per-frame trailer over {FR_magic, frame_index,
% panel_blocks} of that frame only. Trailer is 2 bytes appended little-endian
% after the panel blocks of each frame.
%
% Parameters (per Modular-LED-Display/docs/development/g6_04-pattern-file-format.md):
%   polynomial : 0x1021
%   init       : 0xFFFF
%   refin/refout : false / false
%   xorout     : 0x0000
%   universal check : 0x29B1 over "123456789"
%
% The 256-entry LUT is built from the polynomial constant on first call and
% cached in a persistent variable. The universal check runs alongside the
% LUT build and ERRORS on mismatch.
%
% Input:
%   bytes - uint8 vector (any length, including empty)
%
% Output:
%   crc - uint16

    persistent LUT;
    if isempty(LUT)
        LUT = zeros(256, 1, 'uint16');
        poly = uint16(hex2dec('1021'));
        for b = 0:255
            c = uint16(bitshift(uint16(b), 8));
            for i = 1:8
                if bitand(c, uint16(32768)) ~= 0
                    c = bitxor(uint16(bitshift(c, 1)), poly);
                else
                    c = uint16(bitshift(c, 1));
                end
                c = bitand(c, uint16(65535));
            end
            LUT(b + 1) = c;
        end

        % Universal-check gate: "123456789" -> 0x29B1
        ucheck = uint8('123456789');
        c = uint16(65535);
        for i = 1:length(ucheck)
            idx = bitand(bitxor(bitshift(c, -8), uint16(ucheck(i))), uint16(255));
            c = bitand(bitxor(uint16(bitshift(c, 8)), LUT(idx + 1)), uint16(65535));
        end
        if c ~= uint16(hex2dec('29B1'))
            error('crc16_ccitt_false:LUTBuildFailed', ...
                  'CRC-16/CCITT-FALSE universal check failed: got 0x%04X, expected 0x29B1', c);
        end
    end

    c = uint16(65535);
    for i = 1:length(bytes)
        idx = bitand(bitxor(bitshift(c, -8), uint16(bytes(i))), uint16(255));
        c = bitand(bitxor(uint16(bitshift(c, 8)), LUT(idx + 1)), uint16(65535));
    end
    crc = c;
end

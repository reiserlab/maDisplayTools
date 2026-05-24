function crc = crc8_autosar(bytes)
% CRC8_AUTOSAR Compute CRC-8/AUTOSAR over a byte sequence.
%
% Used for the G6 .pat file header byte 17 (CRC over header bytes 0-16) and
% for the panel-protocol wire-level CIPO confirmation byte (handled by the
% panel firmware, not encoders).
%
% Parameters (per Modular-LED-Display/docs/development/g6_01-panel-protocol.md):
%   polynomial : 0x2F  (Koopman 0x97)
%   init       : 0xFF
%   refin/refout : false / false
%   xorout     : 0xFF
%   universal check : 0xDF over "123456789"
%
% The 256-entry LUT is built from the polynomial constant on first call and
% cached in a persistent variable. The universal check runs alongside the
% LUT build and ERRORS on mismatch — that's the gate that catches table-
% construction bugs before any encoder/parser uses the function.
%
% Input:
%   bytes - uint8 vector (any length, including empty)
%
% Output:
%   crc - uint8

    persistent LUT;
    if isempty(LUT)
        LUT = zeros(256, 1, 'uint8');
        poly = uint8(hex2dec('2F'));
        for b = 0:255
            c = uint8(b);
            for i = 1:8
                if bitand(c, 128) ~= 0
                    c = bitxor(uint8(bitshift(c, 1)), poly);
                else
                    c = uint8(bitshift(c, 1));
                end
            end
            LUT(b + 1) = c;
        end

        % Universal-check gate: "123456789" -> 0xDF
        % NOTE on indexing: bitxor on uint8 returns uint8, and adding 1 to
        % uint8(255) SATURATES at 255 rather than rolling over to 256. Cast
        % the XOR result to double before `+ 1` so the LUT lookup hits the
        % correct entry for the byte-value 0xFF.
        ucheck = uint8('123456789');
        c = uint8(255);
        for i = 1:length(ucheck)
            c = LUT(double(bitxor(c, ucheck(i))) + 1);
        end
        c = bitxor(c, uint8(255));
        if c ~= uint8(hex2dec('DF'))
            error('crc8_autosar:LUTBuildFailed', ...
                  'CRC-8/AUTOSAR universal check failed: got 0x%02X, expected 0xDF', c);
        end
    end

    c = uint8(255);
    for i = 1:length(bytes)
        c = LUT(double(bitxor(c, uint8(bytes(i)))) + 1);
    end
    crc = bitxor(c, uint8(255));
end

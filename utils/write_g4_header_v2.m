function header = write_g4_header_v2(NumPatsX, NumPatsY, GSLevels, RowN, ColN, generation_id, arena_id)
% WRITE_G4_HEADER_V2 Generate G4 pattern header (V2 format with generation + arena metadata)
%
% Creates the 7-byte header for G4/G4.1 pattern files with optional V2 metadata.
% V2 format uses previously unused bytes 2-3 to store generation and arena config.
%
% Inputs:
%   NumPatsX      - Number of patterns in X dimension (uint16)
%   NumPatsY      - Number of patterns in Y dimension (uint16)
%   GSLevels      - Grayscale levels (2 or 16)
%   RowN          - Number of panel rows (uint8)
%   ColN          - Number of panel columns (uint8)
%   generation_id - (optional) Generation ID (0-7), 0=unspecified/V1
%   arena_id      - (optional) Arena config ID (0-255), 0=unspecified
%
% Outputs:
%   header - 1×7 uint8 array containing the pattern header
%
% Header Format (7 bytes):
%   Bytes 0-1: NumPatsX (uint16 little-endian)
%   Byte 2:    V2 flag + generation + reserved
%              [V][GGG][RRRR] where V=version flag, G=generation, R=reserved
%   Byte 3:    Arena config ID (8 bits, 0-255)
%   Byte 4:    GSLevels (2 or 16)
%   Byte 5:    RowN (number of panel rows)
%   Byte 6:    ColN (number of panel columns)
%
% Version Detection:
%   V1: Byte 2 < 0x80 (MSB not set)
%   V2: Byte 2 >= 0x80 (MSB set)
%
% Generation Values:
%   0: Unspecified/legacy
%   1: G3
%   2: G4
%   3: G4.1
%   4: G6
%   5-7: Reserved
%
% Arena ID Ranges:
%   0:       Unspecified/custom
%   1-10:    Reiser lab official
%   11-200:  Community registered
%   201-254: User-defined/experimental
%   255:     Reserved
%
% Examples:
%   % V1 header (backward compatible)
%   header = write_g4_header_v2(96, 1, 16, 2, 12);
%
%   % V2 header with G4.1 + arena ID 4
%   header = write_g4_header_v2(96, 1, 16, 2, 12, 3, 4);
%
% See also: read_g4_header, get_generation_id, get_arena_id

% Handle optional arguments (default to V1 format)
if nargin < 6 || isempty(generation_id)
    generation_id = 0;  % V1 format
end
if nargin < 7 || isempty(arena_id)
    arena_id = 0;
end

% Validate inputs
assert(NumPatsX >= 0 && NumPatsX <= 65535, 'NumPatsX must be 0-65535');
assert(NumPatsY >= 0 && NumPatsY <= 65535, 'NumPatsY must be 0-65535');
assert(ismember(GSLevels, [2, 16]), 'GSLevels must be 2 or 16');
assert(RowN >= 0 && RowN <= 255, 'RowN must be 0-255');
assert(ColN >= 0 && ColN <= 255, 'ColN must be 0-255');
assert(generation_id >= 0 && generation_id <= 7, 'generation_id must be 0-7');
assert(arena_id >= 0 && arena_id <= 255, 'arena_id must be 0-255');

% Initialize header
header = zeros(1, 7, 'uint8');

% Bytes 0-1: NumPatsX (little-endian uint16)
header(1) = uint8(mod(NumPatsX, 256));        % Low byte
header(2) = uint8(floor(NumPatsX / 256));     % High byte

% Bytes 2-3: Config bytes
if generation_id == 0
    % V1 format: NumPatsY as uint16 little-endian
    header(3) = uint8(mod(NumPatsY, 256));    % Low byte
    header(4) = uint8(floor(NumPatsY / 256)); % High byte
else
    % V2 format: bit-packed generation + arena_id
    % Byte 2: [V][GGG][RRRR] where V=1, GGG=generation (3 bits), RRRR=reserved (must be 0)
    v2_flag = uint8(bitshift(1, 7));              % Set MSB (bit 7)
    gen_bits = uint8(bitshift(generation_id, 4)); % Bits 6-4
    reserved = uint8(0);                          % Bits 3-0 (must be 0)
    header(3) = bitor(bitor(v2_flag, gen_bits), reserved);

    % Byte 3: Arena config ID (8 bits)
    header(4) = uint8(arena_id);
end

% Bytes 4-6: Standard fields
header(5) = uint8(GSLevels);
header(6) = uint8(RowN);
header(7) = uint8(ColN);

end

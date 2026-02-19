function info = read_g6_header(header)
% READ_G6_HEADER Parse G6 pattern header (V1 or V2 format)
%
% Parses the 17-byte (V1) or 18-byte (V2) header from G6 pattern files.
% Auto-detects version from byte 5.
%
% Input:
%   header - uint8 vector containing the pattern header (17 or 18 bytes)
%
% Output:
%   info - Structure with fields:
%     .version        - 1 or 2
%     .arena_id       - Arena config ID (0-63), V2 only
%     .observer_id    - Observer position ID (0-63), V2 only
%     .num_frames     - Number of frames
%     .row_count      - Number of panel rows
%     .col_count      - Number of panel columns (full grid)
%     .gs_val         - Grayscale mode (1=GS2, 2=GS16)
%     .panel_mask     - 6-byte panel presence mask
%     .checksum       - Checksum byte
%
% G6 V1 Header (17 bytes):
%   Bytes 1-4:   Magic "G6PT"
%   Byte 5:      Version (1)
%   Byte 6:      gs_val
%   Bytes 7-8:   num_frames
%   Byte 9:      row_count
%   Byte 10:     col_count
%   Byte 11:     checksum
%   Bytes 12-17: panel_mask
%
% G6 V2 Header (18 bytes):
%   Bytes 1-4:   Magic "G6PT"
%   Byte 5:      [VVVV][AAAA] - Version (4 bits) + Arena ID upper 4 bits
%   Byte 6:      [AA][OOOOOO] - Arena ID lower 2 bits + Observer ID (6 bits)
%   Bytes 7-8:   num_frames
%   Byte 9:      row_count
%   Byte 10:     col_count
%   Byte 11:     gs_val
%   Bytes 12-17: panel_mask
%   Byte 18:     checksum
%
% Examples:
%   % Read from file
%   fid = fopen('pattern_G6.pat', 'r');
%   header = fread(fid, 18, 'uint8');
%   fclose(fid);
%   info = read_g6_header(header);
%
% See also: write_g6_header, read_g4_header

% Validate input
assert(isvector(header) && (length(header) == 17 || length(header) == 18), ...
    'Header must be 17-byte (V1) or 18-byte (V2) vector');
header = uint8(header(:));  % Ensure column vector

% Initialize output structure
info = struct();

% Validate magic bytes
magic = char(header(1:4)');
assert(strcmp(magic, 'G6PT'), 'Invalid magic bytes (expected "G6PT", got "%s")', magic);

% Byte 5: Extract version
version_byte = header(5);

% Check if this is V1 (version stored as full byte) or V2 (upper 4 bits)
% V1: byte 5 = 1 (value < 16)
% V2: byte 5 upper nibble = 2 (value >= 32)
if version_byte < 16
    % V1 format: version stored as full byte value
    info.version = double(version_byte);
else
    % V2 format: version in upper 4 bits
    info.version = bitshift(version_byte, -4);
end

if info.version == 1
    % V1 format (17 bytes)
    assert(length(header) == 17, 'V1 header must be exactly 17 bytes');

    info.arena_id = 0;      % Not present in V1
    info.observer_id = 0;   % Not present in V1

    info.gs_val = double(header(6));
    info.num_frames = double(header(7)) + double(header(8)) * 256;
    info.row_count = double(header(9));
    info.col_count = double(header(10));
    info.checksum = header(11);
    info.panel_mask = header(12:17);

elseif info.version == 2
    % V2 format (18 bytes)
    assert(length(header) >= 18, 'V2 header must be at least 18 bytes');

    % Byte 5: Lower 4 bits are upper bits of arena_id
    arena_upper = bitand(version_byte, 15);  % Lower 4 bits of byte 5

    % Byte 6: Upper 2 bits are lower bits of arena_id, lower 6 bits are observer_id
    byte6 = header(6);
    arena_lower = bitshift(byte6, -6);  % Upper 2 bits
    info.arena_id = bitor(bitshift(arena_upper, 2), arena_lower);  % Combine to 6 bits
    info.observer_id = bitand(byte6, 63);  % Lower 6 bits

    info.num_frames = double(header(7)) + double(header(8)) * 256;
    info.row_count = double(header(9));
    info.col_count = double(header(10));
    info.gs_val = double(header(11));
    info.panel_mask = header(12:17);
    info.checksum = header(18);

else
    error('Unsupported G6 header version: %d (expected 1 or 2)', info.version);
end

% Validate gs_val
if ~ismember(info.gs_val, [1, 2])
    warning('Unusual gs_val: %d (expected 1=GS2 or 2=GS16)', info.gs_val);
end

end

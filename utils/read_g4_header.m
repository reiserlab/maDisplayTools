function info = read_g4_header(header)
% READ_G4_HEADER Parse G4 pattern header (V1 or V2 format)
%
% Parses the 7-byte header from G4/G4.1 pattern files and auto-detects
% V1 (legacy) vs V2 (with generation + arena metadata) format.
%
% Input:
%   header - 1×7 or 7×1 uint8 array containing the pattern header
%
% Output:
%   info - Structure with fields:
%     .version        - 1 (legacy) or 2 (with metadata)
%     .NumPatsX       - Number of patterns in X dimension
%     .NumPatsY       - Number of patterns in Y dimension (V1 only)
%     .generation_id  - Generation ID (0-7), V2 only
%     .generation     - Generation name ('G3', 'G4', 'G4.1', 'G6'), V2 only
%     .arena_id       - Arena config ID (0-255), V2 only
%     .GSLevels       - Grayscale levels (2 or 16)
%     .RowN           - Number of panel rows
%     .ColN           - Number of panel columns
%
% Version Detection:
%   V1: Byte 2 < 0x80 (MSB not set) → legacy format
%   V2: Byte 2 >= 0x80 (MSB set) → new format with metadata
%
% Examples:
%   % Read from file
%   fid = fopen('pattern_G4.pat', 'r');
%   header = fread(fid, 7, 'uint8');
%   fclose(fid);
%   info = read_g4_header(header);
%   fprintf('Generation: %s\n', info.generation);
%
% See also: write_g4_header_v2, get_generation_name, get_arena_name

% Validate input
assert(isvector(header) && length(header) == 7, 'Header must be 7-byte vector');
header = uint8(header(:));  % Ensure column vector

% Initialize output structure
info = struct();

% Bytes 0-1: NumPatsX (little-endian uint16)
info.NumPatsX = double(header(1)) + double(header(2)) * 256;

% Detect version by checking MSB of byte 2
config_high = header(3);
is_v2 = config_high >= hex2dec('80');

if is_v2
    % V2 format
    info.version = 2;

    % Byte 2: Extract generation from bits 6-4
    info.generation_id = bitand(bitshift(config_high, -4), 7);

    % Byte 3: Arena config ID
    info.arena_id = double(header(4));

    % NumPatsY not stored in V2 (assume 1 for compatibility)
    info.NumPatsY = 1;

    % Map generation ID to name
    info.generation = get_generation_name(info.generation_id);
else
    % V1 format (legacy)
    info.version = 1;

    % Bytes 2-3: NumPatsY (little-endian uint16)
    info.NumPatsY = double(header(3)) + double(header(4)) * 256;

    % No generation/arena metadata in V1
    info.generation_id = 0;
    info.generation = 'unspecified';
    info.arena_id = 0;
end

% Bytes 4-6: Standard fields (same for V1 and V2)
info.GSLevels = double(header(5));
info.RowN = double(header(6));
info.ColN = double(header(7));

% Validate GSLevels
if ~ismember(info.GSLevels, [2, 16])
    warning('Unusual GSLevels value: %d (expected 2 or 16)', info.GSLevels);
end

end

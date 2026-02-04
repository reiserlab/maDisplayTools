function generate_web_pattern_reference()
    % GENERATE_WEB_PATTERN_REFERENCE Generate reference data for web pattern editor validation
    %
    % This script creates simple 2D patterns that can be used to validate
    % the web-based pattern editor. Unlike the full Pattern_Generator which
    % uses spherical coordinates, these patterns are generated on a flat
    % 2D pixel grid representing the unwrapped arena.
    %
    % Output: pattern_generation_reference.json
    %   Copy to: webDisplayTools/data/pattern_generation_reference.json
    %
    % Usage:
    %   generate_web_pattern_reference()
    %
    % See also: Pattern_Generator, make_grating_edge, make_starfield, make_off_on

    %% Standard arena configuration (G6_2x10)
    arena.generation = 'G6';
    arena.rows = 2;           % Panel rows (vertical)
    arena.cols = 10;          % Panel columns (around)
    arena.panelSize = 20;     % Pixels per panel
    arena.pixelRows = arena.rows * arena.panelSize;    % 40
    arena.pixelCols = arena.cols * arena.panelSize;    % 200

    %% Initialize output structure
    output = struct();
    output.generated = datestr(now, 'yyyy-mm-ddTHH:MM:SS');
    output.source = 'MATLAB generate_web_pattern_reference.m';
    output.matlabVersion = version;

    % Convention documentation
    output.convention.origin = 'bottom-left';
    output.convention.rowOrder = 'row 0 = bottom';
    output.convention.pixelOrder = 'row-major';
    output.convention.notes = 'Pixel values are 0-15 for GS16 mode. Frame 0 pixels are a 1D array in row-major order (row 0 first, then row 1, etc.)';

    %% Generate all pattern types
    fprintf('Generating patterns for %s arena (%dx%d panels, %dx%d pixels)...\n', ...
        arena.generation, arena.rows, arena.cols, arena.pixelRows, arena.pixelCols);

    % 1. Square wave grating (20 pixel wavelength)
    fprintf('  - Generating grating (20px wavelength)...\n');
    patterns.grating_20px_cw_gs16 = generateGrating(arena, 20, 'cw', 50, 15, 0);

    % 2. Sine grating (40 pixel wavelength)
    fprintf('  - Generating sine grating (40px wavelength)...\n');
    patterns.sine_40px_cw_gs16 = generateSineGrating(arena, 40, 'cw', 15, 0);

    % 3. Starfield (100 dots, deterministic seed)
    fprintf('  - Generating starfield (100 dots)...\n');
    patterns.starfield_100_seed12345 = generateStarfield(arena, 100, 1, 15, 12345);

    % 4. Edge pattern
    fprintf('  - Generating edge pattern...\n');
    patterns.edge_middle_gs16 = generateEdge(arena, 15, 0);

    % 5. Off/On pattern
    fprintf('  - Generating off/on pattern...\n');
    patterns.offon_gs16 = generateOffOn(arena, 15, 0);

    output.patterns = patterns;

    %% Save as JSON
    jsonStr = jsonencode(output, 'PrettyPrint', true);

    % Write to file
    outputFile = fullfile(fileparts(mfilename('fullpath')), 'pattern_generation_reference.json');
    fid = fopen(outputFile, 'w');
    fprintf(fid, '%s', jsonStr);
    fclose(fid);

    fprintf('\nReference data saved to:\n  %s\n', outputFile);
    fprintf('\nCopy this file to webDisplayTools/data/pattern_generation_reference.json\n');
end

%% ========================================================================
%  Pattern Generation Functions
%  ========================================================================

function result = generateGrating(arena, wavelength, direction, dutyCycle, high, low)
    % GENERATEGRATING Generate square wave grating pattern
    %
    % Parameters:
    %   arena       - Arena configuration struct
    %   wavelength  - Pattern wavelength in pixels
    %   direction   - 'cw' (clockwise) or 'ccw' (counter-clockwise)
    %   dutyCycle   - Percentage of wavelength at high value (0-100)
    %   high        - Brightness for ON pixels (0-15)
    %   low         - Brightness for OFF pixels (0-15)
    %
    % Returns struct with params, arena info, and result data

    numRows = arena.pixelRows;
    numCols = arena.pixelCols;

    % Number of frames = wavelength (for complete cycle)
    numFrames = wavelength;

    % Pre-allocate pattern array
    Pats = zeros(numRows, numCols, numFrames);

    % Calculate duty cycle threshold
    onPixels = round(wavelength * dutyCycle / 100);

    % Generate each frame
    for f = 1:numFrames
        % Phase offset for this frame (in pixels)
        if strcmpi(direction, 'cw')
            phaseOffset = f - 1;  % Clockwise = positive direction
        else
            phaseOffset = -(f - 1);  % Counter-clockwise
        end

        % Generate the pattern for this frame
        for col = 0:(numCols-1)
            % Calculate position within wavelength
            pos = mod(col + phaseOffset, wavelength);

            % Determine brightness based on duty cycle
            if pos < onPixels
                brightness = high;
            else
                brightness = low;
            end

            % Fill entire column with this brightness
            Pats(:, col+1, f) = brightness;
        end
    end

    % Build result structure
    result = struct();
    result.type = 'grating';
    result.params.wavelength = wavelength;
    result.params.direction = direction;
    result.params.dutyCycle = dutyCycle;
    result.params.high = high;
    result.params.low = low;

    result.arena.generation = arena.generation;
    result.arena.rows = arena.rows;
    result.arena.cols = arena.cols;
    result.arena.panelSize = arena.panelSize;
    result.arena.pixelRows = numRows;
    result.arena.pixelCols = numCols;

    result.result.totalFrames = numFrames;
    result.result.gsMode = 16;

    % Convert frame 0 to 1D array (row-major, row 0 = bottom)
    frame0 = Pats(:, :, 1);
    % In MATLAB, row 1 is top, but we want row 0 = bottom (web convention)
    frame0_flipped = flipud(frame0);  % Flip so row 1 becomes bottom
    result.result.frame0_pixels = reshape(frame0_flipped', 1, []);  % Row-major order

    % Also include a few more frames for verification
    if numFrames >= 5
        frame4 = Pats(:, :, 5);
        frame4_flipped = flipud(frame4);
        result.result.frame4_pixels = reshape(frame4_flipped', 1, []);
    end

    % Calculate checksum (SHA-256 of frame0 data as string)
    frame0_str = mat2str(result.result.frame0_pixels);
    result.result.checksum = calculateSHA256(frame0_str);
end

function result = generateSineGrating(arena, wavelength, direction, high, low)
    % GENERATESINEGRATING Generate sine wave grating pattern
    %
    % Parameters:
    %   arena       - Arena configuration struct
    %   wavelength  - Pattern wavelength in pixels
    %   direction   - 'cw' (clockwise) or 'ccw' (counter-clockwise)
    %   high        - Maximum brightness (0-15)
    %   low         - Minimum brightness (0-15)

    numRows = arena.pixelRows;
    numCols = arena.pixelCols;

    % Number of frames = wavelength (for complete cycle)
    numFrames = wavelength;

    % Pre-allocate pattern array
    Pats = zeros(numRows, numCols, numFrames);

    % Amplitude and offset
    amplitude = (high - low) / 2;
    offset = (high + low) / 2;

    % Generate each frame
    for f = 1:numFrames
        % Phase offset for this frame (in radians)
        if strcmpi(direction, 'cw')
            phaseOffset = (f - 1) * 2 * pi / wavelength;
        else
            phaseOffset = -(f - 1) * 2 * pi / wavelength;
        end

        % Generate the pattern for this frame
        for col = 0:(numCols-1)
            % Calculate sine value
            angle = col * 2 * pi / wavelength - phaseOffset;
            brightness = round(offset + amplitude * sin(angle));

            % Clamp to valid range
            brightness = max(0, min(15, brightness));

            % Fill entire column with this brightness
            Pats(:, col+1, f) = brightness;
        end
    end

    % Build result structure
    result = struct();
    result.type = 'sine';
    result.params.wavelength = wavelength;
    result.params.direction = direction;
    result.params.high = high;
    result.params.low = low;

    result.arena.generation = arena.generation;
    result.arena.rows = arena.rows;
    result.arena.cols = arena.cols;
    result.arena.panelSize = arena.panelSize;
    result.arena.pixelRows = numRows;
    result.arena.pixelCols = numCols;

    result.result.totalFrames = numFrames;
    result.result.gsMode = 16;

    % Convert frame 0 to 1D array (row-major, row 0 = bottom)
    frame0 = Pats(:, :, 1);
    frame0_flipped = flipud(frame0);
    result.result.frame0_pixels = reshape(frame0_flipped', 1, []);

    % Include additional frames
    if numFrames >= 10
        frame9 = Pats(:, :, 10);
        frame9_flipped = flipud(frame9);
        result.result.frame9_pixels = reshape(frame9_flipped', 1, []);
    end

    % Calculate checksum
    frame0_str = mat2str(result.result.frame0_pixels);
    result.result.checksum = calculateSHA256(frame0_str);
end

function result = generateStarfield(arena, dotCount, dotSize, brightness, randomSeed)
    % GENERATESTARFIELD Generate starfield pattern with random dots
    %
    % Parameters:
    %   arena       - Arena configuration struct
    %   dotCount    - Number of dots to generate
    %   dotSize     - Size of each dot in pixels (1 = single pixel)
    %   brightness  - Brightness of dots (0-15)
    %   randomSeed  - Random seed for reproducibility

    numRows = arena.pixelRows;
    numCols = arena.pixelCols;

    % Set random seed for reproducibility
    rng(randomSeed);

    % Generate random dot positions
    dotRows = randi([1, numRows], dotCount, 1);
    dotCols = randi([1, numCols], dotCount, 1);

    % Create single frame pattern (static starfield)
    numFrames = 1;
    Pats = zeros(numRows, numCols, numFrames);

    % Place dots
    for i = 1:dotCount
        % Handle dot size (simple implementation)
        for dr = 0:(dotSize-1)
            for dc = 0:(dotSize-1)
                r = mod(dotRows(i) + dr - 1, numRows) + 1;
                c = mod(dotCols(i) + dc - 1, numCols) + 1;
                Pats(r, c, 1) = brightness;
            end
        end
    end

    % Build result structure
    result = struct();
    result.type = 'starfield';
    result.params.dotCount = dotCount;
    result.params.dotSize = dotSize;
    result.params.brightness = brightness;
    result.params.randomSeed = randomSeed;

    result.arena.generation = arena.generation;
    result.arena.rows = arena.rows;
    result.arena.cols = arena.cols;
    result.arena.panelSize = arena.panelSize;
    result.arena.pixelRows = numRows;
    result.arena.pixelCols = numCols;

    result.result.totalFrames = numFrames;
    result.result.gsMode = 16;

    % Convert frame 0 to 1D array (row-major, row 0 = bottom)
    frame0 = Pats(:, :, 1);
    frame0_flipped = flipud(frame0);
    result.result.frame0_pixels = reshape(frame0_flipped', 1, []);

    % Store dot positions (for verification)
    % Convert to 0-indexed, bottom-left origin
    result.result.dotPositions = struct();
    result.result.dotPositions.rows = numRows - dotRows;  % Flip row indices
    result.result.dotPositions.cols = dotCols - 1;        % Convert to 0-indexed

    % Store actual non-zero pixel count (may differ from dotCount due to overlaps)
    result.result.litPixelCount = sum(result.result.frame0_pixels > 0);

    % Calculate checksum
    frame0_str = mat2str(result.result.frame0_pixels);
    result.result.checksum = calculateSHA256(frame0_str);
end

function result = generateEdge(arena, high, low)
    % GENERATEEDGE Generate advancing edge pattern
    %
    % Parameters:
    %   arena       - Arena configuration struct
    %   high        - Brightness for bright side (0-15)
    %   low         - Brightness for dark side (0-15)
    %
    % The edge starts at the left and advances rightward.
    % Edge position at frame f is at column f (0-indexed).

    numRows = arena.pixelRows;
    numCols = arena.pixelCols;

    % Number of frames = numCols + 1 (from all-dark to all-bright)
    numFrames = numCols + 1;

    % Pre-allocate pattern array
    Pats = zeros(numRows, numCols, numFrames);

    % Generate each frame
    for f = 1:numFrames
        % Edge position (number of bright columns from left)
        edgePos = f - 1;  % 0 to numCols

        % Fill pattern
        for col = 0:(numCols-1)
            if col < edgePos
                Pats(:, col+1, f) = high;  % Bright side (left of edge)
            else
                Pats(:, col+1, f) = low;   % Dark side (right of edge)
            end
        end
    end

    % Build result structure
    result = struct();
    result.type = 'edge';
    result.params.edgePosition = 0.5;  % Normalized position (middle at frame numCols/2)
    result.params.polarity = 'light-to-dark';  % From left to right
    result.params.high = high;
    result.params.low = low;

    result.arena.generation = arena.generation;
    result.arena.rows = arena.rows;
    result.arena.cols = arena.cols;
    result.arena.panelSize = arena.panelSize;
    result.arena.pixelRows = numRows;
    result.arena.pixelCols = numCols;

    result.result.totalFrames = numFrames;
    result.result.gsMode = 16;

    % Convert frame 0 to 1D array (row-major, row 0 = bottom)
    % Frame 0 is all dark (edge at position 0)
    frame0 = Pats(:, :, 1);
    frame0_flipped = flipud(frame0);
    result.result.frame0_pixels = reshape(frame0_flipped', 1, []);

    % Also include middle frame (edge at center)
    middleFrame = ceil(numFrames / 2);
    frameMiddle = Pats(:, :, middleFrame);
    frameMiddle_flipped = flipud(frameMiddle);
    result.result.frameMiddle_pixels = reshape(frameMiddle_flipped', 1, []);
    result.result.middleFrameIndex = middleFrame - 1;  % 0-indexed

    % Calculate checksum
    frame0_str = mat2str(result.result.frame0_pixels);
    result.result.checksum = calculateSHA256(frame0_str);
end

function result = generateOffOn(arena, high, low)
    % GENERATEOFFON Generate simple off/on pattern (uniform brightness ramp)
    %
    % Parameters:
    %   arena - Arena configuration struct
    %   high  - Maximum brightness (0-15)
    %   low   - Minimum brightness (0-15)
    %
    % Creates frames from low to high brightness (inclusive)

    numRows = arena.pixelRows;
    numCols = arena.pixelCols;

    % Number of frames = difference + 1
    numFrames = abs(high - low) + 1;

    % Pre-allocate pattern array
    Pats = zeros(numRows, numCols, numFrames);

    % Generate each frame (uniform brightness)
    for f = 1:numFrames
        if low <= high
            brightness = low + (f - 1);
        else
            brightness = low - (f - 1);
        end
        Pats(:, :, f) = brightness;
    end

    % Build result structure
    result = struct();
    result.type = 'offon';
    result.params.high = high;
    result.params.low = low;

    result.arena.generation = arena.generation;
    result.arena.rows = arena.rows;
    result.arena.cols = arena.cols;
    result.arena.panelSize = arena.panelSize;
    result.arena.pixelRows = numRows;
    result.arena.pixelCols = numCols;

    result.result.totalFrames = numFrames;
    result.result.gsMode = 16;

    % Convert frame 0 to 1D array (row-major, row 0 = bottom)
    frame0 = Pats(:, :, 1);
    frame0_flipped = flipud(frame0);
    result.result.frame0_pixels = reshape(frame0_flipped', 1, []);

    % Also include last frame
    frameLast = Pats(:, :, end);
    frameLast_flipped = flipud(frameLast);
    result.result.frameLast_pixels = reshape(frameLast_flipped', 1, []);

    % Calculate checksum
    frame0_str = mat2str(result.result.frame0_pixels);
    result.result.checksum = calculateSHA256(frame0_str);
end

%% ========================================================================
%  Utility Functions
%  ========================================================================

function hash = calculateSHA256(inputStr)
    % CALCULATESHA256 Calculate SHA-256 hash of input string
    %
    % Uses Java MessageDigest if available, otherwise returns placeholder

    try
        md = java.security.MessageDigest.getInstance('SHA-256');
        md.update(uint8(inputStr));
        hashBytes = typecast(md.digest, 'uint8');
        hash = sprintf('%02x', hashBytes);
    catch
        % Fallback if Java not available
        hash = 'sha256_not_available';
    end
end

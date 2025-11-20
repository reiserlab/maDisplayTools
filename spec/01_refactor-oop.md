# Object-Oriented Refactoring Specification for maDisplayTools

## Executive Summary

This document outlines a refactoring plan to transform `maDisplayTools` from a static method-based architecture to a cleaner, more maintainable object-oriented design that **feels natural in MATLAB**. The goal is to improve code organization, reduce duplication, and make the codebase easier to extend while maintaining backward compatibility.

Unlike the Python implementation (`pyDisplayTools`), this refactoring embraces MATLAB's strengths:
- Simple, practical class hierarchies (not deep abstract hierarchies)
- Struct-based configurations where appropriate (MATLAB developers expect structs)
- Handle classes where state matters, value classes for data containers
- Minimal package nesting (MATLAB's package system is more limited than Python's)
- Focus on interactive workflow and GUI integration

## Current State Analysis

### Existing Architecture

The current `maDisplayTools.m` is a single class with static methods:

**Pattern Creation:**
- `generate_pattern_from_array()` - Main entry point
- `save_pattern_g4()` - Save to .pat file
- `make_pattern_vector_g4()` - Encode to binary

**Pattern Encoding:**
- `make_framevector_gs16()` - Encode grayscale frames
- `make_framevector_binary()` - Encode binary frames

**Pattern Reading:**
- `load_pat()` - Read .pat file
- `decode_framevector_gs16()` - Decode grayscale
- `decode_framevector_binary()` - Decode binary

**Preview & Utilities:**
- `preview_pat()` - Launch preview GUI
- `get_pattern_id()` - Auto-assign IDs
- Various helper functions

**Experiment Builder:**
- `create_experiment_folder_g41()` - Build experiment from YAML

### Key Issues

1. **Code Duplication**: Encoding/decoding logic is split between multiple functions with shared validation and dimension calculations
2. **Scattered Parameters**: Pattern metadata (dimensions, grayscale mode, ID) passed separately instead of bundled
3. **Hard to Extend**: Adding G4.1 or G6 support would require duplicating all encoding functions
4. **Magic Numbers**: Panel size (16), grayscale values (2, 16) scattered throughout
5. **Inconsistent Error Handling**: Some functions validate, others don't
6. **No Intermediate Representation**: Jump directly from array to binary file

## Proposed Architecture

### Design Philosophy: MATLAB-Native OOP

**Key Principles:**
1. **Structs for Configuration**: Use structs for immutable configuration data (MATLAB users expect this)
2. **Classes for Behavior**: Use classes when you need methods and state management
3. **Shallow Hierarchies**: Prefer composition over deep inheritance trees
4. **Simple Packages**: Use `+package` for organization, not complex namespace hierarchies
5. **Progressive Enhancement**: Keep simple things simple, add complexity only where needed
6. **Backward Compatible**: Old API continues to work during transition

### Package Structure

```
+maDisplayTools/
├── Pattern.m              % Main pattern data class (replaces raw arrays)
├── Arena.m                % Arena configuration class
├── PatternFile.m          % File I/O class
├── PatternPreview.m       % Enhanced preview (move from root)
└── +internal/             % Internal implementation details
    ├── EncoderG4.m        % G4 encoding/decoding
    ├── EncoderG41.m       % G4.1 encoding/decoding (future)
    └── PatternUtils.m     % Shared utilities
```

Root directory keeps `maDisplayTools.m` for backward compatibility.

## Core Classes

### 1. Arena Configuration

**Design Decision**: Use a simple class with preset factory methods, not enums.
MATLAB enums are less ergonomic than Python's, and most users want simple presets.

```matlab
classdef Arena < handle
    % ARENA LED display arena configuration
    %
    % Examples:
    %   arena = Arena.G4_4Row();           % Most common
    %   arena = Arena.G4_3Row();
    %   arena = Arena.custom(4, 12);       % 4 rows, 12 cols
    %   arena = Arena.custom(3, 8, 'G41'); % Custom G4.1 arena
    
    properties (SetAccess = private)
        numRows         % Number of panel rows
        numCols         % Number of panel columns
        generation      % 'G4', 'G41', 'G6'
        panelWidth      % Pixels per panel (typically 16)
        panelHeight     % Pixels per panel (typically 16)
    end
    
    properties (Dependent)
        totalWidth      % Total pixels wide
        totalHeight     % Total pixels high
        totalPanels     % Total number of panels
    end
    
    methods (Static)
        function obj = G4_4Row()
            % Standard 4-row G4 arena (most common)
            obj = Arena.custom(4, 12, 'G4');
        end
        
        function obj = G4_3Row()
            % Standard 3-row G4 arena
            obj = Arena.custom(3, 12, 'G4');
        end
        
        function obj = custom(numRows, numCols, generation)
            % Create custom arena configuration
            %   generation: 'G4' (default), 'G41', or 'G6'
            if nargin < 3
                generation = 'G4';
            end
            obj = Arena();
            obj.numRows = numRows;
            obj.numCols = numCols;
            obj.generation = upper(generation);
            
            % Set panel size based on generation
            switch obj.generation
                case {'G4', 'G41'}
                    obj.panelWidth = 16;
                    obj.panelHeight = 16;
                case 'G6'
                    obj.panelWidth = 32;  % May change
                    obj.panelHeight = 32;
                otherwise
                    error('Unknown generation: %s', generation);
            end
        end
    end
    
    methods
        function w = get.totalWidth(obj)
            w = obj.numCols * obj.panelWidth;
        end
        
        function h = get.totalHeight(obj)
            h = obj.numRows * obj.panelHeight;
        end
        
        function n = get.totalPanels(obj)
            n = obj.numRows * obj.numCols;
        end
    end
end
```

### 2. Pattern Data Class

**Design Decision**: Value class (not handle) because patterns are data.
Copy semantics are natural for pattern data - you want `pat2 = pat1` to make a copy.

```matlab
classdef Pattern
    % PATTERN LED display pattern with metadata
    %
    % A Pattern bundles the frame data with arena configuration and
    % display parameters. This eliminates passing 5+ parameters around.
    %
    % Examples:
    %   % Create from array
    %   frames = rand(64, 192, 96) > 0.5;  % 96 binary frames
    %   pat = Pattern(frames, Arena.G4_4Row(), 'binary');
    %
    %   % Create grayscale pattern
    %   frames = randi([0 15], 64, 192, 8, 8);  % 8x8 grid
    %   pat = Pattern(frames, Arena.G4_4Row(), 'grayscale');
    %
    %   % Set metadata
    %   pat.name = 'stripes';
    %   pat.id = 1;
    %
    %   % Access frames
    %   frame = pat.getFrame(5, 3);  % Frame at position x=5, y=3
    
    properties
        frames      % 4D array: (height, width, numX, numY)
        arena       % Arena object
        gsMode      % 'binary' or 'grayscale'
        stretch     % 2D array: (numX, numY), default all ones
        
        % Optional metadata
        id          % Pattern ID (uint16, optional)
        name        % Pattern name (char, optional)
    end
    
    properties (Dependent)
        numX        % Number of frames in X
        numY        % Number of frames in Y
        totalFrames % Total frame count
        height      % Frame height in pixels
        width       % Frame width in pixels
        gsVal       % Numeric gs_val (2 or 16) for backward compatibility
    end
    
    methods
        function obj = Pattern(frames, arena, gsMode, stretch)
            % Create pattern from frame data
            %   frames: 3D or 4D array
            %   arena: Arena object
            %   gsMode: 'binary', 'grayscale', or numeric gs_val (2, 16)
            %   stretch: (optional) stretch values
            
            % Handle optional arguments
            if nargin < 4
                stretch = [];
            end
            if nargin < 3
                gsMode = 'grayscale';
            end
            
            % Convert numeric gs_val to mode string
            if isnumeric(gsMode)
                if gsMode == 2
                    gsMode = 'binary';
                elseif gsMode == 16
                    gsMode = 'grayscale';
                else
                    error('gs_val must be 2 or 16');
                end
            end
            
            % Ensure 4D
            if ndims(frames) == 3
                frames = reshape(frames, size(frames,1), size(frames,2), ...
                                size(frames,3), 1);
            end
            
            % Store properties
            obj.frames = uint8(frames);
            obj.arena = arena;
            obj.gsMode = lower(gsMode);
            
            % Default stretch
            if isempty(stretch)
                stretch = ones(size(frames,3), size(frames,4), 'uint8');
            end
            obj.stretch = uint8(stretch);
            
            % Validate
            obj.validate();
        end
        
        function validate(obj)
            % Validate pattern consistency
            
            % Check dimensions match arena
            if obj.height ~= obj.arena.totalHeight
                error('Pattern height (%d) must match arena (%d)', ...
                      obj.height, obj.arena.totalHeight);
            end
            if obj.width ~= obj.arena.totalWidth
                error('Pattern width (%d) must match arena (%d)', ...
                      obj.width, obj.arena.totalWidth);
            end
            
            % Check stretch dimensions
            if ~isequal(size(obj.stretch), [obj.numX, obj.numY])
                error('Stretch must be numX x numY');
            end
            
            % Check pixel values
            switch obj.gsMode
                case 'binary'
                    if any(obj.frames(:) > 1)
                        error('Binary patterns must have values 0-1');
                    end
                case 'grayscale'
                    if any(obj.frames(:) > 15)
                        error('Grayscale patterns must have values 0-15');
                    end
                otherwise
                    error('gsMode must be ''binary'' or ''grayscale''');
            end
        end
        
        function frame = getFrame(obj, x, y)
            % Get single frame at position (x, y)
            if nargin < 3
                y = 1;
            end
            frame = squeeze(obj.frames(:, :, x, y));
        end
        
        % Dependent property getters
        function n = get.numX(obj)
            n = size(obj.frames, 3);
        end
        
        function n = get.numY(obj)
            n = size(obj.frames, 4);
        end
        
        function n = get.totalFrames(obj)
            n = obj.numX * obj.numY;
        end
        
        function h = get.height(obj)
            h = size(obj.frames, 1);
        end
        
        function w = get.width(obj)
            w = size(obj.frames, 2);
        end
        
        function gv = get.gsVal(obj)
            % Backward compatibility
            if strcmp(obj.gsMode, 'binary')
                gv = 2;
            else
                gv = 16;
            end
        end
    end
end
```

### 3. File I/O Class

**Design Decision**: Static methods for simple file operations.
No need for a complex reader/writer class hierarchy - just load/save methods.

```matlab
classdef PatternFile
    % PATTERNFILE File I/O for .pat files
    %
    % Examples:
    %   % Save pattern
    %   PatternFile.save(pat, './patterns', 'mypattern');
    %
    %   % Load pattern
    %   pat = PatternFile.load('./patterns/pat0001_mypattern.pat');
    %
    %   % Read only metadata (fast)
    %   info = PatternFile.readInfo('./patterns/pat0001_mypattern.pat');
    
    methods (Static)
        function filepath = save(pattern, saveDir, name, options)
            % Save pattern to .pat file
            %   pattern: Pattern object
            %   saveDir: directory for saving
            %   name: pattern name (optional, uses pattern.name if empty)
            %   options: struct with optional fields:
            %     .autoID - auto-assign ID (default: true)
            %     .forceID - use this ID instead of pattern.id
            
            arguments
                pattern Pattern
                saveDir char
                name char = ''
                options.autoID (1,1) logical = true
                options.forceID = []
            end
            
            % Get name
            if isempty(name)
                name = pattern.name;
                if isempty(name)
                    name = 'pattern';
                end
            end
            
            % Assign ID
            if ~isempty(options.forceID)
                patID = options.forceID;
            elseif options.autoID || isempty(pattern.id)
                patID = PatternFile.getNextID(saveDir);
            else
                patID = pattern.id;
            end
            
            % Create directory if needed
            if ~exist(saveDir, 'dir')
                mkdir(saveDir);
            end
            
            % Get encoder for this generation
            encoder = PatternFile.getEncoder(pattern.arena.generation);
            
            % Encode
            binaryData = encoder.encode(pattern, patID);
            
            % Generate filename
            filename = sprintf('pat%04d_%s.pat', patID, name);
            filepath = fullfile(saveDir, filename);
            
            % Write file
            fid = fopen(filepath, 'wb');
            if fid == -1
                error('Could not create file: %s', filepath);
            end
            fwrite(fid, binaryData, 'uint8');
            fclose(fid);
            
            fprintf('Saved: %s (ID=%d)\n', filepath, patID);
        end
        
        function pattern = load(filepath)
            % Load pattern from .pat file
            
            % Read binary data
            fid = fopen(filepath, 'rb');
            if fid == -1
                error('Could not open file: %s', filepath);
            end
            binaryData = fread(fid, '*uint8')';
            fclose(fid);
            
            % Auto-detect generation from file
            generation = PatternFile.detectGeneration(binaryData);
            
            % Get decoder
            encoder = PatternFile.getEncoder(generation);
            
            % Decode
            pattern = encoder.decode(binaryData);
        end
        
        function info = readInfo(filepath)
            % Read metadata without loading full pattern (fast)
            
            fid = fopen(filepath, 'rb');
            if fid == -1
                error('Could not open file: %s', filepath);
            end
            header = fread(fid, 40, '*uint8')';
            fclose(fid);
            
            % Parse header (G4 format)
            info = struct();
            info.id = typecast(uint8(header(1:2)), 'uint16');
            info.numX = typecast(uint8(header(3:4)), 'uint16');
            info.numY = typecast(uint8(header(5:6)), 'uint16');
            info.height = typecast(uint8(header(7:8)), 'uint16');
            info.width = typecast(uint8(header(9:10)), 'uint16');
            info.gsVal = header(11);
        end
        
        function nextID = getNextID(saveDir)
            % Get next available pattern ID in directory
            
            files = dir(fullfile(saveDir, 'pat*.pat'));
            if isempty(files)
                nextID = 1;
                return;
            end
            
            ids = [];
            for i = 1:length(files)
                tokens = regexp(files(i).name, '^pat(\d{4})', 'tokens');
                if ~isempty(tokens)
                    ids(end+1) = str2double(tokens{1}{1}); %#ok<AGROW>
                end
            end
            
            if isempty(ids)
                nextID = 1;
            else
                nextID = max(ids) + 1;
            end
        end
    end
    
    methods (Static, Access = private)
        function encoder = getEncoder(generation)
            % Get encoder/decoder for generation
            %   Returns appropriate encoder class for the generation
            
            persistent encoders
            if isempty(encoders)
                encoders = containers.Map();
            end
            
            if ~encoders.isKey(generation)
                switch generation
                    case 'G4'
                        encoders(generation) = maDisplayTools.internal.EncoderG4();
                    case 'G41'
                        encoders(generation) = maDisplayTools.internal.EncoderG41();
                    otherwise
                        error('No encoder for generation: %s', generation);
                end
            end
            
            encoder = encoders(generation);
        end
        
        function generation = detectGeneration(binaryData)
            % Auto-detect generation from binary data
            % For now, assume G4 (can add detection logic later)
            generation = 'G4';
        end
    end
end
```

### 4. Encoder Classes (Internal)

**Design Decision**: Keep encoding implementation separate and generation-specific.
Users don't interact with these directly - they're internal to PatternFile.

```matlab
% +maDisplayTools/+internal/EncoderG4.m
classdef EncoderG4 < handle
    % ENCODERG4 G4 pattern encoding/decoding
    %   Internal class - users should use PatternFile instead
    
    methods
        function binaryData = encode(~, pattern, patID)
            % Encode Pattern to G4 binary format
            
            % Build 40-byte header
            header = zeros(1, 40, 'uint8');
            header(1:2) = typecast(uint16(patID), 'uint8');
            header(3:4) = typecast(uint16(pattern.numX), 'uint8');
            header(5:6) = typecast(uint16(pattern.numY), 'uint8');
            header(7:8) = typecast(uint16(pattern.height), 'uint8');
            header(9:10) = typecast(uint16(pattern.width), 'uint8');
            header(11) = pattern.gsVal;
            % Bytes 12-39 remain zero
            
            % Encode frames
            numFrames = pattern.numX * pattern.numY;
            frameVectors = cell(numFrames, 1);
            idx = 1;
            
            for y = 1:pattern.numY
                for x = 1:pattern.numX
                    frame = pattern.getFrame(x, y);
                    stretchVal = pattern.stretch(x, y);
                    
                    if pattern.gsVal == 16
                        frameVectors{idx} = encodeFrameGS16(frame, stretchVal);
                    else
                        frameVectors{idx} = encodeFrameBinary(frame, stretchVal);
                    end
                    idx = idx + 1;
                end
            end
            
            % Combine
            binaryData = [header, cell2mat(frameVectors)];
        end
        
        function pattern = decode(obj, binaryData)
            % Decode G4 binary to Pattern object
            
            % Parse header
            header = binaryData(1:40);
            patID = typecast(uint8(header(1:2)), 'uint16');
            numX = typecast(uint8(header(3:4)), 'uint16');
            numY = typecast(uint8(header(5:6)), 'uint16');
            height = typecast(uint8(header(7:8)), 'uint16');
            width = typecast(uint8(header(9:10)), 'uint16');
            gsVal = header(11);
            
            % Determine arena
            numRows = height / 16;
            numCols = width / 16;
            
            if numRows == 4 && numCols == 12
                arena = Arena.G4_4Row();
            elseif numRows == 3 && numCols == 12
                arena = Arena.G4_3Row();
            else
                arena = Arena.custom(numRows, numCols, 'G4');
            end
            
            % Decode frames
            frames = zeros(height, width, numX, numY, 'uint8');
            stretch = zeros(numX, numY, 'uint8');
            
            frameSize = obj.getFrameSize(height, width, gsVal);
            offset = 41;
            
            for y = 1:numY
                for x = 1:numX
                    frameVec = binaryData(offset:offset+frameSize-1);
                    
                    if gsVal == 16
                        [frame, stretchVal] = decodeFrameGS16(frameVec, height, width);
                    else
                        [frame, stretchVal] = decodeFrameBinary(frameVec, height, width);
                    end
                    
                    frames(:, :, x, y) = frame;
                    stretch(x, y) = stretchVal;
                    offset = offset + frameSize;
                end
            end
            
            % Create Pattern
            pattern = Pattern(frames, arena, gsVal, stretch);
            pattern.id = patID;
        end
        
        function size = getFrameSize(~, height, width, gsVal)
            pixels = height * width;
            if gsVal == 16
                size = ceil(pixels / 2) + 1;  % 4 bits per pixel + stretch
            else
                size = ceil(pixels / 8) + 1;  % 1 bit per pixel + stretch
            end
        end
    end
end

% Frame encoding/decoding functions stay similar to current implementation
% but are methods of this class instead of static methods in main class
function encoded = encodeFrameGS16(frame, stretch)
    [rows, cols] = size(frame);
    pixels = rows * cols;
    packed = zeros(1, ceil(pixels/2), 'uint8');
    
    for i = 1:2:pixels
        byte = 0;
        byte = bitor(byte, bitand(uint8(frame(i)), 15));
        if i < pixels
            byte = bitor(byte, bitshift(bitand(uint8(frame(i+1)), 15), 4));
        end
        packed((i+1)/2) = byte;
    end
    
    encoded = [packed, uint8(stretch)];
end

function [frame, stretch] = decodeFrameGS16(frameVec, rows, cols)
    stretch = frameVec(end);
    packed = frameVec(1:end-1);
    pixels = zeros(rows * cols, 1, 'uint8');
    
    for i = 1:length(pixels)
        byteIdx = floor((i-1)/2) + 1;
        if mod(i, 2) == 1
            pixels(i) = bitand(packed(byteIdx), 15);
        else
            pixels(i) = bitshift(packed(byteIdx), -4);
        end
    end
    
    frame = reshape(pixels, rows, cols);
end

function encoded = encodeFrameBinary(frame, stretch)
    [rows, cols] = size(frame);
    pixels = rows * cols;
    packed = zeros(1, ceil(pixels/8), 'uint8');
    
    for i = 1:pixels
        if frame(i)
            byteIdx = floor((i-1)/8) + 1;
            bitPos = mod(i-1, 8);
            packed(byteIdx) = bitor(packed(byteIdx), bitshift(uint8(1), bitPos));
        end
    end
    
    encoded = [packed, uint8(stretch)];
end

function [frame, stretch] = decodeFrameBinary(frameVec, rows, cols)
    stretch = frameVec(end);
    packed = frameVec(1:end-1);
    pixels = zeros(rows * cols, 1, 'uint8');
    
    for i = 1:length(pixels)
        byteIdx = floor((i-1)/8) + 1;
        bitPos = mod(i-1, 8);
        pixels(i) = bitand(bitshift(packed(byteIdx), -bitPos), 1);
    end
    
    frame = reshape(pixels, rows, cols);
end
```

## Migration Strategy

### Phase 1: Implement New Classes (No Breaking Changes)

1. Create `+maDisplayTools` package directory
2. Implement `Arena.m`, `Pattern.m`, `PatternFile.m`
3. Create `+maDisplayTools/+internal` for encoders
4. Move `PatternPreview.m` into package (keep copy at root)
5. Keep existing `maDisplayTools.m` unchanged

**Result**: Both APIs work simultaneously

### Phase 2: Update Static Methods to Delegate

Update `maDisplayTools.m` to use new classes internally:

```matlab
classdef maDisplayTools < handle
    methods (Static)
        function generate_pattern_from_array(Pats, save_dir, patName, gs_val, stretch, arena_pitch)
            % DEPRECATED - Use Pattern and PatternFile classes
            % This wrapper maintains backward compatibility
            
            warning('off', 'backtrace');
            warning('maDisplayTools:deprecated', ...
                ['generate_pattern_from_array is deprecated.\n' ...
                 'Use: pat = Pattern(frames, arena, ''grayscale''); ' ...
                 'PatternFile.save(pat, dir, name);']);
            warning('on', 'backtrace');
            
            % Delegate to new API
            if nargin < 4, gs_val = 16; end
            if nargin < 5, stretch = []; end
            if nargin < 6, arena_pitch = 0; end
            
            % Determine arena from dimensions
            [height, width, ~, ~] = size(Pats);
            numRows = height / 16;
            numCols = width / 16;
            
            if numRows == 4 && numCols == 12
                arena = Arena.G4_4Row();
            elseif numRows == 3 && numCols == 12
                arena = Arena.G4_3Row();
            else
                arena = Arena.custom(numRows, numCols);
            end
            
            % Create pattern
            pat = Pattern(Pats, arena, gs_val, stretch);
            pat.name = patName;
            
            % Save
            PatternFile.save(pat, save_dir, patName);
        end
        
        % Similar wrappers for other functions...
    end
end
```

### Phase 3: Documentation and Examples

Create comprehensive examples showing new API:

```matlab
% Example 1: Simple pattern creation
arena = Arena.G4_4Row();
frames = rand(64, 192, 96) > 0.5;  % 96 binary frames
pat = Pattern(frames, arena, 'binary');
pat.name = 'random_flicker';
PatternFile.save(pat, './patterns', 'random_flicker');

% Example 2: Grayscale patterns
frames = randi([0 15], 64, 192, 8, 8);
pat = Pattern(frames, arena, 'grayscale');
PatternFile.save(pat, './patterns', 'gradient');

% Example 3: Load and modify
pat = PatternFile.load('./patterns/pat0001_mypattern.pat');
pat.frames(:,:,1,1) = pat.frames(:,:,1,1) * 0.5;  % Dim first frame
PatternFile.save(pat, './patterns', 'modified');

% Example 4: Preview
PatternPreview.show(pat);  % or pat.preview() if we add method
```

## Benefits Over Python-Style Design

### 1. Simpler Mental Model
- No abstract base classes to understand
- No deep package hierarchies (`maDisplayTools.io.protocols.G4V1Codec`)
- Classes do one thing well

### 2. Natural MATLAB Workflow
- Structs where users expect them (arena config feels like a struct)
- Value semantics for data (Pattern is copyable)
- Handle semantics for GUIs (PatternPreview)

### 3. Less Boilerplate
- No need for ProtocolRegistry singleton
- No separate Reader/Writer classes
- Static methods for file I/O (MATLAB convention)

### 4. Easier to Learn
- Three main classes: Arena, Pattern, PatternFile
- Clear progression: create pattern → save pattern → load pattern
- Internal complexity hidden in `+internal` package

### 5. Better IDE Support
- MATLAB's autocomplete works better with simpler hierarchies
- Properties show up clearly in workspace
- Help documentation more straightforward

## Testing Strategy

### Unit Tests
```matlab
% Test arena creation
arena = Arena.G4_4Row();
assert(arena.totalHeight == 64);
assert(arena.totalWidth == 192);

% Test pattern validation
frames = ones(64, 192, 4);
pat = Pattern(frames, arena, 'binary');
assert(pat.totalFrames == 4);

% Test file I/O round-trip
PatternFile.save(pat, './test', 'test');
loaded = PatternFile.load('./test/pat0001_test.pat');
assert(isequal(loaded.frames, pat.frames));
```

### Integration Tests
- Test with existing .pat files
- Verify backward compatibility with old API
- Test experiment builder workflow

### Performance Tests
- Compare encoding/decoding speed with current implementation
- Ensure no regression in file size or load times

## Documentation Plan

1. **Migration Guide**: Step-by-step conversion examples
2. **API Reference**: Complete class documentation
3. **Examples Gallery**: Common patterns and workflows
4. **Design Rationale**: Why we chose this approach over alternatives

## Future Extensions

### Easy to Add Later

**G4.1 Support:**
```matlab
% Just add new encoder class
classdef EncoderG41 < handle
    methods
        function binaryData = encode(~, pattern, patID)
            % G4.1-specific encoding
        end
    end
end

% And new arena preset
methods (Static)
    function obj = G41_4Row()
        obj = Arena.custom(4, 12, 'G41');
    end
end
```

**Pattern Transformations:**
```matlab
% Could add as Pattern methods or separate utility
pat2 = pat.rotate(90);
pat2 = pat.scale(0.5);
pat2 = pat.tile(2, 2);
```

**Batch Processing:**
```matlab
% Load multiple patterns
patterns = PatternFile.loadAll('./patterns');
% Process
for i = 1:length(patterns)
    patterns{i}.frames = processFrames(patterns{i}.frames);
end
```

## Conclusion

This refactoring prioritizes **MATLAB idioms over Python paradigms**:

- ✅ Simpler class hierarchies
- ✅ Struct-like configuration objects
- ✅ Value vs. handle semantics used appropriately  
- ✅ Static methods for utilities
- ✅ Shallow package nesting
- ✅ Clear, predictable API

The result is a codebase that feels natural to MATLAB users while still being well-organized, maintainable, and extensible.
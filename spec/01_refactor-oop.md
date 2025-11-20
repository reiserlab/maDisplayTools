# Object-Oriented Refactoring Specification for maDisplayTools

## Executive Summary

This document outlines a refactoring of the existing `maDisplayTools` codebase into a clean, maintainable object-oriented architecture that feels MATLAB *native*. The goal is to improve code organization, reduce duplication, and make the codebase easier to extend while replacing the current static method-based implementation.

Unlike the Python implementation (`pyDisplayTools`), this refactoring embraces MATLAB's strengths:
- Simple, practical class hierarchies (not deep abstract hierarchies)
- Struct-based configurations where appropriate (MATLAB developers expect structs)
- Handle classes where state matters, value classes for data containers
- Minimal package nesting (MATLAB's package system is more limited than Python's)
- Focus on interactive workflow and MATLAB GUI integration

## Current Implementation (To Be Refactored)

The existing `maDisplayTools` implementation that will be replaced is a single class with static methods organized into functional groups:

**Pattern Creation and Encoding:**
- `generate_pattern_from_array()` - Main user-facing function for creating patterns
- `save_pattern_g4()` - Saves pattern structure to .pat binary file
- `make_pattern_vector_g4()` - Generates binary pattern vector from pattern structure
- `make_framevector_gs16()` - Encodes individual grayscale frames (4 bits/pixel)
- `make_framevector_binary()` - Encodes individual binary frames (1 bit/pixel)
- `pack_uint16_le()` - Utility for little-endian encoding

**Pattern Loading and Decoding:**
- `load_pat()` - Loads and decodes all frames from .pat file
- `decode_framevector_gs16()` - Decodes grayscale frame vectors
- `decode_framevector_binary()` - Decodes binary frame vectors
- `preview_pat()` - Launches interactive preview GUI
- `read_header_and_raw()` - Reads pattern file header and raw data

**Experiment Management:**
- `create_experiment_folder_g41()` - Creates experiment folder from YAML protocol
- `collect_pattern_paths()` - Collects pattern paths from experiment YAML
- `generate_new_filename()` - Generates renumbered pattern filenames
- `update_pattern_paths_in_yaml()` - Updates pattern references in YAML
- `validate_all_patterns()` - Validates patterns against arena dimensions

**Pattern Utilities:**
- `get_pattern_id()` - Auto-assigns next available pattern ID
- `frame_size_bytes()` - Calculates frame size in bytes
- `get_pattern_dimensions()` - Extracts dimensions without loading full pattern
- `validate_pattern_dimensions()` - Validates pattern against expected dimensions

**Separate GUI Class:**
- `PatternPreview.m` - Standalone handle class providing interactive pattern preview with sliders for frame navigation

**Characteristics:**
- All parameters (dimensions, gs_val, stretch) passed separately as function arguments
- Pattern data represented as raw arrays, not objects
- Encoding/decoding logic duplicated between grayscale and binary variants
- Arena configuration implicit (inferred from dimensions)
- No intermediate representation between array and binary file
- GUI preview is separate file in root directory

## Refactored Architecture

### Design Philosophy: MATLAB-Native OOP

**Key Principles:**

1. **Structs for Configuration**: Use structs for immutable configuration data (MATLAB users expect this)
2. **Classes for Behavior**: Use classes when you need methods and state management
3. **Shallow Hierarchies**: Prefer composition over deep inheritance trees
4. **Simple Packages**: Use `+package` for organization, not complex namespace hierarchies
5. **Progressive Enhancement**: Keep simple things simple, add complexity only where needed

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

## Core Classes

### 1. Arena Configuration

**Design Decision**: Use a simple class with preset factory methods, not enums.
MATLAB enums are less ergonomic than Python's, and most users want simple presets.

```matlab
classdef Arena < handle
    % ARENA LED display arena configuration
    %
    % Examples:
    %   arena = Arena.custom(4, 12);       % 4 rows, 12 cols (G4, most common)
    %   arena = Arena.custom(3, 12);       % 3 rows, 12 cols (G4)
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
    %   pat = Pattern(frames, Arena.custom(4, 12), 'binary');
    %
    %   % Create grayscale pattern
    %   frames = randi([0 15], 64, 192, 8, 8);  % 8x8 grid
    %   pat = Pattern(frames, Arena.custom(4, 12), 'grayscale');
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
            
            % Encode (patID not stored in G4 binary format, only in filename)
            binaryData = encoder.encode(pattern);
            
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
            header = fread(fid, 7, '*uint8')';
            fclose(fid);
            
            % Parse 7-byte header (G4 format)
            info = struct();
            info.numX = typecast(uint8(header(1:2)), 'uint16');
            info.numY = typecast(uint8(header(3:4)), 'uint16');
            info.gsVal = header(5);
            info.numRows = header(6);
            info.numCols = header(7);
            info.height = info.numRows * 16;
            info.width = info.numCols * 16;
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

**Design Decision**: Use an abstract base class with the Template Method pattern to avoid code duplication while keeping encoding logic separate and generation-specific. **This design explicitly preserves the G4 binary protocol for backward compatibility.**

#### Abstract Base Class: `Encoder`

This class defines the template for the encoding/decoding algorithm.

```matlab
% +maDisplayTools/+internal/Encoder.m
classdef (Abstract) Encoder < handle
    % Defines the interface for all pattern encoders/decoders.

    methods
        function binaryData = encode(self, patternObj, arenaConfigObj)
            % ENCODE - Main method to convert a Pattern object to binary data.
            header = self.getHeader(patternObj, arenaConfigObj);
            
            frameSize = self.getFrameSizeInBytes(arenaConfigObj);
            numFrames = patternObj.getNumFrames();
            binaryData = zeros(1, numel(header) + numFrames * frameSize, 'uint8');
            binaryData(1:numel(header)) = header;

            currentPos = numel(header) + 1;
            for i = 1:numFrames
                frameData = patternObj.getFrame(i);
                stretchVal = patternObj.getStretch(i);
                
                encodedFrame = self.encodeFrame(frameData, stretchVal);
                
                binaryData(currentPos : currentPos + frameSize - 1) = encodedFrame;
                currentPos = currentPos + frameSize;
            end
        end

        function patternObj = decode(self, binaryData)
            % DECODE - Main method to convert binary data to a Pattern object.
            [headerInfo, arenaConfigObj] = self.decodeHeader(binaryData);
            
            frameSize = self.getFrameSizeInBytes(arenaConfigObj);
            numFrames = headerInfo.numX * headerInfo.numY;
            
            frames = zeros(arenaConfigObj.totalHeight, arenaConfigObj.totalWidth, numFrames, 'uint8');
            stretches = zeros(numFrames, 1, 'uint8');
            
            offset = self.getHeaderSize() + 1;
            for i = 1:numFrames
                frameVec = binaryData(offset : offset + frameSize - 1);
                [frame, stretch] = self.decodeFrame(frameVec, arenaConfigObj.totalHeight, arenaConfigObj.totalWidth);
                frames(:,:,i) = frame;
                stretches(i) = stretch;
                offset = offset + frameSize;
            end
            
            patternObj = maDisplayTools.Pattern(frames, arenaConfigObj, 'stretch', stretches);
        end
    end

    % --- Abstract methods for subclasses ---
    methods (Abstract, Access = protected)
        header = getHeader(self, patternObj, arenaConfigObj);
        [headerInfo, arenaConfig] = decodeHeader(self, binaryData);
        encodedFrame = encodeFrame(self, frameData, stretchVal);
        [frame, stretch] = decodeFrame(self, frameVec, height, width);
        byteCount = getFrameSizeInBytes(self, arenaConfigObj);
        sz = getHeaderSize(self);
    end
end
```

#### Concrete Subclass: `Grayscale4Encoder`

This class implements the 4-bit grayscale protocol, reusing the original logic.

```matlab
% +maDisplayTools/+internal/Grayscale4Encoder.m
classdef Grayscale4Encoder < maDisplayTools.internal.Encoder
    methods (Access = protected)
        function header = getHeader(self, pattern, arena)
            header = zeros(1, 7, 'uint8');
            header(1:2) = typecast(uint16(pattern.numX), 'uint8');
            header(3:4) = typecast(uint16(pattern.numY), 'uint8');
            header(5) = 16; % 4-bit grayscale
            header(6) = uint8(arena.numRows);
            header(7) = uint8(arena.numCols);
        end

        function [info, arena] = decodeHeader(self, binaryData)
            info.numX = typecast(uint8(binaryData(1:2)), 'uint16');
            info.numY = typecast(uint8(binaryData(3:4)), 'uint16');
            numRows = binaryData(6);
            numCols = binaryData(7);
            arena = maDisplayTools.Arena.custom(numRows, numCols, 'G4');
        end

        function encoded = encodeFrame(self, frame, stretch)
            pixels = numel(frame);
            packed = zeros(1, ceil(pixels/2), 'uint8');
            for i = 1:2:pixels
                byte = bitor(bitand(uint8(frame(i)), 15), bitshift(bitand(uint8(frame(i+1)), 15), 4));
                packed((i+1)/2) = byte;
            end
            encoded = [packed, uint8(stretch)];
        end

        function [frame, stretch] = decodeFrame(self, frameVec, rows, cols)
            stretch = frameVec(end);
            packed = frameVec(1:end-1);
            pixels = zeros(rows * cols, 1, 'uint8');
            for i = 1:numel(pixels)
                byteIdx = floor((i-1)/2) + 1;
                pixels(i) = bitand(bitshift(packed(byteIdx), -4 * mod(i-1, 2)), 15);
            end
            frame = reshape(pixels, rows, cols);
        end
        
        function byteCount = getFrameSizeInBytes(self, arena)
            byteCount = ceil(arena.totalHeight * arena.totalWidth / 2) + 1;
        end

        function sz = getHeaderSize(self), sz = 7; end
    end
end
```
*(A similar implementation would be created for `BinaryEncoder`)*

## Usage Examples (After Refactoring)

```matlab
% Example 1: Simple pattern creation
arena = Arena.custom(4, 12);  % 4 rows, 12 cols (standard G4)
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

## Design Rationale for Refactoring

### 1. Simple, Practical Design
The refactoring consolidates scattered functionality into three main classes (Arena, Pattern, PatternFile) with a clear progression: create pattern → save pattern → load pattern. This replaces the current approach of passing multiple parameters separately through static methods.

### 2. MATLAB-Native Patterns
The refactoring introduces proper object-oriented patterns while respecting MATLAB conventions: value classes for pattern data, handle classes for GUIs, and static methods for utilities. This replaces the current implicit approach where arena configuration is inferred from dimensions.

### 3. Reduced Duplication and Better Developer Experience
The refactoring eliminates duplicated encoding/decoding logic between grayscale and binary variants by encapsulating format-specific code in encoder classes. This improves IDE support and reduces the boilerplate currently needed to create patterns.

## Testing Strategy

### Unit Tests
```matlab
% Test arena creation
arena = Arena.custom(4, 12);
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

1. **API Reference**: Complete class documentation
2. **Examples Gallery**: Common patterns and workflows
3. **Design Rationale**: Architecture decisions and best practices

## Future Extensions

### Easy to Add Later

**G4.1 Support:**
```matlab
% Just add new encoder class
classdef EncoderG41 < handle
    methods
        function binaryData = encode(~, pattern)
            % G4.1-specific encoding
        end
    end
end

% Use with custom() method
arena = Arena.custom(4, 12, 'G41');
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

This refactoring transforms the existing static method-based implementation into an architecture that prioritizes **MATLAB idioms and simplicity**:

- ✅ Simple class hierarchies (no deep inheritance)
- ✅ Struct-like configuration objects
- ✅ Value vs. handle semantics used appropriately  
- ✅ Static methods for utilities
- ✅ Shallow package nesting
- ✅ Clear, predictable API
- ✅ Easy to extend with new display generations

The refactored codebase will be more maintainable and extensible than the current implementation while feeling natural to MATLAB developers.

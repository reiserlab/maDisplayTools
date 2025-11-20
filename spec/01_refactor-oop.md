# Object-Oriented Programming Refactoring Specification for maDisplayTools

## Executive Summary

This document outlines a comprehensive refactoring plan to transform the `maDisplayTools` codebase from a static method-based architecture to a modern, object-oriented MATLAB system. This refactoring will improve code maintainability, reusability, testability, and provide a cleaner API for users while maintaining backward compatibility where possible.

The refactoring is designed to mirror the Python `pyDisplayTools` implementation while adhering to MATLAB best practices, including proper use of classes, packages, enumerations, and MATLAB's object-oriented features.

## Current State Analysis

### Existing Architecture

The current codebase consists of:

1. **maDisplayTools.m**: A single class file with all static methods
   - Pattern creation functions (`generate_pattern_from_array`, `save_pattern_g4`, `make_pattern_vector_g4`)
   - Pattern encoding functions (`make_framevector_gs16`, `make_framevector_binary`)
   - Pattern loading/decoding functions (`load_pat`, `decode_framevector_gs16`, `decode_framevector_binary`)
   - Pattern preview function (`preview_pat`)
   - Experiment creation function (`create_experiment_folder_g41`)
   - Utility functions (`get_pattern_id`, `read_header_and_raw`, etc.)

2. **PatternPreview.m**: A handle class for interactive pattern visualization

### Key Issues with Current Architecture

1. **Monolithic Design**: All functionality is packed into a single class with static methods, making it difficult to organize and maintain.

2. **Scattered State Management**: Pattern parameters (dimensions, grayscale values, IDs) are passed as individual arguments across multiple functions, leading to parameter proliferation.

3. **Limited Encapsulation**: Related data and operations are separated into standalone static methods rather than cohesive objects.

4. **Repetitive Code**: Pattern validation, dimension calculations, and encoding logic are duplicated across multiple functions.

5. **Poor Extensibility**: Adding new pattern types, arena configurations, or protocol versions requires modifying multiple functions.

6. **No Protocol Abstraction**: G4 encoding is hardcoded; supporting G4.1 or G6 would require duplicating functions.

7. **Inconsistent API**: Mix of positional arguments, optional arguments, and different parameter ordering across functions.

8. **Magic Numbers**: Hardcoded values (16 for panel size, 2/16 for grayscale) scattered throughout code.

## Proposed Object-Oriented Architecture

### Core Design Principles

1. **Single Responsibility Principle**: Each class should have one well-defined purpose
2. **Encapsulation**: Bundle related data and behavior together
3. **Composition over Inheritance**: Use composition to build complex behavior
4. **Immutability where appropriate**: Use `SetAccess = immutable` for configuration objects
5. **Clear interfaces**: Define abstract classes for extensibility
6. **MATLAB Best Practices**: Use packages (`+packagename`), proper properties, and handle vs. value classes appropriately

### Package Structure

```
+maDisplayTools/
├── +core/
│   ├── ArenaGeneration.m      % Enumeration
│   ├── ProtocolVersion.m      % Value class (immutable)
│   ├── ArenaType.m            % Enumeration
│   ├── PanelConfiguration.m   % Value class (immutable)
│   ├── ArenaConfiguration.m   % Value class (immutable)
│   └── PatternData.m          % Value class (immutable)
├── +io/
│   ├── PatternReader.m        % Handle class
│   ├── PatternWriter.m        % Handle class
│   └── +protocols/
│       ├── ProtocolCodec.m    % Abstract class
│       ├── ProtocolRegistry.m % Handle class (singleton)
│       ├── G4V1Codec.m        % Concrete codec
│       ├── G4V2Codec.m        % Concrete codec
│       ├── G41V1Codec.m       % Concrete codec
│       └── G6V1Codec.m        % Concrete codec (future)
├── +pattern/
│   ├── PatternGenerator.m     % Handle class
│   ├── PatternValidator.m     % Handle class
│   ├── PatternPreview.m       % Handle class (enhanced)
│   └── PatternTransform.m     % Handle class
├── +experiment/
│   ├── ExperimentConfig.m     % Value class
│   └── ExperimentBuilder.m    % Handle class
└── +utils/
    ├── EncodingUtils.m        % Static utility class
    └── ValidationUtils.m      % Static utility class
```

## Detailed Class Design

### 1. Core Domain Models

#### 1.1 ArenaGeneration Enumeration

```matlab
% +maDisplayTools/+core/ArenaGeneration.m
classdef ArenaGeneration < uint8
    % ARENAGENERATION Enumeration of arena hardware generations
    %   Defines the different hardware generations of LED display arenas
    
    enumeration
        G4    (1)  % Original G4 displays
        G4_1  (2)  % G4.1 updated displays
        G6    (3)  % Next generation G6 displays
        CUSTOM (4) % Custom/unknown generation
    end
    
    methods
        function str = toString(obj)
            % TOSTRING Convert to string representation
            switch obj
                case maDisplayTools.core.ArenaGeneration.G4
                    str = 'G4';
                case maDisplayTools.core.ArenaGeneration.G4_1
                    str = 'G4.1';
                case maDisplayTools.core.ArenaGeneration.G6
                    str = 'G6';
                case maDisplayTools.core.ArenaGeneration.CUSTOM
                    str = 'CUSTOM';
            end
        end
    end
end
```

#### 1.2 ProtocolVersion Value Class

```matlab
% +maDisplayTools/+core/ProtocolVersion.m
classdef ProtocolVersion
    % PROTOCOLVERSION Pattern protocol version - determines encoding format
    %   Protocol versions are generation-specific. Each hardware generation
    %   can have multiple protocol versions that evolve independently.
    
    properties (SetAccess = immutable)
        generation  % ArenaGeneration
        version     % uint8
    end
    
    properties (Constant)
        % Common protocol versions
        G4_V1 = maDisplayTools.core.ProtocolVersion(...
            maDisplayTools.core.ArenaGeneration.G4, 1);
        G4_V2 = maDisplayTools.core.ProtocolVersion(...
            maDisplayTools.core.ArenaGeneration.G4, 2);
        G4_1_V1 = maDisplayTools.core.ProtocolVersion(...
            maDisplayTools.core.ArenaGeneration.G4_1, 1);
        G6_V1 = maDisplayTools.core.ProtocolVersion(...
            maDisplayTools.core.ArenaGeneration.G6, 1);
    end
    
    methods
        function obj = ProtocolVersion(generation, version)
            % PROTOCOLVERSION Constructor
            %   generation: ArenaGeneration enum value
            %   version: positive integer
            
            obj.generation = generation;
            obj.version = uint8(version);
        end
        
        function str = toString(obj)
            % TOSTRING String representation
            str = sprintf('%s_V%d', obj.generation.toString(), obj.version);
        end
        
        function result = isCompatibleWith(obj, target)
            % ISCOMPATIBLEWITH Check protocol compatibility
            %   Newer hardware can read patterns from older protocols
            %   of the same generation
            
            if obj.generation ~= target.generation
                result = false;
                return;
            end
            result = target.version >= obj.version;
        end
    end
end
```

#### 1.3 ArenaType Enumeration

```matlab
% +maDisplayTools/+core/ArenaType.m
classdef ArenaType
    % ARENATYPE Enumeration of supported arena configurations
    
    enumeration
        G4_3ROW
        G4_4ROW
        G4_1_3ROW
        G4_1_4ROW
        G6_3ROW    % Future support
        G6_4ROW    % Future support
        CUSTOM
    end
end
```

#### 1.4 PanelConfiguration Value Class

```matlab
% +maDisplayTools/+core/PanelConfiguration.m
classdef PanelConfiguration
    % PANELCONFIGURATION Immutable configuration for a single LED panel
    %   Different arena generations may have different panel sizes
    
    properties (SetAccess = immutable)
        panelWidth   % uint8
        panelHeight  % uint8
        generation   % ArenaGeneration
    end
    
    properties (Constant)
        % Standard panel sizes
        G4_PANEL_WIDTH = uint8(16);
        G4_PANEL_HEIGHT = uint8(16);
        G6_PANEL_WIDTH = uint8(32);   % Future - may differ
        G6_PANEL_HEIGHT = uint8(32);  % Future - may differ
    end
    
    methods
        function obj = PanelConfiguration(panelWidth, panelHeight, generation)
            % Constructor
            obj.panelWidth = uint8(panelWidth);
            obj.panelHeight = uint8(panelHeight);
            obj.generation = generation;
        end
        
        function count = pixelCount(obj)
            % PIXELCOUNT Total pixels in a single panel
            count = double(obj.panelWidth) * double(obj.panelHeight);
        end
    end
    
    methods (Static)
        function config = forGeneration(generation)
            % FORGENERATION Factory method for generation-specific config
            %   generation: ArenaGeneration enum value
            
            import maDisplayTools.core.*;
            
            switch generation
                case {ArenaGeneration.G4, ArenaGeneration.G4_1}
                    config = PanelConfiguration(...
                        PanelConfiguration.G4_PANEL_WIDTH, ...
                        PanelConfiguration.G4_PANEL_HEIGHT, ...
                        generation);
                case ArenaGeneration.G6
                    config = PanelConfiguration(...
                        PanelConfiguration.G6_PANEL_WIDTH, ...
                        PanelConfiguration.G6_PANEL_HEIGHT, ...
                        generation);
                otherwise % CUSTOM
                    config = PanelConfiguration(...
                        PanelConfiguration.G4_PANEL_WIDTH, ...
                        PanelConfiguration.G4_PANEL_HEIGHT, ...
                        generation);
            end
        end
    end
end
```

#### 1.5 ArenaConfiguration Value Class

```matlab
% +maDisplayTools/+core/ArenaConfiguration.m
classdef ArenaConfiguration
    % ARENACONFIGURATION Immutable configuration for an LED display arena
    %   Supports both predefined arena types and custom configurations
    
    properties (SetAccess = immutable)
        numRows         % uint8
        numCols         % uint8
        arenaType       % ArenaType
        generation      % ArenaGeneration
        protocolVersion % ProtocolVersion
        panelConfig     % PanelConfiguration
        pitchAngle      % double (degrees)
    end
    
    methods
        function obj = ArenaConfiguration(numRows, numCols, arenaType, ...
                generation, protocolVersion, panelConfig, pitchAngle)
            % Constructor (typically use factory methods instead)
            
            if nargin < 7
                pitchAngle = 0.0;
            end
            
            obj.numRows = uint8(numRows);
            obj.numCols = uint8(numCols);
            obj.arenaType = arenaType;
            obj.generation = generation;
            obj.protocolVersion = protocolVersion;
            obj.panelConfig = panelConfig;
            obj.pitchAngle = pitchAngle;
            
            % Validate
            if numRows <= 0 || numCols <= 0
                error('Arena dimensions must be positive');
            end
            
            if panelConfig.generation ~= generation
                error('Panel configuration generation mismatch');
            end
        end
        
        function height = pixelHeight(obj)
            % PIXELHEIGHT Total pixel height of arena
            height = double(obj.numRows) * double(obj.panelConfig.panelHeight);
        end
        
        function width = pixelWidth(obj)
            % PIXELWIDTH Total pixel width of arena
            width = double(obj.numCols) * double(obj.panelConfig.panelWidth);
        end
        
        function total = totalPanels(obj)
            % TOTALPANELS Total number of panels in arena
            total = double(obj.numRows) * double(obj.numCols);
        end
        
        function dims = panelDimensions(obj)
            % PANELDIMENSIONS Get panel dimensions as [width, height]
            dims = [double(obj.panelConfig.panelWidth), ...
                    double(obj.panelConfig.panelHeight)];
        end
    end
    
    methods (Static)
        function arena = fromPreset(arenaType, pitchAngle)
            % FROMPRESET Create arena from predefined type
            %   arenaType: ArenaType enum value
            %   pitchAngle: (optional) pitch angle in degrees
            
            import maDisplayTools.core.*;
            
            if nargin < 2
                pitchAngle = 0.0;
            end
            
            % Define presets: [rows, cols, generation, protocol]
            switch arenaType
                case ArenaType.G4_3ROW
                    rows = 3; cols = 12;
                    gen = ArenaGeneration.G4;
                    proto = ProtocolVersion.G4_V1;
                case ArenaType.G4_4ROW
                    rows = 4; cols = 12;
                    gen = ArenaGeneration.G4;
                    proto = ProtocolVersion.G4_V1;
                case ArenaType.G4_1_3ROW
                    rows = 3; cols = 12;
                    gen = ArenaGeneration.G4_1;
                    proto = ProtocolVersion.G4_1_V1;
                case ArenaType.G4_1_4ROW
                    rows = 4; cols = 12;
                    gen = ArenaGeneration.G4_1;
                    proto = ProtocolVersion.G4_1_V1;
                case ArenaType.G6_3ROW
                    rows = 3; cols = 12;
                    gen = ArenaGeneration.G6;
                    proto = ProtocolVersion.G6_V1;
                case ArenaType.G6_4ROW
                    rows = 4; cols = 12;
                    gen = ArenaGeneration.G6;
                    proto = ProtocolVersion.G6_V1;
                otherwise
                    error('No preset for %s. Use custom() for custom arenas.', ...
                        char(arenaType));
            end
            
            panelConfig = PanelConfiguration.forGeneration(gen);
            arena = ArenaConfiguration(rows, cols, arenaType, ...
                gen, proto, panelConfig, pitchAngle);
        end
        
        function arena = custom(numRows, numCols, varargin)
            % CUSTOM Create custom arena configuration
            %   numRows: number of panel rows
            %   numCols: number of panel columns
            %
            %   Optional name-value pairs:
            %     'Generation' - ArenaGeneration (default: G4)
            %     'ProtocolVersion' - ProtocolVersion (default: auto)
            %     'PanelWidth' - custom panel width (default: standard)
            %     'PanelHeight' - custom panel height (default: standard)
            %     'PitchAngle' - pitch angle in degrees (default: 0.0)
            
            import maDisplayTools.core.*;
            
            p = inputParser;
            addParameter(p, 'Generation', ArenaGeneration.G4);
            addParameter(p, 'ProtocolVersion', []);
            addParameter(p, 'PanelWidth', []);
            addParameter(p, 'PanelHeight', []);
            addParameter(p, 'PitchAngle', 0.0);
            parse(p, varargin{:});
            
            generation = p.Results.Generation;
            protocolVersion = p.Results.ProtocolVersion;
            panelWidth = p.Results.PanelWidth;
            panelHeight = p.Results.PanelHeight;
            pitchAngle = p.Results.PitchAngle;
            
            % Auto-select protocol if not specified
            if isempty(protocolVersion)
                switch generation
                    case ArenaGeneration.G4
                        protocolVersion = ProtocolVersion.G4_V1;
                    case ArenaGeneration.G4_1
                        protocolVersion = ProtocolVersion.G4_1_V1;
                    case ArenaGeneration.G6
                        protocolVersion = ProtocolVersion.G6_V1;
                    otherwise
                        protocolVersion = ProtocolVersion(...
                            ArenaGeneration.CUSTOM, 1);
                end
            end
            
            % Create panel configuration
            if ~isempty(panelWidth) && ~isempty(panelHeight)
                panelConfig = PanelConfiguration(panelWidth, panelHeight, generation);
            else
                panelConfig = PanelConfiguration.forGeneration(generation);
            end
            
            arena = ArenaConfiguration(numRows, numCols, ...
                ArenaType.CUSTOM, generation, protocolVersion, ...
                panelConfig, pitchAngle);
        end
    end
end
```

#### 1.6 PatternData Value Class

```matlab
% +maDisplayTools/+core/PatternData.m
classdef PatternData
    % PATTERNDATA Immutable container for pattern pixel data and metadata
    
    properties (SetAccess = immutable)
        frames      % 4D uint8 array: (rows, cols, numPatsX, numPatsY)
        stretch     % 2D uint8 array: (numPatsX, numPatsY)
        gsVal       % uint8: 2 for binary, 16 for grayscale
        arena       % ArenaConfiguration
        patternID   % uint16 (optional)
        name        % char array (optional)
    end
    
    methods
        function obj = PatternData(frames, arena, gsVal, stretch, patternID, name)
            % Constructor
            %   frames: 4D array (rows, cols, numPatsX, numPatsY)
            %   arena: ArenaConfiguration
            %   gsVal: 2 (binary) or 16 (grayscale)
            %   stretch: (optional) 2D array (numPatsX, numPatsY)
            %   patternID: (optional) pattern ID number
            %   name: (optional) pattern name
            
            if nargin < 6, name = ''; end
            if nargin < 5, patternID = []; end
            if nargin < 4 || isempty(stretch)
                stretch = ones(size(frames, 3), size(frames, 4), 'uint8');
            end
            
            obj.frames = uint8(frames);
            obj.arena = arena;
            obj.gsVal = uint8(gsVal);
            obj.stretch = uint8(stretch);
            obj.patternID = patternID;
            obj.name = name;
            
            % Validate
            obj.validate();
        end
        
        function validate(obj)
            % VALIDATE Check pattern data consistency
            
            [rows, cols, numX, numY] = size(obj.frames);
            
            % Check dimensions match arena
            if rows ~= obj.arena.pixelHeight()
                error('Pattern height (%d) does not match arena (%d)', ...
                    rows, obj.arena.pixelHeight());
            end
            if cols ~= obj.arena.pixelWidth()
                error('Pattern width (%d) does not match arena (%d)', ...
                    cols, obj.arena.pixelWidth());
            end
            
            % Check stretch dimensions
            if ~isequal(size(obj.stretch), [numX, numY])
                error('Stretch dimensions do not match pattern frame counts');
            end
            
            % Validate pixel values based on gsVal
            if obj.gsVal == 2
                if any(obj.frames(:) > 1)
                    error('Binary patterns must have values 0-1');
                end
            elseif obj.gsVal == 16
                if any(obj.frames(:) > 15)
                    error('Grayscale patterns must have values 0-15');
                end
            else
                error('gsVal must be 2 (binary) or 16 (grayscale)');
            end
        end
        
        function [numX, numY] = getFrameCounts(obj)
            % GETFRAMECOUNTS Get number of frames in X and Y dimensions
            numX = size(obj.frames, 3);
            numY = size(obj.frames, 4);
        end
        
        function total = getTotalFrames(obj)
            % GETTOTALFRAMES Get total number of frames
            total = size(obj.frames, 3) * size(obj.frames, 4);
        end
        
        function frame = getFrame(obj, x, y)
            % GETFRAME Get a single frame by X and Y indices (1-based)
            if nargin < 3, y = 1; end
            frame = squeeze(obj.frames(:, :, x, y));
        end
    end
end
```

### 2. Protocol Codec System

#### 2.1 Abstract Protocol Codec

```matlab
% +maDisplayTools/+io/+protocols/ProtocolCodec.m
classdef (Abstract) ProtocolCodec < handle
    % PROTOCOLCODEC Abstract base class for pattern encoding/decoding
    %   Each protocol version has its own codec implementation
    
    properties (Abstract, Constant)
        PROTOCOL_VERSION  % ProtocolVersion constant
    end
    
    methods (Abstract)
        % Encode pattern data to binary vector
        binaryData = encode(obj, patternData)
        
        % Decode binary vector to pattern data
        patternData = decode(obj, binaryData)
        
        % Get header size in bytes
        headerSize = getHeaderSize(obj)
        
        % Get frame size in bytes for given dimensions
        frameSize = getFrameSize(obj, rows, cols, gsVal)
    end
    
    methods
        function version = getProtocolVersion(obj)
            % GETPROTOCOLVERSION Get protocol version
            version = obj.PROTOCOL_VERSION;
        end
        
        function compatible = isCompatibleWith(obj, arena)
            % ISCOMPATIBLEWITH Check if codec is compatible with arena
            compatible = obj.PROTOCOL_VERSION.isCompatibleWith(...
                arena.protocolVersion);
        end
    end
end
```

#### 2.2 G4 V1 Codec

```matlab
% +maDisplayTools/+io/+protocols/G4V1Codec.m
classdef G4V1Codec < maDisplayTools.io.protocols.ProtocolCodec
    % G4V1CODEC Original G4 protocol codec
    
    properties (Constant)
        PROTOCOL_VERSION = maDisplayTools.core.ProtocolVersion.G4_V1;
    end
    
    methods
        function binaryData = encode(obj, patternData)
            % ENCODE Encode pattern to G4 V1 binary format
            
            import maDisplayTools.utils.EncodingUtils;
            
            % Extract data
            frames = patternData.frames;
            stretch = patternData.stretch;
            gsVal = patternData.gsVal;
            
            [rows, cols, numX, numY] = size(frames);
            
            % Build header (40 bytes)
            header = zeros(1, 40, 'uint8');
            
            % Pattern ID (bytes 0-1, little-endian uint16)
            if ~isempty(patternData.patternID)
                header(1:2) = EncodingUtils.packUInt16LE(patternData.patternID);
            end
            
            % Dimensions
            header(3:4) = EncodingUtils.packUInt16LE(numX);  % x_num
            header(5:6) = EncodingUtils.packUInt16LE(numY);  % y_num
            header(7:8) = EncodingUtils.packUInt16LE(rows);  % num_panels (height)
            header(9:10) = EncodingUtils.packUInt16LE(cols); % num_panels (width)
            header(11) = gsVal;  % gs_val
            
            % Reserved/unused bytes 12-39 stay zero
            
            % Encode frames
            totalFrames = numX * numY;
            frameSize = obj.getFrameSize(rows, cols, gsVal);
            
            frameData = zeros(1, totalFrames * frameSize, 'uint8');
            offset = 1;
            
            for y = 1:numY
                for x = 1:numX
                    frame = squeeze(frames(:, :, x, y));
                    stretchVal = stretch(x, y);
                    
                    if gsVal == 16
                        encoded = obj.encodeFrameGS16(frame, stretchVal);
                    else
                        encoded = obj.encodeFrameBinary(frame, stretchVal);
                    end
                    
                    frameData(offset:offset+length(encoded)-1) = encoded;
                    offset = offset + length(encoded);
                end
            end
            
            % Combine header and frames
            binaryData = [header, frameData];
        end
        
        function patternData = decode(obj, binaryData)
            % DECODE Decode G4 V1 binary format to pattern data
            
            import maDisplayTools.utils.EncodingUtils;
            import maDisplayTools.core.*;
            
            % Read header
            header = binaryData(1:40);
            
            patternID = EncodingUtils.unpackUInt16LE(header(1:2));
            numX = EncodingUtils.unpackUInt16LE(header(3:4));
            numY = EncodingUtils.unpackUInt16LE(header(5:6));
            rows = EncodingUtils.unpackUInt16LE(header(7:8));
            cols = EncodingUtils.unpackUInt16LE(header(9:10));
            gsVal = header(11);
            
            % Determine arena configuration
            numPanelRows = rows / 16;
            numPanelCols = cols / 16;
            
            % Create arena (use custom if non-standard)
            if numPanelRows == 3 && numPanelCols == 12
                arena = ArenaConfiguration.fromPreset(ArenaType.G4_3ROW);
            elseif numPanelRows == 4 && numPanelCols == 12
                arena = ArenaConfiguration.fromPreset(ArenaType.G4_4ROW);
            else
                arena = ArenaConfiguration.custom(numPanelRows, numPanelCols);
            end
            
            % Decode frames
            frameSize = obj.getFrameSize(rows, cols, gsVal);
            frames = zeros(rows, cols, numX, numY, 'uint8');
            stretch = zeros(numX, numY, 'uint8');
            
            offset = 41; % After header
            
            for y = 1:numY
                for x = 1:numX
                    frameVec = binaryData(offset:offset+frameSize-1);
                    
                    if gsVal == 16
                        [frame, stretchVal] = obj.decodeFrameGS16(frameVec, rows, cols);
                    else
                        [frame, stretchVal] = obj.decodeFrameBinary(frameVec, rows, cols);
                    end
                    
                    frames(:, :, x, y) = frame;
                    stretch(x, y) = stretchVal;
                    
                    offset = offset + frameSize;
                end
            end
            
            % Create PatternData object
            patternData = PatternData(frames, arena, gsVal, stretch, patternID);
        end
        
        function size = getHeaderSize(~)
            % GETHEADERSIZE Header is 40 bytes for G4 V1
            size = 40;
        end
        
        function size = getFrameSize(~, rows, cols, gsVal)
            % GETFRAMESIZE Calculate frame size in bytes
            
            pixels = rows * cols;
            
            if gsVal == 16
                % 4 bits per pixel + 1 byte stretch
                size = ceil(pixels / 2) + 1;
            else % gsVal == 2
                % 1 bit per pixel + 1 byte stretch
                size = ceil(pixels / 8) + 1;
            end
        end
    end
    
    methods (Access = private)
        function encoded = encodeFrameGS16(~, frame, stretch)
            % ENCODEFRAMEGS16 Encode grayscale frame
            % Implementation similar to current make_framevector_gs16
            
            import maDisplayTools.utils.EncodingUtils;
            
            [rows, cols] = size(frame);
            pixels = rows * cols;
            
            % Pack pixels (4 bits each)
            packed = EncodingUtils.pack4BitPixels(frame(:));
            
            % Add stretch byte at end
            encoded = [packed, uint8(stretch)];
        end
        
        function [frame, stretch] = decodeFrameGS16(~, frameVec, rows, cols)
            % DECODEFRAMEGS16 Decode grayscale frame
            
            import maDisplayTools.utils.EncodingUtils;
            
            % Last byte is stretch
            stretch = frameVec(end);
            
            % Unpack pixels
            pixels = EncodingUtils.unpack4BitPixels(frameVec(1:end-1), rows * cols);
            frame = reshape(pixels, rows, cols);
        end
        
        function encoded = encodeFrameBinary(~, frame, stretch)
            % ENCODEFRAMEBINARY Encode binary frame
            
            import maDisplayTools.utils.EncodingUtils;
            
            [rows, cols] = size(frame);
            
            % Pack pixels (1 bit each)
            packed = EncodingUtils.pack1BitPixels(frame(:));
            
            % Add stretch byte at end
            encoded = [packed, uint8(stretch)];
        end
        
        function [frame, stretch] = decodeFrameBinary(~, frameVec, rows, cols)
            % DECODEFRAMEBINARY Decode binary frame
            
            import maDisplayTools.utils.EncodingUtils;
            
            % Last byte is stretch
            stretch = frameVec(end);
            
            % Unpack pixels
            pixels = EncodingUtils.unpack1BitPixels(frameVec(1:end-1), rows * cols);
            frame = reshape(pixels, rows, cols);
        end
    end
end
```

#### 2.3 Protocol Registry

```matlab
% +maDisplayTools/+io/+protocols/ProtocolRegistry.m
classdef ProtocolRegistry < handle
    % PROTOCOLREGISTRY Singleton registry for protocol codecs
    
    properties (Access = private)
        codecs  % containers.Map: ProtocolVersion.toString() -> codec
    end
    
    methods (Access = private)
        function obj = ProtocolRegistry()
            % Private constructor for singleton
            obj.codecs = containers.Map();
            obj.registerDefaultCodecs();
        end
        
        function registerDefaultCodecs(obj)
            % REGISTERDEFAULTCODECS Register built-in codecs
            import maDisplayTools.io.protocols.*;
            
            obj.registerCodec(G4V1Codec());
            % obj.registerCodec(G4V2Codec());  % Future
            % obj.registerCodec(G41V1Codec()); % Future
        end
    end
    
    methods (Static)
        function instance = getInstance()
            % GETINSTANCE Get singleton instance
            persistent registry
            if isempty(registry) || ~isvalid(registry)
                registry = maDisplayTools.io.protocols.ProtocolRegistry();
            end
            instance = registry;
        end
    end
    
    methods
        function registerCodec(obj, codec)
            % REGISTERCODEC Register a codec
            key = codec.PROTOCOL_VERSION.toString();
            obj.codecs(key) = codec;
        end
        
        function codec = getCodec(obj, protocolVersion)
            % GETCODEC Get codec for protocol version
            key = protocolVersion.toString();
            if obj.codecs.isKey(key)
                codec = obj.codecs(key);
            else
                error('No codec registered for protocol %s', key);
            end
        end
        
        function codec = detectCodec(obj, binaryData)
            % DETECTCODEC Auto-detect protocol from binary data
            %   Analyzes header to determine protocol version
            
            % For now, assume G4 V1 (can be enhanced with detection logic)
            import maDisplayTools.core.ProtocolVersion;
            codec = obj.getCodec(ProtocolVersion.G4_V1);
        end
    end
end
```

### 3. I/O Classes

#### 3.1 Pattern Writer

```matlab
% +maDisplayTools/+io/PatternWriter.m
classdef PatternWriter < handle
    % PATTERNWRITER Write patterns to .pat files
    
    properties
        saveDir     % Directory for saving patterns
        autoID      % Auto-assign pattern IDs (default: true)
    end
    
    methods
        function obj = PatternWriter(saveDir, autoID)
            % Constructor
            %   saveDir: directory path for saving patterns
            %   autoID: (optional) auto-assign IDs (default: true)
            
            if nargin < 2
                autoID = true;
            end
            
            obj.saveDir = saveDir;
            obj.autoID = autoID;
            
            if ~exist(saveDir, 'dir')
                mkdir(saveDir);
            end
        end
        
        function filepath = write(obj, patternData, name)
            % WRITE Write pattern to file
            %   patternData: PatternData object
            %   name: (optional) pattern name (overrides patternData.name)
            
            if nargin < 3 || isempty(name)
                name = patternData.name;
            end
            
            % Assign ID if needed
            if obj.autoID || isempty(patternData.patternID)
                patternID = obj.getNextID();
                % Create new PatternData with ID
                patternData = maDisplayTools.core.PatternData(...
                    patternData.frames, patternData.arena, ...
                    patternData.gsVal, patternData.stretch, ...
                    patternID, name);
            end
            
            % Get codec
            registry = maDisplayTools.io.protocols.ProtocolRegistry.getInstance();
            codec = registry.getCodec(patternData.arena.protocolVersion);
            
            % Encode
            binaryData = codec.encode(patternData);
            
            % Generate filename
            filename = sprintf('pat%04d_%s.pat', patternData.patternID, name);
            filepath = fullfile(obj.saveDir, filename);
            
            % Write file
            fid = fopen(filepath, 'wb');
            if fid == -1
                error('Could not open file for writing: %s', filepath);
            end
            
            fwrite(fid, binaryData, 'uint8');
            fclose(fid);
            
            fprintf('Saved: %s\n', filepath);
        end
        
        function nextID = getNextID(obj)
            % GETNEXTID Get next available pattern ID
            
            takenIDs = [];
            files = dir(fullfile(obj.saveDir, '*.pat'));
            
            for i = 1:length(files)
                tokens = regexp(files(i).name, '^pat(\d{4})', 'tokens');
                if ~isempty(tokens)
                    takenIDs = [takenIDs, str2double(tokens{1}{1})];
                end
            end
            
            if isempty(takenIDs)
                nextID = 1;
            else
                nextID = max(takenIDs) + 1;
            end
        end
    end
end
```

#### 3.2 Pattern Reader

```matlab
% +maDisplayTools/+io/PatternReader.m
classdef PatternReader < handle
    % PATTERNREADER Read patterns from .pat files
    
    methods (Static)
        function patternData = read(filepath)
            % READ Read pattern from file
            %   filepath: path to .pat file
            %   Returns: PatternData object
            
            % Read binary data
            fid = fopen(filepath, 'rb');
            if fid == -1
                error('Could not open file: %s', filepath);
            end
            
            binaryData = fread(fid, '*uint8')';
            fclose(fid);
            
            % Detect and get codec
            registry = maDisplayTools.io.protocols.ProtocolRegistry.getInstance();
            codec = registry.detectCodec(binaryData);
            
            % Decode
            patternData = codec.decode(binaryData);
        end
        
        function metadata = readMetadata(filepath)
            % READMETADATA Read only header metadata (fast)
            
            % Read just the header
            fid = fopen(filepath, 'rb');
            if fid == -1
                error('Could not open file: %s', filepath);
            end
            
            header = fread(fid, 40, '*uint8')';
            fclose(fid);
            
            import maDisplayTools.utils.EncodingUtils;
            
            % Parse header
            metadata = struct();
            metadata.patternID = EncodingUtils.unpackUInt16LE(header(1:2));
            metadata.numPatsX = EncodingUtils.unpackUInt16LE(header(3:4));
            metadata.numPatsY = EncodingUtils.unpackUInt16LE(header(5:6));
            metadata.rows = EncodingUtils.unpackUInt16LE(header(7:8));
            metadata.cols = EncodingUtils.unpackUInt16LE(header(9:10));
            metadata.gsVal = header(11);
        end
    end
end
```

### 4. Pattern Tools

#### 4.1 Pattern Generator

```matlab
% +maDisplayTools/+pattern/PatternGenerator.m
classdef PatternGenerator < handle
    % PATTERNGENERATOR Generate patterns from arrays or functions
    
    properties
        defaultArena  % Default ArenaConfiguration
        defaultGsVal  % Default grayscale value (2 or 16)
    end
    
    methods
        function obj = PatternGenerator(arena, gsVal)
            % Constructor
            %   arena: (optional) default ArenaConfiguration
            %   gsVal: (optional) default grayscale value
            
            import maDisplayTools.core.*;
            
            if nargin < 2
                gsVal = 16;
            end
            if nargin < 1
                arena = ArenaConfiguration.fromPreset(ArenaType.G4_4ROW);
            end
            
            obj.defaultArena = arena;
            obj.defaultGsVal = gsVal;
        end
        
        function patternData = fromArray(obj, frames, varargin)
            % FROMARRAY Create pattern from array
            %   frames: 3D or 4D array (rows, cols, [numX, numY])
            %
            %   Optional name-value pairs:
            %     'Arena' - ArenaConfiguration (default: obj.defaultArena)
            %     'GsVal' - grayscale value (default: obj.defaultGsVal)
            %     'Stretch' - stretch values (default: all ones)
            %     'Name' - pattern name (default: '')
            
            import maDisplayTools.core.PatternData;
            
            p = inputParser;
            addParameter(p, 'Arena', obj.defaultArena);
            addParameter(p, 'GsVal', obj.defaultGsVal);
            addParameter(p, 'Stretch', []);
            addParameter(p, 'Name', '');
            parse(p, varargin{:});
            
            arena = p.Results.Arena;
            gsVal = p.Results.GsVal;
            stretch = p.Results.Stretch;
            name = p.Results.Name;
            
            % Ensure 4D
            if ndims(frames) == 3
                frames = reshape(frames, [size(frames, 1), size(frames, 2), ...
                    size(frames, 3), 1]);
            end
            
            % Create default stretch if needed
            if isempty(stretch)
                stretch = ones(size(frames, 3), size(frames, 4), 'uint8');
            end
            
            % Create PatternData (will validate)
            patternData = PatternData(frames, arena, gsVal, stretch, [], name);
        end
        
        function patternData = fromFunction(obj, funcHandle, varargin)
            % FROMFUNCTION Create pattern from function
            %   funcHandle: function that returns frames array
            %               signature: frames = func()
            %
            %   Additional name-value pairs as in fromArray
            
            frames = funcHandle();
            patternData = obj.fromArray(frames, varargin{:});
        end
    end
end
```

#### 4.2 Pattern Validator

```matlab
% +maDisplayTools/+pattern/PatternValidator.m
classdef PatternValidator < handle
    % PATTERNVALIDATOR Validate patterns
    
    methods (Static)
        function [isValid, errors, warnings] = validate(patternData)
            % VALIDATE Validate pattern data
            %   Returns: isValid (logical), errors (cell array), warnings (cell array)
            
            errors = {};
            warnings = {};
            
            try
                patternData.validate();
            catch ME
                errors{end+1} = ME.message;
            end
            
            % Additional validation checks
            [rows, cols, numX, numY] = size(patternData.frames);
            
            % Check frame count
            if numX * numY > 10000
                warnings{end+1} = sprintf(...
                    'Very large number of frames (%d). May impact performance.', ...
                    numX * numY);
            end
            
            % Check for blank frames
            for y = 1:numY
                for x = 1:numX
                    frame = patternData.getFrame(x, y);
                    if all(frame(:) == 0)
                        warnings{end+1} = sprintf(...
                            'Frame (%d,%d) is completely blank', x, y);
                    end
                end
            end
            
            isValid = isempty(errors);
        end
        
        function [isValid, msg] = validateFile(filepath, arena)
            % VALIDATEFILE Validate pattern file matches arena
            %   filepath: path to .pat file
            %   arena: ArenaConfiguration to check against
            
            import maDisplayTools.io.PatternReader;
            
            try
                metadata = PatternReader.readMetadata(filepath);
                
                if metadata.rows ~= arena.pixelHeight()
                    isValid = false;
                    msg = sprintf('Height mismatch: file=%d, arena=%d', ...
                        metadata.rows, arena.pixelHeight());
                    return;
                end
                
                if metadata.cols ~= arena.pixelWidth()
                    isValid = false;
                    msg = sprintf('Width mismatch: file=%d, arena=%d', ...
                        metadata.cols, arena.pixelWidth());
                    return;
                end
                
                isValid = true;
                msg = 'Valid';
                
            catch ME
                isValid = false;
                msg = ME.message;
            end
        end
    end
end
```

### 5. Experiment Builder

```matlab
% +maDisplayTools/+experiment/ExperimentBuilder.m
classdef ExperimentBuilder < handle
    % EXPERIMENTBUILDER Create experiment folders from YAML protocols
    
    properties
        experimentPath  % Path to experiment folder
        arena          % ArenaConfiguration
        verbose        % Verbose output (default: true)
    end
    
    methods
        function obj = ExperimentBuilder(experimentPath, arena, verbose)
            % Constructor
            %   experimentPath: path to experiment folder
            %   arena: ArenaConfiguration
            %   verbose: (optional) verbose output (default: true)
            
            if nargin < 3
                verbose = true;
            end
            
            obj.experimentPath = experimentPath;
            obj.arena = arena;
            obj.verbose = verbose;
        end
        
        function build(obj, yamlPath)
            % BUILD Build experiment folder from YAML
            %   yamlPath: path to YAML protocol file
            
            % This method would implement the logic from
            % create_experiment_folder_g41, using the new OOP structure
            
            if obj.verbose
                fprintf('Building experiment from: %s\n', yamlPath);
            end
            
            % 1. Load YAML
            % 2. Validate patterns
            % 3. Renumber patterns
            % 4. Copy to experiment folder
            % 5. Update YAML
            
            % Implementation details similar to current function
            % but using PatternReader, PatternWriter, PatternValidator
        end
    end
end
```

### 6. Utility Classes

```matlab
% +maDisplayTools/+utils/EncodingUtils.m
classdef EncodingUtils
    % ENCODINGUTILS Static utilities for binary encoding/decoding
    
    methods (Static)
        function bytes = packUInt16LE(val)
            % PACKUINT16LE Pack uint16 as little-endian bytes
            bytes = zeros(1, 2, 'uint8');
            bytes(1) = bitand(val, 255);
            bytes(2) = bitshift(val, -8);
        end
        
        function val = unpackUInt16LE(bytes)
            % UNPACKUINT16LE Unpack little-endian bytes to uint16
            val = uint16(bytes(1)) + uint16(bytes(2)) * 256;
        end
        
        function packed = pack4BitPixels(pixels)
            % PACK4BITPIXELS Pack 4-bit pixel values (0-15) into bytes
            %   Two pixels per byte
            
            numPixels = length(pixels);
            numBytes = ceil(numPixels / 2);
            packed = zeros(1, numBytes, 'uint8');
            
            for i = 1:2:numPixels
                byte = 0;
                % First pixel (lower 4 bits)
                byte = bitor(byte, bitand(uint8(pixels(i)), 15));
                % Second pixel (upper 4 bits) if exists
                if i < numPixels
                    byte = bitor(byte, bitshift(bitand(uint8(pixels(i+1)), 15), 4));
                end
                packed((i+1)/2) = byte;
            end
        end
        
        function pixels = unpack4BitPixels(packed, numPixels)
            % UNPACK4BITPIXELS Unpack bytes into 4-bit pixel values
            
            pixels = zeros(numPixels, 1, 'uint8');
            
            for i = 1:numPixels
                byteIdx = floor((i-1) / 2) + 1;
                if mod(i, 2) == 1
                    % Odd pixel (lower 4 bits)
                    pixels(i) = bitand(packed(byteIdx), 15);
                else
                    % Even pixel (upper 4 bits)
                    pixels(i) = bitshift(packed(byteIdx), -4);
                end
            end
        end
        
        function packed = pack1BitPixels(pixels)
            % PACK1BITPIXELS Pack 1-bit pixel values (0-1) into bytes
            %   Eight pixels per byte
            
            numPixels = length(pixels);
            numBytes = ceil(numPixels / 8);
            packed = zeros(1, numBytes, 'uint8');
            
            for i = 1:numPixels
                byteIdx = floor((i-1) / 8) + 1;
                bitPos = mod(i-1, 8);
                if pixels(i)
                    packed(byteIdx) = bitor(packed(byteIdx), ...
                        bitshift(uint8(1), bitPos));
                end
            end
        end
        
        function pixels = unpack1BitPixels(packed, numPixels)
            % UNPACK1BITPIXELS Unpack bytes into 1-bit pixel values
            
            pixels = zeros(numPixels, 1, 'uint8');
            
            for i = 1:numPixels
                byteIdx = floor((i-1) / 8) + 1;
                bitPos = mod(i-1, 8);
                pixels(i) = bitand(bitshift(packed(byteIdx), -bitPos), 1);
            end
        end
    end
end
```

## Migration Strategy

### Phase 1: Core Infrastructure (No Breaking Changes)

1. Create package structure (`+maDisplayTools`, `+core`, `+io`, etc.)
2. Implement core classes (ArenaConfiguration, ProtocolVersion, etc.)
3. Implement codec system
4. Keep existing static methods working

### Phase 2: New API Implementation

1. Implement PatternGenerator, PatternWriter, PatternReader
2. Implement PatternValidator
3. Update PatternPreview to use new classes
4. Create examples using new API

### Phase 3: Deprecation and Migration

1. Add deprecation warnings to old static methods
2. Document migration path
3. Update all examples to new API
4. Eventually remove old API in major version bump

### Backward Compatibility Wrapper

```matlab
% Keep in maDisplayTools.m during transition
classdef maDisplayTools < handle
    methods (Static)
        function generate_pattern_from_array(Pats, save_dir, patName, gs_val, stretch, arena_pitch)
            % DEPRECATED - Use PatternGenerator and PatternWriter instead
            warning('maDisplayTools:deprecated', ...
                'generate_pattern_from_array is deprecated. Use new OOP API.');
            
            % Delegate to new implementation
            import maDisplayTools.core.*;
            import maDisplayTools.pattern.*;
            import maDisplayTools.io.*;
            
            % ... conversion logic ...
        end
        
        % Similar wrappers for other functions
    end
end
```

## Benefits of Refactoring

1. **Better Organization**: Clear separation of concerns with package structure
2. **Extensibility**: Easy to add new protocols, arena types, transformations
3. **Testability**: Classes can be unit tested in isolation
4. **Maintainability**: Changes localized to specific classes
5. **Type Safety**: Enumerations and value classes prevent invalid states
6. **Reusability**: Components can be reused in different contexts
7. **Documentation**: Self-documenting through class structure
8. **Future-Proof**: Easy to extend for G6 and beyond

## Testing Strategy

1. **Unit Tests**: Test each class in isolation
2. **Integration Tests**: Test complete workflows
3. **Regression Tests**: Ensure backward compatibility
4. **Performance Tests**: Verify encoding/decoding performance

## Documentation Requirements

1. Class documentation with examples
2. Migration guide from old to new API
3. Architecture overview
4. Protocol specification documents
5. Example scripts for common workflows

This refactoring will transform maDisplayTools into a professional, maintainable codebase that can evolve with the hardware while providing a clean, intuitive API for users.
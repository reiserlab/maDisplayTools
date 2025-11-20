# Panel Map Extension Specification for maDisplayTools

## Executive Summary

This document specifies a `panelMap` feature for `maDisplayTools` that allows flexible remapping of pattern content to physical LED panels. Unlike the G3 system where panels are wired in non-sequential order requiring complex mapping, the current system has regular sequential wiring. However, users still need flexibility to:

1. **Reorder panels** - Route pattern content to different physical positions
2. **Disable panels** - Skip sending data to specific panels (value = 0)
3. **Duplicate content** - Show the same pattern segment on multiple panels

This feature is inspired by the G3 `Panel_map` but simplified for the regular hardware wiring in the current system.

## Default Behavior (No Panel Map)

When no `panelMap` is specified (or when `panelMap` is empty `[]`), the system uses **sequential panel mapping**:

```matlab
% Default arena - no panelMap specified
arena = Arena.custom(4, 12);
% Implicitly uses panelMap = reshape(1:48, 12, 4)'
% Which is equivalent to:
%  [  1  2  3  4  5  6  7  8  9 10 11 12;
%    13 14 15 16 17 18 19 20 21 22 23 24;
%    25 26 27 28 29 30 31 32 33 34 35 36;
%    37 38 39 40 41 42 43 44 45 46 47 48 ]
```

**Characteristics of default mapping:**
- Panels numbered sequentially from 1 to `totalPanels`
- Row-major order: left-to-right, top-to-bottom
- Panel ID = (row - 1) × numCols + col
- All panels active (no disabled panels)
- Pattern data must be sized for all panels

This is the standard configuration and maintains backward compatibility with existing code. The `panelMap` extension provides flexibility when you need to deviate from this default arrangement.

## Use Cases

Custom panel maps are useful when the default sequential mapping doesn't match your needs:

### 1. Asymmetric Arenas
```matlab
% Arena with missing panels in corners (cylindrical approximation)
arena = Arena.custom(4, 12);
arena.panelMap = [
     0  2  3  4  5  6  7  8  9 10  0  0;
    13 14 15 16 17 18 19 20 21 22 23 24;
    25 26 27 28 29 30 31 32 33 34 35 36;
     0 38 39 40 41 42 43 44 45 46  0  0
];
% Panels 1, 11, 12, 37, 47, 48 are disabled (0)
```

### 2. Content Mirroring
```matlab
% Show same pattern on left and right halves
arena = Arena.custom(4, 12);
arena.panelMap = [
     1  2  3  4  5  6  6  5  4  3  2  1;
     7  8  9 10 11 12 12 11 10  9  8  7;
    13 14 15 16 17 18 18 17 16 15 14 13;
    19 20 21 22 23 24 24 23 22 21 20 19
];
% Right half mirrors left half
```

### 3. Rotational Shift
```matlab
% Shift entire pattern 3 panels to the right
arena = Arena.custom(4, 12);
arena.panelMap = reshape(circshift(1:48, 3), 4, 12)';
```

### 4. Custom Test Configurations
```matlab
% Only show pattern on top row for testing
arena = Arena.custom(4, 12);
arena.panelMap = [
     1  2  3  4  5  6  7  8  9 10 11 12;
     0  0  0  0  0  0  0  0  0  0  0  0;
     0  0  0  0  0  0  0  0  0  0  0  0;
     0  0  0  0  0  0  0  0  0  0  0  0
];
```

## Design Specification

### Arena Class Extension

Add `panelMap` as an optional property to the `Arena` class:

```matlab
classdef Arena < handle
    properties (SetAccess = private)
        numRows         % Number of panel rows
        numCols         % Number of panel columns
        generation      % 'G4', 'G41', 'G6'
        panelWidth      % Pixels per panel (typically 16)
        panelHeight     % Pixels per panel (typically 16)
    end
    
    properties (Access = public)
        panelMap        % Optional: Panel ID mapping matrix [numRows x numCols]
                        % Default: [] (use sequential 1:totalPanels)
                        % Values: 0 (disabled) or panel IDs (can duplicate)
    end
    
    properties (Dependent)
        totalWidth      % Total pixels wide
        totalHeight     % Total pixels high
        totalPanels     % Total number of panels
        activePanels    % Number of active panels (non-zero in panelMap)
        maxPanelID      % Highest panel ID in map (determines pattern size)
    end
    
    methods
        function obj = Arena(varargin)
            % Constructor can accept panelMap as name-value pair
            % arena = Arena.custom(4, 12, PanelMap=customMap);
        end
        
        function set.panelMap(obj, map)
            % Validate panel map
            if isempty(map)
                obj.panelMap = [];
                return;
            end
            
            % Check dimensions
            if ~isequal(size(map), [obj.numRows, obj.numCols])
                error('Arena:InvalidPanelMap', ...
                    'panelMap must be %dx%d (rows x cols), got %dx%d', ...
                    obj.numRows, obj.numCols, size(map, 1), size(map, 2));
            end
            
            % Check values (non-negative integers)
            if ~isnumeric(map) || any(map(:) < 0) || any(mod(map(:), 1) ~= 0)
                error('Arena:InvalidPanelMap', ...
                    'panelMap values must be non-negative integers');
            end
            
            obj.panelMap = map;
        end
        
        function n = get.activePanels(obj)
            if isempty(obj.panelMap)
                n = obj.totalPanels;
            else
                n = sum(obj.panelMap(:) > 0);
            end
        end
        
        function m = get.maxPanelID(obj)
            if isempty(obj.panelMap)
                m = obj.totalPanels;
            else
                m = max(obj.panelMap(:));
            end
        end
        
        function tf = hasCustomMapping(obj)
            % Check if a custom panel map is defined
            tf = ~isempty(obj.panelMap);
        end
        
        function panelID = getPanelID(obj, row, col)
            % Get panel ID for given row/col position
            % Returns 0 if panel is disabled
            if isempty(obj.panelMap)
                % Default sequential mapping
                panelID = (row - 1) * obj.numCols + col;
            else
                panelID = obj.panelMap(row, col);
            end
        end
        
        function [rows, cols] = findPanel(obj, panelID)
            % Find all physical positions for a given panel ID
            % (can return multiple if panel is duplicated)
            if isempty(obj.panelMap)
                % Default sequential mapping
                row = floor((panelID - 1) / obj.numCols) + 1;
                col = mod(panelID - 1, obj.numCols) + 1;
                rows = row;
                cols = col;
            else
                [rows, cols] = find(obj.panelMap == panelID);
            end
        end
    end
end
```

### Pattern Class Impact

The `Pattern` class needs to be aware of arena's `panelMap` for validation:

```matlab
classdef Pattern < handle
    methods
        function validateAgainstArena(obj, arena)
            % Validate pattern dimensions match arena
            %
            % With panelMap, we need to check against maxPanelID,
            % not totalPanels
            
            expectedWidth = arena.numCols * arena.panelWidth;
            expectedHeight = arena.maxPanelID * arena.panelHeight / arena.numCols;
            
            % For row_compression mode
            if obj.rowCompression
                expectedHeight = ceil(arena.maxPanelID / arena.numCols);
            end
            
            if obj.frameWidth ~= expectedWidth
                error('Pattern:DimensionMismatch', ...
                    'Pattern width %d does not match arena width %d', ...
                    obj.frameWidth, expectedWidth);
            end
            
            if obj.frameHeight ~= expectedHeight
                error('Pattern:DimensionMismatch', ...
                    'Pattern height %d does not match expected height %d', ...
                    obj.frameHeight, expectedHeight);
            end
        end
    end
end
```

### Encoding Logic Changes

The encoder needs to handle panel mapping when creating binary output:

```matlab
classdef EncoderG4 < handle
    methods (Static)
        function bytes = encodeFrame(frameData, arena, rowCompression)
            % Encode a single frame with panel mapping
            %
            % frameData: [height x width] grayscale matrix
            % arena: Arena object (may contain panelMap)
            % rowCompression: boolean
            
            if arena.hasCustomMapping()
                bytes = EncoderG4.encodeFrameWithMapping(frameData, arena, rowCompression);
            else
                bytes = EncoderG4.encodeFrameSequential(frameData, arena, rowCompression);
            end
        end
        
        function bytes = encodeFrameWithMapping(frameData, arena, rowCompression)
            % Encode frame respecting panelMap
            
            % Preallocate for maximum possible panels
            maxPanels = arena.totalPanels;
            bytesPerPanel = arena.panelWidth * arena.panelHeight / 2; % 4 bits/pixel
            if rowCompression
                bytesPerPanel = arena.panelWidth / 2;
            end
            
            panelBytes = zeros(maxPanels * bytesPerPanel, 1, 'uint8');
            outputIdx = 1;
            
            % Process panels in physical order (row-major)
            for row = 1:arena.numRows
                for col = 1:arena.numCols
                    panelID = arena.panelMap(row, col);
                    
                    if panelID == 0
                        % Skip disabled panels (send zeros)
                        panelBytes(outputIdx:outputIdx+bytesPerPanel-1) = 0;
                    else
                        % Extract data for this panel from pattern
                        [srcRows, srcCols] = EncoderG4.getPanelExtent(panelID, arena, rowCompression);
                        panelData = frameData(srcRows, srcCols);
                        
                        % Encode panel data
                        encoded = EncoderG4.encodePanelData(panelData);
                        panelBytes(outputIdx:outputIdx+length(encoded)-1) = encoded;
                    end
                    
                    outputIdx = outputIdx + bytesPerPanel;
                end
            end
            
            bytes = panelBytes;
        end
        
        function [rows, cols] = getPanelExtent(panelID, arena, rowCompression)
            % Get pixel extent for a panel ID in the pattern data
            %
            % Pattern is arranged as if panels were in sequential order
            
            % Calculate position in sequential layout
            panelRow = floor((panelID - 1) / arena.numCols) + 1;
            panelCol = mod(panelID - 1, arena.numCols) + 1;
            
            % Get pixel ranges
            if rowCompression
                rows = panelRow;
            else
                rows = (panelRow - 1) * arena.panelHeight + (1:arena.panelHeight);
            end
            cols = (panelCol - 1) * arena.panelWidth + (1:arena.panelWidth);
        end
    end
end
```

## File Format Impact

### Pattern File Header

The `.pat` file format should optionally store panel map information:

```
Header:
    uint16: x_panels (columns)
    uint16: y_panels (rows)  
    uint16: x_frames (num frames in X dimension)
    uint16: y_frames (num frames in Y dimension)
    uint16: gs_val (grayscale levels: 1, 3, or 4)
    uint16: flags (bit 0: row_compression, bit 1: has_panel_map)
    uint16: reserved
    uint16: reserved
    
    [Optional if flags.has_panel_map = 1]
    uint16: panel_map_length (= x_panels * y_panels * 2 bytes)
    uint16[]: panel_map data (row-major, each panel ID as uint16)
    
Frame Data:
    uint8[]: encoded frames...
```

### Backward Compatibility

- Patterns without `panelMap` work exactly as before
- The `has_panel_map` flag in header distinguishes files
- Old code ignores the flag and uses sequential mapping
- New code checks flag and reads map if present

## Usage Examples

### Example 1: Create Pattern with Custom Mapping

```matlab
% Create arena with custom panel arrangement
arena = Arena.custom(4, 12);
arena.panelMap = [
     0  2  3  4  5  6  7  8  9 10  0  0;
    13 14 15 16 17 18 19 20 21 22 23 24;
    25 26 27 28 29 30 31 32 33 34 35 36;
     0 38 39 40 41 42 43 44 45 46  0  0
];

% Create pattern (must have data for panels 2-10, 13-24, 25-36, 38-46)
% That's 40 panels max, so pattern needs 40 * 16 pixels height
frames = rand(40, 192, 1, 1) * 15; % 40 rows, 192 cols (12*16)

pat = Pattern(frames, arena);
pat.save('test.pat');
```

### Example 2: Mirror Pattern for Symmetric Display

```matlab
% Create mirrored arena
arena = Arena.custom(4, 12);

% Left 6 columns show panels 1-24, right 6 mirror them
leftPanels = reshape(1:24, 4, 6);
arena.panelMap = [leftPanels, fliplr(leftPanels)];

% Only need to create pattern for left half (24 panels)
frames = createMyPattern(24, arena.panelWidth); % Your pattern function

pat = Pattern(frames, arena);
pat.save('mirrored.pat');
```

### Example 3: Test Pattern on Single Row

```matlab
% Only enable top row for testing
arena = Arena.custom(4, 12);
arena.panelMap = [
     1:12;
    zeros(3, 12)
];

% Pattern only needs data for 12 panels
frames = createTestPattern(12, arena.panelWidth);

pat = Pattern(frames, arena);
pat.save('top_row_test.pat');
```

### Example 4: Load and Inspect Panel Map

```matlab
% Load pattern file
pat = Pattern.load('test.pat');

if pat.arena.hasCustomMapping()
    fprintf('Pattern uses custom panel mapping:\n');
    disp(pat.arena.panelMap);
    fprintf('Active panels: %d/%d\n', ...
        pat.arena.activePanels, pat.arena.totalPanels);
else
    fprintf('Pattern uses sequential panel mapping\n');
end
```

## CLI Integration

Add commands to work with panel maps:

```matlab
% Create arena with custom panel map
rdt arena create Rows=4, Cols=12, PanelMap=myMap

% Show panel map for a pattern
rdt pattern info "test.pat" --show-panel-map

% Validate panel map
rdt arena validate PanelMap=myMap, Rows=4, Cols=12
```

## Validation Rules

### Panel Map Validation

1. **Dimensions**: Must be `[numRows x numCols]`
2. **Values**: Non-negative integers (0 = disabled)
3. **No gaps**: If max panel ID is N, all IDs 1 to N should be used at least once
   - Warning (not error) if gaps exist
4. **Duplicates allowed**: Multiple positions can have same panel ID

### Pattern Validation Against Arena with Panel Map

1. **Height**: Pattern height must accommodate `maxPanelID`
   - Sequential: `height = ceil(maxPanelID / numCols) * panelHeight`
   - Row compression: `height = ceil(maxPanelID / numCols)`

2. **Width**: Pattern width must be `numCols * panelWidth`

3. **Content coverage**: All non-zero panel IDs in map must have corresponding data in pattern

## Error Handling

### Common Errors

```matlab
% Error: Panel map wrong size
arena.panelMap = ones(3, 10); % Should be 4x12
% Error: Arena:InvalidPanelMap
%        panelMap must be 4x12 (rows x cols), got 3x10

% Error: Invalid panel IDs
arena.panelMap = ones(4, 12) * -1;
% Error: Arena:InvalidPanelMap
%        panelMap values must be non-negative integers

% Warning: Gaps in panel IDs
arena.panelMap = reshape([1:20, 25:48, 0, 0, 0, 0], 4, 12)';
% Warning: Arena:PanelMapGaps
%          Panel IDs 21-24 are not used in panel map
```

### Pattern Size Mismatch

```matlab
% Pattern too small for panel map
arena = Arena.custom(4, 12);
arena.panelMap = reshape(1:48, 4, 12)'; % Uses all 48 panels

frames = rand(30, 192); % Only 30 rows, need 48
pat = Pattern(frames, arena);
% Error: Pattern:DimensionMismatch
%        Pattern height 30 does not match expected height 48
```

## Performance Considerations

### Memory

- Panel map adds minimal memory overhead (numRows × numCols × 2 bytes)
- Typical 4×12 arena: 96 bytes
- Pattern data size unchanged (determined by maxPanelID, not totalPanels)

### Encoding Speed

- Custom panel mapping adds ~10-20% overhead during encoding
- Negligible for interactive use
- Batch operations may see ~15% slowdown
- Optimization: Cache panel extent calculations

### File Size

- Panel map adds to header: typically <100 bytes
- Negligible compared to frame data (thousands to millions of bytes)

## Future Extensions

### Rotation and Transformation Helpers

```matlab
% Helper functions for common transformations
arena.panelMap = Arena.rotatePanelMap(originalMap, 90); % Rotate 90°
arena.panelMap = Arena.mirrorPanelMap(originalMap, 'horizontal');
arena.panelMap = Arena.shiftPanelMap(originalMap, 3, 'right');
```

### Panel Groups

```matlab
% Define named groups of panels
arena.addPanelGroup('left_wall', [1, 13, 25, 37]);
arena.addPanelGroup('right_wall', [12, 24, 36, 48]);

% Apply pattern to specific groups
pat.applyToGroup('left_wall', leftPattern);
```

### Dynamic Remapping

```matlab
% Change panel mapping without recreating pattern
pat.remapPanels(newPanelMap);
pat.save('remapped.pat');
```

## Testing Strategy

### Unit Tests

```matlab
% Test panel map validation
testInvalidDimensions()
testNegativeValues()
testDuplicatePanels()

% Test panel ID lookup
testGetPanelID()
testFindPanel()

% Test encoding with mapping
testEncodeWithMapping()
testEncodeDisabledPanels()
testEncodeDuplicatedPanels()
```

### Integration Tests

```matlab
% Test full workflow
testCreatePatternWithMapping()
testSaveLoadWithMapping()
testBackwardCompatibility()
```

### Visual Verification

```matlab
% Preview should show panel mapping
pat = Pattern.load('test.pat');
pat.preview(); % Should highlight disabled/duplicated panels
```

## Documentation Requirements

### User Guide

- Tutorial: "Creating Custom Panel Arrangements"
- Examples: Common use cases (asymmetric arenas, mirroring, testing)
- Troubleshooting: Common panel map errors

### API Documentation

- `Arena.panelMap` property documentation
- `getPanelID()` and `findPanel()` method documentation
- File format specification update

### Migration Guide

- How to convert existing patterns to use panel maps
- How to optimize patterns for custom layouts

## Conclusion

The `panelMap` extension provides powerful flexibility for custom arena configurations while maintaining:

1. **Backward compatibility**: Existing patterns work unchanged
2. **Simple API**: Easy to understand and use
3. **Efficient encoding**: Minimal performance impact
4. **Validation**: Clear error messages for invalid configurations
5. **Flexibility**: Supports disable, reorder, and duplicate use cases

The implementation integrates cleanly with the existing OOP architecture and CLI interface, following MATLAB-native design patterns.
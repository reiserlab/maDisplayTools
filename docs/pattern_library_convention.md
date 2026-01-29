# Pattern Library Convention

This document describes the recommended convention for organizing pattern files to enable automatic arena-pattern association and validation.

## Overview

Patterns are organized in directories whose names match arena configuration filenames (without the `.yaml` extension). This allows tools to automatically determine which arena a pattern was created for and validate compatibility.

## Directory Structure

```
patterns/
  G6_2x10/
    square_grating_G6.mat
    square_grating.pat
    sine_grating_G6.mat
    sine_grating.pat
  G41_2x12_ccw/
    edge_G4.mat
    edge.pat
  G6_2x8of10/
    starfield_G6.mat
    starfield.pat
```

## Arena Config Naming

Arena configurations are stored in `configs/arenas/` with the following naming conventions:

### Full Arenas
Format: `{GEN}_{rows}x{cols}.yaml`

Examples:
- `G6_2x10.yaml` - G6, 2 rows, 10 columns, 360° coverage
- `G4_3x12.yaml` - G4, 3 rows, 12 columns, 360° coverage
- `G3_4x12.yaml` - G3, 4 rows, 12 columns, 360° coverage

### Partial Arenas
Format: `{GEN}_{rows}x{installed}of{total}.yaml`

Examples:
- `G6_2x8of10.yaml` - G6, 2 rows, 8 of 10 columns installed (288° coverage)
- `G6_3x12of18.yaml` - G6, 3 rows, 12 of 18 columns installed (240° coverage)

### Arenas with Column Order
Format: `{GEN}_{rows}x{cols}_{order}.yaml`

Examples:
- `G41_2x12_ccw.yaml` - G4.1, 2 rows, 12 columns, counter-clockwise
- `G41_2x12_cw.yaml` - G4.1, 2 rows, 12 columns, clockwise

## Arena Config Schema

```yaml
format_version: "1.0"
name: "G6_2x10"
description: "Full G6 arena, 2 rows x 10 columns, 360 degree coverage"

arena:
  generation: "G6"        # G3, G4, G4.1, or G6
  num_rows: 2             # Number of panel rows
  num_cols: 10            # Number of columns in full grid
  columns_installed: null # null = all columns, or array of 0-indexed indices
  orientation: "normal"   # "normal" or "upside_down"
  column_order: "cw"      # "cw" or "ccw"
  angle_offset_deg: 0     # Rotation offset in degrees
```

### Partial Arena Example

```yaml
format_version: "1.0"
name: "G6_2x8of10"
description: "G6 walking arena, 2 rows, 8 of 10 columns installed"

arena:
  generation: "G6"
  num_rows: 2
  num_cols: 10
  columns_installed: [1, 2, 3, 4, 5, 6, 7, 8]  # Columns 0 and 9 missing
  orientation: "normal"
  column_order: "cw"
  angle_offset_deg: 0
```

## Validation

Use `validate_pattern_arena` to check that a pattern matches its arena:

```matlab
% Validate using directory convention
[valid, info] = validate_pattern_arena('patterns/G6_2x10/grating_G6.mat');

% Validate against explicit arena config
[valid, info] = validate_pattern_arena('my_pattern.mat', 'configs/arenas/G6_2x10.yaml');

% Quick check (prints result)
validate_pattern_arena('patterns/G6_2x10/grating_G6.mat');
% ✓ VALID: Pattern (40x200) matches arena 'G6_2x10' (40x200)
```

## Pattern Dimensions

Pattern pixel dimensions are determined by the arena configuration:

- **total_pixels_x** = `num_columns_installed * pixels_per_panel`
- **total_pixels_y** = `num_rows * pixels_per_panel`

Where `pixels_per_panel` is:
- G3: 8
- G4, G4.1: 16
- G6: 20

For partial arenas, `total_pixels_x` uses only the installed columns, not the full grid.

## File Naming

### During Development
Use descriptive names for pattern files:
- `square_grating_8px_G6.mat`
- `starfield_random_G6.mat`
- `sine_vertical_G4.mat`

### At SD Card Deployment
Files are renamed to `pat0001.pat`, `pat0002.pat`, etc. by `deploy_experiments_to_sd.m`.

## Migration from Existing Patterns

Existing patterns can be organized into the new structure:

1. Create directories matching your arena configs
2. Move pattern files into appropriate directories
3. Run validation to confirm correct organization:

```matlab
% Validate all patterns in a directory
files = dir('patterns/G6_2x10/*.mat');
for i = 1:length(files)
    validate_pattern_arena(fullfile(files(i).folder, files(i).name));
end
```

## Why This Convention?

1. **No file format changes** - Works with existing G4 and G6 patterns
2. **Language-agnostic** - Python, MATLAB, or any tool can infer arena from path
3. **Human-readable** - Clear at a glance which patterns belong to which arena
4. **Backward compatible** - Existing patterns work, just need to be organized
5. **Validation-friendly** - Tools can automatically verify pattern-arena compatibility

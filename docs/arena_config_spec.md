# Arena Configuration Specification

> **Version**: 1.0 (Draft)
> **Last Updated**: 2026-01-18

## Overview

The Arena Config is a JSON file that describes the complete physical and logical configuration of a panel display arena. It serves as the single source of truth for:

1. **Arena geometry** — panel generation, grid dimensions, which panels are installed
2. **Rig configuration** — IP address, enabled plugins
3. **Pattern constraints** — derived from geometry (pixels per panel, total resolution)

Both MATLAB and web tools read/write this same format, ensuring consistency across the toolchain.

---

## JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Arena Configuration",
  "type": "object",
  "required": ["format_version", "arena"],
  "properties": {
    "format_version": {
      "type": "string",
      "description": "Schema version for forward compatibility",
      "enum": ["1.0"]
    },
    "name": {
      "type": "string",
      "description": "Human-readable name for this configuration",
      "examples": ["G6_2x10_flight", "Lab_A_G41_arena"]
    },
    "description": {
      "type": "string",
      "description": "Optional notes about this arena setup"
    },
    "arena": {
      "type": "object",
      "required": ["generation", "num_rows", "num_cols"],
      "properties": {
        "generation": {
          "type": "string",
          "enum": ["G3", "G4", "G4.1", "G6"],
          "description": "Panel generation (G5 deprecated, not supported)"
        },
        "num_rows": {
          "type": "integer",
          "minimum": 1,
          "maximum": 8,
          "description": "Number of panel rows (vertical stacking)"
        },
        "num_cols": {
          "type": "integer",
          "minimum": 1,
          "maximum": 48,
          "description": "Number of panel columns (around the arena)"
        },
        "panels_installed": {
          "type": ["array", "null"],
          "items": {
            "type": "integer",
            "minimum": 0
          },
          "description": "0-indexed list of installed panel positions (row-major). null = all installed"
        },
        "orientation": {
          "type": "string",
          "enum": ["normal", "flipped"],
          "default": "normal",
          "description": "normal = row 0 at bottom, flipped = row 0 at top"
        },
        "angle_offset_deg": {
          "type": "number",
          "default": 0,
          "description": "Rotational offset in degrees for panel 0 position"
        }
      }
    },
    "rig": {
      "type": "object",
      "description": "Rig-specific configuration (optional)",
      "properties": {
        "ip_address": {
          "type": "string",
          "format": "ipv4",
          "description": "Controller IP address"
        },
        "port": {
          "type": "integer",
          "default": 62222,
          "description": "Controller TCP port"
        },
        "plugins": {
          "type": "object",
          "description": "Plugin configurations (TBD - awaiting Lisa's spec)",
          "properties": {
            "backlight": {
              "type": "object",
              "properties": {
                "enabled": { "type": "boolean", "default": false },
                "com_port": { "type": "string" },
                "ir_power": { "type": "integer", "minimum": 0, "maximum": 100 },
                "red_power": { "type": "integer", "minimum": 0, "maximum": 100 },
                "green_power": { "type": "integer", "minimum": 0, "maximum": 100 },
                "blue_power": { "type": "integer", "minimum": 0, "maximum": 100 }
              }
            },
            "camera": {
              "type": "object",
              "properties": {
                "enabled": { "type": "boolean", "default": false },
                "type": { "type": "string", "enum": ["BIAS", "SimpleBIAS"] },
                "ip": { "type": "string", "default": "127.0.0.1" },
                "port": { "type": "integer" },
                "config_file": { "type": "string" }
              }
            },
            "temperature": {
              "type": "object",
              "properties": {
                "enabled": { "type": "boolean", "default": false },
                "daq_device": { "type": "string", "default": "ni" },
                "channel": { "type": "string" }
              }
            }
          }
        }
      }
    },
    "metadata": {
      "type": "object",
      "description": "Optional metadata",
      "properties": {
        "created": { "type": "string", "format": "date-time" },
        "modified": { "type": "string", "format": "date-time" },
        "author": { "type": "string" }
      }
    }
  }
}
```

---

## Derived Properties

The following properties are computed from the arena configuration and should NOT be stored in the JSON:

| Property | Formula | Description |
|----------|---------|-------------|
| `pixels_per_panel` | Generation lookup | G3=8, G4/G4.1=16, G6=20 |
| `total_pixels_x` | `num_cols × pixels_per_panel` | Total horizontal resolution |
| `total_pixels_y` | `num_rows × pixels_per_panel` | Total vertical resolution |
| `num_panels` | `num_rows × num_cols` | Total panel slots |
| `num_panels_installed` | `length(panels_installed)` or `num_panels` | Active panels |
| `panel_width_mm` | Generation lookup | G3=32, G4=40.45, G4.1=40, G6=45.4 |
| `inner_radius_mm` | `panel_width / (2 × tan(π/num_cols))` | Arena inner radius |

### Generation Specifications

| Generation | Pixels | Panel Width (mm) | LED Type | Notes |
|------------|--------|------------------|----------|-------|
| G3 | 8×8 | 32 | Circle | Legacy |
| G4 | 16×16 | 40.45 | Circle | Legacy |
| G4.1 | 16×16 | 40 | 0604 rect | Current production |
| G5 | 20×20 | 40 | 0604 rect | **Deprecated** |
| G6 | 20×20 | 45.4 | 0604 rect | Next generation |

---

## Standard Configurations

These pre-defined configurations cover common use cases:

### G6_2x10_full
Full 360° cylinder with G6 panels.
```json
{
  "format_version": "1.0",
  "name": "G6_2x10_full",
  "description": "Full G6 arena, 2 rows × 10 columns",
  "arena": {
    "generation": "G6",
    "num_rows": 2,
    "num_cols": 10,
    "panels_installed": null,
    "orientation": "normal"
  }
}
```
- Resolution: 200 × 40 pixels
- Coverage: 360°

### G6_2x8_flight
Flight arena with rear gap (columns 0 and 9 removed).
```json
{
  "format_version": "1.0",
  "name": "G6_2x8_flight",
  "description": "G6 flight arena, 288° coverage with rear gap",
  "arena": {
    "generation": "G6",
    "num_rows": 2,
    "num_cols": 10,
    "panels_installed": [1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 13, 14, 15, 16, 17, 18],
    "orientation": "normal"
  }
}
```
- Resolution: 200 × 40 pixels (pattern), 160 × 40 active
- Coverage: 288° (72° gap behind fly)

### G41_2x12_full
Standard G4.1 arena.
```json
{
  "format_version": "1.0",
  "name": "G41_2x12_full",
  "description": "Standard G4.1 arena, 2 rows × 12 columns",
  "arena": {
    "generation": "G4.1",
    "num_rows": 2,
    "num_cols": 12,
    "panels_installed": null,
    "orientation": "normal"
  }
}
```
- Resolution: 192 × 32 pixels
- Coverage: 360°

### G3_4x12_full
Legacy G3 arena (reference).
```json
{
  "format_version": "1.0",
  "name": "G3_4x12_full",
  "description": "Legacy G3 arena, 4 rows × 12 columns",
  "arena": {
    "generation": "G3",
    "num_rows": 4,
    "num_cols": 12,
    "panels_installed": null,
    "orientation": "normal"
  }
}
```
- Resolution: 96 × 32 pixels
- Coverage: 360°

---

## Panel Indexing

Panels are indexed in **row-major order**, starting from 0:

```
Example: 2 rows × 10 columns

Row 1: [10] [11] [12] [13] [14] [15] [16] [17] [18] [19]
Row 0: [ 0] [ 1] [ 2] [ 3] [ 4] [ 5] [ 6] [ 7] [ 8] [ 9]
        ↑ Front of arena (fly facing)
```

For a **flight arena** with columns 0 and 9 removed:
```
panels_installed: [1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 13, 14, 15, 16, 17, 18]
```

### Orientation

- **normal**: Row 0 is at the bottom, row indices increase upward
- **flipped**: Row 0 is at the top, row indices increase downward

This affects how patterns are rendered but not how panels are indexed.

---

## MATLAB Interface

### Loading

```matlab
function config = load_arena_config(filepath)
    % Load arena configuration from JSON file
    %
    % Usage:
    %   config = load_arena_config('G6_2x10_full.json')
    %   config = load_arena_config()  % Opens file dialog
    %
    % Returns struct with fields:
    %   config.arena.generation
    %   config.arena.num_rows
    %   config.arena.num_cols
    %   config.arena.panels_installed  ([] if all installed)
    %   config.arena.orientation
    %   config.rig.ip_address
    %   config.rig.plugins
    %   config.derived.pixels_per_panel
    %   config.derived.total_pixels_x
    %   config.derived.total_pixels_y
    %   config.derived.inner_radius_mm
```

### Saving

```matlab
function save_arena_config(config, filepath)
    % Save arena configuration to JSON file
    %
    % Usage:
    %   save_arena_config(config, 'my_arena.json')
    %
    % Note: Derived properties are NOT saved (computed on load)
```

### Validation

```matlab
function [valid, errors] = validate_arena_config(config)
    % Validate arena configuration
    %
    % Checks:
    %   - Required fields present
    %   - Generation is supported (not G5)
    %   - panels_installed indices are valid
    %   - num_rows × num_cols ≤ 48
```

---

## Web Interface

The web arena editor exports this same JSON format:

```javascript
// Export button handler
function exportArenaConfig() {
    const config = {
        format_version: "1.0",
        name: document.getElementById('config-name').value,
        arena: {
            generation: state.panelType,
            num_rows: state.numRows,
            num_cols: state.numCols,
            panels_installed: getInstalledPanels(),  // null if all
            orientation: state.orientation,
            angle_offset_deg: state.angleOffset
        }
    };
    
    downloadJSON(config, `${config.name || 'arena_config'}.json`);
}
```

---

## Integration with Pattern Tools

### Pattern Generation
When creating patterns, the arena config determines:
1. **Grid size**: `num_rows × pixels_per_panel` by `num_cols × pixels_per_panel`
2. **Active regions**: Only generate visible patterns for installed panels
3. **Orientation**: Flip pattern vertically if `orientation = "flipped"`

### Pattern File Headers
The G6 pattern format (`.pat`) includes arena geometry in its header:
- `row_count` ← `arena.num_rows`
- `col_count` ← `arena.num_cols`
- `panel_mask` ← derived from `arena.panels_installed`

### Workflow
```
Arena Editor → arena_config.json → Pattern Generator → pattern.pat → SD Card
                     ↓
              PanelsController (uses rig.ip_address)
```

---

## Future Extensions (v2+)

Reserved for G6 protocol v2+ features:

```json
{
  "arena": {
    "g6_options": {
      "storage_mode": "local",      // "sd" or "local" (PSRAM)
      "protocol_version": 2,
      "regions": [
        { "id": 0, "columns": [0, 1, 2, 3, 4] },
        { "id": 1, "columns": [5, 6, 7, 8, 9] }
      ]
    }
  }
}
```

These fields are **not implemented** in v1 and should be ignored if present.

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-18 | Initial draft |

# Claude Code Guidelines for maDisplayTools

## MATLAB Integration

### MATLAB Connector
Claude Code can run MATLAB commands via the MATLAB Connector MCP server. To execute MATLAB code, use the general-purpose Task agent with a prompt like:

```
Run this MATLAB code:
cd('/Users/reiserm/Documents/GitHub/maDisplayTools');
results = validate_pattern_save_load();
```

The agent will execute the code and return the results.

### MANDATORY: Pattern Validation After Code Changes

**IMPORTANT**: After modifying ANY of the following files, you MUST run the validation script before considering the task complete:

**Files that require validation:**
- `g6/g6_encode_panel.m` - G6 panel encoding
- `g6/g6_decode_panel.m` - G6 panel decoding
- `g6/g6_save_pattern.m` - G6 pattern saving
- `patternTools/save_pattern.m` - G4/G4.1 pattern saving
- `patternTools/Pattern_Generator.m` - Core pattern generation
- `patternTools/PatternPreviewerApp.m` - Pattern loading/display
- `patternTools/PatternCombinerApp.m` - Pattern combination (also run `validate_pattern_combiner`)
- `maDisplayTools.m` - Pattern loading (`load_pat`, `load_pat_g4`, `load_pat_g6`)
- `utils/load_arena_config.m` - Arena config loading
- `configs/arenas/*.yaml` - Arena configuration files

**How to run validation:**
```matlab
cd('/Users/reiserm/Documents/GitHub/maDisplayTools');
results = validate_pattern_save_load();
% All 6 tests should pass
```

**Expected output:**
```
=== Pattern Save/Load Validation ===

Testing: G4 full 4x12
  PASS: Config loaded, dims=64x192 (G4 save test skipped)
Testing: G4 partial 3x12of18
  PASS: Config loaded, dims=48x192 (G4 save test skipped)
Testing: G4.1 full 2x12
  PASS: Config loaded, dims=32x192 (G4 save test skipped)
Testing: G6 full 2x10
  PASS: OK: 40x200, 2 frames
Testing: G6 partial 2x8of10
  PASS: OK: 40x160, 2 frames
Testing: G6 partial 3x12of18
  PASS: OK: 60x240, 2 frames

=== Summary ===
Passed: 6 / 6
All tests PASSED!
```

**If any test fails**: Do not mark the task as complete. Debug and fix the issue first.

## Repository Structure

```
maDisplayTools/
├── configs/
│   ├── arenas/          # Standard arena configs (YAML)
│   └── rigs/            # Rig configs (reference arena YAML)
├── controller/          # PanelsController, TCP code
├── docs/
│   └── G4G6_ROADMAP.md  # Main roadmap (update regularly)
├── g6/                  # G6-specific pattern tools
│   ├── g6_encode_panel.m
│   ├── g6_decode_panel.m
│   └── g6_save_pattern.m
├── patternTools/        # Pattern generation and preview tools
│   ├── PatternGeneratorApp.m  # Main GUI (App Designer)
│   ├── PatternPreviewerApp.m  # Preview GUI (App Designer)
│   ├── Pattern_Generator.m    # Core pattern engine
│   ├── save_pattern.m         # Pattern save router
│   ├── make_grating_edge.m    # Pattern types
│   ├── make_starfield.m
│   ├── arena_coordinates.m    # Arena geometry
│   ├── arena_projection.m
│   └── legacy/                # Deprecated GUIDE GUIs (reference only)
│       ├── G4_Pattern_Generator_gui.m
│       └── G4_Pattern_Generator_gui.fig
├── tests/               # Validation scripts
│   ├── validate_pattern_save_load.m
│   ├── test_arena_config.m
│   └── visualize_standard_arenas.m
└── utils/               # Utility functions
    ├── load_arena_config.m
    ├── get_generation_specs.m
    └── deploy_experiments_to_sd.m
```

## Key Files

### Roadmap
`docs/G4G6_ROADMAP.md` is the main project roadmap. Update it when:
- Completing tasks
- Discovering new issues
- Making architectural decisions
- Adding deferred items

### Single Source of Truth
- **Panel specs**: `utils/get_generation_specs.m`
- **Arena configs**: `configs/arenas/*.yaml`
- **Generation handling**: Always check generation from arena config, not hardcoded

## Pattern Generations

| Gen | Pixels | Panel Width | LED Type |
|-----|--------|-------------|----------|
| G3 | 8x8 | 32mm | 3mm round |
| G4 | 16x16 | 40.45mm | 1.9mm round |
| G4.1 | 16x16 | 40mm | 0603 SMD (45°) |
| G6 | 20x20 | 45.4mm | 0402 SMD (45°) |

**Note**: G5 is deprecated and not supported.

## Encoding Conventions

### G6 Panel Encoding
- **Origin**: (0,0) at bottom-left of panel
- **Order**: Row-major (`pixel_num = row * 20 + col`)
- **Row flip**: Encoder flips rows (`row_from_bottom = 19 - row`), decoder must flip back
- **GS2**: 1-bit binary, 53 bytes per panel (header + cmd + 50 data + stretch)
- **GS16**: 4-bit grayscale, 203 bytes per panel (header + cmd + 200 data + stretch)

### G4/G4.1 Pattern Format
- Uses `make_pattern_vector_g4()` for binary encoding
- `.mat` file contains metadata, `.pat` file is binary for controller
- gs_val: 1=binary (2 levels), 4=grayscale (16 levels)

### Panel ID Numbering (Display)
Panel IDs in PatternPreviewerApp use **column-major** ordering:
- Column 0: Pan 0, Pan 1, Pan 2 (going down rows)
- Column 1: Pan 3, Pan 4, Pan 5 (going down rows)
- Formula: `panelID = col * numRows + row`

This matches the G6 documentation convention.

## Arena Configs

### Partial Arenas
Partial arenas have fewer columns installed than the full grid:
```yaml
arena:
  num_rows: 2
  num_cols: 10           # Full grid columns
  columns_installed: [0, 1, 2, 3, 4, 5, 6, 7]  # 0-indexed, 8 of 10 installed
```

Naming convention: `G6_2x8of10.yaml` = 2 rows, 8 installed columns of 10 total

### Column Order
- `cw` = clockwise when viewed from above
- `ccw` = counter-clockwise
- Column 0 starts at south in both cases

## Testing Workflow

1. Make code changes
2. **Run validation script** (MANDATORY for pattern-related changes):
   ```matlab
   cd('/Users/reiserm/Documents/GitHub/maDisplayTools');
   results = validate_pattern_save_load();
   ```
3. Verify all 6 tests pass
4. Test in GUI if UI changes (PatternGeneratorApp, PatternPreviewerApp)
5. Update roadmap if needed

### Validation Script Details

`tests/validate_pattern_save_load.m` tests:
| Arena Config | Expected Dims | Description |
|--------------|---------------|-------------|
| G4_4x12.yaml | 64×192 | G4 full arena |
| G4_3x12of18.yaml | 48×192 | G4 partial arena |
| G41_2x12_cw.yaml | 32×192 | G4.1 full arena |
| G6_2x10.yaml | 40×200 | G6 full arena |
| G6_2x8of10.yaml | 40×160 | G6 partial (8 of 10 cols) |
| G6_3x12of18.yaml | 60×240 | G6 partial (12 of 18 cols) |

The G6 tests perform full save/load cycles. G4/G4.1 tests verify config loading and dimensions.

## App Designer GUIs

The pattern tools use MATLAB App Designer (not GUIDE):
- Single `.m` file contains UI and code
- Callbacks are methods
- Modern, maintainable architecture
- All located in `patternTools/`

### Current Apps

| App | Purpose | Status |
|-----|---------|--------|
| `PatternPreviewerApp.m` | Central hub for viewing/animating patterns | ✅ Complete |
| `PatternGeneratorApp.m` | Pattern creation (gratings, starfield, etc.) | ✅ Complete (needs separation from preview) |
| `PatternCombinerApp.m` | Combine two patterns (sequential, mask, L/R split) | ✅ Complete |

### Pattern Combiner Validation

After modifying `PatternCombinerApp.m`, also run:
```matlab
results = validate_pattern_combiner();
% All 12 tests should pass
```

### MANDATORY: GUI Visual Verification

**IMPORTANT**: After modifying ANY GUI file (PatternGeneratorApp.m, PatternPreviewerApp.m, or other App Designer apps), you MUST capture and verify a screenshot.

**How to capture GUI screenshots:**
```matlab
cd('/Users/reiserm/Documents/GitHub/maDisplayTools');
clear classes;
addpath(genpath('.'));

% Create screenshots directory if needed
if ~exist('screenshots', 'dir'), mkdir('screenshots'); end

% Launch app and capture screenshot
app = PatternPreviewerApp();  % or PatternGeneratorApp()
pause(1);  % Allow UI to render
drawnow;
exportapp(app.UIFigure, 'screenshots/previewer_test.png');
delete(app);
```

**After capturing, use the Read tool to view the screenshot** at `screenshots/*.png` and verify:
- All buttons, checkboxes, dropdowns, and labels appear
- Text is not truncated or cut off
- New UI elements fit within their containers
- Layout looks correct (elements don't overlap)

**Why this matters**: MATLAB caches class definitions. You must run `clear classes` before relaunching to see changes. Additionally, UI elements can be created correctly in code but not visible due to:
- Container/panel not tall enough to show all rows
- Column widths too narrow for text
- Elements placed outside visible area

**If UI element not visible**: Check the grid layout RowHeight/ColumnWidth settings and element Layout.Row/Layout.Column assignments.

### Why Not GUIDE?
The legacy `G4_Pattern_Generator_gui.m` (in `patternTools/legacy/`) uses GUIDE which has:
- Hardcoded callbacks in binary `.fig` files
- Cannot programmatically rename callbacks
- GUIDE is deprecated by MathWorks

## Common Issues

### Pattern displays upside down
Check that decoder flips rows to compensate for encoder flip.
See `g6_decode_panel.m` lines 66 and 99.

### "Index exceeds array elements" on load
Check panel_mask handling in loader. Partial arenas have fewer panels than full grid.

### MATLAB function caching
After changing function signatures, run:
```matlab
rehash path;
clear function_name;
```

## Inter-App Communication

### PatternPreviewerApp Public API

When other apps (PatternGeneratorApp, PatternCombiner, DrawingApp) need to send patterns to the Previewer:

```matlab
previewer = PatternPreviewerApp;
previewer.loadPatternFromApp(Pats, stretch, gs_val, name, arenaConfig);
```

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `Pats` | 3D uint8 (rows × cols × frames) | Yes | Pixel data |
| `stretch` | 1D array or scalar | Yes | Stretch value per frame |
| `gs_val` | 2 or 16 | Yes | Grayscale mode |
| `name` | string | No | Display name for pattern |
| `arenaConfig` | struct | No* | Arena configuration |
| `isUnsaved` | boolean | No | Show "UNSAVED" warning label |

*`arenaConfig` should be passed explicitly rather than relying on auto-detection from dimensions. Multiple arena configs can have identical dimensions, making auto-detection unreliable.

**Arena Config Resolution Priority:**
1. **Explicit parameter** (preferred) - Pass `arenaConfig` from the generating app
2. **Directory name** (fallback) - If pattern is saved, directory name should match arena config name per pattern library convention
3. **Dimension matching** (last resort) - Only if above methods unavailable; may be ambiguous

**Why explicit is better:**
- Guarantees correct panel boundaries and IDs
- Essential for partial arenas (e.g., G6_2x8of10 vs G6_2x10 have same row count)
- Enables accurate projection views (Mercator/Mollweide)

## Related Repositories

- `webDisplayTools` - Web-based editors (public)
- `G4_Display_Tools` - Legacy G4 code (reference only)

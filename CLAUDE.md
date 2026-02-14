# Claude Code Guidelines for maDisplayTools

## Model Preference

**IMPORTANT**: Use **Claude Opus 4** as the default model for this project.
- Do NOT automatically switch to Sonnet 4.5
- Opus 4 provides better code quality and architectural reasoning for this codebase
- Only use Haiku for trivial tasks when explicitly approved

## MATLAB Development Guidelines

When writing MATLAB code, follow these best practices and resources:

### Performance Optimization
- Reference: [MATLAB Performance Optimizer Skill](https://github.com/matlab/skills/tree/main/skills/matlab-performance-optimizer)
- Key principles:
  - Preallocate arrays when size is known
  - Vectorize operations instead of loops where possible
  - Use built-in functions (they're optimized)
  - Profile before optimizing (use `profile on/off/viewer`)

### App Development
- Reference: [Creating Programmatic Apps](https://github.com/matlab/prompts/blob/main/prompts/app-building/create-programmatic-app.md)
- Use App Designer for GUI development
- Follow established patterns in existing apps (PatternGeneratorApp, PatternPreviewerApp, PatternCombinerApp)
- Maintain singleton pattern for main GUI apps

### Coding Standards
- Reference: [MATLAB Coding Rules](https://github.com/matlab/rules)
- Write clear, descriptive function headers with examples
- Use structured comments (Purpose, Inputs, Outputs, Examples)
- Validate inputs at function entry
- Use meaningful variable names (no single-letter vars except loop indices)

## MATLAB Integration

### MATLAB Connector
Claude Code can run MATLAB commands via the MATLAB Connector MCP server. To execute MATLAB code, use the general-purpose Task agent with a prompt like:

```
Run this MATLAB code:
cd('/Users/reiserm/Documents/GitHub/maDisplayTools');
results = validate_pattern_save_load();
```

The agent will execute the code and return the results.

**MATLAB application path**: `/Applications/MATLAB_R2025b.app/bin/matlab`

## Testing Requirements

### Standard Test Preamble

**ALL MATLAB test code must start with:**
```matlab
cd('/Users/reiserm/Documents/GitHub/maDisplayTools');
clear classes;    % Clear cached class definitions (REQUIRED for App Designer changes)
addpath(genpath('.'));  % Add all subdirectories to path
```

**Why `clear classes` is essential:**
- MATLAB caches class definitions aggressively
- Without it, changes to App Designer apps won't take effect
- Symptoms: "old" behavior persists, properties not found, callbacks don't match

### MANDATORY Testing After Code Changes

Run the appropriate tests based on what files you modified. **Do not mark a task complete until all relevant tests pass.**

#### 1. Pattern Save/Load Validation

**When required:** After modifying ANY of these files:
- `g6/g6_encode_panel.m` - G6 panel encoding
- `g6/g6_decode_panel.m` - G6 panel decoding
- `g6/g6_save_pattern.m` - G6 pattern saving
- `patternTools/save_pattern.m` - G4/G4.1 pattern saving
- `patternTools/Pattern_Generator.m` - Core pattern generation
- `patternTools/PatternPreviewerApp.m` - Pattern loading/display
- `maDisplayTools.m` - Pattern loading (`load_pat`, `load_pat_g4`, `load_pat_g6`)
- `utils/load_arena_config.m` - Arena config loading
- `configs/arenas/*.yaml` - Arena configuration files

**How to run:**
```matlab
cd('/Users/reiserm/Documents/GitHub/maDisplayTools');
results = validate_pattern_save_load();
% All 6 tests should pass
```

**Test coverage:**
| Arena Config | Expected Dims | Description |
|--------------|---------------|-------------|
| G4_4x12.yaml | 64×192 | G4 full arena |
| G4_3x12of18.yaml | 48×192 | G4 partial arena |
| G41_2x12_cw.yaml | 32×192 | G4.1 full arena |
| G6_2x10.yaml | 40×200 | G6 full arena |
| G6_2x8of10.yaml | 40×160 | G6 partial (8 of 10 cols) |
| G6_3x12of18.yaml | 60×240 | G6 partial (12 of 18 cols) |

**Expected output:**
```
=== Pattern Save/Load Validation ===
Testing: G4 full 4x12
  PASS: Config loaded, dims=64x192
Testing: G4 partial 3x12of18
  PASS: Config loaded, dims=48x192
Testing: G4.1 full 2x12
  PASS: Config loaded, dims=32x192
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

#### 2. Pattern Combiner Validation

**When required:** After modifying `PatternCombinerApp.m`

**How to run:**
```matlab
cd('/Users/reiserm/Documents/GitHub/maDisplayTools');
results = validate_pattern_combiner();
% All 12 tests should pass
```

#### 3. App Launch Test

**When required:** After modifying ANY App Designer file (*.m files for apps)

**How to run:**
```matlab
cd('/Users/reiserm/Documents/GitHub/maDisplayTools');
clear classes;
addpath(genpath('.'));

% Test only the apps you modified
app = PatternGeneratorApp(); pause(1); delete(app);
app = PatternPreviewerApp(); pause(1); delete(app);
app = PatternCombinerApp(); pause(1); delete(app);
disp('All apps launched successfully');
```

**Why this is required:**
- Property declarations must match all property references
- UI component creation order matters
- Callback function signatures must be correct
- These errors only appear at runtime, not during file editing

#### 4. Singleton Pattern Test

**When required:** After modifying ANY app constructor (startupFcn or constructor method)

**How to run:**
```matlab
cd('/Users/reiserm/Documents/GitHub/maDisplayTools');
results = test_singleton_pattern();
% All 3 tests should pass
```

**Why this matters:**
- Only one instance of each app should exist at a time
- Prevents conflicts in inter-app communication
- Second instance attempt should throw error with ID `*:SingletonViolation`
- Existing app is brought to front with alert shown

#### 5. GUI Visual Verification

**When required:** After modifying ANY App Designer UI layout or adding/removing UI components

**How to run:**
```matlab
cd('/Users/reiserm/Documents/GitHub/maDisplayTools');
clear classes;
addpath(genpath('.'));

% Create screenshots directory if needed
if ~exist('screenshots', 'dir'), mkdir('screenshots'); end

% Launch app and capture screenshot
app = PatternPreviewerApp();  % or PatternGeneratorApp(), PatternCombinerApp()
pause(1);  % Allow UI to render
drawnow;
exportapp(app.UIFigure, 'screenshots/test_screenshot.png');
delete(app);
```

**After capturing, use the Read tool to verify:**
- All buttons, checkboxes, dropdowns, and labels appear
- Text is not truncated or cut off
- New UI elements fit within their containers
- Layout looks correct (elements don't overlap)

**Common UI visibility issues:**
- Container/panel not tall enough to show all rows
- Column widths too narrow for text
- Elements placed outside visible area
- Solution: Check grid layout RowHeight/ColumnWidth settings and element Layout.Row/Layout.Column assignments

#### 6. Web → MATLAB Roundtrip Validation

**When required:** After modifying `pat-encoder.js`, `pat-parser.js` (webDisplayTools), or MATLAB load functions (`maDisplayTools.load_pat`, `load_pat_g4`, `load_pat_g6`)

**Step 1 — Generate web reference patterns:**
```bash
cd /Users/reiserm/Documents/GitHub/webDisplayTools
node tests/generate-roundtrip-patterns.js --outdir ../maDisplayTools/tests/web_generated_patterns
```

**Step 2 — Validate in MATLAB:**
```matlab
cd('/Users/reiserm/Documents/GitHub/maDisplayTools');
clear classes; addpath(genpath('.'));
results = validate_web_roundtrip();
% All 8 tests should pass
```

**Test coverage:**
| # | Arena Config | GS | Pattern Type | Frames |
|---|-------------|-----|-------------|--------|
| 1 | G6_2x10 | GS16 | Square grating | 20 |
| 2 | G6_2x10 | GS2 | Square grating | 20 |
| 3 | G6_2x8of10 | GS16 | Sine grating | 20 |
| 4 | G6_3x12of18 | GS16 | Horizontal grating | 20 |
| 5 | G4_4x12 | GS16 | Square grating | 16 |
| 6 | G4_4x12 | GS2 | Square grating | 16 |
| 7 | G41_2x12_cw | GS16 | Sine grating | 16 |
| 8 | G4_3x12of18 | GS16 | Checkerboard | 16 |

**What it validates:** Pixel-exact match for all frames (deterministic patterns generated by web PatEncoder, loaded by MATLAB load_pat), plus V2 header metadata (generation, arena_id, dimensions, gs_val).

**When to re-run manually:**

| Trigger | What changed | Run what |
|---------|-------------|----------|
| Modified `pat-encoder.js` | Encoding logic | Regenerate patterns + MATLAB validation |
| Modified `pat-parser.js` | Parsing logic | Regenerate patterns + MATLAB validation |
| Modified `maDisplayTools.m` load functions | MATLAB decoder | MATLAB validation only (existing .pat files) |
| Modified `g6_decode_panel.m` | G6 panel decoding | MATLAB validation only |
| Modified `read_g4_header.m` or `read_g6_header.m` | Header parsing | MATLAB validation only |
| New arena config added | Arena registry | Add test case to generator, regenerate + validate |
| Before major release/merge | Catch any regressions | Full regenerate + MATLAB validation |

**CI/CD note:** The roundtrip test cannot run in GitHub Actions (MATLAB license required). Web-side CI covers encoder/parser regressions via `validate-header-v2.js` (10 tests), `validate-g6-encoding.js` (25 tests), and `validate-pattern-generation.js` (11 tests). The generator script self-verifies (encode → parse → pixel compare).

### Testing Utilities

**Close all App Designer apps and reset state:**
```matlab
delete(findall(0, 'Type', 'figure'));  % Close all figures AND App Designer apps
clear classes;
```

**Close only pattern apps:**
```matlab
close_pattern_apps();  % Closes PatternPreviewerApp, PatternGeneratorApp, PatternCombinerApp
```
Also available via "Close Pattern Apps" button in PatternPreviewerApp's status bar.

**Note:** `close all` does NOT close App Designer apps (only traditional `figure()` windows). Use `delete(app)` when you have the handle, or `delete(findall(0, 'Type', 'figure'))` to close all.

**Test with synthetic patterns:**
```matlab
app = PatternPreviewerApp();
testPats = uint8(zeros(40, 200, 2));  % 2 frames
testPats(:,:,1) = randi([0 15], 40, 200);  % Random grayscale
arenaConfig = load_arena_config('G6_2x10.yaml');
app.loadPatternFromApp(testPats, [1 1], 16, 'Test Pattern', arenaConfig);
```

### Close Session Protocol

When the user says **"close session"**, enter plan mode and prepare documentation updates:

1. **Summarize session work**
   - List files modified/created
   - Describe features added, bugs fixed, or refactors completed

2. **Review CLAUDE.md for updates**
   - New testing patterns or best practices discovered
   - Gotchas or pitfalls encountered
   - New utility functions that should be documented
   - Any corrections to existing documentation

3. **Review docs/G4G6_ROADMAP.md for updates**
   - Mark completed tasks as done
   - Add any new issues discovered during the session
   - Note deferred items or future improvements identified

4. **Present plan for approval**
   - Show all proposed documentation changes
   - Wait for user approval before making edits

5. **After approval**
   - Make the documentation updates
   - Optionally offer to create a git commit summarizing the session

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

### Session Logs
Detailed session logs are archived in `docs/G4G6_ROADMAP_SESSIONS.md` to reduce context usage.

**Convention:**
- The main roadmap (`G4G6_ROADMAP.md`) contains only a brief changelog table
- Detailed session notes go in `G4G6_ROADMAP_SESSIONS.md`
- At session close, add a one-line entry to the changelog table and append full details to the sessions file

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

## Arena Registry

The arena registry assigns unique IDs to arena configurations for use in pattern file headers.

### Key Design: Per-Generation Namespaces

Arena IDs are **per-generation**, not global:
- G4 arena ID 1 ≠ G6 arena ID 1
- Each generation (G4, G4.1, G6) has its own ID namespace
- Registry location: `configs/arena_registry/`

### Utility Functions

**Get arena ID from name:**
```matlab
arena_id = get_arena_id('G6', 'G6_2x10');  % Returns 1
```

**Get arena name from ID:**
```matlab
arena_name = get_arena_name('G6', 1);  % Returns 'G6_2x10'
```

**Get generation ID/name:**
```matlab
gen_id = get_generation_id('G4.1');  % Returns 3
gen_name = get_generation_name(3);   % Returns 'G4.1'
```

### ID Ranges

**G4.1 (8-bit):** 0=unspecified, 1-10=Reiser lab, 11-200=community, 201-254=user, 255=reserved
**G6 (6-bit):** 0=unspecified, 1-10=Reiser lab, 11-50=community, 51-62=user, 63=reserved

See `configs/arena_registry/README.md` for full documentation.

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
| `PatternGeneratorApp.m` | Focused pattern creation, sends to Previewer | ✅ Complete |
| `PatternCombinerApp.m` | Combine two patterns (sequential, mask, L/R split) | ✅ Complete |
| `PatternGeneratorApp_v0.m` | Legacy generator with embedded preview (archived) | 📦 Archived |

### Why Not GUIDE?
The legacy `G4_Pattern_Generator_gui.m` (in `patternTools/legacy/`) uses GUIDE which has:
- Hardcoded callbacks in binary `.fig` files
- Cannot programmatically rename callbacks
- GUIDE is deprecated by MathWorks

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

## Controller API (PanelsController)

### Preferred: `trialParams`

Use `trialParams` for all controller commands in scripts and examples:

```matlab
pc.trialParams(controlMode, patternID, fps, initPos, gain, deciSeconds, waitForEnd)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `controlMode` | 0-7 | Mode (2=constant rate, 3=stream position, 4=closed-loop, etc.) |
| `patternID` | uint16 | Pattern slot on SD card |
| `fps` | int16 | Frame rate (signed; negative = reverse) |
| `initPos` | int16 | Initial frame position (signed) |
| `gain` | uint16 | Gain value (for closed-loop modes) |
| `deciSeconds` | uint16 | Duration in 0.1s units (e.g., 50 = 5 sec) |
| `waitForEnd` | bool | Wait for controller to signal completion (default: `true`) |

**Usage patterns:**
```matlab
% Mode 2 (constant rate): let controller handle timing
pc.trialParams(2, patID, 10, 1, 0, 50, true);  % 10fps, 5 sec, blocks until done

% Mode 3 (stream position): non-blocking so MATLAB can send updates
pc.trialParams(3, patID, 0, 1, 0, 600, false);  % 60 sec timeout
pc.setPositionX(frameIndex);  % Send position updates
pc.stopDisplay();              % Stop when done

% Mode 4 (closed-loop): let controller handle timing
pc.trialParams(4, patID, 0, 1, gain, 100, true);  % 10 sec
```

### Deprecated: `startG41Trial`

**Do NOT use `startG41Trial` in new code.** Use `trialParams` instead — it sends the same TCP command (`0x0C 0x08`) with a cleaner interface and supports all modes 0-7.

`startG41Trial` is scheduled for removal in a future cleanup pass.

### Lab Test Scripts

| Script | Purpose |
|--------|---------|
| `tests/create_lab_test_patterns.m` | Generate curated patterns for lab validation |
| `tests/diagnose_web_patterns.m` | Byte-level .pat file comparison (row headers, frames) |
| `examples/test_mode3.m` | Mode 3 (stream position) lab test suite |
| `examples/G41_Modes_Demo.m` | Modes 2/3/4 demo using `trialParams` |

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

## Related Repositories

| Repository | Path | Description |
|------------|------|-------------|
| `webDisplayTools` | `/Users/reiserm/Documents/GitHub/webDisplayTools` | Web-based editors (public) |
| `G4_Display_Tools` | (GitHub only) | Legacy G4 code (reference only) |

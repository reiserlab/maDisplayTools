# G4G6 Roadmap - Session Archive

> **Purpose**: Detailed session logs moved here to keep the main roadmap compact.
> See `G4G6_ROADMAP.md` for the compact changelog table.

---

## 2026-01-31: Pattern Editor UI Fixes + Major Issues Documented

**Focus**: Bug fixes for 3D viewer panel labels, combiner naming, and documenting critical issues for future work

**Completed**:

1. **3D Viewer Panel Number Fixes** (`js/pattern-editor/viewers/three-viewer.js`):
   - Fixed CSS2D label cleanup - labels now properly removed when unchecking "Panel numbers" checkbox
   - Root cause: Labels were nested inside column groups but cleanup only checked direct children
   - Solution: Added explicit cleanup of `this.labelObjects` array before clearing arena, plus clearing all children from `labelRenderer.domElement` container
   - Changed panel number color from yellow (#ffff00) to red (#ff3333) for better visibility
   - Increased font size from 14px to 17px (20% larger)
   - Enhanced text shadow for better contrast

2. **Combined Pattern Suggested Names** (`pattern_editor.html`):
   - Added `getBaseName()` helper to extract clean names from filenames (removes .pat extension, paths, truncates to 20 chars)
   - Auto-generates descriptive names when combining patterns: `{nameA}_{nameB}_{mode}.pat`
   - Mode suffixes: `seq` (sequential), `blend`, `mask`, `splitH{%}` (horizontal split), `splitV{%}` (vertical split)

3. **Rename Button** (`pattern_editor.html`):
   - Added ✎ button to status bar next to filename
   - Opens prompt dialog to change pattern filename
   - Automatically adds .pat extension if missing
   - Marks pattern as dirty after rename

**Major Issues Documented for Next Session**:

1. **CRITICAL - Pattern Geometry Model**: Web uses simple pixel shifting but MATLAB has full spherical projection model. Nearly all pattern generation is geometrically incorrect. Need to analyze `Pattern_Generator.m`, `arena_coordinates.m`, `make_*.m` functions and implement matching JS geometry engine.

2. **Arena Config in Filename**: Web patterns lack folder structure. Proposed solution: prepend arena config (e.g., `G6_2x10_grating_20px.pat`).

3. **Locked Arena Config**: Should be set once and locked, not dropdown-selectable mid-session.

4. **Stretch Feature**: Referenced in MATLAB but not offered in web UI. Needs code analysis.

5. **3D Viewer Features**: Need analysis of missing features (screenshots, view presets, angular resolution histogram, etc.).

6. **Export Formats**: GIF, MP4/MPG, PNG sequence export not implemented.

**Files Modified**:
- `js/pattern-editor/viewers/three-viewer.js` — Label cleanup, color, size
- `pattern_editor.html` — getBaseName(), suggested names, rename button

**Key Technical Notes**:
- CSS2DRenderer appends label elements to its own `domElement` container, not the Three.js scene
- When removing CSS2DObjects from scene, must also remove their DOM elements from labelRenderer container
- `this.labelObjects` array tracks all labels for cleanup

---

## 2026-01-30 (Night): Pattern Editor Streams F, G, H

**Focus**: Complete remaining Pattern Editor work streams

**Completed**:

1. **Stream F: 3D Viewer Integration**:
   - Fixed Three.js ES6 module imports (full CDN URLs instead of importmap-style)
   - Fixed arena positioning (columns at Y=0, matching arena_3d_viewer.html)
   - Fixed camera setup (top-down at cRadius*3, controls.update() call)
   - Added double-initialization guard to prevent multiple renderers
   - Verified: pattern renders, frame stepping works

2. **Stream G: Pattern Combiner**:
   - Created `js/pattern-editor/tools/combiner.js`:
     - `combineSequential()` — concatenate frames
     - `combineMask()` — threshold/blend spatially
     - `combineSplit()` — left/right or top/bottom
   - Integrated into pattern_editor.html:
     - Pattern A/B info displays
     - Load Pattern B button
     - Swap A ↔ B button
     - Combination mode dropdown
     - Error handling for mismatches

3. **Stream H: Integration & Polish**:
   - All module syntax checks pass
   - validate-pattern-generation.js: 6/6 pass
   - validate-g6-encoding.js: 25/25 pass
   - HTML structure complete

4. **CLAUDE.md Update**:
   - Added "Planning Best Practices" section
   - Recommends parallel Explore agents (2-3) for complex tasks

**Files Created/Modified**:
- `js/pattern-editor/viewers/three-viewer.js` — Fixed imports, positioning
- `js/pattern-editor/tools/combiner.js` — NEW
- `pattern_editor.html` — Combiner integration
- `CLAUDE.md` — Planning best practices

**Key Technical Notes**:
- Three.js importmap doesn't apply to externally loaded modules; use full URLs
- Arena columns must be centered at Y=0 for camera math to work
- Always call `controls.update()` after setting target/position

**Remaining for Future Sessions**:
- Generate MATLAB reference data for pattern validation
- Manual end-to-end testing of all features
- Performance optimization for large patterns
- Remove development banner when ready

---

## 2026-01-30 (Late): Claude Code Demo Projects Session

**Focus**: Identify and implement demo projects for colleagues new to Claude Code

**Completed**:

1. **G6 Panel Editor Pattern Templates** (webDisplayTools):
   - Added 25+ new templates to `g6_panel_editor.html`
   - **GS2 templates**: Directional arrows (up/down/left/right), geometric shapes (circle, filled circle, triangles, diamond, star), half patterns, quadrants
   - **GS16 templates**: Gradient arrows, expanding discs (small/medium/large for looming), sine waves (2 frequencies), Gaussian blobs
   - Updated version from 7 to 8

2. **Reverse-Phi Pattern** (attempted, incomplete):
   - Created `make_reverse_phi.m` with basic frame inversion
   - Updated `Pattern_Generator.m` dispatcher
   - Added "Reverse-Phi" to PatternGeneratorApp dropdown
   - **Issue**: Implementation is incorrect - simple frame inversion doesn't produce proper reverse-phi illusion
   - **Action needed**: Research proper specification (Anstis 1970, Chubb & Sperling 1988) before reimplementing

**Files Created/Modified**:
- `webDisplayTools/g6_panel_editor.html` — New templates (v8)
- `patternTools/make_reverse_phi.m` — NEW (needs revision)
- `patternTools/Pattern_Generator.m` — Added 're' case
- `patternTools/PatternGeneratorApp.m` — Added Reverse-Phi option

**Deferred**:
- Reverse-Phi needs proper specification before reimplementation
- Consider removing from UI or marking experimental

---

## 2026-01-30: Web Pattern Viewer Implementation

**Focus**: Add .pat file loading to 3D arena viewer (webDisplayTools)

**Completed**:

1. **Pattern Parser Module** (`js/pat-parser.js`):
   - G6 format: 17-byte header with "G6PT" magic, 20×20 panels
   - G4 format: 7-byte header, 16×16 panels
   - Row flip compensation (encoder flips rows, decoder must flip back)
   - Verification function with console logging
   - ES module exports for browser import

2. **3D Viewer Pattern Loading** (`arena_3d_viewer.html`):
   - "Load .pat File" button with file picker
   - Pattern info display (filename, generation, dimensions, frames, GS mode)
   - Frame slider for multi-frame navigation
   - Play/Pause button with FPS dropdown (1, 5, 10, 20, 30)
   - Clear Pattern button to return to test patterns
   - Auto-detect matching arena config from pattern dimensions

3. **FOV Controls**:
   - FOV slider (30° to 170°)
   - Preset buttons: Normal (60°), Wide (120°), Fly Eye (170°)
   - Real-time camera update

4. **Testing Infrastructure**:
   - `window.testLoadPattern(url)` for automated testing
   - Chrome extension testing workflow documented
   - Console logging for pattern verification

5. **Documentation** (`CLAUDE.md`):
   - Pattern validation section
   - Chrome extension testing workflow
   - Close session protocol (references maDisplayTools roadmap)

**GitHub Issues Created**:
- #8: UI polish and playback improvements
- #9: True fisheye shader for fly eye simulation

**Files Created/Modified**:
- `webDisplayTools/js/pat-parser.js` — NEW
- `webDisplayTools/arena_3d_viewer.html` — Pattern loading, playback, FOV
- `webDisplayTools/CLAUDE.md` — Testing docs, close session protocol

**Testing**:
- Tested G6 GS16 pattern (17 frames) — loads and plays correctly
- FOV presets work as expected
- Verified with Claude Chrome extension (screenshots, JS execution)

---

## 2026-01-29 (Night): UI Layout Refinements for Stackable Apps

**Focus**: Make PatternGeneratorApp and PatternCombinerApp shorter so they can be stacked vertically

**Completed**:

1. **PatternGeneratorApp Layout Overhaul**:
   - Moved 3 buttons to span full window width (below both Parameters and Options panels)
   - Buttons now equal-width: "Generate & Preview", "Save...", "Export Script..."
   - Added status line at the very bottom (moved from window title)
   - Changed MainGrid from `[1 2]` to `[3 2]` (panels row, buttons row, status row)
   - Default height: 604px

2. **PatternCombinerApp Compaction**:
   - Aligned "Sequential / Mask / Left/Right" radio buttons with "Replace / 50% Blend" row
   - Removed spacer row from action buttons, reduced row heights to {28, 28, 28, 28}
   - All 4 action buttons now visible without cutoff (Swap, Reset, Combine & Preview, Save)
   - Reduced MainGrid row heights: {55, 170, 140, 30, 25} (was {80, 210, 140, 30, 25})
   - Default height: 464px

3. **Focus Management**:
   - `bringAllPatternAppsToFront()` reverted to exact name matching (status no longer in window title)
   - All three apps (Generator, Combiner, Previewer) updated consistently

4. **Validation**: All 6 pattern save/load tests pass

**Files Modified**:
- `patternTools/PatternGeneratorApp.m` — Full-width buttons, status line, height 604
- `patternTools/PatternCombinerApp.m` — Compact layout, height 464
- `patternTools/PatternPreviewerApp.m` — Focus management consistency

---

## 2026-01-29 (Late PM): PatternGeneratorApp Separation Complete

**Focus**: Separate Pattern Generator from embedded preview, create focused generation-only app

**Completed**:

1. **New PatternGeneratorApp.m** (~1,000 lines vs ~2,400 original):
   - Clean rebuild focused on pattern creation only
   - Compact single-column layout (380×700 px)
   - "Generate & Preview" button sends pattern to PatternPreviewerApp
   - Positions side-by-side with Previewer (Generator left, Previewer right)
   - All generation parameters preserved: pattern types, motion, brightness, masks, starfield options
   - Arena config locking after generation (prevents mismatch)

2. **Inter-App Communication**:
   - Uses same API as PatternCombinerApp: `loadPatternFromApp(Pats, stretch, gs_val, name, arenaConfig, true)`
   - Finds/reuses existing Previewer window
   - Positions Previewer adjacent to Generator automatically

3. **Archived Original**:
   - `PatternGeneratorApp_v0.m` — Original version with embedded preview preserved for reference

4. **Fixed Pattern_Generator call**:
   - Corrected function signature: `[Pats, ~, ~] = Pattern_Generator(handles)` (was incorrectly using extra args)

5. **All validation tests passing**: 6/6 pattern save/load

**Files Created/Modified**:
- `patternTools/PatternGeneratorApp.m` — NEW: Focused generator (~1,000 lines)
- `patternTools/PatternGeneratorApp_v0.m` — RENAMED: Original with embedded preview
- `CLAUDE.md` — Updated Current Apps table

**Architecture Achievement**:
Future Vision goal complete — Now have 3 of 4 specialized windows:
- ✅ PatternPreviewerApp (central hub)
- ✅ PatternGeneratorApp (focused generation)
- ✅ PatternCombinerApp (pattern combination)
- 🔄 Drawing App (planned)

---

## 2026-01-29 (PM): PatternCombinerApp Refinements + PatternPreviewerApp Fixes

**Focus**: Bug fixes and UI improvements based on user testing

**Completed**:

1. **PatternCombinerApp UI Redesign**:
   - Window size increased from 620×520 to 660×640 to show all buttons
   - Three aligned info panels at bottom: "Pattern 1 Info", "Combined Pattern Info", "Pattern 2 Info"
   - Pattern names displayed in bold as first line in each info panel
   - All action buttons now visible: Swap, Reset, Combine, Preview, Save
   - Added editable "Save as:" field at bottom for custom output names

2. **Dynamic File Naming**:
   - Names now update when changing options (threshold, split position, binary op, mask mode)
   - Added callbacks to ThresholdSpinner, BinaryOpDropDown, SplitSlider, MaskModeGroup
   - Naming conventions:
     - Sequential: `{Pat1}_then_{Pat2}`
     - Mask (Replace): `{Pat1}_mask{threshold}_{Pat2}`
     - Mask (Blend): `{Pat1}_blend_{Pat2}`
     - Binary: `{Pat1}_{OR|AND|XOR}_{Pat2}`
     - Left/Right: `{Pat1}_LR{splitCol}_{Pat2}`
   - Tracks `LastSuggestedName` to preserve user edits while allowing auto-updates

3. **PatternPreviewerApp Fixes**:
   - **Frame slider initialization**: Added `drawnow` before/after `setupFrameSlider()` to fix compressed tick marks on first in-memory pattern load
   - **Projection views for in-memory patterns**: Added `generateArenaCoordinatesFromConfig()` method that generates arena coordinates directly from config struct (not just file path)
   - **Generation display**: Format field now shows "G6 (in memory)" instead of just "(in memory)" when arena config is available
   - **Window reuse**: PatternCombinerApp now finds and reuses existing PatternPreviewerApp window instead of opening multiples

4. **All validation tests still passing**: 6/6 pattern save/load, 12/12 pattern combiner

**Files Modified**:
- `patternTools/PatternCombinerApp.m` — UI resize, naming callbacks, LastSuggestedName tracking
- `patternTools/PatternPreviewerApp.m` — Slider fix, projection views fix, generation display, window reuse support

**Next Session Suggestion** (discussed with user):
- **Separate Pattern Generator from Previewer** — The Previewer is now a robust standalone app. Consider doing a clean rebuild of the Generator as a focused tool that sends patterns to Previewer, rather than removing functionality piece by piece from the current combined app. This would complete the Future Vision architecture (4 specialized windows).

---

## 2026-01-29: PatternCombinerApp Implementation

**Focus**: Implement the Pattern Combiner app from the Future Vision roadmap

**Completed**:
1. **PatternCombinerApp.m** — New App Designer GUI (620×520 px, 3-column layout)
   - Three combination modes (radio buttons): Sequential, Mask, Left/Right
   - Pattern 1 selection via file dialog, sets arena config
   - Pattern 2 dropdown populated with compatible patterns (same directory, same GS level)
   - Swap button to exchange Pattern 1 ↔ Pattern 2
   - Combine, Preview, Save buttons
   - Combined pattern info display (size, frames, name)

2. **Combination Modes**:
   - **Sequential**: Concatenate frames (Pattern 1 then Pattern 2)
   - **Mask (GS16)**: Replace at threshold value OR 50% blend with rounding
   - **Mask (Binary)**: OR, AND, XOR operations
   - **Left/Right**: Configurable split point slider (0 to total_cols-1)

3. **Frame Handling**:
   - Sequential: Different frame counts allowed (concatenates)
   - Spatial modes: Frame count mismatch triggers truncation dialog
   - Stretch value mismatch triggers dialog (concatenate as-is OR uniform value)

4. **PatternPreviewerApp Updates**:
   - Added `isUnsaved` parameter to `loadPatternFromApp()` API
   - Red "UNSAVED" warning label appears in top-right when pattern is unsaved
   - Enabled Pattern Combiner menu item (Tools > Pattern Combiner)

5. **Validation Script**: `tests/validate_pattern_combiner.m`
   - 12 tests covering all combination modes
   - Tests: sequential (equal/different frames), mask (replace/blend/rounding/clamping), left/right (symmetric/asymmetric), binary ops (OR/AND/XOR), frame truncation

**Output Naming Convention**:
- Sequential: `{Pat1}_then_{Pat2}`
- Spatial: `{Pat1}_plus_{Pat2}`
- Swap-aware (updates names when swapped)

**Files Created**:
- `patternTools/PatternCombinerApp.m` — Main app (~1100 lines)
- `tests/validate_pattern_combiner.m` — Validation script (12 tests, all pass)

**Files Modified**:
- `patternTools/PatternPreviewerApp.m` — Added unsaved warning, enabled menu, updated API
- `docs/G4G6_ROADMAP.md` — Updated Future Vision status, added session notes

---

## 2026-01-27: PatternGeneratorApp Refinements + Partial Arena Issue

**Focus**: Bug fixes, UI improvements, and discovery of arena config schema limitation

**Completed**:
1. **Info Dialog** — Changed from modal to non-modal so users can reference while using main GUI
2. **Mask Mutual Exclusion** — Removed; both SA and Lat/Long masks can now be used together (applied sequentially by Pattern_Generator.m)
3. **Partial Arena Rendering** — Fixed `Pcols`/`Pcircle` parameters in `generateArenaMatFile()`:
   - `Pcols` = number of installed columns (from `panels_installed` length)
   - `Pcircle` = full circle column count (`num_cols`)
   - Now matches G4 Pattern Generator behavior
4. **View Labels**:
   - Grid view: "Pixel Column" / "Pixel Row", Y-axis flipped so row 0 at bottom
   - Mercator: "Longitude (deg)" / "Latitude (deg)"
   - Mollweide: "Longitude (deg)" / "Latitude (deg)"
5. **FOV Reset** — Now always resets to ±180° lon, ±90° lat (full view)
6. **Mollweide Zoom** — Fixed zoom/reset buttons to work with Mollweide projection
7. **Data Tips** — Re-enabled for pattern inspection
8. **Arena Info Display** — Fixed for partial arenas:
   - Shows installed panel count (not grid total)
   - Shows actual pixel dimensions (installed columns × pixels_per_panel)
   - Shows azimuth coverage AND deg/px for partial arenas

**Issue Discovered — Arena Config Schema**:
The `panels_installed` field is used inconsistently:
- `G6_3x18_partial.yaml`: column indices `[0,1,2,...,11]` (12 columns)
- `G6_2x8_walking.yaml`: panel indices `[1,2,...,8,11,...,18]` (16 panels)

**Recommendation**: Extend schema with separate `columns_installed` and `panels_installed` fields. Added to In-Flight Work section.

**Files Modified**:
- `patternGenerator/PatternGeneratorApp.m` — Multiple fixes
- `docs/G4G6_ROADMAP.md` — Added In-Flight Work item #6

---

## 2026-01-26 (PM): Roadmap Comprehensive Update

**Focus**: Document in-flight work, decisions, and why PatternGeneratorApp

**Added**:
1. **In-Flight Work section** — 7 items with detailed "To Pick Up" instructions:
   - TCP Migration Testing (needs lab time)
   - Experiment Workflow / Lisa's Code (PR open)
   - Cross-Platform SD Card Copying (new consideration)
   - PatternGeneratorApp Missing Features (feature list)
   - Branch Reconciliation (merge strategy)
   - Web Tools Landing Page (status update)
   - Pattern Validation / Regression Testing (planned)

2. **"Why PatternGeneratorApp" section** — Documents why we created new App Designer GUI instead of updating G4 GUIDE GUI:
   - GUIDE `.fig` files have hardcoded callbacks
   - Can't programmatically rename callbacks
   - GUIDE is deprecated
   - App Designer advantages (single file, modern, maintainable)

**Updated**:
- Sprint 2 status → marked P1 (Arena Config) and P3 (Pattern Editor core) complete
- Sprint 3 dates → Feb 2-5 (was Feb 3-7)
- Sprint 3 P2 (TCP) → notes "requires lab time"
- Backlog → marked completed items, added new items (cross-platform SD, GitHub for experiments)
- Branch reconciliation → added merge strategy (PRs through Lisa/Frank for their code)

**Decisions Documented**:
- Arena config in experiments: "Document as question for later" (open question)
- TCP migration: Wait for Sprint 3 (needs lab time)
- Cross-platform workflow: Develop on Mac, run on Windows. GitHub for experiment org worth considering.
- PatternGeneratorApp features: Will need all features, go through 1-by-1
- Merge strategy: One big merge to main, PRs through owners for their code

---

## 2026-01-26: PatternGeneratorApp Created

**Focus**: New App Designer GUI for multi-generation pattern creation

**Completed**:
1. **PatternGeneratorApp.m** — Modern App Designer replacement for G4_Pattern_Generator_gui
   - Multi-generation support (G3, G4, G4.1, G6) via arena config dropdown
   - Pattern types: Square grating, sine grating, edge, starfield, off-on
   - Motion types: Rotation, translation, expansion-contraction
   - Grayscale modes: Binary (1-bit) and grayscale (4-bit)
   - Real-time preview with LED-accurate green phosphor colormap (568nm peak)
   - Playback controls: Play/Stop button with FPS dropdown (1/5/10/20)
   - Arena info display: panels, pixels, deg/px horizontal (3 decimal places)
   - Step size shows pixel equivalent, spinner step = half deg/pixel
   - Default arena config: G41_2x12_ccw
   - Window size: 1350×600 pixels

2. **get_generation_specs.m** — Single source of truth for panel specs
   - Moved from hardcoded values in multiple files
   - Used by load_arena_config.m, load_rig_config.m, design_arena.m

3. **Documentation updates**
   - Updated README.md with PatternGeneratorApp documentation
   - Updated g4_pattern_editor_assessment.md with feature inventory

**Key Design Decisions**:
- Used App Designer instead of GUIDE for modern UI and better maintainability
- Integrated with existing YAML arena configs (no separate config system)
- LED colormap uses phosphor green (RGB [0.6, 1.0, 0.2] at peak)
- Step size initialized to 1 pixel (deg/pixel value)

**Files Created/Modified**:
- `patternGenerator/PatternGeneratorApp.m` — NEW: ~580 lines App Designer GUI
- `utils/get_generation_specs.m` — NEW: panel specs single source of truth
- `README.md` — Updated with comprehensive documentation
- `docs/G4G6_ROADMAP.md` — Updated with progress

**Next Steps**:
1. Compare PatternGeneratorApp to G4_Pattern_Generator_gui.m features
2. Add missing pattern parameter controls (starfield options, mask settings, etc.)
3. Review rendering options (pixel vs pattern visualization modes)
4. Add export options (GIF, stim icons) or punt to webDisplayTools

---

## 2026-01-24 (PM): Web Tools UI Redesign + Arena Config System

**Focus**: Arena configs as single source of truth for web tools

**Completed**:
1. **YAML Config System** (maDisplayTools):
   - Created `configs/arenas/` with 9 standard arena configs (G6_2x10_full, G6_2x8_walking, G41_2x12_ccw, G41_2x12_cw, G4_3x12_full, G4_4x12_full, G4_3x18_partial, G3_4x12_full, G3_3x24_full)
   - Created `configs/rigs/` with rig configs that reference arena YAMLs
   - Created MATLAB load functions: `load_arena_config.m`, `load_rig_config.m`, `load_experiment_config.m`
   - Updated `design_arena.m` with `column_order` field

2. **CI/CD Config Sync** (webDisplayTools):
   - Created `scripts/generate-arena-configs.js` — Node.js script to parse YAML and generate JS
   - Created `.github/workflows/sync-arena-configs.yml` — Weekly sync + manual trigger
   - Generated `js/arena-configs.js` with STANDARD_CONFIGS and PANEL_SPECS

3. **Arena Editor Redesign** (`arena_editor.html`):
   - **View mode** (default): Dropdown to select from 9 configs, read-only properties
   - **Create mode**: "+ Create New Arena" or "Clone as New" to edit
   - Single toggle button for column numbers (near SVG)
   - Exports YAML configs, "View in 3D" passes `?config=NAME`

4. **3D Viewer Redesign** (`arena_3d_viewer.html`):
   - Removed generation tabs and row controls
   - Added config dropdown and "Load from File" button
   - URL params: `?config=G6_2x10_full` (new) or legacy `?gen=G6&cols=10...`
   - Fixed label positioning: panel labels on back, column labels on ground
   - Updated LED specs with accurate dimensions:
     - G3: 3mm diameter round (4mm pitch)
     - G4: 1.9mm diameter round
     - G4.1: 0603 SMD (1.6mm × 0.8mm) at 45°
     - G6: 0402 SMD (1.0mm × 0.5mm) at 45°

**Files Created/Modified**:
- `maDisplayTools/configs/arenas/*.yaml` — 9 arena configs
- `maDisplayTools/configs/rigs/*.yaml` — Rig configs
- `maDisplayTools/utils/load_arena_config.m`, `load_rig_config.m`, etc.
- `webDisplayTools/scripts/generate-arena-configs.js`
- `webDisplayTools/.github/workflows/sync-arena-configs.yml`
- `webDisplayTools/js/arena-configs.js` (generated)
- `webDisplayTools/arena_editor.html` — Major rewrite
- `webDisplayTools/arena_3d_viewer.html` — Major rewrite

**Remaining Work** (future session):
- Test all 9 configs in both web tools
- Test "Load from File" with YAML files
- Test "Create New Arena" workflow end-to-end
- Update webDisplayTools landing page
- Consider: Add `description` field to STANDARD_CONFIGS for better dropdown labels

**Versions Verified**:
- Node.js: v24.12.0 (current LTS)
- Three.js: 0.182.0 (latest as of Jan 2026)

---

## 2026-01-24: TCP Migration Testing + Experiment Workflow Fixes

**TCP Migration** (branch: `claude/switchable-tcp-controller-qQRKM`):
- Created PanelsControllerNative.m using MATLAB tcpclient
- Both backends (pnet and tcpclient) work and perform comparably
- Key limitations discovered:
  - Only 4 G4.1 commands work: allOn, allOff, stopDisplay, streamFrame
  - Need 50ms delay between commands for reliability
  - Controller locks up if streaming frames >10 FPS
  - sendDisplayReset, resetCounter NOT G4.1 commands
- Test files created/updated:
  - tests/simple_comparison.m — primary test, 100% reliable
  - tests/test_command_verification.m — G4.1 commands only
  - tests/benchmark_timing.m, test_reliability.m — updated
  - tests/benchmark_streaming.m — limited to 5-10 FPS

**Experiment Workflow** (branch: `claude/bugfix-trialparams-executor-80r3o`):
- Extensive testing with Lisa
- Fixed CommandExecutor trial execution (trialParams())
- Fixed ProtocolRunner OutputDir parameter
- Added ScriptPlugin.close() method
- Updated deploy_experiments_to_sd.m to format SD each time
- Created docs/experiment_pipeline_guide.md (comprehensive guide)
- PR opened for review

**Next Steps**:
- Merge experiment workflow PR after review
- More careful TCP testing to understand FPS limitations
- **Large pattern / Mode 3 reliability testing**:
  - Test streamFrame with full-size patterns (2x12, 4-row arenas)
  - Verify Mode 3 (single frame streaming) stability for pre-rendered playback
  - Determine maximum reliable FPS for different pattern sizes
  - Document any size/rate limitations for Peter/Frank
- Report streaming issues to Peter/Frank
- Begin arena config implementation

---

## 2026-01-23: G6 Panel Editor CI/CD Complete 🎉
**Participants**: Michael, Claude

**Completed**:
- G6 panel editor updated to use simplified row-major encoding (matching MATLAB)
- Removed LED_MAP lookup table from g6_panel_editor.html
- Created shared encoding module (`js/g6-encoding.js`) for Node.js + browser
- MATLAB reference data generator (`g6/generate_g6_encoding_reference.m`)
- CI/CD validation workflow with 25 tests (all passing)

**Encoding Convention** (now consistent across MATLAB and JavaScript):
- Origin (0,0) at bottom-left of panel
- Row-major ordering: `pixel_num = row_from_bottom * 20 + col`
- GS2: MSB-first, 50 bytes total
- GS16: high nibble = even pixel, 200 bytes total

**Files Created/Updated**:
- `maDisplayTools/g6/generate_g6_encoding_reference.m` — generates validation JSON
- `maDisplayTools/g6/g6_encoding_reference.json` — reference data (8 test vectors, 14 patterns)
- `webDisplayTools/g6_panel_editor.html` — v7, row-major encoding
- `webDisplayTools/js/g6-encoding.js` — shared encoding module
- `webDisplayTools/data/g6_encoding_reference.json` — copy of reference data
- `webDisplayTools/tests/validate-g6-encoding.js` — 25 validation tests
- `webDisplayTools/.github/workflows/validate-g6-encoding.yml` — CI/CD workflow

**Key Technical Note**:
MATLAB stores pixel_matrix in display order (row 0 = top of visual), while panel coordinates use row 0 = bottom. Test script flips rows when comparing: `pixelMatrix = matlabMatrix.slice().reverse()`

---

## 2026-01-21: Tuesday Lab Session — SUCCESS! 🎉
**Participants**: Michael (lab), Claude (remote assist)

**Completed**:
- Full SD card workflow validation
- Root cause of WSACONNRESET identified (unparseable files on FAT32)
- `prepare_sd_card.m` enhanced with Format/UsePatternFolder/ValidateDriveName options
- 100 two-digit test patterns generated and tested
- Frank/Peter's controller update tested — indexing correct
- All 3 isolation steps passed

**Key Findings**:
1. Controller uses FAT32 dirIndex (write order), not filenames
2. MANIFEST files must be written AFTER patterns
3. FAT32 delete doesn't clear directory entries — format required for clean slate
4. Pattern naming now lowercase: `pat0001.pat`

**Files Created/Updated**:
- `utils/prepare_sd_card.m` — unified version with all options
- `examples/create_test_patterns_100.m` — generates 00-99 patterns
- `examples/test_sd_card_copy_100.m` — copies 100 patterns in order
- `docs/todo_lab_tuesday.md` — updated with completion status

**Next Session (Thursday)**:
- TCP migration testing (priority)
- G3 PControl code review & feature list
- Experiment workflow integration (awaiting Lisa)

---

## 2026-01-18: Initial Planning Session
**Participants**: Michael, Claude

**Reviewed**:
- All existing docs in `maDisplayTools/docs/`
- `webDisplayTools` structure and CLAUDE.md
- G4_Display_Tools/G4_Pattern_Generator for reference
- G6 Protocol spec (Google Doc)
- External interactions doc (camera, LED, temperature)

**Key Decisions**:
1. Arena config will be JSON, shared between MATLAB and web tools
2. Pattern editor: update GUIDE first, web version parallel track
3. G5 deprecated — won't be supported
4. Camera work deferred — out of scope for this roadmap
5. Tuesday lab session priority: SD card playback validation

**G3 PControl Architecture Notes** (for reference):
- `PControl.m` + `PControl.fig` — Main GUIDE-based GUI with X/Y gain/offset sliders, mode selection, position controls
- `Panel_com.m` — Serial communication layer (switch/case command dispatcher)
- `PControl_init.m` — State initialization (gain/offset ranges, positions, modes)
- `Pattern_Player.m` + `.fig` — Simpler GUI for pattern preview with X/Y position stepping
- Key GUI elements: gain sliders (±10), offset sliders (±5V), X/Y mode menus (open/closed loop), position +/- buttons, START/STOP button
- State stored in `handles.PC` struct and `SD.mat` (pattern metadata from SD card)
- G4.1 version needs: Replace serial→TCP, update `Panel_com`→`PanelsController`, add generation selection

**Documents Created**:
- `G4G6_ROADMAP.md` (this file)
- `arena_config_spec.md`
- `pattern_testing/README.md`

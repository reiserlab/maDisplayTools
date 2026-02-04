# G4/G6 Display Tools Roadmap

> **Living Document** — Update this file every few days as work progresses and priorities shift.
>
> **Last Updated**: 2026-02-04
> **Next Review**: ~2026-02-07
>
> **TODO**: Consider compressing this roadmap — move completed sprints to archive, consolidate in-flight items, streamline for active development focus.

---

## Quick Reference

| Repository | Purpose | Visibility |
|------------|---------|------------|
| `maDisplayTools` | MATLAB tools, controller code, private patterns | Private |
| `webDisplayTools` | Web-based editors, public tools | Public |
| `G4_Display_Tools` | Legacy G4 code (reference only) | Public |

**Cross-repo Project Board**: [G4.1 & G6 project planning](https://github.com/users/floesche/projects/6) (maintained by floesche)

**GitHub Pages**: https://reiserlab.github.io/webDisplayTools/

---

## Active Development Branches

| Branch | Purpose | Status | Notes |
|--------|---------|--------|-------|
| `feature/g6-tools` | Main dev branch, G6 tools, roadmap | Active | Primary development |
| `claude/switchable-tcp-controller-qQRKM` | TCP migration testing (pnet vs tcpclient) | Testing | PanelsControllerNative.m + test suite |
| `claude/bugfix-trialparams-executor-80r3o` | YAML experiment workflow fixes | PR open | Fixes for CommandExecutor, ProtocolRunner, ScriptPlugin |
| `yamlSystem` | Lisa's YAML experiment system | Active | Base branch for experiment workflow |
| `g41-controller-update` | Earlier G4.1 work, arena design | Stable | Has design_arena.m, docs, LEDController |
| `pcontrol` | PControl GUI work | TBD | Not yet started |

**Branch workflow**: Feature branches → PR → merge to `main`

---

## Completed Work (Jan 15-21)

### ✅ Web Tools Repository Setup
- Created `webDisplayTools` as separate public repository
- Flat directory structure with single HTML files
- Modern dark theme with green accents (#00e676)
- Reiser Lab branding and GitHub links
- JetBrains Mono / IBM Plex Mono fonts

### ✅ G6 Panel Pattern Editor (Single Panel)
- `g6_panel_editor.html` — fully functional
- 20×20 pixel pattern editing
- Multiple modes: GS2, GS16, 4-Char, LED Map Reference
- Real-time preview and pattern export
- Version 7 (updated with MATLAB-compatible encoding)
- CI/CD validation workflow complete (MATLAB reference data → web validation)

### ✅ Arena Layout Editor (Web)
- `arena_editor.html` — fully functional
- SVG-based visualization matching MATLAB exactly
- Panel generation tabs (G3, G4, G4.1, G5, G6, Custom)
- Click-to-toggle panels for partial arena designs
- Units toggle (inches/mm)
- Export PDF and JSON with full geometry
- Default: G6 with 10 panels

### ✅ Arena Layout (MATLAB)
- `utils/design_arena.m` — consolidated from legacy scripts
- Supports G3, G4, G4.1, G5, G6 generations
- Configurable panels (4-36), partial arena support
- PDF export, returns computed geometry
- Key formula: `c_radius = panel_width / (tan(alpha/2)) / 2`

### ✅ CI/CD Validation Framework
- MATLAB generates `reference_data.json`
- `js/arena-calculations.js` — standalone calculation module
- `tests/validate-arena-calculations.js` — Node.js test runner
- `.github/workflows/validate-calculations.yml` — GitHub Actions
- All 11 test configurations pass validation
- Pattern: MATLAB → JSON → Web validates against it

### ✅ 3D Arena Viewer
- `arena_3d_viewer.html` — Three.js visualization
- Links from Arena Editor with URL parameters
- Pattern presets (all-on, grating, sine)
- Auto-rotate animation
- Screenshot export with stats overlay

### ✅ SD Card Deployment — FULLY TESTED (Jan 21)
- `utils/prepare_sd_card.m` — stages patterns for SD card
  - `'Format', true` — formats SD card for clean FAT32 state (recommended)
  - `'UsePatternFolder', true/false` — patterns in /patterns or root
  - `'ValidateDriveName', true` — requires SD card named PATSD
- Renames to pat0001.pat, pat0002.pat, etc. (lowercase)
- Creates MANIFEST.bin (for microcontroller) and MANIFEST.txt (human-readable)
- Saves local log to `logs/`
- **Tested with 100 patterns end-to-end on hardware!**
- Frank/Peter's controller update — pattern indexing correct

**Root cause of WSACONNRESET errors identified:**
- Controller encountering unexpected files it couldn't parse
- FAT32 delete doesn't clear directory entries — controller saw "ghost" files
- Fix: Format SD card to fully clear FAT32 directory table

**Note on multiple protocols:**
Current implementation intentionally avoids deduplication. If an experiment uses multiple protocols referencing the same pattern, that pattern appears multiple times with different unique IDs. Simple approach that provides straightforward path to supporting multiple protocols per experiment.

### ✅ Test Pattern Generation
- `examples/create_test_patterns.m` — 20 patterns (digits 0-9 + gratings)
- `examples/create_test_patterns_100.m` — 100 two-digit patterns (00-99)
- `examples/test_sd_card_copy.m` — copies test patterns to SD
- `examples/test_sd_card_copy_100.m` — copies 100 patterns in numeric order

### ✅ Documentation
- `sd_card_deployment_notes.md` — usage guide
- `tcp_migration_plan.md` — pnet → tcpclient migration
- `todo_lab_tuesday.md` — hardware debugging checklist (completed!)
- `CLAUDE.md` in webDisplayTools — AI assistant guidelines

### ✅ PatternPreviewerApp Histogram & Utilities (Jan 30)
- Graphical histogram with color-coded horizontal bars (black→green gradient)
- Log/Linear scale toggle for sparse pattern visualization
- Enable checkbox to disable histogram during playback (clears display when disabled)
- Performance optimization: persistent graphics objects (no create/destroy per frame)
- UI controls locked during playback to prevent race conditions
- New utilities: `open_pattern_apps()`, `save_pattern_app_layout()`, `close_pattern_apps()`
- FPS options: 1, 5, 10, 20, 30 (removed 60)
- Bug fix: histogram bars not rendering (was using `XData` instead of `YData` for `barh`)

### ✅ Pattern Tools Quick Start Guide (Jan 30)
- Created `docs/pattern_tools_quickstart.md` for new lab members
- Annotated screenshots for PatternGeneratorApp, PatternPreviewerApp, PatternCombinerApp
- Documents arena configs, pattern organization convention, typical workflows
- Includes app launcher utilities, troubleshooting tips, link to G4 documentation
- GitHub issues link for reporting problems

### ✅ G6 Pattern Tools & CI/CD (Jan 23-24)
- Created `g6/` directory with pattern encoding tools
  - `g6_save_pattern.m` — user-facing pattern creation
  - `g6_encode_panel.m` — internal 20×20 panel encoding (GS2/GS16)
  - `generate_g6_encoding_reference.m` — reference data generator
  - `test_g6_encoding.m` — encoding validation script
- Agreed encoding convention with Will: row-major order, (0,0) at bottom-left
- CI/CD validation workflow:
  - MATLAB generates `g6_encoding_reference.json`
  - webDisplayTools: `js/g6-encoding.js` (shared module)
  - webDisplayTools: `tests/validate-g6-encoding.js`
  - GitHub Actions workflow for automated testing
- Documentation: `g6_quickstart.md`, `g6_migration_plan.md`

---

## Sprint 1 (Jan 21-24) — COMPLETED

### [P0] TCP Migration Testing ✅ PARTIAL
- [x] Created parallel implementations on `claude/switchable-tcp-controller-qQRKM`
  - PanelsController.m (pnet) - unchanged
  - PanelsControllerNative.m (tcpclient) - new
- [x] Basic benchmarks run on hardware
- [x] Performance comparable between backends
- [x] Test suite updated for G4.1 commands only (allOn, allOff, stopDisplay, streamFrame)
- [x] 50ms delay between commands for reliability
- ⚠️ Controller locks up at streaming >10 FPS — need feedback to Peter/Frank
- 🔄 More careful testing needed with updated procedures

### [P1] G3 PControl Code Review — NOT STARTED
- Deferred to later sprint
- `pcontrol` branch exists but empty

### [P2] Experiment Workflow Integration ✅ COMPLETE
- [x] Extensive testing with Lisa (Jan 24)
- [x] Fixed multiple bugs:
  - CommandExecutor: switched to trialParams() for trial execution
  - ProtocolRunner: fixed OutputDir parameter being ignored
  - ScriptPlugin: added missing close() method
  - deploy_experiments_to_sd.m: now formats SD card each time
- [x] Created comprehensive `docs/experiment_pipeline_guide.md`
- [x] PR open: `claude/bugfix-trialparams-executor-80r3o`

### [P3] G6 Panel Editor CI/CD ✅ COMPLETE
- Already marked complete — see Completed Work section

### [P4] G6 Pattern Tools Migration ✅ COMPLETE
- [x] Created `g6/` directory with pattern tools
- [x] Agreed encoding convention with Will: row-major, (0,0) bottom-left
- [x] CI/CD validation infrastructure in place
- [x] Documentation: `g6_quickstart.md`, `g6_migration_plan.md`

### Tuesday Lab Session (Jan 21) — ALL PASSED ✅
- [x] Resolved `WSACONNRESET` errors (root cause: unparseable files on SD)
- [x] Tested SD card deployment with known-good patterns
- [x] Validated `prepare_sd_card.m` end-to-end
- [x] Tested with Frank/Peter's controller update
- [x] Generated and tested 100 patterns successfully

---

## Current Focus (Sprint 2: Jan 27-31) — WRAPPING UP

### 🎯 Primary Goal: Arena Config & Web Tools Update

### Tasks

- [x] **[P1] Arena Config Implementation** ✅ COMPLETE
  - [x] Draft JSON schema (see `arena_config_spec.md` on g41-controller-update) ✅
  - [x] Switched to YAML for arena/rig/experiment configs ✅
  - [x] Created `configs/arenas/` with 10 standard arena configs ✅
  - [x] Created `configs/rigs/` with rig configs (reference arena YAML) ✅
  - [x] Implement MATLAB `load_arena_config.m`, `load_rig_config.m`, etc. ✅
  - [x] Update `design_arena.m` with column_order field ✅
  - [x] Web arena editor redesigned with view/create modes ✅
  - [x] Web 3D viewer redesigned with config dropdown ✅
  - [x] CI/CD workflow to sync configs from maDisplayTools to webDisplayTools ✅
  - ~[ ] **Audit maDisplayTools** for arena-specific details~ → Deferred (arena config propagation is in-flight work below)
  - [x] **Audit G4 pattern editor** to map how it can use new arena config ✅ → Done via PatternGeneratorApp
  - [x] Remove G5 from valid arena designs ✅ (errors in load_arena_config.m, get_generation_specs.m, ProtocolParser.m; no G5 tab in web tools)

- [x] **[P2] Update webDisplayTools** ✅ COMPLETE
  - [x] Arena editor: Dropdown for 9 standard configs, view/create modes ✅
  - [x] 3D viewer: Dropdown for configs, removed manual gen/row controls ✅
  - [x] CI/CD workflow: Auto-sync arena configs from maDisplayTools ✅
  - [x] Updated LED specs with accurate dimensions (G3: 3mm round, G4: 1.9mm round, G4.1: 0603 SMD, G6: 0402 SMD) ✅
  - [x] Update landing page to reflect current status ✅
  - [x] Update tool descriptions and status badges ✅
  - [x] Add links to documentation / roadmap ✅
  - [x] Clarify which tools are complete vs placeholder ✅

- [x] **[P3] Pattern Editor Assessment & Implementation** ✅ COMPLETE (core)
  - [x] Inventory G4_Pattern_Generator_gui.m features (see `docs/g4_pattern_editor_assessment.md`)
  - [x] Identify generation-specific vs universal features
  - [x] Plan update strategy for multi-generation support (see plan file)
  - [x] Created `PatternGeneratorApp.m` — new App Designer GUI
  - [x] Implemented multi-generation support (G3, G4, G4.1, G6)
  - [x] Integrated arena YAML configs via dropdown
  - [x] Added LED-accurate preview with green phosphor colormap
  - [x] Added playback controls (Play/Stop, FPS selection)
  - [x] Added arena info display (panels, pixels, deg/px horizontal)
  - Remaining feature parity work moved to Sprint 3

- [ ] **[P4] Branch Reconciliation** (after P1 arena work complete)
  - **Goal**: Get complete, tested items that don't require substantial further work onto `main` and close branches
  - **Strategy**: Merge everything to main in one go that doesn't impact others' work
    - Anything touching Lisa's code → PR through Lisa
    - Anything touching PanelController → PR through Frank
  - [ ] Merge consolidated arena work to main
  - [ ] Port remaining g41-controller-update items (LEDController, docs, test patterns) to main
  - [ ] Reconcile with Lisa's experiment execution system (already in main)
  - [ ] Close stale branches (g41-controller-update, old claude/ branches)

### Deferred to Later
- G4.1 Control GUI Development — wait until arena config and pattern editor work is more mature

### Done Criteria
- [x] Arena config YAML loading/saving works in MATLAB and web ✅
- [x] webDisplayTools landing page accurately reflects project status ✅
- [x] Pattern editor requirements documented ✅
- [x] PatternGeneratorApp functional with multi-generation support ✅

---

## Sprint 3 (Feb 2-5)

### 🎯 Primary Goal: PatternGeneratorApp Feature Parity + TCP Migration Testing

### Tasks

- [x] **[P1] Complete PatternGeneratorApp Feature Parity** ✅ COMPLETE
  - [x] Add generation selector (G3, G4, G4.1, G6) — skip G5 ✅
  - [x] Update pixel grid sizes (8×8, 16×16, 20×20) ✅
  - [x] Integrate arena config loading ✅
  - [x] Add missing features from G4 GUI ✅ (Jan 26 evening):
    - [x] Duty cycle spinner (1-99%)
    - [x] Brightness levels (high/low/background, auto-adjust for 1-bit/4-bit)
    - [x] Pattern FOV (full-field / local)
    - [x] Motion angle (0-360°)
    - [x] Pole coordinates (azimuth 0-360°, elevation -90 to 90°)
    - [x] Arena pitch (-90 to 90°)
    - [x] Solid angle mask (checkbox + configure dialog)
    - [x] Lat/long mask (checkbox + configure dialog)
    - [x] Starfield options panel (conditional, with all 6 parameters)
  - [x] Regression tests pass against G4 baseline patterns ✅
  - [x] .pat binary export ✅
  - [x] Mercator view ✅
  - GIF export → moved to Future Vision (Pattern Previewer)

- [ ] **[P2] TCP Migration Testing** (requires lab time)
  - [ ] Investigate controller lockup at >10 FPS streaming
  - [ ] **Large pattern stress testing** — "large" means many frames (not varying arena size)
  - [ ] **Mode 3 reliability testing** — pre-rendered playback streaming stability
  - [ ] Create `tests/benchmark_large_patterns.m`
  - [ ] Document maximum reliable streaming rate
  - [ ] Report findings to Peter/Frank
  - [ ] Decision: merge PanelsControllerNative or keep parallel

- [ ] **[P3] Web Pattern Editor (Multi-Panel)** — if time permits
  - [ ] **Direct port** of updated G4 pattern editor to web
  - [ ] Support G3 (8×8), G4/G4.1 (16×16), G6 (20×20) — skip G5
  - [ ] Maybe add 3D preview integration
  - [ ] Export as GIF files or MPGs
  - [ ] CI/CD validation

### Done Criteria
- [x] MATLAB pattern editor generates valid patterns for G3, G4, G4.1, G6 ✅
- [ ] TCP migration testing complete with documented limits (if lab time available)
- [ ] Web pattern editor functional for multi-panel arena patterns (stretch goal)

---

## Planned Sessions

### Pattern Compatibility Testing Session

**Goal**: Verify end-to-end pattern compatibility between MATLAB and Web tools.

**Test Matrix**:
| Dimension | Values to Test |
|-----------|----------------|
| Generation | G4, G6 |
| Arena Type | Full, Partial |
| Grayscale | GS2 (binary), GS16 (4-bit) |
| Source | Each pattern-generating widget |

**Tests**:
1. **MATLAB → Web**: Patterns made in MATLAB load correctly in web 3D viewer
2. **Web → MATLAB**: Patterns made in web Pattern Editor play correctly in MATLAB PatternPreviewerApp
3. **Round-trip**: Save from one platform, load in other, verify pixel-identical

**Widgets to Test**:
- Pattern Editor (web) — all pattern types (grating, sine, rotation, expansion, translation, starfield, edge)
- PatternGeneratorApp (MATLAB) — same pattern types
- Icon Generator (web) — verify saved patterns
- PatternCombinerApp (MATLAB) — combined patterns

**Success Criteria**: All patterns from the test matrix load and display correctly on both platforms.

---

### Web 3D Viewer Feature Review Session

**Goal**: Review standalone Arena 3D Viewer features and decide which to port to Pattern Editor's 3D view.

**Standalone Viewer Features to Evaluate**:
- Auto-rotate animation
- Screenshot export with stats overlay
- FOV presets (60°, 120°, 170° fly eye)
- Statistics panel (angular resolution, pixel counts)
- Pattern presets dropdown

**New Feature: Mercator Projection View**
- If straightforward to implement, add Mercator projection tab to Pattern Editor
- Alternative 2D view alongside Grid view

---

### Deferred: Observer Perspective Controls

**Status**: 🔴 DEFERRED — Needs design discussion about arena config integration

**Features to Consider (Later)**:
1. **Arena Pitch** — Tilt the arena relative to horizontal (already in PatternGeneratorApp)
2. **Observer Translation** — Move observer position within arena (not just center)
3. **Observer Height** — Vertical position of viewpoint

**Why Deferred**:
- These parameters affect pattern generation, not just visualization
- Need to decide: Are these part of arena config? Pattern metadata? Runtime-only?
- Current arena config schema doesn't include observer position
- Should observer position be saved with patterns or be a preview-only setting?

**To Pick Up Later**:
1. Design discussion: Where do observer parameters live?
2. Update arena config schema if needed
3. Implement in both MATLAB and Web tools consistently

---

## In-Flight Work

These are started projects that need to be picked up and completed. Each section describes current state, what's left, and how to resume.

### 0. Web Tools Update for Arena Config Changes

**Status**: ✅ COMPLETE (Jan 30)

**Changes Made (Jan 28)**:
1. **File renames**: `G6_2x10_full.yaml` → `G6_2x10.yaml`, `G6_2x8_walking.yaml` → `G6_2x8of10.yaml`, etc.
2. **Schema change**: `panels_installed` → `columns_installed`
3. **New naming convention**: Partial arenas use `{rows}x{installed}of{total}` format

**Completed (Jan 30)**:
- [x] CI/CD workflow triggered to sync configs
- [x] `arena_editor.html` updated to use `columns_installed`
- [x] Config dropdown shows new names
- [x] 3D viewer loads renamed configs
- [x] Added `.pat` file loading to 3D viewer (new feature!)
- [x] Updated `CLAUDE.md` with testing documentation

---

### 0a. Web 3D Viewer Pattern Loading

**Status**: ✅ COMPLETE (Jan 30)

**New Feature**: Load `.pat` files directly in the 3D arena viewer.

**Implemented**:
- `js/pat-parser.js` — G6 and G4 pattern file parser
- Pattern loading UI in `arena_3d_viewer.html`
- Multi-frame playback with FPS control (1-30 FPS)
- FOV control with presets (Normal 60°, Wide 120°, Fly Eye 170°)
- `window.testLoadPattern(url)` for automated testing

**Open Issues** (GitHub):
- [#8: UI polish and playback improvements](https://github.com/reiserlab/webDisplayTools/issues/8)
  - Remove "Rotate Pattern" button (redundant)
  - Rename "Pattern" → "Test Patterns"
  - Add negative FPS for CW/CCW playback
  - Lock controls during playback
  - Fix cramped statistics panel
  - Uniform button sizes
- [#9: True fisheye shader for fly eye simulation](https://github.com/reiserlab/webDisplayTools/issues/9)
  - Barrel distortion shader
  - ~270° horizontal × 180° vertical FOV

---

### 1. TCP Migration Testing

**Branch**: `claude/switchable-tcp-controller-qQRKM`

**Status**: Parallel implementations created and basic testing done. More careful testing needed.

**Current State**:
- `PanelsController.m` (pnet) — unchanged, working
- `PanelsControllerNative.m` (tcpclient) — new, basic tests pass
- Both backends perform comparably in benchmarks
- Test suite updated for G4.1 commands only (allOn, allOff, stopDisplay, streamFrame)

**Known Issues**:
- Controller locks up if streaming >10 FPS
- Need 50ms delay between commands for reliability
- `sendDisplayReset`, `resetCounter` are NOT G4.1 commands

**To Pick Up**:
1. Need lab time with hardware to test properly
2. Run `tests/simple_comparison.m` to verify both backends still work
3. Investigate FPS limitation — create `tests/benchmark_large_patterns.m`
4. Document maximum reliable streaming rate
5. Report findings to Peter/Frank
6. Decision: merge PanelsControllerNative or keep as parallel option

**Files to Review**:
- `controller/PanelsControllerNative.m`
- `tests/simple_comparison.m`, `tests/benchmark_streaming.m`
- `docs/tcp_migration_plan.md`

---

### 2. Experiment Workflow / Lisa's Code

**Branch**: `claude/bugfix-trialparams-executor-80r3o` (PR open)

**Status**: Bugs fixed, PR open for review. Arena config propagation needs discussion.

**Current State**:
- Fixed CommandExecutor trial execution (uses `trialParams()`)
- Fixed ProtocolRunner OutputDir parameter
- Added ScriptPlugin.close() method
- Updated `deploy_experiments_to_sd.m` to format SD each time
- Comprehensive guide: `docs/experiment_pipeline_guide.md`

**Open Question** (document for later):
> How should arena config propagate through Lisa's experiment system? What's the tradeoff between:
> - Experiment YAML referencing arena config
> - Arena config embedded in experiment
> - Runtime arena config lookup from rig config
>
> Need to think about this more before deciding.

**To Pick Up**:
1. Get PR merged (needs Lisa's review)
2. Later: Design arena config integration with experiment system

**Files to Review**:
- `docs/experiment_pipeline_guide.md`
- PR changes in `claude/bugfix-trialparams-executor-80r3o`

---

### 3. Cross-Platform SD Card Copying

**Status**: Not started. This is a new consideration.

**Problem**: We develop/test on Mac but always run experiments on Windows. Currently can only prepare SD cards on Windows. Would be nicer to copy files on Mac.

**Considerations**:
- Need to investigate SD card formatting on macOS
- FAT32 directory entry behavior may differ across platforms
- `prepare_sd_card.m` currently uses Windows-specific path handling

**Related Idea**: Consider GitHub for experiment-specific organization
- Would include timestamps
- Pattern library management
- Could enable better versioning of experiments

**To Pick Up**:
1. Research macOS FAT32 formatting tools
2. Test `prepare_sd_card.m` on macOS (may need path handling updates)
3. Consider if git-based experiment organization makes SD copying less critical

---

### 4. Arena Pitch in Pattern Previewer Projections

**Status**: 🔴 DEFERRED — Needs design discussion

**Problem**: Pattern Previewer (PatternPreviewerApp.m) projections ignore arena pitch. When loading patterns for pitched arenas, the Mercator/Mollweide views don't account for the arena tilt.

**Root Cause**: `PatternPreviewerApp.loadArenaConfig()` reads the wrong field name:
```matlab
% Current (wrong):
if isfield(cfg.arena, 'rotations')     % Field doesn't exist
    rotations = cfg.arena.rotations;
end

% Correct (from PatternGeneratorApp):
if isfield(cfg.arena, 'rotations_deg')
    rotations = deg2rad(cfg.arena.rotations_deg);
end
```

**Design Options** (need discussion):
1. **Read pitch from YAML config** — Straightforward but arena config currently lacks rotations_deg
2. **Add pitch spinner UI control** — Like PatternGeneratorApp has, allows runtime adjustment
3. **Modify arena config structure** — Add rotations_deg to all arena YAML files
4. **Ignore pitch in Previewer** — Simplest, but projections won't match reality

**To Pick Up**:
1. Decide on design approach (discuss with Michael)
2. If adding UI control: Add pitch spinner to PatternPreviewerApp (like PatternGeneratorApp)
3. If reading from config: Update arena YAMLs with rotations_deg field
4. Test with pitched arena patterns

**Files to Review**:
- `patternPreviewer/PatternPreviewerApp.m` (loadArenaConfig method)
- `patternGenerator/PatternGeneratorApp.m` (pitch handling reference)
- `configs/arenas/*.yaml` (current schema)

---

### 5. PatternGeneratorApp Missing Features

**Status**: ✅ Feature parity achieved! All major G4 GUI features implemented.

**Current State**: See `docs/g4_pattern_editor_assessment.md` for full comparison.

**Completed Features** (2026-01-26/27):
- ✅ Duty cycle (1-99% spinner)
- ✅ Brightness levels (High/Low spinners, background in mask dialogs)
- ✅ Pole coordinates (Longitude/Latitude spinners in Full-field mode)
- ✅ Motion angle (0-360° spinner in Local mode)
- ✅ Arena pitch (-90 to 90°)
- ✅ Pattern FOV (Full-field / Local dropdown)
- ✅ Mask options (Solid Angle + Lat/Long with Configure dialogs, mutually exclusive)
- ✅ Starfield options (Conditional panel: dot count, radius, size, occlusion, level, re-randomize)
- ✅ Mercator view + Mollweide view with adjustable dot size and FOV zoom
- ✅ Info dialog with coordinate system diagrams and parameter reference
- ✅ 1:1 aspect ratio for all views

**Remaining Lower Priority Features**:

| Priority | Feature | Notes |
|----------|---------|-------|
| ~~Medium~~ | ~~.pat binary export~~ | ✅ Implemented (Jan 29) |
| Low | Phase shift | Starting phase offset (default 0) |
| Low | Anti-aliasing control | Fixed at 15 samples (works well) |
| Low | GIF export | Moved to Future Vision → Pattern Previewer |

**Files**:
- `patternGenerator/PatternGeneratorApp.m`
- `docs/g4_pattern_editor_assessment.md` (detailed feature inventory)

---

### 5. Branch Reconciliation

**Status**: Multiple branches with completed work need to be merged to main.

**Active Branches**:
| Branch | Status | Action |
|--------|--------|--------|
| `feature/g6-tools` | Active dev | Continue using, merge when stable |
| `claude/switchable-tcp-controller-qQRKM` | Testing | Merge after TCP testing complete |
| `claude/bugfix-trialparams-executor-80r3o` | PR open | Merge after Lisa's review |
| `yamlSystem` | Lisa's branch | Coordinate with Lisa |
| `g41-controller-update` | Stable | Port useful items, then close |
| `pcontrol` | Not started | Keep for future PControl work |

**Merge Strategy**:
- Merge everything to main in one go that doesn't impact others' work
- Anything touching Lisa's code → PR through Lisa
- Anything touching PanelController → PR through Frank
- Can merge arena config, PatternGeneratorApp, SD card tools independently

**To Pick Up**:
1. List all changes on each branch
2. Identify which changes are ready vs need more work
3. Create PRs for independent pieces
4. Coordinate with Lisa/Frank for their code

---

### 6. Arena Config for Partial Arenas

**Status**: ✅ COMPLETE (Jan 28)

**Problem** (Jan 27):
The `panels_installed` field was used inconsistently (column indices vs panel indices).

**Solution Implemented**:
1. Renamed field from `panels_installed` to `columns_installed` for clarity
2. Standardized on column indices (0-indexed) for all partial arenas
3. Renamed arena config files for clarity:
   - `G6_2x10_full.yaml` → `G6_2x10.yaml`
   - `G6_2x8_walking.yaml` → `G6_2x8of10.yaml`
   - `G6_3x18_partial.yaml` → `G6_3x12of18.yaml`
   - Similar for G4 and G3 configs
4. `load_arena_config.m` updated with new `num_columns_installed` derived property
5. `total_pixels_x` now based on installed columns (for correct pattern dimensions)

**Schema**:
```yaml
arena:
  num_rows: 2
  num_cols: 10           # Full grid columns
  columns_installed: [1, 2, 3, 4, 5, 6, 7, 8]  # 0-indexed, or null for all
```

**Files Updated**:
- `configs/arenas/*.yaml` — renamed and updated schema
- `utils/load_arena_config.m` — field rename + derived calculations
- `patternGenerator/PatternGeneratorApp.m` — field references
- `patternGenerator/configure_arena.m` — YAML output

---

### 7. Web Tools Landing Page

**Status**: ✅ COMPLETE

**Current State**:
- Arena Editor: ✅ Complete
- Arena 3D Viewer: ✅ Complete
- G6 Panel Editor: ✅ Complete (CI/CD validated)
- Pattern Editor: ❌ Placeholder (noted on landing page)
- Experiment Designer: ❌ Placeholder (noted on landing page)
- Landing page updated with status badges and descriptions

---

### 7. Pattern Validation / Regression Testing

**Status**: ✅ COMPLETE (MATLAB) — Web validation pending

**Goal**: Ensure Pattern_Generator.m produces identical output to G4_Pattern_Generator for same inputs.

**Completed** (Jan 26):
- [x] Baseline patterns generated using G4_Pattern_Generator (5 pattern types)
- [x] Stored in `validation/pattern_baseline/` (baseline_patterns.mat, baseline_parameters.yaml)
- [x] Comparison script `validation/compare_patterns.m` — runs and passes
- [x] All 5 pattern types pass: square grating, sine grating, edge, starfield, off-on

**Future Work**:
- [ ] Revisit validation when Pattern Editor is migrated to web tools
- [ ] Create JavaScript-based validation for web pattern editor (similar to G6 panel editor CI/CD)

---

### 8. Pattern Save/Load Validation Script

**Status**: ✅ COMPLETE (Jan 29)

**Goal**: Automated testing of pattern save/load for all arena generations and configurations.

**Script**: `tests/validate_pattern_save_load.m`

**Test Coverage**:
| Arena Config | Rows | Cols | Description |
|--------------|------|------|-------------|
| G4_4x12.yaml | 4 | 12 | G4 full arena |
| G4_3x12of18.yaml | 3 | 12 | G4 partial arena |
| G41_2x12_cw.yaml | 2 | 12 | G4.1 full arena |
| G6_2x10.yaml | 2 | 10 | G6 full arena |
| G6_2x8of10.yaml | 2 | 8 | G6 partial (8 of 10 cols) |
| G6_3x12of18.yaml | 3 | 12 | G6 partial (12 of 18 cols) |

**Test Process**:
1. Load arena config from YAML
2. Generate test grating pattern (2 frames)
3. Save pattern using save_pattern() / g6_save_pattern()
4. Load pattern using maDisplayTools.load_pat()
5. Verify dimensions match expected (rows × cols in pixels)
6. Verify frame count matches

**Usage**:
```matlab
results = validate_pattern_save_load();
if all([results.passed])
    disp('All tests passed!');
end
```

**Run After**:
- Any changes to g6_encode_panel.m or g6_decode_panel.m
- Any changes to save_pattern.m or g6_save_pattern.m
- Any changes to maDisplayTools.load_pat()
- Any changes to arena config schema

**Files**:
- `tests/validate_pattern_save_load.m` — Main validation script

---

## Known Issues / Technical Debt

### 🔴 CRITICAL: Web Pattern Editor Geometry Model

**Status**: Documented 2026-01-31

**Problem**: The web pattern editor (`pattern_editor.html`) uses a **flat 2D pixel-shifting model** instead of MATLAB's **spherical projection model**. This means nearly all generated patterns are geometrically incorrect when viewed on the actual cylindrical arena.

**MATLAB Approach** (correct):
1. Pre-computes 3D Cartesian coordinates (x, y, z) for every arena pixel
2. Converts to spherical coordinates (phi, theta, rho)
3. Rotates coordinates to align pattern with desired pole/motion direction
4. Applies anti-aliasing by sampling each pixel's angular field-of-view
5. Evaluates pattern function (grating, sine, etc.) on spherical coordinates

**Web Approach** (simplified):
1. Treats arena as flat 2D grid
2. Uses pixel column index as phase for gratings
3. No coordinate transformation
4. No anti-aliasing
5. No support for translation/expansion motion types

**Impact**:
- Gratings rotate in discrete pixel jumps, not continuous angles
- Patterns don't tile properly at arena boundaries
- No anti-aliasing causes visual artifacts at high spatial frequencies
- Cannot generate translation or expansion-contraction patterns
- Patterns look different on hardware vs web preview

**Files Affected**:
- `webDisplayTools/js/pattern-editor/tools/generator.js` — needs spherical geometry
- `webDisplayTools/pattern_editor.html` — UI unaffected, but output incorrect
- Would need new: `arena-coordinates.js` (JavaScript port of arena_coordinates.m)

**Resolution Options**:
1. **Full port**: Port MATLAB's spherical projection to JavaScript (complex, high accuracy)
2. **Pre-computed coords**: Generate arena coordinates in MATLAB, load as JSON in web
3. **Accept limitation**: Keep web for simple patterns, use MATLAB for precise patterns
4. **Hybrid**: Web generates, MATLAB validates/corrects

**Related Files for Reference**:
- `maDisplayTools/patternTools/arena_coordinates.m` — coordinate generation
- `maDisplayTools/patternTools/Pattern_Generator.m` — pattern dispatcher
- `maDisplayTools/patternTools/make_grating_edge.m` — example spherical generation

---

### In-Flight: Spherical Geometry Rewrite

**Plan file:** `~/.claude/plans/validated-leaping-fog.md`

**Status:** Phase 1 complete, Phase 2 in progress

**Goal:** Port MATLAB's spherical coordinate pattern generation to JavaScript, fixing the fundamental geometry mismatch where web patterns use flat 2D pixel-shifting.

| Phase | Status | Description |
|-------|--------|-------------|
| 1 | ✅ Done | Core coordinate system (arenaCoordinates, rotateCoordinates, cart2sphere, sphere2cart, samplesByPRad) |
| 2 | 🔄 Next | Basic rotation patterns with spherical coordinates |
| 3 | Pending | Anti-aliasing integration |
| 4 | Pending | Translation and expansion motion types |
| 5 | Pending | UI controls for spherical patterns |
| 6 | Pending | MATLAB reference validation suite |

**New files:**
- `webDisplayTools/js/arena-geometry.js` — Coordinate generation and transformations

---

### Other Known Issues

| Issue | Priority | Notes |
|-------|----------|-------|
| ~~Arena config in web patterns~~ | ~~Medium~~ | ✅ FIXED: Filename prefix added (G6_2x10_pattern.pat) |
| ~~Arena config should lock after generation~~ | ~~Low~~ | ✅ FIXED: Lock button added to status bar |
| Stretch feature not in web UI | Low | Referenced in MATLAB but not exposed in web |
| 3D viewer missing features | Low | Screenshots, view presets, angular resolution histogram |
| Export formats | Low | GIF, MP4, PNG sequence export not implemented in web |

---

## Why PatternGeneratorApp (Not G4 GUI Update)

We created a new `PatternGeneratorApp.m` using App Designer instead of updating the existing `G4_Pattern_Generator_gui.m`. Here's why:

### GUIDE Limitations

The original G4 Pattern Generator uses MATLAB's legacy GUIDE framework:
- **`.fig` files contain hardcoded callback references** — Callback names like `pushbutton1_Callback` are embedded in the binary `.fig` file and reference specific function names in the `.m` file
- **No programmatic way to modify `.fig` callbacks** — You can't reliably rename or reorganize callbacks without breaking the GUI
- **Callback function names are fragile** — Changing `G4_Pattern_Generator_gui.m` to `Pattern_Generator_gui.m` would break all callbacks unless you manually edit the `.fig` file in GUIDE
- **GUIDE is deprecated** — MathWorks recommends App Designer for new GUIs

### App Designer Advantages

App Designer (`PatternGeneratorApp.m`) provides:
- **Single file contains both UI and code** — No separate `.fig` file
- **Callbacks are methods** — Renaming is straightforward
- **Modern UI components** — Better styling, responsive layouts
- **Better maintainability** — Code is more readable and testable
- **Cross-platform consistency** — More reliable appearance across OS

### Our Approach

1. **Reference, don't modify** — Keep G4_Pattern_Generator_gui.m for reference
2. **Fresh implementation** — Build PatternGeneratorApp.m from scratch using App Designer
3. **Feature parity goal** — Implement same features, validate output matches
4. **Single source of truth** — Use `get_generation_specs.m` and YAML arena configs

### Files for Reference

Legacy G4 files (in G4_Display_Tools, kept for reference):
- `G4_Pattern_Generator_gui.m` + `.fig` — Original GUIDE GUI
- `configure_arena.m` + `.fig` — Arena setup dialog
- `mask_options.m` + `.fig` — Mask configuration
- `more_options.m` + `.fig` — Advanced rendering options

---

## Backlog (Prioritized)

### High Priority

1. ~~**Unified Arena Config Implementation**~~ ✅ COMPLETE
   - ~~MATLAB struct ↔ JSON bidirectional conversion~~ → YAML configs implemented
   - ~~Web tools read/write same format~~ → CI/CD syncs configs
   - ~~Pre-defined standard configs~~ → 10 standard configs in `configs/arenas/`

2. ~~**Update webDisplayTools Landing Page**~~ ✅ COMPLETE
   - ~~Reflect current roadmap status~~ → Done
   - ~~Update tool descriptions and status badges~~ → Done
   - ~~Add links to documentation / roadmap~~ → Done
   - ~~Clarify which tools are complete vs placeholder~~ → Done

3. ~~**G6 Pattern Format Support**~~ ✅ COMPLETE
   - ~~Implement G6 .pat file writer (per protocol spec)~~ → `g6_save_pattern.m`
   - ~~Panel block formatting with parity~~ → `g6_encode_panel.m`
   - ~~Validate against protocol v1 spec~~ → `validate_pattern_save_load.m`
   - Note: No G6 hardware available yet for testing

4. ~~**Pattern Index Direction Verification**~~ ✅ COMPLETE
   - **Convention agreed**: (0,0) at lower left, increasing up and to the right
   - ~~Keep as verification item to confirm as we move to whole patterns~~ → Verified in MATLAB and Web
   - ~~Add validation tests to catch any mismatches~~ → `validate_pattern_save_load.m`
   - ~~Document convention clearly in pattern tools~~ → In CLAUDE.md and g6_decode_panel.m

5. **Cross-Platform SD Card Workflow** (NEW)
   - Test `prepare_sd_card.m` on macOS
   - Research macOS FAT32 formatting tools
   - Enable develop-on-Mac, run-on-Windows workflow

### Medium Priority

6. **GitHub for Experiment Organization** (NEW - under consideration)
   - Version control for experiment configurations
   - Pattern library management with timestamps
   - Could reduce need for SD card copying across platforms
   - Needs design discussion

7. **Plugin System Foundation**
   - Define plugin interface in YAML experiment files
   - LEDController.m integration (backlight)
   - BIAS camera integration (existing code)
   - NI DAQ temperature logging

8. **Experiment Designer (Web)**
   - YAML-based experiment configuration
   - Trial sequence builder
   - Export for MATLAB execution

9. ~~**Pure MATLAB Exploration**~~ → Partially complete
   - TCP: `tcpclient` migration → In-flight work (PanelsControllerNative.m exists)
   - Camera: Evaluate Image Acquisition Toolbox vs BIAS → Deferred

### Low Priority (Future)

10. **3D Arena Visualization Enhancements**
    - ~~Load custom patterns from file~~ ✅ Done (arena_3d_viewer.html + pat-parser.js)
    - Angular resolution histogram (per-pixel calculation)
    - Export 3D models for CAD
    - **Pole location visualization** — Show 3D representation of arena geometry including pole position and orientation for pitched arenas

11. **Pattern Visualization & Export**
    - Export patterns as images (PNG), GIFs, or movies (MP4)
    - Pattern "icon" representations for libraries/catalogs:
      - Unrolled flat view (full arena unwrapped)
      - 3D perspective views (above, behind, 3/4 angle)
      - Static thumbnails for pattern browsers
      - Dynamic/animated icons with motion blur to indicate temporal patterns
    - Useful for documentation, papers, pattern selection UIs

12. **G6 Protocol v2+ Features**
    - PSRAM pattern storage
    - TSI file generation
    - Mode 1 support

13. ~~**App Designer Migration**~~ ✅ DONE
    - ~~Evaluate only after GUIDE version is stable~~ → PatternGeneratorApp uses App Designer
    - ~~Would enable better cross-platform support~~ → Implemented

---

## Future Vision: PatternGeneratorApp Architecture

> **Status**: MATLAB implementation largely complete. Next step: architect web tools port.

### Web Tools Port (Next Step)

The MATLAB pattern generation architecture is now mostly implemented (Generator, Previewer, Combiner apps). Before porting to web tools, we need:

1. **Design Vision** — Define the user experience for web-based pattern creation
   - Single-page vs multi-window approach
   - Mobile/tablet support considerations
   - Offline capability requirements

2. **Layout Strategy** — Plan how to organize the web UI
   - Leverage existing dark theme design system
   - Responsive layout for different screen sizes
   - Integration with existing arena_3d_viewer.html

3. **Technical Architecture** — Choose implementation approach
   - Vanilla JS vs framework (React, Vue, etc.)
   - Pattern file handling (upload, download, local storage)
   - Sharing/collaboration features

### Near-term: New Pattern Types

**Looming Patterns**
- Expanding disc or square from center point
- Two velocity modes:
  - Constant velocity: user specifies step size (degrees per frame)
  - r/v loom: user specifies l/v ratio for biologically-relevant approach timing

**Reverse-φ (Reverse-phi) Patterns** ⚠️ NEEDS REVISIT
- Classic reverse-phi motion illusion
- Brightness inversion between consecutive frames while pattern shifts position
- Creates perceived motion opposite to physical displacement direction
- **Status (2026-01-30)**: Initial implementation attempted but behavior is incorrect. The current `make_reverse_phi.m` simply inverts alternate frames, but the proper reverse-phi requires more careful consideration of:
  - Exact timing relationship between spatial shift and contrast inversion
  - Whether inversion should be global or local to the shifted region
  - Reference literature (Anstis 1970, Chubb & Sperling 1988) for correct implementation
- **Files created** (need revision): `patternTools/make_reverse_phi.m`, updates to `Pattern_Generator.m` and `PatternGeneratorApp.m`
- **Action**: Remove from UI or mark as experimental until properly specified and implemented

### Longer-term: Multi-Window Architecture

Split PatternGeneratorApp into 4 specialized windows:

| Window | Purpose | Key Feature | Status |
|--------|---------|-------------|--------|
| **Pattern Previewer** | Central hub for viewing/animating patterns | Per-frame stretch + intensity histogram | ✅ Complete |
| **Pattern Generator** | Standard pattern creation (gratings, starfield, looming, etc.) | "Generate and Preview" → sends to Previewer | ✅ Complete |
| **Pattern Combiner** | Combine two patterns (sequential, mask, left/right) | Multi-mode combination with swap | ✅ Complete |
| **Drawing App** | Manual pixel-level pattern creation | For custom non-parameterized stimuli | Planned |

**Generator/Previewer Separation: COMPLETE** (2026-01-29)

The `PatternGeneratorApp.m` was rebuilt as a focused generation-only tool:
- Compact single-column UI (380×700 px) — fits alongside Previewer
- "Generate & Preview" button creates pattern and sends to PatternPreviewerApp
- Original version archived as `PatternGeneratorApp_v0.m`
- Uses same API as PatternCombinerApp for consistency

**Workflow**:
1. Previewer is the central app — can open files or launch generator apps
2. Generator apps create patterns and push to Previewer via "Generate and Preview"
3. Previewer handles all visualization, playback, and file operations
4. This separation allows each tool to focus on its specialty

**Previewer Features** (✅ Implemented Jan 30):
- Per-frame stretch value display ✅
- Per-frame intensity histogram ✅:
  - Graphical horizontal bars with black→green gradient (0→15)
  - Pixel counts displayed on right side of each bar
  - Log/Linear scale toggle for sparse patterns
  - Enable checkbox to disable during playback (clears display when disabled)
  - Optimized with persistent graphics objects for smooth playback
- GIF/video export ✅
- UI controls disabled during playback to prevent race conditions ✅
- App layout utilities: `open_pattern_apps()`, `save_pattern_app_layout()`, `close_pattern_apps()` ✅

**Benefits**:
- Cleaner separation of concerns (creation vs. viewing)
- Previewer can load and inspect any .pat file independently
- Multiple generation workflows feed into single preview tool
- Future extensibility (new generator types just need to push to Previewer)
- Intensity histogram provides instant pattern audit capability

---

## Architecture Decisions

### Arena Config vs Rig Config

**Arena Config** — Pattern-specific, standalone YAML document:
```yaml
# configs/arenas/G6_2x10.yaml
arena:
  generation: "G6"
  num_rows: 2
  num_cols: 10
  columns_installed: null  # null = all columns, or array of 0-indexed column indices
  column_order: "cw"
  orientation: "normal"
```

**Rig Config** — Hardware-specific, references arena config by filename:
```yaml
# configs/rigs/test_rig_1.yaml
rig:
  name: "Fly Arena 1"
  arena_config: "G6_2x10.yaml"  # Reference, not embedded
  controller:
    ip_address: "10.102.40.47"
    port: 62222
  sd_card:
    drive_path: "/Volumes/PATSD"  # macOS
    # drive_path: "E:"  # Windows
  plugins:
    led_controller:
      enabled: true
      port: "COM3"
```

**Rationale**: Arena config is needed standalone for pattern design. Rig config references arena by filename (not embedded) to avoid duplication. YAML chosen over JSON for readability and comments.

### CI/CD Validation Strategy
Established pattern for ensuring MATLAB ↔ Web consistency:
1. MATLAB generates `reference_data.json` with computed values
2. Web tool has matching calculation logic
3. Node.js test compares web calculations to reference (tolerance: 0.0001)
4. GitHub Actions runs on push, fails if calculations diverge

**Implemented for**: Arena Editor, G6 Panel Editor
**To implement for**: Pattern Editor (multi-panel)

### Pattern Editor Strategy
1. **MATLAB GUI** (G4_Pattern_Generator_gui.m) — update for all generations (G3, G4, G4.1, G6)
2. **Web Editor** — unified multi-panel editor for cross-platform access
3. **Shared backend logic** — both tools use same pattern generation algorithms
4. **Regression testing** — automated comparison against baseline patterns
5. **Arena config integration** — load config to auto-set panel dimensions

### SD Card Deployment Strategy
- SD card must be named "PATSD"
- Use `'Format', true` option for cleanest FAT32 state
- Patterns written BEFORE manifest files (FAT32 dirIndex order matters)
- No deduplication — same pattern can have multiple IDs for multi-protocol experiments
- MANIFEST files go in root, patterns in root or `/patterns` subfolder

### Repository Structure
```
maDisplayTools/
├── configs/
│   ├── arenas/              # Standard arena configs (YAML)
│   │   ├── G6_2x10.yaml
│   │   ├── G6_2x8of10.yaml
│   │   ├── G41_2x12_ccw.yaml
│   │   └── ... (10 configs total)
│   └── rigs/                # Rig configs (reference arena YAML)
│       ├── test_rig_1.yaml
│       └── ...
├── controller/              # PanelsController, TCP code
├── docs/
│   ├── G4G6_ROADMAP.md      # This file
│   ├── arena_config_spec.md # Arena config JSON schema
│   ├── g4_pattern_editor_assessment.md  # Feature inventory
│   ├── pattern_testing/     # Regression test patterns & plan
│   └── arena-designs/       # PDF exports, reference_data.json
├── examples/
│   ├── test_patterns/       # SD card test patterns (20)
│   └── test_patterns_100/   # Two-digit patterns (00-99)
├── patternGenerator/        # Pattern generation tools
│   ├── PatternGeneratorApp.m    # NEW: App Designer GUI
│   ├── Pattern_Generator.m      # Core pattern engine
│   ├── arena_coordinates.m      # Arena pixel coordinates
│   ├── configure_arena.m/.fig   # Arena config dialog
│   └── support/                 # Helper functions
├── utils/
│   ├── design_arena.m       # Arena geometry (with column_order)
│   ├── get_generation_specs.m   # Panel specs (single source of truth)
│   ├── prepare_sd_card.m    # SD card deployment
│   ├── load_arena_config.m  # Load arena YAML
│   ├── load_rig_config.m    # Load rig YAML (resolves arena ref)
│   └── load_experiment_config.m
└── logs/                    # MANIFEST logs

webDisplayTools/
├── index.html               # Landing page
├── arena_editor.html        # ✅ Complete (view/create modes, config dropdown)
├── arena_3d_viewer.html     # ✅ Complete (config dropdown, accurate LED specs)
├── g6_panel_editor.html     # ✅ Complete (CI/CD validated)
├── pattern_editor.html      # Placeholder (Sprint 3)
├── experiment_designer.html # Placeholder
├── scripts/
│   └── generate-arena-configs.js  # CI/CD: YAML → JS generator
├── .github/workflows/
│   └── sync-arena-configs.yml     # CI/CD: Weekly sync from maDisplayTools
├── data/
│   ├── reference_data.json  # MATLAB-generated validation data
│   └── g6_encoding_reference.json
├── js/
│   ├── arena-configs.js     # ✅ Auto-generated (STANDARD_CONFIGS, PANEL_SPECS)
│   ├── arena-calculations.js
│   └── g6-encoding.js       # G6 panel encoding module
└── tests/
    ├── validate-arena-calculations.js
    └── validate-g6-encoding.js
```

---

## Session Notes

> **Note**: Detailed session logs have been moved to `G4G6_ROADMAP_SESSIONS.md` to keep this file compact.
> See the Changelog table below for a summary of each session.

---

## References

### Project Tracking
- [G4.1 & G6 Project Board](https://github.com/users/floesche/projects/6) — Cross-repo issue tracking (maintained by floesche)
- Controller IP addresses — See Slack (not in GitHub)

### Documentation
- [G6 Protocol Spec](https://docs.google.com/document/d/17crYq4sdD1GhazOPS_Yi6UyGV6ugUy3WGnCWWw49r_0/edit) — Panel protocol v1-v4
- [External Interactions Doc](https://docs.google.com/document/d/1sOOfHelMIC74Od7Tmjm4quTOmdrwfoByE4V4sNNtN54/edit) — Camera, LED, temperature
- `tcp_migration_plan.md` — TCP benchmark procedures
- `sd_card_deployment_notes.md` — SD card workflow
- `todo_lab_tuesday.md` — Hardware debugging checklist (COMPLETED)

### Code References
- `G4_Display_Tools/G4_Pattern_Generator/` — Original pattern generator
- `G4_Display_Tools/PControl_Matlab/` — G4 PControl (GUI files may be missing)
- [floesche/LED-Display_G3_Software](https://github.com/floesche/LED-Display_G3_Software) — G3 software including original PControl GUI
- `webDisplayTools/arena_editor.html` — Web arena editor (complete)
- `webDisplayTools/g6_panel_editor.html` — Single panel editor (complete, CI/CD validated)
- `webDisplayTools/arena_3d_viewer.html` — 3D visualization (complete)

### Hardware
- G6 LED mapping: See protocol spec "LED Mappings" section
- SD card: Must be named "PATSD", FAT32 format

---

## Changelog

| Date | Change |
|------|--------|
| 2026-02-04 | **Icon Generator v1.4 + Partial Arena Fixes** — Fixed icon generator angular orientation to match 3D viewer (partial arena gap now centered at South). Fixed "arena is not defined" typo. Changed default inner radius to 0.4 for thicker ring. Flipped vertical orientation (top of arena at center of ring). Fixed gap line drawing to include `angleOffsetRad`. Pattern Editor v0.9.21: Fixed 3D viewer not updating on arena change (added `threeViewer.reinit()` call). Fixed partial arena support in 3D viewer (using `columns_installed.length` for comparison). |
| 2026-02-03 (night) | **Pattern Editor v0.9.14** — Fixed partial arena dimension calculations (5 locations in pattern_editor.html, 4 in generator.js). G6_3x12of18 now correctly produces 240×60 px patterns (was incorrectly 360×60). G6_2x8of10 correctly produces 160×40 px patterns. Added animated GIF thumbnails for clipboard patterns (cycles through frames on hover at ~6-7 FPS, shows frame count badge). Tested Icon Generator path detection for partial arenas (works correctly). All 73 MATLAB validation tests pass. **BUG DISCOVERED**: Edge patterns generate 201 frames instead of expected 16 frames (validation tests only compare frame 0, not frame count). |
| 2026-02-03 (PM) | **Pattern Editor v0.9.12** — Fixed frame reference tracking bug when deleting clipboard frames (loadedClipboardFrameId now cleared when loaded frame is deleted, preventing confusion when array indices shift). Added icon thumbnail preview in Frame Shifting panel (64x64 thumbnail shows which frame is loaded for shifting, with Clear button). **Icon Generator v1.3** — Added GIF generation mode (select mode, FPS, generates animated GIF from all pattern frames), progress bar during encoding, proper Download GIF functionality. |
| 2026-02-03 | **Pattern Editor v0.9.7** — Fixed critical JavaScript falsy-value bug where `poleElevation = 0` was silently converted to `-90` (because `0 || -90` evaluates to -90). Added `parseFloatWithDefault()` helper using `Number.isFinite()` to correctly handle zero values. Fixed 6 occurrences in pattern_editor.html. Patterns with Pole El = 0 now correctly produce concentric rings (matching MATLAB) instead of horizontal stripes. |
| 2026-02-02 (PM) | **Pattern Editor v0.9.4** — Icon thumbnails for clipboard (cylindrical view using icon-generator.js), "Double-click to view" tooltip, LOADED badge for active items. Fixed multiple bugs: `drawPatternGrid()` undefined, `itemType` undefined, starfield `randomSeed` element ID mismatch. Double-click pattern now exits edit mode. Increased clipboard height. Added "← Tools" home link. Created GitHub issue #27 for remaining bugs (icon size, full-field projection, animation tab UX). Added tooltip guidelines to CLAUDE.md. |
| 2026-02-02 (late AM) | **Icon Generator v0.9** — Added folder upload option with `webkitdirectory` attribute (browsers expose full path when selecting folder). Added manual arena override dropdown when auto-detection fails. Fixed browser security limitation where single file input doesn't expose folder path. Reduced pole axis arrow length to 1.1x max(height, diameter). **Status**: All changes committed and pushed. |
| 2026-02-02 (PM) | **Pattern Editor v0.9 + Icon Generator v0.8** — Major UI improvements: GENERATE button 25% wider with bigger arrows. Tabbed clipboard (Frames/Patterns tabs with counts). Two capture buttons ("Frame" green, "Pat" blue) on viewer. Clipboard clears on arena change. New Image tab placeholder. Animate tab mode toggle (Frame Shifting vs Frame Animation). Frame Animation builds patterns from clipboard frames. Icon Generator: removed dropdown, auto-detects arena from filename/path (e.g., `G6_2x10_*.pat`). **Next session**: Test all UI improvements on GitHub Pages. |
| 2026-02-02 | **Session review + Pattern Editor v0.6** — Reviewed parallel session work (spherical geometry ~95% complete, pattern editor streams A-H complete, icon generator pat-parser conflict resolved). **Fixed icon generator issue**: parallel sessions toggled ES6 exports; final state correct but test page had wrong method name (`parse` vs `parsePatFile`). **Pattern Editor updates**: Redesigned GENERATE button (narrow column with vertical stacked letters, arrows above/below pointing right). Split clipboard into Frames and Patterns sections with single-selection, delete-on-hover X buttons. Added pole geometry visualization to 3D viewer (red line through arena with arrowhead, toggled via checkbox). Compacted UI: removed info notes, added tooltips, combined inputs on same lines (pole az/el, dots/size/seed, duty/phase, mode/high-low). Spherical geometry needs more testing for translation patterns with non-standard pole. Updated to v0.6. |
| 2026-01-31 (PM) | **Autonomous session: validation + documentation** — Ran MATLAB `generate_web_pattern_reference.m` to create pattern reference data. Updated `tests/validate-pattern-generation.js` to handle starfield/edge differences (different RNG/algorithm). All 11 validation tests pass (grating and sine match exactly, starfield and edge verify structure). Updated CLAUDE.md with project size assessment guidance and parallel agent strategy. Added "Known Issues / Technical Debt" section documenting critical geometry model gap. Added pole location visualization to 3D viewer backlog. Added roadmap compression TODO note. |
| 2026-01-31 | **Pattern Editor UI fixes + major issues documented** — Fixed panel number label cleanup in 3D viewer (CSS2D DOM elements now properly removed from labelRenderer container). Changed panel numbers to red (#ff3333) and 20% larger (17px). Added combined pattern suggested names (e.g., `patternA_patternB_blend.pat`) with mode-based suffixes. Added rename button (✎) to status bar for changing pattern filename. **Documented critical issues for next session**: (1) Pattern geometry model is fundamentally different between MATLAB (full projection model) and web (pixel shifting) - nearly all patterns geometrically incorrect until fixed; (2) Web patterns need arena config in filename; (3) Arena config should be locked not dropdown-selectable; (4) Stretch feature not implemented; (5) Export formats (GIF/MP4) needed; (6) 3D viewer feature analysis needed. |
| 2026-01-30 (night) | **Pattern Editor Streams F, G, H complete** — Fixed 3D viewer Three.js module imports (use full CDN URLs, not importmap). Fixed arena positioning (Y=0 center) and camera setup. Created `js/pattern-editor/tools/combiner.js` with sequential/mask/split modes. Integrated combiner into pattern_editor.html with A/B pattern info, swap, mode dropdown. All validation tests pass (6/6 pattern gen, 25/25 G6 encoding). Added CLAUDE.md "Planning Best Practices" section for parallel agents. |
| 2026-01-30 (evening) | **Web Pattern Editor planning + initial implementation** — Created comprehensive migration plan for Pattern Editor (saved to `~/.claude/plans/linear-fluttering-lerdorf.md`). Built initial `pattern_editor.html` skeleton with two-pane layout (tools left, viewer right), tool tabs (Generate/Frame/Combine), viewer tabs (Grid/3D), frame clipboard, playback controls. Added to landing page with "In Development" status. Split roadmap: moved detailed session logs to `G4G6_ROADMAP_SESSIONS.md` to reduce context usage (~37% / 600 lines archived). |
| 2026-01-30 (late) | **Roadmap updates: backlog items completed** — Marked High Priority #3 (G6 Pattern Format Support) and #4 (Pattern Index Direction Verification) as COMPLETE. Updated Low Priority #10 (3D Arena Visualization): first task "Load custom patterns from file" done via arena_3d_viewer.html + pat-parser.js. Updated Future Vision section: MATLAB implementation (Generator, Previewer, Combiner) now largely complete; added "Web Tools Port" as next step requiring design vision, layout strategy, and technical architecture planning. |
| 2026-01-30 | **Web Pattern Viewer implementation** — Added .pat file loading to 3D arena viewer (webDisplayTools). Created `js/pat-parser.js` module for G6 and G4 pattern parsing with row flip compensation. Added pattern loading UI: file picker, pattern info display, frame slider, play/pause with FPS control (1-30), FOV slider with presets (60°/120°/170°). Added `testLoadPattern()` for automated testing. Updated CLAUDE.md with testing docs and close session protocol. Created GitHub issues #8 (UI polish) and #9 (fisheye shader). Marked In-Flight Work #0 (Web Tools Update) as COMPLETE. |
| 2026-01-29 (Night) | **UI layout refinements for stackable apps** — PatternGeneratorApp: moved 3 buttons to full window width below both panels, equal-width ("Generate & Preview", "Save...", "Export Script..."), status line at bottom, height 604px. PatternCombinerApp: aligned radio buttons with Options content, removed spacer from action buttons, reduced row heights, all buttons visible without cutoff, height 464px. Both apps now stack nicely on screen. All validation tests pass. |
| 2026-01-29 (PM) | **PatternCombinerApp refinements + PatternPreviewerApp fixes** — UI redesign: window 660×640, three aligned info panels with pattern names in bold, all action buttons visible, editable "Save as:" field. Dynamic file naming: names update when changing options (threshold, split, binary op, mask mode); conventions: `_then_` (sequential), `_mask{N}_` (replace), `_blend_` (blend), `_{OP}_` (binary), `_LR{N}_` (split). PatternPreviewerApp fixes: slider initialization (drawnow fixes compressed ticks), projection views for in-memory patterns (new `generateArenaCoordinatesFromConfig()` method), format shows "G6 (in memory)" with generation, window reuse (finds existing Previewer). All 18 validation tests pass. **Next suggested**: Clean rebuild of Pattern Generator as focused tool that sends to Previewer. |
| 2026-01-29 | **PatternCombinerApp implemented** — New App Designer GUI (620×520 px) for combining two patterns. Three modes: Sequential (concatenate frames), Mask (replace at threshold / 50% blend for GS16; OR/AND/XOR for binary), Left/Right (configurable split point). Features: Pattern 1 sets arena config, Pattern 2 dropdown shows compatible patterns (same dir, same GS), Swap button, frame truncation dialog for spatial modes, stretch mismatch dialog. Updated PatternPreviewerApp with `isUnsaved` flag and red "UNSAVED" warning label. Created `tests/validate_pattern_combiner.m` (12 tests, all pass). Enabled Tools > Pattern Combiner menu. Updated Future Vision table to show 3 of 4 apps complete. |
| 2026-01-29 | **Directory reorganization + PatternPreviewerApp enhancements** — Consolidated `patternGenerator/` and `patternPreviewer/` into `patternTools/`. Moved legacy GUIDE files to `patternTools/legacy/`. Added Panel ID overlay feature to PatternPreviewerApp (checkbox next to Panel Outlines, displays Pan # and Col # in red text). Fixed panel ID numbering to use column-major order (matches G6 documentation). Added GUI screenshot verification workflow to CLAUDE.md using `exportapp()`. Documented inter-app communication API (`loadPatternFromApp`) with recommendation to pass arena config explicitly rather than auto-detect from dimensions. |
| 2026-01-29 | **G6 pattern fixes + validation infrastructure** — Fixed G6 row inversion bug (g6_decode_panel.m now flips rows to compensate for encoder flip). Removed G4 fprintf output in save_pattern.m. PatternPreviewerApp now shows installed columns for partial arenas (e.g., "2 x 8of10"). Created `tests/validate_pattern_save_load.m` for automated testing of G4, G4.1, G6 save/load with full and partial arenas. Added In-Flight Work item #4: Arena pitch in Pattern Previewer (DEFERRED for design discussion). Added In-Flight Work item #8: Pattern Save/Load Validation Script. |
| 2026-01-29 | **Future Vision section added** — Documented planned PatternGeneratorApp architecture evolution. Near-term: looming patterns (disc/square, constant or r/v velocity) and reverse-φ patterns (brightness inversion motion illusion). Longer-term: split into 4 windows (Pattern Previewer as central hub, Pattern Generator, Pattern Combiner, Drawing App). Previewer features: per-frame stretch display, per-frame intensity histogram (dynamic pixel counts per intensity level). Also completed: stretch UI control in PatternGeneratorApp, descriptive .pat filenames (removed `pat0001.pat` numeric format). |
| 2026-01-28 | **Arena config schema update + pattern library convention** — Resolved blocking issue #6 (panels_installed inconsistency). Renamed field `panels_installed` → `columns_installed` for clarity. Renamed arena config files: removed `_full` suffix, partial arenas now use `XofY` format (e.g., `G6_2x8of10.yaml` = 8 of 10 columns installed). Updated `load_arena_config.m` with new `num_columns_installed` derived property; `total_pixels_x` now based on installed columns. Created pattern library convention: patterns organized in directories matching arena config names for automatic validation. New files: `utils/validate_pattern_arena.m`, `docs/pattern_library_convention.md`. **Web tools need update**: arena editor config dropdown, 3D viewer URL params, CI/CD sync workflow. |
| 2026-01-27 | **PatternGeneratorApp refinements** — Fixed partial arena rendering (Pcols/Pcircle parameters now match G4 Pattern Generator). Info dialog now non-modal. Masks no longer mutually exclusive. Fixed view labels (Pixel Row/Column for Grid, Longitude/Latitude for projections). Y-axis flipped in Grid view (row 0 at bottom). FOV reset goes to full ±180°/±90°. Fixed Mollweide zoom buttons. Re-enabled data tips. Fixed arena info display for partial arenas (correct panel count, pixel dimensions, deg/px). **Discovered arena config schema issue**: `panels_installed` used inconsistently (column indices vs panel indices). Added In-Flight Work item #6 for schema extension. |
| 2026-01-26 (PM) | **Comprehensive roadmap update** — Added In-Flight Work section with 7 items and "To Pick Up" instructions. Added "Why PatternGeneratorApp" section documenting GUIDE limitations. Updated Sprint 2 (P1, P3 complete), Sprint 3 dates (Feb 2-5). Added merge strategy (PRs through Lisa/Frank for their code). Updated backlog: marked completed items, added cross-platform SD and GitHub for experiments. |
| 2026-01-26 | **PatternGeneratorApp created** — New App Designer GUI for multi-generation pattern creation. Features: arena config dropdown (YAML integration), LED green phosphor colormap, playback controls (1/5/10/20 FPS), arena info display (deg/px horizontal to 3 decimal places), step size in pixel equivalents. Single source of truth: `get_generation_specs.m` for panel specs. Updated README.md with comprehensive documentation. |
| 2026-01-25 | Column numbering convention fixed (GitHub Issue #4). CW/CCW column ordering implemented with south baseline. c0 starts at south for both conventions (CW: left of south, CCW: right of south). MATLAB design_arena.m updated with column labels (c#) and compass indicators (N/S). Web tools updated: arena_editor.html and arena_3d_viewer.html. Added G6_3x18_partial config (10 standard configs total). Fixed 3D viewer fly view camera position. Statistics panel moved to floating right panel. LED specs added to PANEL_SPECS (led_type, dimensions). Created arena_config_audit.md documenting single-source-of-truth issues. |
| 2026-01-24 (PM) | Web tools UI redesign complete. Arena configs now single source of truth. Created 9 standard arena YAML configs in maDisplayTools. CI/CD workflow syncs configs to webDisplayTools. Arena editor & 3D viewer redesigned with config dropdowns. Updated LED specs with accurate dimensions (G3: 3mm round, G4: 1.9mm round, G4.1: 0603 SMD, G6: 0402 SMD). Fixed 3D viewer label positioning. Node v24.12.0, Three.js 0.182.0 (both current). |
| 2026-01-24 | Sprint 1 COMPLETE. Added Active Branches section. TCP migration partial (PanelsControllerNative works, needs more testing). Experiment workflow complete (PR open). Updated Sprint 2 priorities: Arena Config P1 (with audit steps), webDisplayTools P2, Pattern Editor P3, Branch Reconciliation P4 (goal: complete items to main). GUI deferred. Sprint 3: Large pattern = many frames, web editor = direct port of MATLAB + GIF/MPG export. Remove G5 from valid arenas. Pattern index convention agreed: (0,0) lower left. |
| 2026-01-23 | G6 Panel Editor CI/CD COMPLETE. Updated encoding to simplified row-major (removed LED_MAP). Created shared g6-encoding.js module. 25 validation tests passing. Sprint 2 P3 marked complete. |
| 2026-01-21 | SD card workflow COMPLETE. Reorganized sprints: Sprint 2 = Arena Config + G4.1 GUI, Sprint 3 = Pattern Editors. Added backlog item for pattern index direction discrepancy. Updated architecture with separate arena/rig config. |
| 2026-01-18 | Initial roadmap created, consolidated from remote_work_plan.md |

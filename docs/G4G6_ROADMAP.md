# G4/G6 Display Tools Roadmap

> **Living Document** — Update this file every few days as work progresses and priorities shift.
> 
> **Last Updated**: 2026-01-29
> **Next Review**: ~2026-02-01

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

## In-Flight Work

These are started projects that need to be picked up and completed. Each section describes current state, what's left, and how to resume.

### 0. Web Tools Update for Arena Config Changes

**Status**: 🔴 NEEDS UPDATE — Arena config schema changed in MATLAB, web tools need sync

**Changes Made (Jan 28)**:
1. **File renames**: `G6_2x10_full.yaml` → `G6_2x10.yaml`, `G6_2x8_walking.yaml` → `G6_2x8of10.yaml`, etc.
2. **Schema change**: `panels_installed` → `columns_installed`
3. **New naming convention**: Partial arenas use `{rows}x{installed}of{total}` format

**Web Tools to Update**:

| File | Changes Needed |
|------|----------------|
| `arena_editor.html` | Update config dropdown names, change `panels_installed` → `columns_installed` in YAML export |
| `arena_3d_viewer.html` | Update URL param examples (`?config=G6_2x10` not `G6_2x10_full`) |
| `js/arena-configs.js` | Regenerate from YAML (CI/CD should handle this) |
| `scripts/generate-arena-configs.js` | Update to use `columns_installed` field |
| `.github/workflows/sync-arena-configs.yml` | Trigger manual sync to pick up renamed files |

**To Pick Up**:
1. Run CI/CD sync workflow manually (or wait for weekly trigger)
2. Update `arena_editor.html` YAML export to use `columns_installed`
3. Test config dropdown shows new names
4. Test partial arena export produces correct `columns_installed` array
5. Verify 3D viewer loads renamed configs

**Files to Review**:
- `webDisplayTools/arena_editor.html`
- `webDisplayTools/arena_3d_viewer.html`
- `webDisplayTools/scripts/generate-arena-configs.js`

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

3. **G6 Pattern Format Support**
   - Implement G6 .pat file writer (per protocol spec)
   - Panel block formatting with parity
   - Validate against protocol v1 spec
   - Note: No G6 hardware available yet for testing

4. **Pattern Index Direction Verification**
   - **Convention agreed**: (0,0) at lower left, increasing up and to the right
   - Keep as verification item to confirm as we move to whole patterns
   - Add validation tests to catch any mismatches
   - Document convention clearly in pattern tools

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
    - Load custom patterns from file
    - Angular resolution histogram (per-pixel calculation)
    - Export 3D models for CAD

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

> **Status**: Planning/Design — Not yet scheduled for implementation

### Near-term: New Pattern Types

**Looming Patterns**
- Expanding disc or square from center point
- Two velocity modes:
  - Constant velocity: user specifies step size (degrees per frame)
  - r/v loom: user specifies l/v ratio for biologically-relevant approach timing

**Reverse-φ (Reverse-phi) Patterns**
- Classic reverse-phi motion illusion
- Brightness inversion between consecutive frames while pattern shifts position
- Creates perceived motion opposite to physical displacement direction

### Longer-term: Multi-Window Architecture

Split PatternGeneratorApp into 4 specialized windows:

| Window | Purpose | Key Feature | Status |
|--------|---------|-------------|--------|
| **Pattern Previewer** | Central hub for viewing/animating patterns | Per-frame stretch + intensity histogram | ✅ Complete |
| **Pattern Generator** | Standard pattern creation (gratings, starfield, looming, etc.) | "Generate and Preview" → sends to Previewer | 🔄 Needs separation |
| **Pattern Combiner** | Combine two patterns (sequential, mask, left/right) | Multi-mode combination with swap | ✅ Complete |
| **Drawing App** | Manual pixel-level pattern creation | For custom non-parameterized stimuli | Planned |

**Next Priority: Generator/Previewer Separation**

The current `PatternGeneratorApp.m` combines both generation and preview functionality. Now that `PatternPreviewerApp.m` is a robust standalone app with full projection support, the next step is to create a focused Pattern Generator that:
- Handles only pattern parameter configuration and generation
- Sends generated patterns to PatternPreviewerApp via `loadPatternFromApp()`
- Has a simpler UI without embedded preview

**Recommended approach**: Clean rebuild of Generator rather than removing functionality piece by piece. This creates cleaner code and allows rethinking the UI layout for a generation-focused workflow.

**Workflow**:
1. Previewer is the central app — can open files or launch generator apps
2. Generator apps create patterns and push to Previewer via "Generate and Preview"
3. Previewer handles all visualization, playback, and file operations
4. This separation allows each tool to focus on its specialty

**Previewer Features**:
- Per-frame stretch value display (number field next to plot)
- Per-frame intensity histogram:
  - Shows only the intensity levels actually present in the frame
  - Displays pixel count for each intensity (e.g., "0: 2400 px, 1: 1200 px, 15: 400 px")
  - Dynamically adapts — 3 rows for binary patterns, up to 16 for full grayscale
  - Updates in real-time during playback
  - Essential for validating Pattern Combiner output
- GIF/video export for documentation and sharing

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

### 2026-01-29 (PM): PatternCombinerApp Refinements + PatternPreviewerApp Fixes

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

### 2026-01-29: PatternCombinerApp Implementation

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

### 2026-01-27: PatternGeneratorApp Refinements + Partial Arena Issue

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

### 2026-01-26 (PM): Roadmap Comprehensive Update

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

### 2026-01-26: PatternGeneratorApp Created

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

### 2026-01-24 (PM): Web Tools UI Redesign + Arena Config System

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

### 2026-01-24: TCP Migration Testing + Experiment Workflow Fixes

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

### 2026-01-23: G6 Panel Editor CI/CD Complete 🎉
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

### 2026-01-21: Tuesday Lab Session — SUCCESS! 🎉
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

### 2026-01-18: Initial Planning Session
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

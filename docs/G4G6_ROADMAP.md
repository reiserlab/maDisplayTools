# G4/G6 Display Tools Roadmap

> **Living Document** — Update this file every few days as work progresses and priorities shift.
> 
> **Last Updated**: 2026-01-24 (PM session)
> **Next Review**: ~2026-01-28

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

## Current Focus (Sprint 2: Jan 27-31)

### 🎯 Primary Goal: Arena Config & Web Tools Update

### Tasks

- [ ] **[P1] Arena Config Implementation** (HIGH PRIORITY)
  - [x] Draft JSON schema (see `arena_config_spec.md` on g41-controller-update) ✅
  - [x] Switched to YAML for arena/rig/experiment configs ✅
  - [x] Created `configs/arenas/` with 9 standard arena configs ✅
  - [x] Created `configs/rigs/` with rig configs (reference arena YAML) ✅
  - [x] Implement MATLAB `load_arena_config.m`, `load_rig_config.m`, etc. ✅
  - [x] Update `design_arena.m` with column_order field ✅
  - [x] Web arena editor redesigned with view/create modes ✅
  - [x] Web 3D viewer redesigned with config dropdown ✅
  - [x] CI/CD workflow to sync configs from maDisplayTools to webDisplayTools ✅
  - [ ] **Audit maDisplayTools** for arena-specific details, map out how to minimize redundancy
  - [ ] **Audit G4 pattern editor** to map how it can use new arena config (feeds P3 and Sprint 3 P1)
  - [ ] Remove G5 from valid arena designs (nonfunctional, not worth supporting)

- [ ] **[P2] Update webDisplayTools**
  - [x] Arena editor: Dropdown for 9 standard configs, view/create modes ✅
  - [x] 3D viewer: Dropdown for configs, removed manual gen/row controls ✅
  - [x] CI/CD workflow: Auto-sync arena configs from maDisplayTools ✅
  - [x] Updated LED specs with accurate dimensions (G3: 3mm round, G4: 1.9mm round, G4.1: 0603 SMD, G6: 0402 SMD) ✅
  - [ ] Update landing page to reflect current status
  - [ ] Update tool descriptions and status badges
  - [ ] Add links to documentation / roadmap
  - [ ] Clarify which tools are complete vs placeholder

- [ ] **[P3] Pattern Editor Assessment**
  - [ ] Inventory G4_Pattern_Generator_gui.m features
  - [ ] Identify generation-specific vs universal features
  - [ ] Plan update strategy for multi-generation support

- [ ] **[P4] Branch Reconciliation** (after P1 arena work complete)
  - **Goal**: Get complete, tested items that don't require substantial further work onto `main` and close branches
  - [ ] Merge consolidated arena work to main
  - [ ] Port remaining g41-controller-update items (LEDController, docs, test patterns) to main
  - [ ] Reconcile with Lisa's experiment execution system (already in main)
  - [ ] Close stale branches (g41-controller-update, old claude/ branches)

### Deferred to Later
- G4.1 Control GUI Development — wait until arena config and pattern editor work is more mature

### Done Criteria
- [ ] Arena config JSON loading/saving works in MATLAB and web
- [ ] webDisplayTools landing page accurately reflects project status
- [ ] Pattern editor requirements documented

---

## Sprint 3 (Feb 3-7)

### 🎯 Primary Goal: Pattern Editor Update + TCP Migration Completion

### Tasks

- [ ] **[P1] Update G4_Pattern_Generator_gui.m**
  - [ ] Add generation selector (G3, G4, G4.1, G6) — skip G5
  - [ ] Update pixel grid sizes (8×8, 16×16, 20×20)
  - [ ] Integrate arena config loading
  - [ ] Run regression tests

- [ ] **[P2] Complete TCP Migration + Large Pattern Testing**
  - [ ] Investigate controller lockup at >10 FPS streaming
  - [ ] **Large pattern stress testing** — "large" means many frames (not varying arena size)
  - [ ] **Mode 3 reliability testing** — pre-rendered playback streaming stability
  - [ ] Create `tests/benchmark_large_patterns.m`
  - [ ] Document maximum reliable streaming rate
  - [ ] Report findings to Peter/Frank
  - [ ] Decision: merge PanelsControllerNative or keep parallel

- [ ] **[P3] Web Pattern Editor (Multi-Panel)**
  - [ ] **Direct port** of updated G4 pattern editor to web
  - [ ] Support G3 (8×8), G4/G4.1 (16×16), G6 (20×20) — skip G5
  - [ ] Maybe add 3D preview integration
  - [ ] Export as GIF files or MPGs
  - [ ] CI/CD validation

### Done Criteria
- [ ] MATLAB pattern editor generates valid patterns for G3, G4, G4.1, G6
- [ ] TCP migration testing complete with documented limits
- [ ] Web pattern editor functional for multi-panel arena patterns

---

## Backlog (Prioritized)

### High Priority

1. **Unified Arena Config Implementation**
   - MATLAB struct ↔ JSON bidirectional conversion
   - Web tools read/write same format
   - Pre-defined standard configs (G6_2x10_full, G6_2x8_flight, etc.)

2. **Update webDisplayTools Landing Page**
   - Reflect current roadmap status (what's complete vs placeholder)
   - Update tool descriptions and status badges
   - Add links to documentation / roadmap
   - Clarify consolidated pattern editor plan

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

### Medium Priority

5. **Plugin System Foundation**
   - Define plugin interface in YAML experiment files
   - LEDController.m integration (backlight)
   - BIAS camera integration (existing code)
   - NI DAQ temperature logging

6. **Experiment Designer (Web)**
   - YAML-based experiment configuration
   - Trial sequence builder
   - Export for MATLAB execution

7. **Pure MATLAB Exploration**
   - TCP: `tcpclient` migration (in progress)
   - Camera: Evaluate Image Acquisition Toolbox vs BIAS
   - Create experimental branches for testing

### Low Priority (Future)

8. **3D Arena Visualization Enhancements**
   - Load custom patterns from file
   - Angular resolution histogram (per-pixel calculation)
   - Export 3D models for CAD

9. **Pattern Visualization & Export**
   - Export patterns as images (PNG), GIFs, or movies (MP4)
   - Pattern "icon" representations for libraries/catalogs:
     - Unrolled flat view (full arena unwrapped)
     - 3D perspective views (above, behind, 3/4 angle)
     - Static thumbnails for pattern browsers
     - Dynamic/animated icons with motion blur to indicate temporal patterns
   - Useful for documentation, papers, pattern selection UIs

10. **G6 Protocol v2+ Features**
    - PSRAM pattern storage
    - TSI file generation
    - Mode 1 support

11. **App Designer Migration**
    - Evaluate only after GUIDE version is stable
    - Would enable better cross-platform support

---

## Architecture Decisions

### Arena Config vs Rig Config

**Arena Config** — Pattern-specific, standalone document:
```json
{
  "format_version": "1.0",
  "generation": "G6",
  "num_rows": 2,
  "num_cols": 10,
  "panels_installed": [1,2,3,4,5,6,7,8],
  "orientation": "normal"
}
```

**Rig Config** — Hardware-specific, embeds arena config:
```json
{
  "format_version": "1.0",
  "rig_name": "Fly Arena 1",
  "ip_address": "10.102.40.47",
  "sd_drive_letter": "E",
  "arena": {
    "generation": "G6",
    "num_rows": 2,
    "num_cols": 10,
    "panels_installed": [1,2,3,4,5,6,7,8],
    "orientation": "normal"
  },
  "plugins": {
    "led_controller": { ... },
    "camera": { ... }
  }
}
```

**Rationale**: Arena config is needed standalone for pattern design. Once you have a rig, you know the arena configuration, so rig config embeds arena. Both can exist as separate documents.

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
│   │   ├── G6_2x10_full.yaml
│   │   ├── G6_2x8_walking.yaml
│   │   ├── G41_2x12_ccw.yaml
│   │   └── ... (9 configs total)
│   └── rigs/                # Rig configs (reference arena YAML)
│       ├── test_rig_1.yaml
│       └── ...
├── controller/              # PanelsController, TCP code
├── docs/
│   ├── G4G6_ROADMAP.md      # This file
│   ├── arena_config_spec.md # Arena config JSON schema
│   ├── pattern_testing/     # Regression test patterns & plan
│   └── arena-designs/       # PDF exports, reference_data.json
├── examples/
│   ├── test_patterns/       # SD card test patterns (20)
│   └── test_patterns_100/   # Two-digit patterns (00-99)
├── utils/
│   ├── design_arena.m       # Arena geometry (with column_order)
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
| 2026-01-24 (PM) | Web tools UI redesign complete. Arena configs now single source of truth. Created 9 standard arena YAML configs in maDisplayTools. CI/CD workflow syncs configs to webDisplayTools. Arena editor & 3D viewer redesigned with config dropdowns. Updated LED specs with accurate dimensions (G3: 3mm round, G4: 1.9mm round, G4.1: 0603 SMD, G6: 0402 SMD). Fixed 3D viewer label positioning. Node v24.12.0, Three.js 0.182.0 (both current). |
| 2026-01-24 | Sprint 1 COMPLETE. Added Active Branches section. TCP migration partial (PanelsControllerNative works, needs more testing). Experiment workflow complete (PR open). Updated Sprint 2 priorities: Arena Config P1 (with audit steps), webDisplayTools P2, Pattern Editor P3, Branch Reconciliation P4 (goal: complete items to main). GUI deferred. Sprint 3: Large pattern = many frames, web editor = direct port of MATLAB + GIF/MPG export. Remove G5 from valid arenas. Pattern index convention agreed: (0,0) lower left. |
| 2026-01-23 | G6 Panel Editor CI/CD COMPLETE. Updated encoding to simplified row-major (removed LED_MAP). Created shared g6-encoding.js module. 25 validation tests passing. Sprint 2 P3 marked complete. |
| 2026-01-21 | SD card workflow COMPLETE. Reorganized sprints: Sprint 2 = Arena Config + G4.1 GUI, Sprint 3 = Pattern Editors. Added backlog item for pattern index direction discrepancy. Updated architecture with separate arena/rig config. |
| 2026-01-18 | Initial roadmap created, consolidated from remote_work_plan.md |

# G4/G6 Display Tools Roadmap

> **Living Document** — Update this file every few days as work progresses and priorities shift.
> 
> **Last Updated**: 2026-01-23
> **Next Review**: ~2026-01-27

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

---

## Current Focus (Sprint 1: Jan 21-24)

### 🎯 Primary Goal: TCP Migration & GUI Planning
With SD card workflow complete, focus shifts to TCP migration testing and planning G4.1 control GUI.

### Thursday Lab Session (Jan 23) — PRIORITIES

- [ ] **[P0] TCP Migration Testing**
  - [ ] Create feature branch `feature/tcpclient-migration`
  - [ ] Implement `tcpclient` version of PanelsController
  - [ ] Run Phase 1-3 benchmarks (see `tcp_migration_plan.md`)
  - [ ] Test on actual hardware in lab
  - [ ] Document results, decide go/no-go for merge

- [ ] **[P1] G3 PControl Code Review & Feature List**
  - [ ] Clone [floesche/LED-Display_G3_Software](https://github.com/floesche/LED-Display_G3_Software)
  - [ ] Review `PControl.m` / `PControl.fig` architecture
  - [ ] Generate comprehensive feature list from code
  - [ ] Categorize: implement now / implement later / don't implement
  - [ ] Decision: adapt existing GUIDE code vs fresh App Designer redesign

- [ ] **[P2] Experiment Workflow Integration** (dependent on Lisa)
  - [ ] Update `create_experiment_folder_g41` to call `prepare_sd_card`
  - [ ] Test end-to-end: YAML → SD card → run experiment
  - [ ] Switch to `'UsePatternFolder', true` for production
  - [ ] Awaiting Lisa's update before end of week

### Completed This Sprint
- [x] **Tuesday Lab Session** (Jan 21) — ALL PASSED ✅
  - [x] Resolved `WSACONNRESET` errors (root cause: unparseable files on SD)
  - [x] Tested SD card deployment with known-good patterns
  - [x] Validated `prepare_sd_card.m` end-to-end
  - [x] Tested with Frank/Peter's controller update
  - [x] Generated and tested 100 patterns successfully

---

## Upcoming (Sprint 2: Jan 25-31)

### 🎯 Primary Goal: Arena Config & G4.1 Control GUI

### Tasks

- [ ] **[P1] Arena Config Implementation**
  - [x] Draft JSON schema (see `arena_config_spec.md`) ✅
  - [ ] Implement MATLAB `load_arena_config.m` / `save_arena_config.m`
  - [ ] Update `design_arena.m` to export arena config JSON
  - [ ] Update web arena editor to load/export arena config JSON
  - [ ] Define standard arena configs (G6_2x10_full, G6_2x8_flight, etc.)

- [ ] **[P2] G4.1 Control GUI Development**
  - [ ] Based on Thursday's feature review, begin implementation
  - [ ] Either: adapt G3 PControl GUIDE code, or fresh App Designer build
  - [ ] Core features: pattern selection, gain/offset controls, mode selection
  - [ ] Wrapper around PanelsController.m

- [x] **[P3] G6 Single Panel Editor CI/CD** ✅ COMPLETE
  - [x] Generate MATLAB reference data for g6_panel_editor
  - [x] Implement validation workflow (like arena editor)
  - [x] Add to GitHub Actions

### Done Criteria
- [ ] Arena config JSON loading/saving works in MATLAB and web
- [ ] G4.1 Control GUI prototype functional
- [x] G6 panel editor has CI/CD validation ✅

---

## Sprint 3 (Feb 1-7)

### 🎯 Primary Goal: Unified Pattern Editor (MATLAB + Web)

### Tasks

- [ ] **[P1] Pattern Editor Assessment**
  - [ ] Inventory G4_Pattern_Generator_gui.m features
  - [ ] Identify which features are generation-specific vs universal
  - [ ] Create baseline regression test patterns (before any changes)
  - [ ] Document in `docs/pattern_testing/baseline_inventory.md`

- [ ] **[P2] Update G4_Pattern_Generator_gui.m**
  - [ ] Add generation selector (G3, G4, G4.1, G6) — skip G5
  - [ ] Update pixel grid sizes (8×8, 16×16, 20×20)
  - [ ] Integrate arena config loading
  - [ ] Verify all existing pattern types work for each generation
  - [ ] Run regression tests against baseline patterns

- [ ] **[P3] Web Pattern Editor (Multi-Panel)**
  - [ ] Create unified web pattern editor for full arena patterns
  - [ ] Support G3 (8×8), G4/G4.1 (16×16), G6 (20×20) panel sizes
  - [ ] Arena config integration (auto-set dimensions from loaded config)
  - [ ] Export patterns in appropriate formats per generation
  - [ ] Implement CI/CD validation (MATLAB reference → web validation)

### Done Criteria
- [ ] MATLAB pattern editor generates valid patterns for G3, G4, G4.1, G6
- [ ] Web pattern editor functional for multi-panel arena patterns
- [ ] Regression tests pass (patterns match baseline)
- [ ] CI/CD validation in place for pattern editor

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

4. **Pattern Index Direction Discrepancy**
   - MATLAB and web tools may count rows/columns in opposite directions (0-up vs 0-down)
   - Not a fundamental problem — referencing issue
   - Need to clarify and document convention when consolidating around G6 pattern format
   - Add validation tests to catch any mismatches

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
├── controller/          # PanelsController, TCP code
├── docs/
│   ├── G4G6_ROADMAP.md      # This file
│   ├── arena_config_spec.md # Arena config JSON schema
│   ├── pattern_testing/     # Regression test patterns & plan
│   └── arena-designs/       # PDF exports, reference_data.json
├── examples/
│   ├── test_patterns/       # SD card test patterns (20)
│   └── test_patterns_100/   # Two-digit patterns (00-99)
├── utils/
│   ├── design_arena.m       # Arena geometry
│   ├── prepare_sd_card.m    # SD card deployment
│   └── (arena config functions TBD)
└── logs/                    # MANIFEST logs

webDisplayTools/
├── index.html               # Landing page
├── arena_editor.html        # ✅ Complete
├── arena_3d_viewer.html     # ✅ Complete  
├── g6_panel_editor.html     # ✅ Complete (CI/CD validated)
├── pattern_editor.html      # Placeholder (Sprint 3)
├── experiment_designer.html # Placeholder
├── data/
│   ├── reference_data.json  # MATLAB-generated validation data
│   └── arena_configs/       # Standard arena config JSONs (TBD)
├── js/
│   ├── arena-calculations.js
│   └── g6-encoding.js           # G6 panel encoding module
└── tests/
    ├── validate-arena-calculations.js
    └── validate-g6-encoding.js  # G6 encoding validation
```

---

## Session Notes

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
| 2026-01-23 | G6 Panel Editor CI/CD COMPLETE. Updated encoding to simplified row-major (removed LED_MAP). Created shared g6-encoding.js module. 25 validation tests passing. Sprint 2 P3 marked complete. |
| 2026-01-21 | SD card workflow COMPLETE. Reorganized sprints: Sprint 2 = Arena Config + G4.1 GUI, Sprint 3 = Pattern Editors. Added backlog item for pattern index direction discrepancy. Updated architecture with separate arena/rig config. |
| 2026-01-18 | Initial roadmap created, consolidated from remote_work_plan.md |

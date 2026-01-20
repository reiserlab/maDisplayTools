# G4/G6 Display Tools Roadmap

> **Living Document** — Update this file every few days as work progresses and priorities shift.
> 
> **Last Updated**: 2026-01-18
> **Next Review**: ~2026-01-21 (after Tuesday lab session)

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

## Completed Work (Jan 15-17)

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
- Version 6 (migrated from previous standalone version)

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

### ✅ SD Card Deployment
- `utils/prepare_sd_card.m` — stages patterns for SD card
- Renames to PAT0001.pat, PAT0002.pat, etc.
- Creates MANIFEST.bin (for microcontroller) and MANIFEST.txt (human-readable)
- Saves local log to `logs/`
- Test patterns created in `examples/test_patterns/`

### ✅ Documentation
- `sd_card_deployment_notes.md` — usage guide
- `tcp_migration_plan.md` — pnet → tcpclient migration
- `todo_lab_tuesday.md` — hardware debugging checklist
- `CLAUDE.md` in webDisplayTools — AI assistant guidelines

---

## Current Focus (Sprint 1: Jan 18-24)

### 🎯 Primary Goal: Hardware Validation
Validate SD card → pattern playback pipeline on G4.1 hardware.

### Tasks

- [ ] **[P0] Tuesday Lab Session** (Jan 21)
  - [ ] Resolve `WSACONNRESET` errors (see `todo_lab_tuesday.md`)
  - [ ] Test SD card deployment with known-good patterns
  - [ ] Validate `prepare_sd_card.m` end-to-end
  - [ ] Document any firmware/hardware issues discovered

- [ ] **[P1] Arena Config Spec** (remote work)
  - [x] Draft JSON schema (see `arena_config_spec.md`) ✅
  - [ ] Implement MATLAB `load_arena_config.m` / `save_arena_config.m`
  - [ ] Update `design_arena.m` to export arena config JSON
  - [ ] Update web arena editor to export matching JSON format

- [ ] **[P2] Pattern Editor Assessment**
  - [ ] Inventory G4_Pattern_Generator_gui.m features
  - [ ] Identify which features are generation-specific vs universal
  - [ ] Create baseline regression test patterns (before any changes)
  - [ ] Document in `docs/pattern_testing/baseline_inventory.md`

- [ ] **[P3] G6 MATLAB Pattern Tools**
  - [ ] Locate existing G6 MATLAB pattern code
  - [ ] Move/copy into `maDisplayTools` repo under `G6/` or `utils/patterns/`
  - [ ] Document what exists vs what's missing
  - [ ] Ensure MATLAB tools match web tool outputs

### Done Criteria
- [ ] Can deploy patterns to SD card and play on hardware without errors
- [ ] Arena config JSON spec documented and MATLAB functions working
- [ ] Pattern editor feature inventory complete
- [ ] G6 MATLAB code located and organized

---

## Upcoming (Sprint 2: Jan 25-31)

### 🎯 Primary Goal: Pattern Editor Refactor (Phase 1)

### Tasks

- [ ] **[P1] Update G4_Pattern_Generator_gui.m**
  - [ ] Add generation selector (G3, G4, G4.1, G6) — skip G5
  - [ ] Update pixel grid sizes (8×8, 16×16, 20×20)
  - [ ] Verify all existing pattern types work for each generation
  - [ ] Run regression tests against baseline patterns

- [ ] **[P2] TCP Migration Testing**
  - [ ] Create feature branch `feature/tcpclient-migration`
  - [ ] Implement `tcpclient` version of PanelsController
  - [ ] Run Phase 1-3 benchmarks (see `tcp_migration_plan.md`)
  - [ ] Document results, decide go/no-go for merge

- [ ] **[P3] Web Pattern Editor (Single Panel)**
  - [ ] Consolidate g6_panel_editor into unified panel editor
  - [ ] Support G3 (8×8), G4/G4.1 (16×16), G6 (20×20)
  - [ ] Add "load arena config" to set defaults
  - [ ] Implement CI/CD validation (like arena editor)

### Done Criteria
- [ ] Pattern editor generates valid patterns for G3, G4, G4.1, G6
- [ ] Regression tests pass (patterns match baseline)
- [ ] TCP migration benchmarks documented

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
   - Clarify consolidated pattern editor plan (not separate G4.1/G6)

3. **Pattern Editor: Multi-Panel Support**
   - Extend web editor for full arena patterns
   - Arena config integration (auto-set dimensions)
   - Export patterns in G4.1 and G6 formats

4. **PControl Revival**
   - Reference: G3 PControl GUI in [floesche/LED-Display_G3_Software](https://github.com/floesche/LED-Display_G3_Software/tree/main/MATLAB%20Code/controller)
   - Clone repo and review `PControl.m` / `PControl.fig` for inspiration
   - Simple UI for pattern preview and mode testing
   - Wrapper around PanelsController.m

5. **G6 Pattern Format Support**
   - Implement G6 .pat file writer (per protocol spec)
   - Panel block formatting with parity
   - Validate against protocol v1 spec

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

### Arena Config
Single JSON format used by all tools (see `arena_config_spec.md`):
```json
{
  "format_version": "1.0",
  "arena": {
    "generation": "G6",
    "num_rows": 2,
    "num_cols": 10,
    "panels_installed": [1,2,3,4,5,6,7,8],
    "orientation": "normal"
  },
  "rig": {
    "ip_address": "10.102.40.47",
    "plugins": { ... }
  }
}
```

### CI/CD Validation Strategy
Established pattern for ensuring MATLAB ↔ Web consistency:
1. MATLAB generates `reference_data.json` with computed values
2. Web tool has matching calculation logic
3. Node.js test compares web calculations to reference (tolerance: 0.0001)
4. GitHub Actions runs on push, fails if calculations diverge

**Implemented for**: Arena Editor
**To implement for**: Pattern Editor, G6 format validation

### Pattern Editor Strategy
1. **GUIDE GUI** (G4_Pattern_Generator_gui.m) — update for all generations
2. **Web Editor** — for simple patterns, cross-platform access
3. **MATLAB backend** — both tools use same pattern generation functions
4. **Regression testing** — automated comparison against baseline patterns

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
│   └── test_patterns/       # SD card test patterns
├── utils/
│   ├── design_arena.m       # Arena geometry
│   ├── prepare_sd_card.m    # SD card deployment
│   └── (arena config functions TBD)
└── logs/                    # MANIFEST logs

webDisplayTools/
├── index.html               # Landing page
├── arena_editor.html        # ✅ Complete
├── arena_3d_viewer.html     # ✅ Complete  
├── g6_panel_editor.html     # ✅ Complete (single panel)
├── g41_pattern_editor.html  # Placeholder
├── g6_pattern_editor.html   # Placeholder (multi-panel)
├── experiment_designer.html # Placeholder
├── data/
│   ├── reference_data.json  # MATLAB-generated validation data
│   └── arena_configs/       # Standard arena config JSONs (TBD)
├── js/
│   └── arena-calculations.js
└── tests/
    └── validate-arena-calculations.js
```

---

## Session Notes

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

**New Items Added**:
- Plugin system (Lisa's work on YAML experiments)
- PControl revival (simple pattern display UI)
- Standard arena configs (G6_2x10_full, G6_2x8_flight, etc.)

**Open Questions**:
- ~~Where is old PControl code?~~ → Found in [floesche/LED-Display_G3_Software](https://github.com/floesche/LED-Display_G3_Software/tree/main/MATLAB%20Code/controller)
- Exact plugin parameters — awaiting Lisa's YAML spec
- G6 protocol v1 firmware status — check with Peter/Will

**G3 PControl Architecture Notes** (for G4.1 GUI reference):
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

**Next Session Goals**:
- Review Tuesday lab results
- Update Sprint 1 completion status
- Adjust Sprint 2 priorities based on findings

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
- `todo_lab_tuesday.md` — Hardware debugging checklist

### Code References
- `G4_Display_Tools/G4_Pattern_Generator/` — Original pattern generator
- `G4_Display_Tools/PControl_Matlab/` — G4 PControl (GUI files may be missing)
- [floesche/LED-Display_G3_Software](https://github.com/floesche/LED-Display_G3_Software) — G3 software including original PControl GUI
- `webDisplayTools/arena_editor.html` — Web arena editor (complete)
- `webDisplayTools/g6_panel_editor.html` — Single panel editor (complete)
- `webDisplayTools/arena_3d_viewer.html` — 3D visualization (complete)

### Hardware
- G6 LED mapping: See protocol spec "LED Mappings" section

---

## Changelog

| Date | Change |
|------|--------|
| 2026-01-18 | Initial roadmap created, consolidated from remote_work_plan.md |

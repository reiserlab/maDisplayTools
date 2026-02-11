# G4/G6 Display Tools Roadmap

> **Living Document** — Update this file every few days as work progresses and priorities shift.
>
> **Last Updated**: 2026-02-10
> **Next Review**: ~2026-02-14
>
> **Note**: Historical details (completed sprints, completed in-flight work) archived in `G4G6_ROADMAP_SESSIONS.md`.

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

## Completed Work (Jan 15 – Feb 4)

> **Archived**: Full details in `G4G6_ROADMAP_SESSIONS.md` under "ARCHIVED ROADMAP SECTIONS"

**Summary of completed milestones:**
- ✅ Web Tools Repository Setup (webDisplayTools, dark theme, fonts)
- ✅ G6 Panel Editor with CI/CD validation (v8)
- ✅ Arena Layout Editor (web + MATLAB)
- ✅ Arena 3D Viewer with .pat file loading
- ✅ SD Card Deployment (tested with 100 patterns)
- ✅ PatternGeneratorApp (App Designer, multi-generation)
- ✅ PatternPreviewerApp (histogram, playback controls)
- ✅ PatternCombinerApp (sequential/mask/split modes)
- ✅ Arena Config YAML system (10 configs, CI/CD sync)
- ✅ Pattern Tools Quick Start Guide
- ✅ G6 encoding tools + CI/CD validation

---

## Sprint 1 & 2 (Jan 21 – Jan 31) — COMPLETED

> **Archived**: Sprint details in `G4G6_ROADMAP_SESSIONS.md`

**Sprint 1** (Jan 21-24): TCP migration testing (partial), experiment workflow fixes, G6 panel CI/CD, Tuesday lab session success.

**Sprint 2** (Jan 27-31): Arena config implementation, webDisplayTools update, PatternGeneratorApp core features.

### Remaining from Sprint 2: Branch Reconciliation

- **Goal**: Get complete, tested items onto `main` and close branches
- **Strategy**: Merge everything that doesn't impact others' work
  - Lisa's code → PR through Lisa
  - PanelController → PR through Frank
- [ ] Merge consolidated arena work to main
- [ ] Port remaining g41-controller-update items to main
- [ ] Reconcile with Lisa's experiment execution system
- [ ] Close stale branches

---

## Near-Term Priorities (Feb 7+)

### ✅ Recently Completed (Feb 7)
- **Tier 1 Testing Suite** — 4 test scripts, 28/28 tests pass
  - GUI launch validation (4 tests)
  - Pattern round-trip validation (6 tests)
  - Fixed G4/G4.1 save test skipping (6 tests)
  - Pattern combiner tests (12 tests)
- **Arena Registry System** — Per-generation namespaces, 4 utility functions
  - ID ranges: G4.1 (8-bit 0-255), G6 (6-bit 0-63)
  - 6 arena configs registered (G4, G41, G6)
- **GitHub #12 Fixed** — Singleton pattern for all 3 GUI apps

### ✅ Completed: Header V2 Implementation (Feb 8)

1. **G6 Header Extension** ✅ COMPLETE
   - [x] Implemented bit-packed arena_id + observer_id in bytes 5-6
   - [x] 4 bits version, 6 bits arena_id, 6 bits observer_id
   - [x] Updated g6_save_pattern.m, created read_g6_header.m
   - [x] Extended header from 17 to 18 bytes (V2 format)

2. **G4.1 Header V2** ✅ COMPLETE
   - [x] Implemented generation + arena_id in bytes 2-3
   - [x] Updated save_pattern.m and maDisplayTools.make_pattern_vector_g4
   - [x] Created write_g4_header_v2.m and read_g4_header.m
   - [x] Maintained full backward compatibility with V1

3. **Header V2 Validation** ✅ COMPLETE
   - [x] Created validate_header_v2.m (8/8 tests passing)
   - [x] Updated load_pat to return generation metadata
   - [x] All 30 Tier 1 tests passing (GUI, round-trip, combiner, header)

**Status**: Implementation complete, automated tests passing. Manual testing started but incomplete - deferred to full round-trip testing with webDisplayTools integration (next priority).

### ✅ Completed: webDisplayTools Header V2 Integration (Feb 10)

1. **Update pat-parser.js + pat-encoder.js** ✅ COMPLETE
   - [x] G4 V2 header parsing (generation_id, arena_id from bytes 2-3)
   - [x] G6 V2 header parsing (arena_id, observer_id from bytes 5-6)
   - [x] Backward compatibility with V1 patterns
   - [x] Encoder always writes V2 headers
   - [x] Arena registry lookup functions in arena-configs.js
   - [x] 55 new test assertions (10 tests), all passing

2. **Round-Trip Validation** (partially complete)
   - [x] MATLAB → Web: V2 patterns load correctly in arena_3d_viewer and pattern_editor
   - [x] Metadata displayed (generation, arena_id, observer_id) in both viewers
   - [x] Web → MATLAB: 8 web-generated patterns load correctly in MATLAB (validate_web_roundtrip.m, 8/8 pass)
   - [ ] Test mixed V1/V2 pattern library

3. **Pattern Editor UX** ✅ COMPLETE
   - [x] Arena dropdown syncs from V2 header arena_id (fixes CW/CCW mismatch)
   - [x] Preview mode: tool panels dim + GENERATE disabled on file load
   - [x] "New" button exits preview mode

4. **Documentation**
   - [ ] Update pattern format documentation
   - [ ] Document V2 header specs in webDisplayTools README

### Deferred / Lower Priority

1. **Arena Config Loading Verification**
   - [ ] Test path-based loading (`load_arena_config('configs/arenas/G6_2x10.yaml')`)
   - [ ] Test filename prefix detection (e.g., `G6_2x10_pattern.pat` → auto-loads config)
   - [ ] Document any issues found

3. **Test Looming & Reverse-Phi Patterns**
   - Branch: `claude/` branch in maDisplayTools
   - [ ] Test looming patterns (expanding disc/square, constant and r/v velocity)
   - [ ] Test reverse-phi patterns (verify correct implementation per literature)
   - [ ] If working → migrate to webDisplayTools

4. **Round-Trip Pattern Validation** (partially complete)
   - **Goal**: Ensure MATLAB ↔ Web pattern compatibility at pixel level
   - **Current coverage** (8 patterns, all passing):
     - [x] G4, G4.1, G6 generations
     - [x] GS2 and GS16 grayscale modes
     - [x] Full and partial arenas (6 arena configs)
     - [x] 4 pattern types (square grating, sine grating, horizontal grating, checkerboard)
     - [x] 16-20 frames per pattern (full-cycle periodic motion)
     - [x] V2 header metadata round-trip (generation, arena_id, dimensions)
   - **Test A: Load compatibility**
     - [x] MATLAB patterns load correctly in web 3D viewer (manual, Feb 10)
     - [x] Web patterns load correctly in MATLAB (`validate_web_roundtrip.m`, 8/8 pass)
     - [x] Pixel values match exactly (deterministic patterns, pixel-by-pixel)
   - **Test B: Generation comparison** (future — requires spherical geometry port)
     - [ ] Generate identical patterns in both tools with same parameters
     - [ ] Numerically compare output (byte-for-byte if possible)
     - [ ] Document any discrepancies
   - **Remaining**:
     - [ ] Expand to 100+ patterns with all pattern types (edge, starfield, rotation, expansion, translation)
     - [ ] Test mixed V1/V2 pattern library
   - **Scripts**:
     - [x] `maDisplayTools/tests/validate_web_roundtrip.m` — MATLAB validator (8 tests)
     - [x] `webDisplayTools/tests/generate-roundtrip-patterns.js` — Reference pattern generator
     - [ ] `webDisplayTools/tests/validate-roundtrip-patterns.js` — Web-side self-check (optional)

   **CI/CD Analysis: Why this is a manual validation step**

   The roundtrip test cannot run in GitHub Actions CI/CD because:
   - The MATLAB side requires a MATLAB license + runtime (not available in GitHub-hosted runners)
   - MATLAB GitHub Actions exist but require MathWorks license server access
   - The test spans two repositories (maDisplayTools + webDisplayTools)

   **What IS in CI/CD** (webDisplayTools):
   - `validate-header-v2.js` — V2 header encode/decode self-test (10 tests, 55 assertions)
   - `validate-g6-encoding.js` — G6 panel encoding validation (25 tests)
   - `validate-pattern-generation.js` — Pattern generation reference comparison (11 tests)
   - The generator script self-verifies (encode → parse → pixel compare) — any encoder regression would fail here

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

5. **maDisplayTools Repo Cleanup & Merge Strategy**
   - **Strategy**: Merge to main in stages, pattern GUIs first
   - **Constraint**: Minimize changes to Lisa's code until fully tested
   - [ ] Phase 1: Pattern tools (PatternGeneratorApp, PatternPreviewerApp, PatternCombinerApp)
   - [ ] Phase 2: Arena config system
   - [ ] Phase 3: SD card tools
   - [ ] Phase 4: Experiment workflow (coordinate with Lisa)
   - [ ] Phase 5: TCP migration (coordinate with Frank)

---

## Sprint 3 (Feb 2-5) — WRAPPING UP

### 🎯 Original Goal: PatternGeneratorApp Feature Parity + TCP Migration Testing

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

> **Archived**: Completed in-flight items (Web Tools Update #0, 3D Viewer Pattern Loading #0a, PatternGeneratorApp #5, Arena Config for Partial Arenas #6, Landing Page #7, Pattern Validation #7, Pattern Save/Load Script #8) moved to `G4G6_ROADMAP_SESSIONS.md`.

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

**Testing Notes** (2026-02-10):
> Tested experiment workflow on `claude/bugfix-trialparams-executor-80r3o` branch. The fixes work but the test infrastructure needs significant improvement. The YAML test files are overly complex and don't reflect realistic experiment configurations. Before doing further development, the test suite needs to be rebuilt with simpler, more practical test data.

**To Pick Up**:
1. Get PR merged (needs Lisa's review)
2. Later: Design arena config integration with experiment system
3. **Simpler, practical test YAML files** — Current test data is overly complex. Need minimal, realistic YAML configs that reflect actual behavioral experiment workflows. Focus on "what would a real experiment look like?" rather than exhaustive edge cases.
4. **Complete test suite** — Build proper unit tests for the experiment YAML system with:
   - Clear, relevant test patterns based on real experiment workflows
   - Defined testing protocol (what to test, how to validate, pass/fail criteria)
   - Coverage of edge cases discovered during hands-on testing
5. **Reduce YAML configuration complexity** — Simplify the YAML configuration structure to be more practical and easier for lab members to write and maintain. Consider flattening nested structures and providing well-documented templates.

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

## Backlog (Prioritized)

> **Archived**: "Why PatternGeneratorApp (Not G4 GUI Update)" moved to `G4G6_ROADMAP_SESSIONS.md`

### High Priority

1. **Cross-Platform SD Card Workflow**
   - Test `prepare_sd_card.m` on macOS
   - Research macOS FAT32 formatting tools
   - Enable develop-on-Mac, run-on-Windows workflow

### Medium Priority

2. **GitHub for Experiment Organization** (under consideration)
   - Version control for experiment configurations
   - Pattern library management with timestamps
   - Could reduce need for SD card copying across platforms
   - Needs design discussion

3. **Plugin System Foundation**
   - Define plugin interface in YAML experiment files
   - LEDController.m integration (backlight)
   - BIAS camera integration (existing code)
   - NI DAQ temperature logging

4. **Experiment Designer (Web)**
   - YAML-based experiment configuration
   - Trial sequence builder
   - Export for MATLAB execution

### Low Priority (Future)

5. **3D Arena Visualization Enhancements**
   - Angular resolution histogram (per-pixel calculation)
   - Export 3D models for CAD
   - Pole location visualization for pitched arenas

6. **Pattern Visualization & Export**
   - Export patterns as images (PNG), GIFs, or movies (MP4)
   - Pattern "icon" representations for libraries/catalogs
   - Static thumbnails, animated icons with motion blur

7. **G6 Protocol v2+ Features**
   - PSRAM pattern storage
   - TSI file generation
   - Mode 1 support

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
| 2026-02-10 (PM) | **Web → MATLAB Roundtrip Validation** — Created cross-platform roundtrip test infrastructure: generate-roundtrip-patterns.js (Node.js, generates 8 deterministic .pat files with self-verification) + validate_web_roundtrip.m (MATLAB, pixel-exact comparison). Test matrix: G4/G4.1/G6 × GS2/GS16 × full/partial arenas × 4 pattern types × 16-20 frames each. All 8/8 tests pass. Documented CI/CD analysis (MATLAB license prevents GitHub Actions; web-side CI covers encoder regressions; manual trigger table for re-runs). Added experiment YAML improvement notes to roadmap (simpler test files, complete test suite, reduce complexity). |
| 2026-02-10 | **webDisplayTools Header V2 + Preview Mode** — Implemented V2 header support in web tools: pat-parser.js auto-detects V1/V2 for G4/G4.1/G6, pat-encoder.js always writes V2, arena-configs.js has registry lookups. Added preview mode to Pattern Editor (dims tools on file load, amber banner, GENERATE disabled). Fixed arena dropdown CW/CCW mismatch using V2 header arena_id for authoritative config lookup. 218 tests across 8 suites, zero regressions. Pattern Editor bumped to v0.9.23. All changes in webDisplayTools repo (3 commits). |
| 2026-02-08 | **Header V2 Implementation Complete** — Implemented G4.1 and G6 Header V2 formats with generation and arena metadata. G4.1: V2 header uses bytes 2-3 for generation_id (3 bits) + arena_id (8 bits). G6: Extended header to 18 bytes with bytes 5-6 for arena_id (6 bits) + observer_id (6 bits). Created write_g4_header_v2.m, read_g4_header.m, read_g6_header.m, validate_header_v2.m (8/8 tests passing). Updated save_pattern.m, g6_save_pattern.m, maDisplayTools loaders. Full backward compatibility with V1 maintained. All 30 Tier 1 tests passing. Manual testing started but incomplete - deferred to round-trip validation with webDisplayTools (next priority). Updated CLAUDE.md with model preference (Opus 4) and MATLAB development guidelines (performance, app design, coding standards). |
| 2026-02-07 | **Tier 1 Testing + Arena Registry + Singleton Pattern** — Created comprehensive Tier 1 test suite: validate_gui_launch.m (4 tests), validate_pattern_round_trip.m (6 tests), fixed G4/G4.1 save test skipping. All 28/28 tests pass. Implemented arena registry system with per-generation namespaces (G4, G41, G6), index.yaml, generations.yaml, 6 symlinked configs, 4 utility functions (get_arena_id/name, get_generation_id/name). Fixed GitHub #12: Added singleton pattern to all 3 GUI apps (prevents multiple instances, shows warning dialog). All implementations tested and passing. |
| 2026-02-05 | **PR Review Session** — Reviewed 3 PRs from colleague: Merged PR #30 (Prettier formatter tooling). Deferred PR #31 (GitHub download fallback) and PR #32 (run formatter) until maDisplayTools branch cleanup. Key issues: PR #31 hardcodes `feature/g6-tools` branch; PR #32 expands minified gif.worker.js from 1 to 885 lines. |
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
| 2026-02-05 | **Documentation compression complete** — Archived completed work to SESSIONS.md. Added Near-Term Priorities section with 5 urgent tasks: arena config verification, close GUIs issue, looming/reverse-phi testing, round-trip validation (100+ patterns), repo cleanup strategy. Added Roadmap Hygiene Rules to webDisplayTools CLAUDE.md. Roadmap reduced from 1,204 to ~817 lines. |
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

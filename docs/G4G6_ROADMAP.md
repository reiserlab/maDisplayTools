# G4/G6 Display Tools Roadmap

> **Living Document** — Update this file as work progresses and priorities shift.
>
> **Last Updated**: 2026-02-14
>
> **Note**: Completed work and detailed session logs archived in `G4G6_ROADMAP_SESSIONS.md`.

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
| `feature/g6-tools` | Main dev branch, G6 tools | Active | Primary development, 202 files changed vs main |
| `claude/switchable-tcp-controller-qQRKM` | TCP migration (pnet vs tcpclient) | Testing | Needs lab time |
| `claude/bugfix-trialparams-executor-80r3o` | YAML experiment workflow fixes | PR open | Needs Lisa's review |
| `yamlSystem` | Lisa's YAML experiment system | Active | Base branch for experiment workflow |
| `g41-controller-update` | Earlier G4.1 work, arena design | Stable | Port remaining items, then close |
| `pcontrol` | PControl GUI work | TBD | Not yet started |

**Branch workflow**: Feature branches → PR → merge to `main`

---

## Current Priorities (Feb 18+)

### Priority 1: Roadmap Cleanup & Issue Triage ✅
- [x] Archive completed sections to SESSIONS.md
- [x] Create GitHub issues for features buried in roadmap text
- [x] Restructure roadmap for clarity

### Priority 2: Pattern Compatibility & Mode 3 Testing ✅
- [x] Root cause found & fixed: Web encoder row header bug (`pat-encoder.js:408`)
- [x] Root cause found & fixed: Web encoder GS16 command byte bug (`pat-encoder.js:414`)
- [x] Fix applied, roundtrip re-validated (8/8 pass)
- [x] Lab test scripts created (`create_lab_test_patterns.m`, `diagnose_web_patterns.m`, `test_mode3.m`)
- [x] Registered G41_2x12_cw in arena registry; removed CCW (not working, irrelevant for G4.1)
- [x] Lab validation: MATLAB + web, GS2 + GS16 — all working on G4.1 CW arena
- [x] Mode 3 (stream position) frame stepping verified working
- [ ] Max Mode 3 streaming rate documentation (deferred — needs dedicated benchmarking)

### Priority 3: Merge-Gate Test Suite
Build a clean, focused test suite that gates `feature/g6-tools` → `main` merge.

**Core tests (must all pass before merge):**
- [ ] MATLAB pattern generation: all generations × GS modes → save → load → pixel-exact
- [ ] Web pattern generation: same patterns → encode → MATLAB load → pixel-exact
- [ ] Raw header byte comparison: web and MATLAB produce byte-identical file headers
- [ ] Simple YAML protocol: load experiment YAML → execute trial sequence → verify
- [ ] App launch: all 3 apps start and close without error

**Cleanup:**
- [ ] Consolidate scattered test files into single `run_merge_gate_tests.m`
- [ ] Remove or archive obsolete test scripts (24+ files, many manual/one-off)
- [ ] Add header V2 tests to web CI (`validate-header-v2.js` — currently manual only)

**Current test inventory** (needs triage):
- MATLAB: 8 automated validators + 16 manual/one-off scripts in tests/, examples/, scripts/
- Web: 5 in CI + 4 manual
- No unified runner, no merge gate

### Priority 4: Repo Cleanup & Merge to Main
- [ ] Phase 1: Pattern tools (PatternGeneratorApp, PatternPreviewerApp, PatternCombinerApp)
- [ ] Phase 2: Arena config system
- [ ] Phase 3: SD card tools
- [ ] Phase 4: Experiment workflow (coordinate with Lisa)
- [ ] Phase 5: TCP migration (coordinate with Frank)
- [ ] Close stale branches
- [ ] Post-merge: Remove deprecated controller functions (`startG41Trial`, other unused legacy methods)

---

## In-Flight Work

These are started projects that need to be picked up and completed.

> **Archived**: Completed in-flight items moved to `G4G6_ROADMAP_SESSIONS.md`.

---

### 1. TCP Migration Testing

**Branch**: `claude/switchable-tcp-controller-qQRKM`

**Status**: Parallel implementations created and basic testing done. More careful testing needed.

**Current State**:
- `PanelsController.m` (pnet) — unchanged, working
- `PanelsControllerNative.m` (tcpclient) — new, basic tests pass
- Both backends perform comparably in benchmarks

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

**Files**: `controller/PanelsControllerNative.m`, `tests/simple_comparison.m`, `tests/benchmark_streaming.m`, `docs/tcp_migration_plan.md`

---

### 2. Experiment Workflow / Lisa's Code

**Branch**: `claude/bugfix-trialparams-executor-80r3o` (PR open)

**Status**: Bugs fixed, PR open for review. Arena config propagation needs discussion.

**Current State**:
- Fixed CommandExecutor trial execution, ProtocolRunner OutputDir, ScriptPlugin.close()
- Comprehensive guide: `docs/experiment_pipeline_guide.md`

**Open Question**: How should arena config propagate through the experiment system? (experiment YAML referencing config vs embedded vs runtime lookup from rig config)

**To Pick Up**:
1. Get PR merged (needs Lisa's review)
2. Design arena config integration with experiment system
3. Rebuild test suite with simpler, practical YAML files reflecting real experiments
4. Simplify YAML configuration structure for lab members

**Files**: `docs/experiment_pipeline_guide.md`, PR changes in branch

---

### 3. Cross-Platform SD Card Workflow

**Status**: Not started. See GitHub issue #16.

**Problem**: We develop/test on Mac but run experiments on Windows. `prepare_sd_card.m` uses Windows-specific path handling.

**To Pick Up**:
1. Research macOS FAT32 formatting tools
2. Test `prepare_sd_card.m` on macOS
3. Consider if git-based experiment organization makes SD copying less critical

---

### 4. Observer Position & Arena Pitch

**Status**: Design discussion needed. Spans both maDisplayTools and webDisplayTools.

**Scope** (broader than original "Previewer pitch bug"):
- **Immediate**: PatternPreviewerApp reads wrong field name for arena pitch (`rotations` instead of `rotations_deg`)
- **Arena coordinate offset**: `angle_offset_deg` is defined in arena configs but ignored by pattern generators (both MATLAB `arena_coordinates.m` and web `arenaCoordinates()`). Fix: apply offset at coordinate level so all pattern types respect the declared zero reference. Workaround: manual phase offset in pattern editor.
- **Full feature**: Register different observer positions (pitch, translation, height), propagate into Pattern Generator UI, store in V2 pattern headers, update arena config schema
- **Web side**: Add observer perspective controls to web tools (arena pitch, observer position)

**Design Questions**:
- Are observer parameters part of arena config, pattern metadata, or runtime-only?
- Should observer position be saved with patterns or be a preview-only setting?
- How does this interact with the existing V2 header observer_id field?

**To Pick Up**: See GitHub issues — maDisplayTools #15, webDisplayTools #40.

**Files**: `patternTools/PatternPreviewerApp.m` (loadArenaConfig), `patternTools/PatternGeneratorApp.m` (pitch handling reference), `configs/arenas/*.yaml`

---

### 5. Branch Reconciliation & Merge to Main

**Status**: Multiple branches with completed work need to be merged.

**Active Branches**:
| Branch | Status | Action |
|--------|--------|--------|
| `feature/g6-tools` | Active dev | Staged merge to main (Priority 3) |
| `claude/switchable-tcp-controller-qQRKM` | Testing | Merge after TCP testing |
| `claude/bugfix-trialparams-executor-80r3o` | PR open | Merge after Lisa's review |
| `yamlSystem` | Lisa's branch | Coordinate with Lisa |
| `g41-controller-update` | Stable | Port useful items, then close |
| `pcontrol` | Not started | Keep for future PControl work |

**Merge Strategy**:
- Merge arena config, pattern tools, SD card tools independently (no impact on others)
- Lisa's code → PR through Lisa
- PanelController → PR through Frank

---

## Known Issues / Technical Debt

### Remaining Validation Work

**Round-trip testing** (8/8 patterns passing):
- [x] G4, G4.1, G6 × GS2/GS16 × full/partial arenas — pixel-exact match
- [x] V2 header metadata round-trip
- [ ] Raw header byte comparison: web and MATLAB encoders must produce byte-identical file headers
- [ ] Expand to 100+ patterns (edge, starfield, rotation, expansion, translation — blocked on needing more pattern types in web generator)
- [ ] Arena config loading verification (path-based, filename prefix detection)

See CLAUDE.md section 6 for test protocol and CI/CD trigger table.

### Open Items

| Issue | Priority | Notes |
|-------|----------|-------|
| `angle_offset_deg` in pattern generation | Medium | Ignored by both MATLAB/web generators; group with observer position (#4) |
| Stretch feature review | Medium | Not consistently implemented/visualized across tools (webDisplayTools #37) |
| Export formats | Low | GIF, MP4, PNG sequence export for web tools (webDisplayTools #38) |
| V2 header documentation | Low | Bit-packing specs not documented (webDisplayTools #39) |

---

## Backlog

### High Priority

1. **Cross-Platform SD Card Workflow** — macOS support for `prepare_sd_card.m` (#16)
2. **Observer Position & Arena Pitch** — Cross-repo feature (#15, webDisplayTools #40)

### Medium Priority

3. **New Pattern Types** — Looming (expanding disc, r/v loom) and reverse-phi (needs literature-based reimplementation). See maDisplayTools #13.
4. **GitHub for Experiment Organization** — Version control for experiment configs, pattern library management
5. **Plugin System Foundation** — LEDController.m, BIAS camera, NI DAQ temperature logging
6. **Experiment Designer (Web)** — YAML-based experiment config, trial sequence builder

### Low Priority (Future)

7. **3D Arena Visualization & Projections** — Mercator/Mollweide views, spherical arena visualization, ray-trace overlay (webDisplayTools #42)
8. **Pattern Export Formats** — GIF, MP4, PNG sequence for web tools (webDisplayTools #38)
9. **G6 Protocol v2+ Features** — PSRAM pattern storage, TSI file generation, Mode 1 support
10. **3D/Spherical Image Dataset Integration** — Natural scene datasets as stimulus templates (webDisplayTools #41)

---

## Future Vision

### Multi-Window MATLAB Architecture

| Window | Purpose | Status |
|--------|---------|--------|
| **Pattern Previewer** | Central hub for viewing/animating patterns | Complete |
| **Pattern Generator** | Standard pattern creation (gratings, starfield, etc.) | Complete |
| **Pattern Combiner** | Combine two patterns (sequential, mask, left/right) | Complete |
| **Drawing App** | Manual pixel-level pattern creation | Web only (not planned for MATLAB) |

> **Note**: The Drawing App exists in webDisplayTools. This is an intentional capability gap — MATLAB focuses on parameterized pattern generation while web tools offer both parameterized and freeform creation.

### Web Tools Port

MATLAB pattern generation is largely complete. Web tools have independent implementations with spherical geometry now fully ported. Key remaining web work:
- Mercator/Mollweide projection views and spherical arena visualization (webDisplayTools #42)
- Observer perspective controls (webDisplayTools #40)
- Pattern export formats (webDisplayTools #38)

### New Pattern Types

Tracked in maDisplayTools #13:
- **Looming** — Expanding disc/square, constant & r/v velocity. MATLAB implementation exists on branch, needs testing + migration to web.
- **Reverse-phi** — Current `make_reverse_phi.m` is incorrect. Needs reimplementation per Anstis 1970, Chubb & Sperling 1988.

---

## Architecture Decisions

### Arena Config vs Rig Config
**Arena Config** — Pattern-specific standalone YAML (`configs/arenas/*.yaml`). Contains generation, grid dimensions, columns_installed, column_order.
**Rig Config** — Hardware-specific YAML (`configs/rigs/*.yaml`). References arena config by filename (not embedded). Contains controller IP/port, SD card path, plugins.
**Rationale**: Arena config needed standalone for pattern design. Rig config references by filename to avoid duplication. YAML chosen over JSON for readability and comments.

### CI/CD Validation Strategy
MATLAB generates `reference_data.json` → Web tool has matching logic → Node.js test compares (tolerance: 0.0001) → GitHub Actions runs on push.
**Implemented for**: Arena Editor, G6 Panel Editor, Pattern Generation, Header V2.

### Pattern Editor Strategy
Dual implementation: MATLAB GUI (PatternGeneratorApp) + Web Editor (pattern_editor.html). Both use spherical projection (MATLAB native, web via arena-geometry.js port). Regression testing via automated comparison against baseline patterns. Arena config integration auto-sets panel dimensions.

### SD Card Deployment Strategy
SD card named "PATSD", FAT32. Patterns written BEFORE manifest files (FAT32 dirIndex order matters). No deduplication. MANIFEST files in root.

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

### Code References
- `G4_Display_Tools/G4_Pattern_Generator/` — Original pattern generator
- `G4_Display_Tools/PControl_Matlab/` — G4 PControl
- [floesche/LED-Display_G3_Software](https://github.com/floesche/LED-Display_G3_Software) — G3 software including original PControl GUI
- `webDisplayTools/` — Arena editor, 3D viewer, panel editor, pattern editor (all complete)

### Hardware
- G6 LED mapping: See protocol spec "LED Mappings" section
- SD card: Must be named "PATSD", FAT32 format

---

## Changelog

| Date | Change |
|------|--------|
| 2026-02-19 | **G4.1 Experiment Patterns & Lab Validation** — Generated 12 experiment patterns (gratings, counters, luminance sweeps) for G41_2x12_cw. Added `project_root()` for cross-platform paths. All patterns validated on hardware. SD card delivered to Peter. |
| 2026-02-18 | **Lab Validation & Bug Fixes** — Validated G4.1 CW arena (GS2+GS16, MATLAB+web, Mode 3). Fixed GS16 command byte bug, `place_digit` return value bug, generator ES6 export stripping. Removed G41 CCW, added 15° angle offset to CW. Logged `angle_offset_deg` gap as known issue (grouped with observer position). Identified need for merge-gate test suite. |
| 2026-02-14 | **MATLAB MCP Session Testing** — Empirically verified MCP server behavior (6 tests): persistent session, shared state across Task agents, no process accumulation. Documented findings in CLAUDE.md. |
| 2026-02-14 | **Row Header Bug Fix + Lab Test Prep** — Fixed web encoder row header bug (root cause of arena display issue). Created lab test scripts (8-pattern suite, Mode 3 tests, byte-level diagnostics). Deprecated `startG41Trial` in favor of `trialParams`. |
| 2026-02-13 | **Pattern Editor v0.9.29 — Button Hierarchy & Discoverability** — Relocated LOAD/NEW to viewer toolbar per user feedback. Established 3-tier visual hierarchy: solid green (GENERATE/LOAD/SAVE), green-outlined (NEW/viewer tabs/frame nav), status indicators (clipboard tabs). |
| 2026-02-11 | **Roadmap Cleanup & Issue Triage** — Archived completed sections to SESSIONS.md, created GitHub issues for tracked features, restructured roadmap (937 → ~450 lines). Marked spherical geometry as complete. Broadened arena pitch to full observer position feature. |
| 2026-02-11 | **Pattern Editor v0.9.26 — UI Polish + Issue Cleanup** — Fixed 3D viewer bugs, vertical filmstrip layout, animated combiner thumbnails. Closed webDisplayTools issues #28, #29. |
| 2026-02-10 (PM) | **Web → MATLAB Roundtrip Validation** — 8/8 test patterns passing (pixel-exact). Cross-platform test infrastructure created. |
| 2026-02-10 | **webDisplayTools Header V2 + Preview Mode** — V2 header support in web tools, preview mode, arena dropdown sync. 218 tests, zero regressions. |
| 2026-02-08 | **Header V2 Implementation Complete** — G4.1 and G6 V2 headers with generation/arena metadata. All 30 Tier 1 tests passing. |
| 2026-02-07 | **Tier 1 Testing + Arena Registry + Singleton Pattern** — 28/28 tests, per-generation arena namespaces, GitHub #12 fixed. |
| 2026-02-05 | **PR Review + Documentation Compression** — Reviewed 3 PRs, archived completed work to SESSIONS.md. |

> Older entries archived in `G4G6_ROADMAP_SESSIONS.md`.

# To-Do List - Lab Testing (Started Tuesday Jan 21, 2025)

## Progress Log

### Tuesday Jan 21, 2025 — COMPLETED ✅

**Step 1: PASSED ✅**
- Power cycled controller
- Connection test (`pc.open`, `allOn`, `allOff`) worked
- Loaded 5 known-good patterns from classic G4 repo manually to SD card (PATSD)
- All 5 displayed correctly using `panelsController.trialParams`
- Confirmed these are G4.1 format (32 rows)

**Step 2: PASSED ✅**
- Created `prepare_sd_card_test.m` (simplified version, writes to SD root, validates PATSD name)
- Root cause identified: Controller uses FAT32 dirIndex (write order), not filenames
- MANIFEST files written before patterns → controller saw them as patterns 1 & 2
- Created unified `prepare_sd_card.m` with options:
  - `'Format', true` — formats SD card for clean FAT32 state (recommended)
  - `'UsePatternFolder', true/false` — patterns in /patterns or root
  - `'ValidateDriveName', true` — requires SD card named PATSD
- Write order fixed: patterns FIRST, then manifests

**Step 3: PASSED ✅**
- Created `create_test_patterns_100.m` — generates 100 two-digit patterns (00-99)
- Uses 4x6 pixel font, two digits per 16x16 panel
- Created `test_sd_card_copy_100.m` — loads patterns in numeric order
- Successfully generated, copied, and ran all 100 patterns on controller!
- Pattern naming convention: `pat0001_num00_2x12.pat` (lowercase)
- Tested with Frank/Peter's controller update — pattern indexing correct!

**Root cause of last week's WSACONNRESET error:**
- Controller encountering unexpected files it couldn't parse (MANIFEST files, leftover FAT32 entries)
- FAT32 delete doesn't fully clear directory entries — controller still saw "ghost" files
- Fix: Format SD card (`'Format', true`) to fully clear FAT32 directory table

**Note on multiple protocols:**
Current implementation intentionally avoids "clever" deduplication. If an experiment uses multiple protocols that reference the same pattern file, that pattern appears multiple times in the cell array and gets copied with different unique pattern IDs. This keeps things simple and provides a straightforward path to supporting multiple protocols per experiment. Lisa doesn't need to worry about complex deduplication logic.

---

## Final Status: ALL STEPS COMPLETED ✅

**SD card workflow fully functional:**
- 100 patterns tested end-to-end
- Controller firmware updated — pattern indexing correct
- Ready for production use

---

## Priority 0: Setup
- [x] Install Claude on the lab PC (claude.ai in browser)
- [x] Formatted SD card as PATSD

## Priority 1: Isolate the Problem
- [x] Step 1: Test with known-good patterns — PASSED
- [x] Step 2: Test SD copy code — PASSED (after fixes)
- [x] Step 3: Test with new patterns — PASSED (100 patterns!)

## Priority 2: Debug Based on Findings
- [x] Root cause identified and fixed (FAT32 dirIndex + format solution)

## Priority 3: Production Ready
- [x] Run full test suite with 100 test patterns
- [x] Document fixes made
- [ ] Update `create_experiment_folder_g41` to call `prepare_sd_card`
- [ ] Test end-to-end: YAML → SD card → run experiment
- [ ] Share with Lisa for integration testing

---

## Remaining Items for Thursday (or future lab day)

### Integration with Experiment Workflow
- [ ] Update `create_experiment_folder_g41` to call `prepare_sd_card`
- [ ] Test with real experiment YAML files
- [ ] Switch to `'UsePatternFolder', true` for production
- [ ] Test end-to-end: YAML → SD card → run experiment

### Share with Team
- [ ] Share `prepare_sd_card.m` with Lisa for integration testing
- [ ] Document the multiple-protocol pattern approach
- [ ] Update roadmap with completed SD card milestone

---

## Quick Reference

**Key files:**
- `utils/prepare_sd_card.m` — main SD copy function (with Format/UsePatternFolder options)
- `examples/create_test_patterns.m` — generates 20 test patterns (digits + gratings)
- `examples/create_test_patterns_100.m` — generates 100 two-digit patterns (00-99)
- `examples/test_sd_card_copy.m` — copies test patterns to SD
- `examples/test_sd_card_copy_100.m` — copies 100 patterns in order
- `controller/PanelsController.m` — hardware communication
- `logs/` — check for recent MANIFEST logs

**GitHub branch:** `g41-controller-update`

**IP address:** `10.102.40.47` (confirmed correct)

**SD card requirements:**
- Named "PATSD"
- FAT32 format
- Use `'Format', true` option for cleanest results

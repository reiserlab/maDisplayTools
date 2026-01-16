# SD Card Deployment - Status Update (Jan 16, 2026)

## What's Done

**New `prepare_sd_card` function** (`utils/file_transfer/prepare_sd_card.m`)
- Takes ordered list of pattern paths
- Renames to `PAT0001.pat`, `PAT0002.pat`, etc.
- Creates `MANIFEST.bin` (pattern count + timestamp for microcontroller)
- Creates `MANIFEST.txt` (human-readable mapping)
- Saves local log to `logs/MANIFEST_YYYYMMDD_HHMMSS.txt`
- Returns mapping struct with success/error status

**Test patterns created** (`examples/test_patterns/`)
- 10 number patterns (0-9, scrolling digits)
- 10 grating patterns (various spatial frequencies)
- All binary (gs_val=2), sized for 2×12 arena

**Documentation** (`docs/sd_card_deployment_notes.md`)
- Quick start guide
- Integration plan with `create_experiment_folder_g41`

## Current Issue

Communication errors occurred when testing patterns from SD card. Unclear if:
- Pattern files have encoding issues
- Controller got into bad state
- SD card write order problem
- Something else

## Next Steps (see to-do list below)

## Integration Plan

The existing `create_experiment_folder_g41` will be updated to:
1. Extract pattern paths from YAML
2. Call `prepare_sd_card()` directly
3. Return mapping for experiment records

This simplifies the workflow: YAML → `prepare_sd_card()` → SD card ready for experiment.

## Microcontroller Side

Needs to read `MANIFEST.bin`:
- Bytes 0-1 (uint16): Pattern count
- Bytes 2-5 (uint32): Unix timestamp

Pattern filenames are predictable: `PAT0001.pat` through `PAT{count}.pat`

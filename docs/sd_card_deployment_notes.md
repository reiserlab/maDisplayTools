---
title: SD Card Deployment
parent: MATLAB Tools
grand_parent: Generation 6
nav_order: 20
---

# SD Card Pattern Deployment - Usage Notes

> **Last Updated**: 2026-02-28
> **Status**: Fully tested with 100 patterns end-to-end on G4.1 hardware. Mac formatting via `diskutil` added.

---

## Quick Start Guide

### Basic Usage (Windows)

```matlab
addpath('/path/to/maDisplayTools/utils');

patterns = {
    '/path/to/horizontal_grating.pat'   % → pat0001.pat
    '/path/to/vertical_stripes.pat'     % → pat0002.pat
    '/path/to/checkerboard.pat'         % → pat0003.pat
};

% Deploy to SD card (recommended: format for clean state)
mapping = prepare_sd_card(patterns, 'E', 'Format', true);
```

### Basic Usage (Mac / Cross-platform)

```matlab
addpath('/path/to/maDisplayTools/utils');
addpath('/path/to/maDisplayTools/tests/fixtures');

patterns = {
    '/path/to/horizontal_grating.pat'
    '/path/to/vertical_stripes.pat'
    '/path/to/checkerboard.pat'
};

% Auto-detect SD card
sd = detect_sd_card();
if sd.found
    mapping = prepare_sd_card_crossplatform(patterns, sd.path, 'Format', true);
else
    fprintf('SD card not found. Candidates: %s\n', sd.candidates);
end
```

### SD Card Requirements

- **Name**: Must be named **"PATSD"** (validated by default)
- **Format**: FAT32
- **Recommendation**: Use `'Format', true` option for cleanest results

### Platform Support

| Feature | Windows | Mac | Linux |
|---------|---------|-----|-------|
| Auto-detect SD card | `detect_sd_card()` scans D:-Z: | `detect_sd_card()` scans /Volumes | Scans /media, /mnt |
| Format SD card | `format X: /FS:FAT32 /V:PATSD /Q /Y` | `diskutil eraseDisk FAT32 PATSD MBRFormat diskN` | Not implemented |
| Pattern deployment | Full: staging → format → ordered copy → MANIFEST | Full: same as Windows | Staging only |
| MANIFEST creation | Yes | Yes | Yes (staging dir) |

---

## Function Options

```matlab
mapping = prepare_sd_card(patterns, drive_letter, Name, Value, ...)
```

| Option | Default | Description |
|--------|---------|-------------|
| `'Format'` | `false` | Format SD card as FAT32 before copying (recommended) |
| `'ValidateDriveName'` | `true` | Require SD card to be named "PATSD" |
| `'StagingDir'` | `tempdir` | Custom staging directory path |

### Examples

```matlab
% Recommended: format drive, patterns in /patterns folder
mapping = prepare_sd_card(patterns, 'E', 'Format', true);

% With custom staging directory (for experiment traceability)
mapping = prepare_sd_card(patterns, 'E', 'Format', true, ...
    'StagingDir', 'C:\Experiments\2026-01-21\patterns');

% Skip drive name validation (not recommended)
mapping = prepare_sd_card(patterns, 'E', 'ValidateDriveName', false);
```

---

## What It Does

1. **Validates SD card** → Checks drive exists and is named "PATSD"
2. **Formats SD card** (if `'Format', true`) → Clean FAT32 state
3. **Renames patterns** → pat0001.pat, pat0002.pat, etc. (lowercase)
4. **Creates MANIFEST.bin** → 6 bytes: uint16 count + uint32 unix timestamp
5. **Creates MANIFEST.txt** → Human-readable mapping of new names to originals
6. **Copies to SD card** → Patterns FIRST, then manifests (order matters!)
7. **Cleans dot-files** (Mac) → Removes `._*` AppleDouble resource fork files
8. **Saves local log** → `maDisplayTools/logs/MANIFEST_YYYYMMDD_HHMMSS.txt`
9. **Verifies** → Confirms pattern count matches (excludes `._*` files)

### SD Card Structure

```
E:\ (PATSD)
├── MANIFEST.bin
├── MANIFEST.txt
└── patterns/
    ├── pat0001.pat
    ├── pat0002.pat
    ├── pat0003.pat
    └── ...
```

---

## Pattern ID Assignment

Pattern IDs are determined by **position in the input cell array**:
- 1st path → pat0001.pat (Pattern ID 1)
- 2nd path → pat0002.pat (Pattern ID 2)
- etc.

### Multiple Protocols Support

The same source file can appear multiple times and will get different IDs each time. This is **intentional design** — it provides a simple path to supporting multiple protocols per experiment without complex deduplication logic.

```matlab
patterns = {
    'grating_01.pat'   % Protocol A uses this as Pattern ID 1
    'grating_02.pat'   % Protocol A uses this as Pattern ID 2
    'grating_01.pat'   % Protocol B uses this as Pattern ID 3 (same file, new ID)
    'checkerboard.pat' % Protocol B uses this as Pattern ID 4
};
```

---

## Return Value

```matlab
mapping.success         % true/false
mapping.error           % error message if failed, empty if success
mapping.timestamp       % '2026-01-21T15:30:00'
mapping.timestamp_unix  % uint32 unix timestamp
mapping.sd_drive        % 'E'
mapping.num_patterns    % number of patterns
mapping.patterns{i}     % struct with .new_name and .original_path
mapping.log_file        % path to local log file
mapping.staging_dir     % path to staging directory
mapping.target_dir      % final location on SD card
```

---

## Why Formatting Matters (FAT32 Technical Details)

### The Problem

The G4.1 controller reads patterns by **FAT32 directory index (dirIndex)**, not by filename. The dirIndex is determined by the **order files are written** to the filesystem.

When you delete files on FAT32:
- The directory entries are marked as "available" but **not cleared**
- New files may fill in old slots unpredictably
- The controller may see "ghost" entries from deleted files

### The Solution

Using `'Format', true`:
1. Completely clears the FAT32 directory table
2. Guarantees patterns get dirIndex 0, 1, 2, ... in write order
3. MANIFEST files written AFTER patterns get higher dirIndex values (ignored by controller)

### Write Order

The function ensures correct write order:
1. **Patterns first** (pat0001.pat, pat0002.pat, ...) → dirIndex 0, 1, 2, ...
2. **MANIFEST.bin** → dirIndex N
3. **MANIFEST.txt** → dirIndex N+1

---

## Troubleshooting

### WSACONNRESET Errors

**Symptom**: MATLAB reports "WSA error: WSACONNRESET" when communicating with controller.

**Root Cause**: The controller encountered files it couldn't parse (MANIFEST files, leftover FAT32 entries, or corrupted patterns) and dropped the connection.

**Solution**:
1. Format the SD card: `prepare_sd_card(patterns, 'E', 'Format', true)`
2. If still failing, manually format in Windows (FAT32, name it "PATSD")
3. Ensure no extra files are on the SD card

### Pattern IDs Off By N

**Symptom**: Pattern ID 1 shows wrong pattern, but ID 3 or higher works correctly.

**Root Cause**: Non-pattern files (MANIFEST, other files) were written before patterns and took the first dirIndex slots.

**Solution**: Use `'Format', true` to ensure clean write order.

### Drive Not Found

**Symptom**: "SD card drive not found: E:"

**Solution**: Check Windows Explorer for correct drive letter, update the call accordingly.

### Drive Name Validation Failed

**Symptom**: "SD card is not named PATSD"

**Solution**: Rename SD card to "PATSD" in Windows/Disk Utility, or use `'ValidateDriveName', false` (not recommended for production).

### Mac: SD Card Not Auto-Detected

**Symptom**: `detect_sd_card()` returns `found = false` on Mac.

**Solution**:
1. Check if the card is mounted: `ls /Volumes/` in Terminal
2. If mounted under a different name, pass the path manually or use `'Label', 'YOURNAME'`
3. If not mounted, try reinserting or use Disk Utility to mount it

### Mac: Format Fails or Times Out

**Symptom**: `diskutil eraseDisk` fails or the volume doesn't remount after formatting.

**Solution**:
1. Format manually in Terminal: `diskutil eraseDisk FAT32 PATSD MBRFormat diskN` (replace `diskN` with your device — find it via `diskutil list external`)
2. Wait 5-10 seconds for remount, then check `ls /Volumes/PATSD`
3. If using an SD card reader, try a different USB port
4. Re-run the deployment script after manual format

### Mac: "Verification failed: expected N, found 2N on SD card"

**Symptom**: `mapping.error` says found double the expected pattern count (e.g., 32 instead of 16).

**Root Cause**: macOS creates hidden `._` resource fork files (AppleDouble format) when copying to FAT32 volumes. MATLAB's `dir('*.pat')` matches these, and — more critically — the G4.1 controller sees them as extra FAT32 directory entries that shift dirIndex ordering.

**Solution**: This is now fixed automatically — `prepare_sd_card_crossplatform` deletes all `._*` files after copying and excludes them from the verification count. If you still see this issue, run in Terminal on the SD card:
```bash
dot_clean /Volumes/PATSD
# or manually:
find /Volumes/PATSD -name '._*' -delete
```

### Mac: Card Passes All Software Tests But Controller Shows No Patterns

**Symptom**: `test_sd_card_deployment` passes, all 16 files are byte-exact vs source, dirIndex order is correct, MANIFEST is valid — but the G4.1 controller shows no patterns.

**Root Cause**: macOS automatically creates hidden system directories (`.Spotlight-V100`, `.fseventsd`) in the FAT32 root immediately upon mounting. These occupy root dirIndex slots and confuse the G4.1 controller firmware. The `._` AppleDouble cleanup handles pattern-level dot files, but these root-level system directories cannot be deleted while the volume is mounted (macOS locks them).

**What we tried (Mar 2 lab test)**:
- Removed `.fseventsd` ✓ (deletable after `mdutil -d` + `mdutil -i off`)
- `.Spotlight-V100` → "Operation not permitted" (locked by macOS, even with Spotlight disabled)
- CrowdStrike endpoint agent further blocks immediate-unmount strategies
- `hdiutil` disk image approach creates a clean FAT32 (no Spotlight dirs!), but `asr restore` doesn't support FAT32 images, and raw `dd`/`mkfs.fat` need root access

**Current Workaround**: **Format and deploy SD cards on Windows.** The Windows-prepared card works perfectly on the G4.1 controller. The Mac-prepared card (same byte-exact patterns) does not.

**Future fix options** (untested):
1. Run MATLAB/script as root to use `mkfs.fat` (from `brew install dosfstools`) for a clean FAT32 format, then mount with `-nobrowse` before copying
2. Use `hdiutil create` → populate image → `dd if=image of=/dev/rdiskN` (needs root)
3. Disable SIP temporarily to allow `.Spotlight-V100` deletion (not recommended on shared lab Macs)
4. Investigate whether the G4.1 controller firmware can be made tolerant of extra root directory entries

**Key finding**: The `prepare_sd_card_crossplatform.m` script, dot-file cleanup, and MANIFEST generation all work correctly on Mac. The ONLY issue is macOS poisoning the FAT32 root directory with undeletable system directories that the G4.1 controller firmware cannot handle.

### Mac: Permission Denied During Format

**Symptom**: "Operation not permitted" or similar error from `diskutil`.

**Solution**: MATLAB must be run with sufficient privileges. Try running the format command directly in Terminal (outside MATLAB) first, then re-run the deployment script with `'Format', false`.

---

## Recommended Workflow: Experiment Folder as Staging Directory

For traceability and data organization, use your experiment folder as the staging directory. This keeps a local copy of exactly what's on the SD card.

### Example

```matlab
% Define experiment folder
experiment_folder = 'C:\Experiments\2026-01-21_gratings';

% Collect pattern paths (from YAML or manual list)
patterns = {
    'C:\Patterns\library\grating_4deg.pat'
    'C:\Patterns\library\grating_8deg.pat'
    'C:\Patterns\library\grating_16deg.pat'
    'C:\Patterns\library\blank.pat'
};

% Stage to experiment folder and copy to SD card
mapping = prepare_sd_card(patterns, 'E', ...
    'Format', true, ...
    'StagingDir', fullfile(experiment_folder, 'patterns'));

if mapping.success
    % Save mapping for experiment records
    save(fullfile(experiment_folder, 'sd_card_mapping.mat'), 'mapping');
    fprintf('Experiment ready!\n');
else
    error('SD card prep failed: %s', mapping.error);
end
```

### Result: Experiment Folder Structure

```
C:\Experiments\2026-01-21_gratings\
├── patterns/
│   ├── pat0001.pat          # Copy of grating_4deg.pat
│   ├── pat0002.pat          # Copy of grating_8deg.pat
│   ├── pat0003.pat          # Copy of grating_16deg.pat
│   ├── pat0004.pat          # Copy of blank.pat
│   ├── MANIFEST.bin         # For microcontroller
│   └── MANIFEST.txt         # Human-readable mapping
├── sd_card_mapping.mat      # MATLAB struct with full mapping
└── protocol.yaml            # Your experiment protocol (if using)
```

### Result: SD Card Structure

```
E:\ (PATSD)
├── MANIFEST.bin
├── MANIFEST.txt
└── patterns/
    ├── pat0001.pat
    ├── pat0002.pat
    ├── pat0003.pat
    └── pat0004.pat
```

The experiment folder contains an exact copy of the SD card contents, plus the mapping struct for programmatic access.

---

## Integration with create_experiment_folder_g41

### Proposed Flow

```
YAML protocol 
    → extract pattern paths (collect_pattern_paths)
    → prepare_sd_card(paths, drive, 'Format', true, 'StagingDir', experiment_folder/patterns)
    → save mapping.mat
    → SD card ready for experiment
```

### Code Sketch

```matlab
function mapping = create_experiment_folder_g41(yaml_file_path, sd_drive, experiment_folder)
    % Load YAML
    experiment_data = yaml.loadFile(yaml_file_path);
    
    % Collect pattern paths in protocol order
    pattern_paths = maDisplayTools.collect_pattern_paths(experiment_data);
    
    % Validate dimensions
    arena_info = experiment_data.arena_info;
    maDisplayTools.validate_all_patterns(pattern_paths, ...
        arena_info.num_rows, arena_info.num_cols);
    
    % Stage to experiment folder and copy to SD card
    staging_dir = fullfile(experiment_folder, 'patterns');
    mapping = prepare_sd_card(pattern_paths, sd_drive, ...
        'Format', true, ...
        'StagingDir', staging_dir);
    
    if ~mapping.success
        error('SD card deployment failed: %s', mapping.error);
    end
    
    % Save mapping for experiment records
    save(fullfile(experiment_folder, 'sd_card_mapping.mat'), 'mapping');
    
    % Copy YAML to experiment folder
    [~, yaml_name, yaml_ext] = fileparts(yaml_file_path);
    copyfile(yaml_file_path, fullfile(experiment_folder, [yaml_name, yaml_ext]));
end
```

---

## Microcontroller Side

The microcontroller reads MANIFEST.bin to get:
- **Bytes 0-1** (uint16): Pattern count
- **Bytes 2-5** (uint32): Unix timestamp of SD card write

Pattern filenames are predictable: `patterns/pat0001.pat` through `patterns/pat{count}.pat`

No filesystem sorting required—just construct filenames from count.

---

## Test Patterns

The reference pattern set for lab testing is at `patterns/reference/G41_2x12_cw/` (16 patterns):

| Generator | Patterns | Description |
|-----------|----------|-------------|
| `tests/create_g41_experiment_patterns.m` | 16 | Gratings, counters, luminance, orientation, web roundtrip |

Test and deploy to SD card with:
```matlab
results = test_sd_card_deployment();               % Quick test (fake SD)
results = test_sd_card_deployment('UseRealSD', true); % Real SD card
```

---

## Changelog

| Date | Change |
|------|--------|
| 2026-03-03 | Removed `UsePatternFolder` option. Patterns are now always placed in `/patterns` subfolder. |
| 2026-03-02 | Lab test: Windows SD card works, Mac SD card fails on G4.1 controller. Root cause: macOS `.Spotlight-V100` in FAT32 root (undeletable). Current recommendation: format on Windows. See troubleshooting section. |
| 2026-03-01 | Fixed macOS dot-file issue: `._*` resource fork files on FAT32 corrupted dirIndex ordering. Now auto-cleaned after copy. Verification count excludes dot-files. |
| 2026-02-28 | Added Mac `diskutil` formatting support. Created `detect_sd_card.m` utility for cross-platform SD detection. Added Mac quick start guide, platform support table, and Mac-specific troubleshooting. Refactored `prepare_g41_experiment_sd.m` to use utilities. |
| 2026-01-21 | Added Format/UsePatternFolder/ValidateDriveName options. Lowercase pattern names. Full 100-pattern testing complete. Added troubleshooting section. |
| 2026-01-16 | Initial version with staging directory workflow. |

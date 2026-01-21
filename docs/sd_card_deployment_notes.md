# SD Card Pattern Deployment - Usage Notes

> **Last Updated**: 2026-01-21
> **Status**: Fully tested with 100 patterns end-to-end on G4.1 hardware

---

## Quick Start Guide

### Basic Usage

```matlab
% Add to path
addpath('/path/to/maDisplayTools/utils');

% Define patterns in desired order
% Position in array = Pattern ID (1st = pat0001, 2nd = pat0002, etc.)
patterns = {
    '/path/to/horizontal_grating.pat'   % → pat0001.pat
    '/path/to/vertical_stripes.pat'     % → pat0002.pat
    '/path/to/checkerboard.pat'         % → pat0003.pat
    '/path/to/horizontal_grating.pat'   % → pat0004.pat (same file, different ID)
};

% Deploy to SD card (recommended: format for clean state)
mapping = prepare_sd_card(patterns, 'E', 'Format', true);

% Check for errors
if ~mapping.success
    fprintf('Error: %s\n', mapping.error);
end
```

### SD Card Requirements

- **Name**: Must be named **"PATSD"** (validated by default)
- **Format**: FAT32
- **Recommendation**: Use `'Format', true` option for cleanest results

---

## Function Options

```matlab
mapping = prepare_sd_card(patterns, drive_letter, Name, Value, ...)
```

| Option | Default | Description |
|--------|---------|-------------|
| `'Format'` | `false` | Format SD card as FAT32 before copying (recommended) |
| `'UsePatternFolder'` | `true` | Put patterns in `/patterns` subfolder (vs root) |
| `'ValidateDriveName'` | `true` | Require SD card to be named "PATSD" |
| `'StagingDir'` | `tempdir` | Custom staging directory path |

### Examples

```matlab
% Recommended: format drive, patterns in /patterns folder
mapping = prepare_sd_card(patterns, 'E', 'Format', true);

% Testing: format drive, patterns in root directory
mapping = prepare_sd_card(patterns, 'E', 'Format', true, 'UsePatternFolder', false);

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
7. **Saves local log** → `maDisplayTools/logs/MANIFEST_YYYYMMDD_HHMMSS.txt`
8. **Verifies** → Confirms pattern count matches

### SD Card Structure (UsePatternFolder=true, default)

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

### SD Card Structure (UsePatternFolder=false)

```
E:\ (PATSD)
├── MANIFEST.bin
├── MANIFEST.txt
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

**Solution**: Rename SD card to "PATSD" in Windows, or use `'ValidateDriveName', false` (not recommended for production).

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

Two test pattern sets are available in `examples/`:

| Script | Patterns | Description |
|--------|----------|-------------|
| `create_test_patterns.m` | 20 | Digits 0-9 (large) + 10 gratings |
| `create_test_patterns_100.m` | 100 | Two-digit numbers 00-99 (small font) |

Copy to SD card with:
```matlab
cd examples
create_test_patterns_100   % Generate patterns (first time only)
test_sd_card_copy_100('E') % Copy to SD card drive E:
```

---

## Changelog

| Date | Change |
|------|--------|
| 2026-01-21 | Added Format/UsePatternFolder/ValidateDriveName options. Lowercase pattern names. Full 100-pattern testing complete. Added troubleshooting section. |
| 2026-01-16 | Initial version with staging directory workflow. |

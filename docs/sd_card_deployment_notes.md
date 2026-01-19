# SD Card Pattern Deployment - Usage Notes

## Quick Start Guide

### Basic Usage

```matlab
% Add to path
addpath('/path/to/maDisplayTools/utils/file_transfer');

% Define patterns in desired order
patterns = {
    '/path/to/horizontal_grating.pat'
    '/path/to/vertical_stripes.pat'
    '/path/to/checkerboard.pat'
};

% Deploy to SD card
mapping = prepare_sd_card(patterns, 'E');

% Check for errors
if ~mapping.success
    fprintf('Error: %s\n', mapping.error);
end
```

### What It Does

1. **Renames patterns** → PAT0001.pat, PAT0002.pat, etc. (in `/patterns/` folder)
2. **Creates MANIFEST.bin** → 6 bytes: uint16 count + uint32 unix timestamp
3. **Creates MANIFEST.txt** → Human-readable mapping of new names to originals
4. **Saves local log** → `maDisplayTools/logs/MANIFEST_YYYYMMDD_HHMMSS.txt`

### Return Value

```matlab
mapping.success         % true/false
mapping.error           % error message if failed, empty if success
mapping.timestamp       % '2026-01-15T15:30:00'
mapping.timestamp_unix  % uint32 unix timestamp
mapping.sd_drive        % 'E'
mapping.num_patterns    % number of patterns
mapping.patterns{i}     % struct with .new_name and .original_path
mapping.log_file        % path to local log file
mapping.staging_dir     % path to staging directory
```

The mapping struct is always returned, even on failure. Check `mapping.success` before using.

---

## Integration with create_experiment_folder_g41

### Current Flow (to be updated)

```
YAML → create_experiment_folder_g41() → experiment folder on PC
```

### Proposed Flow

```
YAML → create_experiment_folder_g41() → prepare_sd_card() → SD card
```

### Integration Steps

1. **Extract pattern paths** from YAML using existing `collect_pattern_paths()`
2. **Call `prepare_sd_card()`** with the collected paths and SD drive
3. **Check `mapping.success`** and handle errors
4. **Store mapping** in the experiment data or save alongside YAML
5. **Remove** the current pattern renaming/copying logic (now handled by `prepare_sd_card`)

### Code Sketch

```matlab
function mapping = create_experiment_folder_g41(yaml_file_path, sd_drive)
    % Load YAML
    experiment_data = yaml.loadFile(yaml_file_path);
    
    % Collect pattern paths in order
    pattern_paths = maDisplayTools.collect_pattern_paths(experiment_data);
    
    % Remove duplicates while preserving order
    [unique_patterns, ~, ~] = unique(pattern_paths, 'stable');
    
    % Validate dimensions (existing code)
    arena_info = experiment_data.arena_info;
    maDisplayTools.validate_all_patterns(unique_patterns, ...
        arena_info.num_rows, arena_info.num_cols);
    
    % Deploy to SD card
    mapping = prepare_sd_card(unique_patterns, sd_drive);
    
    if ~mapping.success
        error('SD card deployment failed: %s', mapping.error);
    end
    
    % Optionally save mapping to experiment record
    experiment_data.sd_card_mapping = mapping;
    yaml.dumpFile('experiment_record.yaml', experiment_data, "block");
end
```

### Key Changes from Current Implementation

| Current | New |
|---------|-----|
| Patterns copied to PC folder | Patterns go directly to SD card |
| Named `pat0001_originalname.pat` | Named `PAT0001.pat` |
| Mapping stored in YAML | Mapping in MANIFEST.txt + returned struct |
| No timestamp tracking | Timestamp in MANIFEST.bin + logs |
| No error handling | Returns success/error in mapping struct |

### Microcontroller Side

The microcontroller reads MANIFEST.bin to get:
- **Bytes 0-1** (uint16): Pattern count
- **Bytes 2-5** (uint32): Unix timestamp of SD card write

Pattern files are predictable: `PAT0001.pat` through `PAT{count}.pat`

No filesystem sorting required—just construct filenames from count.

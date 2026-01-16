# SD Card Pattern Deployment - Usage Notes

## Quick Start Guide

### Basic Usage

```matlab
% Add to path
addpath('/path/to/maDisplayTools/utils');

% Define patterns in desired order
% Position in array = Pattern ID (1st = PAT0001, 2nd = PAT0002, etc.)
patterns = {
    '/path/to/horizontal_grating.pat'   % → PAT0001
    '/path/to/vertical_stripes.pat'     % → PAT0002
    '/path/to/checkerboard.pat'         % → PAT0003
    '/path/to/horizontal_grating.pat'   % → PAT0004 (same file, different ID)
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
5. **Copies to SD card** → Exact copy of staging directory

### Pattern ID Assignment

Pattern IDs are determined by position in the input cell array:
- 1st path → PAT0001.pat
- 2nd path → PAT0002.pat
- etc.

The same source file can appear multiple times and will get different IDs each time (not necessarily recommended, just how it works now). 

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

---

## Recommended Workflow: Experiment Folder as Staging Directory

For traceability and data organization, use your experiment folder as the staging directory. This keeps a local copy of exactly what's on the SD card.

### Example

```matlab
% Define experiment folder
experiment_folder = 'C:\Experiments\2026-01-15_gratings';

% Collect pattern paths (from YAML or manual list)
patterns = {
    'C:\Patterns\library\grating_4deg.pat'
    'C:\Patterns\library\grating_8deg.pat'
    'C:\Patterns\library\grating_16deg.pat'
    'C:\Patterns\library\blank.pat'
};

% Stage to experiment folder and copy to SD card
mapping = prepare_sd_card(patterns, 'E', fullfile(experiment_folder, 'patterns'));

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
C:\Experiments\2026-01-15_gratings\
├── patterns/
│   ├── PAT0001.pat          # Copy of grating_4deg.pat
│   ├── PAT0002.pat          # Copy of grating_8deg.pat
│   ├── PAT0003.pat          # Copy of grating_16deg.pat
│   ├── PAT0004.pat          # Copy of blank.pat
│   ├── MANIFEST.bin         # For microcontroller
│   └── MANIFEST.txt         # Human-readable mapping
├── sd_card_mapping.mat      # MATLAB struct with full mapping
└── protocol.yaml            # Your experiment protocol (if using)
```

### Result: SD Card Structure

```
E:\
├── patterns/
│   ├── PAT0001.pat
│   ├── PAT0002.pat
│   ├── PAT0003.pat
│   └── PAT0004.pat
├── MANIFEST.bin
└── MANIFEST.txt
```

The experiment folder contains an exact copy of the SD card contents, plus the mapping struct for programmatic access.

---

## Integration with create_experiment_folder_g41

### Proposed Flow

```
YAML protocol 
    → extract pattern paths (collect_pattern_paths)
    → prepare_sd_card(paths, drive, experiment_folder/patterns)
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
    mapping = prepare_sd_card(pattern_paths, sd_drive, staging_dir);
    
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

Pattern filenames are predictable: `patterns/PAT0001.pat` through `patterns/PAT{count}.pat`

No filesystem sorting required—just construct filenames from count.

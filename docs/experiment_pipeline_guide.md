---
title: Experimental Pipeline
parent: MATLAB Tools
grand_parent: Generation 6
nav_order: 20
---

# G4.1 Experiment Pipeline Guide

**Last Updated:** 2026-04-03  

**Status:** Implemented and tested on rig

**Dependencies:** Please make sure you have the matlab add-on called yaml by Martin Koch installed. It can be found under Add-ons in the matlab toolbar.

---

## Overview

This document describes the complete pipeline for creating and running G4.1 LED arena experiments, from YAML protocol creation through SD card setup to experiment execution.

---

## Pipeline Steps

### 1. Create YAML Protocol File

**Status:** Manual process. Web tools in production.

#### Creating Your Protocol

1. **Start with a template or example**
   - Example location: `maDisplayTools/examples/yamls/full_experiment_test.yaml`
   - Contains a tested, working protocol with camera and backlight plugins

2. **Organize your files**
   - Create a dedicated folder for your experiment yamls
   - Save the YAML file in this folder
   - Create a dedicated experiment folder to hold the updated yaml and results of this experiment.

3. **Define your experiment**
   - Reference your rig YAML in the `rig:` field
   - Define optional plugins (camera, backlight, etc.)
   - Define experimental conditions in `block`
   - Add optional pretrial, intertrial, and posttrial phases

   For full details on the YAML format, including the arena and rig YAML files, see `yaml_protocol_documentation.md`.

---

### 2. Deploy Experiments to SD Card

**Script:** `deploy_experiments_to_sd.m`  
**Location:** `maDisplayTools/utils/`

#### SD Card Preparation

Before running the script, ensure your SD card is labeled **`PATSD`**. Lab SD cards should already have this label. You can verify and set the label using your operating system's disk utility.

#### Function Call

```matlab
result = deploy_experiments_to_sd(yaml_file_paths, sd_drive, output_dir)
result = deploy_experiments_to_sd(yaml_file_paths, sd_drive, output_dir, staging_dir)
```

**Arguments:**

| Argument | Required | Description | Example |
|----------|----------|-------------|---------|
| `yaml_file_paths` | Yes | String, char, or cell array of YAML file path(s) | `{'exp1.yaml', 'exp2.yaml'}` |
| `sd_drive` | Yes | Drive letter for SD card | `'E'` |
| `output_dir` | Yes | Directory where updated YAML file and results will be saved | `'./experiment_folder'` |
| `staging_dir` | No | Optional custom staging directory path | `'./staging'` |

**Return Value:**

`result` is a struct with fields:
- `result.success` — `true` if the entire process succeeded
- `result.error` — error message if failed, empty string if success
- `result.yaml_files` — cell array of original YAML files processed
- `result.num_patterns` — total unique patterns deployed
- `result.sd_mapping` — mapping struct from `prepare_sd_card()`
- `result.output_yaml_files` — cell array of paths to the new YAML files created

#### What This Script Does

##### 1. **Pattern Extraction**
- Scans all provided YAML files for pattern references
- Uses `pattern_library` field to resolve relative pattern filenames to full paths

##### 2. **Validation**
- Runs `validate_protocol_for_sd_card()` on each YAML before touching the SD card
- ✓ YAML structure and version (must be version 2)
- ✓ Rig configuration resolves and loads cleanly
- ✓ Arena configuration is valid
- ✓ Pattern files exist and match arena dimensions
- ✓ All commands have required fields
- If any YAML fails validation, the script stops before writing anything to the SD card

##### 3. **Pattern Processing**
- Removes duplicate patterns (same file referenced in multiple YAMLs)
- Preserves order of first appearance across all YAML files

##### 4. **SD Card Setup** (via `prepare_sd_card.m`)
- Copies patterns to SD card
- Renames patterns to standardized format: `PAT0001.pat`, `PAT0002.pat`, etc.
- Creates/updates manifest on the SD card

##### 5. **New YAML Files Created**
- **Originals are not modified**
- A new YAML file is created for each input YAML in `output_dir`
- New filename format: `original_name_YYYYMMDD_HHMMSS.yaml`
- New files contain:
  - Updated `pattern_ID` fields matching SD card numbering
  - An added `sd_card_mapping` section recording the pattern mapping for this SD card

**These new YAML files are the ones you use to run experiments** (see Step 3).

#### Example

```matlab
% Single experiment
result = deploy_experiments_to_sd( ...
    'my_experiment.yaml', ...
    'E', ...
    './experiment_folder');

if ~result.success
    fprintf('Error: %s\n', result.error);
else
    fprintf('Ready to run: %s\n', result.output_yaml_files{1});
end

% Multiple experiments
yamls = {'exp1.yaml', 'exp2.yaml', 'exp3.yaml'};
result = deploy_experiments_to_sd(yamls, 'E', './experiment_folder');
```

#### Updates to timestamped YAML produced by deployment step

```yaml

# All pattern IDs updated to match where the pattern is found on the SD card
# protocol otherwise unchanged

# New section added automatically:
sd_card_mapping:
  timestamp: '2026-01-21T14:30:00'
  sd_drive: E
  mappings:
    - original: /original/path/pat0123_vertical_bars.pat
      sd_name: PAT0001.pat
    - original: /original/path/pat0456_checkerboard.pat
      sd_name: PAT0002.pat
```

---

### 3. Eject and Insert SD Card

After `deploy_experiments_to_sd` completes:

1. Safely eject the SD card from your computer
2. Insert it into the Teensy microcontroller attached to the arena

The SD card must be inserted before running `run_protocol`.

---

### 4. Run Experiment

**Script:** `run_protocol.m`  
**Location:** `maDisplayTools/experimentExecution/`

#### Prerequisites

- ✓ SD card prepared with patterns (Step 2 complete)
- ✓ Updated YAML file with `pattern_ID` values (output from Step 2)
- ✓ SD card inserted into Teensy microcontroller
- ✓ Arena and any plugin hardware powered on and connected

#### Function Call

```matlab
run_protocol(protocolFilePath)
run_protocol(protocolFilePath, Name, Value, ...)
```

**Use the YAML file output by `deploy_experiments_to_sd` (the timestamped copy in `output_dir`), not your original YAML.**

#### Required Arguments

| Argument | Type | Description | Example |
|----------|------|-------------|---------|
| `protocolFilePath` | string/char | Path to the updated YAML protocol file from Step 2 | `'./experiment_folder/my_experiment_20260121_143000.yaml'` |

#### Optional Name-Value Arguments

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `'arenaIP'` | string/char | from rig YAML | Override the controller IP address from the rig config |
| `'OutputDir'` | string/char | YAML file's folder | Directory for experiment outputs (logs, metadata) |
| `'Verbose'` | logical | `true` | Enable detailed logging to console |
| `'DryRun'` | logical | `false` | Validate protocol without executing (testing mode) |

#### Usage Examples

**Basic execution (IP comes from rig YAML):**
```matlab
run_protocol('./experiment_folder/my_experiment_20260121_143000.yaml');
```

**Override arena IP:**
```matlab
run_protocol('./experiment_folder/my_experiment_20260121_143000.yaml', ...
             'arenaIP', '10.102.40.61');
```

**With custom output directory:**
```matlab
run_protocol('./experiment_folder/my_experiment_20260121_143000.yaml', ...
             'OutputDir', './data/run_001');
```

**Validation only (no hardware commands):**
```matlab
run_protocol('./experiment_folder/my_experiment_20260121_143000.yaml', ...
             'DryRun', true);
```

**Full customization:**
```matlab
run_protocol('./experiment_folder/my_experiment_20260121_143000.yaml', ...
             'OutputDir', './experiments/exp_20260121', ...
             'Verbose', true, ...
             'DryRun', false);
```

#### What Happens During Execution

1. **Initialization**
   - Parses and validates YAML protocol
   - Initializes logging system
   - Connects to arena hardware (using IP from rig YAML, or `arenaIP` override)
   - Initializes any defined plugins

2. **Trial Generation**
   - Generates trial order based on protocol
   - Applies randomization if enabled
   - Creates trial metadata

3. **Execution Phases**
   - **Pretrial:** Setup and initialization commands (if enabled)
   - **Main Loop:** 
     - Executes each trial condition
     - Runs intertrial commands between trials (if enabled)
     - Logs all commands and timing
   - **Posttrial:** Cleanup and final commands (if enabled)

4. **Finalization**
   - Saves trial order and metadata to output directory
   - Generates experiment summary
   - Closes hardware connections and plugin connections
   - Finalizes log file

---

## Complete Pipeline Example

### Step-by-Step Walkthrough

#### 1. Create Your Protocol

```yaml
# my_experiment.yaml
version: 2

experiment_info:
  name: "Vertical Bar Motion"
  author: "Lisa"
  date_created: "2026-01-21"
  pattern_library: "/Users/lisa/patterns/"

rig: "./configs/rigs/my_rig.yaml"

plugins:
  - name: "camera" #Must match name in rig yaml
    type: "class"
    matlab:
      class: "BiasPlugin"

  - name: "backlight" #Must match name in rig yaml
    type: "class"
    matlab:
      class: "LEDControllerPlugin"

experiment_structure:
  repetitions: 3
  randomization:
    enabled: true
    method: "block"

block:
  conditions:
    - id: "left_motion"
      commands:
        - type: "plugin"
          plugin_name: "camera"
          command_name: "getTimestamp"
        - type: "controller"
          command_name: "trialParams"
          pattern: "vertical_bars.pat"  # Relative to pattern_library
          pattern_ID: 0  # Will be updated by deploy script
          duration: 5
          mode: 2
          frame_index: 1
          frame_rate: 60
          gain: 0
        - type: "wait"
          duration: 5
```

#### 2. Deploy to SD Card

```matlab
% Define your protocol files
protocols = {'/Users/lisa/experiments/exp001/my_experiment.yaml'};

% Define SD card drive letter and where to save updated YAMLs
sd_card = 'E';
output_dir = '/Users/lisa/experiments/exp001/sd_ready';

% Deploy
result = deploy_experiments_to_sd(protocols, sd_card, output_dir);

if result.success
    fprintf('Ready to run: %s\n', result.output_yaml_files{1});
end
```

**Console Output:**
```
=== Extracting patterns from YAML files ===
  my_experiment.yaml: 1 patterns

=== Validating YAML protocols ===
  ✓ my_experiment validated

=== Preparing patterns for SD card ===
Total patterns: 1 (from all YAMLs)
Unique patterns to deploy: 1

=== Deploying to SD card ===
  ...

=== Creating updated YAML files ===
  Created: /Users/lisa/experiments/exp001/sd_ready/my_experiment_20260121_143000.yaml
  Added 1 pattern mappings
  Updated 1 pattern_ID fields

=== Deployment complete ===

Ready to run: /Users/lisa/experiments/exp001/sd_ready/my_experiment_20260121_143000.yaml
```

#### 3. Eject SD Card and Insert into Teensy

Safely eject from your computer, then insert into the Teensy attached to the arena.

#### 4. Run Your Experiment

```matlab
% Use the timestamped YAML from the deploy step, not the original
run_protocol('/Users/lisa/experiments/exp001/sd_ready/my_experiment_20260121_143000.yaml');
```

---

## Troubleshooting

### Common Issues

#### Pattern Files Not Found
**Problem:** Deploy script can't find pattern files  
**Solution:** 
- Check `pattern_library` path is correct
- Verify pattern filenames are exact (case-sensitive on Mac/Linux)
- Use absolute paths if patterns are in multiple locations

#### Validation Fails Before SD Card Write
**Problem:** `deploy_experiments_to_sd` reports validation errors and stops  
**Solution:**
- Read the error messages — they identify exactly which field or file is the problem
- Common causes: missing required fields in YAML, pattern files that don't exist, rig YAML path incorrect, protocol version not set to 2
- Fix the original YAML and re-run deploy

#### SD Card Not Accessible
**Problem:** Script can't write to SD card  
**Solution:**
- Verify SD card is mounted
- Check drive letter is correct (Windows: `'E'`, `'F'`, etc.)
- Ensure SD card is not write-protected
- Check sufficient space is available
- Verify SD card label is `PATSD`

#### Pattern ID Mismatch
**Problem:** Hardware can't find pattern  
**Solution:**
- Verify you are running the timestamped YAML output by `deploy_experiments_to_sd`, not your original YAML
- Re-run `deploy_experiments_to_sd` if the SD card was re-prepared since the last deploy
- Ensure SD card is inserted in Teensy before running experiment

#### Connection Failed
**Problem:** Can't connect to arena hardware  
**Solution:**
- Verify IP address in your rig YAML is correct
- Check arena is powered on and network cable is connected
- Try pinging the IP: `ping 10.102.40.61`
- Use the `'arenaIP'` override in `run_protocol` for one-off testing with a different IP

---

## Best Practices

### YAML Management
- ✓ Keep original YAML files in dedicated yamls folder
- ✓ Use descriptive experiment names
- ✓ Use `pattern_library` for centralized pattern management
- ✓ Don't manually edit `pattern_ID` values or `sd_card_mapping` sections — these are managed by the deploy script
- ✓ Keep your original experiment YAML as the source of truth; the timestamped copy is for a specific SD card

### Experiment Execution
- ✓ Run `DryRun` mode first to validate protocol before committing to hardware
- ✓ Use descriptive `OutputDir` paths
- ✓ Keep `Verbose` enabled during testing
- ✓ Check logs immediately after experiments

**Document Version:** 2.0  
**Last Tested:** 2026-04-03 
**MATLAB Version:** R2019-2020  
**Compatible Systems:** G4.1 LED Arenas

# G4.1 Experiment Pipeline Guide

**Last Updated:** 2026-01-21  
**Status:** Implemented and initial testing (real life testing needed)

---

## Overview

This document describes the complete pipeline for creating and running G4.1 LED arena experiments, from YAML protocol creation through SD card setup to experiment execution.

---

## Pipeline Steps

### 1. Create YAML Protocol File

**Status:** Manual process

#### Creating Your Protocol

1. **Start with a template or example**
   - Example location: `maDisplayTools/examples/SimpleYamlExperimentDemo/`
   - Contains tested, working protocol

2. **Organize your files**
   - Create a dedicated folder for your experiment
   - Save the YAML file in this folder
   - This folder will serve as your `OutputDir` during experiment execution

3. **Define your experiment**
   - Configure arena settings (`arena_info`)
   - Define experimental conditions (`block`)
   - Add optional pretrial, intertrial, posttrial phases
   - Include any required plugins (only script plugins supported so far, more are coming)

#### Recent YAML Format Updates

##### `pattern_library` Field (NEW)

**Location:** `experiment_info` section

**Purpose:** Central location for pattern files

**Usage:**
```yaml
experiment_info:
  name: "My Experiment"
  date_created: "2026-01-21"
  author: "Your Name"
  pattern_library: "/path/to/patterns/"  # ← New field
```

**Benefits:**
- If all patterns are in one location, specify it once in `pattern_library`
- Reference patterns by filename only throughout the rest of the YAML
- Individual patterns can still use absolute paths to override the library location
- So it is still useful when most patterns share a location, but one or two are elsewhere

**Example:**
```yaml
experiment_info:
  pattern_library: "/Users/lisa/patterns/"

# Later in the file:
commands:
  - type: "controller"
    command_name: "startG41Trial"
    pattern: "pat0001_vertical_bars.pat"  # Will look in pattern_library
    
  - type: "controller"
    command_name: "startG41Trial"
    pattern: "/special/location/pat0099_test.pat"  # Absolute path overrides
```

##### `pattern_ID` Field (NEW)

**Location:** All controller commands that use patterns

**Purpose:** Explicit pattern ID for SD card reference

**Why this changed:**
- YAML files are now reusable for setting up multiple SD cards
- Pattern filenames in YAML no longer match SD card IDs

**How it works:**
```yaml
- type: "controller"
  command_name: "startG41Trial"
  pattern: "/path/to/pat0123_my_pattern.pat"  # Original filename
  pattern_ID: 5  # ← Actual ID on SD card (auto-updated by deploy script)
  duration: 2
  mode: 2
```

**Important:**
- You don't need to manually set `pattern_ID` values, you can leave them empty. However, it will not hurt anything if you put in initial values when creating your yaml. 
- The `deploy_experiments_to_sd` script automatically updates these fields
- Each time you redeploy to a new SD card, IDs are recalculated and updated
- The pattern filename remains unchanged for your reference

---

### 2. Deploy Experiments to SD Card

**Script:** `deploy_experiments_to_sd.m`  
**Location:** `maDisplayTools/`

#### Function Call

```matlab
deploy_experiments_to_sd(yamlPaths, sdCardPath)
```

**Arguments:**
- `yamlPaths` - Cell array of paths to YAML protocol files
  - Example: `{'/path/to/exp1.yaml', '/path/to/exp2.yaml'}`
- `sdCardPath` - Path to mounted SD card
  - Example (Windows): `'E'`

#### What This Script Does

##### 1. **Pattern Extraction**
- Scans all provided YAML files
- Extracts unique pattern file paths
- Uses `pattern_library` field to resolve relative paths
- Validates that all pattern files exist

##### 2. **Validation**
- ✓ YAML files exist and are readable
- ✓ Pattern files exist and are accessible
- ✓ Total patterns fit on SD card (checks available space)
- ✓ SD card is mounted and writable
- ✓ File operations permissions are correct

##### 3. **Pattern Processing**
- Removes duplicate patterns (same file referenced multiple times)
- Sorts patterns in order of first appearance across YAML files

##### 4. **SD Card Setup** (via `prepare_sd_card.m`)
- Copies patterns to SD card
- Renames patterns to standardized format: `pat0001.pat`, `pat0002.pat`, etc.
- Creates/updates `manifest.txt` with pattern metadata
- Archives any previous manifest
- Generates pattern mapping: original filename → new SD card filename

##### 5. **YAML Updates**
- Adds `pattern_mapping` section to bottom of each YAML file
- Updates all `pattern_ID` fields to match SD card IDs
- Preserves original pattern paths for reference
- YAML files are now ready for experiment execution

#### Example YAML After Deployment

```yaml
# ... rest of protocol ...

commands:
  - type: "controller"
    command_name: "startG41Trial"
    pattern: "/original/path/pat0003_vertical_bars.pat"
    pattern_ID: 1  # ← Updated by deploy script
    
# New section added automatically:
pattern_mapping:
  description: "Mapping of original pattern paths to SD card filenames"
  timestamp: "2026-01-21T14:30:00"
  mappings:
    - original: "/original/path/pat0123_vertical_bars.pat"
      sd_card: "pat0001_vertical_bars.pat"
      pattern_id: 1
```

---

### 3. Run Experiment

**Script:** `run_protocol.m`  
**Location:** `maDisplayTools/experimentExecution/`

#### Prerequisites

- ✓ SD card prepared with patterns (Step 2 complete)
- ✓ YAML file updated with `pattern_ID` values
- ✓ SD card inserted into Teensy microcontroller
- ✓ Arena hardware powered on and connected

#### Function Call

```matlab
run_protocol(protocolFilePath, arenaIP, Name, Value, ...)
```

#### Required Arguments

| Argument | Type | Description | Example |
|----------|------|-------------|---------|
| `protocolFilePath` | string/char | Path to YAML protocol file | `'./experiments/exp001/protocol.yaml'` |
| `arenaIP` | string/char | IP address of arena controller | `'192.168.1.10'` |

#### Optional Name-Value Arguments

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `'OutputDir'` | string/char | yamlFileLocation | Base directory for experiment outputs (logs, data) |
| `'Verbose'` | logical | `true` | Enable detailed logging to console |
| `'DryRun'` | logical | `false` | Validate protocol without executing (testing mode) |

#### Usage Examples

**Basic execution:**
```matlab
run_protocol('protocol.yaml', '192.168.1.10');
```

**With custom output directory:**
```matlab
run_protocol('protocol.yaml', '192.168.1.10', 'OutputDir', './my_data');
```

**Quiet mode (minimal console output):**
```matlab
run_protocol('protocol.yaml', '192.168.1.10', 'Verbose', false);
```

**Validation only (no hardware commands):**
```matlab
run_protocol('protocol.yaml', '192.168.1.10', 'DryRun', true);
```

**Full customization:**
```matlab
run_protocol('protocol.yaml', '192.168.1.10', ...
             'OutputDir', './experiments/exp_20260121', ...
             'Verbose', true, ...
             'DryRun', false);
```

#### What Happens During Execution

1. **Initialization**
   - Parses and validates YAML protocol
   - Initializes logging system
   - Connects to arena hardware
   - Initializes any defined plugins

2. **Trial Generation**
   - Generates trial order based on protocol
   - Applies randomization if enabled
   - Creates trial metadata

3. **Execution Phases**
   - **Pretrial:** Setup and initialization commands (if defined)
   - **Main Loop:** 
     - Executes each trial condition
     - Runs intertrial commands between trials (if defined)
     - Logs all commands and timing
   - **Posttrial:** Cleanup and final commands (if defined)

4. **Finalization**
   - Saves trial order and metadata in provided output directory
   - Generates experiment summary
   - Closes hardware connections
   - Closes all plugin connections
   - Finalizes log file

---

## Complete Pipeline Example

### Step-by-Step Walkthrough

#### 1. Create Your Protocol

```yaml
# my_experiment.yaml
version: 1

experiment_info:
  name: "Vertical Bar Motion"
  author: "Lisa"
  date_created: "2026-01-21"
  pattern_library: "/Users/lisa/patterns/"

arena_info:
  num_rows: 4
  num_cols: 12
  generation: "G4.1"

experiment_structure:
  repetitions: 3
  randomization:
    enabled: true
    method: "block"

block:
  conditions:
    - id: "left_motion"
      commands:
        - type: "controller"
          command_name: "startG41Trial"
          pattern: "vertical_bars.pat"  # Relative to pattern_library
          pattern_ID: 0  # Will be updated by deploy script
          duration: 5
          mode: 2
          frame_index: 1
          frame_rate: 60
          gain: 0
```

#### 2. Deploy to SD Card

```matlab
% Define your protocol files
protocols = {
    '/Users/lisa/experiments/exp001/my_experiment.yaml',
    '/Users/lisa/experiments/exp002/another_experiment.yaml'
};

% Define SD card drive letter
sd_card = 'E';

% Deploy
deploy_experiments_to_sd(protocols, sd_card);
```

**Console Output:**
```
=== Deploying Experiments to SD Card ===
Found 2 protocol files
Extracting patterns...
  Found 5 unique patterns
Validating...
  ✓ All protocols valid
  ✓ All patterns exist
  ✓ SD card accessible
  ✓ Sufficient space available
Preparing SD card...
  Copying patterns...
  ✓ pat0001_vertical_bars.pat
  ✓ pat0002_horizontal_bars.pat
  ...
Updating protocols...
  ✓ Updated my_experiment.yaml
  ✓ Updated another_experiment.yaml
=== Deployment Complete ===
```

#### 3. Run Your Experiment

```matlab
% Basic execution
run_protocol('/Users/lisa/experiments/exp001/my_experiment.yaml', ...
             '192.168.1.10');
```

**Or with full options:**
```matlab
run_protocol('/Users/lisa/experiments/exp001/my_experiment.yaml', ...
             '192.168.1.10', ...
             'OutputDir', '/Users/lisa/data', ...
             'Verbose', true, ...
             'DryRun', false);
```

---

## Troubleshooting

### Common Issues

#### Pattern Files Not Found
**Problem:** Deploy script can't find pattern files  
**Solution:** 
- Check `pattern_library` path is correct
- Verify pattern filenames are exact (case-sensitive)
- Use absolute paths if patterns are in multiple locations

#### SD Card Not Accessible
**Problem:** Script can't write to SD card  
**Solution:**
- Verify SD card is mounted
- Check path matches your OS (Mac: `/Volumes/...`, Windows: `E:`, `F:`, etc.)
- Ensure SD card is not write-protected
- Check sufficient space available

#### Pattern ID Mismatch
**Problem:** Hardware can't find pattern  
**Solution:**
- Verify SD card was properly prepared with `deploy_experiments_to_sd`
- Check `pattern_ID` values were updated in YAML
- Ensure SD card is inserted in Teensy before running experiment

#### Connection Failed
**Problem:** Can't connect to arena hardware  
**Solution:**
- Verify IP address is correct
- Check arena is powered on
- Ensure network connection
- Try pinging the IP address: `ping 192.168.1.10`

---

## Best Practices

### YAML Management
- ✓ Keep YAML files in dedicated experiment folders
- ✓ Use descriptive experiment names
- ✓ Use `pattern_library` for centralized pattern management
- ✓ Don't manually edit `pattern_ID` values or `pattern_mapping` sections

### Experiment Execution
- ✓ Run `DryRun` mode first to validate protocol
- ✓ Use descriptive `OutputDir` paths
- ✓ Keep `Verbose` enabled during testing
- ✓ Check logs immediately after experiments

**Document Version:** 1.0  
**Last Tested:** 2026-01-21  
**MATLAB Version:** R2019-2020  
**Compatible Systems:** G4.1 LED Arenas

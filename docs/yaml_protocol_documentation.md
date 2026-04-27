---
title: YAML Protocol
parent: MATLAB Tools
grand_parent: Generation 6
nav_order: 20
---

# G4.1 YAML Protocol Documentation

## Overview

This document describes the YAML protocol format for defining G4.1 LED arena experiments. The protocol specifies experiment structure, hardware plugins, and the sequence of commands executed during trials.

Experiments use a **three-tier configuration system**:

| File | Purpose | Travels with... |
|------|---------|----------------|
| **Arena YAML** | Physical arena hardware (panel layout, column order, geometry) | The arena itself |
| **Rig YAML** | Rig-specific setup (IP address, serial ports, camera config) | A single computer/arena setup |
| **Experiment YAML** | Experiment design (conditions, timing, optional plugin overrides) | The experiment |

The experiment YAML references the rig YAML, which in turn references the arena YAML. You only need to create the arena and rig YAMLs once per setup. For each new experiment, you create only the experiment YAML.

---

## Arena YAML

The arena YAML describes the physical LED panel hardware. It is independent of any computer or rig and should be kept with the arena.

```yaml
format_version: "1.0"
name: "G41_2x12_cw"
description: "G4.1 arena, 2 rows x 12 columns, 360 degree, CW, c0 at south"

arena:
  generation: "G4.1"       # Required: "G3", "G4", "G4.1", or "G6"
  num_rows: 2              # Required: Number of panel rows (1-12)
  num_cols: 12             # Required: Number of panel columns (1-24)
  columns_installed: null  # null = all columns installed; list of 0-indexed column indices for partial arenas
  orientation: "normal"    # Optional: "normal" or "inverted"
  column_order: "cw"       # Optional: "cw" (clockwise) or "ccw"; defaults to "cw"
  angle_offset_deg: 15     # Optional: Angular offset of column 0 center in degrees
```

**Field Details:**

- `generation` — Required. Must be one of: `G3`, `G4`, `G4.1`, `G6`.
- `num_rows` — Required. Valid range: 1–12. Warning issued if > 6.
- `num_cols` — Required. Valid range: 1–24. Warning issued if > 18.
- `columns_installed` — For partial arenas (not all columns physically present). Set to `null` for a full arena. For a partial arena, provide a list of **0-indexed** column numbers that are installed, e.g. `[0, 1, 2, 3]`. Pattern dimensions are validated against the installed count, not `num_cols`.
- `orientation` — Optional. Defaults to `normal`. Use `inverted` if the arena is mounted upside-down.
- `column_order` — Optional. `cw` = columns increase clockwise when viewed from above; `ccw` = counterclockwise. Defaults to `cw`.
- `angle_offset_deg` — Optional. Angular offset of the center of column 0, in degrees. Used to account for physical alignment (e.g., `15` means column 0 center is 15° from the reference direction).

---

## Rig YAML

The rig YAML describes a single computer/arena setup. It contains the path to the arena YAML, the controller IP and port, and hardware plugin configuration (camera, backlight, etc.).

```yaml
format_version: "1.0"
name: "Test Rig 1"
description: "Test rig at 10.102.40.61"

arena: "../arenas/G41_2x12_cw.yaml"  # Path to arena YAML (relative or absolute)

controller:
  host: "10.102.40.61"   # Required: IP address of the Teensy controller
  port: 62222            # Optional: TCP port (default: 62222)

plugins:
  backlight:
    enabled: true
    type: "LED Controller"
    port: 'COM6'
  camera:
    enabled: true
    type: "Bias"
    ip: "127.0.0.1"
    port: 5010
    config_path: 'C:\path\to\bias_config.json'
    bias_executable: 'C:\path\to\BIAS\test_gui.exe'
  temperature:
    enabled: false
```

**Field Details:**

- `arena` — Required. Path to the arena YAML file. Can be relative (resolved from the rig YAML's location) or absolute.
- `controller.host` — Required. IP address of the Teensy microcontroller running the arena.
- `controller.port` — Optional. TCP port (default: `62222`).
- `plugins` — Plugin hardware configuration, keyed by plugin name. These settings are merged with the experiment YAML's plugin definitions at runtime. Hardware-specific settings (ports, IPs, executables, config paths) belong here so the experiment YAML stays portable.

The plugin names used here (e.g., `backlight`, `camera`) must match the `name` fields in the experiment YAML's `plugins` section.

---

## Experiment YAML

The experiment YAML contains the experiment design. It references the rig YAML and defines plugins, trial conditions, and phase commands.

### Top-Level Structure

```yaml
version: 2                    # Required: Protocol version number (must be 2)
experiment_info: {...}        # Required: Metadata
rig: "path/to/rig.yaml"      # Required: Path to rig YAML
plugins: [...]                # Optional: Plugin definitions
experiment_structure: {...}   # Required: Repetitions and randomization
pretrial: {...}               # Optional: Pre-experiment setup
block: {...}                  # Required: Main experimental conditions
intertrial: {...}             # Optional: Between-trial reset
posttrial: {...}              # Optional: Post-experiment cleanup
```

---

## Required Experiment YAML Sections

### 1. Experiment Metadata

```yaml
experiment_info:
  name: "My Experiment"                    # Required: Descriptive name
  date_created: "2024-01-15"               # Optional: Creation date
  author: "Research Lab"                   # Optional: Creator name
  pattern_library: "/path/to/patterns"     # Optional: Path to pattern files directory
```

`pattern_library` sets a default directory for pattern file resolution. If a `pattern` field in a command is just a filename (no path separators), the system prepends `pattern_library` to form the full path. A command with an absolute path ignores `pattern_library`.

### 2. Rig Reference

```yaml
rig: "./configs/rigs/my_rig.yaml"
```

Required. Path to the rig YAML file (relative to the experiment YAML's location, or absolute). The rig YAML provides the arena configuration and controller IP — you do not define these in the experiment YAML.

### 3. Experiment Structure

```yaml
experiment_structure:
  repetitions: 3                           # Number of times to repeat block (must be >= 1)
  randomization:
    enabled: true                          # Randomize condition order
    seed: null                             # Random seed (null = random; integer for reproducibility)
    method: "block"                        # Currently only "block" supported
```

### 4. Block (Main Trials)

```yaml
block:
  conditions:
    - id: "condition_1"                    # Unique condition identifier
      commands: [...]                      # List of commands (see Command Types)
    
    - id: "condition_2"
      commands: [...]
```

**Validation:**
- Must contain at least one condition
- Each condition must have a unique `id`
- Each condition must have a `commands` list

---

## Plugin Definitions

Plugins integrate external hardware (cameras, serial devices, custom instruments) into experiments. Three plugin types are supported: **serial_device**, **class**, and **script**.

Hardware-specific settings for built-in plugins (`BiasPlugin`, `LEDControllerPlugin`) are defined in the **rig YAML**. The experiment YAML's plugin definitions specify the class to use and any experiment-specific overrides. If a config field appears in both, the experiment YAML value wins.

### Serial Device Plugin

For simple serial devices controlled by text commands defined in YAML.

```yaml
plugins:
  - name: "second_light"                   # Unique plugin name
    type: "serial_device"                  # Plugin type
    port: "COM6"                           # Serial port (required)
    baudrate: 9600                         # Baud rate (optional, default: 9600)
    critical: true                         # Abort on failure? (optional, default: true)
    commands:                              # Command definitions (required)
      activate: "LED ON\r\n"               # Static command string
      set_power: "POWER %d\r\n"            # Command with integer parameter
      off: "LED OFF\r\n"
```

**Required Fields:**
- `name` - Plugin identifier (referenced in commands)
- `type: "serial_device"`
- `port` - Serial port name (or `port_windows` / `port_posix` for cross-platform)
- `commands` - Struct mapping command names to command strings

**Optional Fields:**
- `baudrate` - Baud rate (default: 9600)
- `critical` - If true, plugin failures abort experiment (default: true)

**Command String Formatting:**
- Static strings: `"LIGHT ON\r\n"`
- Single integer: `"BRIGHT %d\r\n"` (requires `params.value`)
- Multiple integers: `"RGB %d %d %d\r\n"` (requires `params.values` array)
- String parameter: `"SET %s\r\n"` (requires `params.text`)

**Usage Example:**
```yaml
commands:
  - type: "plugin"
    plugin_name: "second_light"
    command_name: "set_power"              # Must match key in plugin's commands
    params:
      value: 50                            # For single %d format specifier
```

### Class Plugin

For complex devices requiring custom MATLAB/Python classes with methods and state management.

```yaml
plugins:
  - name: "camera"                         # Unique plugin name
    type: "class"                          # Plugin type
    matlab:                                # MATLAB-specific (required if using MATLAB)
      class: "BiasPlugin"                  # MATLAB class name
    python:                                # Python-specific (required if using python)
      module: "pyDisplayTools.plugins"     # Python module path
      class: "BiasPlugin"                  # Python class name
    config:                                # Plugin-specific configuration (optional)
      # Experiment-level overrides go here; hardware config lives in rig YAML
```

**Required Fields:**
- `name` - Plugin identifier
- `type: "class"`
- `matlab.class` OR `python.module` and `python.class`

**Optional Fields:**
- `config` - Plugin-specific configuration. Merged with rig YAML plugin config (experiment wins on conflict).

**Class Requirements:**
The plugin class must implement:
```matlab
function obj = MyClass(name, config, logger)  % Constructor
function initialize(obj)                      % Setup/connection
function result = execute(obj, command, params)  % Command execution
function cleanup(obj)                         % Cleanup/disconnection
```

**Available Built-in Class Plugins:**

#### BiasPlugin (Camera Control)

Hardware configuration (ip, port, config_path, bias_executable) is defined in the rig YAML under `plugins.camera`. The experiment YAML `config` section is for optional experiment-level overrides.

```yaml
# In the experiment YAML plugins section:
- name: "camera"
  type: "class"
  matlab:
    class: "BiasPlugin"
  config:                                      # All optional — hardware config is in rig YAML
    saveDir: 'path/to/save/videos'             # Optional: where videos are saved; default is experiment YAML folder
    frame_rate: 100                            # Optional: default 100; warning if outside 10-200
    video_format: "ufmf"                       # Optional: "ufmf" (default) or "avi"
    log_file: "./logs/bias_timestamps.log"     # Optional: default is experiment_folder/logs/<plugin>_<timestamp>.log
    critical: true                             # Optional: default true
```

**BiasPlugin High-Level Commands** (Recommended):
- `startPreview` - Start camera preview without recording
- `startRecording` - Start recording (params: `filename`, optional)
- `stopRecording` - Stop recording, keep camera running
- `stopCapture` - Stop video capture completely
- `saveConfig` - Save config (params: `config_file`, optional if present in rig file)
- `getTimestamp` - Get timestamp and frame count (logged automatically)

**BiasPlugin Low-Level Commands** (Advanced):
- `connect` - Initialize connection (params: `ip`, `port`, optional if they're already provided in rig file)
- `loadConfiguration` - Load config file (params: `config_path`, optional if it's already provided in rig file)
- `enableLogging` - Enable BIAS logging (recording to file)
- `disableLogging` - Disable BIAS logging
- `setVideoFile` - Set output video filename (params: `filename`, optional)
- `startCapture` - Start video capture

**Usage Example (High-Level):**
```yaml
commands:
  - type: "plugin"
    plugin_name: "camera"
    command_name: "startRecording"
    params:
      filename: "trial_001"
```

**Usage Example (Low-Level):**
```yaml
commands:
  # Manual control sequence
  - type: "plugin"
    plugin_name: "camera"
    command_name: "setVideoFile"
    params:
      filename: "trial_001"
  
  - type: "plugin"
    plugin_name: "camera"
    command_name: "enableLogging"
  
  - type: "plugin"
    plugin_name: "camera"
    command_name: "startCapture"
```

**Note on video filenames:** The `filename` parameter names the *folder* the video is saved in, not the video file itself. BIAS generates the video filename automatically. If `filename` is a relative path, the folder is created inside the experiment YAML's location (or `saveDir` if configured). An absolute path controls where the folder is created directly.

#### LEDControllerPlugin (Backlight Control)

The serial port is defined in the rig YAML under `plugins.backlight`. The experiment YAML definition typically needs no `config` block.

```yaml
# In the experiment YAML plugins section:
- name: "backlight"
  type: "class"
  matlab:
    class: "LEDControllerPlugin"
  # config:               # Optional experiment-level overrides
  #   critical: true      # default true
```

**LEDControllerPlugin Commands:**
- `setIRLEDPower` - Set IR LED power (params: `power` 0-100)
- `setRedLEDPower` - Set red LED (params: `power`; optional: `panel_num`, `pattern`)
- `setGreenLEDPower` - Set green LED (params: `power`; optional: `panel_num`, `pattern`)
- `setBlueLEDPower` - Set blue LED (params: `power`; optional: `panel_num`, `pattern`)
- `setVisibleBacklightsOff` - Turn off all visible (non-IR) LEDs (no params)
- `turnOnLED` - Turn on LED
- `turnOffLED` - Turn off LED

For the color LED commands, `panel_num` selects a specific panel (0-indexed), and `pattern` is a string bitmask (e.g., `"1010"`). If `panel_num` is omitted, the command applies to all panels.

**Usage Example:**
```yaml
commands:
  - type: "plugin"
    plugin_name: "backlight"
    command_name: "setIRLEDPower"
    params:
      power: 50
  
  - type: "plugin"
    plugin_name: "backlight"
    command_name: "setRedLEDPower"
    params:
      power: 5
      panel_num: 0        # Optional: specific panel (0-indexed)
      pattern: "1010"     # Optional: bitmask pattern string

   - type: "plugin"
    plugin_name: "backlight"
    command_name: "turnOnLED"   # No params needed

  - type: "plugin"
    plugin_name: "backlight"
    command_name: "setVisibleBacklightsOff"   # No params needed
```

### Script Plugin

For custom MATLAB scripts you want to run during an experiment.

```yaml
plugins:
  - name: "custom_analysis_script"
    type: "script"
    script_path: "./plugins/my_custom_analysis.m"   # Required
    script_type: "function"        # Currently only "function" supported
```

**Required Fields:**
- `name` - Plugin identifier
- `type: "script"`
- `script_path` - Path to .m file

**Optional Fields:**
- `script_type` - Currently only `"function"` supported (default: "function")

**Function Requirements:**
```matlab
function result = myFunction(params)
    % params is a struct containing parameters from YAML
    % result can be any return value
end
```

**Usage Example:**
```yaml
commands:
  - type: "plugin"
    plugin_name: "custom_analysis_script"
    params:                          # Optional params passed to function
      input_value: 42
      filename: "data.txt"
```

---

## Experiment Phases

### Pretrial (Optional)

Commands executed once before the main block begins.

```yaml
pretrial:
  include: true                            # Set false to skip entirely
  commands:
    - type: "controller"
      command_name: "allOn"
    - type: "wait"
      duration: 1
```

### Block (Required)

Main experimental conditions that are repeated and/or randomized.

```yaml
block:
  conditions:
    - id: "condition_1"                    # Unique identifier
      commands: [...]
    - id: "condition_2"
      commands: [...]
```

### Intertrial (Optional)

Commands executed between each trial condition repetition.

```yaml
intertrial:
  include: true
  commands:
    - type: "controller"
      command_name: "allOff"
    - type: "wait"
      duration: 2
```

### Posttrial (Optional)

Commands executed once after the main block completes.

```yaml
posttrial:
  include: true
  commands:
    - type: "controller"
      command_name: "allOff"
    - type: "plugin"
      plugin_name: "camera"
      command_name: "stopCapture"
```

---

## Command Types

### 1. Controller Commands

Send commands to the G4.1 LED arena controller.

```yaml
- type: "controller"
  command_name: "trialParams"              # Command name (required)
  # Additional parameters depend on command
```

**Available Controller Commands:**

- `trialParams`   — Start a pattern trial
  ```yaml
  - type: "controller"
    command_name: "trialParams"
    pattern: "pat0001_vertical_bars.pat"   # Pattern filename (required)
    pattern_ID: 1                          # SD card pattern ID (updated by deploy script)
    mode: 2                                # Display mode: 2, 3, or 4 (required)
    frame_index: 1                         # Starting frame index (required)
    duration: 5                            # Trial duration in seconds (required, must be > 0)
    frame_rate: 60                         # Frames per second (required)
    gain: 0                                # Gain value (required)
  ```

- `allOn` — Turn all panels on
  ```yaml
  - type: "controller"
    command_name: "allOn"
  ```

- `allOff` — Turn all panels off
  ```yaml
  - type: "controller"
    command_name: "allOff"
  ```

- `stopDisplay` — Stop the current display
  ```yaml
  - type: "controller"
    command_name: "stopDisplay"
  ```

- `setPositionX` — Set X position
  ```yaml
  - type: "controller"
    command_name: "setPositionX"
    posX: 0                                # Non-negative number (required)
  ```

- `setColorDepth` — Set grayscale depth
  ```yaml
  - type: "controller"
    command_name: "setColorDepth"
    gs_val: 16                             # Must be 2 or 16 (required)
  ```

- `sendDisplayReset` — Reset the display
  ```yaml
  - type: "controller"
    command_name: "sendDisplayReset"
  ```

- `setFrameRate` — Set frame rate
  ```yaml
  - type: "controller"
    command_name: "setFrameRate"
    fps: 60                                # Frames per second
  ```

- `streamFrame` — Stream a single frame
  ```yaml
  - type: "controller"
    command_name: "streamFrame"
    aox: 0                                 # Analog output X
    aoy: 0                                 # Analog output Y
    frame: [...]                           # Frame data array
  ```

**Mode Descriptions:**
- Mode 2: Position mode (uses `frame_rate`, ignores `gain`)
- Mode 3: Not yet fully documented
- Mode 4: Closed-loop mode (uses `gain`, ignores `frame_rate`)

**Commands Not Yet Implemented:**

The following commands are planned but not yet available in PanelsController:
- `set-refresh-rate` - Set display refresh rate
- `get-ethernet-ip-address` - Get controller IP address
- `ping` - Ping the controller
- `get-controller-info` - Get controller information
- `get-sd-manifest` - Get SD card manifest

**Validation Rules:**
- `mode` must be 2, 3, or 4
- `duration` must be > 0 (warning if > 3600)
- `pattern` must reference a file that exists
- `pattern_ID` is automatically updated during SD card deployment to match the pattern's position on the SD card (1-indexed)

### 2. Plugin Commands

Execute commands on hardware plugins.

```yaml
- type: "plugin"
  plugin_name: "camera"                    # Plugin name (required, must exist in plugins)
  command_name: "startRecording"           # Command name (required)
  params:                                  # Parameters (optional, depends on command)
    filename: "trial_001"
```

**Special Plugin Command - Logging:**
```yaml
- type: "plugin"
  plugin_name: "log"                       # Special built-in logger
  command_name: "log"                      # Always "log"
  params:
    message: "Trial started"               # Log message (required, max 2000 chars)
    level: "INFO"                          # Optional: DEBUG, INFO, WARNING, ERROR
```

**Validation Rules:**
- `plugin_name` must reference a defined plugin (or "log")
- For log commands: `params.message` is required and cannot be empty
- For log commands: `params.level` if provided must be DEBUG, INFO, WARNING, or ERROR

### 3. Wait Commands

**IMPORTANT**

Commands in the yaml will execute as quickly as possible without wait commands to delay them. The durations of your wait commands in a trial must equal your desired trial duration, but they can be split up to control when during the trial different commands execute. See full example to see how this works. 

```yaml
- type: "wait"
  duration: 1.5                            # Duration in seconds (required, must be >= 0)
```

Warning issued if duration > 300 seconds.  # WILL UPDATE THIS TO ISSUE IF DELAYS DONT LINE UP WITH EXPECTED PATTER DURATION 


---

## Pattern Files

Pattern files must:
1. Exist at the path specified in the YAML
2. Match the arena dimensions (`num_rows` × number of installed columns)
3. Be readable .pat binary files

Pattern paths are resolved relative to `experiment_info.pattern_library` if the path contains no directory separator.

**Pattern ID Assignment:**
When patterns are deployed to the SD card, the `pattern_ID` fields in your YAML are automatically updated to match the order patterns appear on the SD card (1-indexed). For example, if `pat0030_vertical.pat` is the 2nd pattern copied to the SD card, its `pattern_ID` will be set to 2, regardless of the original ID in the filename.

**Example:**
```yaml
experiment_info:
  pattern_library: "/home/user/patterns"

# Command references pattern:
pattern: "pat0001_vertical_bars.pat"
# Resolves to: /home/user/patterns/pat0001_vertical_bars.pat
# After SD deployment: pattern_ID will be updated to match SD card position
```

---

## Complete Example

```yaml
version: 2

experiment_info:
  name: "Visual Motion Experiment"
  date_created: "2024-01-15"
  author: "Research Lab"
  pattern_library: "/path/to/patterns"

rig: "./configs/rigs/my_rig.yaml"

plugins:
  - name: "backlight"
    type: "class"
    matlab:
      class: "LEDControllerPlugin"
    # No config needed — port is in the rig YAML

  - name: "camera"
    type: "class"
    matlab:
      class: "BiasPlugin"
    # config:                        # Uncomment to override rig YAML values
    #   video_format: "avi"
    #   frame_rate: 150

experiment_structure:
  repetitions: 3
  randomization:
    enabled: true
    seed: null
    method: "block"

pretrial:
  include: true
  commands:
    - type: "controller"
      command_name: "allOn"

    - type: "wait"
      duration: 1

    - type: "controller"
      command_name: "allOff"

    - type: "plugin"      
      plugin_name: "backlight"
      command_name: "setVisibleBacklightsOff"

    - type: "plugin"
      plugin_name: "backlight"
      command_name: "setIRLEDPower"
      params:
        power: 50

    - type: "plugin"
      plugin_name: "backlight"
      command_name: "turnOnLED"

    - type: "wait"
      duration: 0.5

    - type: "plugin"
      plugin_name: "camera"
      command_name: "startRecording"
      params:
        filename: 'testExperiment'

# ============================================================================
# BLOCK - 16 experiment pattern conditions
# ============================================================================
block:
  conditions:

    - id: "sq_grating_30deg_gs2 - Red turns on during trial and turns off before trial end"
      commands:
        # Getting timestamp at start of trial instead of end for better consistency
        - type: "plugin"
          plugin_name: "camera"
          command_name: "getTimestamp"

        - type: "controller"
          command_name: "trialParams"
          pattern: "pat01_sq_grating_30deg_gs2_G4.pat"
          pattern_ID: 1
          duration: 10
          mode: 2
          frame_index: 1
          frame_rate: 10
          gain: 0

        - type: "wait"
          duration: 3

        - type: "plugin"
          plugin_name: "backlight"
          command_name: "setRedLEDPower"
          params:
            power: 5
            panel_num: 0
            pattern: "1010"

        - type: "wait"
          duration: 4

        - type: "plugin"
          plugin_name: "backlight"
          command_name: "setVisibleBacklightsOff"

        - type: "wait"
          duration: 3

    - id: "sq_grating_30deg_gs16 - Green turns on during trial and remains on for duration"
      commands:

        - type: "plugin"
          plugin_name: "camera"
          command_name: "getTimestamp"

        - type: "controller"
          command_name: "trialParams"
          pattern: "pat02_sq_grating_30deg_gs16_G4.pat"
          pattern_ID: 2
          duration: 10
          mode: 2
          frame_index: 1
          frame_rate: 10
          gain: 0

        - type: "wait"
          duration: 3

        - type: "plugin"
          plugin_name: "backlight"
          command_name: "setGreenLEDPower"
          params:
            power: 5
            panel_num: 0
            pattern: "1010"

        - type: "wait"
          duration: 7

        - type: "plugin"
          plugin_name: "backlight"
          command_name: "setVisibleBacklightsOff"


intertrial:
  include: true
  commands:
    - type: "controller"
      command_name: "allOff"

    - type: "wait"
      duration: 2

posttrial:
  include: true
  commands:
    - type: "controller"
      command_name: "allOff"

    - type: "plugin"
      plugin_name: "backlight"
      command_name: "turnOffLED"

    - type: "plugin"
      plugin_name: "camera"
      command_name: "stopRecording"

    - type: "plugin"
      plugin_name: "camera"
      command_name: "stopCapture"
```

---

## Validation Checklist

Before running an experiment, ensure:

1. **Required sections present:**
   - ✓ `version: 2`
   - ✓ `experiment_info` with at minimum a `name` field
   - ✓ `rig` pointing to a valid rig YAML file
   - ✓ `experiment_structure` with `repetitions` ≥ 1
   - ✓ `block` with at least one condition

2. **Rig and arena configuration valid:**
   - ✓ Rig YAML file exists and is readable
   - ✓ `controller.host` is a valid IP address
   - ✓ Arena YAML file exists and has `generation`, `num_rows`, `num_cols`
   - ✓ `generation` is one of: "G3", "G4", "G4.1", "G6"

3. **All plugins properly defined:**
   - ✓ Each plugin has unique `name`
   - ✓ `serial_device` plugins have `port` and `commands`
   - ✓ `class` plugins have `matlab.class` or `python.module`/`python.class`
   - ✓ `script` plugins have `script_path`
   - ✓ Hardware config (ports, IPs, executables) for built-in plugins is in the rig YAML

4. **All commands valid:**
   - ✓ Controller commands have required parameters
   - ✓ Plugin commands reference existing plugins
   - ✓ Wait commands have valid duration

5. **Pattern files:**
   - ✓ All pattern files exist
   - ✓ Pattern dimensions match arena configuration (rows × installed columns)
   - ✓ Pattern IDs will be automatically updated during SD card deployment

Use `validate_protocol_for_sd_card()` to perform comprehensive validation before deployment.

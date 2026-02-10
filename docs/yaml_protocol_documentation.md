# G4.1 YAML Protocol Documentation

## Overview

This document describes the YAML protocol format for defining G4.1 LED arena experiments. The protocol specifies experiment structure, hardware plugins, and the sequence of commands executed during trials.

---

## YAML Structure

A valid protocol file contains these top-level sections:

```yaml
version: 1                    # Required: Protocol version number
experiment_info: {...}        # Required: Metadata
arena_info: {...}             # Required: Arena hardware configuration
plugins: [...]                # Optional: Hardware plugin definitions
experiment_structure: {...}   # Required: Repetitions and randomization
pretrial: {...}               # Optional: Pre-experiment setup
block: {...}                  # Required: Main experimental conditions
intertrial: {...}             # Optional: Between-trial reset
posttrial: {...}              # Optional: Post-experiment cleanup
```

---

## Required Top-Level Sections

### 1. Experiment Metadata

```yaml
experiment_info:
  name: "My Experiment"                    # Descriptive name
  date_created: "2024-01-15"               # Creation date
  author: "Research Lab"                   # Creator name
  pattern_library: "/path/to/patterns"     # Path to pattern files directory (optional)
```

### 2. Arena Configuration

```yaml
arena_info:
  num_rows: 2                              # Number of panel rows (1-12)
  num_cols: 12                             # Number of panel columns (1-24)
  generation: "G4.1"                       # Arena generation: "G4", "G4.1", or "G6"
```

**Validation:**
- `num_rows` must be 1-12 (warning if > 6)
- `num_cols` must be 1-24 (warning if > 16)
- `generation` must be one of: "G4", "G4.1", "G6"

### 3. Experiment Structure

```yaml
experiment_structure:
  repetitions: 3                           # Number of times to repeat block
  randomization:
    enabled: true                          # Randomize condition order
    seed: null                             # Random seed (null = random; integer for reproducibility)
    method: "block"                        # Currently only "block" supported
```

**Validation:**
- `repetitions` must be ≥ 1

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

Plugins integrate external hardware (cameras, serial devices, custom instruments) into experiments. Three plugin types are supported: **serial**, **class**, and **script**.

### Serial Device Plugin

For simple serial devices controlled by text commands defined in YAML.

```yaml
plugins:
  - name: "background_light"               # Unique plugin name
    type: "serial"                         # Plugin type
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
- `type: "serial"`
- `port` - Serial port name
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
    plugin_name: "background_light"
    command_name: "set_power"              # Must match key in plugin's commands
    params:
      value: 50                            # For single %d format specifier
```

### Class Plugin

For complex devices requiring custom MATLAB/Python classes with methods and state management.

```yaml
plugins:
  - name: "bias_camera"                    # Unique plugin name
    type: "class"                          # Plugin type
    matlab:                                # MATLAB-specific (required if using MATLAB)
      class: "BiasPlugin"                  # MATLAB class name
    python:                                # Python-specific (optional)
      module: "pyDisplayTools.plugins"     # Python module path
      class: "BiasPlugin"                  # Python class name
    config:                                # Plugin-specific configuration (optional)
      bias_executable: "C:/path/to/BIAS/test_gui.exe"
      log_file: "./logs/bias_timestamps.log" (optional, default log location is experiment_folder/logs/<plugin_name>_<timestamp>.log)
      video_extension: ".avi"              
```

**Required Fields:**
- `name` - Plugin identifier
- `type: "class"`
- `matlab.class` OR `python.module` and `python.class`

**Optional Fields:**
- `config` - Plugin-specific configuration passed to constructor

**Class Requirements:**
Your custom class must implement:
```matlab
function obj = MyClass(name, config, logger)  % Constructor
function initialize(obj)                      % Setup/connection
function result = execute(obj, command, params)  % Command execution
function cleanup(obj)                         % Cleanup/disconnection
```

**Available Built-in Class Plugins:**

#### BiasPlugin (Camera Control)
```yaml
- name: "bias_camera"
  type: "class"
  matlab:
    class: "BiasPlugin"
  config:
    bias_executable: "C:/path/to/BIAS/test_gui.exe" # Required
    log_file: "./logs/bias_timestamps.log"     # Optional - default is experiment_folder/logs/<plugin>_<timestamp>.log
    video_extension: ".avi"                    # Optional, default: .avi
    critical: true                             # Optional, default: true
```

**BiasPlugin High-Level Commands** (Recommended):
- `startPreview` - Start camera preview without recording
- `startRecording` - Start recording (params: `filename`)
- `stopRecording` - Stop recording, keep camera running
- `saveConfig` - Save config (params: `config_file`, optional)
- `disconnect` - Disconnect and cleanup

**BiasPlugin Low-Level Commands** (Advanced):
- `connect` - Initialize connection (params: `ip`, `port`)
- `loadConfiguration` - Load config file (params: `config_path`)
- `enableLogging` - Enable BIAS logging (recording to file)
- `disableLogging` - Disable BIAS logging
- `setVideoFile` - Set output video filename (params: `filename`)
- `startCapture` - Start video capture
- `stopCapture` - Stop video capture completely
- `getTimestamp` - Get timestamp and frame count (logged automatically)

**Usage Example (High-Level):**
```yaml
commands:
  - type: "plugin"
    plugin_name: "bias_camera"
    command_name: "startRecording"
    params:
      filename: "trial_001.avi"
```

**Usage Example (Low-Level):**
```yaml
commands:
  # Manual control sequence
  - type: "plugin"
    plugin_name: "bias_camera"
    command_name: "setVideoFile"
    params:
      filename: "trial_001.avi"
  
  - type: "plugin"
    plugin_name: "bias_camera"
    command_name: "enableLogging"
  
  - type: "plugin"
    plugin_name: "bias_camera"
    command_name: "startCapture"
```

#### LEDControllerPlugin (Backlight Control)
```yaml
- name: "backlight"
  type: "class"
  matlab:
    class: "LEDControllerPlugin"
  config:
    port: "COM6"
    critical: true                             # Optional, default: true
```

**LEDControllerPlugin Commands:**
- `setIRLEDPower` - Set IR LED power (params: `power` 0-100)
- `setRedLEDPower` - Set red LED (params: `power`, `power_backoff`, `pattern`)
- `setGreenLEDPower` - Set green LED (params: `power`, `power_backoff`, `pattern`)
- `setBlueLEDPower` - Set blue LED (params: `power`, `power_backoff`, `pattern`)
- `turnOnLED` - Turn on LED
- `turnOffLED` - Turn off LED

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
      power_backoff: 0
      pattern: "1010"
```

### Script Plugin

For executing custom MATLAB functions during experiments.

```yaml
plugins:
  - name: "preprocessing"                  # Unique plugin name
    type: "script"                         # Plugin type
    script_path: "./user_functions/preprocess_data.m"  # Path to .m file (required)
    script_type: "function"                # Currently only "function" supported
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
    plugin_name: "preprocessing"
    params:                                # Optional params passed to function
      input_value: 42
      filename: "data.txt"
```

---

## Trial Structure Sections

### Pretrial (Optional)

Executed once before any trials. Used for hardware initialization.

```yaml
pretrial:
  include: true                            # Enable pretrial (required)
  commands: [...]                          # List of commands
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

Executed between each trial. Used for baseline/reset.

```yaml
intertrial:
  include: true                            # Enable intertrial (required)
  commands: [...]                          # List of commands
```

### Posttrial (Optional)

Executed once after all trials. Used for cleanup and data saving.

```yaml
posttrial:
  include: true                            # Enable posttrial (required)
  commands: [...]                          # List of commands
```

**Note:** When `include: false`, the section is skipped entirely.

---

## Command Types

Three command types can appear in `commands` lists: **controller**, **plugin**, and **wait**.

### 1. Controller Commands

Control the G4.1 LED arena through the PanelsController.

```yaml
- type: "controller"
  command_name: "allOn"                    # Command name (required)
  # Additional parameters depend on command (see below)
```

#### Available Controller Commands

**Basic Commands:**
- `allOn` - Turn all panels on
  ```yaml
  - type: "controller"
    command_name: "allOn"
  ```

- `allOff` - Turn all panels off
  ```yaml
  - type: "controller"
    command_name: "allOff"
  ```

- `stopDisplay` - Stop displaying pattern
  ```yaml
  - type: "controller"
    command_name: "stopDisplay"
  ```

- `setPositionX` - Set starting frame position
  ```yaml
  - type: "controller"
    command_name: "setPositionX"
    posX: 1                                # Frame number (≥ 0)
  ```

- `setColorDepth` - Change grayscale value
  ```yaml
  - type: "controller"
    command_name: "setColorDepth"
    gs_val: 16                             # 2 (binary) or 16 (grayscale)
  ```

**Trial Command (Combined Command):**
- `trialParams` - Display a pattern trial
  ```yaml
  - type: "controller"
    command_name: "trialParams"
    pattern: "pat0001_vertical_bars.pat"   # Pattern filename (required)
    pattern_ID: 1                          # Pattern ID number (required)
    mode: 2                                # Display mode (required): 2, 3, or 4
    frame_index: 1                         # Starting frame (required, ≥ 1)
    duration: 5                            # Duration in seconds (required, > 0)
    frame_rate: 60                         # Frames/sec (required, mode 2 only)
    gain: -90                              # Gain parameter (required, mode 4 only)
  ```

**Mode Descriptions:**
- Mode 2: Position mode (uses `frame_rate`, ignores `gain`)
- Mode 3: Not yet fully documented
- Mode 4: Closed-loop mode (uses `gain`, ignores `frame_rate`)

**Additional Implemented Commands:**

These commands are implemented in PanelsController but have not yet been implemented in the yaml:

- `sendDisplayReset` - Reset the display
  ```yaml
  - type: "controller"
    command_name: "sendDisplayReset"
  ```

- `setFrameRate` - Set frame rate
  ```yaml
  - type: "controller"
    command_name: "setFrameRate"
    fps: 60                                # Frames per second
  ```

- `streamFrame` - Stream a single frame
  ```yaml
  - type: "controller"
    command_name: "streamFrame"
    aox: 0                                 # Analog output X
    aoy: 0                                 # Analog output Y
    frame: [...]                           # Frame data array
  ```

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
  plugin_name: "bias_camera"               # Plugin name (required, must exist in plugins)
  command_name: "startRecording"           # Command name (required)
  params:                                  # Parameters (optional, depends on command)
    filename: "trial_001.avi"
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

Insert delays between commands.

```yaml
- type: "wait"
  duration: 1.5                            # Duration in seconds (required)
```

**Validation Rules:**
- `duration` must be ≥ 0
- Warning if duration > 60 seconds

---

## Pattern Files

Pattern files must:
1. Exist at the path specified in the YAML
2. Match the arena dimensions (`num_rows` × `num_cols`)
3. Be readable .pat binary files

Pattern paths are resolved relative to `experiment_info.pattern_library`.

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
version: 1

experiment_info:
  name: "Visual Motion Experiment"
  date_created: "2024-01-15"
  author: "Research Lab"
  pattern_library: "/path/to/patterns"

arena_info:
  num_rows: 2
  num_cols: 12
  generation: "G4.1"

plugins:
  - name: "backlight"
    type: "serial"
    port: "COM4"
    baudrate: 115200
    commands:
      activate: "LED ON\r\n"
      off: "LED OFF\r\n"
  
  - name: "bias_camera"
    type: "class"
    matlab:
      class: "BiasPlugin"
    config:
      bias_executable: "C:/BIAS/test_gui.exe"

experiment_structure:
  repetitions: 3
  randomization:
    enabled: true
    seed: null
    method: "block"

pretrial:
  include: true
  commands:
    - type: "plugin"
      plugin_name: "backlight"
      command_name: "activate"
    
    - type: "plugin"
      plugin_name: "bias_camera"
      command_name: "connect"
      params:
        ip: "127.0.0.1"
        port: 5010
    
    - type: "wait"
      duration: 1

block:
  conditions:
    - id: "vertical_bars"
      commands:
        - type: "plugin"
          plugin_name: "bias_camera"
          command_name: "startRecording"
          params:
            filename: "vertical_bars.avi"
        
        - type: "controller"
          command_name: "trialParams"
          pattern: "pat0001_vertical_bars.pat"
          pattern_ID: 1
          mode: 2
          frame_index: 1
          duration: 5
          frame_rate: 60
          gain: 0
        
        - type: "plugin"
          plugin_name: "bias_camera"
          command_name: "stopRecording"
    
    - id: "horizontal_bars"
      commands:
        - type: "plugin"
          plugin_name: "bias_camera"
          command_name: "startRecording"
          params:
            filename: "horizontal_bars.avi"
        
        - type: "controller"
          command_name: "trialParams"
          pattern: "pat0002_horizontal_bars.pat"
          pattern_ID: 2
          mode: 2
          frame_index: 1
          duration: 5
          frame_rate: 60
          gain: 0
        
        - type: "plugin"
          plugin_name: "bias_camera"
          command_name: "stopRecording"

intertrial:
  include: true
  commands:
    - type: "controller"
      command_name: "trialParams"
      pattern: "pat0010_baseline.pat"
      pattern_ID: 10
      mode: 2
      frame_index: 1
      duration: 2
      frame_rate: 60
      gain: 0
    
    - type: "wait"
      duration: 0.5

posttrial:
  include: true
  commands:
    - type: "plugin"
      plugin_name: "bias_camera"
      command_name: "disconnect"
    
    - type: "plugin"
      plugin_name: "backlight"
      command_name: "off"
```

---

## Validation Checklist

Before running an experiment, ensure:

1. **Required sections present:**
   - ✓ `version: 1`
   - ✓ `experiment_info` with name, date_created, author, pattern_library
   - ✓ `arena_info` with num_rows, num_cols, generation
   - ✓ `experiment_structure` with repetitions ≥ 1
   - ✓ `block` with at least one condition

2. **Arena configuration valid:**
   - ✓ num_rows: 1-12
   - ✓ num_cols: 1-24
   - ✓ generation: "G4", "G4.1", or "G6"

3. **All plugins properly defined:**
   - ✓ Each plugin has unique `name`
   - ✓ Serial plugins have `port` and `commands`
   - ✓ Class plugins have `matlab.class` or `python.module`
   - ✓ Script plugins have `script_path`

4. **All commands valid:**
   - ✓ Controller commands have required parameters
   - ✓ Plugin commands reference existing plugins
   - ✓ Wait commands have valid duration

5. **Pattern files:**
   - ✓ All pattern files exist
   - ✓ Pattern dimensions match arena configuration
   - ✓ Pattern IDs will be automatically updated during SD card deployment

Use `validate_protocol_for_sd_card()` to perform comprehensive validation before deployment.

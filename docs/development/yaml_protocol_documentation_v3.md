---
title: YAML Protocol
parent: MATLAB Tools
grand_parent: Generation 6
nav_order: 20
---

# G4.1 YAML Protocol Documentation (Version 3)

## Overview

This document describes the Version 3 YAML protocol format for defining G4.1 LED arena experiments. The protocol specifies experiment structure, hardware plugins, and the sequence of conditions executed during an experiment.

Experiments use a **three-tier configuration system**:

| File | Purpose | Travels with... |
|------|---------|----------------|
| **Arena YAML** | Physical arena hardware (panel layout, column order, geometry) | The arena itself |
| **Rig YAML** | Rig-specific setup (IP address, serial ports, camera config) | A single computer/arena setup |
| **Experiment YAML** | Experiment design (conditions library, experiment sequence, optional variables and plugins) | The experiment |

The experiment YAML references the rig YAML, which in turn references the arena YAML. You only need to create the arena and rig YAMLs once per setup. For each new experiment, you create only the experiment YAML.

### What Changed in Version 3

Version 3 replaces the V2 `pretrial` / `block` / `intertrial` / `posttrial` phase structure with a more flexible two-part design:

- A **conditions library** — all named conditions are defined once in a `conditions` list.
- An **experiment sequence** — a readable top-to-bottom list that references conditions by name and defines how they are grouped, repeated, and randomized.

This means you are no longer limited to a single block with a single intertrial. Any step in the experiment sequence can be a standalone condition, a simple loop, or a complex repeating block with its own intertrial — and you can have as many of each as you like. The sequence is fully expanded into an ordered list of steps before execution; the runner executes them top-to-bottom with no additional scheduling logic.

An optional **variables section** lets you define named values once at the top of the file and reference them throughout via YAML anchors, making it easy to adjust timing, LED power, pattern IDs, and other parameters without editing many scattered fields.

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

The experiment YAML contains the experiment design. It references the rig YAML and defines plugins, named conditions, the experiment sequence, and optional variables.

### Top-Level Structure

```yaml
version: 3                    # Required: Protocol version (must be 3)
experiment_info: {...}        # Required: Metadata
rig: "path/to/rig.yaml"      # Required: Path to rig YAML
variables: {...}              # Optional: Named values for use as YAML anchors
plugins: [...]                # Optional: Plugin definitions
experiment: [...]             # Required: Ordered experiment sequence
conditions: [...]             # Required: Named condition library
```

---

## Required Experiment YAML Sections

### 1. Experiment Metadata

```yaml
experiment_info:
  name: "My Experiment"                    # Required: Descriptive name
  date_created: "2026-01-15"               # Optional: Creation date
  author: "Research Lab"                   # Optional: Creator name
  pattern_library: "/path/to/patterns"     # Optional: Path to pattern files directory
```

`pattern_library` sets a default directory for pattern file resolution. If a `pattern` field in a command is just a filename (no path separators), the system prepends `pattern_library` to form the full path. A command with an absolute path ignores `pattern_library`. Set `pattern_library: ''` to omit it.

### 2. Rig Reference

```yaml
rig: "./configs/rigs/my_rig.yaml"
```

Required. Path to the rig YAML file (relative to the experiment YAML's location, or absolute). The rig YAML provides the arena configuration and controller IP — you do not define these in the experiment YAML.

### 3. Conditions Library

The `conditions` section is a list of named conditions. Each condition has a unique `name` and a `commands` list. Conditions are defined here once and referenced by name in the `experiment` sequence. There is no limit on the number of conditions, and they can be referenced any number of times in the experiment sequence.

```yaml
conditions:

  - name: "my condition"          # Required: unique name (referenced in experiment sequence)
    commands:                     # Required: at least one command
      - type: "controller"
        command_name: "allOff"
      - type: "wait"
        duration: 2

  - name: "another condition"
    commands:
      - type: "plugin"
        plugin_name: "camera"
        command_name: "getTimestamp"
      - type: "controller"
        command_name: "trialParams"
        pattern: "my_pattern.pat"
        pattern_ID: 1
        duration: 5
        mode: 2
        frame_index: 1
        frame_rate: 60
      - type: "wait"
        duration: 5
```

**Validation:**
- Must contain at least one condition
- Each condition must have a unique `name`
- Each condition must have a non-empty `commands` list
- All conditions referenced in the `experiment` section must be defined here

### 4. Experiment Sequence

The `experiment` section is an ordered list that defines what actually runs, and in what order. Each entry is either a **standalone condition reference** (a string matching a condition name) or a **block definition** (a YAML mapping that groups trials with optional repetitions, randomization, and an intertrial).

The parser fully expands this list into a flat, ordered sequence of steps before the runner begins — there is no additional scheduling logic at runtime.

```yaml
experiment:
  - "start recording"           # Standalone: runs once, in sequence
  - "baseline wait"             # Standalone: runs once, in sequence
  - "setup leds"                # Standalone: runs once, in sequence

  - name: "training blocks"     # Block: optional label (used in log output)
    trials:                     # Required: list of condition names
      - "trial type A"
      - "trial type B"
      - "trial type A"
      - "trial type B"
    repetitions: 3              # Optional: repeat the trials list N times (default: 1)
    randomize: false            # Optional: randomize trial order per repetition (default: false)
    intertrial: "blank screen"  # Optional: condition inserted between every consecutive trial

  - "shutdown"                  # Standalone: runs once, in sequence
```

**Standalone condition reference:**
- A plain string that matches a `name` in the `conditions` list
- Runs once, in the position it appears
- Use for setup, teardown, breaks, and any single step that should not repeat

**Block definition:**
- A YAML mapping that specifies a set of trials to run in a loop
- `trials` — Required. A list of condition names (strings). The trials run in the order listed, then the order repeats for each repetition (or is re-randomized if `randomize: true`)
- `repetitions` — Optional. A positive integer. The `trials` list is repeated this many times. Default: 1
- `randomize` — Optional. If `true`, the trial order is independently randomized for each repetition. Default: `false`
- `intertrial` — Optional. The name of a condition to insert between every consecutive pair of trials, including across repetition boundaries. Not inserted after the final trial
- `name` — Optional. A label used in log output to identify the block. When set, each step is logged as `blockname: trialname`

**How intertrials work:**

The intertrial is inserted *between* trials, not after the last one. Given two trials `[A, B]` with `repetitions: 2` and `intertrial: "blank"`:

```
A → blank → B → blank → A → blank → B
```

The intertrial is **not** added after the final `B`.

---

## Optional: Variables

The `variables` section lets you define named values once and reuse them throughout the YAML using standard YAML anchor (`&`) and alias (`*`) syntax. This is optional but highly recommended for experiments with repeated timing values, LED powers, or pattern IDs.

```yaml
variables:
  trial_duration:   &trial_duration   40      # seconds
  led_power:        &led_power         8      # LED intensity
  led_command:      &led_command  "setRedLEDPower"  # can anchor strings too
```

To use a variable value elsewhere in the file, write `*variable_name`:

```yaml
conditions:
  - name: "my trial"
    commands:
      - type: "controller"
        command_name: "trialParams"
        pattern: "my_pattern.pat"
        pattern_ID: 2
        duration: *trial_duration
        mode: 2
        frame_index: 1
        frame_rate: 60
      - type: "wait"
        duration: *trial_duration
```

**How it works:** YAML anchors (`&name value`) assign a name to a value at the point of definition. Aliases (`*name`) substitute that value wherever they appear. The YAML library resolves all anchors and aliases when the file is loaded, so by the time the parser sees the data, every `*variable_name` has already been replaced with its value. The `variables` section itself is preserved in the parsed protocol for logging purposes.

**Notes:**
- Variable names should be lowercase with underscores
- Anchors on string values require the string to be quoted: `&my_cmd "setRedLEDPower"`
- You can use the same anchor value as many times as needed
- Any YAML value can be anchored — numbers, strings, booleans
- The `variables` section has no effect on validation or execution beyond anchor resolution; it exists purely to make anchor declarations visible and documented in one place

---

## Plugin Definitions

Plugins integrate external hardware (cameras, serial devices, custom instruments) into experiments. Three plugin types are supported: **serial_device**, **class**, and **script**.

Hardware-specific settings for built-in plugins (`BiasPlugin`, `LEDControllerPlugin`, `DAQThermometerPlugin`) are defined in the **rig YAML**. The experiment YAML's plugin definitions specify the class to use and any experiment-specific overrides. If a config field appears in both, the experiment YAML value wins.

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
- `name` — Plugin identifier (referenced in commands)
- `type: "serial_device"`
- `port` — Serial port name (or `port_windows` / `port_posix` for cross-platform)
- `commands` — Struct mapping command names to command strings

**Optional Fields:**
- `baudrate` — Baud rate (default: 9600)
- `critical` — If true, plugin failures abort experiment (default: true)

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
    python:                                # Python-specific (required if using Python)
      module: "pyDisplayTools.plugins"     # Python module path
      class: "BiasPlugin"                  # Python class name
    config:                                # Plugin-specific configuration (optional)
      # Experiment-level overrides go here; hardware config lives in rig YAML
```

**Required Fields:**
- `name` — Plugin identifier
- `type: "class"`
- `matlab.class` OR `python.module` and `python.class`

**Optional Fields:**
- `config` — Plugin-specific configuration. Merged with rig YAML plugin config (experiment wins on conflict).

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

Hardware configuration (`ip`, `port`, `config_path`, `bias_executable`) is defined in the rig YAML under `plugins.camera`. The experiment YAML `config` section is for optional experiment-level overrides.

```yaml
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
- `startPreview` — Start camera preview without recording
- `startRecording` — Start recording (params: `filename`, optional)
- `stopRecording` — Stop recording, keep camera running
- `stopCapture` — Stop video capture completely
- `saveConfig` — Save config (params: `config_file`, optional if present in rig file)
- `getTimestamp` — Get timestamp and frame count (logged automatically)

**BiasPlugin Low-Level Commands** (Advanced):
- `connect` — Initialize connection (params: `ip`, `port`, optional if already in rig file)
- `loadConfiguration` — Load config file (params: `config_path`, optional if already in rig file)
- `enableLogging` — Enable BIAS logging (recording to file)
- `disableLogging` — Disable BIAS logging
- `setVideoFile` — Set output video filename (params: `filename`, optional)
- `startCapture` — Start video capture

**Usage Example (High-Level):**
```yaml
commands:
  - type: "plugin"
    plugin_name: "camera"
    command_name: "startRecording"
    params:
      filename: "trial_001"
```

**Note on video filenames:** The `filename` parameter names the *folder* the video is saved in, not the video file itself. BIAS generates the video filename automatically. If `filename` is a relative path, the folder is created inside the experiment YAML's location (or `saveDir` if configured). An absolute path controls where the folder is created directly.

#### LEDControllerPlugin (Backlight Control)

The serial port is defined in the rig YAML under `plugins.backlight`. The experiment YAML definition typically needs no `config` block.

```yaml
- name: "backlight"
  type: "class"
  matlab:
    class: "LEDControllerPlugin"
  # config:               # Optional experiment-level overrides
  #   critical: true      # default true
```

**LEDControllerPlugin Commands:**
- `setIRLEDPower` — Set IR LED power (params: `power` 0–100)
- `setRedLEDPower` — Set red LED (params: `power`; optional: `panel_num`, `pattern`)
- `setGreenLEDPower` — Set green LED (params: `power`; optional: `panel_num`, `pattern`)
- `setBlueLEDPower` — Set blue LED (params: `power`; optional: `panel_num`, `pattern`)
- `setVisibleBacklightsOff` — Turn off all visible (non-IR) LEDs (no params)
- `turnOnLED` — Turn on LED
- `turnOffLED` — Turn off LED

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

#### DAQThermometerPlugin (Temperature Logging)

Reads temperature from NI CompactDAQ thermocouples. Configuration belongs in the experiment YAML `config` block (or optionally in the rig YAML). Continuous background logging is the recommended mode for long experiments, as it does not block any other commands.

```yaml
- name: "temperature"
  type: "class"
  matlab:
    class: "DAQThermometerPlugin"
  config:
    # Required fields
    device_id: "cDAQ1Mod4"         # NI DAQ device identifier
    channels:                      # Thermocouple channel(s)
      - "ai0"
      - "ai2"
    # Optional fields — defaults shown
    thermocouple_type: "K"         # Thermocouple type (default: "K")
    sample_rate: 7                 # Hz (default: 7, matches Shubham's DAQ scripts)
    sample_duration: 1.0           # Seconds per get_temperature read (default: 1.0)
    generate_plots: true           # Save a PNG plot on log_temperature (default: true)
```

**DAQThermometerPlugin Commands:**
- `startContinuousLogging` — Start background acquisition that logs temperature at `sample_rate` Hz to a CSV file without blocking. Runs for the duration of the experiment until `stopContinuousLogging` is called. Recommended for long experiments.
- `stopContinuousLogging` — Stop background acquisition and close the CSV file.
- `get_temperature` — Read a single temperature sample (blocks for `sample_duration` seconds). Use for occasional spot-checks; prefer `startContinuousLogging` for continuous recording.
- `log_temperature` — Read and log a single temperature sample to file (optionally saves a PNG plot).

**Usage Example:**
```yaml
# In ir led setup condition:
- type: "plugin"
  plugin_name: "temperature"
  command_name: "startContinuousLogging"  # Returns immediately; logs in background

# In shutdown condition:
- type: "plugin"
  plugin_name: "temperature"
  command_name: "stopContinuousLogging"   # Stops acquisition and closes CSV
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
- `name` — Plugin identifier
- `type: "script"`
- `script_path` — Path to .m file

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

## Command Types

Commands appear inside condition definitions. Three command types are available.

### 1. Controller Commands

Send commands to the G4.1 LED arena controller.

```yaml
- type: "controller"
  command_name: "trialParams"              # Command name (required)
  # Additional parameters depend on command
```

**Available Controller Commands:**

- `trialParams` — Start a pattern trial
  ```yaml
  - type: "controller"
    command_name: "trialParams"
    pattern: "pat0001_vertical_bars.pat"   # Pattern filename (required)
    pattern_ID: 1                          # SD card pattern ID (updated by deploy script)
    mode: 2                                # Display mode: 2, 3, or 4 (required)
    frame_index: 1                         # Starting frame index (required)
    duration: 5                            # Trial duration in seconds (required, must be > 0)
    frame_rate: 60                         # Frames per second (required; negative = reverse)
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

**Negative `frame_rate`:** A negative value plays the pattern in reverse (e.g., `-120` for CCW motion when `+120` gives CW).

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

**Using a Variable as a Command Name:**

The `command_name` field can be set using a YAML alias if you want to vary the plugin command based on a variable:

```yaml
variables:
  led_command: &led_command "setRedLEDPower"

conditions:
  - name: "my trial"
    commands:
      - type: "plugin"
        plugin_name: "backlight"
        command_name: *led_command          # Resolves to "setRedLEDPower"
        params:
          power: 8
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

### 3. Wait Commands

**IMPORTANT**

Commands in a condition execute as quickly as possible in sequence unless wait commands are used to insert delays. The durations of your wait commands in a condition should match your desired timing — for example, in a trial condition, the total wait time should equal the pattern duration you set in `trialParams`. Waits can be split across a condition to control when other commands execute relative to the start of the trial.

```yaml
- type: "wait"
  duration: 1.5                            # Duration in seconds (required, must be >= 0)
```

**Example — pattern with mid-trial LED change:**

`trialParams` is non-blocking: it sends the command to the arena and returns immediately. The pattern plays on the arena while subsequent commands in the condition execute. The `wait` commands hold the total duration to match the pattern length.

```yaml
- name: "trial with mid-trial LED"
  commands:
    - type: "controller"
      command_name: "trialParams"
      pattern: "my_pattern.pat"
      pattern_ID: 1
      duration: 10
      mode: 2
      frame_index: 1
      frame_rate: 60
    - type: "wait"
      duration: 3            # wait 3 s after pattern starts
    - type: "plugin"
      plugin_name: "backlight"
      command_name: "setRedLEDPower"
      params:
        power: 5
    - type: "wait"
      duration: 7            # wait remaining 7 s (3 + 7 = 10 s total = pattern duration)
    - type: "plugin"
      plugin_name: "backlight"
      command_name: "setVisibleBacklightsOff"
```

---

## Pattern Files

Pattern files must:
1. Exist at the path specified in the YAML
2. Match the arena dimensions (`num_rows` × number of installed columns)
3. Be readable `.pat` binary files

Pattern paths are resolved relative to `experiment_info.pattern_library` if the path contains no directory separator.

**Pattern ID Assignment:**
When patterns are deployed to the SD card, the `pattern_ID` fields in your YAML are automatically updated to match the order patterns appear on the SD card (1-indexed). For example, if `pat0030_vertical.pat` is the 2nd pattern copied to the SD card, its `pattern_ID` will be set to 2, regardless of the original ID in the filename.

**Using variables for pattern IDs** is recommended so you only need to update the value once in the `variables` section:

```yaml
variables:
  my_pattern_id: &my_pattern_id 2

conditions:
  - name: "my trial"
    commands:
      - type: "controller"
        command_name: "trialParams"
        pattern: "my_pattern.pat"
        pattern_ID: *my_pattern_id
        ...
```

---

## Complete Example

The following is a minimal but complete V3 experiment YAML illustrating the key features: variables, standalone conditions, a block with repetitions and an intertrial, and the two-plugin setup (camera + backlight).

```yaml
version: 3

# ============================================================================
# EXPERIMENT METADATA
# ============================================================================
experiment_info:
  name: "Visual Motion Experiment"
  date_created: "2026-01-15"
  author: "Research Lab"
  pattern_library: "/path/to/patterns"

# ============================================================================
# RIG
# ============================================================================
rig: "./configs/rigs/my_rig.yaml"

# ============================================================================
# VARIABLES
# ============================================================================
variables:
  trial_duration:  &trial_duration   5    # seconds per trial
  inter_duration:  &inter_duration   2    # seconds between trials
  ir_power:        &ir_power        50    # IR LED power
  vis_power:       &vis_power        5    # visible LED power
  cw_pattern_id:   &cw_pattern_id    1    # SD card slot for CW pattern
  ccw_pattern_id:  &ccw_pattern_id   2    # SD card slot for CCW pattern

# ============================================================================
# PLUGINS
# ============================================================================
plugins:
  - name: "camera"
    type: "class"
    matlab:
      class: "BiasPlugin"

  - name: "backlight"
    type: "class"
    matlab:
      class: "LEDControllerPlugin"

# ============================================================================
# EXPERIMENT SEQUENCE
# ============================================================================
experiment:
  - "setup"

  - name: "motion trials"
    trials:
      - "cw motion"
      - "ccw motion"
    repetitions: 3
    randomize: true
    intertrial: "blank"

  - "shutdown"

# ============================================================================
# CONDITIONS LIBRARY
# ============================================================================
conditions:

  # --- Setup -----------------------------------------------------------------
  - name: "setup"
    commands:
      - type: "plugin"
        plugin_name: "backlight"
        command_name: "setIRLEDPower"
        params:
          power: *ir_power
      - type: "plugin"
        plugin_name: "backlight"
        command_name: "turnOnLED"
      - type: "plugin"
        plugin_name: "camera"
        command_name: "startRecording"
        params:
          filename: "motion_experiment"
      - type: "wait"
        duration: 1

  # --- Trials ----------------------------------------------------------------
  - name: "cw motion"
    commands:
      - type: "plugin"
        plugin_name: "camera"
        command_name: "getTimestamp"
      - type: "plugin"
        plugin_name: "backlight"
        command_name: "setRedLEDPower"
        params:
          power: *vis_power
          panel_num: 0
          pattern: "1111"
      - type: "controller"
        command_name: "trialParams"
        pattern: "vertical_bars_cw.pat"
        pattern_ID: *cw_pattern_id
        duration: *trial_duration
        mode: 2
        frame_index: 1
        frame_rate: 60
      - type: "wait"
        duration: *trial_duration
      - type: "plugin"
        plugin_name: "backlight"
        command_name: "setVisibleBacklightsOff"

  - name: "ccw motion"
    commands:
      - type: "plugin"
        plugin_name: "camera"
        command_name: "getTimestamp"
      - type: "plugin"
        plugin_name: "backlight"
        command_name: "setRedLEDPower"
        params:
          power: *vis_power
          panel_num: 0
          pattern: "1111"
      - type: "controller"
        command_name: "trialParams"
        pattern: "vertical_bars_ccw.pat"
        pattern_ID: *ccw_pattern_id
        duration: *trial_duration
        mode: 2
        frame_index: 1
        frame_rate: -60                    # Negative = reverse direction
      - type: "wait"
        duration: *trial_duration
      - type: "plugin"
        plugin_name: "backlight"
        command_name: "setVisibleBacklightsOff"

  # --- Intertrial ------------------------------------------------------------
  - name: "blank"
    commands:
      - type: "controller"
        command_name: "allOff"
      - type: "wait"
        duration: *inter_duration

  # --- Shutdown --------------------------------------------------------------
  - name: "shutdown"
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

**What the experiment sequence expands to:**

With `repetitions: 3` and `randomize: true`, the parser generates a flat sequence like:

```
1.  setup
2.  motion trials: ccw motion     ← randomized order, rep 1
3.  intertrial (blank)
4.  motion trials: cw motion
5.  intertrial (blank)
6.  motion trials: cw motion      ← randomized order, rep 2
7.  intertrial (blank)
8.  motion trials: ccw motion
9.  intertrial (blank)
10. motion trials: ccw motion     ← randomized order, rep 3
11. intertrial (blank)
12. motion trials: cw motion
13. shutdown
```

Note that the intertrial (`blank`) is not inserted after the final trial of the block, and not between the block and `shutdown`.

---

## Validation Checklist

Before running an experiment, ensure:

1. **Required sections present:**
   - ✓ `version: 3`
   - ✓ `experiment_info` with at minimum a `name` field
   - ✓ `rig` pointing to a valid rig YAML file
   - ✓ `conditions` with at least one condition (each with a unique `name` and non-empty `commands`)
   - ✓ `experiment` with at least one entry

2. **Rig and arena configuration valid:**
   - ✓ Rig YAML file exists and is readable
   - ✓ `controller.host` is a valid IP address
   - ✓ Arena YAML file exists and has `generation`, `num_rows`, `num_cols`
   - ✓ `generation` is one of: `"G3"`, `"G4"`, `"G4.1"`, `"G6"`

3. **Experiment sequence valid:**
   - ✓ All string entries match a name in the `conditions` list
   - ✓ All block `trials` entries match names in the `conditions` list
   - ✓ Block `intertrial` (if used) matches a name in the `conditions` list
   - ✓ Block `repetitions` (if used) is a positive integer

4. **All plugins properly defined:**
   - ✓ Each plugin has a unique `name`
   - ✓ `serial_device` plugins have `port` (or `port_windows`/`port_posix`), `baudrate`, and `commands`
   - ✓ `class` plugins have `matlab.class` or `python.module`/`python.class`
   - ✓ `script` plugins have `script_path`
   - ✓ Hardware config (ports, IPs, executables) for built-in plugins is in the rig YAML

5. **All commands valid:**
   - ✓ Controller commands have the required parameters for their `command_name`
   - ✓ Plugin commands reference plugins that are defined
   - ✓ Wait commands have a non-negative `duration`
   - ✓ Total wait durations in trial conditions match their `trialParams` `duration` values

6. **Pattern files:**
   - ✓ All pattern files exist
   - ✓ Pattern dimensions match arena configuration (rows × installed columns)
   - ✓ `pattern_ID` values will be automatically updated during SD card deployment

Use `validate_protocol_for_sd_card()` to perform comprehensive validation before deployment.

---

**Document Version:** 3.0  
**Last Updated:** 2026-04-03  
**MATLAB Version:** R2019–2020  
**Compatible Systems:** G4.1 LED Arenas

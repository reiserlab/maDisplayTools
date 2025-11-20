# Protocol Version 1 Specification

## Overview

The maDisplayTools protocol system provides a flexible, YAML-based framework for defining visual neuroscience experiments on modular LED display arenas. Protocol files define experiment metadata, hardware configurations, plugin integrations, and the sequence of experimental conditions to be executed.

## Protocol Structure

A protocol file is organized into several key sections:

### 1. Version Declaration

```yaml
version: 1
```

Specifies the protocol format version. This ensures compatibility between protocol files and the execution framework.

### 2. Experiment Metadata

```yaml
experiment_info:
  name: "My Experiment"
  date_created: "2024-01-15"
  author: "Researcher Name"
```

Tracks basic information about the experiment for organization and documentation purposes.

### 3. Arena Configuration

```yaml
arena_info:
  num_rows: 4
  num_cols: 12
  generation: "G4"
```

Defines the physical LED display arena:
- `num_rows`: Number of LED panel rows
- `num_cols`: Number of LED panel columns  
- `generation`: Display system generation (e.g., "G3", "G4")

### 4. Plugin Definitions

```yaml
plugins:
  - id: "plugin_name"
    type: "plugin_type"
    # ... plugin-specific configuration
```

Plugins extend the framework to interface with external hardware or execute custom code. Each plugin requires a unique `id` used to reference it in command sequences.

### 5. Experiment Structure

```yaml
experiment_structure:
  repetitions: 3
  randomization:
    enabled: true
    seed: null
    method: "block"
```

Controls trial organization:
- `repetitions`: How many times to repeat all conditions
- `randomization.enabled`: Whether to randomize condition order
- `randomization.seed`: Random seed for reproducibility (null = random)
- `randomization.method`: Randomization strategy ("block" or "trial")

### 6. Block (Experimental Conditions)

```yaml
block:
  conditions:
    - id: "condition_1"
      commands:
        - type: "combined_command"
          pattern: "./path/to/pattern.pat"
          duration: 2000
          # ... additional parameters
```

Defines the core experimental conditions. Each condition represents a unique trial type with a sequence of commands to execute.

### 7. Execution Sequences

The protocol supports four execution phases:

- **pretrial**: Executed once before any trials (hardware initialization)
- **block**: Main experimental conditions (repeated and/or randomized)
- **intertrial**: Executed between each trial (reset, inter-trial intervals)
- **posttrial**: Executed once after all trials (cleanup, data saving)

## Plugin System

The plugin system enables extensibility through three plugin types:

### Serial Device Plugin

Direct serial communication with hardware devices.

```yaml
- id: "background_light"
  type: "serial_device"
  port_windows: "COM4"
  port_posix: "/dev/ttyUSB0"
  baudrate: 115200
  commands:
    activate: "RED 50\nGREEN 0\nBLUE 0\nON 0,0"
    reset: "RESET"
    off: "OFF"
```

**Usage in commands:**
```yaml
- plugin: "background_light"
  command: "activate"
```

Serial plugins send predefined strings to the device. Define custom commands in the `commands` section and reference them by name.

### Class Plugin

Custom class implementations that provide complex functionality.

```yaml
- id: "simple_bias"
  type: "class"
  matlab:
    class: "maDisplayTools.plugins.SimpleBias"
  python:
    module: "pyDisplayTools.plugins.SimpleBias"
    class: "SimpleBias"
  config:
    ip: "127.0.0.1"
    port: 5020
    config_path: "./config/simple_bias_config.json"
```

**Usage in commands:**
```yaml
- plugin: "simple_bias"
  method: "connect"
- plugin: "simple_bias"
  method: "startCapture"
- plugin: "simple_bias"
  method: "setVideoFile"
  params:
    filename: "recording.avi"
```

Class plugins:

- Can be implemented in both MATLAB (maDisplayTools) and Python (pyDisplayTools)
- Support method calls with optional parameters
- Can maintain state across calls
- Access configuration through the `config` section

### Script Plugin

Executes external scripts.

```yaml
- id: "run_something"
  type: "script"
  script: "./user_functions/script_to_run"
```

**Usage in commands:**
```yaml
- plugin: "run_something"
```

The framework automatically appends the appropriate extension:
- `.m` for MATLAB runtime
- `.py` for Python runtime

## Command Types

### Combined Command

Displays visual patterns on the LED arena.

```yaml
- type: "combined_command"
  pattern: "./path/to/pattern.pat"
  duration: 2000          # milliseconds
  mode: 2                 # 1=position, 2=closed-loop
  frame_index: 1          # starting frame
  frame_rate: 60          # Hz
  gain: 0                 # closed-loop gain
  offset: 0               # closed-loop offset
```

### Wait Command

Pauses execution for a specified duration.

```yaml
- type: "wait"
  duration: 50  # milliseconds
```

### Plugin Command

Executes plugin methods (see Plugin System section above).

## Best Practices

### Organization
- Use descriptive IDs for conditions and plugins
- Group related initialization in pretrial
- Keep cleanup operations in posttrial
- Use intertrial for consistent baseline periods

### Documentation
- Add inline comments to explain complex sequences
- Document plugin configurations
- Specify units in comments (ms, Hz, mm, etc.)

### Modularity
- Define reusable plugins for common hardware
- Keep condition-specific logic in the block section
- Separate initialization from execution

### Reproducibility
- Set explicit randomization seeds when needed
- Document all hardware configurations
- Include version information in metadata

## Example Workflow

A typical experiment execution follows this sequence:

1. **Pretrial**: Initialize all hardware, load configurations
2. **Block** (repeated × `repetitions`):
   - For each condition (randomized if enabled):
     - Execute condition commands
     - Execute intertrial commands (between trials)
3. **Posttrial**: Save data, shut down hardware, cleanup

## File Locations

Protocol files are typically stored in:
- `examples/` - Example protocols for reference
- User-defined experiment directories

Related files:
- Pattern files (`.pat`) - Visual stimuli definitions
- Configuration files (`.json`) - Plugin-specific settings
- User scripts (`.m`, `.py`) - Custom script plugins

## Cross-Platform Compatibility

The protocol format is designed for cross-platform use:
- YAML format is platform-agnostic
- Plugins specify both Windows and POSIX serial ports
- Runtime automatically selects appropriate implementations
- Pattern paths use forward slashes (converted as needed)

## Version History

- **Version 1**: Initial protocol specification
  - Basic plugin system (serial, class, script)
  - Experiment structure with randomization
  - Four-phase execution model (pretrial, block, intertrial, posttrial)
  - Combined commands for pattern display

---
title: Custom Plugin Development
parent: MATLAB Tools
grand_parent: Generation 6
nav_order: 30
---

# Custom Plugin Development Guide

## Overview

Plugins are the mechanism by which maDisplayTools integrates external hardware and custom logic into experiment execution. A plugin can control a camera, read a sensor, send serial commands, or run any arbitrary MATLAB code at defined points during an experiment.

Plugins are declared in the `plugins` section of the experiment YAML. The **PluginManager** constructs and initializes each plugin before the experiment begins, and calls `cleanup()` on each when the experiment ends. During execution, any condition step with `type: "plugin"` is routed through PluginManager to the named plugin's `execute()` method.

### Plugin Types

Three plugin types are supported. Choose based on how you need to interact with your hardware or logic:

| Type | Best For | How It Works |
|------|----------|--------------|
| `serial_device` | Simple serial hardware with named commands | Commands and their byte sequences are defined entirely in YAML — no MATLAB class needed |
| `class` | Complex hardware, or any device that already has (or needs) a MATLAB class | You write a MATLAB class; maDisplayTools wraps it and calls its methods |
| `script` | Custom analysis, logging, or any one-shot logic | You write a MATLAB function; maDisplayTools calls it at defined points in the protocol |

> **Hardware-specific config:** Port names, IP addresses, and similar rig-specific settings belong in the rig YAML, not the experiment YAML. The experiment YAML's plugin definition stays portable across rigs. If a config field appears in both, the experiment YAML value wins.

---

## Serial Device Plugin

The `serial_device` type is the simplest plugin — no MATLAB class required. You define the device's commands directly in the YAML, specifying the bytes to send and optionally the bytes to expect back. The built-in **SerialPlugin** class handles opening the port, formatting and sending commands, and reading responses.

Use this type when your hardware is simple: it receives short byte sequences and optionally replies with short byte sequences, with no complex state or logic needed on the MATLAB side.

### YAML Definition

```yaml
plugins:
  - name: "my_device"            # Unique name; referenced in condition steps
    type: "serial_device"
    port: "COM3"                  # Serial port (define in rig YAML)
    baud_rate: 9600               # Baud rate
    timeout: 2.0                  # Read timeout in seconds (default: 2.0)
    critical: true                # Abort experiment on failure (default: true)
    commands:
      set_power:                  # Command name (used in experiment steps)
        send: [0x50, "{power}"]   # Bytes to send; {param} substitutes values
        expect: [0x41, 0x4B]      # Optional: expected reply bytes (ACK check)
      turn_off:
        send: [0x00]
      query_status:
        send: [0x53]
        receive_length: 4         # Read N bytes back without checking content
```

### Configuration Fields

| Field | Description |
|-------|-------------|
| `name` | Unique plugin identifier. Referenced in condition steps. |
| `type` | `"serial_device"` |
| `port` | Serial port name (e.g. `COM3` on Windows, `/dev/ttyUSB0` on Linux/Mac). Define in rig YAML. |
| `baud_rate` | Baud rate matching the device firmware. |
| `timeout` | Seconds to wait for a serial response. Default: `2.0`. |
| `critical` | If `true`, any failure aborts the experiment. Default: `true`. |
| `commands` | Map of command name → send/expect definition. See below. |

#### Command Definition Fields

| Field | Description |
|-------|-------------|
| `send` | Array of bytes to transmit. Numeric literals (`0x50`), decimal integers, and `{param_name}` substitution placeholders are all valid. |
| `expect` | Optional array of bytes expected in the reply. SerialPlugin reads and compares; a mismatch raises an error. |
| `receive_length` | Optional number of bytes to read back. Use when you want to capture the reply without checking its exact content. |

### Parameter Substitution

Placeholders in `send` like `{power}` are replaced at runtime with the matching parameter from the condition step's `params` block. The substituted value must be a number in [0, 255].

### Using the Plugin in a Condition

```yaml
conditions:
  set_power_50:
    commands:
      - type: "plugin"
        plugin_name: "my_device"
        command_name: "set_power"
        params:
          power: 50              # Substituted into {power} in the send bytes
```

> **Note:** The serial_device plugin opens and holds the serial port for the entire experiment. If another process needs the same port, close it before running.

---

## Class Plugin

The `class` type lets you integrate any MATLAB class into the experiment framework. You write the class; maDisplayTools wraps it in a **ClassPlugin** and calls its lifecycle methods at the appropriate points.

Use this type when your hardware requires more logic than simple byte sequences — for example, a camera controlled via HTTP, a DAQ device, or any hardware that already has a MATLAB driver class you want to wrap.

### Required Class Interface

Your class must implement the constructor signature and three methods shown below. ClassPlugin validates their presence at startup and will error if any are missing.

#### Constructor

```matlab
function self = MyPluginClass(name, config, logger)
    % name   - string: the plugin name from the YAML
    % config - struct: the merged config block from rig + experiment YAML
    % logger - ExperimentLogger instance
end
```

#### initialize()

```matlab
function initialize(self)
    % Called once before the experiment starts.
    % Open connections, allocate resources, configure hardware.
    % Raise an error here if setup fails — PluginManager will prompt
    % the user to check the hardware and offer one retry.
end
```

#### execute(command, params)

```matlab
function result = execute(self, command, params)
    % Called each time the protocol issues a plugin command step.
    % command - string: the command_name from the YAML step
    % params  - struct: the params block from the YAML step (may be empty struct)
    % result  - any value, or [] if not needed
    %
    % Route on command using a switch statement.
    result = [];
    switch command
        case 'do_something'
            self.hardware.doSomething(params.value);
        case 'read_value'
            result = self.hardware.read();
        otherwise
            error('Unknown command: %s', command);
    end
end
```

#### cleanup()

```matlab
function cleanup(self)
    % Called once after the experiment ends (or on error).
    % Close connections, stop background tasks, release resources.
    % Guard against double-cleanup if needed (e.g. check isInitialized).
end
```

#### getStatus() (optional)

```matlab
function status = getStatus(self)
    % Optional. ClassPlugin calls this if it exists and includes
    % the result in its own getStatus() output.
    status = struct();
    status.initialized = self.isInitialized;
    % add whatever fields are useful for diagnostics
end
```

### YAML Definition

```yaml
plugins:
  - name: "my_instrument"         # Unique plugin name
    type: "class"
    matlab:
      class: "MyPluginClass"      # Must be on the MATLAB path
    config:                        # Passed as struct to constructor
      port: "COM4"
      sample_rate: 1000
      critical: true
```

> **Rig vs experiment config:** Hardware-specific fields (port, IP, sample rate) belong in the rig YAML under `plugins.<name>`. The experiment YAML `config` block is for experiment-level overrides. At runtime the two are merged, with experiment values winning on conflict.

### Full Example: Simple DAQ Voltage Reader

This example shows a minimal class plugin for reading voltage from a DAQ channel using MATLAB's Data Acquisition Toolbox. It is the pattern to use when a sensor outputs an analog voltage and there is no existing MATLAB driver for it — you just need to read whatever it outputs.

```matlab
classdef DAQVoltagePlugin < handle

    properties (Access = private)
        name
        config
        logger
        daqSession
        isInitialized = false
        logFile
        logFid = -1
    end

    methods (Access = public)

        function self = DAQVoltagePlugin(name, config, logger)
            self.name   = name;
            self.config = config;
            self.logger = logger;
        end

        function initialize(self)
            % Required config fields: device_id, channel_id
            % Optional config fields: log_file
            if ~isfield(self.config, 'device_id')
                error('DAQVoltagePlugin: missing config field device_id');
            end
            if ~isfield(self.config, 'channel_id')
                error('DAQVoltagePlugin: missing config field channel_id');
            end

            self.daqSession = daq('ni');
            addinput(self.daqSession, self.config.device_id, ...
                     self.config.channel_id, 'Voltage');

            % Determine log file path
            if isfield(self.config, 'log_file')
                self.logFile = self.config.log_file;
            elseif isfield(self.config, 'saveDir')
                self.logFile = fullfile(self.config.saveDir, ...
                    sprintf('%s_voltage.csv', self.name));
            end

            if ~isempty(self.logFile)
                self.logFid = fopen(self.logFile, 'w');
                fprintf(self.logFid, 'timestamp,voltage_V\n');
            end

            self.isInitialized = true;
            self.logger.log('INFO', sprintf('[%s] DAQ initialized', self.name));
        end

        function result = execute(self, command, params)
            result = [];
            if ~self.isInitialized
                error('%s: not initialized', self.name);
            end
            switch command
                case 'read_voltage'
                    data = read(self.daqSession, 'OutputFormat', 'Matrix');
                    result = data(1);
                    self.logger.log('DEBUG', sprintf('[%s] voltage = %.4f V', ...
                        self.name, result));

                case 'log_voltage'
                    data = read(self.daqSession, 'OutputFormat', 'Matrix');
                    v = data(1);
                    result = v;
                    if self.logFid >= 0
                        fprintf(self.logFid, '%.6f,%.6f\n', posixtime(datetime('now')), v);
                    end
                    self.logger.log('INFO', sprintf('[%s] logged voltage = %.4f V', ...
                        self.name, v));

                otherwise
                    error('[%s] Unknown command: %s', self.name, command);
            end
        end

        function cleanup(self)
            if self.isInitialized
                if ~isempty(self.daqSession)
                    delete(self.daqSession);
                end
                if self.logFid >= 0
                    fclose(self.logFid);
                    self.logFid = -1;
                end
                self.isInitialized = false;
                self.logger.log('INFO', sprintf('[%s] cleaned up', self.name));
            end
        end

    end
end
```

Rig YAML entry for this plugin:

```yaml
plugins:
  voltage_sensor:
    device_id: "Dev1"             # NI device name (from NI MAX or daq.getDevices)
    channel_id: "ai0"             # Analog input channel
```

Experiment YAML entry and usage:

```yaml
plugins:
  - name: "voltage_sensor"
    type: "class"
    matlab:
      class: "DAQVoltagePlugin"

conditions:
  log_reading:
    duration: 0
    commands:
      - type: "plugin"
        plugin_name: "voltage_sensor"
        command_name: "log_voltage"
```

> **DAQ vs Serial:** DAQ plugins talk to a DAQ box (e.g. NI CompactDAQ) via MATLAB's Data Acquisition Toolbox. The sensor itself just produces a voltage — no commands are sent to it. Serial plugins send explicit byte sequences to a device that has its own firmware. They are not interchangeable.

### Error Handling and the critical Flag

If `initialize()` raises an error, PluginManager will prompt the user to check the hardware and press Enter to retry. If a second attempt also fails, the error propagates and the experiment does not start.

In `execute()`, whether a failure aborts the experiment depends on your class's `isCritical` property (set from `config.critical`). See `LEDControllerPlugin` or `DAQThermometerPlugin` for reference implementations.

---

## Script Plugin

The `script` type runs a MATLAB function file at defined points during the experiment. Write a `.m` function, point the YAML at it, and it will be called whenever a condition step invokes it.

Use this type for one-shot actions that do not require persistent state between calls: saving a derived data file at the end of the experiment, triggering an alert, or any custom logic that should run at a defined moment in the protocol.

> **Stateful plugins:** If your script needs to maintain state between calls (open file handles, running background tasks, persistent connections), use a class plugin instead.

### YAML Definition

```yaml
plugins:
  - name: "post_trial_logger"     # Unique plugin name
    type: "script"
    script_path: "./plugins/my_logger.m"   # Relative paths resolved from experiment YAML location
```

### Configuration Fields

| Field | Description |
|-------|-------------|
| `name` | Unique plugin identifier. |
| `type` | `"script"` |
| `script_path` | Path to the `.m` file. Relative paths are resolved from the experiment YAML location. |

### Function Signature

Your function must accept a single `params` struct argument. It may optionally return a result value.

```matlab
function result = my_logger(params)
    % params - struct containing any fields passed from the YAML step
    %          e.g. params.output_path, params.condition_id
    % result - optional; return [] if not needed

    fid = fopen(params.output_path, 'a');
    fprintf(fid, 'Condition %s completed at %s\n', ...
        params.condition_id, datestr(now));
    fclose(fid);

    result = [];
end
```

### Using the Plugin in a Condition

```yaml
conditions:
  end_of_block:
    duration: 0
    commands:
      - type: "plugin"
        plugin_name: "post_trial_logger"
        params:
          output_path: "./results/run_log.txt"
          condition_id: "block_1"
```

Note: script plugin steps do not use `command_name`. ScriptPlugin always calls the function directly — there is only one action per script plugin.

### The saveDir Field

PluginManager automatically injects a `saveDir` field into every plugin's config before calling `initialize()`. This is set to the experiment output directory. It gives your plugin a reliable place to write output files without hardcoding paths. In a class plugin it is available as `self.config.saveDir`; to use it in a script plugin, pass it through explicitly in the YAML `params` block.

---

## Plugin Lifecycle

Understanding when each plugin method is called helps you allocate and release resources correctly.

| Phase | What Happens | Your Plugin Method |
|-------|-------------|-------------------|
| Startup | PluginManager constructs all plugins | constructor |
| Startup | PluginManager initializes all plugins | `initialize()` |
| Pretrial | Condition steps execute in order | `execute(cmd, params)` |
| Block trials | Each condition step executes | `execute(cmd, params)` |
| Intertrial | Between every trial | `execute(cmd, params)` |
| Posttrial | Final condition steps execute | `execute(cmd, params)` |
| Shutdown | PluginManager closes all plugins | `cleanup()` |

> **On error:** If an experiment aborts at any point, PluginManager calls `cleanup()` on all registered plugins. Design your `cleanup()` to be safe to call at any stage, including before `initialize()` has completed.

### Plugin Command Steps in the YAML

Any step within a condition's `commands` list can invoke a plugin:

```yaml
- type: "plugin"
  plugin_name: "my_instrument"  # Must match a name in the plugins section
  command_name: "set_power"      # Passed as first arg to execute()
                                 # (Not used for script plugins)
  params:                        # Optional; passed as struct to execute()
    power: 75
    mode: "continuous"
```

### Hardware Retry Behavior

PluginManager implements a single-retry pattern for hardware initialization failures:

- **serial_device and class plugins:** if `initialize()` throws, the user is prompted to check the device and press Enter. One retry is attempted. If it fails again, the exception propagates and the experiment does not start.
- **script plugins:** if `initialize()` throws (e.g. file not found), the user is prompted with the error message and one retry is attempted.
- **class construction:** if the class cannot be found on the MATLAB path, the user is prompted to add the folder and press Enter, and one retry is attempted. Other construction errors (wrong interface, missing methods) abort immediately without prompting.

---

## Quick Reference

### Which Plugin Type Should I Use?

| Situation | Use This Type |
|-----------|--------------|
| Simple serial hardware — just send bytes, optionally check a reply | `serial_device` |
| Hardware with a MATLAB driver class already written | `class` |
| Hardware with no MATLAB driver — you need to write the control logic | `class` |
| DAQ device (NI, etc.) read via MATLAB Data Acquisition Toolbox | `class` |
| Custom one-shot analysis or logging, no persistent state needed | `script` |
| Anything requiring state between calls, background tasks, or open handles | `class` |

### Class Plugin Interface Checklist

- `MyClass(name, config, logger)` — constructor takes exactly these three args
- `initialize()` — opens connections; may throw on hardware failure
- `execute(command, params)` — routes on command string; returns result or `[]`
- `cleanup()` — closes connections; must be safe to call at any point
- `getStatus()` — optional diagnostic method

### YAML Snippet Templates

**serial_device:**

```yaml
- name: "device_name"
  type: "serial_device"
  port: "COM3"                   # Define in rig YAML
  baud_rate: 9600
  commands:
    command_name:
      send: [0xFF, "{param}"]
      expect: [0x41, 0x4B]       # Optional
```

**class:**

```yaml
- name: "device_name"
  type: "class"
  matlab:
    class: "MyPluginClass"
  config:                        # Hardware settings go in rig YAML
    key: value
```

**script:**

```yaml
- name: "script_name"
  type: "script"
  script_path: "./plugins/my_function.m"
```

**Condition step invoking any plugin:**

```yaml
- type: "plugin"
  plugin_name: "device_name"
  command_name: "command_name"   # Omit for script plugins
  params:
    key: value
```

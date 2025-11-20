# Command-Line Interface for maDisplayTools

## Executive Summary

This document outlines a command-line interface for `maDisplayTools` that runs **within the MATLAB command window**. Unlike Python's shell-based CLI, this design embraces MATLAB's interactive environment while providing a consistent, discoverable interface for common tasks.

The CLI uses a simple entry point function `rdt()` (short for **R**eiser **D**isplay **T**ools) that dispatches to specialized command functions, leveraging MATLAB's name-value arguments for clean, readable syntax.

**Note**: This CLI should be implemented **after** the OOP refactoring (see `01_refactor-oop.md`), as it builds on the `Arena`, `Pattern`, and `PatternFile` classes.

## Design Philosophy: MATLAB-Native CLI

### Key Principles

1. **Command Window First**: Designed for MATLAB's interactive environment, not shell scripts
2. **Name-Value Arguments**: Uses MATLAB's modern `arguments` blocks for validation
3. **Return Values**: Commands can return data structures for further processing
4. **Tab Completion**: Compatible with MATLAB's tab completion (R2021b+)
5. **Help Integration**: Works with MATLAB's `help` command
6. **Simple Dispatch**: No complex plugin architecture - just function calls

### Why Not a Shell CLI?

MATLAB users work in the command window, not system shells. A shell-based CLI would require:
- Switching contexts between MATLAB and terminal
- Complex data passing (files/pipes instead of variables)
- Separate installation/PATH management
- Platform-specific shell scripts

Instead, this MATLAB-native CLI:
- Stays in MATLAB environment
- Can access workspace variables directly
- Integrates with MATLAB's help system
- Works identically on all platforms

## Command Structure

```matlab
rdt <command> <subcommand> (Name, Value, ...)
```

Commands return data structures when useful, allowing:
```matlab
% Use command for side effects (save file)
rdt pattern create Array=frames, Name="test", Arena="g4-4row"

% Capture return value for further use
info = rdt pattern info "pattern.pat"
fprintf('Pattern has %d frames\n', info.numFrames);
```

## Command Hierarchy

```
rdt
├── pattern
│   ├── create        Create new pattern from array/script/function
│   ├── info          Show pattern metadata
│   ├── preview       Launch interactive preview
│   └── validate      Validate pattern file
├── experiment
│   ├── create        Create experiment folder from YAML
│   ├── validate      Validate experiment protocol
│   └── info          Show experiment details
├── arena
│   ├── list          List available arena presets
│   └── info          Show arena details
└── config
    ├── show          Show current configuration
    ├── set           Set configuration value
    └── reset         Reset to defaults
```

Help is integrated: `help rdt`, `help rdt_pattern_create`, etc.

## Detailed Command Specifications

### Pattern Commands

#### `rdt pattern create`

Create pattern from array, script, or function.

**Syntax:**
```matlab
rdt pattern create (Name, Value, ...)

Name-Value Arguments:
  Array (numeric)           Pattern array [rows, cols, numX, numY]
  Script (string)           Path to script that creates 'frames' variable
  Function (function_handle) Function that returns pattern array
  Name (string)             Pattern name (required)
  Arena (string)            Arena preset: "g4-3row", "g4-4row", etc.
  ArenaRows (int)           Custom arena rows (for non-preset)
  ArenaCols (int)           Custom arena cols (for non-preset)
  GsMode (string)           "binary" or "grayscale" [default: "grayscale"]
  Stretch (numeric)         Stretch values [numX, numY]
  OutputDir (string)        Output directory [default: "./patterns"]
  Preview (logical)         Launch preview after creation [default: false]
```

**Examples:**
```matlab
% From array in workspace
frames = rand(64, 192, 96) > 0.5;
rdt pattern create Array=frames, Name="random", Arena="g4-4row", GsMode="binary"

% From script
rdt pattern create Script="make_grating.m", Name="grating", Arena="g4-4row"

% From function
rdt pattern create Function=@makeVerticalBars, Name="vbars", Arena="g4-3row"

% Custom arena
rdt pattern create Array=frames, Name="custom", ArenaRows=5, ArenaCols=8

% Create and preview
rdt pattern create Array=frames, Name="test", Arena="g4-4row", Preview=true

% With custom output directory
rdt pattern create Array=frames, Name="exp1", Arena="g4-4row", ...
    OutputDir="./experiments/exp001/patterns"
```

**Script Requirements:**
When using `Script` option, the script must create a variable called `frames`:
```matlab
% make_grating.m
frames = zeros(64, 192, 24);
for i = 1:24
    frames(1+2*(i-1):2*i, :, i) = 1;
end
```

**Function Requirements:**
When using `Function` option, function must return the frames array:
```matlab
function frames = makeVerticalBars()
    frames = zeros(64, 192, 12);
    for i = 1:12
        frames(:, 1+16*(i-1):16*i, i) = 1;
    end
end
```

#### `rdt pattern info`

Display pattern file metadata.

**Syntax:**
```matlab
info = rdt pattern info (PatternFile, Name, Value, ...)

Arguments:
  PatternFile (string)      Path to .pat file

Name-Value Arguments:
  Verbose (logical)         Show detailed info [default: false]

Returns:
  info (struct)             Pattern metadata
```

**Examples:**
```matlab
% Display info
rdt pattern info "patterns/pat0001_test.pat"

% Output:
%   Pattern: pat0001_test.pat
%   ID: 1
%   Dimensions: 64 x 192 pixels (4 x 12 panels)
%   Frames: 96 total (96 x 1)
%   Mode: grayscale (16 levels)
%   Generation: G4

% Get info structure
info = rdt pattern info "patterns/pat0001_test.pat"
fprintf('Pattern has %d frames\n', info.numFrames);

% Detailed info
rdt pattern info "patterns/pat0001_test.pat", Verbose=true
```

**Returned Structure:**
```matlab
info.id           % Pattern ID
info.name         % Filename
info.width        % Width in pixels
info.height       % Height in pixels
info.numX         % Frames in X
info.numY         % Frames in Y
info.numFrames    % Total frames
info.gsMode       % "binary" or "grayscale"
info.gsVal        % 2 or 16
info.generation   % "G4", "G41", etc.
info.fileSize     % Size in bytes
```

#### `rdt pattern preview`

Launch interactive pattern preview.

**Syntax:**
```matlab
rdt pattern preview (PatternFile, Name, Value, ...)

Arguments:
  PatternFile (string)      Path to .pat file

Name-Value Arguments:
  StartFrame (int)          Initial frame index [default: 1]
  Export (string)           Export format: "gif", "frames", "video"
  ExportPath (string)       Export output path
  ExportFormat (string)     Image format for frames: "png", "tiff" [default: "png"]
  FPS (double)              Frames per second for video/gif [default: 10]
```

**Examples:**
```matlab
% Launch preview GUI
rdt pattern preview "patterns/pat0001_test.pat"

% Start at specific frame
rdt pattern preview "patterns/pat0001_test.pat", StartFrame=10

% Export as animated GIF
rdt pattern preview "patterns/pat0001_test.pat", Export="gif", ...
    ExportPath="animation.gif"

% Export all frames as PNG images
rdt pattern preview "patterns/pat0001_test.pat", Export="frames", ...
    ExportPath="./frames/"

% Export frames as TIFF
rdt pattern preview "patterns/pat0001_test.pat", Export="frames", ...
    ExportPath="./frames/", ExportFormat="tiff"
```

#### `rdt pattern validate`

Validate pattern file(s) against arena configuration.

**Syntax:**
```matlab
results = rdt pattern validate (PatternFiles, Name, Value, ...)

Arguments:
  PatternFiles (string|cell) One or more .pat files

Name-Value Arguments:
  Arena (string)            Expected arena type
  ArenaRows (int)           Expected arena rows
  ArenaCols (int)           Expected arena cols
  Strict (logical)          Fail on warnings [default: false]
```

**Examples:**
```matlab
% Validate single file
rdt pattern validate "patterns/pat0001_test.pat", Arena="g4-4row"

% Output:
%   ✓ pat0001_test.pat: Valid
%     Dimensions: 64 x 192 (matches g4-4row)
%     Frames: 96

% Validate multiple files
files = ["patterns/pat0001.pat", "patterns/pat0002.pat"];
rdt pattern validate files, Arena="g4-4row"

% Get results structure
results = rdt pattern validate "patterns/*.pat", ArenaRows=4, ArenaCols=12

% Strict mode (warnings become errors)
rdt pattern validate "patterns/*.pat", Arena="g4-4row", Strict=true
```

**Returned Structure:**
```matlab
results(i).file       % Filename
results(i).valid      % true/false
results(i).errors     % Cell array of error messages
results(i).warnings   % Cell array of warnings
```

### Experiment Commands

#### `rdt experiment create`

Create experiment folder from YAML protocol.

**Syntax:**
```matlab
rdt experiment create (Name, Value, ...)

Name-Value Arguments:
  Protocol (string)         YAML protocol file (required)
  Output (string)           Output directory (required)
  Arena (string)            Override arena type from YAML
  Force (logical)           Overwrite existing [default: false]
  DryRun (logical)          Show plan without executing [default: false]
  Verbose (logical)         Show detailed output [default: true]
```

**Examples:**
```matlab
% Create experiment
rdt experiment create Protocol="protocol.yaml", Output="./experiments/exp001"

% Dry run (show what would happen)
rdt experiment create Protocol="protocol.yaml", Output="./exp001", DryRun=true

% Force overwrite
rdt experiment create Protocol="protocol.yaml", Output="./exp001", Force=true

% Override arena type
rdt experiment create Protocol="protocol.yaml", Output="./exp001", Arena="g41-4row"

% Quiet mode
rdt experiment create Protocol="protocol.yaml", Output="./exp001", Verbose=false
```

#### `rdt experiment validate`

Validate experiment protocol file.

**Syntax:**
```matlab
results = rdt experiment validate (ProtocolFile, Name, Value, ...)

Arguments:
  ProtocolFile (string)     YAML protocol file

Name-Value Arguments:
  Verbose (logical)         Show detailed results [default: false]

Returns:
  results (struct)          Validation results
```

**Examples:**
```matlab
% Validate protocol
rdt experiment validate "protocol.yaml"

% Output:
%   ✓ Protocol is valid
%   Patterns: 12 referenced, 12 found
%   Conditions: 4

% Get results
results = rdt experiment validate "protocol.yaml"
if results.isValid
    fprintf('Ready to create experiment\n');
end

% Detailed validation
rdt experiment validate "protocol.yaml", Verbose=true
```

#### `rdt experiment info`

Show experiment protocol information.

**Syntax:**
```matlab
info = rdt experiment info (ProtocolFile, Name, Value, ...)

Arguments:
  ProtocolFile (string)     YAML protocol file

Name-Value Arguments:
  ShowPatterns (logical)    List pattern details [default: false]
  ShowConditions (logical)  List conditions [default: false]

Returns:
  info (struct)             Experiment information
```

**Examples:**
```matlab
% Basic info
rdt experiment info "protocol.yaml"

% Output:
%   Experiment Protocol
%   Arena: g4-4row
%   Patterns: 12
%   Conditions: 4
%   Duration: ~45 minutes

% Show pattern details
rdt experiment info "protocol.yaml", ShowPatterns=true

% Get info structure
info = rdt experiment info "protocol.yaml"
fprintf('Experiment uses %d patterns\n', info.numPatterns);
```

### Arena Commands

#### `rdt arena list`

List available arena presets.

**Syntax:**
```matlab
arenas = rdt arena list (Name, Value, ...)

Name-Value Arguments:
  Verbose (logical)         Show detailed specs [default: false]

Returns:
  arenas (struct array)     Arena configurations
```

**Examples:**
```matlab
% List arenas
rdt arena list

% Output:
%   Available Arenas:
%   1. g4-3row    (G4,  3 rows × 12 cols =  48 panels,  48 × 192 pixels)
%   2. g4-4row    (G4,  4 rows × 12 cols =  48 panels,  64 × 192 pixels)
%   3. g41-3row   (G41, 3 rows × 12 cols =  48 panels,  48 × 192 pixels)
%   4. g41-4row   (G41, 4 rows × 12 cols =  48 panels,  64 × 192 pixels)

% Detailed list
rdt arena list Verbose=true

% Get arena list
arenas = rdt arena list
for i = 1:length(arenas)
    fprintf('%s: %dx%d pixels\n', arenas(i).name, arenas(i).height, arenas(i).width);
end
```

#### `rdt arena info`

Show detailed arena configuration.

**Syntax:**
```matlab
arena = rdt arena info (ArenaName, Name, Value, ...)

Arguments:
  ArenaName (string)        Arena preset name

Returns:
  arena (struct)            Arena configuration
```

**Examples:**
```matlab
% Show arena details
rdt arena info "g4-4row"

% Output:
%   Arena: g4-4row
%   Generation: G4
%   Configuration:
%     Rows: 4 panels (64 pixels)
%     Cols: 12 panels (192 pixels)
%     Total: 48 panels (12,288 pixels)
%   Panel Size: 16 × 16 pixels

% Get arena object
arena = rdt arena info "g4-4row"
fprintf('Total pixels: %d\n', arena.width * arena.height);
```

### Configuration Commands

#### `rdt config show`

Display current configuration.

**Syntax:**
```matlab
config = rdt config show

Returns:
  config (struct)           Current configuration
```

**Examples:**
```matlab
% Show config
rdt config show

% Output:
%   Configuration:
%     default_arena: g4-4row
%     default_output_dir: ./patterns
%     default_gs_mode: grayscale
%     auto_preview: false

% Get config
config = rdt config show
fprintf('Default arena: %s\n', config.default_arena);
```

#### `rdt config set`

Set configuration value.

**Syntax:**
```matlab
rdt config set (Key, Value)

Arguments:
  Key (string)              Configuration key
  Value                     Configuration value
```

**Examples:**
```matlab
% Set default arena
rdt config set "default_arena", "g4-4row"

% Set default output directory
rdt config set "default_output_dir", "./my_patterns"

% Set default grayscale mode
rdt config set "default_gs_mode", "grayscale"

% Enable auto-preview
rdt config set "auto_preview", true
```

**Available Keys:**
- `default_arena` - Default arena type (string)
- `default_output_dir` - Default output directory (string)
- `default_gs_mode` - Default grayscale mode: "binary" or "grayscale"
- `auto_preview` - Auto-preview after creation (logical)

#### `rdt config reset`

Reset configuration to defaults.

**Syntax:**
```matlab
rdt config reset (Name, Value, ...)

Name-Value Arguments:
  Confirm (logical)         Skip confirmation [default: false]
```

**Examples:**
```matlab
% Reset (with confirmation)
rdt config reset

% Reset without confirmation
rdt config reset Confirm=true
```

## Implementation Architecture

### File Structure

```
maDisplayTools/
├── rdt.m                          % Main entry point
├── +maDisplayTools/
│   ├── Arena.m                    % From OOP refactor
│   ├── Pattern.m                  % From OOP refactor
│   ├── PatternFile.m              % From OOP refactor
│   ├── PatternPreview.m           % From OOP refactor
│   ├── +internal/                 % From OOP refactor
│   │   └── EncoderG4.m
│   └── +cli/
│       ├── +pattern/
│       │   ├── create.m
│       │   ├── info.m
│       │   ├── preview.m
│       │   └── validate.m
│       ├── +experiment/
│       │   ├── create.m
│       │   ├── validate.m
│       │   └── info.m
│       ├── +arena/
│       │   ├── list.m
│       │   └── info.m
│       ├── +config/
│       │   ├── show.m
│       │   ├── set.m
│       │   └── reset.m
│       └── ConfigManager.m        % Persistent config storage
```

### Main Entry Point

```matlab
% rdt.m
function varargout = rdt(command, subcommand, varargin)
    % RDT Reiser Display Tools command-line interface
    %
    %   rdt <command> <subcommand> (Name, Value, ...)
    %
    % Commands:
    %   pattern       Pattern creation and management
    %   experiment    Experiment folder management
    %   arena         Arena configuration information
    %   config        Configuration management
    %
    % Examples:
    %   rdt pattern create Array=frames, Name="test", Arena="g4-4row"
    %   rdt pattern info "pattern.pat"
    %   rdt pattern preview "pattern.pat"
    %   rdt experiment create Protocol="protocol.yaml", Output="./exp001"
    %   rdt arena list
    %   rdt config show
    %
    % For help on specific commands:
    %   help rdt_pattern_create
    %   help rdt_experiment_create
    %   help rdt_arena_list
    
    % Handle no arguments - show help
    if nargin == 0
        help rdt
        return
    end
    
    % Validate command
    validCommands = {'pattern', 'experiment', 'arena', 'config'};
    if ~ismember(lower(command), validCommands)
        error('Unknown command: %s. Valid commands: %s', ...
              command, strjoin(validCommands, ', '));
    end
    
    % Require subcommand
    if nargin < 2
        error('Subcommand required. Type: help rdt_%s_<subcommand>', command);
    end
    
    % Dispatch to appropriate handler
    funcName = sprintf('maDisplayTools.cli.%s.%s', lower(command), lower(subcommand));
    
    try
        % Check if function exists
        if ~exist(funcName, 'file')
            error('Unknown subcommand: %s %s', command, subcommand);
        end
        
        % Call the function
        func = str2func(funcName);
        [varargout{1:nargout}] = func(varargin{:});
        
    catch ME
        % Enhance error message
        fprintf(2, 'Error in %s %s: %s\n', command, subcommand, ME.message);
        fprintf(2, 'For help, type: help rdt_%s_%s\n', lower(command), lower(subcommand));
        rethrow(ME);
    end
end
```

### Example Implementation: Pattern Create

```matlab
% +maDisplayTools/+cli/+pattern/create.m
function create(varargin)
    % CREATE Create pattern from array, script, or function
    %
    % Usage:
    %   rdt pattern create (Name, Value, ...)
    %
    % Name-Value Arguments:
    %   Array (numeric)           Pattern array
    %   Script (string)           Path to script
    %   Function (function_handle) Function returning array
    %   Name (string)             Pattern name (required)
    %   Arena (string)            Arena preset
    %   ArenaRows (int)           Custom arena rows
    %   ArenaCols (int)           Custom arena cols
    %   GsMode (string)           "binary" or "grayscale"
    %   Stretch (numeric)         Stretch values
    %   OutputDir (string)        Output directory
    %   Preview (logical)         Preview after creation
    
    p = inputParser;
    p.CaseSensitive = false;
    
    addParameter(p, 'Array', []);
    addParameter(p, 'Script', '');
    addParameter(p, 'Function', []);
    addParameter(p, 'Name', '', @(x) ~isempty(x));
    addParameter(p, 'Arena', '');
    addParameter(p, 'ArenaRows', []);
    addParameter(p, 'ArenaCols', []);
    addParameter(p, 'GsMode', 'grayscale');
    addParameter(p, 'Stretch', []);
    addParameter(p, 'OutputDir', './patterns');
    addParameter(p, 'Preview', false);
    
    parse(p, varargin{:});
    opts = p.Results;
    
    % Validate name
    if isempty(opts.Name)
        error('Name argument is required');
    end
    
    % Get frames from Array, Script, or Function
    frames = getFrames(opts);
    
    % Create arena
    arena = createArena(opts);
    
    % Create pattern
    fprintf('Creating pattern "%s"...\n', opts.Name);
    pat = Pattern(frames, arena, opts.GsMode, opts.Stretch);
    pat.name = opts.Name;
    
    % Save
    filepath = PatternFile.save(pat, opts.OutputDir, opts.Name);
    
    % Print summary
    fprintf('Pattern created: %s\n', filepath);
    fprintf('  Size: %dx%d pixels\n', pat.height, pat.width);
    fprintf('  Frames: %d total (%d×%d)\n', pat.totalFrames, pat.numX, pat.numY);
    fprintf('  Mode: %s (%d levels)\n', pat.gsMode, pat.gsVal);
    
    % Preview if requested
    if opts.Preview
        rdt('pattern', 'preview', filepath);
    end
end

function frames = getFrames(opts)
    % Get frames from Array, Script, or Function
    
    sourceCount = ~isempty(opts.Array) + ~isempty(opts.Script) + ~isempty(opts.Function);
    
    if sourceCount == 0
        error('One of Array, Script, or Function must be provided');
    elseif sourceCount > 1
        error('Only one of Array, Script, or Function can be provided');
    end
    
    if ~isempty(opts.Array)
        frames = opts.Array;
        
    elseif ~isempty(opts.Script)
        % Run script in base workspace
        fprintf('Loading from script: %s\n', opts.Script);
        [~, scriptName] = fileparts(opts.Script);
        evalin('base', scriptName);
        
        if evalin('base', 'exist(''frames'', ''var'')')
            frames = evalin('base', 'frames');
        else
            error('Script must create a variable named ''frames''');
        end
        
    else % Function
        fprintf('Generating from function...\n');
        frames = opts.Function();
    end
    
    if isempty(frames)
        error('Frames array is empty');
    end
end

function arena = createArena(opts)
    % Create arena from options
    
    if ~isempty(opts.Arena)
        % Use preset
        switch lower(opts.Arena)
            case 'g4-3row'
                arena = Arena.G4_3Row();
            case 'g4-4row'
                arena = Arena.G4_4Row();
            case 'g41-3row'
                arena = Arena.custom(3, 12, 'G41');
            case 'g41-4row'
                arena = Arena.custom(4, 12, 'G41');
            otherwise
                error('Unknown arena: %s', opts.Arena);
        end
        
    elseif ~isempty(opts.ArenaRows) && ~isempty(opts.ArenaCols)
        % Custom arena
        arena = Arena.custom(opts.ArenaRows, opts.ArenaCols);
        
    else
        error('Either Arena or both ArenaRows and ArenaCols must be provided');
    end
end
```

### Configuration Manager

```matlab
% +maDisplayTools/+cli/ConfigManager.m
classdef ConfigManager < handle
    % CONFIGMANAGER Persistent configuration storage
    
    properties (Constant)
        CONFIG_FILE = fullfile(prefdir, 'rdt_config.mat');
    end
    
    methods (Static)
        function config = load()
            if exist(ConfigManager.CONFIG_FILE, 'file')
                data = load(ConfigManager.CONFIG_FILE);
                config = data.config;
            else
                config = ConfigManager.defaults();
            end
        end
        
        function save(config)
            save(ConfigManager.CONFIG_FILE, 'config');
        end
        
        function config = defaults()
            config = struct();
            config.default_arena = 'g4-4row';
            config.default_output_dir = './patterns';
            config.default_gs_mode = 'grayscale';
            config.auto_preview = false;
        end
        
        function value = get(key)
            config = ConfigManager.load();
            if isfield(config, key)
                value = config.(key);
            else
                defaults = ConfigManager.defaults();
                value = defaults.(key);
            end
        end
        
        function set(key, value)
            config = ConfigManager.load();
            config.(key) = value;
            ConfigManager.save(config);
        end
        
        function reset()
            config = ConfigManager.defaults();
            ConfigManager.save(config);
        end
    end
end
```

## Help System Integration

Each command function has comprehensive help documentation:

```matlab
% User types:
help rdt

% Shows main help

% User types:
help rdt_pattern_create

% Shows detailed help for pattern create command
```

This leverages MATLAB's built-in help system rather than building a custom one.

## Usage Workflows

### Workflow 1: Create Pattern from Workspace

```matlab
% Generate pattern in workspace
frames = zeros(64, 192, 24);
for i = 1:24
    frames(1+2*(i-1):2*i, :, i) = 15;
end

% Create pattern
rdt pattern create Array=frames, Name="horizontal_bars", Arena="g4-4row"

% Preview
rdt pattern preview "patterns/pat0001_horizontal_bars.pat"
```

### Workflow 2: Batch Pattern Creation

```matlab
% Create multiple patterns from scripts
patterns = ["grating", "starfield", "rotation"];

for i = 1:length(patterns)
    script = sprintf("%s.m", patterns(i));
    rdt pattern create Script=script, Name=patterns(i), Arena="g4-4row"
end

% Validate all
files = dir("patterns/*.pat");
for i = 1:length(files)
    filepath = fullfile(files(i).folder, files(i).name);
    rdt pattern validate filepath, Arena="g4-4row"
end
```

### Workflow 3: Experiment Setup

```matlab
% First, validate protocol
results = rdt experiment validate "protocol.yaml"

if results.isValid
    % Create experiment
    rdt experiment create Protocol="protocol.yaml", Output="./experiments/exp001"
else
    fprintf('Protocol has errors:\n');
    disp(results.errors);
end
```

### Workflow 4: Interactive Pattern Development

```matlab
% Configure environment
rdt config set "default_arena", "g4-4row"
rdt config set "auto_preview", true

% Create pattern (will auto-preview)
rdt pattern create Function=@makePattern, Name="test", Arena="g4-4row"

% Get info programmatically
info = rdt pattern info "patterns/pat0001_test.pat"
fprintf('Created pattern with %d frames\n', info.numFrames);
```

## Benefits of This Design

### 1. MATLAB-Native
- Works in command window (no shell switching)
- Uses MATLAB's name-value argument syntax
- Integrates with MATLAB's help system
- Returns data structures for further processing

### 2. Simple Implementation
- No complex plugin architecture
- Just function calls and dispatching
- Easy to understand and maintain
- Straightforward testing

### 3. Interactive Workflow
- Can pass workspace variables directly
- Can capture return values
- Can chain operations
- Works with MATLAB debugger

### 4. Consistent with Python CLI
- Same command structure
- Similar parameter names
- Compatible workflows
- Easy to document across both tools

### 5. Extensible
- Add new commands by adding functions
- No central registry to update
- Self-documenting through help
- Easy to add options

## Comparison with Python CLI

| Feature | Python (`pdt`) | MATLAB (`rdt`) |
|---------|----------------|----------------|
| Entry point | Shell command | MATLAB function |
| Arguments | `--option value` | `Option=value` |
| Help | `pdt --help` | `help mdt` |
| Data passing | Files/stdin | Variables |
| Return values | Exit codes | Structs |
| Environment | System shell | MATLAB workspace |
| Installation | pip/PATH | MATLAB path |

The MATLAB CLI adapts the Python CLI's command structure to MATLAB's idioms, providing a familiar interface while respecting each platform's conventions.

## Testing Strategy

### Unit Tests
```matlab
% Test pattern creation
frames = ones(64, 192, 4);
rdt pattern create Array=frames, Name="test", Arena="g4-4row"
assert(exist("patterns/pat0001_test.pat", "file") > 0);

% Test info
info = rdt pattern info "patterns/pat0001_test.pat"
assert(info.numFrames == 4);

% Test config
rdt config set "default_arena", "g4-3row"
config = rdt config show
assert(strcmp(config.default_arena, "g4-3row"));
```

### Integration Tests
```matlab
% Full workflow test
rdt pattern create Array=ones(64,192,4), Name="integration_test", Arena="g4-4row"
info = rdt pattern info "patterns/pat0001_integration_test.pat"
results = rdt pattern validate "patterns/pat0001_integration_test.pat", Arena="g4-4row"
assert(results.valid);
```

## Migration from Old API

Old API:
```matlab
maDisplayTools.generate_pattern_from_array(Pats, './patterns', 'mypattern', 16, [], 0);
```

New CLI:
```matlab
rdt pattern create Array=Pats, Name="mypattern", Arena="g4-4row", OutputDir="./patterns"
```

Benefits:
- Clearer parameter names
- No need to remember parameter order
- Built-in validation
- Easier to discover options

## Documentation Requirements

1. **Function Help**: Each command function has detailed help
2. **Examples**: Each help includes practical examples
3. **User Guide**: Comprehensive guide with workflows
4. **Migration Guide**: How to convert from old API
5. **Quick Reference**: Command summary cheat sheet

## Future Enhancements

### Tab Completion (R2021b+)
```matlab
% Register tab completion
matlab.internal.addCompletions('rdt', @rdtCompletions);

function completions = rdtCompletions(text, pos)
    % Provide context-aware completions
    completions = {'pattern', 'experiment', 'arena', 'config'};
end
```

### Default Arguments from Config
```matlab
% If Arena not specified, use config default
if isempty(opts.Arena)
    opts.Arena = maDisplayTools.cli.ConfigManager.get('default_arena');
end
```

### Command Aliases
```matlab
% Short aliases
function varargout = rdtp(varargin)
    % Alias for rdt pattern
    [varargout{1:nargout}] = rdt('pattern', varargin{:});
end
```

## Conclusion

This MATLAB-native CLI design provides:
- **Familiar syntax** for MATLAB users
- **Compatible commands** with Python CLI
- **Simple implementation** using standard MATLAB features
- **Interactive workflow** integration
- **Extensible architecture** for future commands

The design respects MATLAB's interactive environment while maintaining consistency with the Python implementation's command structure and parameters.
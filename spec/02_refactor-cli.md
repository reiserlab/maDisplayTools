# Command-Line Interface for maDisplayTools

## Executive Summary

This document outlines a command-line interface to be added as part of the `maDisplayTools` refactoring. The CLI runs **within the MATLAB command window**, embracing MATLAB's interactive environment while providing a consistent, discoverable interface for common tasks.

The CLI uses a simple entry point function `pdt()` (short for **P**anel **D**isplay **T**ools) that dispatches to specialized command functions, leveraging MATLAB's name-value arguments for clean, readable syntax.

This CLI builds on the `Arena`, `Pattern`, and `PatternFile` classes defined in the OOP refactoring specification.

## Current Implementation (To Be Replaced)

The existing `maDisplayTools` implementation that will be replaced provides only a programmatic API through static methods:

**Pattern Creation:**
```matlab
% Create pattern from 4D array
maDisplayTools.generate_pattern_from_array(Pats, save_dir, patName, gs_val, stretch, arena_pitch);
```

**Pattern Loading and Preview:**
```matlab
% Load pattern file
[frames, meta] = maDisplayTools.load_pat(filepath);

% Preview with GUI
[frames, meta] = maDisplayTools.preview_pat(filepath);
```

**Experiment Creation:**
```matlab
% Create experiment folder from YAML
maDisplayTools.create_experiment_folder_g41(yaml_file_path, experiment_folder_path);
```

**Characteristics:**
- Primarily programmatic API (function calls with positional/optional arguments)
- No command-line style interface within MATLAB
- Users must remember parameter order and available options
- Limited discoverability (must read documentation or source code)
- Pattern creation requires multiple parameters passed separately
- No interactive help for individual operations
- No configuration management

The refactored implementation will add a discoverable, self-documenting command interface while maintaining the ability to use the underlying classes programmatically.

## Design Philosophy: MATLAB-Native CLI

### Key Principles

1. **Command Window First**: Designed for MATLAB's interactive environment
2. **Name-Value Arguments**: Uses MATLAB's modern `arguments` blocks for validation
3. **Return Values**: Commands can return data structures for further processing
4. **Tab Completion**: Compatible with MATLAB's tab completion (R2021b+)
5. **Help Integration**: Works with MATLAB's `help` command
6. **Simple Dispatch**: No complex plugin architecture - just function calls
7. **Workspace Integration**: Direct access to workspace variables

## Command Structure

```matlab
pdt <command> <subcommand> (Name, Value, ...)
```

Commands return data structures when useful, allowing:
```matlab
% Use command for side effects (save file)
pdt pattern create Array=frames, Name="test", Arena="g4-4row"

% Capture return value for further use
info = pdt pattern info "pattern.pat"
fprintf('Pattern has %d frames\n', info.numFrames);
```

## Command Hierarchy

```
pdt
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

Help is integrated: `help pdt`, `help pdt_pattern_create`, etc.

## Detailed Command Specifications

### Pattern Commands

#### `pdt pattern create`

Create pattern from array, script, or function.

**Syntax:**
```matlab
pdt pattern create (Name, Value, ...)

Name-Value Arguments:
  Array (numeric)           Pattern array [rows, cols, numX, numY] (required)
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
pdt pattern create Array=frames, Name="random", Arena="g4-4row", GsMode="binary"

% Custom arena
frames = zeros(80, 128, 12);
pdt pattern create Array=frames, Name="custom", ArenaRows=5, ArenaCols=8

% Create and preview
pdt pattern create Array=frames, Name="test", Arena="g4-4row", Preview=true

% With custom output directory
pdt pattern create Array=frames, Name="exp1", Arena="g4-4row", ...
    OutputDir="./experiments/exp001/patterns"

```

#### `pdt pattern info`

Display pattern file metadata.

**Syntax:**
```matlab
info = pdt pattern info (PatternFile, Name, Value, ...)

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
pdt pattern info "patterns/pat0001_test.pat"

% Output:
%   Pattern: pat0001_test.pat
%   ID: 1
%   Dimensions: 64 x 192 pixels (4 x 12 panels)
%   Frames: 96 total (96 x 1)
%   Mode: grayscale (16 levels)
%   Generation: G4

% Get info structure
info = pdt pattern info "patterns/pat0001_test.pat"
fprintf('Pattern has %d frames\n', info.numFrames);

% Detailed info
pdt pattern info "patterns/pat0001_test.pat", Verbose=true
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

#### `pdt pattern preview`

Launch interactive pattern preview.

**Syntax:**
```matlab
pdt pattern preview (PatternFile, Name, Value, ...)

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
pdt pattern preview "patterns/pat0001_test.pat"

% Start at specific frame
pdt pattern preview "patterns/pat0001_test.pat", StartFrame=10

% Export as animated GIF
pdt pattern preview "patterns/pat0001_test.pat", Export="gif", ...
    ExportPath="animation.gif"

% Export all frames as PNG images
pdt pattern preview "patterns/pat0001_test.pat", Export="frames", ...
    ExportPath="./frames/"

% Export frames as TIFF
pdt pattern preview "patterns/pat0001_test.pat", Export="frames", ...
    ExportPath="./frames/", ExportFormat="tiff"
```

#### `pdt pattern validate`

Validate pattern file(s) against arena configuration.

**Syntax:**
```matlab
results = pdt pattern validate (PatternFiles, Name, Value, ...)

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
pdt pattern validate "patterns/pat0001_test.pat", Arena="g4-4row"

% Output:
%   ✓ pat0001_test.pat: Valid
%     Dimensions: 64 x 192 (matches g4-4row)
%     Frames: 96

% Validate multiple files
files = ["patterns/pat0001.pat", "patterns/pat0002.pat"];
pdt pattern validate files, Arena="g4-4row"

% Validate all patterns in directory
% (Note: MATLAB's dir() doesn't support wildcards in path argument directly,
% but you can filter results)
results = pdt pattern validate "patterns/*.pat", ArenaRows=4, ArenaCols=12

% Strict mode (warnings become errors)
pdt pattern validate "patterns/*.pat", Arena="g4-4row", Strict=true
```

**Returned Structure:**
```matlab
results(i).file       % Filename
results(i).valid      % true/false
results(i).errors     % Cell array of error messages
results(i).warnings   % Cell array of warnings
```

### Experiment Commands

#### `pdt experiment create`

Create experiment folder from YAML protocol.

**Syntax:**
```matlab
pdt experiment create (Name, Value, ...)

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
pdt experiment create Protocol="protocol.yaml", Output="./experiments/exp001"

% Dry run (show what would happen)
pdt experiment create Protocol="protocol.yaml", Output="./exp001", DryRun=true

% Force overwrite
pdt experiment create Protocol="protocol.yaml", Output="./exp001", Force=true

% Override arena type
pdt experiment create Protocol="protocol.yaml", Output="./exp001", Arena="g41-4row"

% Quiet mode
pdt experiment create Protocol="protocol.yaml", Output="./exp001", Verbose=false
```

#### `pdt experiment validate`

Validate experiment protocol file.

**Syntax:**
```matlab
results = pdt experiment validate (ProtocolFile, Name, Value, ...)

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
pdt experiment validate "protocol.yaml"

% Output:
%   ✓ Protocol is valid
%   Patterns: 12 referenced, 12 found
%   Conditions: 4

% Get results
results = pdt experiment validate "protocol.yaml"
if results.isValid
    fprintf('Protocol is valid!\n');
end

% Detailed validation
pdt experiment validate "protocol.yaml", Verbose=true
```

#### `pdt experiment info`

Show experiment protocol information.

**Syntax:**
```matlab
info = pdt experiment info (ProtocolFile, Name, Value, ...)

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
pdt experiment info "protocol.yaml"

% Output:
%   Experiment Protocol
%   Arena: g4-4row
%   Patterns: 12
%   Conditions: 4
%   Duration: ~45 minutes

% Show pattern details
pdt experiment info "protocol.yaml", ShowPatterns=true

% Get info structure
info = pdt experiment info "protocol.yaml"
fprintf('Experiment uses %d patterns\n', info.numPatterns);
```

### Arena Commands

#### `pdt arena list`

List available arena presets.

**Syntax:**
```matlab
arenas = pdt arena list (Name, Value, ...)

Name-Value Arguments:
  Verbose (logical)         Show detailed specs [default: false]

Returns:
  arenas (struct array)     Arena configurations
```

**Examples:**
```matlab
% List arenas
pdt arena list

% Output:
%   Available Arenas:
%   1. g4-3row    (G4,  3 rows × 12 cols =  48 panels,  48 × 192 pixels)
%   2. g4-4row    (G4,  4 rows × 12 cols =  48 panels,  64 × 192 pixels)
%   3. g41-3row   (G41, 3 rows × 12 cols =  48 panels,  48 × 192 pixels)
%   4. g41-4row   (G41, 4 rows × 12 cols =  48 panels,  64 × 192 pixels)

% Detailed list
pdt arena list Verbose=true

% Get arena list
arenas = pdt arena list
for i = 1:length(arenas)
    fprintf('%s: %dx%d pixels\n', arenas(i).name, arenas(i).height, arenas(i).width);
end
```

#### `pdt arena info`

Show detailed arena configuration.

**Syntax:**
```matlab
arena = pdt arena info (ArenaName, Name, Value, ...)

Arguments:
  ArenaName (string)        Arena preset name

Returns:
  arena (struct)            Arena configuration
```

**Examples:**
```matlab
% Show arena details
pdt arena info "g4-4row"

% Output:
%   Arena: g4-4row
%   Generation: G4
%   Configuration:
%     Rows: 4 panels (64 pixels)
%     Cols: 12 panels (192 pixels)
%     Total: 48 panels (12,288 pixels)
%   Panel Size: 16 × 16 pixels

% Get arena object
arena = pdt arena info "g4-4row"
fprintf('Total pixels: %d\n', arena.width * arena.height);
```

### Configuration Commands

#### `pdt config show`

Display current configuration.

**Syntax:**
```matlab
config = pdt config show

Returns:
  config (struct)           Current configuration
```

**Examples:**
```matlab
% Show config
pdt config show

% Output:
%   Configuration:
%     default_arena: g4-4row
%     default_output_dir: ./patterns
%     default_gs_mode: grayscale
%     auto_preview: false

% Get config
config = pdt config show
fprintf('Default arena: %s\n', config.default_arena);
```

#### `pdt config set`

Set configuration value.

**Syntax:**
```matlab
pdt config set (Key, Value)

Arguments:
  Key (string)              Configuration key
  Value                     Configuration value
```

**Examples:**
```matlab
% Set default arena
pdt config set "default_arena", "g4-4row"

% Set default output directory
pdt config set "default_output_dir", "./my_patterns"

% Set default grayscale mode
pdt config set "default_gs_mode", "grayscale"

% Enable auto-preview
pdt config set "auto_preview", true
```

**Available Keys:**
- `default_arena` - Default arena type (string)
- `default_output_dir` - Default output directory (string)
- `default_gs_mode` - Default grayscale mode: "binary" or "grayscale"
- `auto_preview` - Auto-preview after creation (logical)

#### `pdt config reset`

Reset configuration to defaults.

**Syntax:**
```matlab
pdt config reset (Name, Value, ...)

Name-Value Arguments:
  Confirm (logical)         Skip confirmation [default: false]
```

**Examples:**
```matlab
% Reset (with confirmation)
pdt config reset

% Reset without confirmation
pdt config reset Confirm=true
```

## Implementation Architecture

### File Structure

```
maDisplayTools/
├── pdt.m                          % Main entry point
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
│       └── ConfigManager.m
├── examples/
└── spec/
```

### Main Entry Point

```matlab
% pdt.m
function varargout = pdt(command, subcommand, varargin)
    % PDT Panel Display Tools command-line interface
    %
    %   pdt <command> <subcommand> (Name, Value, ...)
    %
    % Commands:
    %   pattern       Pattern creation and management
    %   experiment    Experiment folder management
    %   arena         Arena configuration information
    %   config        Configuration management
    %
    % Examples:
    %   pdt pattern create Array=frames, Name="test", Arena="g4-4row"
    %   pdt pattern info "pattern.pat"
    %   pdt pattern preview "pattern.pat"
    %   pdt experiment create Protocol="protocol.yaml", Output="./exp001"
    %   pdt arena list
    %   pdt config show
    %
    % For help on specific commands:
    %   help pdt_pattern_create
    %   help pdt_experiment_create
    %   help pdt_arena_list
    
    % Handle no arguments - show help
    if nargin == 0
        help pdt
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
        error('Subcommand required. Type: help pdt_%s_<subcommand>', command);
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
        fprintf(2, 'For help, type: help pdt_%s_%s\n', lower(command), lower(subcommand));
        rethrow(ME);
    end
end
```

### Example Implementation: Pattern Create

The command now relies on an `arguments` block for validation instead of `inputParser`.

```matlab
% +maDisplayTools/+cli/+pattern/create.m
function create(varargin)
    % CREATE Create pattern from array, script, or function
    %
    % Usage:
    %   pdt pattern create (Name, Value, ...)
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

    arguments
        Array (:,:,:,:) {mustBeNumeric} = []
        Script (1,:) char = ''
        Function function_handle = []
        Name (1,:) char {mustBeNonempty}
        Arena (1,:) char = ''
        ArenaRows (1,1) double {mustBePositive} = []
        ArenaCols (1,1) double {mustBePositive} = []
        GsMode (1,:) char {mustBeMember(GsMode, ["binary","grayscale"])} = 'grayscale'
        Stretch (:,:) double = []
        OutputDir (1,:) char = './patterns'
        Preview (1,1) logical = false
    end

    opts.Array = Array; %#ok<NASGU>
    opts.Script = Script;
    opts.Function = Function;
    opts.Name = Name;
    opts.Arena = Arena;
    opts.ArenaRows = ArenaRows;
    opts.ArenaCols = ArenaCols;
    opts.GsMode = GsMode;
    opts.Stretch = Stretch;
    opts.OutputDir = OutputDir;
    opts.Preview = Preview;

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
        pdt('pattern', 'preview', filepath);
    end
end
```

function frames = getFrames(opts)
    % Get frames from Array

    if isempty(opts.Array)
        error('Array argument is required');
    end

    frames = opts.Array;

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
                arena = Arena.custom(3, 12, 'G4');
            case 'g4-4row'
                arena = Arena.custom(4, 12, 'G4');
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
        CONFIG_FILE = fullfile(prefdir, 'pdt_config.mat');
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
help pdt

% Shows main help

% User types:
help pdt_pattern_create

% Shows detailed help for pattern create command
```

This leverages MATLAB's built-in help system rather than building a custom one.

## Usage Workflows (After Refactoring)

### Workflow 1: Create Pattern from Workspace

```matlab
% Generate pattern in workspace
frames = zeros(64, 192, 24);
for i = 1:24
    frames(1+2*(i-1):2*i, :, i) = 15;
end

% Create pattern
pdt pattern create Array=frames, Name="horizontal_bars", Arena="g4-4row"

% Preview
pdt pattern preview "patterns/pat0001_horizontal_bars.pat"

% Info shows grayscale mode and arena config
```

### Workflow 2: Batch Pattern Creation

```matlab
% Create multiple patterns from workspace
for i = 1:10
    % Generate different pattern for each iteration
    frames = generatePattern(i);  % Your custom function
    name = sprintf("pattern_%02d", i);
    pdt pattern create Array=frames, Name=name, Arena="g4-4row"
end

% Validate all
files = dir("patterns/*.pat");
for i = 1:length(files)
    filepath = fullfile(files(i).folder, files(i).name);
    pdt pattern validate filepath, Arena="g4-4row"
end
```

### Workflow 3: Experiment Setup

```matlab
% First, validate protocol
results = pdt experiment validate "protocol.yaml"

if results.isValid
    % Create experiment
    pdt experiment create Protocol="protocol.yaml", Output="./experiments/exp001"
else
    fprintf('Protocol has errors:\n');
    disp(results.errors);
end
```

### Workflow 4: Interactive Pattern Development

```matlab
% Configure environment
pdt config set "default_arena", "g4-4row"
pdt config set "auto_preview", true

% Create pattern (will auto-preview)
frames = rand(64, 192, 96) > 0.5;
pdt pattern create Array=frames, Name="test", Arena="g4-4row"

% Get info programmatically
info = pdt pattern info "patterns/pat0001_test.pat"
fprintf('Created pattern with %d frames\n', info.numFrames);

```

## Benefits of Refactored Design


### 1. MATLAB-Native
The refactored CLI works in the command window (no shell switching), uses MATLAB's name-value argument syntax, and integrates with MATLAB's help system. This replaces the current approach of calling static methods with positional arguments.

### 2. Improved Discoverability
Unlike the current implementation where users must read documentation to discover available options, the refactored CLI provides self-documenting commands through MATLAB's help system and clear command hierarchy.

### 3. Interactive Workflow
The refactored design allows passing workspace variables directly, capturing return values, and chaining operations. This builds on the current programmatic API while making it more accessible.

### 4. Configuration Management
The refactored implementation adds configuration management (default arena, output directory, etc.) which does not exist in the current implementation.

## Testing Strategy

### Unit Tests
```matlab
% Test pattern creation
frames = ones(64, 192, 4);
pdt pattern create Array=frames, Name="test", Arena="g4-4row"
assert(exist("patterns/pat0001_test.pat", "file") > 0);

% Test info
info = pdt pattern info "patterns/pat0001_test.pat"
assert(info.numFrames == 4);

% Test config
pdt config set "default_arena", "g4-3row"
config = pdt config show
assert(strcmp(config.default_arena, "g4-3row"));
```

### Integration Tests
```matlab
% Full workflow test
pdt pattern create Array=ones(64,192,4), Name="integration_test", Arena="g4-4row"
info = pdt pattern info "patterns/pat0001_integration_test.pat"
results = pdt pattern validate "patterns/pat0001_integration_test.pat", Arena="g4-4row"
assert(results.valid);
```

## Documentation Requirements

1. **Function Help**: Each command function has detailed help
2. **Examples**: Each help includes practical examples
3. **User Guide**: Comprehensive guide with workflows
4. **Quick Reference**: Command summary cheat sheet
5. **Tutorial**: Step-by-step introduction for new users

## Future Enhancements

### Tab Completion (R2021b+)
```matlab
% Register tab completion
matlab.internal.addCompletions('pdt', @pdtCompletions);

function completions = pdtCompletions(text, pos)
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
function varargout = pdtp(varargin)
    % Alias for pdt pattern
    [varargout{1:nargout}] = pdt('pattern', varargin{:});
end
```

## Conclusion

This refactoring adds a MATLAB-native CLI to the codebase that provides:
- **Natural syntax** replacing positional arguments with name-value pairs
- **Simple implementation** using standard MATLAB features
- **Interactive workflow** integration with workspace variables
- **Extensible architecture** for future commands
- **Discoverable interface** through help system (unlike current implementation)

The refactored CLI will complement the object-oriented classes while making the toolkit more accessible and easier to use than the current static method implementation.
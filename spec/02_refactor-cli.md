# Command-Line Interface Refactoring Specification for maDisplayTools

## Executive Summary

This document outlines a comprehensive plan to create a unified, professional command-line interface for `maDisplayTools` in MATLAB. Unlike Python's Click-based CLI which runs from the system shell, this MATLAB CLI is designed to run **from within the MATLAB command window**, providing a streamlined, consistent interface while maintaining MATLAB's interactive workflow.

**Important Note**: This CLI refactoring should be implemented **after** the Object-Oriented Programming refactoring described in `01_refactor-oop.md`, as it will leverage the new OOP architecture for cleaner implementation and better separation of concerns.

## Current State Analysis

### Existing Interface

Currently, the package uses static methods with verbose calling syntax:

```matlab
% Pattern creation
maDisplayTools.generate_pattern_from_array(Pats, save_dir, patName, gs_val, stretch, arena_pitch);

% Pattern preview
maDisplayTools.preview_pat(filepath);

% Experiment creation
maDisplayTools.create_experiment_folder_g41(yaml_path, experiment_path);
```

### Issues with Current Approach

1. **Verbose Syntax**: Long class name (`maDisplayTools`) must be typed for every operation
2. **Inconsistent Naming**: Mix of `generate_`, `preview_`, `create_` prefixes
3. **Poor Discoverability**: Users must read documentation to know what functions exist
4. **No Tab Completion**: Cannot discover available commands through tab completion
5. **Inconsistent Arguments**: Different functions use different argument conventions
6. **No Help System**: No unified way to get help on available commands
7. **No Parameter Validation**: Manual checking of arguments in each function
8. **No Command History**: Difficult to recall complex command invocations

## Proposed CLI Architecture for MATLAB

### Design Philosophy

The new CLI will use a **command pattern** with a main entry point function `mdt()` that provides:

1. **Intuitive Syntax**: Short, memorable commands
2. **Tab Completion**: Discover commands and options via tab
3. **Consistent Interface**: All commands follow the same patterns
4. **Rich Help System**: Built-in help for all commands
5. **Name-Value Arguments**: Modern MATLAB argument syntax
6. **Input Validation**: Automatic validation using `arguments` blocks
7. **Interactive Workflow**: Designed for MATLAB's interactive nature

### Command Structure

The CLI will be invoked from MATLAB as:

```matlab
rdt <command> <subcommand> (Name, Value, ...)
```

Where `rdt` stands for "**R**eiser **D**isplay**T**ools".

### Command Hierarchy

```
rdt
├── pattern
│   ├── create        % Create new patterns
│   ├── preview       % Preview pattern files
│   ├── validate      % Validate pattern files
│   ├── info          % Show pattern information
│   └── convert       % Convert between formats
├── experiment
│   ├── create        % Create experiment folder
│   ├── validate      % Validate experiment protocol
│   └── info          % Show experiment details
├── arena
│   ├── list          % List available arena presets
│   └── info          % Show arena configuration
├── config
│   ├── show          % Show current configuration
│   ├── set           % Set configuration values
│   └── reset         % Reset to defaults
└── help              % Show help information
```

## Detailed Command Specifications

### Global Syntax

All commands follow this pattern:

```matlab
rdt <command> <subcommand> (Name, Value, ...)
```

For help on any command:

```matlab
rdt help
rdt help <command>
rdt help <command> <subcommand>
```

### Pattern Commands

#### `rdt pattern create`

Create patterns from MATLAB scripts, functions, or arrays.

```matlab
rdt pattern create (Options...)

Name-Value Arguments:
  Script (string)           % Path to MATLAB script that defines 'Pats' variable
  Function (function_handle)% Function handle that returns pattern array
  Array (numeric)           % Pattern array directly (rows, cols, numX, [numY])
  Name (string)             % Pattern name (required)
  OutputDir (string)        % Directory to save pattern [default: './patterns']
  ArenaType (string)        % Arena type: 'g4-3row', 'g4-4row', 'g41-3row', 'g41-4row'
  ArenaRows (int)           % Custom arena row count (panels)
  ArenaCols (int)           % Custom arena column count (panels)
  Grayscale (int)           % 2 (binary) or 16 (grayscale) [default: 16]
  Pitch (double)            % Arena pitch angle [default: 0.0]
  Stretch (numeric)         % Stretch values (numX, numY) [default: ones]
  Preview (logical)         % Preview after creation [default: false]

Examples:
  % Create from script that defines 'Pats' variable
  rdt pattern create Script="my_pattern.m", Name="vertical-bars", ArenaType="g4-4row"

  % Create from function handle
  rdt pattern create Function=@makeVerticalBars, Name="vbars", ArenaType="g4-3row"

  % Create from array in workspace
  rdt pattern create Array=Pats, Name="test", ArenaRows=3, ArenaCols=12

  % Create and preview
  rdt pattern create Script="my_pattern.m", Name="demo", Preview=true

  % Binary pattern
  rdt pattern create Array=Pats, Name="binary", Grayscale=2, ArenaType="g4-4row"

  % Custom arena
  rdt pattern create Array=Pats, Name="custom", ArenaRows=5, ArenaCols=10
```

#### `rdt pattern preview`

Preview pattern files interactively or export frames.

```matlab
rdt pattern preview (PatternFile, Options...)

Arguments:
  PatternFile (string)      % Path to .pat file (required)

Name-Value Arguments:
  Frame (int)               % Start at specific frame [default: 0]
  NoGUI (logical)           % Print info only, don't show GUI [default: false]
  ExportGIF (string)        % Export animation as GIF (filename)
  ExportFrames (string)     % Export all frames to directory
  ExportFormat (string)     % Image format: 'png', 'tiff', 'jpg' [default: 'png']

Examples:
  % Preview pattern (launches interactive figure)
  rdt pattern preview "patterns/pat0001_vertical_bars.pat"

  % Start at frame 10
  rdt pattern preview "patterns/pat0001_test.pat", Frame=10

  % Export as GIF
  rdt pattern preview "patterns/pat0001_test.pat", ExportGIF="animation.gif", NoGUI=true

  % Export all frames as PNG
  rdt pattern preview "patterns/pat0001_test.pat", ExportFrames="./frames/"

  % Export as TIFF
  rdt pattern preview "patterns/pat0001_test.pat", ExportFrames="./frames/", ExportFormat="tiff"
```

#### `rdt pattern validate`

Validate pattern files against arena specifications.

```matlab
rdt pattern validate (PatternFiles, Options...)

Arguments:
  PatternFiles (string|cell) % One or more pattern files to validate

Name-Value Arguments:
  ArenaType (string)         % Expected arena type
  ArenaRows (int)            % Expected arena rows (panels)
  ArenaCols (int)            % Expected arena columns (panels)
  Strict (logical)           % Fail on warnings [default: false]
  OutputJSON (string)        % Save results as JSON to file
  Verbose (logical)          % Show detailed results [default: false]

Returns:
  results (struct)           % Validation results for each file

Examples:
  % Validate single pattern
  rdt pattern validate "patterns/pat0001_test.pat", ArenaType="g4-4row"

  % Validate multiple patterns
  files = ["patterns/pat0001.pat", "patterns/pat0002.pat"];
  rdt pattern validate files, ArenaRows=4, ArenaCols=12

  % Get results structure
  results = rdt pattern validate "patterns/*.pat", ArenaType="g4-4row"

  % Strict mode (warnings are errors)
  rdt pattern validate "patterns/*.pat", Strict=true

  % Save as JSON
  rdt pattern validate "patterns/*.pat", OutputJSON="validation.json"
```

#### `rdt pattern info`

Display pattern metadata and statistics.

```matlab
rdt pattern info (PatternFile, Options...)

Arguments:
  PatternFile (string)       % Path to .pat file (required)

Name-Value Arguments:
  Verbose (logical)          % Show detailed information [default: false]
  OutputJSON (string)        % Save results as JSON to file

Returns:
  info (struct)              % Pattern metadata

Examples:
  % Basic info
  rdt pattern info "patterns/pat0001_test.pat"

  Output:
    Pattern ID: 1
    Dimensions: 64 x 192 pixels (4 x 12 panels)
    Frames: 24 (X) x 1 (Y) = 24 total
    Grayscale: 16 levels (4-bit)
    Protocol: G4_V1
    File size: 73,768 bytes

  % Detailed info
  rdt pattern info "patterns/pat0001_test.pat", Verbose=true

  % Get info structure
  info = rdt pattern info "patterns/pat0001_test.pat"
  fprintf('Pattern has %d frames\n', info.totalFrames);

  % Save as JSON
  rdt pattern info "patterns/pat0001_test.pat", OutputJSON="info.json"
```

#### `rdt pattern convert`

Convert patterns between formats (future feature).

```matlab
rdt pattern convert (InputFile, OutputFile, Options...)

Arguments:
  InputFile (string)         % Input pattern file
  OutputFile (string)        % Output pattern file

Name-Value Arguments:
  FromFormat (string)        % Input format: 'pat', 'mat' [auto-detect if empty]
  ToFormat (string)          % Output format: 'pat', 'mat' [auto-detect if empty]

Examples:
  % Convert MAT to PAT
  rdt pattern convert "old_pattern.mat", "new_pattern.pat"

  % Explicit formats
  rdt pattern convert "data.dat", "pattern.pat", FromFormat="mat", ToFormat="pat"
```

### Experiment Commands

#### `rdt experiment create`

Create experiment folder from YAML protocol.

```matlab
rdt experiment create (Options...)

Name-Value Arguments:
  Protocol (string)          % YAML protocol file (required)
  Output (string)            % Experiment output directory (required)
  ArenaType (string)         % Arena type (overrides YAML)
  Force (logical)            % Overwrite existing folder [default: false]
  DryRun (logical)           % Show actions without executing [default: false]
  ValidateOnly (logical)     % Only validate, don't create [default: false]
  Verbose (logical)          % Show detailed output [default: true]

Examples:
  % Create experiment
  rdt experiment create Protocol="protocol.yaml", Output="./experiments/exp001"

  % Dry run to see what would happen
  rdt experiment create Protocol="protocol.yaml", Output="./exp001", DryRun=true

  % Force overwrite existing
  rdt experiment create Protocol="protocol.yaml", Output="./exp001", Force=true

  % Validate only
  rdt experiment create Protocol="protocol.yaml", Output="./exp001", ValidateOnly=true

  % Override arena type from YAML
  rdt experiment create Protocol="protocol.yaml", Output="./exp001", ArenaType="g41-4row"
```

#### `rdt experiment validate`

Validate experiment protocol without creating folder.

```matlab
rdt experiment validate (ProtocolFile, Options...)

Arguments:
  ProtocolFile (string)      % YAML protocol file to validate

Name-Value Arguments:
  Verbose (logical)          % Show detailed results [default: false]
  OutputJSON (string)        % Save results as JSON to file

Returns:
  results (struct)           % Validation results

Examples:
  % Validate protocol
  rdt experiment validate "protocol.yaml"

  % Detailed validation
  rdt experiment validate "protocol.yaml", Verbose=true

  % Get validation results
  results = rdt experiment validate "protocol.yaml"
  if results.isValid
      fprintf('Protocol is valid!\n');
  end
```

#### `rdt experiment info`

Show experiment protocol information.

```matlab
rdt experiment info (ProtocolFile, Options...)

Arguments:
  ProtocolFile (string)      % YAML protocol file

Name-Value Arguments:
  ShowPatterns (logical)     % List all patterns [default: false]
  ShowConditions (logical)   % List all conditions [default: false]
  Verbose (logical)          % Show detailed info [default: false]
  OutputJSON (string)        % Save results as JSON to file

Returns:
  info (struct)              % Experiment information

Examples:
  % Basic info
  rdt experiment info "protocol.yaml"

  % Show all patterns
  rdt experiment info "protocol.yaml", ShowPatterns=true

  % Show all conditions
  rdt experiment info "protocol.yaml", ShowConditions=true

  % Get info structure
  info = rdt experiment info "protocol.yaml"
```

### Arena Commands

#### `rdt arena list`

List available arena presets.

```matlab
rdt arena list (Options...)

Name-Value Arguments:
  Verbose (logical)          % Show detailed specs [default: false]
  OutputJSON (string)        % Save results as JSON to file

Returns:
  arenas (struct array)      % Array of arena configurations

Examples:
  % List arenas
  rdt arena list

  Output:
    Available Arena Presets:
    1. g4-3row      (G4, 3 rows x 12 cols, 48x192 pixels)
    2. g4-4row      (G4, 4 rows x 12 cols, 64x192 pixels)
    3. g41-3row     (G4.1, 3 rows x 12 cols, 48x192 pixels)
    4. g41-4row     (G4.1, 4 rows x 12 cols, 64x192 pixels)

  % Detailed list
  rdt arena list Verbose=true

  % Get arena list
  arenas = rdt arena list
  for i = 1:length(arenas)
      fprintf('%s: %dx%d pixels\n', arenas(i).name, ...
              arenas(i).pixelHeight, arenas(i).pixelWidth);
  end
```

#### `rdt arena info`

Show arena configuration details.

```matlab
rdt arena info (ArenaType, Options...)

Arguments:
  ArenaType (string)         % Arena type: 'g4-3row', 'g4-4row', etc.

Name-Value Arguments:
  OutputJSON (string)        % Save results as JSON to file

Returns:
  arena (struct)             % Arena configuration

Examples:
  % Show G4 4-row arena info
  rdt arena info "g4-4row"

  Output:
    Arena Type: G4_4ROW
    Generation: G4
    Protocol: G4_V1
    Panel Configuration:
      - Panel size: 16 x 16 pixels
      - Arena size: 4 rows x 12 columns
      - Total panels: 48
      - Total pixels: 64 x 192

  % Get arena configuration
  arena = rdt arena info "g4-4row"
  fprintf('Arena has %d total pixels\n', arena.totalPixels);
```

### Configuration Commands

#### `rdt config show`

Display current configuration.

```matlab
rdt config show (Options...)

Name-Value Arguments:
  OutputJSON (string)        % Save results as JSON to file

Returns:
  config (struct)            % Current configuration

Examples:
  % Show configuration
  rdt config show

  Output:
    Configuration:
      Default arena type: g4-4row
      Default grayscale: 16
      Default output dir: ./patterns
      Auto-preview: false

  % Get config structure
  config = rdt config show
```

#### `rdt config set`

Set configuration values.

```matlab
rdt config set (Key, Value, Options...)

Arguments:
  Key (string)               % Configuration key
  Value                      % Configuration value

Name-Value Arguments:
  Persist (logical)          % Save to disk [default: true]

Examples:
  % Set default arena type
  rdt config set "default.arena_type", "g4-4row"

  % Set default output directory
  rdt config set "default.output_dir", "./my_patterns"

  % Set default grayscale
  rdt config set "default.grayscale", 16

  % Temporary setting (session only)
  rdt config set "default.arena_type", "g41-3row", Persist=false
```

#### `rdt config reset`

Reset configuration to defaults.

```matlab
rdt config reset (Options...)

Name-Value Arguments:
  Confirm (logical)          % Skip confirmation [default: false]

Examples:
  % Reset with confirmation prompt
  rdt config reset

  % Reset without confirmation
  rdt config reset Confirm=true
```

### Help Command

#### `rdt help`

Show help information.

```matlab
rdt help
rdt help <command>
rdt help <command> <subcommand>

Examples:
  % General help
  rdt help

  % Command help
  rdt help pattern

  % Subcommand help
  rdt help pattern create
```

## Implementation Details

### Project Structure

```
maDisplayTools/
├── rdt.m                      % Main entry point function
├── +maDisplayTools/
│   ├── +cli/
│   │   ├── +pattern/
│   │   │   ├── create.m
│   │   │   ├── preview.m
│   │   │   ├── validate.m
│   │   │   ├── info.m
│   │   │   └── convert.m
│   │   ├── +experiment/
│   │   │   ├── create.m
│   │   │   ├── validate.m
│   │   │   └── info.m
│   │   ├── +arena/
│   │   │   ├── list.m
│   │   │   └── info.m
│   │   ├── +config/
│   │   │   ├── show.m
│   │   │   ├── set.m
│   │   │   └── reset.m
│   │   └── +utils/
│   │       ├── ConfigManager.m
│   │       ├── OutputFormatter.m
│   │       ├── HelpSystem.m
│   │       └── TabComplete.m
│   ├── +core/           % From OOP refactoring
│   ├── +io/             % From OOP refactoring
│   └── +pattern/        % From OOP refactoring
├── spec/
│   ├── 01_refactor-oop.md
│   └── 02_refactor-cli.md
└── examples/
```

### Main Entry Point Function

```matlab
% rdt.m - Main CLI entry point
function varargout = rdt(varargin)
    % RDT Reiser Display Tools command-line interface
    %
    %   rdt <command> <subcommand> (Name, Value, ...)
    %
    %   Commands:
    %     pattern      - Pattern creation and management
    %     experiment   - Experiment folder management
    %     arena        - Arena configuration information
    %     config       - Configuration management
    %     help         - Show help information
    %
    %   Examples:
    %     rdt pattern create Script="my_pattern.m", Name="test", ArenaType="g4-4row"
    %     rdt pattern preview "patterns/pat0001_test.pat"
    %     rdt experiment create Protocol="protocol.yaml", Output="./exp001"
    %     rdt arena list
    %     rdt help pattern create
    %
    %   For detailed help on any command:
    %     rdt help <command>
    %     rdt help <command> <subcommand>
    
    % Handle no arguments
    if nargin == 0
        maDisplayTools.cli.utils.HelpSystem.showMainHelp();
        return;
    end
    
    % Get command
    command = varargin{1};
    
    % Special case: help command
    if strcmpi(command, 'help')
        if nargin == 1
            maDisplayTools.cli.utils.HelpSystem.showMainHelp();
        elseif nargin == 2
            maDisplayTools.cli.utils.HelpSystem.showCommandHelp(varargin{2});
        elseif nargin == 3
            maDisplayTools.cli.utils.HelpSystem.showSubcommandHelp(varargin{2}, varargin{3});
        else
            error('Too many arguments for help command');
        end
        return;
    end
    
    % Get subcommand
    if nargin < 2
        error('Subcommand required for "%s". Type "rdt help %s" for usage.', command, command);
    end
    
    subcommand = varargin{2};
    
    % Get remaining arguments (name-value pairs or positional)
    args = varargin(3:end);
    
    % Dispatch to appropriate handler
    try
        switch lower(command)
            case 'pattern'
                [varargout{1:nargout}] = dispatchPattern(subcommand, args);
            case 'experiment'
                [varargout{1:nargout}] = dispatchExperiment(subcommand, args);
            case 'arena'
                [varargout{1:nargout}] = dispatchArena(subcommand, args);
            case 'config'
                [varargout{1:nargout}] = dispatchConfig(subcommand, args);
            otherwise
                error('Unknown command: %s. Type "rdt help" for available commands.', command);
        end
    catch ME
        fprintf(2, 'Error: %s\n', ME.message);
        if ~isempty(ME.cause)
            for i = 1:length(ME.cause)
                fprintf(2, '  Caused by: %s\n', ME.cause{i}.message);
            end
        end
        fprintf(2, '\nFor help, type: rdt help %s %s\n', command, subcommand);
        rethrow(ME);
    end
end

function varargout = dispatchPattern(subcommand, args)
    % Dispatch to pattern subcommands
    switch lower(subcommand)
        case 'create'
            [varargout{1:nargout}] = maDisplayTools.cli.pattern.create(args{:});
        case 'preview'
            [varargout{1:nargout}] = maDisplayTools.cli.pattern.preview(args{:});
        case 'validate'
            [varargout{1:nargout}] = maDisplayTools.cli.pattern.validate(args{:});
        case 'info'
            [varargout{1:nargout}] = maDisplayTools.cli.pattern.info(args{:});
        case 'convert'
            [varargout{1:nargout}] = maDisplayTools.cli.pattern.convert(args{:});
        otherwise
            error('Unknown pattern subcommand: %s', subcommand);
    end
end

function varargout = dispatchExperiment(subcommand, args)
    % Dispatch to experiment subcommands
    switch lower(subcommand)
        case 'create'
            [varargout{1:nargout}] = maDisplayTools.cli.experiment.create(args{:});
        case 'validate'
            [varargout{1:nargout}] = maDisplayTools.cli.experiment.validate(args{:});
        case 'info'
            [varargout{1:nargout}] = maDisplayTools.cli.experiment.info(args{:});
        otherwise
            error('Unknown experiment subcommand: %s', subcommand);
    end
end

function varargout = dispatchArena(subcommand, args)
    % Dispatch to arena subcommands
    switch lower(subcommand)
        case 'list'
            [varargout{1:nargout}] = maDisplayTools.cli.arena.list(args{:});
        case 'info'
            [varargout{1:nargout}] = maDisplayTools.cli.arena.info(args{:});
        otherwise
            error('Unknown arena subcommand: %s', subcommand);
    end
end

function varargout = dispatchConfig(subcommand, args)
    % Dispatch to config subcommands
    switch lower(subcommand)
        case 'show'
            [varargout{1:nargout}] = maDisplayTools.cli.config.show(args{:});
        case 'set'
            [varargout{1:nargout}] = maDisplayTools.cli.config.set(args{:});
        case 'reset'
            [varargout{1:nargout}] = maDisplayTools.cli.config.reset(args{:});
        otherwise
            error('Unknown config subcommand: %s', subcommand);
    end
end
```

### Example Command Implementation: Pattern Create

```matlab
% +maDisplayTools/+cli/+pattern/create.m
function create(varargin)
    % CREATE Create pattern from script, function, or array
    %
    %   rdt pattern create (Name, Value, ...)
    %
    %   Name-Value Arguments:
    %     Script          - Path to MATLAB script that defines 'Pats'
    %     Function        - Function handle that returns pattern array
    %     Array           - Pattern array directly
    %     Name            - Pattern name (required)
    %     OutputDir       - Output directory [default: './patterns']
    %     ArenaType       - Arena type preset
    %     ArenaRows       - Custom arena rows
    %     ArenaCols       - Custom arena columns
    %     Grayscale       - 2 or 16 [default: 16]
    %     Pitch           - Pitch angle [default: 0.0]
    %     Stretch         - Stretch values
    %     Preview         - Preview after creation [default: false]
    
    arguments (Repeating)
        varargin
    end
    
    % Parse using inputParser for flexibility
    p = inputParser;
    p.KeepUnmatched = false;
    p.CaseSensitive = false;
    
    addParameter(p, 'Script', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'Function', [], @(x) isa(x, 'function_handle'));
    addParameter(p, 'Array', [], @isnumeric);
    addParameter(p, 'Name', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'OutputDir', './patterns', @(x) ischar(x) || isstring(x));
    addParameter(p, 'ArenaType', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'ArenaRows', [], @isnumeric);
    addParameter(p, 'ArenaCols', [], @isnumeric);
    addParameter(p, 'Grayscale', 16, @(x) isnumeric(x) && ismember(x, [2, 16]));
    addParameter(p, 'Pitch', 0.0, @isnumeric);
    addParameter(p, 'Stretch', [], @isnumeric);
    addParameter(p, 'Preview', false, @islogical);
    
    parse(p, varargin{:});
    opts = p.Results;
    
    % Validate required arguments
    if isempty(opts.Name)
        error('Name argument is required');
    end
    
    % Validate input source
    inputCount = ~isempty(opts.Script) + ~isempty(opts.Function) + ~isempty(opts.Array);
    if inputCount == 0
        error('One of Script, Function, or Array must be provided');
    elseif inputCount > 1
        error('Only one of Script, Function, or Array can be provided');
    end
    
    import maDisplayTools.core.*;
    import maDisplayTools.pattern.*;
    import maDisplayTools.io.*;
    
    % Determine arena configuration
    arena = determineArena(opts);
    
    % Get pattern array
    Pats = loadPatternArray(opts);
    
    % Create pattern
    fprintf('Creating pattern "%s"...\n', opts.Name);
    generator = PatternGenerator(arena, opts.Grayscale);
    
    if isempty(opts.Stretch)
        patternData = generator.fromArray(Pats, 'Name', opts.Name);
    else
        patternData = generator.fromArray(Pats, 'Name', opts.Name, 'Stretch', opts.Stretch);
    end
    
    % Save pattern
    writer = PatternWriter(opts.OutputDir);
    filepath = writer.write(patternData, opts.Name);
    
    fprintf('Pattern created successfully: %s\n', filepath);
    fprintf('  Dimensions: %d x %d pixels\n', patternData.arena.pixelHeight(), ...
            patternData.arena.pixelWidth());
    [numX, numY] = patternData.getFrameCounts();
    fprintf('  Frames: %d (X) x %d (Y) = %d total\n', numX, numY, numX*numY);
    fprintf('  Grayscale: %d levels\n', patternData.gsVal);
    
    % Preview if requested
    if opts.Preview
        fprintf('Launching preview...\n');
        rdt('pattern', 'preview', filepath);
    end
end

function arena = determineArena(opts)
    % Determine arena configuration from options
    import maDisplayTools.core.*;
    
    if ~isempty(opts.ArenaType)
        % Use preset
        typeStr = upper(strrep(opts.ArenaType, '-', '_'));
        arenaType = ArenaType.(typeStr);
        arena = ArenaConfiguration.fromPreset(arenaType, opts.Pitch);
    elseif ~isempty(opts.ArenaRows) && ~isempty(opts.ArenaCols)
        % Custom arena
        arena = ArenaConfiguration.custom(opts.ArenaRows, opts.ArenaCols, ...
            'PitchAngle', opts.Pitch);
    else
        error('Either ArenaType or both ArenaRows and ArenaCols must be provided');
    end
end

function Pats = loadPatternArray(opts)
    % Load pattern array from script, function, or direct array
    
    if ~isempty(opts.Script)
        % Load from script
        fprintf('Loading pattern from script: %s\n', opts.Script);
        
        % Run script in a temporary workspace
        oldDir = pwd;
        [scriptDir, scriptName, ~] = fileparts(opts.Script);
        if ~isempty(scriptDir)
            cd(scriptDir);
        end
        
        try
            % Run script
            evalin('base', scriptName);
            
            % Get Pats variable from base workspace
            if evalin('base', 'exist(''Pats'', ''var'')')
                Pats = evalin('base', 'Pats');
            else
                error('Script must define variable ''Pats''');
            end
        catch ME
            cd(oldDir);
            rethrow(ME);
        end
        
        cd(oldDir);
        
    elseif ~isempty(opts.Function)
        % Load from function
        fprintf('Generating pattern from function...\n');
        Pats = opts.Function();
        
    else
        % Direct array
        Pats = opts.Array;
    end
    
    % Validate Pats
    if isempty(Pats)
        error('Pattern array is empty');
    end
    if ~isnumeric(Pats)
        error('Pattern array must be numeric');
    end
end
```

### Example Command Implementation: Pattern Preview

```matlab
% +maDisplayTools/+cli/+pattern/preview.m
function preview(patternFile, varargin)
    % PREVIEW Preview pattern file interactively or export frames
    %
    %   rdt pattern preview (PatternFile, Name, Value, ...)
    %
    %   Arguments:
    %     PatternFile     - Path to .pat file
    %
    %   Name-Value Arguments:
    %     Frame           - Start at specific frame [default: 0]
    %     NoGUI           - Print info only [default: false]
    %     ExportGIF       - Export as GIF (filename)
    %     ExportFrames    - Export frames to directory
    %     ExportFormat    - Image format: 'png', 'tiff', 'jpg' [default: 'png']
    
    arguments
        patternFile {mustBeFile}
    end
    
    arguments (Repeating)
        varargin
    end
    
    % Parse optional arguments
    p = inputParser;
    p.CaseSensitive = false;
    addParameter(p, 'Frame', 0, @isnumeric);
    addParameter(p, 'NoGUI', false, @islogical);
    addParameter(p, 'ExportGIF', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'ExportFrames', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'ExportFormat', 'png', @(x) ismember(x, {'png', 'tiff', 'jpg'}));
    
    parse(p, varargin{:});
    opts = p.Results;
    
    import maDisplayTools.io.PatternReader;
    import maDisplayTools.pattern.PatternPreview;
    
    % Load pattern
    fprintf('Loading pattern: %s\n', patternFile);
    patternData = PatternReader.read(patternFile);
    
    % Print info
    fprintf('\nPattern Information:\n');
    fprintf('  ID: %d\n', patternData.patternID);
    if ~isempty(patternData.name)
        fprintf('  Name: %s\n', patternData.name);
    end
    fprintf('  Dimensions: %d x %d pixels\n', ...
            patternData.arena.pixelHeight(), patternData.arena.pixelWidth());
    [numX, numY] = patternData.getFrameCounts();
    fprintf('  Frames: %d (X) x %d (Y) = %d total\n', numX, numY, numX*numY);
    fprintf('  Grayscale: %d levels\n', patternData.gsVal);
    fprintf('  Protocol: %s\n', patternData.arena.protocolVersion.toString());
    
    % Export GIF if requested
    if ~isempty(opts.ExportGIF)
        fprintf('\nExporting GIF to: %s\n', opts.ExportGIF);
        exportGIF(patternData, opts.ExportGIF);
        fprintf('GIF export complete.\n');
    end
    
    % Export frames if requested
    if ~isempty(opts.ExportFrames)
        fprintf('\nExporting frames to: %s\n', opts.ExportFrames);
        exportFrames(patternData, opts.ExportFrames, opts.ExportFormat);
        fprintf('Frame export complete.\n');
    end
    
    % Show GUI unless NoGUI is set
    if ~opts.NoGUI
        fprintf('\nLaunching interactive preview...\n');
        previewer = PatternPreview(patternFile);
        
        % Set initial frame if specified
        if opts.Frame > 0
            % Update to specified frame (implementation depends on PatternPreview class)
        end
    end
end

function exportGIF(patternData, filename)
    % Export pattern as animated GIF
    [numX, numY] = patternData.getFrameCounts();
    
    for y = 1:numY
        for x = 1:numX
            frame = patternData.getFrame(x, y);
            
            % Normalize to 0-255
            if patternData.gsVal == 2
                frameNorm = uint8(frame * 255);
            else
                frameNorm = uint8(frame / 15 * 255);
            end
            
            % Write to GIF
            if x == 1 && y == 1
                imwrite(frameNorm, gray(256), filename, 'gif', ...
                        'Loopcount', inf, 'DelayTime', 0.1);
            else
                imwrite(frameNorm, gray(256), filename, 'gif', ...
                        'WriteMode', 'append', 'DelayTime', 0.1);
            end
        end
    end
end

function exportFrames(patternData, directory, format)
    % Export all frames as individual images
    
    if ~exist(directory, 'dir')
        mkdir(directory);
    end
    
    [numX, numY] = patternData.getFrameCounts();
    
    for y = 1:numY
        for x = 1:numX
            frame = patternData.getFrame(x, y);
            
            % Normalize to 0-255
            if patternData.gsVal == 2
                frameNorm = uint8(frame * 255);
            else
                frameNorm = uint8(frame / 15 * 255);
            end
            
            % Generate filename
            filename = fullfile(directory, sprintf('frame_x%03d_y%03d.%s', x, y, format));
            
            % Write image
            imwrite(frameNorm, gray(256), filename);
        end
    end
end
```

### Configuration Manager

```matlab
% +maDisplayTools/+cli/+utils/ConfigManager.m
classdef ConfigManager < handle
    % CONFIGMANAGER Manage CLI configuration settings
    
    properties (Constant)
        CONFIG_FILE = fullfile(prefdir, 'rdt_config.mat');
    end
    
    methods (Static)
        function config = load()
            % LOAD Load configuration from file
            
            if exist(ConfigManager.CONFIG_FILE, 'file')
                data = load(ConfigManager.CONFIG_FILE);
                config = data.config;
            else
                config = ConfigManager.getDefaults();
            end
        end
        
        function save(config)
            % SAVE Save configuration to file
            save(ConfigManager.CONFIG_FILE, 'config');
            fprintf('Configuration saved to: %s\n', ConfigManager.CONFIG_FILE);
        end
        
        function config = getDefaults()
            % GETDEFAULTS Get default configuration
            
            config = struct();
            config.default_arena_type = 'g4-4row';
            config.default_grayscale = 16;
            config.default_output_dir = './patterns';
            config.auto_preview = false;
        end
        
        function value = get(key, default)
            % GET Get configuration value
            
            if nargin < 2
                default = [];
            end
            
            config = ConfigManager.load();
            
            % Support nested keys like 'default.arena_type'
            parts = strsplit(key, '.');
            current = config;
            for i = 1:length(parts)
                part = parts{i};
                if isfield(current, part)
                    current = current.(part);
                else
                    value = default;
                    return;
                end
            end
            
            value = current;
        end
        
        function set(key, value, persist)
            % SET Set configuration value
            
            if nargin < 3
                persist = true;
            end
            
            config = ConfigManager.load();
            
            % Support simple keys only for now
            parts = strsplit(key, '.');
            if length(parts) == 1
                config.(parts{1}) = value;
            else
                % Nested keys - create structure as needed
                current = config;
                for i = 1:length(parts)-1
                    if ~isfield(current, parts{i})
                        current.(parts{i}) = struct();
                    end
                    current = current.(parts{i});
                end
                current.(parts{end}) = value;
                config.(parts{1}) = config.(parts{1}); % Update root
            end
            
            if persist
                ConfigManager.save(config);
            end
        end
        
        function reset()
            % RESET Reset configuration to defaults
            config = ConfigManager.getDefaults();
            ConfigManager.save(config);
            fprintf('Configuration reset to defaults.\n');
        end
    end
end
```

### Help System

```matlab
% +maDisplayTools/+cli/+utils/HelpSystem.m
classdef HelpSystem
    % HELPSYSTEM Provide help information for commands
    
    methods (Static)
        function showMainHelp()
            % SHOWMAINHELP Show main help message
            
            fprintf('\n');
            fprintf('Reiser Display Tools (rdt) - Command-line interface\n');
            fprintf('===================================================\n\n');
            fprintf('Usage:\n');
            fprintf('  rdt <command> <subcommand> (Name, Value, ...)\n\n');
            fprintf('Commands:\n');
            fprintf('  pattern      Pattern creation and management\n');
            fprintf('  experiment   Experiment folder management\n');
            fprintf('  arena        Arena configuration information\n');
            fprintf('  config       Configuration management\n');
            fprintf('  help         Show help information\n\n');
            fprintf('Examples:\n');
            fprintf('  rdt pattern create Script="my_pattern.m", Name="test", ArenaType="g4-4row"\n');
            fprintf('  rdt pattern preview "patterns/pat0001_test.pat"\n');
            fprintf('  rdt experiment create Protocol="protocol.yaml", Output="./exp001"\n');
            fprintf('  rdt arena list\n\n');
            fprintf('For command-specific help:\n');
            fprintf('  rdt help <command>\n');
            fprintf('  rdt help <command> <subcommand>\n\n');
        end
        
        function showCommandHelp(command)
            % SHOWCOMMANDHELP Show help for a specific command
            
            switch lower(command)
                case 'pattern'
                    HelpSystem.showPatternHelp();
                case 'experiment'
                    HelpSystem.showExperimentHelp();
                case 'arena'
                    HelpSystem.showArenaHelp();
                case 'config'
                    HelpSystem.showConfigHelp();
                otherwise
                    error('Unknown command: %s', command);
            end
        end
        
        function showSubcommandHelp(command, subcommand)
            % SHOWSUBCOMMANDHELP Show help for a specific subcommand
            
            % Use MATLAB's help system to show function documentation
            funcName = sprintf('maDisplayTools.cli.%s.%s', command, subcommand);
            try
                help(funcName);
            catch
                error('No help available for: %s %s', command, subcommand);
            end
        end
        
        function showPatternHelp()
            fprintf('\n');
            fprintf('Pattern Commands\n');
            fprintf('================\n\n');
            fprintf('Subcommands:\n');
            fprintf('  create       Create new patterns from scripts, functions, or arrays\n');
            fprintf('  preview      Preview pattern files interactively\n');
            fprintf('  validate     Validate pattern files\n');
            fprintf('  info         Show pattern information\n');
            fprintf('  convert      Convert between formats\n\n');
            fprintf('For subcommand help:\n');
            fprintf('  rdt help pattern <subcommand>\n\n');
        end
        
        function showExperimentHelp()
            fprintf('\n');
            fprintf('Experiment Commands\n');
            fprintf('===================\n\n');
            fprintf('Subcommands:\n');
            fprintf('  create       Create experiment folder from YAML\n');
            fprintf('  validate     Validate experiment protocol\n');
            fprintf('  info         Show experiment information\n\n');
            fprintf('For subcommand help:\n');
            fprintf('  rdt help experiment <subcommand>\n\n');
        end
        
        function showArenaHelp()
            fprintf('\n');
            fprintf('Arena Commands\n');
            fprintf('==============\n\n');
            fprintf('Subcommands:\n');
            fprintf('  list         List available arena presets\n');
            fprintf('  info         Show arena configuration details\n\n');
            fprintf('For subcommand help:\n');
            fprintf('  rdt help arena <subcommand>\n\n');
        end
        
        function showConfigHelp()
            fprintf('\n');
            fprintf('Configuration Commands\n');
            fprintf('======================\n\n');
            fprintf('Subcommands:\n');
            fprintf('  show         Display current configuration\n');
            fprintf('  set          Set configuration values\n');
            fprintf('  reset        Reset to defaults\n\n');
            fprintf('For subcommand help:\n');
            fprintf('  rdt help config <subcommand>\n\n');
        end
    end
end
```

## Tab Completion Support

MATLAB R2021b and later support tab completion for custom functions. We can enhance discoverability by implementing tab completion:

```matlab
% Register tab completion for mdt function
% This would be called during package initialization

function completions = rdt_completions(~, ~, ~)
    % Provide tab completion suggestions for rdt command
    
    persistent commands subcommands
    
    if isempty(commands)
        commands = {'pattern', 'experiment', 'arena', 'config', 'help'};
        subcommands = struct();
        subcommands.pattern = {'create', 'preview', 'validate', 'info', 'convert'};
        subcommands.experiment = {'create', 'validate', 'info'};
        subcommands.arena = {'list', 'info'};
        subcommands.config = {'show', 'set', 'reset'};
    end
    
    completions = commands;
end
```

## Usage Examples

### Creating Patterns

```matlab
% Example 1: Create from script
% First create a script that defines 'Pats' variable
rdt pattern create Script="vertical_bars.m", Name="vbars", ArenaType="g4-4row"

% Example 2: Create from function handle
function Pats = makeHorizontalGrating()
    rows = 64; cols = 192; frames = 24;
    Pats = zeros(rows, cols, frames, 1, 'uint8');
    for f = 1:frames
        Pats(1+(f-1)*2:f*2, :, f, 1) = 15;
    end
end

rdt pattern create Function=@makeHorizontalGrating, Name="hgrating", ArenaType="g4-4row"

% Example 3: Create from workspace array
Pats = rand(64, 192, 24, 1) * 15;
rdt pattern create Array=Pats, Name="random", ArenaType="g4-4row", Grayscale=16

% Example 4: Create and preview
rdt pattern create Script="my_pattern.m", Name="test", ArenaType="g4-4row", Preview=true

% Example 5: Custom arena
rdt pattern create Array=Pats, Name="custom", ArenaRows=5, ArenaCols=10
```

### Previewing and Validating

```matlab
% Preview pattern
rdt pattern preview "patterns/pat0001_vbars.pat"

% Preview starting at frame 10
rdt pattern preview "patterns/pat0001_vbars.pat", Frame=10

% Export as GIF
rdt pattern preview "patterns/pat0001_vbars.pat", ExportGIF="animation.gif", NoGUI=true

% Export all frames
rdt pattern preview "patterns/pat0001_vbars.pat", ExportFrames="./frames/"

% Validate patterns
rdt pattern validate "patterns/pat0001_vbars.pat", ArenaType="g4-4row"

% Get validation results
results = rdt pattern validate "patterns/*.pat", ArenaType="g4-4row"

% Get pattern info
info = rdt pattern info "patterns/pat0001_vbars.pat"
fprintf('Pattern has %d total frames\n', info.totalFrames);
```

### Creating Experiments

```matlab
% Create experiment folder
rdt experiment create Protocol="protocol.yaml", Output="./experiments/exp001"

% Dry run first
rdt experiment create Protocol="protocol.yaml", Output="./exp001", DryRun=true

% Force overwrite
rdt experiment create Protocol="protocol.yaml", Output="./exp001", Force=true

% Validate protocol
results = rdt experiment validate "protocol.yaml"
if results.isValid
    fprintf('Protocol is valid!\n');
end
```

### Arena Information

```matlab
% List all arenas
rdt arena list

% Detailed list
rdt arena list Verbose=true

% Get arena list as structure
arenas = rdt arena list
for i = 1:length(arenas)
    fprintf('%s: %dx%d pixels\n', arenas(i).name, ...
            arenas(i).pixelHeight, arenas(i).pixelWidth);
end

% Get specific arena info
arena = rdt arena info "g4-4row"
```

### Configuration Management

```matlab
% Show configuration
rdt config show

% Set default arena type
rdt config set "default.arena_type", "g4-4row"

% Set default output directory
rdt config set "default.output_dir", "./my_patterns"

% Reset configuration
rdt config reset Confirm=true
```

### Batch Processing

```matlab
% Create multiple patterns in loop
patternNames = ["pattern1", "pattern2", "pattern3"];
for i = 1:length(patternNames)
    script = sprintf("%s.m", patternNames(i));
    rdt pattern create Script=script, Name=patternNames(i), ArenaType="g4-4row"
end

% Validate all created patterns
files = dir("patterns/*.pat");
for i = 1:length(files)
    filepath = fullfile(files(i).folder, files(i).name);
    rdt pattern validate filepath, ArenaType="g4-4row"
end
```

## Benefits of MATLAB Command Window CLI

1. **Native MATLAB Integration**: Works seamlessly in MATLAB environment
2. **Interactive Workflow**: Fits MATLAB's interactive computing model
3. **Tab Completion**: MATLAB's built-in tab completion helps discovery
4. **Variable Integration**: Easy to pass arrays from workspace
5. **Function Handle Support**: Can pass function handles directly
6. **Familiar Syntax**: Uses MATLAB's name-value pair convention
7. **Help Integration**: Integrated with MATLAB's help system
8. **Debugger Support**: Can debug commands with MATLAB debugger
9. **No Shell Dependency**: No need for external shell scripts
10. **Cross-Platform**: Works identically on Windows, macOS, Linux

## Testing Strategy

1. **Unit Tests**: Test each command function independently
2. **Integration Tests**: Test complete workflows
3. **Argument Validation**: Test error handling for invalid arguments
4. **Return Value Tests**: Verify returned structures
5. **Configuration Tests**: Test config persistence

## Documentation Requirements

1. Function help documentation for each command
2. User guide with examples
3. Quick reference card
4. Migration guide from old API
5. Video tutorials for common workflows

This CLI design provides a professional, intuitive interface optimized for MATLAB's command window environment while maintaining consistency with the Python implementation's command structure.
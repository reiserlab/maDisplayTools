function [isValid, errors, warnings] = validate_protocol_for_sd_card(protocolFilePath, resolvedPatternPaths, varargin)
% VALIDATE_PROTOCOL_FOR_SD_CARD Comprehensive validation before SD card deployment
%
% This function performs all validation that should occur BEFORE patterns are
% copied to the SD card and BEFORE running an experiment. This reduces runtime
% validation overhead and catches errors early in the workflow.
%
% Syntax:
%   [isValid, errors, warnings] = validate_protocol_for_sd_card(protocolFilePath, resolvedPatternPaths)
%   [isValid, errors, warnings] = validate_protocol_for_sd_card(..., 'Verbose', true)
%
% Input Arguments:
%   protocolFilePath     - Path to YAML protocol file (required)
%   resolvedPatternPaths - Cell array of full pattern file paths already resolved
%                          by extract_patterns_from_yaml() (required)
%
% Name-Value Pairs:
%   'Verbose' - Print detailed validation progress (default: true)
%
% Outputs:
%   isValid  - Boolean, true if protocol passes all validation
%   errors   - Cell array of error messages (validation failures)
%   warnings - Cell array of warning messages (non-critical issues)
%
% Validation Performed:
%   1. YAML structure and format validation
%      - File existence and readability
%      - Required sections present
%      - Field type validation
%      - Version compatibility
%
%   2. Arena configuration validation
%      - Valid generation (G4, G4.1, G6)
%      - Reasonable row/column counts
%      - Hardware compatibility
%
%   3. Experiment structure validation
%      - Positive repetition count
%      - Valid randomization settings
%      - Condition definitions complete
%
%   4. Plugin configuration validation
%      - Supported plugin types
%      - Required fields present
%      - Type-specific validation
%
%   5. Command validation
%      - All commands have required fields
%      - Parameter types correct
%      - Value ranges appropriate
%
%   6. Pattern file validation
%      - All pattern files exist (using resolvedPatternPaths)
%      - Pattern files readable
%      - Pattern dimensions match arena configuration
%
% Example:
%   % Extract patterns from YAML (resolves paths)
%   [patterns_per_yaml, yaml_files] = extract_patterns_from_yaml('experiment.yaml');
%   
%   % Validate using resolved paths
%   [valid, errors, warns] = validate_protocol_for_sd_card(...
%       yaml_files{1}, patterns_per_yaml{1});
%   
%   if ~valid
%       fprintf('Validation failed with %d errors:\n', length(errors));
%       for i = 1:length(errors)
%           fprintf('  %d. %s\n', i, errors{i});
%       end
%   else
%       fprintf('Validation passed! Safe to copy to SD card.\n');
%   end
%
% See also: ProtocolParser, run_protocol, extract_patterns_from_yaml

    % Parse input arguments
    p = inputParser;
    addRequired(p, 'protocolFilePath', @(x) ischar(x) || isstring(x));
    addRequired(p, 'resolvedPatternPaths', @iscell);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, protocolFilePath, resolvedPatternPaths, varargin{:});
    
    verbose = p.Results.Verbose;
    protocolFilePath = char(p.Results.protocolFilePath);
    resolvedPatternPaths = p.Results.resolvedPatternPaths;
    
    % Initialize outputs
    errors = {};
    warnings = {};
    
    if verbose
        fprintf('\n=== Protocol Validation for SD Card Deployment ===\n');
        fprintf('Protocol: %s\n', protocolFilePath);
        fprintf('Patterns to validate: %d\n\n', length(resolvedPatternPaths));
    end
    
    %% Phase 1: Parse and validate YAML structure
    if verbose
        fprintf('Phase 1: YAML Structure Validation\n');
    end
    
    try
        % Use ProtocolParser for comprehensive YAML validation
        parser = ProtocolParser('verbose', false);
        protocol = parser.parse(protocolFilePath);
        
        if verbose
            fprintf('  ✓ YAML parsing successful\n');
            fprintf('  ✓ Protocol version %d supported\n', protocol.version);
        end
        
    catch ME
        errors{end+1} = sprintf('YAML parsing failed: %s', ME.message);
        if verbose
            fprintf('  ✗ YAML parsing failed\n');
        end
        isValid = false;
        return;
    end
    
    %% Phase 2: Arena configuration validation
    if verbose
        fprintf('Phase 2: Arena Configuration Validation\n');
    end
    
    [arenaErrors, arenaWarnings] = validateArenaConfiguration(protocol.arenaConfig, verbose);
    errors = [errors, arenaErrors];
    warnings = [warnings, arenaWarnings];
    
    %% Phase 3: Experiment structure validation
    if verbose
        fprintf('Phase 3: Experiment Structure Validation\n');
    end
    
    [expErrors, expWarnings] = validateExperimentStructure(protocol.experimentStructure, verbose);
    errors = [errors, expErrors];
    warnings = [warnings, expWarnings];
    
    %% Phase 4: Plugin configuration validation
    if verbose
        fprintf('Phase 4: Plugin Configuration Validation\n');
    end
    
    if isfield(protocol, 'plugins') && ~isempty(protocol.plugins)
        [pluginErrors, pluginWarnings] = validatePlugins(protocol.plugins, verbose);
        errors = [errors, pluginErrors];
        warnings = [warnings, pluginWarnings];
    else
        if verbose
            fprintf('  ℹ No plugins defined\n');
        end
    end
    
    %% Phase 5: Command validation
    if verbose
        fprintf('Phase 5: Command Validation\n');
    end
    
    [cmdErrors, cmdWarnings] = validateCommands(protocol, verbose);
    errors = [errors, cmdErrors];
    warnings = [warnings, cmdWarnings];
    
    %% Phase 6: Pattern file validation
    if verbose
        fprintf('Phase 6: Pattern File Validation\n');
    end
    
    [patErrors, patWarnings] = validatePatternFiles(protocol, resolvedPatternPaths, verbose);
    errors = [errors, patErrors];
    warnings = [warnings, patWarnings];
    
    %% Summary
    isValid = isempty(errors);
    
    if verbose
        fprintf('\n=== Validation Summary ===\n');
        if isValid
            fprintf('✓ VALIDATION PASSED\n');
        else
            fprintf('✗ VALIDATION FAILED\n');
        end
        fprintf('  Errors: %d\n', length(errors));
        fprintf('  Warnings: %d\n', length(warnings));
        
        if ~isempty(errors)
            fprintf('\nErrors:\n');
            for i = 1:length(errors)
                fprintf('  %d. %s\n', i, errors{i});
            end
        end
        
        if ~isempty(warnings)
            fprintf('\nWarnings:\n');
            for i = 1:length(warnings)
                fprintf('  %d. %s\n', i, warnings{i});
            end
        end
        fprintf('========================\n\n');
    end
end

%% Validation Helper Functions

function [errors, warnings] = validateArenaConfiguration(arenaConfig, verbose)
    errors = {};
    warnings = {};
    
    % Check generation
    validGenerations = {'G4', 'G4.1', 'G6'};
    if ~ismember(arenaConfig.generation, validGenerations)
        errors{end+1} = sprintf('Invalid arena generation: %s (must be G4, G4.1, or G6)', ...
            arenaConfig.generation);
    end
    
    % Check dimensions
    if arenaConfig.num_rows < 1 || arenaConfig.num_rows > 12
        errors{end+1} = sprintf('Invalid num_rows: %d (must be 1-12)', arenaConfig.num_rows);
    end
    
    if arenaConfig.num_cols < 1 || arenaConfig.num_cols > 24
        errors{end+1} = sprintf('Invalid num_cols: %d (must be 1-24)', arenaConfig.num_cols);
    end
    
    % Warnings for unusual configurations
    if arenaConfig.num_rows > 6
        warnings{end+1} = sprintf('Unusually large num_rows: %d (typical: 3-4)', ...
            arenaConfig.num_rows);
    end
    
    if arenaConfig.num_cols > 16
        warnings{end+1} = sprintf('Unusually large num_cols: %d (typical: 12)', ...
            arenaConfig.num_cols);
    end
    
    if verbose && isempty(errors)
        fprintf('  ✓ Arena: %s, %dx%d panels\n', arenaConfig.generation, ...
            arenaConfig.num_rows, arenaConfig.num_cols);
    end
end

function [errors, warnings] = validateExperimentStructure(expStructure, verbose)
    errors = {};
    warnings = {};
    
    % Check repetitions
    if ~isfield(expStructure, 'repetitions')
        errors{end+1} = 'Missing required field: repetitions';
    elseif expStructure.repetitions < 1
        errors{end+1} = sprintf('Invalid repetitions: %d (must be >= 1)', ...
            expStructure.repetitions);
    elseif expStructure.repetitions > 100
        warnings{end+1} = sprintf('Large repetition count: %d (may result in long experiment)', ...
            expStructure.repetitions);
    end
    
    % Check randomization
    if isfield(expStructure, 'randomization')
        rand = expStructure.randomization;
        if isfield(rand, 'enabled') && rand.enabled
            if ~isfield(rand, 'method') || ~strcmp(rand.method, 'block')
                errors{end+1} = 'Invalid randomization method (only "block" is supported)';
            end
        end
    end
    
    if verbose && isempty(errors)
        fprintf('  ✓ Experiment structure valid\n');
    end
end

function [errors, warnings] = validatePlugins(plugins, verbose)
    errors = {};
    warnings = {};
    
    validTypes = {'serial_device', 'class', 'script'};
    
    for i = 1:length(plugins)
        if length(plugins) == 1
            plugin = plugins;
        else
            plugin = plugins{i};
        end
        
        % Check required fields
        if ~isfield(plugin, 'name')
            errors{end+1} = sprintf('Plugin %d missing required field: name', i);
            continue;
        end
        
        if ~isfield(plugin, 'type')
            errors{end+1} = sprintf('Plugin "%s" missing required field: type', plugin.name);
            continue;
        end
        
        % Check type validity
        if ~ismember(plugin.type, validTypes)
            errors{end+1} = sprintf('Plugin "%s" has invalid type: %s', ...
                plugin.name, plugin.type);
        end
        
        % Type-specific validation
        switch plugin.type
            case 'serial_device'
                if ~isfield(plugin, 'port') && ~isfield(plugin, 'port_windows') && ~isfield(plugin, 'port_posix')
                    errors{end+1} = sprintf('SerialDevice plugin "%s" missing port', plugin.name);
                end
                if ~isfield(plugin, 'commands')
                    errors{end+1} = sprintf('SerialDevice plugin "%s" missing commands', plugin.name);
                end
                
            case 'class'
                if isfield(plugin, 'matlab')
                    if ~isfield(plugin.matlab, 'class')
                        errors{end+1} = sprintf('Class plugin "%s" missing matlab class', plugin.name);
                    end
                elseif isfield(plugin, 'python')
                    if ~isfield(plugin.python, 'class') && ~isfield(plugin.python, 'module')
                        errors{end+1} = sprintf('Class plugin "%s" missing python class or module', plugin.name);
                    end
                else
                    errors{end+1} = sprintf('Class plugin "%s" must specify matlab or python class', plugin.name);
                end
                
            case 'script'
                if ~isfield(plugin, 'script_path')
                    errors{end+1} = sprintf('Script plugin "%s" missing script_path', plugin.name);
                end
        end
    end
    
    if verbose && isempty(errors)
        fprintf('  ✓ %d plugin(s) valid\n', length(plugins));
    end
end

function [errors, warnings] = validateCommands(protocol, verbose)
    errors = {};
    warnings = {};
    
    % Collect all command sequences
    commandSets = {};
    commandSetNames = {};
    
    if ~isempty(protocol.pretrialCommands)
        commandSets{end+1} = protocol.pretrialCommands;
        commandSetNames{end+1} = 'pretrial';
    end
    
    for i = 1:length(protocol.blockConditions)
        commandSets{end+1} = protocol.blockConditions(i).commands;
        commandSetNames{end+1} = sprintf('condition %s', protocol.blockConditions(i).id);
    end
    
    if ~isempty(protocol.intertrialCommands)
        commandSets{end+1} = protocol.intertrialCommands;
        commandSetNames{end+1} = 'intertrial';
    end
    
    if ~isempty(protocol.posttrialCommands)
        commandSets{end+1} = protocol.posttrialCommands;
        commandSetNames{end+1} = 'posttrial';
    end
    
    % Validate each command set
    for i = 1:length(commandSets)
        commands = commandSets{i};
        setName = commandSetNames{i};
        
        for j = 1:length(commands)
            cmd = commands{j};
            [cmdErrors, cmdWarnings] = validateSingleCommand(cmd, setName, j);
            errors = [errors, cmdErrors];
            warnings = [warnings, cmdWarnings];
        end
    end
    
    if verbose && isempty(errors)
        fprintf('  ✓ All commands valid\n');
    end
end

function [errors, warnings] = validateSingleCommand(cmd, context, index)
    errors = {};
    warnings = {};
    
    % Check type field
    if ~isfield(cmd, 'type')
        errors{end+1} = sprintf('%s command %d missing type field', context, index);
        return;
    end
    
    % Type-specific validation
    switch cmd.type
        case 'controller'
            [e, w] = validateControllerCommand(cmd, context, index);
            errors = [errors, e];
            warnings = [warnings, w];
            
        case 'wait'
            [e, w] = validateWaitCommand(cmd, context, index);
            errors = [errors, e];
            warnings = [warnings, w];
            
        case 'plugin'
            [e, w] = validatePluginCommand(cmd, context, index);
            errors = [errors, e];
            warnings = [warnings, w];
            
        otherwise
            errors{end+1} = sprintf('%s command %d has invalid type: %s', ...
                context, index, cmd.type);
    end
end

function [errors, warnings] = validateControllerCommand(cmd, context, index)
    errors = {};
    warnings = {};
    
    if ~isfield(cmd, 'command_name')
        errors{end+1} = sprintf('%s controller command %d missing command_name', ...
            context, index);
        return;
    end
    
    cmdName = cmd.command_name;
    
    % Command-specific parameter validation
    switch cmdName
        case 'allOn'
            % No parameters needed
            
        case 'allOff'
            % No parameters needed
            
        case 'stopDisplay'
            % No parameters needed
            
        case 'setPositionX'
            if ~isfield(cmd, 'posX')
                errors{end+1} = sprintf('%s setPositionX command missing posX parameter', context);
            elseif ~isnumeric(cmd.posX) || cmd.posX < 0
                errors{end+1} = sprintf('%s setPositionX posX must be non-negative', context);
            end
            
        case 'setColorDepth'
            if ~isfield(cmd, 'gs_val')
                errors{end+1} = sprintf('%s setColorDepth command missing gs_val parameter', context);
            elseif ~ismember(cmd.gs_val, [2, 16])
                errors{end+1} = sprintf('%s setColorDepth gs_val must be 2 or 16', context);
            end
            
        case {'startG41Trial', 'trialParams'}
            % Validate all required trial parameters
            requiredFields = {'mode', 'pattern', 'pattern_ID', 'frame_index', ...
                'duration', 'frame_rate', 'gain'};
            
            for i = 1:length(requiredFields)
                field = requiredFields{i};
                if ~isfield(cmd, field)
                    errors{end+1} = sprintf('%s trial command missing %s parameter', ...
                        context, field);
                end
            end
            
            % Mode validation
            if isfield(cmd, 'mode')
                if ~ismember(cmd.mode, [2, 3, 4])
                    errors{end+1} = sprintf('%s trial mode must be 2, 3, or 4 (got %d)', ...
                        context, cmd.mode);
                end
            end
            
            % Duration validation
            if isfield(cmd, 'duration')
                if cmd.duration <= 0
                    errors{end+1} = sprintf('%s trial duration must be positive', context);
                elseif cmd.duration > 3600
                    warnings{end+1} = sprintf('%s trial duration very long: %.1fs', ...
                        context, cmd.duration);
                end
            end
            
        otherwise
            warnings{end+1} = sprintf('%s uses unknown controller command: %s', ...
                context, cmdName);
    end
end

function [errors, warnings] = validateWaitCommand(cmd, context, index)
    errors = {};
    warnings = {};
    
    if ~isfield(cmd, 'duration')
        errors{end+1} = sprintf('%s wait command %d missing duration', context, index);
    elseif ~isnumeric(cmd.duration) || cmd.duration < 0
        errors{end+1} = sprintf('%s wait command %d duration must be non-negative', ...
            context, index);
    elseif cmd.duration > 60000  % 1 minute in milliseconds
        warnings{end+1} = sprintf('%s wait command %d has very long duration: %d ms', ...
            context, index, cmd.duration);
    end
end

function [errors, warnings] = validatePluginCommand(cmd, context, index)
    errors = {};
    warnings = {};
    
    if ~isfield(cmd, 'plugin_name')
        errors{end+1} = sprintf('%s plugin command %d missing plugin_name', ...
            context, index);
        return;
    end
    
    % Special validation for log command
    if isfield(cmd, 'command_name') && strcmpi(cmd.command_name, 'log')
        % Validate params field exists
        if ~isfield(cmd, 'params')
            errors{end+1} = sprintf('%s plugin command %d: log command requires params field', ...
                context, index);
            return;
        end
        
        % Validate message field exists
        if ~isfield(cmd.params, 'message')
            errors{end+1} = sprintf('%s plugin command %d: log command requires params.message', ...
                context, index);
            return;
        end
        
        % Validate message is a non-empty string
        if ~ischar(cmd.params.message) && ~isstring(cmd.params.message)
            errors{end+1} = sprintf('%s plugin command %d: log message must be a string', ...
                context, index);
        elseif isempty(strtrim(char(cmd.params.message)))
            errors{end+1} = sprintf('%s plugin command %d: log message cannot be empty', ...
                context, index);
        else
            % Check message length (max 2000 characters for safety)
            msg = char(cmd.params.message);
            if length(msg) > 2000
                errors{end+1} = sprintf('%s plugin command %d: log message exceeds 2000 character limit (%d characters)', ...
                    context, index, length(msg));
            end
        end
        
        % Validate level parameter if provided
        if isfield(cmd.params, 'level')
            valid_levels = {'DEBUG', 'INFO', 'WARNING', 'ERROR'};
            level = upper(char(cmd.params.level));
            if ~ismember(level, valid_levels)
                errors{end+1} = sprintf('%s plugin command %d: invalid log level "%s" (must be DEBUG, INFO, WARNING, or ERROR)', ...
                    context, index, cmd.params.level);
            end
        end
        
        return;  % Log command validation complete
    end
    
    % Note: Further plugin command validation (command_name, params) happens at runtime
    % based on plugin type, which is determined from plugin definitions
end

function [errors, warnings] = validatePatternFiles(protocol, resolvedPatternPaths, verbose)
    errors = {};
    warnings = {};
    
    if verbose
        fprintf('  Validating %d pattern file(s)...\n', length(resolvedPatternPaths));
    end
    
    % Validate each pattern file exists and is readable
    missing_patterns = {};
    readable_patterns = {};
    
    for i = 1:length(resolvedPatternPaths)
        fullPath = resolvedPatternPaths{i};
        
        % Check existence
        if ~exist(fullPath, 'file')
            missing_patterns{end+1} = fullPath; %#ok<AGROW>
            continue;
        end
        
        % Check readability
        try
            fid = fopen(fullPath, 'r');
            if fid == -1
                errors{end+1} = sprintf('Cannot read pattern file: %s', fullPath); %#ok<AGROW>
            else
                fclose(fid);
                readable_patterns{end+1} = fullPath; %#ok<AGROW>
            end
        catch ME
            errors{end+1} = sprintf('Error accessing pattern file %s: %s', ...
                fullPath, ME.message); %#ok<AGROW>
        end
    end
    
    % Report missing patterns
    if ~isempty(missing_patterns)
        for i = 1:length(missing_patterns)
            errors{end+1} = sprintf('Pattern file not found: %s', missing_patterns{i}); %#ok<AGROW>
        end
    end
    
    if verbose && isempty(errors)
        fprintf('  ✓ All pattern files exist and readable\n');
    end
    
    % Validate pattern dimensions match arena configuration
    if ~isempty(readable_patterns)
        if verbose
            fprintf('  Validating pattern dimensions...\n');
        end
        
        try
            maDisplayTools.validate_all_patterns(readable_patterns, ...
                protocol.arenaConfig.num_rows, ...
                protocol.arenaConfig.num_cols);
            
            if verbose
                fprintf('  ✓ All patterns match arena dimensions (%dx%d panels)\n', ...
                    protocol.arenaConfig.num_rows, protocol.arenaConfig.num_cols);
            end
            
        catch ME
            errors{end+1} = sprintf('Pattern dimension validation failed: %s', ME.message);
            if verbose
                fprintf('  ✗ Pattern dimension validation failed\n');
            end
        end
    end
end

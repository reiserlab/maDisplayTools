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
%   protocolFilePath     - Path to V3 YAML protocol file (required)
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
%      - Version 3 enforcement
%
%   2. Rig configuration validation
%      - Rig file resolves and loads cleanly
%      - Controller IP and port present
%      - Arena file resolved from rig
%
%   3. Arena configuration validation
%      - Valid generation (G3, G4, G4.1, G6)
%      - Reasonable row/column counts
%      - column_order, orientation, columns_installed, angle_offset fields
%
%   4. Plugin configuration validation
%      - Supported plugin types
%      - Required fields present per type
%      - Warns if class plugin has no config (expected to come from rig YAML)
%
%   5. Command validation
%      - All commands have required fields
%      - Parameter types correct
%      - Value ranges appropriate
%
%   6. Pattern file validation
%      - All pattern files exist (using resolvedPatternPaths)
%      - Pattern files readable
%      - Pattern dimensions match arena configuration (accounts for
%        partial arenas via columns_installed)
%
% Example:
%   [patterns_per_yaml, yaml_files] = extract_patterns_from_yaml('experiment.yaml');
%   [valid, errors, warns] = validate_protocol_for_sd_card(...
%       yaml_files{1}, patterns_per_yaml{1});
%   if ~valid
%       fprintf('Validation failed:\n');
%       for i = 1:length(errors)
%           fprintf('  %d. %s\n', i, errors{i});
%       end
%   end
%
% See also: ProtocolParser, run_protocol, deploy_experiments_to_sd

    p = inputParser;
    addRequired(p, 'protocolFilePath',     @(x) ischar(x) || isstring(x));
    addRequired(p, 'resolvedPatternPaths', @iscell);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, protocolFilePath, resolvedPatternPaths, varargin{:});

    verbose              = p.Results.Verbose;
    protocolFilePath     = char(p.Results.protocolFilePath);
    resolvedPatternPaths = p.Results.resolvedPatternPaths;

    errors   = {};
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
        parser   = ProtocolParser('verbose', false);
        protocol = parser.parse(protocolFilePath);

        if verbose
            fprintf('  ✓ YAML parsing successful\n');
        end

    catch ME
        errors{end+1} = sprintf('YAML parsing failed: %s', ME.message);
        if verbose
            fprintf('  ✗ YAML parsing failed: %s\n', ME.message);
        end
        isValid = false;
        return;
    end

    % Enforce V3
    if protocol.version ~= 3
        errors{end+1} = sprintf(['Protocol is version %d. Only version 3 is supported.\n' ...
            '  Please migrate your protocol to the V3 YAML format.'], protocol.version);
        if verbose
            fprintf('  ✗ Version %d protocol rejected (V3 required)\n', protocol.version);
        end
        isValid = false;
        return;
    end

    if verbose
        fprintf('  ✓ Protocol version 3 confirmed\n');
    end

    %% Phase 2: Rig configuration validation
    if verbose
        fprintf('Phase 2: Rig Configuration Validation\n');
    end

    [rigErrors, rigWarnings] = validateRigConfiguration(protocol, verbose);
    errors   = [errors,   rigErrors];
    warnings = [warnings, rigWarnings];

    % If rig config is broken, arena/pattern checks will also fail — stop early
    if ~isempty(rigErrors)
        isValid = false;
        if verbose
            printSummary(errors, warnings);
        end
        return;
    end

    %% Phase 3: Arena configuration validation
    if verbose
        fprintf('Phase 3: Arena Configuration Validation\n');
    end

    [arenaErrors, arenaWarnings] = validateArenaConfiguration( ...
        protocol.arenaConfig, protocol.derivedConfig, verbose);
    errors   = [errors,   arenaErrors];
    warnings = [warnings, arenaWarnings];

    %% Phase 4: Plugin configuration validation
    if verbose
        fprintf('Phase 4: Plugin Configuration Validation\n');
    end

    if isfield(protocol, 'plugins') && ~isempty(protocol.plugins)
        [pluginErrors, pluginWarnings] = validatePlugins( ...
            protocol.plugins, protocol.rigConfig, verbose);
        errors   = [errors,   pluginErrors];
        warnings = [warnings, pluginWarnings];
    else
        if verbose
            fprintf('  ℹ No plugins defined in experiment YAML\n');
        end
    end

    %% Phase 5: Command validation
    if verbose
        fprintf('Phase 5: Command Validation\n');
    end

    [cmdErrors, cmdWarnings] = validateCommands(protocol, verbose);
    errors   = [errors,   cmdErrors];
    warnings = [warnings, cmdWarnings];

    %% Phase 6: Pattern file validation
    if verbose
        fprintf('Phase 6: Pattern File Validation\n');
    end

    [patErrors, patWarnings] = validatePatternFiles( ...
        protocol, resolvedPatternPaths, verbose);
    errors   = [errors,   patErrors];
    warnings = [warnings, patWarnings];

    %% Summary
    isValid = isempty(errors);

    if verbose
        printSummary(errors, warnings);
    end
end

%% =========================================================================
%% Validation Helper Functions
%% =========================================================================

function printSummary(errors, warnings)
    isValid = isempty(errors);
    fprintf('\n=== Validation Summary ===\n');
    if isValid
        fprintf('✓ VALIDATION PASSED\n');
    else
        fprintf('✗ VALIDATION FAILED\n');
    end
    fprintf('  Errors: %d\n',   length(errors));
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

% -------------------------------------------------------------------------

function [errors, warnings] = validateRigConfiguration(protocol, verbose)
    errors   = {};
    warnings = {};

    if ~isfield(protocol, 'rigConfig') || isempty(protocol.rigConfig)
        errors{end+1} = 'Rig config not resolved — check rig: path in protocol YAML';
        if verbose
            fprintf('  ✗ Rig config missing\n');
        end
        return;
    end

    rig = protocol.rigConfig;

    if isfield(rig, 'name') && ~isempty(rig.name)
        if verbose
            fprintf('  ✓ Rig: %s\n', rig.name);
        end
    else
        warnings{end+1} = 'Rig config has no name field';
    end

    % Controller host
    if ~isfield(rig, 'controller') || ~isfield(rig.controller, 'host') || ...
            isempty(rig.controller.host)
        errors{end+1} = 'Rig config missing controller.host (IP address)';
    else
        hostStr = char(rig.controller.host);
        parts   = strsplit(hostStr, '.');
        if length(parts) ~= 4 || any(cellfun(@(p) isempty(p) || isnan(str2double(p)), parts))
            warnings{end+1} = sprintf('Controller host may not be a valid IP address: %s', hostStr);
        else
            if verbose
                fprintf('  ✓ Controller: %s', hostStr);
            end
        end
    end

    % Controller port
    if ~isfield(rig, 'controller') || ~isfield(rig.controller, 'port')
        warnings{end+1} = 'Rig config missing controller.port (will default to 62222)';
    else
        port = rig.controller.port;
        if ~isnumeric(port) || port < 1 || port > 65535
            errors{end+1} = sprintf('Invalid controller port: %s (must be 1-65535)', num2str(port));
        else
            if verbose
                fprintf(':%d\n', port);
            end
        end
    end

    % Arena file
    if ~isfield(protocol, 'arenaFilepath') || isempty(protocol.arenaFilepath)
        warnings{end+1} = 'Arena file path not recorded in parsed protocol';
    else
        if ~isfile(protocol.arenaFilepath)
            errors{end+1} = sprintf('Arena config file not found: %s', protocol.arenaFilepath);
        else
            if verbose
                fprintf('  ✓ Arena file: %s\n', protocol.arenaFilepath);
            end
        end
    end

    if verbose && isempty(errors)
        fprintf('  ✓ Rig configuration valid\n');
    end
end

% -------------------------------------------------------------------------

function [errors, warnings] = validateArenaConfiguration(arenaConfig, derivedConfig, verbose)
    errors   = {};
    warnings = {};

    % Generation
    validGenerations = {'G3', 'G4', 'G4.1', 'G6'};
    if ~isfield(arenaConfig, 'generation') || isempty(arenaConfig.generation)
        errors{end+1} = 'Arena config missing generation field';
    elseif ~ismember(arenaConfig.generation, validGenerations)
        errors{end+1} = sprintf('Invalid arena generation: "%s" (must be G3, G4, G4.1, or G6)', ...
            arenaConfig.generation);
    end

    % num_rows
    if ~isfield(arenaConfig, 'num_rows')
        errors{end+1} = 'Arena config missing num_rows';
    elseif arenaConfig.num_rows < 1 || arenaConfig.num_rows > 12
        errors{end+1} = sprintf('Invalid num_rows: %d (must be 1-12)', arenaConfig.num_rows);
    elseif arenaConfig.num_rows > 6
        warnings{end+1} = sprintf('Unusually large num_rows: %d (typical: 2-4)', arenaConfig.num_rows);
    end

    % num_cols
    if ~isfield(arenaConfig, 'num_cols')
        errors{end+1} = 'Arena config missing num_cols';
    elseif arenaConfig.num_cols < 1 || arenaConfig.num_cols > 24
        errors{end+1} = sprintf('Invalid num_cols: %d (must be 1-24)', arenaConfig.num_cols);
    elseif arenaConfig.num_cols > 18
        warnings{end+1} = sprintf('Unusually large num_cols: %d (typical: 12-18)', arenaConfig.num_cols);
    end

    % column_order
    if isfield(arenaConfig, 'column_order') && ~isempty(arenaConfig.column_order)
        if ~ismember(lower(arenaConfig.column_order), {'cw', 'ccw'})
            errors{end+1} = sprintf('Invalid column_order: "%s" (must be "cw" or "ccw")', ...
                arenaConfig.column_order);
        end
    else
        warnings{end+1} = 'Arena config missing column_order (will default to "cw")';
    end

    % orientation
    if isfield(arenaConfig, 'orientation') && ~isempty(arenaConfig.orientation)
        if ~ismember(lower(arenaConfig.orientation), {'normal', 'inverted'})
            errors{end+1} = sprintf('Invalid orientation: "%s" (must be "normal" or "inverted")', ...
                arenaConfig.orientation);
        end
    end

    % angle_offset_deg
    if isfield(arenaConfig, 'angle_offset_deg') && ~isempty(arenaConfig.angle_offset_deg)
        offset = arenaConfig.angle_offset_deg;
        if ~isnumeric(offset)
            errors{end+1} = 'angle_offset_deg must be a number';
        elseif abs(offset) > 360
            warnings{end+1} = sprintf('angle_offset_deg of %.1f degrees seems unusually large', offset);
        end
    end

    % columns_installed (partial arena)
    if isfield(arenaConfig, 'columns_installed') && ~isempty(arenaConfig.columns_installed)
        installed = arenaConfig.columns_installed;
        numCols   = arenaConfig.num_cols;

        if any(installed < 0) || any(installed >= numCols)
            errors{end+1} = sprintf(['columns_installed contains out-of-range indices. ' ...
                'Valid range is 0 to %d (0-indexed).'], numCols - 1);
        end

        if length(unique(installed)) < length(installed)
            errors{end+1} = 'columns_installed contains duplicate column indices';
        end

        numInstalled = length(unique(installed));
        if verbose
            fprintf('  ✓ Partial arena: %d of %d columns installed\n', numInstalled, numCols);
        end
    end

    % Derived config sanity check
    if ~isempty(derivedConfig)
        if isfield(derivedConfig, 'total_pixels_x') && derivedConfig.total_pixels_x < 1
            errors{end+1} = 'Derived total_pixels_x is zero — check arena dimensions and generation';
        end
        if isfield(derivedConfig, 'total_pixels_y') && derivedConfig.total_pixels_y < 1
            errors{end+1} = 'Derived total_pixels_y is zero — check arena dimensions and generation';
        end
        if verbose && isempty(errors)
            fprintf('  ✓ Arena: %s, %dx%d panels, %dx%d px\n', ...
                arenaConfig.generation, ...
                arenaConfig.num_rows, arenaConfig.num_cols, ...
                derivedConfig.total_pixels_x, derivedConfig.total_pixels_y);
        end
    else
        if verbose && isempty(errors)
            fprintf('  ✓ Arena: %s, %dx%d panels\n', ...
                arenaConfig.generation, arenaConfig.num_rows, arenaConfig.num_cols);
        end
    end
end

% -------------------------------------------------------------------------

function [errors, warnings] = validatePlugins(plugins, rigConfig, verbose)
    errors   = {};
    warnings = {};

    validTypes = {'serial_device', 'class', 'script'};

    for i = 1:length(plugins)
        if iscell(plugins)
            plugin = plugins{i};
        else
            plugin = plugins(i);
        end

        if ~isfield(plugin, 'name')
            errors{end+1} = sprintf('Plugin %d missing required field: name', i);
            continue;
        end

        if ~isfield(plugin, 'type')
            errors{end+1} = sprintf('Plugin "%s" missing required field: type', plugin.name);
            continue;
        end

        if ~ismember(plugin.type, validTypes)
            errors{end+1} = sprintf('Plugin "%s" has invalid type: "%s" (must be: %s)', ...
                plugin.name, plugin.type, strjoin(validTypes, ', '));
            continue;
        end

        switch plugin.type

            case 'serial_device'
                if ~isfield(plugin, 'port') && ~isfield(plugin, 'port_windows') && ...
                        ~isfield(plugin, 'port_posix')
                    errors{end+1} = sprintf('serial_device plugin "%s" missing port field', ...
                        plugin.name);
                end
                if ~isfield(plugin, 'commands')
                    errors{end+1} = sprintf('serial_device plugin "%s" missing commands field', ...
                        plugin.name);
                end

            case 'class'
                if ~isfield(plugin, 'matlab') && ~isfield(plugin, 'python')
                    errors{end+1} = sprintf(['Class plugin "%s" must specify matlab ' ...
                        'and/or python class'], plugin.name);
                end
                if isfield(plugin, 'matlab') && ~isfield(plugin.matlab, 'class')
                    errors{end+1} = sprintf('Class plugin "%s" matlab block missing class name', ...
                        plugin.name);
                end
                if isfield(plugin, 'python')
                    if ~isfield(plugin.python, 'module') || ~isfield(plugin.python, 'class')
                        errors{end+1} = sprintf(['Class plugin "%s" python block must specify ' ...
                            'both module and class'], plugin.name);
                    end
                end

                % Warn if config is absent from both experiment and rig YAML
                if ~isfield(plugin, 'config') || isempty(plugin.config)
                    rigHasConfig = false;
                    if isfield(rigConfig, 'plugins') && isstruct(rigConfig.plugins) && ...
                            isfield(rigConfig.plugins, plugin.name)
                        rigPlugin    = rigConfig.plugins.(plugin.name);
                        rigHasConfig = isstruct(rigPlugin) && ~isempty(fieldnames(rigPlugin));
                    end

                    if rigHasConfig
                        if verbose
                            fprintf('  ℹ Plugin "%s": config will be sourced from rig YAML\n', ...
                                plugin.name);
                        end
                    else
                        warnings{end+1} = sprintf(['Class plugin "%s" has no config in ' ...
                            'experiment YAML and none found in rig YAML — plugin may fail ' ...
                            'to initialize'], plugin.name);
                    end
                end

            case 'script'
                if ~isfield(plugin, 'script_path')
                    errors{end+1} = sprintf('Script plugin "%s" missing script_path field', ...
                        plugin.name);
                end
        end
    end

    if verbose && isempty(errors)
        fprintf('  ✓ %d plugin(s) valid\n', length(plugins));
    end
end

% -------------------------------------------------------------------------

function [errors, warnings] = validateCommands(protocol, verbose)
    % Validate every command in every condition in the protocol's
    % conditions library.
    %
    % ProtocolParser.conditionsMap is a containers.Map of
    % conditionName -> commands, populated identically for both standard
    % V3 protocols and flow-control protocols (requires: [flow_control]).
    % Validating from conditionsMap rather than commandSequence keeps this
    % function agnostic to which execution path the protocol uses:
    % commandSequence is the flat, fully-expanded step list and is left
    % empty ({}) by the parser for flow-control protocols (their execution
    % order isn't known until runtime — e.g. repeat_until iteration count),
    % so validating against it silently checks zero commands for any
    % flow-control protocol. conditionsMap has no such gap, and as a bonus
    % each condition is validated exactly once regardless of how many
    % times it's referenced or repeated.

    errors   = {};
    warnings = {};

    condNames  = keys(protocol.conditionsMap);
    numChecked = 0;

    for i = 1:length(condNames)
        label    = condNames{i};
        commands = protocol.conditionsMap(label);

        if ~iscell(commands)
            commands = {commands};
        end

        for j = 1:length(commands)
            cmd = commands{j};
            [cmdErrors, cmdWarnings] = validateSingleCommand(cmd, label, j);
            errors   = [errors,   cmdErrors];   %#ok<AGROW>
            warnings = [warnings, cmdWarnings]; %#ok<AGROW>
        end

        numChecked = numChecked + 1;
    end

    if verbose && isempty(errors)
        fprintf('  ✓ All commands valid (%d condition(s) checked)\n', numChecked);
    end
end

% -------------------------------------------------------------------------

function [errors, warnings] = validateSingleCommand(cmd, context, index)
    errors   = {};
    warnings = {};

    if ~isfield(cmd, 'type')
        errors{end+1} = sprintf('%s command %d missing type field', context, index);
        return;
    end

    switch cmd.type
        case 'controller'
            [e, w] = validateControllerCommand(cmd, context, index);
            errors   = [errors,   e];
            warnings = [warnings, w];

        case 'wait'
            [e, w] = validateWaitCommand(cmd, context, index);
            errors   = [errors,   e];
            warnings = [warnings, w];

        case 'plugin'
            [e, w] = validatePluginCommand(cmd, context, index);
            errors   = [errors,   e];
            warnings = [warnings, w];

        otherwise
            errors{end+1} = sprintf('%s command %d has unrecognized type: "%s"', ...
                context, index, cmd.type);
    end
end

% -------------------------------------------------------------------------

function [errors, warnings] = validateControllerCommand(cmd, context, index)
    errors   = {};
    warnings = {};

    if ~isfield(cmd, 'command_name')
        errors{end+1} = sprintf('%s controller command %d missing command_name', context, index);
        return;
    end

    cmdName = cmd.command_name;

    switch cmdName
        case {'allOn', 'allOff', 'stopDisplay'}
            % No parameters needed

        case 'setPositionX'
            if ~isfield(cmd, 'posX')
                errors{end+1} = sprintf('%s setPositionX command missing posX parameter', context);
            elseif ~isnumeric(cmd.posX) || cmd.posX < 0
                errors{end+1} = sprintf('%s setPositionX posX must be a non-negative number', context);
            end

        case 'setColorDepth'
            if ~isfield(cmd, 'gs_val')
                errors{end+1} = sprintf('%s setColorDepth command missing gs_val parameter', context);
            elseif ~ismember(cmd.gs_val, [2, 16])
                errors{end+1} = sprintf('%s setColorDepth gs_val must be 2 or 16 (got %d)', ...
                    context, cmd.gs_val);
            end

        case {'startG41Trial', 'trialParams'}
            % Fields required for every mode.
            % Note: pattern_ID is intentionally excluded from required fields.
            % It is written automatically by deploy_experiments_to_sd() when
            % the SD card is prepared. Source YAML files should omit it or
            % leave it empty; do not use an anchor/alias for this field.
            requiredFields = {'mode', 'pattern', 'frame_index', 'duration'};

            for i = 1:length(requiredFields)
                field = requiredFields{i};
                if ~isfield(cmd, field)
                    errors{end+1} = sprintf('%s trial command (command %d) missing required field: %s', ...
                        context, index, field);
                end
            end

            % Mode-specific required fields, matching
            % CommandExecutor.executeControllerCommand's trialParams cases:
            %   mode 2 additionally requires frame_rate
            %   mode 3 has no additional requirements
            %   mode 4 additionally requires gain
            if isfield(cmd, 'mode')
                switch cmd.mode
                    case 2
                        if ~isfield(cmd, 'frame_rate')
                            errors{end+1} = sprintf(...
                                '%s trial command (command %d) mode 2 missing required field: frame_rate', ...
                                context, index);
                        end
                    case 4
                        if ~isfield(cmd, 'gain')
                            errors{end+1} = sprintf(...
                                '%s trial command (command %d) mode 4 missing required field: gain', ...
                                context, index);
                        end
                end
            end

            % Validate pattern_ID only if present and non-empty
            if isfield(cmd, 'pattern_ID') && ~isempty(cmd.pattern_ID)
                pid = cmd.pattern_ID;
                if ~isnumeric(pid) || pid < 1 || floor(pid) ~= pid
                    errors{end+1} = sprintf( ...
                        '%s pattern_ID must be a positive integer (got %s)', ...
                        context, num2str(pid));
                end
            end

            if isfield(cmd, 'mode') && ~ismember(cmd.mode, [2, 3, 4])
                errors{end+1} = sprintf('%s trial mode must be 2, 3, or 4 (got %d)', ...
                    context, cmd.mode);
            end

            if isfield(cmd, 'duration')
                if cmd.duration <= 0
                    errors{end+1} = sprintf('%s trial duration must be positive (got %.2f s)', ...
                        context, cmd.duration);
                elseif cmd.duration > 3600
                    warnings{end+1} = sprintf('%s trial duration is very long: %.1f s', ...
                        context, cmd.duration);
                end
            end

        otherwise
            warnings{end+1} = sprintf('%s uses unrecognized controller command: "%s"', ...
                context, cmdName);
    end
end

% -------------------------------------------------------------------------

function [errors, warnings] = validateWaitCommand(cmd, context, index)
    errors   = {};
    warnings = {};

    if ~isfield(cmd, 'duration')
        errors{end+1} = sprintf('%s wait command %d missing duration', context, index);
        return;
    end

    if ~isnumeric(cmd.duration) || cmd.duration < 0
        errors{end+1} = sprintf('%s wait command %d duration must be a non-negative number', ...
            context, index);
    elseif cmd.duration > 300
        warnings{end+1} = sprintf('%s wait command %d has very long duration: %.1f s', ...
            context, index, cmd.duration);
    end
end

% -------------------------------------------------------------------------

function [errors, warnings] = validatePluginCommand(cmd, context, index)
    errors   = {};
    warnings = {};

    if ~isfield(cmd, 'plugin_name')
        errors{end+1} = sprintf('%s plugin command %d missing plugin_name', context, index);
        return;
    end

    % Validate log command specifically
    if isfield(cmd, 'command_name') && strcmpi(cmd.command_name, 'log')
        if ~isfield(cmd, 'params')
            errors{end+1} = sprintf('%s plugin command %d: log command requires a params field', ...
                context, index);
            return;
        end
        if ~isfield(cmd.params, 'message')
            errors{end+1} = sprintf('%s plugin command %d: log command requires params.message', ...
                context, index);
            return;
        end
        if ~ischar(cmd.params.message) && ~isstring(cmd.params.message)
            errors{end+1} = sprintf('%s plugin command %d: log message must be a string', ...
                context, index);
        elseif isempty(strtrim(char(cmd.params.message)))
            errors{end+1} = sprintf('%s plugin command %d: log message cannot be empty', ...
                context, index);
        elseif length(char(cmd.params.message)) > 2000
            errors{end+1} = sprintf('%s plugin command %d: log message exceeds 2000 character limit (%d chars)', ...
                context, index, length(char(cmd.params.message)));
        end
        if isfield(cmd.params, 'level')
            if ~ismember(upper(char(cmd.params.level)), {'DEBUG', 'INFO', 'WARNING', 'ERROR'})
                errors{end+1} = sprintf('%s plugin command %d: invalid log level "%s"', ...
                    context, index, cmd.params.level);
            end
        end
    end
end

% -------------------------------------------------------------------------

function [errors, warnings] = validatePatternFiles(protocol, resolvedPatternPaths, verbose)
    errors   = {};
    warnings = {};

    if verbose
        fprintf('  Validating %d pattern file(s)...\n', length(resolvedPatternPaths));
    end

    missing_patterns  = {};
    readable_patterns = {};

    for i = 1:length(resolvedPatternPaths)
        fullPath = resolvedPatternPaths{i};

        if ~exist(fullPath, 'file')
            missing_patterns{end+1} = fullPath; %#ok<AGROW>
            continue;
        end

        fid = fopen(fullPath, 'r');
        if fid == -1
            errors{end+1} = sprintf('Pattern file exists but cannot be read: %s', fullPath);
        else
            fclose(fid);
            readable_patterns{end+1} = fullPath; %#ok<AGROW>
        end
    end

    if ~isempty(missing_patterns)
        for i = 1:length(missing_patterns)
            errors{end+1} = sprintf('Pattern file not found: %s', missing_patterns{i});
        end
    end

    if verbose && isempty(missing_patterns)
        fprintf('  ✓ All pattern files exist and are readable\n');
    end

    if ~isempty(readable_patterns)
        if verbose
            fprintf('  Validating pattern dimensions...\n');
        end

        if isfield(protocol, 'derivedConfig') && ~isempty(protocol.derivedConfig) && ...
                isfield(protocol.derivedConfig, 'num_columns_installed')
            effectiveCols = protocol.derivedConfig.num_columns_installed;
        else
            effectiveCols = protocol.arenaConfig.num_cols;
        end

        numRows = protocol.arenaConfig.num_rows;

        try
            maDisplayTools.validate_all_patterns(readable_patterns, numRows, effectiveCols);

            if verbose
                fprintf('  ✓ All patterns match arena dimensions (%dx%d panels)\n', ...
                    numRows, effectiveCols);
            end

        catch ME
            errors{end+1} = sprintf('Pattern dimension validation failed: %s', ME.message);
            if verbose
                fprintf('  ✗ Pattern dimension validation failed\n');
            end
        end
    end
end

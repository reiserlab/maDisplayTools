classdef ProtocolParser < handle
    % Parse and validate Version 3 YAML protocol files
    %
    % Version 3 protocol files introduce two major features over V2:
    %
    %   1. CONDITIONS library - all conditions are defined once by name in a
    %      top-level "conditions" list.  Conditions are referenced by name
    %      in the experiment sequence rather than defined inline.
    %
    %   2. EXPERIMENT sequence - a flat, readable list that mixes standalone
    %      condition references (strings) with block definitions (mappings
    %      with trials, repetitions, randomize, and intertrial fields).
    %      The parser fully expands this sequence into an ordered flat list
    %      of {id, commands} steps that the runner executes top-to-bottom
    %      with no additional scheduling logic.

    % Output:
    %   parse() returns a protocol struct with fields:
    %     .version          - 3
    %     .filepath         - path to protocol YAML
    %     .experimentInfo   - struct: name, date_created, author, etc.
    %     .rigConfig        - full resolved rig config struct
    %     .arenaConfig      - shortcut to rigConfig.arena
    %     .derivedConfig    - shortcut to rigConfig.derived
    %     .controllerConfig - shortcut to rigConfig.controller
    %     .rigFilepath      - resolved rig YAML path
    %     .arenaFilepath    - resolved arena YAML path
    %     .plugins          - cell array of plugin definition structs,
    %                         with rig hardware config merged in
    %     .variables        - struct from the optional "variables" YAML section
    %                         (anchor values resolved at load time;
    %                          preserved here for logging/documentation purposes)
    %     .rawYamlData      - raw YAML struct as loaded by yaml.loadFile, with all
    %                         anchor/alias values already resolved by SnakeYAML.
    %                         Used by ProtocolRunner to write a resolved copy of
    %                         the YAML into each run's results folder.
    %     .commandSequence  - cell array of structs, each with:
    %                           .id       string label for logging
    %                           .commands cell array of command structs
    %                         The runner executes this list in order.
    %
    % Example:
    %   parser  = ProtocolParser('verbose', true);
    %   protocol = parser.parse('./protocols/my_exp.yaml');
    %   fprintf('%d steps\n', length(protocol.commandSequence));

    properties (Access = private)
        verbose     % Print parsing progress to console
        filepath    % Path to the protocol file being parsed
        metricMap   % containers.Map: metricName -> pluginName (flow control)
    end

    properties (Constant)
        SUPPORTED_VERSION            = 3;
        REQUIRED_YAML_SECTIONS       = {'experiment_info', 'rig', 'conditions', 'experiment'};
        REQUIRED_ARENA_FIELDS        = {'num_rows', 'num_cols', 'generation'};
        SUPPORTED_GENERATIONS        = {'G3', 'G4', 'G4.1', 'G6'};
        SUPPORTED_PLUGIN_TYPES       = {'serial_device', 'class', 'script'};
    end

    % =========================================================================
    %  PUBLIC INTERFACE
    % =========================================================================
    methods (Access = public)

        function self = ProtocolParser(varargin)
            % Constructor
            %
            % Optional Name-Value Arguments:
            %   'verbose' - Print parsing progress (default: false)
            %
            % Example:
            %   parser = ProtocolParser('verbose', true);

            p = inputParser;
            addParameter(p, 'verbose', false, @islogical);
            parse(p, varargin{:});
            self.verbose = p.Results.verbose;
        end

        function protocol = parse(self, filepath)
            % Parse a Version 3 YAML protocol file
            %
            % Input Arguments:
            %   filepath - Path to the YAML protocol file
            %
            % Returns:
            %   protocol - Struct described in the class header comment
            %
            % Errors:
            %   ProtocolParser:FileNotFound   - file does not exist
            %   ProtocolParser:ValidationError - file fails validation
            %   ProtocolParser:ParseError      - unexpected parsing failure

            self.filepath = filepath;

            if ~isfile(filepath)
                error('ProtocolParser:FileNotFound', ...
                    'Protocol file not found: %s', filepath);
            end

            if self.verbose
                fprintf('Parsing protocol: %s\n', filepath);
            end

            try
                rawData = yaml.loadFile(filepath);

                if self.verbose
                    fprintf('  YAML loaded successfully\n');
                end

                % Check version before anything else so the error is clear
                self.checkVersion(rawData);

                % Validate structure and content
                self.validateProtocol(rawData);

                % Extract and build protocol struct
                protocol = self.extractProtocol(rawData);
                protocol.filepath = filepath;

                if self.verbose
                    self.printProtocolSummary(protocol);
                end

            catch ME
                % Re-throw validation errors unchanged; wrap everything else
                if strcmp(ME.identifier, 'ProtocolParser:ValidationError') || ...
                   strcmp(ME.identifier, 'ProtocolParser:FileNotFound')
                    rethrow(ME);
                else
                    error('ProtocolParser:ParseError', ...
                        'Failed to parse protocol file: %s\nError: %s', ...
                        filepath, ME.message);
                end
            end
        end

        function v = get_supported_version(~)
            % Return the single protocol version this parser accepts
            v = ProtocolParser.SUPPORTED_VERSION;
        end

    end

    % =========================================================================
    %  PRIVATE — VALIDATION
    % =========================================================================
    methods (Access = private)

        function checkVersion(self, data)
            % Verify version field exists and equals SUPPORTED_VERSION

            if ~isfield(data, 'version')
                self.throwValidationError('Protocol missing required "version" field');
            end
            if data.version ~= self.SUPPORTED_VERSION
                self.throwValidationError( ...
                    ['Unsupported protocol version: %d\n' ...
                     'This parser accepts version %d only.\n' ...
                     'For version 2 protocols, use the version 2 branch.'], ...
                    data.version, self.SUPPORTED_VERSION);
            end
        end

        function validateProtocol(self, data)
            % Top-level validation — calls section-specific validators in order

            % Required top-level sections
            for i = 1:length(self.REQUIRED_YAML_SECTIONS)
                section = self.REQUIRED_YAML_SECTIONS{i};
                if ~isfield(data, section)
                    self.throwValidationError( ...
                        'Protocol missing required "%s" section', section);
                end
            end

            self.validateExperimentInfo(data.experiment_info);
            self.validateRigReference(data.rig);

            if isfield(data, 'plugins')
                self.validatePlugins(data.plugins);
            end

            % Validate conditions library; returns the list of defined names
            conditionNames = self.validateConditionsLibrary(data.conditions);

            % Validate experiment sequence against the known condition names
            self.validateExperimentSequence(data.experiment, conditionNames);

            if self.verbose
                fprintf('  Validation passed\n');
            end
        end

        % --- experiment_info -------------------------------------------------

        function validateExperimentInfo(self, info)
            if ~isfield(info, 'name')
                self.throwValidationError( ...
                    'experiment_info missing required "name" field');
            end
            if ~ischar(info.name) && ~isstring(info.name)
                self.throwValidationError('experiment_info.name must be a string');
            end
        end

        % --- rig reference ---------------------------------------------------

        function validateRigReference(self, rigRef)
            if ~ischar(rigRef) && ~isstring(rigRef)
                self.throwValidationError( ...
                    'rig must be a file path string, e.g. rig: "configs/rigs/my_rig.yaml"');
            end

            rigPath = self.resolveRelativePath(rigRef);
            if ~isfile(rigPath)
                self.throwValidationError('Rig config file not found: %s', rigPath);
            end

            try
                rigConfig = load_rig_config(rigPath);
            catch ME
                self.throwValidationError( ...
                    'Failed to load rig config: %s\nError: %s', rigPath, ME.message);
            end

            if ~isfield(rigConfig, 'arena')
                self.throwValidationError('Rig config missing arena configuration');
            end

            arena = rigConfig.arena;
            for i = 1:length(self.REQUIRED_ARENA_FIELDS)
                field = self.REQUIRED_ARENA_FIELDS{i};
                if ~isfield(arena, field)
                    self.throwValidationError( ...
                        'Rig arena missing required "%s" field', field);
                end
            end

            if strcmpi(arena.generation, 'G5')
                self.throwValidationError( ...
                    'G5 is deprecated. Use G6 for 20x20 pixel panels.');
            end
            if ~ismember(arena.generation, self.SUPPORTED_GENERATIONS)
                self.throwValidationError( ...
                    'arena.generation must be one of: %s', ...
                    strjoin(self.SUPPORTED_GENERATIONS, ', '));
            end

            if self.verbose
                fprintf('  Rig: %s  |  Arena: %s (%dx%d)\n', ...
                    rigConfig.name, arena.generation, ...
                    arena.num_rows, arena.num_cols);
            end
        end

        % --- plugins ---------------------------------------------------------

        function validatePlugins(self, plugins)
            plugins = self.normalizeToCell(plugins);

            for i = 1:length(plugins)
                plugin = plugins{i};

                if ~isfield(plugin, 'name')
                    self.throwValidationError( ...
                        'Plugin %d missing required "name" field', i);
                end
                if ~isfield(plugin, 'type')
                    self.throwValidationError( ...
                        'Plugin "%s" missing required "type" field', plugin.name);
                end
                if ~ismember(plugin.type, self.SUPPORTED_PLUGIN_TYPES)
                    self.throwValidationError( ...
                        'Plugin "%s" has unsupported type "%s". Must be one of: %s', ...
                        plugin.name, plugin.type, ...
                        strjoin(self.SUPPORTED_PLUGIN_TYPES, ', '));
                end

                switch plugin.type
                    case 'serial_device', self.validateSerialPlugin(plugin);
                    case 'class',         self.validateClassPlugin(plugin);
                    case 'script',        self.validateScriptPlugin(plugin);
                end
            end
        end

        function validateSerialPlugin(self, plugin)
            requiredFields = {'baudrate', 'commands'};
            for i = 1:length(requiredFields)
                if ~isfield(plugin, requiredFields{i})
                    self.throwValidationError( ...
                        'Serial plugin "%s" missing required "%s" field', ...
                        plugin.name, requiredFields{i});
                end
            end
            if ~isfield(plugin, 'port') && ...
               ~isfield(plugin, 'port_windows') && ...
               ~isfield(plugin, 'port_posix')
                self.throwValidationError( ...
                    ['Serial plugin "%s" must define at least one port field ' ...
                     '(port, port_windows, or port_posix)'], plugin.name);
            end
        end

        function validateClassPlugin(self, plugin)
            if ~isfield(plugin, 'matlab') && ~isfield(plugin, 'python')
                self.throwValidationError( ...
                    'Class plugin "%s" must define a matlab or python implementation', ...
                    plugin.name);
            end
            if isfield(plugin, 'matlab') && ~isfield(plugin.matlab, 'class')
                self.throwValidationError( ...
                    'Class plugin "%s" matlab section missing required "class" field', ...
                    plugin.name);
            end
            if isfield(plugin, 'config') && isfield(plugin.config, 'frame_rate')
                if ~isnumeric(plugin.config.frame_rate) || plugin.config.frame_rate <= 0
                    self.throwValidationError( ...
                        'Class plugin "%s" frame_rate must be a positive number', ...
                        plugin.name);
                end
            end
        end

        function validateScriptPlugin(self, plugin)
            if ~isfield(plugin, 'script_path')
                self.throwValidationError( ...
                    'Script plugin "%s" missing required "script_path" field', plugin.name);
            end
        end

        % --- conditions library ----------------------------------------------

        function conditionNames = validateConditionsLibrary(self, conditions)
            % Validate each condition and return the list of defined names.
            % The returned cell array is used by validateExperimentSequence
            % to confirm that every reference resolves to a real condition.

            conditions = self.normalizeToCell(conditions);

            if isempty(conditions)
                self.throwValidationError( ...
                    '"conditions" must contain at least one condition');
            end

            conditionNames = {};
            for i = 1:length(conditions)
                cond = conditions{i};

                if ~isfield(cond, 'name')
                    self.throwValidationError( ...
                        'Condition %d missing required "name" field', i);
                end

                condName = char(cond.name);

                if ismember(condName, conditionNames)
                    self.throwValidationError( ...
                        'Duplicate condition name: "%s"', condName);
                end
                conditionNames{end+1} = condName; %#ok<AGROW>

                if ~isfield(cond, 'commands')
                    self.throwValidationError( ...
                        'Condition "%s" missing required "commands" field', condName);
                end

                commands = self.normalizeToCell(cond.commands);
                if isempty(commands)
                    self.throwValidationError( ...
                        'Condition "%s" must contain at least one command', condName);
                end

                self.validateCommands(commands, sprintf('Condition "%s"', condName));
            end
        end

        % --- experiment sequence ---------------------------------------------

        function validateExperimentSequence(self, experiment, conditionNames)
            experiment = self.normalizeToCell(experiment);

            if isempty(experiment)
                self.throwValidationError( ...
                    '"experiment" section must contain at least one entry');
            end

            for i = 1:length(experiment)
                entry = experiment{i};

                if ischar(entry) || isstring(entry)
                    % Standalone condition reference
                    if ~ismember(char(entry), conditionNames)
                        self.throwValidationError( ...
                            'experiment entry %d references unknown condition: "%s"', ...
                            i, entry);
                    end

                elseif isstruct(entry)
                    if isfield(entry, 'flow_control')
                        % Flow-control entry
                        self.validateFlowControlEntry(entry, conditionNames, i);
                    elseif isfield(entry, 'trials')
                        % Block definition (may have a block-level trial_check)
                        self.validateBlockDefinition(entry, conditionNames, i);
                    elseif isfield(entry, 'condition')
                        % Verbose condition reference (mapping form)
                        if ~ismember(char(entry.condition), conditionNames)
                            self.throwValidationError( ...
                                'experiment entry %d references unknown condition: "%s"', ...
                                i, char(entry.condition));
                        end
                    else
                        self.throwValidationError( ...
                            ['experiment entry %d is a mapping but has no "trials:", ' ...
                             '"condition:", or "flow_control:" key'], i);
                    end

                else
                    self.throwValidationError( ...
                        ['experiment entry %d must be either a condition name (string) ' ...
                         'or a block definition (YAML mapping)'], i);
                end
            end
        end

        function validateBlockDefinition(self, block, conditionNames, blockIndex)
            % A block must have a trials list; all other fields are optional

            if ~isfield(block, 'trials')
                self.throwValidationError( ...
                    'experiment block %d missing required "trials" field', blockIndex);
            end

            trials = self.normalizeToCell(block.trials);
            if isempty(trials)
                self.throwValidationError( ...
                    'experiment block %d "trials" list must not be empty', blockIndex);
            end

            for j = 1:length(trials)
                trialName = char(trials{j});
                if ~ismember(trialName, conditionNames)
                    self.throwValidationError( ...
                        'experiment block %d references unknown condition: "%s"', ...
                        blockIndex, trialName);
                end
            end

            if isfield(block, 'repetitions')
                reps = block.repetitions;
                if ~isnumeric(reps) || reps < 1 || floor(reps) ~= reps
                    self.throwValidationError( ...
                        'experiment block %d "repetitions" must be a positive integer', ...
                        blockIndex);
                end
            end

            if isfield(block, 'intertrial')
                itName = char(block.intertrial);
                if ~ismember(itName, conditionNames)
                    self.throwValidationError( ...
                        ['experiment block %d "intertrial" references unknown ' ...
                         'condition: "%s"'], blockIndex, itName);
                end
            end

            % Mutual exclusivity: repetitions and min_repeats/max_repeats
            hasRepetitions = isfield(block, 'repetitions') && ~isempty(block.repetitions);
            hasMinMax = (isfield(block, 'min_repeats') && ~isempty(block.min_repeats)) || ...
                        (isfield(block, 'max_repeats') && ~isempty(block.max_repeats));
            if hasRepetitions && hasMinMax
                self.throwValidationError( ...
                    'experiment block %d sets both "repetitions" and "min_repeats"/"max_repeats" — use one or the other', ...
                    blockIndex);
            end

            % Block-level trial_check validation
            if isfield(block, 'trial_check') && ~isempty(block.trial_check)
                self.validateBlockTrialCheck(block.trial_check, conditionNames, blockIndex);
            end
        end

        % --- commands --------------------------------------------------------

        function validateCommands(self, commands, context)
            % Validate a cell array of command structs.

            for i = 1:length(commands)
                cmd = commands{i};

                if ~isfield(cmd, 'type')
                    self.throwValidationError( ...
                        '%s, command %d: missing required "type" field', context, i);
                end

                switch cmd.type

                    case 'controller'
                        if ~isfield(cmd, 'command_name')
                            self.throwValidationError( ...
                                '%s, command %d: controller command missing "command_name"', ...
                                context, i);
                        end
                        if isfield(cmd, 'duration')
                            self.validateDurationField(cmd.duration, ...
                                sprintf('%s, command %d duration', context, i));
                        end

                    case 'wait'
                        if ~isfield(cmd, 'duration')
                            self.throwValidationError( ...
                                '%s, command %d: wait command missing "duration"', context, i);
                        end
                        self.validateDurationField(cmd.duration, ...
                            sprintf('%s, command %d duration', context, i));

                    case 'plugin'
                        if ~isfield(cmd, 'plugin_name')
                            self.throwValidationError( ...
                                '%s, command %d: plugin command missing "plugin_name"', ...
                                context, i);
                        end

                    otherwise
                        self.throwValidationError( ...
                            '%s, command %d: invalid type "%s"', context, i, cmd.type);
                end
            end
        end

        function validateDurationField(self, value, context)
            % A duration field must be a non-negative number.
            % YAML anchor/alias syntax (*var_name) is resolved by SnakeYAML
            % before this validation runs, so values are always numeric here.

            if isnumeric(value) && isscalar(value) && value >= 0
                return;
            end
            self.throwValidationError( ...
                '%s: duration must be a non-negative number', context);
        end

    end

    % =========================================================================
    %  PRIVATE — EXTRACTION
    % =========================================================================
    methods (Access = private)

        function protocol = extractProtocol(self, data)
            % Build the protocol struct from validated raw YAML data

            protocol = struct();
            protocol.version       = data.version;
            protocol.experimentInfo = data.experiment_info;

            % --- Capabilities ------------------------------------------------
            protocol.capabilities = self.parseCapabilities(data);

            % --- Rig / arena / controller ------------------------------------
            rigPath = self.resolveRelativePath(data.rig);
            rigConfig = load_rig_config(rigPath);

            protocol.rigConfig        = rigConfig;
            protocol.arenaConfig      = rigConfig.arena;
            protocol.derivedConfig    = rigConfig.derived;
            protocol.rigFilepath      = rigPath;
            protocol.arenaFilepath    = rigConfig.arena_file;

            if isfield(rigConfig, 'controller')
                protocol.controllerConfig = rigConfig.controller;
            else
                protocol.controllerConfig = struct('host', '', 'port', 62222);
            end

            if self.verbose
                fprintf('  Controller: %s:%d\n', ...
                    protocol.controllerConfig.host, ...
                    protocol.controllerConfig.port);
            end

            % --- Plugins -----------------------------------------------------
            if isfield(data, 'plugins')
                expPlugins = self.normalizeToCell(data.plugins);
                expPlugins = self.mergeRigPluginConfig(expPlugins, rigConfig.plugins);
                protocol.plugins = expPlugins;
                if self.verbose
                    fprintf('  Plugins: %d defined\n', length(protocol.plugins));
                end
            else
                protocol.plugins = {};
                if self.verbose
                    fprintf('  Plugins: none\n');
                end
            end

            % --- Metric map (flow control) -----------------------------------
            self.metricMap     = self.buildMetricMap(protocol.plugins);
            protocol.metricMap = self.metricMap;

            % --- Variables ---------------------------------------------------
            protocol.variables = self.parseVariables(data);

            if self.verbose && ~isempty(fieldnames(protocol.variables))
                varNames = fieldnames(protocol.variables);
                fprintf('  Variables (%d): %s\n', length(varNames), ...
                    strjoin(varNames, ', '));
            end

            % --- Conditions → commands map -----------------------------------
            conditionsMap = self.buildConditionsMap(data.conditions);

            % --- Determine if flow control is used ---------------------------
            protocol.hasFlowControl = ismember('flow_control', protocol.capabilities);

            % --- Experiment → command sequence and/or program ----------------
            experiment = self.normalizeToCell(data.experiment);

            if protocol.hasFlowControl
                % Flow-control protocol: build a program of control nodes.
                % The commandSequence is not pre-expanded (repeat_until has
                % unknown iteration count at parse time).
                protocol.program         = self.buildProgram(experiment, conditionsMap);
                protocol.conditionsMap   = conditionsMap;
                protocol.commandSequence = {};

                % Validate the program (criteria, monitors, caps)
                self.validateFlowControlProgram(protocol);

                if self.verbose
                    fprintf('  Program: %d nodes (flow control)\n', ...
                        numel(protocol.program));
                end
            else
                % Standard protocol: fully expand into flat command sequence
                protocol.commandSequence = self.expandExperiment(experiment, conditionsMap);
                protocol.program         = {};
                protocol.conditionsMap   = conditionsMap;

                if self.verbose
                    fprintf('  Command sequence: %d steps\n', ...
                        length(protocol.commandSequence));
                end
            end

            % --- Raw YAML data (aliases resolved) ----------------------------
            protocol.rawYamlData = data;
        end

        function variables = parseVariables(self, data)
            % Return the variables struct, or an empty struct if absent

            if isfield(data, 'variables') && isstruct(data.variables)
                variables = data.variables;
            else
                variables = struct();
            end
        end

        function conditionsMap = buildConditionsMap(self, conditions)
            % Build a containers.Map of conditionName -> commands cell array.
            % All YAML anchor/alias values are already resolved by SnakeYAML
            % before this method is called; no further substitution is needed.

            conditions    = self.normalizeToCell(conditions);
            conditionsMap = containers.Map();

            for i = 1:length(conditions)
                cond     = conditions{i};
                name     = char(cond.name);
                commands = self.normalizeToCell(cond.commands);
                conditionsMap(name) = commands;
            end
        end

        function commandSequence = expandExperiment(self, experiment, conditionsMap)
            % Expand the experiment list into a flat ordered cell array of
            % {id, commands} structs.  Standalone condition references become
            % one step each.  Block definitions are expanded into all their
            % trials (with repetitions and optional randomization) with
            % intertrials inserted between consecutive trials.

            commandSequence = {};

            for i = 1:length(experiment)
                entry = experiment{i};

                if ischar(entry) || isstring(entry)
                    % Standalone condition — one step
                    name     = char(entry);
                    commands = conditionsMap(name);
                    commandSequence{end+1} = struct('id', name, 'commands', {commands}); %#ok<AGROW>

                elseif isstruct(entry)
                    % Block — expand and append all generated steps
                    blockSteps  = self.expandBlock(entry, conditionsMap);
                    commandSequence = [commandSequence, blockSteps]; %#ok<AGROW>
                end
            end
        end

        function entries = expandBlock(self, blockDef, conditionsMap)
            % Expand a block definition into an ordered cell array of steps.
            %
            % Intertrial steps are inserted between every consecutive pair of
            % trials, including across repetition boundaries, but not after
            % the final trial in the block.

            trials = self.normalizeToCell(blockDef.trials);

            reps = 1;
            if isfield(blockDef, 'repetitions')
                reps = blockDef.repetitions;
            end

            doRandomize = false;
            if isfield(blockDef, 'randomize')
                doRandomize = logical(blockDef.randomize);
            end

            hasIntertrial = isfield(blockDef, 'intertrial') && ...
                            ~isempty(blockDef.intertrial);
            if hasIntertrial
                intertrialName     = char(blockDef.intertrial);
                intertrialCommands = conditionsMap(intertrialName);
            end

            blockLabel = '';
            if isfield(blockDef, 'name')
                blockLabel = char(blockDef.name);
            end

            % Build the complete ordered trial list across all repetitions
            allTrials = {};
            for rep = 1:reps
                if doRandomize
                    order     = randperm(length(trials));
                    repTrials = trials(order);
                else
                    repTrials = trials;
                end
                allTrials = [allTrials, repTrials]; %#ok<AGROW>
            end

            % Assemble entries, inserting intertrial between (not after last)
            entries = {};
            for k = 1:length(allTrials)
                trialName = char(allTrials{k});
                commands  = conditionsMap(trialName);

                if isempty(blockLabel)
                    stepId = trialName;
                else
                    stepId = sprintf('%s: %s', blockLabel, trialName);
                end

                entries{end+1} = struct('id', stepId, 'commands', {commands}); %#ok<AGROW>

                % Insert intertrial after every trial except the last
                if hasIntertrial && k < length(allTrials)
                    itId           = sprintf('intertrial (%s)', intertrialName);
                    entries{end+1} = struct('id', itId, ...
                                           'commands', {intertrialCommands}); %#ok<AGROW>
                end
            end
        end

    end

    % =========================================================================
    %  PRIVATE — FLOW CONTROL PARSING (Stage 1)
    % =========================================================================
    methods (Access = private)

        function caps = parseCapabilities(~, data)
            % Extract the requires: list from the YAML
            if isfield(data, 'requires') && ~isempty(data.requires)
                r = data.requires;
                if ischar(r) || isstring(r)
                    caps = {char(r)};
                elseif iscell(r)
                    caps = cellfun(@char, r, 'UniformOutput', false);
                else
                    caps = {};
                end
            else
                caps = {};
            end
        end

        function map = buildMetricMap(self, plugins)
            % Build a mapping from metric name to the plugin that provides
            % it. Plugins declare this via a provides_metric field.
            map = containers.Map();
            for i = 1:numel(plugins)
                pd = plugins{i};
                if isfield(pd, 'provides_metric') && ~isempty(pd.provides_metric)
                    metricName = char(pd.provides_metric);
                    pluginName = char(pd.name);
                    if map.isKey(metricName)
                        self.throwValidationError( ...
                            'Metric "%s" is provided by both "%s" and "%s"', ...
                            metricName, map(metricName), pluginName);
                    end
                    map(metricName) = pluginName;
                    if self.verbose
                        fprintf('  Metric "%s" -> plugin "%s"\n', metricName, pluginName);
                    end
                end
            end
        end

        function program = buildProgram(self, experiment, conditionsMap)
            % Build a program of control nodes from the experiment list.
            % This is the flow-control analogue of expandExperiment: instead
            % of a flat command sequence, it produces a list of nodes that
            % the runner interprets at runtime.
            program = {};
            for i = 1:numel(experiment)
                program{end + 1} = self.classifyEntry(experiment{i}, conditionsMap); %#ok<AGROW>
            end
        end

        function node = classifyEntry(self, entry, conditionsMap)
            % Map one experiment entry to a program node

            if ischar(entry) || isstring(entry)
                node = struct('kind', 'ref', 'name', char(entry));
                return;
            end

            if ~isstruct(entry)
                self.throwValidationError( ...
                    'Experiment entry is neither a string nor a mapping');
            end

            if isfield(entry, 'flow_control')
                fc = char(entry.flow_control);
                switch fc
                    case 'trial_check'
                        node = self.parseTrialCheckNode(entry);
                    case 'repeat_until'
                        node = self.parseRepeatUntilNode(entry);
                    otherwise
                        self.throwValidationError( ...
                            'Unrecognised flow_control value: "%s" (Stage 1 supports trial_check and repeat_until)', fc);
                end
            elseif isfield(entry, 'trials')
                node = self.parseStaticBlockNode(entry);
            elseif isfield(entry, 'condition')
                node = struct('kind', 'ref', 'name', char(entry.condition));
            else
                self.throwValidationError( ...
                    'Experiment mapping has no "condition:", "trials:", or "flow_control:" key');
            end
        end

        function node = parseTrialCheckNode(self, entry)
            node              = struct();
            node.kind         = 'trial_check';
            node.trial        = char(entry.condition);
            node.criterion    = self.parseCriterion(entry.criterion);
            node.monitor      = self.resolveMonitor(node.criterion.metric);
            node.max_attempts = self.requiredFlowField(entry, 'max_attempts', 'trial_check');
            node.on_exhausted = char(self.requiredFlowField(entry, 'on_exhausted', 'trial_check'));

            if isfield(entry, 'on_fail') && isstruct(entry.on_fail) ...
                    && isfield(entry.on_fail, 'run') && ~isempty(entry.on_fail.run)
                node.on_fail_run = char(entry.on_fail.run);
            else
                node.on_fail_run = '';
            end
        end

        function node = parseRepeatUntilNode(self, entry)
            node              = struct();
            node.kind         = 'repeat_until';
            node.name         = char(self.fieldOrDefault(entry, 'name', 'repeat_until block'));
            node.trials       = self.normalizeToCellOfChar(entry.trials);
            node.criterion    = self.parseCriterion(entry.criterion);
            node.monitor      = self.resolveMonitor(node.criterion.metric);
            node.min_repeats  = self.fieldOrDefault(entry, 'min_repeats', 1);
            node.max_repeats  = self.requiredFlowField(entry, 'max_repeats', 'repeat_until');
            node.randomize    = logical(self.fieldOrDefault(entry, 'randomize', false));

            if isfield(entry, 'trial_check') && ~isempty(entry.trial_check)
                node.trial_check = self.parseBlockTrialCheckNode(entry.trial_check);
            else
                node.trial_check = [];
            end
        end

        function node = parseStaticBlockNode(self, entry)
            node             = struct();
            node.kind        = 'block';
            node.name        = char(self.fieldOrDefault(entry, 'name', 'block'));
            node.trials      = self.normalizeToCellOfChar(entry.trials);
            node.repetitions = self.fieldOrDefault(entry, 'repetitions', 1);
            node.randomize   = logical(self.fieldOrDefault(entry, 'randomize', false));
            node.intertrial  = '';
            if isfield(entry, 'intertrial') && ~isempty(entry.intertrial)
                node.intertrial = char(entry.intertrial);
            end

            if isfield(entry, 'trial_check') && ~isempty(entry.trial_check)
                node.trial_check = self.parseBlockTrialCheckNode(entry.trial_check);
            else
                node.trial_check = [];
            end
        end

        function tc = parseBlockTrialCheckNode(self, tcEntry)
            tc              = struct();
            tc.criterion    = self.parseCriterion(tcEntry.criterion);
            tc.monitor      = self.resolveMonitor(tc.criterion.metric);
            tc.max_attempts = self.requiredFlowField(tcEntry, 'max_attempts', 'block trial_check');
            tc.on_exhausted = char(self.requiredFlowField(tcEntry, 'on_exhausted', 'block trial_check'));

            if isfield(tcEntry, 'on_fail') && isstruct(tcEntry.on_fail) ...
                    && isfield(tcEntry.on_fail, 'run') && ~isempty(tcEntry.on_fail.run)
                tc.on_fail_run = char(tcEntry.on_fail.run);
            else
                tc.on_fail_run = '';
            end
        end

        function crit = parseCriterion(~, raw)
            % Parse a criterion struct from the YAML
            crit = struct();
            crit.metric    = char(raw.metric);
            crit.statistic = char(raw.statistic);
            crit.stop_when = char(raw.stop_when);

            if isfield(raw, 'threshold') && ~isempty(raw.threshold)
                crit.threshold = raw.threshold;
            end
            if isfield(raw, 'level') && ~isempty(raw.level)
                crit.level = raw.level;
            end
            if isfield(raw, 'baseline') && ~isempty(raw.baseline)
                bl = raw.baseline;
                crit.baseline = struct();
                if isfield(bl, 'window')
                    w = bl.window;
                    if iscell(w)
                        crit.baseline.window = [w{1}, w{2}];
                    else
                        crit.baseline.window = w;
                    end
                end
                if isfield(bl, 'units')
                    crit.baseline.units = char(bl.units);
                end
            end
            if isfield(raw, 'fraction') && ~isempty(raw.fraction)
                crit.fraction = raw.fraction;
            end
        end

        function monitorName = resolveMonitor(self, metricName)
            metricName = char(metricName);
            if self.metricMap.isKey(metricName)
                monitorName = self.metricMap(metricName);
            else
                monitorName = '';
            end
        end
    end

    % =========================================================================
    %  PRIVATE — FLOW CONTROL VALIDATION
    % =========================================================================
    methods (Access = private)

        function validateFlowControlEntry(self, entry, conditionNames, entryIndex)
            % Validate a flow-control experiment entry at the structural
            % level (fields present, references valid). Criterion-level
            % validation happens in validateFlowControlProgram.
            fc = char(entry.flow_control);
            loc = sprintf('experiment entry %d', entryIndex);

            switch fc
                case 'trial_check'
                    if ~isfield(entry, 'condition') || isempty(entry.condition)
                        self.throwValidationError( ...
                            '%s: trial_check requires "condition:" field', loc);
                    end
                    if ~ismember(char(entry.condition), conditionNames)
                        self.throwValidationError( ...
                            '%s: trial_check references unknown condition: "%s"', ...
                            loc, char(entry.condition));
                    end
                    if ~isfield(entry, 'criterion') || isempty(entry.criterion)
                        self.throwValidationError( ...
                            '%s: trial_check requires "criterion:" field', loc);
                    end
                    if isfield(entry, 'on_fail') && isstruct(entry.on_fail) ...
                            && isfield(entry.on_fail, 'run') && ~isempty(entry.on_fail.run)
                        if ~ismember(char(entry.on_fail.run), conditionNames)
                            self.throwValidationError( ...
                                '%s: on_fail.run references unknown condition: "%s"', ...
                                loc, char(entry.on_fail.run));
                        end
                    end

                case 'repeat_until'
                    if ~isfield(entry, 'trials') || isempty(entry.trials)
                        self.throwValidationError( ...
                            '%s: repeat_until requires "trials:" field', loc);
                    end
                    trials = self.normalizeToCell(entry.trials);
                    for j = 1:numel(trials)
                        tName = char(trials{j});
                        if ~ismember(tName, conditionNames)
                            self.throwValidationError( ...
                                '%s: repeat_until references unknown condition: "%s"', ...
                                loc, tName);
                        end
                    end
                    if ~isfield(entry, 'criterion') || isempty(entry.criterion)
                        self.throwValidationError( ...
                            '%s: repeat_until requires "criterion:" field', loc);
                    end

                otherwise
                    self.throwValidationError( ...
                        '%s: unknown flow_control type: "%s"', loc, fc);
            end

            % Validate block-level trial_check if present on a repeat_until
            if isfield(entry, 'trial_check') && ~isempty(entry.trial_check)
                self.validateBlockTrialCheck(entry.trial_check, conditionNames, entryIndex);
            end
        end

        function validateBlockTrialCheck(self, tc, conditionNames, blockIndex)
            loc = sprintf('experiment block %d (block-level trial_check)', blockIndex);

            if ~isfield(tc, 'criterion') || isempty(tc.criterion)
                self.throwValidationError('%s: missing "criterion:" field', loc);
            end
            if ~isfield(tc, 'max_attempts') || isempty(tc.max_attempts)
                self.throwValidationError('%s: missing "max_attempts" (required, no default)', loc);
            end
            if ~isfield(tc, 'on_exhausted') || isempty(tc.on_exhausted)
                self.throwValidationError('%s: missing "on_exhausted" (required, no default)', loc);
            else
                exVal = char(tc.on_exhausted);
                if ~ismember(exVal, {'advance', 'abort'})
                    self.throwValidationError( ...
                        '%s: on_exhausted must be "advance" or "abort" (got "%s")', loc, exVal);
                end
            end
            if isfield(tc, 'on_fail') && isstruct(tc.on_fail) ...
                    && isfield(tc.on_fail, 'run') && ~isempty(tc.on_fail.run)
                if ~ismember(char(tc.on_fail.run), conditionNames)
                    self.throwValidationError( ...
                        '%s: on_fail.run references unknown condition: "%s"', ...
                        loc, char(tc.on_fail.run));
                end
            end
        end

        function validateFlowControlProgram(self, protocol)
            % Validate the program nodes after they've been parsed.
            % Criterion-level validation and monitor resolution checks.
            cmap = protocol.conditionsMap;

            % Check requires: [flow_control] is present
            hasFC = any(cellfun(@(n) ismember(n.kind, {'trial_check', 'repeat_until'}), ...
                protocol.program));
            if hasFC && ~ismember('flow_control', protocol.capabilities)
                self.throwValidationError( ...
                    'Protocol uses flow control but does not declare requires: [flow_control]');
            end

            for i = 1:numel(protocol.program)
                node = protocol.program{i};
                loc  = sprintf('program entry %d', i);

                switch node.kind
                    case 'ref'
                        % Already validated in validateExperimentSequence

                    case 'trial_check'
                        self.validateCriterionFields(node.criterion, loc);
                        self.assertMonitorResolved(node.monitor, node.criterion.metric, loc);
                        self.assertOnExhaustedKeyword(node.on_exhausted, loc);
                        if ~isempty(node.on_fail_run)
                            if ~cmap.isKey(node.on_fail_run)
                                self.throwValidationError( ...
                                    '%s: on_fail.run references unknown condition: "%s"', ...
                                    loc, node.on_fail_run);
                            end
                        end

                    case 'repeat_until'
                        self.validateCriterionFields(node.criterion, loc);
                        self.assertMonitorResolved(node.monitor, node.criterion.metric, loc);
                        if node.min_repeats > node.max_repeats
                            self.throwValidationError( ...
                                '%s: min_repeats (%d) cannot exceed max_repeats (%d)', ...
                                loc, node.min_repeats, node.max_repeats);
                        end
                        if ~isempty(node.trial_check)
                            tc    = node.trial_check;
                            tcLoc = sprintf('%s (block-level trial_check)', loc);
                            self.validateCriterionFields(tc.criterion, tcLoc);
                            self.assertMonitorResolved(tc.monitor, tc.criterion.metric, tcLoc);
                            self.assertOnExhaustedKeyword(tc.on_exhausted, tcLoc);
                        end

                    case 'block'
                        if ~isempty(node.trial_check)
                            tc    = node.trial_check;
                            tcLoc = sprintf('%s (block-level trial_check)', loc);
                            self.validateCriterionFields(tc.criterion, tcLoc);
                            self.assertMonitorResolved(tc.monitor, tc.criterion.metric, tcLoc);
                            self.assertOnExhaustedKeyword(tc.on_exhausted, tcLoc);
                        end
                end
            end
        end

        function validateCriterionFields(self, criterion, loc)
            issues = CriterionEvaluator.validate(criterion);
            if ~isempty(issues)
                msg = sprintf('%s: criterion validation failed:\n', loc);
                for j = 1:numel(issues)
                    msg = sprintf('%s  - %s\n', msg, issues{j});
                end
                self.throwValidationError('%s', msg);
            end

            supported = CriterionEvaluator.supportedMetrics();
            if ~ismember(char(criterion.metric), supported)
                self.throwValidationError( ...
                    '%s: metric "%s" is not supported (available: %s)', ...
                    loc, char(criterion.metric), strjoin(supported, ', '));
            end
        end

        function assertMonitorResolved(self, monitorName, metricName, loc)
            if isempty(monitorName)
                self.throwValidationError( ...
                    '%s: no plugin provides metric "%s" — add provides_metric to the plugin definition', ...
                    loc, char(metricName));
            end
        end

        function assertOnExhaustedKeyword(self, value, loc)
            if ~ismember(value, {'advance', 'abort'})
                self.throwValidationError( ...
                    '%s: on_exhausted must be "advance" or "abort" (got "%s")', loc, value);
            end
        end

    end

    % =========================================================================
    %  PRIVATE — HELPERS
    % =========================================================================
    methods (Access = private)

        function cellArr = normalizeToCell(~, input)
            % Convert loadFile output to a uniform cell array.
            %
            % loadFile returns:
            %   - A cell array for YAML sequences with mixed types
            %   - A struct array for YAML sequences of mappings
            %   - A plain value for YAML scalars
            %
            % This function normalises all three cases.

            if isempty(input)
                cellArr = {};
            elseif iscell(input)
                cellArr = input;
            elseif isstruct(input)
                % Struct array (one element per YAML list item)
                cellArr = arrayfun(@(s) s, input, 'UniformOutput', false);
            else
                % Scalar string, number, etc.
                cellArr = {input};
            end
        end

        function resolved = resolveRelativePath(self, relPath)
            % Resolve relPath relative to the protocol file's directory.
            % Absolute paths (Windows drive letters or Unix /...) are returned
            % unchanged.
      
            relPath = char(relPath);
            
            [protDir, ~, ~] = fileparts(self.filepath);

            isAbsolute = (ispc() && length(relPath) >= 2 && relPath(2) == ':') || ...
                         (~ispc() && startsWith(relPath, '/'));

            if isAbsolute
                resolved = relPath;
            else
                resolved = fullfile(protDir, relPath);
            end

            % Canonicalize (resolves .. and symlinks)
            resolved = char(java.io.File(resolved).getCanonicalPath());
        end

        function expPlugins = mergeRigPluginConfig(self, expPlugins, rigPlugins)
            % Merge rig-level hardware config into experiment plugin definitions.
            %
            % Rig fields are written into plugin.config.  If the experiment
            % YAML already defines the same field in plugin.config, the
            % experiment value is kept (experiment overrides rig).  The
            % "enabled" rig field is skipped (rig-level metadata only).

            if isempty(rigPlugins) || ~isstruct(rigPlugins)
                return;
            end

            rigPluginNames = fieldnames(rigPlugins);

            for i = 1:length(expPlugins)
                plugin     = expPlugins{i};
                pluginName = plugin.name;

                if ~ismember(pluginName, rigPluginNames)
                    continue;
                end

                rigPlugin = rigPlugins.(pluginName);
                if ~isstruct(rigPlugin)
                    continue;
                end

                if ~isfield(plugin, 'config') || isempty(plugin.config)
                    plugin.config = struct();
                end

                rigFields = fieldnames(rigPlugin);
                for j = 1:length(rigFields)
                    field = rigFields{j};
                    if strcmp(field, 'enabled')
                        continue;
                    end
                    if ~isfield(plugin.config, field)
                        plugin.config.(field) = rigPlugin.(field);
                    end
                end

                expPlugins{i} = plugin;

                if self.verbose
                    fprintf('  Merged rig config into plugin: %s\n', pluginName);
                end
            end
        end

        function printProtocolSummary(self, protocol)
            % Print a human-readable summary of the parsed protocol

            fprintf('\n=== Protocol Summary ===\n');
            fprintf('Version:    %d\n', protocol.version);
            fprintf('Experiment: %s\n', protocol.experimentInfo.name);

            if isfield(protocol.experimentInfo, 'author')
                fprintf('Author:     %s\n', protocol.experimentInfo.author);
            end
            if isfield(protocol.experimentInfo, 'date_created')
                fprintf('Date:       %s\n', protocol.experimentInfo.date_created);
            end

            fprintf('Rig:        %s\n', protocol.rigConfig.name);
            fprintf('Controller: %s:%d\n', ...
                protocol.controllerConfig.host, protocol.controllerConfig.port);
            fprintf('Arena:      %dx%d panels (%s)\n', ...
                protocol.arenaConfig.num_rows, ...
                protocol.arenaConfig.num_cols, ...
                protocol.arenaConfig.generation);

            % Variables
            varNames = fieldnames(protocol.variables);
            if ~isempty(varNames)
                fprintf('\nVariables (%d):\n', length(varNames));
                for i = 1:length(varNames)
                    val = protocol.variables.(varNames{i});
                    if isnumeric(val)
                        fprintf('  %-24s = %g\n', varNames{i}, val);
                    else
                        fprintf('  %-24s = "%s"\n', varNames{i}, val);
                    end
                end
            end

            % Command sequence
            n = length(protocol.commandSequence);
            fprintf('\nCommand sequence (%d steps):\n', n);
            for i = 1:n
                fprintf('  %3d. %s\n', i, protocol.commandSequence{i}.id);
            end

            fprintf('========================\n\n');
        end

        function throwValidationError(self, varargin)
            msg     = sprintf(varargin{:});
            fullMsg = sprintf('Protocol validation failed (%s):\n%s', self.filepath, msg);
            error('ProtocolParser:ValidationError', '%s', fullMsg);
        end

        % --- flow control helpers ---

        function val = requiredFlowField(self, s, fieldName, context)
            % Read a required flow-control field, erroring if missing
            if ~isfield(s, fieldName) || isempty(s.(fieldName))
                self.throwValidationError( ...
                    '%s requires "%s" (no default)', context, fieldName);
            end
            val = s.(fieldName);
        end

        function out = normalizeToCellOfChar(self, input)
            c   = self.normalizeToCell(input);
            out = cell(1, numel(c));
            for i = 1:numel(c)
                out{i} = char(c{i});
            end
        end

    end

    % =========================================================================
    %  STATIC
    % =========================================================================
    methods (Static)

        function n = get_total_steps(protocol)
            % Return the total number of execution steps in a V3 protocol
            %
            % Input:
            %   protocol - parsed protocol struct (output of parse())
            % Returns:
            %   n - number of entries in protocol.commandSequence

            n = length(protocol.commandSequence);
        end

        function v = fieldOrDefault(s, field, default)
            % Return a struct field value, or a default if absent/empty
            if isstruct(s) && isfield(s, field) && ~isempty(s.(field))
                v = s.(field);
            else
                v = default;
            end
        end

    end

end

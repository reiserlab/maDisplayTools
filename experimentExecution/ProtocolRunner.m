classdef ProtocolRunner < handle
    % PROTOCOLRUNNER Main orchestrator for experiment execution
    %
    % This class manages the complete lifecycle of a Version 3 experiment:
    %   - Parsing and validating the protocol YAML file
    %   - Initializing hardware and plugins
    %   - Executing the command sequence produced by ProtocolParser
    %   - Logging and data management
    %   - Cleanup and error handling
    %
    % The Version 3 parser fully expands the experiment sequence (conditions,
    % blocks, repetitions, randomization, intertrials) into a flat ordered
    % list of steps.  This runner simply executes that list top-to-bottom
    % with no additional scheduling logic.
    %
    % See also: ProtocolParser, run_protocol

    properties (Access = private)
        protocolFilePath    % Path to YAML protocol file
        arenaIP             % Arena controller IP address
        protocolData        % Parsed protocol struct (from ProtocolParser)
        pluginManager       % PluginManager instance
        arenaController     % Arena hardware controller
        commandExecutor     % CommandExecutor instance
        parser              % ProtocolParser instance
        logger              % ExperimentLogger instance
        outputDir           % Base output directory (defaults to yaml location)
        experimentDir       % Timestamped results directory for this run
        verbose             % Verbose logging flag
        dryRun              % Dry run mode — validate only, no hardware
        maxAttempts         % Max retry attempts per step on recoverable error
        recoverableErrors   % Cell array of error identifiers that allow retry

        % --- Flow control (Stage 1) ---
        executedTrace       % Cell array of structured trace records
        baselineValues      % containers.Map: metricName -> baseline value
    end

    % =========================================================================
    %  PUBLIC INTERFACE
    % =========================================================================
    methods (Access = public)

        function self = ProtocolRunner(protocolFilePath, varargin)
            % Constructor — parses and validates the protocol file.
            % Hardware is not touched until run() is called.
            %
            % Syntax:
            %   runner = ProtocolRunner(protocolFilePath)
            %   runner = ProtocolRunner(protocolFilePath, Name, Value)
            %
            % Input Arguments:
            %   protocolFilePath - Path to a Version 3 YAML protocol file
            %
            % Name-Value Pairs:
            %   'arenaIP'     - Arena IP if different from rig config (default: '')
            %   'OutputDir'   - Base output directory (default: yaml file location)
            %   'Verbose'     - Print progress to console (default: true)
            %   'DryRun'      - Validate and initialize without executing (default: false)
            %   'maxAttempts' - Retry attempts on recoverable hardware errors (default: 2)

            p = inputParser;
            addRequired(p,  'protocolFilePath', @ischar);
            addParameter(p, 'arenaIP',      '',    @ischar);
            addParameter(p, 'OutputDir',    '',    @ischar);
            addParameter(p, 'Verbose',      true,  @islogical);
            addParameter(p, 'DryRun',       false, @islogical);
            addParameter(p, 'maxAttempts',  2,     @(x) isnumeric(x) && x >= 1);
            parse(p, protocolFilePath, varargin{:});

            self.protocolFilePath = p.Results.protocolFilePath;
            self.outputDir        = p.Results.OutputDir;
            self.verbose          = p.Results.Verbose;
            self.dryRun           = p.Results.DryRun;
            self.arenaIP          = p.Results.arenaIP;
            self.maxAttempts      = p.Results.maxAttempts;

            self.recoverableErrors = {
                'CommandExecutor:HardwareFailure', ...
                'SerialPlugin:NotConnected', ...
                'SerialPlugin:CriticalFailure'
            };

            self.executedTrace  = {};
            self.baselineValues = containers.Map();

            self.validateEnvironment();
            self.parseProtocol();

            % Resolve arena IP: argument takes precedence over rig config
            if isempty(self.arenaIP)
                self.arenaIP = self.protocolData.controllerConfig.host;
            end
            if isempty(self.arenaIP)
                error('ProtocolRunner:NoArenaIP', ...
                    ['No arena IP address found. Provide one via the ''arenaIP'' ' ...
                     'argument or add controller.host to your rig config YAML.']);
            end
        end

        function run(self)
            % RUN Execute the complete experiment
            %
            % Execution flow:
            %   1. Initialize experiment directory, logger, plugins, hardware
            %   2. Execute the experiment:
            %      - Standard protocols: iterate the flat command sequence
            %      - Flow-control protocols: interpret the program of nodes
            %   3. Finalize (save summary, clean shutdown)

            try
                self.initializeExperiment();

                if self.dryRun
                    self.logger.log('INFO', 'Dry run complete — protocol is valid');
                    self.cleanup();
                    return;
                end

                if self.protocolData.hasFlowControl
                    self.executeProgramSequence();
                else
                    self.executeCommandSequence();
                end

                self.finalizeExperiment();

            catch ME
                self.logger.log('ERROR', sprintf('Experiment failed: %s', ME.message));
                self.cleanup();
                rethrow(ME);
            end
        end

        function cleanup(self)
            % CLEANUP Stop hardware and close all resources
            %
            % Called automatically at the end of a successful run and on
            % any error.  Safe to call more than once.

            fprintf('Performing cleanup...\n');

            if ~isempty(self.arenaController)
                try
                    self.arenaController.stopDisplay();
                    self.arenaController.close();
                    fprintf('  - Arena hardware stopped\n');
                catch ME
                    fprintf(2, '  - Warning: Could not stop arena: %s\n', ME.message);
                end
            end

            if ~isempty(self.pluginManager)
                try
                    self.pluginManager.closeAll();
                    fprintf('  - All plugins closed\n');
                catch ME
                    fprintf(2, '  - Warning: Could not close plugins: %s\n', ME.message);
                end
            end

            if ~isempty(self.logger)
                try
                    self.logger.close();
                    fprintf('  - Log file closed\n');
                catch ME
                    fprintf(2, '  - Warning: Could not close logger: %s\n', ME.message);
                end
            end

            fprintf('Cleanup complete.\n');
        end

    end

    % =========================================================================
    %  PRIVATE — INITIALIZATION
    % =========================================================================
    methods (Access = private)

        function validateEnvironment(self)
            % Check MATLAB version compatibility

            v = ver('MATLAB');
            if str2double(v.Version) < 9.0  % R2016a
                warning('MATLAB version %s may not be fully supported', v.Version);
            end

            if self.verbose
                fprintf('Environment validation passed\n');
            end
        end

        function parseProtocol(self)
            % Parse the YAML file and store the resulting protocol struct.
            %
            % After this call, self.protocolData contains:
            %   .version          - 3
            %   .experimentInfo   - name, date_created, author, etc.
            %   .rigConfig        - full rig configuration
            %   .arenaConfig      - arena fields (num_rows, num_cols, generation)
            %   .derivedConfig    - computed arena properties
            %   .controllerConfig - host and port
            %   .plugins          - cell array of plugin definition structs
            %   .variables        - resolved variable name -> value struct
            %   .rawYamlData      - raw YAML struct (aliases resolved) for
            %                       writing per-run resolved copies to disk
            %   .commandSequence  - flat ordered cell array of {id, commands}
            %                       structs, ready to execute top-to-bottom

            if self.verbose
                fprintf('Parsing protocol: %s\n', self.protocolFilePath);
            end

            self.parser = ProtocolParser('verbose', self.verbose);

            try
                self.protocolData = self.parser.parse(self.protocolFilePath);
            catch ME
                error('ProtocolRunner:ParseFailed', ...
                    'Failed to parse protocol file: %s', ME.message);
            end
        end

        function initializeExperiment(self)
            % Create output directory, start logger, initialize plugins and hardware

            fprintf('\n=== Initializing Experiment ===\n');

            self.getExperimentDirectory();
            self.initializeLogger();
            self.saveExperimentInputFiles();

            self.logger.log('INFO', '=== EXPERIMENT START ===');
            self.logger.log('INFO', sprintf('Protocol: %s', self.protocolFilePath));
            self.logger.log('INFO', sprintf('Output:   %s', self.experimentDir));

            self.initializePlugins();
            self.initializeArenaHardware();

            self.commandExecutor = CommandExecutor( ...
                self.arenaController, ...
                self.pluginManager, ...
                self.logger);

            self.logger.log('INFO', 'Initialization complete');
            fprintf('=== Initialization Complete ===\n\n');
            cd(cd); % A trick to prevent a weird matlab GUI bug where files disappear
                        % from the matlab file explorer but files are fine.

        end

        function getExperimentDirectory(self)
            % Create a timestamped results subdirectory

            ts   = char(datetime('now', 'Format', 'MM-dd-yyyy_HH-mm-ss'));
            fold = ['results' ts];

            if ~isempty(self.outputDir)
                self.experimentDir = fullfile(self.outputDir, fold);
            else
                [protDir, ~, ~] = fileparts(self.protocolFilePath);
                self.experimentDir = fullfile(protDir, fold);
            end
        end

        function saveExperimentInputFiles(self)
            % Archive the protocol YAML and its paired SD card manifest
            % (if present) into the experiment directory.
            %
            % The manifest is matched to the YAML by the shared yyyymmdd_HHMMSS
            % timestamp that deploy_experiments_to_sd embeds in both filenames.

            yamlDir = fileparts(self.protocolFilePath);
            if isempty(yamlDir)
                yamlDir = '.';
            end

            % Write a resolved copy of the protocol YAML — all anchor/alias
            % references replaced with their actual values.  This is the
            % per-run record: it captures exactly what values were in use
            % for this run, including any variables the user may have edited
            % in the timestamped working YAML before running.
            [~, yamlName, yamlExt] = fileparts(self.protocolFilePath);
            destYaml = fullfile(self.experimentDir, [yamlName yamlExt]);
            try
                yaml.dumpFile(destYaml, self.protocolData.rawYamlData, 'block');
                self.logger.log('INFO', sprintf('Archived resolved protocol YAML: %s', destYaml));
            catch ME
                self.logger.log('WARNING', sprintf( ...
                    'Could not archive protocol YAML: %s', ME.message));
            end

            % Find and copy the matching SD card manifest
            token = regexp(yamlName, '(\d{8}_\d{6})$', 'tokens');
            if isempty(token)
                self.logger.log('WARNING', sprintf( ...
                    ['YAML filename "%s" does not contain a yyyymmdd_HHMMSS ' ...
                     'timestamp suffix — manifest will not be archived.'], yamlName));
                return;
            end

            timestamp    = token{1}{1};
            manifestName = sprintf('MANIFEST_%s.txt', timestamp);
            manifestSrc  = fullfile(yamlDir, manifestName);

            if ~isfile(manifestSrc)
                self.logger.log('WARNING', sprintf( ...
                    'Expected manifest "%s" not found — manifest will not be archived.', ...
                    manifestName));
                return;
            end

            destManifest = fullfile(self.experimentDir, manifestName);
            try
                copyfile(manifestSrc, destManifest);
                self.logger.log('INFO', sprintf('Archived SD card manifest: %s', destManifest));
            catch ME
                self.logger.log('WARNING', sprintf( ...
                    'Could not archive SD card manifest: %s', ME.message));
            end
        end

        function initializeLogger(self)
            logFile    = fullfile(self.experimentDir, 'logs', 'experiment.log');
            self.logger = ExperimentLogger(logFile, self.verbose);
        end

        function initializePlugins(self)
            self.pluginManager = PluginManager(self.logger, self.experimentDir);

            if isempty(self.protocolData.plugins)
                self.logger.log('INFO', 'No plugins defined in protocol');
                return;
            end

            self.logger.log('INFO', 'Initializing plugins...');

            plugins = self.protocolData.plugins;
            for i = 1:length(plugins)
                pluginDef = plugins{i};
                try
                    self.pluginManager.initializePlugin(pluginDef);
                    self.logger.log('INFO', sprintf('  ✓ %s', pluginDef.name));
                catch ME
                    self.logger.log('ERROR', sprintf('  ✗ %s: %s', pluginDef.name, ME.message));
                    error('ProtocolRunner:PluginInitFailed', ...
                        'Plugin initialization failed for "%s"', pluginDef.name);
                end
            end

            self.logger.log('INFO', sprintf('All %d plugins initialized', length(plugins)));
        end

        function initializeArenaHardware(self)
            self.logger.log('INFO', 'Initializing arena hardware...');

            generation = self.protocolData.arenaConfig.generation;
            numRows    = self.protocolData.arenaConfig.num_rows;
            numCols    = self.protocolData.arenaConfig.num_cols;

            if strcmp(generation, 'G4.1')
                try
                    self.arenaController = getPanelsController(self.arenaIP);
                    self.arenaController.open(false);
                catch ME
                    self.logger.log('ERROR', 'Failed to connect to arena controller');
                    error('ProtocolRunner:ArenaInitFailed', ...
                        'Could not connect to arena at %s: %s', self.arenaIP, ME.message);
                end
                self.logger.log('INFO', sprintf('  Arena: %s (%dx%d panels)', ...
                    generation, numRows, numCols));
            else
                error('ProtocolRunner:UnsupportedArena', ...
                    'Unsupported arena generation: %s', generation);
            end
        end

    end

    % =========================================================================
    %  PRIVATE — EXECUTION
    % =========================================================================
    methods (Access = private)

        function executeCommandSequence(self)
            % Execute every step in the command sequence in order.
            %
            % The sequence is already fully expanded by ProtocolParser —
            % conditions resolved, variables substituted, blocks unrolled,
            % intertrials inserted.  This method simply iterates the list.

            seq      = self.protocolData.commandSequence;
            numSteps = length(seq);

            self.logger.log('INFO', '=== EXPERIMENT SEQUENCE START ===');
            self.logger.log('INFO', sprintf('Total steps: %d', numSteps));
            fprintf('\n=== Starting Experiment (%d steps) ===\n', numSteps);

            for i = 1:numSteps
                step = seq{i};
                self.logger.log('INFO', sprintf('--- Step %d/%d: %s ---', ...
                    i, numSteps, step.id));
                fprintf('Step %d/%d: %s\n', i, numSteps, step.id);

                self.executePhase(step.commands, step.id);
            end

            self.logger.log('INFO', '=== EXPERIMENT SEQUENCE COMPLETE ===');
            fprintf('\n=== All Steps Complete ===\n\n');
        end

        function executePhase(self, commands, phaseName)
            % Execute a list of commands with retry logic on recoverable errors.
            %
            % Input Arguments:
            %   commands  - Cell array of command structs
            %   phaseName - Label used in log messages and retry prompts

            if isempty(commands)
                self.logger.log('INFO', sprintf('No commands for "%s" — skipping', phaseName));
                return;
            end

            self.logger.log('INFO', sprintf('=== %s START ===', upper(phaseName)));
            startTime = tic;

            attempt = 1;
            success = false;
            while ~success && attempt <= self.maxAttempts
                try
                    for i = 1:length(commands)
                        self.commandExecutor.execute(commands{i});
                    end
                    success = true;

                catch ME
                    self.logger.log('ERROR', sprintf('"%s" failed on attempt %d: %s', ...
                        phaseName, attempt, ME.message));

                    if attempt < self.maxAttempts && ...
                            ismember(ME.identifier, self.recoverableErrors)
                        attempt = attempt + 1;
                        switch ME.identifier
                            case 'CommandExecutor:HardwareFailure'
                                msg = sprintf(['\n*** Arena hardware failure during "%s" ***\n' ...
                                    'Command returned no confirmation from the arena.\n' ...
                                    'Please restart the arena controller and wait for it ' ...
                                    'to come back online.\n' ...
                                    'Press Enter when ready to retry...'], phaseName);
                            case {'SerialPlugin:NotConnected', 'SerialPlugin:CriticalFailure'}
                                msg = sprintf(['\n*** Serial device failure during "%s" ***\n' ...
                                    'A serial device lost its connection.\n' ...
                                    'Please check the device and press Enter to retry...'], ...
                                    phaseName);
                            otherwise
                                msg = sprintf(['\n*** Recoverable error during "%s" ***\n' ...
                                    'Error: %s\n' ...
                                    'Press Enter to retry...'], phaseName, ME.message);
                        end
                        input(msg);
                    else
                        rethrow(ME);
                    end
                end
            end

            elapsed = toc(startTime);
            self.logger.log('INFO', sprintf('"%s" completed in %.2f s', phaseName, elapsed));
        end

    end

    % =========================================================================
    %  PRIVATE — FLOW CONTROL EXECUTION (Stage 1)
    % =========================================================================
    methods (Access = private)

        function executeProgramSequence(self)
            % Execute a flow-control program (the parallel path to
            % executeCommandSequence for protocols with requires: [flow_control])

            program = self.protocolData.program;
            fprintf('\n=== Starting Experiment (%d top-level nodes) ===\n\n', ...
                numel(program));
            self.logger.log('INFO', '=== EXPERIMENT PROGRAM START ===');
            self.logger.log('INFO', sprintf('Total nodes: %d', numel(program)));

            for i = 1:numel(program)
                self.executeNode(program{i});
            end

            self.logger.log('INFO', '=== EXPERIMENT PROGRAM COMPLETE ===');
            fprintf('\n=== All Nodes Complete ===\n\n');
        end

        function executeNode(self, node)
            switch node.kind
                case 'ref';          self.executeFlowCondition(node.name);
                case 'trial_check';  self.runTrialCheck(node);
                case 'repeat_until'; self.runRepeatUntil(node);
                case 'block';        self.runStaticFlowBlock(node);
                otherwise
                    error('ProtocolRunner:UnknownNode', ...
                        'Unknown node kind: %s', node.kind);
            end
        end

        % --- leaf execution (flow control path) --------------------------

        function timing = executeFlowCondition(self, name)
            % Run all commands of a named condition and record timestamps.
            % Returns a timing struct for the calling control method.
            commands = self.protocolData.conditionsMap(name);

            self.logger.log('INFO', sprintf('--- Running condition: %s ---', name));
            fprintf('  > %s\n', name);

            monitorName = self.firstMonitor();
            if ~isempty(monitorName)
                t_start = self.pluginManager.executePluginCommand( ...
                    monitorName, 'getTime');
            else
                t_start = NaN;
            end

            for i = 1:numel(commands)
                self.commandExecutor.execute(commands{i});
            end

            if ~isempty(monitorName)
                t_end = self.pluginManager.executePluginCommand( ...
                    monitorName, 'getTime');
            else
                t_end = NaN;
            end

            timing = struct('t_start', t_start, 't_end', t_end);

            self.addTraceRecord(struct( ...
                'type',          'condition', ...
                'step_name',     name, ...
                'trial_start_t', t_start, ...
                'trial_end_t',   t_end));
        end

        % --- trial_check -------------------------------------------------

        function runTrialCheck(self, node)
            tc = struct( ...
                'criterion',    node.criterion, ...
                'monitor',      node.monitor, ...
                'on_fail_run',  node.on_fail_run, ...
                'max_attempts', node.max_attempts, ...
                'on_exhausted', node.on_exhausted);
            self.runTrialCheckLogic(node.trial, tc);
        end

        function runTrialCheckLogic(self, conditionName, tc)
            % Shared trial_check logic used by standalone trial_check
            % nodes, block-level checks, and repeat_until with per-trial
            % checks.

            fprintf('\n[TRIAL_CHECK] "%s" (metric: %s, max %d attempts)\n', ...
                conditionName, tc.criterion.metric, tc.max_attempts);

            if strcmp(tc.on_exhausted, 'abort')
                invalidReason = 'technical';
            else
                invalidReason = 'biological';
            end

            attempt  = 1;
            resolved = false;

            while ~resolved
                fprintf('  attempt %d/%d:\n', attempt, tc.max_attempts);
                self.logger.log('INFO', sprintf( ...
                    'trial_check "%s" attempt %d', conditionName, attempt));

                timing = self.executeFlowCondition(conditionName);

                window = self.getMonitorWindow(tc.monitor, ...
                    timing.t_start, timing.t_end);

                baselineVal = self.getBaseline(tc.criterion, tc.monitor);
                evalResult  = CriterionEvaluator.evaluate( ...
                    window, tc.criterion, baselineVal);

                % Handle abort from evaluator
                if evalResult.abort
                    self.logger.log('ERROR', sprintf( ...
                        'trial_check "%s": criterion evaluation aborted: %s', ...
                        conditionName, evalResult.abort_reason));
                    self.addTraceRecord(struct( ...
                        'type',          'trial_check_result', ...
                        'step_name',     conditionName, ...
                        'exit',          'abort', ...
                        'total_attempts', attempt, ...
                        'abort_reason',  evalResult.abort_reason));
                    error('ProtocolRunner:CriterionAbort', ...
                        'trial_check "%s": %s', ...
                        conditionName, evalResult.abort_reason);
                end

                trialPassed = ~evalResult.fired;

                self.addTraceRecord(struct( ...
                    'type',                'trial_check_attempt', ...
                    'step_name',           conditionName, ...
                    'parent_step',         conditionName, ...
                    'attempt',             attempt, ...
                    'attempt_of',          tc.max_attempts, ...
                    'valid',               trialPassed, ...
                    'invalid_reason',      ternaryStr(trialPassed, '', invalidReason), ...
                    'criterion_value',     evalResult.statistic_value, ...
                    'effective_threshold', evalResult.effective_threshold, ...
                    'mode',                evalResult.mode, ...
                    'valid_count',         evalResult.valid_count, ...
                    'total_count',         evalResult.total_count, ...
                    'result',              ternaryStr(trialPassed, 'pass', 'fail'), ...
                    'recovery_run',        tc.on_fail_run, ...
                    'trial_start_t',       timing.t_start, ...
                    'trial_end_t',         timing.t_end));

                if trialPassed
                    fprintf('  -> trial valid (value=%.3f, threshold=%.3f), advancing\n', ...
                        evalResult.statistic_value, evalResult.effective_threshold);
                    self.logger.log('INFO', sprintf( ...
                        'trial_check "%s" passed on attempt %d', ...
                        conditionName, attempt));
                    self.addTraceRecord(struct( ...
                        'type',          'trial_check_result', ...
                        'step_name',     conditionName, ...
                        'exit',          'pass', ...
                        'total_attempts', attempt));
                    resolved = true;

                elseif attempt >= tc.max_attempts
                    fprintf('  -> max attempts reached; on_exhausted = %s\n', ...
                        tc.on_exhausted);
                    self.logger.log('WARNING', sprintf( ...
                        'trial_check "%s" exhausted after %d attempts', ...
                        conditionName, attempt));
                    self.addTraceRecord(struct( ...
                        'type',          'trial_check_result', ...
                        'step_name',     conditionName, ...
                        'exit',          sprintf('exhausted_%s', tc.on_exhausted), ...
                        'total_attempts', attempt));
                    if strcmp(tc.on_exhausted, 'abort')
                        error('ProtocolRunner:TrialCheckExhausted', ...
                            'trial_check for "%s" failed after %d attempts — aborting', ...
                            conditionName, attempt);
                    end
                    resolved = true;

                else
                    fprintf('  -> trial invalid (value=%.3f, threshold=%.3f)', ...
                        evalResult.statistic_value, evalResult.effective_threshold);
                    if ~isempty(tc.on_fail_run)
                        fprintf('; running "%s"', tc.on_fail_run);
                        self.executeFlowCondition(tc.on_fail_run);
                    end
                    fprintf('\n');
                    attempt = attempt + 1;
                end
            end
        end

        % --- repeat_until ------------------------------------------------

        function runRepeatUntil(self, node)
            fprintf('\n[REPEAT_UNTIL] block "%s" (min %d, max %d repeats)\n', ...
                node.name, node.min_repeats, node.max_repeats);

            hasTrialCheck = isfield(node, 'trial_check') && ~isempty(node.trial_check);
            rep  = 1;
            stop = false;

            while ~stop
                fprintf('  repetition %d/%d:\n', rep, node.max_repeats);
                self.logger.log('INFO', sprintf( ...
                    'Block "%s" repetition %d', node.name, rep));

                repStartT = self.getMonitorTime(node.monitor);

                order = 1:numel(node.trials);
                if node.randomize
                    order = order(randperm(numel(order)));
                end
                for k = order
                    if hasTrialCheck
                        self.runTrialCheckLogic(node.trials{k}, node.trial_check);
                    else
                        self.executeFlowCondition(node.trials{k});
                    end
                end

                repEndT = self.getMonitorTime(node.monitor);

                % Evaluate criterion only after min_repeats
                if rep < node.min_repeats
                    fprintf('  -> below min_repeats (%d), continuing\n', ...
                        node.min_repeats);
                    self.addTraceRecord(struct( ...
                        'type',             'repeat_until_repetition', ...
                        'step_name',        node.name, ...
                        'repetition',       rep, ...
                        'max_repeats',      node.max_repeats, ...
                        'criterion_active', false, ...
                        'result',           'continue'));
                    rep = rep + 1;
                    continue;
                end

                window      = self.getMonitorWindow(node.monitor, repStartT, repEndT);
                baselineVal = self.getBaseline(node.criterion, node.monitor);

                % Baseline not yet available -> criterion inactive
                if isfield(node.criterion, 'baseline') && isempty(baselineVal)
                    fprintf('  -> baseline not yet available, continuing\n');
                    self.addTraceRecord(struct( ...
                        'type',             'repeat_until_repetition', ...
                        'step_name',        node.name, ...
                        'repetition',       rep, ...
                        'max_repeats',      node.max_repeats, ...
                        'criterion_active', false, ...
                        'result',           'continue'));
                    rep = rep + 1;
                    if rep > node.max_repeats
                        stop = true;
                    end
                    continue;
                end

                evalResult = CriterionEvaluator.evaluate( ...
                    window, node.criterion, baselineVal);

                if evalResult.abort
                    self.logger.log('ERROR', sprintf( ...
                        'repeat_until "%s": criterion evaluation aborted: %s', ...
                        node.name, evalResult.abort_reason));
                    error('ProtocolRunner:CriterionAbort', ...
                        'repeat_until "%s": %s', ...
                        node.name, evalResult.abort_reason);
                end

                criterionMet = evalResult.fired;

                self.addTraceRecord(struct( ...
                    'type',                'repeat_until_repetition', ...
                    'step_name',           node.name, ...
                    'repetition',          rep, ...
                    'max_repeats',         node.max_repeats, ...
                    'criterion_active',    true, ...
                    'criterion_value',     evalResult.statistic_value, ...
                    'effective_threshold', evalResult.effective_threshold, ...
                    'mode',                evalResult.mode, ...
                    'valid_count',         evalResult.valid_count, ...
                    'total_count',         evalResult.total_count, ...
                    'result',              ternaryStr(criterionMet, 'criterion_met', 'continue')));

                if criterionMet
                    fprintf('  -> criterion met after %d repetition(s) (value=%.3f, threshold=%.3f)\n', ...
                        rep, evalResult.statistic_value, evalResult.effective_threshold);
                    self.logger.log('INFO', sprintf( ...
                        'repeat_until "%s": criterion met after %d repetitions', ...
                        node.name, rep));
                    stop = true;

                elseif rep >= node.max_repeats
                    fprintf('  -> max repeats reached (%d)\n', node.max_repeats);
                    self.logger.log('INFO', sprintf( ...
                        'repeat_until "%s": max repeats reached (%d)', ...
                        node.name, node.max_repeats));
                    self.executedTrace{end}.result = 'max_reached';
                    stop = true;

                else
                    fprintf('  -> criterion not met (value=%.3f, threshold=%.3f), continuing\n', ...
                        evalResult.statistic_value, evalResult.effective_threshold);
                    rep = rep + 1;
                end
            end
        end

        % --- static block (flow control path) ----------------------------

        function runStaticFlowBlock(self, node)
            fprintf('\n[BLOCK] "%s" (%d repetition(s), randomize=%d)\n', ...
                node.name, node.repetitions, node.randomize);

            hasTrialCheck = ~isempty(node.trial_check);

            for rep = 1:node.repetitions
                order = 1:numel(node.trials);
                if node.randomize
                    order = order(randperm(numel(order)));
                end
                for k = order
                    if hasTrialCheck
                        self.runTrialCheckLogic(node.trials{k}, node.trial_check);
                    else
                        self.executeFlowCondition(node.trials{k});
                    end
                end
            end
        end

    end

    % =========================================================================
    %  PRIVATE — FLOW CONTROL HELPERS
    % =========================================================================
    methods (Access = private)

        function t = getMonitorTime(self, monitorName)
            t = self.pluginManager.executePluginCommand( ...
                monitorName, 'getTime');
        end

        function window = getMonitorWindow(self, monitorName, t_start, t_end)
            params = struct('t_start', t_start, 't_end', t_end);
            window = self.pluginManager.executePluginCommand( ...
                monitorName, 'getDataForInterval', params);
        end

        function val = getBaseline(self, criterion, monitorName)
            if ~isfield(criterion, 'baseline') || isempty(criterion.baseline)
                val = [];
                return;
            end

            metricName = char(criterion.metric);

            if self.baselineValues.isKey(metricName)
                val = self.baselineValues(metricName);
                return;
            end

            bl = criterion.baseline;
            if strcmp(char(bl.units), 'minutes')
                windowEnd = bl.window(2) * 60;
            else
                windowEnd = bl.window(2);
            end

            currentTime = self.getMonitorTime(monitorName);
            if currentTime < windowEnd
                val = [];
                self.logger.log('INFO', sprintf( ...
                    'Baseline for "%s" not yet available (%.1f s elapsed, need %.1f s)', ...
                    metricName, currentTime, windowEnd));
                return;
            end

            if strcmp(char(bl.units), 'minutes')
                blStart = bl.window(1) * 60;
                blEnd   = bl.window(2) * 60;
            else
                blStart = bl.window(1);
                blEnd   = bl.window(2);
            end

            blWindow = self.getMonitorWindow(monitorName, blStart, blEnd);

            if isempty(blWindow.values)
                self.logger.log('WARNING', sprintf( ...
                    'Baseline window for "%s" contains no samples', metricName));
                val = [];
                return;
            end

            val = mean(blWindow.values(~isnan(blWindow.values)));
            self.baselineValues(metricName) = val;

            self.logger.log('INFO', sprintf( ...
                'Baseline for "%s" computed: %.3f (from %.1f to %.1f s, %d samples)', ...
                metricName, val, blStart, blEnd, numel(blWindow.values)));
            fprintf('  [baseline] %s = %.3f (%.0f–%.0f s)\n', ...
                metricName, val, blStart, blEnd);
        end

        function name = firstMonitor(self)
            keys = self.protocolData.metricMap.keys();
            if isempty(keys)
                name = '';
            else
                name = self.protocolData.metricMap(keys{1});
            end
        end

        function addTraceRecord(self, record)
            self.executedTrace{end + 1} = record;
        end

        function writeFlowControlTraceSummary(self)
            summaryFile = fullfile(self.experimentDir, 'executed_trace.txt');
            fid = fopen(summaryFile, 'w');
            fprintf(fid, 'EXECUTED TRACE\n');
            fprintf(fid, '==============\n\n');
            fprintf(fid, 'Experiment : %s\n', self.protocolData.experimentInfo.name);
            fprintf(fid, 'Date       : %s\n\n', datestr(now));

            for i = 1:numel(self.executedTrace)
                r = self.executedTrace{i};
                switch r.type
                    case 'condition'
                        fprintf(fid, '  %3d. [condition] %s (%.2f–%.2f s)\n', ...
                            i, r.step_name, r.trial_start_t, r.trial_end_t);

                    case 'trial_check_attempt'
                        validStr = ternaryStr(r.valid, 'VALID', ...
                            sprintf('INVALID (%s)', r.invalid_reason));
                        fprintf(fid, '  %3d. [trial_check attempt %d/%d] %s — %s (value=%.3f, threshold=%.3f)\n', ...
                            i, r.attempt, r.attempt_of, r.step_name, ...
                            validStr, r.criterion_value, r.effective_threshold);

                    case 'trial_check_result'
                        fprintf(fid, '  %3d. [trial_check result] %s — %s (%d attempt(s))\n', ...
                            i, r.step_name, r.exit, r.total_attempts);

                    case 'repeat_until_repetition'
                        if r.criterion_active
                            fprintf(fid, '  %3d. [repeat_until rep %d/%d] %s — %s (value=%.3f, threshold=%.3f)\n', ...
                                i, r.repetition, r.max_repeats, r.step_name, ...
                                r.result, r.criterion_value, r.effective_threshold);
                        else
                            fprintf(fid, '  %3d. [repeat_until rep %d/%d] %s — %s (criterion inactive)\n', ...
                                i, r.repetition, r.max_repeats, r.step_name, r.result);
                        end

                    otherwise
                        fprintf(fid, '  %3d. [%s] %s\n', i, r.type, r.step_name);
                end
            end

            fclose(fid);
            self.logger.log('INFO', sprintf('Executed trace saved: %s', summaryFile));

            % Print to console
            fprintf('\n--- Executed trace (%d entries) ---\n', numel(self.executedTrace));
            fid2 = fopen(summaryFile, 'r');
            while ~feof(fid2)
                line = fgetl(fid2);
                if ischar(line)
                    fprintf('%s\n', line);
                end
            end
            fclose(fid2);
        end

    end

    % =========================================================================
    %  PRIVATE — FINALIZATION
    % =========================================================================
    methods (Access = private)

        function finalizeExperiment(self)
            % Save execution record and summary, then clean shutdown

            self.logger.log('INFO', 'Finalizing experiment...');

            dataDir = fullfile(self.experimentDir, 'data');
            if ~exist(dataDir, 'dir')
                mkdir(dataDir);
            end

            if self.protocolData.hasFlowControl
                % Flow-control protocol: save both planned and actual

                % Planned sequence (the program of nodes as parsed)
                experimentSteps = self.protocolData.program; %#ok<NASGU>
                conditionsMap   = self.protocolData.conditionsMap; %#ok<NASGU>
                experimentInfo  = self.protocolData.experimentInfo; %#ok<NASGU>
                save(fullfile(dataDir, 'experiment_steps.mat'), ...
                    'experimentSteps', 'conditionsMap', 'experimentInfo');

                % Executed trace (what actually ran)
                executedTrace = self.executedTrace; %#ok<NASGU>
                save(fullfile(dataDir, 'executed_trace.mat'), 'executedTrace');

                self.writeFlowControlTraceSummary();
            else
                % Standard protocol: save step IDs as before
                seq     = self.protocolData.commandSequence;
                stepIds = cellfun(@(s) s.id, seq, 'UniformOutput', false); %#ok<NASGU>
                save(fullfile(dataDir, 'experiment_steps.mat'), 'stepIds');
            end

            self.generateExperimentSummary();
            self.cleanup();
        end

        function generateExperimentSummary(self)
            % Write a human-readable summary file to the experiment directory

            summaryFile = fullfile(self.experimentDir, 'summary.txt');
            fid = fopen(summaryFile, 'w');

            fprintf(fid, 'EXPERIMENT SUMMARY\n');
            fprintf(fid, '==================\n\n');
            fprintf(fid, 'Experiment : %s\n', self.protocolData.experimentInfo.name);
            fprintf(fid, 'Date       : %s\n', datestr(now));
            fprintf(fid, 'Protocol   : %s\n\n', self.protocolFilePath);

            fprintf(fid, 'Arena Configuration:\n');
            fprintf(fid, '  Generation : %s\n', self.protocolData.arenaConfig.generation);
            fprintf(fid, '  Dimensions : %dx%d panels\n', ...
                self.protocolData.arenaConfig.num_rows, ...
                self.protocolData.arenaConfig.num_cols);
            fprintf(fid, '\n');

            % Variables
            varNames = fieldnames(self.protocolData.variables);
            if ~isempty(varNames)
                fprintf(fid, 'Variables:\n');
                for i = 1:length(varNames)
                    val = self.protocolData.variables.(varNames{i});
                    if isnumeric(val)
                        fprintf(fid, '  %-24s = %g\n', varNames{i}, val);
                    else
                        fprintf(fid, '  %-24s = "%s"\n', varNames{i}, val);
                    end
                end
                fprintf(fid, '\n');
            end

            % Execution steps
            if self.protocolData.hasFlowControl
                program = self.protocolData.program;
                fprintf(fid, 'Program (%d nodes, flow control):\n', numel(program));
                for i = 1:numel(program)
                    node = program{i};
                    if isfield(node, 'trial')
                        fprintf(fid, '  %3d. [%s] %s\n', i, node.kind, node.trial);
                    elseif isfield(node, 'name')
                        fprintf(fid, '  %3d. [%s] %s\n', i, node.kind, node.name);
                    else
                        fprintf(fid, '  %3d. [%s]\n', i, node.kind);
                    end
                end
            else
                seq = self.protocolData.commandSequence;
                fprintf(fid, 'Execution sequence (%d steps):\n', length(seq));
                for i = 1:length(seq)
                    fprintf(fid, '  %3d. %s\n', i, seq{i}.id);
                end
            end

            fclose(fid);

            self.logger.log('INFO', sprintf('Summary saved: %s', summaryFile));
        end

    end
end

% =========================================================================
%  LOCAL HELPER (outside classdef — MATLAB requires this at file scope)
% =========================================================================
function s = ternaryStr(cond, a, b)
    if cond, s = a; else, s = b; end
end

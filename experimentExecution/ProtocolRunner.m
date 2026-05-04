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
            %   2. Execute every step in the command sequence in order
            %   3. Finalize (save summary, clean shutdown)

            try
                self.initializeExperiment();

                if self.dryRun
                    self.logger.log('INFO', 'Dry run complete — protocol is valid');
                    self.cleanup();
                    return;
                end

                self.executeCommandSequence();
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

            % Copy the protocol YAML
            [~, yamlName, yamlExt] = fileparts(self.protocolFilePath);
            destYaml = fullfile(self.experimentDir, [yamlName yamlExt]);
            try
                copyfile(self.protocolFilePath, destYaml);
                self.logger.log('INFO', sprintf('Archived protocol YAML: %s', destYaml));
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
                    self.arenaController = PanelsController(self.arenaIP);
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

        function finalizeExperiment(self)
            % Save execution record and summary, then clean shutdown

            self.logger.log('INFO', 'Finalizing experiment...');

            % Save a record of the step IDs that were executed, in order
            dataDir = fullfile(self.experimentDir, 'data');
            if ~exist(dataDir, 'dir')
                mkdir(dataDir);
            end

            seq       = self.protocolData.commandSequence;
            stepIds   = cellfun(@(s) s.id, seq, 'UniformOutput', false);
            save(fullfile(dataDir, 'experiment_steps.mat'), 'stepIds');

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
            seq = self.protocolData.commandSequence;
            fprintf(fid, 'Execution sequence (%d steps):\n', length(seq));
            for i = 1:length(seq)
                fprintf(fid, '  %3d. %s\n', i, seq{i}.id);
            end

            fclose(fid);

            self.logger.log('INFO', sprintf('Summary saved: %s', summaryFile));
        end

    end
end

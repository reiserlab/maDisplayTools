classdef ProtocolRunner < handle
    % PROTOCOLRUNNER Main orchestrator for experiment execution
    %
    % This class manages the complete lifecycle of an experiment:
    % - Parsing and validating the protocol file
    % - Initializing hardware and plugins
    % - Executing pretrial, trials, intertrial, and posttrial phases
    % - Logging and data management
    % - Cleanup and error handling
    
    properties (Access = private)
        protocolFilePath        % Path to YAML protocol file
        protocolData            % Parsed protocol structure
        pluginManager           % PluginManager instance
        arenaController         % Arena hardware controller
        commandExecutor         % CommandExecutor instance
        parser                  % ProtocolParser instance
        logger                  % ExperimentLogger instance
        patternIDMap            % containers.Map: pattern path -> ID
        trialExecutionOrder     % Array of trial metadata structs
        outputDir               % Base output directory
        experimentDir           % Specific experiment directory (timestamped)
        verbose                 % Verbose logging flag
        dryRun                  % Dry run mode (validate only)
    end
    
    methods (Access = public)
        function self = ProtocolRunner(protocolFilePath, varargin)
            % PROTOCOLRUNNER Constructor
            %
            % Syntax:
            %   runner = ProtocolRunner(protocolFilePath)
            %   runner = ProtocolRunner(protocolFilePath, Name, Value)
            %
            % Input Arguments:
            %   protocolFilePath - Path to YAML protocol file
            %
            % Name-Value Pairs:
            %   'OutputDir' - Base output directory (default: './experiments')
            %   'Verbose' - Enable verbose logging (default: true)
            %   'DryRun' - Validate without executing (default: false)
            
            % Parse inputs
            p = inputParser;
            addRequired(p, 'protocolFilePath', @ischar);
            addParameter(p, 'OutputDir', './experiments', @ischar);
            addParameter(p, 'Verbose', true, @islogical);
            addParameter(p, 'DryRun', false, @islogical);
            parse(p, protocolFilePath, varargin{:});
            
            % Store configuration
            self.protocolFilePath = p.Results.protocolFilePath;
            self.outputDir = p.Results.OutputDir;
            self.verbose = p.Results.Verbose;
            self.dryRun = p.Results.DryRun;
            
            % Initialize (validation only at construction)
            self.validateEnvironment();
            self.parseProtocol();
            self.validateProtocolStructure();
            self.extractPatternMapping();
        end
        
        function run(self)
            % RUN Execute the complete experiment protocol
            %
            % Execution flow:
            %   1. Initialize experiment (hardware, plugins, logging)
            %   2. Generate trial order
            %   3. Execute pretrial phase
            %   4. Execute main trial loop
            %   5. Execute posttrial phase
            %   6. Cleanup and save data
            
            try
                % === Initialization ===
                self.initializeExperiment();
                
                % If dry run, stop here
                if self.dryRun
                    self.logger.log('INFO', 'Dry run complete - protocol is valid');
                    self.cleanup();
                    return;
                end
                
                % === Generate Trial Order ===
                self.generateTrialOrder();
                
                % === Execute Pretrial ===
                self.executePretrialPhase();
                
                % === Execute Main Trials ===
                self.executeMainTrialLoop();
                
                % === Execute Posttrial ===
                self.executePosttrialPhase();
                
                % === Finalize ===
                self.finalizeExperiment();
                
            catch ME
                self.logger.log('ERROR', sprintf('Experiment failed: %s', ME.message));
                self.cleanup();
                rethrow(ME);
            end
        end
        
        function cleanup(self)
            % CLEANUP Emergency cleanup of all resources
            %
            % Called on error or at end of experiment
            
            fprintf('Performing cleanup...\n');
            
            % Stop arena hardware
            if ~isempty(self.arenaController)
                try
                    % TODO: Call arena all_off or stop methods
                    fprintf('  - Stopping arena hardware\n');
                catch ME
                    fprintf(2, '  - Warning: Could not stop arena: %s\n', ME.message);
                end
            end
            
            % Close all plugins
            if ~isempty(self.pluginManager)
                try
                    self.pluginManager.closeAll();
                    fprintf('  - Closed all plugins\n');
                catch ME
                    fprintf(2, '  - Warning: Could not close plugins: %s\n', ME.message);
                end
            end
            
            % Close logger
            if ~isempty(self.logger)
                try
                    self.logger.close();
                    fprintf('  - Closed log file\n');
                catch ME
                    fprintf(2, '  - Warning: Could not close logger: %s\n', ME.message);
                end
            end
            
            fprintf('Cleanup complete.\n');
        end
    end
    
    methods (Access = private)
        %% ================= Section 1: Initialization =================
        
        function validateEnvironment(self)
            % VALIDATEENVIRONMENT Check MATLAB version and toolboxes
            
            % Check MATLAB version
            v = ver('MATLAB');
            if str2double(v.Version) < 9.0  % R2016a
                warning('MATLAB version %s may not be fully supported', v.Version);
            end
            
            % Check for YAML parser (needs yamlmatlab or similar)
            % TODO: Add check for YAML parsing capability
            
            if self.verbose
                fprintf('Environment validation passed\n');
            end
        end
        
        function parseProtocol(self)
            % PARSEPROTOCOL Load and parse YAML protocol file
            
            if self.verbose
                fprintf('Parsing protocol: %s\n', self.protocolFilePath);
            end
            self.parser = ProtocolParser('verbose', false);
            protocol = self.parser.parse(self.protocolFilePath);
            
            % TODO: Parse YAML file
            % This requires a YAML parser (e.g., yamlmatlab from File Exchange)
            % For now, placeholder:
            try
                % self.protocolData = yaml.ReadYaml(self.protocolFilePath);
                % OR
                % self.protocolData = ReadYaml(self.protocolFilePath);
                
                % Placeholder - replace with actual YAML parsing
                error('YAML parsing not yet implemented - add YAML parser');
                
            catch ME
                error('Failed to parse protocol file: %s', ME.message);
            end
        end
        
        function validateProtocolStructure(self)
            % VALIDATEPROTOCOLSTRUCTURE Check protocol has all required fields
            
            if self.verbose
                fprintf('Validating protocol structure...\n');
            end
            
            % Check version
            if ~isfield(self.protocolData, 'version') || self.protocolData.version ~= 1
                error('Protocol must specify version: 1');
            end
            
            % Check required sections
            requiredFields = {'experiment_info', 'arena_info', 'experiment_structure', 'block'};
            for i = 1:length(requiredFields)
                if ~isfield(self.protocolData, requiredFields{i})
                    error('Protocol missing required section: %s', requiredFields{i});
                end
            end
            
            % Validate arena_info
            arenaFields = {'num_rows', 'num_cols', 'generation'};
            for i = 1:length(arenaFields)
                if ~isfield(self.protocolData.arena_info, arenaFields{i})
                    error('arena_info missing required field: %s', arenaFields{i});
                end
            end
            
            % Validate block has conditions
            if ~isfield(self.protocolData.block, 'conditions') || ...
               isempty(self.protocolData.block.conditions)
                error('Protocol must define at least one condition in block');
            end
            
            % TODO: Add more validation
            % - Check condition IDs are unique
            % - Check plugin IDs are unique if plugins exist
            % - Validate command structures
            
            if self.verbose
                fprintf('  ✓ Protocol structure is valid\n');
            end
        end
        
        function extractPatternMapping(self)
            % EXTRACTPATTERNMAPPING Extract pattern path -> ID mapping
            
            self.patternIDMap = containers.Map();
            
            if isfield(self.protocolData, 'pattern_mapping')
                if self.verbose
                    fprintf('Extracting pattern ID mapping...\n');
                end
                
                % Convert pattern_mapping struct to containers.Map
                mapping = self.protocolData.pattern_mapping;
                paths = fieldnames(mapping);
                
                for i = 1:length(paths)
                    path = paths{i};
                    id = mapping.(path);
                    self.patternIDMap(path) = id;
                    
                    if self.verbose
                        fprintf('  Pattern ID %d: %s\n', id, path);
                    end
                end
                
                if self.verbose
                    fprintf('  ✓ Loaded %d pattern mappings\n', self.patternIDMap.Count);
                end
            else
                warning('No pattern_mapping found in protocol');
            end
        end
        
        function initializeExperiment(self)
            % Initialize all components for execution
            
            fprintf('\n=== Initializing Experiment ===\n');
            
            % Create experiment directory
            self.createExperimentDirectory();
            
            % Initialize logger
            self.initializeLogger();
            
            % Log experiment start
            self.logger.log('INFO', '=== EXPERIMENT START ===');
            self.logger.log('INFO', sprintf('Protocol: %s', self.protocolFilePath));
            self.logger.log('INFO', sprintf('Output: %s', self.experimentDir));
            
            % Initialize plugins
            self.initializePlugins();
            
            % Initialize arena hardware
            self.initializeArenaHardware();
            
            % Create command executor
            self.commandExecutor = CommandExecutor(...
                self.arenaController, ...
                self.pluginManager, ...
                self.patternIDMap, ...
                self.logger);
            
            self.logger.log('INFO', 'Initialization complete');
            fprintf('=== Initialization Complete ===\n\n');
        end
        
        function createExperimentDirectory(self)
            % Create timestamped output directory
            
            % Create timestamped directory name
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            expName = self.protocolData.experiment_info.name;
            expName = strrep(expName, ' ', '_');  % Replace spaces
            dirName = sprintf('%s_%s', timestamp, expName);
            
            self.experimentDir = fullfile(self.outputDir, dirName);
            
            % Create directories
            if ~exist(self.experimentDir, 'dir')
                mkdir(self.experimentDir);
            end
            mkdir(fullfile(self.experimentDir, 'data'));
            mkdir(fullfile(self.experimentDir, 'logs'));
            
            if self.verbose
                fprintf('Created experiment directory: %s\n', self.experimentDir);
            end
            
            % Copy protocol file to experiment directory
            [~, filename, ext] = fileparts(self.protocolFilePath);
            copyfile(self.protocolFilePath, ...
                    fullfile(self.experimentDir, [filename ext]));
        end
        
        function initializeLogger(self)
            % INITIALIZELOGGER Create experiment logger
            
            logFile = fullfile(self.experimentDir, 'logs', 'experiment.log');
            self.logger = ExperimentLogger(logFile, self.verbose);
        end
        
        function initializePlugins(self)
            % INITIALIZEPLUGINS Initialize all plugins defined in protocol
            
            if ~isfield(self.protocolData, 'plugins')
                self.logger.log('INFO', 'No plugins defined in protocol');
                self.pluginManager = PluginManager(self.logger);
                return;
            end
            
            self.logger.log('INFO', 'Initializing plugins...');
            self.pluginManager = PluginManager(self.logger);
            
            plugins = self.protocolData.plugins;
            for i = 1:length(plugins)
                pluginDef = plugins(i);
                
                try
                    self.pluginManager.initializePlugin(pluginDef);
                    self.logger.log('INFO', sprintf('  ✓ Initialized plugin: %s', ...
                                                  pluginDef.id));
                catch ME
                    self.logger.log('ERROR', sprintf('  ✗ Failed to initialize plugin %s: %s', ...
                                                   pluginDef.id, ME.message));
                    error('Plugin initialization failed');
                end
            end
            
            self.logger.log('INFO', sprintf('All %d plugins initialized', length(plugins)));
        end
        
        function initializeArenaHardware(self)
            % INITIALIZEARENAHARDWARE Connect to and configure arena
            
            self.logger.log('INFO', 'Initializing arena hardware...');
            
            generation = self.protocolData.arena_info.generation;
            numRows = self.protocolData.arena_info.num_rows;
            numCols = self.protocolData.arena_info.num_cols;
            
            % TODO: Initialize appropriate controller based on generation
            % For now, placeholder for G4.1
            if strcmp(generation, 'G4') || strcmp(generation, 'G4.1')
                % self.arenaController = G4Controller();  % Create actual controller
                % self.arenaController.connect();
                % self.arenaController.configure(numRows, numCols);
                
                self.logger.log('INFO', sprintf('  Arena: %s (%dx%d panels)', ...
                                              generation, numRows, numCols));
                self.logger.log('WARNING', 'Arena controller not yet implemented');
            else
                error('Unsupported arena generation: %s', generation);
            end
        end
        
        %% ================= Section 2: Trial Order Generation =================
        
        function generateTrialOrder(self)
            % GENERATETRIALORDER Create trial execution sequence
            
            self.logger.log('INFO', 'Generating trial order...');
            
            % Extract configuration
            conditions = self.protocolData.block.conditions;
            reps = self.protocolData.experiment_structure.repetitions;
            
            % Get randomization settings
            if isfield(self.protocolData.experiment_structure, 'randomization')
                randSettings = self.protocolData.experiment_structure.randomization;
            else
                % Backward compatibility with old format
                randSettings.enabled = self.protocolData.experiment_structure.randomize;
                randSettings.seed = [];
                randSettings.method = 'block';
            end
            
            % Create base condition list
            numConditions = length(conditions);
            conditionIDs = cell(1, numConditions);
            for i = 1:numConditions
                conditionIDs{i} = conditions(i).id;
            end
            
            % Replicate for repetitions
            totalTrials = numConditions * reps;
            self.trialExecutionOrder = struct('trialNumber', {}, ...
                                            'conditionID', {}, ...
                                            'repetition', {}, ...
                                            'blockNumber', {});
            
            trialCounter = 0;
            
            if randSettings.enabled
                % Set random seed if specified
                if ~isempty(randSettings.seed) && ~isnan(randSettings.seed)
                    rng(randSettings.seed);
                    self.logger.log('INFO', sprintf('  Using random seed: %d', randSettings.seed));
                else
                    seed = randi(1e6);
                    rng(seed);
                    self.logger.log('INFO', sprintf('  Generated random seed: %d', seed));
                end
                
                if strcmp(randSettings.method, 'block')
                    % Block randomization: shuffle within each repetition
                    for rep = 1:reps
                        shuffledIndices = randperm(numConditions);
                        for i = 1:numConditions
                            trialCounter = trialCounter + 1;
                            self.trialExecutionOrder(trialCounter).trialNumber = trialCounter;
                            self.trialExecutionOrder(trialCounter).conditionID = ...
                                conditionIDs{shuffledIndices(i)};
                            self.trialExecutionOrder(trialCounter).repetition = rep;
                            self.trialExecutionOrder(trialCounter).blockNumber = rep;
                        end
                    end
                else  % 'trial' method
                    % Trial randomization: shuffle all trials together
                    allConditionIDs = repmat(conditionIDs, 1, reps);
                    allReps = repelem(1:reps, numConditions);
                    shuffledIndices = randperm(totalTrials);
                    
                    for i = 1:totalTrials
                        trialCounter = trialCounter + 1;
                        idx = shuffledIndices(i);
                        self.trialExecutionOrder(trialCounter).trialNumber = trialCounter;
                        self.trialExecutionOrder(trialCounter).conditionID = allConditionIDs{idx};
                        self.trialExecutionOrder(trialCounter).repetition = allReps(idx);
                        self.trialExecutionOrder(trialCounter).blockNumber = NaN;
                    end
                end
            else
                % No randomization: sequential order
                for rep = 1:reps
                    for i = 1:numConditions
                        trialCounter = trialCounter + 1;
                        self.trialExecutionOrder(trialCounter).trialNumber = trialCounter;
                        self.trialExecutionOrder(trialCounter).conditionID = conditionIDs{i};
                        self.trialExecutionOrder(trialCounter).repetition = rep;
                        self.trialExecutionOrder(trialCounter).blockNumber = rep;
                    end
                end
            end
            
            self.logger.log('INFO', sprintf('  Generated %d trials', totalTrials));
            self.logger.log('INFO', sprintf('  %d conditions × %d repetitions', ...
                                          numConditions, reps));
            
            % Log trial order for reproducibility
            self.logger.log('INFO', 'Trial execution order:');
            for i = 1:min(10, length(self.trialExecutionOrder))
                trial = self.trialExecutionOrder(i);
                self.logger.log('INFO', sprintf('    Trial %d: Condition %s (Rep %d)', ...
                                              trial.trialNumber, ...
                                              trial.conditionID, ...
                                              trial.repetition));
            end
            if length(self.trialExecutionOrder) > 10
                self.logger.log('INFO', sprintf('    ... (%d more trials)', ...
                                              length(self.trialExecutionOrder) - 10));
            end
        end
        
        %% ================= Section 3: Execution Phases =================
        
        function executePretrialPhase(self)
            % EXECUTEPRETRIALPHASE Execute pretrial commands
            
            if ~isfield(self.protocolData, 'pretrial') || ...
               ~self.protocolData.pretrial.include
                self.logger.log('INFO', 'No pretrial phase defined');
                return;
            end
            
            self.logger.log('INFO', '=== PRETRIAL PHASE START ===');
            fprintf('\n=== Executing Pretrial ===\n');
            
            pretrial = self.protocolData.pretrial;
            commands = pretrial.commands;
            
            for i = 1:length(commands)
                self.logger.log('INFO', sprintf('Executing pretrial command %d/%d', ...
                                              i, length(commands)));
                
                try
                    self.commandExecutor.execute(commands(i));
                catch ME
                    self.logger.log('ERROR', sprintf('Pretrial command %d failed: %s', ...
                                                   i, ME.message));
                    error('Pretrial phase failed');
                end
            end
            
            self.logger.log('INFO', '=== PRETRIAL PHASE COMPLETE ===');
            fprintf('=== Pretrial Complete ===\n\n');
        end
        
        function executeMainTrialLoop(self)
            % EXECUTEMAINTRIALLOOP Execute all experimental trials
            
            self.logger.log('INFO', '=== MAIN TRIAL LOOP START ===');
            fprintf('\n=== Starting Main Trials ===\n');
            
            numTrials = length(self.trialExecutionOrder);
            
            % Check if intertrial is defined
            hasIntertrial = isfield(self.protocolData, 'intertrial') && ...
                           self.protocolData.intertrial.include;
            
            for trialIdx = 1:numTrials
                % Get trial metadata
                trial = self.trialExecutionOrder(trialIdx);
                
                % Log trial start
                self.logger.log('INFO', sprintf('--- Trial %d/%d: Condition %s (Rep %d) ---', ...
                                              trial.trialNumber, numTrials, ...
                                              trial.conditionID, trial.repetition));
                fprintf('Trial %d/%d: %s\n', trial.trialNumber, numTrials, trial.conditionID);
                
                % Find condition definition
                conditionDef = self.findConditionByID(trial.conditionID);
                
                % Execute trial commands
                self.executeTrial(trial, conditionDef);
                
                % Execute intertrial (if not last trial and intertrial exists)
                if trialIdx < numTrials && hasIntertrial
                    self.executeIntertrialPhase();
                end
            end
            
            self.logger.log('INFO', '=== MAIN TRIAL LOOP COMPLETE ===');
            fprintf('\n=== All Trials Complete ===\n\n');
        end
        
        function conditionDef = findConditionByID(self, conditionID)
            % FINDCONDITIONBYID Find condition definition by ID
            
            conditions = self.protocolData.block.conditions;
            for i = 1:length(conditions)
                if strcmp(conditions(i).id, conditionID)
                    conditionDef = conditions(i);
                    return;
                end
            end
            error('Condition not found: %s', conditionID);
        end
        
        function executeTrial(self, trialMetadata, conditionDef)
            % EXECUTETRIAL Execute commands for a single trial
            
            startTime = tic;
            
            commands = conditionDef.commands;
            
            for i = 1:length(commands)
                try
                    self.commandExecutor.execute(commands(i));
                catch ME
                    self.logger.log('ERROR', sprintf('Trial %d command %d failed: %s', ...
                                                   trialMetadata.trialNumber, i, ME.message));
                    error('Trial execution failed');
                end
            end
            
            duration = toc(startTime);
            self.logger.log('INFO', sprintf('Trial %d completed in %.2f seconds', ...
                                          trialMetadata.trialNumber, duration));
        end
        
        function executeIntertrialPhase(self)
            % EXECUTEINTERTRIALPHASE Execute intertrial commands
            
            intertrial = self.protocolData.intertrial;
            commands = intertrial.commands;
            
            for i = 1:length(commands)
                try
                    self.commandExecutor.execute(commands(i));
                catch ME
                    self.logger.log('ERROR', sprintf('Intertrial command %d failed: %s', ...
                                                   i, ME.message));
                    error('Intertrial phase failed');
                end
            end
        end
        
        function executePosttrialPhase(self)
            % EXECUTEPOSTTRIALPHASE Execute posttrial commands
            
            if ~isfield(self.protocolData, 'posttrial') || ...
               ~self.protocolData.posttrial.include
                self.logger.log('INFO', 'No posttrial phase defined');
                return;
            end
            
            self.logger.log('INFO', '=== POSTTRIAL PHASE START ===');
            fprintf('\n=== Executing Posttrial ===\n');
            
            posttrial = self.protocolData.posttrial;
            commands = posttrial.commands;
            
            for i = 1:length(commands)
                self.logger.log('INFO', sprintf('Executing posttrial command %d/%d', ...
                                              i, length(commands)));
                
                try
                    self.commandExecutor.execute(commands(i));
                catch ME
                    self.logger.log('ERROR', sprintf('Posttrial command %d failed: %s', ...
                                                   i, ME.message));
                    % Don't fail experiment on posttrial error
                    fprintf(2, 'Warning: Posttrial command failed\n');
                end
            end
            
            self.logger.log('INFO', '=== POSTTRIAL PHASE COMPLETE ===');
            fprintf('=== Posttrial Complete ===\n\n');
        end
        
        function finalizeExperiment(self)
            % FINALIZEEXPERIMENT Save data and close resources
            
            self.logger.log('INFO', 'Finalizing experiment...');
            
            % Save trial execution order
            trialOrder = self.trialExecutionOrder;
            save(fullfile(self.experimentDir, 'data', 'trial_order.mat'), 'trialOrder');
            
            % TODO: Save any additional data collected during experiment
            
            % Generate summary
            self.generateExperimentSummary();
            
            % Clean shutdown
            self.cleanup();
            
            self.logger.log('INFO', '=== EXPERIMENT COMPLETE ===');
        end
        
        function generateExperimentSummary(self)
            % GENERATEEXPERIMENTSUMMARY Create experiment summary file
            
            summaryFile = fullfile(self.experimentDir, 'summary.txt');
            fid = fopen(summaryFile, 'w');
            
            fprintf(fid, 'EXPERIMENT SUMMARY\n');
            fprintf(fid, '==================\n\n');
            fprintf(fid, 'Experiment: %s\n', self.protocolData.experiment_info.name);
            fprintf(fid, 'Date: %s\n', datestr(now));
            fprintf(fid, 'Protocol: %s\n\n', self.protocolFilePath);
            
            fprintf(fid, 'Arena Configuration:\n');
            fprintf(fid, '  Generation: %s\n', self.protocolData.arena_info.generation);
            fprintf(fid, '  Dimensions: %dx%d panels\n', ...
                    self.protocolData.arena_info.num_rows, ...
                    self.protocolData.arena_info.num_cols);
            fprintf(fid, '\n');
            
            fprintf(fid, 'Experimental Design:\n');
            fprintf(fid, '  Conditions: %d\n', length(self.protocolData.block.conditions));
            fprintf(fid, '  Repetitions: %d\n', self.protocolData.experiment_structure.repetitions);
            fprintf(fid, '  Total Trials: %d\n', length(self.trialExecutionOrder));
            fprintf(fid, '\n');
            
            % TODO: Add more summary statistics
            
            fclose(fid);
            
            self.logger.log('INFO', sprintf('Summary saved to: %s', summaryFile));
        end
    end
end

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
        arenaIP
        protocolData            % Parsed protocol structure
        pluginManager           % PluginManager instance
        arenaController         % Arena hardware controller
        commandExecutor         % CommandExecutor instance
        parser                  % ProtocolParser instance
        logger                  % ExperimentLogger instance
        patternIDMap            % containers.Map: pattern path -> ID
        trialExecutionOrder     % Array of trial metadata structs
        outputDir               % Output directory - location where experiment folder is saved
        experimentDir           % Created automatically - yaml filename plus timestamp at run time
        verbose                 % Verbose logging flag
        dryRun                  % Dry run mode (validate only)
        startTime
    end
    
    methods (Access = public)
        function self = ProtocolRunner(protocolFilePath, arenaIP, varargin)
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
            %   'OutputDir' - Directory where experiment folder will be
            %   saved
            %   'Verbose' - Enable verbose logging (default: true)
            %   'DryRun' - Validate without executing (default: false)
            
            % Parse inputs
            p = inputParser;
            addRequired(p, 'protocolFilePath', @ischar);
            addRequired(p, 'arenaIP', @ischar);
            addParameter(p, 'OutputDir', './experiments', @ischar);
            addParameter(p, 'Verbose', true, @islogical);
            addParameter(p, 'DryRun', false, @islogical);
            parse(p, protocolFilePath, arenaIP, varargin{:});
            
            % Store configuration
            self.protocolFilePath = p.Results.protocolFilePath;
            self.startTime = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
            self.outputDir = p.Results.OutputDir;
            self.verbose = p.Results.Verbose;
            self.dryRun = p.Results.DryRun;
            self.arenaIP = p.Results.arenaIP;
            
            % get experiment folder
            self.getExperimentDir()
            
            % Initialize (validation only at construction)
            self.validateEnvironment();
            self.parseProtocol();

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
            % Emergency cleanup of all resources
            %
            % Called on error or at end of experiment
            
            fprintf('Performing cleanup...\n');
            
            % Stop arena hardware
            if ~isempty(self.arenaController)
                try
                    self.arenaController.stopDisplay();
                    self.arenaController.close();
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
            % Instantiate ProtocolParser to parse yaml file and return
            % experiment data. Resulting data is structured as follows: 
            % self.protocolData is a struct with the following fields: 
            %    - version: the yaml file version
            %    - experimentInfo: a struct with three fields, "name",
            %     "date_created", and "author" 
            %     - arenaConfig: struct with three fields, "num_rows",
            %     "num_cols", and "generation"
            %     - plugins: cell array of structs. Each struct has a
            %     "name" and "type" field plus additional fields depending
            %     on type. Possible types are "serial_device", "class", and
            %     "script"
            %     - experimentStructure: struct with two fields,
            %     "repetitions", and "randomization", which is another
            %     small struct
            %     - pretrialCommands: A cell array of commands, each a
            %     struct with type, name, and other type dependent fields
            %     - blockConditions: a
            %     struct array. So blockConditions(1) is a struct with two
            %     fields, "id", and "commands", a  cell array of structs
            %     - intertrialCommands: cell array of commands for
            %     intertrial
            %     - posttrialCommands: cell array of commands for posttrial
            %     - filepath: path to the yaml file
            
            if self.verbose
                fprintf('Parsing protocol: %s\n', self.protocolFilePath);
            end
            self.parser = ProtocolParser('verbose', self.verbose);

            try
                self.protocolData = self.parser.parse(self.protocolFilePath);
                
            catch ME
                error('Failed to parse protocol file: %s', ME.message);
            end
        end
        
        
        %function extractPatternMapping(self)
            % Extract pattern path -> ID mapping
            
        %     self.patternIDMap = containers.Map();
        % 
        %     if isfield(self.protocolData, 'pattern_mapping')
        %         if self.verbose
        %             fprintf('Extracting pattern ID mapping...\n');
        %         end
        % 
        %         % Convert pattern_mapping struct to containers.Map
        %         mapping = self.protocolData.pattern_mapping;
        %         paths = fieldnames(mapping);
        % 
        %         for i = 1:length(paths)
        %             path = paths{i};
        %             id = mapping.(path);
        %             self.patternIDMap(path) = id;
        % 
        %             if self.verbose
        %                 fprintf('  Pattern ID %d: %s\n', id, path);
        %             end
        %         end
        % 
        %         if self.verbose
        %             fprintf('  ✓ Loaded %d pattern mappings\n', self.patternIDMap.Count);
        %         end
        %     else
        %         warning('No pattern_mapping found in protocol');
        %     end
        % end
        
        function initializeExperiment(self)
            % Initialize all components for execution
            
            fprintf('\n=== Initializing Experiment ===\n');
           
            
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
                self.logger);
            
            self.logger.log('INFO', 'Initialization complete');
            fprintf('=== Initialization Complete ===\n\n');
        end
        
        
        function initializeLogger(self)
            % Create experiment logger with timestamped filename
            
            % Generate timestamp for current experiment run
            
            
            % Create log filename with timestamp
            logFilename = sprintf('experimentLog_%s.log', self.startTime);
            logFile = fullfile(self.experimentDir, 'logs', logFilename);
            self.logger = ExperimentLogger(logFile, self.verbose);
        end

        function getExperimentDir(self)
            % Experiment directory is outputDir/yamlFilename_startTime
            [~, yaml_filename, ~] = fileparts(self.protocolFilePath);
            experimentName = [yaml_filename '_' self.startTime];
            self.experimentDir = fullfile(self.outputDir, experimentName);

            if ~exist(self.experimentDir, 'dir')
                mkdir(self.experimentDir);
            end

        end
        
        function initializePlugins(self)
            % Initialize all plugins defined in protocol
            
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
                                                  pluginDef.name));
                catch ME
                    self.logger.log('ERROR', sprintf('  ✗ Failed to initialize plugin %s: %s', ...
                                                   pluginDef.name, ME.message));
                    error('Plugin initialization failed');
                end
            end
            
            self.logger.log('INFO', sprintf('All %d plugins initialized', length(plugins)));
        end
        
        function initializeArenaHardware(self)
            % Connect to and configure arena
            
            self.logger.log('INFO', 'Initializing arena hardware...');
            
            generation = self.protocolData.arenaConfig.generation;
            numRows = self.protocolData.arenaConfig.num_rows;
            numCols = self.protocolData.arenaConfig.num_cols;
            
            if strcmp(generation, 'G4.1')
                try
                    self.arenaController = PanelsController(self.arenaIP);  % Create actual controller   
                    self.arenaController.open(false);
                catch ME
                    self.logger.log('ERROR', sprintf(' call to create PanelsController object failed.'));
                    error('Call to create PanelsController object failed.');
                end
                % try                 
                %     self.arenaController.open(false);
                % catch ME
                %     self.logger.log('ERROR', sprintf(' attempt to open the controller failed.'));
                %     error('Call to open function in PanelsController failed.');
                % end
                % 
                self.logger.log('INFO', sprintf('  Arena: %s (%dx%d panels)', ...
                                              generation, numRows, numCols));
            else
                error('Unsupported arena generation: %s', generation);
            end
        end
        
        %% ================= Section 2: Trial Order Generation =================
        
        function generateTrialOrder(self)
            % Create trial execution sequence
            
            self.logger.log('INFO', 'Generating trial order...');
            
            % Extract configuration
            conditions = self.protocolData.blockConditions;
            reps = self.protocolData.experimentStructure.repetitions;
            
            % Get randomization settings
            randSettings.enabled = self.protocolData.experimentStructure.randomization.enabled;
            randSettings.seed = self.protocolData.experimentStructure.randomization.seed;
            randSettings.method = self.protocolData.experimentStructure.randomization.method;
              
            % Create base condition list
            numConditions = length(conditions);
            conditionIDs = cell(1, numConditions);
            for i = 1:numConditions
                conditionIDs{i} = conditions(i).id;
            end
            
            % Replicate for repetitions
            totalTrials = ProtocolParser.get_total_trials(self.protocolData);
            totalConditionTrials = length(self.protocolData.blockConditions)*reps;
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
                    shuffledIndices = randperm(totalConditionTrials);
                    
                    for i = 1:totalConditionTrials
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
            % Execute pretrial commands
            
            if ~isfield(self.protocolData, 'pretrialCommands') || ...
               isempty(self.protocolData.pretrialCommands)
                self.logger.log('INFO', 'No pretrial phase defined');
                return;
            end
            
            self.logger.log('INFO', '=== PRETRIAL PHASE START ===');
            fprintf('\n=== Executing Pretrial ===\n');
            
            commands = self.protocolData.pretrialCommands;
            
            for i = 1:length(commands)
                self.logger.log('INFO', sprintf('Executing pretrial command %d/%d', ...
                                              i, length(commands)));
                
                try
                    self.commandExecutor.execute(commands{i});
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
            % Execute all experimental trials
            
            self.logger.log('INFO', '=== MAIN TRIAL LOOP START ===');
            fprintf('\n=== Starting Main Trials ===\n');
            
            numTrials = length(self.trialExecutionOrder);
            
            % Check if intertrial is defined
            hasIntertrial = isfield(self.protocolData, 'intertrialCommands') && ...
                           ~isempty(self.protocolData.intertrialCommands);
            
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
            % Find condition definition by ID
            
            conditions = self.protocolData.blockConditions;
            for i = 1:length(conditions)
                if strcmp(conditions(i).id, conditionID)
                    conditionDef = conditions(i);
                    return;
                end
            end
            error('Condition not found: %s', conditionID);
        end
        
        function executeTrial(self, trialMetadata, conditionDef)
            % Execute commands for a single trial
            
            startTime = tic;
            
            commands = conditionDef.commands;
            
            for i = 1:length(commands)
                try
                    self.commandExecutor.execute(commands{i});
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
            % Execute intertrial commands
            
            commands = self.protocolData.intertrialCommands;
            
            for i = 1:length(commands)
                try
                    self.commandExecutor.execute(commands{i});
                catch ME
                    self.logger.log('ERROR', sprintf('Intertrial command %d failed: %s', ...
                                                   i, ME.message));
                    error('Intertrial phase failed');
                end
            end
        end
        
        function executePosttrialPhase(self)
            % Execute posttrial commands
            
            if ~isfield(self.protocolData, 'posttrialCommands') || ...
               isempty(self.protocolData.posttrialCommands)
                self.logger.log('INFO', 'No posttrial phase defined');
                return;
            end
            
            self.logger.log('INFO', '=== POSTTRIAL PHASE START ===');
            fprintf('\n=== Executing Posttrial ===\n');
            
            commands = self.protocolData.posttrialCommands;
            
            for i = 1:length(commands)
                self.logger.log('INFO', sprintf('Executing posttrial command %d/%d', ...
                                              i, length(commands)));
                
                try
                    self.commandExecutor.execute(commands{i});
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
            % Save data and close resources
            
            self.logger.log('INFO', 'Finalizing experiment...');
            
            % Save trial execution order
            trialOrder = self.trialExecutionOrder;
            
            save(fullfile(self.experimentDir, 'trial_order.mat'), 'trialOrder');
            
            % TODO: Save any additional data collected during experiment
            
            % Generate summary
            self.generateExperimentSummary();
            
            % Clean shutdown
            self.cleanup();
            
%            self.logger.log('INFO', '=== EXPERIMENT COMPLETE ===');
        end
        
        function generateExperimentSummary(self)
            % Create experiment summary file with timestamped filename
            
            % Generate timestamp for current experiment run
            
            
            % Create summary filename with timestamp
            summaryFilename = sprintf('experimentSummary_%s.txt', self.startTime);
            summaryFile = fullfile(self.experimentDir, summaryFilename);
            fid = fopen(summaryFile, 'w');
            
            fprintf(fid, 'EXPERIMENT SUMMARY\n');
            fprintf(fid, '==================\n\n');
            fprintf(fid, 'Experiment: %s\n', self.protocolData.experimentInfo.name);
            fprintf(fid, 'Date: %s\n', self.startTime);
            fprintf(fid, 'Protocol: %s\n\n', self.protocolFilePath);
            
            fprintf(fid, 'Arena Configuration:\n');
            fprintf(fid, '  Generation: %s\n', self.protocolData.arenaConfig.generation);
            fprintf(fid, '  Dimensions: %dx%d panels\n', ...
                    self.protocolData.arenaConfig.num_rows, ...
                    self.protocolData.arenaConfig.num_cols);
            fprintf(fid, '\n');
            
            fprintf(fid, 'Experimental Design:\n');
            fprintf(fid, '  Conditions: %d\n', length(self.protocolData.blockConditions));
            fprintf(fid, '  Repetitions: %d\n', self.protocolData.experimentStructure.repetitions);
            fprintf(fid, '  Total Trials: %d\n', ProtocolParser.get_total_trials(self.protocolData));
            fprintf(fid, '\n');
            
            % TODO: Add more summary statistics
            
            fclose(fid);
            
            self.logger.log('INFO', sprintf('Summary saved to: %s', summaryFile));
        end
    end
end

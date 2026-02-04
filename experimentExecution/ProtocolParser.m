classdef ProtocolParser < handle
    % Parse  and validate YAML protocol files
    %
    % This class reads YAML protocol files and extracts all sections into
    % a structured format. It validates the protocol structure and provides
    % detailed error messages for any issues.
    %
    % Example usage:
    %   parser = ProtocolParser('verbose', true);
    %   protocol = parser.parse('./protocols/my_experiment.yaml');
    %   
    %   % Access parsed data:
    %   experimentName = protocol.experimentInfo.name;
    %   numConditions = length(protocol.blockConditions);
    
    properties (Access = private)
        verbose         % Whether to print parsing progress
        filepath        % Path to protocol file being parsed
    end

    properties (Constant)
        SUPPORTED_VERSIONS = [1];
        REQUIRED_YAML_SECTIONS = {'experiment_info', 'arena_info', 'experiment_structure', 'block'};
        REQUIRED_ARENA_FIELDS = {'num_rows', 'num_cols', 'generation'};
        SUPPORTED_GENERATIONS = {'G4', 'G4.1', 'G6'};
        SUPPORTED_RANDOMIZATION_METHODS = {'block'};
        SUPPORTED_PLUGIN_TYPES = {'serial_device', 'class', 'script'};

    end
    
    methods (Access = public)
        function self = ProtocolParser(varargin)
            % Constructor
            %
            % Optional Name-Value Arguments:
            %   'verbose' - Print parsing progress (default: false)
            %
            % Example:
            %   parser = ProtocolParser('verbose', true);
            
            % Parse input arguments
            p = inputParser;
            addParameter(p, 'verbose', false, @islogical);
            parse(p, varargin{:});
            
            self.verbose = p.Results.verbose;
        end
        
        function protocol = parse(self, filepath)
            % Parse YAML protocol file
            %
            % Input Arguments:
            %   filepath - Path to YAML protocol file
            %
            % Returns:
            %   protocol - Struct containing all parsed protocol data
            %   The struct fields are: 
            %     - version:  Just a number keeping track of yaml versions
            %     - experiment_info: a struct with three fields, "name",
            %     "date_created", and "author" 
            %     - arena_info: struct with three fields, "num_rows",
            %     "num_cols", and "generation"
            %     - plugins: cell array of structs. Each struct has a
            %     "name" and "type" field plus additional fields depending
            %     on type. Possible types are "serial_device", "class", and
            %     "script"
            %     - experiment_structure: struct with two fields,
            %     "repetitions", and "randomization", which is another
            %     small struct
            %     - pretrial: struct with two fields, "include" (1 for yes,
            %     0 for no), and "commands", a cell array of structs - one
            %     for each command. 
            %     - block: has just one field, "conditions", which is a
            %     struct array. So rawData.block.conditions(1) has two
            %     fields, "id", and "commands", a  cell array of structs
            %     - intertrial: struct with two fields, "include", and
            %     "commands", a cell array of structs
            %     - posttrial: struct with two fields, "include" and
            %     "commands", a cell array of structs

            %
            % Example:
            %   protocol = parser.parse('./protocols/experiment.yaml');
            
            self.filepath = filepath;
            
            if self.verbose
                fprintf('Parsing protocol: %s\n', filepath);
            end
            
            % Check file exists
            if ~isfile(filepath)
                error('ProtocolParser:FileNotFound', ...
                      'Protocol file not found: %s', filepath);
            end
            
            try
                % Read YAML file using yamlread found in yamlSupport
                rawData = yamlread(filepath);
                
                if self.verbose
                    fprintf('  YAML file loaded successfully\n');
                end
                
                % Validate protocol structure
                self.validateProtocol(rawData);
                
                % Extract all sections into structured format
                protocol = self.extractProtocol(rawData);
                
                % Store filepath in protocol for reference
                protocol.filepath = filepath;
                
                if self.verbose
                    fprintf('  Protocol parsed successfully\n');
                    self.printProtocolSummary(protocol);
                end
                
            catch ME
                % Provide context for parsing errors
                if strcmp(ME.identifier, 'ProtocolParser:ValidationError')
                    rethrow(ME);
                else
                    error('ProtocolParser:ParseError', ...
                          'Failed to parse protocol file: %s\nError: %s', ...
                          filepath, ME.message);
                end
            end
        end
    

        %% Getters to be used by other classes
    
        function output = get_supported_versions(self)
            output = self.SUPPORTED_VERSIONS;
        end


    end
    
    methods (Access = private)

        function validateProtocol(self, data)
            % Check that protocol has required structure
            %
            % Input Arguments:
            %   data - Raw parsed YAML data
            
            % Check version field exists
            if ~isfield(data, 'version')
                self.throwValidationError('Protocol missing required "version" field');
            end
            
            % Check version is supported
            if ~ismember(data.version, self.SUPPORTED_VERSIONS)
                self.throwValidationError(...
                    'Unsupported protocol version: %d (supported versions: %s)', ...
                    data.version, ...
                    mat2str(self.SUPPORTED_VERSIONS));
            end
            
            
            % Check major sections exist
            for i = 1:length(self.REQUIRED_YAML_SECTIONS)
                section = self.REQUIRED_YAML_SECTIONS{i};
                if ~isfield(data, section)
                    self.throwValidationError('Protocol missing required "%s" section', section);
                end
            end
            
            % Validate experiment_info
            self.validateExperimentInfo(data.experiment_info);
            
            % Validate arena_info
            self.validateArenaInfo(data.arena_info);
            
            % Validate experiment_structure
            self.validateExperimentStructure(data.experiment_structure);

       
            
            % Validate plugins (if present)
            if isfield(data, 'plugins')
                data.plugins = self.ensure_cell_array(data.plugins);
               
                self.validatePlugins(data.plugins);
            end
            
            % Validate trial sections
            self.validateTrialSections(data);
            
            if self.verbose
                fprintf('  Protocol validation passed\n');
            end
        end
        
        function validateExperimentInfo(self, experimentInfo)
            % Validate experiment_info section
            
            if ~isfield(experimentInfo, 'name')
                self.throwValidationError('experiment_info missing required "name" field');
            end
            
            if ~ischar(experimentInfo.name) && ~isstring(experimentInfo.name)
                self.throwValidationError('experiment_info.name must be a string');
            end
        end
        
        function validateArenaInfo(self, arenaInfo)
            % Validate arena_info section
            
            % Check required fields
            for i = 1:length(self.REQUIRED_ARENA_FIELDS)
                field = self.REQUIRED_ARENA_FIELDS{i};
                if ~isfield(arenaInfo, field)
                    self.throwValidationError('arena_info missing required "%s" field', field);
                end
            end
            
            % Validate num_rows
            if ~isnumeric(arenaInfo.num_rows) || arenaInfo.num_rows < 1
                self.throwValidationError('arena_info.num_rows must be a positive integer');
            end
            
            % Validate num_cols
            if ~isnumeric(arenaInfo.num_cols) || arenaInfo.num_cols < 1
                self.throwValidationError('arena_info.num_cols must be a positive integer');
            end
            
            % Validate generation
            if ~ismember(arenaInfo.generation, self.SUPPORTED_GENERATIONS)
                self.throwValidationError('arena_info.generation must be one of: %s', ...
                                         strjoin(self.SUPPORTED_GENERATIONS, ', '));
            end
        end
        
        function validateExperimentStructure(self, experimentStructure)
            % Validate experiment_structure section
            
            if ~isfield(experimentStructure, 'repetitions')
                self.throwValidationError('experiment_structure missing required "repetitions" field');
            end
            
            if ~isnumeric(experimentStructure.repetitions) || ...
               experimentStructure.repetitions < 1
                self.throwValidationError('experiment_structure.repetitions must be a positive integer');
            end
            
            % Validate randomization (if present)
            if isfield(experimentStructure, 'randomization')
                rand = experimentStructure.randomization;
                
                if isfield(rand, 'enabled') && rand.enabled
                    if ~isfield(rand, 'method')
                        self.throwValidationError('randomization.method required when randomization enabled');
                    end
                    
                    if ~ismember(rand.method, self.SUPPORTED_RANDOMIZATION_METHODS)
                        self.throwValidationError('randomization.method not supported');
                    end
                end
            end
        end
        
        function validatePlugins(self, plugins)
            % Validate plugins section
            
            
            
            if ~iscell(plugins)
                self.throwValidationError('plugins must be a list (cell array)');
            end
            
            for i = 1:length(plugins)
                plugin = plugins{i};
                
                % Check required fields
                if ~isfield(plugin, 'name')
                    self.throwValidationError('Plugin %d missing required "name" field', i);
                end
                
                if ~isfield(plugin, 'type')
                    self.throwValidationError('Plugin "%s" missing required "type" field', ...
                                             plugin.name);
                end
                
                % Validate plugin type
                if ~ismember(plugin.type, self.SUPPORTED_PLUGIN_TYPES)
                    self.throwValidationError('Plugin "%s" has invalid type "%s" (must be: %s)', ...
                                             plugin.name, plugin.type, ...
                                             strjoin(self.SUPPORTED_PLUGIN_TYPES, ', '));
                end
                
                % Type-specific validation
                switch plugin.type
                    case 'serial_device'
                        self.validateSerialPlugin(plugin);
                    case 'class'
                        self.validateClassPlugin(plugin);
                    case 'script'
                        self.validateScriptPlugin(plugin);
                end
            end
        end
        
        function validateSerialPlugin(self, plugin)
            % Validate serial_device plugin
            
            requiredFields = {'baudrate', 'commands'};
            for i = 1:length(requiredFields)
                field = requiredFields{i};
                if ~isfield(plugin, field)
                    self.throwValidationError('Serial plugin "%s" missing required "%s" field', ...
                                             plugin.name, field);
                end
            end
            
            % Must have at least one port defined
            if ~isfield(plugin, 'port_windows') && ~isfield(plugin, 'port_posix')
                self.throwValidationError('Serial plugin "%s" must define port_windows and/or port_posix', ...
                                         plugin.name);
            end
        end
        
        function validateClassPlugin(self, plugin)
            % Validate class plugin
            
            % Must have matlab and/or python implementation
            if ~isfield(plugin, 'matlab') && ~isfield(plugin, 'python')
                self.throwValidationError('Class plugin "%s" must define matlab and/or python implementation', ...
                                         plugin.name);
            end
            
            % Validate matlab implementation
            if isfield(plugin, 'matlab')
                if ~isfield(plugin.matlab, 'class')
                    self.throwValidationError('Class plugin "%s" matlab implementation missing "class" field', ...
                                             plugin.name);
                end
            end
            
            % Validate python implementation
            if isfield(plugin, 'python')
                pythonRequired = {'module', 'class'};
                for i = 1:length(pythonRequired)
                    field = pythonRequired{i};
                    if ~isfield(plugin.python, field)
                        self.throwValidationError('Class plugin "%s" python implementation missing "%s" field', ...
                                                 plugin.name, field);
                    end
                end
            end
        end
        
        function validateScriptPlugin(self, plugin)
            % Validate script plugin
            
            if ~isfield(plugin, 'script_path')
                self.throwValidationError('Script plugin "%s" missing required "script_path" field', ...
                                         plugin.name);
            end
        end
        
        function validateTrialSections(self, data)
            % Validate pretrial, block, intertrial, posttrial
            
            % Block is required and must have conditions
            if ~isfield(data, 'block')
                self.throwValidationError('Protocol missing required "block" section');
            end
            
            if ~isfield(data.block, 'conditions')
                self.throwValidationError('block section missing required "conditions" field');
            end
            
            if ~isstruct(data.block.conditions) || isempty(data.block.conditions)
                self.throwValidationError('block.conditions must be a non-empty list');
            end
  %          data.block.conditions = self.ensure_cell_array(data.block.conditions);
            
            
            % Validate each condition
            for i = 1:length(data.block.conditions)
                
                condition = data.block.conditions(i);
                
                if ~isfield(condition, 'id')
                    self.throwValidationError('Block condition %d missing required "id" field', i);
                end
                
                if ~isfield(condition, 'commands')
                    self.throwValidationError('Block condition "%s" missing required "commands" field', ...
                                             condition.id);
                end
                
                condition.commands = self.ensure_cell_array(condition.commands);

                if ~iscell(condition.commands)
                    self.throwValidationError('Block condition "%s" commands must be a list', ...
                                             condition.id);
                end
                
                % Validate commands in condition
                self.validateCommands(condition.commands, ...
                                     sprintf('Block condition "%s"', condition.id));
            end
            
            % Validate optional sections (if included)
            optionalSections = {'pretrial', 'intertrial', 'posttrial'};
            for i = 1:length(optionalSections)
                section = optionalSections{i};
                if isfield(data, section)
                    self.validateOptionalSection(data.(section), section);
                end
            end
        end
        
        function validateOptionalSection(self, section, sectionName)
            % Validate pretrial/intertrial/posttrial
            
            if ~isfield(section, 'include')
                self.throwValidationError('%s section missing required "include" field', sectionName);
            end
            
            if ~islogical(section.include) && ~isnumeric(section.include)
                self.throwValidationError('%s.include must be true or false', sectionName);
            end
            
            % If included, must have commands
            if section.include
                if ~isfield(section, 'commands')
                    self.throwValidationError('%s section has include=true but missing "commands" field', ...
                                             sectionName);
                end
                
                section.commands = self.ensure_cell_array(section.commands);

                if ~iscell(section.commands)
                    self.throwValidationError('%s.commands must be a list', sectionName);
                end
                
                % Validate commands
                self.validateCommands(section.commands, sectionName);
            end
        end
        
        function validateCommands(self, commands, context)
            % Validate a list of commands
            %
            % Input Arguments:
            %   commands - Cell array of command structs
            %   context - String describing where these commands are from
            
            for i = 1:length(commands)
                command = commands{i};
                
                % Every command must have a type
                if ~isfield(command, 'type')
                    self.throwValidationError('%s command %d missing required "type" field', ...
                                             context, i);
                end
                
                % Validate based on type
                switch command.type
                    case 'controller'
                        self.validateControllerCommand(command, context, i);
                    case 'wait'
                        self.validateWaitCommand(command, context, i);
                    case 'plugin'
                        self.validatePluginCommand(command, context, i);
                    otherwise
                        self.throwValidationError('%s command %d has invalid type "%s"', ...
                                                 context, i, command.type);
                end
            end
        end
        
        function validateControllerCommand(self, command, context, index)
            % Validate controller command
            
            if ~isfield(command, 'command_name')
                self.throwValidationError('%s controller command %d missing "command_name" field', ...
                                         context, index);
            end
            
            % Note: We don't validate command-specific parameters here
            % That will be done in CommandExecutor during execution
        end
        
        function validateWaitCommand(self, command, context, index)
            % Validate wait command
            
            if ~isfield(command, 'duration')
                self.throwValidationError('%s wait command %d missing "duration" field', ...
                                         context, index);
            end
            
            if ~isnumeric(command.duration) || command.duration < 0
                self.throwValidationError('%s wait command %d duration must be non-negative number', ...
                                         context, index);
            end
        end
        
        function validatePluginCommand(self, command, context, index)
            % Validate plugin command
            
            if ~isfield(command, 'plugin_name')
                self.throwValidationError('%s plugin command %d missing "plugin_name" field', ...
                                         context, index);
            end
            
            % Note: command_name field is validated later by CommandExecutor
            % based on plugin type (some plugins like scripts don't need it)
        end
        
        function protocol = extractProtocol(self, data)
            % Extract all protocol sections into structured format
            %
            % Input Arguments:
            %   data - Raw parsed YAML data
            %
            % Returns:
            %   protocol - Struct with organized protocol data
            
            protocol = struct();
            
            % Store version
            protocol.version = data.version;
            
            % Extract experiment metadata
            protocol.experimentInfo = data.experiment_info;
            
            % Extract arena configuration
            protocol.arenaConfig = data.arena_info;
            
            % Extract experiment structure
            protocol.experimentStructure = data.experiment_structure;
            
            % Extract plugins (if present)
            if isfield(data, 'plugins')
                protocol.plugins = data.plugins;
                protocol.plugins = self.ensure_cell_array(protocol.plugins);

                if self.verbose
                    fprintf('  Found %d plugin definitions\n', length(protocol.plugins));
                end
            else
                protocol.plugins = [];
                if self.verbose
                    fprintf('  No plugins defined\n');
                end
            end
            
            % Extract pretrial commands
            protocol.pretrialCommands = self.extractOptionalSection(data, 'pretrial');
            protocol.pretrialCommands = self.ensure_cell_array(protocol.pretrialCommands);

            if self.verbose
                if isempty(protocol.pretrialCommands)
                    fprintf('  Pretrial: skipped\n');
                else
                    fprintf('  Pretrial: %d commands\n', length(protocol.pretrialCommands));
                end
            end
            
            % Extract block conditions
            protocol.blockConditions = data.block.conditions;
  %          protocol.blockConditions = self.ensure_cell_array(protocol.blockConditions);

            for cond = 1:length(protocol.blockConditions)
                protocol.blockConditions(cond).commands = self.ensure_cell_array(protocol.blockConditions(cond).commands);
   
            end
            if self.verbose
                fprintf('  Block: %d conditions\n', length(protocol.blockConditions));
            end
            
            % Extract intertrial commands
            protocol.intertrialCommands = self.extractOptionalSection(data, 'intertrial');
            protocol.intertrialCommands = self.ensure_cell_array(protocol.intertrialCommands);

            if self.verbose
                if isempty(protocol.intertrialCommands)
                    fprintf('  Intertrial: skipped\n');
                else
                    fprintf('  Intertrial: %d commands\n', length(protocol.intertrialCommands));
                end
            end
            
            % Extract posttrial commands
            protocol.posttrialCommands = self.extractOptionalSection(data, 'posttrial');
            protocol.posttrialCommands = self.ensure_cell_array(protocol.posttrialCommands);

            if self.verbose
                if isempty(protocol.posttrialCommands)
                    fprintf('  Posttrial: skipped\n');
                else
                    fprintf('  Posttrial: %d commands\n', length(protocol.posttrialCommands));
                end
            end
        end
        
        function commands = extractOptionalSection(self, data, sectionName)
            % Extract commands from optional section
            %
            % Returns empty array if section not included
            
            if isfield(data, sectionName) && ...
               isfield(data.(sectionName), 'include') && ...
               data.(sectionName).include && ...
               isfield(data.(sectionName), 'commands')
                
                commands = data.(sectionName).commands;
            else
                commands = [];
            end
        end
        
        function printProtocolSummary(self, protocol)
            % Print summary of parsed protocol
            
            fprintf('\n=== Protocol Summary ===\n');
            fprintf('Experiment: %s\n', protocol.experimentInfo.name);
            
            if isfield(protocol.experimentInfo, 'author')
                fprintf('Author: %s\n', protocol.experimentInfo.author);
            end
            
            if isfield(protocol.experimentInfo, 'date_created')
                fprintf('Date Created: %s\n', protocol.experimentInfo.date_created);
            end
            
            fprintf('Arena: %dx%d panels (%s)\n', ...
                    protocol.arenaConfig.num_rows, ...
                    protocol.arenaConfig.num_cols, ...
                    protocol.arenaConfig.generation);
            
            fprintf('Repetitions: %d\n', protocol.experimentStructure.repetitions);
            
            if isfield(protocol.experimentStructure, 'randomization') && ...
               isfield(protocol.experimentStructure.randomization, 'enabled')
                if protocol.experimentStructure.randomization.enabled
                    fprintf('Randomization: enabled (%s)\n', ...
                            protocol.experimentStructure.randomization.method);
                else
                    fprintf('Randomization: disabled\n');
                end
            end
            
            total_trials = ProtocolParser.get_total_trials(protocol);

            fprintf('Conditions: %d\n', length(protocol.blockConditions));
            fprintf('Total trials: %d\n', total_trials);
            fprintf('========================\n\n');
        end
        
        function throwValidationError(self, varargin)
            % Throw validation error with context
            
            % Format error message
            msg = sprintf(varargin{:});
            
            % Add file context
            fullMsg = sprintf('Protocol validation failed (%s):\n%s', ...
                             self.filepath, msg);
            
            error('ProtocolParser:ValidationError', '%s', fullMsg);
        end

        function cellArray = ensure_cell_array(~, data)
            if isempty(data)
                cellArray = [];
            elseif isstruct(data) && ~iscell(data)
                cellArray = {data};
            else
                cellArray = data;
            end

        end
    end
    
    methods (Static)

        function output = get_total_trials(protocol)

            num_conds = length(protocol.blockConditions);
            reps = protocol.experimentStructure.repetitions;
            pre = 0;
            inter = 0;
            post = 0;
            if ~isempty(protocol.pretrialCommands)
                pre = 1;
            end
            if ~isempty(protocol.intertrialCommands)
                inter = 1;
            end
            if ~isempty(protocol.posttrialCommands)
                post = 1;
            end
            output = (num_conds*reps) + inter*((num_conds*reps)-1) + pre + post;
            
        end

        
    end

end
classdef ProtocolParser < handle
    % PROTOCOLPARSER Parse and validate YAML protocol files
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
    
    methods (Access = public)
        function self = ProtocolParser(varargin)
            % PROTOCOLPARSER Constructor
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
            % PARSE Parse YAML protocol file
            %
            % Input Arguments:
            %   filepath - Path to YAML protocol file
            %
            % Returns:
            %   protocol - Struct containing all parsed protocol data
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
                % Read YAML file using ReadYaml
                rawData = ReadYaml(filepath);
                
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
    end
    
    methods (Access = private)
        function validateProtocol(self, data)
            % VALIDATEPROTOCOL Check that protocol has required structure
            %
            % Input Arguments:
            %   data - Raw parsed YAML data
            
            % Check version field exists
            if ~isfield(data, 'version')
                self.throwValidationError('Protocol missing required "version" field');
            end
            
            % Check version is supported
            if data.version ~= 1
                self.throwValidationError('Unsupported protocol version: %d (expected 1)', ...
                                         data.version);
            end
            
            % Check major sections exist
            requiredSections = {'experiment_info', 'arena_info', 'experiment_structure'};
            for i = 1:length(requiredSections)
                section = requiredSections{i};
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
                self.validatePlugins(data.plugins);
            end
            
            % Validate trial sections
            self.validateTrialSections(data);
            
            if self.verbose
                fprintf('  Protocol validation passed\n');
            end
        end
        
        function validateExperimentInfo(self, experimentInfo)
            % VALIDATEEXPERIMENTINFO Validate experiment_info section
            
            if ~isfield(experimentInfo, 'name')
                self.throwValidationError('experiment_info missing required "name" field');
            end
            
            if ~ischar(experimentInfo.name) && ~isstring(experimentInfo.name)
                self.throwValidationError('experiment_info.name must be a string');
            end
        end
        
        function validateArenaInfo(self, arenaInfo)
            % VALIDATEARENAINFO Validate arena_info section
            
            % Check required fields
            arenaRequired = {'num_rows', 'num_cols', 'generation'};
            for i = 1:length(arenaRequired)
                field = arenaRequired{i};
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
            validGenerations = {'G4', 'G4.1', 'G6'};
            if ~ismember(arenaInfo.generation, validGenerations)
                self.throwValidationError('arena_info.generation must be one of: %s', ...
                                         strjoin(validGenerations, ', '));
            end
        end
        
        function validateExperimentStructure(self, experimentStructure)
            % VALIDATEEXPERIMENTSTRUCTURE Validate experiment_structure section
            
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
                    
                    validMethods = {'block', 'trial'};
                    if ~ismember(rand.method, validMethods)
                        self.throwValidationError('randomization.method must be "block" or "trial"');
                    end
                end
            end
        end
        
        function validatePlugins(self, plugins)
            % VALIDATEPLUGINS Validate plugins section
            
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
                validTypes = {'serial_device', 'class', 'script'};
                if ~ismember(plugin.type, validTypes)
                    self.throwValidationError('Plugin "%s" has invalid type "%s" (must be: %s)', ...
                                             plugin.name, plugin.type, ...
                                             strjoin(validTypes, ', '));
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
            % VALIDATESERIAL Validate serial_device plugin
            
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
            % VALIDATECLASSPLUGIN Validate class plugin
            
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
            % VALIDATESCRIPTPLUGIN Validate script plugin
            
            if ~isfield(plugin, 'script')
                self.throwValidationError('Script plugin "%s" missing required "script" field', ...
                                         plugin.name);
            end
        end
        
        function validateTrialSections(self, data)
            % VALIDATETRIALSECTIONS Validate pretrial, block, intertrial, posttrial
            
            % Block is required and must have conditions
            if ~isfield(data, 'block')
                self.throwValidationError('Protocol missing required "block" section');
            end
            
            if ~isfield(data.block, 'conditions')
                self.throwValidationError('block section missing required "conditions" field');
            end
            
            if ~iscell(data.block.conditions) || isempty(data.block.conditions)
                self.throwValidationError('block.conditions must be a non-empty list');
            end
            
            % Validate each condition
            for i = 1:length(data.block.conditions)
                condition = data.block.conditions{i};
                
                if ~isfield(condition, 'id')
                    self.throwValidationError('Block condition %d missing required "id" field', i);
                end
                
                if ~isfield(condition, 'commands')
                    self.throwValidationError('Block condition "%s" missing required "commands" field', ...
                                             condition.id);
                end
                
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
            % VALIDATEOPTIONALSECTION Validate pretrial/intertrial/posttrial
            
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
                
                if ~iscell(section.commands)
                    self.throwValidationError('%s.commands must be a list', sectionName);
                end
                
                % Validate commands
                self.validateCommands(section.commands, sectionName);
            end
        end
        
        function validateCommands(self, commands, context)
            % VALIDATECOMMANDS Validate a list of commands
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
            % VALIDATECONTROLLERCOMMAND Validate controller command
            
            if ~isfield(command, 'command_name')
                self.throwValidationError('%s controller command %d missing "command_name" field', ...
                                         context, index);
            end
            
            % Note: We don't validate command-specific parameters here
            % That will be done in CommandExecutor during execution
        end
        
        function validateWaitCommand(self, command, context, index)
            % VALIDATEWAITCOMMAND Validate wait command
            
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
            % VALIDATEPLUGINCOMMAND Validate plugin command
            
            if ~isfield(command, 'plugin_name')
                self.throwValidationError('%s plugin command %d missing "plugin_name" field', ...
                                         context, index);
            end
            
            % Note: command_name field is validated later by CommandExecutor
            % based on plugin type (some plugins like scripts don't need it)
        end
        
        function protocol = extractProtocol(self, data)
            % EXTRACTPROTOCOL Extract all protocol sections into structured format
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
            if self.verbose
                if isempty(protocol.pretrialCommands)
                    fprintf('  Pretrial: skipped\n');
                else
                    fprintf('  Pretrial: %d commands\n', length(protocol.pretrialCommands));
                end
            end
            
            % Extract block conditions
            protocol.blockConditions = data.block.conditions;
            if self.verbose
                fprintf('  Block: %d conditions\n', length(protocol.blockConditions));
            end
            
            % Extract intertrial commands
            protocol.intertrialCommands = self.extractOptionalSection(data, 'intertrial');
            if self.verbose
                if isempty(protocol.intertrialCommands)
                    fprintf('  Intertrial: skipped\n');
                else
                    fprintf('  Intertrial: %d commands\n', length(protocol.intertrialCommands));
                end
            end
            
            % Extract posttrial commands
            protocol.posttrialCommands = self.extractOptionalSection(data, 'posttrial');
            if self.verbose
                if isempty(protocol.posttrialCommands)
                    fprintf('  Posttrial: skipped\n');
                else
                    fprintf('  Posttrial: %d commands\n', length(protocol.posttrialCommands));
                end
            end
        end
        
        function commands = extractOptionalSection(self, data, sectionName)
            % EXTRACTOPTIONALSECTION Extract commands from optional section
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
            % PRINTPROTOCOLSUMMARY Print summary of parsed protocol
            
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
            
            fprintf('Conditions: %d\n', length(protocol.blockConditions));
            fprintf('Total trials: %d\n', ...
                    length(protocol.blockConditions) * protocol.experimentStructure.repetitions);
            fprintf('========================\n\n');
        end
        
        function throwValidationError(self, varargin)
            % THROWVALIDATIONERROR Throw validation error with context
            
            % Format error message
            msg = sprintf(varargin{:});
            
            % Add file context
            fullMsg = sprintf('Protocol validation failed (%s):\n%s', ...
                             self.filepath, msg);
            
            error('ProtocolParser:ValidationError', '%s', fullMsg);
        end
    end
end
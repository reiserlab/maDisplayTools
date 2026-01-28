classdef PluginManager < handle
    % Manages initialization and execution of all plugins
    %
    % This class handles:
    % - Initializing serial device, class, and script plugins
    % - Storing plugin instances in a registry
    % - Executing plugin commands
    % - Cleanup and connection management
    
    properties (Access = private)
        pluginRegistry      % containers.Map: plugin ID -> Plugin object
        logger
        outputDir% ExperimentLogger instance
    end
    
    methods (Access = public)
        function self = PluginManager(logger)
            % Constructor
            %
            % Input Arguments:
            %   logger - ExperimentLogger instance for logging
            
            self.pluginRegistry = containers.Map();
            self.logger = logger;
            self.outputDir = fileparts(self.logger.logFile); % This is outputDir/logs, same location as experiment.log
        end
        
        function initializePlugin(self, pluginDef)
            % Initialize a plugin from definition
            %
            % Input Arguments:
            %   pluginDef - Struct containing plugin definition from YAML
            %               Required fields: id, type
            %               Additional fields depend on type
            
            pluginName = pluginDef.name;
            pluginType = pluginDef.type;
            
            self.logger.log('INFO', sprintf('Initializing %s plugin: %s', ...
                                          pluginType, pluginName));

            % Inject outputDir into plugin config if available

            if ~isfield(pluginDef, 'config')
                pluginDef.config = struct();
            end
            if ~isfield(pluginDef.config, 'log_file') || isempty(pluginDef.config.log_file)
             % Default: outputDir/logs/<pluginname>_timestamps.log
                pluginDef.config.log_file = fullfile(self.outputDir, sprintf('%s.log', pluginName));
            end


            
            % Create appropriate plugin object based on type.
            %% TODO: Still need to create these classes. Each class can load a plugin
            % of the particular type made by the user. 
            switch pluginType
                case 'serial_device'
                    plugin = SerialPlugin(pluginName, pluginDef, self.logger);
                    
                case 'class'
                    plugin = ClassPlugin(pluginName, pluginDef, self.logger);
                    
                case 'script'
                    plugin = ScriptPlugin(pluginName, pluginDef, self.logger);
                    
                otherwise
                    error('Unknown plugin type: %s', pluginType);
            end
            
            % Initialize the plugin
            plugin.initialize();
            
            % Store in registry
            self.pluginRegistry(pluginName) = plugin;
        end
        
        function plugin = getPlugin(self, pluginName)
            % Retrieve plugin by ID
            %
            % Input Arguments:
            %   pluginName - Plugin identifier string
            %
            % Returns:
            %   plugin - Plugin object
            
            if ~self.pluginRegistry.isKey(pluginName)
                error('Plugin not found: %s', pluginName);
            end
            
            plugin = self.pluginRegistry(pluginName);
        end
        
        function result = executePluginCommand(self, pluginName, varargin)
            % Execute a command on a plugin
            %
            % Input Arguments:
            %   pluginName - Plugin identifier string
            %   varargin - Additional arguments depend on plugin type:
            %              For SerialPlugin: 'command', commandName
            %              For ClassPlugin: 'method', methodName, 'params', params
            %              For ScriptPlugin: (no additional args)
            %
            % Returns:
            %   result - Command execution result (plugin-dependent)
            
            plugin = self.getPlugin(pluginName);
            result = plugin.execute(varargin{:});
        end
        
        function closeAll(self)
            % Close all plugin connections
            
            self.logger.log('INFO', 'Closing all plugins...');
            
            pluginNames = keys(self.pluginRegistry);
            for i = 1:length(pluginNames)
                pluginName = pluginNames{i};
                try
                    plugin = self.pluginRegistry(pluginName);
                    plugin.cleanup();
                    self.logger.log('INFO', sprintf('  ✓ Closed plugin: %s', pluginName));
                catch ME
                    self.logger.log('WARNING', sprintf('  ✗ Failed to close plugin %s: %s', ...
                                                     pluginName, ME.message));
                end
            end
        end
        
        function count = getPluginCount(self)
            % Get number of registered plugins
            
            count = self.pluginRegistry.Count;
        end
        
        function ids = listpluginNames(self)
            % Get list of all plugin IDs
            
            ids = keys(self.pluginRegistry);
        end
    end
end

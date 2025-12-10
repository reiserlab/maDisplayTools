classdef PluginManager < handle
    % PLUGINMANAGER Manages initialization and execution of all plugins
    %
    % This class handles:
    % - Initializing serial device, class, and script plugins
    % - Storing plugin instances in a registry
    % - Executing plugin commands
    % - Cleanup and connection management
    
    properties (Access = private)
        pluginRegistry      % containers.Map: plugin ID -> Plugin object
        logger              % ExperimentLogger instance
    end
    
    methods (Access = public)
        function self = PluginManager(logger)
            % PLUGINMANAGER Constructor
            %
            % Input Arguments:
            %   logger - ExperimentLogger instance for logging
            
            self.pluginRegistry = containers.Map();
            self.logger = logger;
        end
        
        function initializePlugin(self, pluginDef)
            % INITIALIZEPLUGIN Initialize a plugin from definition
            %
            % Input Arguments:
            %   pluginDef - Struct containing plugin definition from YAML
            %               Required fields: id, type
            %               Additional fields depend on type
            
            pluginID = pluginDef.id;
            pluginType = pluginDef.type;
            
            self.logger.log('INFO', sprintf('Initializing %s plugin: %s', ...
                                          pluginType, pluginID));
            
            % Create appropriate plugin object based on type
            switch pluginType
                case 'serial_device'
                    plugin = SerialPlugin(pluginID, pluginDef, self.logger);
                    
                case 'class'
                    plugin = ClassPlugin(pluginID, pluginDef, self.logger);
                    
                case 'script'
                    plugin = ScriptPlugin(pluginID, pluginDef, self.logger);
                    
                otherwise
                    error('Unknown plugin type: %s', pluginType);
            end
            
            % Initialize the plugin
            plugin.initialize();
            
            % Store in registry
            self.pluginRegistry(pluginID) = plugin;
        end
        
        function plugin = getPlugin(self, pluginID)
            % GETPLUGIN Retrieve plugin by ID
            %
            % Input Arguments:
            %   pluginID - Plugin identifier string
            %
            % Returns:
            %   plugin - Plugin object
            
            if ~self.pluginRegistry.isKey(pluginID)
                error('Plugin not found: %s', pluginID);
            end
            
            plugin = self.pluginRegistry(pluginID);
        end
        
        function result = executePluginCommand(self, pluginID, varargin)
            % EXECUTEPLUGINCOMMAND Execute a command on a plugin
            %
            % Input Arguments:
            %   pluginID - Plugin identifier string
            %   varargin - Additional arguments depend on plugin type:
            %              For SerialPlugin: 'command', commandName
            %              For ClassPlugin: 'method', methodName, 'params', params
            %              For ScriptPlugin: (no additional args)
            %
            % Returns:
            %   result - Command execution result (plugin-dependent)
            
            plugin = self.getPlugin(pluginID);
            result = plugin.execute(varargin{:});
        end
        
        function closeAll(self)
            % CLOSEALL Close all plugin connections
            
            self.logger.log('INFO', 'Closing all plugins...');
            
            pluginIDs = keys(self.pluginRegistry);
            for i = 1:length(pluginIDs)
                pluginID = pluginIDs{i};
                try
                    plugin = self.pluginRegistry(pluginID);
                    plugin.close();
                    self.logger.log('INFO', sprintf('  ✓ Closed plugin: %s', pluginID));
                catch ME
                    self.logger.log('WARNING', sprintf('  ✗ Failed to close plugin %s: %s', ...
                                                     pluginID, ME.message));
                end
            end
        end
        
        function count = getPluginCount(self)
            % GETPLUGINCOUNT Get number of registered plugins
            
            count = self.pluginRegistry.Count;
        end
        
        function ids = listPluginIDs(self)
            % LISTPLUGINIDS Get list of all plugin IDs
            
            ids = keys(self.pluginRegistry);
        end
    end
end

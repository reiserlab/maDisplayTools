classdef ClassPlugin < handle
    % Manages user-defined MATLAB class instances
    %
    % This plugin type allows integration of complex hardware devices or
    % systems that require custom classes with methods and state management.
    % Examples: LED controllers, cameras, DAQ systems, custom instruments.
    %
    % YAML Definition Format:
    %   plugins:
    %     - name: "led_controller"
    %       type: "class"
    %       class: "LEDControllerPlugin"  % User-defined class name
    %       config:                        % Configuration passed to constructor
    %         port: "COM6"
    %         baudrate: 115200
    %         critical: true
    %
    % Class Requirements:
    %   - Must have constructor: function obj = MyClass(name, config, logger)
    %   - Must implement: function result = execute(obj, command, params)
    %   - Must implement: function initialize(obj)  % For connection setup
    %   - Must implement: function cleanup(obj)     % For cleanup/disconnection
    %   - Optional: function status = getStatus(obj)
    %
    % Usage in Protocol:
    %   block:
    %     conditions:
    %       - id: "trial1"
    %         commands:
    %           - type: "plugin"
    %             plugin_name: "led_controller"
    %             command_name: "setRedLED"
    %             params:
    %               power: 5
    %               pattern: "1010"
    
    properties (Access = private)
        name           % Plugin name
        definition     % Plugin definition from YAML
        logger         % Logger instance
        className      % Name of user's class
        classInstance  % Instance of user's class
        config         % Configuration struct for the class
        experimentDir  % Experiment directory where any output files/folders are saved
    end
    
    methods
        function self = ClassPlugin(name, definition, logger)
            % CLASSPLUGIN Constructor
            %
            % Args:
            %   name: Plugin name (string)
            %   definition: Plugin definition struct from YAML
            %   logger: Logger instance
            
            self.name = name;
            self.definition = definition;
            self.logger = logger;
            
            % Validate required fields
            %self.validateDefinition(); % Already validated in parser
            
            % Extract configuration
            self.extractConfiguration();
            
            % Create class instance
            try
                self.createClassInstance();
            catch ME
                self.logger.log('ERROR', sprintf('[%s] Failed to create class instance: %s', ...
                    self.name, ME.message));
                rethrow(ME);
            end
        end
        
        function initialize(self)
            % Initialize the user class
            %
            % Calls the initialize() method on the user's class instance.
            % This is where devices open connections, allocate resources, etc.
            
            try
                self.logger.log('INFO', sprintf('[%s] Initializing class: %s', ...
                    self.name, self.className));
                
                % Call user class's initialize method
                self.classInstance.initialize();
                
                self.logger.log('INFO', sprintf('[%s] Class initialized successfully', ...
                    self.name));
                
            catch ME
                self.logger.log('ERROR', sprintf('[%s] Initialization failed: %s', ...
                    self.name, ME.message));
                rethrow(ME);
            end
        end
        
        function result = execute(self, command, params)
            % Execute a command on the user class
            %
            % Args:
            %   command: Command name (string)
            %   params: Parameter struct (optional)
            %
            % Returns:
            %   result: Command result from user class
            
            if ~exist('params', 'var')
                params = struct();
            end
            
            try
                self.logger.log('DEBUG', sprintf('[%s] Executing command: %s', ...
                    self.name, command));
                
                % Call user class's execute method
                result = self.classInstance.execute(command, params);
                
                self.logger.log('DEBUG', sprintf('[%s] Command completed: %s', ...
                    self.name, command));
                
            catch ME
                self.logger.log('ERROR', sprintf('[%s] Command failed: %s - %s', ...
                    self.name, command, ME.message));
                rethrow(ME);
            end
        end
        
        function cleanup(self)
            % Clean up the user class
            %
            % Calls the cleanup() method on the user's class instance.
            % This is where devices close connections, release resources, etc.
            
            if ~isempty(self.classInstance)
                try
                    self.logger.log('INFO', sprintf('[%s] Cleaning up class: %s', ...
                        self.name, self.className));
                    
                    % Call user class's cleanup method
                    self.classInstance.cleanup();
                    
                    self.logger.log('INFO', sprintf('[%s] Class cleaned up', self.name));
                    
                catch ME
                    self.logger.log('WARNING', sprintf('[%s] Cleanup error: %s', ...
                        self.name, ME.message));
                end
            end
        end
        
        function status = getStatus(self)
            % Get current plugin status
            %
            % Returns:
            %   status: Struct with plugin information
            
            status = struct();
            status.name = self.name;
            status.className = self.className;
            status.hasInstance = ~isempty(self.classInstance);
            
            % Try to get status from user class if it implements getStatus()
            if status.hasInstance && ismethod(self.classInstance, 'getStatus')
                try
                    status.classStatus = self.classInstance.getStatus();
                catch
                    status.classStatus = 'unavailable';
                end
            end
        end
        
        function type = getPluginType(self)
            % Get plugin type identifier
            %
            % Returns:
            %   type: String "class"
            
            type = 'class';
        end
    end
    
    methods (Access = private)
        function validateDefinition(self)
            % Check required fields in definition
            
            if ~isfield(self.definition, 'class')
                error('ClassPlugin:MissingField', ...
                    'Plugin "%s" missing required field: class', self.name);
            end
        end
        
        function extractConfiguration(self)
            % Extract class name and configuration
            if isfield(self.definition, 'matlab')
                self.className = self.definition.matlab.class;
            elseif isfield(self.definition, 'python')
                if isfield(self.definition.python, 'module')
                    self.className = self.definition.python.module;
                else
                    self.className = self.definition.python.class;
                end
            end
            
            % Optional config struct
            if isfield(self.definition, 'config')
                self.config = self.definition.config;
            else
                self.config = struct();
            end

            if isfield(self.config, 'experimentDir')
                self.experimentDir = self.config.experimentDir;
            else
                self.experimentDir = pwd;
            end
        end
        
        function createClassInstance(self)
            % Instantiate the user's class
            %
            % The class must accept (name, config, logger) as constructor arguments.
            
            self.logger.log('DEBUG', sprintf('[%s] Instantiating class: %s', ...
                self.name, self.className));
            
            % Check if class exists
            if exist(self.className, 'class') ~= 8
                error('ClassPlugin:ClassNotFound', ...
                    'Class not found: %s (check MATLAB path)', self.className);
            end
            
            try
                % Instantiate with standard plugin interface
                self.classInstance = feval(self.className, self.name, self.config, self.logger);
                
            catch ME
                error('ClassPlugin:InstantiationFailed', ...
                    'Failed to instantiate %s: %s\n\nClass must accept (name, config, logger) as constructor arguments.', ...
                    self.className, ME.message);
            end
            
            % Validate required methods
            self.validateClassInterface();
        end
        
        function validateClassInterface(self)
            % Verify that user class implements required methods
            
            requiredMethods = {'initialize', 'execute', 'cleanup'};
            
            for i = 1:length(requiredMethods)
                methodName = requiredMethods{i};
                
                if ~ismethod(self.classInstance, methodName)
                    error('ClassPlugin:MissingMethod', ...
                        'Class %s must implement method: %s', ...
                        self.className, methodName);
                end
            end
            
            self.logger.log('DEBUG', sprintf('[%s] Class interface validated', ...
                self.name));
        end
    end
end

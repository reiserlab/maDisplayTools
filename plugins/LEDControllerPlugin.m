classdef LEDControllerPlugin < handle
    % Plugin wrapper for LEDController (backlight control)
    %
    % This plugin wraps the existing LEDController class to integrate it
    % with the experiment framework's plugin system. It allows control of
    % IR and colored LED backlights during experiments.
    %
    % YAML Definition Format:
    %   plugins:
    %     - name: "backlight"
    %       type: "class"
    %       matlab:
    %         class: "LEDControllerPlugin"
    %       config:
    %         port: "COM6"
    %
    % Usage in Protocol:
    %   pretrial:
    %     commands:
    %       - type: "plugin"
    %         plugin_name: "backlight"
    %         command_name: "setIRLEDPower"
    %         params:
    %           power: 50
    %       
    %       - type: "plugin"
    %         plugin_name: "backlight"
    %         command_name: "setRedLEDPower"
    %         params:
    %           power: 5
    %           power_backoff: 0
    %           pattern: "1010"
    %       
    %       - type: "plugin"
    %         plugin_name: "backlight"
    %         command_name: "turnOnLED"
    %
    %   posttrial:
    %     commands:
    %       - type: "plugin"
    %         plugin_name: "backlight"
    %         command_name: "turnOffLED"
    %
    % Available Commands:
    %   - setIRLEDPower: Set IR LED power (params.power: 0-100)
    %   - setRedLEDPower: Set red LED (params.power, power_backoff, pattern)
    %   - setGreenLEDPower: Set green LED (params.power, power_backoff, pattern)
    %   - setBlueLEDPower: Set blue LED (params.power, power_backoff, pattern)
    %   - turnOnLED: Turn on LED
    %   - turnOffLED: Turn off LED
    
    properties (Access = private)
        name           % Plugin name from YAML
        config         % Configuration struct
        logger         % Logger instance
        port           % Serial port (e.g., "COM6")
        isCritical     % If true, failure aborts experiment
        controller     % LEDController instance
        isInitialized  % Initialization status
    end
    
    methods (Access = public)
        function self = LEDControllerPlugin(name, config, logger)
            % LEDCONTROLLERPLUGIN Constructor
            %
            % Args:
            %   name: Plugin name (string)
            %   config: Configuration struct from YAML
            %   logger: Logger instance
            %
            % Required config fields:
            %   port: Serial port (e.g., "COM6")
            %
            % Optional config fields:
            %   critical: If true, failures abort experiment (default: true)
            
            self.name = name;
            self.config = config;
            self.logger = logger;
            self.isInitialized = false;
            
            % Extract configuration
            self.extractConfiguration();
            
            self.logger.log('INFO', sprintf('[%s] LEDController plugin created for port %s', ...
                self.name, self.port));
        end
        
        function initialize(self)
            % Initialize the LED controller
            %
            % Creates the LEDController instance and opens the serial connection.
            % This is called during experiment setup (pretrial).
            
            try
                self.logger.log('INFO', sprintf('[%s] Initializing LED controller on %s...', ...
                    self.name, self.port));
                
                % Create LEDController instance
                self.controller = LEDController(self.port);
                
                self.isInitialized = true;
                self.logger.log('INFO', sprintf('[%s] LED controller initialized successfully', ...
                    self.name));
                
            catch ME
                self.logger.log('ERROR', sprintf('[%s] Initialization failed: %s', ...
                    self.name, ME.message));
                
                if self.isCritical
                    rethrow(ME);
                else
                    self.logger.log('WARNING', sprintf('[%s] Non-critical plugin, continuing...', ...
                        self.name));
                end
            end
        end
        
        function result = execute(self, command, params)
            % Execute a command on the LED controller
            %
            % Args:
            %   command: Command name (string)
            %   params: Parameter struct (optional, depends on command)
            %
            % Returns:
            %   result: Empty (LED controller commands don't return values)
            %
            % Available commands:
            %   - "setIRLEDPower": params.power (0-100)
            %   - "setRedLEDPower": params.power, power_backoff, pattern
            %   - "setGreenLEDPower": params.power, power_backoff, pattern
            %   - "setBlueLEDPower": params.power, power_backoff, pattern
            %   - "turnOnLED": no params
            %   - "turnOffLED": no params
            
            result = [];
            
            % Check initialization
            if ~self.isInitialized
                error('LEDControllerPlugin:NotInitialized', ...
                    '[%s] LED controller not initialized', self.name);
            end
            
            if ~exist('params', 'var')
                params = struct();
            end
            
            try
                self.logger.log('DEBUG', sprintf('[%s] Executing command: %s', ...
                    self.name, command));
                
                % Route command to appropriate LEDController method
                switch command
                    case 'setIRLEDPower'
                        % params.power (required)
                        if ~isfield(params, 'power')
                            error('Missing required parameter: power');
                        end
                        self.controller.setIRLEDPower(params.power);
                        
                    case 'setRedLEDPower'
                        % params.power (required)
                        % params.power_backoff (optional, default 0)
                        % params.pattern (optional, default '')
                        if ~isfield(params, 'power')
                            error('Missing required parameter: power');
                        end
                        power_backoff = 0;
                        pattern = '';
                        if isfield(params, 'power_backoff')
                            power_backoff = params.power_backoff;
                        end
                        if isfield(params, 'pattern')
                            pattern = params.pattern;
                        end
                        self.controller.setRedLEDPower(params.power, power_backoff, pattern);
                        
                    case 'setGreenLEDPower'
                        % Same signature as setRedLEDPower
                        if ~isfield(params, 'power')
                            error('Missing required parameter: power');
                        end
                        power_backoff = 0;
                        pattern = '';
                        if isfield(params, 'power_backoff')
                            power_backoff = params.power_backoff;
                        end
                        if isfield(params, 'pattern')
                            pattern = params.pattern;
                        end
                        self.controller.setGreenLEDPower(params.power, power_backoff, pattern);
                        
                    case 'setBlueLEDPower'
                        % Same signature as setRedLEDPower
                        if ~isfield(params, 'power')
                            error('Missing required parameter: power');
                        end
                        power_backoff = 0;
                        pattern = '';
                        if isfield(params, 'power_backoff')
                            power_backoff = params.power_backoff;
                        end
                        if isfield(params, 'pattern')
                            pattern = params.pattern;
                        end
                        self.controller.setBlueLEDPower(params.power, power_backoff, pattern);
                        
                    case 'turnOnLED'
                        % No parameters
                        self.controller.turnOnLED();
                        
                    case 'turnOffLED'
                        % No parameters
                        self.controller.turnOffLED();
                        
                    otherwise
                        error('Unknown command: %s', command);
                end
                
                self.logger.log('DEBUG', sprintf('[%s] Command completed: %s', ...
                    self.name, command));
                
            catch ME
                self.logger.log('ERROR', sprintf('[%s] Command "%s" failed: %s', ...
                    self.name, command, ME.message));
                
                if self.isCritical
                    rethrow(ME);
                else
                    self.logger.log('WARNING', sprintf('[%s] Non-critical plugin, continuing...', ...
                        self.name));
                end
            end
        end
        
        function cleanup(self)
            % Clean up the LED controller
            %
            % Deletes the LEDController instance, which closes the serial connection.
            % This is called during experiment cleanup (posttrial).
            
            if self.isInitialized && ~isempty(self.controller)
                try
                    self.logger.log('INFO', sprintf('[%s] Cleaning up LED controller...', ...
                        self.name));
                    
                    % Delete the controller (closes serial connection)
                    self.controller.delete();
                    self.controller = [];
                    
                    self.isInitialized = false;
                    self.logger.log('INFO', sprintf('[%s] LED controller cleaned up', ...
                        self.name));
                    
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
            status.port = self.port;
            status.critical = self.isCritical;
            status.initialized = self.isInitialized;
            status.has_controller = ~isempty(self.controller);
        end
    end
    
    methods (Access = private)
        function extractConfiguration(self)
            % Extract and validate configuration from config struct
            
            % Required: port
            if ~isfield(self.config, 'port')
                error('LEDControllerPlugin:MissingConfig', ...
                    'Plugin "%s" missing required config field: port', self.name);
            end
            self.port = self.config.port;
            
            % Optional: critical flag (default false)
            if isfield(self.config, 'critical')
                self.isCritical = self.config.critical;
            else
                self.isCritical = true;
            end
        end
    end
end

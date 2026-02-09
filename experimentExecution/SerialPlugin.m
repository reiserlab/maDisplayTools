classdef SerialPlugin < handle
    % Plugin for simple serial devices defined entirely in YAML
    %
    % This class handles serial devices that can be fully controlled with
    % simple string commands defined in the YAML protocol file. For complex
    % devices requiring custom logic, use type: "class" instead.
    %
    % YAML Definition Format:
    %   plugins:
    %     - name: "simple_light"
    %       type: "serial"
    %       port: "COM5"
    %       baudrate: 9600                  # Optional, default 9600
    %       critical: false                 # Optional, default false
    %       commands:
    %         on: "LIGHT ON\r\n"
    %         off: "LIGHT OFF\r\n"
    %         set_brightness: "BRIGHT %d\r\n"  # %d for integer parameter
    %
    % Command String Formatting:
    %   - Static strings: "LIGHT ON\r\n"
    %   - Integer param: "BRIGHT %d\r\n"    (params.value = 50)
    %   - Multiple params: "LED %d %d\r\n"  (params.red = 50, params.green = 30)
    %
    % For complex devices (like LEDController), use type: "class" instead:
    %   plugins:
    %     - name: "led_controller"
    %       type: "class"
    %       class: "LEDControllerPlugin"
    %       config:
    %         port: "COM6"
    
    properties (Access = private)
        name              % Plugin name
        definition        % Plugin definition from YAML
        logger            % Logger instance
        port              % Serial port (e.g., "COM6" or "/dev/ttyUSB0")
        baudrate          % Baud rate (default: 9600)
        isCritical        % If true, failure aborts experiment
        isConnected       % Connection status flag
        serialPort        % MATLAB serialport object
        commands          % containers.Map: command_name -> command_string
        experimentDir
    end
    
    methods (Access = public)
        function self = SerialPlugin(name, definition, logger)
            % SERIALPLUGIN Constructor
            %
            % Args:
            %   name: Plugin name (string)
            %   definition: Plugin definition struct from YAML
            %   logger: Logger instance
            
            self.name = name;
            self.definition = definition;
            self.logger = logger;
            self.isConnected = false;
            self.commands = containers.Map();
            
            % Validate required fields
            self.validateDefinition();
            
            % Extract configuration
            self.extractConfiguration();
            
            % Load command definitions
            self.loadCommands();
            
            % Log initialization
            self.logger.log('INFO', sprintf('[%s] Serial plugin initialized with %d commands', ...
                self.name, self.commands.Count));
        end
        
        function initialize(self)
            % Initialize the serial device connection
            %
            % This method should be called during experiment setup (pretrial).
            % Subclasses can override to add device-specific initialization.
            %
            % Throws:
            %   Error if connection fails and plugin is critical
            
            try
                self.logger.log('INFO', sprintf('[%s] Connecting to serial device on %s...', ...
                    self.name, self.port));
                
                % Subclasses should implement openConnection()
                self.openConnection();
                
                self.isConnected = true;
                self.logger.log('INFO', sprintf('[%s] Successfully connected', self.name));
                
            catch ME
                self.logger.log('ERROR', sprintf('[%s] Connection failed: %s', ...
                    self.name, ME.message));
                
                if self.isCritical
                    error('SerialPlugin:CriticalFailure', ...
                        'Critical plugin %s failed to initialize: %s', ...
                        self.name, ME.message);
                else
                    self.logger.log('WARNING', sprintf('[%s] Non-critical plugin, continuing...', ...
                        self.name));
                end
            end
        end
        
        function result = execute(self, command, params)
            % Execute a simple serial command
            %
            % Args:
            %   command: Command name (must exist in commands map)
            %   params: Parameter struct (optional)
            %
            % Returns:
            %   result: Command execution result
            %
            % The command string can contain format specifiers:
            %   "LIGHT ON\r\n"           - Static string
            %   "BRIGHT %d\r\n"          - Single integer (params.value)
            %   "LED %d %d\r\n"          - Multiple integers (params.values array)
            %   "SET %s\r\n"             - String parameter (params.text)
            
            % Check if connected
            if ~self.isConnected
                error('SerialPlugin:NotConnected', ...
                    '[%s] Device not connected', self.name);
            end
            
            % Check if command exists
            if ~self.commands.isKey(command)
                error('SerialPlugin:UnknownCommand', ...
                    '[%s] Unknown command: %s', self.name, command);
            end
            
            % Get command string
            cmdString = self.commands(command);
            
            % Format command with parameters if needed
            if contains(cmdString, '%')
                if ~exist('params', 'var') || isempty(params)
                    error('SerialPlugin:MissingParameters', ...
                        '[%s] Command "%s" requires parameters', self.name, command);
                end
                cmdString = self.formatCommand(cmdString, params);
            end
            
            % Log command
            self.logger.log('DEBUG', sprintf('[%s] Sending: %s', ...
                self.name, strrep(cmdString, sprintf('\r\n'), '<CRLF>')));
            
            try
                % Send command
                write(self.serialPort, cmdString, 'string');
                
                % Wait briefly for device to process
                pause(0.01);
                
                % Read response if available
                if self.serialPort.NumBytesAvailable > 0
                    response = readline(self.serialPort);
                    self.logger.log('INFO', sprintf('[%s] Response: %s', ...
                        self.name, response));
                    result = char(response);
                else
                    result = [];
                end
                
            catch ME
                self.logger.log('ERROR', sprintf('[%s] Command failed: %s', ...
                    self.name, ME.message));
                
                if self.isCritical
                    rethrow(ME);
                else
                    warning('SerialPlugin:CommandFailed', ...
                        'Non-critical plugin command failed: %s', ME.message);
                    result = [];
                end
            end
        end
        
        function cleanup(self)
            % Close serial connection and clean up resources
            %
            % This method is called during experiment cleanup (posttrial).
            % Subclasses can override to add device-specific cleanup.
            
            if self.isConnected
                try
                    self.logger.log('INFO', sprintf('[%s] Closing serial connection...', ...
                        self.name));
                    
                    % Subclasses should implement closeConnection()
                    self.closeConnection();
                    
                    self.isConnected = false;
                    self.logger.log('INFO', sprintf('[%s] Connection closed', self.name));
                    
                catch ME
                    self.logger.log('WARNING', sprintf('[%s] Error during cleanup: %s', ...
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
            status.baudrate = self.baudrate;
            status.critical = self.isCritical;
            status.connected = self.isConnected;
            status.num_commands = self.commands.Count;
            status.command_names = keys(self.commands);
        end
        
        function type = getPluginType(self)
            % Get plugin type identifier
            %
            % Returns:
            %   type: String "serial_device"
            
            type = 'serial_device';
        end
    end
    
    methods (Access = private)
        function validateDefinition(self)
            % Validate that required fields are present in definition
            %
            % Throws:
            %   Error if required fields are missing
            
            if ~isfield(self.definition, 'port')
                error('SerialPlugin:MissingField', ...
                    'Plugin "%s" missing required field: port', self.name);
            end
            
            if ~isfield(self.definition, 'commands')
                error('SerialPlugin:MissingField', ...
                    'Plugin "%s" missing required field: commands', self.name);
            end
            
            if ~isstruct(self.definition.commands)
                error('SerialPlugin:InvalidField', ...
                    'Plugin "%s" commands field must be a struct', self.name);
            end
        end
        
        function extractConfiguration(self)
            % Extract configuration from YAML definition
            
            % Required: port
            self.port = self.definition.port;
            
            % Optional: baudrate (default 9600)
            if isfield(self.definition, 'baudrate')
                self.baudrate = self.definition.baudrate;
            else
                self.baudrate = 9600;
            end
            
            % Optional: critical flag (default false)
            if isfield(self.definition, 'critical')
                self.isCritical = self.definition.critical;
            else
                self.isCritical = false;
            end

            if isfield(self.definition.config, 'experimentDir')
                self.experimentDir = self.definition.config.experimentDir;
            else
                self.experimentDir = pwd;
            end


        end
        
        function loadCommands(self)
            % Load command definitions from YAML
            %
            % Commands are stored in a containers.Map for fast lookup.
            % Each command maps to a string that will be sent to the device.
            
            commandFields = fieldnames(self.definition.commands);
            
            for i = 1:length(commandFields)
                cmdName = commandFields{i};
                cmdString = self.definition.commands.(cmdName);
                
                % Validate command string
                if ~ischar(cmdString) && ~isstring(cmdString)
                    error('SerialPlugin:InvalidCommand', ...
                        'Command "%s" must be a string', cmdName);
                end
                
                % Store in map
                self.commands(cmdName) = char(cmdString);
                
                self.logger.log('DEBUG', sprintf('[%s] Loaded command: %s -> %s', ...
                    self.name, cmdName, strrep(cmdString, sprintf('\r\n'), '<CRLF>')));
            end
        end
        
        function openConnection(self)
            % Open serial connection using MATLAB serialport
            %
            % Creates a serialport object and configures it for communication.
            
            try
                self.serialPort = serialport(self.port, self.baudrate);
                configureTerminator(self.serialPort, "CR/LF");
                
                % Set timeout
                self.serialPort.Timeout = 1;
                
            catch ME
                error('SerialPlugin:ConnectionFailed', ...
                    'Failed to open serial port %s: %s', self.port, ME.message);
            end
        end
        
        function closeConnection(self)
            % Close serial connection
            %
            % Deletes the serialport object and clears the reference.
            
            if ~isempty(self.serialPort)
                try
                    delete(self.serialPort);
                catch ME
                    self.logger.log('WARNING', sprintf('[%s] Error closing port: %s', ...
                        self.name, ME.message));
                end
                self.serialPort = [];
            end
        end
        
        function cmdString = formatCommand(self, template, params)
            % Format command string with parameters
            %
            % Args:
            %   template: Command string template with format specifiers
            %   params: Struct with parameter values
            %
            % Returns:
            %   cmdString: Formatted command string
            %
            % Supported patterns:
            %   %d - Single integer from params.value
            %   Multiple %d - Integers from params.values array
            %   %s - String from params.text
            
            % Count format specifiers
            numSpecs = length(regexp(template, '%[ds]'));
            
            if numSpecs == 0
                % No formatting needed
                cmdString = template;
                
            elseif numSpecs == 1
                % Single parameter
                if contains(template, '%d')
                    % Integer parameter
                    if isfield(params, 'value')
                        cmdString = sprintf(template, params.value);
                    else
                        error('SerialPlugin:MissingParameter', ...
                            'Command requires params.value');
                    end
                elseif contains(template, '%s')
                    % String parameter
                    if isfield(params, 'text')
                        cmdString = sprintf(template, params.text);
                    else
                        error('SerialPlugin:MissingParameter', ...
                            'Command requires params.text');
                    end
                end
                
            else
                % Multiple parameters - use values array
                if ~isfield(params, 'values')
                    error('SerialPlugin:MissingParameter', ...
                        'Command with multiple format specifiers requires params.values array');
                end
                
                if length(params.values) ~= numSpecs
                    error('SerialPlugin:ParameterMismatch', ...
                        'Expected %d values, got %d', numSpecs, length(params.values));
                end
                
                cmdString = sprintf(template, params.values{:});
            end
        end
    end
end

classdef BiasPlugin < handle
    % Plugin for BIAS camera control using BiasControl class
    %
    % This plugin wraps the BiasControl camera interface for use in
    % G4.1 experiments. It manages camera initialization, video capture,
    % and timestamp logging.
    %
    % YAML Definition Format:
    %   plugins:
    %     - name: "bias_camera"
    %       type: "class"
    %       matlab:
    %         class: "BiasPlugin"
    %       config:
    %         bias_executable: "C:/path/to/BIAS/test_gui.exe"
    %         log_file: "./logs/bias_timestamps.log"  # Optional, for timestamp logging
    %
    % Available Commands:
    %   - connect: Initialize BiasControl connection
    %     Params: ip (string), port (integer)
    %     Example:
    %       - type: "plugin"
    %         plugin_name: "bias_camera"
    %         command_name: "connect"
    %         params:
    %           ip: "127.0.0.1"
    %           port: 5010
    %
    %   - loadConfiguration: Load BIAS configuration from JSON file
    %     Params: config_path (string)
    %     Example:
    %       - type: "plugin"
    %         plugin_name: "bias_camera"
    %         command_name: "loadConfiguration"
    %         params:
    %           config_path: "./config/bias_config.json"
    %
    %   - enableLogging: Enable BIAS logging
    %     Params: none
    %
    %   - disableLogging: Disable BIAS logging
    %     Params: none
    %
    %   - setVideoFile: Set output video filename
    %     Params: filename (string)
    %     Example:
    %       - type: "plugin"
    %         plugin_name: "bias_camera"
    %         command_name: "setVideoFile"
    %         params:
    %           filename: "trial_001.avi"
    %
    %   - startCapture: Start video capture
    %     Params: none
    %
    %   - stopCapture: Stop video capture
    %     Params: none
    %
    %   - getTimestamp: Get current timestamp and frame count
    %     Params: none
    %     Returns: Struct with .timestamp and .frame_count fields
    %     Note: This command logs the timestamp/frame to both the main
    %           experiment log and a separate BIAS log file
    %
    %   - preview: Show camera preview
    %     Params: none
    %
    %   - stop: Stop camera preview
    %     Params: none
    %
    % Notes:
    %   - The BIAS executable must be started separately before connecting
    %   - Timestamps are automatically logged when getTimestamp is called
    %   - All BIAS responses are logged to the experiment logger
    
    properties (Access = private)
        name              % Plugin name
        config            % Plugin configuration from YAML
        logger            % Logger instance
        biasControl       % BiasControl instance
        biasExecutable    % Path to BIAS executable
        biasLogFile       % Path to BIAS timestamp log file (optional)
        isConnected       % Connection status flag
    end
    
    methods
        function self = BiasPlugin(name, config, logger)
            % BIASPLUGIN Constructor
            %
            % Args:
            %   name: Plugin name (string)
            %   config: config section from yaml's class definition
            %   logger: Logger instance
            
            self.name = name;
            self.config = config;
            self.logger = logger;
            self.isConnected = false;
            
            % Extract configuration
            self.extractConfiguration();
            
            % Launch BIAS executable if provided
            if ~isempty(self.biasExecutable)
                self.launchBiasExecutable();
            end
            
            self.logger.log('INFO', sprintf('[%s] BiasPlugin created', self.name));
        end
        
        function initialize(self)
            % Initialize the plugin
            %
            % Note: Actual connection happens via the 'connect' command
            % since it requires runtime parameters (ip, port)
            
            self.logger.log('INFO', sprintf('[%s] BiasPlugin initialized', self.name));
        end
        
        function result = execute(self, command, params)
            % Execute a command on the BIAS camera
            %
            % Args:
            %   command: Command name (string)
            %   params: Parameter struct (optional)
            %
            % Returns:
            %   result: Command result (varies by command)
            
            if ~exist('params', 'var')
                params = struct();
            end
            
            result = [];
            
            try
                switch command
                    case 'connect'
                        result = self.cmdConnect(params);
                        
                    case 'loadConfiguration'
                        result = self.cmdLoadConfiguration(params);
                        
                    case 'enableLogging'
                        result = self.cmdEnableLogging();
                        
                    case 'disableLogging'
                        result = self.cmdDisableLogging();
                        
                    case 'setVideoFile'
                        result = self.cmdSetVideoFile(params);
                        
                    case 'startCapture'
                        result = self.cmdStartCapture();
                        
                    case 'stopCapture'
                        result = self.cmdStopCapture();
                        
                    case 'getTimestamp'
                        result = self.cmdGetTimestamp();
                        
                    case 'preview'
                        result = self.cmdPreview();
                        
                    case 'stop'
                        result = self.cmdStop();
                        
                    otherwise
                        error('Unknown command: %s', command);
                end
                
                self.logger.log('DEBUG', sprintf('[%s] Command completed: %s', ...
                    self.name, command));
                
            catch ME
                self.logger.log('ERROR', sprintf('[%s] Command failed: %s - %s', ...
                    self.name, command, ME.message));
                rethrow(ME);
            end
        end
        
        function cleanup(self)
            % Clean up the plugin
            %
            % Disconnects from BIAS and closes log file
            
            if self.isConnected && ~isempty(self.biasControl)
                try
                    self.logger.log('INFO', sprintf('[%s] Disconnecting from BIAS', ...
                        self.name));
                    
                    % BiasControl doesn't have explicit disconnect method
                    % Just clear the object
                    self.biasControl = [];
                    self.isConnected = false;
                    
                    self.logger.log('INFO', sprintf('[%s] BIAS disconnected', ...
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
            status.isConnected = self.isConnected;
            status.hasBiasControl = ~isempty(self.biasControl);
            status.biasExecutable = self.biasExecutable;
            status.logFile = self.biasLogFile;
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
        function extractConfiguration(self)
            % Extract configuration from plugin definition
            
            
                
            % BIAS executable path (required)
            if isfield(self.config, 'bias_executable')
                self.biasExecutable = self.config.bias_executable;
            else
                error('[%s] Missing required config field: bias_executable', ...
                    self.name);
            end
            
            % Optional log file for timestamps
            if isfield(self.config, 'log_file')
                self.biasLogFile = self.config.log_file;
            else
                self.biasLogFile = '';
            end
            
        end
        
        function launchBiasExecutable(self)
            % Launch the BIAS GUI executable
            
            if ~exist(self.biasExecutable, 'file')
                error('[%s] BIAS executable not found: %s', ...
                    self.name, self.biasExecutable);
            end
            
            self.logger.log('INFO', sprintf('[%s] Launching BIAS executable: %s', ...
                self.name, self.biasExecutable));
            
            try
                cmdString = ['cmd /C "', self.biasExecutable, '" && exit &'];
                system(cmdString);
                
                % Give BIAS time to start up
                pause(2);
                
                self.logger.log('INFO', sprintf('[%s] BIAS executable launched', ...
                    self.name));
                
            catch ME
                error('[%s] Failed to launch BIAS executable: %s', ...
                    self.name, ME.message);
            end
        end
        
        % Command implementations
        
        function result = cmdConnect(self, params)
            % Connect to BIAS
            %
            % Required params:
            %   ip - IP address (string)
            %   port - Port number (integer)
            
            if ~isfield(params, 'ip') || ~isfield(params, 'port')
                error('[%s] connect command requires ip and port parameters', ...
                    self.name);
            end
            
            ip = params.ip;
            port = params.port;
            
            self.logger.log('INFO', sprintf('[%s] Connecting to BIAS at %s:%d', ...
                self.name, ip, port));
            
            % Create BiasControl instance
            self.biasControl = BiasControl(ip, port);
            
            % Connect
            self.biasControl.connect();
            self.isConnected = true;
            
            self.logger.log('INFO', sprintf('[%s] Connected to BIAS', self.name));
            
            result = true;
        end
        
        function result = cmdLoadConfiguration(self, params)
            % Load BIAS configuration from JSON file
            %
            % Required params:
            %   config_path - Path to JSON config file (string)
            
            self.assertConnected();
            
            if ~isfield(params, 'config_path')
                error('[%s] loadConfiguration requires config_path parameter', ...
                    self.name);
            end
            
            configPath = params.config_path;
            
            if ~exist(configPath, 'file')
                error('[%s] Configuration file not found: %s', ...
                    self.name, configPath);
            end
            
            self.logger.log('INFO', sprintf('[%s] Loading configuration: %s', ...
                self.name, configPath));
            
            self.biasControl.loadConfiguration(configPath);
            
            self.logger.log('INFO', sprintf('[%s] Configuration loaded', self.name));
            
            result = true;
        end
        
        function result = cmdEnableLogging(self)
            % Enable BIAS logging
            
            self.assertConnected();
            
            self.logger.log('INFO', sprintf('[%s] Enabling BIAS logging', self.name));
            
            self.biasControl.enableLogging();
            
            result = true;
        end
        
        function result = cmdDisableLogging(self)
            % Disable BIAS logging
            
            self.assertConnected();
            
            self.logger.log('INFO', sprintf('[%s] Disabling BIAS logging', self.name));
            
            self.biasControl.disableLogging();
            
            result = true;
        end
        
        function result = cmdSetVideoFile(self, params)
            % Set output video filename
            %
            % Required params:
            %   filename - Video filename (string)
            
            self.assertConnected();
            
            if ~isfield(params, 'filename')
                error('[%s] setVideoFile requires filename parameter', self.name);
            end
            
            filename = params.filename;
            
            self.logger.log('INFO', sprintf('[%s] Setting video file: %s', ...
                self.name, filename));
            
            self.biasControl.setVideoFile(filename);
            
            result = true;
        end
        
        function result = cmdStartCapture(self)
            % Start video capture
            
            self.assertConnected();
            
            self.logger.log('INFO', sprintf('[%s] Starting video capture', self.name));
            
            self.biasControl.startCapture();
            
            result = true;
        end
        
        function result = cmdStopCapture(self)
            % Stop video capture
            
            self.assertConnected();
            
            self.logger.log('INFO', sprintf('[%s] Stopping video capture', self.name));
            
            self.biasControl.stopCapture();
            
            result = true;
        end
        
        function result = cmdGetTimestamp(self)
            % Get current timestamp and frame count
            %
            % Returns:
            %   result - Struct with .timestamp and .frame_count fields
            %
            % Also logs timestamp to experiment log and BIAS log file
            
            self.assertConnected();
            
            % Get timestamp and frame count from BIAS
            timestampObj = self.biasControl.getTimeStamp();
            frameCountObj = self.biasControl.getFrameCount();
            
            timestamp = timestampObj.value;
            frameCount = frameCountObj.value;
            
            result = struct();
            result.timestamp = timestamp;
            result.frame_count = frameCount;
            
            % Log to main experiment logger
            self.logger.log('INFO', sprintf('[%s] BIAS Timestamp: %f, Frame: %d', ...
                self.name, timestamp, frameCount));
            
            % Also log to separate BIAS log file if specified
            if ~isempty(self.biasLogFile)
                self.logBiasTimestamp(timestamp, frameCount);
            end
        end
        
        function result = cmdPreview(self)
            % Show camera preview
            
            self.assertConnected();
            
            self.logger.log('INFO', sprintf('[%s] Starting camera preview', self.name));
            
            flyBowl_camera_control(self.biasControl, 'preview');
            
            result = true;
        end
        
        function result = cmdStop(self)
            % Stop camera preview
            
            self.assertConnected();
            
            self.logger.log('INFO', sprintf('[%s] Stopping camera preview', self.name));
            
            flyBowl_camera_control(self.biasControl, 'stop');
            
            result = true;
        end
        
        function assertConnected(self)
            % Assert that BIAS is connected
            
            if ~self.isConnected || isempty(self.biasControl)
                error('[%s] Not connected to BIAS. Call connect command first.', ...
                    self.name);
            end
        end
        
        function logBiasTimestamp(self, timestamp, frameCount)
            % Log timestamp and frame count to separate BIAS log file
            %
            % Args:
            %   timestamp - Timestamp value
            %   frameCount - Frame count value
            
            try
                % Create log directory if needed
                [logDir, ~, ~] = fileparts(self.biasLogFile);
                if ~isempty(logDir) && ~exist(logDir, 'dir')
                    mkdir(logDir);
                end
                
                % Append to log file
                fid = fopen(self.biasLogFile, 'a');
                if fid == -1
                    self.logger.log('WARNING', sprintf('[%s] Failed to open BIAS log file: %s', ...
                        self.name, self.biasLogFile));
                    return;
                end
                
                % Write timestamp with current date/time
                fprintf(fid, '%s\tTimestamp: %f\tFrame: %d\n', ...
                    datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF'), ...
                    timestamp, frameCount);
                
                fclose(fid);
                
            catch ME
                self.logger.log('WARNING', sprintf('[%s] Failed to write to BIAS log: %s', ...
                    self.name, ME.message));
            end
        end
    end
end

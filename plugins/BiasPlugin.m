classdef BiasPlugin < handle
    % Plugin for BIAS camera control using BiasControl class
    %
    % This plugin wraps the BiasControl camera interface for use in
    % G4.1 experiments. It provides both low-level control commands
    % and high-level convenience commands for common workflows.
    %
    % YAML Definition Format:
    %   plugins:
    %     - name: "bias_camera"
    %       type: "class"
    %       matlab:
    %         class: "BiasPlugin"
    %       config:
    %         bias_executable: "C:/path/to/BIAS/test_gui.exe"
    %         log_file: "./logs/bias_timestamps.log"  % Optional
    %         video_extension: ".avi"  % Optional, default .avi
    %
    % Available Commands:
    %
    % === HIGH-LEVEL COMMANDS (Recommended for most users) ===
    %
    %   - startPreview: Start camera preview without recording
    %     Params: none
    %     Example:
    %       - type: "plugin"
    %         plugin_name: "bias_camera"
    %         command_name: "startPreview"
    %
    %   - startRecording: Start video capture with recording to file
    %     Params: filename (string) - video filename (extension optional)
    %     Example:
    %       - type: "plugin"
    %         plugin_name: "bias_camera"
    %         command_name: "startRecording"
    %         params:
    %           filename: "trial_001"  % or "trial_001.avi"
    %
    %   - stopRecording: Stop recording but keep camera capturing
    %     Params: none
    %     Example:
    %       - type: "plugin"
    %         plugin_name: "bias_camera"
    %         command_name: "stopRecording"
    %
    %   - stopCapture: Stop video capture completely
    %     Params: none
    %     Example:
    %       - type: "plugin"
    %         plugin_name: "bias_camera"
    %         command_name: "stopCapture"
    %
    %   - saveConfig: Save current BIAS configuration to JSON file
    %     Params: config_file (string, optional) - defaults to "bias_config.json"
    %     Example:
    %       - type: "plugin"
    %         plugin_name: "bias_camera"
    %         command_name: "saveConfig"
    %         params:
    %           config_file: "my_config.json"
    %
    %   - disconnect: Disconnect from BIAS and cleanup
    %     Params: none
    %     Example:
    %       - type: "plugin"
    %         plugin_name: "bias_camera"
    %         command_name: "disconnect"
    %
    % === LOW-LEVEL COMMANDS (Advanced users) ===
    %
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
    %   - enableLogging: Enable BIAS logging (recording to file)
    %     Params: none
    %     Example:
    %       - type: "plugin"
    %         plugin_name: "bias_camera"
    %         command_name: "enableLogging"
    %
    %   - disableLogging: Disable BIAS logging
    %     Params: none
    %     Example:
    %       - type: "plugin"
    %         plugin_name: "bias_camera"
    %         command_name: "disableLogging"
    %
    %   - setVideoFile: Set output video filename
    %     Params: filename (string)
    %     Note: Can use full path or relative filename
    %     Example:
    %       - type: "plugin"
    %         plugin_name: "bias_camera"
    %         command_name: "setVideoFile"
    %         params:
    %           filename: "trial_001.avi"  % Uses experiment folder
    %           % OR
    %           filename: "C:/full/path/to/video.avi"  % Full path
    %
    %   - startCapture: Start video capture
    %     Params: none
    %     Example:
    %       - type: "plugin"
    %         plugin_name: "bias_camera"
    %         command_name: "startCapture"
    %
    %   - getTimestamp: Get current timestamp and frame count
    %     Params: none
    %     Returns: Struct with .timestamp and .frame_count fields
    %     Note: This command logs the timestamp/frame to both the main
    %           experiment log and a separate BIAS log file
    %     Example:
    %       - type: "plugin"
    %         plugin_name: "bias_camera"
    %         command_name: "getTimestamp"
    %
    % Notes:
    %   - High-level commands bundle multiple operations for convenience
    %   - Low-level commands provide direct access to BiasControl methods
    %   - Video files saved via startRecording use the experiment folder
    %   - setVideoFile can use full paths for custom locations
    %   - All BIAS responses are logged to the experiment logger
    
    properties (Access = private)
        name              % Plugin name
        config            % Plugin configuration from YAML
        logger            % Logger instance
        biasControl       % BiasControl instance
        biasExecutable    % Path to BIAS executable
        biasLogFile       % Path to BIAS timestamp log file (optional)
        experimentDir     % Path to experiment folder for saving videos
        isCritical        % A failure of the camera halts the experiment if true. Default: true
        isConnected       % Connection status flag
        isRecording       % Recording status flag
        isCapturing       % Capture status flag
        videoExtension    % Default video file extension
    end
    
    methods
        function self = BiasPlugin(name, config, logger)
            % BIASPLUGIN Constructor
            %
            % Args:
            %   name: Plugin name (string)
            %   config: config section from yaml's class definition
            %   logger: Logger instance
            %   experiment_folder: Path to experiment folder (string, optional)
            
            self.name = name;
            self.config = config;
            self.logger = logger;
            self.isConnected = false;
            self.isRecording = false;
            self.isCapturing = false;
            self.videoExtension = '.avi';  % Default extension
            
            
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
                    % Connection and configuration
                    case 'connect'
                        result = self.cmdConnect(params);
                    case 'loadConfiguration'
                        result = self.cmdLoadConfiguration(params);
                    
                    % Low-level control commands
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
                    
                    % High-level convenience commands
                    case 'startPreview'
                        result = self.cmdStartPreview();
                    case 'startRecording'
                        result = self.cmdStartRecording(params);
                    case 'stopRecording'
                        result = self.cmdStopRecording();
                    case 'saveConfig'
                        result = self.cmdSaveConfig(params);
                    case 'disconnect'
                        result = self.cmdDisconnect();
                        
                    otherwise
                        error('BiasPlugin:UnknownCommand', ...
                              'Unknown BIAS camera command: %s', command);
                end
                
                self.logger.log('DEBUG', sprintf('[%s] Command completed: %s', ...
                    self.name, command));
                
            catch ME

                if self.isCritical
                    self.logger.log('ERROR', sprintf('[%s] Command failed: %s - %s', ...
                    self.name, command, ME.message));
                    rethrow(ME);
                else
                    self.logger.log('WARNING', sprintf('[%s] Non-critical plugin error, continuing experiment...', ...
                        self.name));
                end
                
            end
        end
        
        function cleanup(self)
            % Clean up the plugin
            %
            % Stops capture and disconnects from BIAS
            
            if self.isConnected && ~isempty(self.biasControl)
                try
                    self.logger.log('INFO', sprintf('[%s] Cleaning up BIAS plugin', ...
                        self.name));
                    
                    % Stop capture if still running
                    if self.isCapturing
                        self.biasControl.stopCapture();
                    end
                    
                    % Disconnect
                    self.biasControl.disconnect();
                    self.biasControl.closeWindow();
                    
                    self.biasControl = [];
                    self.isConnected = false;
                    self.isRecording = false;
                    self.isCapturing = false;
                    
                    self.logger.log('INFO', sprintf('[%s] BIAS cleanup complete', ...
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
            status.isCritical = self.isCritical;
            status.isConnected = self.isConnected;
            status.isRecording = self.isRecording;
            status.isCapturing = self.isCapturing;
            status.hasBiasControl = ~isempty(self.biasControl);
            status.biasExecutable = self.biasExecutable;
            status.logFile = self.biasLogFile;
            status.experimentFolder = self.experimentDir;
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
            
            % Extract BIAS executable path
            if isfield(self.config, 'bias_executable')
                self.biasExecutable = self.config.bias_executable;
            else
                self.logger.log('ERROR', sprintf('[%s] No BIAS executable defined.', ...
                    self.name));
                error('BiasPlugin:MissingExecutable', ...
                      '[%s] requires an executable file to run.', ...
                      self.name);
            end
            
            % Extract experiment directory
            if isfield(self.config, 'experimentDir')
                self.experimentDir = self.config.experimentDir;
            else
                self.experimentDir = pwd;
            end

            if isfield(self.config, 'log_file')
                self.biasLogFile = self.config.log_file;
            else
                %default to experimentDir/logs/<pluginName>_<timestamp>.log
                ts = char(datetime('now','Format','yyyyMMdd_HHmmss'));
                self.biasLogFile = fullfile(self.experimentDir, 'logs', sprintf('%s_%s.log', self.name, ts));
            end
            
            % Extract video extension if provided
            if isfield(self.config, 'video_extension')
                ext = self.config.video_extension;
                if ~startsWith(ext, '.')
                    ext = ['.' ext];
                end
                self.videoExtension = ext;
            end

             % Optional: critical flag (default true)
            if isfield(self.config, 'critical')
                self.isCritical = self.config.critical;
            else
                self.isCritical = true;
            end
        end
        
        function launchBiasExecutable(self)
            % Launch BIAS executable if not already running
            
            if ~exist(self.biasExecutable, 'file')
                self.logger.log('WARNING', sprintf('[%s] BIAS executable not found: %s', ...
                    self.name, self.biasExecutable));
                return;
            end
            
            self.logger.log('INFO', sprintf('[%s] Launching BIAS executable: %s', ...
                self.name, self.biasExecutable));
            
            try
                % Launch BIAS in background
                if ispc()
                    system(['start "" "' self.biasExecutable '"']);
                else
                    system([self.biasExecutable ' &']);
                end
                
                % Give BIAS time to start up
                pause(2);
                
                self.logger.log('INFO', sprintf('[%s] BIAS executable launched', ...
                    self.name));
                
            catch ME
                
                if self.isCritical
                    self.logger.log('ERROR', sprintf('Aborting. [%s] executable failed: %s', ...
                    self.name, ME.message));
                    rethrow(ME);
                else
                    self.logger.log('WARNING', sprintf('[%s] Failed to launch BIAS: %s', ...
                    self.name, ME.message));
                end
                
            end
        end
        
        % ===================================================================
        % LOW-LEVEL COMMAND IMPLEMENTATIONS
        % Direct wrappers for BiasControl methods
        % ===================================================================
        
        function result = cmdConnect(self, params)
            % Connect to BIAS
            %
            % Required params:
            %   ip - IP address (string)
            %   port - Port number (integer)
            
            if ~isfield(params, 'ip') || ~isfield(params, 'port')
                error('BiasPlugin:MissingParams', ...
                      '[%s] connect command requires ip and port parameters', ...
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
                error('BiasPlugin:MissingParams', ...
                      '[%s] loadConfiguration requires config_path parameter', ...
                      self.name);
            end
            
            configPath = params.config_path;
            
            if ~exist(configPath, 'file')
                error('BiasPlugin:FileNotFound', ...
                      '[%s] Configuration file not found: %s', ...
                      self.name, configPath);
            end
            
            self.logger.log('INFO', sprintf('[%s] Loading configuration: %s', ...
                self.name, configPath));
            
            self.biasControl.loadConfiguration(configPath);
            
            self.logger.log('INFO', sprintf('[%s] Configuration loaded', self.name));
            
            result = true;
        end
        
        function result = cmdEnableLogging(self)
            % Enable BIAS logging (recording to file)
            
            self.assertConnected();
            
            self.logger.log('INFO', sprintf('[%s] Enabling BIAS logging', self.name));
            
            self.biasControl.enableLogging();
            
            % Update state
            if self.isCapturing
                self.isRecording = true;
            end
            
            result = true;
        end
        
        function result = cmdDisableLogging(self)
            % Disable BIAS logging
            
            self.assertConnected();
            
            self.logger.log('INFO', sprintf('[%s] Disabling BIAS logging', self.name));
            
            self.biasControl.disableLogging();
            
            % Update state
            self.isRecording = false;
            
            result = true;
        end
        
        function result = cmdSetVideoFile(self, params)
            % Set output video filename
            %
            % Required params:
            %   filename - Video filename (string)
            %
            % Notes:
            %   - If filename is not an absolute path and experiment_folder is set,
            %     the file will be saved in the experiment folder
            %   - If filename is an absolute path, it will be used as-is
            %   - Extension is added if missing
            
            self.assertConnected();
            
            if ~isfield(params, 'filename')
                error('BiasPlugin:MissingParams', ...
                      '[%s] setVideoFile requires filename parameter', self.name);
            end
            
            filename = params.filename;
            
            % Determine full path
            if self.isAbsolutePath(filename)
                % Use absolute path as-is
                videoPath = filename;
            else
                % Ensure extension
                filename = self.ensureExtension(filename, self.videoExtension);
                
                % Use experiment folder if available
                if ~isempty(self.experimentDir)
                    videoPath = fullfile(self.experimentDir, 'videos', filename);
                    mkdir(fullfile(self.experimentDir, 'videos'));
                else
                    videoPath = fullfile(pwd, filename);  % Use relative path
                end
            end

            
            
            self.logger.log('INFO', sprintf('[%s] Setting video file: %s', ...
                self.name, videoPath));
            
            self.biasControl.setVideoFile(videoPath);
            
            result = true;
        end
        
        function result = cmdStartCapture(self)
            % Start video capture
            
            self.assertConnected();
            
            self.logger.log('INFO', sprintf('[%s] Starting video capture', self.name));
            
            self.biasControl.startCapture();
            
            % Update state
            self.isCapturing = true;
            % isRecording depends on whether logging is enabled
            
            result = true;
        end
        
        function result = cmdStopCapture(self)
            % Stop video capture
            
            self.assertConnected();
            
            if ~self.isCapturing
                self.logger.log('WARNING', sprintf('[%s] Camera not currently capturing', ...
                    self.name));
                result = false;
                return;
            end
            
            self.logger.log('INFO', sprintf('[%s] Stopping video capture', self.name));
            
            self.biasControl.stopCapture();
            
            % Update state
            self.isCapturing = false;
            self.isRecording = false;
            
            self.logger.log('INFO', sprintf('[%s] Capture stopped', self.name));
            
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
        
        % ===================================================================
        % HIGH-LEVEL COMMAND IMPLEMENTATIONS
        % Convenience commands that bundle common operations
        % ===================================================================
        
        function result = cmdStartPreview(self)
            % Start camera preview without recording
            %
            % Based on FlyBowl 'preview' case:
            %   flea3.disableLogging();
            %   flea3.startCapture();
            
            self.assertConnected();
            
            self.logger.log('INFO', sprintf('[%s] Starting camera preview', self.name));
            
            % Call low-level commands
            self.cmdDisableLogging();
            self.cmdStartCapture();
            
            self.logger.log('INFO', sprintf('[%s] Preview started', self.name));
            
            result = true;
        end
        
        function result = cmdStartRecording(self, params)
            % Start video capture with recording to file
            %
            % Required params:
            %   filename - Video filename (string, extension optional)
            %
            % Based on FlyBowl 'start' case:
            %   flea3.setVideoFile(param);
            %   flea3.enableLogging();
            %   flea3.startCapture();
            
            self.assertConnected();
            
            if ~isfield(params, 'filename')
                error('BiasPlugin:MissingParams', ...
                      '[%s] startRecording requires filename parameter', ...
                      self.name);
            end
            
            % Check if experiment folder is set (unless using absolute path)
            filename = params.filename;
            if ~self.isAbsolutePath(filename) && isempty(self.experimentDir)
                self.logger.log('WARNING', sprintf('[%s] Experiment folder not set, using relative path', ...
                    self.name));
            end
            
            self.logger.log('INFO', sprintf('[%s] Starting recording: %s', ...
                self.name, filename));
            
            % Call low-level commands
            self.cmdSetVideoFile(params);
            self.cmdEnableLogging();
            self.cmdStartCapture();
            
            self.logger.log('INFO', sprintf('[%s] Recording started', self.name));
            
            result = true;
        end
        
        function result = cmdStopRecording(self)
            % Stop recording but keep camera capturing
            %
            % Disables logging while camera continues to run
            
            self.assertConnected();
            
            if ~self.isRecording
                self.logger.log('WARNING', sprintf('[%s] Not currently recording', ...
                    self.name));
                result = false;
                return;
            end
            
            self.logger.log('INFO', sprintf('[%s] Stopping recording', self.name));
            
            % Call low-level command
            self.cmdDisableLogging();
            
            self.logger.log('INFO', sprintf('[%s] Recording stopped (camera still capturing)', ...
                self.name));
            
            result = true;
        end
        
        function result = cmdSaveConfig(self, params)
            % Save current BIAS configuration to JSON file
            %
            % Optional params:
            %   config_file - Name of config file (string, defaults to "bias_config.json")
            %
            % Based on FlyBowl 'saveconfig' case:
            %   flea3.saveConfiguration(param);
            
            self.assertConnected();
            
            % Get config filename (use default if not provided)
            if isfield(params, 'config_file')
                configFile = params.config_file;
            else
                configFile = 'bias_config.json';
            end
            
            % Construct full path in experiment folder if available
            if ~isempty(self.experimentDir)
                configPath = fullfile(self.experimentDir, configFile);
            else
                configPath = configFile;  % Save in current directory
            end
            
            self.logger.log('INFO', sprintf('[%s] Saving configuration to: %s', ...
                self.name, configPath));
            
            % Save configuration
            self.biasControl.saveConfiguration(configPath);
            
            self.logger.log('INFO', sprintf('[%s] Configuration saved', self.name));
            
            result = true;
        end
        
        function result = cmdDisconnect(self)
            % Disconnect from BIAS and cleanup
            %
            % Based on FlyBowl 'disconnect' case:
            %   flea3.stopCapture();
            %   flea3.disconnect();
            %   flea3.closeWindow();
            
            self.assertConnected();
            
            self.logger.log('INFO', sprintf('[%s] Disconnecting from BIAS', self.name));
            
            % Stop capture if still running
            if self.isCapturing
                self.cmdStopCapture();
            end
            
            % Disconnect
            self.biasControl.disconnect();
            self.biasControl.closeWindow();
            
            self.isConnected = false;
            self.isRecording = false;
            self.isCapturing = false;
            
            self.logger.log('INFO', sprintf('[%s] Disconnected from BIAS', self.name));
            
            result = true;
        end
        
        % ===================================================================
        % HELPER METHODS
        % ===================================================================
        
        function assertConnected(self)
            % Assert that BIAS is connected
            
            if ~self.isConnected || isempty(self.biasControl)
                error('BiasPlugin:NotConnected', ...
                      '[%s] Not connected to BIAS. Call connect command first.', ...
                      self.name);
            end
        end
        
        function filename = ensureExtension(self, filename, extension)
            % Ensure filename has the correct extension
            %
            % Args:
            %   filename - Input filename (string)
            %   extension - Desired extension including dot (string)
            %
            % Returns:
            %   filename - Filename with correct extension (string)
            
            [~, ~, ext] = fileparts(filename);
            
            if isempty(ext)
                % No extension, add it
                filename = [filename, extension];
            elseif ~strcmpi(ext, extension)
                % Wrong extension, warn but keep it
                self.logger.log('WARNING', sprintf('[%s] File has extension %s, expected %s', ...
                    self.name, ext, extension));
            end
        end
        
        function isAbs = isAbsolutePath(self, filepath)
            % Check if filepath is absolute
            %
            % Args:
            %   filepath - File path to check (string)
            %
            % Returns:
            %   isAbs - True if absolute path (boolean)
            
            if ispc()
                % Windows: Check for drive letter (C:\) or UNC path (\\)
                isAbs = ~isempty(regexp(filepath, '^[a-zA-Z]:\\', 'once')) || ...
                        startsWith(filepath, '\\');
            else
                % Unix/Mac: Check for leading /
                isAbs = startsWith(filepath, '/');
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

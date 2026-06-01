classdef DAQThermometerPlugin < handle
    % DAQ-based thermocouple plugin for temperature monitoring during experiments
    %
    % Wraps the MATLAB Data Acquisition Toolbox to read temperature from a
    % National Instruments CompactDAQ thermocouple module. Supports 1 to 4
    % channels on a single module. All hardware identity fields are
    % rig-configurable; the class code never needs to change between setups.
    %
    % Required MATLAB Toolbox: Data Acquisition Toolbox (R2020a or later)
    %
    % Rig YAML Config Fields:
    %   enabled: true     - Whether the thermometer is in use for this
    %                       experiment [required]
    %   type: "DAQ Thermometer" - Identifier in case more than one type of
    %                           hardware is used for this purpose in the
    %                           future [required]
    %   device_id         - NI module ID (e.g. 'cDAQ1Mod4')          [required]
    %   channels          - List of channel strings (1-4 supported)  [required]
    %     - "ai0"
    %     - "ai2"        
    %   measurement_type  - Type of measurement (default: 'Thermocouple')
    %   thermocouple_type - Thermocouple type string (default: 'K')
    %   sample_rate       - Samples per second (default: 7)
    %   sample_duration   - Default read duration in seconds (default: 1.0)
    %   generate_plots    - Save plots by default (default: true)
    %   vendor            - DAQ vendor string (default: 'ni')
    %
    %   ALL RIG YAML CONFIGURATION VALUES CAN BE OVERRIDED BY INCLUDING
    %   THEM IN THE EXPERIMENT YAML'S TEMPERATURE CONFIG.
    %
    % Commands:
    %   get_temperature          - Blocking read for sample_duration seconds;
    %                              logs and returns mean per channel. Intended
    %                              for between-trial passive monitoring.
    %   log_temperature          - Blocking read; logs mean/min/max per channel
    %                              and optionally saves a plot. Intended for
    %                              pre/post-experiment records.
    %   startContinuousLogging   - Starts non-blocking background acquisition at
    %                              the configured sample_rate. Each sample fires a
    %                              callback that writes one row to a CSV file.
    %                              Returns immediately; does not block execution.
    %                              Cannot be combined with get_temperature or
    %                              log_temperature while active.
    %   stopContinuousLogging    - Stops background acquisition and closes the
    %                              CSV file. Called automatically by cleanup() if
    %                              still running at experiment end.
    %
    % Optional Command Params:
    %   sample_duration  - Override config default read duration
    %                      (get_temperature and log_temperature only)
    %   generate_plots   - Override config plot default (log_temperature only)
    %   filename         - Full path for the CSV log file
    %                      (startContinuousLogging only; default: auto-named
    %                       temperature_YYYYMMDD_HHMMSS.csv in saveDir)
    %
    % Experiment YAML Example:
    %   
    %   plugins: 
    %     - name: "thermometer"
    %       type: "class"
    %       matlab:
    %         class: "DAQThermometerPlugin"
    % 
    %   pretrial:
    %     commands:
    %       - type: "plugin"
    %         plugin_name: "thermometer"
    %         command_name: "log_temperature"
    %         params:
    %           sample_duration: 30.0
    %   intertrial:
    %     commands:
    %       - type: "plugin"
    %         plugin_name: "thermometer"
    %         command_name: "get_temperature"
    %   posttrial:
    %     commands:
    %       - type: "plugin"
    %         plugin_name: "thermometer"
    %         command_name: "log_temperature"
    %         params:
    %           sample_duration: 30.0

    properties (Access = private)
        name                    % Plugin name string
        config                  % Config struct from rig YAML
        logger                  % ExperimentLogger instance
        daqSession              % daq session object
        isConnected             % logical: true after successful initialize()
        vendor                  % DAQ vendor string
        deviceId                % NI module ID string
        measurementType         % Measurement type string (default: 'Thermocouple')
        thermocoupleType        % Thermocouple type string (e.g. 'K')
        sampleRate              % Samples per second
        channels                % Cell array of one to four channel strings 
        numChannels             % Number of configured channels
        defaultSampleDuration   % Default read duration in seconds
        defaultGeneratePlots    % Default plot-saving behaviour (logical)
        saveDir                 % Directory for plot output
        % --- Continuous logging state ---
        isLogging               % logical: true while startContinuousLogging is active
        logFileId               % file handle for continuous CSV log (-1 when closed)
        logFilePath             % full path of the active continuous log CSV
        continuousTic           % tic handle used for elapsed timestamps in callback
    end

    methods (Access = public)

        function self = DAQThermometerPlugin(name, config, logger)
            % Constructor - parses config; does not open hardware
            %
            % Args:
            %   name   - Plugin name string
            %   config - Config struct from rig YAML
            %   logger - ExperimentLogger instance

            self.name        = name;
            self.config      = config;
            self.logger      = logger;
            self.isConnected = false;
            self.isLogging   = false;
            self.logFileId   = -1;
            self.logFilePath = '';

            self.extractConfig();
        end

        function initialize(self)
            % Open DAQ session, set sample rate, and register all channels
            %
            % Creates the daq() session and calls addinput() once per
            % configured channel, applying thermocouple type and Celsius
            % units to each. Called by PluginManager before any experiment
            % commands are executed.
            %
            % Throws on failure so PluginManager can prompt for retry.

            self.logger.log('INFO', sprintf( ...
                '[%s] Initializing DAQ session (vendor: %s, device: %s, type: %s, rate: %g Hz, channels: %d)', ...
                self.name, self.vendor, self.deviceId, ...
                self.measurementType, self.sampleRate, self.numChannels));

            self.daqSession = daq(self.vendor);
            self.daqSession.Rate = self.sampleRate;

            for i = 1:self.numChannels
                ch = addinput(self.daqSession, self.deviceId, self.channels{i}, ...
                    self.measurementType);
                if strcmp(self.measurementType, 'Thermocouple')
                    ch.ThermocoupleType = self.thermocoupleType;
                    ch.Units = 'Celsius';
               % else: Voltage and other measurement types need no additional
                % channel properties beyond what addinput() sets by default.
                % But optional channel properties could be here in an else statement.
                end
                
                self.logger.log('DEBUG', sprintf('[%s] Added channel %s', ...
                    self.name, self.channels{i}));
            end

            self.isConnected = true;
            self.logger.log('INFO', sprintf('[%s] DAQ session ready', self.name));
        end

        function result = execute(self, command, params)
            % Dispatch a command to the appropriate handler
            %
            % Supported commands:
            %   get_temperature        - Blocking read; returns mean per channel
            %   log_temperature        - Blocking read; logs stats and optionally plots
            %   startContinuousLogging - Start non-blocking background CSV logging
            %   stopContinuousLogging  - Stop background logging and close CSV
            %
            % Args:
            %   command - Command name string
            %   params  - Struct of optional command parameters (may be omitted)
            %
            % Returns:
            %   result - Struct; fields depend on command (see private methods)

            if nargin < 3
                params = struct();
            end

            switch command
                case 'get_temperature'
                    if self.isLogging
                        error('DAQThermometerPlugin:LoggingActive', ...
                            '[%s] Cannot call get_temperature while continuous logging is active. Call stopContinuousLogging first.', ...
                            self.name);
                    end
                    result = self.cmdGetTemperature(params);
                case 'log_temperature'
                    if self.isLogging
                        error('DAQThermometerPlugin:LoggingActive', ...
                            '[%s] Cannot call log_temperature while continuous logging is active. Call stopContinuousLogging first.', ...
                            self.name);
                    end
                    result = self.cmdLogTemperature(params);
                case 'startContinuousLogging'
                    result = self.cmdStartContinuousLogging(params);
                case 'stopContinuousLogging'
                    result = self.cmdStopContinuousLogging(params);
                otherwise
                    error('DAQThermometerPlugin:UnknownCommand', ...
                        '[%s] Unknown command: %s', self.name, command);
            end
        end

        function cleanup(self)
            % Stop and release the DAQ session
            %
            % If continuous logging is still active, stops it and closes the
            % CSV file before releasing the DAQ session. Called automatically
            % by PluginManager at the end of the experiment, whether the
            % experiment completes normally or errors.

            if self.isLogging
                self.logger.log('INFO', sprintf( ...
                    '[%s] Stopping continuous logging during cleanup', self.name));
                self.cmdStopContinuousLogging(struct());
            end

            if self.isConnected && ~isempty(self.daqSession)
                try
                    self.logger.log('INFO', sprintf('[%s] Releasing DAQ session', self.name));
                    if self.daqSession.Running
                        stop(self.daqSession);
                    end
                    delete(self.daqSession);
                    self.isConnected = false;
                    self.logger.log('INFO', sprintf('[%s] DAQ session released', self.name));
                catch ME
                    self.logger.log('WARNING', sprintf('[%s] Error during cleanup: %s', ...
                        self.name, ME.message));
                end
            end
        end

        function status = getStatus(self)
            % Return plugin status struct

            status                  = struct();
            status.name             = self.name;
            status.vendor           = self.vendor;
            status.deviceId         = self.deviceId;
            status.thermocoupleType = self.thermocoupleType;
            status.sampleRate       = self.sampleRate;
            status.numChannels      = self.numChannels;
            status.connected        = self.isConnected;
            status.isLogging        = self.isLogging;
            status.logFilePath      = self.logFilePath;
        end

    end

    methods (Access = private)

        function extractConfig(self)
            % Parse config struct, validate required fields, and apply defaults
            %
            % Normalizes the channels field so that a single YAML list item
            % (which parses as a struct) is wrapped in a cell array, matching
            % the multi-channel cell array format.

            % Required: device_id
            if ~isfield(self.config, 'device_id') || isempty(self.config.device_id)
                error('DAQThermometerPlugin:MissingConfig', ...
                    '[%s] Required config field missing: device_id', self.name);
            end
            self.deviceId = self.config.device_id;

            % Required: channels
            if ~isfield(self.config, 'channels') || isempty(self.config.channels)
                error('DAQThermometerPlugin:MissingConfig', ...
                    '[%s] Required config field missing: channels', self.name);
            end

            % Normalize: single YAML list item parses as struct, not cell array
            raw = self.config.channels;
            if ~iscell(raw)
                raw = {raw};
            end
            self.channels = raw(:)';
            self.numChannels = numel(self.channels);

            if self.numChannels < 1 || self.numChannels > 4
                error('DAQThermometerPlugin:InvalidConfig', ...
                    '[%s] channels must contain 1 to 4 entries (got %d)', ...
                    self.name, self.numChannels);
            end

            % Optional: vendor (default: 'ni')
            if isfield(self.config, 'vendor') && ~isempty(self.config.vendor)
                self.vendor = self.config.vendor;
            else
                self.vendor = 'ni';
            end

            % Optional: measurement_type (default: 'Thermocouple')
            if isfield(self.config, 'measurement_type') && ~isempty(self.config.measurement_type)
                self.measurementType = self.config.measurement_type;
            else
                self.measurementType = 'Thermocouple';
            end

            % Optional: thermocouple_type (default: 'K')
            if isfield(self.config, 'thermocouple_type') && ~isempty(self.config.thermocouple_type)
                self.thermocoupleType = self.config.thermocouple_type;
            else
                self.thermocoupleType = 'K';
            end

            % Optional: sample_rate (default: 7, matching Shubham's script)
            if isfield(self.config, 'sample_rate') && ~isempty(self.config.sample_rate)
                self.sampleRate = self.config.sample_rate;
            else
                self.sampleRate = 7;
            end

            % Optional: sample_duration (default: 1.0 s)
            if isfield(self.config, 'sample_duration') && ~isempty(self.config.sample_duration)
                self.defaultSampleDuration = self.config.sample_duration;
            else
                self.defaultSampleDuration = 1.0;
            end

            % Optional: generate_plots (default: true)
            if isfield(self.config, 'generate_plots') && ~isempty(self.config.generate_plots)
                self.defaultGeneratePlots = self.config.generate_plots;
            else
                self.defaultGeneratePlots = true;
            end

            % saveDir injected by PluginManager; fall back to working directory
            if isfield(self.config, 'saveDir') && ~isempty(self.config.saveDir)
                self.saveDir = self.config.saveDir;
            else
                self.saveDir = pwd;
            end
        end

        function result = cmdGetTemperature(self, params)
            % Short temperature read for between-trial passive monitoring
            %
            % Reads for sample_duration seconds, computes per-channel
            % mean/min/max, and writes a summary line to the experiment log.
            % Does not generate plots regardless of config setting.
            %
            % Args:
            %   params.sample_duration - Override default duration (optional)
            %
            % Returns:
            %   result.channels(i).mean  - Mean temperature (degrees C)
            %   result.channels(i).min   - Min temperature (degrees C)
            %   result.channels(i).max   - Max temperature (degrees C)
            %   result.timestamp         - datetime of read

            if ~self.isConnected
                error('DAQThermometerPlugin:NotConnected', ...
                    '[%s] DAQ session not initialized', self.name);
            end

            duration = self.resolveDuration(params);

            self.logger.log('DEBUG', sprintf('[%s] get_temperature: reading for %.1f s', ...
                self.name, duration));

            data   = read(self.daqSession, seconds(duration));
            result = self.buildResult(data);

            self.logSummary(result);
        end

        function result = cmdLogTemperature(self, params)
            % Longer temperature read for pre/post-experiment records
            %
            % Reads for sample_duration seconds, computes per-channel
            % mean/min/max, writes a summary to the experiment log, and
            % optionally saves a plot PNG to the experiment output directory.
            %
            % Args:
            %   params.sample_duration - Override default duration (optional)
            %   params.generate_plots  - Override config plot default (optional)
            %
            % Returns:
            %   result.channels  - Same as cmdGetTemperature
            %   result.timestamp - datetime of read
            %   result.plotFile  - Full path to saved PNG, or '' if not generated

            if ~self.isConnected
                error('DAQThermometerPlugin:NotConnected', ...
                    '[%s] DAQ session not initialized', self.name);
            end

            duration = self.resolveDuration(params);

            if isfield(params, 'generate_plots') && ~isempty(params.generate_plots)
                doPlot = params.generate_plots;
            else
                doPlot = self.defaultGeneratePlots;
            end

            self.logger.log('DEBUG', sprintf( ...
                '[%s] log_temperature: reading for %.1f s (generate_plots: %d)', ...
                self.name, duration, doPlot));

            data = read(self.daqSession, seconds(duration));
            result = self.buildResult(data);
            result.plotFile = '';

            self.logSummary(result);

            if doPlot
                result.plotFile = self.savePlot(data, result);
            end
        end

        function result = cmdStartContinuousLogging(self, params)
            % Start non-blocking background temperature acquisition
            %
            % Configures the DAQ session for continuous mode and starts it.
            % Returns immediately. The hardware driver acquires samples
            % independently and fires continuousLogCallback once per sample,
            % which writes one row to the CSV file. MATLAB processes callbacks
            % during pause() calls in the main protocol, so logging is
            % effectively concurrent with experiment execution.
            %
            % Cannot be called while continuous logging is already active, or
            % while get_temperature / log_temperature would be appropriate
            % (those commands cannot run while the session is in continuous mode).
            %
            % Args:
            %   params.filename - Full path for the CSV log file (optional).
            %                     Default: temperature_YYYYMMDD_HHMMSS.csv in saveDir.
            %
            % Returns:
            %   result.logFile - Full path of the opened CSV log file

            if ~self.isConnected
                error('DAQThermometerPlugin:NotConnected', ...
                    '[%s] DAQ session not initialized', self.name);
            end

            if self.isLogging
                self.logger.log('WARNING', sprintf( ...
                    '[%s] startContinuousLogging called but logging is already active', ...
                    self.name));
                result = struct('logFile', self.logFilePath);
                return;
            end

            % Resolve log file path
            if isfield(params, 'filename') && ~isempty(params.filename)
                filepath = params.filename;
            else
                timestamp = datestr(now, 'yyyymmdd_HHMMSS');
                filepath  = fullfile(self.saveDir, ...
                    sprintf('temperature_%s.csv', timestamp));
            end

            % Open CSV and write header
            fid = fopen(filepath, 'w');
            if fid == -1
                error('DAQThermometerPlugin:FileError', ...
                    '[%s] Could not open temperature log file: %s', self.name, filepath);
            end
            self.logFileId  = fid;
            self.logFilePath = filepath;

            headerParts = [{'elapsed_s'}, self.channels];
            if self.numChannels == 2
                headerParts{end+1} = 'dT_C';
            end
            fprintf(self.logFileId, '%s\n', strjoin(headerParts, ','));

            % Configure callback: fire once per acquired scan
            self.daqSession.ScansAvailableFcnCount = 1;
            self.continuousTic = tic;
            self.daqSession.ScansAvailableFcn = @(src, ~) self.continuousLogCallback(src);

            % Start continuous acquisition (non-blocking)
            start(self.daqSession, "continuous");
            self.isLogging = true;

            self.logger.log('INFO', sprintf( ...
                '[%s] Continuous logging started at %g Hz -> %s', ...
                self.name, self.sampleRate, filepath));

            result = struct('logFile', filepath);
        end

        function result = cmdStopContinuousLogging(self, ~)
            % Stop background temperature acquisition and close the CSV file
            %
            % Stops the DAQ session, removes the callback, and closes the log
            % file. Safe to call even if logging is not active (logs a warning).
            % Called automatically by cleanup() if still running at experiment end.
            %
            % Returns:
            %   result.logFile - Full path of the closed CSV log file

            if ~self.isLogging
                self.logger.log('WARNING', sprintf( ...
                    '[%s] stopContinuousLogging called but logging is not active', ...
                    self.name));
                result = struct('logFile', self.logFilePath);
                return;
            end

            % Stop acquisition and clear callback
            stop(self.daqSession);
            self.daqSession.ScansAvailableFcn = [];

            % Close log file
            if self.logFileId ~= -1
                fclose(self.logFileId);
                self.logFileId = -1;
            end

            self.isLogging = false;

            self.logger.log('INFO', sprintf( ...
                '[%s] Continuous logging stopped -> %s', self.name, self.logFilePath));

            result = struct('logFile', self.logFilePath);
        end

        function continuousLogCallback(self, src)
            % Callback fired by the DAQ session each time a new scan is available
            %
            % Reads exactly one scan from the acquisition buffer, computes the
            % elapsed time since logging started, and writes one CSV row.
            % For two channels, also writes the inter-channel difference (dT).
            %
            % Format: elapsed_s, ch0_C [, ch1_C [, ch2_C [, ch3_C]]] [, dT_C]
            %
            % Errors inside callbacks are silently swallowed by MATLAB; any
            % exception here is caught and written to the experiment log instead
            % of crashing the callback infrastructure.

            try
                data    = read(src, src.ScansAvailableFcnCount);
                elapsed = toc(self.continuousTic);

                vals = zeros(1, self.numChannels);
                for i = 1:self.numChannels
                    vals(i) = data{1, i};
                end

                if self.numChannels == 2
                    row = [elapsed, vals, vals(2) - vals(1)];
                else
                    row = [elapsed, vals];
                end

                fmt = [repmat('%.4f,', 1, numel(row) - 1), '%.4f\n'];
                fprintf(self.logFileId, fmt, row);

            catch ME
                self.logger.log('WARNING', sprintf( ...
                    '[%s] continuousLogCallback error: %s', self.name, ME.message));
            end
        end

        function duration = resolveDuration(self, params)
            % Return params.sample_duration if provided, else config default

            if isfield(params, 'sample_duration') && ~isempty(params.sample_duration)
                duration = params.sample_duration;
            else
                duration = self.defaultSampleDuration;
            end
        end

        function result = buildResult(self, data)
            % Compute per-channel statistics from timetable and build result struct
            %
            % Accesses timetable columns by index so the method is not
            % sensitive to the auto-generated column names (e.g. cDAQ1Mod4_ai0).
            %
            % Args:
            %   data - Timetable returned by read()
            %
            % Returns:
            %   result.channels  - Struct array of per-channel stats
            %   result.timestamp - datetime of read
            channelStats = [];

            for i = 1:self.numChannels
                channelStats(i) = struct( 'label', ...
              '', 'mean', 0, 'min', 0, 'max', 0);
                readings               = data{:, i};
                channelStats(i).label  = self.channels{i};
                channelStats(i).mean   = mean(readings);
                channelStats(i).min    = min(readings);
                channelStats(i).max    = max(readings);
            end

            result           = struct();
            result.channels  = channelStats;
            result.timestamp = datetime('now');
        end

        function logSummary(self, result)
            % Write per-channel mean/min/max to experiment log
            %
            % For exactly 2 channels, also logs the mean temperature difference.

            for i = 1:self.numChannels
                ch = result.channels(i);
                self.logger.log('INFO', sprintf( ...
                    '[%s] %s: mean=%.2f C  min=%.2f C  max=%.2f C', ...
                    self.name, ch.label, ch.mean, ch.min, ch.max));
            end

            if self.numChannels == 2
                tempDiff = result.channels(2).mean - result.channels(1).mean;
                self.logger.log('INFO', sprintf( ...
                    '[%s] %s - %s mean difference: %.2f C', ...
                    self.name, result.channels(2).label, result.channels(1).label, tempDiff));
            end
        end

        function plotFile = savePlot(self, data, result)
            % Generate and save a temperature plot PNG to saveDir
            %
            % Plot layout depends on channel count:
            %   1 channel  : single axes, readings over time
            %   2 channels : 3 subplots - ch1, ch2, and difference (ch2 - ch1)
            %   3-4 channels: one subplot per channel, readings over time only
            %
            % Args:
            %   data   - Timetable returned by read()
            %   result - Result struct from buildResult()
            %
            % Returns:
            %   plotFile - Full path to the saved PNG file

            timestamp = datestr(result.timestamp, 'yyyymmdd_HHMMSS');
            filename  = sprintf('thermometer_%s.png', timestamp);
            plotFile  = fullfile(self.saveDir, filename);

            time = data.Time;
            fig  = figure('Visible', 'off');

            if self.numChannels == 1

                plot(time, data{:, 1});
                xlabel('Time');
                ylabel('Temperature (C)');
                title(sprintf('%s', ...
                    result.channels(1).label));
                grid on;

            elseif self.numChannels == 2

                readings1 = data{:, 1};
                readings2 = data{:, 2};

                subplot(3, 1, 1);
                plot(time, readings1);
                ylabel('Temp (C)');
                title(sprintf('%s', ...
                    result.channels(1).label));
                grid on;

                subplot(3, 1, 2);
                plot(time, readings2);
                ylabel('Temp (C)');
                title(result.channels(2).label);
                grid on;

                subplot(3, 1, 3);
                plot(time, readings2 - readings1);
                xlabel('Time');
                ylabel('Delta T (C)');
                title(sprintf('Difference (%s - %s)', ...
                    result.channels(2).label, result.channels(1).label));
                grid on;

            else  % 3 or 4 channels

                for i = 1:self.numChannels
                    subplot(self.numChannels, 1, i);
                    plot(time, data{:, i});
                    ylabel('Temp (C)');
                    title(result.channels(i).label);
                    if i == self.numChannels
                        xlabel('Time');
                    end
                    grid on;
                end

            end

            sgtitle(sprintf('Temperature Log  %s', ...
                datestr(result.timestamp, 'yyyy-mm-dd HH:MM:SS')));

            saveas(fig, plotFile);
            close(fig);

            self.logger.log('INFO', sprintf('[%s] Plot saved: %s', self.name, plotFile));
        end

    end
end

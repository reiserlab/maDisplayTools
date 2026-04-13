classdef DAQThermometerPlugin < handle
    % DAQ-based thermometer plugin for temperature monitoring during experiments
    %
    % Wraps the MATLAB Data Acquisition Toolbox to read temperature from a
    % National Instruments CompactDAQ thermocouple module. Hardware identity
    % (device, channel, measurement type) is fully rig-configurable so the
    % class code never needs to change between setups.
    %
    % Required MATLAB Toolbox: Data Acquisition Toolbox (R2020a or later)
    %
    % Rig YAML Config Fields:
    %   vendor            - DAQ vendor string (default: 'ni')
    %   device_id         - NI device/module ID (e.g. 'cDAQ1Mod1') [required]
    %   channel           - Channel number on the module (e.g. 1)    [required]
    %   measurement_type  - Measurement type string (default: 'Thermocouple')
    %   sample_duration   - Default read duration in seconds (default: 1.0)
    %   sample_rate       - Samples per second; omit to use toolbox default
    %
    % Experiment YAML Usage:
    %   - type: "plugin"
    %     plugin_name: "temperature"
    %     command_name: "get_temperature"
    %     params:
    %       sample_duration: 2.0    % optional override
    %
    % Class Plugin Interface:
    %   Constructor : DAQThermometerPlugin(name, config, logger)
    %   initialize  : Opens DAQ session and adds measurement channel
    %   execute     : Accepts command 'get_temperature'; returns result struct
    %   cleanup     : Stops and releases DAQ session
    %   getStatus   : Returns status struct

    properties (Access = private)
        name                % Plugin name string
        config              % Config struct from rig YAML
        logger              % ExperimentLogger instance
        daqSession          % daq session object
        isConnected         % logical: true after successful initialize()
        vendor              % DAQ vendor string (default: 'ni')
        deviceId            % NI device/module ID string
        channel             % Channel number
        measurementType     % Measurement type string
        defaultSampleDuration  % Fallback sample duration in seconds
    end

    methods (Access = public)

        function self = DAQThermometerPlugin(name, config, logger)
            % Constructor - parses config; does not open hardware
            %
            % Args:
            %   name   - Plugin name string
            %   config - Config struct from rig YAML
            %   logger - ExperimentLogger instance

            self.name   = name;
            self.config = config;
            self.logger = logger;
            self.isConnected = false;

            self.extractConfig();
        end

        function initialize(self)
            % Open DAQ session and add measurement channel
            %
            % Creates the daq() session, optionally sets sample rate, and
            % calls addinput() to configure the physical channel. Called by
            % PluginManager before any experiment commands are executed.
            %
            % Throws on failure so PluginManager can prompt for retry.

            self.logger.log('INFO', sprintf('[%s] Initializing DAQ session (vendor: %s, device: %s, channel: %d, type: %s)', ...
                self.name, self.vendor, self.deviceId, self.channel, self.measurementType));

            self.daqSession = daq(self.vendor);

            if isfield(self.config, 'sample_rate') && ~isempty(self.config.sample_rate)
                self.daqSession.Rate = self.config.sample_rate;
                self.logger.log('DEBUG', sprintf('[%s] Sample rate set to %g Hz', ...
                    self.name, self.config.sample_rate));
            end

            addinput(self.daqSession, self.deviceId, self.channel, self.measurementType);

            self.isConnected = true;
            self.logger.log('INFO', sprintf('[%s] DAQ session ready', self.name));
        end

        function result = execute(self, command, params)
            % Execute a plugin command
            %
            % Supported commands:
            %   get_temperature - Read temperature from DAQ channel
            %
            % Args:
            %   command - Command name string
            %   params  - Struct of command parameters (optional)
            %             params.sample_duration overrides config default
            %
            % Returns:
            %   result  - Struct with fields:
            %             .temperature  - Mean temperature value (degrees C)
            %             .unit         - String 'C'
            %             .timestamp    - datetime of the read

            if nargin < 3
                params = struct();
            end

            switch command
                case 'get_temperature'
                    result = self.cmdGetTemperature(params);
                otherwise
                    error('DAQThermometerPlugin:UnknownCommand', ...
                        '[%s] Unknown command: %s', self.name, command);
            end
        end

        function cleanup(self)
            % Stop and release the DAQ session
            %
            % Called by PluginManager during posttrial cleanup.

            if self.isConnected && ~isempty(self.daqSession)
                try
                    self.logger.log('INFO', sprintf('[%s] Releasing DAQ session', self.name));
                    stop(self.daqSession);
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

            status = struct();
            status.name            = self.name;
            status.vendor          = self.vendor;
            status.deviceId        = self.deviceId;
            status.channel         = self.channel;
            status.measurementType = self.measurementType;
            status.connected       = self.isConnected;
        end

    end

    methods (Access = private)

        function extractConfig(self)
            % Parse config struct and apply defaults for optional fields

            % Required fields
            if ~isfield(self.config, 'device_id') || isempty(self.config.device_id)
                error('DAQThermometerPlugin:MissingConfig', ...
                    '[%s] Required config field missing: device_id', self.name);
            end
            if ~isfield(self.config, 'channel') || isempty(self.config.channel)
                error('DAQThermometerPlugin:MissingConfig', ...
                    '[%s] Required config field missing: channel', self.name);
            end

            self.deviceId = self.config.device_id;
            self.channel  = self.config.channel;

            % Optional fields with defaults
            if isfield(self.config, 'vendor') && ~isempty(self.config.vendor)
                self.vendor = self.config.vendor;
            else
                self.vendor = 'ni';
            end

            if isfield(self.config, 'measurement_type') && ~isempty(self.config.measurement_type)
                self.measurementType = self.config.measurement_type;
            else
                self.measurementType = 'Thermocouple';
            end

            if isfield(self.config, 'sample_duration') && ~isempty(self.config.sample_duration)
                self.defaultSampleDuration = self.config.sample_duration;
            else
                self.defaultSampleDuration = 1.0;
            end
        end

        function result = cmdGetTemperature(self, params)
            % Read temperature from DAQ channel and return result struct
            %
            % Uses params.sample_duration if provided, otherwise falls back
            % to the config default (self.defaultSampleDuration).

            if ~self.isConnected
                error('DAQThermometerPlugin:NotConnected', ...
                    '[%s] DAQ session not initialized', self.name);
            end

            if isfield(params, 'sample_duration') && ~isempty(params.sample_duration)
                duration = params.sample_duration;
            else
                duration = self.defaultSampleDuration;
            end

            self.logger.log('DEBUG', sprintf('[%s] Reading temperature (%.1f s)', ...
                self.name, duration));

            data = read(self.daqSession, seconds(duration));

            temperature = mean(data{:, 1});
            timestamp   = datetime('now');

            result = struct();
            result.temperature = temperature;
            result.unit        = 'C';
            result.timestamp   = timestamp;

            self.logger.log('INFO', sprintf('[%s] Temperature: %.2f C', ...
                self.name, temperature));
        end

    end
end
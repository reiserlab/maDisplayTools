classdef WingbeatMonitorPlugin < handle
    % WINGBEATMONITORPLUGIN  Class plugin exposing wingbeat frequency (WBF)
    % from the flight arena's wingbeat analyzer as a flow-control metric,
    % with optional LmR / left-wing / right-wing channels for the same
    % real-time monitoring/plotting the old G4 conductor GUI provided.
    %
    % Hardware model: the wingbeat analyzer computes WBF internally and
    % outputs it as an analog voltage on one channel. This plugin does NOT
    % do any frequency extraction — it reads that voltage via an NI DAQ
    % board (MATLAB Data Acquisition Toolbox) and converts it to Hz with a
    % single linear scale factor, matching how the old G4 conductor system
    % (feedback_model.m) interpreted the same channel. The LmR/left/right
    % channels, if configured, are raw analog voltages (same as the old
    % system's channels 1-3) and are logged/exposed as-is, unscaled.
    %
    % The WBF scale factor is a class property with a documented default,
    % not (yet) a required config field, per Lisa's instruction — it should
    % be trivial to find and change by hand right now, and trivial to
    % promote to a rig YAML config field later if it turns out to vary by
    % hardware or rig. An optional config override is already wired in for
    % that transition; see WBF_SCALE_FACTOR and extractConfig().
    %
    % Monitor plugin interface (required by the flow-control runner /
    % CriterionEvaluator, per the provides_metric convention):
    %   getTime               -> seconds elapsed since initialize()
    %   getDataForInterval    -> struct with .t and .values (Hz, WBF only)
    %                            for a [t_start, t_end] window on that clock
    %
    % Additional convenience commands:
    %   startMonitoring       -> begin continuous background acquisition
    %   stopMonitoring        -> stop acquisition, close the raw-data log
    %   getLatest             -> most recent WBF reading (Hz) and its time
    %   getPlotData           -> t/wbf/lmr/left/right over a window, for
    %                            reproducing the old real-time monitoring
    %                            plots. Fields for channels that were not
    %                            configured are omitted.
    %   puff                  -> fire the air puffer for puff_duration
    %                            seconds (or params.duration if given)
    %
    % Air puffer note: the puffer is wired as a digital output channel on
    % THIS SAME DAQ session, not a separate plugin/session, per Lisa's
    % decision — Michael's original message described "a digital output"
    % in the context of the same NI board already carrying the WBF
    % channels, and combining them avoids assuming the lab has separate
    % physical DAQ hardware for each signal. This is understood to be a
    % stopgap: if the lab later prefers puffing independent of wingbeat
    % monitoring (e.g. for walking flies), or implements the arena's free
    % DO line instead, the puff-related config/properties/methods below
    % are kept self-contained specifically so they can be lifted into a
    % standalone AirPufferPlugin later with minimal rework.
    %
    % Untested assumption, flag for hardware testing: writing to a
    % software-timed digital output channel while continuous hardware-timed
    % analog input acquisition is running on the same session is expected
    % to work with the DAQ Toolbox, but this combination hasn't been
    % verified against real (or NI MAX simulated) hardware yet.
    %
    % Required MATLAB Toolbox: Data Acquisition Toolbox (R2020a or later)
    %
    % Rig/Experiment YAML Config Fields:
    %   device_id         - NI DAQ device/module ID (e.g. 'cDAQ1Mod2')  [required]
    %   wbf_channel       - Analog input channel carrying the WBF voltage,
    %                       e.g. 'ai3'                                  [required]
    %   lmr_channel       - Analog input channel for L-minus-R, e.g. 'ai0' [optional]
    %   left_channel      - Analog input channel for left wing, e.g. 'ai1' [optional]
    %   right_channel     - Analog input channel for right wing, e.g. 'ai2'[optional]
    %   sample_rate       - Continuous acquisition rate in Hz (default: 20)
    %   buffer_duration   - Seconds of history kept for interval queries
    %                       (default: 60)
    %   wbf_scale_factor  - Hz per Volt on the WBF channel (default: 100,
    %                       matching the old system's /100 conversion).
    %                       Optional override — see WBF_SCALE_FACTOR below
    %                       for the actual default value.
    %   log_raw_data      - Log every acquired scan to CSV (default: true)
    %   puff_channel      - Digital output channel for the air puffer,
    %                       e.g. 'port0/line0'                          [optional]
    %   puff_device_id    - NI device/module ID for the puffer, if different
    %                       from device_id above (default: same as device_id)
    %   puff_duration     - Default puff length in seconds (default: 0.1)
    %   puff_active_high  - Whether the puffer fires on DO HIGH (default: true).
    %                       Flip this if the actual wiring turns out inverted.
    %
    % Plugin definition (experiment or rig YAML):
    %   plugins:
    %     - name: "wingbeat"
    %       type: "class"
    %       provides_metric: "wingbeat_frequency"
    %       matlab:
    %         class: "WingbeatMonitorPlugin"
    %       config:
    %         device_id: "cDAQ1Mod2"
    %         wbf_channel: "ai3"
    %         lmr_channel: "ai0"
    %         left_channel: "ai1"
    %         right_channel: "ai2"
    %         puff_channel: "port0/line0"
    %
    % Class Plugin Interface:
    %   Constructor : WingbeatMonitorPlugin(name, config, logger)
    %   initialize  : Opens the DAQ session, adds configured channels, starts clock
    %   execute     : Dispatches the commands listed above
    %   cleanup     : Stops acquisition and releases the DAQ session
    %   getStatus   : Returns a status struct

    properties (Constant)
        % Hz per Volt on the WBF channel. This is the single place to
        % change the conversion if it turns out to be wrong for this rig.
        % Config field wbf_scale_factor (if provided) overrides this.
        WBF_SCALE_FACTOR = 100
    end

    properties (Access = private)
        name                % Plugin name string
        config              % Config struct from rig/experiment YAML
        logger              % ExperimentLogger instance

        daqSession          % daq session object
        isInitialized = false
        isMonitoring  = false

        deviceId            % NI device/module ID string
        wbfChannel          % Analog input channel string for WBF voltage
        sampleRate          % Continuous acquisition rate (Hz)
        bufferDuration      % Seconds of history retained (s)
        scaleFactor         % Hz per Volt, resolved in extractConfig()

        % Optional raw channels (empty string = not configured)
        lmrChannel   = ''
        leftChannel  = ''
        rightChannel = ''
        hasLmr   = false
        hasLeft  = false
        hasRight = false

        % Column index of each channel within evt.Data, set in initialize()
        % based on the order channels were added to the DAQ session.
        colWbf
        colLmr
        colLeft
        colRight

        clockRef            % tic reference; getTime() is toc(clockRef)
        daqStartOffset      % toc(clockRef) value when acquisition started

        bufferTimestamps = []   % Nx1, seconds on clockRef
        bufferValues     = []   % Nx1, WBF in Hz
        bufferLmr        = []   % Nx1, Volts (only populated if hasLmr)
        bufferLeft       = []   % Nx1, Volts (only populated if hasLeft)
        bufferRight      = []   % Nx1, Volts (only populated if hasRight)

        logRawData          % logical: write raw scans to CSV
        logFile
        logFid = -1

        % --- Air puffer (digital output, same session) ---
        % Self-contained: everything with a "puff" prefix here exists so
        % this block can be lifted into a standalone AirPufferPlugin later
        % with minimal changes, if/when the lab wants puffing decoupled
        % from wingbeat monitoring or moves it to the arena's DO line.
        puffChannel  = ''
        puffDeviceId = ''
        hasPuffer    = false
        puffDuration     % seconds, resolved in extractConfig()
        puffActiveHigh   % logical, resolved in extractConfig()

        testMode = false   % TEST-ONLY: set true by initializeForTest();
                            % skips real hardware writes in puff()
    end

    methods (Access = public)

        function self = WingbeatMonitorPlugin(name, config, logger)
            % Constructor - parses config; does not open hardware
            self.name   = name;
            self.config = config;
            self.logger = logger;

            self.extractConfig();
        end

        function initialize(self)
            % Open the DAQ session and add the configured input channels.
            % Channel order fixed as WBF, then LmR, left, right (whichever
            % of the last three are present) — colWbf/colLmr/colLeft/colRight
            % record each channel's column in evt.Data for the callback.
            self.daqSession = daq('ni');

            addinput(self.daqSession, self.deviceId, self.wbfChannel, 'Voltage');
            self.colWbf = 1;
            nextCol = 2;

            if self.hasLmr
                addinput(self.daqSession, self.deviceId, self.lmrChannel, 'Voltage');
                self.colLmr = nextCol;
                nextCol = nextCol + 1;
            end
            if self.hasLeft
                addinput(self.daqSession, self.deviceId, self.leftChannel, 'Voltage');
                self.colLeft = nextCol;
                nextCol = nextCol + 1;
            end
            if self.hasRight
                addinput(self.daqSession, self.deviceId, self.rightChannel, 'Voltage');
                self.colRight = nextCol; %#ok<NASGU> % kept for symmetry/clarity; not read after this
            end

            self.daqSession.Rate = self.sampleRate;

            if self.hasPuffer
                addoutput(self.daqSession, self.puffDeviceId, self.puffChannel, 'Digital');
                self.setPufferIdle();
            end

            if self.logRawData
                if isfield(self.config, 'log_file')
                    self.logFile = self.config.log_file;
                elseif isfield(self.config, 'saveDir')
                    self.logFile = fullfile(self.config.saveDir, ...
                        sprintf('%s_wbf_raw.csv', self.name));
                end
                if ~isempty(self.logFile)
                    self.logFid = fopen(self.logFile, 'w');
                    fprintf(self.logFid, 'time_s,wbf_hz%s%s%s\n', ...
                        self.csvHeaderSuffix('lmr_V', self.hasLmr), ...
                        self.csvHeaderSuffix('left_V', self.hasLeft), ...
                        self.csvHeaderSuffix('right_V', self.hasRight));
                end
            end

            self.clockRef = tic;
            self.isInitialized = true;
            self.logger.log('INFO', sprintf('[%s] Wingbeat monitor initialized (device=%s, wbf=%s, lmr=%s, left=%s, right=%s, puff=%s, scale=%.3f Hz/V)', ...
                self.name, self.deviceId, self.wbfChannel, ...
                self.channelLabel(self.hasLmr, self.lmrChannel), ...
                self.channelLabel(self.hasLeft, self.leftChannel), ...
                self.channelLabel(self.hasRight, self.rightChannel), ...
                self.channelLabel(self.hasPuffer, self.puffChannel), ...
                self.scaleFactor));
        end

        function result = execute(self, command, params)
            % Dispatch a command by name. params may be omitted/empty for
            % commands that don't need it.
            if nargin < 3
                params = struct();
            end

            if ~self.isInitialized
                error('WingbeatMonitorPlugin:%s: execute() called before initialize()', self.name);
            end

            switch command
                case 'startMonitoring'
                    self.startMonitoring();
                    result = [];
                case 'stopMonitoring'
                    self.stopMonitoring();
                    result = [];
                case 'getLatest'
                    result = self.getLatest();
                case 'getTime'
                    result = self.getTime();
                case 'getDataForInterval'
                    result = self.getDataForInterval(params.t_start, params.t_end);
                case 'getPlotData'
                    result = self.getPlotData(params.t_start, params.t_end);
                case 'puff'
                    self.puff(params);
                    result = [];
                otherwise
                    error('WingbeatMonitorPlugin:%s: unknown command "%s"', self.name, command);
            end
        end

        function cleanup(self)
            % Stop acquisition (if running), idle the puffer, and release
            % the DAQ session.
            if self.hasPuffer
                self.setPufferIdle();
            end
            if ~isempty(self.daqSession) && isvalid(self.daqSession) && self.daqSession.Running
                stop(self.daqSession);
            end
            if self.logFid ~= -1
                fclose(self.logFid);
                self.logFid = -1;
            end
            self.isMonitoring = false;
            self.logger.log('INFO', sprintf('[%s] Wingbeat monitor cleaned up', self.name));
        end

        function simulateScan(self, t, data)
            % TEST-ONLY: feeds a synthetic scan through the same path the
            % DAQ driver's ScansAvailableFcn would use. Not called during a
            % real experiment. t is a column vector of timestamps (seconds,
            % relative to daqStartOffset); data is an NxM matrix matching
            % the column layout initialize()/initializeForTest() set up.
            evt.TimeStamps = t;
            evt.Data = data;
            self.scansAvailableCallback(evt);
        end

        function initializeForTest(self)
            % TEST-ONLY: mirrors the column-assignment and clock-start
            % portion of initialize() without opening a real DAQ session.
            % Use this instead of initialize() when there is no hardware
            % attached, then drive data in with simulateScan(). Also sets
            % testMode so puff() logs instead of writing to real hardware.
            self.testMode = true;
            self.colWbf = 1;
            nextCol = 2;
            if self.hasLmr
                self.colLmr = nextCol;
                nextCol = nextCol + 1;
            end
            if self.hasLeft
                self.colLeft = nextCol;
                nextCol = nextCol + 1;
            end
            if self.hasRight
                self.colRight = nextCol;
            end

            if self.hasPuffer
                self.setPufferIdle();
            end

            if self.logRawData && isfield(self.config, 'log_file')
                self.logFile = self.config.log_file;
                self.logFid = fopen(self.logFile, 'w');
                fprintf(self.logFid, 'time_s,wbf_hz%s%s%s\n', ...
                    self.csvHeaderSuffix('lmr_V', self.hasLmr), ...
                    self.csvHeaderSuffix('left_V', self.hasLeft), ...
                    self.csvHeaderSuffix('right_V', self.hasRight));
            end

            self.clockRef = tic;
            self.daqStartOffset = 0;
            self.isInitialized = true;
            self.logger.log('INFO', sprintf('[%s] Wingbeat monitor initialized FOR TEST (no hardware)', self.name));
        end

        function status = getStatus(self)
            status = struct( ...
                'isInitialized', self.isInitialized, ...
                'isMonitoring',  self.isMonitoring, ...
                'scaleFactor',   self.scaleFactor, ...
                'hasLmr',        self.hasLmr, ...
                'hasLeft',       self.hasLeft, ...
                'hasRight',      self.hasRight, ...
                'hasPuffer',     self.hasPuffer, ...
                'puffDuration',  self.puffDuration, ...
                'puffActiveHigh', self.puffActiveHigh, ...
                'bufferedSamples', numel(self.bufferValues));
        end
    end

    methods (Access = private)

        function extractConfig(self)
            if ~isfield(self.config, 'device_id')
                error('WingbeatMonitorPlugin: missing required config field device_id');
            end
            if ~isfield(self.config, 'wbf_channel')
                error('WingbeatMonitorPlugin: missing required config field wbf_channel');
            end
            self.deviceId   = self.config.device_id;
            self.wbfChannel = self.config.wbf_channel;

            if isfield(self.config, 'lmr_channel')
                self.lmrChannel = self.config.lmr_channel;
                self.hasLmr = true;
            end
            if isfield(self.config, 'left_channel')
                self.leftChannel = self.config.left_channel;
                self.hasLeft = true;
            end
            if isfield(self.config, 'right_channel')
                self.rightChannel = self.config.right_channel;
                self.hasRight = true;
            end

            if isfield(self.config, 'sample_rate')
                self.sampleRate = self.config.sample_rate;
            else
                self.sampleRate = 20;
            end

            if isfield(self.config, 'buffer_duration')
                self.bufferDuration = self.config.buffer_duration;
            else
                self.bufferDuration = 60;
            end

            if isfield(self.config, 'wbf_scale_factor')
                self.scaleFactor = self.config.wbf_scale_factor;
            else
                self.scaleFactor = self.WBF_SCALE_FACTOR;
            end

            if isfield(self.config, 'log_raw_data')
                self.logRawData = self.config.log_raw_data;
            else
                self.logRawData = true;
            end

            % --- Air puffer (optional) ---
            if isfield(self.config, 'puff_channel')
                self.puffChannel = self.config.puff_channel;
                self.hasPuffer = true;
            end
            if isfield(self.config, 'puff_device_id')
                self.puffDeviceId = self.config.puff_device_id;
            else
                self.puffDeviceId = self.deviceId;
            end
            if isfield(self.config, 'puff_duration')
                self.puffDuration = self.config.puff_duration;
            else
                self.puffDuration = 0.1;
            end
            if isfield(self.config, 'puff_active_high')
                self.puffActiveHigh = self.config.puff_active_high;
            else
                self.puffActiveHigh = true;
            end
        end

        function startMonitoring(self)
            if self.isMonitoring
                return
            end
            self.daqStartOffset = toc(self.clockRef);
            self.daqSession.ScansAvailableFcn = @(src, evt) self.scansAvailableCallback(evt);
            start(self.daqSession, 'continuous');
            self.isMonitoring = true;
            self.logger.log('INFO', sprintf('[%s] Wingbeat monitoring started', self.name));
        end

        function stopMonitoring(self)
            if ~self.isMonitoring
                return
            end
            stop(self.daqSession);
            self.isMonitoring = false;
            self.logger.log('INFO', sprintf('[%s] Wingbeat monitoring stopped', self.name));
        end

        function scansAvailableCallback(self, evt)
            % Fires once per DAQ scan block during continuous acquisition.
            % Keep this fast and error-tolerant — an exception here would
            % otherwise crash the event-processing loop.
            try
                t = self.daqStartOffset + evt.TimeStamps;
                wbfV = evt.Data(:, self.colWbf);
                hz = wbfV * self.scaleFactor;

                if self.hasLmr,   lmrV   = evt.Data(:, self.colLmr);   end
                if self.hasLeft,  leftV  = evt.Data(:, self.colLeft);  end
                if self.hasRight, rightV = evt.Data(:, self.colRight); end

                % Log from the local scan-block vectors, not the buffer —
                % keeps this independent of trimBuffer's trimming below.
                if self.logFid ~= -1
                    for i = 1:numel(t)
                        fprintf(self.logFid, '%.4f,%.3f%s%s%s\n', t(i), hz(i), ...
                            self.csvValueSuffix(self.hasLmr, lmrV, i), ...
                            self.csvValueSuffix(self.hasLeft, leftV, i), ...
                            self.csvValueSuffix(self.hasRight, rightV, i));
                    end
                end

                self.bufferTimestamps = [self.bufferTimestamps; t];
                self.bufferValues     = [self.bufferValues; hz];
                if self.hasLmr,   self.bufferLmr   = [self.bufferLmr; lmrV];     end
                if self.hasLeft,  self.bufferLeft  = [self.bufferLeft; leftV];   end
                if self.hasRight, self.bufferRight = [self.bufferRight; rightV]; end
                self.trimBuffer();
            catch ME
                self.logger.log('WARNING', sprintf('[%s] scansAvailableCallback error: %s', ...
                    self.name, ME.message));
            end
        end

        function trimBuffer(self)
            if isempty(self.bufferTimestamps)
                return
            end
            cutoff = self.bufferTimestamps(end) - self.bufferDuration;
            keep = self.bufferTimestamps >= cutoff;
            self.bufferTimestamps = self.bufferTimestamps(keep);
            self.bufferValues     = self.bufferValues(keep);
            if self.hasLmr,   self.bufferLmr   = self.bufferLmr(keep);   end
            if self.hasLeft,  self.bufferLeft  = self.bufferLeft(keep);  end
            if self.hasRight, self.bufferRight = self.bufferRight(keep); end
        end

        function result = getLatest(self)
            if isempty(self.bufferValues)
                error('WingbeatMonitorPlugin:%s: no data available yet (has startMonitoring been called?)', self.name);
            end
            result = struct('t', self.bufferTimestamps(end), 'hz', self.bufferValues(end));
        end

        function t = getTime(self)
            t = toc(self.clockRef);
        end

        function result = getDataForInterval(self, tStart, tEnd)
            mask = self.bufferTimestamps >= tStart & self.bufferTimestamps <= tEnd;
            result = struct('t', self.bufferTimestamps(mask), 'values', self.bufferValues(mask));
        end

        function result = getPlotData(self, tStart, tEnd)
            % Returns t/wbf plus whichever of lmr/left/right are configured,
            % for reproducing the old real-time monitoring plots. Fields
            % for unconfigured channels are simply not present in the
            % returned struct.
            mask = self.bufferTimestamps >= tStart & self.bufferTimestamps <= tEnd;
            result = struct('t', self.bufferTimestamps(mask), 'wbf', self.bufferValues(mask));
            if self.hasLmr
                result.lmr = self.bufferLmr(mask);
            end
            if self.hasLeft
                result.left = self.bufferLeft(mask);
            end
            if self.hasRight
                result.right = self.bufferRight(mask);
            end
        end

        function puff(self, params)
            % Fire the air puffer for puff_duration seconds (or
            % params.duration if given). Blocking call — a puff is short,
            % so this mirrors the thermometer plugin's blocking
            % get_temperature pattern rather than adding async machinery.
            if ~self.hasPuffer
                error('WingbeatMonitorPlugin:%s: puff command called but no puff_channel configured', self.name);
            end
            if isfield(params, 'duration')
                dur = params.duration;
            else
                dur = self.puffDuration;
            end

            if self.testMode
                self.logger.log('INFO', sprintf('[%s] TEST: simulated puff for %.3fs (active=%d)', ...
                    self.name, dur, self.puffActiveHigh));
                return
            end

            write(self.daqSession, self.puffActiveHigh);
            pause(dur);
            write(self.daqSession, ~self.puffActiveHigh);
            self.logger.log('INFO', sprintf('[%s] Puffed for %.3fs', self.name, dur));
        end

        function setPufferIdle(self)
            % Ensure the puffer is in its inactive state. Called at
            % initialize()/initializeForTest() and cleanup() so a plugin
            % failure or aborted experiment can't leave it stuck open.
            if self.testMode
                self.logger.log('INFO', sprintf('[%s] TEST: puffer set idle', self.name));
                return
            end
            if ~isempty(self.daqSession) && isvalid(self.daqSession)
                write(self.daqSession, ~self.puffActiveHigh);
            end
        end

        function suffix = csvHeaderSuffix(~, label, isPresent)
            if isPresent
                suffix = [',' label];
            else
                suffix = '';
            end
        end

        function suffix = csvValueSuffix(~, isPresent, vec, i)
            % vec is the current scan block's local vector (not the
            % buffer), so i indexes it directly.
            if isPresent
                suffix = sprintf(',%.5f', vec(i));
            else
                suffix = '';
            end
        end

        function label = channelLabel(~, isPresent, channelId)
            if isPresent
                label = channelId;
            else
                label = 'none';
            end
        end
    end
end

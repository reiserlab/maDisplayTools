classdef CommandExecutor < handle
    % Executes all command types (controller commands, wait, plugin)
    %
    % Single responsibility: interpret command structures and execute them
    % by delegating to appropriate subsystems (arena controller, plugins)
    
    properties (Access = private)
        arenaController     % Arena hardware controller
        pluginManager       % PluginManager instance
        patternIDMap        % containers.Map: pattern path -> ID
        logger              % ExperimentLogger instance
    end
    
    methods (Access = public)
        function self = CommandExecutor(arenaController, pluginManager, logger)
            % Input Arguments:
            %   arenaController - Arena hardware controller object
            %   pluginManager - PluginManager instance
            %   patternIDMap - Map of pattern paths to IDs
            %   logger - ExperimentLogger instance
            
            self.arenaController = arenaController;
            self.pluginManager = pluginManager;
            %self.patternIDMap = patternIDMap;
            self.logger = logger;
        end
        
        function execute(self, command)
            % Execute a single command
            %
            % Input Arguments:
            %   command - Command struct from protocol YAML
            %             Must have 'type' field
            
            if ~isfield(command, 'type')
                self.logger.log('ERROR', sprintf('Command failed due to missing type field.'));
                error('Command missing required ''type'' field');
            end
            
            commandType = command.type;
            
            % Log command execution
            self.logger.log('DEBUG', sprintf('Executing command type: %s', commandType));
            
            % Execute based on type
            switch commandType
                case 'controller'
                    self.executeControllerCommand(command);
                    
                case 'wait'
                    self.executeWaitCommand(command);
                    
                case 'plugin'
                    self.executePluginCommand(command);
                    
                otherwise
                    self.logger.log('ERROR', sprintf('Command failed due to unknown command type'));
                    error('Unknown command type: %s', commandType);
            end
        end
    end
    
    methods (Access = private)
        function executeControllerCommand(self, command)
            
            if ~isfield(command, 'command_name')  
                self.logger.log('ERROR', sprintf('Controller command failed due to missing command name.'));
                error('Controller command missing ''command_name'' field');
            end

            commandName = command.command_name;

            self.logger.log('INFO', sprintf('Controller command: %s', commandName));
            
            % Execute based on specific command, with error handling
            try
                switch commandName
                        
                    case 'allOn'
                        suc = self.arenaController.allOn();
                        if ~suc
                            self.logger.log('ERROR', 'allOn command failed - controller returned false');
                            error('Controller command failed: allOn');
                        end
                        self.logger.log('INFO', 'allOn command succeeded');
                        
                    case 'allOff'
                        suc = self.arenaController.allOff();
                        if ~suc
                            self.logger.log('ERROR', 'allOff command failed - controller returned false');
                            error('Controller command failed: allOff');
                        end
                        self.logger.log('INFO', 'allOff command succeeded');
                        
                    case 'stopDisplay'
                        suc = self.arenaController.stopDisplay();
                        if ~suc
                            self.logger.log('ERROR', 'stopDisplay command failed - controller returned false');
                            error('Controller command failed: stopDisplay');
                        end
                        self.logger.log('INFO', 'stopDisplay command succeeded');

                    case 'setPositionX'
                        if ~isfield(command, 'posX')
                            self.logger.log('ERROR', sprintf('setPositionX failed due to missing parameter.'));
                            error('posX parameter missing, cannot execute setPositionX');
                        end
                        posX = command.posX;
                        % setPositionX does not return a value, so we just call it
                        self.arenaController.setPositionX(posX);
                        self.logger.log('INFO', sprintf('setPositionX command sent: posX=%d', posX));

                    case 'setColorDepth'
                        if ~isfield(command, 'gs_val')
                            self.logger.log('ERROR', sprintf('set color depth failed due to missing parameter'));
                            error('gs_val parameter missing, cannot execute setColorDepth');
                        end
                        gs_val = command.gs_val;
                        suc = self.arenaController.setColorDepth(gs_val);
                        if ~suc
                            self.logger.log('ERROR', sprintf('setColorDepth command failed - controller returned false'));
                            error('Controller command failed: setColorDepth');
                        end
                        self.logger.log('INFO', sprintf('setColorDepth command succeeded: gs_val=%d', gs_val));

                    case {'startG41Trial', 'trialParams'}
                        % Unified trial execution using trialParams()
                        % Supports both 'startG41Trial' and 'trialParams' command names

                        % All fields required for unified interface
                        required_fields = {'mode', 'pattern', 'pattern_ID', 'frame_index', 'duration', 'frame_rate', 'gain'};
                        self.check_required_fields(command, required_fields);

                        mode = command.mode;
                        if mode < 2 || mode > 4
                            self.logger.log('ERROR', sprintf('Trial failed: mode must be 2, 3, or 4 (got %d)', mode));
                            error('Trial failed: mode must be 2, 3, or 4');
                        end

                        % Extract parameters
                        patID = command.pattern_ID;
                        posX = command.frame_index;
                        dur = command.duration;
                        frameRate = command.frame_rate;
                        gain = command.gain;

                        % Execute using trialParams which waits for "Sequence completed"
                        self.logger.log('INFO', sprintf('Trial: mode=%d, patID=%d, pos=%d, dur=%.1fs, fps=%d, gain=%d', ...
                            mode, patID, posX, dur, frameRate, gain));
                        suc = self.arenaController.trialParams(mode, patID, frameRate, posX, gain, dur*10, true);
                        if ~suc
                            self.logger.log('ERROR', 'trialParams command failed - controller returned false or timeout');
                            error('Controller command failed: trialParams');
                        end
                        self.logger.log('INFO', 'trialParams command succeeded');
     
                    otherwise
                        self.logger.log('ERROR', sprintf('command failed due to unknown controller command %s',commandName));
                        error('Unknown controller command: %s', commandName);
                end
                
            catch ME
                % Log the exception details
                self.logger.log('ERROR', sprintf('Controller command %s threw exception: %s', ...
                    commandName, ME.message));
                
                % Log stack trace if available
                if ~isempty(ME.stack)
                    self.logger.log('ERROR', sprintf('  at %s (line %d)', ...
                        ME.stack(1).name, ME.stack(1).line));
                end
                
                % Re-throw to halt experiment
                rethrow(ME);
            end

            self.logger.log('INFO', sprintf('%s command completed', commandName));
           
        end
        
        function executeWaitCommand(self, command)
            % Pause execution
            %
            % Command fields:
            %   duration - Wait duration in seconds
            
            if ~isfield(command, 'duration')
                error('Wait command missing ''duration'' field');
            end
            
            duration = command.duration;
            
            self.logger.log('INFO', sprintf('Wait command: %d ms', duration));
            
            % pause
            pause(duration);
            
            self.logger.log('DEBUG', 'Wait command completed');
        end
        
        function executePluginCommand(self, command)
            % Execute plugin method/command
            %
            % Command fields:
            %   plugin_name - Plugin ID to call
            %   For SerialPlugin:
            %     command_name - Command name to execute
            %   For ClassPlugin:
            %     command_name - Method name to call
            %     params - (optional) Parameters struct
            %   For ScriptPlugin:
            %     (no additional fields needed)
            %   For Log command (all plugin types):
            %     command_name - 'log'
            %     params.message - Log message (required)
            %     params.level - Log level (optional, default: 'INFO')
            
            if ~isfield(command, 'plugin_name')
                error('Plugin command missing ''plugin_name'' field');
            end
            
            pluginID = command.plugin_name;
            
            % Special handling for log command
            if isfield(command, 'command_name') && strcmpi(command.command_name, 'log')
                % Validate params and message
                if isfield(command, 'params') && isfield(command.params, 'message')
  
                    message = command.params.message;
                    
                    % Get optional level parameter (default: 'INFO')
                    if isfield(command.params, 'level')
                        level = upper(command.params.level);
                    else
                        level = 'INFO';
                    end
                    
                    % Execute log command via PluginManager
                    self.pluginManager.logCustomMessage(pluginID, message, level);
                    
                    % Log that we executed the log command
                    self.logger.log('DEBUG', 'Log command completed');
                    
                    return;  % Done, no further execution needed
                end
            end
            
            % Get plugin to determine type
            plugin = self.pluginManager.getPlugin(pluginID);
            pluginType = plugin.getPluginType();
            
            self.logger.log('INFO', sprintf('Plugin command: %s (%s)', ...
                                          pluginID, pluginType));
            
            % Execute based on plugin type
            switch pluginType
                case 'serial_device'
                    if ~isfield(command, 'command_name')
                        error('SerialPlugin requires ''command_name'' field');
                    end
                    
                    commandName = command.command_name;
                    self.logger.log('DEBUG', sprintf('  Serial command: %s', commandName));
                    
                    self.pluginManager.executePluginCommand(pluginID, commandName);
                    
                case 'class'
                    if ~isfield(command, 'command_name')
                        error('ClassPlugin requires ''command_name'' field');
                    end
                    
                    methodName = command.command_name;
                    self.logger.log('DEBUG', sprintf('  Method: %s', methodName));
                    
                    if isfield(command, 'params')
                        params = command.params;
                        self.pluginManager.executePluginCommand(pluginID, methodName, params);
                    else
                        self.pluginManager.executePluginCommand(pluginID, methodName);
                    end
                    
                case 'script'
                    self.logger.log('DEBUG', '  Executing script');
                    self.pluginManager.executePluginCommand(pluginID);
                    
                otherwise
                    error('Unknown plugin type: %s', pluginType);
            end
            
            self.logger.log('DEBUG', 'Plugin command completed');
        end
   

        function check_required_fields(self, command, fields)
    
            if ~isfield(command, fields)
                msg = 'command failed due to missing at least one required field.';
                self.logger.log('INFO', sprintf(msg));
                error(msg);
            else
                % Check that all field values are within range
                for field = 1:length(fields)
                    switch fields{field}
    
                        case 'mode'
                            if command.mode < 2 || command.mode > 4
                                msg = 'command failed due to invalid mode';
                            else
                                msg = [];
                            end
    
                        case 'pattern'
                            % add value check for pat ID here
                            msg = [];
    
                        case 'frame_index'
                            % add value check for posX here
                            msg = [];
    
                        case 'duration'
                            % add value check for duration here
                            msg = [];
    
                        case 'frame_rate'
                            % add limits for frame rate here
                            msg = [];
    
                        case 'gain'
                            % add limits for gain here
                            msg = [];
    
                        case 'gs_val'
                            if command.gs_val ~=2 && command.gs_val ~=16
                                msg = 'command failed due to invalid gs value';
                            else
                                msg = [];
                            end
    
                    end
                    if ~isempty(msg)
                        self.logger.log('ERROR', sprintf(msg));
                        error(msg);
                    else
                        self.logger.log('DEBUG', sprintf('parameters checked and valid.'));
                    end
    
                end
            end
    
        end
    end

    methods (Static)

        function id = getPatternID(pattern)
            
            % Extract pattern ID from filename following convention pat####_description.pat
            % Returns numeric ID without leading zeros
            %
            % Input:
            %   filename - string, pattern filename (e.g., 'pat0001_vertical_bars.pat')
            %
            % Output:
            %   id - numeric pattern ID without leading zeros
            
            % Use regexp to extract the 4-digit number after 'pat'
            match = regexp(pattern, '^pat(\d{4})', 'tokens');
            
            if isempty(match)
                error('Filename does not follow pat####_description.pat convention');
            end
            
            % Convert string to number (automatically removes leading zeros)
            id = str2double(match{1}{1});
        end

        
    end
end

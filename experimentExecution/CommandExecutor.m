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
            
                % Execute based on specific command
            switch commandName
                    
                case 'allOn'
                    suc = self.arenaController.allOn();
                    self.logger.log('INFO', sprintf('all on success: %d', suc));
                    
                case 'allOff'
                    suc = self.arenaController.allOff();
                    self.logger.log('INFO', sprintf('all off success: %d', suc));
                    
                case 'stopDisplay'
                    suc = self.arenaController.stopDisplay(); 
                    self.logger.log('INFO', sprintf('stop display success: %d', suc));

                case 'setPositionX'
                    if ~isfield(command, 'posX')
                        self.logger.log('ERROR', sprintf('setPositionX failed due to missing parameter.'));
                        error('posX parameter missing, cannot execute setPositionX');
                    else
                        posX = command.posX;
                        suc = self.arenaController.setPositionX(posX);
                        self.logger.log('INFO', sprintf('set position x succes: %d', suc));
                    end

                case 'setColorDepth'
                    if ~isfield(command, 'gs_val')
                        self.logger.log('ERROR', sprintf('set color depth failed due to missing parameter'));
                        error('gs_val parameter missing, cannot execute setColorDepth');
                        
                    else
                        gs_val = command.gs_val;
                        suc = self.arenaController.setColorDepth(gs_val);
                        self.logger.log('INFO', sprintf('set color depth success: %d', suc));
                    end

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

                    % Log info about parameters ignored by specific modes
                    if mode == 2 && gain ~= 0
                        self.logger.log('INFO', sprintf('Note: gain=%d is ignored in mode 2 (constant rate)', gain));
                    elseif mode == 3
                        if frameRate ~= 0
                            self.logger.log('INFO', sprintf('Note: frame_rate=%d is ignored in mode 3 (position stream)', frameRate));
                        end
                        if gain ~= 0
                            self.logger.log('INFO', sprintf('Note: gain=%d is ignored in mode 3 (position stream)', gain));
                        end
                    elseif mode == 4 && frameRate ~= 0
                        self.logger.log('INFO', sprintf('Note: frame_rate=%d is ignored in mode 4 (closed-loop ADC)', frameRate));
                    end

                    % Execute using trialParams which waits for "Sequence completed"
                    self.logger.log('INFO', sprintf('Trial: mode=%d, patID=%d, pos=%d, dur=%.1fs, fps=%d, gain=%d', ...
                        mode, patID, posX, dur, frameRate, gain));
                    suc = self.arenaController.trialParams(mode, patID, frameRate, posX, gain, dur*10, true);
                    if ~suc
                        self.logger.log('WARNING', 'trialParams returned false - trial may not have completed successfully');
                    end
 
                otherwise
                    self.logger.log('ERROR', sprintf('command failed due to unknown controller command %s',commandName));
                    error('Unknown controller command: %s', commandName);
            end

            self.logger.log('INFO', sprintf('%s command completed', commandName));
           
        end
        
        function executeWaitCommand(self, command)
            % Pause execution
            %
            % Command fields:
            %   duration - Wait duration in milliseconds
            
            if ~isfield(command, 'duration')
                error('Wait command missing ''duration'' field');
            end
            
            duration = command.duration;
            
            self.logger.log('INFO', sprintf('Wait command: %d ms', duration));
            
            % Convert milliseconds to seconds and pause
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
            
            if ~isfield(command, 'plugin_name')
                error('Plugin command missing ''plugin_name'' field');
            end
            
            pluginID = command.plugin_name;
            
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
                    
                    self.pluginManager.executePluginCommand(pluginID, ...
                                                          'command', commandName);
                    
                case 'class'
                    if ~isfield(command, 'command_name')
                        error('ClassPlugin requires ''command_name'' field');
                    end
                    
                    methodName = command.command_name;
                    self.logger.log('DEBUG', sprintf('  Method: %s', methodName));
                    
                    if isfield(command, 'params')
                        params = command.params;
                        self.pluginManager.executePluginCommand(pluginID, ...
                                                              'method', methodName, ...
                                                              'params', params);
                    else
                        self.pluginManager.executePluginCommand(pluginID, ...
                                                              'method', methodName);
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

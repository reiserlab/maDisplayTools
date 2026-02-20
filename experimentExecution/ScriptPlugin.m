classdef ScriptPlugin < handle
    % Executes user-defined MATLAB scripts and functions
    %
    % This plugin type allows execution of MATLAB .m files (scripts or functions)
    % during experiment execution. Supports both parameterless scripts and
    % functions that accept parameters.
    %
    % YAML Definition Format:
    %   plugins:
    %     my_script:
    %       type: script
    %       script_path: 'path/to/script.m'
    %       script_type: 'function'         # 'function' or 'script', default: 'function'
    %       base_path: 'path/to/scripts'    # optional, added to path
    %       workspace: 'caller'             # 'caller' or 'base', default: 'caller'
    %
    % Function Requirements (script_type: 'function'):
    %   - Must be a MATLAB function: function result = myFunc(params)
    %   - Receives params struct as single argument
    %   - Can return a result value
    %   - Better encapsulation than scripts
    %
    % Script Requirements (script_type: 'script'):
    %   - Pure MATLAB script (no function declaration)
    %   - Executes in specified workspace
    %   - Cannot directly receive parameters (uses workspace variables)
    %   - Cannot return values directly
    %
    % Usage in Protocol:
    %   pretrial:
    %     plugin_actions:
    %       - plugin: my_script
    %         action: run
    %         params:
    %           input_value: 42
    %           filename: 'output.txt'
    
    properties (Access = private)
        name           % Plugin name
        definition     % Plugin definition from YAML
        logger         % Logger instance
        scriptPath     % Full path to script/function file
        scriptType     % 'function' or 'script'
        functionName   % Name of function (if function type)
        addedPath      % Path that was added (for cleanup)
        workspace      % Workspace for script execution
        experimentDir
    end
    
    methods
        function self = ScriptPlugin(name, definition, logger)
            % SCRIPTPLUGIN Constructor
            %
            % Args:
            %   name: Plugin name (string)
            %   definition: Plugin definition struct from YAML
            %   logger: Logger instance
            
            self.name = name;
            self.definition = definition;
            self.logger = logger;
            self.addedPath = '';
            
            % Validate required fields
            self.validateDefinition();
            
            % Extract configuration (experiment directory if nothing else)
            self.extractConfiguration();
            
        end

        function initialize(self)
            % Make sure the script_path field and the script provided exist
            
            if ~isfield(self.definition, 'script_path')
                self.logger.log('ERROR', sprintf('%s is missing the path to the script.', ...
                    self.name));
                error('Missing script path.');
                
            elseif exist(self.definition.script_path, 'file') ~= 2
                self.logger.log('ERROR', sprintf(['file provided for the %s ...' ...
                    'plugin does not exist.'], self.name));
                error('ScriptPlugin:FileNotFound', ...
                    'Script file not found: %s', self.scriptPath);

            else
            
                self.scriptPath = self.definition.script_path;

            end
            
            % Determine script type
            if isfield(self.definition, 'script_type')
                self.scriptType = self.definition.script_type;
            else
                self.scriptType = 'function'; % Default to function
            end
            
            % Validate script type
            if ~ismember(self.scriptType, {'function'})
                error('ScriptPlugin:InvalidType', ...
                    'script_type must be "function" for now, got: %s', ...
                    self.scriptType);
            end
            
            
            % Set workspace
            if isfield(self.definition, 'workspace')
                self.workspace = self.definition.workspace;
            else
                self.workspace = 'caller'; % Default
            end
            
            % Add path 
            [scriptDir, ~] = fileparts(self.scriptPath);
            addpath(scriptDir);
            self.addedPath = scriptDir;
            self.logger.log('DEBUG', sprintf('[%s] added to path', self.name));

            if strcmp(self.scriptType, 'function')
                [~, self.functionName, ~] = fileparts(self.scriptPath);
            else
                self.logger.log('ERROR', sprintf('for right now script plugins must be functions'));
                error('Your script plugin must be a function');
            end
            
           
            
            self.logger.log('INFO', sprintf('[%s] Initialized %s: %s', ...
                self.name, self.scriptType, self.scriptPath));
        end
        
        function result = execute(self, params)
            % Run the script or function
            %
            % Args:
            %   action: Action name (typically 'run' or custom action name)
            %   params: Struct with parameters to pass to function/script
            %
            % Returns:
            %   result: Return value from function (empty for scripts)
            
            try
                self.logger.log('DEBUG', sprintf('[%s] Executing %s', ...
                    self.name, self.scriptType));
                if ~exist('params','var')
                    params = [];
                end
                
                if strcmp(self.scriptType, 'function')
                    result = self.executeFunction(params);
                else
                    result = self.executeScript(params);
                end
                
                self.logger.log('DEBUG', sprintf('[%s] Execution completed', self.name));
                
            catch ME
                self.logger.log('ERROR', sprintf('[%s] Execution failed: %s', ...
                    self.name, ME.message));
                rethrow(ME);
            end
        end
        
        function close(self)
            % Close plugin (called by PluginManager.closeAll)
            self.cleanup();
        end

        function cleanup(self)
            % Remove added paths
            
            % Remove added path if any
            if ~isempty(self.addedPath)
                try
                    rmpath(self.addedPath);
                    self.logger.log('DEBUG', sprintf('[%s] Removed path: %s', ...
                        self.name, self.addedPath));
                catch ME
                    self.logger.log('WARNING', sprintf('[%s] Error removing path: %s', ...
                        self.name, ME.message));
                end
            end
            
            self.logger.log('INFO', sprintf('[%s] Plugin cleaned up', self.name));
        end
        
        function status = getStatus(self)
            % Get current plugin status
            %
            % Returns:
            %   status: Struct with plugin information
            
            status = struct();
            status.name = self.name;
            status.scriptPath = self.scriptPath;
            status.scriptType = self.scriptType;
            status.exists = exist(self.scriptPath, 'file') == 2;
            
            if strcmp(self.scriptType, 'function')
                status.functionName = self.functionName;
                status.callable = exist(self.functionName, 'file') == 2;
            else
                status.functionName = '';
                status.callable = status.exists;
            end
        end

        function type = getPluginType(self)

            type = 'script';
        end

        function type = getScriptType(self)

            type = self.scriptType;
        end
        
        function result = validateScript(self)
            % Check if script/function is valid
            %
            % Returns:
            %   result: true if valid, error otherwise
            
            if ~exist(self.scriptPath, 'file')
                error('ScriptPlugin:FileNotFound', ...
                    'Script file not found: %s', self.scriptPath);
            end
            
            if strcmp(self.scriptType, 'function')
                if exist(self.functionName, 'file') ~= 2
                    error('ScriptPlugin:FunctionNotFound', ...
                        'Function not found: %s', self.functionName);
                end
            end
            
            result = true;
        end
    end
    
    methods (Access = private)
        function validateDefinition(self)
            % Check required fields in definition
            
            if ~isfield(self.definition, 'script_path')
                error('ScriptPlugin:MissingField', ...
                    'Plugin "%s" missing required field: script_path', self.name);
            end
        end

        function extractConfiguration(self)

            if isfield(self.definition, 'config') && isfield(self.definition.config, 'experimentDir')
                self.experimentDir = self.definition.config.experimentDir;
            else
                self.experimentDir = pwd;
            end

        end
            
        
        function result = executeFunction(self, params)
            % Call function with parameters
            %
            % Args:
            %   params: Struct to pass to function
            %
            % Returns:
            %   result: Function return value
            
            try
                % Check number of output arguments
                nout = nargout(self.functionName);
                
                if nout == 0
                    % Function doesn't return anything
                    feval(self.functionName, params);
                    result = [];
                else
                    % Function returns value(s)
                    result = feval(self.functionName, params);
                end
                
            catch ME
                error('ScriptPlugin:ExecutionError', ...
                    'Error executing function %s: %s', ...
                    self.functionName, ME.message);
            end
        end
        
        function result = executeScript(self, params)
            % Run script in specified workspace
            %
            % Args:
            %   params: Struct with variables to set in workspace
            %
            % Returns:
            %   result: Empty (scripts can't return values)
            %
            % Note: Parameters are written to workspace as individual variables
            
            % Write params to workspace
            if ~isempty(params) && isstruct(params)
                fieldNames = fieldnames(params);
                for i = 1:length(fieldNames)
                    assignin(self.workspace, fieldNames{i}, params.(fieldNames{i}));
                end
                
                self.logger.log('DEBUG', sprintf('[%s] Set %d variables in %s workspace', ...
                    self.name, length(fieldNames), self.workspace));
            end
            
            try
                % Run the script
                if strcmp(self.workspace, 'base')
                    evalin('base', sprintf("run('%s')", self.scriptPath));
                else
                    run(self.scriptPath);
                end
                
                result = [];
                
            catch ME
                error('ScriptPlugin:ExecutionError', ...
                    'Error executing script %s: %s', ...
                    self.scriptPath, ME.message);
            end
        end
    end
end

% Helper function
function result = isAbsolutePath(pathStr)
    % Check if path is absolute (cross-platform)
    if ispc
        % Windows: check for drive letter or UNC path
        result = ~isempty(regexp(pathStr, '^[A-Za-z]:', 'once')) || ...
                 startsWith(pathStr, '\\');
    else
        % Unix/Mac: check for leading /
        result = startsWith(pathStr, '/');
    end
end

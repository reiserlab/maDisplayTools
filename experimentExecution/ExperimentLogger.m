classdef ExperimentLogger < handle
    % EXPERIMENTLOGGER Manages experiment logging to file and console
    %
    % Supports different log levels: DEBUG, INFO, WARNING, ERROR
    % Writes to both log file and optionally to console
    
    properties (Access = private)
        logFile         % Path to log file
        fileID          % File handle for log file
        verbose         % Whether to echo logs to console
        logLevel        % Minimum log level to record
    end
    
    properties (Constant)
        % Log level hierarchy
        LEVELS = struct('DEBUG', 0, 'INFO', 1, 'WARNING', 2, 'ERROR', 3);
    end
    
    methods (Access = public)
        function self = ExperimentLogger(logFile, verbose, logLevel)
            % Constructor
            %
            % Input Arguments:
            %   logFile - Path to log file
            %   verbose - Echo logs to console (default: false)
            %   logLevel - Minimum level to log (default: 'DEBUG')
            
            if nargin < 2
                verbose = false;
            end
            if nargin < 3
                logLevel = 'DEBUG';
            end
            
            self.logFile = logFile;
            self.verbose = verbose;
            self.logLevel = logLevel;
            
            % Open log file
            self.openLogFile();
            
            % Write header
            self.writeHeader();
        end
        
        function log(self, level, message)
            % LOG Write log entry
            %
            % Input Arguments:
            %   level - Log level: 'DEBUG', 'INFO', 'WARNING', 'ERROR'
            %   message - Log message string
            
            % Check if this level should be logged
            if self.LEVELS.(level) < self.LEVELS.(self.logLevel)
                return;  % Below minimum log level
            end
            
            % Create timestamp
            %% TODO: Update this 
            timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF');
            
            % Format log entry
            logEntry = sprintf('[%s] %s: %s\n', timestamp, level, message);
            
            % Write to file
            fprintf(self.fileID, '%s', logEntry);
            
            % Flush to disk immediately (ensures logs saved even if crash)
            % Note: This may impact performance for high-frequency logging
            % fflush(self.fileID);  % Uncomment if needed
            
            % Echo to console if verbose
            if self.verbose
                switch level
                    case 'ERROR'
                        fprintf(2, '%s', logEntry);  % stderr
                    case 'WARNING'
                        fprintf(2, '%s', logEntry);  % stderr
                    otherwise
                        fprintf('%s', logEntry);      % stdout
                end
            end
        end
        
        function logCommand(self, commandType, parameters)
            % Log command execution with parameters
            %
            % Input Arguments:
            %   commandType - Type of command
            %   parameters - Struct of command parameters
            
            paramStr = self.structToString(parameters);
            message = sprintf('Executing %s: %s', commandType, paramStr);
            self.log('INFO', message);
        end
        
        function logTrial(self, trialNum, conditionID, duration)
            % Log trial completion
            %
            % Input Arguments:
            %   trialNum - Trial number
            %   conditionID - Condition identifier
            %   duration - Trial duration in seconds
            
            message = sprintf('Trial %d (%s) completed in %.2f s', ...
                             trialNum, conditionID, duration);
            self.log('INFO', message);
        end
        
        function close(self)
            % Close log file
            
            if ~isempty(self.fileID) && self.fileID > 0
                self.log('INFO', 'Closing log file');
                
                % Write footer
                fprintf(self.fileID, '\n=== LOG END ===\n');
                fprintf(self.fileID, 'Closed: %s\n', datestr(now));
                
                % Close file
                fclose(self.fileID);
                self.fileID = -1;
            end
        end
        
        function delete(self)
            % DELETE Destructor - ensure file is closed
            
            self.close();
        end
    end
    
    methods (Access = private)
        function openLogFile(self)
            % OPENLOGFILE Open log file for writing
            
            % Create log directory if needed
            [logDir, ~, ~] = fileparts(self.logFile);
            if ~exist(logDir, 'dir')
                mkdir(logDir);
            end
            
            % Open file
            self.fileID = fopen(self.logFile, 'w');
            
            if self.fileID == -1
                error('Failed to open log file: %s', self.logFile);
            end
        end
        
        function writeHeader(self)
            % Write log file header
            
            fprintf(self.fileID, '=== EXPERIMENT LOG ===\n');
            fprintf(self.fileID, 'Created: %s\n', datestr(now));
            fprintf(self.fileID, 'Log Level: %s\n', self.logLevel);
            fprintf(self.fileID, '======================\n\n');
        end
        
        function str = structToString(self, s)
            % STRUCTTOSTRING Convert struct to readable string
            %
            % Input Arguments:
            %   s - Struct to convert
            %
            % Returns:
            %   str - String representation
            
            if isempty(s) || ~isstruct(s)
                str = '{}';
                return;
            end
            
            fields = fieldnames(s);
            parts = cell(1, length(fields));
            
            for i = 1:length(fields)
                field = fields{i};
                value = s.(field);
                
                if ischar(value)
                    parts{i} = sprintf('%s=''%s''', field, value);
                elseif isnumeric(value) && isscalar(value)
                    parts{i} = sprintf('%s=%g', field, value);
                elseif isnumeric(value) && isvector(value)
                    parts{i} = sprintf('%s=[%s]', field, num2str(value));
                else
                    parts{i} = sprintf('%s=<complex>', field);
                end
            end
            
            str = sprintf('{%s}', strjoin(parts, ', '));
        end
    end
end

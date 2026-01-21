function run_protocol(protocolFilePath, arenaIP, varargin)
% RUN_PROTOCOL Execute a G4.1 display experiment from a YAML protocol file
%
% Syntax:
%   run_protocol(protocolFilePath)
%   run_protocol(protocolFilePath, Name, Value)
%
% Description:
%   This is the main entry point for executing experiments defined in YAML
%   protocol files. It initializes all hardware, plugins, and executes the
%   experimental sequence.
%
% Input Arguments:
%   protocolFilePath - Path to the YAML protocol file (required)
%
% Name-Value Pairs:
%   'OutputDir' - Base directory for experiment outputs (default: './experiments')
%   'Verbose' - Enable verbose logging (default: true)
%   'DryRun' - Validate protocol without executing (default: false)
%
% Example:
%   run_protocol('protocol.yaml')
%   run_protocol('protocol.yaml', 'OutputDir', './my_experiments')
%   run_protocol('protocol.yaml', 'Verbose', false, 'DryRun', true)
%
% Notes:
%   - Pattern files must be manually copied to SD card before running
%   - Requires pattern_mapping section in protocol YAML
%   - All plugins and scripts must be on MATLAB path
%
% See also: ProtocolRunner
    [yamlLocation, yamlFilename, ~] = fileparts(protocolFilePath);
    if isempty(yamlLocation)
        yamlLocation = '.';
    end
    % Parse input arguments
    p = inputParser;
    addRequired(p, 'protocolFilePath', @(x) ischar(x) || isstring(x));
    addRequired(p, 'arenaIP', @ischar);
    addParameter(p, 'OutputDir', yamlLocation, @(x) ischar(x) || isstring(x));
    addParameter(p, 'Verbose', true, @islogical);
    addParameter(p, 'DryRun', false, @islogical);
    parse(p, protocolFilePath, arenaIP, varargin{:});
    
    % Convert to char if string
    protocolFilePath = char(p.Results.protocolFilePath);
    outputDir = char(p.Results.OutputDir);
    
    % Validate protocol file exists
    if ~exist(protocolFilePath, 'file')
        error('Protocol file not found: %s', protocolFilePath);
    end
    
    % Create and configure protocol runner
    runner = ProtocolRunner(protocolFilePath, arenaIP, ...
                           'OutputDir', outputDir, ...
                           'Verbose', p.Results.Verbose, ...
                           'DryRun', p.Results.DryRun);
    
    % Execute the protocol with error handling
    try
        runner.run();
        fprintf('\n=== Finalizing Experiment ===\n');
        
    catch ME
        % Log error
        fprintf(2, '\n!!! Experiment failed with error !!!\n');
        fprintf(2, 'Error: %s\n', ME.message);
        fprintf(2, 'In: %s (line %d)\n', ME.stack(1).file, ME.stack(1).line);
        
        % Attempt cleanup
        try
            runner.cleanup();
        catch cleanupError
            fprintf(2, 'Cleanup also failed: %s\n', cleanupError.message);
        end
        
        % Re-throw original error
        rethrow(ME);
    end
        
end

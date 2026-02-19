function simple_demo()
    
    %% Use yaml file saved in examples/SimpleYamlExperimentDemo as yaml path
    % Update to match path on your machine
    yamlPath = '/Users/lisaferguson/Documents/PC/Programming/Reiser/maDisplayTools/examples/SimpleYamlExperimentDemo/simple_protocol_v1.yaml';
    % Change this path to a location easy to find on your computer. The
    % path where your yaml file is saved is a smart choice
    expFolder = '/Users/lisaferguson/Documents/PC/Programming/Reiser/maDisplayTools/examples/simpleDemo';
    % This yaml file uses patterns saved in
    % examples/SimpleYamlExperimentDemo. They are for a 2 row, 12 column
    % arena. They are all the same pattern, this is for demonstration
    % purposes only. 

    %% Next you must set up the sd card to contain the patterns for the demo.
    
    sd_drive = 'D'; % Set the drive letter for the sd card when it's plugged into the PC
    deploy_experiments_to_sd(yamlPath, sd_drive);

    %% next you call run_protocol.m with the following inputs: 
    %   path to yaml - required
    %   ip address to connect to your particular arena - required
    %   'OutputDir' as string, value pair (output filepath) - optional 
    %   'Verbose' as string, value pair (true or false) - optional
    %   'DryRun' as string, value pair (true or false) - optional

    % If you don't provide an output directory, outputs will be saved in 
    % the same folder where the yaml file lives. Verbose defaults to true and provides more
    % information about what's happening as it happens. DryRun defaults to
    % false, set it to true if you want to validate your experiment but not
    % actually run it. 

    run_protocol(yamlPath, '192.168.10.62', 'OutputDir', fullfile(expFolder, 'Results'), 'Verbose', false)
    
    % Works until plugin initialization, need to implement the class to
    % handle script plugins and make a dummy plugin for the demo.
end
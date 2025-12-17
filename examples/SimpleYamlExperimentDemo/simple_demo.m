function simple_demo()
    
    %% Use yaml file saved in examples/SimpleYamlExperimentDemo as yaml path
    % Update to match path on your machine
    yamlPath = '/Users/lisaferguson/Documents/PC/Programming/Reiser/maDisplayTools/examples/SimpleYamlExperimentDemo/simple_protocol_v1.yaml';

    % This yaml file uses patterns saved in
    % examples/SimpleYamlExperimentDemo. They are for a 2 row, 12 column
    % arena. They are all the same pattern, this is for demonstration
    % purposes only. 
    
    % Change this path to a location easy to find on your computer
    expFolder = '/Users/lisaferguson/Documents/PC/Programming/Reiser/maDisplayTools/examples/simpleDemo';

    [~, yamlFilename, ext] = fileparts(yamlPath);
    yamlFilename = [yamlFilename ext];
    % First step is to create an experiment folder. 
    
    maDisplayTools.create_experiment_folder_g41(yamlPath, expFolder);
    cd(expFolder); 

    % Now you have an experiment folder saved with three patterns and a
    % yaml file. This is what a real experiment will look like. 

    % next you call run_protocol.m with the following inputs: 
    %   path to yaml in your new experiment folder - required
    %   ip address to connect to your particular arena - required
    %   'OutputDir' as string, value pair (output filepath) - optional 
    %   'Verbose' as string, value pair (true or false) - optional
    %   'DryRun' as string, value pair (true or false) - optional

    % If you don't provide an output directory, outputs will be saved in 
    % './experiments'. Verbose defaults to true and provides more
    % information about what's happening as it happens. DryRun defaults to
    % false, set it to true if you want to validate your experiment but not
    % actually run it. 

    run_protocol(fullfile(expFolder, yamlFilename), '192.168.10.62', 'OutputDir', fullfile(expFolder, 'Results'), 'Verbose', false)
    
    % Works until plugin initialization, need to implement the class to
    % handle script plugins and make a dummy plugin for the demo.
end
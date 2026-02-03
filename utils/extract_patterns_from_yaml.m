function [pattern_paths_per_yaml, yaml_files] = extract_patterns_from_yaml(yaml_file_paths)
% EXTRACT_PATTERNS_FROM_YAML Extract patterns from YAML files, organized per file
%
%   pattern_paths_per_yaml = extract_patterns_from_yaml(yaml_file_paths)
%   [pattern_paths_per_yaml, yaml_files] = extract_patterns_from_yaml(yaml_file_paths)
%
%   Extracts all pattern file paths from one or more YAML experiment protocol files.
%   Handles pattern_library field for relative path resolution.
%   Patterns are kept separated by source YAML file for validation purposes.
%   Order: pretrial -> block conditions -> intertrial -> posttrial (per YAML file).
%
%   INPUTS:
%       yaml_file_paths - String, char array, or cell array of YAML file path(s)
%
%   OUTPUTS:
%       pattern_paths_per_yaml - Cell array where pattern_paths_per_yaml{i}
%                                contains all resolved full paths from yaml_files{i}
%                                (may contain duplicates within or across YAMLs)
%       yaml_files             - Cell array of YAML file paths processed (normalized)
%
%   PATTERN_LIBRARY SUPPORT:
%       If experiment_info.pattern_library is specified in the YAML:
%         - Patterns can be referenced by filename only: "mypattern.pat"
%         - Full path is constructed: pattern_library + "/" + filename
%       
%       If pattern_library is empty or missing:
%         - Patterns must have full absolute paths
%
%   EXAMPLE:
%       % Single YAML
%       [patterns_per_yaml, yamls] = extract_patterns_from_yaml('experiment1.yaml');
%       patterns = patterns_per_yaml{1};  % Patterns from first YAML
%       
%       % Multiple YAMLs - patterns kept separate by source file
%       [patterns_per_yaml, yamls] = extract_patterns_from_yaml({'exp1.yaml', 'exp2.yaml'});
%       exp1_patterns = patterns_per_yaml{1};  % From exp1.yaml
%       exp2_patterns = patterns_per_yaml{2};  % From exp2.yaml
%       
%       % Flatten and deduplicate after validation if needed
%       all_patterns = [patterns_per_yaml{:}];
%       unique_patterns = unique(all_patterns, 'stable');
%
%   See also: prepare_sd_card, deploy_experiments_to_sd

    %% Input validation
    if nargin < 1
        error('extract_patterns_from_yaml:MissingInput', 'Must provide yaml_file_paths');
    end
    
    % Normalize to cell array
    if ischar(yaml_file_paths) || isstring(yaml_file_paths)
        yaml_file_paths = cellstr(yaml_file_paths);
    end
    
    if isempty(yaml_file_paths)
        pattern_paths_per_yaml = {};
        yaml_files = {};
        return;
    end
    
    % Validate all files exist
    for i = 1:length(yaml_file_paths)
        if ~isfile(yaml_file_paths{i})
            error('extract_patterns_from_yaml:FileNotFound', ...
                'YAML file not found: %s', yaml_file_paths{i});
        end
    end
    
    yaml_files = yaml_file_paths;
    
    %% Extract patterns from each YAML file (keep separated by file)
    pattern_paths_per_yaml = cell(length(yaml_file_paths), 1);
    
    for i = 1:length(yaml_file_paths)
        yaml_path = yaml_file_paths{i};
        fprintf('Processing %s...\n', yaml_path);
        
        try
            % Load YAML
            experiment_data = yaml.loadFile(yaml_path);
            
            % Extract patterns from this file
            file_patterns = extract_patterns_from_single_yaml(experiment_data, yaml_path);
            
            % Convert strings to char vectors if needed
            for j = 1:length(file_patterns)
                if isstring(file_patterns{j})
                    file_patterns{j} = char(file_patterns{j});
                end
            end
            
            % Store patterns for this YAML (keep separate, don't concatenate)
            pattern_paths_per_yaml{i} = file_patterns;
            
            fprintf('  Found %d pattern references\n', length(file_patterns));
            
        catch ME
            error('extract_patterns_from_yaml:ParseError', ...
                'Failed to process %s: %s', yaml_path, ME.message);
        end
    end
    
    %% Validate all pattern files exist
    fprintf('\nValidating pattern files...\n');
    missing_patterns = {};
    
    for i = 1:length(pattern_paths_per_yaml)
        patterns = pattern_paths_per_yaml{i};
        for j = 1:length(patterns)
            if ~isfile(patterns{j})
                missing_patterns{end+1} = sprintf('[%s] %s', yaml_files{i}, patterns{j}); %#ok<AGROW>
            end
        end
    end
    
    if ~isempty(missing_patterns)
        fprintf('\nERROR: The following pattern files were not found:\n');
        for i = 1:length(missing_patterns)
            fprintf('  - %s\n', missing_patterns{i});
        end
        error('extract_patterns_from_yaml:MissingPatterns', ...
            '%d pattern file(s) not found', length(missing_patterns));
    end
    
    fprintf('✓ All pattern files found\n');
end


function patterns = extract_patterns_from_single_yaml(experiment_data, yaml_path)
% Extract patterns from a single YAML structure in execution order
%
%   Order: pretrial -> block conditions -> intertrial -> posttrial

    patterns = {};
    
    % Get pattern_library if specified
    pattern_library = '';
    if isfield(experiment_data, 'experiment_info') && ...
       isfield(experiment_data.experiment_info, 'pattern_library') && ...
       ~isempty(experiment_data.experiment_info.pattern_library)
        pattern_library = experiment_data.experiment_info.pattern_library;
        fprintf('  Using pattern library: %s\n', pattern_library);
    end
    
    % Helper function to resolve pattern path
    resolve_path = @(pattern_ref) resolve_pattern_path(pattern_ref, pattern_library);
    
    % Helper function to extract patterns from commands list
    extract_from_commands = @(commands) extract_patterns_from_commands(commands, resolve_path);
    
    % 1. Pretrial
    if isfield(experiment_data, 'pretrial')
        pretrial = experiment_data.pretrial;
        if isfield(pretrial, 'include') && pretrial.include
            if isfield(pretrial, 'commands')
                pretrial_patterns = extract_from_commands(pretrial.commands);
                patterns = [patterns; pretrial_patterns];
            end
        end
    end
    
    % 2. Block conditions
    if isfield(experiment_data, 'block') && isfield(experiment_data.block, 'conditions')
        conditions = experiment_data.block.conditions;
        
        % Handle both cell array and struct array
        if iscell(conditions)
            % Cell array of structs
            for i = 1:length(conditions)
                condition = conditions{i};
                if isfield(condition, 'commands')
                    cond_patterns = extract_from_commands(condition.commands);
                    patterns = [patterns; cond_patterns];
                end
            end
        else
            % Struct array
            for i = 1:length(conditions)
                condition = conditions(i);
                if isfield(condition, 'commands')
                    cond_patterns = extract_from_commands(condition.commands);
                    patterns = [patterns; cond_patterns];
                end
            end
        end
    end
    
    % 3. Intertrial
    if isfield(experiment_data, 'intertrial')
        intertrial = experiment_data.intertrial;
        if isfield(intertrial, 'include') && intertrial.include
            if isfield(intertrial, 'commands')
                intertrial_patterns = extract_from_commands(intertrial.commands);
                patterns = [patterns; intertrial_patterns];
            end
        end
    end
    
    % 4. Posttrial
    if isfield(experiment_data, 'posttrial')
        posttrial = experiment_data.posttrial;
        if isfield(posttrial, 'include') && posttrial.include
            if isfield(posttrial, 'commands')
                posttrial_patterns = extract_from_commands(posttrial.commands);
                patterns = [patterns; posttrial_patterns];
            end
        end
    end
    
    % Convert to column vector
    patterns = patterns(:);
end


function patterns = extract_patterns_from_commands(commands, resolve_path)
% Extract patterns from a commands list
%
%   commands - cell array or struct array of command structs
%   resolve_path - function handle to resolve pattern paths

    patterns = {};
    
    if isempty(commands)
        return;
    end
    
    % Handle both cell array and struct array
    if iscell(commands)
        % Cell array of structs
        for i = 1:length(commands)
            command = commands{i};
            if isstruct(command) && isfield(command, 'pattern')
                pattern_path = resolve_path(command.pattern);
                % Ensure it's a char vector, not a string
                if isstring(pattern_path)
                    pattern_path = char(pattern_path);
                end
                patterns{end+1} = pattern_path; %#ok<AGROW>
            end
        end
    else
        % Struct array
        for i = 1:length(commands)
            command = commands(i);
            if isfield(command, 'pattern')
                pattern_path = resolve_path(command.pattern);
                % Ensure it's a char vector, not a string
                if isstring(pattern_path)
                    pattern_path = char(pattern_path);
                end
                patterns{end+1} = pattern_path; %#ok<AGROW>
            end
        end
    end
    
    % Convert to column vector
    patterns = patterns(:);
end


function full_path = resolve_pattern_path(pattern_ref, pattern_library)
% Resolve pattern reference to full path using pattern_library if needed
%
%   If pattern_library is specified and pattern_ref is just a filename,
%   constructs: pattern_library/pattern_ref
%
%   Otherwise returns pattern_ref as-is (assumed to be full path)

    if isempty(pattern_library)
        % No library specified - pattern_ref must be full path
        full_path = pattern_ref;
    else
        % Check if pattern_ref looks like a full path (contains / or \, or starts with drive letter)
        is_full_path = contains(pattern_ref, filesep) || ...
                      contains(pattern_ref, '/') || ...
                      contains(pattern_ref, '\') || ...
                      (ispc && length(pattern_ref) > 2 && pattern_ref(2) == ':');
        
        if is_full_path
            % Already a full path - use as-is
            full_path = pattern_ref;
        else
            % Just a filename - prepend pattern_library
            full_path = fullfile(pattern_library, pattern_ref);
        end
    end
end

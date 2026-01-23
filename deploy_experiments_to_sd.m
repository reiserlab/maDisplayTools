function result = deploy_experiments_to_sd(yaml_file_paths, sd_drive, staging_dir)
% DEPLOY_EXPERIMENTS_TO_SD Extract patterns from YAMLs and deploy to SD card
%
%   result = deploy_experiments_to_sd(yaml_file_paths, sd_drive)
%   result = deploy_experiments_to_sd(yaml_file_paths, sd_drive, staging_dir)
%
%   High-level wrapper that:
%     1. Extracts patterns from one or more YAML files
%     2. Deploys them to SD card using prepare_sd_card()
%     3. Updates each YAML file with SD card pattern mapping
%
%   INPUTS:
%       yaml_file_paths - String, char array, or cell array of YAML file path(s)
%       sd_drive        - Drive letter for SD card (e.g., 'E' or 'E:')
%       staging_dir     - (Optional) Path for staging directory
%
%   OUTPUTS:
%       result - Struct with fields:
%           .success          - true if entire process succeeded
%           .error            - error message if failed, empty if success
%           .yaml_files       - cell array of YAML files processed
%           .num_patterns     - total unique patterns deployed
%           .sd_mapping       - mapping struct from prepare_sd_card()
%           .yaml_updates     - cell array of structs with update info per YAML
%
%   YAML UPDATES:
%       Adds a 'sd_card_mapping' section to each YAML file with:
%         - timestamp: when SD card was prepared
%         - sd_drive: drive letter used
%         - mappings: list of pattern mappings for patterns used in this YAML
%
%       Example added to YAML:
%         sd_card_mapping:
%           timestamp: '2026-01-19T15:30:00'
%           sd_drive: E
%           mappings:
%             - original: /data/patterns/vertical_grating.pat
%               sd_name: PAT0001.pat
%             - original: /data/patterns/checkerboard.pat
%               sd_name: PAT0003.pat
%
%   EXAMPLE:
%       % Deploy single experiment
%       result = deploy_experiments_to_sd('experiment1.yaml', 'E');
%       if ~result.success
%           fprintf('Error: %s\n', result.error);
%       end
%       
%       % Deploy multiple experiments (shares patterns)
%       yamls = {'exp1.yaml', 'exp2.yaml', 'exp3.yaml'};
%       result = deploy_experiments_to_sd(yamls, 'E');
%
%   See also: prepare_sd_card, extract_patterns_from_yaml

    %% Initialize result struct
    result = struct();
    result.success = false;
    result.error = '';
    result.yaml_files = {};
    result.num_patterns = 0;
    result.sd_mapping = struct();
    result.yaml_updates = {};
    
    %% Input validation
    if nargin < 2
        result.error = 'Must provide yaml_file_paths and sd_drive';
        return;
    end
    
    if nargin < 3
        staging_dir = '';  % Let prepare_sd_card use default
    end
    
    %% Step 1: Extract patterns from YAML files
    fprintf('\n=== Extracting patterns from YAML files ===\n');
    
    try
        [pattern_paths, yaml_files] = extract_patterns_from_yaml(yaml_file_paths);
    catch ME
        result.error = sprintf('Pattern extraction failed: %s', ME.message);
        return;
    end
    
    result.yaml_files = yaml_files;
    result.num_patterns = length(pattern_paths);
    
    if result.num_patterns == 0
        result.error = 'No patterns found in YAML file(s)';
        return;
    end
    
    fprintf('\nReady to deploy %d unique patterns\n', result.num_patterns);
    
    %% Step 2: Deploy to SD card
    fprintf('\n=== Deploying to SD card ===\n');
    
    try
        if isempty(staging_dir)
            sd_mapping = prepare_sd_card(pattern_paths, sd_drive, 'Format', true);
        else
            sd_mapping = prepare_sd_card(pattern_paths, sd_drive, 'StagingDir', staging_dir, 'Format', true);
        end
    catch ME
        result.error = sprintf('SD card deployment failed: %s', ME.message);
        return;
    end
    
    if ~sd_mapping.success
        result.error = sprintf('SD card deployment failed: %s', sd_mapping.error);
        result.sd_mapping = sd_mapping;
        return;
    end
    
    result.sd_mapping = sd_mapping;
    
    fprintf('\n=== SD card deployment successful ===\n');
    
    %% Step 3: Update YAML files with SD card mapping
    fprintf('\n=== Updating YAML files ===\n');
    
    result.yaml_updates = cell(length(yaml_files), 1);
    total_ids_updated = 0;
    
    for i = 1:length(yaml_files)
        yaml_path = yaml_files{i};
        fprintf('Updating %s...\n', yaml_path);
        
        try
            update_info = update_yaml_with_sd_mapping(yaml_path, sd_mapping);
            result.yaml_updates{i} = update_info;
            fprintf('  Added %d pattern mappings\n', update_info.num_mappings);
            fprintf('  Updated %d pattern_ID fields\n', update_info.num_ids_updated);
            total_ids_updated = total_ids_updated + update_info.num_ids_updated;
        catch ME
            warning('Failed to update %s: %s', yaml_path, ME.message);
            result.yaml_updates{i} = struct('success', false, 'error', ME.message);
            % Don't fail entire process - SD card is already written
        end
    end
    
    %% Success
    result.success = true;
    
    fprintf('\n=== Deployment complete ===\n');
    fprintf('Patterns deployed: %d\n', result.num_patterns);
    fprintf('YAML files updated: %d\n', length(yaml_files));
    fprintf('Pattern IDs updated: %d\n', total_ids_updated);
    fprintf('SD card: %s:\n', sd_mapping.sd_drive);
    fprintf('Log saved: %s\n', sd_mapping.log_file);
end


function update_info = update_yaml_with_sd_mapping(yaml_path, sd_mapping)
% Update a single YAML file with SD card pattern mapping
%
%   Adds 'sd_card_mapping' section with timestamp, drive, and pattern mappings
%   Updates 'pattern_ID' fields in commands to match SD card numbering
%   Only includes patterns that are actually used in this YAML

    update_info = struct();
    update_info.success = false;
    update_info.yaml_file = yaml_path;
    update_info.num_mappings = 0;
    update_info.num_ids_updated = 0;
    update_info.error = '';
    
    % Load YAML
    experiment_data = yaml.loadFile(yaml_path);
    
    % Get pattern_library if specified
    pattern_library = '';
    if isfield(experiment_data, 'experiment_info') && ...
       isfield(experiment_data.experiment_info, 'pattern_library') && ...
       ~isempty(experiment_data.experiment_info.pattern_library)
        pattern_library = experiment_data.experiment_info.pattern_library;
    end
    
    % Build mapping: original_path -> SD card ID number
    % Pattern ID is simply the index in sd_mapping.patterns array
    % (sd_mapping.patterns{1} = ID 1, sd_mapping.patterns{2} = ID 2, etc.)
    path_to_id = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for i = 1:length(sd_mapping.patterns)
        original_path = sd_mapping.patterns{i}.original_path;
        % ID is the array index
        id_num = i;
        path_to_id(original_path) = id_num;
    end
    
    % Update pattern_ID fields in commands throughout the YAML
    num_ids_updated = 0;
    
    % Helper function to update commands in a section
    update_commands = @(commands) update_pattern_ids_in_commands(commands, path_to_id, pattern_library);
    
    % Update pretrial
    if isfield(experiment_data, 'pretrial') && isfield(experiment_data.pretrial, 'commands')
        [experiment_data.pretrial.commands, count] = update_commands(experiment_data.pretrial.commands);
        num_ids_updated = num_ids_updated + count;
    end
    
    % Update block conditions
    if isfield(experiment_data, 'block') && isfield(experiment_data.block, 'conditions')
        conditions = experiment_data.block.conditions;
        
        if iscell(conditions)
            % Cell array of conditions
            for i = 1:length(conditions)
                if isfield(conditions{i}, 'commands')
                    [conditions{i}.commands, count] = update_commands(conditions{i}.commands);
                    num_ids_updated = num_ids_updated + count;
                end
            end
        else
            % Struct array
            for i = 1:length(conditions)
                if isfield(conditions(i), 'commands')
                    [conditions(i).commands, count] = update_commands(conditions(i).commands);
                    num_ids_updated = num_ids_updated + count;
                end
            end
        end
        
        experiment_data.block.conditions = conditions;
    end
    
    % Update intertrial
    if isfield(experiment_data, 'intertrial') && isfield(experiment_data.intertrial, 'commands')
        [experiment_data.intertrial.commands, count] = update_commands(experiment_data.intertrial.commands);
        num_ids_updated = num_ids_updated + count;
    end
    
    % Update posttrial
    if isfield(experiment_data, 'posttrial') && isfield(experiment_data.posttrial, 'commands')
        [experiment_data.posttrial.commands, count] = update_commands(experiment_data.posttrial.commands);
        num_ids_updated = num_ids_updated + count;
    end
    
    update_info.num_ids_updated = num_ids_updated;
    
    % Extract patterns used in this YAML (with full paths) for the mapping section
    yaml_patterns = extract_patterns_from_single_yaml(experiment_data, yaml_path);
    
    % Build SD card mapping for just the patterns in this YAML
    mappings = {};
    for i = 1:length(yaml_patterns)
        yaml_pattern = yaml_patterns{i};
        
        % Find this pattern in the SD card mapping
        for j = 1:length(sd_mapping.patterns)
            if strcmp(sd_mapping.patterns{j}.original_path, yaml_pattern)
                % Found it - add to mappings
                sd_name = sd_mapping.patterns{j}.new_name;
                sd_id = sscanf(sd_name, 'PAT%d.pat');
                
                mapping_entry = struct();
                mapping_entry.original = yaml_pattern;
                mapping_entry.sd_name = sd_name;
                mapping_entry.sd_id = sd_id;
                mappings{end+1} = mapping_entry; %#ok<AGROW>
                break;
            end
        end
    end
    
    update_info.num_mappings = length(mappings);
    
    % Create sd_card_mapping section
    sd_card_mapping_section = struct();
    sd_card_mapping_section.timestamp = sd_mapping.timestamp;
    sd_card_mapping_section.sd_drive = sd_mapping.sd_drive;
    sd_card_mapping_section.num_patterns_on_card = sd_mapping.num_patterns;
    sd_card_mapping_section.num_patterns_in_experiment = length(mappings);
    sd_card_mapping_section.mappings = mappings;
    
    % Add to experiment_data
    experiment_data.sd_card_mapping = sd_card_mapping_section;
    
    % Save updated YAML
    yaml.dumpFile(yaml_path, experiment_data, 'block');
    
    update_info.success = true;
end


function [updated_commands, num_updated] = update_pattern_ids_in_commands(commands, path_to_id, pattern_library)
% Update pattern_ID fields in commands to match SD card numbering
%
%   commands - cell array or struct array of command structs
%   path_to_id - containers.Map from pattern path to SD card ID
%   pattern_library - pattern library path for resolving relative paths
%
%   Returns:
%       updated_commands - commands with updated pattern_ID fields
%       num_updated - count of how many pattern_IDs were updated

    num_updated = 0;
    
    if isempty(commands)
        updated_commands = commands;
        return;
    end
    
    % Handle both cell array and struct array
    if iscell(commands)
        % Cell array of commands
        for i = 1:length(commands)
            command = commands{i};
            if isstruct(command) && isfield(command, 'pattern')
                % Get the full path of this pattern
                pattern_path = resolve_pattern_path(command.pattern, pattern_library);
                if isstring(pattern_path)
                    pattern_path = char(pattern_path);
                end
                
                % Look up the SD card ID
                if isKey(path_to_id, pattern_path)
                    sd_id = path_to_id(pattern_path);
                    
                    % Update the pattern_ID field
                    commands{i}.pattern_ID = sd_id;
                    num_updated = num_updated + 1;
                end
            end
        end
    else
        % Struct array
        for i = 1:length(commands)
            command = commands(i);
            if isfield(command, 'pattern')
                % Get the full path of this pattern
                pattern_path = resolve_pattern_path(command.pattern, pattern_library);
                if isstring(pattern_path)
                    pattern_path = char(pattern_path);
                end
                
                % Look up the SD card ID
                if isKey(path_to_id, pattern_path)
                    sd_id = path_to_id(pattern_path);
                    
                    % Update the pattern_ID field
                    commands(i).pattern_ID = sd_id;
                    num_updated = num_updated + 1;
                end
            end
        end
    end
    
    updated_commands = commands;
end


function patterns = extract_patterns_from_single_yaml(experiment_data, yaml_path)
% Extract patterns from a single YAML structure in execution order
% (Helper function - duplicated from extract_patterns_from_yaml.m for standalone use)

    patterns = {};
    
    % Get pattern_library if specified
    pattern_library = '';
    if isfield(experiment_data, 'experiment_info') && ...
       isfield(experiment_data.experiment_info, 'pattern_library') && ...
       ~isempty(experiment_data.experiment_info.pattern_library)
        pattern_library = experiment_data.experiment_info.pattern_library;
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
            for i = 1:length(conditions)
                condition = conditions{i};
                if isfield(condition, 'commands')
                    cond_patterns = extract_from_commands(condition.commands);
                    patterns = [patterns; cond_patterns];
                end
            end
        else
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

    if isempty(pattern_library)
        full_path = pattern_ref;
    else
        is_full_path = contains(pattern_ref, filesep) || ...
                      contains(pattern_ref, '/') || ...
                      contains(pattern_ref, '\') || ...
                      (ispc && length(pattern_ref) > 2 && pattern_ref(2) == ':');
        
        if is_full_path
            full_path = pattern_ref;
        else
            full_path = fullfile(pattern_library, pattern_ref);
        end
    end
end

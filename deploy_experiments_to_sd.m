function result = deploy_experiments_to_sd(yaml_file_paths, sd_drive, output_dir, staging_dir)
% DEPLOY_EXPERIMENTS_TO_SD Extract patterns from YAMLs and deploy to SD card
%
%   result = deploy_experiments_to_sd(yaml_file_paths, sd_drive, output_dir)
%   result = deploy_experiments_to_sd(yaml_file_paths, sd_drive, output_dir, staging_dir)
%
%   High-level wrapper that:
%     1. Extracts patterns from one or more YAML files
%     2. Deploys them to SD card using prepare_sd_card()
%     3. Creates NEW YAML files with SD card pattern mapping (originals untouched)
%
%   INPUTS:
%       yaml_file_paths - String, char array, or cell array of YAML file path(s)
%       sd_drive        - Drive letter for SD card (e.g., 'E' or 'E:')
%       output_dir      - Directory where updated YAML files will be saved
%       staging_dir     - (Optional) Path for staging directory
%
%   OUTPUTS:
%       result - Struct with fields:
%           .success          - true if entire process succeeded
%           .error            - error message if failed, empty if success
%           .yaml_files       - cell array of original YAML files processed
%           .num_patterns     - total unique patterns deployed
%           .sd_mapping       - mapping struct from prepare_sd_card()
%           .yaml_updates     - cell array of structs with update info per YAML
%           .output_yaml_files - cell array of new YAML file paths created
%
%   NEW YAML FILES:
%       Original YAMLs are NOT modified. New versions are created in output_dir with:
%         - Filename: original_name_[timestamp].yaml (e.g., exp1_20260130_143000.yaml)
%         - Contains 'sd_card_mapping' section with timestamp, drive, and pattern mappings
%         - Updated 'pattern_ID' fields matching SD card numbering
%         - Integer types preserved (num_rows, num_cols, repetitions, controller params, etc.)
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
%       result = deploy_experiments_to_sd('experiment1.yaml', 'E', './updated_yamls');
%       if ~result.success
%           fprintf('Error: %s\n', result.error);
%       end
%       
%       % Deploy multiple experiments (shares patterns)
%       yamls = {'exp1.yaml', 'exp2.yaml', 'exp3.yaml'};
%       result = deploy_experiments_to_sd(yamls, 'E', './updated_yamls');
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
    result.output_yaml_files = {};
    
    %% Input validation
    if nargin < 3
        result.error = 'Must provide yaml_file_paths, sd_drive, and output_dir';
        return;
    end
    
    if nargin < 4
        staging_dir = '';  % Let prepare_sd_card use default
    end
    
    % Validate output_dir
    if ~isfolder(output_dir)
        try
            mkdir(output_dir);
        catch ME
            result.error = sprintf('Failed to create output directory %s: %s', output_dir, ME.message);
            return;
        end
    end
    
    %% Step 1: Extract patterns from YAML files
    fprintf('\n=== Extracting patterns from YAML files ===\n');
    
    try
        [pattern_paths_per_yaml, yaml_files] = extract_patterns_from_yaml(yaml_file_paths);
    catch ME
        result.error = sprintf('Pattern extraction failed: %s', ME.message);
        return;
    end
    
    result.yaml_files = yaml_files;
    
    % Show per-YAML summary
    for i = 1:length(yaml_files)
        fprintf('  %s: %d patterns\n', yaml_files{i}, length(pattern_paths_per_yaml{i}));
    end

    %% NEW: Validate all YAML protocols before deployment
    fprintf('\n=== Validating YAML protocols ===\n');
    
    validation_failed = false;
    all_errors = {};
    
    for i = 1:length(yaml_files)
        yaml_path = yaml_files{i};
        patterns_for_this_yaml = pattern_paths_per_yaml{i};
        
        % Run validation - pass the resolved patterns for this YAML
        [isValid, errors, warnings] = validate_protocol_for_sd_card(...
            yaml_path, patterns_for_this_yaml, 'Verbose', false);
        
        if ~isValid
            validation_failed = true;
            [~, yaml_name] = fileparts(yaml_path);
            fprintf('  ✗ VALIDATION FAILED with %d error(s) in %s\n', length(errors), yaml_name);
            all_errors = [all_errors; errors];
            
            % Print errors for this YAML
            for j = 1:length(errors)
                fprintf('    %d. %s\n', j, errors{j});
            end
        else
            [~, yaml_name] = fileparts(yaml_path);
            fprintf('  ✓ %s validated\n', yaml_name);
            
            % Print warnings if any
            if ~isempty(warnings)
                fprintf('    ⚠ %d warning(s):\n', length(warnings));
                for j = 1:length(warnings)
                    fprintf('      %d. %s\n', j, warnings{j});
                end
            end
        end
    end
    
    % Stop if any validation failed
    if validation_failed
        result.error = sprintf('Protocol validation failed with %d total error(s). See details above.', length(all_errors));
        fprintf('\n✗ Deployment aborted due to validation errors\n\n');
        return;
    end
    
    fprintf('\n✓ All protocols validated successfully\n');
    
    %% Step 2: Flatten and deduplicate patterns for SD card deployment
    fprintf('\n=== Preparing patterns for SD card ===\n');
    
    % Concatenate all patterns from all YAMLs
    all_patterns = [];
    for i = 1:length(pattern_paths_per_yaml)
        all_patterns = [all_patterns; pattern_paths_per_yaml{i}];
    end
    
    % Remove duplicates while preserving order
    pattern_paths = unique(all_patterns, 'stable');
    
    result.num_patterns = length(pattern_paths);
    
    if result.num_patterns == 0
        result.error = 'No patterns found in YAML file(s)';
        return;
    end
    
    fprintf('Total patterns: %d (from all YAMLs)\n', length(all_patterns));
    fprintf('Unique patterns to deploy: %d\n', result.num_patterns);
    
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
    
    %% Step 3: Create new YAML files with SD card mapping
    fprintf('\n=== Creating updated YAML files ===\n');
    
    result.yaml_updates = cell(length(yaml_files), 1);
    result.output_yaml_files = cell(length(yaml_files), 1);
    total_ids_updated = 0;
    
    for i = 1:length(yaml_files)
        yaml_path = yaml_files{i};
        fprintf('Processing %s...\n', yaml_path);
        
        try
            % Create new YAML file with timestamp suffix
            [update_info, new_yaml_path] = create_updated_yaml_with_sd_mapping(...
                yaml_path, sd_mapping, output_dir);
            
            result.yaml_updates{i} = update_info;
            result.output_yaml_files{i} = new_yaml_path;
            
            fprintf('  Created: %s\n', new_yaml_path);
            fprintf('  Added %d pattern mappings\n', update_info.num_mappings);
            fprintf('  Updated %d pattern_ID fields\n', update_info.num_ids_updated);
            total_ids_updated = total_ids_updated + update_info.num_ids_updated;

            
        catch ME
            warning('Failed to process %s: %s', yaml_path, ME.message);
            result.yaml_updates{i} = struct('success', false, 'error', ME.message);
            result.output_yaml_files{i} = '';
            % Don't fail entire process - SD card is already written
        end
    end
    
    %% Success
    result.success = true;
    
    fprintf('\n=== Deployment complete ===\n');
    fprintf('Patterns deployed: %d\n', result.num_patterns);
    fprintf('YAML files processed: %d\n', length(yaml_files));
    fprintf('New YAML files created: %d\n', sum(~cellfun(@isempty, result.output_yaml_files)));
    fprintf('Pattern IDs updated: %d\n', total_ids_updated);
    fprintf('SD card: %s:\n', sd_mapping.sd_drive);
    fprintf('Log saved: %s\n', sd_mapping.log_file);
    fprintf('Updated YAMLs saved to: %s\n', output_dir);
end


function [update_info, new_yaml_path] = create_updated_yaml_with_sd_mapping(yaml_path, sd_mapping, output_dir)
% Create a NEW YAML file with SD card pattern mapping (original untouched)
%
%   Creates new YAML file named: original_name_[timestamp].yaml
%   Adds 'sd_card_mapping' section with timestamp, drive, and pattern mappings
%   Updates 'pattern_ID' fields in commands to match SD card numbering
%   Only includes patterns that are actually used in this YAML
%   Converts specific fields to integers before saving

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
    
    % Build mapping: original_path -> SD card ID number and new name
    path_to_id = containers.Map('KeyType', 'char', 'ValueType', 'double');
    path_to_name = containers.Map('KeyType', 'char', 'ValueType', 'char');
    
    for i = 1:length(sd_mapping.patterns)
        original_path = sd_mapping.patterns{i}.original_path;
        id_num = i;
        sd_name = sd_mapping.patterns{i}.new_name;
        path_to_id(original_path) = id_num;
        path_to_name(original_path) = sd_name;
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
    
    % Collect patterns actually used in this YAML
    patterns_in_yaml = extract_patterns_from_single_yaml(experiment_data, yaml_path);
    
    % Build mappings list for just the patterns in this YAML
    mappings_list = {};
    for i = 1:length(patterns_in_yaml)
        pattern_path = patterns_in_yaml{i};
        if isKey(path_to_name, pattern_path)
            mapping_entry = struct();
            mapping_entry.original = pattern_path;
            mapping_entry.sd_name = path_to_name(pattern_path);
            mappings_list{end+1} = mapping_entry; %#ok<AGROW>
        end
    end
    
    % Add sd_card_mapping section
    sd_card_mapping = struct();
    sd_card_mapping.timestamp = sd_mapping.timestamp;
    sd_card_mapping.sd_drive = sd_mapping.sd_drive;
    sd_card_mapping.mappings = mappings_list;
    
    experiment_data.sd_card_mapping = sd_card_mapping;
    
    % Convert specific fields to integers before saving
    experiment_data = convert_integers_for_yaml(experiment_data);
    
    % Generate new filename with timestamp
    [~, base_name, ~] = fileparts(yaml_path);
    
    % Extract timestamp from sd_mapping (format: 'yyyy-mm-ddTHH:MM:SS')
    % Convert to filename-safe format: 'yyyymmdd_HHMMSS'
    timestamp_str = sd_mapping.timestamp;
    timestamp_str = strrep(timestamp_str, '-', '');
    timestamp_str = strrep(timestamp_str, ':', '');
    timestamp_str = strrep(timestamp_str, 'T', '_');
    
    new_filename = sprintf('%s_%s.yaml', base_name, timestamp_str);
    new_yaml_path = fullfile(output_dir, new_filename);
    
    % Save new YAML file (original untouched) with block style for readability
    yaml.dumpFile(new_yaml_path, experiment_data, 'block');
    
    update_info.success = true;
    update_info.num_mappings = length(mappings_list);
    update_info.num_ids_updated = num_ids_updated;
end


function data = convert_integers_for_yaml(data)
% Convert specific fields to integer types before YAML export
%
% Ensures that fields which should be integers are saved as integers
% in the YAML file (not floats). Handles:
%   - arena_info.num_rows, num_cols
%   - experiment_structure.repetitions
%   - Controller command parameters: pattern_ID, mode, frame_index, frame_rate, gain
%   - Plugin parameters: baudrate, port, sample_rate, fps, buffer_size
%
% Integer fields are converted to int32 type, which supports:
%   - Negative values (e.g., gain = -90)
%   - Large values (e.g., baudrate = 115200)
%   - Range: -2,147,483,648 to 2,147,483,647

    % Arena info integers
    if isfield(data, 'arena_info')
        if isfield(data.arena_info, 'num_rows') && isnumeric(data.arena_info.num_rows)
            data.arena_info.num_rows = int32(data.arena_info.num_rows);
        end
        if isfield(data.arena_info, 'num_cols') && isnumeric(data.arena_info.num_cols)
            data.arena_info.num_cols = int32(data.arena_info.num_cols);
        end
    end
    
    % Experiment structure integers
    if isfield(data, 'experiment_structure')
        if isfield(data.experiment_structure, 'repetitions') && ...
           isnumeric(data.experiment_structure.repetitions)
            data.experiment_structure.repetitions = int32(data.experiment_structure.repetitions);
        end
    end
    
    % Plugin definitions - baudrate, port, sample_rate
    if isfield(data, 'plugins')
        data.plugins = convert_plugin_definition_integers(data.plugins);
    end
    
    % Command parameters throughout the experiment structure
    % (pretrial, block conditions, intertrial, posttrial)
    if isfield(data, 'pretrial') && isfield(data.pretrial, 'commands')
        data.pretrial.commands = convert_command_integers(data.pretrial.commands);
    end
    
    if isfield(data, 'block') && isfield(data.block, 'conditions')
        data.block.conditions = convert_conditions_integers(data.block.conditions);
    end
    
    if isfield(data, 'intertrial') && isfield(data.intertrial, 'commands')
        data.intertrial.commands = convert_command_integers(data.intertrial.commands);
    end
    
    if isfield(data, 'posttrial') && isfield(data.posttrial, 'commands')
        data.posttrial.commands = convert_command_integers(data.posttrial.commands);
    end
end


function plugins = convert_plugin_definition_integers(plugins)
% Convert integer fields in plugin definitions (baudrate, port, sample_rate)
    
    if isempty(plugins)
        return;
    end
    
    % Handle both cell array and struct array
    if iscell(plugins)
        for i = 1:length(plugins)
            if isstruct(plugins{i})
                % Convert baudrate
                if isfield(plugins{i}, 'baudrate') && isnumeric(plugins{i}.baudrate)
                    plugins{i}.baudrate = int32(plugins{i}.baudrate);
                end
                % Convert port (if numeric)
                if isfield(plugins{i}, 'port') && isnumeric(plugins{i}.port)
                    plugins{i}.port = int32(plugins{i}.port);
                end
                % Convert sample_rate in config
                if isfield(plugins{i}, 'config') && isstruct(plugins{i}.config)
                    if isfield(plugins{i}.config, 'sample_rate') && ...
                       isnumeric(plugins{i}.config.sample_rate)
                        plugins{i}.config.sample_rate = int32(plugins{i}.config.sample_rate);
                    end
                end
            end
        end
    else
        % Struct array
        for i = 1:length(plugins)
            % Convert baudrate
            if isfield(plugins(i), 'baudrate') && isnumeric(plugins(i).baudrate)
                plugins(i).baudrate = int32(plugins(i).baudrate);
            end
            % Convert port (if numeric)
            if isfield(plugins(i), 'port') && isnumeric(plugins(i).port)
                plugins(i).port = int32(plugins(i).port);
            end
            % Convert sample_rate in config
            if isfield(plugins(i), 'config') && isstruct(plugins(i).config)
                if isfield(plugins(i).config, 'sample_rate') && ...
                   isnumeric(plugins(i).config.sample_rate)
                    plugins(i).config.sample_rate = int32(plugins(i).config.sample_rate);
                end
            end
        end
    end
end


function conditions = convert_conditions_integers(conditions)
% Convert integer fields in block conditions
    
    if isempty(conditions)
        return;
    end
    
    % Handle both cell array and struct array
    if iscell(conditions)
        for i = 1:length(conditions)
            if isstruct(conditions{i}) && isfield(conditions{i}, 'commands')
                conditions{i}.commands = convert_command_integers(conditions{i}.commands);
            end
        end
    else
        % Struct array
        for i = 1:length(conditions)
            if isfield(conditions(i), 'commands')
                conditions(i).commands = convert_command_integers(conditions(i).commands);
            end
        end
    end
end


function commands = convert_command_integers(commands)
% Convert integer fields in command lists
%
% For controller commands, converts: pattern_ID, mode, frame_index, frame_rate, gain
% For plugin commands, converts params fields: fps, buffer_size, port
    
    if isempty(commands)
        return;
    end
    
    % Handle both cell array and struct array
    if iscell(commands)
        for i = 1:length(commands)
            if isstruct(commands{i})
                commands{i} = convert_single_command_integers(commands{i});
            end
        end
    else
        % Struct array
        for i = 1:length(commands)
            commands(i) = convert_single_command_integers(commands(i));
        end
    end
end


function command = convert_single_command_integers(command)
% Convert integer fields in a single command struct
    
    % Check if this is a controller command
    if isfield(command, 'type') && strcmp(command.type, 'controller')
        % Convert controller integer parameters
        if isfield(command, 'pattern_ID') && isnumeric(command.pattern_ID)
            command.pattern_ID = int32(command.pattern_ID);
        end
        if isfield(command, 'mode') && isnumeric(command.mode)
            command.mode = int32(command.mode);
        end
        if isfield(command, 'frame_index') && isnumeric(command.frame_index)
            command.frame_index = int32(command.frame_index);
        end
        if isfield(command, 'frame_rate') && isnumeric(command.frame_rate)
            command.frame_rate = int32(command.frame_rate);
        end
        if isfield(command, 'gain') && isnumeric(command.gain)
            command.gain = int32(command.gain);
        end
    end
    
    % Check if this is a plugin command with params
    if isfield(command, 'type') && strcmp(command.type, 'plugin')
        if isfield(command, 'params') && isstruct(command.params)
            % Convert plugin integer parameters
            if isfield(command.params, 'fps') && isnumeric(command.params.fps)
                command.params.fps = int32(command.params.fps);
            end
            if isfield(command.params, 'buffer_size') && isnumeric(command.params.buffer_size)
                command.params.buffer_size = int32(command.params.buffer_size);
            end
            if isfield(command.params, 'port') && isnumeric(command.params.port)
                command.params.port = int32(command.params.port);
            end
        end
    end
end


function [updated_commands, num_updated] = update_pattern_ids_in_commands(commands, path_to_id, pattern_library)
% Update pattern_ID fields in commands to match SD card numbering
%
%   commands - cell array or struct array of command structs
%   path_to_id - containers.Map from pattern path to SD card ID
%   pattern_library - pattern library path for resolving relative paths
%
%   Returns:
%       updated_commands - commands with updated pattern_ID fields (as int32)
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
                    
                    % Update the pattern_ID field (will be converted to int32 later)
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
                    
                    % Update the pattern_ID field (will be converted to int32 later)
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
%
% Order: pretrial -> block conditions -> intertrial -> posttrial

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
%
%   If pattern_library is specified and pattern_ref is just a filename,
%   constructs: pattern_library/pattern_ref
%
%   Otherwise returns pattern_ref as-is (assumed to be full path)

    if isempty(pattern_library)
        % No library specified - pattern_ref must be full path
        full_path = pattern_ref;
    else
        % Check if pattern_ref looks like a full path
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

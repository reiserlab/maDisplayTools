function result = deploy_experiments_to_sd(yaml_file_paths, sd_drive, output_dir, staging_dir)
% DEPLOY_EXPERIMENTS_TO_SD Extract patterns from V3 YAMLs and deploy to SD card
%
%   result = deploy_experiments_to_sd(yaml_file_paths, sd_drive, output_dir)
%   result = deploy_experiments_to_sd(yaml_file_paths, sd_drive, output_dir, staging_dir)
%
%   High-level wrapper that:
%     1. Extracts patterns from one or more YAML files
%     2. Validates each protocol using validate_protocol_for_sd_card()
%     3. Deploys patterns to SD card using prepare_sd_card()
%     4. Creates NEW YAML files with SD card pattern mapping (originals untouched)
%
%   INPUTS:
%       yaml_file_paths - String, char array, or cell array of YAML file path(s)
%       sd_drive        - Drive letter for SD card (e.g., 'E' or 'E:')
%       output_dir      - Directory where updated YAML files will be saved
%       staging_dir     - (Optional) Path for staging directory
%
%   OUTPUTS:
%       result - Struct with fields:
%           .success           - true if entire process succeeded
%           .error             - error message if failed, empty if success
%           .yaml_files        - cell array of original YAML files processed
%           .num_patterns      - total unique patterns deployed
%           .sd_mapping        - mapping struct from prepare_sd_card()
%           .yaml_updates      - cell array of structs with update info per YAML
%           .output_yaml_files - cell array of new YAML file paths created
%
%   NEW YAML FILES:
%       Original YAMLs are NOT modified. New versions are created in output_dir with:
%         - Filename: original_name_[timestamp].yaml
%         - Contains 'sd_card_mapping' section with timestamp, drive, and pattern mappings
%         - Updated 'pattern_ID' fields matching SD card numbering
%         - Integer types preserved (controller params, plugin params, etc.)
%
%   YAML UPDATES:
%       Adds a 'sd_card_mapping' section to each YAML file with:
%         - timestamp: when SD card was prepared
%         - sd_drive: drive letter used
%         - mappings: list of pattern mappings for patterns used in this YAML
%
%   EXAMPLE:
%       result = deploy_experiments_to_sd('experiment.yaml', 'E', './updated_yamls');
%       if ~result.success
%           fprintf('Error: %s\n', result.error);
%       end
%
%       yamls = {'exp1.yaml', 'exp2.yaml'};
%       result = deploy_experiments_to_sd(yamls, 'E', './updated_yamls');
%
%   See also: prepare_sd_card, validate_protocol_for_sd_card

    %% Initialize result struct
    result = struct();
    result.success           = false;
    result.error             = '';
    result.yaml_files        = {};
    result.num_patterns      = 0;
    result.sd_mapping        = struct();
    result.yaml_updates      = {};
    result.output_yaml_files = {};

    %% Input validation
    if nargin < 3
        result.error = 'Must provide yaml_file_paths, sd_drive, and output_dir';
        fprintf('%s\n', result.error);
        return;
    end

    if nargin < 4
        staging_dir = '';
    end

    % Normalize yaml_file_paths to a cell array of char vectors
    if ischar(yaml_file_paths) || isstring(yaml_file_paths)
        yaml_file_paths = cellstr(yaml_file_paths);
    end

    if isempty(yaml_file_paths)
        result.error = 'yaml_file_paths is empty — nothing to process';
        fprintf('%s\n', result.error);
        return;
    end

    % Confirm every YAML file exists before doing any work
    for i = 1:length(yaml_file_paths)
        if ~isfile(yaml_file_paths{i})
            result.error = sprintf('YAML file not found: %s', yaml_file_paths{i});
            fprintf('%s\n', result.error);
            return;
        end
    end

    yaml_files = yaml_file_paths;

    if ~isfolder(output_dir)
        try
            mkdir(output_dir);
        catch ME
            result.error = sprintf('Failed to create output directory %s: %s', ...
                output_dir, ME.message);
            fprintf('%s\n', result.error);
            return;
        end
    end

    %% Step 1: Extract patterns from each YAML file
    fprintf('\n=== Extracting patterns from YAML files ===\n');

    pattern_paths_per_yaml = cell(length(yaml_files), 1);

    for i = 1:length(yaml_files)
        yaml_path = yaml_files{i};
        try
            experiment_data = yaml.loadFile(yaml_path);
            file_patterns   = extract_patterns_from_single_yaml(experiment_data, yaml_path);
            % Ensure all entries are char vectors
            for j = 1:length(file_patterns)
                if isstring(file_patterns{j})
                    file_patterns{j} = char(file_patterns{j});
                end
            end
            pattern_paths_per_yaml{i} = file_patterns;
            fprintf('  %s: %d pattern(s)\n', yaml_path, length(file_patterns));
        catch ME
            result.error = sprintf('Failed to extract patterns from %s: %s', ...
                yaml_path, ME.message);
            fprintf('%s\n', result.error);
            return;
        end
    end

    result.yaml_files = yaml_files;

    %% Step 2: Validate all YAML protocols before deployment
    fprintf('\n=== Validating YAML protocols ===\n');

    validation_failed = false;
    all_errors        = {};

    for i = 1:length(yaml_files)
        yaml_path             = yaml_files{i};
        patterns_for_this_yaml = pattern_paths_per_yaml{i};

        [isValid, errors, warnings] = validate_protocol_for_sd_card(...
            yaml_path, patterns_for_this_yaml, 'Verbose', false);

        if ~isValid
            validation_failed = true;
            [~, yaml_name] = fileparts(yaml_path);
            fprintf('  ✗ VALIDATION FAILED with %d error(s) in %s\n', ...
                length(errors), yaml_name);
            all_errors = [all_errors; errors]; %#ok<AGROW>
            for j = 1:length(errors)
                fprintf('    %d. %s\n', j, errors{j});
            end
        else
            [~, yaml_name] = fileparts(yaml_path);
            fprintf('  ✓ %s validated\n', yaml_name);
            if ~isempty(warnings)
                fprintf('    ⚠ %d warning(s):\n', length(warnings));
                for j = 1:length(warnings)
                    fprintf('      %d. %s\n', j, warnings{j});
                end
            end
        end
    end

    if validation_failed
        result.error = sprintf('Protocol validation failed with %d total error(s). See details above.', ...
            length(all_errors));
        fprintf('%s\n', result.error);
        return;
    end

    fprintf('\n✓ All protocols validated successfully\n');

    %% Step 3: Flatten and deduplicate patterns for SD card deployment
    fprintf('\n=== Preparing patterns for SD card ===\n');

    all_patterns = [];
    for i = 1:length(pattern_paths_per_yaml)
        all_patterns = [all_patterns; pattern_paths_per_yaml{i}]; %#ok<AGROW>
    end

    pattern_paths = unique(all_patterns, 'stable');
    result.num_patterns = length(pattern_paths);

    if result.num_patterns == 0
        result.error = 'No patterns found in YAML file(s)';
        fprintf('%s\n', result.error);
        return;
    end

    fprintf('Total patterns: %d (from all YAMLs)\n',    length(all_patterns));
    fprintf('Unique patterns to deploy: %d\n', result.num_patterns);

    %% Step 4: Deploy to SD card
    fprintf('\n=== Deploying to SD card ===\n');

    try
        if isempty(staging_dir)
            staging_dir = fullfile(output_dir, 'sd_prep');
            sd_mapping = prepare_sd_card(pattern_paths, sd_drive, ...
                'Format', false, 'StagingDir', staging_dir);
        else
            sd_mapping = prepare_sd_card(pattern_paths, sd_drive, ...
                'StagingDir', staging_dir, 'Format', false);
        end
    catch ME
        result.error = sprintf('SD card deployment failed: %s', ME.message);
        fprintf('%s\n', result.error);
        return;
    end

    if ~sd_mapping.success
        result.error    = sprintf('SD card deployment failed: %s', sd_mapping.error);
        result.sd_mapping = sd_mapping;
        fprintf('SD card deployment failed: %s\n', sd_mapping.error);
        return;
    end

    result.sd_mapping = sd_mapping;
    fprintf('\n=== SD card deployment successful ===\n');

    %% Step 5: Create new YAML files with SD card mapping
    fprintf('\n=== Creating updated YAML files ===\n');

    result.yaml_updates      = cell(length(yaml_files), 1);
    result.output_yaml_files = cell(length(yaml_files), 1);
    total_ids_updated        = 0;

    for i = 1:length(yaml_files)
        yaml_path = yaml_files{i};
        fprintf('Processing %s...\n', yaml_path);

        try
            [update_info, new_yaml_path] = create_updated_yaml_with_sd_mapping(...
                yaml_path, sd_mapping, output_dir);

            result.yaml_updates{i}      = update_info;
            result.output_yaml_files{i} = new_yaml_path;

            fprintf('  Created: %s\n',              new_yaml_path);
            fprintf('  Added %d pattern mappings\n', update_info.num_mappings);
            fprintf('  Updated %d pattern_ID fields\n', update_info.num_ids_updated);
            total_ids_updated = total_ids_updated + update_info.num_ids_updated;

        catch ME
            warning('Failed to process %s: %s', yaml_path, ME.message);
            result.yaml_updates{i}      = struct('success', false, 'error', ME.message);
            result.output_yaml_files{i} = '';
        end
    end

    try
        timestamped_manifest = create_timestamped_manifest(staging_dir, sd_mapping, output_dir);
        fprintf('  Created timestamped manifest %s in output directory\n', timestamped_manifest);
    catch ME
        warning('deploy_experiments_to_sd:manifestSaveFailed', ...
            'Failed to create timestamped manifest: %s', ME.message);
    end

    %% Success
    result.success = true;

    fprintf('\n=== Deployment complete ===\n');
    fprintf('Patterns deployed: %d\n',      result.num_patterns);
    fprintf('YAML files processed: %d\n',   length(yaml_files));
    fprintf('New YAML files created: %d\n', sum(~cellfun(@isempty, result.output_yaml_files)));
    fprintf('Pattern IDs updated: %d\n',    total_ids_updated);
    fprintf('SD card: %s:\n',               sd_mapping.sd_drive);
    fprintf('Log saved: %s\n',              sd_mapping.log_file);
    fprintf('Updated YAMLs saved to: %s\n', output_dir);
end


function timestamped_manifest = create_timestamped_manifest(staging_dir, sd_mapping, output_dir)

    timestamp_str = sd_mapping.timestamp;
    timestamp_str = strrep(timestamp_str, '-', '');
    timestamp_str = strrep(timestamp_str, ':', '');
    timestamp_str = strrep(timestamp_str, 'T', '_');

    destManifestPath = fullfile(output_dir, ['MANIFEST_' timestamp_str '.txt']);
    origManifestPath = fullfile(staging_dir, 'MANIFEST.txt');

    copyfile(origManifestPath, destManifestPath);
    timestamped_manifest = destManifestPath;
end


function [update_info, new_yaml_path] = create_updated_yaml_with_sd_mapping( ...
        yaml_path, sd_mapping, output_dir)
% Create a NEW YAML file with SD card pattern mapping (original untouched).
%
%   Uses SnakeYAML's compose/serialize API to operate on the Node tree
%   before aliases are resolved, so anchors and aliases in the original
%   file are preserved natively in the output.
%
%   Two changes are made to the node tree:
%     1. Each pattern_ID ScalarNode is replaced with the SD card number.
%     2. A new sd_card_mapping MappingNode is appended to the root.

    update_info = struct();
    update_info.success         = false;
    update_info.yaml_file       = yaml_path;
    update_info.num_mappings    = 0;
    update_info.num_ids_updated = 0;
    update_info.error           = '';

    % Parse as struct — needed only to resolve pattern_library and
    % collect the pattern file list for the sd_card_mapping section
    experiment_data = yaml.loadFile(yaml_path);

    pattern_library = '';
    if isfield(experiment_data, 'experiment_info') && ...
       isfield(experiment_data.experiment_info, 'pattern_library') && ...
       ~isempty(experiment_data.experiment_info.pattern_library)
        pattern_library = experiment_data.experiment_info.pattern_library; %#ok<NASGU>
    end

    % Build filename->SD card ID and path->SD card name maps
    filename_to_id = containers.Map('KeyType', 'char', 'ValueType', 'double');
    path_to_name   = containers.Map('KeyType', 'char', 'ValueType', 'char');
    for i = 1:length(sd_mapping.patterns)
        orig           = sd_mapping.patterns{i}.original_path;
        [~, fn, ext]   = fileparts(orig);
        filename_to_id([fn ext]) = i;
        path_to_name(orig)       = sd_mapping.patterns{i}.new_name;
    end

    % Compose the YAML node tree.
    % At this level aliases are Java object references, not resolved copies,
    % so serialize() will re-emit anchors and aliases correctly.
    reader   = java.io.FileReader(yaml_path);
    yamlObj  = org.yaml.snakeyaml.Yaml();
    rootNode = yamlObj.compose(reader);
    reader.close();

    % Update pattern_ID ScalarNodes in the tree
    num_ids_updated = update_pattern_id_nodes(rootNode, filename_to_id);

    % Collect which patterns this YAML references (for the mapping section)
    patterns_in_yaml = extract_patterns_from_single_yaml(experiment_data, yaml_path);
    mappings_list = {};
    for i = 1:length(patterns_in_yaml)
        ppath = char(patterns_in_yaml{i});
        if isKey(path_to_name, ppath)
            mappings_list{end+1} = struct( ...
                'original', ppath, ...
                'sd_name',  path_to_name(ppath)); %#ok<AGROW>
        end
    end

    % Serialize the modified node tree to a string.
    % Aliases are re-emitted natively by SnakeYAML at this step.
    strWriter = java.io.StringWriter();
    yamlObj.serialize(rootNode, strWriter);
    serialized = char(strWriter.toString());

    % Append sd_card_mapping as a proper node (no enum names — styles
    % are borrowed from the already-loaded tree, so version-independent)
    append_sd_card_mapping_node(rootNode, sd_mapping, mappings_list);

    % Serialize back to YAML — aliases re-emitted natively by SnakeYAML
    [~, base_name, ~] = fileparts(yaml_path);
    timestamp_str = strrep(sd_mapping.timestamp, '-', '');
    timestamp_str = strrep(timestamp_str, ':', '');
    timestamp_str = strrep(timestamp_str, 'T', '_');
    new_filename  = sprintf('%s_%s.yaml', base_name, timestamp_str);
    new_yaml_path = fullfile(output_dir, new_filename);

    writer = java.io.FileWriter(new_yaml_path);
    yamlObj.serialize(rootNode, writer);
    writer.close();

    update_info.success         = true;
    update_info.num_mappings    = length(mappings_list);
    update_info.num_ids_updated = num_ids_updated;
end


function append_sd_card_mapping_node(rootNode, sd_mapping, mappings_list)
% Append a sd_card_mapping section to the root MappingNode.
%
% Style constants (ScalarStyle and FlowStyle) are borrowed directly from
% existing nodes in the already-loaded tree rather than referenced by class
% name.  This makes the function version-independent across SnakeYAML 1.x
% and 2.x: the types automatically match because the instances came from
% the same JAR.
%
%   PLAIN ScalarStyle — borrowed from the first key node in the document.
%     Every YAML key is a plain scalar, so this is always available.
%
%   BLOCK FlowStyle — borrowed from the root MappingNode itself.
%     A block-style YAML document will always have BLOCK (or AUTO) here,
%     and passing it to the MappingNode/SequenceNode constructors
%     for the new content produces the same block output.

    % Borrow style constants — no class name references, no version issues
    PLAIN = rootNode.getValue().get(0).getKeyNode().getScalarStyle();
    BLOCK = rootNode.getFlowStyle();

    STR = org.yaml.snakeyaml.nodes.Tag.STR;
    MAP = org.yaml.snakeyaml.nodes.Tag.MAP;
    SEQ = org.yaml.snakeyaml.nodes.Tag.SEQ;

    mk_str  = @(v)    org.yaml.snakeyaml.nodes.ScalarNode(STR, v, [], [], PLAIN);
    mk_pair = @(k, v) org.yaml.snakeyaml.nodes.NodeTuple(mk_str(k), mk_str(v));

    % mappings: sequence of {original, sd_name} pairs
    items = java.util.ArrayList();
    for i = 1:length(mappings_list)
        t = java.util.ArrayList();
        t.add(mk_pair('original', mappings_list{i}.original));
        t.add(mk_pair('sd_name',  mappings_list{i}.sd_name));
        items.add(org.yaml.snakeyaml.nodes.MappingNode(MAP, t, BLOCK));
    end
    mappingsSeq = org.yaml.snakeyaml.nodes.SequenceNode(SEQ, items, BLOCK);

    % sd_card_mapping body
    body = java.util.ArrayList();
    body.add(mk_pair('timestamp', sd_mapping.timestamp));
    body.add(mk_pair('sd_drive',  sd_mapping.sd_drive));
    body.add(org.yaml.snakeyaml.nodes.NodeTuple(mk_str('mappings'), mappingsSeq));
    bodyNode = org.yaml.snakeyaml.nodes.MappingNode(MAP, body, BLOCK);

    % Append to root
    rootNode.getValue().add( ...
        org.yaml.snakeyaml.nodes.NodeTuple(mk_str('sd_card_mapping'), bodyNode));
end

function num_updated = update_pattern_id_nodes(rootNode, filename_to_id)
% Walk the conditions->commands subtree and replace each pattern_ID
% ScalarNode with the corresponding SD card ID number.
%
% ScalarNode is immutable in SnakeYAML, so we replace the NodeTuple that
% contains it with a new NodeTuple pointing to a new ScalarNode.  The
% parent MappingNode's getValue() list is a mutable Java ArrayList so
% set() works directly.

    num_updated    = 0;
    conditionsNode = get_value_node(rootNode, 'conditions');
    if isempty(conditionsNode)
        return;
    end

    condList = conditionsNode.getValue();          % Java List of condition MappingNodes
    for i = 0:condList.size()-1
        condNode     = condList.get(i);
        commandsNode = get_value_node(condNode, 'commands');
        if isempty(commandsNode)
            continue;
        end

        cmdList = commandsNode.getValue();         % Java List of command MappingNodes
        for j = 0:cmdList.size()-1
            cmdNode = cmdList.get(j);
            if ~isa(cmdNode, 'org.yaml.snakeyaml.nodes.MappingNode')
                continue;
            end

            patternVal = get_scalar_string(cmdNode, 'pattern');
            if isempty(patternVal)
                continue;
            end

            [~, fn, ext] = fileparts(char(patternVal));
            filename = [fn ext];
            if ~isKey(filename_to_id, filename)
                continue;
            end

            if replace_scalar(cmdNode, 'pattern_ID', num2str(filename_to_id(filename)))
                num_updated = num_updated + 1;
            end
        end
    end
end


function valueNode = get_value_node(mappingNode, key)
% Return the value Node for the given key in a MappingNode, or [] if absent.

    valueNode = [];
    if ~isa(mappingNode, 'org.yaml.snakeyaml.nodes.MappingNode')
        return;
    end
    tuples = mappingNode.getValue();
    for i = 0:tuples.size()-1
        tuple   = tuples.get(i);
        keyNode = tuple.getKeyNode();
        if isa(keyNode, 'org.yaml.snakeyaml.nodes.ScalarNode') && ...
                strcmp(char(keyNode.getValue()), key)
            valueNode = tuple.getValueNode();
            return;
        end
    end
end


function value = get_scalar_string(mappingNode, key)
% Return the string value of a scalar field, or '' if absent or non-scalar.

    value = '';
    node  = get_value_node(mappingNode, key);
    if isempty(node) || ~isa(node, 'org.yaml.snakeyaml.nodes.ScalarNode')
        return;
    end
    value = char(node.getValue());
end


function success = replace_scalar(mappingNode, key, newValue)
% Replace a scalar value in a MappingNode by swapping its NodeTuple.
%
% ScalarNode is immutable, so a new ScalarNode is constructed with the same
% Tag and ScalarStyle as the original (preserving quoting behaviour), then
% placed in a new NodeTuple which replaces the old one in the parent list.

    success = false;
    tuples  = mappingNode.getValue();
    for i = 0:tuples.size()-1
        tuple   = tuples.get(i);
        keyNode = tuple.getKeyNode();
        if isa(keyNode, 'org.yaml.snakeyaml.nodes.ScalarNode') && ...
                strcmp(char(keyNode.getValue()), key)
            old     = tuple.getValueNode();
            newNode = org.yaml.snakeyaml.nodes.ScalarNode( ...
                old.getTag(), newValue, [], [], old.getScalarStyle());
            tuples.set(i, org.yaml.snakeyaml.nodes.NodeTuple(keyNode, newNode));
            success = true;
            return;
        end
    end
end


function [updated_commands, num_updated] = update_pattern_ids_in_commands( ...
        commands, path_to_id, pattern_library)
% Update pattern_ID fields in a commands list to match SD card numbering.
%
%   commands        - cell array or struct array of command structs
%   path_to_id      - containers.Map from pattern path to SD card ID number
%   pattern_library - pattern library path for resolving relative filenames
%
%   Returns:
%       updated_commands - commands with updated pattern_ID fields (as int32)
%       num_updated      - number of pattern_IDs updated

    num_updated = 0;

    if isempty(commands)
        updated_commands = commands;
        return;
    end

    if iscell(commands)
        for i = 1:length(commands)
            command = commands{i};
            if isstruct(command) && isfield(command, 'pattern')
                pattern_path = resolve_pattern_path(command.pattern, pattern_library);
                if isstring(pattern_path)
                    pattern_path = char(pattern_path);
                end
                if isKey(path_to_id, pattern_path)
                    commands{i}.pattern_ID = path_to_id(pattern_path);
                    num_updated = num_updated + 1;
                end
            end
        end
    else
        for i = 1:length(commands)
            command = commands(i);
            if isfield(command, 'pattern')
                pattern_path = resolve_pattern_path(command.pattern, pattern_library);
                if isstring(pattern_path)
                    pattern_path = char(pattern_path);
                end
                if isKey(path_to_id, pattern_path)
                    commands(i).pattern_ID = path_to_id(pattern_path);
                    num_updated = num_updated + 1;
                end
            end
        end
    end

    updated_commands = commands;
end


function patterns = extract_patterns_from_single_yaml(experiment_data, ~)
% Extract all pattern file paths from a V3 YAML structure.
%
%   In V3, all conditions (including what were pretrial, intertrial,
%   and posttrial in V2) are defined in the top-level 'conditions' list.
%   This function walks every condition's commands and collects any that
%   have a 'pattern' field (i.e. trialParams / startG41Trial commands).
%
%   The second argument (yaml_path) is accepted for interface compatibility
%   but is not used.

    patterns = {};

    pattern_library = '';
    if isfield(experiment_data, 'experiment_info') && ...
       isfield(experiment_data.experiment_info, 'pattern_library') && ...
       ~isempty(experiment_data.experiment_info.pattern_library)
        pattern_library = experiment_data.experiment_info.pattern_library;
    end

    resolve_path        = @(p) resolve_pattern_path(p, pattern_library);
    extract_from_cmds   = @(cmds) extract_patterns_from_commands(cmds, resolve_path);

    if ~isfield(experiment_data, 'conditions')
        patterns = patterns(:);
        return;
    end

    conditions = experiment_data.conditions;
    if ~iscell(conditions)
        conditions = arrayfun(@(s) s, conditions, 'UniformOutput', false);
    end

    for i = 1:length(conditions)
        cond = conditions{i};
        if isfield(cond, 'commands')
            cond_patterns = extract_from_cmds(cond.commands);
            patterns = [patterns; cond_patterns]; %#ok<AGROW>
        end
    end

    patterns = patterns(:);
end


function patterns = extract_patterns_from_commands(commands, resolve_path)
% Extract pattern file paths from a commands list.
%
%   commands     - cell array or struct array of command structs
%   resolve_path - function handle to resolve pattern filenames to full paths

    patterns = {};

    if isempty(commands)
        return;
    end

    if iscell(commands)
        for i = 1:length(commands)
            command = commands{i};
            if isstruct(command) && isfield(command, 'pattern')
                pattern_path = resolve_path(command.pattern);
                if isstring(pattern_path)
                    pattern_path = char(pattern_path);
                end
                patterns{end+1} = pattern_path; %#ok<AGROW>
            end
        end
    else
        for i = 1:length(commands)
            command = commands(i);
            if isfield(command, 'pattern')
                pattern_path = resolve_path(command.pattern);
                if isstring(pattern_path)
                    pattern_path = char(pattern_path);
                end
                patterns{end+1} = pattern_path; %#ok<AGROW>
            end
        end
    end

    patterns = patterns(:);
end


function full_path = resolve_pattern_path(pattern_ref, pattern_library)
% Resolve a pattern filename or path to a full path.
%
%   If pattern_library is given and pattern_ref looks like a plain filename
%   (no directory separators), prepends pattern_library.
%   Otherwise returns pattern_ref unchanged.

    if isempty(pattern_library)
        full_path = pattern_ref;
        return;
    end

    is_full_path = contains(pattern_ref, filesep) || ...
                   contains(pattern_ref, '/')     || ...
                   contains(pattern_ref, '\')     || ...
                   (ispc && length(pattern_ref) > 2 && pattern_ref(2) == ':');

    if is_full_path
        full_path = pattern_ref;
    else
        full_path = fullfile(pattern_library, pattern_ref);
    end
end

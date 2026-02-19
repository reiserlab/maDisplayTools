function arena_name = get_arena_name(generation_str, arena_id)
%GET_ARENA_NAME Look up arena name from registry by ID
%
%   arena_name = get_arena_name(generation_str, arena_id) returns the arena
%   name for a given generation and numeric arena ID.
%
%   IMPORTANT: Arena IDs are per-generation (not global).
%   G4 arena ID 1 is independent of G6 arena ID 1.
%
%   Inputs:
%       generation_str - Generation: 'G3', 'G4', 'G4.1', 'G41', 'G6'
%       arena_id - Numeric ID (0-255 for G4.1, 0-63 for G6)
%
%   Output:
%       arena_name - Arena name (e.g., 'G6_2x10', 'G41_2x12_cw')
%           Returns empty string '' if ID not found
%
%   Example:
%       arena_name = get_arena_name('G6', 1);  % Returns 'G6_2x10'
%       arena_name = get_arena_name('G4.1', 1);  % Returns 'G41_2x12_cw'

    % Normalize generation string
    generation_str = upper(generation_str);
    generation_str = strrep(generation_str, '.', '');
    if strcmp(generation_str, 'G41')
        generation_str = 'G41';
    end

    % Handle unspecified arena ID
    if arena_id == 0
        arena_name = 'unspecified';
        return;
    end

    % Get maDisplayTools root directory
    thisFile = mfilename('fullpath');
    utilsDir = fileparts(thisFile);
    rootDir = fileparts(utilsDir);

    % Load registry index
    registry_path = fullfile(rootDir, 'configs', 'arena_registry', 'index.yaml');
    if ~exist(registry_path, 'file')
        error('get_arena_name:RegistryNotFound', ...
            'Arena registry not found: %s', registry_path);
    end

    try
        registry = yamlread(registry_path);
    catch ME
        error('get_arena_name:RegistryLoadFailed', ...
            'Failed to load registry: %s', ME.message);
    end

    % Check if generation exists in registry
    if ~isfield(registry, generation_str)
        warning('get_arena_name:GenerationNotFound', ...
            'Generation %s not found in registry', generation_str);
        arena_name = '';
        return;
    end

    % Get generation's arena map
    gen_arenas = registry.(generation_str);

    % Convert arena_id to string key (yamlread prepends 'x' to numeric keys)
    id_key = sprintf('x%d', arena_id);

    % Look up arena name
    if isfield(gen_arenas, id_key)
        arena_name = gen_arenas.(id_key);
    else
        warning('get_arena_name:IDNotFound', ...
            'Arena ID %d not found in %s registry', arena_id, generation_str);
        arena_name = '';
    end
end

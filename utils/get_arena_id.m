function arena_id = get_arena_id(generation_str, arena_name)
%GET_ARENA_ID Look up arena ID from registry
%
%   arena_id = get_arena_id(generation_str, arena_name) returns the numeric
%   arena ID for a given generation and arena name.
%
%   IMPORTANT: Arena IDs are per-generation (not global).
%   G4 arena ID 1 is independent of G6 arena ID 1.
%
%   Inputs:
%       generation_str - Generation: 'G3', 'G4', 'G4.1', 'G41', 'G6'
%       arena_name - Arena name (e.g., 'G6_2x10', 'G41_2x12_cw')
%
%   Output:
%       arena_id - Numeric ID (0-255 for G4.1, 0-63 for G6)
%           Returns 0 if arena not found in registry
%
%   Example:
%       arena_id = get_arena_id('G6', 'G6_2x10');  % Returns 1
%       arena_id = get_arena_id('G4.1', 'G41_2x12_cw');  % Returns 1

    % Normalize generation string
    generation_str = upper(generation_str);
    generation_str = strrep(generation_str, '.', '');
    if strcmp(generation_str, 'G41')
        generation_str = 'G41';
    end

    % Get maDisplayTools root directory
    thisFile = mfilename('fullpath');
    utilsDir = fileparts(thisFile);
    rootDir = fileparts(utilsDir);

    % Load registry index
    registry_path = fullfile(rootDir, 'configs', 'arena_registry', 'index.yaml');
    if ~exist(registry_path, 'file')
        error('get_arena_id:RegistryNotFound', ...
            'Arena registry not found: %s', registry_path);
    end

    try
        registry = yamlread(registry_path);
    catch ME
        error('get_arena_id:RegistryLoadFailed', ...
            'Failed to load registry: %s', ME.message);
    end

    % Check if generation exists in registry
    if ~isfield(registry, generation_str)
        warning('get_arena_id:GenerationNotFound', ...
            'Generation %s not found in registry, returning ID 0', generation_str);
        arena_id = 0;
        return;
    end

    % Get generation's arena map
    gen_arenas = registry.(generation_str);

    % Search for arena name in the map
    arena_id = 0;  % Default if not found
    arena_ids = fieldnames(gen_arenas);
    for i = 1:length(arena_ids)
        id_str = arena_ids{i};
        if strcmp(gen_arenas.(id_str), arena_name)
            % Handle 'x' prefix from yamlread (e.g., 'x1' -> 1)
            if startsWith(id_str, 'x')
                arena_id = str2double(id_str(2:end));
            else
                arena_id = str2double(id_str);
            end
            return;
        end
    end

    % Arena not found
    warning('get_arena_id:ArenaNotFound', ...
        'Arena %s not found in %s registry, returning ID 0', ...
        arena_name, generation_str);
end

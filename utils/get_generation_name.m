function generation_str = get_generation_name(gen_id)
%GET_GENERATION_NAME Map numeric generation ID to name string
%
%   generation_str = get_generation_name(gen_id) returns the generation
%   name string for a given numeric ID (0-7).
%
%   Input:
%       gen_id - Numeric ID (0-7)
%
%   Output:
%       generation_str - Generation name: 'unspecified', 'G3', 'G4', 'G4.1', 'G6'
%
%   Example:
%       gen_name = get_generation_name(3);  % Returns 'G4.1'

    switch gen_id
        case 0
            generation_str = 'unspecified';
        case 1
            generation_str = 'G3';
        case 2
            generation_str = 'G4';
        case 3
            generation_str = 'G4.1';
        case 4
            generation_str = 'G6';
        case {5, 6, 7}
            generation_str = 'reserved';
        otherwise
            error('get_generation_name:InvalidID', ...
                'Invalid generation ID: %d (must be 0-7)', gen_id);
    end
end

function gen_id = get_generation_id(generation_str)
%GET_GENERATION_ID Map generation name to numeric ID
%
%   gen_id = get_generation_id(generation_str) returns the numeric ID
%   (0-7) for a given generation name string.
%
%   Input:
%       generation_str - Generation name: 'G3', 'G4', 'G4.1', 'G41', 'G6'
%
%   Output:
%       gen_id - Numeric ID (0-7):
%           0: Unspecified
%           1: G3
%           2: G4
%           3: G4.1
%           4: G6
%           5-7: Reserved
%
%   Example:
%       gen_id = get_generation_id('G4.1');  % Returns 3
%       gen_id = get_generation_id('G41');   % Returns 3 (accepts both formats)

    % Normalize generation string
    generation_str = upper(generation_str);
    generation_str = strrep(generation_str, 'G4.1', 'G41');
    generation_str = strrep(generation_str, '.', '');

    % Map generation to ID
    switch generation_str
        case 'G3'
            gen_id = 1;
        case 'G4'
            gen_id = 2;
        case 'G41'
            gen_id = 3;
        case 'G6'
            gen_id = 4;
        case {'UNSPECIFIED', 'UNKNOWN', ''}
            gen_id = 0;
        otherwise
            error('get_generation_id:InvalidGeneration', ...
                'Unknown generation: %s', generation_str);
    end
end

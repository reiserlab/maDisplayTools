function show_resolved_config(config, indent_level)
% SHOW_RESOLVED_CONFIG Pretty-print a resolved configuration struct
%
% Usage:
%   config = load_arena_config('configs/arenas/G6_2x10_full.yaml');
%   show_resolved_config(config)
%
%   config = load_rig_config('configs/rigs/example_rig.yaml');
%   show_resolved_config(config)
%
%   config = load_experiment_config('experiments/protocol.yaml');
%   show_resolved_config(config)
%
% This function displays a hierarchically formatted view of the
% configuration for debugging and verification purposes.
%
% Input:
%   config       - Configuration struct from load_*_config functions
%   indent_level - (internal) Current indentation level
%
% Example output:
%   ========================================
%   RESOLVED CONFIGURATION
%   ========================================
%   Source: configs/arenas/G6_2x10_full.yaml
%
%   arena:
%     generation: G6
%     num_rows: 2
%     num_cols: 10
%     panels_installed: [all]
%     orientation: normal
%     column_order: cw
%
%   derived:
%     pixels_per_panel: 20
%     total_pixels_x: 200
%     total_pixels_y: 40
%     panel_width_mm: 45.4
%     inner_radius_mm: 144.65
%   ========================================
%
% See also: load_arena_config, load_rig_config, load_experiment_config

if nargin < 2
    indent_level = 0;
end

%% Header for top-level call
if indent_level == 0
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('RESOLVED CONFIGURATION\n');
    fprintf('========================================\n');

    % Show source files
    if isfield(config, 'source_file') && ~isempty(config.source_file)
        fprintf('Source: %s\n', config.source_file);
    end
    if isfield(config, 'rig_file') && ~isempty(config.rig_file)
        fprintf('Rig:    %s\n', config.rig_file);
    end
    if isfield(config, 'arena_file') && ~isempty(config.arena_file)
        fprintf('Arena:  %s\n', config.arena_file);
    end
    fprintf('\n');
end

%% Get fields to display (exclude meta fields at top level)
meta_fields = {'source_file', 'rig_file', 'arena_file'};
fields = fieldnames(config);

%% Display each field
indent = repmat('  ', 1, indent_level);

for i = 1:length(fields)
    field = fields{i};

    % Skip meta fields at top level
    if indent_level == 0 && ismember(field, meta_fields)
        continue;
    end

    value = config.(field);

    if isstruct(value)
        % Nested struct - recurse
        fprintf('%s%s:\n', indent, field);
        show_resolved_config(value, indent_level + 1);
    elseif isempty(value)
        % Empty value
        if strcmp(field, 'panels_installed')
            fprintf('%s%s: [all]\n', indent, field);
        else
            fprintf('%s%s: [empty]\n', indent, field);
        end
    elseif isnumeric(value)
        if isscalar(value)
            % Scalar number
            if value == floor(value)
                fprintf('%s%s: %d\n', indent, field, value);
            else
                fprintf('%s%s: %.4g\n', indent, field, value);
            end
        else
            % Array
            if length(value) <= 10
                fprintf('%s%s: [%s]\n', indent, field, num2str(value));
            else
                fprintf('%s%s: [%d elements]\n', indent, field, length(value));
            end
        end
    elseif islogical(value)
        if value
            fprintf('%s%s: true\n', indent, field);
        else
            fprintf('%s%s: false\n', indent, field);
        end
    elseif ischar(value) || isstring(value)
        % String value
        if length(value) > 60
            fprintf('%s%s: %s...\n', indent, field, value(1:57));
        else
            fprintf('%s%s: %s\n', indent, field, value);
        end
    elseif iscell(value)
        % Cell array
        fprintf('%s%s: [%d items]\n', indent, field, length(value));
    else
        % Other types
        fprintf('%s%s: [%s]\n', indent, field, class(value));
    end
end

%% Footer for top-level call
if indent_level == 0
    fprintf('========================================\n');
    fprintf('\n');
end

end

function apps = open_pattern_apps(varargin)
%OPEN_PATTERN_APPS Launch pattern apps with saved screen positions
%   OPEN_PATTERN_APPS() launches PatternPreviewerApp, PatternGeneratorApp,
%   and PatternCombinerApp, restoring their last saved positions.
%
%   OPEN_PATTERN_APPS('previewer') launches only PatternPreviewerApp
%   OPEN_PATTERN_APPS('generator') launches only PatternGeneratorApp
%   OPEN_PATTERN_APPS('combiner') launches only PatternCombinerApp
%   OPEN_PATTERN_APPS('previewer', 'generator') launches specified apps
%
%   apps = OPEN_PATTERN_APPS(...) returns struct with app handles
%
%   Use SAVE_PATTERN_APP_LAYOUT to save current positions.
%
%   See also: save_pattern_app_layout, close_pattern_apps

    % Parse which apps to open
    if isempty(varargin)
        openPreviewer = true;
        openGenerator = true;
        openCombiner = true;
    else
        openPreviewer = any(strcmpi(varargin, 'previewer'));
        openGenerator = any(strcmpi(varargin, 'generator'));
        openCombiner = any(strcmpi(varargin, 'combiner'));
    end

    % Load saved layout if available
    prefsDir = fullfile(fileparts(mfilename('fullpath')), '..', 'configs');
    prefsFile = fullfile(prefsDir, 'app_layout.mat');

    layout = struct();
    if exist(prefsFile, 'file')
        loaded = load(prefsFile, 'layout');
        layout = loaded.layout;
        fprintf('Loaded saved layout from:\n  %s\n', prefsFile);
    else
        fprintf('No saved layout found. Apps will open with default positions.\n');
        fprintf('Use save_pattern_app_layout() to save positions after arranging.\n');
    end

    apps = struct();

    % Launch PatternPreviewerApp
    if openPreviewer
        try
            fprintf('Launching PatternPreviewerApp...\n');
            apps.Previewer = PatternPreviewerApp();
            if isfield(layout, 'PreviewerPosition')
                apps.Previewer.UIFigure.Position = layout.PreviewerPosition;
            end
        catch ME
            fprintf('  Failed: %s\n', ME.message);
        end
    end

    % Launch PatternGeneratorApp
    if openGenerator
        try
            fprintf('Launching PatternGeneratorApp...\n');
            apps.Generator = PatternGeneratorApp();
            if isfield(layout, 'GeneratorPosition')
                apps.Generator.UIFigure.Position = layout.GeneratorPosition;
            end
        catch ME
            fprintf('  Failed: %s\n', ME.message);
        end
    end

    % Launch PatternCombinerApp
    if openCombiner
        try
            fprintf('Launching PatternCombinerApp...\n');
            apps.Combiner = PatternCombinerApp();
            if isfield(layout, 'CombinerPosition')
                apps.Combiner.UIFigure.Position = layout.CombinerPosition;
            end
        catch ME
            fprintf('  Failed: %s\n', ME.message);
        end
    end

    fprintf('Done.\n');

    % Don't return output if not requested (cleaner command window)
    if nargout == 0
        clear apps;
    end
end

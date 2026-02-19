function save_pattern_app_layout()
%SAVE_PATTERN_APP_LAYOUT Save current positions of open pattern apps
%   Saves the screen position and size of any open PatternPreviewerApp,
%   PatternGeneratorApp, or PatternCombinerApp to a preferences file.
%
%   Use OPEN_PATTERN_APPS to restore the saved layout.
%
%   See also: open_pattern_apps, close_pattern_apps

    layout = struct();
    savedCount = 0;

    % Find all open figures
    figs = findall(0, 'Type', 'figure');

    for i = 1:numel(figs)
        fig = figs(i);
        try
            figName = get(fig, 'Name');
            pos = get(fig, 'Position');  % [left bottom width height]

            if contains(figName, 'Pattern Previewer', 'IgnoreCase', true)
                layout.PreviewerPosition = pos;
                savedCount = savedCount + 1;
                fprintf('  Saved PatternPreviewerApp: [%d %d %d %d]\n', round(pos));
            elseif contains(figName, 'Pattern Generator', 'IgnoreCase', true)
                layout.GeneratorPosition = pos;
                savedCount = savedCount + 1;
                fprintf('  Saved PatternGeneratorApp: [%d %d %d %d]\n', round(pos));
            elseif contains(figName, 'Pattern Combiner', 'IgnoreCase', true)
                layout.CombinerPosition = pos;
                savedCount = savedCount + 1;
                fprintf('  Saved PatternCombinerApp: [%d %d %d %d]\n', round(pos));
            end
        catch
            % Skip figures that error on property access
        end
    end

    if savedCount == 0
        fprintf('No pattern apps are currently open.\n');
        fprintf('Open and position the apps, then run save_pattern_app_layout() again.\n');
        return;
    end

    % Save to preferences file in user's maDisplayTools config
    prefsDir = fullfile(fileparts(mfilename('fullpath')), '..', 'configs');
    prefsFile = fullfile(prefsDir, 'app_layout.mat');

    save(prefsFile, 'layout');
    fprintf('Saved layout for %d app(s) to:\n  %s\n', savedCount, prefsFile);
end

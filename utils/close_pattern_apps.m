function close_pattern_apps()
%CLOSE_PATTERN_APPS Close all open pattern tool apps
%   Closes PatternPreviewerApp, PatternGeneratorApp, and PatternCombinerApp
%   without affecting other MATLAB figures or apps.

    appClasses = {'PatternPreviewerApp', 'PatternGeneratorApp', 'PatternCombinerApp'};
    closedCount = 0;

    % Find all figure windows
    figs = findall(0, 'Type', 'figure');

    for i = 1:numel(figs)
        fig = figs(i);
        % Check if this figure belongs to one of our apps
        % App Designer apps store the app object in UserData or we can check the Tag
        try
            % Get the figure's name/tag to identify it
            figName = get(fig, 'Name');
            for j = 1:numel(appClasses)
                if contains(figName, 'Pattern', 'IgnoreCase', true)
                    delete(fig);
                    closedCount = closedCount + 1;
                    break;
                end
            end
        catch
            % Skip figures that error on property access
        end
    end

    if closedCount > 0
        fprintf('Closed %d pattern app(s)\n', closedCount);
    else
        fprintf('No pattern apps were open\n');
    end
end

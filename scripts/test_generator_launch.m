% Test PatternGeneratorApp launch
cd('/Users/reiserm/Documents/GitHub/maDisplayTools');
clear classes;
addpath(genpath('.'));

% Test PatternGeneratorApp launches without error
try
    app = PatternGeneratorApp();
    pause(1);

    % Check position (should be around 600 height now)
    pos = app.UIFigure.Position;
    fprintf('PatternGeneratorApp position: [%d %d %d %d]\n', pos(1), pos(2), pos(3), pos(4));

    % Check if buttons exist and are arranged
    fprintf('Generate button column: %d\n', app.GeneratePreviewButton.Layout.Column);
    fprintf('Save button column: %d\n', app.SaveButton.Layout.Column);
    fprintf('Export button column: %d\n', app.ExportScriptButton.Layout.Column);

    delete(app);
    disp('PatternGeneratorApp launched successfully');
catch ME
    disp(['ERROR: ' ME.message]);
    disp(getReport(ME));
end

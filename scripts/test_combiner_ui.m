% Test PatternCombinerApp UI and capture screenshot
cd('/Users/reiserm/Documents/GitHub/maDisplayTools');
clear classes;
rehash path;
addpath(genpath('.'));

% Create screenshots directory if needed
if ~exist('screenshots', 'dir'), mkdir('screenshots'); end

% Launch PatternCombinerApp and capture screenshot
disp('Launching PatternCombinerApp...');
app = PatternCombinerApp();
pause(2);  % Allow UI to render
drawnow;

% Export screenshot
exportapp(app.UIFigure, 'screenshots/combiner_ui_test2.png');
disp('Screenshot saved to screenshots/combiner_ui_test2.png');

% Check window dimensions
pos = app.UIFigure.Position;
fprintf('Window size: %d x %d pixels\n', pos(3), pos(4));

% Close the app
delete(app);
disp('Test complete.');

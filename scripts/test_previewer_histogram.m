% Test script for PatternPreviewerApp with histogram bars
cd('/Users/reiserm/Documents/GitHub/maDisplayTools');
clear classes;
addpath(genpath('.'));

% Test that app launches without error
app = PatternPreviewerApp();
pause(1);

% Load a test pattern to see the histogram
% Create a simple test pattern with varying intensities
testPats = uint8(zeros(40, 200, 1));
for i = 0:15
    testPats(1:40, (i*12+1):((i+1)*12), 1) = i;
end

% Load it using the public API
arenaConfig = load_arena_config('configs/arenas/G6_2x10.yaml');
app.loadPatternFromApp(testPats, 1, 16, 'Test Pattern', arenaConfig);
pause(0.5);

% Capture screenshot - use print since exportapp doesn't work in nodisplay mode
if ~exist('screenshots', 'dir'), mkdir('screenshots'); end
try
    exportapp(app.UIFigure, 'screenshots/previewer_histogram_bars.png');
catch
    % Fallback: try print
    print(app.UIFigure, 'screenshots/previewer_histogram_bars', '-dpng', '-r150');
end

delete(app);
disp('Test completed successfully');
exit;

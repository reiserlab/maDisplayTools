% Test histogram rendering with grayscale → binary → grayscale sequence
cd('/Users/reiserm/Documents/GitHub/maDisplayTools');
delete(findall(0, 'Type', 'figure'));
clear classes;
addpath(genpath('.'));

if ~exist('screenshots', 'dir'), mkdir('screenshots'); end

disp('=== Test 1: Grayscale Pattern ===');
app = PatternPreviewerApp();
pause(1);

% Create grayscale pattern with varied intensities
grayPats1 = uint8(zeros(40, 200, 2));
for i = 0:15
    grayPats1(:, (i*12+1):min((i+1)*12, 200), 1) = i;
end
grayPats1(:,:,2) = 15 - grayPats1(:,:,1);  % Inverted for frame 2

arenaConfig = load_arena_config('configs/arenas/G6_2x10.yaml');
app.loadPatternFromApp(grayPats1, [1 1], 16, 'Grayscale Test 1', arenaConfig);
pause(0.5);
drawnow;

% Try exportapp if display available, otherwise use print
try
    exportapp(app.UIFigure, 'screenshots/hist_test1_grayscale.png');
catch
    print(app.UIFigure, '-dpng', '-r150', 'screenshots/hist_test1_grayscale.png');
end
disp('Screenshot 1 saved: grayscale pattern');

disp('');
disp('=== Test 2: Binary Pattern ===');
% Create binary pattern
binaryPats = uint8(zeros(40, 200, 2));
binaryPats(1:20, :, 1) = 1;  % Top half on
binaryPats(:, 1:100, 2) = 1; % Left half on

app.loadPatternFromApp(binaryPats, [1 1], 2, 'Binary Test', arenaConfig);
pause(0.5);
drawnow;

try
    exportapp(app.UIFigure, 'screenshots/hist_test2_binary.png');
catch
    print(app.UIFigure, '-dpng', '-r150', 'screenshots/hist_test2_binary.png');
end
disp('Screenshot 2 saved: binary pattern');

disp('');
disp('=== Test 3: Back to Grayscale ===');
% Create different grayscale pattern
grayPats2 = uint8(randi([0 15], 40, 200, 2));

app.loadPatternFromApp(grayPats2, [1 1], 16, 'Grayscale Test 2', arenaConfig);
pause(0.5);
drawnow;

try
    exportapp(app.UIFigure, 'screenshots/hist_test3_grayscale.png');
catch
    print(app.UIFigure, '-dpng', '-r150', 'screenshots/hist_test3_grayscale.png');
end
disp('Screenshot 3 saved: grayscale pattern (after binary)');

delete(app);
disp('');
disp('All tests complete - check screenshots');

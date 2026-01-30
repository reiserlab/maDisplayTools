%% demo_histogram_rendering.m
% Demonstration script for PatternPreviewerApp histogram functionality
% Tests grayscale -> binary -> grayscale transitions with screenshots
%
% This script was used to verify histogram rendering after implementing
% persistent graphics objects for performance optimization.
%
% Usage:
%   Run this script to generate test screenshots in the screenshots/ folder
%   Screenshots demonstrate histogram adaptation between pattern types

%% Setup
cd('/Users/reiserm/Documents/GitHub/maDisplayTools');
delete(findall(0, 'Type', 'figure'));  % Close all apps/figures
clear classes;  % Clear cached class definitions
addpath(genpath('.'));  % Add all paths

if ~exist('screenshots', 'dir'), mkdir('screenshots'); end

%% Test 1: Grayscale Pattern (16 intensity levels)
disp('=== Test 1: Grayscale Pattern ===');
app = PatternPreviewerApp();
pause(1);

% Create gradient pattern with all 16 intensity levels
grayPats1 = uint8(zeros(40, 200, 2));
for i = 0:15
    grayPats1(:, (i*12+1):min((i+1)*12, 200), 1) = i;
end
grayPats1(:,:,2) = 15 - grayPats1(:,:,1);  % Inverted for frame 2

arenaConfig = load_arena_config('G6_2x10.yaml');
app.loadPatternFromApp(grayPats1, [1 1], 16, 'Grayscale Test 1', arenaConfig);
pause(0.5);
drawnow;

exportapp(app.UIFigure, 'screenshots/demo_hist1_grayscale.png');
disp('Screenshot 1 saved: 16-level grayscale histogram');

%% Test 2: Binary Pattern (2 intensity levels)
disp('');
disp('=== Test 2: Binary Pattern ===');

% Create binary pattern (top half = 1, bottom half = 0)
binaryPats = uint8(zeros(40, 200, 2));
binaryPats(1:20, :, 1) = 1;   % Top half ON in frame 1
binaryPats(:, 1:100, 2) = 1;  % Left half ON in frame 2

app.loadPatternFromApp(binaryPats, [1 1], 2, 'Binary Test', arenaConfig);
pause(0.5);
drawnow;

exportapp(app.UIFigure, 'screenshots/demo_hist2_binary.png');
disp('Screenshot 2 saved: 2-level binary histogram');

%% Test 3: Back to Grayscale (verify histogram reinitializes)
disp('');
disp('=== Test 3: Back to Grayscale ===');

% Create random grayscale pattern
grayPats2 = uint8(randi([0 15], 40, 200, 2));

app.loadPatternFromApp(grayPats2, [1 1], 16, 'Grayscale Test 2', arenaConfig);
pause(0.5);
drawnow;

exportapp(app.UIFigure, 'screenshots/demo_hist3_grayscale_after_binary.png');
disp('Screenshot 3 saved: grayscale histogram after binary transition');

%% Cleanup
delete(app);
disp('');
disp('=== Demo Complete ===');
disp('Screenshots saved to screenshots/ folder:');
disp('  - demo_hist1_grayscale.png');
disp('  - demo_hist2_binary.png');
disp('  - demo_hist3_grayscale_after_binary.png');

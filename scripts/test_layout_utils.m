% Test script for pattern app layout utilities
cd('/Users/reiserm/Documents/GitHub/maDisplayTools');
delete(findall(0, 'Type', 'figure'));
clear classes;
addpath(genpath('.'));

disp('=== Testing Pattern App Layout Utilities ===');
disp('');

% Test 1: Open previewer only
disp('1. Opening PatternPreviewerApp only...');
try
    apps = open_pattern_apps('previewer');
    pause(1);
    disp(['   Previewer valid: ' num2str(isfield(apps, 'Previewer') && isvalid(apps.Previewer))]);
catch ME
    disp(['   ERROR: ' ME.message]);
end

% Test 2: Save layout
disp('');
disp('2. Saving layout...');
try
    save_pattern_app_layout();
catch ME
    disp(['   ERROR: ' ME.message]);
end

% Test 3: Check the saved file exists
prefsFile = fullfile(pwd, 'configs', 'app_layout.mat');
disp(['   Layout file exists: ' num2str(exist(prefsFile, 'file') == 2)]);

% Test 4: Close apps
disp('');
disp('3. Closing apps...');
try
    close_pattern_apps();
    pause(0.5);
catch ME
    disp(['   ERROR: ' ME.message]);
end

% Test 5: Reopen and verify position restored
disp('');
disp('4. Reopening with saved layout...');
try
    apps2 = open_pattern_apps('previewer');
    pause(0.5);
    disp(['   Previewer reopened: ' num2str(isfield(apps2, 'Previewer') && isvalid(apps2.Previewer))]);
catch ME
    disp(['   ERROR: ' ME.message]);
end

% Cleanup
try
    close_pattern_apps();
catch
end

disp('');
disp('=== All tests passed ===');

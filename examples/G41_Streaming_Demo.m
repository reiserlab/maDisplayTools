%% Simple streaming demo
% This demo creates a pattern of vertical bars and then runs five trials.
% Trial 1 - static frame, no motion
% Trial 2 - shifts bars to the right one pixel at a time for 48 total
% frames at a shifting rate of 10 shifts per second
% Trial 3 - shifts bars to the left one pixel at a time for 48 total
% frames at a shifting rate of 10 shifts per second
% Trial 4 - shifts bars to the right five pixels at a time for 48 total
% frames at a shifting rate of 10 shifts per second
% Trial 5 - shifts bars to the left five pixels at a time for 48 total
% frames at a shifting rate of 10 shifts per second

% This is just one potential way of handling your loops and parameters,
% your code can be very different as long as the way in which you convert
% patArray to pattern (make sure you take into account gs value) and the
% way in which you stream the pattern (panelsController.streamFrame) are as
% seen here. Make sure you always save the initial state of your pattern
% for easy reset between trials, and always clean up after (stop display 
% and close the controller).

%% Establish parameters and metadata

num_trials = 5;
shift_per_trial = [0 1 -1 5 -5]; % This way pattern can move different directions 
% for different trials even though trials are all run in the same loop. 1
% shifts right, -1 shifts left, 0 = no sh.
static_duration = 5; %duration for any static frames being streamed
aox = 0; 
aoy = 0;
pat_gs = 16; % 2 for binary, 16 for grayscale
num_frames = 48; % The number of times you want to shift the pattern in a single trial
shift_rate = 10; % Ten shifts per second, so 48 shifts makes a trial of approximately 4.8s
%% Load/create initial pattern

% Define pattern dimensions
rows = 32;  % 16 for 1 row arena, 32 for 2 row arena ,48 for 3 row arena, 64 for 4 row arena
cols = 192;

% Create the pattern array
% This example creates a vertical grating that shifts horizontally

% Create the base pattern for one row of a single frame
pat_row = zeros(1, cols, 'uint8');
for i = 0:(cols/12 - 1)
    if mod(i, 2) == 0
        val = 1;
    else
        val = 0;
    end
    pat_row((i*12 + 1):(i*12 + 12)) = val;
end
% create pattern of these rows
patArray = zeros(rows, cols, 'uint8');
for row = 1:rows
    patArray(row, :) = pat_row;
end
patArrayInitial = patArray; %store initial state of the pattern for re-use

if pat_gs == 2 || pat_gs == 1
    pattern = maDisplayTools.make_framevector_binary(patArrayInitial,0);
elseif pat_gs == 16 || pat_gs == 4  
    pattern = maDisplayTools.make_framevector_gs16(patArrayInitial, 0);
else
    error('pat_gs value invalid. 2 for binary or 16 for grayscale, deprecated values of 1 and 4 also accepted');
end
patternInitial = pattern; % store converted initial pattern frame for re-use

%% Initialize Panels Controller and other hardware
panelsController = PanelsController('10.102.40.47');
panelsController.open(false);

%% Execute any pre-experiment hardware preparations

%% Start experiment

for trial = 1:num_trials
    if shift_per_trial(trial) == 0
        %static pattern, just stream. If you wanted to display a pattern
        %other than the initial frame, shift here however you want then
        %stream. 
        panelsController.streamFrame(aox,aoy,patternInitial);
        pause(static_duration);
    else
        shift_val = shift_per_trial(trial);
        panelsController.streamFrame(aox,aoy,patternInitial); 
        pause(1/shift_rate);
        for frame = 2:num_frames
            patArray = circshift(patArray,[0,shift_val]);
            if pat_gs == 2 || pat_gs == 1
                pattern = maDisplayTools.make_framevector_binary(patArray,0);
            elseif pat_gs == 16 || pat_gs == 4  
                pattern = maDisplayTools.make_framevector_gs16(patArray, 0);
            else
                error('pat_gs value invalid. 2 for binary or 16 for grayscale, deprecated values of 1 and 4 also accepted');
            end
            panelsController.streamFrame(aox,aoy,pattern);
            pause(1/shift_rate); 
        end
    end
    patArray = patArrayInitial; %reset pattern for next trial.
end

%%  Final Cleanup 
panelsController.stopDisplay();
panelsController.close(true);
disp('Demo Finished.');
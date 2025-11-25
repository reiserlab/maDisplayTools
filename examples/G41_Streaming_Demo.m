%% Establish parameters and metadata
num_trials = 5;
aox = 0;
aoy = 0;
patShift = 5;
pat_gs = 16; % 2 for binary, 16 for grayscale
%% Load/create initial pattern

% Define pattern dimensions
rows = 48;  % 16 for 1 row arena, 32 for 2 row arena ,48 for 3 row arena, 64 for 4 row arena
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

%% Initialize Panels Controller and other hardware
panelsController = PanelsController('192.168.10.62');
panelsController.open(false);

%% Execute any pre-experiment hardware preparations

%% Start experiment

% First trial
if pat_gs == 2 || pat_gs == 1
    pattern = maDisplayTools.make_framevector_binary(patArray,0);
elseif pat_gs == 16 || pat_gs == 4  
    pattern = maDisplayTools.make_framevector_gs16(patArray, 0);
else
    error('pat_gs value invalid. 2 for binary or 16 for grayscale, deprecated values of 1 and 4 also accepted');
end
PanelsController.streamFrame(aox,aoy,pattern);

for trial = 2:num_trials
    %shift pattern in some way
    patArray =  circshift(patArray, [0,patShift]);
    if pat_gs == 2 || pat_gs == 1
        pattern = maDisplayTools.make_framevector_binary(patArray,0);
    elseif pat_gs == 16 || pat_gs == 4  
        pattern = maDisplayTools.make_framevector_gs16(patArray, 0);
    else
        error('pat_gs value invalid. 2 for binary or 16 for grayscale, deprecated values of 1 and 4 also accepted');
    end
    % update any other parameters or hardware

    %stream the pattern
    PanelsController.streamFrame(aox,aoy,pattern);

end

%%  Final Cleanup 
panelsController.close(true);
disp('Demo Finished.');
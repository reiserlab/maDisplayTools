%% Demo of trial in mode 2, 3, or 4.

% As of now, patterns must be moved to the SD card manually before they can
% be accessed. Before running this demo, please ensure the SD card on the 
% teensy has been loaded with at least 3 patterns. 

% The following parameters are required: mode, pattern id, frame rate,
% initial frame position, gain, and duration. Any parameters not necessary
% for the particular mode can be left empty []. 
patIDS = {1 2 3}; %This demo will cycle through patterns with other parameters staying the same. 
% Other parameters could also be made into a cell array to cycle through. 
% Conditions here are sequential but you could randomize by choosing a
% random pattern from the cell array on each loop. 
mode = 2;
posX = 1; % The frame number to start on
frameRate = 10;
gain = []; % unneeded in mode 2. 
dur = 5; %seconds, will convert to deciseconds in execution.

% IP address for the arena
ip_add = '10.102.40.61';

%Steps for a single trial

panelsController = PanelsController(ip_add);
panelsController.open(false);

for pat = 1:length(patIDS)
    patID = patIDs{pat};
    panelsController.startG41Trial(self, mode, patID, frameRate, posX, gain, dur*10)
    pause(dur);
end
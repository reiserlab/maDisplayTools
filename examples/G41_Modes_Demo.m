% mode 2 experiment

% Mode 2 requires the following parameters: mode, pattern id, frame rate,
% initial frame position, and duration.
pat = 3;
mode = 2;
frame_ind = 1;
frame_rate = 20;
dur = 5;

%Patterns must be saved on SD card before running 
sd_dir = '';

% IP address for the arena
ip_add = '10.102.40.61';

%Steps for a single trial

panelsController = PanelsController(ip_add);
panelsController.open(false);
setG41TrialParams(self, mode, patID, frameRate, posX, gain, dur)
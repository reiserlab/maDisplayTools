%% Demo of all implemented PanelsController commands aside from modes. 

%% Initialize Panels Controller
ip_add = '10.102.40.61'; % may vary by arena
panelsController = PanelsController(ip_add);
panelsController.open(false);

%% All On

success = panelsController.allOn();
if success == 1
    disp("All on demo complete. Moving to All off.");
else
    disp("All on was not successful. Please check firmware state or reboot arena.");
    return;
end

%% All off

success = panelsController.allOff();
if success == 1
    disp("All of demo complete. Moving to streaming mode.");
else
    disp("All off was not successful. Please check firmware state or reboot arena.");
    return;
end

%% Streaming mode

% First you have to make a pattern 

%set grayscale value
pat_gs = 16;
% Define pattern dimensions
rows = 32;  % 16 for 1 row arena, 32 for 2 row arena ,48 for 3 row arena, 64 for 4 row arena
cols = 192;

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

if pat_gs == 2 || pat_gs == 1
    pattern = maDisplayTools.make_framevector_binary(patArray,0);
elseif pat_gs == 16 || pat_gs == 4  
    pattern = maDisplayTools.make_framevector_gs16(patArray, 0);
else
    error('pat_gs value invalid. 2 for binary or 16 for grayscale, deprecated values of 1 and 4 also accepted');
end

% Set duration to stream static frame in seconds: 
static_duration = 5;
% set parameters
aox = 0;
aoy = 0;

success = panelsController.streamFrame(aox,aoy,pattern);
pause(static_duration);

if success == 1
    disp("Stream frame demo finished. Moving on to stop display.");
else
    disp("Streaming mode was not successful. Please check firmware state or reboot arena.");
    return;
end

%% Stop Display

success = panelsController.stopDisplay();
if success == 1
    disp("Stop display demo finished. moving on to display reset");
else
    disp("Stop display was not successful. Please check firmware state or reboot arena.");
    return;
end

% %% Display Reset - commented out because it is crashing the firmware -
% need to investigate.
% 
% success = panelsController.sendDisplayReset();
% if success == 1
%     disp('Display reset demo finished. Moving on to getEthernetIPAddress');
% else
%     disp('Display reset was unsuccessful.');
% end

%% Get Ethernet IP Address - will implement in PanelsController

disp("Get ethernet IP address not yet implemented in matlab wrapper but this " + ...
    "demo will send the command via pnet and read the response.")

cmdData = uint8([1 102]);
pnet(panelsController.tcpConn, 'write', cmdData);

% Step 1: Read the first byte to get total response length
lengthByte = pnet(panelsController.tcpConn, 'read', 1, 'uint8');
    
if isempty(lengthByte)
    error('No response received from hardware');
end

% Step 2: Read the remaining bytes (total_length - 1, since we already read 1)
remainingBytes = lengthByte - 1;
response = pnet(panelsController.tcpConn, 'read', remainingBytes, 'uint8');

% Combine: [lengthByte, response]
fullResponse = [lengthByte; response(:)];

% Skip first 3 bytes (length, command_echo, status) to get payload
payload = fullResponse(4:end);

% Convert payload to IP address string
% Assuming payload is 4 bytes representing IP octets
if length(payload) >= 4
    ipAddress = sprintf('%d.%d.%d.%d', payload(1), payload(2), payload(3), payload(4));
else
    ipAddress = '';
    warning('Invalid IP address response');
end

disp(['IP address: ' ipAddress]);
disp("ethernet IP demo finished. Moving on to set refresh rate.");

%% Set Refresh rate - Will implement in PanelsController

disp("Set refresh rate is not yet implemented in panels controller, but I will " + ...
    "send the command via pnet");
cmdData = uint8([3 22]);
refreshRate = 20;
pnet(panelsController.tcpConn, 'write', refreshRate);

disp("Refresh rate demo finsihed. Moving on to set frame position.");

%% Set Frame position

posX = 1;
panelsController.setPositionX(posX);
disp("Set frame position currently does not return a success value. Will add in future versions.");
disp("Set frame position successful. Moving on to clean up.");

%% Switch grayscale - I forgot to add this one at first and havent' tested it yet
% 
% gs_val = 2;
% success = panelsController.setColorDepth(self, gs_val);
% if success == 1
%     disp("Grayscale switch successful. Moving on to clean up.");
% else
%     disp("Grayscale swithc not successfull. Please check firmware state or boot arena.");
%     return;
% end

%% Clean up. Always run these when you're done with the arena.

panelsController.stopDisplay();
panelsController.close();
clear;

function [Pats, num_frames, true_step_size] = make_reverse_phi(param, arena_x, arena_y, arena_z, arena_file)
% FUNCTION [Pats, num_frames, true_step_size] = make_reverse_phi(param, arena_x, arena_y, arena_z, arena_file)
%
% Creates reverse-phi (reverse-phi) motion pattern - a classic motion illusion
% where brightness inverts between consecutive frames while the pattern shifts
% position. This causes perceived motion opposite to the physical displacement.
%
% The pattern is useful for studying motion detection circuits, particularly
% the elementary motion detector (EMD) or Hassenstein-Reichardt correlator model.
%
% inputs:
%   param: structure containing pattern parameters (see make_grating_edge for details)
%   arena_x/y/z: cartesian coordinates of pixels in arena
%   arena_file: path to arena coordinate file
%
% outputs:
%   Pats: array of brightness values with alternating inverted frames
%   num_frames: number of frames in Pats
%   true_step_size: corrected step size value
%
% Example usage (via Pattern_Generator):
%   param.pattern_type = 'reverse_phi';
%   param.motion_type = 'rotation';
%   param.spat_freq = deg2rad(30);  % 30 degree wavelength
%   param.step_size = deg2rad(3);   % 3 degrees per frame
%   param.levels = [15, 0, 0];      % High contrast
%
% Reference:
%   Anstis, S. M. (1970). Phi movement as a subtraction process.
%   Vision Research, 10(12), 1411-1430.

% Generate the base grating pattern using existing infrastructure
% We use square grating as the base pattern for clearest reverse-phi effect
base_param = param;

% Generate the underlying grating pattern
[Pats, num_frames, true_step_size] = make_grating_edge(base_param, arena_x, arena_y, arena_z, arena_file);

% Calculate the inversion: reverse-phi inverts brightness on alternate frames
% Original brightness b becomes (max - b) on inverted frames
% This preserves the spatial frequency but creates the illusion of reversed motion

max_level = max(param.levels(1:2));
min_level = min(param.levels(1:2));
level_range = max_level - min_level;

% Invert alternate frames (frames 2, 4, 6, ...)
for frame = 2:2:num_frames
    % Normalize to 0-1, invert, then scale back
    normalized = (Pats(:,:,frame) - min_level) / level_range;
    inverted = 1 - normalized;
    Pats(:,:,frame) = inverted * level_range + min_level;
end

% Note: The resulting pattern will appear to move in the OPPOSITE direction
% of the actual spatial shift. This is because the motion detection system
% (EMD model) correlates brightness changes across space and time, and
% the brightness inversion causes the correlation to be strongest in the
% direction opposite to the physical displacement.

end

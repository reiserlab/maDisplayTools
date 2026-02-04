function [Pats, num_frames, true_step_size] = make_reverse_phi(param, arena_x, arena_y, arena_z, arena_file)
% FUNCTION [Pats, num_frames, true_step_size] = make_reverse_phi(param, arena_x, arena_y, arena_z, arena_file)
%
% Creates reverse-phi motion pattern - a visual illusion where the pattern
% shifts spatially while contrast inverts on EVERY frame. This causes the
% perceived motion direction to be OPPOSITE to the physical displacement.
%
% The illusion arises because motion detection circuits (Hassenstein-Reichardt
% correlator / elementary motion detector) correlate luminance changes across
% space and time. When contrast inverts with each spatial shift, the strongest
% correlation occurs in the direction opposite to the physical movement.
%
% Implementation:
%   - Uses square wave grating with fixed 50% duty cycle
%   - Supports rotation, translation, and expansion-contraction motion types
%   - Contrast inverts between consecutive frames (not just alternate frames)
%   - Frame N: bright bars at positions p, p+wavelength, ...
%   - Frame N+1: dark bars at positions p+step, p+step+wavelength, ...
%
% Inputs: (all angles in radians)
%   param: structure containing:
%       .motion_type: 'rotation', 'translation', or 'expansion-contraction'
%       .pattern_fov: 'local' or 'full-field'
%       .spat_freq: spatial wavelength (radians)
%       .step_size: motion per frame (radians)
%       .levels: [bright, dark, background] intensity values
%       .pole_coord: [longitude, latitude] of pattern pole (full-field mode)
%       .sa_mask: solid angle mask parameters
%       .motion_angle: direction of motion (local mode)
%       .aa_samples: anti-aliasing samples per pixel
%       .aa_poles: whether to anti-alias poles
%       .rows, .cols: arena pixel dimensions (set by Pattern_Generator)
%       .p_rad: pixel angular radius (set by Pattern_Generator)
%   arena_x/y/z: cartesian coordinates of pixels in arena
%   arena_file: path to arena coordinate file
%
% Outputs:
%   Pats: 3D array (rows x cols x num_frames) of brightness values
%   num_frames: number of frames in pattern
%   true_step_size: corrected step size (adjusted to divide evenly into spat_freq)
%
% Example usage (via Pattern_Generator):
%   param.pattern_type = 'reverse_phi';
%   param.motion_type = 'rotation';
%   param.spat_freq = deg2rad(30);  % 30 degree wavelength
%   param.step_size = deg2rad(3);   % 3 degrees per frame
%   param.levels = [15, 0, 0];      % bright=15, dark=0, background=0
%
% Reference:
%   Anstis, S. M. (1970). Phi movement as a subtraction process.
%   Vision Research, 10(12), 1411-1430.
%
% See also: make_grating_edge, Pattern_Generator

%% Set up coordinate system based on motion type and FOV
% This logic matches make_grating_edge for consistency

if strncmpi(param.pattern_fov, 'f', 1)  % Full-field: orient pattern for pole coordinates
    rotations = [-param.pole_coord(1), -param.pole_coord(2) - pi/2, 0];
else  % Local: orient poles so motion is maximal at mask center
    if strncmpi(param.motion_type, 'r', 1)
        rotations = [-param.sa_mask(1:2), -param.motion_angle];
    else  % Translation: roll more so motion = rightward by default
        rotations = [-param.sa_mask(1:2), -param.motion_angle - pi/2];
    end
end

[pat_x, pat_y, pat_z] = rotate_coordinates(arena_x, arena_y, arena_z, rotations);
[pat_phi, pat_theta, ~] = cart2sphere(pat_x, pat_y, pat_z);

%% Determine coordinate through which pattern changes
if strncmpi(param.motion_type, 'r', 1)
    coord = pat_phi;  % Rotation: motion through phi coordinate
elseif strncmpi(param.motion_type, 'e', 1)
    coord = pat_theta;  % Expansion-contraction: motion through theta
else
    coord = tan(pat_theta - pi/2);  % Translation: motion through apparent distance
end

%% Apply anti-aliasing by sampling multiple points per pixel
coord = samples_by_p_rad(coord, param.aa_samples, arena_file);

%% Calculate number of frames
% Must complete one full spatial wavelength
num_frames = max([1, round(param.spat_freq / param.step_size)]);
true_step_size = param.spat_freq / num_frames;

%% Generate reverse-phi pattern
% Fixed 50% duty cycle for reverse-phi
duty_cycle = 50;

% Get brightness levels
bright_level = param.levels(1);
dark_level = param.levels(2);

% Pre-allocate pattern array
Pats = zeros(param.rows, param.cols, num_frames);

% Generate each frame with alternating contrast
for frame = 1:num_frames
    % Calculate phase offset for this frame
    phase_offset = (frame - 1) * true_step_size;

    % Generate square wave grating at this phase
    % square() returns values from -1 to 1, convert to 0-1 range
    grating = squeeze(mean(square((coord + param.phase_shift - phase_offset) * 2 * pi / param.spat_freq, duty_cycle), 3) + 1) / 2;

    % Determine if this frame should be inverted
    % Frame 1: normal, Frame 2: inverted, Frame 3: normal, etc.
    if mod(frame, 2) == 0
        % Even frames: invert contrast (swap bright and dark)
        Pats(:, :, frame) = grating * (dark_level - bright_level) + bright_level;
    else
        % Odd frames: normal contrast
        Pats(:, :, frame) = grating * (bright_level - dark_level) + dark_level;
    end
end

%% Apply pole anti-aliasing (if enabled)
% Correct for aliasing at poles where spatial frequency is too small to sample
if ~strncmpi(param.motion_type, 'e', 1) && param.aa_poles == 1
    t2 = param.p_rad;  % Sampling angle
    d2 = param.spat_freq / 2;  % Minimum angle for sampling (Nyquist limit)

    if strncmpi(param.motion_type, 'r', 1)
        ns_angle = t2 / d2;
    else
        % Calculate maximum distance that can be accurately sampled
        d1 = -d2/2 + sqrt(d2^2/4 + d2/tan(t2) - 1);
        ns_angle = pi/2 - atan(d1) - t2/2;
    end

    % Mask both poles with mid-gray value (average of bright and dark)
    samples = samples_by_diff(pat_theta, param.aa_samples);
    mask = samples < ns_angle | samples > pi - ns_angle;
    mask = mean(mask, 3);
    mask = repmat(mask, [1, 1, num_frames]);

    % Fill masked pole regions with mid-gray
    mid_level = (bright_level + dark_level) / 2;
    Pats = Pats .* (1 - mask) + mid_level .* mask;
end

end

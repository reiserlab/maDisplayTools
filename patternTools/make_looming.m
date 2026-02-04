function [Pats, num_frames, true_step_size] = make_looming(param, arena_x, arena_y, arena_z, arena_file)
% FUNCTION [Pats, num_frames, true_step_size] = make_looming(param, arena_x, arena_y, arena_z, arena_file)
%
% Creates looming stimulus - an expanding circle on the spherical display
% that simulates an object approaching along a trajectory defined by the pole.
%
% Two approach profiles are supported:
%   1. Constant velocity: Angular size increases linearly with time
%      theta(t) = theta_initial + rate * t
%
%   2. Exponential: Angular size follows realistic collision-course dynamics
%      theta(t) = 2 * atan(l / (2 * v * (t_collision - t)))
%      where l/v is the size-to-velocity ratio
%      This creates the characteristic rapid expansion near "impact"
%
% The looming object is a filled circle centered at the pole coordinates,
% projected onto the spherical arena surface. Anti-aliasing is applied
% at the circle edge for smooth appearance.
%
% Inputs: (all angles in radians unless noted)
%   param: structure containing:
%       .loom_profile: 'constant_velocity' or 'exponential'
%       .initial_size: starting angular radius (radians)
%       .final_size: ending angular radius (radians)
%       .l_over_v: size/velocity ratio in seconds (exponential only)
%       .pole_coord: [longitude, latitude] center of looming object
%       .levels: [object_brightness, background_brightness, mask_background]
%       .aa_samples: anti-aliasing samples per pixel
%       .rows, .cols: arena pixel dimensions (set by Pattern_Generator)
%       .p_rad: pixel angular radius (set by Pattern_Generator)
%   arena_x/y/z: cartesian coordinates of pixels in arena
%   arena_file: path to arena coordinate file
%
% Outputs:
%   Pats: 3D array (rows x cols x num_frames) of brightness values
%   num_frames: number of frames in pattern (calculated from profile)
%   true_step_size: angular size change per frame (for info only)
%
% Example usage (via Pattern_Generator):
%   % Constant velocity loom
%   param.pattern_type = 'looming';
%   param.loom_profile = 'constant_velocity';
%   param.initial_size = deg2rad(5);    % Start at 5 degrees
%   param.final_size = deg2rad(90);     % Expand to 90 degrees
%   param.pole_coord = [0, 0];          % Center of arena
%   param.levels = [15, 0, 0];          % Bright object on dark background
%
%   % Exponential loom
%   param.pattern_type = 'looming';
%   param.loom_profile = 'exponential';
%   param.initial_size = deg2rad(5);
%   param.final_size = deg2rad(80);
%   param.l_over_v = 0.040;             % 40 ms l/v ratio
%   param.pole_coord = [0, 0];
%   param.levels = [15, 0, 0];
%
% References:
%   Gabbiani, F., Krapp, H. G., & Laurent, G. (1999). Computation of object
%   approach by a wide-field, motion-sensitive neuron. Journal of Neuroscience.
%
%   Fotowat, H., & Gabbiani, F. (2011). Collision detection as a model for
%   sensory-motor integration. Annual Review of Neuroscience.
%
% See also: Pattern_Generator, make_grating_edge

%% Validate parameters
if ~isfield(param, 'loom_profile')
    param.loom_profile = 'constant_velocity';
end

if ~isfield(param, 'initial_size') || ~isfield(param, 'final_size')
    error('make_looming:MissingParams', 'initial_size and final_size are required');
end

if param.initial_size >= param.final_size
    error('make_looming:InvalidSize', 'initial_size must be less than final_size');
end

if param.final_size > pi
    warning('make_looming:LargeSize', 'final_size > pi radians (180 deg) will cover more than hemisphere');
end

%% Load arena parameters for anti-aliasing
load(arena_file, 'p_rad');
if ~exist('p_rad', 'var')
    p_rad = param.p_rad;
end

%% Rotate coordinates so loom center is at the pole
% The pole_coord defines where the looming object appears
rotations = [-param.pole_coord(1), -param.pole_coord(2) - pi/2, 0];
[pat_x, pat_y, pat_z] = rotate_coordinates(arena_x, arena_y, arena_z, rotations);
[~, pat_theta, ~] = cart2sphere(pat_x, pat_y, pat_z);

% pat_theta is the angular distance from the loom center (pole)
% At the pole, theta = 0; at the equator, theta = pi/2

%% Calculate angular sizes for each frame based on profile
if strncmpi(param.loom_profile, 'c', 1)
    % Constant velocity profile
    % Linear interpolation from initial to final size

    % Determine number of frames based on step_size or reasonable default
    if isfield(param, 'step_size') && param.step_size > 0
        num_frames = max([2, round((param.final_size - param.initial_size) / param.step_size)]);
    else
        % Default: approximately 1 degree per frame
        num_frames = max([2, round(rad2deg(param.final_size - param.initial_size))]);
    end

    % Linear spacing of angular sizes
    theta_sizes = linspace(param.initial_size, param.final_size, num_frames);
    true_step_size = (param.final_size - param.initial_size) / (num_frames - 1);

elseif strncmpi(param.loom_profile, 'e', 1)
    % Exponential profile (realistic collision course)
    % theta(t) = 2 * atan(l / (2 * v * (t_collision - t)))
    % where l/v ratio determines approach dynamics

    if ~isfield(param, 'l_over_v') || param.l_over_v <= 0
        error('make_looming:MissingLV', 'l_over_v (positive value in seconds) required for exponential profile');
    end

    l_over_v = param.l_over_v;  % in seconds

    % From the looming equation, solve for time:
    % theta = 2 * atan(l / (2*v * tau))  where tau = t_collision - t
    % tau = l / (2*v * tan(theta/2)) = (l/v) / (2 * tan(theta/2))

    % Calculate time to collision for initial and final sizes
    tau_initial = l_over_v / (2 * tan(param.initial_size / 2));
    tau_final = l_over_v / (2 * tan(param.final_size / 2));

    % tau decreases as object approaches (tau_initial > tau_final)
    if tau_final <= 0
        tau_final = 0.001;  % Avoid division by zero at collision
    end

    % Number of frames: use time-based sampling
    % Assume a reasonable frame rate for determining frame count
    if isfield(param, 'frame_rate') && param.frame_rate > 0
        dt = 1 / param.frame_rate;
    else
        % Default: sample so we get reasonable temporal resolution
        % More frames near the end where expansion is fastest
        dt = (tau_initial - tau_final) / 60;  % ~60 frames default
    end

    num_frames = max([2, ceil((tau_initial - tau_final) / dt)]);

    % Generate time points (tau decreasing from tau_initial to tau_final)
    tau_values = linspace(tau_initial, tau_final, num_frames);

    % Calculate angular size at each time point
    theta_sizes = 2 * atan(l_over_v ./ (2 * tau_values));

    % Report average step size (varies across frames for exponential)
    true_step_size = (param.final_size - param.initial_size) / (num_frames - 1);

else
    error('make_looming:InvalidProfile', 'loom_profile must be ''constant_velocity'' or ''exponential''');
end

%% Get brightness levels
object_level = param.levels(1);
background_level = param.levels(2);

%% Apply anti-aliasing by sampling multiple points per pixel
% Sample the angular distance from loom center at multiple points per pixel
theta_samples = samples_by_p_rad(pat_theta, param.aa_samples, arena_file);

%% Generate looming pattern frames
Pats = zeros(param.rows, param.cols, num_frames);

for frame = 1:num_frames
    current_radius = theta_sizes(frame);

    % For each pixel, calculate fraction inside the looming circle
    % This provides anti-aliased edges

    % Pixels where all samples are inside the circle
    inside = theta_samples < current_radius;
    fraction_inside = mean(inside, 3);  % Average across AA samples

    % Blend between object and background based on fraction inside
    Pats(:, :, frame) = fraction_inside * object_level + ...
                        (1 - fraction_inside) * background_level;
end

%% Round to integer values
Pats = round(Pats);

end

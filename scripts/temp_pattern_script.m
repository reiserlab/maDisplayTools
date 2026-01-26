% Script version of Pattern_Generator with current GUI parameters
% (script saved in /Users/reiserm/Documents/GitHub/maDisplayTools/scripts)
%
% Save this script with a new filename to keep it from being overwritten

%% user-defined pattern parameters
% all angles/distances/sizes are in units of radians rather than degrees
% some parameters are only needed in certain cirumstances {specified by curly brace}
param.pattern_type = 'starfield'; %square grating, sine grating, edge, starfield, or Off/On
param.motion_type = 'rotation'; %rotation, translation, or expansion-contraction
param.pattern_fov = 'full-field'; %full-field or local
param.arena_pitch = 0; %angle of arena pitch (0 = straight ahead, positive values = pitched up)
param.gs_val = 4; %bits of intensity value (1 or 4)
param.levels = [15 0 7]; %brightness level of [1st bar (in grating) or advancing edge, 2nd bar or receding edge, background (mask)]
param.pole_coord = [0 -1.571]; %location of pattern pole [longitude, latitude] {for pattern_fov=full-field}
param.motion_angle = 0; %angle of rotation (0=rightward motion, positive values rotate the direction clockwise) {fov=local}
param.spat_freq = 0.7854; %spatial angle (in radians) before pattern repeats {for gratings and edge}
param.step_size = 0.03272; %amount of motion per frame (in radians) {for type~=off/on}
param.duty_cycle = 10; %percent of spat_freq taken up by first bar {for square gratings}
param.num_dots = 500; %number of dots in star-field {for type=starfield}
param.dot_radius = 0.03272; %radius of dots (in radians) {for starfield}
param.dot_size = 'static'; %static or distance-relative {for starfield}
param.dot_occ = 'sum'; %how occluding dots are drawn (closest, sum, or mean) {for starfield}
param.dot_re_random = 1; %whether to re-randomize dot starting locations (1=randomize, 0=reuse previous) {for startfield}
param.dot_level = 0; %0 = dot brightness set to 1st level; 1 and 2 = random brightness (0-1st; 0 or 1st) {for starfield}
param.snap_dots = 0; %1 if apparent dot locations should be rounded to the nearest pixel {for starfield}
param.sa_mask = [0    0 3.14    0]; %location, size, and direction of solid angle mask [longitude, latitude, solid_angle, out/in]
param.long_lat_mask = [-3.14  3.14 -1.57  1.57     0]; %coordinates of latitude/longitude mask [min-long, max-long, min-lat, max-latitude, out/in]
param.aa_samples = 15; %# of samples taken to calculate the brightness of each pixel (1 or 15 suggested)
param.aa_poles = 1; %1=anti-aliases the poles of rotation/translation grating/edge stimuli by matching them to the duty cycle
param.back_frame = 0; %1=adds a frame (frame 1) uniformly at background (mask) level
param.flip_right = 0; %1=left-right flips the right half of the pattern
param.phase_shift = 0; %shifts the starting frame of pattern (in radians)
param.checker_layout = 0; %0 = standard LED panel layout; 1 = checkerboard (e.g. 2-color) panel layout


%% generate pattern
[Pats, param.true_step_size, param.rot180] = Pattern_Generator(param);
param.stretch = zeros(size(Pats,3),1); %stretch increases (within limits) the per-frame brightness -- zeros add no brightness


%% save pattern
save_dir = /Users/reiserm/Documents/GitHub/maDisplayTools/configs;
patName = 'Pattern';
param.ID = get_pattern_ID(save_dir);
save_pattern(Pats, param, save_dir, patName, arena_file);


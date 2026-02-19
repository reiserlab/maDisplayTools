function specs = get_generation_specs(generation)
% GET_GENERATION_SPECS - Single source of truth for panel specifications
%
% Returns hardware specifications for a given panel generation.
% This function consolidates specifications that were previously duplicated in:
%   - load_arena_config.m (compute_derived_properties)
%   - load_rig_config.m (compute_arena_derived)
%   - design_arena.m (get_panel_specs)
%
% Usage:
%   specs = get_generation_specs('G4')
%   specs = get_generation_specs('G4.1')
%   specs = get_generation_specs('G6')
%
% Input:
%   generation - string: 'G3', 'G4', 'G4.1', or 'G6'
%
% Output:
%   specs - struct with fields:
%     Basic specs:
%       pixels_per_panel    - pixels per panel edge (8, 16, or 20)
%       panel_width_mm      - panel width in mm
%       panel_depth_mm      - panel depth (PCB thickness + LEDs)
%
%     Pin configuration (for physical layout):
%       num_pins            - total pins for connection
%       pin_dist_mm         - distance from panel center to pins
%       pin_spacing_mm      - spacing between adjacent pins
%       pin_config          - 'single' or 'dual' header
%       header_separation_mm - (G6 only) distance between dual headers
%       pins_to_plot        - array of pins to draw in layout diagrams
%
%     Metadata:
%       generation          - canonical generation name
%       led_type            - LED array type description
%
% Sources:
%   G6: KiCad files from https://github.com/iorodeo/LED-Display_G6_Hardware_Panel
%   G4/G4.1: Historical measurements from arena layout scripts
%   G3: Legacy panel specifications
%
% See also: load_arena_config, load_rig_config, design_arena

% Normalize generation name: remove dots, uppercase
gen_key = upper(strrep(generation, '.', ''));

switch gen_key
    case 'G3'
        % G3 - Legacy 32mm panels with 8x8 LEDs
        specs.pixels_per_panel = 8;
        specs.panel_width_mm = 32;
        specs.panel_depth_mm = 18;          % ~0.7 inches
        specs.num_pins = 8;
        specs.pin_dist_mm = 15.24;          % ~0.6 inches
        specs.pin_spacing_mm = 2.54;
        specs.pin_config = 'single';
        specs.header_separation_mm = 0;     % N/A for single header
        specs.pins_to_plot = [];
        specs.generation = 'G3';
        specs.led_type = '8x8 LED matrix';

    case 'G4'
        % G4 - Original 40.45mm panels with 16x16 LEDs
        specs.pixels_per_panel = 16;
        specs.panel_width_mm = 40.45;
        specs.panel_depth_mm = 18;          % ~0.7 inches
        specs.num_pins = 15;
        specs.pin_dist_mm = 13;             % ~0.51 inches
        specs.pin_spacing_mm = 2.54;
        specs.pin_config = 'single';
        specs.header_separation_mm = 0;
        specs.pins_to_plot = [];
        specs.generation = 'G4';
        specs.led_type = '16x16 LED matrix';

    case 'G41'
        % G4.1 - Thinner 40mm panels with 16x16 LEDs
        specs.pixels_per_panel = 16;
        specs.panel_width_mm = 40;
        specs.panel_depth_mm = 6.35;        % ~0.25 inches (thinner)
        specs.num_pins = 15;
        specs.pin_dist_mm = 4.57;           % ~0.18 inches
        specs.pin_spacing_mm = 2.54;
        specs.pin_config = 'single';
        specs.header_separation_mm = 0;
        specs.pins_to_plot = [];
        specs.generation = 'G4.1';
        specs.led_type = '16x16 LED matrix (thin)';

    case 'G6'
        % G6 - 45.4mm panels with 20x20 LEDs, dual 5-pin headers
        % Dimensions from KiCad: board outline (49.8,49.8) to (95.2,95.2) = 45.4mm
        % Headers: J2/J3 at y=90.135 (bottom), J4/J5 at y=53.9 (top)
        %          J2/J4 at x=87.9 (right), J3/J5 at x=57.1 (left)
        % Header separation: 30.8mm between left/right headers
        specs.pixels_per_panel = 20;
        specs.panel_width_mm = 45.4;
        specs.panel_depth_mm = 3.45;        % Estimated from design files
        specs.num_pins = 10;                % 2 x 5-pin headers
        specs.pin_dist_mm = 4.57;           % ~0.18 inches
        specs.pin_spacing_mm = 2.54;
        specs.pin_config = 'dual';
        specs.header_separation_mm = 30.8;  % Distance between the two headers
        specs.pins_to_plot = 1:5;           % Plot 5 pins per header (mirrored)
        specs.generation = 'G6';
        specs.led_type = '20x20 LED matrix';

    case 'G5'
        error('G5 panels are deprecated and no longer supported. Use G6 for 20x20 pixel panels.');

    otherwise
        error('Unknown generation: %s. Valid generations: G3, G4, G4.1, G6', generation);
end

end

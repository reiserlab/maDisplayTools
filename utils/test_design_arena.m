%% Test design_arena.m
% This script validates design_arena.m by generating classical arena configurations.
% Run individual sections to compare against historical PDF files.
%
% Author: Reiser Lab

%% Setup
close all;
clear;

% Add utils to path if needed
if ~exist('design_arena', 'file')
    addpath(fileparts(mfilename('fullpath')));
end

% Output folder for PDFs (docs/arena-designs)
pdf_folder = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'docs', 'arena-designs');
if ~exist(pdf_folder, 'dir')
    mkdir(pdf_folder);
end

%% ========================================================================
%  G3 CONFIGURATIONS (32mm panels, 8x8 pixels)
%  ========================================================================

%% G3: 12/12 Full Ring
design_arena('G3', 12, 'save_pdf', true, 'pdf_filename', fullfile(pdf_folder, 'G3_12_of_12_panel_arena.pdf'));

%% G3: 24/24 Full Ring
design_arena('G3', 24, 'save_pdf', true, 'pdf_filename', fullfile(pdf_folder, 'G3_24_of_24_panel_arena.pdf'));

%% ========================================================================
%  G4 CONFIGURATIONS (40.45mm panels, 16x16 pixels)
%  ========================================================================

%% G4: 12/12 Standard Ring
design_arena('G4', 12, 'save_pdf', true, 'pdf_filename', fullfile(pdf_folder, 'G4_12_of_12_panel_arena.pdf'));

%% G4: 18/18 Full Ring
design_arena('G4', 18, 'save_pdf', true, 'pdf_filename', fullfile(pdf_folder, 'G4_18_of_18_panel_arena.pdf'));

%% ========================================================================
%  G4.1 CONFIGURATIONS (40mm panels, 16x16 pixels, thinner)
%  ========================================================================

%% G4.1: 12/12 Full Ring
design_arena('G4.1', 12, 'save_pdf', true, 'pdf_filename', fullfile(pdf_folder, 'G41_12_of_12_panel_arena.pdf'));

%% G4.1: 12/18 Open Arena
design_arena('G4.1', 18, 'panels_installed', [1:11 18], 'save_pdf', true, 'pdf_filename', fullfile(pdf_folder, 'G41_12_of_18_panel_arena.pdf'));

%% ========================================================================
%  G5 CONFIGURATIONS (40mm panels, 20x20 pixels)
%  ========================================================================

%% G5: 8/8 Full Ring
design_arena('G5', 8, 'save_pdf', true, 'pdf_filename', fullfile(pdf_folder, 'G5_8_of_8_panel_arena.pdf'));

%% ========================================================================
%  G6 CONFIGURATIONS (45.4mm panels, 20x20 pixels)
%  ========================================================================

%% G6: 12/12 Full Ring
design_arena('G6', 12, 'save_pdf', true, 'pdf_filename', fullfile(pdf_folder, 'G6_12_of_12_panel_arena.pdf'));

%% G6: 8/10 with gap (planned arena)
design_arena('G6', 10, 'panels_installed', [1:7 10], 'save_pdf', true, 'pdf_filename', fullfile(pdf_folder, 'G6_8_of_10_panel_arena.pdf'));

%% G6: 12/18 Large with gap
design_arena('G6', 18, 'panels_installed', [1:11 18], 'save_pdf', true, 'pdf_filename', fullfile(pdf_folder, 'G6_12_of_18_panel_arena.pdf'));

%% ========================================================================
%  GENERATE ALL PDFs
%  ========================================================================

%% Generate All PDFs (runs all configs, saves PDFs, closes figures)
close all;

configs = {
    % Type, num_panels, panels_installed, angle_offset
    'G3', 12, 1:12, 0;
    'G3', 24, 1:24, 0;
    'G4', 12, 1:12, 0;
    'G4', 18, 1:18, 0;
    'G4.1', 12, 1:12, 0;
    'G4.1', 18, [1:11 18], 0;
    'G5', 8, 1:8, 0;
    'G6', 12, 1:12, 0;
    'G6', 10, [1:7 10], 0;
    'G6', 18, [1:11 18], 0;
};

fprintf('\nGenerating PDFs in: %s\n\n', pdf_folder);

for i = 1:size(configs, 1)
    ptype = configs{i, 1};
    npanels = configs{i, 2};
    installed = configs{i, 3};
    offset = configs{i, 4};

    % Generate filename
    ptype_clean = strrep(ptype, '.', '');
    pdf_name = sprintf('%s_%d_of_%d_panel_arena.pdf', ptype_clean, length(installed), npanels);
    pdf_path = fullfile(pdf_folder, pdf_name);

    % Generate arena and save
    [info, fig] = design_arena(ptype, npanels, ...
        'panels_installed', installed, ...
        'angle_offset', offset, ...
        'save_pdf', true, ...
        'pdf_filename', pdf_path);

    fprintf('%-8s %2d/%2d panels  r=%.2f in  %.2f deg/px\n', ...
        ptype, length(installed), npanels, info.c_radius, info.degs_per_pixel);

    close(fig);
end

fprintf('\nDone! PDFs saved to: %s\n', pdf_folder);

%% ========================================================================
%  SUMMARY TABLE (text only)
%  ========================================================================

%% Print Summary Table
fprintf('\n========== ARENA SUMMARY TABLE ==========\n');
fprintf('%-8s %-8s %-10s %-10s %-10s\n', 'Type', 'Panels', 'Radius(in)', 'Radius(mm)', 'Deg/Pixel');
fprintf('%s\n', repmat('-', 1, 50));

summary_configs = {
    'G3', 12;
    'G3', 24;
    'G4', 12;
    'G4', 18;
    'G4.1', 12;
    'G4.1', 18;
    'G5', 8;
    'G6', 10;
    'G6', 12;
    'G6', 18;
};

for i = 1:size(summary_configs, 1)
    ptype = summary_configs{i, 1};
    npanels = summary_configs{i, 2};
    [info, fig] = design_arena(ptype, npanels, 'figure_visible', 'off');
    close(fig);
    fprintf('%-8s %-8d %-10.3f %-10.2f %-10.2f\n', ...
        ptype, npanels, info.c_radius, info.c_radius*25.4, info.degs_per_pixel);
end

fprintf('\n');

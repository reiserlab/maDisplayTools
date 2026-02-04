function generate_spherical_reference()
% GENERATE_SPHERICAL_REFERENCE Generate reference data for JavaScript validation
%
% This script generates pattern data using MATLAB's spherical coordinate
% system and exports it as JSON for comparison with JavaScript implementation.
%
% Output: webDisplayTools/data/spherical_pattern_reference.json
%
% Usage:
%   cd('/Users/reiserm/Documents/GitHub/maDisplayTools');
%   addpath(genpath('.'));
%   generate_spherical_reference();

    fprintf('=== Generating Spherical Pattern Reference Data ===\n\n');

    % Output path
    outputPath = '/Users/reiserm/Documents/GitHub/webDisplayTools/data/spherical_pattern_reference.json';

    % Ensure output directory exists
    outputDir = fileparts(outputPath);
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    % Create temporary arena coordinate file
    arenaFile = fullfile(tempdir, 'arena_G6_2x10_test.mat');
    fprintf('Creating arena coordinates: %s\n', arenaFile);

    % Arena parameters for G6 2x10
    Psize = 20;     % pixels per panel side
    Pcols = 10;     % panel columns
    Prows = 2;      % panel rows
    Pcircle = 10;   % panels for full 360°
    rot180 = 0;     % not flipped
    model = 'smooth';
    rotations = [0 0 0];
    translations = [0 0 0];

    % Generate arena coordinates (this saves to file)
    arena_coordinates(Psize, Pcols, Prows, Pcircle, rot180, model, rotations, translations, arenaFile);

    % Load the generated coordinates
    arenaData = load(arenaFile);
    arena_x = arenaData.arena_x;
    arena_y = arenaData.arena_y;
    arena_z = arenaData.arena_z;
    p_rad = arenaData.p_rad;

    fprintf('Arena dimensions: %d rows x %d cols\n', size(arena_x, 1), size(arena_x, 2));
    fprintf('p_rad: %.6f radians\n\n', p_rad);

    % Test cases to generate
    testCases = {};

    %% Test Case 1: Basic rotation grating
    fprintf('Generating: rotation_basic...\n');
    tc = struct();
    tc.name = 'rotation_basic';
    tc.description = 'Basic rotation grating with pole at north';
    tc.generation = 'G6';
    tc.rows = 2;
    tc.cols = 10;
    tc.spatFreq = pi / 10;  % ~20 pixel wavelength
    tc.motionType = 'rotation';
    tc.waveform = 'square';
    tc.dutyCycle = 50;
    tc.high = 15;
    tc.low = 0;
    tc.poleCoord = [0, 0];
    tc.numFrames = 1;
    tc.aaSamples = 1;
    tc.arenaModel = 'smooth';
    tc.gsMode = 16;

    % Build param struct for make_grating_edge
    param = build_param_struct(tc, Psize, Pcols, Prows, p_rad);

    % Generate pattern
    [Pats, ~, ~] = make_grating_edge(param, arena_x, arena_y, arena_z, arenaFile);

    % Scale to grayscale range and extract first frame
    tc.referenceFrame = reshape(round(Pats(:,:,1)' * (tc.high - tc.low) + tc.low), 1, []);  % Row-major flatten
    tc.testFrame = 0;
    testCases{end+1} = tc;

    %% Test Case 2: Rotation grating with offset pole
    fprintf('Generating: rotation_offset_pole...\n');
    tc = struct();
    tc.name = 'rotation_offset_pole';
    tc.description = 'Rotation grating with pole offset by pi/4';
    tc.generation = 'G6';
    tc.rows = 2;
    tc.cols = 10;
    tc.spatFreq = pi / 10;
    tc.motionType = 'rotation';
    tc.waveform = 'square';
    tc.dutyCycle = 50;
    tc.high = 15;
    tc.low = 0;
    tc.poleCoord = [pi/4, 0];
    tc.numFrames = 1;
    tc.aaSamples = 1;
    tc.arenaModel = 'smooth';
    tc.gsMode = 16;

    param = build_param_struct(tc, Psize, Pcols, Prows, p_rad);
    [Pats, ~, ~] = make_grating_edge(param, arena_x, arena_y, arena_z, arenaFile);

    tc.referenceFrame = reshape(round(Pats(:,:,1)' * (tc.high - tc.low) + tc.low), 1, []);
    tc.testFrame = 0;
    testCases{end+1} = tc;

    %% Test Case 3: Sine wave rotation
    fprintf('Generating: rotation_sine...\n');
    tc = struct();
    tc.name = 'rotation_sine';
    tc.description = 'Sine wave rotation grating';
    tc.generation = 'G6';
    tc.rows = 2;
    tc.cols = 10;
    tc.spatFreq = pi / 10;
    tc.motionType = 'rotation';
    tc.waveform = 'sine';
    tc.high = 15;
    tc.low = 0;
    tc.poleCoord = [0, 0];
    tc.numFrames = 1;
    tc.aaSamples = 1;
    tc.arenaModel = 'smooth';
    tc.gsMode = 16;

    param = build_param_struct(tc, Psize, Pcols, Prows, p_rad);
    [Pats, ~, ~] = make_grating_edge(param, arena_x, arena_y, arena_z, arenaFile);

    tc.referenceFrame = reshape(round(Pats(:,:,1)' * (tc.high - tc.low) + tc.low), 1, []);
    tc.testFrame = 0;
    testCases{end+1} = tc;

    %% Test Case 4: Expansion pattern
    fprintf('Generating: expansion_basic...\n');
    tc = struct();
    tc.name = 'expansion_basic';
    tc.description = 'Basic expansion pattern (concentric rings)';
    tc.generation = 'G6';
    tc.rows = 2;
    tc.cols = 10;
    tc.spatFreq = pi / 4;
    tc.motionType = 'expansion';
    tc.waveform = 'square';
    tc.dutyCycle = 50;
    tc.high = 15;
    tc.low = 0;
    tc.poleCoord = [0, 0];
    tc.numFrames = 1;
    tc.aaSamples = 1;
    tc.arenaModel = 'smooth';
    tc.gsMode = 16;

    param = build_param_struct(tc, Psize, Pcols, Prows, p_rad);
    [Pats, ~, ~] = make_grating_edge(param, arena_x, arena_y, arena_z, arenaFile);

    tc.referenceFrame = reshape(round(Pats(:,:,1)' * (tc.high - tc.low) + tc.low), 1, []);
    tc.testFrame = 0;
    testCases{end+1} = tc;

    %% Test Case 5: Translation pattern
    fprintf('Generating: translation_basic...\n');
    tc = struct();
    tc.name = 'translation_basic';
    tc.description = 'Basic translation pattern (linear motion)';
    tc.generation = 'G6';
    tc.rows = 2;
    tc.cols = 10;
    tc.spatFreq = 0.5;
    tc.motionType = 'translation';
    tc.waveform = 'square';
    tc.dutyCycle = 50;
    tc.high = 15;
    tc.low = 0;
    tc.poleCoord = [0, 0];
    tc.numFrames = 1;
    tc.aaSamples = 1;
    tc.arenaModel = 'smooth';
    tc.gsMode = 16;

    param = build_param_struct(tc, Psize, Pcols, Prows, p_rad);
    [Pats, ~, ~] = make_grating_edge(param, arena_x, arena_y, arena_z, arenaFile);

    tc.referenceFrame = reshape(round(Pats(:,:,1)' * (tc.high - tc.low) + tc.low), 1, []);
    tc.testFrame = 0;
    testCases{end+1} = tc;

    %% Test Case 6: Different duty cycle
    fprintf('Generating: rotation_25pct_duty...\n');
    tc = struct();
    tc.name = 'rotation_25pct_duty';
    tc.description = 'Rotation grating with 25% duty cycle';
    tc.generation = 'G6';
    tc.rows = 2;
    tc.cols = 10;
    tc.spatFreq = pi / 10;
    tc.motionType = 'rotation';
    tc.waveform = 'square';
    tc.dutyCycle = 25;
    tc.high = 15;
    tc.low = 0;
    tc.poleCoord = [0, 0];
    tc.numFrames = 1;
    tc.aaSamples = 1;
    tc.arenaModel = 'smooth';
    tc.gsMode = 16;

    param = build_param_struct(tc, Psize, Pcols, Prows, p_rad);
    [Pats, ~, ~] = make_grating_edge(param, arena_x, arena_y, arena_z, arenaFile);

    tc.referenceFrame = reshape(round(Pats(:,:,1)' * (tc.high - tc.low) + tc.low), 1, []);
    tc.testFrame = 0;
    testCases{end+1} = tc;

    %% Build output structure
    output = struct();
    output.generatedBy = 'MATLAB generate_spherical_reference.m';
    output.generatedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    output.matlabVersion = version();
    output.arenaParams = struct('Psize', Psize, 'Pcols', Pcols, 'Prows', Prows, ...
                                'Pcircle', Pcircle, 'model', model, 'p_rad', p_rad);
    output.testCases = testCases;

    %% Write JSON output
    fprintf('\nWriting output to: %s\n', outputPath);

    % Convert to JSON
    jsonStr = jsonencode(output, 'PrettyPrint', true);

    % Write file
    fid = fopen(outputPath, 'w');
    if fid == -1
        error('Could not open output file for writing');
    end
    fprintf(fid, '%s', jsonStr);
    fclose(fid);

    % Clean up temp file
    delete(arenaFile);

    fprintf('\n=== Done! Generated %d test cases ===\n', length(testCases));
end


function param = build_param_struct(tc, Psize, Pcols, Prows, p_rad)
% BUILD_PARAM_STRUCT Build the param struct expected by make_grating_edge

    param = struct();
    param.rows = Prows * Psize;
    param.cols = Pcols * Psize;
    param.p_rad = p_rad;

    % Motion type mapping
    if strcmpi(tc.motionType, 'rotation')
        param.motion_type = 'rotation';
    elseif strcmpi(tc.motionType, 'expansion')
        param.motion_type = 'expansion-contraction';
    else
        param.motion_type = 'translation';
    end

    % Pattern type (square vs sine)
    if strcmpi(tc.waveform, 'sine')
        param.pattern_type = 'sine';
    else
        param.pattern_type = 'square';
    end

    param.spat_freq = tc.spatFreq;
    if isfield(tc, 'dutyCycle')
        param.duty_cycle = tc.dutyCycle;
    else
        param.duty_cycle = 50;  % Default for sine waves (not used but required)
    end
    param.pole_coord = tc.poleCoord;
    param.step_size = tc.spatFreq;  % One full wavelength per step (single frame)
    param.aa_samples = tc.aaSamples;
    param.aa_poles = 0;  % Disable pole AA for simpler comparison
    param.phase_shift = 0;
    param.pattern_fov = 'full-field';
    param.arena_pitch = 0;
    param.sa_mask = [0, 0];
    param.motion_angle = 0;
    param.levels = [1, 0, 0];  % Pattern output is 0-1, we scale later
end

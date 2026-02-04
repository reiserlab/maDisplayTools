function generate_comprehensive_reference()
% GENERATE_COMPREHENSIVE_REFERENCE Generate comprehensive reference data for JavaScript validation
%
% This script generates pattern data for multiple arena configurations and pattern types
% using MATLAB's pattern generation functions and exports it as JSON for comparison
% with JavaScript implementation.
%
% Output: webDisplayTools/data/comprehensive_pattern_reference.json
%
% Usage:
%   cd('/Users/reiserm/Documents/GitHub/maDisplayTools');
%   addpath(genpath('.'));
%   generate_comprehensive_reference();

    fprintf('=== Generating Comprehensive Pattern Reference Data ===\n\n');

    % Output path
    outputPath = '/Users/reiserm/Documents/GitHub/webDisplayTools/data/comprehensive_pattern_reference.json';

    % Ensure output directory exists
    outputDir = fileparts(outputPath);
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    % Arena configurations to test
    arenaConfigs = {
        struct('name', 'G6_2x10', 'generation', 'G6', 'rows', 2, 'cols', 10, 'Psize', 20)
        struct('name', 'G6_2x8of10', 'generation', 'G6', 'rows', 2, 'cols', 8, 'Psize', 20, 'Pcircle', 10)
        struct('name', 'G4_4x12', 'generation', 'G4', 'rows', 4, 'cols', 12, 'Psize', 16)
        struct('name', 'G4_3x12of18', 'generation', 'G4', 'rows', 3, 'cols', 12, 'Psize', 16, 'Pcircle', 18)
    };

    testCases = {};

    %% Generate test cases for each arena
    for a = 1:length(arenaConfigs)
        arena = arenaConfigs{a};
        fprintf('\n=== Arena: %s ===\n', arena.name);

        % Set up arena parameters
        Psize = arena.Psize;
        Pcols = arena.cols;
        Prows = arena.rows;
        if isfield(arena, 'Pcircle')
            Pcircle = arena.Pcircle;
        else
            Pcircle = Pcols;  % Full circle
        end
        rot180 = 0;
        model = 'smooth';
        rotations = [0 0 0];
        translations = [0 0 0];

        % Create temporary arena coordinate file
        arenaFile = fullfile(tempdir, sprintf('arena_%s_test.mat', arena.name));
        fprintf('Creating arena coordinates: %s\n', arenaFile);

        % Generate arena coordinates
        arena_coordinates(Psize, Pcols, Prows, Pcircle, rot180, model, rotations, translations, arenaFile);

        % Load the generated coordinates
        arenaData = load(arenaFile);
        arena_x = arenaData.arena_x;
        arena_y = arenaData.arena_y;
        arena_z = arenaData.arena_z;
        p_rad = arenaData.p_rad;

        fprintf('Arena dimensions: %d rows x %d cols, p_rad: %.6f\n', ...
            size(arena_x, 1), size(arena_x, 2), p_rad);

        %% 1. Square Grating - Rotation
        fprintf('  Generating: %s_grating_rotation...\n', arena.name);
        tc = createTestCase(arena, 'grating_rotation', ...
            'Square grating with rotation motion, pole at north');
        tc.motionType = 'rotation';
        tc.waveform = 'square';
        tc.spatFreq = pi / 10;  % ~20 pixel wavelength
        tc.dutyCycle = 50;
        tc.poleCoord = [0, 0];
        tc = generatePattern(tc, Psize, Pcols, Prows, p_rad, arena_x, arena_y, arena_z, arenaFile);
        testCases{end+1} = tc;

        %% 2. Square Grating - Expansion
        fprintf('  Generating: %s_grating_expansion...\n', arena.name);
        tc = createTestCase(arena, 'grating_expansion', ...
            'Square grating with expansion motion');
        tc.motionType = 'expansion';
        tc.waveform = 'square';
        tc.spatFreq = pi / 4;
        tc.dutyCycle = 50;
        tc.poleCoord = [0, 0];
        tc = generatePattern(tc, Psize, Pcols, Prows, p_rad, arena_x, arena_y, arena_z, arenaFile);
        testCases{end+1} = tc;

        %% 3. Square Grating - Translation
        fprintf('  Generating: %s_grating_translation...\n', arena.name);
        tc = createTestCase(arena, 'grating_translation', ...
            'Square grating with translation motion');
        tc.motionType = 'translation';
        tc.waveform = 'square';
        tc.spatFreq = 0.5;
        tc.dutyCycle = 50;
        tc.poleCoord = [0, 0];
        tc = generatePattern(tc, Psize, Pcols, Prows, p_rad, arena_x, arena_y, arena_z, arenaFile);
        testCases{end+1} = tc;

        %% 4. Sine Grating - Rotation
        fprintf('  Generating: %s_sine_rotation...\n', arena.name);
        tc = createTestCase(arena, 'sine_rotation', ...
            'Sine grating with rotation motion');
        tc.motionType = 'rotation';
        tc.waveform = 'sine';
        tc.spatFreq = pi / 10;
        tc.poleCoord = [0, 0];
        tc = generatePattern(tc, Psize, Pcols, Prows, p_rad, arena_x, arena_y, arena_z, arenaFile);
        testCases{end+1} = tc;

        %% 5. Square Grating with offset pole
        fprintf('  Generating: %s_grating_offset_pole...\n', arena.name);
        tc = createTestCase(arena, 'grating_offset_pole', ...
            'Square grating with pole offset by pi/4');
        tc.motionType = 'rotation';
        tc.waveform = 'square';
        tc.spatFreq = pi / 10;
        tc.dutyCycle = 50;
        tc.poleCoord = [pi/4, 0];
        tc = generatePattern(tc, Psize, Pcols, Prows, p_rad, arena_x, arena_y, arena_z, arenaFile);
        testCases{end+1} = tc;

        %% 6. Different duty cycle
        fprintf('  Generating: %s_grating_25pct_duty...\n', arena.name);
        tc = createTestCase(arena, 'grating_25pct_duty', ...
            'Square grating with 25% duty cycle');
        tc.motionType = 'rotation';
        tc.waveform = 'square';
        tc.spatFreq = pi / 10;
        tc.dutyCycle = 25;
        tc.poleCoord = [0, 0];
        tc = generatePattern(tc, Psize, Pcols, Prows, p_rad, arena_x, arena_y, arena_z, arenaFile);
        testCases{end+1} = tc;

        %% 7. Off/On pattern
        fprintf('  Generating: %s_offon...\n', arena.name);
        tc = createTestCase(arena, 'offon', 'Off/On brightness ramp');
        tc.patternType = 'offon';
        tc.high = 15;
        tc.low = 0;

        % Off/On generates |high-low|+1 frames
        numFrames = abs(tc.high - tc.low) + 1;
        pixelRows = Prows * Psize;
        pixelCols = Pcols * Psize;

        % Generate frame 0 (all low)
        tc.referenceFrame = zeros(1, pixelRows * pixelCols);
        tc.numFrames = numFrames;
        testCases{end+1} = tc;

        %% 8. Edge pattern (duty cycle sweep)
        fprintf('  Generating: %s_edge...\n', arena.name);
        tc = createTestCase(arena, 'edge', 'Edge pattern with duty cycle sweep');
        tc.patternType = 'edge';
        tc.motionType = 'rotation';
        tc.spatFreq = 2*pi;  % Full wavelength
        tc.poleCoord = [0, 0];
        tc = generateEdgePattern(tc, Psize, Pcols, Prows, p_rad, arena_x, arena_y, arena_z, arenaFile);
        testCases{end+1} = tc;

        % Clean up temp arena file
        delete(arenaFile);
    end

    %% Build output structure
    output = struct();
    output.generatedBy = 'MATLAB generate_comprehensive_reference.m';
    output.generatedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    output.matlabVersion = version();
    output.testCases = testCases;

    %% Write JSON output
    fprintf('\n\nWriting output to: %s\n', outputPath);

    % Convert to JSON
    jsonStr = jsonencode(output, 'PrettyPrint', true);

    % Write file
    fid = fopen(outputPath, 'w');
    if fid == -1
        error('Could not open output file for writing');
    end
    fprintf(fid, '%s', jsonStr);
    fclose(fid);

    fprintf('\n=== Done! Generated %d test cases ===\n', length(testCases));
end


function tc = createTestCase(arena, name, description)
% Create a test case structure with common fields
    tc = struct();
    tc.name = sprintf('%s_%s', arena.name, name);
    tc.description = description;
    tc.arenaConfig = arena.name;
    tc.generation = arena.generation;
    tc.rows = arena.rows;
    tc.cols = arena.cols;
    tc.Psize = arena.Psize;
    if isfield(arena, 'Pcircle')
        tc.Pcircle = arena.Pcircle;
    else
        tc.Pcircle = arena.cols;
    end
    tc.high = 15;
    tc.low = 0;
    tc.gsMode = 16;
    tc.aaSamples = 1;
    tc.arenaModel = 'smooth';
    tc.testFrame = 0;
end


function tc = generatePattern(tc, Psize, Pcols, Prows, p_rad, arena_x, arena_y, arena_z, arenaFile)
% Generate a grating pattern and add reference frame to test case

    % Build param struct for make_grating_edge
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
        param.duty_cycle = 50;
    end
    param.pole_coord = tc.poleCoord;
    param.step_size = tc.spatFreq;  % Single frame
    param.aa_samples = tc.aaSamples;
    param.aa_poles = 0;
    param.phase_shift = 0;
    param.pattern_fov = 'full-field';
    param.arena_pitch = 0;
    param.sa_mask = [0, 0];
    param.motion_angle = 0;
    param.levels = [1, 0, 0];

    % Generate pattern
    [Pats, num_frames, ~] = make_grating_edge(param, arena_x, arena_y, arena_z, arenaFile);

    % Scale to grayscale range and extract first frame
    tc.referenceFrame = reshape(round(Pats(:,:,1)' * (tc.high - tc.low) + tc.low), 1, []);
    tc.numFrames = num_frames;
end


function tc = generateEdgePattern(tc, Psize, Pcols, Prows, p_rad, arena_x, arena_y, arena_z, arenaFile)
% Generate an edge pattern (duty cycle sweep) and add reference frame

    % Build param struct for make_grating_edge
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

    param.pattern_type = 'edge';  % This triggers duty cycle sweep
    param.spat_freq = tc.spatFreq;
    param.duty_cycle = 50;  % Not used for edge
    param.pole_coord = tc.poleCoord;
    param.step_size = tc.spatFreq;
    param.aa_samples = tc.aaSamples;
    param.aa_poles = 0;
    param.phase_shift = 0;
    param.pattern_fov = 'full-field';
    param.arena_pitch = 0;
    param.sa_mask = [0, 0];
    param.motion_angle = 0;
    param.levels = [1, 0, 0];

    % Generate pattern
    [Pats, num_frames, ~] = make_grating_edge(param, arena_x, arena_y, arena_z, arenaFile);

    % Extract frame 0 (duty cycle = 0%)
    tc.referenceFrame = reshape(round(Pats(:,:,1)' * (tc.high - tc.low) + tc.low), 1, []);
    tc.numFrames = num_frames;
end

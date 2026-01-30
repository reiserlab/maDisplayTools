classdef PatternGeneratorApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                   matlab.ui.Figure
        MainGrid                   matlab.ui.container.GridLayout
        LeftPanel                  matlab.ui.container.Panel
        RightPanel                 matlab.ui.container.Panel

        % Left panel - Arena Section
        InfoButton                 matlab.ui.control.Button
        ArenaConfigLabel           matlab.ui.control.Label
        ArenaConfigDropDown        matlab.ui.control.DropDown
        ChangeArenaButton          matlab.ui.control.Button
        GenerationLabel            matlab.ui.control.Label
        GenerationText             matlab.ui.control.Label
        ArenaInfoLabel             matlab.ui.control.Label
        ArenaInfoText              matlab.ui.control.Label

        % Left panel - Pattern Section
        PatternTypeLabel           matlab.ui.control.Label
        PatternTypeDropDown        matlab.ui.control.DropDown
        MotionTypeLabel            matlab.ui.control.Label
        MotionTypeDropDown         matlab.ui.control.DropDown
        PatternFOVLabel            matlab.ui.control.Label
        PatternFOVDropDown         matlab.ui.control.DropDown

        SpatialFreqLabel           matlab.ui.control.Label
        SpatialFreqSpinner         matlab.ui.control.Spinner
        StepSizeLabel              matlab.ui.control.Label
        StepSizeSpinner            matlab.ui.control.Spinner
        StepSizeInfoText           matlab.ui.control.Label
        StretchLabel               matlab.ui.control.Label
        StretchSpinner             matlab.ui.control.Spinner
        DutyCycleLabel             matlab.ui.control.Label
        DutyCycleSpinner           matlab.ui.control.Spinner

        % Left panel - Brightness Section
        GrayscaleLabel             matlab.ui.control.Label
        GrayscaleDropDown          matlab.ui.control.DropDown
        BrightnessHighLabel        matlab.ui.control.Label
        BrightnessHighSpinner      matlab.ui.control.Spinner
        BrightnessLowLabel         matlab.ui.control.Label
        BrightnessLowSpinner       matlab.ui.control.Spinner

        % Left panel - Advanced Controls
        MotionAngleLabel           matlab.ui.control.Label
        MotionAngleSpinner         matlab.ui.control.Spinner
        PoleAzimuthLabel           matlab.ui.control.Label
        PoleAzimuthSpinner         matlab.ui.control.Spinner
        PoleElevationLabel         matlab.ui.control.Label
        PoleElevationSpinner       matlab.ui.control.Spinner
        ArenaPitchLabel            matlab.ui.control.Label
        ArenaPitchSpinner          matlab.ui.control.Spinner

        % Bottom buttons (full width, outside panels)
        ButtonGrid                 matlab.ui.container.GridLayout
        GeneratePreviewButton      matlab.ui.control.Button
        SaveButton                 matlab.ui.control.Button
        ExportScriptButton         matlab.ui.control.Button
        StatusLabel                matlab.ui.control.Label

        % Right panel - Options (Starfield, Mask Config)
        StarfieldOptionsPanel      matlab.ui.container.Panel
        DotCountLabel              matlab.ui.control.Label
        DotCountSpinner            matlab.ui.control.Spinner
        DotRadiusLabel             matlab.ui.control.Label
        DotRadiusSpinner           matlab.ui.control.Spinner
        DotSizeLabel               matlab.ui.control.Label
        DotSizeDropDown            matlab.ui.control.DropDown
        DotOcclusionLabel          matlab.ui.control.Label
        DotOcclusionDropDown       matlab.ui.control.DropDown
        DotLevelLabel              matlab.ui.control.Label
        DotLevelDropDown           matlab.ui.control.DropDown
        DotReRandomCheckBox        matlab.ui.control.CheckBox

        % Right panel - Solid Angle Mask Config
        SAMaskPanel                matlab.ui.container.Panel
        SAMaskCheckBox             matlab.ui.control.CheckBox
        SAAzimuthLabel             matlab.ui.control.Label
        SAAzimuthSpinner           matlab.ui.control.Spinner
        SAElevationLabel           matlab.ui.control.Label
        SAElevationSpinner         matlab.ui.control.Spinner
        SARadiusLabel              matlab.ui.control.Label
        SARadiusSpinner            matlab.ui.control.Spinner
        SABackgroundLabel          matlab.ui.control.Label
        SABackgroundSpinner        matlab.ui.control.Spinner
        SAInvertCheckBox           matlab.ui.control.CheckBox

        % Right panel - Lat/Long Mask Config
        LatLongMaskPanel           matlab.ui.container.Panel
        LatLongMaskCheckBox        matlab.ui.control.CheckBox
        LonMinLabel                matlab.ui.control.Label
        LonMinSpinner              matlab.ui.control.Spinner
        LonMaxLabel                matlab.ui.control.Label
        LonMaxSpinner              matlab.ui.control.Spinner
        LatMinLabel                matlab.ui.control.Label
        LatMinSpinner              matlab.ui.control.Spinner
        LatMaxLabel                matlab.ui.control.Label
        LatMaxSpinner              matlab.ui.control.Spinner
        LatLongInvertCheckBox      matlab.ui.control.CheckBox
    end

    properties (Access = private)
        maDisplayToolsRoot         % Root path of maDisplayTools
        ArenaConfigs               % Cell array of arena config paths
        CurrentArenaConfig         % Currently loaded arena config
        DegPerPixelH               % Horizontal degrees per pixel at equator
        PixelsH                    % Total horizontal pixels
        PixelsV                    % Total vertical pixels

        % Mask parameters (stored separately for dialog access)
        SAMaskParams               % [azimuth, elevation, radius, invert] in radians
        LatLongMaskParams          % [long_min, long_max, lat_min, lat_max, invert] in radians
        MaskBackgroundLevel = 0    % Brightness level for masked areas (0-15 for 4-bit)

        % Arena lock state
        ArenaLocked = true         % Whether arena config is locked
        PatternGenerated = false   % Whether a pattern has been generated

        % Generated pattern (transient, for Save)
        Pats                       % Pattern data (rows x cols x frames)
        NumFrames                  % Number of frames

        % Previewer reference
        PreviewerApp               % Handle to PatternPreviewerApp instance
    end

    methods (Access = private)

        function setStatus(app, status)
            % Set status message in StatusLabel at bottom
            if isempty(status)
                app.StatusLabel.Text = 'Ready';
            else
                app.StatusLabel.Text = status;
            end
        end

        function bringAllPatternAppsToFront(app)
            % Find all pattern app figures and bring to front
            % This ensures all pattern apps stay visible after operations
            allFigs = findall(0, 'Type', 'figure');
            patternAppNames = {'Pattern Previewer', 'Pattern Generator', 'Pattern Combiner'};

            for i = 1:length(allFigs)
                if ismember(allFigs(i).Name, patternAppNames)
                    figure(allFigs(i));
                end
            end
            % Bring current app to front last (gives it focus)
            figure(app.UIFigure);
        end

        function scanArenaConfigs(app)
            % Scan for available arena YAML configs
            configDir = fullfile(app.maDisplayToolsRoot, 'configs', 'arenas');

            if ~isfolder(configDir)
                app.ArenaConfigs = {};
                app.ArenaConfigDropDown.Items = {'No configs found'};
                return;
            end

            % Find all YAML files
            yamlFiles = [dir(fullfile(configDir, '*.yaml')); dir(fullfile(configDir, '*.yml'))];

            if isempty(yamlFiles)
                app.ArenaConfigs = {};
                app.ArenaConfigDropDown.Items = {'No configs found'};
                return;
            end

            app.ArenaConfigs = cell(length(yamlFiles), 1);
            items = cell(length(yamlFiles), 1);
            defaultIdx = 1;

            for i = 1:length(yamlFiles)
                app.ArenaConfigs{i} = fullfile(configDir, yamlFiles(i).name);
                [~, name, ~] = fileparts(yamlFiles(i).name);
                items{i} = name;

                % Set G41_2x12_ccw as default if found
                if strcmpi(name, 'G41_2x12_ccw')
                    defaultIdx = i;
                end
            end

            app.ArenaConfigDropDown.Items = items;
            if ~isempty(items)
                app.ArenaConfigDropDown.Value = items{defaultIdx};
            end
        end

        function loadArenaConfig(app)
            % Load the selected arena configuration
            idx = find(strcmp(app.ArenaConfigDropDown.Items, app.ArenaConfigDropDown.Value));

            if isempty(idx) || idx > length(app.ArenaConfigs)
                app.GenerationText.Text = 'N/A';
                return;
            end

            configPath = app.ArenaConfigs{idx};

            try
                app.CurrentArenaConfig = load_arena_config(configPath);
                app.GenerationText.Text = app.CurrentArenaConfig.arena.generation;

                % Generate arena_parameters.mat from YAML config
                app.generateArenaMatFile();

                % Compute and display arena geometry info
                app.updateArenaInfo();

                % Update step size info display
                app.updateStepSizeInfo();

                % Update stretch limits based on generation
                app.updateStretchLimits();

                app.setStatus(sprintf('Loaded: %s', app.ArenaConfigDropDown.Value));
            catch ME
                app.setStatus(sprintf('Error: %s', ME.message));
                app.GenerationText.Text = 'Error';
            end
        end

        function generateArenaMatFile(app)
            % Generate arena_parameters.mat from current YAML config
            if isempty(app.CurrentArenaConfig)
                return;
            end

            cfg = app.CurrentArenaConfig;

            % Get panel specs from generation
            specs = get_generation_specs(cfg.arena.generation);
            Psize = specs.pixels_per_panel;

            % Get arena dimensions
            Prows = cfg.arena.num_rows;
            Pcircle = cfg.arena.num_cols;  % Full circle is always num_cols

            % Pcols = number of installed panel columns
            if ~isempty(cfg.arena.columns_installed)
                Pcols = length(cfg.arena.columns_installed);
            else
                Pcols = cfg.arena.num_cols;  % All columns installed
            end

            % Orientation
            rot180 = strcmp(cfg.arena.orientation, 'upside_down');

            % Default model and transforms
            model = 'poly';
            rotations = [0 0 0];
            translations = [0 0 0];

            if isfield(cfg.arena, 'cylinder_model')
                model = cfg.arena.cylinder_model;
            end
            if isfield(cfg.arena, 'rotations_deg')
                rotations = deg2rad(cfg.arena.rotations_deg);
            end
            if isfield(cfg.arena, 'translations')
                translations = cfg.arena.translations;
            end

            % Generate arena coordinates using arena_coordinates function
            arena_folder = fullfile(app.maDisplayToolsRoot, 'configs', 'arenas');
            arena_file = fullfile(arena_folder, 'arena_parameters.mat');
            arena_coordinates(Psize, Pcols, Prows, Pcircle, rot180, model, rotations, translations, arena_file);
        end

        function updateArenaInfo(app)
            % Compute and display arena geometry information
            if isempty(app.CurrentArenaConfig)
                app.ArenaInfoText.Text = 'N/A';
                return;
            end

            cfg = app.CurrentArenaConfig;
            specs = get_generation_specs(cfg.arena.generation);

            numRows = cfg.arena.num_rows;
            numCols = cfg.arena.num_cols;

            % Get installed columns count
            if ~isempty(cfg.arena.columns_installed)
                numColsInstalled = length(cfg.arena.columns_installed);
            else
                numColsInstalled = numCols;
            end

            totalPanels = numRows * numColsInstalled;

            % Compute total pixels
            pixelsV = numRows * specs.pixels_per_panel;
            pixelsH = numColsInstalled * specs.pixels_per_panel;

            % Store for later use
            app.PixelsH = pixelsH;
            app.PixelsV = pixelsV;

            % Calculate degrees per pixel (horizontal) at equator
            azimuthCoverage = 360 * numColsInstalled / numCols;
            app.DegPerPixelH = azimuthCoverage / pixelsH;

            % Build info string
            if numColsInstalled < numCols
                % Partial arena - show installed/total
                infoStr = sprintf('%d panels (%dx%dof%d), %dx%d px, %.3f deg/px', ...
                    totalPanels, numRows, numColsInstalled, numCols, ...
                    pixelsV, pixelsH, app.DegPerPixelH);
            else
                % Full arena
                infoStr = sprintf('%d panels (%dx%d), %dx%d px, %.3f deg/px', ...
                    totalPanels, numRows, numCols, ...
                    pixelsV, pixelsH, app.DegPerPixelH);
            end
            app.ArenaInfoText.Text = infoStr;
        end

        function updateStepSizeInfo(app)
            % Display step size in pixel equivalents
            if app.DegPerPixelH > 0
                stepDeg = app.StepSizeSpinner.Value;
                stepPx = stepDeg / app.DegPerPixelH;
                app.StepSizeInfoText.Text = sprintf('= %.2f px', stepPx);

                % Update spinner step to be half a pixel
                app.StepSizeSpinner.Step = app.DegPerPixelH / 2;
            else
                app.StepSizeInfoText.Text = '';
            end
        end

        function updateStretchLimits(app)
            % Update stretch spinner limits based on generation
            if isempty(app.CurrentArenaConfig)
                return;
            end

            gen = app.CurrentArenaConfig.arena.generation;
            if startsWith(upper(gen), 'G6')
                % G6 stretch range (from protocol spec)
                app.StretchSpinner.Limits = [0 255];
            else
                % G4/G4.1 stretch range
                app.StretchSpinner.Limits = [0 100];
            end

            % Clamp current value if out of range
            if app.StretchSpinner.Value > app.StretchSpinner.Limits(2)
                app.StretchSpinner.Value = app.StretchSpinner.Limits(2);
            end
        end

        function updateParameterStates(app)
            % Enable/disable parameters based on pattern type and FOV
            patternType = app.PatternTypeDropDown.Value;
            patternFOV = app.PatternFOVDropDown.Value;
            isLocal = strcmp(patternFOV, 'Local (mask-centered)');

            % Default: enable most parameters
            spatEnabled = true;
            stepEnabled = true;
            dutyEnabled = true;
            motionEnabled = true;
            maskEnabled = true;

            switch patternType
                case 'Starfield'
                    spatEnabled = false;
                    dutyEnabled = false;
                    app.StarfieldOptionsPanel.Visible = 'on';
                case 'Off/On'
                    spatEnabled = false;
                    stepEnabled = false;
                    dutyEnabled = false;
                    motionEnabled = false;
                    maskEnabled = false;
                    app.StarfieldOptionsPanel.Visible = 'off';
                case 'Edge'
                    dutyEnabled = false;
                    app.StarfieldOptionsPanel.Visible = 'off';
                case 'Sine Grating'
                    dutyEnabled = false;
                    app.StarfieldOptionsPanel.Visible = 'off';
                case 'Reverse-Phi'
                    % Reverse-phi uses square grating as base, enable duty cycle
                    app.StarfieldOptionsPanel.Visible = 'off';
                otherwise
                    app.StarfieldOptionsPanel.Visible = 'off';
            end

            % Apply states
            app.SpatialFreqSpinner.Enable = spatEnabled;
            app.SpatialFreqLabel.Enable = spatEnabled;
            app.StepSizeSpinner.Enable = stepEnabled;
            app.StepSizeLabel.Enable = stepEnabled;
            app.DutyCycleSpinner.Enable = dutyEnabled;
            app.DutyCycleLabel.Enable = dutyEnabled;
            app.MotionTypeDropDown.Enable = motionEnabled;
            app.MotionTypeLabel.Enable = motionEnabled;

            % Mask controls (checkboxes in RHS panel)
            app.SAMaskCheckBox.Enable = maskEnabled;
            app.LatLongMaskCheckBox.Enable = maskEnabled;
            % If masks disabled, also disable their parameters
            if ~maskEnabled
                app.SAMaskCheckBox.Value = false;
                app.LatLongMaskCheckBox.Value = false;
                app.SAMaskCheckBoxChanged();
                app.LatLongMaskCheckBoxChanged();
            end

            % Motion angle vs Pole coordinates based on FOV
            if isLocal
                % Local mode: show motion angle, hide pole coords
                app.MotionAngleLabel.Visible = 'on';
                app.MotionAngleSpinner.Visible = 'on';
                app.PoleAzimuthLabel.Visible = 'off';
                app.PoleAzimuthSpinner.Visible = 'off';
                app.PoleElevationLabel.Visible = 'off';
                app.PoleElevationSpinner.Visible = 'off';
            else
                % Full-field mode: show pole coords, hide motion angle
                app.MotionAngleLabel.Visible = 'off';
                app.MotionAngleSpinner.Visible = 'off';
                app.PoleAzimuthLabel.Visible = 'on';
                app.PoleAzimuthSpinner.Visible = 'on';
                app.PoleElevationLabel.Visible = 'on';
                app.PoleElevationSpinner.Visible = 'on';
            end
        end

        function updateBrightnessLimits(app)
            % Update brightness limits based on grayscale mode
            if strcmp(app.GrayscaleDropDown.Value, 'Binary (1-bit)')
                maxVal = 1;
            else
                maxVal = 15;
            end

            app.BrightnessHighSpinner.Limits = [0 maxVal];
            app.BrightnessLowSpinner.Limits = [0 maxVal];

            % Clamp current values
            if app.BrightnessHighSpinner.Value > maxVal
                app.BrightnessHighSpinner.Value = maxVal;
            end
            if app.BrightnessLowSpinner.Value > maxVal
                app.BrightnessLowSpinner.Value = maxVal;
            end
        end

        function handles = buildHandlesStruct(app)
            % Build the handles struct expected by Pattern_Generator
            handles = struct();

            % Arena file path
            handles.arena_folder = fullfile(app.maDisplayToolsRoot, 'configs', 'arenas');
            handles.arena_file = 'arena_parameters.mat';

            % Build param struct
            param = struct();

            % Map dropdown values to Pattern_Generator expected values
            patternTypeMap = containers.Map(...
                {'Square Grating', 'Sine Grating', 'Edge', 'Starfield', 'Off/On', 'Reverse-Phi'}, ...
                {'square grating', 'sine grating', 'edge', 'starfield', 'off_on', 'reverse_phi'});
            motionTypeMap = containers.Map(...
                {'Rotation', 'Translation', 'Expansion-Contraction'}, ...
                {'rotation', 'translation', 'expansion-contraction'});
            patternFOVMap = containers.Map(...
                {'Full-field', 'Local (mask-centered)'}, ...
                {'full-field', 'local'});

            param.pattern_type = patternTypeMap(app.PatternTypeDropDown.Value);
            param.motion_type = motionTypeMap(app.MotionTypeDropDown.Value);
            param.pattern_fov = patternFOVMap(app.PatternFOVDropDown.Value);

            % Convert degrees to radians for angles
            param.spat_freq = deg2rad(app.SpatialFreqSpinner.Value);
            param.step_size = deg2rad(app.StepSizeSpinner.Value);

            % Grayscale value
            if strcmp(app.GrayscaleDropDown.Value, 'Binary (1-bit)')
                param.gs_val = 1;
            else
                param.gs_val = 4;
            end

            % Brightness levels [high, low, background]
            param.levels = [app.BrightnessHighSpinner.Value, ...
                           app.BrightnessLowSpinner.Value, ...
                           app.MaskBackgroundLevel];

            param.duty_cycle = app.DutyCycleSpinner.Value;

            % Advanced controls
            param.motion_angle = deg2rad(app.MotionAngleSpinner.Value);
            param.pole_coord = [deg2rad(app.PoleAzimuthSpinner.Value), ...
                               deg2rad(app.PoleElevationSpinner.Value)];
            param.arena_pitch = deg2rad(app.ArenaPitchSpinner.Value);

            % Mask parameters
            if app.SAMaskCheckBox.Value && ~isempty(app.SAMaskParams)
                param.sa_mask = app.SAMaskParams;
            else
                param.sa_mask = [0 0 pi 0];  % No mask
            end

            if app.LatLongMaskCheckBox.Value && ~isempty(app.LatLongMaskParams)
                param.long_lat_mask = app.LatLongMaskParams;
            else
                param.long_lat_mask = [-pi pi -pi/2 pi/2 0];  % No mask
            end

            % Starfield options
            param.num_dots = app.DotCountSpinner.Value;
            param.dot_radius = deg2rad(app.DotRadiusSpinner.Value);

            dotSizeMap = containers.Map(...
                {'Static', 'Distance-relative'}, ...
                {'static', 'distance'});
            param.dot_size = dotSizeMap(app.DotSizeDropDown.Value);

            dotOccMap = containers.Map(...
                {'Closest', 'Sum', 'Mean'}, ...
                {'closest', 'sum', 'mean'});
            param.dot_occ = dotOccMap(app.DotOcclusionDropDown.Value);

            dotLevelMap = containers.Map(...
                {'Fixed', 'Random spread', 'Random binary'}, ...
                {0, 1, 2});
            param.dot_level = dotLevelMap(app.DotLevelDropDown.Value);

            param.dot_re_random = double(app.DotReRandomCheckBox.Value);
            param.snap_dots = 0;

            % Fixed parameters
            param.aa_samples = 15;
            param.aa_poles = 1;
            param.back_frame = 0;
            param.flip_right = 0;
            param.phase_shift = 0;
            param.checker_layout = 0;

            % Generation from arena config
            if ~isempty(app.CurrentArenaConfig)
                param.generation = app.CurrentArenaConfig.arena.generation;
            else
                param.generation = 'G4';
            end

            handles.param = param;
        end

        function name = generatePatternName(app)
            % Generate a descriptive pattern name
            patType = lower(strrep(app.PatternTypeDropDown.Value, ' ', '_'));
            spatFreq = app.SpatialFreqSpinner.Value;
            stepSize = app.StepSizeSpinner.Value;

            if strcmp(app.PatternTypeDropDown.Value, 'Starfield')
                name = sprintf('%s_%ddots', patType, app.DotCountSpinner.Value);
            elseif strcmp(app.PatternTypeDropDown.Value, 'Off/On')
                name = 'off_on';
            elseif strcmp(app.PatternTypeDropDown.Value, 'Edge')
                name = sprintf('%s_%.0fstep', patType, stepSize);
            elseif strcmp(app.PatternTypeDropDown.Value, 'Reverse-Phi')
                name = sprintf('reverse_phi_%.0fdeg_%.0fstep', spatFreq, stepSize);
            else
                name = sprintf('%s_%.0fdeg_%.0fstep', patType, spatFreq, stepSize);
            end
        end

        function gs_val = getGrayscaleValue(app)
            % Get numeric grayscale value (2 or 16)
            if strcmp(app.GrayscaleDropDown.Value, 'Binary (1-bit)')
                gs_val = 2;
            else
                gs_val = 16;
            end
        end

        function previewer = findExistingPreviewer(~)
            % Find an existing PatternPreviewerApp window if one exists
            previewer = [];

            figs = findall(0, 'Type', 'figure');
            for i = 1:length(figs)
                if isprop(figs(i), 'Name') && strcmp(figs(i).Name, 'Pattern Previewer')
                    try
                        if isprop(figs(i), 'RunningAppInstance')
                            appInstance = figs(i).RunningAppInstance;
                            if isa(appInstance, 'PatternPreviewerApp') && isvalid(appInstance)
                                previewer = appInstance;
                                return;
                            end
                        end
                    catch
                        % Skip if we can't access the app instance
                    end
                end
            end
        end

        function positionPreviewerAdjacent(app)
            % Position Previewer window to the right of Generator
            % Only repositions if Previewer doesn't have a saved position
            if isempty(app.PreviewerApp) || ~isvalid(app.PreviewerApp)
                return;
            end

            % Check if Previewer already has a saved position - if so, don't override
            if ispref('maDisplayTools', 'PatternPreviewerPosition')
                return;  % User has positioned it themselves, respect that
            end

            % Get screen size
            screenSize = get(0, 'ScreenSize');
            screenWidth = screenSize(3);

            % Get Generator position
            genPos = app.UIFigure.Position;
            genRight = genPos(1) + genPos(3);

            % Calculate Previewer position (to the right of Generator)
            previewerWidth = 900;
            previewerHeight = 700;
            previewerLeft = genRight + 10;  % 10px gap

            % Check if it fits on screen
            if previewerLeft + previewerWidth > screenWidth
                % Doesn't fit - put on top instead
                previewerLeft = genPos(1);
            end

            previewerBottom = genPos(2);

            app.PreviewerApp.UIFigure.Position = [previewerLeft, previewerBottom, previewerWidth, previewerHeight];
        end

        function savePreferences(~)
            % Static method to clear all saved preferences (for debugging)
            if ispref('maDisplayTools')
                rmpref('maDisplayTools');
            end
        end

        function lockArena(app)
            % Lock arena config after pattern generation
            app.ArenaConfigDropDown.Enable = 'off';
            app.ChangeArenaButton.Text = 'Change';
            app.ArenaLocked = true;
        end

        function unlockArena(app)
            % Unlock arena config (clears pattern)
            app.ArenaConfigDropDown.Enable = 'on';
            app.ChangeArenaButton.Text = 'Lock';
            app.ArenaLocked = false;

            % Clear generated pattern
            app.Pats = [];
            app.NumFrames = 0;
            app.PatternGenerated = false;
        end

        function parameterChanged(app)
            % Called when any parameter changes - clear generated state
            if app.PatternGenerated
                app.PatternGenerated = false;
                app.Pats = [];
                app.setStatus('Parameters changed - regenerate');
            end
        end

        function showInfoDialog(app)
            % Show reference information in a non-modal dialog
            content = app.getInfoContent();
            fig = uifigure('Name', 'Pattern Generator Reference', ...
                'Position', [200 100 550 600], ...
                'WindowStyle', 'normal');

            ta = uitextarea(fig);
            ta.Position = [10 10 530 580];
            ta.Value = content;
            ta.FontName = 'Courier New';
            ta.FontSize = 11;
            ta.Editable = 'off';
        end

        function content = getInfoContent(~)
            % Return comprehensive info text
            content = {...
                '=== PATTERN GENERATOR REFERENCE ===';
                '';
                'COORDINATE SYSTEM:';
                '  Longitude: -180 to +180 deg (azimuth around arena)';
                '  Latitude:  -90 to +90 deg (elevation from equator)';
                '  Pole latitude -90 = pole points DOWN (default)';
                '';
                'PATTERN TYPES:';
                '  Square Grating - Sharp-edged bars';
                '  Sine Grating - Smooth sinusoidal bars';
                '  Edge - Single contrast edge';
                '  Starfield - Random dots';
                '  Off/On - All off, then all on';
                '';
                'MOTION TYPES:';
                '  Rotation - Pattern rotates around pole';
                '  Translation - Pattern moves in straight line';
                '  Expansion-Contraction - Radial motion';
                '';
                'PATTERN FOV:';
                '  Full-field: Pattern defined by pole coordinates';
                '  Local: Pattern centered on mask, motion angle controls direction';
                '';
                'MASKS:';
                '  Solid Angle: Circular mask by azimuth/elevation/radius';
                '  Lat/Long: Rectangular mask by lon/lat bounds';
                '  Both masks can be used together (applied sequentially)';
                '';
                'STARFIELD OPTIONS:';
                '  Dot Count: Number of random dots (1-1000)';
                '  Dot Radius: Angular size in degrees';
                '  Dot Size: Static or Distance-relative';
                '  Occlusion: Closest/Sum/Mean for overlapping dots';
                '  Dot Level: Fixed brightness, random spread, or random binary';
                '  Re-randomize: New positions each frame';
                '';
                'WORKFLOW:';
                '  1. Select arena configuration';
                '  2. Set pattern parameters';
                '  3. Click "Generate & Preview" to see result';
                '  4. Click "Save Pattern" to save .pat file';
                };
        end
    end

    % Callbacks
    methods (Access = private)

        function ArenaConfigDropDownValueChanged(app)
            app.loadArenaConfig();
            app.parameterChanged();
        end

        function ChangeArenaButtonPushed(app)
            if app.ArenaLocked
                app.unlockArena();
            else
                app.lockArena();
            end
        end

        function PatternTypeDropDownValueChanged(app)
            app.updateParameterStates();
            app.parameterChanged();
        end

        function PatternFOVDropDownValueChanged(app)
            app.updateParameterStates();
            app.parameterChanged();
        end

        function GrayscaleDropDownValueChanged(app)
            app.updateBrightnessLimits();
            app.parameterChanged();
        end

        function StepSizeSpinnerValueChanged(app)
            app.updateStepSizeInfo();
            app.parameterChanged();
        end

        function SAMaskCheckBoxChanged(app)
            % Enable/disable mask parameters and update visual state
            isActive = app.SAMaskCheckBox.Value;

            % Bold checkbox when active
            if isActive
                app.SAMaskCheckBox.FontWeight = 'bold';
                % Initialize params if empty
                if isempty(app.SAMaskParams)
                    app.SAMaskParams = [0, 0, deg2rad(45), 0];  % Default: center, 45 deg radius
                end
            else
                app.SAMaskCheckBox.FontWeight = 'normal';
            end

            % Enable/disable all parameter controls
            enableState = matlab.lang.OnOffSwitchState(isActive);
            app.SAAzimuthLabel.Enable = enableState;
            app.SAAzimuthSpinner.Enable = enableState;
            app.SAElevationLabel.Enable = enableState;
            app.SAElevationSpinner.Enable = enableState;
            app.SARadiusLabel.Enable = enableState;
            app.SARadiusSpinner.Enable = enableState;
            app.SABackgroundLabel.Enable = enableState;
            app.SABackgroundSpinner.Enable = enableState;
            app.SAInvertCheckBox.Enable = enableState;

            app.parameterChanged();
        end

        function LatLongMaskCheckBoxChanged(app)
            % Enable/disable mask parameters and update visual state
            isActive = app.LatLongMaskCheckBox.Value;

            % Bold checkbox when active
            if isActive
                app.LatLongMaskCheckBox.FontWeight = 'bold';
                % Initialize params if empty
                if isempty(app.LatLongMaskParams)
                    app.LatLongMaskParams = [deg2rad(-90), deg2rad(90), deg2rad(-45), deg2rad(45), 0];
                end
            else
                app.LatLongMaskCheckBox.FontWeight = 'normal';
            end

            % Enable/disable all parameter controls
            enableState = matlab.lang.OnOffSwitchState(isActive);
            app.LonMinLabel.Enable = enableState;
            app.LonMinSpinner.Enable = enableState;
            app.LonMaxLabel.Enable = enableState;
            app.LonMaxSpinner.Enable = enableState;
            app.LatMinLabel.Enable = enableState;
            app.LatMinSpinner.Enable = enableState;
            app.LatMaxLabel.Enable = enableState;
            app.LatMaxSpinner.Enable = enableState;
            app.LatLongInvertCheckBox.Enable = enableState;

            app.parameterChanged();
        end

        function saMaskParamChanged(app)
            % Update SA mask params from UI
            app.SAMaskParams = [deg2rad(app.SAAzimuthSpinner.Value), ...
                               deg2rad(app.SAElevationSpinner.Value), ...
                               deg2rad(app.SARadiusSpinner.Value), ...
                               double(app.SAInvertCheckBox.Value)];
            app.MaskBackgroundLevel = app.SABackgroundSpinner.Value;
            app.parameterChanged();
        end

        function latLongMaskParamChanged(app)
            % Update lat/long mask params from UI
            app.LatLongMaskParams = [deg2rad(app.LonMinSpinner.Value), ...
                                    deg2rad(app.LonMaxSpinner.Value), ...
                                    deg2rad(app.LatMinSpinner.Value), ...
                                    deg2rad(app.LatMaxSpinner.Value), ...
                                    double(app.LatLongInvertCheckBox.Value)];
            app.parameterChanged();
        end


        function GeneratePreviewButtonPushed(app)
            % Generate pattern and send to Previewer
            app.setStatus('Generating...');
            drawnow;

            try
                handles = app.buildHandlesStruct();
                [Pats, ~, ~] = Pattern_Generator(handles);

                % Store pattern
                app.Pats = Pats;
                app.NumFrames = size(Pats, 3);
                app.PatternGenerated = true;

                % Lock arena after generation
                app.lockArena();

                % Find or create Previewer (same pattern as PatternCombinerApp)
                if isempty(app.PreviewerApp) || ~isvalid(app.PreviewerApp)
                    app.PreviewerApp = app.findExistingPreviewer();
                    if isempty(app.PreviewerApp)
                        app.PreviewerApp = PatternPreviewerApp();
                    end
                end

                % Send pattern to Previewer
                name = app.generatePatternName();
                gs_val = app.getGrayscaleValue();
                stretchVal = app.StretchSpinner.Value * ones(app.NumFrames, 1);
                app.PreviewerApp.loadPatternFromApp(Pats, stretchVal, gs_val, name, app.CurrentArenaConfig, true);

                % Position Previewer adjacent
                app.positionPreviewerAdjacent();

                % Bring all pattern apps to front (Previewer + Generator visible)
                app.bringAllPatternAppsToFront();

                app.setStatus(sprintf('%d frames, %dx%d', app.NumFrames, size(Pats, 1), size(Pats, 2)));

            catch ME
                app.setStatus('Error - see dialog');
                uialert(app.UIFigure, ME.message, 'Generation Error', 'Icon', 'error');
            end
        end

        function SaveButtonPushed(app)
            if isempty(app.Pats)
                app.setStatus('Generate a pattern first');
                return;
            end

            % Build default save path
            arenaName = '';
            patternDir = app.maDisplayToolsRoot;
            if ~isempty(app.CurrentArenaConfig)
                arenaName = app.CurrentArenaConfig.name;
                patternDir = fullfile(app.maDisplayToolsRoot, 'patterns', arenaName);

                if ~isfolder(patternDir)
                    try
                        mkdir(patternDir);
                    catch
                        patternDir = app.maDisplayToolsRoot;
                    end
                end
            end

            gen = '';
            if ~isempty(app.CurrentArenaConfig)
                gen = upper(app.CurrentArenaConfig.arena.generation);
            end
            isG6 = startsWith(gen, 'G6');

            defaultFilename = app.generatePatternName();
            defaultPath = fullfile(patternDir, defaultFilename);

            if isG6
                dialogTitle = 'Save Pattern - Enter base name (creates .pat)';
            else
                dialogTitle = 'Save Pattern - Enter base name (creates .mat + .pat)';
            end

            [filename, pathname] = uiputfile('*.*', dialogTitle, defaultPath);
            if isequal(filename, 0)
                return;
            end

            app.setStatus('Saving...');
            drawnow;

            try
                handles = app.buildHandlesStruct();
                param = handles.param;
                param.stretch = app.StretchSpinner.Value * ones(app.NumFrames, 1);

                if ~isempty(app.CurrentArenaConfig)
                    param.arena_config = app.CurrentArenaConfig;
                end

                [~, patName, ~] = fileparts(filename);
                save_pattern(app.Pats, param, pathname, patName, [], ...
                    fullfile(handles.arena_folder, handles.arena_file));

                patFile = sprintf('%s_%s.pat', patName, gen);
                if isG6
                    app.setStatus(sprintf('Saved: %s', patFile));
                else
                    matFile = sprintf('%s_%s.mat', patName, gen);
                    app.setStatus(sprintf('Saved: %s + %s', matFile, patFile));
                end

            catch ME
                app.setStatus('Save error');
                uialert(app.UIFigure, ME.message, 'Save Error', 'Icon', 'error');
            end
        end

        function ExportScriptButtonPushed(app)
            [filename, pathname] = uiputfile('*.m', 'Export Script', 'pattern_script.m');
            if isequal(filename, 0)
                return;
            end

            filepath = fullfile(pathname, filename);

            fid = fopen(filepath, 'w');
            fprintf(fid, '%% Pattern Generation Script\n');
            fprintf(fid, '%% Generated by PatternGeneratorApp on %s\n\n', datestr(now));

            fprintf(fid, '%% Add paths\n');
            fprintf(fid, 'addpath(genpath(''%s''));\n\n', app.maDisplayToolsRoot);

            fprintf(fid, '%% Arena configuration\n');
            if ~isempty(app.CurrentArenaConfig)
                fprintf(fid, 'arena_config = load_arena_config(''%s'');\n\n', ...
                    app.CurrentArenaConfig.source_file);
            end

            fprintf(fid, '%% Pattern parameters\n');
            fprintf(fid, 'param = struct();\n');
            fprintf(fid, 'param.pattern_type = ''%s'';\n', lower(strrep(app.PatternTypeDropDown.Value, ' ', '_')));
            fprintf(fid, 'param.motion_type = ''%s'';\n', lower(app.MotionTypeDropDown.Value));
            fprintf(fid, 'param.pattern_fov = ''%s'';\n', lower(strrep(app.PatternFOVDropDown.Value, ' (mask-centered)', '')));
            fprintf(fid, 'param.spat_freq = deg2rad(%.1f);  %% degrees\n', app.SpatialFreqSpinner.Value);
            fprintf(fid, 'param.step_size = deg2rad(%.1f);  %% degrees\n', app.StepSizeSpinner.Value);

            if strcmp(app.GrayscaleDropDown.Value, 'Binary (1-bit)')
                fprintf(fid, 'param.gs_val = 1;  %% binary\n');
            else
                fprintf(fid, 'param.gs_val = 4;  %% grayscale\n');
            end

            fprintf(fid, 'param.generation = ''%s'';\n', app.GenerationText.Text);
            fprintf(fid, 'param.levels = [%d %d %d];\n', app.BrightnessHighSpinner.Value, ...
                app.BrightnessLowSpinner.Value, app.MaskBackgroundLevel);
            fprintf(fid, 'param.duty_cycle = %d;\n', app.DutyCycleSpinner.Value);
            fprintf(fid, 'param.arena_pitch = deg2rad(%.1f);\n', app.ArenaPitchSpinner.Value);
            fprintf(fid, 'param.pole_coord = [deg2rad(%.1f) deg2rad(%.1f)];\n', ...
                app.PoleAzimuthSpinner.Value, app.PoleElevationSpinner.Value);
            fprintf(fid, 'param.motion_angle = deg2rad(%.1f);\n', app.MotionAngleSpinner.Value);

            fprintf(fid, '\n%% Default mask parameters\n');
            fprintf(fid, 'param.sa_mask = [0 0 pi 0];  %% no solid angle mask\n');
            fprintf(fid, 'param.long_lat_mask = [-pi pi -pi/2 pi/2 0];  %% no lat/long mask\n');

            fprintf(fid, '\n%% Starfield parameters\n');
            fprintf(fid, 'param.num_dots = %d;\n', app.DotCountSpinner.Value);
            fprintf(fid, 'param.dot_radius = deg2rad(%.1f);\n', app.DotRadiusSpinner.Value);

            fprintf(fid, '\n%% Fixed parameters\n');
            fprintf(fid, 'param.aa_samples = 15;\n');
            fprintf(fid, 'param.aa_poles = 1;\n');
            fprintf(fid, 'param.back_frame = 0;\n');
            fprintf(fid, 'param.flip_right = 0;\n');
            fprintf(fid, 'param.phase_shift = 0;\n');
            fprintf(fid, 'param.checker_layout = 0;\n');

            fprintf(fid, '\n%% Build handles struct for Pattern_Generator\n');
            fprintf(fid, 'handles.param = param;\n');
            fprintf(fid, 'handles.arena_folder = ''%s'';\n', fullfile(app.maDisplayToolsRoot, 'configs', 'arenas'));
            fprintf(fid, 'handles.arena_file = ''arena_parameters.mat'';\n');

            fprintf(fid, '\n%% Generate pattern\n');
            fprintf(fid, '[Pats, ~, ~] = Pattern_Generator(handles);\n');
            fprintf(fid, 'stretch = param.stretch * ones(size(Pats, 3), 1);\n');
            fprintf(fid, '\n%% Preview pattern\n');
            fprintf(fid, 'previewer = PatternPreviewerApp();\n');
            fprintf(fid, 'previewer.loadPatternFromApp(Pats, stretch, %d, ''exported_pattern'', arena_config, true);\n', ...
                app.getGrayscaleValue());

            fclose(fid);
            app.setStatus(sprintf('Exported: %s', filename));
        end
    end

    % App creation and deletion
    methods (Access = public)

        function app = PatternGeneratorApp
            % Create and configure components
            app.createComponents();

            % Find maDisplayTools root
            appPath = fileparts(mfilename('fullpath'));
            app.maDisplayToolsRoot = fileparts(appPath);

            % Initialize state
            app.PatternGenerated = false;
            app.SAMaskParams = [];
            app.LatLongMaskParams = [];

            % Initialize arena configs
            app.scanArenaConfigs();
            if ~isempty(app.ArenaConfigs)
                app.loadArenaConfig();
            end

            % Update parameter states
            app.updateParameterStates();

            % Register the app
            registerApp(app, app.UIFigure);

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            delete(app.UIFigure);
        end

        function savePositionAndClose(app)
            % Save window position before closing
            if isvalid(app.UIFigure)
                setpref('maDisplayTools', 'PatternGeneratorPosition', app.UIFigure.Position);
            end
            delete(app);
        end
    end

    % Component creation
    methods (Access = private)

        function createComponents(app)
            % Create UIFigure with persistent position
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Name = 'Pattern Generator';
            app.UIFigure.CloseRequestFcn = @(~,~) app.savePositionAndClose();

            % Load saved position or use default
            defaultPos = [59 54 652 604];  % Height for stacking
            if ispref('maDisplayTools', 'PatternGeneratorPosition')
                savedPos = getpref('maDisplayTools', 'PatternGeneratorPosition');
                % Validate saved position (ensure it's on screen)
                screenSize = get(0, 'ScreenSize');
                if savedPos(1) >= 0 && savedPos(1) < screenSize(3) - 100 && ...
                   savedPos(2) >= 0 && savedPos(2) < screenSize(4) - 100 && ...
                   savedPos(3) >= 200 && savedPos(4) >= 200
                    app.UIFigure.Position = savedPos;
                else
                    app.UIFigure.Position = defaultPos;
                end
            else
                app.UIFigure.Position = defaultPos;
            end

            % Create main grid layout (3 rows: panels, buttons, status)
            app.MainGrid = uigridlayout(app.UIFigure, [3 2]);
            app.MainGrid.ColumnWidth = {'1x', 'fit'};
            app.MainGrid.RowHeight = {'1x', 30, 20};  % panels, buttons, status
            app.MainGrid.Padding = [5 5 5 5];
            app.MainGrid.RowSpacing = 5;

            % Create Left Panel (main controls)
            app.LeftPanel = uipanel(app.MainGrid);
            app.LeftPanel.Title = 'Parameters';
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;
            app.LeftPanel.Scrollable = 'on';

            leftGrid = uigridlayout(app.LeftPanel, [19 3]);  % Parameters only (buttons moved outside)
            leftGrid.RowHeight = repmat({25}, 1, 19);  % 19 param rows
            leftGrid.ColumnWidth = {90, '1x', 55};  % Original widths for labels/spinners
            leftGrid.Padding = [10 10 10 10];
            leftGrid.RowSpacing = 4;

            row = 1;

            % === Arena Section ===
            app.ArenaConfigLabel = uilabel(leftGrid);
            app.ArenaConfigLabel.Text = 'Arena:';
            app.ArenaConfigLabel.Layout.Row = row;
            app.ArenaConfigLabel.Layout.Column = 1;

            app.ArenaConfigDropDown = uidropdown(leftGrid);
            app.ArenaConfigDropDown.Items = {'Loading...'};
            app.ArenaConfigDropDown.ValueChangedFcn = @(~,~) app.ArenaConfigDropDownValueChanged();
            app.ArenaConfigDropDown.Layout.Row = row;
            app.ArenaConfigDropDown.Layout.Column = 2;
            app.ArenaConfigDropDown.Enable = 'off';

            % Button container for Change + Info
            btnGrid = uigridlayout(leftGrid, [1 2]);
            btnGrid.ColumnWidth = {35, 15};
            btnGrid.Padding = [0 0 0 0];
            btnGrid.ColumnSpacing = 2;
            btnGrid.Layout.Row = row;
            btnGrid.Layout.Column = 3;

            app.ChangeArenaButton = uibutton(btnGrid, 'push');
            app.ChangeArenaButton.Text = char(9998);  % Pencil icon
            app.ChangeArenaButton.Tooltip = 'Click to change arena';
            app.ChangeArenaButton.ButtonPushedFcn = @(~,~) app.ChangeArenaButtonPushed();
            app.ChangeArenaButton.Layout.Row = 1;
            app.ChangeArenaButton.Layout.Column = 1;

            app.InfoButton = uibutton(btnGrid, 'push');
            app.InfoButton.Text = '?';
            app.InfoButton.ButtonPushedFcn = @(~,~) app.showInfoDialog();
            app.InfoButton.Layout.Row = 1;
            app.InfoButton.Layout.Column = 2;
            row = row + 1;

            % Generation
            app.GenerationLabel = uilabel(leftGrid);
            app.GenerationLabel.Text = 'Gen:';
            app.GenerationLabel.Layout.Row = row;
            app.GenerationLabel.Layout.Column = 1;

            app.GenerationText = uilabel(leftGrid);
            app.GenerationText.Text = 'N/A';
            app.GenerationText.FontWeight = 'bold';
            app.GenerationText.Layout.Row = row;
            app.GenerationText.Layout.Column = [2 3];
            row = row + 1;

            % Arena Info
            app.ArenaInfoLabel = uilabel(leftGrid);
            app.ArenaInfoLabel.Text = 'Info:';
            app.ArenaInfoLabel.Layout.Row = row;
            app.ArenaInfoLabel.Layout.Column = 1;

            app.ArenaInfoText = uilabel(leftGrid);
            app.ArenaInfoText.Text = '';
            app.ArenaInfoText.FontSize = 9;
            app.ArenaInfoText.FontColor = [0.4 0.4 0.4];
            app.ArenaInfoText.Layout.Row = row;
            app.ArenaInfoText.Layout.Column = [2 3];
            row = row + 1;

            % === Pattern Section ===
            app.PatternTypeLabel = uilabel(leftGrid);
            app.PatternTypeLabel.Text = 'Pattern:';
            app.PatternTypeLabel.Layout.Row = row;
            app.PatternTypeLabel.Layout.Column = 1;

            app.PatternTypeDropDown = uidropdown(leftGrid);
            app.PatternTypeDropDown.Items = {'Square Grating', 'Sine Grating', 'Edge', 'Starfield', 'Off/On', 'Reverse-Phi'};
            app.PatternTypeDropDown.Value = 'Square Grating';
            app.PatternTypeDropDown.ValueChangedFcn = @(~,~) app.PatternTypeDropDownValueChanged();
            app.PatternTypeDropDown.Layout.Row = row;
            app.PatternTypeDropDown.Layout.Column = [2 3];
            row = row + 1;

            app.MotionTypeLabel = uilabel(leftGrid);
            app.MotionTypeLabel.Text = 'Motion:';
            app.MotionTypeLabel.Layout.Row = row;
            app.MotionTypeLabel.Layout.Column = 1;

            app.MotionTypeDropDown = uidropdown(leftGrid);
            app.MotionTypeDropDown.Items = {'Rotation', 'Translation', 'Expansion-Contraction'};
            app.MotionTypeDropDown.Value = 'Rotation';
            app.MotionTypeDropDown.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.MotionTypeDropDown.Layout.Row = row;
            app.MotionTypeDropDown.Layout.Column = [2 3];
            row = row + 1;

            app.PatternFOVLabel = uilabel(leftGrid);
            app.PatternFOVLabel.Text = 'FOV:';
            app.PatternFOVLabel.Layout.Row = row;
            app.PatternFOVLabel.Layout.Column = 1;

            app.PatternFOVDropDown = uidropdown(leftGrid);
            app.PatternFOVDropDown.Items = {'Full-field', 'Local (mask-centered)'};
            app.PatternFOVDropDown.Value = 'Full-field';
            app.PatternFOVDropDown.ValueChangedFcn = @(~,~) app.PatternFOVDropDownValueChanged();
            app.PatternFOVDropDown.Layout.Row = row;
            app.PatternFOVDropDown.Layout.Column = [2 3];
            row = row + 1;

            % Spatial Frequency
            app.SpatialFreqLabel = uilabel(leftGrid);
            app.SpatialFreqLabel.Text = 'Spat Freq:';
            app.SpatialFreqLabel.Layout.Row = row;
            app.SpatialFreqLabel.Layout.Column = 1;

            app.SpatialFreqSpinner = uispinner(leftGrid);
            app.SpatialFreqSpinner.Limits = [1 360];
            app.SpatialFreqSpinner.Value = 30;
            app.SpatialFreqSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.SpatialFreqSpinner.Layout.Row = row;
            app.SpatialFreqSpinner.Layout.Column = [2 3];
            row = row + 1;

            % Step Size
            app.StepSizeLabel = uilabel(leftGrid);
            app.StepSizeLabel.Text = 'Step (deg):';
            app.StepSizeLabel.Layout.Row = row;
            app.StepSizeLabel.Layout.Column = 1;

            app.StepSizeSpinner = uispinner(leftGrid);
            app.StepSizeSpinner.Limits = [0.1 30];
            app.StepSizeSpinner.Value = 3;
            app.StepSizeSpinner.Step = 0.5;
            app.StepSizeSpinner.ValueChangedFcn = @(~,~) app.StepSizeSpinnerValueChanged();
            app.StepSizeSpinner.Layout.Row = row;
            app.StepSizeSpinner.Layout.Column = 2;

            app.StepSizeInfoText = uilabel(leftGrid);
            app.StepSizeInfoText.Text = '';
            app.StepSizeInfoText.FontSize = 9;
            app.StepSizeInfoText.FontColor = [0.3 0.5 0.3];
            app.StepSizeInfoText.Layout.Row = row;
            app.StepSizeInfoText.Layout.Column = 3;
            row = row + 1;

            % Stretch
            app.StretchLabel = uilabel(leftGrid);
            app.StretchLabel.Text = 'Stretch:';
            app.StretchLabel.Layout.Row = row;
            app.StretchLabel.Layout.Column = 1;

            app.StretchSpinner = uispinner(leftGrid);
            app.StretchSpinner.Limits = [0 100];
            app.StretchSpinner.Value = 0;
            app.StretchSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.StretchSpinner.Layout.Row = row;
            app.StretchSpinner.Layout.Column = [2 3];
            row = row + 1;

            % Duty Cycle
            app.DutyCycleLabel = uilabel(leftGrid);
            app.DutyCycleLabel.Text = 'Duty (%):';
            app.DutyCycleLabel.Layout.Row = row;
            app.DutyCycleLabel.Layout.Column = 1;

            app.DutyCycleSpinner = uispinner(leftGrid);
            app.DutyCycleSpinner.Limits = [1 99];
            app.DutyCycleSpinner.Value = 50;
            app.DutyCycleSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.DutyCycleSpinner.Layout.Row = row;
            app.DutyCycleSpinner.Layout.Column = [2 3];
            row = row + 1;

            % === Brightness Section ===
            app.GrayscaleLabel = uilabel(leftGrid);
            app.GrayscaleLabel.Text = 'Grayscale:';
            app.GrayscaleLabel.Layout.Row = row;
            app.GrayscaleLabel.Layout.Column = 1;

            app.GrayscaleDropDown = uidropdown(leftGrid);
            app.GrayscaleDropDown.Items = {'Grayscale (4-bit)', 'Binary (1-bit)'};
            app.GrayscaleDropDown.Value = 'Grayscale (4-bit)';
            app.GrayscaleDropDown.ValueChangedFcn = @(~,~) app.GrayscaleDropDownValueChanged();
            app.GrayscaleDropDown.Layout.Row = row;
            app.GrayscaleDropDown.Layout.Column = [2 3];
            row = row + 1;

            app.BrightnessHighLabel = uilabel(leftGrid);
            app.BrightnessHighLabel.Text = 'Bright:';
            app.BrightnessHighLabel.Layout.Row = row;
            app.BrightnessHighLabel.Layout.Column = 1;

            app.BrightnessHighSpinner = uispinner(leftGrid);
            app.BrightnessHighSpinner.Limits = [0 15];
            app.BrightnessHighSpinner.Value = 15;
            app.BrightnessHighSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.BrightnessHighSpinner.Layout.Row = row;
            app.BrightnessHighSpinner.Layout.Column = [2 3];
            row = row + 1;

            app.BrightnessLowLabel = uilabel(leftGrid);
            app.BrightnessLowLabel.Text = 'Dark:';
            app.BrightnessLowLabel.Layout.Row = row;
            app.BrightnessLowLabel.Layout.Column = 1;

            app.BrightnessLowSpinner = uispinner(leftGrid);
            app.BrightnessLowSpinner.Limits = [0 15];
            app.BrightnessLowSpinner.Value = 0;
            app.BrightnessLowSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.BrightnessLowSpinner.Layout.Row = row;
            app.BrightnessLowSpinner.Layout.Column = [2 3];
            row = row + 1;

            % === Advanced Controls ===
            app.MotionAngleLabel = uilabel(leftGrid);
            app.MotionAngleLabel.Text = 'Motion Ang:';
            app.MotionAngleLabel.Layout.Row = row;
            app.MotionAngleLabel.Layout.Column = 1;

            app.MotionAngleSpinner = uispinner(leftGrid);
            app.MotionAngleSpinner.Limits = [0 360];
            app.MotionAngleSpinner.Value = 0;
            app.MotionAngleSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.MotionAngleSpinner.Layout.Row = row;
            app.MotionAngleSpinner.Layout.Column = [2 3];
            row = row + 1;

            app.PoleAzimuthLabel = uilabel(leftGrid);
            app.PoleAzimuthLabel.Text = 'Pole Lon:';
            app.PoleAzimuthLabel.Layout.Row = row;
            app.PoleAzimuthLabel.Layout.Column = 1;

            app.PoleAzimuthSpinner = uispinner(leftGrid);
            app.PoleAzimuthSpinner.Limits = [-180 180];
            app.PoleAzimuthSpinner.Value = 0;
            app.PoleAzimuthSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.PoleAzimuthSpinner.Layout.Row = row;
            app.PoleAzimuthSpinner.Layout.Column = [2 3];
            row = row + 1;

            app.PoleElevationLabel = uilabel(leftGrid);
            app.PoleElevationLabel.Text = 'Pole Lat:';
            app.PoleElevationLabel.Layout.Row = row;
            app.PoleElevationLabel.Layout.Column = 1;

            app.PoleElevationSpinner = uispinner(leftGrid);
            app.PoleElevationSpinner.Limits = [-90 90];
            app.PoleElevationSpinner.Value = -90;
            app.PoleElevationSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.PoleElevationSpinner.Layout.Row = row;
            app.PoleElevationSpinner.Layout.Column = [2 3];
            row = row + 1;

            app.ArenaPitchLabel = uilabel(leftGrid);
            app.ArenaPitchLabel.Text = 'Pitch:';
            app.ArenaPitchLabel.Layout.Row = row;
            app.ArenaPitchLabel.Layout.Column = 1;

            app.ArenaPitchSpinner = uispinner(leftGrid);
            app.ArenaPitchSpinner.Limits = [-90 90];
            app.ArenaPitchSpinner.Value = 0;
            app.ArenaPitchSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.ArenaPitchSpinner.Layout.Row = row;
            app.ArenaPitchSpinner.Layout.Column = [2 3];

            % === Right Panel (Options - Starfield, Mask Config) ===
            app.RightPanel = uipanel(app.MainGrid);
            app.RightPanel.Title = 'Options';
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;
            % RightPanel always visible (contains mask controls)

            rightGrid = uigridlayout(app.RightPanel, [3 1]);
            rightGrid.RowHeight = {'fit', 'fit', 'fit'};
            rightGrid.ColumnWidth = {'1x'};
            rightGrid.Padding = [5 5 5 5];
            rightGrid.RowSpacing = 5;

            % === Starfield Options Panel ===
            app.StarfieldOptionsPanel = uipanel(rightGrid);
            app.StarfieldOptionsPanel.Title = 'Starfield';
            app.StarfieldOptionsPanel.Layout.Row = 1;
            app.StarfieldOptionsPanel.Layout.Column = 1;
            app.StarfieldOptionsPanel.Visible = 'off';

            starGrid = uigridlayout(app.StarfieldOptionsPanel, [6 2]);
            starGrid.RowHeight = {22, 22, 22, 22, 22, 22};
            starGrid.ColumnWidth = {70, '1x'};
            starGrid.Padding = [5 5 5 5];
            starGrid.RowSpacing = 2;

            app.DotCountLabel = uilabel(starGrid);
            app.DotCountLabel.Text = 'Count:';
            app.DotCountLabel.Layout.Row = 1;
            app.DotCountLabel.Layout.Column = 1;

            app.DotCountSpinner = uispinner(starGrid);
            app.DotCountSpinner.Limits = [1 1000];
            app.DotCountSpinner.Value = 100;
            app.DotCountSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.DotCountSpinner.Layout.Row = 1;
            app.DotCountSpinner.Layout.Column = 2;

            app.DotRadiusLabel = uilabel(starGrid);
            app.DotRadiusLabel.Text = 'Radius:';
            app.DotRadiusLabel.Layout.Row = 2;
            app.DotRadiusLabel.Layout.Column = 1;

            app.DotRadiusSpinner = uispinner(starGrid);
            app.DotRadiusSpinner.Limits = [0.1 45];
            app.DotRadiusSpinner.Value = 5;
            app.DotRadiusSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.DotRadiusSpinner.Layout.Row = 2;
            app.DotRadiusSpinner.Layout.Column = 2;

            app.DotSizeLabel = uilabel(starGrid);
            app.DotSizeLabel.Text = 'Size:';
            app.DotSizeLabel.Layout.Row = 3;
            app.DotSizeLabel.Layout.Column = 1;

            app.DotSizeDropDown = uidropdown(starGrid);
            app.DotSizeDropDown.Items = {'Static', 'Distance-relative'};
            app.DotSizeDropDown.Value = 'Static';
            app.DotSizeDropDown.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.DotSizeDropDown.Layout.Row = 3;
            app.DotSizeDropDown.Layout.Column = 2;

            app.DotOcclusionLabel = uilabel(starGrid);
            app.DotOcclusionLabel.Text = 'Occlusion:';
            app.DotOcclusionLabel.Layout.Row = 4;
            app.DotOcclusionLabel.Layout.Column = 1;

            app.DotOcclusionDropDown = uidropdown(starGrid);
            app.DotOcclusionDropDown.Items = {'Closest', 'Sum', 'Mean'};
            app.DotOcclusionDropDown.Value = 'Closest';
            app.DotOcclusionDropDown.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.DotOcclusionDropDown.Layout.Row = 4;
            app.DotOcclusionDropDown.Layout.Column = 2;

            app.DotLevelLabel = uilabel(starGrid);
            app.DotLevelLabel.Text = 'Level:';
            app.DotLevelLabel.Layout.Row = 5;
            app.DotLevelLabel.Layout.Column = 1;

            app.DotLevelDropDown = uidropdown(starGrid);
            app.DotLevelDropDown.Items = {'Fixed', 'Random spread', 'Random binary'};
            app.DotLevelDropDown.Value = 'Fixed';
            app.DotLevelDropDown.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.DotLevelDropDown.Layout.Row = 5;
            app.DotLevelDropDown.Layout.Column = 2;

            app.DotReRandomCheckBox = uicheckbox(starGrid);
            app.DotReRandomCheckBox.Text = 'Re-randomize';
            app.DotReRandomCheckBox.Value = true;
            app.DotReRandomCheckBox.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.DotReRandomCheckBox.Layout.Row = 6;
            app.DotReRandomCheckBox.Layout.Column = [1 2];

            % === Solid Angle Mask Panel (with integrated checkbox) ===
            app.SAMaskPanel = uipanel(rightGrid);
            app.SAMaskPanel.Title = '';  % No title - checkbox serves as header
            app.SAMaskPanel.Layout.Row = 2;
            app.SAMaskPanel.Layout.Column = 1;

            saGrid = uigridlayout(app.SAMaskPanel, [6 2]);
            saGrid.RowHeight = {22, 22, 22, 22, 22, 22};
            saGrid.ColumnWidth = {80, '1x'};
            saGrid.Padding = [5 5 5 5];
            saGrid.RowSpacing = 2;

            % Checkbox at top controls mask active state
            app.SAMaskCheckBox = uicheckbox(saGrid);
            app.SAMaskCheckBox.Text = 'Solid Angle Mask';
            app.SAMaskCheckBox.Value = false;
            app.SAMaskCheckBox.ValueChangedFcn = @(~,~) app.SAMaskCheckBoxChanged();
            app.SAMaskCheckBox.Layout.Row = 1;
            app.SAMaskCheckBox.Layout.Column = [1 2];

            app.SAAzimuthLabel = uilabel(saGrid);
            app.SAAzimuthLabel.Text = 'Azimuth (deg):';
            app.SAAzimuthLabel.Layout.Row = 2;
            app.SAAzimuthLabel.Layout.Column = 1;
            app.SAAzimuthLabel.Enable = 'off';

            app.SAAzimuthSpinner = uispinner(saGrid);
            app.SAAzimuthSpinner.Limits = [-180 180];
            app.SAAzimuthSpinner.Value = 0;
            app.SAAzimuthSpinner.ValueChangedFcn = @(~,~) app.saMaskParamChanged();
            app.SAAzimuthSpinner.Layout.Row = 2;
            app.SAAzimuthSpinner.Layout.Column = 2;
            app.SAAzimuthSpinner.Enable = 'off';

            app.SAElevationLabel = uilabel(saGrid);
            app.SAElevationLabel.Text = 'Elevation (deg):';
            app.SAElevationLabel.Layout.Row = 3;
            app.SAElevationLabel.Layout.Column = 1;
            app.SAElevationLabel.Enable = 'off';

            app.SAElevationSpinner = uispinner(saGrid);
            app.SAElevationSpinner.Limits = [-90 90];
            app.SAElevationSpinner.Value = 0;
            app.SAElevationSpinner.ValueChangedFcn = @(~,~) app.saMaskParamChanged();
            app.SAElevationSpinner.Layout.Row = 3;
            app.SAElevationSpinner.Layout.Column = 2;
            app.SAElevationSpinner.Enable = 'off';

            app.SARadiusLabel = uilabel(saGrid);
            app.SARadiusLabel.Text = 'Radius (deg):';
            app.SARadiusLabel.Layout.Row = 4;
            app.SARadiusLabel.Layout.Column = 1;
            app.SARadiusLabel.Enable = 'off';

            app.SARadiusSpinner = uispinner(saGrid);
            app.SARadiusSpinner.Limits = [1 180];
            app.SARadiusSpinner.Value = 45;
            app.SARadiusSpinner.ValueChangedFcn = @(~,~) app.saMaskParamChanged();
            app.SARadiusSpinner.Layout.Row = 4;
            app.SARadiusSpinner.Layout.Column = 2;
            app.SARadiusSpinner.Enable = 'off';

            app.SABackgroundLabel = uilabel(saGrid);
            app.SABackgroundLabel.Text = 'Background:';
            app.SABackgroundLabel.Layout.Row = 5;
            app.SABackgroundLabel.Layout.Column = 1;
            app.SABackgroundLabel.Enable = 'off';

            app.SABackgroundSpinner = uispinner(saGrid);
            app.SABackgroundSpinner.Limits = [0 15];
            app.SABackgroundSpinner.Value = 0;
            app.SABackgroundSpinner.ValueChangedFcn = @(~,~) app.saMaskParamChanged();
            app.SABackgroundSpinner.Layout.Row = 5;
            app.SABackgroundSpinner.Layout.Column = 2;
            app.SABackgroundSpinner.Enable = 'off';

            app.SAInvertCheckBox = uicheckbox(saGrid);
            app.SAInvertCheckBox.Text = 'Invert Mask';
            app.SAInvertCheckBox.Value = false;
            app.SAInvertCheckBox.ValueChangedFcn = @(~,~) app.saMaskParamChanged();
            app.SAInvertCheckBox.Layout.Row = 6;
            app.SAInvertCheckBox.Layout.Column = [1 2];
            app.SAInvertCheckBox.Enable = 'off';

            % === Lat/Long Mask Panel (with integrated checkbox) ===
            app.LatLongMaskPanel = uipanel(rightGrid);
            app.LatLongMaskPanel.Title = '';  % No title - checkbox serves as header
            app.LatLongMaskPanel.Layout.Row = 3;
            app.LatLongMaskPanel.Layout.Column = 1;

            llGrid = uigridlayout(app.LatLongMaskPanel, [6 2]);
            llGrid.RowHeight = {22, 22, 22, 22, 22, 22};
            llGrid.ColumnWidth = {80, '1x'};
            llGrid.Padding = [5 5 5 5];
            llGrid.RowSpacing = 2;

            % Checkbox at top controls mask active state
            app.LatLongMaskCheckBox = uicheckbox(llGrid);
            app.LatLongMaskCheckBox.Text = 'Lat/Long Mask';
            app.LatLongMaskCheckBox.Value = false;
            app.LatLongMaskCheckBox.ValueChangedFcn = @(~,~) app.LatLongMaskCheckBoxChanged();
            app.LatLongMaskCheckBox.Layout.Row = 1;
            app.LatLongMaskCheckBox.Layout.Column = [1 2];

            app.LonMinLabel = uilabel(llGrid);
            app.LonMinLabel.Text = 'Lon Min (deg):';
            app.LonMinLabel.Layout.Row = 2;
            app.LonMinLabel.Layout.Column = 1;
            app.LonMinLabel.Enable = 'off';

            app.LonMinSpinner = uispinner(llGrid);
            app.LonMinSpinner.Limits = [-180 180];
            app.LonMinSpinner.Value = -90;
            app.LonMinSpinner.ValueChangedFcn = @(~,~) app.latLongMaskParamChanged();
            app.LonMinSpinner.Layout.Row = 2;
            app.LonMinSpinner.Layout.Column = 2;
            app.LonMinSpinner.Enable = 'off';

            app.LonMaxLabel = uilabel(llGrid);
            app.LonMaxLabel.Text = 'Lon Max (deg):';
            app.LonMaxLabel.Layout.Row = 3;
            app.LonMaxLabel.Layout.Column = 1;
            app.LonMaxLabel.Enable = 'off';

            app.LonMaxSpinner = uispinner(llGrid);
            app.LonMaxSpinner.Limits = [-180 180];
            app.LonMaxSpinner.Value = 90;
            app.LonMaxSpinner.ValueChangedFcn = @(~,~) app.latLongMaskParamChanged();
            app.LonMaxSpinner.Layout.Row = 3;
            app.LonMaxSpinner.Layout.Column = 2;
            app.LonMaxSpinner.Enable = 'off';

            app.LatMinLabel = uilabel(llGrid);
            app.LatMinLabel.Text = 'Lat Min (deg):';
            app.LatMinLabel.Layout.Row = 4;
            app.LatMinLabel.Layout.Column = 1;
            app.LatMinLabel.Enable = 'off';

            app.LatMinSpinner = uispinner(llGrid);
            app.LatMinSpinner.Limits = [-90 90];
            app.LatMinSpinner.Value = -45;
            app.LatMinSpinner.ValueChangedFcn = @(~,~) app.latLongMaskParamChanged();
            app.LatMinSpinner.Layout.Row = 4;
            app.LatMinSpinner.Layout.Column = 2;
            app.LatMinSpinner.Enable = 'off';

            app.LatMaxLabel = uilabel(llGrid);
            app.LatMaxLabel.Text = 'Lat Max (deg):';
            app.LatMaxLabel.Layout.Row = 5;
            app.LatMaxLabel.Layout.Column = 1;
            app.LatMaxLabel.Enable = 'off';

            app.LatMaxSpinner = uispinner(llGrid);
            app.LatMaxSpinner.Limits = [-90 90];
            app.LatMaxSpinner.Value = 45;
            app.LatMaxSpinner.ValueChangedFcn = @(~,~) app.latLongMaskParamChanged();
            app.LatMaxSpinner.Layout.Row = 5;
            app.LatMaxSpinner.Layout.Column = 2;
            app.LatMaxSpinner.Enable = 'off';

            app.LatLongInvertCheckBox = uicheckbox(llGrid);
            app.LatLongInvertCheckBox.Text = 'Invert Mask';
            app.LatLongInvertCheckBox.Value = false;
            app.LatLongInvertCheckBox.ValueChangedFcn = @(~,~) app.latLongMaskParamChanged();
            app.LatLongInvertCheckBox.Layout.Row = 6;
            app.LatLongInvertCheckBox.Layout.Column = [1 2];
            app.LatLongInvertCheckBox.Enable = 'off';

            % === Bottom Buttons (full width, spanning both columns) ===
            app.ButtonGrid = uigridlayout(app.MainGrid, [1 3]);
            app.ButtonGrid.Layout.Row = 2;
            app.ButtonGrid.Layout.Column = [1 2];  % Span both columns
            app.ButtonGrid.ColumnWidth = {'1x', '1x', '1x'};  % Equal width
            app.ButtonGrid.RowHeight = {'1x'};
            app.ButtonGrid.Padding = [5 0 5 0];
            app.ButtonGrid.ColumnSpacing = 5;

            app.GeneratePreviewButton = uibutton(app.ButtonGrid, 'push');
            app.GeneratePreviewButton.Text = 'Generate & Preview';
            app.GeneratePreviewButton.ButtonPushedFcn = @(~,~) app.GeneratePreviewButtonPushed();
            app.GeneratePreviewButton.Layout.Row = 1;
            app.GeneratePreviewButton.Layout.Column = 1;
            app.GeneratePreviewButton.BackgroundColor = [0.3 0.6 0.3];
            app.GeneratePreviewButton.FontColor = [1 1 1];

            app.SaveButton = uibutton(app.ButtonGrid, 'push');
            app.SaveButton.Text = 'Save...';
            app.SaveButton.ButtonPushedFcn = @(~,~) app.SaveButtonPushed();
            app.SaveButton.Layout.Row = 1;
            app.SaveButton.Layout.Column = 2;

            app.ExportScriptButton = uibutton(app.ButtonGrid, 'push');
            app.ExportScriptButton.Text = 'Export Script...';
            app.ExportScriptButton.ButtonPushedFcn = @(~,~) app.ExportScriptButtonPushed();
            app.ExportScriptButton.Layout.Row = 1;
            app.ExportScriptButton.Layout.Column = 3;

            % === Status Label (full width at bottom) ===
            app.StatusLabel = uilabel(app.MainGrid);
            app.StatusLabel.Layout.Row = 3;
            app.StatusLabel.Layout.Column = [1 2];  % Span both columns
            app.StatusLabel.Text = 'Ready';

            % Show figure
            app.UIFigure.Visible = 'on';
        end
    end
end

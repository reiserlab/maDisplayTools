classdef PatternGeneratorApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                   matlab.ui.Figure
        GridLayout                 matlab.ui.container.GridLayout
        LeftPanel                  matlab.ui.container.Panel
        RightPanel                 matlab.ui.container.Panel

        % Left panel - Controls
        InfoButton                 matlab.ui.control.Button
        ArenaConfigLabel           matlab.ui.control.Label
        ArenaConfigDropDown        matlab.ui.control.DropDown
        ChangeArenaButton          matlab.ui.control.Button
        GenerationLabel            matlab.ui.control.Label
        GenerationText             matlab.ui.control.Label
        ArenaInfoLabel             matlab.ui.control.Label
        ArenaInfoText              matlab.ui.control.Label

        PatternTypeLabel           matlab.ui.control.Label
        PatternTypeDropDown        matlab.ui.control.DropDown
        MotionTypeLabel            matlab.ui.control.Label
        MotionTypeDropDown         matlab.ui.control.DropDown

        SpatialFreqLabel           matlab.ui.control.Label
        SpatialFreqSpinner         matlab.ui.control.Spinner
        StepSizeLabel              matlab.ui.control.Label
        StepSizeSpinner            matlab.ui.control.Spinner
        StepSizeInfoText           matlab.ui.control.Label
        StretchLabel               matlab.ui.control.Label
        StretchSpinner             matlab.ui.control.Spinner

        GrayscaleLabel             matlab.ui.control.Label
        GrayscaleDropDown          matlab.ui.control.DropDown

        % Phase 1: Core parameters
        DutyCycleLabel             matlab.ui.control.Label
        DutyCycleSpinner           matlab.ui.control.Spinner
        BrightnessHighLabel        matlab.ui.control.Label
        BrightnessHighSpinner      matlab.ui.control.Spinner
        BrightnessLowLabel         matlab.ui.control.Label
        BrightnessLowSpinner       matlab.ui.control.Spinner
        PatternFOVLabel            matlab.ui.control.Label
        PatternFOVDropDown         matlab.ui.control.DropDown

        % Phase 2: Advanced controls
        MotionAngleLabel           matlab.ui.control.Label
        MotionAngleSpinner         matlab.ui.control.Spinner
        PoleAzimuthLabel           matlab.ui.control.Label
        PoleAzimuthSpinner         matlab.ui.control.Spinner
        PoleElevationLabel         matlab.ui.control.Label
        PoleElevationSpinner       matlab.ui.control.Spinner
        ArenaPitchLabel            matlab.ui.control.Label
        ArenaPitchSpinner          matlab.ui.control.Spinner

        % Phase 3: Mask controls
        MasksHeaderLabel           matlab.ui.control.Label
        SAMaskCheckBox             matlab.ui.control.CheckBox
        SAMaskButton               matlab.ui.control.Button
        LatLongMaskCheckBox        matlab.ui.control.CheckBox
        LatLongMaskButton          matlab.ui.control.Button

        % Phase 4: Starfield options
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

        GenerateButton             matlab.ui.control.Button
        SaveButton                 matlab.ui.control.Button
        ExportScriptButton         matlab.ui.control.Button

        StatusLabel                matlab.ui.control.Label

        % Right panel - Preview
        PreviewAxes                matlab.ui.control.UIAxes
        FrameSlider                matlab.ui.control.Slider
        FrameLabel                 matlab.ui.control.Label
        PlayButton                 matlab.ui.control.Button
        FPSDropDown                matlab.ui.control.DropDown
        ViewModeLabel              matlab.ui.control.Label
        ViewModeDropDown           matlab.ui.control.DropDown
        DotScaleLabel              matlab.ui.control.Label
        DotScaleSlider             matlab.ui.control.Slider
        DotScaleValueLabel         matlab.ui.control.Label

        % FOV controls for projection views (zoom in only + reset)
        FOVLabel                   matlab.ui.control.Label
        LonZoomButton              matlab.ui.control.Button
        LonFOVValueLabel           matlab.ui.control.Label
        LatZoomButton              matlab.ui.control.Button
        LatFOVValueLabel           matlab.ui.control.Label
        FOVResetButton             matlab.ui.control.Button
    end

    properties (Access = private)
        maDisplayToolsRoot         % Root path of maDisplayTools
        ArenaConfigs               % Cell array of arena config paths
        CurrentArenaConfig         % Currently loaded arena config
        Pats                       % Generated pattern data
        NumFrames                  % Number of frames in pattern
        CurrentFrame               % Current frame being displayed
        PlayTimer                  % Timer for playback
        IsPlaying                  % Playback state
        LEDColormap                % Green LED colormap
        DegPerPixelH               % Horizontal degrees per pixel at equator
        PixelsH                    % Total horizontal pixels
        PixelsV                    % Total vertical pixels

        % Mask parameters (stored separately for dialog access)
        SAMaskParams               % [azimuth, elevation, radius, invert] in radians
        LatLongMaskParams          % [long_min, long_max, lat_min, lat_max, invert] in radians
        MaskBackgroundLevel = 0    % Brightness level for masked areas (0-15 for 4-bit)

        % Arena coordinates for Mercator view
        ArenaPhi                   % Azimuthal angle (longitude) for each pixel
        ArenaTheta                 % Polar angle (colatitude) for each pixel

        % FOV limits for projection views
        LonFOV = 180               % Longitude FOV half-width in degrees (±LonFOV)
        LatFOV = 90                % Latitude FOV half-height in degrees (±LatFOV)
        LonCenter = 0              % Longitude center in degrees (for partial arenas)
        LatCenter = 0              % Latitude center in degrees

        % Actual coordinate ranges from arena (for auto-FOV)
        ArenaLonMin = -180         % Min longitude in degrees
        ArenaLonMax = 180          % Max longitude in degrees
        ArenaLatMin = -90          % Min latitude in degrees
        ArenaLatMax = 90           % Max latitude in degrees

        % Arena lock state
        ArenaLocked = true         % Whether arena config is locked
        PatternGenerated = false   % Whether a pattern has been generated
    end

    methods (Access = private)

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

                app.StatusLabel.Text = sprintf('Loaded: %s', app.ArenaConfigDropDown.Value);
            catch ME
                app.StatusLabel.Text = sprintf('Error: %s', ME.message);
                app.GenerationText.Text = 'Error';
            end
        end

        function generateArenaMatFile(app)
            % Generate arena_parameters.mat from current YAML config
            % This creates the .mat file that Pattern_Generator expects

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

            % Load extended fields if present
            if isfield(cfg.arena, 'cylinder_model')
                model = cfg.arena.cylinder_model;
            end
            if isfield(cfg.arena, 'rotations_deg')
                rotations = deg2rad(cfg.arena.rotations_deg);
            end
            if isfield(cfg.arena, 'translations')
                translations = cfg.arena.translations;
            end

            % Generate and save arena coordinates
            arena_folder = fullfile(app.maDisplayToolsRoot, 'configs', 'arenas');
            arena_file = fullfile(arena_folder, 'arena_parameters.mat');

            arena_coordinates(Psize, Pcols, Prows, Pcircle, rot180, model, rotations, translations, arena_file);

            % Load the generated coordinates for Mercator view
            try
                arenaData = load(arena_file);
                if isfield(arenaData, 'arena_x') && isfield(arenaData, 'arena_y') && isfield(arenaData, 'arena_z')
                    [app.ArenaPhi, app.ArenaTheta, ~] = cart2sphere(arenaData.arena_x, arenaData.arena_y, arenaData.arena_z);

                    % Compute latitude range from coordinate data
                    latDeg = rad2deg(app.ArenaTheta(:)) - 90;
                    app.ArenaLatMin = min(latDeg);
                    app.ArenaLatMax = max(latDeg);

                    % Compute longitude range based on partial arena config
                    if cfg.derived.azimuth_coverage_deg < 360
                        % Partial arena: center at 0° (front), gap behind fly
                        halfCoverage = cfg.derived.azimuth_coverage_deg / 2;
                        app.ArenaLonMin = -halfCoverage;
                        app.ArenaLonMax = halfCoverage;
                    else
                        % Full 360 arena
                        app.ArenaLonMin = -180;
                        app.ArenaLonMax = 180;
                    end

                    % Initialize FOV based on arena range
                    app.initializeFOVFromArena();
                end
            catch
                app.ArenaPhi = [];
                app.ArenaTheta = [];
                app.ArenaLonMin = -180;
                app.ArenaLonMax = 180;
                app.ArenaLatMin = -90;
                app.ArenaLatMax = 90;
            end
        end

        function handles = buildHandlesStruct(app)
            % Build the handles struct expected by Pattern_Generator
            handles = struct();

            % Arena file path (generate temp .mat if needed)
            handles.arena_folder = fullfile(app.maDisplayToolsRoot, 'configs', 'arenas');
            handles.arena_file = 'arena_parameters.mat';

            % Build param struct
            param = struct();

            % Map dropdown values to Pattern_Generator expected values
            patternTypeMap = containers.Map(...
                {'Square Grating', 'Sine Grating', 'Edge', 'Starfield', 'Off/On'}, ...
                {'square grating', 'sine grating', 'edge', 'starfield', 'off_on'});
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
            % Background is stored separately (set in mask dialogs)
            param.levels = [app.BrightnessHighSpinner.Value, ...
                           app.BrightnessLowSpinner.Value, ...
                           app.MaskBackgroundLevel];

            % Phase 1: Core parameters from UI
            param.duty_cycle = app.DutyCycleSpinner.Value;

            % Phase 2: Advanced controls from UI
            param.motion_angle = deg2rad(app.MotionAngleSpinner.Value);
            % pole_coord = [longitude, latitude] in radians (matches G4 GUI)
            param.pole_coord = [deg2rad(app.PoleAzimuthSpinner.Value), ...
                               deg2rad(app.PoleElevationSpinner.Value)];
            param.arena_pitch = deg2rad(app.ArenaPitchSpinner.Value);

            % Phase 3: Mask parameters
            if app.SAMaskCheckBox.Value && ~isempty(app.SAMaskParams)
                param.sa_mask = app.SAMaskParams;
            else
                param.sa_mask = [0 0 pi 0];  % No mask (pi radius covers everything)
            end

            if app.LatLongMaskCheckBox.Value && ~isempty(app.LatLongMaskParams)
                param.long_lat_mask = app.LatLongMaskParams;
            else
                param.long_lat_mask = [-pi pi -pi/2 pi/2 0];  % No mask (full range)
            end

            % Phase 4: Starfield options from UI
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
                {0, 1, 2});  % Numeric values expected by make_starfield
            param.dot_level = dotLevelMap(app.DotLevelDropDown.Value);

            param.dot_re_random = double(app.DotReRandomCheckBox.Value);
            param.snap_dots = 0;

            % Fixed parameters (not exposed in UI)
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

        function updateArenaInfo(app)
            % Compute and display arena geometry information
            if isempty(app.CurrentArenaConfig)
                app.ArenaInfoText.Text = 'N/A';
                return;
            end

            cfg = app.CurrentArenaConfig;
            specs = get_generation_specs(cfg.arena.generation);

            % Check if partial arena (some panel columns not installed)
            if isfield(cfg.arena, 'columns_installed') && ~isempty(cfg.arena.columns_installed)
                numColsInstalled = length(cfg.arena.columns_installed);
                isPartial = numColsInstalled < cfg.arena.num_cols;
            else
                numColsInstalled = cfg.arena.num_cols;
                isPartial = false;
            end

            % Calculate pixel counts for INSTALLED panels
            app.PixelsH = numColsInstalled * specs.pixels_per_panel;
            app.PixelsV = cfg.arena.num_rows * specs.pixels_per_panel;
            numPanelsInstalled = cfg.arena.num_rows * numColsInstalled;

            % Calculate degrees per pixel at equator
            % Full circle (num_cols) spans 360 degrees
            app.DegPerPixelH = 360 / (cfg.arena.num_cols * specs.pixels_per_panel);

            % Display info
            if isPartial
                azCoverage = 360 * (numColsInstalled / cfg.arena.num_cols);
                app.ArenaInfoText.Text = sprintf('%d panels, %dx%d px, %.0f° az, %.2f°/px', ...
                    numPanelsInstalled, app.PixelsH, app.PixelsV, azCoverage, app.DegPerPixelH);
            else
                app.ArenaInfoText.Text = sprintf('%d panels, %dx%d px, %.2f°/px', ...
                    numPanelsInstalled, app.PixelsH, app.PixelsV, app.DegPerPixelH);
            end

            % Update step size spinner step to half the deg/pixel
            app.StepSizeSpinner.Step = app.DegPerPixelH / 2;

            % Initialize step size to 1 pixel (deg/pixel)
            app.StepSizeSpinner.Value = app.DegPerPixelH;
        end

        function updateStepSizeInfo(app)
            % Update step size pixel equivalent display
            if isempty(app.DegPerPixelH) || app.DegPerPixelH == 0
                app.StepSizeInfoText.Text = '';
                return;
            end

            stepDeg = app.StepSizeSpinner.Value;
            pixelsH = stepDeg / app.DegPerPixelH;

            % For vertical, assume similar angular resolution
            % (though it varies with latitude on a cylinder)
            pixelsV = pixelsH;  % Approximation at equator

            app.StepSizeInfoText.Text = sprintf('~%.2f px/step horiz', pixelsH);
        end

        function updateBrightnessLimits(app)
            % Update brightness spinner limits based on grayscale mode
            if strcmp(app.GrayscaleDropDown.Value, 'Binary (1-bit)')
                maxVal = 1;
            else
                maxVal = 15;
            end

            % Update limits and clamp values
            app.BrightnessHighSpinner.Limits = [0 maxVal];
            app.BrightnessLowSpinner.Limits = [0 maxVal];

            % Set defaults based on mode
            if maxVal == 1
                app.BrightnessHighSpinner.Value = min(app.BrightnessHighSpinner.Value, 1);
                app.BrightnessLowSpinner.Value = min(app.BrightnessLowSpinner.Value, 1);
                app.MaskBackgroundLevel = min(app.MaskBackgroundLevel, 1);
                if app.BrightnessHighSpinner.Value == 0
                    app.BrightnessHighSpinner.Value = 1;
                end
            end
        end

        function updateStretchLimits(app)
            % Update stretch spinner limits based on generation and grayscale mode
            % G3: no stretch (disabled)
            % G4/G4.1/G6: binary = max 100, grayscale = max 20

            if isempty(app.CurrentArenaConfig)
                return;
            end

            gen = upper(app.CurrentArenaConfig.arena.generation);

            % G3 has no stretch
            if startsWith(gen, 'G3')
                app.StretchSpinner.Enable = 'off';
                app.StretchSpinner.Value = 0;
                app.StretchLabel.Enable = 'off';
                return;
            end

            % Enable for G4, G4.1, G6
            app.StretchSpinner.Enable = 'on';
            app.StretchLabel.Enable = 'on';

            % Set max based on grayscale mode
            if strcmp(app.GrayscaleDropDown.Value, 'Binary (1-bit)')
                maxStretch = 100;
            else
                maxStretch = 20;
            end

            app.StretchSpinner.Limits = [0 maxStretch];

            % Clamp current value if needed
            if app.StretchSpinner.Value > maxStretch
                app.StretchSpinner.Value = maxStretch;
            end
        end

        function updateParameterStates(app)
            % Enable/disable parameters based on pattern type
            % Parameter usage by pattern type:
            %
            % | Parameter           | SqGrat | SinGrat | Edge | Starfield | Off/On |
            % |---------------------|:------:|:-------:|:----:|:---------:|:------:|
            % | Spatial Frequency   |   ✅   |    ✅   |  ✅  |     ❌    |   ❌   |
            % | Step Size           |   ✅   |    ✅   |  ✅  |     ✅    |   ❌   |
            % | Duty Cycle          |   ✅   |    ❌   |  ❌  |     ❌    |   ❌   |
            % | Motion Type         |   ✅   |    ✅   |  ✅  |     ✅    |   ❌   |
            % | Motion Angle        |   ✅   |    ✅   |  ✅  |     ✅    |   ❌   |
            % | Pole Coordinates    |   ✅   |    ✅   |  ✅  |     ✅    |   ❌   |
            % | Pattern FOV         |   ✅   |    ✅   |  ✅  |     ✅    |   ❌   |
            % | Brightness High     |   ✅   |    ✅   |  ✅  |     ✅    |   ✅   |
            % | Brightness Low      |   ✅   |    ✅   |  ✅  |     ✅    |   ✅   |
            % | Brightness Bkgnd    |   ✅   |    ✅   |  ✅  |     ✅    |   ❌   |
            % | Masks               |   ✅   |    ✅   |  ✅  |     ✅    |   ❌   |
            % | Starfield options   |   ❌   |    ❌   |  ❌  |     ✅    |   ❌   |

            patternType = app.PatternTypeDropDown.Value;

            isSquareGrating = strcmp(patternType, 'Square Grating');
            isSineGrating = strcmp(patternType, 'Sine Grating');
            isEdge = strcmp(patternType, 'Edge');
            isStarfield = strcmp(patternType, 'Starfield');
            isOffOn = strcmp(patternType, 'Off/On');

            isGratingOrEdge = isSquareGrating || isSineGrating || isEdge;
            hasMotion = ~isOffOn;

            % Spatial Frequency: gratings and edge only
            app.SpatialFreqLabel.Enable = isGratingOrEdge;
            app.SpatialFreqSpinner.Enable = isGratingOrEdge;

            % Step Size: all except Off/On
            app.StepSizeLabel.Enable = hasMotion;
            app.StepSizeSpinner.Enable = hasMotion;
            app.StepSizeInfoText.Enable = hasMotion;

            % Duty Cycle: square grating only
            app.DutyCycleLabel.Enable = isSquareGrating;
            app.DutyCycleSpinner.Enable = isSquareGrating;

            % Motion Type: all except Off/On
            app.MotionTypeLabel.Enable = hasMotion;
            app.MotionTypeDropDown.Enable = hasMotion;

            % Pattern FOV: all except Off/On
            app.PatternFOVLabel.Enable = hasMotion;
            app.PatternFOVDropDown.Enable = hasMotion;

            % Motion Angle vs Pole Coordinates visibility depends on FOV mode
            % (matches G4 GUI behavior from popupmenu7_Callback)
            isFullField = strcmp(app.PatternFOVDropDown.Value, 'Full-field');

            % Motion Angle: visible only in Local mode (not full-field)
            motionAngleVisible = hasMotion && ~isFullField;
            app.MotionAngleLabel.Enable = motionAngleVisible;
            app.MotionAngleSpinner.Enable = motionAngleVisible;
            app.MotionAngleLabel.Visible = motionAngleVisible || ~hasMotion;
            app.MotionAngleSpinner.Visible = motionAngleVisible || ~hasMotion;

            % Pole Coordinates: visible only in Full-field mode
            poleVisible = hasMotion && isFullField;
            app.PoleAzimuthLabel.Enable = poleVisible;
            app.PoleAzimuthSpinner.Enable = poleVisible;
            app.PoleElevationLabel.Enable = poleVisible;
            app.PoleElevationSpinner.Enable = poleVisible;
            app.PoleAzimuthLabel.Visible = poleVisible || ~hasMotion;
            app.PoleAzimuthSpinner.Visible = poleVisible || ~hasMotion;
            app.PoleElevationLabel.Visible = poleVisible || ~hasMotion;
            app.PoleElevationSpinner.Visible = poleVisible || ~hasMotion;

            % Arena Pitch: all except Off/On
            app.ArenaPitchLabel.Enable = hasMotion;
            app.ArenaPitchSpinner.Enable = hasMotion;

            % Masks: all except Off/On
            app.MasksHeaderLabel.Enable = hasMotion;
            app.SAMaskCheckBox.Enable = hasMotion;
            app.SAMaskButton.Enable = hasMotion;
            app.LatLongMaskCheckBox.Enable = hasMotion;
            app.LatLongMaskButton.Enable = hasMotion;

            % Starfield options panel: starfield only
            app.StarfieldOptionsPanel.Visible = isStarfield;
        end

        function updatePreview(app)
            % Update the pattern preview
            if isempty(app.Pats)
                return;
            end

            frame = round(app.FrameSlider.Value);
            if frame < 1
                frame = 1;
            elseif frame > app.NumFrames
                frame = app.NumFrames;
            end

            app.CurrentFrame = frame;

            % Get frame data
            frameData = app.Pats(:, :, frame);

            % Check view mode
            viewMode = app.ViewModeDropDown.Value;

            if strcmp(viewMode, 'Mercator')
                % Mercator projection view
                app.renderMercatorView(frameData, frame);
            elseif strcmp(viewMode, 'Mollweide')
                % Mollweide projection view
                app.renderMollweideView(frameData, frame);
            else
                % Grid (pixel) view - default
                cla(app.PreviewAxes);
                imagesc(app.PreviewAxes, frameData);
                colormap(app.PreviewAxes, app.LEDColormap);
                % Set color limits based on grayscale mode
                if strcmp(app.GrayscaleDropDown.Value, 'Binary (1-bit)')
                    app.PreviewAxes.CLim = [0 1];
                else
                    app.PreviewAxes.CLim = [0 15];
                end
                axis(app.PreviewAxes, 'image');
                % Flip Y-axis so row 0 is at bottom (LED numbering convention)
                app.PreviewAxes.YDir = 'normal';
                app.PreviewAxes.XLabel.String = 'Pixel Column';
                app.PreviewAxes.YLabel.String = 'Pixel Row';
                % Keep 1:1 pixel aspect ratio from 'axis image'
                grid(app.PreviewAxes, 'off');
                title(app.PreviewAxes, sprintf('Frame %d / %d (Grid)', frame, app.NumFrames));
            end

            app.FrameLabel.Text = sprintf('Frame: %d / %d', frame, app.NumFrames);
        end

        function renderMercatorView(app, frameData, frame)
            % Render pattern as Mercator (cylindrical) projection
            % Shows pattern mapped to longitude/latitude coordinates

            % Wrap in try-catch to handle hover tooltip race conditions
            try
            if isempty(app.ArenaPhi) || isempty(app.ArenaTheta)
                % Fall back to grid view if no coordinates
                imagesc(app.PreviewAxes, frameData);
                colormap(app.PreviewAxes, app.LEDColormap);
                axis(app.PreviewAxes, 'image');
                title(app.PreviewAxes, sprintf('Frame %d / %d (no coords)', frame, app.NumFrames));
                return;
            end

            % Convert to longitude (degrees) and latitude (degrees)
            % ArenaPhi is azimuthal angle (longitude): -pi to pi
            % ArenaTheta is polar angle (colatitude): 0 to pi
            % Use theta-90 (not 90-theta) to match grid view orientation
            % This matches arena_projection.m line 31
            lon = rad2deg(app.ArenaPhi);
            lat = rad2deg(app.ArenaTheta) - 90;  % Convert colatitude to latitude

            % Get colors for pixels
            colors = app.getPixelColors(frameData);

            % Flatten coordinates
            lonVec = lon(:);
            latVec = lat(:);

            % Get dot size from slider (percentage scaling)
            dotScale = app.DotScaleSlider.Value / 100;
            baseDotSize = 20;
            dotSize = baseDotSize * dotScale;

            % Clear and plot
            cla(app.PreviewAxes);
            scatter(app.PreviewAxes, lonVec, latVec, dotSize, colors, 'filled');

            % Set axis properties using FOV limits centered on arena
            app.PreviewAxes.XLim = [app.LonCenter - app.LonFOV, app.LonCenter + app.LonFOV];
            app.PreviewAxes.YLim = [app.LatCenter - app.LatFOV, app.LatCenter + app.LatFOV];
            app.PreviewAxes.XLabel.String = 'Longitude (deg)';
            app.PreviewAxes.YLabel.String = 'Latitude (deg)';
            % Aspect ratio based on FOV (degrees are equal in both directions)
            app.PreviewAxes.DataAspectRatio = [1 1 1];
            grid(app.PreviewAxes, 'on');
            title(app.PreviewAxes, sprintf('Frame %d / %d (Mercator)', frame, app.NumFrames));
            catch ME
                % Only ignore "Invalid or deleted object" errors from data tip race conditions
                if ~contains(ME.message, 'Invalid or deleted object')
                    rethrow(ME);
                end
            end
        end

        function renderMollweideView(app, frameData, frame)
            % Render pattern as Mollweide (equal-area) projection
            % Shows pattern mapped to an elliptical projection

            % Wrap in try-catch to handle hover tooltip race conditions
            try
            if isempty(app.ArenaPhi) || isempty(app.ArenaTheta)
                % Fall back to grid view if no coordinates
                imagesc(app.PreviewAxes, frameData);
                colormap(app.PreviewAxes, app.LEDColormap);
                axis(app.PreviewAxes, 'image');
                title(app.PreviewAxes, sprintf('Frame %d / %d (no coords)', frame, app.NumFrames));
                return;
            end

            % Get longitude and latitude in radians
            % Use theta - pi/2 (not pi/2 - theta) to match grid view orientation
            lon = app.ArenaPhi;  % Already in radians, -pi to pi
            lat = app.ArenaTheta - pi/2;  % Convert colatitude to latitude in radians

            % Mollweide projection formulas
            % x = (2*sqrt(2)/pi) * lambda * cos(theta)
            % y = sqrt(2) * sin(theta)
            % where theta is found by solving: 2*theta + sin(2*theta) = pi*sin(phi)

            % Compute auxiliary angle theta using Newton-Raphson iteration
            theta = app.computeMollweideTheta(lat);

            % Apply Mollweide projection
            x = (2 * sqrt(2) / pi) * lon .* cos(theta);
            y = sqrt(2) * sin(theta);

            % Convert to degrees for display (scale to match typical range)
            xDeg = rad2deg(x);
            yDeg = rad2deg(y);

            % Get colors for pixels
            colors = app.getPixelColors(frameData);

            % Flatten coordinates
            xVec = xDeg(:);
            yVec = yDeg(:);

            % Get dot size from slider (percentage scaling)
            dotScale = app.DotScaleSlider.Value / 100;
            baseDotSize = 20;
            dotSize = baseDotSize * dotScale;

            % Clear and plot
            cla(app.PreviewAxes);
            scatter(app.PreviewAxes, xVec, yVec, dotSize, colors, 'filled');

            % Set axis properties using FOV limits (same as Mercator)
            % Mollweide projection compresses x-axis, so we need to transform the limits
            % For the FOV boundaries, compute the Mollweide x,y at the lon/lat edges
            xScale = 2 * sqrt(2) / pi;
            yScale = sqrt(2);

            % Compute x limits at equator (lat=0, where x range is maximum)
            xLimMoll = xScale * deg2rad(app.LonFOV);  % At equator, cos(theta)=1
            xLimDeg = rad2deg(xLimMoll);

            % Compute y limits
            latLimRad = deg2rad(app.LatFOV);
            thetaLim = app.computeMollweideTheta(latLimRad);
            yLimMoll = yScale * sin(thetaLim);
            yLimDeg = rad2deg(yLimMoll);

            app.PreviewAxes.XLim = [-xLimDeg, xLimDeg];
            app.PreviewAxes.YLim = [-yLimDeg, yLimDeg];
            app.PreviewAxes.XLabel.String = 'Longitude (deg)';
            app.PreviewAxes.YLabel.String = 'Latitude (deg)';
            app.PreviewAxes.DataAspectRatio = [1 1 1];
            grid(app.PreviewAxes, 'on');
            title(app.PreviewAxes, sprintf('Frame %d / %d (Mollweide)', frame, app.NumFrames));
            catch ME
                % Only ignore "Invalid or deleted object" errors from data tip race conditions
                if ~contains(ME.message, 'Invalid or deleted object')
                    rethrow(ME);
                end
            end
        end

        function theta = computeMollweideTheta(~, lat)
            % Compute auxiliary angle theta for Mollweide projection
            % Solves: 2*theta + sin(2*theta) = pi*sin(lat)
            % using Newton-Raphson iteration

            theta = lat;  % Initial guess
            maxIter = 10;
            tol = 1e-6;

            for iter = 1:maxIter
                f = 2*theta + sin(2*theta) - pi*sin(lat);
                fprime = 2 + 2*cos(2*theta);

                % Avoid division by zero
                fprime(fprime == 0) = eps;

                delta = f ./ fprime;
                theta = theta - delta;

                if max(abs(delta(:))) < tol
                    break;
                end
            end
        end

        function reloadArenaCoordinates(app, handles, ~)
            % Reload arena coordinates after pattern generation
            % Note: We do NOT apply rot180 to coordinates - that transformation
            % is already applied to the pattern data by Pattern_Generator.
            % arena_projection.m uses the same approach: coordinates stay fixed,
            % pattern data is rotated.

            arena_file = fullfile(handles.arena_folder, handles.arena_file);
            try
                arenaData = load(arena_file);
                if isfield(arenaData, 'arena_x') && isfield(arenaData, 'arena_y') && isfield(arenaData, 'arena_z')
                    arena_x = arenaData.arena_x;
                    arena_y = arenaData.arena_y;
                    arena_z = arenaData.arena_z;

                    % Do NOT rotate coordinates - arena_projection.m keeps coordinates fixed
                    % and only rotates the pattern data, which Pattern_Generator already does

                    [app.ArenaPhi, app.ArenaTheta, ~] = cart2sphere(arena_x, arena_y, arena_z);

                    % Compute latitude range from coordinate data
                    latDeg = rad2deg(app.ArenaTheta(:)) - 90;  % Convert colatitude to latitude
                    app.ArenaLatMin = min(latDeg);
                    app.ArenaLatMax = max(latDeg);

                    % Compute longitude range based on partial arena config
                    % For partial arenas, use the YAML config instead of raw coordinates
                    if ~isempty(app.CurrentArenaConfig) && ...
                            isfield(app.CurrentArenaConfig, 'derived') && ...
                            isfield(app.CurrentArenaConfig.derived, 'azimuth_coverage_deg')

                        cfg = app.CurrentArenaConfig;
                        azimuthCoverage = cfg.derived.azimuth_coverage_deg;

                        if azimuthCoverage < 360
                            % Partial arena: center the view at 0° (front)
                            % with coverage extending equally to both sides
                            % Gap is assumed to be behind the fly (at ±180°)
                            halfCoverage = azimuthCoverage / 2;
                            app.ArenaLonMin = -halfCoverage;
                            app.ArenaLonMax = halfCoverage;
                        else
                            % Full 360 arena
                            app.ArenaLonMin = -180;
                            app.ArenaLonMax = 180;
                        end
                    else
                        % No config info: use raw coordinate range
                        lonDeg = rad2deg(app.ArenaPhi(:));
                        app.ArenaLonMin = min(lonDeg);
                        app.ArenaLonMax = max(lonDeg);
                    end

                    % Auto-set FOV based on arena range + 10 degree padding
                    app.initializeFOVFromArena();
                end
            catch
                app.ArenaPhi = [];
                app.ArenaTheta = [];
                % Reset to full range
                app.ArenaLonMin = -180;
                app.ArenaLonMax = 180;
                app.ArenaLatMin = -90;
                app.ArenaLatMax = 90;
            end
        end

        function initializeFOVFromArena(app)
            % Set FOV to fit arena data range with padding
            padding = 10;  % degrees

            % Compute required FOV half-width for longitude
            lonRange = app.ArenaLonMax - app.ArenaLonMin;
            app.LonCenter = (app.ArenaLonMax + app.ArenaLonMin) / 2;
            lonHalfWidth = lonRange / 2 + padding;

            % Compute required FOV half-height for latitude
            latRange = app.ArenaLatMax - app.ArenaLatMin;
            app.LatCenter = (app.ArenaLatMax + app.ArenaLatMin) / 2;
            latHalfHeight = latRange / 2 + padding;

            % Snap to nearest step value
            lonSteps = [30 45 60 90 120 150 180];
            latSteps = [15 30 45 60 75 90];

            % Find smallest step that fits the range
            lonIdx = find(lonSteps >= lonHalfWidth, 1, 'first');
            if isempty(lonIdx)
                lonIdx = length(lonSteps);
            end
            app.LonFOV = lonSteps(lonIdx);

            latIdx = find(latSteps >= latHalfHeight, 1, 'first');
            if isempty(latIdx)
                latIdx = length(latSteps);
            end
            app.LatFOV = latSteps(latIdx);

            % Update UI labels
            app.LonFOVValueLabel.Text = sprintf('±%d°', app.LonFOV);
            app.LatFOVValueLabel.Text = sprintf('±%d°', app.LatFOV);
        end

        function colors = getPixelColors(app, frameData)
            % Get RGB colors for each pixel based on frame data and LED colormap

            % Normalize frame data to 0-1 range
            if strcmp(app.GrayscaleDropDown.Value, 'Binary (1-bit)')
                maxVal = 1;
            else
                maxVal = 15;
            end
            normalizedData = double(frameData) / maxVal;

            % Create RGB colors using LED colormap
            % Map normalized values to colormap indices
            numColors = size(app.LEDColormap, 1);
            colorIndices = round(normalizedData * (numColors - 1)) + 1;
            colorIndices = max(1, min(numColors, colorIndices));

            % Flatten using column-major order (same as (:) operator)
            % This matches how coordinates are flattened in renderMercatorView
            % and how arena_projection.m uses reshape(Pats, [num_pixels 1])
            colorIndicesVec = colorIndices(:);  % Column-major flattening
            colors = app.LEDColormap(colorIndicesVec, :);
        end

        function initColormap(app)
            % Create LED yellow-green colormap (568nm peak)
            % Black (off) to LED green (on)
            n = 256;
            % LED phosphor green: approximately RGB [0.6, 1.0, 0.2] at peak
            app.LEDColormap = zeros(n, 3);
            app.LEDColormap(:,1) = linspace(0, 0.6, n)';   % Red channel
            app.LEDColormap(:,2) = linspace(0, 1.0, n)';   % Green channel
            app.LEDColormap(:,3) = linspace(0, 0.2, n)';   % Blue channel
        end

        function updateSliderTicks(app)
            % Update slider to have discrete ticks for each frame
            if app.NumFrames <= 1
                app.FrameSlider.Limits = [1 2];
                app.FrameSlider.MajorTicks = [1 2];
                app.FrameSlider.MinorTicks = [];
            else
                app.FrameSlider.Limits = [1 app.NumFrames];
                % Show major ticks - limit to reasonable number
                if app.NumFrames <= 20
                    app.FrameSlider.MajorTicks = 1:app.NumFrames;
                else
                    % For many frames, show fewer ticks
                    step = ceil(app.NumFrames / 10);
                    app.FrameSlider.MajorTicks = 1:step:app.NumFrames;
                end
                app.FrameSlider.MinorTicks = [];
            end
        end

        function playTimerCallback(app, ~, ~)
            % Timer callback for playback
            if ~app.IsPlaying || isempty(app.Pats)
                return;
            end

            % Advance frame
            nextFrame = app.CurrentFrame + 1;
            if nextFrame > app.NumFrames
                nextFrame = 1;  % Loop back to start
            end

            app.FrameSlider.Value = nextFrame;
            app.updatePreview();
        end

        function resetPreview(app)
            % Reset preview when pattern parameters change
            % Called when any parameter changes to invalidate the current pattern

            % Stop playback if running
            if app.IsPlaying
                app.IsPlaying = false;
                if ~isempty(app.PlayTimer) && isvalid(app.PlayTimer)
                    stop(app.PlayTimer);
                end
                app.PlayButton.Text = 'Play';
                app.PlayButton.BackgroundColor = [0.3 0.5 0.7];
            end

            % Clear pattern data
            app.Pats = [];
            app.NumFrames = 0;
            app.CurrentFrame = 1;
            app.PatternGenerated = false;

            % Clear the preview axes
            cla(app.PreviewAxes);
            title(app.PreviewAxes, 'Generate pattern to preview');

            % Disable preview controls
            app.FrameSlider.Enable = 'off';
            app.FrameSlider.Value = 1;
            app.FrameSlider.Limits = [1 2];
            app.PlayButton.Enable = 'off';
            app.FPSDropDown.Enable = 'off';
            app.ViewModeDropDown.Enable = 'off';
            app.DotScaleSlider.Enable = 'off';

            % Update frame label
            app.FrameLabel.Text = 'Frame: -/-';

            % Update status
            app.StatusLabel.Text = 'Parameters changed - generate new pattern';
        end

        function enablePreviewControls(app)
            % Enable preview controls after pattern generation
            app.FrameSlider.Enable = 'on';
            app.PlayButton.Enable = 'on';
            app.FPSDropDown.Enable = 'on';
            app.ViewModeDropDown.Enable = 'on';
            app.DotScaleSlider.Enable = 'on';
            app.PatternGenerated = true;
        end

        function lockArena(app)
            % Lock the arena configuration dropdown
            app.ArenaLocked = true;
            app.ArenaConfigDropDown.Enable = 'off';
            app.ChangeArenaButton.Text = 'Change';
            app.ChangeArenaButton.Tooltip = 'Click to change arena configuration';
        end

        function unlockArena(app)
            % Unlock the arena configuration dropdown
            app.ArenaLocked = false;
            app.ArenaConfigDropDown.Enable = 'on';
            app.ChangeArenaButton.Text = 'Lock';
            app.ChangeArenaButton.Tooltip = 'Click to lock arena configuration';
        end
    end

    % Callbacks
    methods (Access = private)

        function ArenaConfigDropDownValueChanged(app, ~)
            app.loadArenaConfig();
            % Reset preview when arena changes
            app.resetPreview();
        end

        function ChangeArenaButtonPushed(app, ~)
            % Toggle arena lock state
            if app.ArenaLocked
                % Warn user if pattern exists
                if app.PatternGenerated
                    answer = uiconfirm(app.UIFigure, ...
                        'Changing arena will reset the current pattern. Continue?', ...
                        'Change Arena', ...
                        'Options', {'Change', 'Cancel'}, ...
                        'DefaultOption', 2, ...
                        'CancelOption', 2);
                    if ~strcmp(answer, 'Change')
                        return;
                    end
                end
                app.unlockArena();
            else
                app.lockArena();
            end
        end

        function GenerateButtonPushed(app, ~)
            app.StatusLabel.Text = 'Generating pattern...';
            drawnow;

            try
                % Build handles struct
                handles = app.buildHandlesStruct();

                % Generate pattern
                [app.Pats, true_step_size, rot180] = Pattern_Generator(handles);

                % Reload arena coordinates for projection views
                % Pattern_Generator may regenerate arena file with pitch changes
                % Also need to apply rot180 to match pattern orientation
                app.reloadArenaCoordinates(handles, rot180);

                app.NumFrames = size(app.Pats, 3);
                app.CurrentFrame = 1;

                % Update slider with discrete ticks
                app.updateSliderTicks();
                app.FrameSlider.Value = 1;

                % Enable preview controls and update preview
                app.enablePreviewControls();
                app.updatePreview();

                % Lock arena config after successful generation
                app.lockArena();

                app.StatusLabel.Text = sprintf('Generated %d frames (step: %.3f deg)', ...
                    app.NumFrames, rad2deg(true_step_size));

            catch ME
                app.StatusLabel.Text = sprintf('Error: %s', ME.message);
            end
        end

        function SaveButtonPushed(app, ~)
            if isempty(app.Pats)
                app.StatusLabel.Text = 'Generate a pattern first';
                return;
            end

            % Build default save path following pattern library convention:
            % patterns/{arena_name}/pattern_name.mat
            arenaName = '';
            patternDir = app.maDisplayToolsRoot;
            if ~isempty(app.CurrentArenaConfig)
                arenaName = app.CurrentArenaConfig.name;
                patternDir = fullfile(app.maDisplayToolsRoot, 'patterns', arenaName);

                % Create directory if it doesn't exist
                if ~isfolder(patternDir)
                    try
                        mkdir(patternDir);
                        app.StatusLabel.Text = sprintf('Created directory: patterns/%s', arenaName);
                    catch
                        patternDir = app.maDisplayToolsRoot;  % Fall back to root
                    end
                end
            end

            % Determine generation for dialog title
            gen = '';
            if ~isempty(app.CurrentArenaConfig)
                gen = upper(app.CurrentArenaConfig.arena.generation);
            end
            isG6 = startsWith(gen, 'G6');

            % Build descriptive default filename based on pattern parameters
            patType = lower(strrep(app.PatternTypeDropDown.Value, ' ', '_'));
            spatFreq = app.SpatialFreqSpinner.Value;
            stepSize = app.StepSizeSpinner.Value;

            if strcmp(app.PatternTypeDropDown.Value, 'Starfield')
                defaultFilename = sprintf('%s_%ddots', patType, app.DotCountSpinner.Value);
            elseif strcmp(app.PatternTypeDropDown.Value, 'Off/On')
                defaultFilename = 'off_on';
            elseif strcmp(app.PatternTypeDropDown.Value, 'Edge')
                defaultFilename = sprintf('%s_%.0fstep', patType, stepSize);
            else
                defaultFilename = sprintf('%s_%.0fdeg_%.0fstep', patType, spatFreq, stepSize);
            end
            defaultPath = fullfile(patternDir, defaultFilename);

            if isG6
                dialogTitle = 'Save Pattern - Enter base name (creates .pat)';
            else
                dialogTitle = 'Save Pattern - Enter base name (creates .mat + .pat)';
            end
            % Use wildcard filter to allow any filename (we just want the base name)
            [filename, pathname] = uiputfile('*.*', dialogTitle, defaultPath);
            if isequal(filename, 0)
                return;
            end

            app.StatusLabel.Text = 'Saving pattern...';
            drawnow;

            try
                handles = app.buildHandlesStruct();
                param = handles.param;

                % Set stretch from UI (same value for all frames)
                param.stretch = app.StretchSpinner.Value * ones(app.NumFrames, 1);

                % Pass arena config for G6 patterns (enables proper panel_mask for partial arenas)
                if ~isempty(app.CurrentArenaConfig)
                    param.arena_config = app.CurrentArenaConfig;
                end

                % Extract base name (strip any extension user might have added)
                [~, patName, ~] = fileparts(filename);

                save_pattern(app.Pats, param, pathname, patName, [], ...
                    fullfile(handles.arena_folder, handles.arena_file));

                % Show what was saved (G6 = only .pat, G4 = both files)
                patFile = sprintf('%s_%s.pat', patName, gen);
                if isG6
                    app.StatusLabel.Text = sprintf('Saved: %s', patFile);
                else
                    matFile = sprintf('%s_%s.mat', patName, gen);
                    app.StatusLabel.Text = sprintf('Saved: %s + %s', matFile, patFile);
                end

            catch ME
                app.StatusLabel.Text = 'Save error - see dialog';
                % Show full error in dialog (supports multi-line)
                uialert(app.UIFigure, ME.message, 'Save Error', 'Icon', 'error');
            end
        end

        function ExportScriptButtonPushed(app, ~)
            % Export current settings to a MATLAB script
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
            fprintf(fid, 'param.pattern_type = ''%s'';\n', lower(app.PatternTypeDropDown.Value));
            fprintf(fid, 'param.motion_type = ''%s'';\n', lower(app.MotionTypeDropDown.Value));
            fprintf(fid, 'param.pattern_fov = ''full-field'';\n');
            fprintf(fid, 'param.spat_freq = deg2rad(%.1f);  %% degrees\n', app.SpatialFreqSpinner.Value);
            fprintf(fid, 'param.step_size = deg2rad(%.1f);  %% degrees\n', app.StepSizeSpinner.Value);

            if strcmp(app.GrayscaleDropDown.Value, 'Binary (1-bit)')
                fprintf(fid, 'param.gs_val = 1;  %% binary\n');
            else
                fprintf(fid, 'param.gs_val = 4;  %% grayscale\n');
            end

            fprintf(fid, 'param.generation = ''%s'';\n', app.GenerationText.Text);
            fprintf(fid, '\n%% Default parameters (adjust as needed)\n');
            fprintf(fid, 'param.arena_pitch = 0;\n');
            fprintf(fid, 'param.levels = [15 0 0];\n');
            fprintf(fid, 'param.pole_coord = [0 -pi/2];  %% [longitude, latitude] in radians\n');
            fprintf(fid, 'param.motion_angle = 0;\n');
            fprintf(fid, 'param.duty_cycle = 50;\n');
            fprintf(fid, 'param.sa_mask = [0 0 pi 0];\n');
            fprintf(fid, 'param.long_lat_mask = [-pi pi -pi/2 pi/2 0];\n');
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
            fprintf(fid, '[Pats, true_step_size, rot180] = Pattern_Generator(handles);\n');
            fprintf(fid, 'fprintf(''Generated %%d frames\\n'', size(Pats, 3));\n');

            fprintf(fid, '\n%% Save pattern (uncomment to use)\n');
            fprintf(fid, '%% param.stretch = zeros(size(Pats, 3), 1);\n');
            fprintf(fid, '%% param.ID = get_pattern_ID(''./output'');\n');
            fprintf(fid, '%% save_pattern(Pats, param, ''./output'', ''my_pattern'');\n');

            fclose(fid);

            app.StatusLabel.Text = sprintf('Exported: %s', filename);
            edit(filepath);
        end

        function FrameSliderValueChanged(app, ~)
            % Snap to nearest integer
            app.FrameSlider.Value = round(app.FrameSlider.Value);
            app.updatePreview();
        end

        function StepSizeSpinnerValueChanged(app, ~)
            % Update step size info when value changes
            app.updateStepSizeInfo();
            % Also reset preview since step size affects pattern
            app.parameterChanged();
        end

        function parameterChanged(app)
            % Called when any pattern parameter changes
            % Resets preview to indicate pattern needs regeneration
            if app.PatternGenerated
                app.resetPreview();
            end
        end

        function GrayscaleDropDownValueChanged(app, ~)
            % Update brightness and stretch limits when grayscale mode changes
            app.updateBrightnessLimits();
            app.updateStretchLimits();
            app.parameterChanged();
        end

        function PatternTypeDropDownValueChanged(app, ~)
            % Update parameter enable states when pattern type changes
            app.updateParameterStates();
            app.parameterChanged();
        end

        function PatternFOVDropDownValueChanged(app)
            % Update parameter visibility when FOV mode changes
            % In G4 GUI: Full-field shows pole coords, Local shows motion angle
            app.updateParameterStates();
            app.parameterChanged();
        end

        function SAMaskCheckBoxChanged(app, ~)
            % Callback for SA mask checkbox change
            % Both masks can be used together (applied sequentially)
            app.parameterChanged();
        end

        function LatLongMaskCheckBoxChanged(app, ~)
            % Callback for Lat/Long mask checkbox change
            % Both masks can be used together (applied sequentially)
            app.parameterChanged();
        end

        function SAMaskButtonPushed(app, ~)
            % Open dialog to configure solid angle mask
            if isempty(app.SAMaskParams)
                app.SAMaskParams = [0 0 deg2rad(30) 0];  % Default: center, 30° radius
            end

            % Get max brightness based on grayscale mode
            if strcmp(app.GrayscaleDropDown.Value, 'Binary (1-bit)')
                maxBg = 1;
            else
                maxBg = 15;
            end

            % Create simple input dialog
            prompt = {'Azimuth (deg):', 'Elevation (deg):', 'Radius (deg):', ...
                     'Invert (0 or 1):', sprintf('Background brightness (0-%d):', maxBg)};
            dlgtitle = 'Solid Angle Mask';
            dims = [1 40];
            definput = {num2str(rad2deg(app.SAMaskParams(1))), ...
                       num2str(rad2deg(app.SAMaskParams(2))), ...
                       num2str(rad2deg(app.SAMaskParams(3))), ...
                       num2str(app.SAMaskParams(4)), ...
                       num2str(app.MaskBackgroundLevel)};
            answer = inputdlg(prompt, dlgtitle, dims, definput);

            if ~isempty(answer)
                app.SAMaskParams = [deg2rad(str2double(answer{1})), ...
                                   deg2rad(str2double(answer{2})), ...
                                   deg2rad(str2double(answer{3})), ...
                                   str2double(answer{4})];
                app.MaskBackgroundLevel = max(0, min(maxBg, str2double(answer{5})));
                app.SAMaskCheckBox.Value = true;
                app.StatusLabel.Text = sprintf('SA Mask: az=%.1f°, el=%.1f°, r=%.1f°, bg=%d', ...
                    rad2deg(app.SAMaskParams(1)), rad2deg(app.SAMaskParams(2)), ...
                    rad2deg(app.SAMaskParams(3)), app.MaskBackgroundLevel);
                app.parameterChanged();
            end
        end

        function LatLongMaskButtonPushed(app, ~)
            % Open dialog to configure lat/long mask
            if isempty(app.LatLongMaskParams)
                app.LatLongMaskParams = [deg2rad(-45) deg2rad(45) deg2rad(-30) deg2rad(30) 0];  % Default
            end

            % Get max brightness based on grayscale mode
            if strcmp(app.GrayscaleDropDown.Value, 'Binary (1-bit)')
                maxBg = 1;
            else
                maxBg = 15;
            end

            % Create simple input dialog
            prompt = {'Longitude min (deg):', 'Longitude max (deg):', ...
                     'Latitude min (deg):', 'Latitude max (deg):', ...
                     'Invert (0 or 1):', sprintf('Background brightness (0-%d):', maxBg)};
            dlgtitle = 'Lat/Long Mask';
            dims = [1 40];
            definput = {num2str(rad2deg(app.LatLongMaskParams(1))), ...
                       num2str(rad2deg(app.LatLongMaskParams(2))), ...
                       num2str(rad2deg(app.LatLongMaskParams(3))), ...
                       num2str(rad2deg(app.LatLongMaskParams(4))), ...
                       num2str(app.LatLongMaskParams(5)), ...
                       num2str(app.MaskBackgroundLevel)};
            answer = inputdlg(prompt, dlgtitle, dims, definput);

            if ~isempty(answer)
                app.LatLongMaskParams = [deg2rad(str2double(answer{1})), ...
                                        deg2rad(str2double(answer{2})), ...
                                        deg2rad(str2double(answer{3})), ...
                                        deg2rad(str2double(answer{4})), ...
                                        str2double(answer{5})];
                app.MaskBackgroundLevel = max(0, min(maxBg, str2double(answer{6})));
                app.LatLongMaskCheckBox.Value = true;
                app.StatusLabel.Text = sprintf('Lat/Long Mask: lon=[%.1f,%.1f]°, lat=[%.1f,%.1f]°, bg=%d', ...
                    rad2deg(app.LatLongMaskParams(1)), rad2deg(app.LatLongMaskParams(2)), ...
                    rad2deg(app.LatLongMaskParams(3)), rad2deg(app.LatLongMaskParams(4)), ...
                    app.MaskBackgroundLevel);
                app.parameterChanged();
            end
        end

        function PlayButtonPushed(app, ~)
            if isempty(app.Pats)
                app.StatusLabel.Text = 'Generate a pattern first';
                return;
            end

            if app.IsPlaying
                % Stop playback
                app.IsPlaying = false;
                if ~isempty(app.PlayTimer) && isvalid(app.PlayTimer)
                    stop(app.PlayTimer);
                end
                app.PlayButton.Text = 'Play';
                app.PlayButton.BackgroundColor = [0.3 0.5 0.7];
            else
                % Start playback
                app.IsPlaying = true;
                app.PlayButton.Text = 'Stop';
                app.PlayButton.BackgroundColor = [0.7 0.3 0.3];

                % Get FPS from dropdown
                fpsStr = app.FPSDropDown.Value;
                fps = str2double(regexprep(fpsStr, ' fps', ''));

                % Create or update timer
                if ~isempty(app.PlayTimer) && isvalid(app.PlayTimer)
                    stop(app.PlayTimer);
                    delete(app.PlayTimer);
                end

                app.PlayTimer = timer(...
                    'ExecutionMode', 'fixedRate', ...
                    'Period', 1/fps, ...
                    'TimerFcn', @(~,~) app.playTimerCallback());
                start(app.PlayTimer);
            end
        end

        function FPSDropDownValueChanged(app, ~)
            % Update timer period if playing
            if app.IsPlaying && ~isempty(app.PlayTimer) && isvalid(app.PlayTimer)
                fpsStr = app.FPSDropDown.Value;
                fps = str2double(regexprep(fpsStr, ' fps', ''));
                stop(app.PlayTimer);
                app.PlayTimer.Period = 1/fps;
                start(app.PlayTimer);
            end
        end

        function ViewModeDropDownValueChanged(app, ~)
            % Update preview when view mode changes
            % Show/hide dot scale and FOV controls based on view mode
            viewMode = app.ViewModeDropDown.Value;
            isProjection = strcmp(viewMode, 'Mercator') || strcmp(viewMode, 'Mollweide');

            % Dot scale controls
            app.DotScaleLabel.Visible = isProjection;
            app.DotScaleSlider.Visible = isProjection;
            app.DotScaleValueLabel.Visible = isProjection;

            % FOV controls
            app.FOVLabel.Visible = isProjection;
            app.LonZoomButton.Visible = isProjection;
            app.LonFOVValueLabel.Visible = isProjection;
            app.LatZoomButton.Visible = isProjection;
            app.LatFOVValueLabel.Visible = isProjection;
            app.FOVResetButton.Visible = isProjection;

            app.updatePreview();
        end

        function DotScaleSliderValueChanged(app, ~)
            % Update dot scale value label and refresh preview
            app.DotScaleValueLabel.Text = sprintf('%.0f%%', app.DotScaleSlider.Value);
            app.updatePreview();
        end

        function zoomInFOV(app, axis)
            % Zoom in (decrease FOV) for projection views
            % axis: 'lon' or 'lat'

            % FOV steps (descending for zoom in)
            lonSteps = [180 150 120 90 60 45 30];
            latSteps = [90 75 60 45 30 15];

            if strcmp(axis, 'lon')
                % Find next smaller step
                nextIdx = find(lonSteps < app.LonFOV, 1, 'first');
                if ~isempty(nextIdx)
                    app.LonFOV = lonSteps(nextIdx);
                    app.LonFOVValueLabel.Text = sprintf('±%d°', app.LonFOV);
                end
            else
                nextIdx = find(latSteps < app.LatFOV, 1, 'first');
                if ~isempty(nextIdx)
                    app.LatFOV = latSteps(nextIdx);
                    app.LatFOVValueLabel.Text = sprintf('±%d°', app.LatFOV);
                end
            end

            app.updatePreview();
        end

        function resetFOV(app)
            % Reset FOV to full view (±180° lon, ±90° lat)
            app.LonFOV = 180;
            app.LatFOV = 90;
            app.LonCenter = 0;
            app.LatCenter = 0;
            app.LonFOVValueLabel.Text = '±180°';
            app.LatFOVValueLabel.Text = '±90°';
            app.updatePreview();
        end

        function showInfoDialog(app)
            % Show reference information dialog with coordinate diagrams
            % Non-modal so user can reference while using the main GUI
            infoFig = uifigure('Name', 'Pattern Generator Reference', ...
                'Position', [200 100 700 800], ...
                'WindowStyle', 'normal');

            % Create scrollable panel
            scroll = uipanel(infoFig, 'Position', [10 10 680 780], ...
                'Scrollable', 'on');

            % Create text area with monospace font for ASCII diagrams
            infoText = uitextarea(scroll, ...
                'Position', [10 10 650 3000], ...
                'Editable', 'off', ...
                'FontName', 'Courier New', ...
                'FontSize', 11);
            infoText.Value = app.getInfoContent();
        end

        function content = getInfoContent(~)
            % Return help content as cell array of strings
            content = {
                '╔══════════════════════════════════════════════════════════════╗';
                '║           PATTERN GENERATOR REFERENCE                        ║';
                '╚══════════════════════════════════════════════════════════════╝';
                '';
                '┌──────────────────────────────────────────────────────────────┐';
                '│ ARENA COORDINATE SYSTEM                                      │';
                '└──────────────────────────────────────────────────────────────┘';
                '';
                '        TOP VIEW                      SIDE VIEW';
                '        ────────                      ─────────';
                '           +Y (front)                    +Z (up)';
                '            ↑                             ↑';
                '            │                             │';
                '    ┌───────┼───────┐               ┌─────┼─────┐';
                '    │       │       │               │     │     │';
                '-X ←┼───────●───────┼→ +X      -Y ←─┼─────●─────┼─→ +Y';
                '(L) │    (fly)      │ (R)           │  (fly)    │ (front)';
                '    │       │       │               │     │     │';
                '    └───────┼───────┘               └─────┼─────┘';
                '            │                             │';
                '            ↓                             ↓';
                '           -Y (back)                    -Z (down)';
                '';
                '    ● = fly position (center of arena)';
                '    Arena wraps around as a cylinder';
                '';
                '┌──────────────────────────────────────────────────────────────┐';
                '│ SPHERICAL COORDINATES                                        │';
                '└──────────────────────────────────────────────────────────────┘';
                '';
                'LONGITUDE (φ): Horizontal angle      LATITUDE (θ): Vertical angle';
                '───────────────────────────────      ─────────────────────────────';
                '        -90° (left)                        +90° (up/dorsal)';
                '            ↑                                   ↑';
                '    -180° ←─┼─→ 0° (front)                 0° ──┼── horizon';
                '  (behind)  │                                   │';
                '            ↓                                   ↓';
                '        +90° (right)                      -90° (down/ventral)';
                '';
                '┌──────────────────────────────────────────────────────────────┐';
                '│ PATTERN PARAMETERS                                           │';
                '└──────────────────────────────────────────────────────────────┘';
                '';
                'SPATIAL FREQUENCY: Pattern wavelength in degrees';
                '  30° = wide bars     │██████│      │██████│';
                '  10° = narrow bars   │██│  │██│  │██│  │██│';
                '';
                'STEP SIZE: Motion per frame (smaller = more frames, smoother)';
                '  Example: 3°/frame with 30° spatial freq → 10 frames per cycle';
                '';
                'DUTY CYCLE: Ratio of bright to dark (square grating only)';
                '  50%  ████████░░░░░░░░  (equal width bars)';
                '  75%  ████████████░░░░  (wide bright, narrow dark)';
                '  25%  ████░░░░░░░░░░░░  (narrow bright, wide dark)';
                '';
                'BRIGHTNESS LEVELS (4-bit mode: 0-15, 1-bit mode: 0-1)';
                '  Bright Level: brightness of light bars/regions';
                '  Dark Level:   brightness of dark bars/regions';
                '';
                '┌──────────────────────────────────────────────────────────────┐';
                '│ POLE POSITION & PATTERN ORIENTATION                          │';
                '└──────────────────────────────────────────────────────────────┘';
                '';
                'The POLE defines the axis of symmetry for the pattern.';
                'Only visible in Full-field mode (Local mode uses mask center).';
                '';
                'POLE AT (0°, -90°) = below          POLE AT (90°, 0°) = right';
                'Creates HORIZONTAL gratings         Creates VERTICAL gratings';
                '';
                '     ════════════════                   ║  ║  ║  ║  ║  ║';
                '     ════════════════                   ║  ║  ║  ║  ║  ║';
                '     ════════════════   ← bars         ║  ║  ║  ║  ║  ║  ← bars';
                '     ════════════════                   ║  ║  ║  ║  ║  ║';
                '            ↓                                   →';
                '         POLE                                POLE';
                '    (beneath fly)                      (to fly''s right)';
                '';
                'MOTION TYPES:';
                '  Rotation:    Pattern circles around the pole axis';
                '  Translation: Pattern moves perpendicular to pole axis';
                '  Expansion:   Pattern radiates outward from pole';
                '';
                'MOTION ANGLE (Local mode only):';
                '  Direction of pattern motion, 0° = leftward, 90° = downward';
                '';
                'ARENA PITCH: Tilts entire coordinate system forward/backward';
                '  Use when arena is physically mounted at an angle';
                '';
                '┌──────────────────────────────────────────────────────────────┐';
                '│ MASKS                                                        │';
                '└──────────────────────────────────────────────────────────────┘';
                '';
                'SOLID ANGLE MASK: Circular region';
                '  - Azimuth:   center horizontal angle (-180° to 180°)';
                '  - Elevation: center vertical angle (-90° to 90°)';
                '  - Radius:    angular radius of visible region';
                '  - Invert:    show OUTSIDE the circle instead';
                '';
                'LAT/LONG MASK: Rectangular region';
                '  - Longitude min/max: horizontal bounds';
                '  - Latitude min/max:  vertical bounds';
                '  - Invert:    show OUTSIDE the rectangle instead';
                '';
                'Both masks can be enabled simultaneously (applied sequentially).';
                '';
                '┌──────────────────────────────────────────────────────────────┐';
                '│ VIEW MODES                                                   │';
                '└──────────────────────────────────────────────────────────────┘';
                '';
                'GRID (Pixels):  Raw pixel array (columns × rows)';
                '                Best for checking exact pixel values';
                '';
                'MERCATOR:       Cylindrical projection (longitude × latitude)';
                '                Best for seeing horizontal structure';
                '                ┌────────────────┐';
                '                │████████████████│';
                '                │                │';
                '                │████████████████│';
                '                └────────────────┘';
                '';
                'MOLLWEIDE:      Equal-area elliptical projection';
                '                Best for seeing relative sizes correctly';
                '                   ╭──────────────╮';
                '                  ╱████████████████╲';
                '                 │                  │';
                '                  ╲████████████████╱';
                '                   ╰──────────────╯';
                '';
                '┌──────────────────────────────────────────────────────────────┐';
                '│ STARFIELD OPTIONS                                            │';
                '└──────────────────────────────────────────────────────────────┘';
                '';
                'Dot Count:     Number of random dots (1-1000)';
                'Dot Radius:    Angular size of each dot in degrees';
                'Dot Size:      Static (fixed size) or Distance-relative';
                'Occlusion:     How overlapping dots combine';
                '               - Closest: front dot wins';
                '               - Sum: add brightness';
                '               - Mean: average brightness';
                'Dot Level:     Fixed brightness, random spread, or random binary';
                'Re-randomize:  Generate new positions each frame';
                '';
                '═══════════════════════════════════════════════════════════════';
                };
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

            % Initialize colormap and playback state
            app.initColormap();
            app.IsPlaying = false;
            app.PlayTimer = [];
            app.PatternGenerated = false;

            % Initialize mask parameters to defaults (no mask)
            app.SAMaskParams = [];
            app.LatLongMaskParams = [];

            % Initialize arena configs
            app.scanArenaConfigs();
            if ~isempty(app.ArenaConfigs)
                app.loadArenaConfig();
            end

            % Update parameter states based on initial pattern type
            app.updateParameterStates();

            % Initialize preview controls in disabled state
            app.FrameSlider.Enable = 'off';
            app.PlayButton.Enable = 'off';
            app.FPSDropDown.Enable = 'off';
            app.ViewModeDropDown.Enable = 'off';
            app.DotScaleSlider.Enable = 'off';
            title(app.PreviewAxes, 'Generate pattern to preview');

            % Register the app
            registerApp(app, app.UIFigure);

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            % Clean up timer
            if ~isempty(app.PlayTimer) && isvalid(app.PlayTimer)
                stop(app.PlayTimer);
                delete(app.PlayTimer);
            end
            delete(app.UIFigure);
        end
    end

    % Component creation
    methods (Access = private)

        function createComponents(app)
            % Create UIFigure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 50 1350 900];  % Taller window, moved down
            app.UIFigure.Name = 'Pattern Generator';

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure, [1 2]);
            app.GridLayout.ColumnWidth = {'1x', '2x'};

            % Create Left Panel (Controls) with scroll
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Title = 'Parameters';
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;
            app.LeftPanel.Scrollable = 'on';

            leftGrid = uigridlayout(app.LeftPanel, [28 4]);
            leftGrid.RowHeight = repmat({25}, 1, 28);
            leftGrid.ColumnWidth = {'1x', '1.5x', 55, 30};  % Label, Control, Change button, Info button
            leftGrid.Padding = [10 10 10 10];
            leftGrid.RowSpacing = 5;

            row = 1;

            % === Arena Section ===
            % Arena Config with Change and Info buttons
            app.ArenaConfigLabel = uilabel(leftGrid);
            app.ArenaConfigLabel.Text = 'Arena Config:';
            app.ArenaConfigLabel.Layout.Row = row;
            app.ArenaConfigLabel.Layout.Column = 1;

            app.ArenaConfigDropDown = uidropdown(leftGrid);
            app.ArenaConfigDropDown.Items = {'Loading...'};
            app.ArenaConfigDropDown.ValueChangedFcn = @(~,~) app.ArenaConfigDropDownValueChanged();
            app.ArenaConfigDropDown.Layout.Row = row;
            app.ArenaConfigDropDown.Layout.Column = 2;
            app.ArenaConfigDropDown.Enable = 'off';  % Locked by default

            app.ChangeArenaButton = uibutton(leftGrid, 'push');
            app.ChangeArenaButton.Text = 'Change';
            app.ChangeArenaButton.Tooltip = 'Click to change arena configuration';
            app.ChangeArenaButton.ButtonPushedFcn = @(~,~) app.ChangeArenaButtonPushed();
            app.ChangeArenaButton.Layout.Row = row;
            app.ChangeArenaButton.Layout.Column = 3;

            app.InfoButton = uibutton(leftGrid, 'push');
            app.InfoButton.Text = char(9432);  % i Unicode info symbol
            app.InfoButton.ButtonPushedFcn = @(~,~) app.showInfoDialog();
            app.InfoButton.Layout.Row = row;
            app.InfoButton.Layout.Column = 4;
            row = row + 1;

            % Generation (read-only)
            app.GenerationLabel = uilabel(leftGrid);
            app.GenerationLabel.Text = 'Generation:';
            app.GenerationLabel.Layout.Row = row;
            app.GenerationLabel.Layout.Column = 1;

            app.GenerationText = uilabel(leftGrid);
            app.GenerationText.Text = 'N/A';
            app.GenerationText.FontWeight = 'bold';
            app.GenerationText.Layout.Row = row;
            app.GenerationText.Layout.Column = [2 4];
            row = row + 1;

            % Arena Info (read-only)
            app.ArenaInfoLabel = uilabel(leftGrid);
            app.ArenaInfoLabel.Text = 'Arena:';
            app.ArenaInfoLabel.Layout.Row = row;
            app.ArenaInfoLabel.Layout.Column = 1;

            app.ArenaInfoText = uilabel(leftGrid);
            app.ArenaInfoText.Text = '';
            app.ArenaInfoText.FontSize = 10;
            app.ArenaInfoText.FontColor = [0.4 0.4 0.4];
            app.ArenaInfoText.Layout.Row = row;
            app.ArenaInfoText.Layout.Column = [2 4];
            row = row + 1;

            % === Pattern Section ===
            % Pattern Type
            app.PatternTypeLabel = uilabel(leftGrid);
            app.PatternTypeLabel.Text = 'Pattern Type:';
            app.PatternTypeLabel.Layout.Row = row;
            app.PatternTypeLabel.Layout.Column = 1;

            app.PatternTypeDropDown = uidropdown(leftGrid);
            app.PatternTypeDropDown.Items = {'Square Grating', 'Sine Grating', 'Edge', 'Starfield', 'Off/On'};
            app.PatternTypeDropDown.Value = 'Square Grating';
            app.PatternTypeDropDown.ValueChangedFcn = @(~,~) app.PatternTypeDropDownValueChanged();
            app.PatternTypeDropDown.Layout.Row = row;
            app.PatternTypeDropDown.Layout.Column = [2 4];
            row = row + 1;

            % Motion Type
            app.MotionTypeLabel = uilabel(leftGrid);
            app.MotionTypeLabel.Text = 'Motion Type:';
            app.MotionTypeLabel.Layout.Row = row;
            app.MotionTypeLabel.Layout.Column = 1;

            app.MotionTypeDropDown = uidropdown(leftGrid);
            app.MotionTypeDropDown.Items = {'Rotation', 'Translation', 'Expansion-Contraction'};
            app.MotionTypeDropDown.Value = 'Rotation';
            app.MotionTypeDropDown.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.MotionTypeDropDown.Layout.Row = row;
            app.MotionTypeDropDown.Layout.Column = [2 4];
            row = row + 1;

            % Pattern FOV
            app.PatternFOVLabel = uilabel(leftGrid);
            app.PatternFOVLabel.Text = 'Pattern FOV:';
            app.PatternFOVLabel.Layout.Row = row;
            app.PatternFOVLabel.Layout.Column = 1;

            app.PatternFOVDropDown = uidropdown(leftGrid);
            app.PatternFOVDropDown.Items = {'Full-field', 'Local (mask-centered)'};
            app.PatternFOVDropDown.Value = 'Full-field';
            app.PatternFOVDropDown.ValueChangedFcn = @(~,~) app.PatternFOVDropDownValueChanged();
            app.PatternFOVDropDown.Layout.Row = row;
            app.PatternFOVDropDown.Layout.Column = [2 4];
            row = row + 1;

            % Spatial Frequency
            app.SpatialFreqLabel = uilabel(leftGrid);
            app.SpatialFreqLabel.Text = 'Spatial Freq (deg):';
            app.SpatialFreqLabel.Layout.Row = row;
            app.SpatialFreqLabel.Layout.Column = 1;

            app.SpatialFreqSpinner = uispinner(leftGrid);
            app.SpatialFreqSpinner.Limits = [1 360];
            app.SpatialFreqSpinner.Value = 30;
            app.SpatialFreqSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.SpatialFreqSpinner.Layout.Row = row;
            app.SpatialFreqSpinner.Layout.Column = [2 4];
            row = row + 1;

            % Step Size
            app.StepSizeLabel = uilabel(leftGrid);
            app.StepSizeLabel.Text = 'Step Size (deg):';
            app.StepSizeLabel.Layout.Row = row;
            app.StepSizeLabel.Layout.Column = 1;

            app.StepSizeSpinner = uispinner(leftGrid);
            app.StepSizeSpinner.Limits = [0.1 30];
            app.StepSizeSpinner.Value = 3;
            app.StepSizeSpinner.Step = 0.5;
            app.StepSizeSpinner.ValueChangedFcn = @(~,~) app.StepSizeSpinnerValueChanged();
            app.StepSizeSpinner.Layout.Row = row;
            app.StepSizeSpinner.Layout.Column = [2 4];
            row = row + 1;

            % Step Size Info
            app.StepSizeInfoText = uilabel(leftGrid);
            app.StepSizeInfoText.Text = '';
            app.StepSizeInfoText.FontSize = 10;
            app.StepSizeInfoText.FontColor = [0.3 0.5 0.3];
            app.StepSizeInfoText.HorizontalAlignment = 'right';
            app.StepSizeInfoText.Layout.Row = row;
            app.StepSizeInfoText.Layout.Column = [1 3];
            row = row + 1;

            % Stretch (frame timing)
            app.StretchLabel = uilabel(leftGrid);
            app.StretchLabel.Text = 'Stretch:';
            app.StretchLabel.Layout.Row = row;
            app.StretchLabel.Layout.Column = 1;

            app.StretchSpinner = uispinner(leftGrid);
            app.StretchSpinner.Limits = [0 100];
            app.StretchSpinner.Value = 0;
            app.StretchSpinner.Step = 1;
            app.StretchSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.StretchSpinner.Layout.Row = row;
            app.StretchSpinner.Layout.Column = [2 4];
            row = row + 1;

            % Duty Cycle
            app.DutyCycleLabel = uilabel(leftGrid);
            app.DutyCycleLabel.Text = 'Duty Cycle (%):';
            app.DutyCycleLabel.Layout.Row = row;
            app.DutyCycleLabel.Layout.Column = 1;

            app.DutyCycleSpinner = uispinner(leftGrid);
            app.DutyCycleSpinner.Limits = [1 99];
            app.DutyCycleSpinner.Value = 50;
            app.DutyCycleSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.DutyCycleSpinner.Layout.Row = row;
            app.DutyCycleSpinner.Layout.Column = [2 4];
            row = row + 1;

            % === Brightness Section ===
            % Grayscale
            app.GrayscaleLabel = uilabel(leftGrid);
            app.GrayscaleLabel.Text = 'Grayscale:';
            app.GrayscaleLabel.Layout.Row = row;
            app.GrayscaleLabel.Layout.Column = 1;

            app.GrayscaleDropDown = uidropdown(leftGrid);
            app.GrayscaleDropDown.Items = {'Grayscale (4-bit)', 'Binary (1-bit)'};
            app.GrayscaleDropDown.Value = 'Grayscale (4-bit)';
            app.GrayscaleDropDown.ValueChangedFcn = @(~,~) app.GrayscaleDropDownValueChanged();
            app.GrayscaleDropDown.Layout.Row = row;
            app.GrayscaleDropDown.Layout.Column = [2 4];
            row = row + 1;

            % Brightness High
            app.BrightnessHighLabel = uilabel(leftGrid);
            app.BrightnessHighLabel.Text = 'Bright Level:';
            app.BrightnessHighLabel.Layout.Row = row;
            app.BrightnessHighLabel.Layout.Column = 1;

            app.BrightnessHighSpinner = uispinner(leftGrid);
            app.BrightnessHighSpinner.Limits = [0 15];
            app.BrightnessHighSpinner.Value = 15;
            app.BrightnessHighSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.BrightnessHighSpinner.Layout.Row = row;
            app.BrightnessHighSpinner.Layout.Column = [2 4];
            row = row + 1;

            % Brightness Low
            app.BrightnessLowLabel = uilabel(leftGrid);
            app.BrightnessLowLabel.Text = 'Dark Level:';
            app.BrightnessLowLabel.Layout.Row = row;
            app.BrightnessLowLabel.Layout.Column = 1;

            app.BrightnessLowSpinner = uispinner(leftGrid);
            app.BrightnessLowSpinner.Limits = [0 15];
            app.BrightnessLowSpinner.Value = 0;
            app.BrightnessLowSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.BrightnessLowSpinner.Layout.Row = row;
            app.BrightnessLowSpinner.Layout.Column = [2 4];
            row = row + 1;

            % === Advanced Controls Section ===
            % Motion Angle
            app.MotionAngleLabel = uilabel(leftGrid);
            app.MotionAngleLabel.Text = 'Motion Angle (deg):';
            app.MotionAngleLabel.Layout.Row = row;
            app.MotionAngleLabel.Layout.Column = 1;

            app.MotionAngleSpinner = uispinner(leftGrid);
            app.MotionAngleSpinner.Limits = [0 360];
            app.MotionAngleSpinner.Value = 0;
            app.MotionAngleSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.MotionAngleSpinner.Layout.Row = row;
            app.MotionAngleSpinner.Layout.Column = [2 4];
            row = row + 1;

            % Pole Longitude (matches G4 GUI "pole longitude")
            app.PoleAzimuthLabel = uilabel(leftGrid);
            app.PoleAzimuthLabel.Text = 'Pole Longitude (deg):';
            app.PoleAzimuthLabel.Layout.Row = row;
            app.PoleAzimuthLabel.Layout.Column = 1;

            app.PoleAzimuthSpinner = uispinner(leftGrid);
            app.PoleAzimuthSpinner.Limits = [-180 180];
            app.PoleAzimuthSpinner.Value = 0;
            app.PoleAzimuthSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.PoleAzimuthSpinner.Layout.Row = row;
            app.PoleAzimuthSpinner.Layout.Column = [2 4];
            row = row + 1;

            % Pole Latitude (matches G4 GUI "pole latitude")
            app.PoleElevationLabel = uilabel(leftGrid);
            app.PoleElevationLabel.Text = 'Pole Latitude (deg):';
            app.PoleElevationLabel.Layout.Row = row;
            app.PoleElevationLabel.Layout.Column = 1;

            app.PoleElevationSpinner = uispinner(leftGrid);
            app.PoleElevationSpinner.Limits = [-90 90];
            app.PoleElevationSpinner.Value = -90;  % Default matches G4 GUI
            app.PoleElevationSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.PoleElevationSpinner.Layout.Row = row;
            app.PoleElevationSpinner.Layout.Column = [2 4];
            row = row + 1;

            % Arena Pitch
            app.ArenaPitchLabel = uilabel(leftGrid);
            app.ArenaPitchLabel.Text = 'Arena Pitch (deg):';
            app.ArenaPitchLabel.Layout.Row = row;
            app.ArenaPitchLabel.Layout.Column = 1;

            app.ArenaPitchSpinner = uispinner(leftGrid);
            app.ArenaPitchSpinner.Limits = [-90 90];
            app.ArenaPitchSpinner.Value = 0;
            app.ArenaPitchSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.ArenaPitchSpinner.Layout.Row = row;
            app.ArenaPitchSpinner.Layout.Column = [2 4];
            row = row + 1;

            % === Masks Section ===
            app.MasksHeaderLabel = uilabel(leftGrid);
            app.MasksHeaderLabel.Text = '─── Masks ───';
            app.MasksHeaderLabel.FontWeight = 'bold';
            app.MasksHeaderLabel.FontColor = [0.3 0.3 0.5];
            app.MasksHeaderLabel.HorizontalAlignment = 'center';
            app.MasksHeaderLabel.Layout.Row = row;
            app.MasksHeaderLabel.Layout.Column = [1 3];
            row = row + 1;

            % Solid Angle Mask
            app.SAMaskCheckBox = uicheckbox(leftGrid);
            app.SAMaskCheckBox.Text = 'Solid Angle Mask';
            app.SAMaskCheckBox.Value = false;
            app.SAMaskCheckBox.ValueChangedFcn = @(~,~) app.SAMaskCheckBoxChanged();
            app.SAMaskCheckBox.Layout.Row = row;
            app.SAMaskCheckBox.Layout.Column = 1;

            app.SAMaskButton = uibutton(leftGrid, 'push');
            app.SAMaskButton.Text = 'Configure...';
            app.SAMaskButton.ButtonPushedFcn = @(~,~) app.SAMaskButtonPushed();
            app.SAMaskButton.Layout.Row = row;
            app.SAMaskButton.Layout.Column = [2 4];
            row = row + 1;

            % Lat/Long Mask
            app.LatLongMaskCheckBox = uicheckbox(leftGrid);
            app.LatLongMaskCheckBox.Text = 'Lat/Long Mask';
            app.LatLongMaskCheckBox.Value = false;
            app.LatLongMaskCheckBox.ValueChangedFcn = @(~,~) app.LatLongMaskCheckBoxChanged();
            app.LatLongMaskCheckBox.Layout.Row = row;
            app.LatLongMaskCheckBox.Layout.Column = 1;

            app.LatLongMaskButton = uibutton(leftGrid, 'push');
            app.LatLongMaskButton.Text = 'Configure...';
            app.LatLongMaskButton.ButtonPushedFcn = @(~,~) app.LatLongMaskButtonPushed();
            app.LatLongMaskButton.Layout.Row = row;
            app.LatLongMaskButton.Layout.Column = [2 4];
            row = row + 1;

            % === Buttons Section ===
            row = row + 1;  % Spacer

            app.GenerateButton = uibutton(leftGrid, 'push');
            app.GenerateButton.Text = 'Generate';
            app.GenerateButton.ButtonPushedFcn = @(~,~) app.GenerateButtonPushed();
            app.GenerateButton.Layout.Row = row;
            app.GenerateButton.Layout.Column = [1 3];
            app.GenerateButton.BackgroundColor = [0.3 0.6 0.3];
            app.GenerateButton.FontColor = [1 1 1];
            row = row + 1;

            app.SaveButton = uibutton(leftGrid, 'push');
            app.SaveButton.Text = 'Save Pattern...';
            app.SaveButton.ButtonPushedFcn = @(~,~) app.SaveButtonPushed();
            app.SaveButton.Layout.Row = row;
            app.SaveButton.Layout.Column = [1 3];
            row = row + 1;

            app.ExportScriptButton = uibutton(leftGrid, 'push');
            app.ExportScriptButton.Text = 'Export Script...';
            app.ExportScriptButton.ButtonPushedFcn = @(~,~) app.ExportScriptButtonPushed();
            app.ExportScriptButton.Layout.Row = row;
            app.ExportScriptButton.Layout.Column = [1 3];
            row = row + 1;

            % Status
            app.StatusLabel = uilabel(leftGrid);
            app.StatusLabel.Text = 'Ready';
            app.StatusLabel.Layout.Row = row;
            app.StatusLabel.Layout.Column = [1 3];

            % === Right Panel (Preview + Starfield Options) ===
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Title = 'Preview';
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;

            rightGrid = uigridlayout(app.RightPanel, [7 5]);
            rightGrid.RowHeight = {'1x', 60, 30, 30, 40, 30, 'fit'};  % Row 5 taller for slider labels
            rightGrid.ColumnWidth = {'fit', '1x', 80, 80, 50};
            rightGrid.Padding = [20 10 20 10];
            rightGrid.RowSpacing = 8;

            % Preview axes
            app.PreviewAxes = uiaxes(rightGrid);
            app.PreviewAxes.Layout.Row = 1;
            app.PreviewAxes.Layout.Column = [1 5];
            % Keep data tips enabled for pattern inspection
            title(app.PreviewAxes, 'No pattern generated');

            % Frame slider
            app.FrameSlider = uislider(rightGrid);
            app.FrameSlider.Limits = [1 10];
            app.FrameSlider.Value = 1;
            app.FrameSlider.MajorTicks = 1:10;
            app.FrameSlider.MinorTicks = [];
            app.FrameSlider.ValueChangedFcn = @(~,~) app.FrameSliderValueChanged();
            app.FrameSlider.Layout.Row = 2;
            app.FrameSlider.Layout.Column = [1 5];

            % Playback controls row
            app.FrameLabel = uilabel(rightGrid);
            app.FrameLabel.Text = 'Frame: - / -';
            app.FrameLabel.HorizontalAlignment = 'left';
            app.FrameLabel.Layout.Row = 3;
            app.FrameLabel.Layout.Column = 1;

            app.PlayButton = uibutton(rightGrid, 'push');
            app.PlayButton.Text = 'Play';
            app.PlayButton.ButtonPushedFcn = @(~,~) app.PlayButtonPushed();
            app.PlayButton.Layout.Row = 3;
            app.PlayButton.Layout.Column = 3;
            app.PlayButton.BackgroundColor = [0.3 0.5 0.7];
            app.PlayButton.FontColor = [1 1 1];

            app.FPSDropDown = uidropdown(rightGrid);
            app.FPSDropDown.Items = {'1 fps', '5 fps', '10 fps', '20 fps'};
            app.FPSDropDown.Value = '5 fps';
            app.FPSDropDown.ValueChangedFcn = @(~,~) app.FPSDropDownValueChanged();
            app.FPSDropDown.Layout.Row = 3;
            app.FPSDropDown.Layout.Column = [4 5];

            % View mode controls row
            app.ViewModeLabel = uilabel(rightGrid);
            app.ViewModeLabel.Text = 'View:';
            app.ViewModeLabel.HorizontalAlignment = 'right';
            app.ViewModeLabel.Layout.Row = 4;
            app.ViewModeLabel.Layout.Column = 1;

            app.ViewModeDropDown = uidropdown(rightGrid);
            app.ViewModeDropDown.Items = {'Grid (Pixels)', 'Mercator', 'Mollweide'};
            app.ViewModeDropDown.Value = 'Grid (Pixels)';
            app.ViewModeDropDown.ValueChangedFcn = @(~,~) app.ViewModeDropDownValueChanged();
            app.ViewModeDropDown.Layout.Row = 4;
            app.ViewModeDropDown.Layout.Column = [2 5];

            % Dot scale controls (for projection views) - row 5
            app.DotScaleLabel = uilabel(rightGrid);
            app.DotScaleLabel.Text = 'Dot Size:';
            app.DotScaleLabel.HorizontalAlignment = 'right';
            app.DotScaleLabel.Visible = 'off';
            app.DotScaleLabel.Layout.Row = 5;
            app.DotScaleLabel.Layout.Column = 1;

            app.DotScaleSlider = uislider(rightGrid);
            app.DotScaleSlider.Limits = [25 400];
            app.DotScaleSlider.Value = 100;
            app.DotScaleSlider.MajorTicks = [25 50 75 100 125 150 200 400];
            app.DotScaleSlider.MajorTickLabels = {'25', '50', '75', '100', '125', '150', '200', '400'};
            app.DotScaleSlider.MinorTicks = [];
            app.DotScaleSlider.Visible = 'off';
            app.DotScaleSlider.ValueChangedFcn = @(~,~) app.DotScaleSliderValueChanged();
            app.DotScaleSlider.Layout.Row = 5;
            app.DotScaleSlider.Layout.Column = [2 4];

            app.DotScaleValueLabel = uilabel(rightGrid);
            app.DotScaleValueLabel.Text = '100%';
            app.DotScaleValueLabel.HorizontalAlignment = 'left';
            app.DotScaleValueLabel.Visible = 'off';
            app.DotScaleValueLabel.Layout.Row = 5;
            app.DotScaleValueLabel.Layout.Column = 5;

            % === FOV controls (for projection views) - row 6 ===
            % Simplified: zoom in buttons only + reset
            % Layout: [Reset] [Lon+ ±180°] [Lat+ ±90°]
            app.FOVLabel = uilabel(rightGrid);
            app.FOVLabel.Text = 'Zoom:';
            app.FOVLabel.HorizontalAlignment = 'right';
            app.FOVLabel.Visible = 'off';
            app.FOVLabel.Layout.Row = 6;
            app.FOVLabel.Layout.Column = 1;

            % Create a sub-grid for zoom controls
            zoomGrid = uigridlayout(rightGrid, [1 5]);
            zoomGrid.RowHeight = {'1x'};
            zoomGrid.ColumnWidth = {50, 45, 50, 45, 50};
            zoomGrid.Padding = [0 0 0 0];
            zoomGrid.ColumnSpacing = 5;
            zoomGrid.Layout.Row = 6;
            zoomGrid.Layout.Column = [2 5];

            % Longitude zoom button + value
            app.LonZoomButton = uibutton(zoomGrid, 'push');
            app.LonZoomButton.Text = 'Lon+';
            app.LonZoomButton.ButtonPushedFcn = @(~,~) app.zoomInFOV('lon');
            app.LonZoomButton.Visible = 'off';
            app.LonZoomButton.Layout.Row = 1;
            app.LonZoomButton.Layout.Column = 1;

            app.LonFOVValueLabel = uilabel(zoomGrid);
            app.LonFOVValueLabel.Text = '±180°';
            app.LonFOVValueLabel.HorizontalAlignment = 'center';
            app.LonFOVValueLabel.Visible = 'off';
            app.LonFOVValueLabel.Layout.Row = 1;
            app.LonFOVValueLabel.Layout.Column = 2;

            % Latitude zoom button + value
            app.LatZoomButton = uibutton(zoomGrid, 'push');
            app.LatZoomButton.Text = 'Lat+';
            app.LatZoomButton.ButtonPushedFcn = @(~,~) app.zoomInFOV('lat');
            app.LatZoomButton.Visible = 'off';
            app.LatZoomButton.Layout.Row = 1;
            app.LatZoomButton.Layout.Column = 3;

            app.LatFOVValueLabel = uilabel(zoomGrid);
            app.LatFOVValueLabel.Text = '±90°';
            app.LatFOVValueLabel.HorizontalAlignment = 'center';
            app.LatFOVValueLabel.Visible = 'off';
            app.LatFOVValueLabel.Layout.Row = 1;
            app.LatFOVValueLabel.Layout.Column = 4;

            % Reset button
            app.FOVResetButton = uibutton(zoomGrid, 'push');
            app.FOVResetButton.Text = 'Reset';
            app.FOVResetButton.ButtonPushedFcn = @(~,~) app.resetFOV();
            app.FOVResetButton.Visible = 'off';
            app.FOVResetButton.Layout.Row = 1;
            app.FOVResetButton.Layout.Column = 5;

            % === Starfield Options Panel (conditional) ===
            app.StarfieldOptionsPanel = uipanel(rightGrid);
            app.StarfieldOptionsPanel.Title = 'Starfield Options';
            app.StarfieldOptionsPanel.Layout.Row = 7;
            app.StarfieldOptionsPanel.Layout.Column = [1 5];
            app.StarfieldOptionsPanel.Visible = 'off';  % Hidden by default

            starGrid = uigridlayout(app.StarfieldOptionsPanel, [3 4]);
            starGrid.RowHeight = {25, 25, 25};
            starGrid.ColumnWidth = {'fit', '1x', 'fit', '1x'};
            starGrid.Padding = [10 5 10 5];

            % Dot Count
            app.DotCountLabel = uilabel(starGrid);
            app.DotCountLabel.Text = 'Dot Count:';
            app.DotCountLabel.Layout.Row = 1;
            app.DotCountLabel.Layout.Column = 1;

            app.DotCountSpinner = uispinner(starGrid);
            app.DotCountSpinner.Limits = [1 1000];
            app.DotCountSpinner.Value = 100;
            app.DotCountSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.DotCountSpinner.Layout.Row = 1;
            app.DotCountSpinner.Layout.Column = 2;

            % Dot Radius
            app.DotRadiusLabel = uilabel(starGrid);
            app.DotRadiusLabel.Text = 'Dot Radius (deg):';
            app.DotRadiusLabel.Layout.Row = 1;
            app.DotRadiusLabel.Layout.Column = 3;

            app.DotRadiusSpinner = uispinner(starGrid);
            app.DotRadiusSpinner.Limits = [0.1 45];
            app.DotRadiusSpinner.Value = 5;
            app.DotRadiusSpinner.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.DotRadiusSpinner.Layout.Row = 1;
            app.DotRadiusSpinner.Layout.Column = 4;

            % Dot Size
            app.DotSizeLabel = uilabel(starGrid);
            app.DotSizeLabel.Text = 'Dot Size:';
            app.DotSizeLabel.Layout.Row = 2;
            app.DotSizeLabel.Layout.Column = 1;

            app.DotSizeDropDown = uidropdown(starGrid);
            app.DotSizeDropDown.Items = {'Static', 'Distance-relative'};
            app.DotSizeDropDown.Value = 'Static';
            app.DotSizeDropDown.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.DotSizeDropDown.Layout.Row = 2;
            app.DotSizeDropDown.Layout.Column = 2;

            % Dot Occlusion
            app.DotOcclusionLabel = uilabel(starGrid);
            app.DotOcclusionLabel.Text = 'Occlusion:';
            app.DotOcclusionLabel.Layout.Row = 2;
            app.DotOcclusionLabel.Layout.Column = 3;

            app.DotOcclusionDropDown = uidropdown(starGrid);
            app.DotOcclusionDropDown.Items = {'Closest', 'Sum', 'Mean'};
            app.DotOcclusionDropDown.Value = 'Closest';
            app.DotOcclusionDropDown.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.DotOcclusionDropDown.Layout.Row = 2;
            app.DotOcclusionDropDown.Layout.Column = 4;

            % Dot Level
            app.DotLevelLabel = uilabel(starGrid);
            app.DotLevelLabel.Text = 'Dot Level:';
            app.DotLevelLabel.Layout.Row = 3;
            app.DotLevelLabel.Layout.Column = 1;

            app.DotLevelDropDown = uidropdown(starGrid);
            app.DotLevelDropDown.Items = {'Fixed', 'Random spread', 'Random binary'};
            app.DotLevelDropDown.Value = 'Fixed';
            app.DotLevelDropDown.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.DotLevelDropDown.Layout.Row = 3;
            app.DotLevelDropDown.Layout.Column = 2;

            % Re-randomize checkbox
            app.DotReRandomCheckBox = uicheckbox(starGrid);
            app.DotReRandomCheckBox.Text = 'Re-randomize each frame';
            app.DotReRandomCheckBox.Value = true;
            app.DotReRandomCheckBox.ValueChangedFcn = @(~,~) app.parameterChanged();
            app.DotReRandomCheckBox.Layout.Row = 3;
            app.DotReRandomCheckBox.Layout.Column = [3 4];

            % Show the figure
            app.UIFigure.Visible = 'on';
        end
    end
end

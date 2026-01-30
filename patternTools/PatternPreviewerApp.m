classdef PatternPreviewerApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                   matlab.ui.Figure
        GridLayout                 matlab.ui.container.GridLayout

        % Menus
        FileMenu                   matlab.ui.container.Menu
        LoadPatternMenu            matlab.ui.container.Menu
        ExportGIFMenu              matlab.ui.container.Menu
        ExportVideoMenu            matlab.ui.container.Menu
        ToolsMenu                  matlab.ui.container.Menu
        PatternGeneratorMenu       matlab.ui.container.Menu
        PatternCombinerMenu        matlab.ui.container.Menu
        DrawingAppMenu             matlab.ui.container.Menu

        % Main content area
        PreviewAxes                matlab.ui.control.UIAxes
        FrameSlider                matlab.ui.control.Slider
        FrameSliderLabel           matlab.ui.control.Label

        % Left column - Pattern Info
        LeftPanel                  matlab.ui.container.Panel
        FileLabel                  matlab.ui.control.Label
        FileValueLabel             matlab.ui.control.Label
        FormatLabel                matlab.ui.control.Label
        FormatValueLabel           matlab.ui.control.Label
        SizeLabel                  matlab.ui.control.Label
        SizeValueLabel             matlab.ui.control.Label
        PanelsLabel                matlab.ui.control.Label
        PanelsValueLabel           matlab.ui.control.Label
        FramesLabel                matlab.ui.control.Label
        FramesValueLabel           matlab.ui.control.Label
        GrayscaleLabel             matlab.ui.control.Label
        GrayscaleValueLabel        matlab.ui.control.Label
        CurrentFrameLabel          matlab.ui.control.Label
        CurrentFrameValueLabel     matlab.ui.control.Label
        StretchLabel               matlab.ui.control.Label
        StretchValueLabel          matlab.ui.control.Label

        % Middle column - Histogram
        MiddlePanel                matlab.ui.container.Panel
        HistogramTextArea          matlab.ui.control.TextArea

        % Right column - Controls
        RightPanel                 matlab.ui.container.Panel
        PlayButton                 matlab.ui.control.Button
        FPSLabel                   matlab.ui.control.Label
        FPSDropDown                matlab.ui.control.DropDown
        ViewModeLabel              matlab.ui.control.Label
        ViewModeDropDown           matlab.ui.control.DropDown
        DotScaleLabel              matlab.ui.control.Label
        DotScaleSlider             matlab.ui.control.Slider
        DotScaleValueLabel         matlab.ui.control.Label
        LonZoomButton              matlab.ui.control.Button
        LonFOVValueLabel           matlab.ui.control.Label
        LatZoomButton              matlab.ui.control.Button
        LatFOVValueLabel           matlab.ui.control.Label
        FOVResetButton             matlab.ui.control.Button
        ArenaInfoLabel             matlab.ui.control.Label  % Shows auto-detected arena
        ShowPanelOutlinesCheckbox  matlab.ui.control.CheckBox
        ShowPanelIDsCheckbox       matlab.ui.control.CheckBox

        % Unsaved warning label (shown in red when pattern is unsaved)
        UnsavedWarningLabel        matlab.ui.control.Label

        % Status bar
        StatusLabel                matlab.ui.control.Label
    end

    properties (Access = private)
        maDisplayToolsRoot         % Root path of maDisplayTools
        Pats                       % Pattern data (rows x cols x frames)
        Stretch                    % Stretch values (NumPatsY x NumPatsX)
        NumFrames                  % Total number of frames
        CurrentFrame               % Current frame index
        gs_val                     % Grayscale value (2 or 16)
        NumPatsX                   % Frames in X dimension
        NumPatsY                   % Frames in Y dimension

        PlayTimer                  % Timer for playback
        IsPlaying                  % Playback state
        LEDColormap                % Green LED colormap

        % Arena coordinates for projections
        ArenaPhi                   % Azimuthal angle (longitude) for each pixel
        ArenaTheta                 % Polar angle (colatitude) for each pixel
        ArenaConfigs               % Cell array of arena config paths
        CurrentArenaConfig         % Currently loaded arena config

        % FOV limits for projection views
        LonFOV = 180               % Longitude FOV half-width in degrees
        LatFOV = 90                % Latitude FOV half-height in degrees
        LonCenter = 0              % Longitude center in degrees
        LatCenter = 0              % Latitude center in degrees

        CurrentFilePath            % Path to currently loaded file
        PixelsPerPanel = 20        % Pixels per panel (G3=8, G4=16, G6=20)
        IsUnsaved = false          % Whether current pattern is unsaved (from combiner/generator)
    end

    methods (Access = private)

        function initColormap(app)
            % Initialize the LED-style green colormap
            n = 256;
            app.LEDColormap = zeros(n, 3);
            for i = 1:n
                intensity = (i - 1) / (n - 1);
                app.LEDColormap(i, :) = [0, intensity, 0];
            end
        end

        function scanArenaConfigs(app)
            % Scan for available arena YAML configs (used for auto-detection)
            configDir = fullfile(app.maDisplayToolsRoot, 'configs', 'arenas');

            if ~isfolder(configDir)
                app.ArenaConfigs = {};
                return;
            end

            yamlFiles = dir(fullfile(configDir, '*.yaml'));
            if isempty(yamlFiles)
                app.ArenaConfigs = {};
                return;
            end

            % Build list of config paths
            app.ArenaConfigs = cell(length(yamlFiles), 1);
            for i = 1:length(yamlFiles)
                app.ArenaConfigs{i} = fullfile(configDir, yamlFiles(i).name);
            end
        end

        function loadArenaConfig(app, configPath)
            % Load arena config and generate coordinates for projections
            try
                cfg = load_arena_config(configPath);
                app.CurrentArenaConfig = cfg;

                % Get generation specs
                specs = get_generation_specs(cfg.arena.generation);

                Psize = specs.pixels_per_panel;
                Pcols = cfg.derived.num_columns_installed;
                Prows = cfg.arena.num_rows;
                Pcircle = cfg.arena.num_cols;

                rot180 = false;
                if isfield(cfg.arena, 'orientation') && strcmp(cfg.arena.orientation, 'inverted')
                    rot180 = true;
                end

                model = 'smooth';  % 'smooth' or 'poly' - smooth is standard
                rotations = [0 0 0];
                translations = [0 0 0];
                if isfield(cfg.arena, 'rotations')
                    rotations = cfg.arena.rotations;
                end
                if isfield(cfg.arena, 'translations')
                    translations = cfg.arena.translations;
                end

                % Generate arena coordinates
                arena_folder = fullfile(app.maDisplayToolsRoot, 'configs', 'arenas');
                arena_file = fullfile(arena_folder, 'arena_parameters.mat');

                arena_coordinates(Psize, Pcols, Prows, Pcircle, rot180, model, rotations, translations, arena_file);

                % Load the generated coordinates
                arenaData = load(arena_file);
                if isfield(arenaData, 'arena_x') && isfield(arenaData, 'arena_y') && isfield(arenaData, 'arena_z')
                    [app.ArenaPhi, app.ArenaTheta, ~] = cart2sphere(arenaData.arena_x, arenaData.arena_y, arenaData.arena_z);

                    % Compute latitude range
                    latDeg = rad2deg(app.ArenaTheta(:)) - 90;
                    app.LatFOV = max(abs(latDeg)) + 5;

                    % Compute longitude range
                    if isfield(cfg, 'derived') && isfield(cfg.derived, 'azimuth_coverage_deg') && cfg.derived.azimuth_coverage_deg < 360
                        halfCoverage = cfg.derived.azimuth_coverage_deg / 2;
                        app.LonFOV = halfCoverage + 10;
                    else
                        app.LonFOV = 180;
                    end
                else
                    app.ArenaPhi = [];
                    app.ArenaTheta = [];
                    app.StatusLabel.Text = 'Arena file missing x/y/z coordinates';
                end

            catch ME
                % Store error message - will be shown in ArenaInfoLabel by inferArenaFromPath
                app.ArenaPhi = [];
                app.ArenaTheta = [];
                % Rethrow so inferArenaFromPath can capture the error message
                rethrow(ME);
            end
        end

        function generateArenaCoordinatesFromConfig(app, cfg)
            % Generate arena coordinates from config struct (for projection views)
            % This is used when arena config is passed directly (not loaded from file)

            % Get generation specs
            specs = get_generation_specs(cfg.arena.generation);

            Psize = specs.pixels_per_panel;
            Pcols = cfg.derived.num_columns_installed;
            Prows = cfg.arena.num_rows;
            Pcircle = cfg.arena.num_cols;

            rot180 = false;
            if isfield(cfg.arena, 'orientation') && strcmp(cfg.arena.orientation, 'inverted')
                rot180 = true;
            end

            model = 'smooth';  % 'smooth' or 'poly' - smooth is standard
            rotations = [0 0 0];
            translations = [0 0 0];
            if isfield(cfg.arena, 'rotations')
                rotations = cfg.arena.rotations;
            end
            if isfield(cfg.arena, 'translations')
                translations = cfg.arena.translations;
            end

            % Generate arena coordinates
            arena_folder = fullfile(app.maDisplayToolsRoot, 'configs', 'arenas');
            arena_file = fullfile(arena_folder, 'arena_parameters.mat');

            arena_coordinates(Psize, Pcols, Prows, Pcircle, rot180, model, rotations, translations, arena_file);

            % Load the generated coordinates
            arenaData = load(arena_file);
            if isfield(arenaData, 'arena_x') && isfield(arenaData, 'arena_y') && isfield(arenaData, 'arena_z')
                [app.ArenaPhi, app.ArenaTheta, ~] = cart2sphere(arenaData.arena_x, arenaData.arena_y, arenaData.arena_z);

                % Compute latitude range
                latDeg = rad2deg(app.ArenaTheta(:)) - 90;
                app.LatFOV = max(abs(latDeg)) + 5;

                % Compute longitude range
                if isfield(cfg, 'derived') && isfield(cfg.derived, 'azimuth_coverage_deg') && cfg.derived.azimuth_coverage_deg < 360
                    halfCoverage = cfg.derived.azimuth_coverage_deg / 2;
                    app.LonFOV = halfCoverage + 10;
                else
                    app.LonFOV = 180;
                end
            else
                app.ArenaPhi = [];
                app.ArenaTheta = [];
                error('Arena file missing x/y/z coordinates');
            end
        end

        function inferArenaFromPath(app, filepath)
            % Try to infer arena config from pattern file path
            % Patterns are stored in patterns/{arena_name}/
            try
                [folder, ~, ~] = fileparts(filepath);
                [~, arenaName] = fileparts(folder);

                % Look for matching arena config
                configPath = fullfile(app.maDisplayToolsRoot, 'configs', 'arenas', [arenaName '.yaml']);

                if exist(configPath, 'file')
                    try
                        app.loadArenaConfig(configPath);
                        % Check if loadArenaConfig succeeded (ArenaPhi should be non-empty)
                        if ~isempty(app.ArenaPhi)
                            app.ArenaInfoLabel.Text = sprintf('Arena: %s (ready)', arenaName);
                        else
                            app.ArenaInfoLabel.Text = sprintf('Arena: %s (coords empty)', arenaName);
                        end
                    catch ME
                        app.ArenaPhi = [];
                        app.ArenaTheta = [];
                        % Show detailed error in ArenaInfoLabel
                        shortMsg = strtok(ME.message, newline);
                        if length(shortMsg) > 40
                            shortMsg = [shortMsg(1:37) '...'];
                        end
                        app.ArenaInfoLabel.Text = sprintf('Arena error: %s', shortMsg);
                    end
                else
                    % No matching config found - show what we tried
                    app.ArenaPhi = [];
                    app.ArenaTheta = [];
                    app.ArenaInfoLabel.Text = sprintf('Arena: no config for "%s"', arenaName);
                end
            catch ME
                app.ArenaPhi = [];
                app.ArenaTheta = [];
                app.ArenaInfoLabel.Text = sprintf('Arena: path error - %s', ME.message);
            end
        end

        function bringAllPatternAppsToFront(app)
            % Find all pattern app figures and bring to front
            % This ensures all pattern apps stay visible after file dialogs
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

        function loadPatternFile(app, filepath)
            % Load a .pat file
            try
                app.StatusLabel.Text = 'Loading pattern...';
                drawnow;

                % Clear unsaved flag when loading from file
                app.IsUnsaved = false;
                app.updateUnsavedWarning();

                [frames, meta] = maDisplayTools.load_pat(filepath);

                % Store pattern data
                % frames is (NumPatsY, NumPatsX, rows, cols)
                % Reshape to (rows, cols, NumFrames) for easier access
                app.NumPatsX = meta.NumPatsX;
                app.NumPatsY = meta.NumPatsY;
                app.NumFrames = meta.NumPatsX * meta.NumPatsY;

                rows = meta.rows;
                cols = meta.cols;
                app.Pats = zeros(rows, cols, app.NumFrames, 'uint8');

                frame_idx = 1;
                for y = 1:meta.NumPatsY
                    for x = 1:meta.NumPatsX
                        app.Pats(:, :, frame_idx) = squeeze(frames(y, x, :, :));
                        frame_idx = frame_idx + 1;
                    end
                end

                % Store stretch values (also flatten to 1D)
                app.Stretch = zeros(app.NumFrames, 1);
                frame_idx = 1;
                for y = 1:meta.NumPatsY
                    for x = 1:meta.NumPatsX
                        app.Stretch(frame_idx) = meta.stretch(y, x);
                        frame_idx = frame_idx + 1;
                    end
                end

                app.gs_val = (meta.vmax == 15) * 14 + 2;  % 16 if grayscale, 2 if binary
                app.CurrentFrame = 1;
                app.CurrentFilePath = filepath;

                % Try to infer arena from file path (patterns stored in patterns/{arena_name}/)
                app.inferArenaFromPath(filepath);

                % Update UI
                [~, filename, ext] = fileparts(filepath);
                app.FileValueLabel.Text = [filename, ext];
                app.SizeValueLabel.Text = sprintf('%d x %d px', rows, cols);
                app.FramesValueLabel.Text = sprintf('%d', app.NumFrames);

                % Display format info from header
                if isfield(meta, 'format')
                    app.FormatValueLabel.Text = meta.format;
                else
                    app.FormatValueLabel.Text = 'Unknown';
                end

                % Display panel grid dimensions and compute pixels per panel
                if isfield(meta, 'panel_rows') && isfield(meta, 'panel_cols')
                    % Check if G6 partial arena (has full_grid_cols field)
                    if isfield(meta, 'full_grid_cols') && meta.full_grid_cols > meta.panel_cols
                        % G6 partial arena: show installed vs full grid
                        app.PanelsValueLabel.Text = sprintf('%d x %dof%d', ...
                            meta.panel_rows, meta.panel_cols, meta.full_grid_cols);
                    else
                        app.PanelsValueLabel.Text = sprintf('%d x %d', meta.panel_rows, meta.panel_cols);
                    end
                    % Compute pixels per panel from total rows / panel rows
                    if meta.panel_rows > 0
                        app.PixelsPerPanel = meta.rows / meta.panel_rows;
                    else
                        app.PixelsPerPanel = 20;  % Default
                    end
                else
                    app.PanelsValueLabel.Text = '--';
                    app.PixelsPerPanel = 20;  % Default for unknown formats
                end

                if app.gs_val == 16
                    app.GrayscaleValueLabel.Text = '4-bit (0-15)';
                else
                    app.GrayscaleValueLabel.Text = 'Binary (0-1)';
                end

                % Setup frame slider
                app.setupFrameSlider();

                % Enable controls
                app.PlayButton.Enable = 'on';
                app.ExportGIFMenu.Enable = 'on';
                app.ExportVideoMenu.Enable = 'on';

                % Update preview
                app.updatePreview();

                app.StatusLabel.Text = sprintf('Loaded: %s (%d frames, %s)', ...
                    [filename, ext], app.NumFrames, app.GrayscaleValueLabel.Text);

                % Bring all pattern apps to front (prevent MATLAB workspace from stealing focus)
                app.bringAllPatternAppsToFront();

            catch ME
                app.StatusLabel.Text = sprintf('Error loading pattern: %s', ME.message);
                uialert(app.UIFigure, ME.message, 'Load Error');
            end
        end

        function loadPatternData(app, Pats, stretch, gs_val, name, arenaConfig, isUnsaved)
            % Load pattern data directly (for in-memory passing from other apps)
            %
            % Parameters:
            %   Pats        - 3D array (rows x cols x frames) of pattern data
            %   stretch     - 1D array (frames x 1) of stretch values per frame
            %   gs_val      - Grayscale mode: 2 (binary) or 16 (4-bit grayscale)
            %   name        - (optional) Display name for the pattern
            %   arenaConfig - (optional) Arena config struct from load_arena_config()
            %   isUnsaved   - (optional) Boolean flag indicating unsaved combined pattern
            %
            % Example usage from PatternGeneratorApp:
            %   previewer = PatternPreviewerApp;
            %   previewer.loadPatternData(app.Pats, app.Stretch, 16, 'grating', app.ArenaConfig);

            if nargin < 5 || isempty(name)
                name = 'unsaved_pattern';
            end
            if nargin < 6
                arenaConfig = [];
            end
            if nargin < 7
                isUnsaved = false;
            end

            % Store unsaved state and update warning label
            app.IsUnsaved = isUnsaved;
            app.updateUnsavedWarning();

            try
                app.StatusLabel.Text = 'Loading pattern data...';
                drawnow;

                [rows, cols, numFrames] = size(Pats);

                % Store pattern data
                app.Pats = Pats;
                app.NumFrames = numFrames;
                app.NumPatsX = numFrames;  % Assume 1D for in-memory patterns
                app.NumPatsY = 1;

                % Store stretch values
                if isempty(stretch)
                    app.Stretch = zeros(numFrames, 1);
                elseif numel(stretch) == 1
                    app.Stretch = repmat(stretch, numFrames, 1);
                else
                    app.Stretch = stretch(:);  % Ensure column vector
                end

                app.gs_val = gs_val;
                app.CurrentFrame = 1;
                app.CurrentFilePath = '';  % No file path for in-memory data

                % Update UI
                app.FileValueLabel.Text = sprintf('%s (unsaved)', name);
                app.SizeValueLabel.Text = sprintf('%d x %d px', rows, cols);
                app.FramesValueLabel.Text = sprintf('%d', app.NumFrames);

                % Determine generation from arena config if available
                if ~isempty(arenaConfig)
                    % Try to get generation from arena config
                    generation = '';
                    if isfield(arenaConfig, 'arena') && isfield(arenaConfig.arena, 'generation')
                        generation = arenaConfig.arena.generation;
                    elseif isfield(arenaConfig, 'generation')
                        generation = arenaConfig.generation;
                    end
                    if ~isempty(generation)
                        app.FormatValueLabel.Text = sprintf('%s (in memory)', generation);
                    else
                        app.FormatValueLabel.Text = '(in memory)';
                    end
                else
                    app.FormatValueLabel.Text = '(in memory)';
                end

                if app.gs_val == 16
                    app.GrayscaleValueLabel.Text = '4-bit (0-15)';
                else
                    app.GrayscaleValueLabel.Text = 'Binary (0-1)';
                end

                % Use passed arena config if available, otherwise try to detect
                if ~isempty(arenaConfig)
                    app.CurrentArenaConfig = arenaConfig;
                    % Handle both nested (from load_arena_config) and flat config structs
                    if isfield(arenaConfig, 'derived') && isfield(arenaConfig.derived, 'pixels_per_panel')
                        app.PixelsPerPanel = arenaConfig.derived.pixels_per_panel;
                    elseif isfield(arenaConfig, 'pixels_per_panel')
                        app.PixelsPerPanel = arenaConfig.pixels_per_panel;
                    else
                        app.PixelsPerPanel = 20;  % Default
                    end
                    % Update panels label with arena info
                    numPanelRows = rows / app.PixelsPerPanel;
                    numPanelCols = cols / app.PixelsPerPanel;
                    % Check for partial arena (num_cols is in arena sub-struct)
                    fullGridCols = numPanelCols;
                    if isfield(arenaConfig, 'arena') && isfield(arenaConfig.arena, 'num_cols')
                        fullGridCols = arenaConfig.arena.num_cols;
                    elseif isfield(arenaConfig, 'num_cols')
                        fullGridCols = arenaConfig.num_cols;
                    end
                    if fullGridCols ~= numPanelCols
                        % Partial arena
                        app.PanelsValueLabel.Text = sprintf('%d x %dof%d', ...
                            numPanelRows, numPanelCols, fullGridCols);
                    else
                        app.PanelsValueLabel.Text = sprintf('%d x %d', numPanelRows, numPanelCols);
                    end
                    % Get arena name
                    arenaName = '';
                    if isfield(arenaConfig, 'name')
                        arenaName = arenaConfig.name;
                    end
                    app.ArenaInfoLabel.Text = sprintf('Arena: %s', arenaName);

                    % Generate arena coordinates for projection views
                    try
                        app.generateArenaCoordinatesFromConfig(arenaConfig);
                        if ~isempty(app.ArenaPhi)
                            app.ArenaInfoLabel.Text = sprintf('Arena: %s (ready)', arenaName);
                        end
                    catch ME
                        % Projection views won't work but grid view will
                        app.ArenaInfoLabel.Text = sprintf('Arena: %s (no projections: %s)', arenaName, ME.message);
                    end
                else
                    % No arena config passed - use dimension-based detection (not recommended)
                    app.PanelsValueLabel.Text = '--';
                    app.ArenaInfoLabel.Text = 'Arena: (auto-detect)';
                    % Try to detect from dimensions
                    app.detectArenaFromDimensions(rows, cols);
                end

                % Setup frame slider
                % Force UI layout before setting up slider to ensure proper tick spacing
                % This is important when pattern is passed immediately after app creation
                drawnow;
                app.setupFrameSlider();
                drawnow;  % Apply slider changes before proceeding

                % Enable controls
                app.PlayButton.Enable = 'on';
                app.ExportGIFMenu.Enable = 'on';
                app.ExportVideoMenu.Enable = 'on';

                % Update preview
                app.updatePreview();

                app.StatusLabel.Text = sprintf('Loaded: %s (%d frames, %s)', ...
                    name, app.NumFrames, app.GrayscaleValueLabel.Text);

                % Bring all pattern apps to front (prevent MATLAB workspace from stealing focus)
                app.bringAllPatternAppsToFront();

            catch ME
                app.StatusLabel.Text = sprintf('Error loading pattern data: %s', ME.message);
                uialert(app.UIFigure, ME.message, 'Load Error');
            end
        end

        function setupFrameSlider(app)
            % Setup frame slider with proper limits handling
            % Must handle the case where current value may be outside new limits
            %
            % Note: When patterns are passed programmatically (from PatternCombinerApp),
            % we need to clear tick marks before changing limits to prevent visual
            % artifacts from stale tick positions.

            if app.NumFrames > 1
                newMax = double(app.NumFrames);

                % Clear tick marks first to prevent visual artifacts
                app.FrameSlider.MajorTicks = [];
                app.FrameSlider.MinorTicks = [];

                % Temporarily expand limits to avoid value-out-of-range error
                currentMax = app.FrameSlider.Limits(2);

                if newMax > currentMax
                    % Expanding: set limits first, then value
                    app.FrameSlider.Limits = [1 newMax];
                    app.FrameSlider.Value = 1;
                else
                    % Shrinking: set value first, then limits
                    app.FrameSlider.Value = 1;
                    app.FrameSlider.Limits = [1 newMax];
                end

                app.FrameSlider.Enable = 'on';

                % Set appropriate tick marks based on frame count
                % Use integer ticks only, spaced appropriately for readability
                if app.NumFrames <= 10
                    % Few frames: show all ticks
                    ticks = 1:app.NumFrames;
                elseif app.NumFrames <= 20
                    % Medium count: show every 2nd tick
                    ticks = 1:2:app.NumFrames;
                    if mod(app.NumFrames, 2) == 0 && ticks(end) ~= app.NumFrames
                        ticks = [ticks, app.NumFrames];
                    end
                else
                    % Many frames: show ~10 evenly spaced ticks
                    step = ceil(app.NumFrames / 10);
                    ticks = 1:step:app.NumFrames;
                    % Ensure the last tick is exactly at NumFrames
                    if ticks(end) ~= app.NumFrames
                        ticks = [ticks, app.NumFrames];
                    end
                end

                % Set ticks and generate matching labels
                app.FrameSlider.MajorTicks = ticks;
                app.FrameSlider.MinorTicks = [];
                % Generate string labels for each tick value
                app.FrameSlider.MajorTickLabels = arrayfun(@num2str, ticks, 'UniformOutput', false);
            else
                % Single frame - disable slider
                app.FrameSlider.MajorTicks = [];
                app.FrameSlider.MinorTicks = [];
                app.FrameSlider.Value = 1;
                app.FrameSlider.Limits = [1 2];
                app.FrameSlider.Enable = 'off';
                app.FrameSlider.MajorTicks = [1];
                app.FrameSlider.MinorTicks = [];
            end
        end

        function updatePreview(app)
            % Update the pattern preview display
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
                app.renderMercatorView(frameData, frame);
            elseif strcmp(viewMode, 'Mollweide')
                app.renderMollweideView(frameData, frame);
            else
                % Grid (pixel) view - default
                [rows, cols] = size(frameData);

                cla(app.PreviewAxes);
                % Use 0-indexed coordinates for display (origin at lower left)
                % imagesc uses 1-indexed internally, so we offset by -0.5 for pixel centers
                imagesc(app.PreviewAxes, [0 cols-1], [0 rows-1], frameData);
                colormap(app.PreviewAxes, app.LEDColormap);

                if app.gs_val == 16
                    app.PreviewAxes.CLim = [0 15];
                else
                    app.PreviewAxes.CLim = [0 1];
                end

                axis(app.PreviewAxes, 'image');
                app.PreviewAxes.YDir = 'normal';  % (0,0) at bottom-left
                app.PreviewAxes.XLim = [-0.5 cols-0.5];
                app.PreviewAxes.YLim = [-0.5 rows-0.5];

                % Add tick marks at panel boundaries (varies by generation)
                pxPerPanel = app.PixelsPerPanel;
                app.PreviewAxes.XTick = 0:pxPerPanel:cols;
                app.PreviewAxes.YTick = 0:pxPerPanel:rows;
                app.PreviewAxes.XLabel.String = 'Pixel Column (0-indexed)';
                app.PreviewAxes.YLabel.String = 'Pixel Row (0-indexed)';
                grid(app.PreviewAxes, 'on');
                title(app.PreviewAxes, sprintf('Frame %d / %d', frame, app.NumFrames));

                % Draw panel outlines if checkbox is enabled
                if app.ShowPanelOutlinesCheckbox.Value
                    hold(app.PreviewAxes, 'on');
                    numPanelRows = rows / pxPerPanel;
                    numPanelCols = cols / pxPerPanel;
                    for pr = 0:(numPanelRows-1)
                        for pc = 0:(numPanelCols-1)
                            % Rectangle position: bottom-left corner (x, y), width, height
                            % Adjust by -0.5 to align with pixel edges
                            x = pc * pxPerPanel - 0.5;
                            y = pr * pxPerPanel - 0.5;
                            rectangle(app.PreviewAxes, 'Position', [x, y, pxPerPanel, pxPerPanel], ...
                                'EdgeColor', [1 1 0], 'LineWidth', 1.5);  % Yellow outline
                        end
                    end

                    % Draw panel/column IDs if that checkbox is also enabled
                    if app.ShowPanelIDsCheckbox.Value
                        for pr = 0:(numPanelRows-1)
                            for pc = 0:(numPanelCols-1)
                                panelID = pc * numPanelRows + pr;  % Column-major: panels numbered down each column
                                colID = pc;
                                % Center of panel
                                cx = pc * pxPerPanel + pxPerPanel/2 - 0.5;
                                cy = pr * pxPerPanel + pxPerPanel/2 - 0.5;
                                % Two-line label in RED
                                labelText = sprintf('Pan %d\nCol %d', panelID, colID);
                                text(app.PreviewAxes, cx, cy, labelText, ...
                                    'Color', 'r', 'FontSize', 12, 'FontWeight', 'bold', ...
                                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
                            end
                        end
                    end
                    hold(app.PreviewAxes, 'off');
                end
            end

            % Update frame info
            app.CurrentFrameValueLabel.Text = sprintf('%d / %d', frame, app.NumFrames);
            app.StretchValueLabel.Text = sprintf('%d', app.Stretch(frame));
            app.FrameSliderLabel.Text = sprintf('Frame: %d / %d', frame, app.NumFrames);

            % Update histogram
            app.updateHistogram(frameData);
        end

        function updateHistogram(app, frameData)
            % Update the intensity histogram display
            % Shows all possible intensity levels (16 for GS4, 2 for binary)
            maxVal = (app.gs_val == 16) * 15 + (app.gs_val ~= 16) * 1;
            numLevels = maxVal + 1;  % 16 for GS4, 2 for binary

            counts = histcounts(double(frameData(:)), -0.5:1:(maxVal+0.5));
            maxCount = max(max(counts), 1);  % Avoid division by zero

            lines = cell(numLevels, 1);
            for val = 0:maxVal
                count = counts(val + 1);  % 0-indexed value, 1-indexed array
                barLen = round(count / maxCount * 12);
                bar = repmat(char(9608), 1, barLen);  % Unicode full block
                lines{val + 1} = sprintf('%2d: %-12s %d px', val, bar, count);
            end

            app.HistogramTextArea.Value = lines;
        end

        function colors = getPixelColors(app, frameData)
            % Get RGB colors for each pixel based on intensity
            if app.gs_val == 16
                maxVal = 15;
            else
                maxVal = 1;
            end

            % Normalize to 0-1 range
            normalized = double(frameData(:)) / maxVal;

            % Map to LED green colormap
            colors = zeros(numel(frameData), 3);
            colors(:, 2) = normalized;  % Green channel only
        end

        function renderMercatorView(app, frameData, frame)
            % Render pattern as Mercator (cylindrical) projection
            try
                if isempty(app.ArenaPhi) || isempty(app.ArenaTheta)
                    % Fall back to grid view if no coordinates
                    imagesc(app.PreviewAxes, frameData);
                    colormap(app.PreviewAxes, app.LEDColormap);
                    axis(app.PreviewAxes, 'image');
                    title(app.PreviewAxes, sprintf('Frame %d / %d (no arena loaded)', frame, app.NumFrames));
                    return;
                end

                lon = rad2deg(app.ArenaPhi);
                lat = rad2deg(app.ArenaTheta) - 90;

                colors = app.getPixelColors(frameData);
                lonVec = lon(:);
                latVec = lat(:);

                dotScale = app.DotScaleSlider.Value / 100;
                baseDotSize = 20;
                dotSize = baseDotSize * dotScale;

                cla(app.PreviewAxes);
                scatter(app.PreviewAxes, lonVec, latVec, dotSize, colors, 'filled');

                app.PreviewAxes.XLim = [app.LonCenter - app.LonFOV, app.LonCenter + app.LonFOV];
                app.PreviewAxes.YLim = [app.LatCenter - app.LatFOV, app.LatCenter + app.LatFOV];
                app.PreviewAxes.XTick = -180:30:180;
                app.PreviewAxes.YTick = -90:30:90;
                app.PreviewAxes.XLabel.String = 'Longitude (deg)';
                app.PreviewAxes.YLabel.String = 'Latitude (deg)';
                app.PreviewAxes.DataAspectRatio = [1 1 1];
                grid(app.PreviewAxes, 'on');
                title(app.PreviewAxes, sprintf('Frame %d / %d (Mercator)', frame, app.NumFrames));
            catch ME
                % Handle errors gracefully - don't rethrow to prevent timer cascade
                if ~contains(ME.message, 'Invalid or deleted object')
                    app.StatusLabel.Text = sprintf('Mercator error: %s', ME.message);
                    % Fall back to simple grid display
                    try
                        cla(app.PreviewAxes);
                        imagesc(app.PreviewAxes, frameData);
                        colormap(app.PreviewAxes, app.LEDColormap);
                        axis(app.PreviewAxes, 'image');
                        title(app.PreviewAxes, sprintf('Frame %d / %d (fallback)', frame, app.NumFrames));
                    catch
                        % Ignore secondary errors
                    end
                end
            end
        end

        function renderMollweideView(app, frameData, frame)
            % Render pattern as Mollweide (equal-area) projection
            try
                if isempty(app.ArenaPhi) || isempty(app.ArenaTheta)
                    imagesc(app.PreviewAxes, frameData);
                    colormap(app.PreviewAxes, app.LEDColormap);
                    axis(app.PreviewAxes, 'image');
                    title(app.PreviewAxes, sprintf('Frame %d / %d (no arena loaded)', frame, app.NumFrames));
                    return;
                end

                lon = app.ArenaPhi;
                lat = app.ArenaTheta - pi/2;

                theta = app.computeMollweideTheta(lat);
                x = (2 * sqrt(2) / pi) * lon .* cos(theta);
                y = sqrt(2) * sin(theta);

                xDeg = rad2deg(x);
                yDeg = rad2deg(y);

                colors = app.getPixelColors(frameData);
                xVec = xDeg(:);
                yVec = yDeg(:);

                dotScale = app.DotScaleSlider.Value / 100;
                baseDotSize = 20;
                dotSize = baseDotSize * dotScale;

                cla(app.PreviewAxes);
                scatter(app.PreviewAxes, xVec, yVec, dotSize, colors, 'filled');

                % Compute FOV limits accounting for Mollweide compression
                xScale = 2 * sqrt(2) / pi;
                yScale = sqrt(2);

                % X limits at equator (where cos(θ)=1, max range)
                xLimMoll = xScale * deg2rad(app.LonFOV);
                xLimDeg = rad2deg(xLimMoll);

                % Y limits require Mollweide theta calculation
                latLimRad = deg2rad(app.LatFOV);
                thetaLim = app.computeMollweideTheta(latLimRad);
                yLimMoll = yScale * sin(thetaLim);
                yLimDeg = rad2deg(yLimMoll);

                % Validate limits to prevent "second element must be greater" error
                if xLimDeg <= 0 || ~isfinite(xLimDeg)
                    xLimDeg = 180;  % Safe default
                end
                if yLimDeg <= 0 || ~isfinite(yLimDeg)
                    yLimDeg = 90;   % Safe default
                end

                app.PreviewAxes.XLim = [-xLimDeg, xLimDeg];
                app.PreviewAxes.YLim = [-yLimDeg, yLimDeg];
                app.PreviewAxes.XTick = -180:30:180;
                app.PreviewAxes.YTick = -90:30:90;
                app.PreviewAxes.XLabel.String = 'Longitude (deg)';
                app.PreviewAxes.YLabel.String = 'Latitude (deg)';
                app.PreviewAxes.DataAspectRatio = [1 1 1];
                grid(app.PreviewAxes, 'on');
                title(app.PreviewAxes, sprintf('Frame %d / %d (Mollweide)', frame, app.NumFrames));
            catch ME
                % Handle errors gracefully - don't rethrow to prevent timer cascade
                if ~contains(ME.message, 'Invalid or deleted object')
                    app.StatusLabel.Text = sprintf('Mollweide error: %s', ME.message);
                    % Fall back to simple grid display
                    try
                        cla(app.PreviewAxes);
                        imagesc(app.PreviewAxes, frameData);
                        colormap(app.PreviewAxes, app.LEDColormap);
                        axis(app.PreviewAxes, 'image');
                        title(app.PreviewAxes, sprintf('Frame %d / %d (fallback)', frame, app.NumFrames));
                    catch
                        % Ignore secondary errors
                    end
                end
            end
        end

        function theta = computeMollweideTheta(~, lat)
            % Compute auxiliary angle for Mollweide projection
            theta = lat;
            for iter = 1:10
                delta = -(2*theta + sin(2*theta) - pi*sin(lat)) ./ (2 + 2*cos(2*theta));
                theta = theta + delta;
                if max(abs(delta(:))) < 1e-6
                    break;
                end
            end
        end

        function playTimerCallback(app, ~, ~)
            % Timer callback for playback
            nextFrame = app.CurrentFrame + 1;
            if nextFrame > app.NumFrames
                nextFrame = 1;  % Loop back
            end
            app.FrameSlider.Value = nextFrame;
            app.updatePreview();
        end

        function stopPlayback(app)
            % Stop playback
            if ~isempty(app.PlayTimer) && isvalid(app.PlayTimer)
                stop(app.PlayTimer);
                delete(app.PlayTimer);
            end
            app.PlayTimer = [];
            app.IsPlaying = false;
            app.PlayButton.Text = 'Play';
            app.PlayButton.BackgroundColor = [0.3 0.5 0.7];
        end

        function baseName = getPatternBaseName(app)
            % Extract base name for exports from loaded file or in-memory name
            if ~isempty(app.CurrentFilePath)
                % Loaded from file: extract filename without extension
                [~, baseName, ~] = fileparts(app.CurrentFilePath);
            else
                % In-memory pattern: extract name from FileValueLabel
                % Format is "pattern_name (unsaved)" - strip the suffix
                labelText = app.FileValueLabel.Text;
                if contains(labelText, ' (unsaved)')
                    baseName = strrep(labelText, ' (unsaved)', '');
                else
                    baseName = labelText;
                end
            end

            % Fallback if somehow empty
            if isempty(baseName) || strcmp(baseName, '--')
                baseName = 'pattern';
            end
        end

        function updateUnsavedWarning(app)
            % Show or hide the unsaved warning label
            if app.IsUnsaved
                app.UnsavedWarningLabel.Visible = 'on';
                app.UnsavedWarningLabel.Text = 'UNSAVED';
            else
                app.UnsavedWarningLabel.Visible = 'off';
            end
        end

        function detectArenaFromDimensions(app, rows, cols)
            % Attempt to detect arena config from pattern dimensions
            % Note: This is a fallback method and can be ambiguous for partial arenas.
            % It's always better to pass arenaConfig explicitly.
            %
            % Returns: sets app.PixelsPerPanel and app.CurrentArenaConfig if found

            % Try each arena config to find a dimension match
            if isempty(app.ArenaConfigs)
                app.PixelsPerPanel = 20;  % Default
                return;
            end

            for i = 1:length(app.ArenaConfigs)
                try
                    cfg = load_arena_config(app.ArenaConfigs{i});

                    % Get expected dimensions from this config
                    expectedRows = cfg.derived.total_pixels_y;
                    expectedCols = cfg.derived.total_pixels_x;

                    if rows == expectedRows && cols == expectedCols
                        % Found a match
                        app.CurrentArenaConfig = cfg;
                        app.PixelsPerPanel = cfg.derived.pixels_per_panel;

                        % Update arena info label
                        arenaName = cfg.name;
                        if isempty(arenaName)
                            [~, arenaName] = fileparts(app.ArenaConfigs{i});
                            arenaName = strrep(arenaName, '.yaml', '');
                        end
                        app.ArenaInfoLabel.Text = sprintf('Arena: %s (detected)', arenaName);

                        % Try to load coordinates for projections
                        try
                            app.loadArenaConfig(app.ArenaConfigs{i});
                        catch
                            % Projection views won't work but grid view will
                        end

                        return;
                    end
                catch
                    % Skip configs that can't be loaded
                end
            end

            % No match found - use defaults
            app.PixelsPerPanel = 20;
            app.ArenaInfoLabel.Text = sprintf('Arena: unknown (%dx%d)', rows, cols);
        end
    end

    % Callbacks
    methods (Access = private)

        function LoadPatternButtonPushed(app, ~)
            % Open file dialog to load pattern
            [file, path] = uigetfile('*.pat', 'Select Pattern File', ...
                fullfile(app.maDisplayToolsRoot, 'patterns'));
            if isequal(file, 0)
                return;
            end
            app.loadPatternFile(fullfile(path, file));
        end

        function PatternGeneratorButtonPushed(app, ~)
            % Launch PatternGeneratorApp
            try
                PatternGeneratorApp;
                app.StatusLabel.Text = 'Launched Pattern Generator';
            catch ME
                app.StatusLabel.Text = sprintf('Failed to launch: %s', ME.message);
            end
        end

        function PatternCombinerButtonPushed(app, ~)
            % Launch PatternCombinerApp
            try
                PatternCombinerApp;
                app.StatusLabel.Text = 'Launched Pattern Combiner';
            catch ME
                app.StatusLabel.Text = sprintf('Failed to launch: %s', ME.message);
            end
        end

        function DrawingAppButtonPushed(app, ~)
            % Placeholder for future Drawing app
            uialert(app.UIFigure, 'Drawing App is not yet implemented.', 'Coming Soon');
        end

        function FrameSliderValueChanged(app, ~)
            % Handle frame slider change
            app.FrameSlider.Value = round(app.FrameSlider.Value);
            app.updatePreview();
        end

        function PlayButtonPushed(app, ~)
            % Toggle playback
            if app.IsPlaying
                app.stopPlayback();
            else
                % Start playback
                fps = str2double(app.FPSDropDown.Value);
                period = 1 / fps;

                app.PlayTimer = timer('ExecutionMode', 'fixedRate', ...
                    'Period', period, ...
                    'TimerFcn', @app.playTimerCallback);

                start(app.PlayTimer);
                app.IsPlaying = true;
                app.PlayButton.Text = 'Stop';
                app.PlayButton.BackgroundColor = [0.7 0.3 0.3];
            end
        end

        function FPSDropDownValueChanged(app, ~)
            % Update playback speed if playing
            if app.IsPlaying
                app.stopPlayback();
                app.PlayButtonPushed();  % Restart with new FPS
            end
        end

        function ViewModeDropDownValueChanged(app, ~)
            % Handle view mode change
            % Stop playback during view switch to prevent timer race conditions
            wasPlaying = app.IsPlaying;
            if app.IsPlaying
                app.stopPlayback();
            end

            viewMode = app.ViewModeDropDown.Value;

            % Check if projection view requires arena
            if ~strcmp(viewMode, 'Grid (Pixels)') && (isempty(app.ArenaPhi) || isempty(app.ArenaTheta))
                % Warn user - arena not detected
                app.StatusLabel.Text = 'Projection views require arena coordinates. Pattern must be in patterns/{arena_name}/ folder.';
                % Note: Don't reassign ViewModeDropDown.Value here as it can trigger recursive callback
                % The render functions will handle missing arena gracefully with fallback display
            end

            % Show/hide projection controls based on view mode
            if strcmp(viewMode, 'Grid (Pixels)')
                app.DotScaleSlider.Enable = 'off';
                app.LonZoomButton.Enable = 'off';
                app.LatZoomButton.Enable = 'off';
                app.FOVResetButton.Enable = 'off';
                app.ShowPanelOutlinesCheckbox.Enable = 'on';
                % Re-enable panel IDs checkbox if outlines are checked
                if app.ShowPanelOutlinesCheckbox.Value
                    app.ShowPanelIDsCheckbox.Enable = 'on';
                end
            else
                app.DotScaleSlider.Enable = 'on';
                app.LonZoomButton.Enable = 'on';
                app.LatZoomButton.Enable = 'on';
                app.FOVResetButton.Enable = 'on';
                % Disable panel outlines and IDs for projection views (panels aren't rectangles)
                app.ShowPanelOutlinesCheckbox.Enable = 'off';
                app.ShowPanelOutlinesCheckbox.Value = false;
                app.ShowPanelIDsCheckbox.Enable = 'off';
                app.ShowPanelIDsCheckbox.Value = false;
            end

            app.updatePreview();

            % Optionally restart playback after view switch completes
            if wasPlaying
                app.PlayButtonPushed();
            end
        end

        function DotScaleSliderValueChanged(app, ~)
            app.DotScaleValueLabel.Text = sprintf('%.0f%%', app.DotScaleSlider.Value);
            app.updatePreview();
        end

        function LonZoomButtonPushed(app, ~)
            app.LonFOV = max(10, app.LonFOV - 20);
            app.LonFOVValueLabel.Text = sprintf('±%d°', app.LonFOV);
            app.updatePreview();
        end

        function LatZoomButtonPushed(app, ~)
            app.LatFOV = max(10, app.LatFOV - 10);
            app.LatFOVValueLabel.Text = sprintf('±%d°', app.LatFOV);
            app.updatePreview();
        end

        function FOVResetButtonPushed(app, ~)
            app.LonFOV = 180;
            app.LatFOV = 90;
            app.LonFOVValueLabel.Text = '±180°';
            app.LatFOVValueLabel.Text = '±90°';
            % Only update preview if not playing (timer handles updates during playback)
            % This avoids race conditions that can cause timer errors
            if ~app.IsPlaying
                app.updatePreview();
            end
        end

        function ExportGIFButtonPushed(app, ~)
            % Export pattern as GIF
            if isempty(app.Pats)
                uialert(app.UIFigure, 'No pattern loaded', 'Export Error');
                return;
            end

            % Get output filename using pattern name as default
            baseName = app.getPatternBaseName();
            defaultFile = [baseName '.gif'];
            [file, path] = uiputfile('*.gif', 'Export GIF', ...
                fullfile(app.maDisplayToolsRoot, 'exports', defaultFile));
            if isequal(file, 0)
                return;
            end

            filepath = fullfile(path, file);

            % Get FPS from dropdown
            fps = str2double(app.FPSDropDown.Value);
            delay = 1 / fps;

            app.StatusLabel.Text = 'Exporting GIF...';
            drawnow;

            try
                maxVal = (app.gs_val == 16) * 15 + (app.gs_val ~= 16) * 1;

                for i = 1:app.NumFrames
                    frame = app.Pats(:, :, i);
                    scaled = uint8(double(frame) / maxVal * 255);

                    if i == 1
                        imwrite(scaled, gray(256), filepath, 'gif', ...
                            'LoopCount', Inf, 'DelayTime', delay);
                    else
                        imwrite(scaled, gray(256), filepath, 'gif', ...
                            'WriteMode', 'append', 'DelayTime', delay);
                    end
                end

                app.StatusLabel.Text = sprintf('Exported: %s', file);
            catch ME
                app.StatusLabel.Text = sprintf('Export failed: %s', ME.message);
                uialert(app.UIFigure, ME.message, 'Export Error');
            end
        end

        function ExportVideoButtonPushed(app, ~)
            % Export pattern as video
            if isempty(app.Pats)
                uialert(app.UIFigure, 'No pattern loaded', 'Export Error');
                return;
            end

            % Get output filename using pattern name as default
            baseName = app.getPatternBaseName();
            defaultFile = [baseName '.mp4'];
            [file, path] = uiputfile({'*.mp4'; '*.avi'}, 'Export Video', ...
                fullfile(app.maDisplayToolsRoot, 'exports', defaultFile));
            if isequal(file, 0)
                return;
            end

            filepath = fullfile(path, file);

            % Get FPS from dropdown
            fps = str2double(app.FPSDropDown.Value);

            app.StatusLabel.Text = 'Exporting video...';
            drawnow;

            try
                v = VideoWriter(filepath, 'MPEG-4');
                v.FrameRate = fps;
                v.Quality = 95;
                open(v);

                maxVal = (app.gs_val == 16) * 15 + (app.gs_val ~= 16) * 1;

                for i = 1:app.NumFrames
                    frame = app.Pats(:, :, i);
                    scaled = double(frame) / maxVal;

                    % Create RGB frame (grayscale)
                    rgbFrame = repmat(scaled, [1 1 3]);

                    writeVideo(v, rgbFrame);
                end

                close(v);
                app.StatusLabel.Text = sprintf('Exported: %s', file);
            catch ME
                app.StatusLabel.Text = sprintf('Export failed: %s', ME.message);
                uialert(app.UIFigure, ME.message, 'Export Error');
            end
        end

        function panelOutlinesChanged(app)
            % Handle panel outlines checkbox change
            % Enable/disable panel IDs checkbox based on outlines state AND view mode
            % Panel IDs only available in Grid view
            viewMode = app.ViewModeDropDown.Value;
            isGridView = strcmp(viewMode, 'Grid (Pixels)');

            if app.ShowPanelOutlinesCheckbox.Value && isGridView
                app.ShowPanelIDsCheckbox.Enable = 'on';
            else
                app.ShowPanelIDsCheckbox.Enable = 'off';
                app.ShowPanelIDsCheckbox.Value = false;
            end
            app.updatePreview();
        end

        function UIFigureCloseRequest(app, ~)
            % Handle window close - save position before closing
            if isvalid(app.UIFigure)
                setpref('maDisplayTools', 'PatternPreviewerPosition', app.UIFigure.Position);
            end
            app.stopPlayback();
            delete(app);
        end
    end

    % Component initialization
    methods (Access = private)

        function createComponents(app)
            % Create UIFigure and components

            % Get maDisplayTools root
            appPath = fileparts(mfilename('fullpath'));
            app.maDisplayToolsRoot = fileparts(appPath);

            % Add required paths for arena_coordinates and utilities
            addpath(fullfile(app.maDisplayToolsRoot, 'patternTools'));
            addpath(fullfile(app.maDisplayToolsRoot, 'utils'));

            % Create UIFigure with persistent position
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Name = 'Pattern Previewer';
            app.UIFigure.CloseRequestFcn = @(~,~) app.UIFigureCloseRequest();

            % Load saved position or use default
            defaultPos = [480 150 900 700];
            if ispref('maDisplayTools', 'PatternPreviewerPosition')
                savedPos = getpref('maDisplayTools', 'PatternPreviewerPosition');
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

            % Create main grid layout (no toolbar row - using menus instead)
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {'1x'};
            app.GridLayout.RowHeight = {'1x', 50, 280, 25};  % Preview, slider, info panels, status
            app.GridLayout.Padding = [10 10 10 10];
            app.GridLayout.RowSpacing = 5;

            % === Create Menus ===
            app.FileMenu = uimenu(app.UIFigure);
            app.FileMenu.Text = 'File';

            app.LoadPatternMenu = uimenu(app.FileMenu);
            app.LoadPatternMenu.Text = 'Load Pattern...';
            app.LoadPatternMenu.Accelerator = 'O';
            app.LoadPatternMenu.MenuSelectedFcn = @(~,~) app.LoadPatternButtonPushed();

            app.ExportGIFMenu = uimenu(app.FileMenu);
            app.ExportGIFMenu.Text = 'Export GIF...';
            app.ExportGIFMenu.MenuSelectedFcn = @(~,~) app.ExportGIFButtonPushed();
            app.ExportGIFMenu.Enable = 'off';

            app.ExportVideoMenu = uimenu(app.FileMenu);
            app.ExportVideoMenu.Text = 'Export Video...';
            app.ExportVideoMenu.MenuSelectedFcn = @(~,~) app.ExportVideoButtonPushed();
            app.ExportVideoMenu.Enable = 'off';

            app.ToolsMenu = uimenu(app.UIFigure);
            app.ToolsMenu.Text = 'Tools';

            app.PatternGeneratorMenu = uimenu(app.ToolsMenu);
            app.PatternGeneratorMenu.Text = 'Pattern Generator';
            app.PatternGeneratorMenu.MenuSelectedFcn = @(~,~) app.PatternGeneratorButtonPushed();

            app.PatternCombinerMenu = uimenu(app.ToolsMenu);
            app.PatternCombinerMenu.Text = 'Pattern Combiner';
            app.PatternCombinerMenu.MenuSelectedFcn = @(~,~) app.PatternCombinerButtonPushed();
            app.PatternCombinerMenu.Enable = 'on';

            app.DrawingAppMenu = uimenu(app.ToolsMenu);
            app.DrawingAppMenu.Text = 'Drawing App';
            app.DrawingAppMenu.MenuSelectedFcn = @(~,~) app.DrawingAppButtonPushed();
            app.DrawingAppMenu.Enable = 'off';

            % === Row 1: Preview Axes with Unsaved Warning ===
            % Create a panel to hold axes and warning label
            previewPanel = uipanel(app.GridLayout);
            previewPanel.BorderType = 'none';
            previewPanel.Layout.Row = 1;
            previewPanel.Layout.Column = 1;

            previewGrid = uigridlayout(previewPanel);
            previewGrid.ColumnWidth = {'1x', 100};
            previewGrid.RowHeight = {25, '1x'};
            previewGrid.Padding = [0 0 0 0];
            previewGrid.RowSpacing = 0;
            previewGrid.ColumnSpacing = 0;

            % Unsaved warning label in top-right
            app.UnsavedWarningLabel = uilabel(previewGrid);
            app.UnsavedWarningLabel.Text = 'UNSAVED';
            app.UnsavedWarningLabel.FontColor = [1 0 0];  % Red
            app.UnsavedWarningLabel.FontWeight = 'bold';
            app.UnsavedWarningLabel.FontSize = 14;
            app.UnsavedWarningLabel.HorizontalAlignment = 'right';
            app.UnsavedWarningLabel.Layout.Row = 1;
            app.UnsavedWarningLabel.Layout.Column = 2;
            app.UnsavedWarningLabel.Visible = 'off';

            % Preview axes
            app.PreviewAxes = uiaxes(previewGrid);
            app.PreviewAxes.Layout.Row = [1 2];
            app.PreviewAxes.Layout.Column = [1 2];
            title(app.PreviewAxes, 'No pattern loaded');
            app.PreviewAxes.XTick = [];
            app.PreviewAxes.YTick = [];

            % === Row 2: Frame Slider ===
            sliderGrid = uigridlayout(app.GridLayout);
            sliderGrid.Layout.Row = 2;
            sliderGrid.Layout.Column = 1;
            sliderGrid.ColumnWidth = {100, '1x'};
            sliderGrid.RowHeight = {'1x'};
            sliderGrid.Padding = [0 0 0 0];

            app.FrameSliderLabel = uilabel(sliderGrid);
            app.FrameSliderLabel.Text = 'Frame: -- / --';
            app.FrameSliderLabel.Layout.Row = 1;
            app.FrameSliderLabel.Layout.Column = 1;

            app.FrameSlider = uislider(sliderGrid);
            app.FrameSlider.Limits = [1 10];
            app.FrameSlider.Value = 1;
            app.FrameSlider.ValueChangedFcn = @(~,~) app.FrameSliderValueChanged();
            app.FrameSlider.Layout.Row = 1;
            app.FrameSlider.Layout.Column = 2;
            app.FrameSlider.Enable = 'off';

            % === Row 3: Info, Histogram, and Controls (three columns) ===
            infoControlGrid = uigridlayout(app.GridLayout);
            infoControlGrid.Layout.Row = 3;
            infoControlGrid.Layout.Column = 1;
            infoControlGrid.ColumnWidth = {'1x', '1x', '1x'};
            infoControlGrid.RowHeight = {'1x'};
            infoControlGrid.Padding = [0 0 0 0];

            % Left Panel - Pattern Info
            app.LeftPanel = uipanel(infoControlGrid);
            app.LeftPanel.Title = 'Pattern Info';
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;

            leftGrid = uigridlayout(app.LeftPanel);
            leftGrid.ColumnWidth = {80, '1x'};
            leftGrid.RowHeight = {22, 22, 22, 22, 22, 22, 22, 22};  % Added 2 more rows
            leftGrid.Padding = [8 8 8 8];
            leftGrid.RowSpacing = 4;

            app.FileLabel = uilabel(leftGrid);
            app.FileLabel.Text = 'File:';
            app.FileLabel.Layout.Row = 1;
            app.FileLabel.Layout.Column = 1;

            app.FileValueLabel = uilabel(leftGrid);
            app.FileValueLabel.Text = '--';
            app.FileValueLabel.Layout.Row = 1;
            app.FileValueLabel.Layout.Column = 2;

            app.FormatLabel = uilabel(leftGrid);
            app.FormatLabel.Text = 'Format:';
            app.FormatLabel.Layout.Row = 2;
            app.FormatLabel.Layout.Column = 1;

            app.FormatValueLabel = uilabel(leftGrid);
            app.FormatValueLabel.Text = '--';
            app.FormatValueLabel.Layout.Row = 2;
            app.FormatValueLabel.Layout.Column = 2;

            app.SizeLabel = uilabel(leftGrid);
            app.SizeLabel.Text = 'Size:';
            app.SizeLabel.Layout.Row = 3;
            app.SizeLabel.Layout.Column = 1;

            app.SizeValueLabel = uilabel(leftGrid);
            app.SizeValueLabel.Text = '--';
            app.SizeValueLabel.Layout.Row = 3;
            app.SizeValueLabel.Layout.Column = 2;

            app.PanelsLabel = uilabel(leftGrid);
            app.PanelsLabel.Text = 'Panels:';
            app.PanelsLabel.Layout.Row = 4;
            app.PanelsLabel.Layout.Column = 1;

            app.PanelsValueLabel = uilabel(leftGrid);
            app.PanelsValueLabel.Text = '--';
            app.PanelsValueLabel.Layout.Row = 4;
            app.PanelsValueLabel.Layout.Column = 2;

            app.FramesLabel = uilabel(leftGrid);
            app.FramesLabel.Text = 'Frames:';
            app.FramesLabel.Layout.Row = 5;
            app.FramesLabel.Layout.Column = 1;

            app.FramesValueLabel = uilabel(leftGrid);
            app.FramesValueLabel.Text = '--';
            app.FramesValueLabel.Layout.Row = 5;
            app.FramesValueLabel.Layout.Column = 2;

            app.GrayscaleLabel = uilabel(leftGrid);
            app.GrayscaleLabel.Text = 'Grayscale:';
            app.GrayscaleLabel.Layout.Row = 6;
            app.GrayscaleLabel.Layout.Column = 1;

            app.GrayscaleValueLabel = uilabel(leftGrid);
            app.GrayscaleValueLabel.Text = '--';
            app.GrayscaleValueLabel.Layout.Row = 6;
            app.GrayscaleValueLabel.Layout.Column = 2;

            app.CurrentFrameLabel = uilabel(leftGrid);
            app.CurrentFrameLabel.Text = 'Frame:';
            app.CurrentFrameLabel.Layout.Row = 7;
            app.CurrentFrameLabel.Layout.Column = 1;

            app.CurrentFrameValueLabel = uilabel(leftGrid);
            app.CurrentFrameValueLabel.Text = '--';
            app.CurrentFrameValueLabel.Layout.Row = 7;
            app.CurrentFrameValueLabel.Layout.Column = 2;

            app.StretchLabel = uilabel(leftGrid);
            app.StretchLabel.Text = 'Stretch:';
            app.StretchLabel.Layout.Row = 8;
            app.StretchLabel.Layout.Column = 1;

            app.StretchValueLabel = uilabel(leftGrid);
            app.StretchValueLabel.Text = '--';
            app.StretchValueLabel.Layout.Row = 8;
            app.StretchValueLabel.Layout.Column = 2;

            % Middle Panel - Histogram
            app.MiddlePanel = uipanel(infoControlGrid);
            app.MiddlePanel.Title = 'Intensity Histogram';
            app.MiddlePanel.Layout.Row = 1;
            app.MiddlePanel.Layout.Column = 2;

            middleGrid = uigridlayout(app.MiddlePanel);
            middleGrid.ColumnWidth = {'1x'};
            middleGrid.RowHeight = {'1x'};
            middleGrid.Padding = [8 8 8 8];

            app.HistogramTextArea = uitextarea(middleGrid);
            app.HistogramTextArea.Value = {'No pattern loaded'};
            app.HistogramTextArea.Editable = 'off';
            app.HistogramTextArea.FontName = 'Courier New';
            app.HistogramTextArea.FontSize = 11;
            app.HistogramTextArea.Layout.Row = 1;
            app.HistogramTextArea.Layout.Column = 1;

            % Right Panel - Controls
            app.RightPanel = uipanel(infoControlGrid);
            app.RightPanel.Title = 'Controls';
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 3;

            rightGrid = uigridlayout(app.RightPanel);
            rightGrid.ColumnWidth = {90, 90, '1x'};
            rightGrid.RowHeight = {30, 30, 30, 30, 30, 30, 30};  % 7 rows
            rightGrid.Padding = [8 8 8 8];
            rightGrid.RowSpacing = 5;

            % Row 1: Play button and FPS
            app.PlayButton = uibutton(rightGrid, 'push');
            app.PlayButton.Text = 'Play';
            app.PlayButton.ButtonPushedFcn = @(~,~) app.PlayButtonPushed();
            app.PlayButton.Layout.Row = 1;
            app.PlayButton.Layout.Column = 1;
            app.PlayButton.BackgroundColor = [0.3 0.5 0.7];
            app.PlayButton.FontColor = [1 1 1];
            app.PlayButton.Enable = 'off';

            app.FPSLabel = uilabel(rightGrid);
            app.FPSLabel.Text = 'FPS:';
            app.FPSLabel.HorizontalAlignment = 'right';
            app.FPSLabel.Layout.Row = 1;
            app.FPSLabel.Layout.Column = 2;

            app.FPSDropDown = uidropdown(rightGrid);
            app.FPSDropDown.Items = {'1', '5', '10', '20', '30', '60'};
            app.FPSDropDown.Value = '10';
            app.FPSDropDown.ValueChangedFcn = @(~,~) app.FPSDropDownValueChanged();
            app.FPSDropDown.Layout.Row = 1;
            app.FPSDropDown.Layout.Column = 3;

            % Row 2: View mode
            app.ViewModeLabel = uilabel(rightGrid);
            app.ViewModeLabel.Text = 'View:';
            app.ViewModeLabel.Layout.Row = 2;
            app.ViewModeLabel.Layout.Column = 1;

            app.ViewModeDropDown = uidropdown(rightGrid);
            app.ViewModeDropDown.Items = {'Grid (Pixels)', 'Mercator', 'Mollweide'};
            app.ViewModeDropDown.Value = 'Grid (Pixels)';
            app.ViewModeDropDown.ValueChangedFcn = @(~,~) app.ViewModeDropDownValueChanged();
            app.ViewModeDropDown.Layout.Row = 2;
            app.ViewModeDropDown.Layout.Column = [2 3];

            % Row 3: Dot scale
            app.DotScaleLabel = uilabel(rightGrid);
            app.DotScaleLabel.Text = 'Dot Scale:';
            app.DotScaleLabel.Layout.Row = 3;
            app.DotScaleLabel.Layout.Column = 1;

            app.DotScaleSlider = uislider(rightGrid);
            app.DotScaleSlider.Limits = [10 200];
            app.DotScaleSlider.Value = 100;
            app.DotScaleSlider.MajorTicks = [];  % Hide tick labels (shown in separate label)
            app.DotScaleSlider.MinorTicks = [];
            app.DotScaleSlider.ValueChangedFcn = @(~,~) app.DotScaleSliderValueChanged();
            app.DotScaleSlider.Layout.Row = 3;
            app.DotScaleSlider.Layout.Column = 2;
            app.DotScaleSlider.Enable = 'off';

            app.DotScaleValueLabel = uilabel(rightGrid);
            app.DotScaleValueLabel.Text = '100%';
            app.DotScaleValueLabel.Layout.Row = 3;
            app.DotScaleValueLabel.Layout.Column = 3;

            % Row 4: FOV controls
            app.LonZoomButton = uibutton(rightGrid, 'push');
            app.LonZoomButton.Text = 'Lon+';
            app.LonZoomButton.ButtonPushedFcn = @(~,~) app.LonZoomButtonPushed();
            app.LonZoomButton.Layout.Row = 4;
            app.LonZoomButton.Layout.Column = 1;
            app.LonZoomButton.Enable = 'off';

            app.LonFOVValueLabel = uilabel(rightGrid);
            app.LonFOVValueLabel.Text = '±180°';
            app.LonFOVValueLabel.Layout.Row = 4;
            app.LonFOVValueLabel.Layout.Column = 2;

            app.LatZoomButton = uibutton(rightGrid, 'push');
            app.LatZoomButton.Text = 'Lat+';
            app.LatZoomButton.ButtonPushedFcn = @(~,~) app.LatZoomButtonPushed();
            app.LatZoomButton.Layout.Row = 5;
            app.LatZoomButton.Layout.Column = 1;
            app.LatZoomButton.Enable = 'off';

            app.LatFOVValueLabel = uilabel(rightGrid);
            app.LatFOVValueLabel.Text = '±90°';
            app.LatFOVValueLabel.Layout.Row = 5;
            app.LatFOVValueLabel.Layout.Column = 2;

            app.FOVResetButton = uibutton(rightGrid, 'push');
            app.FOVResetButton.Text = 'Reset FOV';
            app.FOVResetButton.ButtonPushedFcn = @(~,~) app.FOVResetButtonPushed();
            app.FOVResetButton.Layout.Row = 5;
            app.FOVResetButton.Layout.Column = 3;
            app.FOVResetButton.Enable = 'off';

            % Row 6: Arena info (auto-detected from pattern path)
            app.ArenaInfoLabel = uilabel(rightGrid);
            app.ArenaInfoLabel.Text = 'Arena: (auto-detected)';
            app.ArenaInfoLabel.Layout.Row = 6;
            app.ArenaInfoLabel.Layout.Column = [1 3];

            % Row 7: Panel outlines checkbox (left) and Panel IDs checkbox (right)
            app.ShowPanelOutlinesCheckbox = uicheckbox(rightGrid);
            app.ShowPanelOutlinesCheckbox.Text = 'Panel Outlines';
            app.ShowPanelOutlinesCheckbox.Value = false;
            app.ShowPanelOutlinesCheckbox.ValueChangedFcn = @(~,~) app.panelOutlinesChanged();
            app.ShowPanelOutlinesCheckbox.Layout.Row = 7;
            app.ShowPanelOutlinesCheckbox.Layout.Column = [1 2];

            app.ShowPanelIDsCheckbox = uicheckbox(rightGrid);
            app.ShowPanelIDsCheckbox.Text = 'Panel IDs';
            app.ShowPanelIDsCheckbox.Value = false;
            app.ShowPanelIDsCheckbox.Enable = 'off';
            app.ShowPanelIDsCheckbox.ValueChangedFcn = @(~,~) app.updatePreview();
            app.ShowPanelIDsCheckbox.Layout.Row = 7;
            app.ShowPanelIDsCheckbox.Layout.Column = 3;

            % === Row 4: Status bar ===
            app.StatusLabel = uilabel(app.GridLayout);
            app.StatusLabel.Text = 'Ready. Use File > Load Pattern to open a .pat file.';
            app.StatusLabel.Layout.Row = 4;
            app.StatusLabel.Layout.Column = 1;

            % Initialize
            app.initColormap();
            app.scanArenaConfigs();
            app.IsPlaying = false;

            % Show the figure
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        function app = PatternPreviewerApp
            % Construct app
            createComponents(app);

            % Register the app with App Designer
            registerApp(app, app.UIFigure);

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            % Delete UIFigure when app is deleted
            app.stopPlayback();
            delete(app.UIFigure);
        end
    end

    % Public API methods for inter-app communication
    methods (Access = public)

        function loadFile(app, filepath)
            % LOADFILE Load a .pat pattern file
            %
            % This is the public API for loading pattern files.
            %
            % Parameters:
            %   filepath - Full path to a .pat file
            %
            % Example:
            %   app = PatternPreviewerApp;
            %   app.loadFile('path/to/pattern.pat');

            app.loadPatternFile(filepath);
        end

        function loadPatternFromApp(app, Pats, stretch, gs_val, name, arenaConfig, isUnsaved)
            % LOADPATTERNFROMAPP Load pattern data from another app
            %
            % This is the public API for other apps (PatternGeneratorApp,
            % PatternCombinerApp, DrawingApp) to pass patterns to the previewer.
            %
            % Parameters:
            %   Pats        - 3D array (rows x cols x frames) of pattern data
            %   stretch     - 1D array (frames x 1) of stretch values per frame
            %                 Can also be a scalar (applied to all frames)
            %   gs_val      - Grayscale mode: 2 (binary) or 16 (4-bit grayscale)
            %   name        - (optional) Display name for the pattern
            %   arenaConfig - (optional) Arena config struct from load_arena_config()
            %                 RECOMMENDED: Pass explicitly rather than relying on
            %                 auto-detection from dimensions, which can be ambiguous
            %                 for partial arenas (e.g., G6_2x8of10 vs G6_2x10).
            %   isUnsaved   - (optional) Boolean flag to show "UNSAVED" warning label
            %                 Set to true when passing combined/generated patterns
            %                 that haven't been saved to disk yet.
            %
            % Example usage from PatternGeneratorApp:
            %   previewer = PatternPreviewerApp;
            %   previewer.loadPatternFromApp(app.Pats, app.Stretch, 16, 'grating', app.ArenaConfig);
            %
            % Example usage from PatternCombinerApp (with unsaved flag):
            %   previewer.loadPatternFromApp(combined, stretch, 16, 'combined', config, true);

            if nargin < 5 || isempty(name)
                name = 'pattern_from_app';
            end
            if nargin < 6
                arenaConfig = [];
            end
            if nargin < 7
                isUnsaved = false;
            end

            % Delegate to the private loadPatternData method
            app.loadPatternData(Pats, stretch, gs_val, name, arenaConfig, isUnsaved);
        end
    end
end

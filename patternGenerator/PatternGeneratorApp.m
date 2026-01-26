classdef PatternGeneratorApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                   matlab.ui.Figure
        GridLayout                 matlab.ui.container.GridLayout
        LeftPanel                  matlab.ui.container.Panel
        RightPanel                 matlab.ui.container.Panel

        % Left panel - Controls
        ArenaConfigLabel           matlab.ui.control.Label
        ArenaConfigDropDown        matlab.ui.control.DropDown
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

        GrayscaleLabel             matlab.ui.control.Label
        GrayscaleDropDown          matlab.ui.control.DropDown

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
            Pcols = cfg.arena.num_cols;
            Pcircle = Pcols;  % Assume full arena for now

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

            param.pattern_type = patternTypeMap(app.PatternTypeDropDown.Value);
            param.motion_type = motionTypeMap(app.MotionTypeDropDown.Value);
            param.pattern_fov = 'full-field';

            % Convert degrees to radians for angles
            param.spat_freq = deg2rad(app.SpatialFreqSpinner.Value);
            param.step_size = deg2rad(app.StepSizeSpinner.Value);

            % Grayscale value and levels
            if strcmp(app.GrayscaleDropDown.Value, 'Binary (1-bit)')
                param.gs_val = 1;
                param.levels = [1 0 0];  % [bright, dark, background] - max 1 for binary
            else
                param.gs_val = 4;
                param.levels = [15 0 0];  % [bright, dark, background] - max 15 for grayscale
            end

            % Default values for other parameters
            param.arena_pitch = 0;
            param.pole_coord = [0 pi/2];
            param.motion_angle = 0;
            param.duty_cycle = 50;
            param.num_dots = 100;
            param.dot_radius = deg2rad(5);
            param.dot_size = 'static';
            param.dot_occ = 'closest';
            param.dot_re_random = 1;
            param.dot_level = 0;
            param.snap_dots = 0;
            param.sa_mask = [0 0 pi 0];
            param.long_lat_mask = [-pi pi -pi/2 pi/2 0];
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

            % Calculate pixel counts
            app.PixelsH = cfg.arena.num_cols * specs.pixels_per_panel;
            app.PixelsV = cfg.arena.num_rows * specs.pixels_per_panel;
            numPanels = cfg.arena.num_rows * cfg.arena.num_cols;

            % Calculate degrees per pixel at equator
            % Full arena spans 360 degrees horizontally
            app.DegPerPixelH = 360 / app.PixelsH;

            % Display info (horizontal deg/px at equator)
            app.ArenaInfoText.Text = sprintf('%d panels, %dx%d px, %.3f deg/px horiz', ...
                numPanels, app.PixelsH, app.PixelsV, app.DegPerPixelH);

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

            % Display the frame with LED green colormap
            frameData = app.Pats(:, :, frame);
            imagesc(app.PreviewAxes, frameData);
            colormap(app.PreviewAxes, app.LEDColormap);
            axis(app.PreviewAxes, 'image');
            title(app.PreviewAxes, sprintf('Frame %d / %d', frame, app.NumFrames));

            app.FrameLabel.Text = sprintf('Frame: %d / %d', frame, app.NumFrames);
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
    end

    % Callbacks
    methods (Access = private)

        function ArenaConfigDropDownValueChanged(app, ~)
            app.loadArenaConfig();
        end

        function GenerateButtonPushed(app, ~)
            app.StatusLabel.Text = 'Generating pattern...';
            drawnow;

            try
                % Build handles struct
                handles = app.buildHandlesStruct();

                % Generate pattern
                [app.Pats, true_step_size, ~] = Pattern_Generator(handles);

                app.NumFrames = size(app.Pats, 3);
                app.CurrentFrame = 1;

                % Update slider with discrete ticks
                app.updateSliderTicks();
                app.FrameSlider.Value = 1;

                % Update preview
                app.updatePreview();

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

            % Get save location
            [filename, pathname] = uiputfile('*.pat', 'Save Pattern', 'pattern.pat');
            if isequal(filename, 0)
                return;
            end

            app.StatusLabel.Text = 'Saving pattern...';
            drawnow;

            try
                handles = app.buildHandlesStruct();
                param = handles.param;
                param.stretch = zeros(app.NumFrames, 1);
                param.ID = 1;  % Will be auto-assigned

                % Extract base name
                [~, patName, ~] = fileparts(filename);
                patName = regexprep(patName, '^pat\d{4}_', '');  % Remove pat#### prefix if present

                save_pattern(app.Pats, param, pathname, patName, [], ...
                    fullfile(handles.arena_folder, handles.arena_file));

                app.StatusLabel.Text = sprintf('Saved: %s', filename);

            catch ME
                app.StatusLabel.Text = sprintf('Save error: %s', ME.message);
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
            fprintf(fid, 'param.pole_coord = [0 pi/2];\n');
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

            % Initialize arena configs
            app.scanArenaConfigs();
            if ~isempty(app.ArenaConfigs)
                app.loadArenaConfig();
            end

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
            app.UIFigure.Position = [100 100 1350 600];
            app.UIFigure.Name = 'Pattern Generator';

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure, [1 2]);
            app.GridLayout.ColumnWidth = {'1x', '2x'};

            % Create Left Panel (Controls)
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.Title = 'Parameters';
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;

            leftGrid = uigridlayout(app.LeftPanel, [16 2]);
            leftGrid.RowHeight = repmat({25}, 1, 16);
            leftGrid.ColumnWidth = {'1x', '1x'};

            % Arena Config
            app.ArenaConfigLabel = uilabel(leftGrid);
            app.ArenaConfigLabel.Text = 'Arena Config:';
            app.ArenaConfigLabel.Layout.Row = 1;
            app.ArenaConfigLabel.Layout.Column = 1;

            app.ArenaConfigDropDown = uidropdown(leftGrid);
            app.ArenaConfigDropDown.Items = {'Loading...'};
            app.ArenaConfigDropDown.ValueChangedFcn = @(~,~) app.ArenaConfigDropDownValueChanged();
            app.ArenaConfigDropDown.Layout.Row = 1;
            app.ArenaConfigDropDown.Layout.Column = 2;

            % Generation (read-only)
            app.GenerationLabel = uilabel(leftGrid);
            app.GenerationLabel.Text = 'Generation:';
            app.GenerationLabel.Layout.Row = 2;
            app.GenerationLabel.Layout.Column = 1;

            app.GenerationText = uilabel(leftGrid);
            app.GenerationText.Text = 'N/A';
            app.GenerationText.FontWeight = 'bold';
            app.GenerationText.Layout.Row = 2;
            app.GenerationText.Layout.Column = 2;

            % Arena Info (read-only) - panels, pixels, deg/px
            app.ArenaInfoLabel = uilabel(leftGrid);
            app.ArenaInfoLabel.Text = 'Arena:';
            app.ArenaInfoLabel.Layout.Row = 3;
            app.ArenaInfoLabel.Layout.Column = 1;

            app.ArenaInfoText = uilabel(leftGrid);
            app.ArenaInfoText.Text = '';
            app.ArenaInfoText.FontSize = 10;
            app.ArenaInfoText.FontColor = [0.4 0.4 0.4];
            app.ArenaInfoText.Layout.Row = 3;
            app.ArenaInfoText.Layout.Column = 2;

            % Pattern Type
            app.PatternTypeLabel = uilabel(leftGrid);
            app.PatternTypeLabel.Text = 'Pattern Type:';
            app.PatternTypeLabel.Layout.Row = 4;
            app.PatternTypeLabel.Layout.Column = 1;

            app.PatternTypeDropDown = uidropdown(leftGrid);
            app.PatternTypeDropDown.Items = {'Square Grating', 'Sine Grating', 'Edge', 'Starfield', 'Off/On'};
            app.PatternTypeDropDown.Value = 'Square Grating';
            app.PatternTypeDropDown.Layout.Row = 4;
            app.PatternTypeDropDown.Layout.Column = 2;

            % Motion Type
            app.MotionTypeLabel = uilabel(leftGrid);
            app.MotionTypeLabel.Text = 'Motion Type:';
            app.MotionTypeLabel.Layout.Row = 5;
            app.MotionTypeLabel.Layout.Column = 1;

            app.MotionTypeDropDown = uidropdown(leftGrid);
            app.MotionTypeDropDown.Items = {'Rotation', 'Translation', 'Expansion-Contraction'};
            app.MotionTypeDropDown.Value = 'Rotation';
            app.MotionTypeDropDown.Layout.Row = 5;
            app.MotionTypeDropDown.Layout.Column = 2;

            % Spatial Frequency
            app.SpatialFreqLabel = uilabel(leftGrid);
            app.SpatialFreqLabel.Text = 'Spatial Freq (deg):';
            app.SpatialFreqLabel.Layout.Row = 6;
            app.SpatialFreqLabel.Layout.Column = 1;

            app.SpatialFreqSpinner = uispinner(leftGrid);
            app.SpatialFreqSpinner.Limits = [1 360];
            app.SpatialFreqSpinner.Value = 30;
            app.SpatialFreqSpinner.Layout.Row = 6;
            app.SpatialFreqSpinner.Layout.Column = 2;

            % Step Size
            app.StepSizeLabel = uilabel(leftGrid);
            app.StepSizeLabel.Text = 'Step Size (deg):';
            app.StepSizeLabel.Layout.Row = 7;
            app.StepSizeLabel.Layout.Column = 1;

            app.StepSizeSpinner = uispinner(leftGrid);
            app.StepSizeSpinner.Limits = [0.1 30];
            app.StepSizeSpinner.Value = 3;
            app.StepSizeSpinner.Step = 0.5;
            app.StepSizeSpinner.ValueChangedFcn = @(~,~) app.StepSizeSpinnerValueChanged();
            app.StepSizeSpinner.Layout.Row = 7;
            app.StepSizeSpinner.Layout.Column = 2;

            % Step Size Info (pixel equivalent)
            app.StepSizeInfoText = uilabel(leftGrid);
            app.StepSizeInfoText.Text = '';
            app.StepSizeInfoText.FontSize = 10;
            app.StepSizeInfoText.FontColor = [0.3 0.5 0.3];
            app.StepSizeInfoText.HorizontalAlignment = 'right';
            app.StepSizeInfoText.Layout.Row = 8;
            app.StepSizeInfoText.Layout.Column = [1 2];

            % Grayscale
            app.GrayscaleLabel = uilabel(leftGrid);
            app.GrayscaleLabel.Text = 'Grayscale:';
            app.GrayscaleLabel.Layout.Row = 9;
            app.GrayscaleLabel.Layout.Column = 1;

            app.GrayscaleDropDown = uidropdown(leftGrid);
            app.GrayscaleDropDown.Items = {'Grayscale (4-bit)', 'Binary (1-bit)'};
            app.GrayscaleDropDown.Value = 'Grayscale (4-bit)';
            app.GrayscaleDropDown.Layout.Row = 9;
            app.GrayscaleDropDown.Layout.Column = 2;

            % Buttons
            app.GenerateButton = uibutton(leftGrid, 'push');
            app.GenerateButton.Text = 'Generate';
            app.GenerateButton.ButtonPushedFcn = @(~,~) app.GenerateButtonPushed();
            app.GenerateButton.Layout.Row = 11;
            app.GenerateButton.Layout.Column = [1 2];
            app.GenerateButton.BackgroundColor = [0.3 0.6 0.3];
            app.GenerateButton.FontColor = [1 1 1];

            app.SaveButton = uibutton(leftGrid, 'push');
            app.SaveButton.Text = 'Save Pattern...';
            app.SaveButton.ButtonPushedFcn = @(~,~) app.SaveButtonPushed();
            app.SaveButton.Layout.Row = 12;
            app.SaveButton.Layout.Column = [1 2];

            app.ExportScriptButton = uibutton(leftGrid, 'push');
            app.ExportScriptButton.Text = 'Export Script...';
            app.ExportScriptButton.ButtonPushedFcn = @(~,~) app.ExportScriptButtonPushed();
            app.ExportScriptButton.Layout.Row = 13;
            app.ExportScriptButton.Layout.Column = [1 2];

            % Status
            app.StatusLabel = uilabel(leftGrid);
            app.StatusLabel.Text = 'Ready';
            app.StatusLabel.Layout.Row = 15;
            app.StatusLabel.Layout.Column = [1 2];

            % Create Right Panel (Preview)
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Title = 'Preview';
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;

            rightGrid = uigridlayout(app.RightPanel, [3 3]);
            rightGrid.RowHeight = {'1x', 60, 30};
            rightGrid.ColumnWidth = {'1x', 80, 80};
            rightGrid.Padding = [20 10 20 10];
            rightGrid.RowSpacing = 10;

            % Preview axes
            app.PreviewAxes = uiaxes(rightGrid);
            app.PreviewAxes.Layout.Row = 1;
            app.PreviewAxes.Layout.Column = [1 3];
            title(app.PreviewAxes, 'No pattern generated');

            % Frame slider with enough space for tick labels
            app.FrameSlider = uislider(rightGrid);
            app.FrameSlider.Limits = [1 10];
            app.FrameSlider.Value = 1;
            app.FrameSlider.MajorTicks = 1:10;
            app.FrameSlider.MinorTicks = [];
            app.FrameSlider.ValueChangedFcn = @(~,~) app.FrameSliderValueChanged();
            app.FrameSlider.Layout.Row = 2;
            app.FrameSlider.Layout.Column = [1 3];

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
            app.PlayButton.Layout.Column = 2;
            app.PlayButton.BackgroundColor = [0.3 0.5 0.7];
            app.PlayButton.FontColor = [1 1 1];

            app.FPSDropDown = uidropdown(rightGrid);
            app.FPSDropDown.Items = {'1 fps', '5 fps', '10 fps', '20 fps'};
            app.FPSDropDown.Value = '5 fps';
            app.FPSDropDown.ValueChangedFcn = @(~,~) app.FPSDropDownValueChanged();
            app.FPSDropDown.Layout.Row = 3;
            app.FPSDropDown.Layout.Column = 3;

            % Show the figure
            app.UIFigure.Visible = 'on';
        end
    end
end

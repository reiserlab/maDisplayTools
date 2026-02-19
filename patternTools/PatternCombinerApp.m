classdef PatternCombinerApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                   matlab.ui.Figure
        MainGrid                   matlab.ui.container.GridLayout

        % Top row - Mode selection and Reset
        ModeLabel                  matlab.ui.control.Label
        SequentialRadio            matlab.ui.control.RadioButton
        MaskRadio                  matlab.ui.control.RadioButton
        LeftRightRadio             matlab.ui.control.RadioButton
        ModeButtonGroup            matlab.ui.container.ButtonGroup
        ResetButton                matlab.ui.control.Button

        % Three columns
        Pat1Panel                  matlab.ui.container.Panel
        MiddlePanel                matlab.ui.container.Panel
        Pat2Panel                  matlab.ui.container.Panel

        % Pattern 1 controls
        Pat1SelectButton           matlab.ui.control.Button
        Pat1InfoPanel              matlab.ui.container.Panel
        Pat1NameValue              matlab.ui.control.Label
        Pat1SizeLabel              matlab.ui.control.Label
        Pat1SizeValue              matlab.ui.control.Label
        Pat1FramesLabel            matlab.ui.control.Label
        Pat1FramesValue            matlab.ui.control.Label
        Pat1GSLabel                matlab.ui.control.Label
        Pat1GSValue                matlab.ui.control.Label
        Pat1ArenaLabel             matlab.ui.control.Label
        Pat1ArenaValue             matlab.ui.control.Label

        % Pattern 2 controls
        Pat2DropDown               matlab.ui.control.DropDown
        Pat2DropDownLabel          matlab.ui.control.Label
        Pat2InfoPanel              matlab.ui.container.Panel
        Pat2NameValue              matlab.ui.control.Label
        Pat2SizeLabel              matlab.ui.control.Label
        Pat2SizeValue              matlab.ui.control.Label
        Pat2FramesLabel            matlab.ui.control.Label
        Pat2FramesValue            matlab.ui.control.Label
        Pat2GSLabel                matlab.ui.control.Label
        Pat2GSValue                matlab.ui.control.Label

        % Middle column controls
        SwapButton                 matlab.ui.control.Button
        CombineButton              matlab.ui.control.Button  % Now does Combine & Preview
        SaveButton                 matlab.ui.control.Button

        % Mode-specific options (in middle panel)
        MaskOptionsPanel           matlab.ui.container.Panel
        MaskModeLabel              matlab.ui.control.Label
        MaskReplaceRadio           matlab.ui.control.RadioButton
        MaskBlendRadio             matlab.ui.control.RadioButton
        MaskModeGroup              matlab.ui.container.ButtonGroup
        ThresholdLabel             matlab.ui.control.Label
        ThresholdSpinner           matlab.ui.control.Spinner
        BinaryOpLabel              matlab.ui.control.Label
        BinaryOpDropDown           matlab.ui.control.DropDown

        LeftRightOptionsPanel      matlab.ui.container.Panel
        SplitLabel                 matlab.ui.control.Label
        SplitSlider                matlab.ui.control.Slider
        SplitValueLabel            matlab.ui.control.Label

        % Combined pattern info
        CombinedInfoPanel          matlab.ui.container.Panel
        CombinedNameValue          matlab.ui.control.Label
        CombinedSizeLabel          matlab.ui.control.Label
        CombinedSizeValue          matlab.ui.control.Label
        CombinedFramesLabel        matlab.ui.control.Label
        CombinedFramesValue        matlab.ui.control.Label

        % Save name edit field (at bottom)
        SaveNameLabel              matlab.ui.control.Label
        SaveNameEditField          matlab.ui.control.EditField

        % Status bar
        StatusLabel                matlab.ui.control.Label
    end

    properties (Access = private)
        maDisplayToolsRoot         % Root path of maDisplayTools

        % Pattern 1 data
        Pat1Pats                   % Pattern data (rows x cols x frames)
        Pat1Stretch                % Stretch values
        Pat1GSVal                  % Grayscale (2 or 16)
        Pat1Name                   % Pattern name (without extension)
        Pat1Path                   % Full path to pattern file
        Pat1Dir                    % Directory containing pattern
        Pat1Meta                   % Metadata from load_pat

        % Pattern 2 data
        Pat2Pats
        Pat2Stretch
        Pat2GSVal
        Pat2Name
        Pat2Path
        Pat2Meta

        % Arena config (from Pattern 1's directory)
        ArenaConfig                % Arena config struct
        ArenaName                  % Arena name (directory name)

        % Available patterns in directory (for dropdown)
        AvailablePatterns          % Cell array of pattern filenames

        % Combined pattern
        CombinedPats
        CombinedStretch
        CombinedName

        % State
        PatternsLocked = false     % Whether pattern selection is locked
        PreviewerApp               % Handle to PatternPreviewerApp instance
        LastSuggestedName = ''     % Track last auto-generated name to detect user edits
    end

    methods (Access = private)

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

        function loadPattern1(app, filepath)
            % Load Pattern 1 and set up arena config
            try
                app.StatusLabel.Text = 'Loading Pattern 1...';
                drawnow;

                [frames, meta] = maDisplayTools.load_pat(filepath);

                % Store pattern data (reshape to rows x cols x frames)
                app.Pat1Meta = meta;
                numFrames = meta.NumPatsX * meta.NumPatsY;
                rows = meta.rows;
                cols = meta.cols;

                app.Pat1Pats = zeros(rows, cols, numFrames, 'uint8');
                app.Pat1Stretch = zeros(numFrames, 1);

                frame_idx = 1;
                for y = 1:meta.NumPatsY
                    for x = 1:meta.NumPatsX
                        app.Pat1Pats(:, :, frame_idx) = squeeze(frames(y, x, :, :));
                        app.Pat1Stretch(frame_idx) = meta.stretch(y, x);
                        frame_idx = frame_idx + 1;
                    end
                end

                app.Pat1GSVal = (meta.vmax == 15) * 14 + 2;  % 16 if grayscale, 2 if binary
                app.Pat1Path = filepath;

                [app.Pat1Dir, app.Pat1Name, ~] = fileparts(filepath);
                [~, app.ArenaName] = fileparts(app.Pat1Dir);

                % Update UI
                app.Pat1NameValue.Text = app.Pat1Name;
                app.Pat1SizeValue.Text = sprintf('%d x %d', rows, cols);
                app.Pat1FramesValue.Text = sprintf('%d', numFrames);
                app.Pat1GSValue.Text = app.gsValToString(app.Pat1GSVal);

                % Load arena config
                app.loadArenaConfig();

                % Populate Pattern 2 dropdown with compatible patterns
                app.populatePattern2Dropdown();

                % Update split slider limits based on pattern width
                app.SplitSlider.Limits = [0, cols - 1];
                app.SplitSlider.Value = floor(cols / 2);
                app.SplitValueLabel.Text = sprintf('%d', floor(cols / 2));

                % Update mask threshold spinner limits
                if app.Pat1GSVal == 16
                    app.ThresholdSpinner.Limits = [0, 15];
                    app.ThresholdSpinner.Visible = 'on';
                    app.ThresholdLabel.Visible = 'on';
                    app.BinaryOpDropDown.Visible = 'off';
                    app.BinaryOpLabel.Visible = 'off';
                else
                    app.ThresholdSpinner.Visible = 'off';
                    app.ThresholdLabel.Visible = 'off';
                    app.BinaryOpDropDown.Visible = 'on';
                    app.BinaryOpLabel.Visible = 'on';
                end

                app.StatusLabel.Text = sprintf('Loaded: %s', app.Pat1Name);

                % Bring all pattern apps to front (prevent MATLAB workspace from stealing focus)
                app.bringAllPatternAppsToFront();

            catch ME
                app.StatusLabel.Text = sprintf('Error: %s', ME.message);
                uialert(app.UIFigure, ME.message, 'Load Error');
            end
        end

        function loadArenaConfig(app)
            % Try to load arena config from pattern directory name
            try
                configPath = fullfile(app.maDisplayToolsRoot, 'configs', 'arenas', [app.ArenaName '.yaml']);

                if exist(configPath, 'file')
                    app.ArenaConfig = load_arena_config(configPath);
                    app.Pat1ArenaValue.Text = app.ArenaName;
                else
                    app.ArenaConfig = [];
                    app.Pat1ArenaValue.Text = sprintf('%s (no config)', app.ArenaName);
                end
            catch ME
                app.ArenaConfig = [];
                app.Pat1ArenaValue.Text = sprintf('Error: %s', ME.message);
            end
        end

        function populatePattern2Dropdown(app)
            % Scan Pattern 1's directory for compatible patterns
            patFiles = dir(fullfile(app.Pat1Dir, '*.pat'));

            app.AvailablePatterns = {};
            items = {'-- Select Pattern 2 --'};
            itemsData = {''};

            for i = 1:length(patFiles)
                filename = patFiles(i).name;
                [~, name, ~] = fileparts(filename);

                % Skip Pattern 1
                if strcmp(name, app.Pat1Name)
                    continue;
                end

                % Quick check: try to load and verify GS compatibility
                try
                    fullPath = fullfile(app.Pat1Dir, filename);
                    [~, meta] = maDisplayTools.load_pat(fullPath);
                    gs_val = (meta.vmax == 15) * 14 + 2;

                    % Only show patterns with matching GS value
                    if gs_val == app.Pat1GSVal
                        items{end+1} = name;
                        itemsData{end+1} = fullPath;
                        app.AvailablePatterns{end+1} = fullPath;
                    end
                catch
                    % Skip patterns that can't be loaded
                end
            end

            app.Pat2DropDown.Items = items;
            app.Pat2DropDown.ItemsData = itemsData;
            app.Pat2DropDown.Value = '';
            app.Pat2DropDown.Enable = 'on';
        end

        function loadPattern2(app, filepath)
            % Load Pattern 2
            if isempty(filepath)
                return;
            end

            try
                app.StatusLabel.Text = 'Loading Pattern 2...';
                drawnow;

                [frames, meta] = maDisplayTools.load_pat(filepath);

                % Store pattern data
                app.Pat2Meta = meta;
                numFrames = meta.NumPatsX * meta.NumPatsY;
                rows = meta.rows;
                cols = meta.cols;

                app.Pat2Pats = zeros(rows, cols, numFrames, 'uint8');
                app.Pat2Stretch = zeros(numFrames, 1);

                frame_idx = 1;
                for y = 1:meta.NumPatsY
                    for x = 1:meta.NumPatsX
                        app.Pat2Pats(:, :, frame_idx) = squeeze(frames(y, x, :, :));
                        app.Pat2Stretch(frame_idx) = meta.stretch(y, x);
                        frame_idx = frame_idx + 1;
                    end
                end

                app.Pat2GSVal = (meta.vmax == 15) * 14 + 2;
                app.Pat2Path = filepath;
                [~, app.Pat2Name, ~] = fileparts(filepath);

                % Update UI
                app.Pat2NameValue.Text = app.Pat2Name;
                app.Pat2SizeValue.Text = sprintf('%d x %d', rows, cols);
                app.Pat2FramesValue.Text = sprintf('%d', numFrames);
                app.Pat2GSValue.Text = app.gsValToString(app.Pat2GSVal);

                % Validate compatibility
                [valid, msg] = app.validatePatterns();
                if ~valid
                    app.StatusLabel.Text = msg;
                    uialert(app.UIFigure, msg, 'Compatibility Error');
                    return;
                end

                % Lock patterns and enable controls
                app.PatternsLocked = true;
                app.Pat1SelectButton.Enable = 'off';
                app.Pat2DropDown.Enable = 'off';
                app.SwapButton.Enable = 'on';
                app.CombineButton.Enable = 'on';

                app.updateCombinedInfo();
                app.StatusLabel.Text = sprintf('Loaded: %s (ready to combine)', app.Pat2Name);

                % Bring all pattern apps to front (prevent MATLAB workspace from stealing focus)
                app.bringAllPatternAppsToFront();

            catch ME
                app.StatusLabel.Text = sprintf('Error: %s', ME.message);
                uialert(app.UIFigure, ME.message, 'Load Error');
            end
        end

        function [valid, msg] = validatePatterns(app)
            % Validate that patterns can be combined
            valid = true;
            msg = '';

            % Check GS values match
            if app.Pat1GSVal ~= app.Pat2GSVal
                valid = false;
                msg = sprintf('Grayscale mismatch: Pattern 1 is %s, Pattern 2 is %s', ...
                    app.gsValToString(app.Pat1GSVal), app.gsValToString(app.Pat2GSVal));
                return;
            end

            % Check dimensions for spatial modes
            mode = app.getSelectedMode();
            if strcmp(mode, 'mask') || strcmp(mode, 'leftright')
                [r1, c1, ~] = size(app.Pat1Pats);
                [r2, c2, ~] = size(app.Pat2Pats);
                if r1 ~= r2 || c1 ~= c2
                    valid = false;
                    msg = sprintf('Size mismatch for spatial combination: %dx%d vs %dx%d', r1, c1, r2, c2);
                    return;
                end
            end
        end

        function mode = getSelectedMode(app)
            % Get the currently selected combination mode
            if app.SequentialRadio.Value
                mode = 'sequential';
            elseif app.MaskRadio.Value
                mode = 'mask';
            else
                mode = 'leftright';
            end
        end

        function str = gsValToString(~, gs_val)
            if gs_val == 16
                str = '4-bit (0-15)';
            else
                str = 'Binary (0-1)';
            end
        end

        function combinePatterns(app)
            % Perform the actual pattern combination
            mode = app.getSelectedMode();

            switch mode
                case 'sequential'
                    app.combineSequential();
                case 'mask'
                    app.combineMask();
                case 'leftright'
                    app.combineLeftRight();
            end

            app.SaveButton.Enable = 'on';

            % Auto-preview after combine
            app.previewCombined();
            app.updateCombinedInfo();
        end

        function combineSequential(app)
            % Concatenate patterns temporally
            [~, ~, f1] = size(app.Pat1Pats);
            [~, ~, f2] = size(app.Pat2Pats);

            % Check for stretch value differences
            stretchMatch = isequal(app.Pat1Stretch, app.Pat2Stretch);
            if ~stretchMatch && f1 == f2
                % Same frame count but different stretches
                stretchMatch = all(app.Pat1Stretch == app.Pat2Stretch);
            end

            if ~stretchMatch
                % Ask user how to handle stretch
                selection = uiconfirm(app.UIFigure, ...
                    'Stretch values differ between patterns. How would you like to combine them?', ...
                    'Stretch Values', ...
                    'Options', {'Concatenate as-is', 'Use uniform value', 'Cancel'}, ...
                    'DefaultOption', 1);

                switch selection
                    case 'Concatenate as-is'
                        app.CombinedStretch = [app.Pat1Stretch(:); app.Pat2Stretch(:)];
                    case 'Use uniform value'
                        % Use the most common stretch value
                        allStretch = [app.Pat1Stretch(:); app.Pat2Stretch(:)];
                        uniformVal = mode(allStretch);
                        app.CombinedStretch = ones(f1 + f2, 1) * uniformVal;
                    case 'Cancel'
                        return;
                end
            else
                app.CombinedStretch = [app.Pat1Stretch(:); app.Pat2Stretch(:)];
            end

            % Concatenate frames
            app.CombinedPats = cat(3, app.Pat1Pats, app.Pat2Pats);
            app.CombinedName = sprintf('%s_then_%s', app.Pat1Name, app.Pat2Name);

            app.StatusLabel.Text = sprintf('Combined: %d + %d = %d frames (sequential)', f1, f2, f1 + f2);
        end

        function combineMask(app)
            % Combine patterns using mask/blend mode
            [r1, c1, f1] = size(app.Pat1Pats);
            [~, ~, f2] = size(app.Pat2Pats);

            % Handle frame count mismatch
            if f1 ~= f2
                minFrames = min(f1, f2);
                selection = uiconfirm(app.UIFigure, ...
                    sprintf('Frame count mismatch: %d vs %d frames. Truncate to %d frames?', f1, f2, minFrames), ...
                    'Frame Mismatch', ...
                    'Options', {'Truncate', 'Cancel'}, ...
                    'DefaultOption', 1);

                if strcmp(selection, 'Cancel')
                    return;
                end

                pat1 = app.Pat1Pats(:, :, 1:minFrames);
                pat2 = app.Pat2Pats(:, :, 1:minFrames);
                stretch1 = app.Pat1Stretch(1:minFrames);
                numFrames = minFrames;
            else
                pat1 = app.Pat1Pats;
                pat2 = app.Pat2Pats;
                stretch1 = app.Pat1Stretch;
                numFrames = f1;
            end

            app.CombinedPats = zeros(r1, c1, numFrames, 'uint8');

            if app.Pat1GSVal == 16
                % Grayscale mode
                if app.MaskReplaceRadio.Value
                    % Replace at threshold
                    threshold = app.ThresholdSpinner.Value;
                    for f = 1:numFrames
                        frame1 = pat1(:, :, f);
                        frame2 = pat2(:, :, f);
                        combined = frame1;
                        mask = (frame1 == threshold);
                        combined(mask) = frame2(mask);
                        app.CombinedPats(:, :, f) = combined;
                    end
                    app.StatusLabel.Text = sprintf('Combined: replaced pixels at value %d', threshold);
                else
                    % 50% blend
                    for f = 1:numFrames
                        frame1 = double(pat1(:, :, f));
                        frame2 = double(pat2(:, :, f));
                        combined = round((frame1 + frame2) / 2);
                        combined = min(max(combined, 0), 15);  % Clamp to 0-15
                        app.CombinedPats(:, :, f) = uint8(combined);
                    end
                    app.StatusLabel.Text = 'Combined: 50% blend';
                end
            else
                % Binary mode - use logical operators
                op = app.BinaryOpDropDown.Value;
                for f = 1:numFrames
                    frame1 = logical(pat1(:, :, f));
                    frame2 = logical(pat2(:, :, f));

                    switch op
                        case 'OR'
                            combined = frame1 | frame2;
                        case 'AND'
                            combined = frame1 & frame2;
                        case 'XOR'
                            combined = xor(frame1, frame2);
                    end

                    app.CombinedPats(:, :, f) = uint8(combined);
                end
                app.StatusLabel.Text = sprintf('Combined: binary %s', op);
            end

            app.CombinedStretch = stretch1;
            % Name based on mask mode
            if app.Pat1GSVal == 16
                if app.MaskReplaceRadio.Value
                    app.CombinedName = sprintf('%s_mask%d_%s', app.Pat1Name, app.ThresholdSpinner.Value, app.Pat2Name);
                else
                    app.CombinedName = sprintf('%s_blend_%s', app.Pat1Name, app.Pat2Name);
                end
            else
                app.CombinedName = sprintf('%s_%s_%s', app.Pat1Name, app.BinaryOpDropDown.Value, app.Pat2Name);
            end
        end

        function combineLeftRight(app)
            % Combine patterns spatially (left/right split)
            [r1, c1, f1] = size(app.Pat1Pats);
            [~, ~, f2] = size(app.Pat2Pats);

            % Handle frame count mismatch
            if f1 ~= f2
                minFrames = min(f1, f2);
                selection = uiconfirm(app.UIFigure, ...
                    sprintf('Frame count mismatch: %d vs %d frames. Truncate to %d frames?', f1, f2, minFrames), ...
                    'Frame Mismatch', ...
                    'Options', {'Truncate', 'Cancel'}, ...
                    'DefaultOption', 1);

                if strcmp(selection, 'Cancel')
                    return;
                end

                pat1 = app.Pat1Pats(:, :, 1:minFrames);
                pat2 = app.Pat2Pats(:, :, 1:minFrames);
                stretch1 = app.Pat1Stretch(1:minFrames);
                numFrames = minFrames;
            else
                pat1 = app.Pat1Pats;
                pat2 = app.Pat2Pats;
                stretch1 = app.Pat1Stretch;
                numFrames = f1;
            end

            splitCol = round(app.SplitSlider.Value);
            app.CombinedPats = zeros(r1, c1, numFrames, 'uint8');

            for f = 1:numFrames
                combined = zeros(r1, c1, 'uint8');
                % Pattern 1 on left (columns 1 to splitCol)
                if splitCol > 0
                    combined(:, 1:splitCol, :) = pat1(:, 1:splitCol, f);
                end
                % Pattern 2 on right (columns splitCol+1 to end)
                if splitCol < c1
                    combined(:, (splitCol+1):end, :) = pat2(:, (splitCol+1):end, f);
                end
                app.CombinedPats(:, :, f) = combined;
            end

            app.CombinedStretch = stretch1;
            app.CombinedName = sprintf('%s_LR%d_%s', app.Pat1Name, splitCol, app.Pat2Name);

            app.StatusLabel.Text = sprintf('Combined: left/right split at column %d', splitCol);
        end

        function swapPatterns(app)
            % Swap Pattern 1 and Pattern 2
            tempPats = app.Pat1Pats;
            tempStretch = app.Pat1Stretch;
            tempGS = app.Pat1GSVal;
            tempName = app.Pat1Name;
            tempPath = app.Pat1Path;
            tempMeta = app.Pat1Meta;

            app.Pat1Pats = app.Pat2Pats;
            app.Pat1Stretch = app.Pat2Stretch;
            app.Pat1GSVal = app.Pat2GSVal;
            app.Pat1Name = app.Pat2Name;
            app.Pat1Path = app.Pat2Path;
            app.Pat1Meta = app.Pat2Meta;

            app.Pat2Pats = tempPats;
            app.Pat2Stretch = tempStretch;
            app.Pat2GSVal = tempGS;
            app.Pat2Name = tempName;
            app.Pat2Path = tempPath;
            app.Pat2Meta = tempMeta;

            % Update UI labels
            app.Pat1NameValue.Text = app.Pat1Name;
            [r1, c1, f1] = size(app.Pat1Pats);
            app.Pat1SizeValue.Text = sprintf('%d x %d', r1, c1);
            app.Pat1FramesValue.Text = sprintf('%d', f1);

            app.Pat2NameValue.Text = app.Pat2Name;
            [r2, c2, f2] = size(app.Pat2Pats);
            app.Pat2SizeValue.Text = sprintf('%d x %d', r2, c2);
            app.Pat2FramesValue.Text = sprintf('%d', f2);

            % Update combined info (including suggested name)
            % Clear the edit field so it gets updated with new suggested name
            app.SaveNameEditField.Value = '';
            app.updateCombinedInfo();

            app.StatusLabel.Text = 'Patterns swapped';
        end

        function updateCombinedInfo(app)
            % Update the combined pattern info display
            mode = app.getSelectedMode();

            if isempty(app.Pat1Pats) || isempty(app.Pat2Pats)
                app.CombinedSizeValue.Text = '--';
                app.CombinedFramesValue.Text = '--';
                app.CombinedNameValue.Text = '(none)';
                app.SaveNameEditField.Value = '';
                return;
            end

            [r1, c1, f1] = size(app.Pat1Pats);
            [~, ~, f2] = size(app.Pat2Pats);

            if strcmp(mode, 'sequential')
                app.CombinedSizeValue.Text = sprintf('%d x %d', r1, c1);
                app.CombinedFramesValue.Text = sprintf('%d', f1 + f2);
                suggestedName = sprintf('%s_then_%s', app.Pat1Name, app.Pat2Name);
            elseif strcmp(mode, 'mask')
                minFrames = min(f1, f2);
                app.CombinedSizeValue.Text = sprintf('%d x %d', r1, c1);
                if f1 ~= f2
                    app.CombinedFramesValue.Text = sprintf('%d (truncated)', minFrames);
                else
                    app.CombinedFramesValue.Text = sprintf('%d', minFrames);
                end
                % Generate name based on mask mode
                if app.Pat1GSVal == 16
                    if app.MaskReplaceRadio.Value
                        suggestedName = sprintf('%s_mask%d_%s', app.Pat1Name, app.ThresholdSpinner.Value, app.Pat2Name);
                    else
                        suggestedName = sprintf('%s_blend_%s', app.Pat1Name, app.Pat2Name);
                    end
                else
                    suggestedName = sprintf('%s_%s_%s', app.Pat1Name, app.BinaryOpDropDown.Value, app.Pat2Name);
                end
            else  % leftright
                minFrames = min(f1, f2);
                app.CombinedSizeValue.Text = sprintf('%d x %d', r1, c1);
                if f1 ~= f2
                    app.CombinedFramesValue.Text = sprintf('%d (truncated)', minFrames);
                else
                    app.CombinedFramesValue.Text = sprintf('%d', minFrames);
                end
                splitCol = round(app.SplitSlider.Value);
                suggestedName = sprintf('%s_LR%d_%s', app.Pat1Name, splitCol, app.Pat2Name);
            end

            app.CombinedNameValue.Text = suggestedName;
            % Update edit field if:
            % 1. It's empty, OR
            % 2. It still matches the last auto-suggested name (user hasn't edited it)
            currentValue = app.SaveNameEditField.Value;
            if isempty(currentValue) || strcmp(currentValue, app.LastSuggestedName)
                app.SaveNameEditField.Value = suggestedName;
            end
            app.LastSuggestedName = suggestedName;
        end

        function previewCombined(app)
            % Launch or reuse PatternPreviewerApp and send combined pattern
            if isempty(app.CombinedPats)
                uialert(app.UIFigure, 'No combined pattern. Click Combine first.', 'Preview Error');
                return;
            end

            try
                % Check if our stored previewer exists and is valid
                if isempty(app.PreviewerApp) || ~isvalid(app.PreviewerApp)
                    % Try to find an existing PatternPreviewerApp window
                    app.PreviewerApp = app.findExistingPreviewer();

                    % If no existing previewer found, create a new one
                    if isempty(app.PreviewerApp)
                        app.PreviewerApp = PatternPreviewerApp();
                    end
                end

                % Send combined pattern to previewer
                app.PreviewerApp.loadPatternFromApp(app.CombinedPats, app.CombinedStretch, ...
                    app.Pat1GSVal, app.CombinedName, app.ArenaConfig, true);  % true = unsaved flag

                % Bring previewer window to front
                figure(app.PreviewerApp.UIFigure);

                app.StatusLabel.Text = 'Preview opened';

            catch ME
                app.StatusLabel.Text = sprintf('Preview error: %s', ME.message);
                uialert(app.UIFigure, ME.message, 'Preview Error');
            end
        end

        function previewer = findExistingPreviewer(~)
            % Find an existing PatternPreviewerApp window if one exists
            previewer = [];

            % Get all open figures
            figs = findall(0, 'Type', 'figure');

            for i = 1:length(figs)
                % Check if this figure belongs to a PatternPreviewerApp
                if isprop(figs(i), 'Name') && strcmp(figs(i).Name, 'Pattern Previewer')
                    % Try to get the app object from the figure's RunningAppInstance
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

        function saveCombined(app)
            % Save the combined pattern
            if isempty(app.CombinedPats)
                uialert(app.UIFigure, 'No combined pattern. Click Combine first.', 'Save Error');
                return;
            end

            try
                app.StatusLabel.Text = 'Saving...';
                drawnow;

                % Get save name from edit field (or use generated name)
                saveName = app.SaveNameEditField.Value;
                if isempty(saveName)
                    saveName = app.CombinedName;
                end

                % Build param struct
                param = struct();
                param.gs_val = app.Pat1GSVal;
                param.stretch = app.CombinedStretch;

                % Determine generation from arena config
                if ~isempty(app.ArenaConfig)
                    param.generation = app.ArenaConfig.arena.generation;
                    param.arena_config = app.ArenaConfig;
                else
                    param.generation = 'G4';  % Default fallback
                end

                % Reshape Pats for save_pattern (expects 4D: rows x cols x NumPatsX x NumPatsY)
                [rows, cols, numFrames] = size(app.CombinedPats);
                Pats4D = reshape(app.CombinedPats, [rows, cols, numFrames, 1]);

                % Save to Pattern 1's directory
                save_pattern(Pats4D, param, app.Pat1Dir, saveName);

                app.StatusLabel.Text = sprintf('Saved: %s', saveName);

            catch ME
                app.StatusLabel.Text = sprintf('Save error: %s', ME.message);
                uialert(app.UIFigure, ME.message, 'Save Error');
            end
        end

        function resetApp(app)
            % Reset the app to initial state
            app.Pat1Pats = [];
            app.Pat1Stretch = [];
            app.Pat1GSVal = [];
            app.Pat1Name = '';
            app.Pat1Path = '';
            app.Pat1Dir = '';
            app.Pat1Meta = [];

            app.Pat2Pats = [];
            app.Pat2Stretch = [];
            app.Pat2GSVal = [];
            app.Pat2Name = '';
            app.Pat2Path = '';
            app.Pat2Meta = [];

            app.ArenaConfig = [];
            app.ArenaName = '';
            app.AvailablePatterns = {};

            app.CombinedPats = [];
            app.CombinedStretch = [];
            app.CombinedName = '';
            app.LastSuggestedName = '';

            app.PatternsLocked = false;

            % Reset UI
            app.Pat1NameValue.Text = '(none)';
            app.Pat1SizeValue.Text = '--';
            app.Pat1FramesValue.Text = '--';
            app.Pat1GSValue.Text = '--';
            app.Pat1ArenaValue.Text = '--';

            app.Pat2DropDown.Items = {'-- Select Pattern 1 first --'};
            app.Pat2DropDown.ItemsData = {''};
            app.Pat2DropDown.Value = '';
            app.Pat2DropDown.Enable = 'off';
            app.Pat2NameValue.Text = '(none)';
            app.Pat2SizeValue.Text = '--';
            app.Pat2FramesValue.Text = '--';
            app.Pat2GSValue.Text = '--';

            app.CombinedNameValue.Text = '(none)';
            app.CombinedSizeValue.Text = '--';
            app.CombinedFramesValue.Text = '--';
            app.SaveNameEditField.Value = '';

            app.Pat1SelectButton.Enable = 'on';
            app.SwapButton.Enable = 'off';
            app.CombineButton.Enable = 'off';
            app.SaveButton.Enable = 'off';

            app.SequentialRadio.Value = true;
            app.SplitSlider.Value = 0;
            app.SplitValueLabel.Text = '0';
            app.ThresholdSpinner.Value = 0;

            app.updateModeOptions();

            app.StatusLabel.Text = 'Reset. Select Pattern 1 to begin.';
        end

        function updateModeOptions(app)
            % Show/hide mode-specific options based on selected mode
            mode = app.getSelectedMode();

            if strcmp(mode, 'mask')
                app.MaskOptionsPanel.Visible = 'on';
                app.LeftRightOptionsPanel.Visible = 'off';
            elseif strcmp(mode, 'leftright')
                app.MaskOptionsPanel.Visible = 'off';
                app.LeftRightOptionsPanel.Visible = 'on';
            else
                % Sequential - hide both
                app.MaskOptionsPanel.Visible = 'off';
                app.LeftRightOptionsPanel.Visible = 'off';
            end

            app.updateCombinedInfo();
        end
    end

    % Callbacks
    methods (Access = private)

        function Pat1SelectButtonPushed(app, ~)
            % Open file dialog to select Pattern 1
            startPath = fullfile(app.maDisplayToolsRoot, 'patterns');
            if ~exist(startPath, 'dir')
                startPath = app.maDisplayToolsRoot;
            end

            [file, path] = uigetfile('*.pat', 'Select Pattern 1', startPath);
            if isequal(file, 0)
                return;
            end
            app.loadPattern1(fullfile(path, file));
        end

        function Pat2DropDownValueChanged(app, ~)
            filepath = app.Pat2DropDown.Value;
            if ~isempty(filepath)
                app.loadPattern2(filepath);
            end
        end

        function ModeChanged(app, ~)
            app.updateModeOptions();
            % Clear combined result when mode changes
            app.CombinedPats = [];
            app.SaveButton.Enable = 'off';
        end

        function SwapButtonPushed(app, ~)
            app.swapPatterns();
        end

        function CombineButtonPushed(app, ~)
            app.combinePatterns();  % This now also calls previewCombined()
        end

        function SaveButtonPushed(app, ~)
            app.saveCombined();
        end

        function ResetButtonPushed(app, ~)
            app.resetApp();
        end

        function SplitSliderValueChanged(app, ~)
            val = round(app.SplitSlider.Value);
            app.SplitSlider.Value = val;
            app.SplitValueLabel.Text = sprintf('%d', val);
            % Update suggested name when split position changes
            app.updateCombinedInfo();
        end

        function MaskModeChanged(app, ~)
            % Show/hide threshold spinner based on mask mode
            if app.MaskReplaceRadio.Value
                app.ThresholdSpinner.Enable = 'on';
                app.ThresholdLabel.Enable = 'on';
            else
                app.ThresholdSpinner.Enable = 'off';
                app.ThresholdLabel.Enable = 'off';
            end
            % Update suggested name when mask mode changes
            app.updateCombinedInfo();
        end

        function ThresholdValueChanged(app, ~)
            % Update suggested name when threshold changes
            app.updateCombinedInfo();
        end

        function BinaryOpChanged(app, ~)
            % Update suggested name when binary operation changes
            app.updateCombinedInfo();
        end

        function UIFigureCloseRequest(app, ~)
            % Save window position before closing
            if isvalid(app.UIFigure)
                setpref('maDisplayTools', 'PatternCombinerPosition', app.UIFigure.Position);
            end
            delete(app);
        end
    end

    % Component initialization
    methods (Access = private)

        function createComponents(app)
            % Get maDisplayTools root
            appPath = fileparts(mfilename('fullpath'));
            app.maDisplayToolsRoot = fileparts(appPath);

            % Add required paths
            addpath(fullfile(app.maDisplayToolsRoot, 'patternTools'));
            addpath(fullfile(app.maDisplayToolsRoot, 'utils'));

            % Create UIFigure (wider to prevent cutoff, taller for all buttons)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Name = 'Pattern Combiner';
            app.UIFigure.CloseRequestFcn = @(~,~) app.UIFigureCloseRequest();

            % Load saved position or use default (compact height)
            defaultPos = [100 100 660 464];  % Height for stacking
            if ispref('maDisplayTools', 'PatternCombinerPosition')
                savedPos = getpref('maDisplayTools', 'PatternCombinerPosition');
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

            % Create main grid layout
            % Row 1: Mode + Options, Row 2: Selection controls, Row 3: Info panels, Row 4: Save name, Row 5: Status
            app.MainGrid = uigridlayout(app.UIFigure);
            app.MainGrid.ColumnWidth = {'1x'};
            app.MainGrid.RowHeight = {55, 170, 140, 30, 25};  % Compact heights
            app.MainGrid.Padding = [10 10 10 10];
            app.MainGrid.RowSpacing = 5;

            % === Row 1: Mode selection and Mode-specific options ===
            topGrid = uigridlayout(app.MainGrid);
            topGrid.Layout.Row = 1;
            topGrid.Layout.Column = 1;
            topGrid.ColumnWidth = {250, '1x'};
            topGrid.RowHeight = {'1x'};
            topGrid.Padding = [0 0 0 0];

            % Left side: Mode selection
            modePanel = uipanel(topGrid);
            modePanel.Title = 'Combination Mode';
            modePanel.Layout.Row = 1;
            modePanel.Layout.Column = 1;

            app.ModeButtonGroup = uibuttongroup(modePanel);
            app.ModeButtonGroup.BorderType = 'none';
            app.ModeButtonGroup.Position = [5 2 240 26];  % Reduced height, positioned at bottom
            app.ModeButtonGroup.SelectionChangedFcn = @(~,~) app.ModeChanged();

            app.SequentialRadio = uiradiobutton(app.ModeButtonGroup);
            app.SequentialRadio.Text = 'Sequential';
            app.SequentialRadio.Value = true;
            app.SequentialRadio.Position = [5 2 80 22];

            app.MaskRadio = uiradiobutton(app.ModeButtonGroup);
            app.MaskRadio.Text = 'Mask';
            app.MaskRadio.Position = [90 2 60 22];

            app.LeftRightRadio = uiradiobutton(app.ModeButtonGroup);
            app.LeftRightRadio.Text = 'Left/Right';
            app.LeftRightRadio.Position = [155 2 80 22];

            % Right side: Mode-specific options
            optionsPanel = uipanel(topGrid);
            optionsPanel.Title = 'Options';
            optionsPanel.Layout.Row = 1;
            optionsPanel.Layout.Column = 2;

            optionsGrid = uigridlayout(optionsPanel);
            optionsGrid.ColumnWidth = {'1x'};
            optionsGrid.RowHeight = {'1x'};  % Single row - panels overlap, only one visible at a time
            optionsGrid.Padding = [5 5 5 5];
            optionsGrid.RowSpacing = 2;

            % Mask options (hidden by default)
            app.MaskOptionsPanel = uipanel(optionsGrid);
            app.MaskOptionsPanel.BorderType = 'none';
            app.MaskOptionsPanel.Layout.Row = 1;
            app.MaskOptionsPanel.Layout.Column = 1;
            app.MaskOptionsPanel.Visible = 'off';

            maskOptGrid = uigridlayout(app.MaskOptionsPanel);
            maskOptGrid.ColumnWidth = {80, 80, 70, 60};
            maskOptGrid.RowHeight = {'1x'};
            maskOptGrid.Padding = [0 0 0 0];

            app.MaskModeGroup = uibuttongroup(maskOptGrid);
            app.MaskModeGroup.BorderType = 'none';
            app.MaskModeGroup.Layout.Row = 1;
            app.MaskModeGroup.Layout.Column = [1 2];
            app.MaskModeGroup.SelectionChangedFcn = @(~,~) app.MaskModeChanged();

            app.MaskReplaceRadio = uiradiobutton(app.MaskModeGroup);
            app.MaskReplaceRadio.Text = 'Replace';
            app.MaskReplaceRadio.Value = true;
            app.MaskReplaceRadio.Position = [5 2 70 20];

            app.MaskBlendRadio = uiradiobutton(app.MaskModeGroup);
            app.MaskBlendRadio.Text = '50% Blend';
            app.MaskBlendRadio.Position = [75 2 80 20];

            app.ThresholdLabel = uilabel(maskOptGrid);
            app.ThresholdLabel.Text = 'Threshold:';
            app.ThresholdLabel.Layout.Row = 1;
            app.ThresholdLabel.Layout.Column = 3;

            app.ThresholdSpinner = uispinner(maskOptGrid);
            app.ThresholdSpinner.Limits = [0 15];
            app.ThresholdSpinner.Value = 0;
            app.ThresholdSpinner.Layout.Row = 1;
            app.ThresholdSpinner.Layout.Column = 4;
            app.ThresholdSpinner.ValueChangedFcn = @(~,~) app.ThresholdValueChanged();

            % Binary operation controls (shown instead of threshold for binary patterns)
            app.BinaryOpLabel = uilabel(maskOptGrid);
            app.BinaryOpLabel.Text = 'Operation:';
            app.BinaryOpLabel.Layout.Row = 1;
            app.BinaryOpLabel.Layout.Column = 3;
            app.BinaryOpLabel.Visible = 'off';

            app.BinaryOpDropDown = uidropdown(maskOptGrid);
            app.BinaryOpDropDown.Items = {'OR', 'AND', 'XOR'};
            app.BinaryOpDropDown.Value = 'OR';
            app.BinaryOpDropDown.Layout.Row = 1;
            app.BinaryOpDropDown.Layout.Column = 4;
            app.BinaryOpDropDown.Visible = 'off';
            app.BinaryOpDropDown.ValueChangedFcn = @(~,~) app.BinaryOpChanged();

            % Left/Right options (hidden by default, same row as Mask - they overlap)
            app.LeftRightOptionsPanel = uipanel(optionsGrid);
            app.LeftRightOptionsPanel.BorderType = 'none';
            app.LeftRightOptionsPanel.Layout.Row = 1;  % Same row as MaskOptionsPanel
            app.LeftRightOptionsPanel.Layout.Column = 1;
            app.LeftRightOptionsPanel.Visible = 'off';

            lrOptGrid = uigridlayout(app.LeftRightOptionsPanel);
            lrOptGrid.ColumnWidth = {70, '1x', 50};
            lrOptGrid.RowHeight = {'1x'};
            lrOptGrid.Padding = [0 0 0 0];

            app.SplitLabel = uilabel(lrOptGrid);
            app.SplitLabel.Text = 'Split at col:';
            app.SplitLabel.Layout.Row = 1;
            app.SplitLabel.Layout.Column = 1;

            app.SplitSlider = uislider(lrOptGrid);
            app.SplitSlider.Limits = [0 191];
            app.SplitSlider.Value = 96;
            app.SplitSlider.MajorTicks = [];
            app.SplitSlider.MinorTicks = [];
            app.SplitSlider.ValueChangedFcn = @(~,~) app.SplitSliderValueChanged();
            app.SplitSlider.Layout.Row = 1;
            app.SplitSlider.Layout.Column = 2;

            app.SplitValueLabel = uilabel(lrOptGrid);
            app.SplitValueLabel.Text = '96';
            app.SplitValueLabel.Layout.Row = 1;
            app.SplitValueLabel.Layout.Column = 3;

            % === Row 2: Selection controls (3 columns) ===
            selectionGrid = uigridlayout(app.MainGrid);
            selectionGrid.Layout.Row = 2;
            selectionGrid.Layout.Column = 1;
            selectionGrid.ColumnWidth = {'1x', '1x', '1x'};
            selectionGrid.RowHeight = {'1x'};
            selectionGrid.Padding = [0 0 0 0];
            selectionGrid.ColumnSpacing = 10;

            % --- Left: Pattern 1 selection ---
            pat1SelectPanel = uipanel(selectionGrid);
            pat1SelectPanel.Title = 'Pattern 1';
            pat1SelectPanel.Layout.Row = 1;
            pat1SelectPanel.Layout.Column = 1;

            pat1SelectGrid = uigridlayout(pat1SelectPanel);
            pat1SelectGrid.ColumnWidth = {'1x'};
            pat1SelectGrid.RowHeight = {30, '1x'};
            pat1SelectGrid.Padding = [5 5 5 5];

            app.Pat1SelectButton = uibutton(pat1SelectGrid, 'push');
            app.Pat1SelectButton.Text = 'Select Pattern 1...';
            app.Pat1SelectButton.Layout.Row = 1;
            app.Pat1SelectButton.Layout.Column = 1;
            app.Pat1SelectButton.ButtonPushedFcn = @(~,~) app.Pat1SelectButtonPushed();

            % --- Middle: Action buttons ---
            actionPanel = uipanel(selectionGrid);
            actionPanel.Title = 'Actions';
            actionPanel.Layout.Row = 1;
            actionPanel.Layout.Column = 2;

            actionGrid = uigridlayout(actionPanel);
            actionGrid.ColumnWidth = {'1x'};
            actionGrid.RowHeight = {28, 28, 28, 28};  % 4 buttons, tighter fit
            actionGrid.Padding = [5 5 5 5];
            actionGrid.RowSpacing = 2;  % Minimal gap between buttons

            app.SwapButton = uibutton(actionGrid, 'push');
            app.SwapButton.Text = '<-- Swap -->';
            app.SwapButton.Layout.Row = 1;
            app.SwapButton.Layout.Column = 1;
            app.SwapButton.ButtonPushedFcn = @(~,~) app.SwapButtonPushed();
            app.SwapButton.Enable = 'off';

            app.ResetButton = uibutton(actionGrid, 'push');
            app.ResetButton.Text = 'Reset';
            app.ResetButton.Layout.Row = 2;
            app.ResetButton.Layout.Column = 1;
            app.ResetButton.ButtonPushedFcn = @(~,~) app.ResetButtonPushed();

            app.CombineButton = uibutton(actionGrid, 'push');
            app.CombineButton.Text = 'Combine & Preview';
            app.CombineButton.Layout.Row = 3;
            app.CombineButton.Layout.Column = 1;
            app.CombineButton.ButtonPushedFcn = @(~,~) app.CombineButtonPushed();
            app.CombineButton.BackgroundColor = [0.3 0.6 0.3];
            app.CombineButton.FontColor = [1 1 1];
            app.CombineButton.Enable = 'off';

            app.SaveButton = uibutton(actionGrid, 'push');
            app.SaveButton.Text = 'Save';
            app.SaveButton.Layout.Row = 4;
            app.SaveButton.Layout.Column = 1;
            app.SaveButton.ButtonPushedFcn = @(~,~) app.SaveButtonPushed();
            app.SaveButton.BackgroundColor = [0.3 0.5 0.7];
            app.SaveButton.FontColor = [1 1 1];
            app.SaveButton.Enable = 'off';

            % --- Right: Pattern 2 selection ---
            pat2SelectPanel = uipanel(selectionGrid);
            pat2SelectPanel.Title = 'Pattern 2';
            pat2SelectPanel.Layout.Row = 1;
            pat2SelectPanel.Layout.Column = 3;

            pat2SelectGrid = uigridlayout(pat2SelectPanel);
            pat2SelectGrid.ColumnWidth = {'1x'};
            pat2SelectGrid.RowHeight = {22, 30, '1x'};
            pat2SelectGrid.Padding = [5 5 5 5];

            app.Pat2DropDownLabel = uilabel(pat2SelectGrid);
            app.Pat2DropDownLabel.Text = 'Select pattern:';
            app.Pat2DropDownLabel.Layout.Row = 1;
            app.Pat2DropDownLabel.Layout.Column = 1;

            app.Pat2DropDown = uidropdown(pat2SelectGrid);
            app.Pat2DropDown.Items = {'-- Select Pattern 1 first --'};
            app.Pat2DropDown.ItemsData = {''};
            app.Pat2DropDown.Value = '';
            app.Pat2DropDown.Enable = 'off';
            app.Pat2DropDown.ValueChangedFcn = @(~,~) app.Pat2DropDownValueChanged();
            app.Pat2DropDown.Layout.Row = 2;
            app.Pat2DropDown.Layout.Column = 1;

            % === Row 3: Three aligned Info panels ===
            infoGrid = uigridlayout(app.MainGrid);
            infoGrid.Layout.Row = 3;
            infoGrid.Layout.Column = 1;
            infoGrid.ColumnWidth = {'1x', '1x', '1x'};
            infoGrid.RowHeight = {'1x'};
            infoGrid.Padding = [0 0 0 0];
            infoGrid.ColumnSpacing = 10;

            % --- Pattern 1 Info ---
            app.Pat1InfoPanel = uipanel(infoGrid);
            app.Pat1InfoPanel.Title = 'Pattern 1 Info';
            app.Pat1InfoPanel.Layout.Row = 1;
            app.Pat1InfoPanel.Layout.Column = 1;

            pat1InfoGrid = uigridlayout(app.Pat1InfoPanel);
            pat1InfoGrid.ColumnWidth = {55, '1x'};
            pat1InfoGrid.RowHeight = {22, 18, 18, 18, 18};
            pat1InfoGrid.Padding = [5 5 5 5];
            pat1InfoGrid.RowSpacing = 2;

            app.Pat1NameValue = uilabel(pat1InfoGrid);
            app.Pat1NameValue.Text = '(none)';
            app.Pat1NameValue.FontWeight = 'bold';
            app.Pat1NameValue.Layout.Row = 1;
            app.Pat1NameValue.Layout.Column = [1 2];

            app.Pat1SizeLabel = uilabel(pat1InfoGrid);
            app.Pat1SizeLabel.Text = 'Size:';
            app.Pat1SizeLabel.Layout.Row = 2;
            app.Pat1SizeLabel.Layout.Column = 1;

            app.Pat1SizeValue = uilabel(pat1InfoGrid);
            app.Pat1SizeValue.Text = '--';
            app.Pat1SizeValue.Layout.Row = 2;
            app.Pat1SizeValue.Layout.Column = 2;

            app.Pat1FramesLabel = uilabel(pat1InfoGrid);
            app.Pat1FramesLabel.Text = 'Frames:';
            app.Pat1FramesLabel.Layout.Row = 3;
            app.Pat1FramesLabel.Layout.Column = 1;

            app.Pat1FramesValue = uilabel(pat1InfoGrid);
            app.Pat1FramesValue.Text = '--';
            app.Pat1FramesValue.Layout.Row = 3;
            app.Pat1FramesValue.Layout.Column = 2;

            app.Pat1GSLabel = uilabel(pat1InfoGrid);
            app.Pat1GSLabel.Text = 'GS:';
            app.Pat1GSLabel.Layout.Row = 4;
            app.Pat1GSLabel.Layout.Column = 1;

            app.Pat1GSValue = uilabel(pat1InfoGrid);
            app.Pat1GSValue.Text = '--';
            app.Pat1GSValue.Layout.Row = 4;
            app.Pat1GSValue.Layout.Column = 2;

            app.Pat1ArenaLabel = uilabel(pat1InfoGrid);
            app.Pat1ArenaLabel.Text = 'Arena:';
            app.Pat1ArenaLabel.Layout.Row = 5;
            app.Pat1ArenaLabel.Layout.Column = 1;

            app.Pat1ArenaValue = uilabel(pat1InfoGrid);
            app.Pat1ArenaValue.Text = '--';
            app.Pat1ArenaValue.Layout.Row = 5;
            app.Pat1ArenaValue.Layout.Column = 2;

            % --- Combined Pattern Info ---
            app.CombinedInfoPanel = uipanel(infoGrid);
            app.CombinedInfoPanel.Title = 'Combined Pattern Info';
            app.CombinedInfoPanel.Layout.Row = 1;
            app.CombinedInfoPanel.Layout.Column = 2;

            combinedInfoGrid = uigridlayout(app.CombinedInfoPanel);
            combinedInfoGrid.ColumnWidth = {55, '1x'};
            combinedInfoGrid.RowHeight = {22, 18, 18, 18, 18};
            combinedInfoGrid.Padding = [5 5 5 5];
            combinedInfoGrid.RowSpacing = 2;

            app.CombinedNameValue = uilabel(combinedInfoGrid);
            app.CombinedNameValue.Text = '(none)';
            app.CombinedNameValue.FontWeight = 'bold';
            app.CombinedNameValue.Layout.Row = 1;
            app.CombinedNameValue.Layout.Column = [1 2];

            app.CombinedSizeLabel = uilabel(combinedInfoGrid);
            app.CombinedSizeLabel.Text = 'Size:';
            app.CombinedSizeLabel.Layout.Row = 2;
            app.CombinedSizeLabel.Layout.Column = 1;

            app.CombinedSizeValue = uilabel(combinedInfoGrid);
            app.CombinedSizeValue.Text = '--';
            app.CombinedSizeValue.Layout.Row = 2;
            app.CombinedSizeValue.Layout.Column = 2;

            app.CombinedFramesLabel = uilabel(combinedInfoGrid);
            app.CombinedFramesLabel.Text = 'Frames:';
            app.CombinedFramesLabel.Layout.Row = 3;
            app.CombinedFramesLabel.Layout.Column = 1;

            app.CombinedFramesValue = uilabel(combinedInfoGrid);
            app.CombinedFramesValue.Text = '--';
            app.CombinedFramesValue.Layout.Row = 3;
            app.CombinedFramesValue.Layout.Column = 2;

            % --- Pattern 2 Info ---
            app.Pat2InfoPanel = uipanel(infoGrid);
            app.Pat2InfoPanel.Title = 'Pattern 2 Info';
            app.Pat2InfoPanel.Layout.Row = 1;
            app.Pat2InfoPanel.Layout.Column = 3;

            pat2InfoGrid = uigridlayout(app.Pat2InfoPanel);
            pat2InfoGrid.ColumnWidth = {55, '1x'};
            pat2InfoGrid.RowHeight = {22, 18, 18, 18};
            pat2InfoGrid.Padding = [5 5 5 5];
            pat2InfoGrid.RowSpacing = 2;

            app.Pat2NameValue = uilabel(pat2InfoGrid);
            app.Pat2NameValue.Text = '(none)';
            app.Pat2NameValue.FontWeight = 'bold';
            app.Pat2NameValue.Layout.Row = 1;
            app.Pat2NameValue.Layout.Column = [1 2];

            app.Pat2SizeLabel = uilabel(pat2InfoGrid);
            app.Pat2SizeLabel.Text = 'Size:';
            app.Pat2SizeLabel.Layout.Row = 2;
            app.Pat2SizeLabel.Layout.Column = 1;

            app.Pat2SizeValue = uilabel(pat2InfoGrid);
            app.Pat2SizeValue.Text = '--';
            app.Pat2SizeValue.Layout.Row = 2;
            app.Pat2SizeValue.Layout.Column = 2;

            app.Pat2FramesLabel = uilabel(pat2InfoGrid);
            app.Pat2FramesLabel.Text = 'Frames:';
            app.Pat2FramesLabel.Layout.Row = 3;
            app.Pat2FramesLabel.Layout.Column = 1;

            app.Pat2FramesValue = uilabel(pat2InfoGrid);
            app.Pat2FramesValue.Text = '--';
            app.Pat2FramesValue.Layout.Row = 3;
            app.Pat2FramesValue.Layout.Column = 2;

            app.Pat2GSLabel = uilabel(pat2InfoGrid);
            app.Pat2GSLabel.Text = 'GS:';
            app.Pat2GSLabel.Layout.Row = 4;
            app.Pat2GSLabel.Layout.Column = 1;

            app.Pat2GSValue = uilabel(pat2InfoGrid);
            app.Pat2GSValue.Text = '--';
            app.Pat2GSValue.Layout.Row = 4;
            app.Pat2GSValue.Layout.Column = 2;

            % === Row 4: Save name edit field ===
            saveNameGrid = uigridlayout(app.MainGrid);
            saveNameGrid.Layout.Row = 4;
            saveNameGrid.Layout.Column = 1;
            saveNameGrid.ColumnWidth = {70, '1x'};
            saveNameGrid.RowHeight = {'1x'};
            saveNameGrid.Padding = [0 0 0 0];

            app.SaveNameLabel = uilabel(saveNameGrid);
            app.SaveNameLabel.Text = 'Save as:';
            app.SaveNameLabel.Layout.Row = 1;
            app.SaveNameLabel.Layout.Column = 1;

            app.SaveNameEditField = uieditfield(saveNameGrid, 'text');
            app.SaveNameEditField.Value = '';
            app.SaveNameEditField.Placeholder = '(combined pattern name)';
            app.SaveNameEditField.Layout.Row = 1;
            app.SaveNameEditField.Layout.Column = 2;

            % === Row 5: Status bar ===
            app.StatusLabel = uilabel(app.MainGrid);
            app.StatusLabel.Text = 'Select Pattern 1 to begin.';
            app.StatusLabel.Layout.Row = 5;
            app.StatusLabel.Layout.Column = 1;

            % Show the figure
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        function app = PatternCombinerApp
            % Check if instance already exists BEFORE creating components (singleton pattern - GitHub #12)
            existingApp = findall(0, 'Type', 'figure', 'Name', 'Pattern Combiner');
            if ~isempty(existingApp)
                % Bring existing app to front
                figure(existingApp(1));
                uialert(existingApp(1), ...
                    'Pattern Combiner is already open. Only one instance is allowed.', ...
                    'Already Open', 'Icon', 'warning');
                % Throw error to prevent second instance
                error('PatternCombinerApp:SingletonViolation', ...
                    'Pattern Combiner is already open. Only one instance is allowed.');
            end

            % Construct app
            createComponents(app);

            % Register the app
            registerApp(app, app.UIFigure);

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            delete(app.UIFigure);
        end
    end
end

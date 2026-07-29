classdef CriterionEvaluator
    % CRITERIONEVALUATOR  Evaluate a declarative flow-control criterion.
    %
    % Replaces user-written script-plugin checks with a closed evaluation
    % engine. Every Stage 1 criterion reduces to: take a metric over a data
    % window, compute a statistic, compare against a threshold. The
    % threshold can be absolute (a fixed number) or relative (a fraction of
    % a precomputed session baseline).
    %
    % All methods are static — there is no per-instance state. The runner
    % owns baseline computation and caching; the evaluator does only the
    % per-window math.
    %
    % Usage:
    %   result = CriterionEvaluator.evaluate(window, criterion)
    %   result = CriterionEvaluator.evaluate(window, criterion, baselineValue)
    %   issues = CriterionEvaluator.validate(criterion)
    %
    % Terminology (from the design doc, §2):
    %   level     — the per-sample line (e.g. 150 Hz). Used by fraction_*
    %               statistics to classify individual samples.
    %   threshold — the value the computed statistic is compared against.
    %               Used in absolute mode.
    %   baseline  — the statistic computed over a reference time window
    %               early in the session. Used in relative mode.
    %   fraction  — the proportion of the baseline that defines the
    %               effective threshold in relative mode.

    methods (Static)

        function result = evaluate(window, criterion, baselineValue)
            % EVALUATE  Evaluate a criterion against a data window.
            %
            % Inputs:
            %   window        - struct with fields:
            %                     .t      - vector of timestamps (seconds)
            %                     .values - vector of metric values
            %   criterion     - struct with fields:
            %                     .statistic  - 'mean' | 'fraction_below' | 'fraction_above'
            %                     .stop_when  - 'below' | 'above'
            %                     .threshold  - (absolute mode) number
            %                     .level      - (fraction_* only) per-sample line
            %                     .baseline   - (relative mode) struct, not used here
            %                     .fraction   - (relative mode) number
            %   baselineValue - (optional) precomputed baseline statistic.
            %                   Required when criterion uses relative mode
            %                   (has .fraction field). Pass [] or omit for
            %                   absolute mode.
            %
            % Output:
            %   result - struct with fields:
            %     .statistic_value    - the computed statistic (numeric)
            %     .effective_threshold - what it was compared against
            %     .fired              - logical: did the criterion fire?
            %     .abort              - logical: should the run abort?
            %     .abort_reason       - string (empty if no abort)
            %     .mode               - 'absolute' | 'relative'
            %     .valid_count        - number of non-NaN samples used
            %     .total_count        - total samples in the window

            % Minimum fraction of valid (non-NaN) samples required.
            % Below this, the window is too sparse to trust and the
            % evaluator aborts. Built-in constant, not a YAML field.
            MIN_VALID_FRACTION = 0.10;

            if nargin < 3
                baselineValue = [];
            end

            result = struct( ...
                'statistic_value',     NaN, ...
                'effective_threshold', NaN, ...
                'fired',               false, ...
                'abort',               false, ...
                'abort_reason',        '', ...
                'mode',                '', ...
                'valid_count',         0, ...
                'total_count',         0);

            % --- Guard: empty window -> abort ---
            if isempty(window.values)
                result.abort        = true;
                result.abort_reason = 'Data window contains no samples';
                return;
            end

            % --- Compute the statistic (NaNs excluded) ---
            [statValue, validCount, totalCount] = ...
                CriterionEvaluator.computeStatistic(window.values, criterion);

            result.statistic_value = statValue;
            result.valid_count     = validCount;
            result.total_count     = totalCount;

            % --- Guard: NaN result -> abort (fail closed, §6) ---
            if isnan(statValue)
                result.abort        = true;
                result.abort_reason = sprintf( ...
                    'Statistic "%s" evaluated to NaN (0 valid samples out of %d)', ...
                    char(criterion.statistic), totalCount);
                return;
            end

            % --- Guard: insufficient valid samples -> abort ---
            validFraction = validCount / totalCount;
            if validFraction < MIN_VALID_FRACTION
                result.abort        = true;
                result.abort_reason = sprintf( ...
                    'Too few valid samples: %d of %d (%.1f%%, minimum %.0f%%)', ...
                    validCount, totalCount, 100 * validFraction, ...
                    100 * MIN_VALID_FRACTION);
                return;
            end

            % --- Determine effective threshold ---
            isRelative = isfield(criterion, 'fraction') ...
                         && ~isempty(criterion.fraction);

            if isRelative
                result.mode = 'relative';

                if isempty(baselineValue) || isnan(baselineValue)
                    result.abort        = true;
                    result.abort_reason = ...
                        'Relative criterion requires a baseline value, but none was provided or it is NaN';
                    return;
                end

                effectiveThreshold = criterion.fraction * baselineValue;
            else
                result.mode        = 'absolute';
                effectiveThreshold = criterion.threshold;
            end

            result.effective_threshold = effectiveThreshold;

            % --- Compare ---
            result.fired = CriterionEvaluator.compare( ...
                statValue, effectiveThreshold, char(criterion.stop_when));
        end

        function issues = validate(criterion)
            % VALIDATE  Check a criterion struct for completeness and
            % consistency. Returns a cell array of error strings; empty
            % means valid. Intended for use at parse time.
            %
            % Input:
            %   criterion - struct from the parsed YAML
            % Output:
            %   issues    - cell array of strings describing problems

            issues = {};

            % --- metric ---
            if ~isfield(criterion, 'metric') || isempty(criterion.metric)
                issues{end + 1} = 'criterion must specify "metric"';
            end

            % --- statistic ---
            validStats = {'mean', 'fraction_below', 'fraction_above'};
            if ~isfield(criterion, 'statistic') || isempty(criterion.statistic)
                issues{end + 1} = 'criterion must specify "statistic"';
            elseif ~ismember(char(criterion.statistic), validStats)
                issues{end + 1} = sprintf( ...
                    'criterion statistic must be one of: %s (got "%s")', ...
                    strjoin(validStats, ', '), char(criterion.statistic));
            end

            % --- stop_when ---
            validDirs = {'below', 'above'};
            if ~isfield(criterion, 'stop_when') || isempty(criterion.stop_when)
                issues{end + 1} = 'criterion must specify "stop_when"';
            elseif ~ismember(char(criterion.stop_when), validDirs)
                issues{end + 1} = sprintf( ...
                    'criterion stop_when must be "below" or "above" (got "%s")', ...
                    char(criterion.stop_when));
            end

            % --- level: required for fraction_*, forbidden for mean ---
            stat = '';
            if isfield(criterion, 'statistic') && ~isempty(criterion.statistic)
                stat = char(criterion.statistic);
            end

            isFraction = ismember(stat, {'fraction_below', 'fraction_above'});
            hasLevel   = isfield(criterion, 'level') && ~isempty(criterion.level);

            if isFraction && ~hasLevel
                issues{end + 1} = sprintf( ...
                    'statistic "%s" requires "level" (the per-sample line)', stat);
            elseif ~isFraction && hasLevel && ~isempty(stat)
                issues{end + 1} = sprintf( ...
                    'statistic "%s" does not use "level" — remove it to avoid confusion', stat);
            end

            % --- threshold vs baseline+fraction: mutually exclusive ---
            hasThreshold = isfield(criterion, 'threshold') ...
                           && ~isempty(criterion.threshold);
            hasBaseline  = isfield(criterion, 'baseline') ...
                           && ~isempty(criterion.baseline);
            hasFraction  = isfield(criterion, 'fraction') ...
                           && ~isempty(criterion.fraction);

            if hasThreshold && (hasBaseline || hasFraction)
                issues{end + 1} = ...
                    '"threshold" and "baseline"/"fraction" are mutually exclusive — use one comparison mode, not both';
            elseif ~hasThreshold && ~hasFraction
                issues{end + 1} = ...
                    'criterion must specify either "threshold" (absolute) or "baseline" + "fraction" (relative)';
            elseif hasFraction && ~hasBaseline
                issues{end + 1} = ...
                    '"fraction" requires "baseline" (the reference window specification)';
            elseif hasBaseline && ~hasFraction
                issues{end + 1} = ...
                    '"baseline" requires "fraction" (the proportion of baseline to compare against)';
            end

            % --- baseline sub-fields ---
            if hasBaseline
                bl = criterion.baseline;
                if ~isfield(bl, 'window') || isempty(bl.window)
                    issues{end + 1} = 'baseline must specify "window" (e.g. [2, 6])';
                elseif numel(bl.window) ~= 2
                    issues{end + 1} = 'baseline.window must be a two-element vector [start, end]';
                elseif bl.window(1) >= bl.window(2)
                    issues{end + 1} = 'baseline.window start must be less than end';
                end
                if ~isfield(bl, 'units') || isempty(bl.units)
                    issues{end + 1} = 'baseline must specify "units" (e.g. "minutes")';
                end
            end
        end

        function metrics = supportedMetrics()
            % SUPPORTEDMETRICS  Return the predefined Stage 1 metric names.
            %
            % This is the canonical list for validation. A real deployment
            % would eventually source this from the rig configuration.
            metrics = {'wingbeat_frequency', 'walking_speed'};
        end
    end

    % =====================================================================
    %  PRIVATE HELPERS
    % =====================================================================
    methods (Static, Access = private)

        function [val, validCount, totalCount] = computeStatistic(values, criterion)
            % Compute the named statistic over the sample vector.
            % NaN values are excluded from all statistics (not propagated).
            % Returns the statistic value plus valid and total sample counts
            % for trace logging.
            totalCount = numel(values);
            validMask  = ~isnan(values);
            validCount = sum(validMask);
            validValues = values(validMask);

            if isempty(validValues)
                val = NaN;  % triggers abort via fail-closed policy
                return;
            end

            stat = char(criterion.statistic);
            switch stat
                case 'mean'
                    val = mean(validValues);

                case 'fraction_below'
                    level = criterion.level;
                    val   = mean(validValues < level);   % strict <

                case 'fraction_above'
                    level = criterion.level;
                    val   = mean(validValues > level);   % strict >

                otherwise
                    val = NaN;
            end
        end

        function fired = compare(statValue, threshold, direction)
            % Compare the computed statistic against the effective threshold.
            % Both comparisons are strict (< and >, not <= and >=).
            switch direction
                case 'below'
                    fired = statValue < threshold;
                case 'above'
                    fired = statValue > threshold;
                otherwise
                    fired = false;
            end
        end
    end
end

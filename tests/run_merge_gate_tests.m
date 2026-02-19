function summary = run_merge_gate_tests(varargin)
%RUN_MERGE_GATE_TESTS Unified test runner for all merge-gate validators
%
%   summary = run_merge_gate_tests() runs all 6 validator suites and
%   prints a consolidated pass/fail report.
%
%   summary = run_merge_gate_tests('Skip', {'gui_launch'}) skips the
%   specified suites (useful in headless CI where App Designer is unavailable).
%
%   Validator suites:
%       1. validate_pattern_round_trip  — Pattern save/load + header V2
%       2. validate_web_roundtrip       — Web → MATLAB pixel-exact
%       3. validate_pattern_combiner    — Combination logic
%       4. validate_gui_launch          — App launch + singleton
%       5. validate_arena_config        — Config system
%       6. validate_g6_encoding         — Byte-level G6 encoding
%
%   Returns:
%       summary - struct with fields:
%           all_passed (logical): true if every suite passed
%           suites_passed (int): number of suites that passed
%           suites_total (int): total suites run
%           tests_passed (int): total individual tests passed
%           tests_total (int): total individual tests
%           suite_results (struct array): per-suite results
%
%   Example:
%       cd(project_root()); clear classes; addpath(genpath('.'));
%       summary = run_merge_gate_tests();

    p = inputParser;
    addParameter(p, 'Skip', {}, @iscell);
    parse(p, varargin{:});
    skip_list = lower(p.Results.Skip);

    suites = {
        'validate_pattern_round_trip', 'Pattern Round-Trip + Header V2'
        'validate_web_roundtrip',      'Web → MATLAB Round-Trip'
        'validate_pattern_combiner',   'Pattern Combiner'
        'validate_gui_launch',         'GUI Launch + Singleton'
        'validate_arena_config',       'Arena Config'
        'validate_g6_encoding',        'G6 Encoding'
    };

    num_suites = size(suites, 1);
    suite_results = struct('name', {}, 'label', {}, 'passed', {}, ...
        'num_passed', {}, 'num_total', {}, 'skipped', {}, 'error', {});

    fprintf('\n');
    fprintf('╔══════════════════════════════════════════════════════╗\n');
    fprintf('║           MERGE GATE TEST SUITE                     ║\n');
    fprintf('╚══════════════════════════════════════════════════════╝\n\n');

    total_passed = 0;
    total_tests = 0;
    suites_passed = 0;
    suites_run = 0;

    for i = 1:num_suites
        func_name = suites{i, 1};
        label = suites{i, 2};

        s = struct('name', func_name, 'label', label, ...
            'passed', false, 'num_passed', 0, 'num_total', 0, ...
            'skipped', false, 'error', '');

        % Check skip list
        short_name = strrep(func_name, 'validate_', '');
        if any(strcmp(short_name, skip_list))
            s.skipped = true;
            fprintf('── Suite %d/%d: %s — SKIPPED\n\n', i, num_suites, label);
            suite_results(end+1) = s; %#ok<AGROW>
            continue;
        end

        suites_run = suites_run + 1;
        fprintf('── Suite %d/%d: %s ──\n', i, num_suites, label);

        try
            results = feval(func_name);

            % Handle both return formats:
            %   Standard: scalar struct with .passed, .num_passed, .num_total
            %   Legacy:   struct array with .passed per element (e.g. validate_pattern_combiner)
            if isfield(results, 'num_passed')
                s.passed = results.passed;
                s.num_passed = results.num_passed;
                s.num_total = results.num_total;
            else
                s.num_total = length(results);
                s.num_passed = sum([results.passed]);
                s.passed = (s.num_passed == s.num_total);
            end
            total_passed = total_passed + s.num_passed;
            total_tests = total_tests + s.num_total;
            if s.passed
                suites_passed = suites_passed + 1;
            end
        catch ME
            s.error = sprintf('%s: %s', ME.identifier, ME.message);
            fprintf('  ERROR: %s\n', s.error);
        end

        fprintf('\n');
        suite_results(end+1) = s; %#ok<AGROW>
    end

    % Print consolidated summary
    fprintf('╔══════════════════════════════════════════════════════╗\n');
    fprintf('║  RESULTS                                            ║\n');
    fprintf('╠══════════════════════════════════════════════════════╣\n');

    for i = 1:length(suite_results)
        s = suite_results(i);
        if s.skipped
            status = 'SKIP';
            counts = '     ';
        elseif ~isempty(s.error)
            status = 'ERR ';
            counts = '     ';
        elseif s.passed
            status = 'PASS';
            counts = sprintf('%2d/%2d', s.num_passed, s.num_total);
        else
            status = 'FAIL';
            counts = sprintf('%2d/%2d', s.num_passed, s.num_total);
        end
        fprintf('║  [%s] %-38s %s ║\n', status, s.label, counts);
    end

    fprintf('╠══════════════════════════════════════════════════════╣\n');
    fprintf('║  Suites: %d/%d passed    Tests: %d/%d passed        ║\n', ...
        suites_passed, suites_run, total_passed, total_tests);
    fprintf('╚══════════════════════════════════════════════════════╝\n');

    all_passed = (suites_passed == suites_run) && (total_passed == total_tests);
    if all_passed
        fprintf('\n  ✓ ALL MERGE GATE TESTS PASSED\n\n');
    else
        fprintf('\n  ✗ MERGE GATE FAILED — see details above\n\n');
    end

    summary = struct(...
        'all_passed', all_passed, ...
        'suites_passed', suites_passed, ...
        'suites_total', suites_run, ...
        'tests_passed', total_passed, ...
        'tests_total', total_tests, ...
        'suite_results', suite_results);
end

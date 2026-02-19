function results = validate_gui_launch()
%VALIDATE_GUI_LAUNCH Test that all pattern GUI apps launch without errors
%
%   results = validate_gui_launch() tests that PatternGeneratorApp,
%   PatternPreviewerApp, and PatternCombinerApp all launch cleanly and
%   close without errors.
%
%   Returns:
%       results - struct with fields:
%           passed (logical): true if all tests passed
%           num_passed (int): number of tests passed
%           num_total (int): total number of tests
%           details (cell array): detailed results for each test
%
%   Example:
%       cd(project_root()); clear classes; addpath(genpath('.'));
%       results = validate_gui_launch();

    fprintf('=== GUI Launch Validation ===\n\n');

    % Initialize results (4 launch + 3 singleton = 7 tests)
    num_tests = 7;
    test_results = false(num_tests, 1);
    test_details = cell(num_tests, 1);
    test_idx = 0;

    % Test 1: PatternGeneratorApp launches
    test_idx = test_idx + 1;
    fprintf('Test %d/%d: PatternGeneratorApp launch...', test_idx, num_tests);
    try
        app = PatternGeneratorApp();
        pause(0.5);  % Allow UI to initialize
        test_results(test_idx) = true;
        test_details{test_idx} = 'PatternGeneratorApp launched successfully';
        delete(app);
        fprintf(' PASS\n');
    catch ME
        test_results(test_idx) = false;
        test_details{test_idx} = sprintf('PatternGeneratorApp launch failed: %s', ME.message);
        fprintf(' FAIL: %s\n', ME.message);
    end

    % Test 2: PatternPreviewerApp launches
    test_idx = test_idx + 1;
    fprintf('Test %d/%d: PatternPreviewerApp launch...', test_idx, num_tests);
    try
        app = PatternPreviewerApp();
        pause(0.5);  % Allow UI to initialize
        test_results(test_idx) = true;
        test_details{test_idx} = 'PatternPreviewerApp launched successfully';
        delete(app);
        fprintf(' PASS\n');
    catch ME
        test_results(test_idx) = false;
        test_details{test_idx} = sprintf('PatternPreviewerApp launch failed: %s', ME.message);
        fprintf(' FAIL: %s\n', ME.message);
    end

    % Test 3: PatternCombinerApp launches
    test_idx = test_idx + 1;
    fprintf('Test %d/%d: PatternCombinerApp launch...', test_idx, num_tests);
    try
        app = PatternCombinerApp();
        pause(0.5);  % Allow UI to initialize
        test_results(test_idx) = true;
        test_details{test_idx} = 'PatternCombinerApp launched successfully';
        delete(app);
        fprintf(' PASS\n');
    catch ME
        test_results(test_idx) = false;
        test_details{test_idx} = sprintf('PatternCombinerApp launch failed: %s', ME.message);
        fprintf(' FAIL: %s\n', ME.message);
    end

    % Test 4: close_pattern_apps() utility function
    test_idx = test_idx + 1;
    fprintf('Test %d/%d: close_pattern_apps() utility...', test_idx, num_tests);
    try
        % Launch all three apps
        app1 = PatternGeneratorApp();
        app2 = PatternPreviewerApp();
        app3 = PatternCombinerApp();
        pause(0.5);

        % Close using utility
        close_pattern_apps();
        pause(0.5);

        % Verify all UIFigures are closed
        remaining = findall(0, 'Type', 'figure', 'Name', 'Pattern Generator');
        remaining = [remaining; findall(0, 'Type', 'figure', 'Name', 'Pattern Previewer')];
        remaining = [remaining; findall(0, 'Type', 'figure', 'Name', 'Pattern Combiner')];

        if isempty(remaining)
            test_results(test_idx) = true;
            test_details{test_idx} = 'close_pattern_apps() closed all apps successfully';
            fprintf(' PASS\n');
        else
            test_results(test_idx) = false;
            test_details{test_idx} = sprintf('close_pattern_apps() left %d windows open', length(remaining));
            fprintf(' FAIL: %d windows still open\n', length(remaining));
        end
    catch ME
        test_results(test_idx) = false;
        test_details{test_idx} = sprintf('close_pattern_apps() failed: %s', ME.message);
        fprintf(' FAIL: %s\n', ME.message);
    end

    %% ================================================================
    %  Part 2: Singleton Enforcement (absorbed from test_singleton_pattern)
    %  ================================================================

    fprintf('\n--- Singleton Enforcement ---\n\n');

    singleton_apps = {'PatternGeneratorApp', 'PatternPreviewerApp', 'PatternCombinerApp'};
    for s = 1:length(singleton_apps)
        appName = singleton_apps{s};
        test_idx = test_idx + 1;
        fprintf('Test %d/%d: %s singleton... ', test_idx, num_tests, appName);

        try
            app1 = feval(appName);
            pause(0.5);

            % Try creating second instance — should throw SingletonViolation
            errorThrown = false;
            try
                app2 = feval(appName);  %#ok<NASGU>
                delete(app2);
            catch ME
                errorThrown = true;
                expectedID = [appName ':SingletonViolation'];
                if strcmp(ME.identifier, expectedID)
                    test_results(test_idx) = true;
                    test_details{test_idx} = sprintf('%s singleton enforced', appName);
                    fprintf('PASS\n');
                else
                    test_results(test_idx) = false;
                    test_details{test_idx} = sprintf('%s wrong error: %s', appName, ME.identifier);
                    fprintf('FAIL: wrong error ID %s\n', ME.identifier);
                end
            end

            if ~errorThrown
                test_results(test_idx) = false;
                test_details{test_idx} = sprintf('%s singleton NOT enforced', appName);
                fprintf('FAIL: second instance created\n');
            end

            delete(app1);
            pause(0.3);

        catch ME
            test_results(test_idx) = false;
            test_details{test_idx} = sprintf('%s creation failed: %s', appName, ME.message);
            fprintf('FAIL: %s\n', ME.message);
        end
    end

    % Summary
    num_passed = sum(test_results);
    fprintf('\n=== Summary ===\n');
    fprintf('Passed: %d / %d\n', num_passed, num_tests);

    if num_passed == num_tests
        fprintf('All tests PASSED!\n');
    else
        fprintf('FAILED tests:\n');
        for i = 1:num_tests
            if ~test_results(i)
                fprintf('  - Test %d: %s\n', i, test_details{i});
            end
        end
    end

    % Return results structure
    results = struct(...
        'passed', num_passed == num_tests, ...
        'num_passed', num_passed, ...
        'num_total', num_tests, ...
        'details', {test_details});
end

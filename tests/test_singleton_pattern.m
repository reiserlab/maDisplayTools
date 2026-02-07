function results = test_singleton_pattern()
% TEST_SINGLETON_PATTERN Validate singleton pattern for pattern apps
%
% Tests that only one instance of each pattern app can be created at a time.
% This prevents conflicts and ensures proper inter-app communication.
%
% Tests:
%   1. PatternGeneratorApp singleton behavior
%   2. PatternPreviewerApp singleton behavior
%   3. PatternCombinerApp singleton behavior
%
% Expected behavior:
%   - First instance creates successfully
%   - Second instance attempt throws error with identifier *:SingletonViolation
%   - Existing app is brought to front and alert shown
%
% Returns:
%   results - struct array with fields: name, passed, message
%
% Related: GitHub issue #12

    % Close all existing apps
    delete(findall(0, 'Type', 'figure'));

    % Initialize results
    tests = {'PatternGeneratorApp', 'PatternPreviewerApp', 'PatternCombinerApp'};
    results = struct('name', {}, 'passed', {}, 'message', {});

    fprintf('\n=== Testing Singleton Pattern (GitHub #12) ===\n\n');

    for i = 1:length(tests)
        appName = tests{i};
        fprintf('Test %d: %s singleton\n', i, appName);

        % Create first instance
        try
            app1 = feval(appName);
            pause(1);
            fprintf('  First instance created successfully\n');

            % Try creating second instance - should throw error
            errorThrown = false;
            errorMsg = '';
            try
                app2 = feval(appName);
                % If we get here, singleton failed
                delete(app2);
            catch ME
                errorThrown = true;
                errorMsg = ME.message;
                expectedID = [appName ':SingletonViolation'];
                if strcmp(ME.identifier, expectedID)
                    fprintf('  PASS: Second instance blocked with error\n');
                    results(i).passed = true;
                    results(i).message = sprintf('Singleton working: %s', errorMsg);
                else
                    fprintf('  FAIL: Wrong error identifier: %s\n', ME.identifier);
                    results(i).passed = false;
                    results(i).message = sprintf('Wrong error: %s', ME.message);
                end
            end

            if ~errorThrown
                fprintf('  FAIL: Second instance was created without error\n');
                results(i).passed = false;
                results(i).message = 'Singleton violation: second instance created';
            end

            % Clean up
            delete(app1);
            pause(0.5);

        catch ME
            fprintf('  FAIL: Could not create first instance\n');
            fprintf('        Error: %s\n', ME.message);
            results(i).passed = false;
            results(i).message = sprintf('Creation failed: %s', ME.message);
        end

        results(i).name = appName;
        fprintf('  Cleaned up\n\n');
    end

    % Summary
    fprintf('=== Summary ===\n');
    passed = sum([results.passed]);
    total = length(results);
    fprintf('Passed: %d / %d\n', passed, total);

    if passed == total
        fprintf('All tests PASSED!\n');
    else
        fprintf('Some tests FAILED.\n');
        for i = 1:length(results)
            if ~results(i).passed
                fprintf('  FAILED: %s - %s\n', results(i).name, results(i).message);
            end
        end
    end

    fprintf('\n');
end

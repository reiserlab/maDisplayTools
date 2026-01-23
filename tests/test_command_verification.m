function results = test_command_verification(pc, backend_name)
%TEST_COMMAND_VERIFICATION Verify G4.1 commands return expected responses
%
%   results = test_command_verification(pc, backend_name)
%
%   Tests that G4.1-supported PanelsController commands work correctly
%   and return the expected responses.
%
%   Inputs:
%       pc           - PanelsController or PanelsControllerNative instance
%       backend_name - String identifier for reporting ('pnet' or 'native')
%
%   Output:
%       results - Struct with test results for each command

    arguments
        pc
        backend_name (1,:) char = 'unknown'
    end

    fprintf('\n=== Command Verification: %s ===\n\n', backend_name);

    results = struct();
    results.backend = backend_name;
    results.tests = struct();

    % Ensure connection
    if ~pc.isOpen
        try
            pc.open(false);
        catch ME
            fprintf('ERROR: Could not connect: %s\n', ME.message);
            results.error = ME.message;
            return;
        end
    end

    % Test G4.1-supported commands only
    % Note: getVersion removed as it may not be supported on G4.1
    tests = {
        'allOn',           @() pc.allOn(),           true;
        'allOff',          @() pc.allOff(),          true;
        'stopDisplay',     @() pc.stopDisplay(),     true;
        'sendDisplayReset', @() pc.sendDisplayReset(), true;
        'resetCounter',    @() pc.resetCounter(),    true;
    };

    passed = 0;
    failed = 0;

    for i = 1:size(tests, 1)
        name = tests{i, 1};
        testFn = tests{i, 2};
        expected = tests{i, 3};

        try
            result = testFn();
            success = (result == expected);

            if success
                status = 'PASS';
                passed = passed + 1;
            else
                status = 'FAIL';
                failed = failed + 1;
            end

            results.tests.(name) = struct('success', success, 'result', result);
            fprintf('  %-20s %s\n', name, status);

        catch ME
            results.tests.(name) = struct('success', false, 'error', ME.message);
            fprintf('  %-20s ERROR: %s\n', name, ME.message);
            failed = failed + 1;
        end

        pause(0.05);  % 50ms pause between commands for reliability
    end

    results.passed = passed;
    results.failed = failed;
    results.total = passed + failed;

    fprintf('\nResults: %d/%d passed\n', passed, results.total);
end

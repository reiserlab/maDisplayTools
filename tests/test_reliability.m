function results = test_reliability(pc, backend_name, duration_min)
%TEST_RELIABILITY Test connection reliability over extended period
%
%   results = test_reliability(pc, backend_name, duration_min)
%
%   Runs continuous commands for specified duration to measure reliability.
%   Target: >99.9% success rate
%
%   Inputs:
%       pc           - PanelsController or PanelsControllerNative instance
%       backend_name - String identifier for reporting
%       duration_min - Test duration in minutes (default: 5)
%
%   Output:
%       results - Struct with reliability statistics

    arguments
        pc
        backend_name (1,:) char = 'unknown'
        duration_min (1,1) double = 5
    end

    fprintf('\n=== Reliability Test: %s (%.1f min) ===\n\n', backend_name, duration_min);

    results = struct();
    results.backend = backend_name;
    results.duration_min = duration_min;

    % Ensure connection
    if ~pc.isOpen
        try
            pc.open();
        catch ME
            fprintf('ERROR: Could not connect: %s\n', ME.message);
            results.error = ME.message;
            return;
        end
    end

    total = 0;
    success = 0;
    errors = 0;
    disconnects = 0;

    duration_sec = duration_min * 60;
    start_time = tic;
    last_report = 0;

    fprintf('  Running... (Ctrl+C to stop early)\n');

    try
        while toc(start_time) < duration_sec
            % Check connection
            if ~pc.isOpen
                disconnects = disconnects + 1;
                fprintf('  [%.1f min] Disconnected! Attempting reconnect...\n', toc(start_time)/60);
                try
                    pc.open();
                    fprintf('  Reconnected.\n');
                catch
                    fprintf('  STOPPED: could not reconnect\n');
                    break;
                end
            end

            % Run command
            try
                if pc.allOn()
                    success = success + 1;
                else
                    errors = errors + 1;
                end
            catch
                errors = errors + 1;
            end
            total = total + 1;

            % Progress report every 30 seconds
            elapsed = toc(start_time);
            if elapsed - last_report >= 30
                rate = success / total * 100;
                fprintf('  [%.1f min] %d/%d (%.2f%%)\n', elapsed/60, success, total, rate);
                last_report = elapsed;
            end

            pause(0.05);  % ~20 commands per second
        end
    catch ME
        if strcmp(ME.identifier, 'MATLAB:interrupt')
            fprintf('  Interrupted by user.\n');
        else
            rethrow(ME);
        end
    end

    % Calculate results
    results.total = total;
    results.success = success;
    results.errors = errors;
    results.disconnects = disconnects;
    results.success_rate = success / total * 100;
    results.actual_duration_min = toc(start_time) / 60;

    fprintf('\n  Results:\n');
    fprintf('    Total commands:  %d\n', total);
    fprintf('    Successful:      %d\n', success);
    fprintf('    Errors:          %d\n', errors);
    fprintf('    Disconnects:     %d\n', disconnects);
    fprintf('    Success rate:    %.2f%%\n', results.success_rate);
    fprintf('    Target:          99.9%%\n');

    if results.success_rate >= 99.9
        fprintf('    Status:          PASS\n');
        results.passed = true;
    else
        fprintf('    Status:          FAIL\n');
        results.passed = false;
    end
    fprintf('\n');
end

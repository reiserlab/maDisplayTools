function results = benchmark_timing(pc, backend_name, iterations)
%BENCHMARK_TIMING Measure command latency for G4.1
%
%   results = benchmark_timing(pc, backend_name, iterations)
%
%   Measures round-trip latency for G4.1-supported commands.
%
%   Inputs:
%       pc           - PanelsController or PanelsControllerNative instance
%       backend_name - String identifier for reporting
%       iterations   - Number of iterations per command (default: 100)
%
%   Output:
%       results - Struct with timing statistics

    arguments
        pc
        backend_name (1,:) char = 'unknown'
        iterations (1,1) double = 100
    end

    fprintf('\n=== Timing Benchmark: %s (%d iterations) ===\n\n', backend_name, iterations);

    results = struct();
    results.backend = backend_name;
    results.iterations = iterations;
    results.commands = struct();

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

    % G4.1-supported commands to benchmark
    commands = {
        'allOn',       @() pc.allOn();
        'allOff',      @() pc.allOff();
        'stopDisplay', @() pc.stopDisplay();
    };

    for i = 1:size(commands, 1)
        name = commands{i, 1};
        cmdFn = commands{i, 2};

        % Check if still connected
        if ~pc.isOpen
            fprintf('  %-20s STOPPED: connection lost\n', name);
            results.stopped_at = name;
            results.reason = 'disconnected';
            break;
        end

        times = zeros(1, iterations);
        errors = 0;

        try
            for j = 1:iterations
                tic;
                success = cmdFn();
                times(j) = toc;

                if ~success
                    errors = errors + 1;
                end

                pause(0.05);  % 50ms delay for reliability
            end

            results.commands.(name) = struct(...
                'mean_ms', mean(times) * 1000, ...
                'std_ms', std(times) * 1000, ...
                'min_ms', min(times) * 1000, ...
                'max_ms', max(times) * 1000, ...
                'errors', errors);

            fprintf('  %-20s %.2f ± %.2f ms (errors: %d)\n', ...
                name, results.commands.(name).mean_ms, ...
                results.commands.(name).std_ms, errors);

        catch ME
            fprintf('  %-20s ERROR: %s\n', name, ME.message);
            results.commands.(name) = struct('error', ME.message);

            % Try to recover
            try
                pc.close(true);
                pause(1);
                pc.open(false);
                fprintf('  (recovered connection)\n');
            catch
                fprintf('  STOPPED: could not recover\n');
                results.stopped_at = name;
                results.reason = ME.message;
                break;
            end
        end

        pause(0.2);  % Brief pause between command types
    end

    fprintf('\n');
end

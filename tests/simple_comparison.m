function results = simple_comparison(ip)
%SIMPLE_COMPARISON Simple comparison between pnet and tcpclient backends
%
%   results = simple_comparison()
%   results = simple_comparison('192.168.10.62')
%
%   A minimal test script comparing PanelsController (pnet) and
%   PanelsControllerNative (tcpclient) implementations on G4.1/Teensy.
%
%   Tests only core commands:
%   - allOn/allOff (small commands, basic connectivity)
%   - stopDisplay (basic command with response)
%   - streamFrame (large packet test, ~3176 bytes)
%
%   Inputs:
%       ip - Host IP address (default: '192.168.10.62')
%
%   Output:
%       results - Struct with comparison results

    arguments
        ip (1,:) char = '192.168.10.62'
    end

    fprintf('\n');
    fprintf('========================================\n');
    fprintf('   Simple TCP Backend Comparison\n');
    fprintf('========================================\n');
    fprintf('Host: %s\n', ip);
    fprintf('========================================\n');

    results = struct();
    results.ip = ip;
    results.timestamp = datetime('now');

    %% Test pnet version
    fprintf('\n--- PanelsController (pnet) ---\n');
    try
        pc = PanelsController(ip);
        pc.open(false);
        results.pnet = run_simple_tests(pc, 'pnet');
        pc.close(true);
        results.pnet.error = [];
    catch ME
        fprintf('ERROR: %s\n', ME.message);
        results.pnet.error = ME.message;
    end

    pause(2);  % Recovery between backends

    %% Test native version
    fprintf('\n--- PanelsControllerNative (tcpclient) ---\n');
    try
        pcn = PanelsControllerNative(ip);
        pcn.open(false);
        results.native = run_simple_tests(pcn, 'native');
        pcn.close(true);
        results.native.error = [];
    catch ME
        fprintf('ERROR: %s\n', ME.message);
        results.native.error = ME.message;
    end

    %% Print comparison summary
    print_summary(results);

    %% Save results
    filename = sprintf('simple_comparison_%s.mat', datestr(now, 'yyyy-mm-dd_HHMMSS'));
    save(filename, 'results');
    fprintf('\nResults saved to: %s\n', filename);
end


function r = run_simple_tests(pc, name)
%RUN_SIMPLE_TESTS Run core command tests
    r = struct();
    r.backend = name;

    % Test 1: allOn (10 iterations)
    fprintf('  allOn:       ');
    [r.allOn.passed, r.allOn.failed, r.allOn.time_ms] = test_command(@() pc.allOn(), 10);
    fprintf('%d/10, %.1f ms avg\n', r.allOn.passed, r.allOn.time_ms);

    pause(0.2);

    % Test 2: allOff (10 iterations)
    fprintf('  allOff:      ');
    [r.allOff.passed, r.allOff.failed, r.allOff.time_ms] = test_command(@() pc.allOff(), 10);
    fprintf('%d/10, %.1f ms avg\n', r.allOff.passed, r.allOff.time_ms);

    pause(0.2);

    % Test 3: stopDisplay (10 iterations)
    fprintf('  stopDisplay: ');
    [r.stop.passed, r.stop.failed, r.stop.time_ms] = test_command(@() pc.stopDisplay(), 10);
    fprintf('%d/10, %.1f ms avg\n', r.stop.passed, r.stop.time_ms);

    pause(0.2);

    % Test 4: streamFrame (large packet test, 5 iterations)
    fprintf('  streamFrame: ');
    try
        % Create a frame for 2x12 panel config (32 rows x 192 cols)
        frame = make_framevector_gs16(zeros(32, 192), 0);  % ~3176 bytes
        [r.stream.passed, r.stream.failed, r.stream.time_ms] = test_command(@() pc.streamFrame(0, 0, frame), 5);
        fprintf('%d/5, %.1f ms avg (%d bytes)\n', r.stream.passed, r.stream.time_ms, length(frame));
    catch ME
        fprintf('SKIPPED - %s\n', ME.message);
        r.stream.passed = 0;
        r.stream.failed = 5;
        r.stream.time_ms = 0;
        r.stream.error = ME.message;
    end
end


function [passed, failed, avg_ms] = test_command(fn, n)
%TEST_COMMAND Test a command n times and measure timing
    passed = 0;
    failed = 0;
    times = zeros(1, n);

    for i = 1:n
        try
            tic;
            result = fn();
            times(i) = toc * 1000;

            if result
                passed = passed + 1;
            else
                failed = failed + 1;
            end
        catch
            times(i) = toc * 1000;
            failed = failed + 1;
        end
    end

    avg_ms = mean(times);
end


function print_summary(results)
%PRINT_SUMMARY Print comparison summary

    fprintf('\n');
    fprintf('========================================\n');
    fprintf('           Comparison Summary\n');
    fprintf('========================================\n\n');

    % Check for errors
    pnet_ok = isfield(results, 'pnet') && isempty(results.pnet.error);
    native_ok = isfield(results, 'native') && isempty(results.native.error);

    if ~pnet_ok && isfield(results.pnet, 'error')
        fprintf('pnet: FAILED - %s\n', results.pnet.error);
    end
    if ~native_ok && isfield(results.native, 'error')
        fprintf('native: FAILED - %s\n', results.native.error);
    end

    if ~pnet_ok || ~native_ok
        fprintf('\nOne or both backends failed to connect.\n');
        return;
    end

    % Results table
    fprintf('%-15s %12s %12s\n', 'Command', 'pnet', 'native');
    fprintf('%-15s %12s %12s\n', '-------', '----', '------');

    % allOn
    fprintf('%-15s %8d/10 %8d/10\n', 'allOn', ...
        results.pnet.allOn.passed, results.native.allOn.passed);

    % allOff
    fprintf('%-15s %8d/10 %8d/10\n', 'allOff', ...
        results.pnet.allOff.passed, results.native.allOff.passed);

    % stopDisplay
    fprintf('%-15s %8d/10 %8d/10\n', 'stopDisplay', ...
        results.pnet.stop.passed, results.native.stop.passed);

    % streamFrame
    fprintf('%-15s %9d/5 %9d/5\n', 'streamFrame', ...
        results.pnet.stream.passed, results.native.stream.passed);

    % Timing comparison
    fprintf('\n%-15s %10s %10s\n', 'Timing (ms)', 'pnet', 'native');
    fprintf('%-15s %10s %10s\n', '-----------', '----', '------');
    fprintf('%-15s %10.1f %10.1f\n', 'allOn', ...
        results.pnet.allOn.time_ms, results.native.allOn.time_ms);
    fprintf('%-15s %10.1f %10.1f\n', 'allOff', ...
        results.pnet.allOff.time_ms, results.native.allOff.time_ms);
    fprintf('%-15s %10.1f %10.1f\n', 'stopDisplay', ...
        results.pnet.stop.time_ms, results.native.stop.time_ms);
    fprintf('%-15s %10.1f %10.1f\n', 'streamFrame', ...
        results.pnet.stream.time_ms, results.native.stream.time_ms);

    % Overall assessment
    fprintf('\n----------------------------------------\n');

    pnet_total = results.pnet.allOn.passed + results.pnet.allOff.passed + ...
                 results.pnet.stop.passed + results.pnet.stream.passed;
    native_total = results.native.allOn.passed + results.native.allOff.passed + ...
                   results.native.stop.passed + results.native.stream.passed;

    fprintf('Total passed:   pnet=%d/35  native=%d/35\n', pnet_total, native_total);

    if native_total >= pnet_total
        fprintf('Status: Native backend is ready for testing\n');
    else
        fprintf('Status: Native backend needs investigation\n');
    end

    fprintf('========================================\n\n');
end

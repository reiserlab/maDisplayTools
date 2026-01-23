function results = run_comparison(ip, options)
%RUN_COMPARISON Compare pnet and native TCP implementations for G4.1
%
%   results = run_comparison(ip)
%   results = run_comparison(ip, 'QuickTest', true)
%   results = run_comparison(ip, 'SkipStreaming', true)
%
%   Runs benchmarks on both PanelsController (pnet) and
%   PanelsControllerNative (tcpclient) implementations for G4.1/Teensy.
%
%   Inputs:
%       ip      - Host IP address (default: '192.168.10.62')
%       Options:
%           QuickTest     - Run with fewer iterations (default: false)
%           SkipStreaming - Skip streaming benchmarks (default: false)
%           SkipReliability - Skip reliability test (default: false)
%
%   Output:
%       results - Struct with comparison results

    arguments
        ip (1,:) char = '192.168.10.62'
        options.QuickTest (1,1) logical = false
        options.SkipStreaming (1,1) logical = false
        options.SkipReliability (1,1) logical = false
    end

    fprintf('\n');
    fprintf('========================================\n');
    fprintf('   TCP Backend Comparison Test (G4.1)\n');
    fprintf('========================================\n');
    fprintf('Host: %s\n', ip);
    fprintf('Quick test: %s\n', mat2str(options.QuickTest));
    fprintf('========================================\n');

    results = struct();
    results.ip = ip;
    results.timestamp = datetime('now');

    % Set iterations based on quick test mode
    if options.QuickTest
        timing_iterations = 20;
        reliability_duration = 0.5;  % 30 seconds
    else
        timing_iterations = 100;
        reliability_duration = 5;  % 5 minutes
    end

    %% Test pnet implementation
    fprintf('\n\n*** Testing PanelsController (pnet) ***\n');

    try
        pc_pnet = PanelsController(ip);
        pc_pnet.open(false);

        results.pnet.verification = test_command_verification(pc_pnet, 'pnet');
        results.pnet.timing = benchmark_timing(pc_pnet, 'pnet', timing_iterations);

        if ~options.SkipReliability
            results.pnet.reliability = test_reliability(pc_pnet, 'pnet', reliability_duration);
        end

        if ~options.SkipStreaming
            results.pnet.streaming = benchmark_streaming(pc_pnet, 'pnet');
        end

        pc_pnet.close(true);

    catch ME
        fprintf('pnet testing failed: %s\n', ME.message);
        results.pnet.error = ME.message;
    end

    pause(2);  % Recovery between backends

    %% Test native implementation
    fprintf('\n\n*** Testing PanelsControllerNative (tcpclient) ***\n');

    try
        pc_native = PanelsControllerNative(ip);
        pc_native.open(false);

        results.native.verification = test_command_verification(pc_native, 'native');
        results.native.timing = benchmark_timing(pc_native, 'native', timing_iterations);

        if ~options.SkipReliability
            results.native.reliability = test_reliability(pc_native, 'native', reliability_duration);
        end

        if ~options.SkipStreaming
            results.native.streaming = benchmark_streaming(pc_native, 'native');
        end

        pc_native.close(true);

    catch ME
        fprintf('native testing failed: %s\n', ME.message);
        results.native.error = ME.message;
    end

    %% Print comparison summary
    print_comparison_summary(results);

    %% Save results
    filename = sprintf('tcp_comparison_%s.mat', datestr(now, 'yyyy-mm-dd_HHMMSS'));
    save(filename, 'results');
    fprintf('\nResults saved to: %s\n', filename);
end


function print_comparison_summary(results)
%PRINT_COMPARISON_SUMMARY Display side-by-side comparison

    fprintf('\n');
    fprintf('========================================\n');
    fprintf('          Comparison Summary\n');
    fprintf('========================================\n\n');

    % Check for errors
    pnet_ok = isfield(results, 'pnet') && ~isfield(results.pnet, 'error');
    native_ok = isfield(results, 'native') && ~isfield(results.native, 'error');

    if ~pnet_ok && isfield(results, 'pnet') && isfield(results.pnet, 'error')
        fprintf('pnet: ERROR - %s\n', results.pnet.error);
    end
    if ~native_ok && isfield(results, 'native') && isfield(results.native, 'error')
        fprintf('native: ERROR - %s\n', results.native.error);
    end

    if ~pnet_ok || ~native_ok
        fprintf('\nCannot compare - one or both backends failed.\n');
        return;
    end

    % Command Verification
    fprintf('Command Verification:\n');
    fprintf('  %-20s %8s %8s\n', '', 'pnet', 'native');
    fprintf('  %-20s %8d %8d\n', 'Passed', ...
        results.pnet.verification.passed, results.native.verification.passed);
    fprintf('  %-20s %8d %8d\n', 'Failed', ...
        results.pnet.verification.failed, results.native.verification.failed);

    % Timing comparison
    fprintf('\nTiming (ms):\n');
    fprintf('  %-20s %12s %12s\n', 'Command', 'pnet', 'native');

    if isfield(results.pnet, 'timing') && isfield(results.pnet.timing, 'commands')
        commands = fieldnames(results.pnet.timing.commands);
        for i = 1:length(commands)
            cmd = commands{i};
            if isfield(results.pnet.timing.commands.(cmd), 'mean_ms') && ...
               isfield(results.native.timing, 'commands') && ...
               isfield(results.native.timing.commands, cmd) && ...
               isfield(results.native.timing.commands.(cmd), 'mean_ms')

                pnet_ms = results.pnet.timing.commands.(cmd).mean_ms;
                native_ms = results.native.timing.commands.(cmd).mean_ms;
                fprintf('  %-20s %8.2f±%.1f %8.2f±%.1f\n', cmd, ...
                    pnet_ms, results.pnet.timing.commands.(cmd).std_ms, ...
                    native_ms, results.native.timing.commands.(cmd).std_ms);
            end
        end
    end

    % Reliability comparison
    if isfield(results.pnet, 'reliability') && isfield(results.native, 'reliability')
        fprintf('\nReliability:\n');
        fprintf('  %-20s %8s %8s\n', '', 'pnet', 'native');
        fprintf('  %-20s %7.2f%% %7.2f%%\n', 'Success rate', ...
            results.pnet.reliability.success_rate, ...
            results.native.reliability.success_rate);
    end

    % Streaming comparison
    if isfield(results.pnet, 'streaming') && isfield(results.native, 'streaming')
        fprintf('\nStreaming (streamFrame):\n');
        fprintf('  %-20s %8s %8s\n', '', 'pnet', 'native');

        pnet_max = 0;
        native_max = 0;
        if isfield(results.pnet.streaming, 'streaming') && isfield(results.pnet.streaming.streaming, 'max_fps')
            pnet_max = results.pnet.streaming.streaming.max_fps;
        end
        if isfield(results.native.streaming, 'streaming') && isfield(results.native.streaming.streaming, 'max_fps')
            native_max = results.native.streaming.streaming.max_fps;
        end
        fprintf('  %-20s %8d %8d\n', 'Max FPS', pnet_max, native_max);
    end

    % Recommendation
    fprintf('\n----------------------------------------\n');
    fprintf('Recommendation: ');

    % Simple heuristic: if native has similar or better performance, recommend it
    if isfield(results.pnet, 'timing') && isfield(results.pnet.timing, 'commands') && ...
       isfield(results.native, 'timing') && isfield(results.native.timing, 'commands')

        pnet_times = [];
        native_times = [];
        commands = fieldnames(results.pnet.timing.commands);
        for i = 1:length(commands)
            cmd = commands{i};
            if isfield(results.pnet.timing.commands.(cmd), 'mean_ms')
                pnet_times(end+1) = results.pnet.timing.commands.(cmd).mean_ms;
            end
            if isfield(results.native.timing.commands, cmd) && ...
               isfield(results.native.timing.commands.(cmd), 'mean_ms')
                native_times(end+1) = results.native.timing.commands.(cmd).mean_ms;
            end
        end

        if ~isempty(pnet_times) && ~isempty(native_times)
            pnet_mean = mean(pnet_times);
            native_mean = mean(native_times);

            if native_mean <= pnet_mean * 1.2  % Native within 20%
                fprintf('native (tcpclient)\n');
                fprintf('  Reason: Cross-platform, no MEX required, comparable performance\n');
            else
                fprintf('pnet (for now)\n');
                fprintf('  Reason: Better performance, but consider native for portability\n');
            end
        else
            fprintf('Insufficient data for recommendation\n');
        end
    else
        fprintf('Insufficient data for recommendation\n');
    end

    fprintf('========================================\n\n');
end

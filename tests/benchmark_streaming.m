function results = benchmark_streaming(pc, backend_name)
%BENCHMARK_STREAMING Test G4.1 frame streaming performance
%
%   results = benchmark_streaming(pc, backend_name)
%
%   Tests streamFrame at increasing frame rates for G4.1 (2x12 panel config).
%   Stops when errors occur or jitter becomes too high.
%
%   Inputs:
%       pc           - PanelsController or PanelsControllerNative instance
%       backend_name - String identifier for reporting
%
%   Output:
%       results - Struct with streaming benchmark results

    arguments
        pc
        backend_name (1,:) char = 'unknown'
    end

    fprintf('\n=== Streaming Benchmark (G4.1): %s ===\n\n', backend_name);

    results = struct();
    results.backend = backend_name;

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

    % G4.1 frame streaming using streamFrame
    fprintf('--- Frame Streaming (streamFrame) ---\n');
    fprintf('  Panel config: 2x12 (32 rows x 192 cols)\n');
    fprintf('  Frame size: ~3176 bytes\n\n');

    results.streaming = benchmark_streamframe(pc, [5, 10, 15, 20, 25, 30]);

    % Summary
    fprintf('\n--- Summary ---\n');
    if isfield(results.streaming, 'max_fps')
        fprintf('Max reliable FPS: %d (jitter: %.1f%%)\n', ...
            results.streaming.max_fps, results.streaming.jitter_at_max);
    end
    fprintf('\n');
end


function result = benchmark_streamframe(pc, fps_list)
%BENCHMARK_STREAMFRAME Test streamFrame at various FPS for G4.1
    result = struct();
    result.fps_tested = [];
    result.jitter = [];
    result.max_fps = 0;
    result.jitter_at_max = 0;

    % Create test frame for G4.1 (2x12 panels = 32 rows x 192 cols)
    try
        test_pattern = zeros(32, 192);
        % Create a simple pattern for visibility
        test_pattern(1:16, 1:96) = 15;  % Top-left quadrant bright
        frame = maDisplayTools.make_framevector_gs16(test_pattern, 0);
        fprintf('  Frame generated: %d bytes\n\n', length(frame));
    catch ME
        fprintf('  Failed to generate frame: %s\n', ME.message);
        result.error = ME.message;
        return;
    end

    for fps = fps_list
        % Check connection before each test
        if ~pc.isOpen
            fprintf('  %3d FPS: STOPPED (disconnected)\n', fps);
            result.stopped_at = fps;
            result.reason = 'disconnected';
            break;
        end

        try
            [success, jitter, error_rate] = test_streamframe_fps(pc, fps, 3, frame);

            if success
                result.fps_tested(end+1) = fps;
                result.jitter(end+1) = jitter;
                result.max_fps = fps;
                result.jitter_at_max = jitter;

                status = 'OK';
                if jitter > 10
                    status = 'HIGH JITTER';
                end
                fprintf('  %3d FPS: jitter %.1f%%, errors %.1f%% (%s)\n', ...
                    fps, jitter, error_rate*100, status);

                % Stop if jitter too high
                if jitter > 20
                    fprintf('  STOPPED: jitter exceeded 20%%\n');
                    result.stopped_at = fps;
                    result.reason = 'high_jitter';
                    break;
                end
            else
                fprintf('  %3d FPS: FAILED (error rate %.1f%%)\n', fps, error_rate*100);
                result.stopped_at = fps;
                result.reason = 'high_error_rate';
                break;
            end

        catch ME
            fprintf('  %3d FPS: ERROR - %s\n', fps, ME.message);
            result.stopped_at = fps;
            result.reason = ME.message;

            % Try to recover
            try
                pc.stopDisplay();
                pause(0.5);
            catch
            end
            break;
        end

        pause(0.5);  % Recovery between frame rates
    end

    pc.stopDisplay();
end


function [success, jitter_pct, error_rate] = test_streamframe_fps(pc, fps, duration_sec, frame)
%TEST_STREAMFRAME_FPS Test streamFrame at a specific FPS
    interval = 1 / fps;
    num_frames = fps * duration_sec;
    times = zeros(1, num_frames);
    errors = 0;

    start = tic;
    for i = 1:num_frames
        % Wait for next frame time
        target_time = (i-1) * interval;
        while toc(start) < target_time
            % Busy wait (more accurate than pause for timing)
        end

        times(i) = toc(start);

        % Send frame
        try
            if ~pc.streamFrame(0, 0, frame)
                errors = errors + 1;
            end
        catch
            errors = errors + 1;
        end
    end

    % Calculate jitter as percentage of ideal interval
    actual_intervals = diff(times);
    jitter_pct = std(actual_intervals) / interval * 100;

    error_rate = errors / num_frames;
    success = (error_rate < 0.1);  % <10% error rate considered success
end

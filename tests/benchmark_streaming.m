function results = benchmark_streaming(pc, backend_name)
%BENCHMARK_STREAMING Test streaming performance at various frame rates
%
%   results = benchmark_streaming(pc, backend_name)
%
%   Tests Mode 3 (position updates) and Mode 5 (full frame streaming)
%   at increasing frame rates. Stops when errors occur.
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

    fprintf('\n=== Streaming Benchmark: %s ===\n\n', backend_name);

    results = struct();
    results.backend = backend_name;

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

    % Mode 3: Stream Pattern Position
    fprintf('--- Mode 3: Position Updates ---\n');
    results.mode3 = benchmark_mode3(pc, [30, 60, 100, 120, 150, 200, 300]);

    % Brief recovery pause
    pause(1);

    % Check if still connected
    if ~pc.isOpen
        fprintf('Connection lost after Mode 3, attempting reconnect...\n');
        try
            pc.open();
        catch
            fprintf('Could not reconnect. Skipping Mode 5.\n');
            return;
        end
    end

    % Mode 5: Full Frame Streaming (if controller supports it)
    fprintf('\n--- Mode 5: Full Frame Streaming ---\n');
    results.mode5 = benchmark_mode5(pc, [10, 20, 30, 40, 50, 60]);

    % Summary
    fprintf('\n--- Summary ---\n');
    if isfield(results.mode3, 'max_fps')
        fprintf('Mode 3 max FPS: %d (jitter: %.1f%%)\n', ...
            results.mode3.max_fps, results.mode3.jitter_at_max);
    end
    if isfield(results.mode5, 'max_fps')
        fprintf('Mode 5 max FPS: %d (jitter: %.1f%%)\n', ...
            results.mode5.max_fps, results.mode5.jitter_at_max);
    end
    fprintf('\n');
end


function result = benchmark_mode3(pc, fps_list)
%BENCHMARK_MODE3 Test Mode 3 (Stream Pattern Position) at various FPS
    result = struct();
    result.fps_tested = [];
    result.jitter = [];
    result.max_fps = 0;
    result.jitter_at_max = 0;

    % Setup: need a pattern loaded
    try
        pc.setControlMode(3);
        pc.setPatternID(1);
    catch ME
        fprintf('  Setup failed: %s\n', ME.message);
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
            [success, jitter] = test_fps_mode3(pc, fps, 3);  % 3 second test

            if success
                result.fps_tested(end+1) = fps;
                result.jitter(end+1) = jitter;
                result.max_fps = fps;
                result.jitter_at_max = jitter;

                status = 'OK';
                if jitter > 10
                    status = 'HIGH JITTER';
                end
                fprintf('  %3d FPS: jitter %.1f%% (%s)\n', fps, jitter, status);

                % Stop if jitter too high
                if jitter > 20
                    fprintf('  STOPPED: jitter exceeded 20%%\n');
                    result.stopped_at = fps;
                    result.reason = 'high_jitter';
                    break;
                end
            else
                fprintf('  %3d FPS: FAILED\n', fps);
                result.stopped_at = fps;
                result.reason = 'command_failed';
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


function [success, jitter_pct] = test_fps_mode3(pc, fps, duration_sec)
%TEST_FPS_MODE3 Test a specific FPS for Mode 3
    interval = 1 / fps;
    num_frames = fps * duration_sec;
    times = zeros(1, num_frames);
    errors = 0;

    start = tic;
    for i = 1:num_frames
        % Wait for next frame time
        target_time = (i-1) * interval;
        while toc(start) < target_time
            % Busy wait (more accurate than pause for high FPS)
        end

        times(i) = toc(start);

        % Send position update
        try
            pc.setPositionX(mod(i-1, 100));
        catch
            errors = errors + 1;
        end
    end

    % Calculate jitter as percentage of ideal interval
    actual_intervals = diff(times);
    jitter_pct = std(actual_intervals) / interval * 100;

    success = (errors / num_frames < 0.1);  % <10% error rate
end


function result = benchmark_mode5(pc, fps_list)
%BENCHMARK_MODE5 Test Mode 5 (Full Frame Streaming) at various FPS
    result = struct();
    result.fps_tested = [];
    result.jitter = [];
    result.max_fps = 0;
    result.jitter_at_max = 0;

    % Setup streaming mode
    try
        pc.setControlMode(0);  % Streaming mode
        pc.startStreamingMode();
    catch ME
        fprintf('  Setup failed: %s\n', ME.message);
        result.error = ME.message;
        return;
    end

    % Create test frame (16x16 panel, simple pattern)
    test_frame = uint8(randi([0, 15], 16, 16));

    for fps = fps_list
        % Check connection
        if ~pc.isOpen
            fprintf('  %3d FPS: STOPPED (disconnected)\n', fps);
            result.stopped_at = fps;
            result.reason = 'disconnected';
            break;
        end

        try
            [success, jitter] = test_fps_mode5(pc, fps, 3, test_frame);

            if success
                result.fps_tested(end+1) = fps;
                result.jitter(end+1) = jitter;
                result.max_fps = fps;
                result.jitter_at_max = jitter;

                status = 'OK';
                if jitter > 10
                    status = 'HIGH JITTER';
                end
                fprintf('  %3d FPS: jitter %.1f%% (%s)\n', fps, jitter, status);

                if jitter > 20
                    fprintf('  STOPPED: jitter exceeded 20%%\n');
                    result.stopped_at = fps;
                    result.reason = 'high_jitter';
                    break;
                end
            else
                fprintf('  %3d FPS: FAILED\n', fps);
                result.stopped_at = fps;
                result.reason = 'command_failed';
                break;
            end

        catch ME
            fprintf('  %3d FPS: ERROR - %s\n', fps, ME.message);
            result.stopped_at = fps;
            result.reason = ME.message;
            break;
        end

        pause(0.5);
    end

    pc.stopDisplay();
end


function [success, jitter_pct] = test_fps_mode5(pc, fps, duration_sec, frame)
%TEST_FPS_MODE5 Test a specific FPS for Mode 5
    interval = 1 / fps;
    num_frames = fps * duration_sec;
    times = zeros(1, num_frames);
    errors = 0;

    % Pre-generate frame command for speed
    try
        frame_cmd = pc.getFrameCmd16(frame);
    catch
        % Fall back to simpler method
        frame_cmd = [];
    end

    start = tic;
    for i = 1:num_frames
        target_time = (i-1) * interval;
        while toc(start) < target_time
        end

        times(i) = toc(start);

        try
            if ~isempty(frame_cmd)
                pc.streamFrameCmd16(frame_cmd);
            else
                pc.streamFrame16(frame);
            end
        catch
            errors = errors + 1;
        end
    end

    actual_intervals = diff(times);
    jitter_pct = std(actual_intervals) / interval * 100;
    success = (errors / num_frames < 0.1);
end

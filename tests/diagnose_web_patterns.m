function results = diagnose_web_patterns(web_pat_path, matlab_pat_path)
%DIAGNOSE_WEB_PATTERNS Compare web-generated vs MATLAB-generated .pat files
%
%   results = diagnose_web_patterns(web_pat_path, matlab_pat_path)
%   results = diagnose_web_patterns(web_pat_path)   % header + row-header check only
%
%   Performs byte-level comparison of .pat files to diagnose encoding
%   differences. Specifically checks:
%     - Row header bytes (known bug: web encoder wrote 0x00 instead of i+1)
%     - Header format (V1 vs V2, arena_id, generation_id)
%     - Frame pixel data
%     - File size
%
%   Run BEFORE going to the lab to confirm fixes work.
%
%   Inputs:
%     web_pat_path    - Path to a web-generated .pat file
%     matlab_pat_path - (optional) Path to a MATLAB-generated .pat file
%
%   Examples:
%     % Check a single web pattern for row header correctness
%     diagnose_web_patterns('path/to/web_pattern.pat');
%
%     % Compare web vs MATLAB patterns
%     diagnose_web_patterns('path/to/web.pat', 'path/to/matlab.pat');

    results = struct();
    results.passed = true;
    results.issues = {};

    fprintf('=== Pattern Diagnostic Tool ===\n\n');

    %% Analyze web pattern
    fprintf('--- Web Pattern: %s ---\n', web_pat_path);
    [web_info, web_row_headers] = analyze_pat_file(web_pat_path);
    results.web = web_info;

    % Check row headers
    fprintf('\n  Row header check:\n');
    row_header_ok = check_row_headers(web_row_headers, web_info.header.RowN);
    if ~row_header_ok
        results.passed = false;
        results.issues{end+1} = 'Web pattern has incorrect row header bytes';
    end

    %% Compare with MATLAB pattern if provided
    if nargin >= 2 && ~isempty(matlab_pat_path)
        fprintf('\n--- MATLAB Pattern: %s ---\n', matlab_pat_path);
        [mat_info, mat_row_headers] = analyze_pat_file(matlab_pat_path);
        results.matlab = mat_info;

        fprintf('\n  Row header check:\n');
        check_row_headers(mat_row_headers, mat_info.header.RowN);

        % Compare headers
        fprintf('\n--- Header Comparison ---\n');
        compare_headers(web_info.header, mat_info.header);

        % Compare dimensions
        if web_info.header.RowN ~= mat_info.header.RowN || ...
           web_info.header.ColN ~= mat_info.header.ColN
            fprintf('  WARNING: Dimension mismatch — cannot compare frames\n');
            results.passed = false;
            results.issues{end+1} = 'Dimension mismatch between web and MATLAB patterns';
        elseif web_info.header.GSLevels ~= mat_info.header.GSLevels
            fprintf('  WARNING: GS level mismatch — cannot compare frames\n');
            results.passed = false;
            results.issues{end+1} = 'GS level mismatch';
        else
            % Compare frame data
            fprintf('\n--- Frame Data Comparison ---\n');
            frame_match = compare_frames(web_pat_path, matlab_pat_path, web_info, mat_info);
            if ~frame_match
                results.passed = false;
                results.issues{end+1} = 'Frame data mismatch';
            end
        end

        % Raw byte comparison
        fprintf('\n--- Raw Byte Comparison ---\n');
        compare_raw_bytes(web_pat_path, matlab_pat_path);
    end

    %% Summary
    fprintf('\n=== Summary ===\n');
    if results.passed
        fprintf('All checks PASSED\n');
    else
        fprintf('Issues found:\n');
        for i = 1:length(results.issues)
            fprintf('  - %s\n', results.issues{i});
        end
    end
end


function [info, row_headers] = analyze_pat_file(pat_path)
%ANALYZE_PAT_FILE Read and analyze a .pat file

    assert(isfile(pat_path), 'File not found: %s', pat_path);

    % Read raw bytes
    fid = fopen(pat_path, 'r');
    raw = fread(fid, inf, 'uint8');
    fclose(fid);

    info.file_size = length(raw);
    fprintf('  File size: %d bytes\n', info.file_size);

    % Parse header
    header_bytes = raw(1:7);
    info.header = read_g4_header(header_bytes);

    h = info.header;
    fprintf('  Header version: V%d\n', h.version);
    fprintf('  NumPatsX: %d\n', h.NumPatsX);
    fprintf('  GS levels: %d\n', h.GSLevels);
    fprintf('  Panel rows: %d, cols: %d\n', h.RowN, h.ColN);
    fprintf('  Pixel dims: %dx%d\n', h.RowN * 16, h.ColN * 16);

    if h.version == 2
        fprintf('  Generation: %s (id=%d)\n', h.generation, h.generation_id);
        fprintf('  Arena ID: %d\n', h.arena_id);
    end

    % Extract row header bytes from frame data
    numSubpanel = 4;
    if h.GSLevels == 16
        subpanelMsgLength = 33;
    else
        subpanelMsgLength = 9;
    end
    frameBytes = (h.ColN * subpanelMsgLength + 1) * h.RowN * numSubpanel;

    fprintf('  Frame size: %d bytes\n', frameBytes);
    fprintf('  Expected file size: %d (header) + %d (frames) = %d\n', ...
        7, h.NumPatsX * frameBytes, 7 + h.NumPatsX * frameBytes);

    % Collect row header bytes from first frame
    row_headers = [];
    if info.file_size >= 7 + frameBytes
        frame_start = 8;  % 1-based, after 7-byte header
        n = frame_start;
        for i = 0:(h.RowN - 1)
            for j = 1:numSubpanel
                row_headers(end+1) = raw(n); %#ok<AGROW>
                n = n + 1;  % row header byte
                n = n + h.ColN * subpanelMsgLength;  % skip subpanel data
            end
        end
    end
end


function ok = check_row_headers(row_headers, num_panel_rows)
%CHECK_ROW_HEADERS Verify row header bytes are correct (1-based row index)

    ok = true;
    expected = [];
    for i = 0:(num_panel_rows - 1)
        for j = 1:4  % 4 subpanels per row
            expected(end+1) = i + 1; %#ok<AGROW>
        end
    end

    if length(row_headers) ~= length(expected)
        fprintf('    ERROR: Expected %d row headers, got %d\n', ...
            length(expected), length(row_headers));
        ok = false;
        return;
    end

    for k = 1:length(row_headers)
        row_idx = floor((k-1) / 4);
        subpanel = mod(k-1, 4) + 1;
        if row_headers(k) == expected(k)
            fprintf('    Row %d, subpanel %d: 0x%02X  OK\n', row_idx, subpanel, row_headers(k));
        else
            fprintf('    Row %d, subpanel %d: 0x%02X  WRONG (expected 0x%02X)\n', ...
                row_idx, subpanel, row_headers(k), expected(k));
            ok = false;
        end
    end

    if ok
        fprintf('    All row headers correct\n');
    else
        fprintf('    *** ROW HEADER BUG DETECTED ***\n');
    end
end


function compare_headers(web_h, mat_h)
%COMPARE_HEADERS Compare two parsed headers

    fields = {'NumPatsX', 'GSLevels', 'RowN', 'ColN'};
    for i = 1:length(fields)
        f = fields{i};
        wv = web_h.(f);
        mv = mat_h.(f);
        if wv == mv
            fprintf('  %s: %d (match)\n', f, wv);
        else
            fprintf('  %s: web=%d, matlab=%d  MISMATCH\n', f, wv, mv);
        end
    end

    % Version comparison
    fprintf('  Header version: web=V%d, matlab=V%d', web_h.version, mat_h.version);
    if web_h.version ~= mat_h.version
        fprintf(' (different but OK — V1/V2 are compatible)\n');
    else
        fprintf(' (match)\n');
    end

    if web_h.version == 2
        fprintf('  Web arena_id: %d\n', web_h.arena_id);
    end
    if mat_h.version == 2
        fprintf('  MATLAB arena_id: %d\n', mat_h.arena_id);
    end
end


function match = compare_frames(web_path, mat_path, web_info, mat_info)
%COMPARE_FRAMES Load and compare frame pixel data

    [web_frames, ~] = maDisplayTools.load_pat(web_path);
    [mat_frames, ~] = maDisplayTools.load_pat(mat_path);

    web_nf = web_info.header.NumPatsX;
    mat_nf = mat_info.header.NumPatsX;
    nf = min(web_nf, mat_nf);

    if web_nf ~= mat_nf
        fprintf('  Frame count: web=%d, matlab=%d (comparing first %d)\n', web_nf, mat_nf, nf);
    else
        fprintf('  Frame count: %d (match)\n', nf);
    end

    match = true;
    for f = 1:nf
        web_frame = squeeze(web_frames(1, f, :, :));
        mat_frame = squeeze(mat_frames(1, f, :, :));

        if isequal(web_frame, mat_frame)
            fprintf('  Frame %d: IDENTICAL\n', f);
        else
            diff_count = sum(web_frame(:) ~= mat_frame(:));
            total = numel(web_frame);
            fprintf('  Frame %d: %d/%d pixels differ (%.1f%%)\n', ...
                f, diff_count, total, 100 * diff_count / total);

            % Show first mismatch
            [rows, cols] = find(web_frame ~= mat_frame, 1, 'first');
            if ~isempty(rows)
                fprintf('    First diff at (%d,%d): web=%d, matlab=%d\n', ...
                    rows(1), cols(1), web_frame(rows(1), cols(1)), mat_frame(rows(1), cols(1)));
            end
            match = false;
        end
    end
end


function compare_raw_bytes(web_path, mat_path)
%COMPARE_RAW_BYTES Byte-level file comparison

    fid = fopen(web_path, 'r'); web_bytes = fread(fid, inf, 'uint8'); fclose(fid);
    fid = fopen(mat_path, 'r'); mat_bytes = fread(fid, inf, 'uint8'); fclose(fid);

    fprintf('  Web file:    %d bytes\n', length(web_bytes));
    fprintf('  MATLAB file: %d bytes\n', length(mat_bytes));

    if length(web_bytes) ~= length(mat_bytes)
        fprintf('  File sizes DIFFER\n');
    end

    compare_len = min(length(web_bytes), length(mat_bytes));
    diffs = find(web_bytes(1:compare_len) ~= mat_bytes(1:compare_len));

    if isempty(diffs)
        if length(web_bytes) == length(mat_bytes)
            fprintf('  Files are BYTE-IDENTICAL\n');
        else
            fprintf('  Common bytes identical, but file sizes differ\n');
        end
    else
        fprintf('  %d byte differences found\n', length(diffs));
        % Show first few differences
        show_n = min(10, length(diffs));
        for i = 1:show_n
            idx = diffs(i);
            fprintf('    Byte %d (0x%04X): web=0x%02X, matlab=0x%02X\n', ...
                idx, idx - 1, web_bytes(idx), mat_bytes(idx));
        end
        if length(diffs) > show_n
            fprintf('    ... and %d more\n', length(diffs) - show_n);
        end
    end
end

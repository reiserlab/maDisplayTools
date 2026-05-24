function pass_count = test_g6_crc()
% TEST_G6_CRC CRC spec-vector + corruption tests for the MATLAB G6 encoder/reader.
%
% Exits with the count of passing checks. Caller is responsible for failure
% reporting (e.g., assert in CI).

    addpath(fileparts(mfilename('fullpath')));
    clear crc8_autosar crc16_ccitt_false

    total = 0; pass_count = 0;

    fprintf('=== CRC universal checks ===\n');
    [pass_count, total] = check(pass_count, total, 'CRC-8/AUTOSAR("123456789")', ...
                                crc8_autosar(uint8('123456789')), uint8(hex2dec('DF')));
    [pass_count, total] = check(pass_count, total, 'CRC-16/CCITT-FALSE("123456789")', ...
                                crc16_ccitt_false(uint8('123456789')), uint16(hex2dec('29B1')));

    fprintf('\n=== CRC-8 protocol vectors ===\n');
    v2L = [uint8(hex2dec('01')), uint8(hex2dec('10')), zeros(1,51,'uint8')];
    [pass_count, total] = check(pass_count, total, '2L Oneshot all-zero (53B)', ...
                                crc8_autosar(v2L), uint8(hex2dec('C6')));
    v16L = [uint8(hex2dec('01')), uint8(hex2dec('30')), zeros(1,201,'uint8')];
    [pass_count, total] = check(pass_count, total, '16L Oneshot all-zero (203B)', ...
                                crc8_autosar(v16L), uint8(hex2dec('6D')));

    fprintf('\n=== CRC-16 protocol vectors ===\n');
    [pass_count, total] = check(pass_count, total, 'Frame-header all-zero (FR + 0x00 0x00)', ...
                                crc16_ccitt_false([uint8('FR'), uint8(0), uint8(0)]), ...
                                uint16(hex2dec('FD6B')));

    fprintf('\n=== Cross-check against g6_encoding_reference.json ===\n');
    ref_path = fullfile(fileparts(mfilename('fullpath')), 'g6_encoding_reference.json');
    ref = jsondecode(fileread(ref_path));
    [pass_count, total] = checkBool(pass_count, total, 'reference JSON has crc_test_vectors', ...
                                    isfield(ref, 'crc_test_vectors'));

    fprintf('\n=== Round-trip + corruption tests ===\n');
    rows = 2; cols = 10; N = 4;
    Pats = zeros(rows*20, cols*20, N, 'uint8');
    for f = 1:N, for i = 1:(rows*20), for j = 1:(cols*20), Pats(i,j,f) = mod(i+j+f, 2); end, end, end
    stretch = uint8(ones(N,1));
    out_dir = tempname; mkdir(out_dir);
    g6_save_pattern(Pats, stretch, [rows, cols], out_dir, 'roundtrip', 'Mode', 'GS2', 'Overwrite', true);
    pat_file = fullfile(out_dir, 'roundtrip_G6.pat');

    % Tolerant clean load (should not warn)
    lastwarn('');
    [~, ~] = maDisplayTools.load_pat(pat_file);
    [wmsg, ~] = lastwarn();
    [pass_count, total] = checkBool(pass_count, total, 'Tolerant parse of clean file (no warning)', isempty(wmsg));

    % Strict clean load (should not throw)
    okStrict = true; sErr = '';
    try
        [~, ~] = maDisplayTools.load_pat(pat_file, 'strict', true);
    catch ME
        okStrict = false; sErr = ME.message;
    end
    [pass_count, total] = checkBool(pass_count, total, 'Strict parse of clean file succeeded', okStrict);

    % Header corruption: flip a bit
    fid = fopen(pat_file, 'r'); buf = fread(fid, Inf, 'uint8=>uint8'); fclose(fid);
    bad = buf; bad(6) = bitxor(bad(6), uint8(1));
    bad_path = fullfile(out_dir, 'corrupt_header_G6.pat');
    fid = fopen(bad_path, 'w'); fwrite(fid, bad, 'uint8'); fclose(fid);
    threw = false;
    try
        [~, ~] = maDisplayTools.load_pat(bad_path, 'strict', true);
    catch ME
        threw = ~isempty(strfind(ME.message, 'header CRC-8 mismatch'));
    end
    [pass_count, total] = checkBool(pass_count, total, 'Strict mode throws on header CRC-8 corruption', threw);

    % Frame body corruption
    bad2 = buf;
    frame_bytes_per = 4 + 20*53 + 2;
    bad2(18 + 2*frame_bytes_per + 10) = bitxor(bad2(18 + 2*frame_bytes_per + 10), uint8(128));
    bad2_path = fullfile(out_dir, 'corrupt_frame_G6.pat');
    fid = fopen(bad2_path, 'w'); fwrite(fid, bad2, 'uint8'); fclose(fid);
    threw2 = false;
    try
        [~, ~] = maDisplayTools.load_pat(bad2_path, 'strict', true);
    catch ME
        threw2 = ~isempty(strfind(ME.message, 'CRC-16 mismatch'));
    end
    [pass_count, total] = checkBool(pass_count, total, 'Strict mode throws on frame CRC-16 corruption', threw2);

    % Tolerant parses corrupt file (with warning)
    lastwarn('');
    tolOK = true;
    try
        [~, ~] = maDisplayTools.load_pat(bad_path);
    catch
        tolOK = false;
    end
    [wmsg, ~] = lastwarn();
    [pass_count, total] = checkBool(pass_count, total, 'Tolerant parses past header corruption (with warning)', tolOK && ~isempty(wmsg));

    fprintf('\n=== Summary ===\n%d / %d checks passed\n', pass_count, total);
end

function [pc, tot] = check(pc, tot, name, got, expected)
    tot = tot + 1;
    ok = (got == expected);
    if ok, pc = pc + 1; end
    if isnumeric(expected)
        if expected > 255
            gotStr = sprintf('0x%04X', double(got));
            expStr = sprintf('0x%04X', double(expected));
        else
            gotStr = sprintf('0x%02X', double(got));
            expStr = sprintf('0x%02X', double(expected));
        end
    else
        gotStr = num2str(got); expStr = num2str(expected);
    end
    if ok, s = 'PASS'; else, s = 'FAIL'; end
    fprintf('  %s  %s: got %s, expected %s\n', s, name, gotStr, expStr);
end

function [pc, tot] = checkBool(pc, tot, name, ok)
    tot = tot + 1;
    if ok, pc = pc + 1; s = 'PASS'; else, s = 'FAIL'; end
    fprintf('  %s  %s\n', s, name);
end

function results = test_sd_card_deployment(options)
% TEST_SD_CARD_DEPLOYMENT Automated test suite for SD card deployment pipeline
%
%   results = test_sd_card_deployment()
%   results = test_sd_card_deployment('UseRealSD', true)
%   results = test_sd_card_deployment('PatternDir', '/path/to/patterns')
%
%   Runs all SD card deployment tests using a fake SD card folder (default)
%   or a real SD card if 'UseRealSD' is true. Tests cover:
%
%     1. Pattern staging and renaming (pat0001.pat, pat0002.pat, ...)
%     2. MANIFEST.bin binary format (uint16 count + uint32 timestamp)
%     3. MANIFEST.txt human-readable mapping
%     4. Verification count accuracy
%     5. macOS dot-file prevention (xattr -c before copy to FAT32)
%     6. ValidateDriveName on Mac (volume name from mount path)
%     7. detect_sd_card utility (when UseRealSD=true)
%     8. Format + deploy pipeline (when UseRealSD=true, DESTRUCTIVE)
%
%   INPUTS (Name-Value):
%       'UseRealSD' (false)   - Test with real SD card (requires PATSD inserted)
%       'Format' (false)      - Format real SD card during test (DESTRUCTIVE)
%       'PatternDir' ('')     - Custom pattern directory (default: reference patterns)
%       'Verbose' (true)      - Print detailed test output
%
%   OUTPUTS:
%       results - Struct with:
%           .passed   - Number of tests passed
%           .failed   - Number of tests failed
%           .total    - Total number of tests
%           .details  - Cell array of {test_name, pass/fail, message}
%
%   EXAMPLES:
%       % Quick test (fake SD, reference patterns)
%       results = test_sd_card_deployment();
%
%       % Full test with real SD card (non-destructive)
%       results = test_sd_card_deployment('UseRealSD', true);
%
%       % Full test with format (DESTRUCTIVE - erases SD card)
%       results = test_sd_card_deployment('UseRealSD', true, 'Format', true);
%
%   See also: prepare_sd_card_crossplatform, detect_sd_card

    arguments
        options.UseRealSD (1,1) logical = false
        options.Format (1,1) logical = false
        options.PatternDir char = ''
        options.Verbose (1,1) logical = true
    end

    %% Setup paths
    this_file = mfilename('fullpath');
    this_dir = fileparts(this_file);
    repo_root = fileparts(this_dir);

    addpath(fullfile(repo_root, 'tests', 'fixtures'));
    addpath(fullfile(repo_root, 'utils'));

    %% Find reference patterns
    if isempty(options.PatternDir)
        pat_dir = fullfile(repo_root, 'patterns', 'reference', 'G41_2x12_cw');
    else
        pat_dir = options.PatternDir;
    end

    if ~isfolder(pat_dir)
        error('Pattern directory not found: %s\nRun create_g41_experiment_patterns.m first.', pat_dir);
    end

    d = dir(fullfile(pat_dir, '*.pat'));
    % Exclude macOS dot-files from source pattern list
    d = d(~startsWith({d.name}, '._'));
    if isempty(d)
        error('No .pat files found in: %s', pat_dir);
    end
    pattern_paths = fullfile(pat_dir, sort({d.name}));
    num_patterns = length(pattern_paths);

    %% Initialize results
    results = struct();
    results.passed = 0;
    results.failed = 0;
    results.total = 0;
    results.details = {};

    fprintf('\n========================================\n');
    fprintf('  SD Card Deployment Test Suite\n');
    fprintf('========================================\n');
    fprintf('  Patterns: %d from %s\n', num_patterns, pat_dir);
    fprintf('  Mode: %s\n', iif(options.UseRealSD, 'Real SD card', 'Fake SD (folder)'));
    if options.UseRealSD && options.Format
        fprintf('  WARNING: Format enabled — SD card will be ERASED\n');
    end
    fprintf('========================================\n\n');

    %% ===== PART 1: Fake SD Card Tests (always run) =====
    fprintf('--- Part 1: Fake SD Card Tests ---\n\n');

    fake_sd = fullfile(tempdir, 'test_sd_card_deployment');
    if isfolder(fake_sd)
        rmdir(fake_sd, 's');
    end
    mkdir(fake_sd);

    % Test 1.1: Basic deployment to folder
    try
        mapping = prepare_sd_card_crossplatform(pattern_paths, fake_sd, ...
            'ValidateDriveName', false);

        if mapping.success
            record_pass('1.1 Basic deployment', ...
                sprintf('%d patterns deployed to fake SD', mapping.num_patterns));
        else
            record_fail('1.1 Basic deployment', mapping.error);
        end
    catch ME
        record_fail('1.1 Basic deployment', ME.message);
    end

    % Test 1.2: Pattern count and naming
    target_dir = fullfile(fake_sd, 'patterns');
    if isfolder(target_dir)
        pat_files = dir(fullfile(target_dir, 'pat*.pat'));
        pat_files = pat_files(~startsWith({pat_files.name}, '._'));

        if length(pat_files) == num_patterns
            record_pass('1.2 Pattern count', ...
                sprintf('%d patterns on card (expected %d)', length(pat_files), num_patterns));
        else
            record_fail('1.2 Pattern count', ...
                sprintf('Found %d, expected %d', length(pat_files), num_patterns));
        end

        % Check naming convention
        expected_first = 'pat0001.pat';
        expected_last = sprintf('pat%04d.pat', num_patterns);
        names = sort({pat_files.name});
        if strcmp(names{1}, expected_first) && strcmp(names{end}, expected_last)
            record_pass('1.3 Pattern naming', ...
                sprintf('%s through %s', expected_first, expected_last));
        else
            record_fail('1.3 Pattern naming', ...
                sprintf('First: %s, Last: %s', names{1}, names{end}));
        end
    else
        record_fail('1.2 Pattern count', 'Patterns folder not found');
        record_fail('1.3 Pattern naming', 'Patterns folder not found');
    end

    % Test 1.4: MANIFEST.bin format
    manifest_bin = fullfile(fake_sd, 'MANIFEST.bin');
    if isfile(manifest_bin)
        fid = fopen(manifest_bin, 'rb');
        count_read = fread(fid, 1, 'uint16');
        ts_read = fread(fid, 1, 'uint32');
        fclose(fid);

        if count_read == num_patterns
            record_pass('1.4 MANIFEST.bin count', ...
                sprintf('count=%d (expected %d)', count_read, num_patterns));
        else
            record_fail('1.4 MANIFEST.bin count', ...
                sprintf('count=%d (expected %d)', count_read, num_patterns));
        end

        if ts_read > 1700000000 && ts_read < 2000000000
            record_pass('1.5 MANIFEST.bin timestamp', ...
                sprintf('timestamp=%d (valid unix range)', ts_read));
        else
            record_fail('1.5 MANIFEST.bin timestamp', ...
                sprintf('timestamp=%d (out of range)', ts_read));
        end
    else
        record_fail('1.4 MANIFEST.bin count', 'File not found');
        record_fail('1.5 MANIFEST.bin timestamp', 'File not found');
    end

    % Test 1.6: MANIFEST.txt content
    manifest_txt = fullfile(fake_sd, 'MANIFEST.txt');
    if isfile(manifest_txt)
        txt_content = fileread(manifest_txt);
        has_timestamp = contains(txt_content, 'Timestamp:');
        has_count = contains(txt_content, sprintf('Pattern Count: %d', num_patterns));
        has_mapping = contains(txt_content, 'pat0001.pat');

        if has_timestamp && has_count && has_mapping
            record_pass('1.6 MANIFEST.txt content', 'All expected fields present');
        else
            record_fail('1.6 MANIFEST.txt content', ...
                sprintf('Missing: %s%s%s', ...
                iif(~has_timestamp, 'timestamp ', ''), ...
                iif(~has_count, 'count ', ''), ...
                iif(~has_mapping, 'mapping', '')));
        end
    else
        record_fail('1.6 MANIFEST.txt content', 'File not found');
    end

    % Test 1.7: Mapping struct fields
    if exist('mapping', 'var') && mapping.success
        required_fields = {'success', 'error', 'timestamp', 'timestamp_unix', ...
            'sd_drive', 'num_patterns', 'patterns', 'log_file', ...
            'staging_dir', 'target_dir'};
        missing_fields = {};
        for i = 1:length(required_fields)
            if ~isfield(mapping, required_fields{i})
                missing_fields{end+1} = required_fields{i}; %#ok<AGROW>
            end
        end

        if isempty(missing_fields)
            record_pass('1.7 Mapping struct fields', ...
                sprintf('All %d required fields present', length(required_fields)));
        else
            record_fail('1.7 Mapping struct fields', ...
                sprintf('Missing: %s', strjoin(missing_fields, ', ')));
        end
    else
        record_fail('1.7 Mapping struct fields', 'Mapping not available');
    end

    % Test 1.8: macOS dot-file prevention (xattr -c)
    if ismac
        fprintf('\n  [Mac-specific] Testing dot-file prevention...\n');

        % Clean and redo
        if isfolder(fake_sd), rmdir(fake_sd, 's'); end
        mkdir(fake_sd);

        mapping2 = prepare_sd_card_crossplatform(pattern_paths, fake_sd, ...
            'ValidateDriveName', false);

        % Check no dot-files were created
        dot_files_pat = dir(fullfile(fake_sd, 'patterns', '._*'));
        dot_files_root = dir(fullfile(fake_sd, '._*'));
        total_dots = length(dot_files_pat) + length(dot_files_root);

        if total_dots == 0 && mapping2.success
            record_pass('1.8 macOS dot-file prevention', ...
                'No ._* files on fake SD (xattr -c worked)');
        elseif ~mapping2.success
            record_fail('1.8 macOS dot-file prevention', ...
                sprintf('Deployment failed: %s', mapping2.error));
        else
            record_fail('1.8 macOS dot-file prevention', ...
                sprintf('%d dot-files still present', total_dots));
        end
    else
        record_pass('1.8 macOS dot-file prevention', 'Skipped (not macOS)');
    end

    % Test 1.9: ValidateDriveName with wrong name
    fprintf('\n  Testing ValidateDriveName rejection...\n');
    wrong_name_sd = fullfile(tempdir, 'test_sd_WRONGNAME');
    if isfolder(wrong_name_sd), rmdir(wrong_name_sd, 's'); end
    mkdir(wrong_name_sd);

    mapping_bad = prepare_sd_card_crossplatform(pattern_paths, wrong_name_sd, ...
        'ValidateDriveName', true);

    if ismac
        if ~mapping_bad.success && contains(mapping_bad.error, 'not named PATSD')
            record_pass('1.9 ValidateDriveName rejection', ...
                'Correctly rejected non-PATSD volume');
        else
            record_fail('1.9 ValidateDriveName rejection', ...
                sprintf('Expected rejection, got: success=%d error="%s"', ...
                mapping_bad.success, mapping_bad.error));
        end
    else
        % On non-Mac non-Windows, ValidateDriveName may not apply
        record_pass('1.9 ValidateDriveName rejection', 'Skipped (not Mac/Windows)');
    end
    rmdir(wrong_name_sd, 's');

    % Test 1.10: Empty pattern list
    mapping_empty = prepare_sd_card_crossplatform({}, fake_sd, ...
        'ValidateDriveName', false);
    if ~mapping_empty.success && contains(mapping_empty.error, 'empty')
        record_pass('1.10 Empty pattern list', 'Correctly rejected empty input');
    else
        record_fail('1.10 Empty pattern list', 'Did not reject empty pattern list');
    end

    %% ===== PART 2: detect_sd_card Tests =====
    fprintf('\n--- Part 2: detect_sd_card Tests ---\n\n');

    % Test 2.1: detect_sd_card runs without error
    try
        sd = detect_sd_card('Verbose', false);
        record_pass('2.1 detect_sd_card runs', ...
            sprintf('found=%d, platform=%s', sd.found, sd.platform));
    catch ME
        record_fail('2.1 detect_sd_card runs', ME.message);
    end

    % Test 2.2: Struct has required fields
    if exist('sd', 'var')
        sd_fields = {'found', 'path', 'label', 'platform', 'device', ...
            'candidates', 'error'};
        missing = {};
        for i = 1:length(sd_fields)
            if ~isfield(sd, sd_fields{i})
                missing{end+1} = sd_fields{i}; %#ok<AGROW>
            end
        end
        if isempty(missing)
            record_pass('2.2 detect_sd_card fields', ...
                sprintf('All %d fields present', length(sd_fields)));
        else
            record_fail('2.2 detect_sd_card fields', ...
                sprintf('Missing: %s', strjoin(missing, ', ')));
        end
    else
        record_fail('2.2 detect_sd_card fields', 'sd struct not available');
    end

    % Test 2.3: Custom label
    try
        sd_custom = detect_sd_card('Label', 'NONEXISTENT_LABEL_12345', 'Verbose', false);
        if ~sd_custom.found
            record_pass('2.3 Custom label (not found)', ...
                'Correctly returns found=false for nonexistent label');
        else
            record_fail('2.3 Custom label (not found)', ...
                'Unexpectedly found a volume named NONEXISTENT_LABEL_12345');
        end
    catch ME
        record_fail('2.3 Custom label (not found)', ME.message);
    end

    %% ===== PART 3: Real SD Card Tests (optional) =====
    if options.UseRealSD
        fprintf('\n--- Part 3: Real SD Card Tests ---\n\n');

        sd_real = detect_sd_card('Verbose', true);

        if ~sd_real.found
            fprintf('  ⚠ SD card not detected. Skipping real SD tests.\n');
            record_fail('3.1 Real SD detected', 'PATSD not found — insert card and retry');
        else
            record_pass('3.1 Real SD detected', sprintf('Found at %s', sd_real.path));

            % Test 3.2: Deploy to real SD (with or without format)
            mapping_real = prepare_sd_card_crossplatform(pattern_paths, sd_real.path, ...
                'Format', options.Format);

            if mapping_real.success
                record_pass('3.2 Real SD deployment', ...
                    sprintf('%d patterns deployed to %s', ...
                    mapping_real.num_patterns, sd_real.path));

                % Test 3.3: Verify no dot-files on real SD
                if ismac
                    real_target = mapping_real.target_dir;
                    dot_check = dir(fullfile(real_target, '._*'));
                    if isempty(dot_check)
                        record_pass('3.3 Real SD no dot-files', ...
                            'No ._* files on SD card');
                    else
                        record_fail('3.3 Real SD no dot-files', ...
                            sprintf('%d dot-files found — dirIndex may be corrupted', ...
                            length(dot_check)));
                    end
                else
                    record_pass('3.3 Real SD no dot-files', 'Skipped (not macOS)');
                end

                % Test 3.4: Verify pattern count on real SD
                real_pats = dir(fullfile(mapping_real.target_dir, '*.pat'));
                real_pats = real_pats(~startsWith({real_pats.name}, '._'));
                if length(real_pats) == num_patterns
                    record_pass('3.4 Real SD pattern count', ...
                        sprintf('%d patterns verified', length(real_pats)));
                else
                    record_fail('3.4 Real SD pattern count', ...
                        sprintf('Found %d, expected %d', length(real_pats), num_patterns));
                end
            else
                record_fail('3.2 Real SD deployment', mapping_real.error);
                record_fail('3.3 Real SD no dot-files', 'Deployment failed');
                record_fail('3.4 Real SD pattern count', 'Deployment failed');
            end
        end
    end

    %% ===== Summary =====
    fprintf('\n========================================\n');
    fprintf('  RESULTS: %d/%d passed', results.passed, results.total);
    if results.failed > 0
        fprintf(' (%d FAILED)', results.failed);
    end
    fprintf('\n========================================\n\n');

    if options.Verbose && results.failed > 0
        fprintf('Failed tests:\n');
        for i = 1:length(results.details)
            if ~results.details{i}{2}
                fprintf('  ✗ %s: %s\n', results.details{i}{1}, results.details{i}{3});
            end
        end
        fprintf('\n');
    end

    % Cleanup
    if isfolder(fake_sd)
        rmdir(fake_sd, 's');
    end

    %% ===== Nested helper functions =====

    function record_pass(name, msg)
        results.passed = results.passed + 1;
        results.total = results.total + 1;
        results.details{end+1} = {name, true, msg};
        if options.Verbose
            fprintf('  ✓ %s: %s\n', name, msg);
        end
    end

    function record_fail(name, msg)
        results.failed = results.failed + 1;
        results.total = results.total + 1;
        results.details{end+1} = {name, false, msg};
        fprintf('  ✗ %s: %s\n', name, msg);
    end

    function val = iif(cond, true_val, false_val)
        if cond
            val = true_val;
        else
            val = false_val;
        end
    end

end

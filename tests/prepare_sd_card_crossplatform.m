function mapping = prepare_sd_card_crossplatform(pattern_paths, sd_location, options)
% PREPARE_SD_CARD_CROSSPLATFORM Cross-platform version of prepare_sd_card
%
%   mapping = prepare_sd_card_crossplatform(pattern_paths, sd_location)
%   mapping = prepare_sd_card_crossplatform(pattern_paths, sd_location, 'Format', true)
%   mapping = prepare_sd_card_crossplatform(pattern_paths, sd_location, 'UsePatternFolder', false)
%   mapping = prepare_sd_card_crossplatform(pattern_paths, sd_location, 'StagingDir', '/path/to/staging')
%
%   Cross-platform wrapper that works on Windows, Mac, and Linux.
%   Handles both drive letters (Windows) and absolute paths (Mac/Linux).
%
%   INPUTS:
%       pattern_paths - Cell array of full paths to pattern files (in desired order)
%       sd_location   - SD card location:
%                       Windows: Drive letter (e.g., 'E' or 'E:')
%                       Mac/Linux: Absolute path (e.g., '/Volumes/SD_CARD' or '/tmp/fake_sd')
%       options       - Name-value pairs:
%           'Format' (false)          - Format SD card before copying (Windows only)
%           'UsePatternFolder' (true) - Copy patterns to /patterns subfolder
%           'StagingDir' ('')         - Custom staging directory (default: tempdir/sd_staging)
%           'ValidateDriveName' (true)- Require SD card named PATSD (Windows only)
%
%   OUTPUTS:
%       mapping - Struct with same fields as prepare_sd_card.m
%
%   EXAMPLES:
%       % Windows (real SD card)
%       mapping = prepare_sd_card_crossplatform(patterns, 'E');
%       mapping = prepare_sd_card_crossplatform(patterns, 'E', 'Format', true);
%       
%       % Mac (real SD card)
%       mapping = prepare_sd_card_crossplatform(patterns, '/Volumes/SD_CARD');
%       
%       % Mac (testing with fake folder)
%       mapping = prepare_sd_card_crossplatform(patterns, '/tmp/fake_sd_card');
%       
%       % Linux
%       mapping = prepare_sd_card_crossplatform(patterns, '/media/user/SD_CARD');
%
%   TESTING ON MAC:
%       % Create fake SD card folder
%       fake_sd = '/tmp/fake_sd_card';
%       if isfolder(fake_sd), rmdir(fake_sd, 's'); end
%       mkdir(fake_sd);
%       
%       % Deploy to fake SD card
%       patterns = {'pattern1.pat', 'pattern2.pat'};
%       result = prepare_sd_card_crossplatform(patterns, fake_sd);
%       
%       % Check contents
%       dir(fullfile(fake_sd, 'patterns'))
%       type(fullfile(fake_sd, 'MANIFEST.txt'))
%
%   NOTES:
%       - Pattern IDs are determined by position in pattern_paths array
%       - Same file can appear multiple times with different IDs
%       - Lowercase filenames: pat0001.pat, pat0002.pat, etc.
%       - MANIFEST files written AFTER patterns for correct FAT32 dirIndex
%       - Format option only works on Windows
%       - ValidateDriveName option only applies to Windows
%
%   See also: prepare_sd_card, deploy_experiments_to_sd

    arguments
        pattern_paths cell
        sd_location char
        options.Format (1,1) logical = false
        options.UsePatternFolder (1,1) logical = true
        options.StagingDir char = ''
        options.ValidateDriveName (1,1) logical = true
    end

    %% Initialize mapping struct
    mapping = struct();
    mapping.success = false;
    mapping.error = '';
    mapping.timestamp = '';
    mapping.timestamp_unix = uint32(0);
    mapping.sd_drive = '';
    mapping.num_patterns = 0;
    mapping.patterns = {};
    mapping.log_file = '';
    mapping.staging_dir = '';
    mapping.target_dir = '';

    %% Set staging directory
    if isempty(options.StagingDir)
        staging_dir = fullfile(tempdir, 'sd_staging');
    else
        staging_dir = options.StagingDir;
    end
    mapping.staging_dir = staging_dir;
    
    %% Detect platform and location type
    is_windows = ispc;
    
    % Check if sd_location looks like a Windows drive letter
    is_drive_letter = (length(sd_location) <= 2 && ...
                      ((length(sd_location) == 1 && isletter(sd_location)) || ...
                       (length(sd_location) == 2 && sd_location(2) == ':')));
    
    %% Normalize location to sd_root path
    if is_drive_letter
        if ~is_windows
            % Non-Windows platform but given a drive letter - error
            mapping.error = 'Drive letters (e.g., ''E:'') are only valid on Windows. On Mac/Linux, provide full path (e.g., ''/Volumes/SD_CARD'')';
            return;
        end
        
        % Windows drive letter - normalize
        sd_drive = upper(strrep(sd_location, ':', ''));
        if length(sd_drive) ~= 1 || ~isletter(sd_drive)
            mapping.error = 'sd_location must be a single letter (e.g., ''E'') or full path';
            return;
        end
        mapping.sd_drive = sd_drive;
        sd_root = [sd_drive, ':'];
    else
        % Absolute path (Mac/Linux or Windows path)
        sd_root = sd_location;
        mapping.sd_drive = sd_location;  % Store full path for non-Windows
    end
    
    %% Check location exists
    if ~isfolder(sd_root)
        mapping.error = sprintf('SD card location not found: %s', sd_root);
        return;
    end
    
    %% Validate SD card name (Windows only)
    if is_windows && is_drive_letter && options.ValidateDriveName
        try
            [~, vol_name] = system(['vol ' sd_drive ':']);
            if ~contains(vol_name, 'PATSD')
                mapping.error = sprintf('SD card is not named PATSD. Found: %s\nUse ''ValidateDriveName'', false to skip this check.', strtrim(vol_name));
                return;
            end
            fprintf('✓ SD card validated: PATSD\n');
        catch ME
            mapping.error = sprintf('Could not validate SD card name: %s', ME.message);
            return;
        end
    elseif ~is_windows && options.ValidateDriveName
        % ValidateDriveName requested but not on Windows - just warn
        fprintf('Note: ValidateDriveName only applies to Windows drive letters\n');
    end
    
    %% Validate pattern count
    num_patterns = length(pattern_paths);
    if num_patterns == 0
        mapping.error = 'pattern_paths is empty';
        return;
    end
    if num_patterns > 9999
        mapping.error = sprintf('Maximum 9999 patterns supported (got %d)', num_patterns);
        return;
    end
    mapping.num_patterns = num_patterns;
    
    %% Validate all pattern files exist
    for i = 1:num_patterns
        if ~isfile(pattern_paths{i})
            mapping.error = sprintf('Pattern file not found: %s', pattern_paths{i});
            return;
        end
    end
    
    %% Generate timestamps
    now_dt = datetime('now');
    timestamp = uint32(floor(posixtime(now_dt)));
    timestamp_str = datestr(now_dt, 'yyyy-mm-ddTHH:MM:SS');
    timestamp_filename = datestr(now_dt, 'yyyymmdd_HHMMSS');
    
    mapping.timestamp = timestamp_str;
    mapping.timestamp_unix = timestamp;
    
    %% Create staging directory
    fprintf('Creating staging directory: %s\n', staging_dir);
    
    try
        if isfolder(staging_dir)
            rmdir(staging_dir, 's');
        end
        mkdir(staging_dir);
        mkdir(fullfile(staging_dir, 'patterns'));
    catch ME
        mapping.error = sprintf('Failed to create staging directory: %s', ME.message);
        return;
    end
    
    %% Copy and rename patterns to staging
    fprintf('Staging %d patterns...\n', num_patterns);
    
    mapping.patterns = cell(num_patterns, 1);
    
    for i = 1:num_patterns
        old_path = pattern_paths{i};
        new_name = sprintf('pat%04d.pat', i);  % Lowercase to match boss's version
        new_path = fullfile(staging_dir, 'patterns', new_name);
        
        try
            copyfile(old_path, new_path);
        catch ME
            mapping.error = sprintf('Failed to copy pattern %s: %s', old_path, ME.message);
            return;
        end
        
        mapping.patterns{i} = struct('new_name', new_name, 'original_path', old_path);
        fprintf('  %s <- %s\n', new_name, old_path);
    end
    
    %% Create MANIFEST.bin (binary) in staging
    bin_path = fullfile(staging_dir, 'MANIFEST.bin');
    try
        fid = fopen(bin_path, 'wb');
        if fid == -1
            error('Could not open file');
        end
        fwrite(fid, uint16(num_patterns), 'uint16');  % 2 bytes: pattern count
        fwrite(fid, timestamp, 'uint32');              % 4 bytes: unix timestamp
        fclose(fid);
    catch ME
        mapping.error = sprintf('Failed to create MANIFEST.bin: %s', ME.message);
        return;
    end
    fprintf('Created MANIFEST.bin (count=%d, timestamp=%d)\n', num_patterns, timestamp);
    
    %% Create MANIFEST.txt (human-readable) in staging
    txt_path = fullfile(staging_dir, 'MANIFEST.txt');
    try
        fid = fopen(txt_path, 'w');
        if fid == -1
            error('Could not open file');
        end
        
        fprintf(fid, 'Timestamp: %s\r\n', timestamp_str);
        fprintf(fid, 'SD Location: %s\r\n', sd_root);
        fprintf(fid, 'Pattern Count: %d\r\n', num_patterns);
        fprintf(fid, '\r\n');
        fprintf(fid, 'Mapping:\r\n');
        
        for i = 1:num_patterns
            fprintf(fid, '%s <- %s\r\n', mapping.patterns{i}.new_name, mapping.patterns{i}.original_path);
        end
        
        fclose(fid);
    catch ME
        mapping.error = sprintf('Failed to create MANIFEST.txt: %s', ME.message);
        return;
    end
    fprintf('Created MANIFEST.txt\n');
    
    %% Save local log copy
    try
        this_file = mfilename('fullpath');
        [this_dir, ~, ~] = fileparts(this_file);
        repo_root = fileparts(this_dir);  % Go up one level
        logs_dir = fullfile(repo_root, 'logs');
        
        if ~isfolder(logs_dir)
            mkdir(logs_dir);
        end
        
        log_filename = sprintf('MANIFEST_%s.txt', timestamp_filename);
        log_path = fullfile(logs_dir, log_filename);
        copyfile(txt_path, log_path);
        mapping.log_file = log_path;
        fprintf('Saved local log: %s\n', log_path);
    catch ME
        warning('Failed to save local log: %s', ME.message);
    end
    
    %% Determine target directory on SD card
    if options.UsePatternFolder
        target_dir = fullfile(sd_root, 'patterns');
    else
        target_dir = sd_root;
    end
    mapping.target_dir = target_dir;
    
    %% Format or clear SD card
    fprintf('\nPreparing SD card (%s)...\n', sd_root);
    
    if options.Format
        if ~is_windows || ~is_drive_letter
            % Format only works on Windows with drive letters
            fprintf('  Warning: Format option only works on Windows with drive letters. Skipping format.\n');
            % Continue with manual cleanup instead
            options.Format = false;
        end
    end
    
    if options.Format && is_windows && is_drive_letter
        % Format the SD card (FAT32, label PATSD) - Windows only
        fprintf('  Formatting as FAT32 (PATSD)...\n');
        [status, result] = system(sprintf('format %s: /FS:FAT32 /V:PATSD /Q /Y', sd_drive));
        if status ~= 0
            mapping.error = sprintf('Format failed: %s', result);
            return;
        end
        fprintf('  ✓ SD card formatted\n');
        
        % Create patterns folder if needed
        if options.UsePatternFolder
            mkdir(target_dir);
            fprintf('  ✓ Created patterns folder\n');
        end
    else
        % Manual cleanup (works on all platforms)
        if options.UsePatternFolder
            % Remove and recreate patterns folder
            if isfolder(target_dir)
                fprintf('  Removing old patterns folder...\n');
                rmdir(target_dir, 's');
            end
            mkdir(target_dir);
        else
            % Delete all files in root (but not directories)
            old_files = dir(fullfile(sd_root, '*.*'));
            for i = 1:length(old_files)
                if ~old_files(i).isdir
                    delete(fullfile(sd_root, old_files(i).name));
                end
            end
            fprintf('  ✓ Cleared existing files\n');
        end
        
        % Delete old manifest files from root (in case switching modes)
        old_manifest_bin = fullfile(sd_root, 'MANIFEST.bin');
        old_manifest_txt = fullfile(sd_root, 'MANIFEST.txt');
        if isfile(old_manifest_bin)
            delete(old_manifest_bin);
        end
        if isfile(old_manifest_txt)
            delete(old_manifest_txt);
        end
    end
    
    %% Copy patterns to SD card (FIRST - for correct dirIndex order)
    fprintf('  Copying %d patterns...\n', num_patterns);
    try
        for i = 1:num_patterns
            src = fullfile(staging_dir, 'patterns', sprintf('pat%04d.pat', i));
            dst = fullfile(target_dir, sprintf('pat%04d.pat', i));
            copyfile(src, dst);
        end
    catch ME
        mapping.error = sprintf('Failed to copy patterns to SD card: %s', ME.message);
        return;
    end
    fprintf('  ✓ Copied %d patterns\n', num_patterns);
    
    %% Copy manifest files to SD card (AFTER patterns for correct dirIndex)
    try
        copyfile(bin_path, fullfile(sd_root, 'MANIFEST.bin'));
        copyfile(txt_path, fullfile(sd_root, 'MANIFEST.txt'));
    catch ME
        mapping.error = sprintf('Failed to copy manifest files: %s', ME.message);
        return;
    end
    fprintf('  ✓ Copied manifest files\n');
    
    %% Verify
    verify_count = length(dir(fullfile(target_dir, '*.pat')));
    if verify_count ~= num_patterns
        mapping.error = sprintf('Verification failed: expected %d patterns, found %d on SD card', ...
            num_patterns, verify_count);
        return;
    end
    
    %% Summary
    fprintf('\n=== SD Card Ready ===\n');
    fprintf('Location: %s\n', sd_root);
    fprintf('Target: %s\n', target_dir);
    fprintf('Patterns: %d (dirIndex 0-%d)\n', num_patterns, num_patterns-1);
    fprintf('Manifests: dirIndex %d-%d\n', num_patterns, num_patterns+1);
    fprintf('Verification: PASSED\n');
    
    %% Success
    mapping.success = true;
end

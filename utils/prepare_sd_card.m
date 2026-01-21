function mapping = prepare_sd_card(pattern_paths, sd_drive, options)
% PREPARE_SD_CARD Stage patterns and copy to SD card with predictable naming
%
%   mapping = prepare_sd_card(pattern_paths, sd_drive)
%   mapping = prepare_sd_card(pattern_paths, sd_drive, 'Format', true)
%   mapping = prepare_sd_card(pattern_paths, sd_drive, 'UsePatternFolder', false)
%   mapping = prepare_sd_card(pattern_paths, sd_drive, 'StagingDir', '/path/to/staging')
%
%   Takes an ordered list of pattern files, renames them to PAT0001.pat,
%   PAT0002.pat, etc., creates manifest files, and copies everything to SD card.
%
%   INPUTS:
%       pattern_paths - Cell array of full paths to pattern files (in desired order)
%       sd_drive      - Drive letter for SD card (e.g., 'E' or 'E:')
%       options       - Name-value pairs:
%           'Format' (false)          - Format SD card before copying (recommended)
%           'UsePatternFolder' (true) - Copy patterns to /patterns subfolder
%           'StagingDir' ('')         - Custom staging directory (default: tempdir/sd_staging)
%           'ValidateDriveName' (true)- Require SD card to be named PATSD
%
%   OUTPUTS:
%       mapping - Struct with fields:
%           .success        - true if SD card copy succeeded
%           .error          - error message if failed, empty if success
%           .timestamp      - human-readable timestamp
%           .timestamp_unix - uint32 unix timestamp
%           .sd_drive       - drive letter used
%           .num_patterns   - number of patterns
%           .patterns       - cell array of structs with .new_name and .original_path
%           .log_file       - path to local log file
%           .staging_dir    - path to staging directory
%           .target_dir     - final location on SD card
%
%   SD CARD STRUCTURE (UsePatternFolder=true, default):
%       E:\patterns\PAT0001.pat
%       E:\patterns\PAT0002.pat
%       E:\patterns\...
%       E:\MANIFEST.bin
%       E:\MANIFEST.txt
%
%   SD CARD STRUCTURE (UsePatternFolder=false):
%       E:\PAT0001.pat
%       E:\PAT0002.pat
%       E:\...
%       E:\MANIFEST.bin
%       E:\MANIFEST.txt
%
%   NOTES:
%       - Pattern IDs are determined by position in pattern_paths array
%       - Same file can appear multiple times with different IDs
%       - MANIFEST files are written AFTER patterns to ensure correct FAT32 dirIndex
%       - Use 'Format', true for most reliable results (clears FAT32 directory table)
%
%   EXAMPLE:
%       patterns = {
%           'C:\experiments\exp1\horizontal_grating.pat'
%           'C:\experiments\exp1\vertical_stripes.pat'
%           'C:\experiments\exp2\checkerboard.pat'
%       };
%       mapping = prepare_sd_card(patterns, 'E', 'Format', true);
%       if ~mapping.success
%           fprintf('Error: %s\n', mapping.error);
%       end
%
%   See also: maDisplayTools

    arguments
        pattern_paths cell
        sd_drive char
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
    
    %% Normalize drive letter
    sd_drive = upper(strrep(sd_drive, ':', ''));
    if length(sd_drive) ~= 1 || ~isletter(sd_drive)
        mapping.error = 'sd_drive must be a single letter (e.g., ''E'')';
        return;
    end
    mapping.sd_drive = sd_drive;
    sd_root = [sd_drive, ':'];
    
    %% Check drive exists
    if ~isfolder(sd_root)
        mapping.error = sprintf('SD card drive not found: %s', sd_root);
        return;
    end
    
    %% Validate SD card name is PATSD
    if options.ValidateDriveName
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
        new_name = sprintf('pat%04d.pat', i);
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
        fprintf(fid, 'SD Drive: %s:\r\n', sd_drive);
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
        repo_root = fileparts(this_dir);  % Go up from utils/
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
    fprintf('\nPreparing SD card (%s:)...\n', sd_drive);
    
    if options.Format
        % Format the SD card (FAT32, label PATSD)
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
        % Manual cleanup
        if options.UsePatternFolder
            % Remove and recreate patterns folder
            if isfolder(target_dir)
                fprintf('  Removing old patterns folder...\n');
                rmdir(target_dir, 's');
            end
            mkdir(target_dir);
        else
            % Delete all files in root
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
    fprintf('Drive: %s:\n', sd_drive);
    fprintf('Target: %s\n', target_dir);
    fprintf('Patterns: %d (dirIndex 0-%d)\n', num_patterns, num_patterns-1);
    fprintf('Manifests: dirIndex %d-%d\n', num_patterns, num_patterns+1);
    fprintf('Verification: PASSED\n');
    
    %% Success
    mapping.success = true;
end
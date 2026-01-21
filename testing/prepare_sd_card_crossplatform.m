function mapping = prepare_sd_card_crossplatform(pattern_paths, sd_location, staging_dir)
% PREPARE_SD_CARD_CROSSPLATFORM Cross-platform wrapper for prepare_sd_card
%
%   mapping = prepare_sd_card_crossplatform(pattern_paths, sd_location)
%   mapping = prepare_sd_card_crossplatform(pattern_paths, sd_location, staging_dir)
%
%   Works on Windows, Mac, and Linux. Handles both drive letters (Windows)
%   and absolute paths (Mac/Linux).
%
%   INPUTS:
%       pattern_paths - Cell array of full paths to pattern files (in desired order)
%       sd_location   - SD card location:
%                       Windows: Drive letter (e.g., 'E' or 'E:')
%                       Mac/Linux: Absolute path (e.g., '/Volumes/SD_CARD' or '/tmp/fake_sd')
%       staging_dir   - (Optional) Path for staging directory
%
%   OUTPUTS:
%       mapping - Same struct as prepare_sd_card (see prepare_sd_card.m)
%
%   EXAMPLES:
%       % Windows (real SD card)
%       mapping = prepare_sd_card_crossplatform(patterns, 'E');
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
%       if isfolder(fake_sd)
%           rmdir(fake_sd, 's');
%       end
%       mkdir(fake_sd);
%       
%       % Deploy to fake SD card
%       result = deploy_experiments_to_sd('test.yaml', fake_sd);
%       
%       % Check contents
%       dir(fullfile(fake_sd, 'patterns'))
%       type(fullfile(fake_sd, 'MANIFEST.txt'))
%
%   See also: prepare_sd_card, deploy_experiments_to_sd

    %% Input validation
    if nargin < 2
        error('Must provide pattern_paths and sd_location');
    end
    
    if nargin < 3
        staging_dir = '';
    end
    
    %% Detect platform and SD card type
    is_windows = ispc;
    
    % Check if sd_location looks like a Windows drive letter
    is_drive_letter = (length(sd_location) <= 2 && ...
                      ((length(sd_location) == 1 && isletter(sd_location)) || ...
                       (length(sd_location) == 2 && sd_location(2) == ':')));
    
    %% Handle based on platform and location type
    if is_windows && is_drive_letter
        % Windows with drive letter - use original prepare_sd_card
        if isempty(staging_dir)
            mapping = prepare_sd_card(pattern_paths, sd_location);
        else
            mapping = prepare_sd_card(pattern_paths, sd_location, staging_dir);
        end
        
    elseif ~is_windows && is_drive_letter
        % Non-Windows platform but given a drive letter - error
        mapping = struct();
        mapping.success = false;
        mapping.error = 'Drive letters (e.g., ''E:'') are only valid on Windows. On Mac/Linux, provide full path (e.g., ''/Volumes/SD_CARD'')';
        mapping.timestamp = '';
        mapping.timestamp_unix = uint32(0);
        mapping.sd_drive = '';
        mapping.num_patterns = 0;
        mapping.patterns = {};
        mapping.log_file = '';
        mapping.staging_dir = '';
        
    else
        % Mac/Linux path or Windows path (not drive letter)
        % Use modified version that handles absolute paths
        if isempty(staging_dir)
            mapping = prepare_sd_card_path(pattern_paths, sd_location);
        else
            mapping = prepare_sd_card_path(pattern_paths, sd_location, staging_dir);
        end
    end
end


function mapping = prepare_sd_card_path(pattern_paths, sd_path, staging_dir)
% Modified version of prepare_sd_card that accepts absolute paths
% This is nearly identical to prepare_sd_card.m but uses sd_path instead of drive letter

    %% Initialize mapping struct early
    mapping = struct();
    mapping.success = false;
    mapping.error = '';
    mapping.timestamp = '';
    mapping.timestamp_unix = uint32(0);
    mapping.sd_drive = sd_path;  % Store full path instead of drive letter
    mapping.num_patterns = 0;
    mapping.patterns = {};
    mapping.log_file = '';
    mapping.staging_dir = '';

    %% Input validation
    if nargin < 2
        mapping.error = 'Must provide pattern_paths and sd_path';
        return;
    end
    
    if nargin < 3 || isempty(staging_dir)
        staging_dir = fullfile(tempdir, 'sd_staging');
    end
    
    mapping.staging_dir = staging_dir;
    
    % Validate SD path exists or can be created
    if ~isfolder(sd_path)
        mapping.error = sprintf('SD card path not found: %s', sd_path);
        return;
    end
    
    % Validate pattern count
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
    
    % Validate all pattern files exist
    for i = 1:num_patterns
        if ~isfile(pattern_paths{i})
            mapping.error = sprintf('Pattern file not found: %s', pattern_paths{i});
            return;
        end
    end
    
    %% Generate timestamps
    timestamp = uint32(posixtime(datetime('now')));
    timestamp_str = datestr(datetime('now'), 'yyyy-mm-ddTHH:MM:SS');
    timestamp_filename = datestr(datetime('now'), 'yyyymmdd_HHMMSS');
    
    mapping.timestamp = timestamp_str;
    mapping.timestamp_unix = timestamp;
    
    %% Create staging directory
    fprintf('Creating staging directory: %s\n', staging_dir);
    
    try
        % Clean up old staging if exists
        if isfolder(staging_dir)
            rmdir(staging_dir, 's');
        end
        mkdir(staging_dir);
        mkdir(fullfile(staging_dir, 'patterns'));
    catch ME
        mapping.error = sprintf('Failed to create staging directory: %s', ME.message);
        return;
    end
    
    %% Copy and rename patterns
    fprintf('Staging %d patterns...\n', num_patterns);
    
    mapping.patterns = cell(num_patterns, 1);
    
    for i = 1:num_patterns
        old_path = pattern_paths{i};
        new_name = sprintf('PAT%04d.pat', i);
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
    
    %% Create MANIFEST.bin (binary)
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
    
    %% Create MANIFEST.txt (human-readable)
    txt_path = fullfile(staging_dir, 'MANIFEST.txt');
    try
        fid = fopen(txt_path, 'w');
        if fid == -1
            error('Could not open file');
        end
        
        fprintf(fid, 'Timestamp: %s\n', timestamp_str);
        fprintf(fid, 'SD Location: %s\n', sd_path);
        fprintf(fid, 'Pattern Count: %d\n', num_patterns);
        fprintf(fid, '\n');
        fprintf(fid, 'Mapping:\n');
        
        for i = 1:num_patterns
            fprintf(fid, '%s <- %s\n', mapping.patterns{i}.new_name, mapping.patterns{i}.original_path);
        end
        
        fclose(fid);
    catch ME
        mapping.error = sprintf('Failed to create MANIFEST.txt: %s', ME.message);
        return;
    end
    fprintf('Created MANIFEST.txt\n');
    
    %% Save local log copy
    try
        % Try to find maDisplayTools root for logs
        % If not found, save to current directory
        this_file = mfilename('fullpath');
        if ~isempty(this_file)
            [this_dir, ~, ~] = fileparts(this_file);
            repo_root = fileparts(fileparts(this_dir));  % Go up from utils/file_transfer
            logs_dir = fullfile(repo_root, 'logs');
        else
            logs_dir = fullfile(pwd, 'logs');
        end
        
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
        % Don't return - this is non-critical
    end
    
    %% Copy to SD card
    sd_root = sd_path;
    sd_patterns = fullfile(sd_root, 'patterns');
    
    fprintf('\nCopying to SD card (%s)...\n', sd_root);
    
    % Check SD card is accessible
    if ~isfolder(sd_root)
        mapping.error = sprintf('SD card path not found: %s', sd_root);
        return;
    end
    
    try
        % Delete old patterns folder if exists
        if isfolder(sd_patterns)
            fprintf('  Removing old patterns folder...\n');
            rmdir(sd_patterns, 's');
        end
        
        % Delete old manifest files if exist
        old_manifest_bin = fullfile(sd_root, 'MANIFEST.bin');
        old_manifest_txt = fullfile(sd_root, 'MANIFEST.txt');
        if isfile(old_manifest_bin)
            delete(old_manifest_bin);
        end
        if isfile(old_manifest_txt)
            delete(old_manifest_txt);
        end
        
        % Create patterns folder on SD
        mkdir(sd_patterns);
        
        % Copy patterns one by one (preserves order on FAT32)
        fprintf('  Copying %d patterns...\n', num_patterns);
        for i = 1:num_patterns
            src = fullfile(staging_dir, 'patterns', sprintf('PAT%04d.pat', i));
            dst = fullfile(sd_patterns, sprintf('PAT%04d.pat', i));
            copyfile(src, dst);
        end
        
        % Copy manifest files
        copyfile(bin_path, fullfile(sd_root, 'MANIFEST.bin'));
        copyfile(txt_path, fullfile(sd_root, 'MANIFEST.txt'));
    catch ME
        mapping.error = sprintf('Failed to copy to SD card: %s', ME.message);
        return;
    end
    
    fprintf('\nDone! Copied %d patterns to %s\n', num_patterns, sd_root);
    
    %% Verify
    verify_count = length(dir(fullfile(sd_patterns, '*.pat')));
    if verify_count ~= num_patterns
        mapping.error = sprintf('Verification failed: expected %d patterns, found %d on SD card', ...
            num_patterns, verify_count);
        return;
    end
    
    fprintf('Verification passed: %d patterns on SD card\n', verify_count);
    
    %% Success
    mapping.success = true;
end

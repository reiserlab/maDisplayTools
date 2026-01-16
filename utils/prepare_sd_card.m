function mapping = prepare_sd_card(pattern_paths, sd_drive, staging_dir)
% PREPARE_SD_CARD Stage patterns and copy to SD card with predictable naming
%
%   mapping = prepare_sd_card(pattern_paths, sd_drive)
%   mapping = prepare_sd_card(pattern_paths, sd_drive, staging_dir)
%
%   Takes an ordered list of pattern files, renames them to PAT0001.pat,
%   PAT0002.pat, etc., creates manifest files, and copies everything to SD card.
%
%   INPUTS:
%       pattern_paths - Cell array of full paths to pattern files (in desired order)
%       sd_drive      - Drive letter for SD card (e.g., 'E' or 'E:')
%       staging_dir   - (Optional) Path for staging directory. Default: tempdir/sd_staging
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
%
%       Creates on SD card (if successful):
%         /patterns/PAT0001.pat
%         /patterns/PAT0002.pat
%         /patterns/...
%         /MANIFEST.bin   - Binary: uint16 count + uint32 timestamp
%         /MANIFEST.txt   - Human-readable mapping
%
%       Always creates local log:
%         maDisplayTools/logs/MANIFEST_YYYYMMDD_HHMMSS.txt
%
%   EXAMPLE:
%       patterns = {
%           '/data/exp1/horizontal_grating.pat'
%           '/data/exp1/vertical_stripes.pat'
%           '/data/exp2/checkerboard.pat'
%       };
%       mapping = prepare_sd_card(patterns, 'E');
%       if ~mapping.success
%           fprintf('Error: %s\n', mapping.error);
%       end
%
%   See also: maDisplayTools

    %% Initialize mapping struct early
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

    %% Input validation
    if nargin < 2
        mapping.error = 'Must provide pattern_paths and sd_drive';
        return;
    end
    
    if nargin < 3 || isempty(staging_dir)
        staging_dir = fullfile(tempdir, 'sd_staging');
    end
    
    mapping.staging_dir = staging_dir;
    
    % Normalize drive letter
    sd_drive = upper(strrep(sd_drive, ':', ''));
    if length(sd_drive) ~= 1 || ~isletter(sd_drive)
        mapping.error = 'sd_drive must be a single letter (e.g., ''E'')';
        return;
    end
    mapping.sd_drive = sd_drive;
    
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
        fprintf(fid, 'SD Drive: %s:\n', sd_drive);
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
        % Find maDisplayTools root (where this function lives)
        this_file = mfilename('fullpath');
        [this_dir, ~, ~] = fileparts(this_file);
        repo_root = fileparts(fileparts(this_dir));  % Go up from utils/file_transfer
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
        % Don't return - this is non-critical
    end
    
    %% Copy to SD card
    sd_root = sprintf('%s:', sd_drive);
    sd_patterns = fullfile(sd_root, 'patterns');
    
    fprintf('\nCopying to SD card (%s)...\n', sd_root);
    
    % Check SD card is accessible
    if ~isfolder(sd_root)
        mapping.error = sprintf('SD card drive not found: %s', sd_root);
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

function mapping = prepare_sd_card_test(pattern_paths, drive_letter, options)
% PREPARE_SD_CARD_TEST - Test version: copy patterns to SD card
%
% Usage:
%   mapping = prepare_sd_card_test(pattern_paths, 'E')
%   mapping = prepare_sd_card_test(pattern_paths, 'E', 'Format', true)
%   mapping = prepare_sd_card_test(pattern_paths, 'E', 'UsePatternFolder', false)
%
% Inputs:
%   pattern_paths - cell array of full paths to .pat files
%   drive_letter  - drive letter for SD card (e.g., 'E')
%   options       - Name-value pairs:
%                   'Format' (false) - format SD card before copying
%                   'UsePatternFolder' (true) - copy to /patterns subfolder
%
% Outputs:
%   mapping - struct with original names, new names, and status

    arguments
        pattern_paths cell
        drive_letter (1,1) char
        options.Format (1,1) logical = false
        options.UsePatternFolder (1,1) logical = true
    end

    % Build root path (Windows style)
    sd_root = [drive_letter, ':'];
    
    %% Validate SD card name is PATSD
    try
        [~, vol_name] = system(['vol ' drive_letter ':']);
        if ~contains(vol_name, 'PATSD')
            error('SD card is not named PATSD. Found: %s', strtrim(vol_name));
        end
        fprintf('✓ SD card validated: PATSD\n');
    catch ME
        error('Could not validate SD card name: %s', ME.message);
    end
    
    %% Check drive exists
    if ~isfolder(sd_root)
        error('Drive %s: not found', drive_letter);
    end
    
    %% Determine target directory
    if options.UsePatternFolder
        target_dir = fullfile(sd_root, 'patterns');
    else
        target_dir = sd_root;
    end
    
    %% Format or clear SD card
    if options.Format
        % Format the SD card (FAT32, label PATSD)
        fprintf('Formatting SD card %s: as PATSD...\n', drive_letter);
        [status, result] = system(sprintf('format %s: /FS:FAT32 /V:PATSD /Q /Y', drive_letter));
        if status ~= 0
            error('Format failed: %s', result);
        end
        fprintf('✓ SD card formatted\n');
        
        % Create patterns folder if needed
        if options.UsePatternFolder
            mkdir(target_dir);
            fprintf('✓ Created patterns folder\n');
        end
    else
        % Create patterns folder if needed
        if options.UsePatternFolder && ~isfolder(target_dir)
            mkdir(target_dir);
            fprintf('✓ Created patterns folder\n');
        end
        
        % Delete existing files in target directory
        old_files = dir(fullfile(target_dir, '*.*'));
        for i = 1:length(old_files)
            if ~old_files(i).isdir
                delete(fullfile(target_dir, old_files(i).name));
            end
        end
        fprintf('✓ Cleared existing files from %s\n', target_dir);
    end
    
    %% Copy and rename patterns (FIRST - for correct dirIndex order)
    n_patterns = length(pattern_paths);
    mapping = struct();
    mapping.original = pattern_paths;
    mapping.renamed = cell(n_patterns, 1);
    mapping.success = false(n_patterns, 1);
    mapping.target_dir = target_dir;
    
    for i = 1:n_patterns
        src = pattern_paths{i};
        new_name = sprintf('PAT%04d.pat', i);
        dst = fullfile(target_dir, new_name);
        
        try
            copyfile(src, dst);
            mapping.renamed{i} = new_name;
            mapping.success(i) = true;
            fprintf('  %s → %s\n', src, new_name);
        catch ME
            warning('Failed to copy %s: %s', src, ME.message);
            mapping.renamed{i} = '';
        end
    end
    
    fprintf('✓ Copied %d patterns\n', sum(mapping.success));
    
    %% Create MANIFEST.bin (AFTER patterns for correct dirIndex)
    manifest_bin = fullfile(target_dir, 'MANIFEST.bin');
    fid = fopen(manifest_bin, 'wb');
    if fid == -1
        error('Could not create MANIFEST.bin');
    end
    fwrite(fid, n_patterns, 'uint16');       % Bytes 0-1: pattern count
    fwrite(fid, floor(posixtime(datetime('now'))), 'uint32');  % Bytes 2-5: timestamp
    fclose(fid);
    fprintf('✓ Created MANIFEST.bin (%d patterns)\n', n_patterns);
    
    %% Create MANIFEST.txt (human readable, LAST)
    manifest_txt = fullfile(target_dir, 'MANIFEST.txt');
    fid = fopen(manifest_txt, 'w');
    if fid == -1
        error('Could not create MANIFEST.txt');
    end
    fprintf(fid, 'MANIFEST created: %s\r\n', datestr(now));
    fprintf(fid, 'Pattern count: %d\r\n\r\n', n_patterns);
    for i = 1:n_patterns
        [~, orig_name, ext] = fileparts(pattern_paths{i});
        fprintf(fid, '%s <- %s%s\r\n', mapping.renamed{i}, orig_name, ext);
    end
    fclose(fid);
    fprintf('✓ Created MANIFEST.txt\n');
    
    %% Summary
    fprintf('\n=== SD Card Ready ===\n');
    fprintf('Drive: %s:\n', drive_letter);
    fprintf('Target: %s\n', target_dir);
    fprintf('Patterns: %d (dirIndex 0-%d)\n', n_patterns, n_patterns-1);
    fprintf('Manifests: dirIndex %d-%d (ignored by controller)\n', n_patterns, n_patterns+1);
    
end
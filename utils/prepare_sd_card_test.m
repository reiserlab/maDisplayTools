function mapping = prepare_sd_card_test(pattern_paths, drive_letter)
% PREPARE_SD_CARD_TEST - Test version: copy patterns to SD card root
%
% Usage:
%   mapping = prepare_sd_card_test(pattern_paths, 'E')
%
% Inputs:
%   pattern_paths - cell array of full paths to .pat files
%   drive_letter  - drive letter for SD card (e.g., 'E')
%
% Outputs:
%   mapping - struct with original names, new names, and status

    % Build root path
    sd_root = [drive_letter ':\'];
    
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
        error('Drive %s not found', sd_root);
    end
    
    %% Clear existing pattern files from root
    old_pats = dir(fullfile(sd_root, 'PAT*.pat'));
    for i = 1:length(old_pats)
        delete(fullfile(sd_root, old_pats(i).name));
    end
    old_manifest = fullfile(sd_root, 'MANIFEST.bin');
    if isfile(old_manifest)
        delete(old_manifest);
    end
    fprintf('✓ Cleared old files\n');
    
    %% Copy and rename patterns
    n_patterns = length(pattern_paths);
    mapping = struct();
    mapping.original = pattern_paths;
    mapping.renamed = cell(n_patterns, 1);
    mapping.success = false(n_patterns, 1);
    
    for i = 1:n_patterns
        src = pattern_paths{i};
        new_name = sprintf('PAT%04d.pat', i);
        dst = fullfile(sd_root, new_name);
        
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
    
    %% Create MANIFEST.bin (pattern count + timestamp)
    manifest_bin = fullfile(sd_root, 'MANIFEST.bin');
    fid = fopen(manifest_bin, 'wb');
    fwrite(fid, n_patterns, 'uint16');       % Bytes 0-1: pattern count
    fwrite(fid, posixtime(datetime('now')), 'uint32');  % Bytes 2-5: timestamp
    fclose(fid);
    fprintf('✓ Created MANIFEST.bin (%d patterns, timestamp %d)\n', n_patterns, floor(posixtime(datetime('now'))));
    
    %% Create MANIFEST.txt (human readable)
    manifest_txt = fullfile(sd_root, 'MANIFEST.txt');
    fid = fopen(manifest_txt, 'w');
    fprintf(fid, 'MANIFEST created: %s\n', datestr(now));
    fprintf(fid, 'Pattern count: %d\n\n', n_patterns);
    for i = 1:n_patterns
        [~, orig_name, ext] = fileparts(pattern_paths{i});
        fprintf(fid, '%s ← %s%s\n', mapping.renamed{i}, orig_name, ext);
    end
    fclose(fid);
    fprintf('✓ Created MANIFEST.txt\n');
    
    %% Summary
    fprintf('\n=== SD Card Ready ===\n');
    fprintf('Drive: %s\n', sd_root);
    fprintf('Patterns: %d\n', n_patterns);
    
end
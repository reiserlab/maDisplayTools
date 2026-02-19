% test_sd_card_copy_100.m
% Test script to copy all 100 number patterns (00-99) to SD card
%
% Prerequisites:
%   1. Run create_test_patterns_100.m first to generate patterns
%   2. Insert SD card named PATSD and note drive letter
%
% Usage:
%   test_sd_card_copy_100        % Uses default drive 'D'
%   test_sd_card_copy_100('F')   % Specify different drive

function test_sd_card_copy_100(drive_letter)
    if nargin < 1
        drive_letter = 'D';
    end
    
    % Add utils to path
    this_dir = fileparts(mfilename('fullpath'))
    repo_root = fileparts(this_dir)
    addpath(fullfile(repo_root, 'utils'))
    
    % Find test patterns
    pat_dir = fullfile(this_dir, 'test_patterns_100')
    
    if ~isfolder(pat_dir)
        error('test_patterns_100 folder not found. Run create_test_patterns_100.m first.');
    end
    
    % Build pattern list in numeric order (00-99)
    patterns = cell(100, 1);
    missing = [];
    
    for num = 0:99
        pat_name = sprintf('pat%04d_num%02d_2x12.pat', num+1, num);
        pat_path = fullfile(pat_dir, pat_name);
        
        if isfile(pat_path)
            patterns{num + 1} = pat_path;
        else
            missing = [missing, num]; %#ok<AGROW>
        end
    end
    
    % Check for missing patterns
    if ~isempty(missing)
        error('Missing patterns: %s\nRun create_test_patterns_100.m first.', mat2str(missing));
    end
    
    fprintf('Found all 100 patterns (num00 - num99)\n');
    
    % Copy to SD card (format drive, use root directory for now)
    mapping = prepare_sd_card(patterns, drive_letter, ...
        'Format', true, ...
        'UsePatternFolder', true);
    
    if mapping.success
        fprintf('\nSuccess! %d patterns copied to %s:\n', mapping.num_patterns, mapping.sd_drive);
        fprintf('Patterns at: %s\n', mapping.target_dir);
        fprintf('\nPattern ID mapping:\n');
        fprintf('  Pattern 1 (dirIndex 0) = num00 (display "00")\n');
        fprintf('  Pattern 2 (dirIndex 1) = num01 (display "01")\n');
        fprintf('  ...\n');
        fprintf('  Pattern 100 (dirIndex 99) = num99 (display "99")\n');
        fprintf('\nNote: Until controller update, use patternID = displayNumber + 3\n');
    else
        fprintf('\nFailed: %s\n', mapping.error);
    end
end
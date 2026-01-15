% test_sd_card_copy.m
% Quick test script to copy all test patterns to SD card
%
% Prerequisites:
%   1. Run create_test_patterns.m first to generate patterns
%   2. Insert SD card and note drive letter
%
% Usage:
%   test_sd_card_copy        % Uses default drive 'E'
%   test_sd_card_copy('F')   % Specify different drive

function test_sd_card_copy(drive_letter)
    if nargin < 1
        drive_letter = 'E';
    end
    
    % Add file_transfer to path
    this_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(this_dir);
    addpath(fullfile(repo_root, 'utils', 'file_transfer'));
    
    % Find test patterns
    pat_dir = fullfile(this_dir, 'test_patterns');
    
    if ~isfolder(pat_dir)
        error('test_patterns folder not found. Run create_test_patterns.m first.');
    end
    
    files = dir(fullfile(pat_dir, '*.pat'));
    
    if isempty(files)
        error('No .pat files found in test_patterns. Run create_test_patterns.m first.');
    end
    
    % Build pattern list
    patterns = cell(length(files), 1);
    for i = 1:length(files)
        patterns{i} = fullfile(pat_dir, files(i).name);
    end
    
    fprintf('Found %d patterns to copy\n', length(patterns));
    
    % Copy to SD card
    mapping = prepare_sd_card(patterns, drive_letter);
    
    if mapping.success
        fprintf('\nSuccess! %d patterns copied to %s:\n', mapping.num_patterns, mapping.sd_drive);
    else
        fprintf('\nFailed: %s\n', mapping.error);
    end
end

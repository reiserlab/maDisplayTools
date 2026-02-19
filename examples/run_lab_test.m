function results = run_lab_test(yaml_file, varargin)
%RUN_LAB_TEST Run a hardware lab test defined by a YAML config file
%
%   results = run_lab_test('lab_test_g41_experiment.yaml')
%   results = run_lab_test('...', 'PatIDs', [1 2 5 6])  % subset
%   results = run_lab_test('...', 'DryRun', true)        % parse only
%   results = run_lab_test('...', 'IP', '10.0.0.5')      % override IP
%
%   Reads a YAML lab test config, connects to the controller, and runs
%   each pattern using trialParams(). Prints results and a verification
%   checklist at the end.
%
%   Parameters:
%       yaml_file  - Path to YAML config file (absolute or relative to
%                    examples/ directory)
%       'PatIDs'   - (optional) Array of sd_slot IDs to test (default: all)
%       'DryRun'   - (optional) If true, parse config only (default: false)
%       'IP'       - (optional) Override connection IP from config
%
%   Returns:
%       results - struct with fields:
%           config (struct): parsed YAML config
%           pat_results (cell array): per-pattern result strings
%           all_passed (logical): true if all patterns played successfully

    p = inputParser;
    addRequired(p, 'yaml_file', @ischar);
    addParameter(p, 'PatIDs', [], @isnumeric);
    addParameter(p, 'DryRun', false, @islogical);
    addParameter(p, 'IP', '', @ischar);
    parse(p, yaml_file, varargin{:});

    pat_id_filter = p.Results.PatIDs;
    dry_run = p.Results.DryRun;
    ip_override = p.Results.IP;

    %% Resolve YAML file path
    if exist(yaml_file, 'file') && ~contains(yaml_file, filesep)
        % Bare filename found on path — resolve to full path
        resolved = which(yaml_file);
        if ~isempty(resolved)
            yaml_file = resolved;
        end
    end
    if ~exist(yaml_file, 'file')
        % Try relative to examples/ directory
        examples_dir = fileparts(mfilename('fullpath'));
        yaml_file = fullfile(examples_dir, yaml_file);
    end
    if ~exist(yaml_file, 'file')
        error('run_lab_test:FileNotFound', 'YAML file not found: %s', yaml_file);
    end

    %% Parse YAML
    cfg = yamlread(yaml_file);

    fprintf('=== Lab Test: %s ===\n', cfg.lab_test.name);
    fprintf('Config: %s\n', yaml_file);

    % Extract settings
    ip_addr = ip_override;
    if isempty(ip_addr)
        ip_addr = cfg.connection.ip;
    end
    mode = cfg.playback.mode;
    fps = cfg.playback.fps;
    dur_sec = cfg.playback.duration_sec;
    pause_sec = cfg.playback.pause_sec;
    do_sanity = cfg.playback.sanity_check;

    fprintf('IP: %s, Mode: %d, FPS: %d, Duration: %d sec\n', ...
        ip_addr, mode, fps, dur_sec);

    % Build pattern list
    patterns = cfg.patterns;
    num_patterns = length(patterns);

    % Filter by PatIDs if specified
    if ~isempty(pat_id_filter)
        slots = zeros(num_patterns, 1);
        for k = 1:num_patterns
            slots(k) = patterns(k).sd_slot;
        end
        keep = ismember(slots, pat_id_filter);
        patterns = patterns(keep);
        num_patterns = length(patterns);
        fprintf('Testing subset: %d of %d patterns\n', num_patterns, length(cfg.patterns));
    end

    fprintf('\nPatterns to test:\n');
    for k = 1:num_patterns
        pat = patterns(k);
        fprintf('  [SD %2d] %s — %s\n', pat.sd_slot, pat.name, pat.description);
    end
    fprintf('\n');

    %% Dry run — stop here
    if dry_run
        fprintf('DRY RUN — config parsed successfully, %d patterns listed.\n', num_patterns);
        results = struct('config', cfg, 'pat_results', {{}}, 'all_passed', true);
        return;
    end

    %% Connect
    fprintf('Connecting to %s...\n', ip_addr);
    pc = PanelsController(ip_addr);
    pc.open(false);

    if do_sanity
        fprintf('Sanity check: allOn...');
        pc.allOn(); pause(1);
        pc.allOff(); pause(0.5);
        fprintf(' OK\n\n');
    end

    %% Run each pattern
    deciSec = dur_sec * 10;
    pat_results = cell(num_patterns, 1);

    for k = 1:num_patterns
        pat = patterns(k);
        pid = pat.sd_slot;
        fprintf('Test %2d/%2d: [SD %2d] %s\n', k, num_patterns, pid, pat.name);

        try
            success = pc.trialParams(mode, pid, fps, 1, 0, deciSec, true);
            if success
                pat_results{k} = 'PASS';
                fprintf('  PASS (completed %d sec)\n', dur_sec);
            else
                pat_results{k} = 'FAIL (trialParams returned false)';
                fprintf('  FAIL (trialParams returned false)\n');
            end
        catch e
            pat_results{k} = sprintf('ERROR: %s', e.message);
            fprintf('  ERROR: %s\n', e.message);
        end

        if k < num_patterns
            pc.allOff();
            pause(pause_sec);
        end
    end

    %% Cleanup
    pc.allOff();
    pc.close();

    %% Summary
    fprintf('\n=== Results ===\n');
    for k = 1:num_patterns
        pat = patterns(k);
        fprintf('  [SD %2d] %-45s %s\n', pat.sd_slot, pat.name, pat_results{k});
    end

    %% Checklist
    if isfield(cfg, 'checklist')
        fprintf('\n=== Lab Verification Checklist ===\n');
        for k = 1:length(cfg.checklist)
            fprintf('[ ] %s\n', cfg.checklist{k});
        end
    end

    fprintf('\nDone.\n');

    %% Return results
    all_passed = all(cellfun(@(r) strcmp(r, 'PASS'), pat_results));
    results = struct('config', cfg, 'pat_results', {pat_results}, 'all_passed', all_passed);
end

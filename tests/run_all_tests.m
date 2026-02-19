function results = run_all_tests(varargin)
    % RUN_ALL_TESTS - Run all unit tests
    %
    % Usage:
    %   results = run_all_tests()           % Run all tests
    %   results = run_all_tests('verbose')  % Verbose output
    %   results = run_all_tests('coverage') % With code coverage
    %   results = run_all_tests('verbose', 'coverage') % Both
    %
    % Examples:
    %   % Quick run during development
    %   run_all_tests()
    %
    %   % Detailed output to see what's happening
    %   run_all_tests('verbose')
    %
    %   % Generate code coverage report
    %   run_all_tests('coverage')
    %
    % Returns:
    %   results - TestResult array with pass/fail information
    
    import matlab.unittest.TestSuite;
    import matlab.unittest.TestRunner;
    import matlab.unittest.plugins.CodeCoveragePlugin;
    
    % Parse options
    verbose = any(strcmp(varargin, 'verbose'));
    coverage = any(strcmp(varargin, 'coverage'));
    
    % Get the directory containing this script (should be tests/)
    script_dir = fileparts(mfilename('fullpath'));
    
    % Create test suite from all unit test files in tests/unit/
    unit_test_dir = fullfile(script_dir, 'unit');
    if ~isfolder(unit_test_dir)
        error('Unit test directory not found: %s', unit_test_dir);
    end
    
    suite = TestSuite.fromFolder(unit_test_dir);
    
    if isempty(suite)
        warning('No tests found in %s', unit_test_dir);
        results = [];
        return;
    end
    
    % Create runner with appropriate verbosity
    if verbose
        runner = TestRunner.withTextOutput('OutputDetail', 3);
    else
        runner = TestRunner.withTextOutput;
    end
    
    % Add code coverage if requested
    if coverage
        % Get repo root (parent of tests/)
        repo_root = fileparts(script_dir);
        srcFolder = fullfile(repo_root, 'experimentExecution');
        coverageReport = fullfile(repo_root, 'coverage');
        
        if ~isfolder(srcFolder)
            warning('Source folder not found: %s. Skipping coverage.', srcFolder);
        else
            runner.addPlugin(CodeCoveragePlugin.forFolder(srcFolder, ...
                'IncludingSubfolders', true, ...
                'Producing', coverageReport));
        end
    end
    
    % Run tests
    fprintf('=== Running All Unit Tests ===\n\n');
    fprintf('Test suite location: %s\n', unit_test_dir);
    fprintf('Total test files: %d\n\n', length(suite));
    
    results = runner.run(suite);
    
    % Display summary
    fprintf('\n=== TEST SUMMARY ===\n');
    fprintf('Total Tests: %d\n', length(results));
    fprintf('Passed: %d\n', sum([results.Passed]));
    fprintf('Failed: %d\n', sum([results.Failed]));
    fprintf('Incomplete: %d\n', sum([results.Incomplete]));
    fprintf('Duration: %.2f seconds\n', sum([results.Duration]));
    
    if all([results.Passed])
        fprintf('\n✓ ALL TESTS PASSED\n');
    else
        fprintf('\n✗ SOME TESTS FAILED\n');
        
        % List failures
        failed = results(~[results.Passed]);
        fprintf('\nFailed tests:\n');
        for i = 1:length(failed)
            fprintf('  - %s\n', failed(i).Name);
            if isfield(failed(i).Details, 'DiagnosticRecord')
                fprintf('    %s\n', failed(i).Details.DiagnosticRecord.Report);
            else
                fprintf('No diagnostic record.');
            end
        end
    end
    
    if coverage
        fprintf('\nCoverage report generated: %s\n', coverageReport);
        fprintf('Open index.html in that directory to view the report.\n');
    end
    
    fprintf('\n');
end

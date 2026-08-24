function results = test_module3()
% TEST_MODULE3 Runs all unit tests for the RetinaScan Module 3 Segmentation.
%
% This function runs all test suites for RetinaScan segmentation and displays
% a detailed report of the passing status.

    fprintf('============================================================\n');
    fprintf('Running RetinaScan Module 3 Unit Test Suite\n');
    fprintf('============================================================\n\n');

    % Define test files
    testFiles = {
        'test_segment_retina', ...
        'test_segment_vessels', ...
        'test_optic_disc', ...
        'test_lesions', ...
        'test_vessel_analysis'
    };
    
    % Initialize test suite
    suite = [];
    for i = 1:numel(testFiles)
        try
            s = testsuite(testFiles{i});
            suite = [suite, s]; %#ok<AGROW>
        catch ME
            fprintf('Warning: Could not load test file "%s": %s\n', testFiles{i}, ME.message);
        end
    end
    
    if isempty(suite)
        fprintf('Error: No tests could be loaded. Make sure the tests are in the MATLAB path.\n');
        results = [];
        return;
    end
    
    % Run tests
    import matlab.unittest.TestRunner;
    import matlab.unittest.plugins.TextReportPlugin;
    
    runner = TestRunner.withTextOutput();
    results = runner.run(suite);
    
    % Display summary
    fprintf('\n============================================================\n');
    fprintf('TEST SUITE SUMMARY:\n');
    fprintf('============================================================\n');
    numPassed = sum([results.Passed]);
    numFailed = sum([results.Failed]);
    numIncomplete = sum([results.Incomplete]);
    totalTests = numel(results);
    
    fprintf('Total Tests Run:  %d\n', totalTests);
    fprintf('Passed:           %d\n', numPassed);
    fprintf('Failed:           %d\n', numFailed);
    fprintf('Incomplete:       %d\n', numIncomplete);
    fprintf('------------------------------------------------------------\n');
    
    if numFailed == 0
        fprintf('✓ ALL TESTS PASSED SUCCESSFULLY!\n');
    else
        fprintf('❌ SOME TESTS FAILED. PLEASE CHECK DETAILS ABOVE.\n');
    end
    fprintf('============================================================\n');
end

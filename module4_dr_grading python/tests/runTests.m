% runTests.m - Master test runner executing the complete Module 4 test suite.

fprintf('==================================================\n');
fprintf('Running Module 4 DR Grading Test Suite\n');
fprintf('==================================================\n\n');

tests = {'testDataset', 'testModel', 'testOrdinalLoss', 'testInference'};
allPassed = true;

% Cache paths
testPath = fileparts(mfilename('fullpath'));
addpath(testPath);

for k = 1:numel(tests)
    testName = tests{k};
    fprintf('[RUNNING] %s...\n', testName);
    try
        run(testName);
        fprintf('[PASSED]  %s\n\n', testName);
    catch ME
        fprintf('[FAILED]  %s: %s\n\n', testName, ME.message);
        allPassed = false;
    end
end

rmpath(testPath);

fprintf('==================================================\n');
if allPassed
    fprintf('RESULT: All tests PASSED successfully!\n');
else
    fprintf('RESULT: Some tests FAILED. Please review error traces.\n');
    error('Test suite execution failed.');
end
fprintf('==================================================\n');

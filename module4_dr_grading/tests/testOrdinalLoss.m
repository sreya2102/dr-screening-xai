% testOrdinalLoss.m - Unit tests for Consistent Rank Logits (CORAL) loss logic.

% Set up search paths
addpath(fullfile(pwd, 'module4_dr_grading'));
addpath(fullfile(pwd, 'module4_dr_grading', 'src'));
addpath(fullfile(pwd, 'module4_dr_grading', 'src', 'utils'));

try
    % Construct dummy cumulative target distributions and model sigmoids
    % Format: [4 heads, BatchSize of 2]
    predictions = dlarray([0.95, 0.80, 0.20, 0.05; 0.99, 0.95, 0.88, 0.70]', 'CB');
    targets = dlarray([1.0, 1.0, 0.0, 0.0; 1.0, 1.0, 1.0, 1.0]', 'CB');
    
    % Evaluate loss
    loss = coralLoss(predictions, targets);
    
    % Assert scalar properties and finite bounds
    assert(isa(loss, 'dlarray'), 'Loss output must be a dlarray.');
    assert(isscalar(extractdata(loss)), 'Loss must be a scalar value.');
    assert(extractdata(loss) > 0, 'Loss must evaluate to a positive value.');
    assert(~isnan(extractdata(loss)) && ~isinf(extractdata(loss)), 'Loss must be a finite real number.');
    
    fprintf('SUCCESS: testOrdinalLoss passed.\n');
catch ME
    fprintf('FAILURE: testOrdinalLoss failed with error: %s\n', ME.message);
    rethrow(ME);
end

% Clean up paths
rmpath(fullfile(pwd, 'module4_dr_grading'));
rmpath(fullfile(pwd, 'module4_dr_grading', 'src'));
rmpath(fullfile(pwd, 'module4_dr_grading', 'src', 'utils'));

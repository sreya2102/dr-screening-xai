% testDataset.m - Unit tests for data loading and preprocessing contracts.

% Set up search paths
addpath(fullfile(pwd, 'module4_dr_grading'));
addpath(fullfile(pwd, 'module4_dr_grading', 'src'));
addpath(fullfile(pwd, 'module4_dr_grading', 'src', 'utils'));

% Setup dummy directory
dummyFolder = fullfile(pwd, 'data', 'dummy');
if ~exist(dummyFolder, 'dir')
    fprintf('Generating dummy dataset for unit tests...\n');
    generateDummyDataset(dummyFolder, 5);
end

try
    % 1. Test cnn-only Mode Datastore
    [trainDS, valDS, testDS] = prepareDataset(dummyFolder, [224, 224], [0.6, 0.2, 0.2], 'cnn-only');
    
    assert(hasdata(trainDS), 'Train dataset must contain readable items.');
    data = read(trainDS);
    
    % Assert image tensor shape, datatype, and target sizes (should be column vectors)
    assert(isequal(size(data{1}), [224, 224, 3]), 'Resized image dimensions must be 224x224x3.');
    assert(isa(data{1}, 'single'), 'Processed image must be single-precision.');
    assert(isequal(size(data{2}), [4, 1]), 'Target ordinal vector must be a 4x1 column vector.');
    assert(isa(data{2}, 'single'), 'Target vector must be single-precision.');
    
    % 2. Test fusion Mode Datastore
    [trainDS_f, valDS_f, testDS_f] = prepareDataset(dummyFolder, [224, 224], [0.6, 0.2, 0.2], 'fusion');
    assert(hasdata(trainDS_f), 'Fusion train dataset must contain readable items.');
    data_f = read(trainDS_f);
    
    % Assert image, lesions, and targets shapes
    assert(isequal(size(data_f{1}), [224, 224, 3]), 'Fusion image must be 224x224x3.');
    assert(isequal(size(data_f{2}), [8, 1]), 'Fusion lesion features must be an 8x1 column vector.');
    assert(isequal(size(data_f{3}), [4, 1]), 'Fusion targets must be a 4x1 column vector.');
    
    fprintf('SUCCESS: testDataset passed.\n');
catch ME
    fprintf('FAILURE: testDataset failed with error: %s\n', ME.message);
    rethrow(ME);
end

% Clean up paths
rmpath(fullfile(pwd, 'module4_dr_grading'));
rmpath(fullfile(pwd, 'module4_dr_grading', 'src'));
rmpath(fullfile(pwd, 'module4_dr_grading', 'src', 'utils'));

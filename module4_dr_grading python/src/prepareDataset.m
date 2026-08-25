function [trainDS, valDS, testDS] = prepareDataset(dataFolder, targetSize, splitRatios, mode)
% PREPAREDATASET Sets up imageDatastores, performs patient-level splitting 
% to prevent data leakage, applies image preprocessing, and combines them
% with CORAL-encoded ordinal targets and optional clinical features.
%
% Inputs:
%   dataFolder  - Path to the dataset folder
%   targetSize  - Image target dimensions (default: [224, 224])
%   splitRatios - 1x3 vector for train/val/test splits (default: [0.7, 0.15, 0.15])
%   mode         - String: 'cnn-only', 'lesion-only', or 'fusion' (default: 'fusion')
% Outputs:
%   trainDS, valDS, testDS - Combined datastores returning:
%       - 'cnn-only':    {preprocessedImage, cumulativeTarget}
%       - 'lesion-only': {lesionVector, cumulativeTarget}
%       - 'fusion':      {preprocessedImage, lesionVector, cumulativeTarget}

    if nargin < 2 || isempty(targetSize)
        targetSize = [224, 224];
    end
    if nargin < 3 || isempty(splitRatios)
        splitRatios = [0.7, 0.15, 0.15];
    end
    if nargin < 4 || isempty(mode)
        mode = 'fusion';
    end
    
    % Normalize split ratios to sum to 1.0
    splitRatios = splitRatios / sum(splitRatios);

    % Create the base imageDatastore
    imds = imageDatastore(dataFolder, ...
        'IncludeSubfolders', true, ...
        'LabelSource', 'foldernames');
    
    files = imds.Files;
    nFiles = numel(files);
    patientIDs = cell(nFiles, 1);
    
    % Extract patient IDs from filenames to prevent leakage
    for k = 1:nFiles
        patientIDs{k} = getPatientID(files{k});
    end
    
    [uniquePatients, ~, idxMap] = unique(patientIDs);
    nPatients = numel(uniquePatients);
    
    % Deterministic random shuffle of patients
    rng(42);
    shuffledPatients = randperm(nPatients);
    
    % Calculate patient-level splits
    nTrain = round(splitRatios(1) * nPatients);
    nVal = round(splitRatios(2) * nPatients);
    
    trainPatientsIdx = shuffledPatients(1:nTrain);
    valPatientsIdx = shuffledPatients(nTrain+1 : nTrain+nVal);
    testPatientsIdx = shuffledPatients(nTrain+nVal+1 : end);
    
    % Map patient splits back to image indices
    trainIdx = ismember(idxMap, trainPatientsIdx);
    valIdx = ismember(idxMap, valPatientsIdx);
    testIdx = ismember(idxMap, testPatientsIdx);
    
    % Construct individual datastores
    trainImds = subset(imds, trainIdx);
    valImds = subset(imds, valIdx);
    testImds = subset(imds, testIdx);
    
    % Create cumulative CORAL targets for each subset (size N x 4)
    trainTargets = makeCoralTargets(trainImds.Labels);
    valTargets = makeCoralTargets(valImds.Labels);
    testTargets = makeCoralTargets(testImds.Labels);
    
    % Create target arrayDatastores and transpose to [4, 1] column vectors
    trainTargetDS = transform(arrayDatastore(trainTargets), @(t) t');
    valTargetDS = transform(arrayDatastore(valTargets), @(t) t');
    testTargetDS = transform(arrayDatastore(testTargets), @(t) t');
    
    % Assemble datastores based on selected mode
    if strcmp(mode, 'cnn-only')
        % Image-only pipeline
        trainImdsTrans = transform(trainImds, @(img) preprocessImage(img));
        valImdsTrans = transform(valImds, @(img) preprocessImage(img));
        testImdsTrans = transform(testImds, @(img) preprocessImage(img));
        
        trainDS = combine(trainImdsTrans, trainTargetDS);
        valDS = combine(valImdsTrans, valTargetDS);
        testDS = combine(testImdsTrans, testTargetDS);
        
    elseif strcmp(mode, 'lesion-only')
        % Lesion-only pipeline
        trainLesions = makeMockLesions(trainImds.Labels);
        valLesions = makeMockLesions(valImds.Labels);
        testLesions = makeMockLesions(testImds.Labels);
        
        % Create lesion arrayDatastores and transpose to [8, 1] column vectors
        trainLesionDS = transform(arrayDatastore(trainLesions), @(l) l');
        valLesionDS = transform(arrayDatastore(valLesions), @(l) l');
        testLesionDS = transform(arrayDatastore(testLesions), @(l) l');
        
        trainDS = combine(trainLesionDS, trainTargetDS);
        valDS = combine(valLesionDS, valTargetDS);
        testDS = combine(testLesionDS, testTargetDS);
        
    else % 'fusion'
        % Combined dual-stream pipeline
        trainImdsTrans = transform(trainImds, @(img) preprocessImage(img));
        valImdsTrans = transform(valImds, @(img) preprocessImage(img));
        testImdsTrans = transform(testImds, @(img) preprocessImage(img));
        
        trainLesions = makeMockLesions(trainImds.Labels);
        valLesions = makeMockLesions(valImds.Labels);
        testLesions = makeMockLesions(testImds.Labels);
        
        % Create lesion arrayDatastores and transpose to [8, 1] column vectors
        trainLesionDS = transform(arrayDatastore(trainLesions), @(l) l');
        valLesionDS = transform(arrayDatastore(valLesions), @(l) l');
        testLesionDS = transform(arrayDatastore(testLesions), @(l) l');
        
        trainDS = combine(trainImdsTrans, trainLesionDS, trainTargetDS);
        valDS = combine(valImdsTrans, valLesionDS, valTargetDS);
        testDS = combine(testImdsTrans, testLesionDS, testTargetDS);
    end
end

function patientID = getPatientID(filepath)
    % Extracts patient ID from a file path to prevent leakage of bilateral scans
    [~, filename, ~] = fileparts(filepath);
    
    % Pattern 1: Messidor-2 style (e.g., 20051020_43808_0100_PP.png -> 43808)
    tokens = regexp(filename, '^\d+_(\d+)_\d+_PP$', 'tokens');
    if ~isempty(tokens)
        patientID = tokens{1}{1};
        return;
    end
    
    % Pattern 2: Simple prefix split by underscore (e.g., 123_left.png -> 123)
    tokens = regexp(filename, '^([^_]+)_', 'tokens');
    if ~isempty(tokens)
        patientID = tokens{1}{1};
        return;
    end
    
    % Fallback: Treat each image name as a unique patient
    patientID = filename;
end

function targets = makeCoralTargets(labels)
    % Encodes categorical labels into CORAL binary cumulative vectors.
    nImages = numel(labels);
    nClasses = 5;
    targets = zeros(nImages, nClasses - 1, 'single');
    for k = 1:nImages
        grade = double(string(labels(k)));
        if grade > 0
            targets(k, 1:grade) = 1.0;
        end
    end
end

function lesions = makeMockLesions(labels)
    % Generates synthetic lesion feature vectors mapped to ground-truth grades.
    % Injects 10% failure rates to train robust fallback nodes.
    nImages = numel(labels);
    lesions = zeros(nImages, 8, 'single');
    
    % Reset seed locally to ensure reproducibility
    rng(100);
    
    for k = 1:nImages
        grade = double(string(labels(k)));
        v = zeros(1, 8, 'single');
        v(7) = 1.0; % I_avail = 1.0
        v(8) = 0.0; % I_missing = 0.0
        
        switch grade
            case 0
                v(1) = log1p(randi([0, 1])); % Microaneurysms
                v(2) = rand() * 0.01;        % Hemorrhage area
                v(3) = rand() * 0.01;        % Exudate area
                v(4) = 0.5 + rand() * 0.2;   % Vessel density
                v(5) = 0.0;                  % NV score
                v(6) = 0.8 + rand() * 0.2;   % Optic disc distance
            case 1
                v(1) = log1p(randi([1, 5]));
                v(2) = rand() * 0.02;
                v(3) = rand() * 0.01;
                v(4) = 0.5 + rand() * 0.2;
                v(5) = 0.0;
                v(6) = rand() * 0.8;
            case 2
                v(1) = log1p(randi([5, 15]));
                v(2) = rand() * 0.05;
                v(3) = rand() * 0.08;
                v(4) = 0.4 + rand() * 0.2;
                v(5) = 0.0;
                v(6) = rand() * 0.7;
            case 3
                v(1) = log1p(randi([15, 40]));
                v(2) = 0.05 + rand() * 0.15;
                v(3) = 0.08 + rand() * 0.15;
                v(4) = 0.3 + rand() * 0.2;
                v(5) = rand() * 0.05;
                v(6) = rand() * 0.5;
            case 4
                v(1) = log1p(randi([30, 80]));
                v(2) = 0.10 + rand() * 0.25;
                v(3) = 0.10 + rand() * 0.25;
                v(4) = 0.2 + rand() * 0.2;
                v(5) = 0.1 + rand() * 0.4;
                v(6) = rand() * 0.4;
        end
        
        % 10% probability of M3 module failure simulation
        if rand() < 0.10
            v = zeros(1, 8, 'single');
            v(8) = 1.0; % I_missing = 1.0, I_avail = 0.0
        end
        
        lesions(k, :) = v;
    end
end

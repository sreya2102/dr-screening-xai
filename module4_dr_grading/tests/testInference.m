% testInference.m - Integration tests for the main inference, serialization, and explainability contracts.

% Set up search paths
addpath(fullfile(pwd, 'module4_dr_grading'));
addpath(fullfile(pwd, 'module4_dr_grading', 'src'));
addpath(fullfile(pwd, 'module4_dr_grading', 'src', 'utils'));

try
    % 1. Construct a mock model data structure with the custom CoralLayer
    net = buildModel('resnet50', 'fusion');
    
    modelData = struct();
    modelData.net = net;
    modelData.version = 'v1.0.0-test';
    modelData.backbone = 'resnet50';
    modelData.mode = 'fusion';
    modelData.featureSchemaVersion = 'v1.0';
    modelData.inputSize = [224, 224, 3];
    modelData.normalizationStats = struct('mean', [0.485, 0.456, 0.406], 'std', [0.229, 0.224, 0.225]);
    modelData.calibrationParams = struct('temperature', 1.25);
    modelData.referableThreshold = 0.45;
    modelData.classNames = {'Normal', 'Mild', 'Moderate', 'Severe', 'Proliferative'};
    
    % Write the model containing Custom CoralLayer to disk
    modelFile = fullfile(pwd, 'trained_models', 'mock_model_test.mat');
    if ~exist(fullfile(pwd, 'trained_models'), 'dir')
        mkdir(fullfile(pwd, 'trained_models'));
    end
    save(modelFile, 'modelData');

    % 2. Test Serialization & Deserialization
    % Load the model back and verify class definitions resolve correctly
    loadedData = load(modelFile);
    loadedModel = loadedData.modelData;
    assert(isa(loadedModel.net, 'dlnetwork'), 'Deserialized model net must resolve to a dlnetwork.');
    assert(any(strcmp({loadedModel.net.Layers.Name}, 'coral_thresholds')), 'Deserialized network must retain custom CoralLayer.');

    % 3. Create a mock RGB fundus image (uint8)
    img = uint8(randi([0, 255], [300, 400, 3]));

    % 4. Create complete mock Module 3 features
    lesionFeatures = struct();
    lesionFeatures.maCount = 8;
    lesionFeatures.hemorrhageArea = 0.03;
    lesionFeatures.exudateArea = 0.02;
    lesionFeatures.vesselDensity = 0.60;
    lesionFeatures.nvScore = 0.0;
    lesionFeatures.opticDiscDistance = 0.5;
    lesionFeatures.isAvailable = true;

    % Run inference with original and loaded models
    res_orig = gradeDR(img, modelData, lesionFeatures);
    res_loaded = gradeDR(img, modelFile, lesionFeatures);
    
    % Assert predictions match exactly after serialization reload
    assert(res_orig.grade == res_loaded.grade, 'Inference grade must match after model reload.');
    assert(abs(res_orig.confidence - res_loaded.confidence) < 1e-5, 'Inference confidence must match after model reload.');
    assert(islogical(res_loaded.referableDR), 'Referable DR flag must be a logical boolean.');

    % 5. Run inference with missing M3 features (Fallback verification)
    lesionFeaturesMissing = struct('isAvailable', false);
    res_fallback = gradeDR(img, modelFile, lesionFeaturesMissing);
    assert(res_fallback.grade >= 0 && res_fallback.grade <= 4, 'Fallback grading must execute successfully.');
    
    % 6. Test explainability activation and gradient hook
    [res_a, activations] = gradeDR(img, modelFile, lesionFeatures, true);
    assert(isa(activations, 'dlarray'), 'Conv layer activations must be returned as a dlarray.');
    
    % Run gradient hook (getGradCAMGradients)
    dlImage = dlarray(reshape(preprocessImage(img), [224, 224, 3, 1]), 'SSCB');
    dlLesions = dlarray(validateLesionFeatures(lesionFeatures)', 'CB');
    
    % Programmatically identify the target convolutional layer in the visual stream
    targetConvLayer = '';
    for idx = numel(net.Layers):-1:1
        if contains(class(net.Layers(idx)), 'Convolution2DLayer')
            targetConvLayer = net.Layers(idx).Name;
            break;
        end
    end
    
    gradients = getGradCAMGradients(net, dlImage, 3, targetConvLayer, dlLesions);
    assert(isa(gradients, 'dlarray'), 'Grad-CAM gradients output must be a dlarray.');
    assert(~isempty(gradients), 'Computed gradients must be non-empty.');

    % Cleanup testing files
    if exist(modelFile, 'file')
        delete(modelFile);
    end

    fprintf('SUCCESS: testInference passed.\n');
catch ME
    if exist(modelFile, 'file')
        delete(modelFile);
    end
    fprintf('FAILURE: testInference failed with error: %s\n', ME.message);
    rethrow(ME);
end

% Clean up paths
rmpath(fullfile(pwd, 'module4_dr_grading'));
rmpath(fullfile(pwd, 'module4_dr_grading', 'src'));
rmpath(fullfile(pwd, 'module4_dr_grading', 'src', 'utils'));

function [result, activations] = gradeDR(image, modelPath, lesionFeatures, returnActivations)
% GRADEDR Performs Diabetic Retinopathy severity grading from an input 
% fundus image and optional Module 3 lesion features.
%
% Inputs:
%   image             - RGB image (uint8 or double)
%   modelPath         - Either a string path to the saved .mat model file, 
%                       or the loaded modelData struct.
%   lesionFeatures    - Struct containing Module 3 features (optional)
%   returnActivations - Logical flag to request intermediate CNN layer activations (optional)
% Outputs:
%   result            - Struct containing grading predictions and metadata:
%                       .grade (predicted grade 0-4)
%                       .confidence (calibrated confidence of the prediction)
%                       .classProbabilities (1x5 vector of calibrated probabilities)
%                       .referableDR (logical flag indicating referable DR)
%                       .referableProbability (probability of grade >= 2)
%                       .referableThreshold (used threshold tau)
%                       .logits (raw output logits from CORAL layer)
%                       .modelVersion (version string)
%   activations       - dlarray containing the activation maps of the final conv layer

    if nargin < 3
        lesionFeatures = [];
    end
    if nargin < 4
        returnActivations = false;
    end

    % 1. Load the model if a path is provided
    persistent lastModelPath loadedModelData;
    if ischar(modelPath) || isstring(modelPath)
        if isempty(loadedModelData) || ~strcmp(lastModelPath, modelPath)
            if ~exist(modelPath, 'file')
                error('Model file not found: %s', modelPath);
            end
            data = load(modelPath);
            if ~isfield(data, 'modelData')
                error('Invalid model format. Missing modelData field.');
            end
            loadedModelData = data.modelData;
            lastModelPath = modelPath;
        end
        modelData = loadedModelData;
    else
        modelData = modelPath; % Assume struct was passed directly
    end

    net = modelData.net;
    mode = modelData.mode;

    % Add helper paths
    utilsPath = fullfile(pwd, 'module4_dr_grading', 'src', 'utils');
    addpath(utilsPath);

    % 2. Image preprocessing
    preprocessedImg = preprocessImage(image);
    
    % Explicitly convert to 4D single-precision tensor [224, 224, 3, 1] to prevent SSCB shape mismatch
    img4D = reshape(preprocessedImg, [224, 224, 3, 1]);

    % 3. Lesion features preprocessing & availability fallback
    lesionVec = validateLesionFeatures(lesionFeatures);

    % 4. Format inputs as dlarray and move to GPU if available
    executionEnvironment = "cpu";
    if canUseGPU()
        executionEnvironment = "gpu";
    end

    % Define targets for extraction
    targetConvLayer = '';
    if returnActivations
        % Programmatically find the final Convolution2DLayer in the visual backbone
        for idx = numel(net.Layers):-1:1
            layerClass = class(net.Layers(idx));
            if contains(layerClass, 'Convolution2DLayer')
                targetConvLayer = net.Layers(idx).Name;
                break;
            end
        end
    end

    inputNames = net.InputNames;

    % Run forward prediction mapping inputs based on compiled input names order
    if strcmp(mode, 'fusion')
        dlImage = dlarray(img4D, 'SSCB');
        dlLesions = dlarray(lesionVec', 'CB');
        
        if gpuDeviceCount > 0 && strcmp(executionEnvironment, "gpu")
            dlImage = gpuArray(dlImage);
            dlLesions = gpuArray(dlLesions);
        end
        
        % Match network input layers ordering programmatically
        if numel(inputNames) == 2
            if contains(inputNames{1}, 'image') || contains(inputNames{1}, 'input_1')
                firstInput = dlImage;
                secondInput = dlLesions;
            else
                firstInput = dlLesions;
                secondInput = dlImage;
            end
        else
            firstInput = dlImage;
            secondInput = dlLesions;
        end
        
        if returnActivations && ~isempty(targetConvLayer)
            [predictions, activations] = predict(net, firstInput, secondInput, 'Outputs', {'coral_sigmoids', targetConvLayer});
        else
            predictions = predict(net, firstInput, secondInput);
            activations = [];
        end
        
    elseif strcmp(mode, 'cnn-only')
        dlImage = dlarray(img4D, 'SSCB');
        if gpuDeviceCount > 0 && strcmp(executionEnvironment, "gpu")
            dlImage = gpuArray(dlImage);
        end
        
        if returnActivations && ~isempty(targetConvLayer)
            [predictions, activations] = predict(net, dlImage, 'Outputs', {'coral_sigmoids', targetConvLayer});
        else
            predictions = predict(net, dlImage);
            activations = [];
        end
        
    else % 'lesion-only'
        dlLesions = dlarray(lesionVec', 'CB');
        if gpuDeviceCount > 0 && strcmp(executionEnvironment, "gpu")
            dlLesions = gpuArray(dlLesions);
        end
        
        predictions = predict(net, dlLesions);
        activations = [];
    end

    % 5. Gather raw predictions
    probs = double(gather(extractdata(predictions)));

    % 6. Apply Probability Calibration
    % Compute logit: log(p / (1 - p))
    logits = log(probs ./ (1.0 - probs));
    logits = max(-20.0, min(20.0, logits)); % Clip for numerical stability

    if isfield(modelData, 'calibrationParams')
        params = modelData.calibrationParams;
        if isfield(params, 'temperature') && ~isempty(params.temperature)
            % Global temperature scaling: preserves threshold monotonicity
            calibProbs = 1.0 ./ (1.0 + exp(-logits / params.temperature));
        elseif isfield(params, 'a') && isfield(params, 'b') && ~isempty(params.a)
            % Platt scaling per-head
            calibProbs = 1.0 ./ (1.0 + exp(-(params.a .* logits + params.b)));
        else
            calibProbs = probs;
        end
    else
        calibProbs = probs;
    end

    % 7. Reconstruct grade and class probabilities
    [grade, confidence, pClass] = reconstructGrade(calibProbs);

    % 8. Evaluate Referable DR
    referableProbability = calibProbs(2); % P(Grade >= 2)
    referableThreshold = modelData.referableThreshold;
    referableDR = referableProbability >= referableThreshold;

    % 9. Package output results
    result = struct();
    result.grade = double(grade);
    result.confidence = double(confidence);
    result.classProbabilities = double(pClass');
    result.referableDR = logical(referableDR);
    result.referableProbability = double(referableProbability);
    result.referableThreshold = double(referableThreshold);
    result.logits = double(logits');
    result.modelVersion = modelData.version;

    % Clean up workspace path
    rmpath(utilsPath);
end

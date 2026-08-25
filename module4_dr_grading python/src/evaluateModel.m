function [metrics, resultsTable] = evaluateModel(modelPath, testDS)
% EVALUATEMODEL Evaluates the trained model on a test datastore, computing
% standard and clinical grading metrics, including accuracy, macro F1,
% MAE, QWK, referable sensitivity/specificity, ECE, and Brier Score.
%
% Inputs:
%   modelPath - String path to model file OR loaded modelData struct
%   testDS    - Test combined datastore
% Outputs:
%   metrics      - Struct containing scalar performance metrics
%   resultsTable - Table containing individual predictions for downstream analysis

    % 1. Load model metadata
    if ischar(modelPath) || isstring(modelPath)
        data = load(modelPath);
        modelData = data.modelData;
    else
        modelData = modelPath;
    end

    reset(testDS);
    
    trueGrades = [];
    predGrades = [];
    confidences = [];
    classProbsList = [];
    referableProbs = [];
    referableTrue = [];
    referablePred = [];

    % Add src/ path to read gradeDR
    srcPath = fileparts(mfilename('fullpath'));
    addpath(srcPath);
    
    fprintf('Running evaluation on testing dataset...\n');
    while hasNext(testDS)
        data = read(testDS);
        
        % Reconstruct true grade from cumulative binary target
        target = data{end};
        trueGrade = sum(double(target));
        
        % Unpack image and lesion features based on mode
        if strcmp(modelData.mode, 'fusion')
            img = data{1};
            v = data{2};
            
            % Reconstruct lesionFeatures struct to pass to gradeDR
            lesionFeatures = struct();
            lesionFeatures.maCount = expm1(double(v(1)));
            lesionFeatures.hemorrhageArea = double(v(2));
            lesionFeatures.exudateArea = double(v(3));
            lesionFeatures.vesselDensity = double(v(4));
            lesionFeatures.nvScore = double(v(5));
            lesionFeatures.opticDiscDistance = double(v(6));
            lesionFeatures.isAvailable = (v(7) > 0.5);
            
        elseif strcmp(modelData.mode, 'cnn-only')
            img = data{1};
            lesionFeatures = [];
        else % 'lesion-only'
            img = zeros(224, 224, 3, 'uint8'); % Dummy image not used
            v = data{1};
            
            lesionFeatures = struct();
            lesionFeatures.maCount = expm1(double(v(1)));
            lesionFeatures.hemorrhageArea = double(v(2));
            lesionFeatures.exudateArea = double(v(3));
            lesionFeatures.vesselDensity = double(v(4));
            lesionFeatures.nvScore = double(v(5));
            lesionFeatures.opticDiscDistance = double(v(6));
            lesionFeatures.isAvailable = (v(7) > 0.5);
        end
        
        % Run main grading API
        res = gradeDR(img, modelData, lesionFeatures);
        
        % Store predictions
        trueGrades = [trueGrades, trueGrade];
        predGrades = [predGrades, res.grade];
        confidences = [confidences, res.confidence];
        classProbsList = [classProbsList; res.classProbabilities];
        referableProbs = [referableProbs, res.referableProbability];
        referableTrue = [referableTrue, (trueGrade >= 2)];
        referablePred = [referablePred, res.referableDR];
    end
    
    rmpath(srcPath);

    % 2. Calculate core metrics
    % Confusion Matrix
    C = confusionmat(trueGrades, predGrades);
    metrics.ConfusionMatrix = C;
    
    % 5-Class Accuracy
    metrics.Accuracy = sum(diag(C)) / sum(C(:));
    
    % Mean Absolute Error (MAE)
    metrics.MAE = mean(abs(trueGrades - predGrades));
    
    % Quadratic Weighted Kappa (QWK)
    metrics.QWK = computeQWK(C);
    
    % Macro F1-Score
    metrics.MacroF1 = computeMacroF1(C);
    
    % Per-Class Sensitivities and Specificities
    nClasses = size(C, 1);
    perClassSens = zeros(1, nClasses);
    perClassSpec = zeros(1, nClasses);
    for c = 1:nClasses
        tp = C(c, c);
        fn = sum(C(c, :)) - tp;
        fp = sum(C(:, c)) - tp;
        tn = sum(C(:)) - tp - fn - fp;
        
        if (tp + fn) > 0, perClassSens(c) = tp / (tp + fn); else, perClassSens(c) = 0; end
        if (tn + fp) > 0, perClassSpec(c) = tn / (tn + fp); else, perClassSpec(c) = 0; end
    end
    metrics.PerClassSensitivity = perClassSens;
    metrics.PerClassSpecificity = perClassSpec;
    
    % Referable DR metrics (Grade >= 2)
    tp_ref = sum(referableTrue & referablePred);
    fn_ref = sum(referableTrue & ~referablePred);
    fp_ref = sum(~referableTrue & referablePred);
    tn_ref = sum(~referableTrue & ~referablePred);
    
    if (tp_ref + fn_ref) > 0, metrics.ReferableSensitivity = tp_ref / (tp_ref + fn_ref); else, metrics.ReferableSensitivity = 0; end
    if (tn_ref + fp_ref) > 0, metrics.ReferableSpecificity = tn_ref / (tn_ref + fp_ref); else, metrics.ReferableSpecificity = 0; end
    
    % Expected Calibration Error (ECE)
    accuracies = (trueGrades == predGrades);
    metrics.ECE = computeECE(confidences, accuracies, 10);
    
    % Brier Score
    oneHotTargets = zeros(numel(trueGrades), 5);
    for k = 1:numel(trueGrades)
        oneHotTargets(k, trueGrades(k) + 1) = 1.0;
    end
    metrics.BrierScore = mean(sum((classProbsList - oneHotTargets).^2, 2));

    % Compile results table
    resultsTable = table(trueGrades', predGrades', confidences', referableProbs', ...
        'VariableNames', {'TrueGrade', 'PredictedGrade', 'Confidence', 'ReferableProbability'});
end

% ------------------------- Helper Functions -------------------------

function kappa = computeQWK(C)
    % Computes Quadratic Weighted Kappa (QWK) from a confusion matrix.
    n = sum(C(:));
    k = size(C, 1);
    [i, j] = meshgrid(1:k, 1:k);
    
    % Quadratic weight matrix
    W = (i - j).^2 / (k - 1)^2;
    
    % Expected agreement matrix
    rowSum = sum(C, 2);
    colSum = sum(C, 1);
    E = (rowSum * colSum) / n;
    
    % Kappa formula
    kappa = 1.0 - sum(sum(W .* C)) / sum(sum(W .* E));
end

function macroF1 = computeMacroF1(C)
    % Computes Macro-averaged F1 Score.
    nClasses = size(C, 1);
    f1Scores = zeros(1, nClasses);
    for c = 1:nClasses
        tp = C(c, c);
        fp = sum(C(:, c)) - tp;
        fn = sum(C(c, :)) - tp;
        
        precision = tp / (tp + fp + eps);
        recall = tp / (tp + fn + eps);
        
        f1Scores(c) = 2 * (precision * recall) / (precision + recall + eps);
    end
    macroF1 = mean(f1Scores);
end

function ece = computeECE(confidences, accuracies, numBins)
    % Computes Expected Calibration Error (ECE) on predictions.
    n = numel(confidences);
    ece = 0;
    binEdges = linspace(0, 1, numBins + 1);
    
    for b = 1:numBins
        inBin = confidences > binEdges(b) & confidences <= binEdges(b+1);
        binSize = sum(inBin);
        if binSize > 0
            binAcc = mean(accuracies(inBin));
            binConf = mean(confidences(inBin));
            ece = ece + (binSize / n) * abs(binAcc - binConf);
        end
    end
end

function [grade, confidence, pClass] = reconstructGrade(probabilities)
% RECONSTRUCTGRADE Converts cumulative probabilities from the CORAL head 
% into integer severity grades and confidence scores.
%
% Inputs:
%   probabilities - Array of size [4, N] or [1, 4] containing cumulative probabilities
% Outputs:
%   grade       - Row vector of predicted class indices (0 to 4)
%   confidence  - Row vector of confidence scores for the predicted grade
%   pClass      - Matrix of size [5, N] containing mutually exclusive class probabilities

    % Transpose if input is a single row vector of length 4
    if size(probabilities, 1) == 1 && size(probabilities, 2) == 4
        probabilities = probabilities';
    end
    
    [nHeads, nSamples] = size(probabilities);
    grade = zeros(1, nSamples);
    confidence = zeros(1, nSamples);
    pClass = zeros(5, nSamples);
    
    for k = 1:nSamples
        preds = probabilities(:, k);
        
        % Ensure monotonicity by sorting in descending order (Platt scaling safe-guard)
        preds = sort(preds, 'descend');
        
        % Count how many cumulative heads exceed the threshold (0.5)
        predictedGrade = sum(preds >= 0.5);
        grade(k) = predictedGrade;
        
        % Reconstruct 5 mutually exclusive class probabilities
        pClass(1, k) = 1.0 - preds(1);
        pClass(2, k) = preds(1) - preds(2);
        pClass(3, k) = preds(2) - preds(3);
        pClass(4, k) = preds(3) - preds(4);
        pClass(5, k) = preds(4);
        
        % Clamp to zero and normalize for numerical safety
        pClass(:, k) = max(0, pClass(:, k));
        sumProb = sum(pClass(:, k));
        if sumProb > 0
            pClass(:, k) = pClass(:, k) / sumProb;
        else
            pClass(:, k) = [1; 0; 0; 0; 0]; % Fallback default
        end
        
        % Confidence corresponds to the probability of the predicted grade
        confidence(k) = pClass(predictedGrade + 1, k);
    end
end

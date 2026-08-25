function gradients = getGradCAMGradients(net, dlImage, targetClassIndex, targetLayerName, dlLesions)
% GETGRADCAMGRADIENTS Computes gradients of the target class score with respect to 
% the activations of the specified final convolutional layer. Supports both
% single-input (cnn-only) and multi-input (fusion) models.
%
% Inputs:
%   net              - Trained dlnetwork object
%   dlImage          - Preprocessed image dlarray (format 'SSCB')
%   targetClassIndex - Integer (1 to 5) indicating class score to backpropagate
%   targetLayerName  - String containing the target activation layer name
%   dlLesions        - Optional dlarray of size [8, 1] containing clinical features
% Outputs:
%   gradients        - dlarray containing target gradients

    if nargin < 5
        dlLesions = [];
    end

    % Call dlfeval to compute gradients via automatic differentiation
    gradients = dlfeval(@computeGradients, net, dlImage, targetClassIndex, targetLayerName, dlLesions);
end

function grad = computeGradients(net, dlImage, targetClassIndex, targetLayerName, dlLesions)
    inputNames = net.InputNames;
    
    % If the network has two inputs (fusion mode), prepare clinical features
    if numel(inputNames) == 2
        if isempty(dlLesions)
            % Fallback to default missing features indicator vector (size 8x1)
            v = zeros(8, 1, 'single');
            v(8) = 1.0; % I_missing = 1.0
            dlLesions = dlarray(v, 'CB');
            if canUseGPU() && isa(dlImage, 'gpuArray')
                dlLesions = gpuArray(dlLesions);
            end
        end
        
        % Order inputs programmatically based on compiled layer names
        if contains(inputNames{1}, 'image') || contains(inputNames{1}, 'input_1')
            firstInput = dlImage;
            secondInput = dlLesions;
        else
            firstInput = dlLesions;
            secondInput = dlImage;
        end
        [predictions, activations] = forward(net, firstInput, secondInput, 'Outputs', {'coral_sigmoids', targetLayerName});
    else
        % Single input visual stream mode
        [predictions, activations] = forward(net, dlImage, 'Outputs', {'coral_sigmoids', targetLayerName});
    end
    
    % Differentiable vectorized cumulative probability reconstruction
    p = predictions;
    pClass = [1.0 - p(1); p(1:3) - p(2:4); p(4)];
    
    % Target the score of the selected class
    score = pClass(targetClassIndex);
    
    % Compute the gradient of the target class score relative to activation maps
    grad = dlgradient(score, activations);
end

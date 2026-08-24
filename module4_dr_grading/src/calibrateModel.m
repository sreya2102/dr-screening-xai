function calibParams = calibrateModel(net, valDS, mode, method)
% CALIBRATEMODEL Optimizes probability calibration parameters on the validation
% partition. Supports both Global Temperature Scaling (monotonic-preserving)
% and Platt Scaling (head-specific logistic regression).
%
% Inputs:
%   net    - Trained dlnetwork object
%   valDS  - Validation combined datastore
%   mode   - String: 'cnn-only', 'lesion-only', 'fusion' (default: 'fusion')
%   method - String: 'temperature' or 'platt' (default: 'temperature')
% Outputs:
%   calibParams - Struct containing calibration coefficients

    if nargin < 3 || isempty(mode)
        mode = 'fusion';
    end
    if nargin < 4 || isempty(method)
        method = 'temperature';
    end

    fprintf('Collecting validation set logits for calibration...\n');
    [allLogits, allTargets] = collectLogits(net, valDS, mode);
    
    calibParams = struct();
    
    if strcmp(method, 'platt')
        try
            % Platt scaling: fit independent logistic regression models for each sigmoid head
            calibParams.a = zeros(4, 1, 'single');
            calibParams.b = zeros(4, 1, 'single');
            
            for i = 1:4
                y = double(allTargets(i, :))';
                z = double(allLogits(i, :))';
                
                % Fit Binomial Generalized Linear Model
                mdl = fitglm(z, y, 'Distribution', 'binomial', 'Link', 'logit');
                
                calibParams.b(i) = single(mdl.Coefficients.Estimate(1)); % Intercept
                calibParams.a(i) = single(mdl.Coefficients.Estimate(2)); % Slope
            end
            fprintf('Platt scaling calibration completed successfully.\n');
        catch ME
            warning('Platt scaling failed due to missing toolboxes or numerical instability: %s. Falling back to Global Temperature Scaling.', ME.message);
            method = 'temperature';
        end
    end
    
    if strcmp(method, 'temperature')
        % Temperature scaling: search for a global scale T > 0 minimizing BCE
        lossFunc = @(t) computeCalibratedLoss(allLogits, allTargets, t);
        
        % Optimize temperature parameter T within [0.1, 10.0]
        T_opt = fminbnd(lossFunc, 0.1, 10.0);
        
        calibParams.temperature = single(T_opt);
        fprintf('Global Temperature Scaling completed. Optimal T = %.4f\n', T_opt);
    end
end

% ------------------------- Helper Functions -------------------------

function [allLogits, allTargets] = collectLogits(net, valDS, mode)
    % Reads all items in the validation set and returns gathered logits and targets.
    reset(valDS);
    allLogits = [];
    allTargets = [];
    
    executionEnvironment = "cpu";
    if canUseGPU()
        executionEnvironment = "gpu";
    end

    while hasNext(valDS)
        data = read(valDS);
        
        % Unpack datastore batch
        if strcmp(mode, 'fusion')
            X_img = dlarray(data{1}, 'SSCB');
            X_les = dlarray(data{2}', 'CB');
            if gpuDeviceCount > 0 && strcmp(executionEnvironment, "gpu")
                X_img = gpuArray(X_img);
                X_les = gpuArray(X_les);
            end
            predictions = predict(net, X_img, X_les);
            target = data{3};
        elseif strcmp(mode, 'cnn-only')
            X_img = dlarray(data{1}, 'SSCB');
            if gpuDeviceCount > 0 && strcmp(executionEnvironment, "gpu")
                X_img = gpuArray(X_img);
            end
            predictions = predict(net, X_img);
            target = data{2};
        else % 'lesion-only'
            X_les = dlarray(data{1}', 'CB');
            if gpuDeviceCount > 0 && strcmp(executionEnvironment, "gpu")
                X_les = gpuArray(X_les);
            end
            predictions = predict(net, X_les);
            target = data{2};
        end
        
        probs = double(gather(extractdata(predictions)));
        
        % Convert probabilities to logit: log(p / (1-p))
        logits = log(probs ./ (1.0 - probs));
        logits = max(-20.0, min(20.0, logits));
        
        allLogits = [allLogits, logits];
        allTargets = [allTargets, target'];
    end
end

function loss = computeCalibratedLoss(logits, targets, T)
    % Computes BCE loss of logit arrays scaled by temperature T.
    probs = 1.0 ./ (1.0 + exp(-logits / T));
    epsilon = 1e-7;
    probs = min(1.0 - epsilon, max(epsilon, probs));
    bce = - (targets .* log(probs) + (1.0 - targets) .* log(1.0 - probs));
    loss = mean(sum(bce, 1));
end

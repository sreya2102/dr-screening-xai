function [net, info] = trainModel(trainDS, valDS, options)
% TRAINMODEL Trains the CORAL ordinal grading network using a custom 
% dlnetwork training loop with validation loss tracking and model checkpointing.
%
% Inputs:
%   trainDS - Training combined datastore
%   valDS   - Validation combined datastore
%   options - Struct containing hyperparameters:
%             .backboneName ('resnet50', 'efficientnetb0')
%             .mode ('cnn-only', 'lesion-only', 'fusion')
%             .epochs (scalar integer, e.g., 20)
%             .miniBatchSize (scalar integer, e.g., 16)
%             .learningRate (scalar double, e.g., 1e-3)
%             .savePath (string path to save the best model)
% Outputs:
%   net     - Trained dlnetwork
%   info    - Struct containing training and validation loss history

    % Set default options
    if nargin < 3
        options = struct();
    end
    if ~isfield(options, 'backboneName'), options.backboneName = 'resnet50'; end
    if ~isfield(options, 'mode'), options.mode = 'fusion'; end
    if ~isfield(options, 'epochs'), options.epochs = 10; end
    if ~isfield(options, 'miniBatchSize'), options.miniBatchSize = 8; end
    if ~isfield(options, 'learningRate'), options.learningRate = 1e-3; end
    if ~isfield(options, 'savePath')
        srcDir = fileparts(mfilename('fullpath'));
        moduleRoot = fileparts(srcDir);
        options.savePath = fullfile(moduleRoot, 'trained_models', 'dr_grading_model.mat');
    end

    % Ensure save directory exists
    [saveDir, ~, ~] = fileparts(options.savePath);
    if ~exist(saveDir, 'dir') && ~isempty(saveDir)
        mkdir(saveDir);
    end

    % Determine execution environment (GPU/CPU)
    executionEnvironment = "cpu";
    if canUseGPU()
        executionEnvironment = "gpu";
    end
    fprintf('Training on: %s\n', executionEnvironment);

    % 1. Build the network
    net = buildModel(options.backboneName, options.mode);

    % 2. Setup Minibatch Queues for Training and Validation
    if strcmp(options.mode, 'fusion')
        % Inputs: image (SSCB), lesions (BC), targets (BC)
        mbqTrain = minibatchqueue(trainDS, ...
            'MiniBatchSize', options.miniBatchSize, ...
            'MiniBatchFormat', {'SSCB', 'BC', 'BC'}, ...
            'OutputCast', {'single', 'single', 'single'}, ...
            'OutputEnvironment', executionEnvironment);
        
        mbqVal = minibatchqueue(valDS, ...
            'MiniBatchSize', options.miniBatchSize, ...
            'MiniBatchFormat', {'SSCB', 'BC', 'BC'}, ...
            'OutputCast', {'single', 'single', 'single'}, ...
            'OutputEnvironment', executionEnvironment);
            
    elseif strcmp(options.mode, 'cnn-only')
        % Inputs: image (SSCB), targets (BC)
        mbqTrain = minibatchqueue(trainDS, ...
            'MiniBatchSize', options.miniBatchSize, ...
            'MiniBatchFormat', {'SSCB', 'BC'}, ...
            'OutputCast', {'single', 'single'}, ...
            'OutputEnvironment', executionEnvironment);
        
        mbqVal = minibatchqueue(valDS, ...
            'MiniBatchSize', options.miniBatchSize, ...
            'MiniBatchFormat', {'SSCB', 'BC'}, ...
            'OutputCast', {'single', 'single'}, ...
            'OutputEnvironment', executionEnvironment);
            
    else % 'lesion-only'
        % Inputs: lesions (BC), targets (BC)
        mbqTrain = minibatchqueue(trainDS, ...
            'MiniBatchSize', options.miniBatchSize, ...
            'MiniBatchFormat', {'BC', 'BC'}, ...
            'OutputCast', {'single', 'single'}, ...
            'OutputEnvironment', executionEnvironment);
        
        mbqVal = minibatchqueue(valDS, ...
            'MiniBatchSize', options.miniBatchSize, ...
            'MiniBatchFormat', {'BC', 'BC'}, ...
            'OutputCast', {'single', 'single'}, ...
            'OutputEnvironment', executionEnvironment);
    end

    % 3. Initialize Custom Training Hyperparameters
    trailingAvg = [];
    trailingAvgSq = [];
    
    % Track metrics
    trainLossHistory = [];
    valLossHistory = [];
    bestValLoss = Inf;
    
    iteration = 0;
    
    % Import loss helper
    srcDir = fileparts(mfilename('fullpath'));
    coralLossPath = fullfile(srcDir, 'utils');
    addpath(coralLossPath);

    % 4. Custom Training Loop
    fprintf('Starting Custom Training Loop...\n');
    for epoch = 1:options.epochs
        shuffle(mbqTrain);
        
        epochLoss = 0;
        epochSteps = 0;
        
        while hasNext(mbqTrain)
            iteration = iteration + 1;
            epochSteps = epochSteps + 1;
            
            % Read mini-batch variables
            if strcmp(options.mode, 'fusion')
                [X_img, X_les, Y_target] = next(mbqTrain);
                inputs = {X_img, X_les};
            else
                [X_in, Y_target] = next(mbqTrain);
                inputs = {X_in};
            end
            
            % Compute gradients and loss inside dlfeval
            [loss, gradients, state] = dlfeval(@modelGradients, net, inputs, Y_target, options.mode);
            net.State = state;
            
            % Update parameters using Adam
            [net, trailingAvg, trailingAvgSq] = adamupdate(net, gradients, ...
                trailingAvg, trailingAvgSq, iteration, options.learningRate);
            
            lossVal = double(gather(extractdata(loss)));
            epochLoss = epochLoss + lossVal;
        end
        
        % Compute average epoch training loss
        avgTrainLoss = epochLoss / epochSteps;
        trainLossHistory = [trainLossHistory, avgTrainLoss];
        
        % 5. Compute Validation Loss
        valLoss = evaluateValidationLoss(net, mbqVal, options.mode);
        valLossHistory = [valLossHistory, valLoss];
        
        fprintf('Epoch %d/%d - Train Loss: %.4f | Val Loss: %.4f\n', ...
            epoch, options.epochs, avgTrainLoss, valLoss);
        
        % 6. Model Checkpointing (Save best model based on validation loss)
        if valLoss < bestValLoss
            bestValLoss = valLoss;
            
            % Prepare model versioning package
            modelData = struct();
            modelData.net = net;
            modelData.version = 'v1.0.0';
            modelData.backbone = options.backboneName;
            modelData.mode = options.mode;
            modelData.featureSchemaVersion = 'v1.0';
            modelData.inputSize = [224, 224, 3];
            modelData.normalizationStats = struct('mean', [0.485, 0.456, 0.406], 'std', [0.229, 0.224, 0.225]);
            modelData.calibrationParams = struct('temperature', 1.0); % Default prior to calibration
            modelData.referableThreshold = 0.5;                       % Default prior to ROC tuning
            modelData.classNames = {'Normal', 'Mild', 'Moderate', 'Severe', 'Proliferative'};
            modelData.trainingMetadata = struct(...
                'Epochs', options.epochs, ...
                'MiniBatchSize', options.miniBatchSize, ...
                'LearningRate', options.learningRate, ...
                'BestValLoss', bestValLoss, ...
                'Timestamp', datetime('now'));
            
            save(options.savePath, 'modelData');
            fprintf(' -> Saved new best model checkpoint to %s\n', options.savePath);
        end
    end
    
    info.TrainLossHistory = trainLossHistory;
    info.ValLossHistory = valLossHistory;
    
    % Clean up workspace path addition
    rmpath(coralLossPath);
end

% ------------------------- Helper Functions -------------------------

function [loss, gradients, state] = modelGradients(net, inputs, targets, mode)
    % Executes forward pass and evaluates loss gradients for dlfeval.
    if strcmp(mode, 'fusion')
        [predictions, state] = forward(net, inputs{1}, inputs{2});
    else
        [predictions, state] = forward(net, inputs{1});
    end
    
    % Compute Consistent Rank Logits loss
    loss = coralLoss(predictions, targets);
    
    % Calculate gradients of loss with respect to learnable parameters
    gradients = dlgradient(loss, net.Learnables);
end

function valLoss = evaluateValidationLoss(net, mbqVal, mode)
    % Evaluates Consistent Rank Logits loss on the validation dataset.
    shuffle(mbqVal);
    totalLoss = 0;
    steps = 0;
    
    while hasNext(mbqVal)
        steps = steps + 1;
        if strcmp(mode, 'fusion')
            [X_img, X_les, Y_target] = next(mbqVal);
            preds = predict(net, X_img, X_les);
        else
            [X_in, Y_target] = next(mbqVal);
            preds = predict(net, X_in);
        end
        
        batchLoss = coralLoss(preds, Y_target);
        totalLoss = totalLoss + double(gather(extractdata(batchLoss)));
    end
    
    valLoss = totalLoss / steps;
end

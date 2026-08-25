function net = buildModel(backboneName, mode)
% BUILDMODEL Builds a multi-stream fusion network or single-stream baseline 
% network for Consistent Rank Logits (CORAL) ordinal grading in MATLAB.
%
% Inputs:
%   backboneName - String: Name of the CNN backbone ('resnet50', 'efficientnetb0')
%   mode         - String: Network configuration mode ('cnn-only', 'lesion-only', 'fusion')
% Outputs:
%   net          - dlnetwork object

    if nargin < 1 || isempty(backboneName)
        backboneName = 'resnet50';
    end
    if nargin < 2 || isempty(mode)
        mode = 'fusion';
    end

    % Add utils path to locate the custom CoralLayer class
    srcDir = fileparts(mfilename('fullpath'));
    utilsPath = fullfile(srcDir, 'utils');
    addpath(utilsPath);

    % 1. Build Visual Stream Layer Graph
    lgraph = [];
    if strcmp(mode, 'fusion') || strcmp(mode, 'cnn-only')
        try
            if strcmp(backboneName, 'resnet50')
                % Load pre-trained ResNet-50
                netBackbone = resnet50();
                lgraph = layerGraph(netBackbone);
                
                % Remove final fully connected and output layers
                lgraph = removeLayers(lgraph, {'fc1000', 'fc1000_softmax', 'ClassificationLayer_fc1000'});
                
                % Add visual embedding layers (128-D projection)
                visualLayers = [
                    fullyConnectedLayer(128, 'Name', 'fc_visual_embed')
                    reluLayer('Name', 'relu_visual')
                ];
                lgraph = addLayers(lgraph, visualLayers);
                lgraph = connectLayers(lgraph, 'avg_pool', 'fc_visual_embed');
            elseif strcmp(backboneName, 'efficientnetb0')
                % Load pre-trained EfficientNet-B0
                netBackbone = efficientnetb0();
                lgraph = layerGraph(netBackbone);
                
                % Remove classification layer
                lgraph = removeLayers(lgraph, {'efficientnet-b0|model|head|fc', 'efficientnet-b0|model|head|softmax', 'ClassificationLayer_efficientnet-b0|model|head|fc'});
                
                % Add visual embedding layers
                visualLayers = [
                    fullyConnectedLayer(128, 'Name', 'fc_visual_embed')
                    reluLayer('Name', 'relu_visual')
                ];
                lgraph = addLayers(lgraph, visualLayers);
                lgraph = connectLayers(lgraph, 'efficientnet-b0|model|head|global_average_pooling2d', 'fc_visual_embed');
            else
                error('Unsupported backbone: %s', backboneName);
            end
        catch ME
            % Fallback simple custom CNN if backbone is not installed or errors
            warning('Pretrained %s could not be loaded: %s. Falling back to a custom CNN.', backboneName, ME.message);
            visualLayers = [
                imageInputLayer([224 224 3], 'Normalization', 'none', 'Name', 'input_image')
                convolution2dLayer(3, 16, 'Padding', 'same', 'Name', 'conv1')
                reluLayer('Name', 'relu1')
                maxPooling2dLayer(2, 'Stride', 2, 'Name', 'pool1')
                convolution2dLayer(3, 32, 'Padding', 'same', 'Name', 'conv2')
                reluLayer('Name', 'relu2')
                maxPooling2dLayer(2, 'Stride', 2, 'Name', 'pool2')
                globalAveragePooling2dLayer('Name', 'global_pool')
                fullyConnectedLayer(128, 'Name', 'fc_visual_embed')
                reluLayer('Name', 'relu_visual')
            ];
            lgraph = layerGraph(visualLayers);
        end
    end

    % 2. Assemble Fusion or Baseline Streams with custom CORAL layers
    if strcmp(mode, 'fusion')
        % Add clinical lesion features input stream (8-D to 32-D projection)
        clinicalLayers = [
            featureInputLayer(8, 'Name', 'input_lesions')
            fullyConnectedLayer(32, 'Name', 'fc_clinical_embed')
            reluLayer('Name', 'relu_clinical')
        ];
        lgraph = addLayers(lgraph, clinicalLayers);
        
        % Add 1-D feature concatenation layer
        lgraph = addLayers(lgraph, concatenationLayer(1, 2, 'Name', 'concat'));
        
        % Connect streams to concatenation block
        lgraph = connectLayers(lgraph, 'relu_visual', 'concat/in1');
        lgraph = connectLayers(lgraph, 'relu_clinical', 'concat/in2');
        
        % Add CORAL classification head (160-D input)
        outputLayers = [
            fullyConnectedLayer(1, 'BiasLearnRateFactor', 0, 'Name', 'fc_coral_logit')
            CoralLayer('coral_thresholds')
            sigmoidLayer('Name', 'coral_sigmoids')
        ];
        lgraph = addLayers(lgraph, outputLayers);
        lgraph = connectLayers(lgraph, 'concat', 'fc_coral_logit');
        
    elseif strcmp(mode, 'lesion-only')
        % Construct pure clinical dense MLP network with CORAL output layers
        clinicalLayers = [
            featureInputLayer(8, 'Name', 'input_lesions')
            fullyConnectedLayer(32, 'Name', 'fc_clinical_embed')
            reluLayer('Name', 'relu_clinical')
            fullyConnectedLayer(1, 'BiasLearnRateFactor', 0, 'Name', 'fc_coral_logit')
            CoralLayer('coral_thresholds')
            sigmoidLayer('Name', 'coral_sigmoids')
        ];
        lgraph = layerGraph(clinicalLayers);
        
    else % cnn-only
        % Add CORAL head output to visual embedding directly
        outputLayers = [
            fullyConnectedLayer(1, 'BiasLearnRateFactor', 0, 'Name', 'fc_coral_logit')
            CoralLayer('coral_thresholds')
            sigmoidLayer('Name', 'coral_sigmoids')
        ];
        lgraph = addLayers(lgraph, outputLayers);
        lgraph = connectLayers(lgraph, 'relu_visual', 'fc_coral_logit');
    end

    % 3. Compile as dlnetwork
    net = dlnetwork(lgraph);
    
    rmpath(utilsPath);
end

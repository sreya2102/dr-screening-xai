% testModel.m - Unit tests for custom CORAL network architecture layers and shapes.

% Set up search paths
addpath(fullfile(pwd, 'module4_dr_grading'));
addpath(fullfile(pwd, 'module4_dr_grading', 'src'));
addpath(fullfile(pwd, 'module4_dr_grading', 'src', 'utils'));

try
    % 1. Test CNN-Only network compilation and layer verification
    net_cnn = buildModel('resnet50', 'cnn-only');
    assert(isa(net_cnn, 'dlnetwork'), 'Model must compile to a dlnetwork object.');
    
    % Assert the presence and configurations of the shared logit and custom CoralLayer
    layerNames = {net_cnn.Layers.Name};
    assert(any(strcmp(layerNames, 'fc_coral_logit')), 'Network must contain the fc_coral_logit layer.');
    assert(any(strcmp(layerNames, 'coral_thresholds')), 'Network must contain the coral_thresholds layer.');
    assert(any(strcmp(layerNames, 'coral_sigmoids')), 'Network must contain the coral_sigmoids layer.');
    
    % Verify the fc_coral_logit layer has exactly 1 output (shared logit)
    fcLogitIdx = find(strcmp(layerNames, 'fc_coral_logit'));
    fcLayer = net_cnn.Layers(fcLogitIdx);
    assert(fcLayer.OutputSize == 1, 'The ordinal head must project to a single shared scalar logit.');
    assert(fcLayer.BiasLearnable == 0, 'Bias learning must be disabled on the logit projector as CoralLayer handles thresholds.');
    
    % Verify coral_thresholds is of class CoralLayer
    thresholdsIdx = find(strcmp(layerNames, 'coral_thresholds'));
    thresholdLayer = net_cnn.Layers(thresholdsIdx);
    assert(isa(thresholdLayer, 'CoralLayer'), 'coral_thresholds must be an instance of the custom CoralLayer.');

    % 2. Test Fusion model compilation and forward shapes
    net_fusion = buildModel('resnet50', 'fusion');
    assert(isa(net_fusion, 'dlnetwork'), 'Fusion model must compile successfully.');
    
    % Verify input streams and concatenation dimensions
    layerNamesF = {net_fusion.Layers.Name};
    assert(any(strcmp(layerNamesF, 'input_lesions')), 'Fusion network must contain input_lesions layer.');
    assert(any(strcmp(layerNamesF, 'concat')), 'Fusion network must contain concatenation layer.');
    
    % Execute forward pass
    X_img = dlarray(zeros(224, 224, 3, 2, 'single'), 'SSCB');
    X_les = dlarray(zeros(8, 2, 'single'), 'CB');
    
    preds_f = predict(net_fusion, X_img, X_les);
    assert(isequal(size(preds_f), [4, 2]), 'Fusion output shape must be [4, BatchSize] (4 cumulative sigmoids).');
    
    % Verify thresholds are strictly monotonic by construction (not post-sorting)
    % Initialize custom layer parameter and check predict output monotonicity
    cLayer = CoralLayer('test');
    cLayer.Theta = single([1.5; 0.5; -1.0; 2.0]); % random unconstrained parameters
    testInput = dlarray([1.0, 2.0], 'CB');
    outputs = cLayer.predict(testInput);
    
    % Check that output logits decrease monotonically for each sample: Y(1) > Y(2) > Y(3) > Y(4)
    outData = extractdata(outputs);
    for b = 1:2
        assert(outData(1, b) > outData(2, b), 'Logit 1 must be greater than Logit 2.');
        assert(outData(2, b) > outData(3, b), 'Logit 2 must be greater than Logit 3.');
        assert(outData(3, b) > outData(4, b), 'Logit 3 must be greater than Logit 4.');
    end

    fprintf('SUCCESS: testModel passed.\n');
catch ME
    fprintf('FAILURE: testModel failed with error: %s\n', ME.message);
    rethrow(ME);
end

% Clean up paths
rmpath(fullfile(pwd, 'module4_dr_grading'));
rmpath(fullfile(pwd, 'module4_dr_grading', 'src'));
rmpath(fullfile(pwd, 'module4_dr_grading', 'src', 'utils'));

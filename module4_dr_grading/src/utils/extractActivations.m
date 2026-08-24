function activations = extractActivations(net, dlImage, targetLayerName)
% EXTRACTACTIVATIONS Extracts activation maps from a specified layer of the network.
%
% Inputs:
%   net             - dlnetwork object
%   dlImage         - Preprocessed image dlarray (format 'SSCB')
%   targetLayerName - Name of the layer from which to extract activations
% Outputs:
%   activations     - dlarray containing the activation maps of the target layer

    [~, activations] = predict(net, dlImage, 'Outputs', {'coral_sigmoids', targetLayerName});
end

function loss = coralLoss(predictions, targets)
% CORALLOSS Computes the Consistent Rank Logits (CORAL) ordinal loss.
%
% Inputs:
%   predictions - dlarray of size [4, BatchSize] containing predicted cumulative probabilities
%   targets     - dlarray of size [4, BatchSize] containing ground-truth cumulative binary labels
% Outputs:
%   loss        - dlarray scalar representing the Consistent Rank Logits loss

    % Clip predictions to prevent log(0) and numerical instability
    epsilon = 1e-7;
    predClipped = min(1.0 - epsilon, max(epsilon, predictions));

    % Binary Cross Entropy formula
    bce = - (targets .* log(predClipped) + (1.0 - targets) .* log(1.0 - predClipped));

    % Sum over cumulative tasks (first dimension), and take average over batch (second dimension)
    loss = mean(sum(bce, 1));
end

classdef CoralLayer < nnet.layer.Layer
% CORALLAYER Custom layer enforcing consistent rank logits (CORAL).
% Parameterizes thresholds as a cumulative sum of exponentials to ensure
% b_1 <= b_2 <= b_3 <= b_4.
%
% Input shape:  [1, BatchSize] (scalar shared logit)
% Output shape: [4, BatchSize] (logits for the 4 ordinal cumulative tasks)

    properties (Learnable)
        % Unconstrained parameters representing threshold separations
        Theta
    end
    
    methods
        function layer = CoralLayer(name)
            layer.Name = name;
            layer.Description = "CORAL ordinal threshold subtraction layer";
            
            % Initialize the learnable parameter vector (4x1)
            layer.Theta = single([0.0; 0.0; 0.0; 0.0]);
        end
        
        function Y = predict(layer, X)
            % X - shared logit dlarray of size [1, BatchSize]
            % Y - output logits dlarray of size [4, BatchSize]
            
            % Enforce monotonicity: b_i = b_{i-1} + exp(theta_i)
            b = zeros(4, 1, 'like', layer.Theta);
            b(1) = layer.Theta(1);
            for i = 2:4
                b(i) = b(i-1) + exp(layer.Theta(i));
            end
            
            % Broadcast subtraction: X is [1, BatchSize], b is [4, 1]
            % Y(i, batch) = X(1, batch) - b(i)
            Y = X - b;
        end
    end
end

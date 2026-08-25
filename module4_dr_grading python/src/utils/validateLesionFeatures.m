function v = validateLesionFeatures(lesionFeatures)
% VALIDATELESIONFEATURES Validates the lesion feature struct from Module 3,
% normalizes the elements, and outputs an 8-D vector with availability flags.
%
% Inputs:
%   lesionFeatures - Struct containing lesion metrics
% Outputs:
%   v - 1x8 single-precision feature vector:
%       [maCount, hemorrhageArea, exudateArea, vesselDensity, nvScore, opticDiscDistance, I_avail, I_missing]

    % Initialize default feature vector representing missing/unavailable state
    v = zeros(1, 8, 'single');
    v(8) = 1.0; % I_missing = 1.0, I_avail = 0.0

    % Check if input is a valid struct and isAvailable is true
    if nargin > 0 && isstruct(lesionFeatures) && isfield(lesionFeatures, 'isAvailable') && lesionFeatures.isAvailable
        % Set availability indicators
        v(7) = 1.0; % I_avail = 1.0
        v(8) = 0.0; % I_missing = 0.0
        
        % 1. maCount (Count >= 0, normalized with log1p)
        if isfield(lesionFeatures, 'maCount') && ~isempty(lesionFeatures.maCount)
            val = double(lesionFeatures.maCount);
            val = max(0, val);
            v(1) = single(log1p(val));
        end
        
        % 2. hemorrhageArea (Ratio in [0, 1])
        if isfield(lesionFeatures, 'hemorrhageArea') && ~isempty(lesionFeatures.hemorrhageArea)
            val = double(lesionFeatures.hemorrhageArea);
            v(2) = single(min(1.0, max(0.0, val)));
        end
        
        % 3. exudateArea (Ratio in [0, 1])
        if isfield(lesionFeatures, 'exudateArea') && ~isempty(lesionFeatures.exudateArea)
            val = double(lesionFeatures.exudateArea);
            v(3) = single(min(1.0, max(0.0, val)));
        end
        
        % 4. vesselDensity (Ratio in [0, 1])
        if isfield(lesionFeatures, 'vesselDensity') && ~isempty(lesionFeatures.vesselDensity)
            val = double(lesionFeatures.vesselDensity);
            v(4) = single(min(1.0, max(0.0, val)));
        end
        
        % 5. nvScore (Ratio in [0, 1])
        if isfield(lesionFeatures, 'nvScore') && ~isempty(lesionFeatures.nvScore)
            val = double(lesionFeatures.nvScore);
            v(5) = single(min(1.0, max(0.0, val)));
        end
        
        % 6. opticDiscDistance (Ratio in [0, 1])
        if isfield(lesionFeatures, 'opticDiscDistance') && ~isempty(lesionFeatures.opticDiscDistance)
            val = double(lesionFeatures.opticDiscDistance);
            v(6) = single(min(1.0, max(0.0, val)));
        end
    end
end

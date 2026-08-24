function img_clahe = apply_clahe(img_gray, roi_mask, varargin)
% APPLY_CLAHE Performs Contrast-Limited Adaptive Histogram Equalization.
%
%   IMG_CLAHE = APPLY_CLAHE(IMG_GRAY, ROI_MASK)
%   applies CLAHE locally within the retinal Field of View (ROI) mask using
%   conservative contrast parameters to prevent noise over-amplification.
%
%   IMG_CLAHE = APPLY_CLAHE(..., 'ClipLimit', CLIP_LIMIT, 'TileGridSize', TILE_GRID)
%   customizes the contrast limit (default 2.0) and contextual grid (default [8 8]).
%
%   Inputs:
%       img_gray - Input 2D grayscale matrix (uint8 or double)
%       roi_mask - Binary 2D logical mask isolating the retina
%
%   Outputs:
%       img_clahe - Enhanced 2D grayscale matrix of same class as input

    % Parse parameters
    p = inputParser;
    addRequired(p, 'img_gray', @(x) isnumeric(x) && ismatrix(x));
    addRequired(p, 'roi_mask', @(x) islogical(x) && ismatrix(x));
    addParameter(p, 'ClipLimit', 2.0 / 255.0, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'TileGridSize', [8 8], @(x) isnumeric(x) && numel(x) == 2);
    parse(p, img_gray, roi_mask, varargin{:});

    opts = p.Results;

    is_uint8 = isuint8(img_gray);
    if is_uint8
        img_input = img_gray;
        clip_val = opts.ClipLimit;
        if clip_val > 1.0
            clip_val = clip_val / 255.0; % Normalize if user passed uint8 scale
        end
    else
        img_input = uint8(round(max(0.0, min(1.0, img_gray)) * 255.0));
        clip_val = opts.ClipLimit;
        if clip_val > 1.0
            clip_val = clip_val / 255.0;
        end
    end

    % Apply adaptive histogram equalization using adapthisteq
    img_equalized = adapthisteq(img_input, ...
        'ClipLimit', clip_val, ...
        'NumTiles', opts.TileGridSize, ...
        'Distribution', 'uniform', ...
        'Alpha', 0.4);

    % Zero out background outside ROI mask
    img_equalized(~roi_mask) = 0;

    if is_uint8
        img_clahe = img_equalized;
    else
        img_clahe = double(img_equalized) / 255.0;
    end
end

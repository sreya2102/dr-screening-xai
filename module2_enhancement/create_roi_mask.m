function [roi_mask, is_fallback, warning_msg] = create_roi_mask(img_gray, varargin)
% CREATE_ROI_MASK Extracts the retinal Field-of-View (FOV) mask from a fundus image.
%
%   [ROI_MASK, IS_FALLBACK, WARNING_MSG] = CREATE_ROI_MASK(IMG_GRAY)
%   computes a binary logical mask isolating the retinal region from the dark
%   background. If the detected mask covers an implausibly small or large area,
%   a conservative centered circular FOV mask is returned as a fallback.
%
%   [ROI_MASK, IS_FALLBACK, WARNING_MSG] = CREATE_ROI_MASK(..., 'MinCoveragePct', MIN_PCT, ...)
%   allows custom overrides for ROI validity thresholds.
%
%   Outputs:
%       roi_mask    - Logical 2D matrix (true inside retina, false outside)
%       is_fallback - Logical flag (true if geometric circular fallback was used)
%       warning_msg - Diagnostic string if fallback was triggered (empty otherwise)

    % Parse optional parameters
    p = inputParser;
    addRequired(p, 'img_gray', @(x) isnumeric(x) && matrix_is_2d(x));
    addParameter(p, 'MinCoveragePct', 10.0, @(x) isnumeric(x) && x > 0 && x < 100);
    addParameter(p, 'MaxCoveragePct', 95.0, @(x) isnumeric(x) && x > 0 && x <= 100);
    addParameter(p, 'DefaultRadiusPct', 0.45, @(x) isnumeric(x) && x > 0 && x < 0.5);
    addParameter(p, 'ThresholdFactor', 0.05, @(x) isnumeric(x) && x >= 0 && x <= 1);
    parse(p, img_gray, varargin{:});

    opts = p.Results;

    % Ensure uint8 range [0, 255] or double [0, 1]
    if isinteger(img_gray)
        img_norm = double(img_gray) / double(intmax(class(img_gray)));
    else
        img_norm = double(img_gray);
        if max(img_norm(:)) > 1.0
            img_norm = img_norm / 255.0;
        end
    end

    [H, W] = size(img_norm);
    total_pixels = H * W;

    is_fallback = false;
    warning_msg = '';

    % Step 1: Initial intensity thresholding
    threshold_val = max(opts.ThresholdFactor, 0.05 * max(img_norm(:)));
    binary_initial = img_norm > threshold_val;

    % Step 2: Morphological closing to fill intra-retinal gaps
    se_size = max(3, round(0.01 * min(H, W)));
    se = strel('disk', se_size);
    binary_closed = imclose(binary_initial, se);

    % Step 3: Morphological hole filling
    binary_filled = imfill(binary_closed, 'holes');

    % Step 4: Extract largest connected component
    cc = bwconncomp(binary_filled);
    if cc.NumObjects > 0
        numPixels = cellfun(@numel, cc.PixelIdxList);
        [~, maxIdx] = max(numPixels);
        roi_mask = false(H, W);
        roi_mask(cc.PixelIdxList{maxIdx}) = true;
    else
        roi_mask = false(H, W);
    end

    % Step 5: Evaluate coverage and detect degeneracy
    coverage_pct = 100.0 * (sum(roi_mask(:)) / total_pixels);

    if coverage_pct < opts.MinCoveragePct || coverage_pct > opts.MaxCoveragePct
        % Trigger conservative centered circular FOV fallback
        is_fallback = true;
        warning_msg = sprintf('WARNING: Degenerate ROI coverage (%.1f%%). Applied centered circular FOV fallback.', coverage_pct);

        centerY = (H + 1) / 2.0;
        centerX = (W + 1) / 2.0;
        radius = opts.DefaultRadiusPct * min(H, W);

        [X, Y] = meshgrid(1:W, 1:H);
        roi_mask = ((X - centerX).^2 + (Y - centerY).^2) <= radius^2;
    end
end

function tf = matrix_is_2d(m)
    tf = ismatrix(m) && (ndims(m) == 2);
end

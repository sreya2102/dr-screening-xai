function img_enhanced = enhance_structures(img_gray, roi_mask, varargin)
% ENHANCE_STRUCTURES Sequentially applies edge-preserving denoising and controlled sharpening.
%
%   IMG_ENHANCED = ENHANCE_STRUCTURES(IMG_GRAY, ROI_MASK)
%   executes a strict two-step structure enhancement sequence:
%       STEP A: Edge-preserving median denoising (suppresses sensor noise first)
%       STEP B: Controlled unsharp masking (sharpens vessels/lesions safely)
%
%   CRITICAL INVARIANT: DENOISING MUST OCCUR BEFORE SHARPENING.
%   Reversing this sequence amplifies high-frequency noise into false lesion artifacts.
%
%   IMG_ENHANCED = ENHANCE_STRUCTURES(..., 'DenoiseKernelSize', KERNEL, ...)
%   allows custom overrides for filter parameters.
%
%   Inputs:
%       img_gray - Input 2D grayscale matrix (uint8 or double)
%       roi_mask - Binary 2D logical mask isolating the retina
%
%   Outputs:
%       img_enhanced - High-contrast, denoised, sharpened 2D matrix

    % Parse parameters
    p = inputParser;
    addRequired(p, 'img_gray', @(x) isnumeric(x) && ismatrix(x));
    addRequired(p, 'roi_mask', @(x) islogical(x) && ismatrix(x));
    addParameter(p, 'DenoiseKernelSize', [3 3], @(x) isnumeric(x) && numel(x) == 2);
    addParameter(p, 'SharpenAmount', 0.5, @(x) isnumeric(x) && x >= 0 && x <= 2.0);
    addParameter(p, 'SharpenRadius', 1.0, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'SharpenThreshold', 0.05, @(x) isnumeric(x) && x >= 0 && x <= 1.0);
    parse(p, img_gray, roi_mask, varargin{:});

    opts = p.Results;

    is_uint8 = isuint8(img_gray);
    if is_uint8
        img_input = img_gray;
    else
        img_input = uint8(round(max(0.0, min(1.0, img_gray)) * 255.0));
    end

    % ---------------------------------------------------------------------
    % STEP A: Edge-Preserving Denoising (EXECUTES FIRST)
    % ---------------------------------------------------------------------
    % Applies 2D median filtering to suppress high-frequency salt-and-pepper / sensor noise.
    img_denoised = medfilt2(img_input, opts.DenoiseKernelSize, 'symmetric');

    % ---------------------------------------------------------------------
    % STEP B: Controlled Structure Sharpening (EXECUTES SECOND)
    % ---------------------------------------------------------------------
    % Applies unsharp masking to accentuate fine vascular structures, microaneurysms,
    % and lesion boundaries without magnifying background noise.
    img_sharpened = imsharpen(img_denoised, ...
        'Amount', opts.SharpenAmount, ...
        'Radius', opts.SharpenRadius, ...
        'Threshold', opts.SharpenThreshold);

    % Zero out background pixels outside ROI
    img_sharpened(~roi_mask) = 0;

    if is_uint8
        img_enhanced = img_sharpened;
    else
        img_enhanced = double(img_sharpened) / 255.0;
    end
end

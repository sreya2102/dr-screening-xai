function img_corrected = correct_illumination(img, roi_mask, varargin)
% CORRECT_ILLUMINATION Equalizes non-uniform background shading in fundus images.
%
%   IMG_CORRECTED = CORRECT_ILLUMINATION(IMG, ROI_MASK)
%   estimates the low-frequency background illumination within the ROI mask
%   and normalizes spatial shading across the retinal Field of View.
%
%   IMG_CORRECTED = CORRECT_ILLUMINATION(..., 'Sigma', SIGMA, ...)
%   customizes the Gaussian smoothing kernel radius for background estimation.
%
%   Inputs:
%       img      - Input 2D (grayscale) or 3D (RGB) matrix (uint8 or double)
%       roi_mask - Binary 2D logical mask isolating the retina
%
%   Outputs:
%       img_corrected - Shading-equalized image matrix of same type and size

    % Parse parameters
    p = inputParser;
    addRequired(p, 'img', @(x) isnumeric(x));
    addRequired(p, 'roi_mask', @(x) islogical(x) && ismatrix(x));
    addParameter(p, 'Sigma', 30.0, @(x) isnumeric(x) && x > 0);
    parse(p, img, roi_mask, varargin{:});

    opts = p.Results;

    is_uint8 = isuint8(img);
    img_double = double(img);
    if is_uint8
        img_double = img_double / 255.0;
    end

    [H, W, C] = size(img_double);
    img_corrected = zeros(H, W, C);

    % Create Gaussian kernel for background illumination estimation
    kernel_size = 2 * ceil(2 * opts.Sigma) + 1;
    h_gauss = fspecial('gaussian', [kernel_size, kernel_size], opts.Sigma);

    for c = 1:C
        channel = img_double(:, :, c);

        % Background estimation via spatial Gaussian filtering
        % Fill outside ROI with mean ROI intensity to prevent edge bleed
        roi_pixels = channel(roi_mask);
        if isempty(roi_pixels)
            mean_val = 0.5;
        else
            mean_val = mean(roi_pixels);
        end

        channel_padded = channel;
        channel_padded(~roi_mask) = mean_val;

        bg_estimated = imfilter(channel_padded, h_gauss, 'replicate');

        % Subtractive illumination correction with mean offset preservation
        corrected_c = channel_padded - bg_estimated + mean_val;

        % Clip values to valid range [0, 1]
        corrected_c = max(0.0, min(1.0, corrected_c));

        % Zero out background outside ROI
        corrected_c(~roi_mask) = 0.0;

        img_corrected(:, :, c) = corrected_c;
    end

    % Convert back to uint8 if input was uint8
    if is_uint8
        img_corrected = uint8(round(img_corrected * 255.0));
    end
end

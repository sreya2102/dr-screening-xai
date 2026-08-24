function [enhanced_image, green_channel, metadata] = enhance_image(input_image, varargin)
% ENHANCE_IMAGE Primary entry point for Module 2: Image Enhancement.
%
%   [ENHANCED_IMAGE, GREEN_CHANNEL, METADATA] = ENHANCE_IMAGE(INPUT_IMAGE)
%   processes a raw or quality-checked retinal fundus image (matrix or filepath)
%   and returns a structure-preserved, contrast-enhanced RGB image, a high-contrast
%   grayscale Green channel image, and a structured metadata diagnostic record.
%
%   [ENHANCED_IMAGE, GREEN_CHANNEL, METADATA] = ENHANCE_IMAGE(..., 'ClipLimit', 2.0, ...)
%   allows custom overrides for enhancement parameters.
%
%   Outputs:
%       enhanced_image - uint8 (H x W x 3) enhanced RGB image for DR Grading & XAI
%       green_channel  - uint8 (H x W) enhanced grayscale image for Segmentation
%       metadata       - struct containing execution diagnostics and parameters

    tStart = tic;

    % Initialize default metadata
    metadata = struct();
    metadata.status = 'SUCCESS';
    metadata.input_dimensions = [0, 0, 0];
    metadata.output_dimensions = [0, 0, 0];
    metadata.roi_coverage_pct = 0.0;
    metadata.roi_fallback_used = false;
    metadata.techniques_applied = {};
    metadata.parameters = struct();
    metadata.execution_time_ms = 0.0;
    metadata.warnings = {};
    metadata.channel_info = struct('color_space', 'RGB', 'primary_channel', 'Green');

    % Parse optional input arguments
    p = inputParser;
    addRequired(p, 'input_image');
    addParameter(p, 'RoiMinCoveragePct', 10.0, @isnumeric);
    addParameter(p, 'RoiMaxCoveragePct', 95.0, @isnumeric);
    addParameter(p, 'IllumSigma', 30.0, @isnumeric);
    addParameter(p, 'ClaheClipLimit', 2.0, @isnumeric);
    addParameter(p, 'ClaheTileGrid', [8 8], @isnumeric);
    addParameter(p, 'DenoiseKernelSize', [3 3], @isnumeric);
    addParameter(p, 'SharpenAmount', 0.5, @isnumeric);
    addParameter(p, 'SharpenRadius', 1.0, @isnumeric);
    addParameter(p, 'SharpenThreshold', 0.05, @isnumeric);
    parse(p, input_image, varargin{:});

    opts = p.Results;
    metadata.parameters = opts;

    try
        % -----------------------------------------------------------------
        % STAGE 1: Input Validation & Image Reading
        % -----------------------------------------------------------------
        if ischar(input_image) || isstring(input_image)
            if ~exist(input_image, 'file')
                error('Module2:FileNotFound', 'Input image file not found: %s', input_image);
            end
            img_data = imread(input_image);
        elseif isnumeric(input_image) || islogical(input_image)
            img_data = input_image;
        else
            error('Module2:InvalidInput', 'Input must be an image matrix or valid file path.');
        end

        if isempty(img_data) || sum(img_data(:)) == 0
            error('Module2:EmptyImage', 'Input image is empty or all-zero.');
        end

        % Convert logical to uint8 if needed
        if islogical(img_data)
            img_data = uint8(img_data) * 255;
        end

        % Standardize input to uint8
        if ~isuint8(img_data)
            if max(img_data(:)) <= 1.0
                img_data = uint8(round(img_data * 255.0));
            else
                img_data = uint8(round(img_data));
            end
        end

        [H, W, C] = size(img_data);
        metadata.input_dimensions = [H, W, C];

        if C == 1
            % Replicate single channel to 3D for uniform color processing
            img_rgb = cat(3, img_data, img_data, img_data);
            metadata.warnings{end+1} = 'Input is grayscale 1-channel image; expanded to 3-channel RGB.';
        elseif C == 3
            img_rgb = img_data;
        else
            error('Module2:UnsupportedChannels', 'Unsupported number of image channels: %d', C);
        end

        % -----------------------------------------------------------------
        % STAGE 2: Retinal Field ROI Masking & Fallback Check
        % -----------------------------------------------------------------
        green_raw = img_rgb(:, :, 2);
        [roi_mask, is_fallback, roi_warn] = create_roi_mask(green_raw, ...
            'MinCoveragePct', opts.RoiMinCoveragePct, ...
            'MaxCoveragePct', opts.RoiMaxCoveragePct);

        metadata.roi_coverage_pct = 100.0 * (sum(roi_mask(:)) / (H * W));
        metadata.roi_fallback_used = is_fallback;

        if is_fallback
            metadata.status = 'WARNING';
            metadata.warnings{end+1} = roi_warn;
        end
        metadata.techniques_applied{end+1} = 'ROI_Masking';

        % -----------------------------------------------------------------
        % STAGE 3: Illumination Correction (Shading Equalization)
        % -----------------------------------------------------------------
        img_illum = correct_illumination(img_rgb, roi_mask, 'Sigma', opts.IllumSigma);
        metadata.techniques_applied{end+1} = 'Illumination_Correction';

        % -----------------------------------------------------------------
        % STAGE 4: Green Channel Isolation & Contrast Enhancement (CLAHE)
        % -----------------------------------------------------------------
        green_illum = img_illum(:, :, 2);
        green_clahe = apply_clahe(green_illum, roi_mask, ...
            'ClipLimit', opts.ClaheClipLimit, ...
            'TileGridSize', opts.ClaheTileGrid);
        metadata.techniques_applied{end+1} = 'CLAHE';

        % -----------------------------------------------------------------
        % STAGE 5: Structure Enhancement (Step A: Denoise -> Step B: Sharpen)
        % -----------------------------------------------------------------
        green_enhanced = enhance_structures(green_clahe, roi_mask, ...
            'DenoiseKernelSize', opts.DenoiseKernelSize, ...
            'SharpenAmount', opts.SharpenAmount, ...
            'SharpenRadius', opts.SharpenRadius, ...
            'SharpenThreshold', opts.SharpenThreshold);
        metadata.techniques_applied{end+1} = 'StepA_MedianDenoise';
        metadata.techniques_applied{end+1} = 'StepB_UnsharpSharpen';

        green_channel = green_enhanced;

        % -----------------------------------------------------------------
        % STAGE 6: RGB Output Reconstruction
        % -----------------------------------------------------------------
        % Reconstruct RGB by modulating original color channel ratios with enhanced luminance
        enhanced_rgb = zeros(H, W, 3, 'uint8');

        % Normalize green enhancement ratio
        green_base = double(green_illum) + 1.0;
        enhancement_ratio = double(green_enhanced) ./ green_base;

        for c = 1:3
            channel_c = double(img_illum(:, :, c));
            channel_enhanced = channel_c .* enhancement_ratio;
            channel_enhanced(~roi_mask) = 0;
            enhanced_rgb(:, :, c) = uint8(round(max(0.0, min(255.0, channel_enhanced))));
        end

        enhanced_image = enhanced_rgb;
        metadata.output_dimensions = size(enhanced_image);

    catch ME
        % Handle unexpected execution failures safely
        metadata.status = 'FAILED';
        metadata.warnings{end+1} = sprintf('ERROR: %s', ME.message);

        % Fallback outputs to prevent crash
        if exist('img_data', 'var') && ~isempty(img_data)
            enhanced_image = img_data;
            if size(img_data, 3) == 3
                green_channel = img_data(:, :, 2);
            else
                green_channel = img_data;
            end
        else
            enhanced_image = zeros(512, 512, 3, 'uint8');
            green_channel = zeros(512, 512, 'uint8');
        end
    end

    metadata.execution_time_ms = toc(tStart) * 1000.0;
end

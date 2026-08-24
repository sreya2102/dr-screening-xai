function [qualityResult, fovMask] = assess_image_quality(inputImage, config)
% ASSESS_IMAGE_QUALITY Evaluates retinal fundus image quality.
%
% Inputs:
%   inputImage - Image array (M x N x 3 or M x N) OR file path string
%   config     - (Optional) Custom threshold configuration struct.
%                If omitted, default_iqa_config() is used.
%
% Outputs:
%   qualityResult - Struct containing quality classification and details:
%                   .status           : 'Good', 'Borderline', or 'Reject'
%                   .quality_score    : Composite quality score (0.0 to 1.0)
%                   .is_acceptable    : Boolean (true for Good/Borderline, false for Reject)
%                   .metrics          : Detailed struct of computed metrics
%                   .rejection_reason : Cell array of warning/rejection descriptions
%   fovMask       - Binary logical mask of retinal FOV ROI.

    % Load config if not provided
    if nargin < 2 || isempty(config)
        config = default_iqa_config();
    end
    
    % Initialize output struct
    qualityResult = struct();
    reasons = {};
    
    % Read image if input is a filepath string
    if ischar(inputImage) || isstring(inputImage)
        if ~exist(inputImage, 'file')
            qualityResult.status           = 'Reject';
            qualityResult.quality_score    = 0.0;
            qualityResult.is_acceptable    = false;
            qualityResult.metrics          = struct('sharpness',0,'contrast',0,'brightness',0,'fov_coverage',0,'uniformity',999);
            qualityResult.rejection_reason = {'File not found'};
            fovMask                        = false(100, 100);
            return;
        end
        img = imread(inputImage);
    else
        img = inputImage;
    end
    
    % Step 1: Extract Retinal Field of View (FOV) Mask
    fovMask = extract_fov_mask(img);
    
    % Step 2: Compute Quantitative Quality Metrics
    metrics = compute_iqa_metrics(img, fovMask);
    qualityResult.metrics = metrics;
    
    % Step 3: Rule-based Decision Tree & Defect Identification
    hasRejectTrigger = false;
    hasBorderlineTrigger = false;
    
    % Check FOV Coverage
    if metrics.fov_coverage < config.fov_ratio_reject_thresh
        hasRejectTrigger = true;
        reasons{end+1} = sprintf('Invalid/Missing Retinal FOV (Coverage: %.2f < %.2f)', ...
            metrics.fov_coverage, config.fov_ratio_reject_thresh);
    elseif metrics.fov_coverage < config.fov_ratio_good_thresh
        hasBorderlineTrigger = true;
        reasons{end+1} = sprintf('Partial FOV Framing (Coverage: %.2f)', metrics.fov_coverage);
    end
    
    % Check Sharpness (Defocus Blur)
    if metrics.sharpness < config.sharpness_reject_thresh
        hasRejectTrigger = true;
        reasons{end+1} = sprintf('Severe Defocus Blur (Sharpness: %.1f < %.1f)', ...
            metrics.sharpness, config.sharpness_reject_thresh);
    elseif metrics.sharpness < config.sharpness_good_thresh
        hasBorderlineTrigger = true;
        reasons{end+1} = sprintf('Mild Image Blur (Sharpness: %.1f)', metrics.sharpness);
    end
    
    % Check Contrast
    if metrics.contrast < config.contrast_reject_thresh
        hasRejectTrigger = true;
        reasons{end+1} = sprintf('Severe Low Contrast (Contrast: %.1f < %.1f)', ...
            metrics.contrast, config.contrast_reject_thresh);
    elseif metrics.contrast < config.contrast_good_thresh
        hasBorderlineTrigger = true;
        reasons{end+1} = sprintf('Sub-optimal Contrast (Contrast: %.1f)', metrics.contrast);
    end
    
    % Check Brightness / Exposure Bounds
    if metrics.brightness < config.brightness_min_reject
        hasRejectTrigger = true;
        reasons{end+1} = sprintf('Severe Underexposure (Brightness: %.1f < %.1f)', ...
            metrics.brightness, config.brightness_min_reject);
    elseif metrics.brightness > config.brightness_max_reject
        hasRejectTrigger = true;
        reasons{end+1} = sprintf('Severe Overexposure/Glare (Brightness: %.1f > %.1f)', ...
            metrics.brightness, config.brightness_max_reject);
    elseif metrics.brightness < config.brightness_min_good
        hasBorderlineTrigger = true;
        reasons{end+1} = sprintf('Mild Underexposure (Brightness: %.1f)', metrics.brightness);
    elseif metrics.brightness > config.brightness_max_good
        hasBorderlineTrigger = true;
        reasons{end+1} = sprintf('Mild Overexposure (Brightness: %.1f)', metrics.brightness);
    end
    
    % Check Illumination Uniformity
    if metrics.uniformity > config.uniformity_max_reject
        hasRejectTrigger = true;
        reasons{end+1} = sprintf('Severe Illumination Gradient (Uniformity std: %.1f > %.1f)', ...
            metrics.uniformity, config.uniformity_max_reject);
    elseif metrics.uniformity > config.uniformity_max_borderline
        hasBorderlineTrigger = true;
        reasons{end+1} = sprintf('Uneven Illumination (Uniformity std: %.1f)', metrics.uniformity);
    end
    
    % Step 4: Compute Normalized Composite Quality Score (0.0 to 1.0)
    scoreSharpness  = min(1.0, metrics.sharpness / config.sharpness_good_thresh);
    scoreContrast   = min(1.0, metrics.contrast / config.contrast_good_thresh);
    scoreFov        = min(1.0, metrics.fov_coverage / config.fov_ratio_good_thresh);
    
    % Brightness score peaked around ideal intensity (120)
    idealBrightness = 120.0;
    maxBrightDev    = 100.0;
    brightDev       = abs(metrics.brightness - idealBrightness);
    scoreBrightness = max(0.0, 1.0 - (brightDev / maxBrightDev));
    
    compositeScore = (config.weight_sharpness  * scoreSharpness)  + ...
                     (config.weight_contrast   * scoreContrast)   + ...
                     (config.weight_brightness * scoreBrightness) + ...
                     (config.weight_fov        * scoreFov);
                 
    qualityResult.quality_score = min(1.0, max(0.0, compositeScore));
    
    % Step 5: Final Classification Assignment
    if hasRejectTrigger
        qualityResult.status        = 'Reject';
        qualityResult.is_acceptable = false;
    elseif hasBorderlineTrigger
        qualityResult.status        = 'Borderline';
        qualityResult.is_acceptable = true;
    else
        qualityResult.status        = 'Good';
        qualityResult.is_acceptable = true;
    end
    
    if isempty(reasons)
        qualityResult.rejection_reason = {'Image quality meets all optimal standards'};
    else
        qualityResult.rejection_reason = reasons;
    end
end

function metrics = compute_iqa_metrics(img, fovMask)
% COMPUTE_IQA_METRICS Computes individual Image Quality Assessment (IQA) metrics.
%
% Inputs:
%   img     - RGB image (M x N x 3) or Grayscale image (M x N)
%   fovMask - Logical binary matrix (M x N) indicating fundus ROI
%
% Outputs:
%   metrics - Struct containing quantitative image quality scores:
%             .sharpness     (Laplacian variance inside FOV)
%             .contrast      (RMS contrast standard deviation inside FOV)
%             .brightness    (Mean pixel intensity inside FOV)
%             .fov_coverage  (Ratio of fundus ROI area to total image area)
%             .uniformity    (Quadrant mean intensity standard deviation)

    metrics = struct();
    
    [rows, cols, numChannels] = size(img);
    totalPixels = rows * cols;
    
    % Ensure image is double in range [0, 255]
    imgDouble = double(img);
    if max(imgDouble(:)) <= 1.0 && max(imgDouble(:)) > 0
        imgDouble = imgDouble * 255.0;
    end
    
    % Use Green channel for sharpness/contrast/brightness if RGB
    % Green channel provides best contrast for retinal vascular structure
    if numChannels == 3
        evalChannel = imgDouble(:,:,2); % Green channel
    else
        evalChannel = imgDouble;
    end
    
    % 1. FOV Coverage Ratio
    fovPixels = sum(fovMask(:));
    if fovPixels == 0
        metrics.fov_coverage = 0.0;
        metrics.sharpness    = 0.0;
        metrics.contrast     = 0.0;
        metrics.brightness   = 0.0;
        metrics.uniformity   = 999.0; % High variance indicates poor uniformity
        return;
    end
    
    metrics.fov_coverage = fovPixels / totalPixels;
    
    % Extract valid ROI pixels
    roiPixels = evalChannel(fovMask);
    
    % 2. Brightness (Mean intensity inside FOV ROI)
    metrics.brightness = mean(roiPixels);
    
    % 3. Contrast (RMS contrast = standard deviation of ROI pixels)
    metrics.contrast = std(roiPixels);
    
    % 4. Sharpness (Variance of Laplacian operator inside FOV ROI)
    laplacianKernel = [0 1 0; 1 -4 1; 0 1 0];
    laplacianResponse = imfilter(evalChannel, laplacianKernel, 'replicate');
    roiLaplacian = laplacianResponse(fovMask);
    metrics.sharpness = var(roiLaplacian);
    
    % 5. Illumination Uniformity across 4 Quadrants
    midR = floor(rows / 2);
    midC = floor(cols / 2);
    
    q1_mask = fovMask(1:midR, 1:midC);
    q2_mask = fovMask(1:midR, (midC+1):end);
    q3_mask = fovMask((midR+1):end, 1:midC);
    q4_mask = fovMask((midR+1):end, (midC+1):end);
    
    q1_img = evalChannel(1:midR, 1:midC);
    q2_img = evalChannel(1:midR, (midC+1):end);
    q3_img = evalChannel((midR+1):end, 1:midC);
    q4_img = evalChannel((midR+1):end, (midC+1):end);
    
    qMeans = [];
    if any(q1_mask(:)), qMeans(end+1) = mean(q1_img(q1_mask)); end
    if any(q2_mask(:)), qMeans(end+1) = mean(q2_img(q2_mask)); end
    if any(q3_mask(:)), qMeans(end+1) = mean(q3_img(q3_mask)); end
    if any(q4_mask(:)), qMeans(end+1) = mean(q4_img(q4_mask)); end
    
    if length(qMeans) >= 2
        metrics.uniformity = std(qMeans);
    else
        metrics.uniformity = 0.0;
    end
end

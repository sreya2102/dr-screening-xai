function [vesselMask, vesselSkeleton, features] = segment_vessels(enhancedImg, options)
% SEGMENT_VESSELS Segments retinal blood vessels from enhanced fundus images.
%
% Syntax:
%   [vesselMask, vesselSkeleton, features] = segment_vessels(enhancedImg, options)
%
% Inputs:
%   enhancedImg - RGB or grayscale retinal fundus image (uint8)
%   options     - Configuration struct with fields:
%                   .vesselSensitivity - Threshold sensitivity (0 to 1, default 0.5)
%                   .roiMask           - Retinal Field of View mask (logical)
%
% Outputs:
%   vesselMask     - Binary vessel segmentation mask (logical)
%   vesselSkeleton - Binary vessel skeleton (logical)
%   features       - Struct containing vessel metrics:
%                      .vesselDensity
%                      .vesselPixelCount
%                      .skeletonLength

    % Input validation & parameter setup
    if nargin < 2
        options = struct();
    end
    if ~isfield(options, 'vesselSensitivity') || isempty(options.vesselSensitivity)
        options.vesselSensitivity = 0.5;
    end
    
    % Ensure grayscale / green channel extraction
    if size(enhancedImg, 3) == 3
        % Extract green channel (highest contrast for retinal vessels)
        greenChannel = enhancedImg(:, :, 2);
    else
        greenChannel = enhancedImg;
    end
    
    % Convert to double for numerical computations
    I = double(greenChannel) / 255.0;
    
    % FOV mask estimation if not provided
    if isfield(options, 'roiMask') && ~isempty(options.roiMask)
        roiMask = options.roiMask;
    else
        % Estimate FOV mask from green channel using thresholding and morphology
        baseMask = greenChannel > 10;
        baseMask = imfill(baseMask, 'holes');
        se = strel('disk', 10);
        roiMask = imerode(baseMask, se);
    end
    
    % Step 1: Preprocessing & Background normalization
    % Subtract background to remove illumination gradients
    se_bg = strel('disk', 30);
    I_bg = imopen(I, se_bg);
    I_sub = I - I_bg;
    
    % Contrast enhancement on the vessel-enhanced image
    I_sub = (I_sub - min(I_sub(:))) / (max(I_sub(:)) - min(I_sub(:)) + eps);
    I_enhanced = adapthisteq(I_sub, 'ClipLimit', 0.01, 'NumTiles', [8 8]);
    
    % Denoise with a mild bilateral/Gaussian filter
    I_filtered = imgaussfilt(I_enhanced, 0.8);
    
    % Step 2: Multi-Scale Hessian-based Frangi Vesselness Filter
    scales = [1.0, 1.5, 2.5];
    vesselness = zeros(size(I_filtered));
    
    beta = 0.5;
    c = 0.05; % Sensitivity parameter for background noise
    
    for s = scales
        % Compute smoothed derivatives at scale s
        sig = s;
        % Gaussian kernel sizes
        kSize = ceil(3 * sig) * 2 + 1;
        % Generate coordinate grid
        [X, Y] = meshgrid(-(kSize-1)/2:(kSize-1)/2, -(kSize-1)/2:(kSize-1)/2);
        
        % Gaussian derivatives
        G = exp(-(X.^2 + Y.^2) / (2 * sig^2));
        G = G / sum(G(:));
        
        Dxx = (X.^2 / sig^4 - 1/sig^2) .* G;
        Dyy = (Y.^2 / sig^4 - 1/sig^2) .* G;
        Dxy = (X.*Y / sig^4) .* G;
        
        % Convolve with image
        Ixx = imfilter(I_filtered, Dxx, 'replicate');
        Iyy = imfilter(I_filtered, Dyy, 'replicate');
        Ixy = imfilter(I_filtered, Dxy, 'replicate');
        
        % Scale normalization (Lindeberg)
        Ixx = (sig^2) * Ixx;
        Iyy = (sig^2) * Iyy;
        Ixy = (sig^2) * Ixy;
        
        % Compute eigenvalues of the Hessian matrix at each pixel
        response = zeros(size(I_filtered));
        for r = 1:size(I_filtered, 1)
            for col = 1:size(I_filtered, 2)
                if ~roiMask(r, col)
                    continue;
                end
                H = [Ixx(r, col), Ixy(r, col); Ixy(r, col), Iyy(r, col)];
                [V, D] = eig(H);
                eigvals = diag(D);
                
                % Sort by absolute value: |l1| <= |l2|
                [~, idx] = sort(abs(eigvals));
                l1 = eigvals(idx(1));
                l2 = eigvals(idx(2));
                
                % For dark vessels on a bright background (green channel),
                % vessels have positive eigenvalues when inverting, or negative
                % in raw. Since we didn't invert, dark structures on light
                % background have l2 > 0.
                if l2 > 0
                    % Brightness ratio (blobness)
                    Rb = abs(l1) / (abs(l2) + eps);
                    % Second-order structuredness
                    S = sqrt(l1^2 + l2^2);
                    
                    % Vesselness measure
                    v = exp(-Rb^2 / (2 * beta^2)) * (1 - exp(-S^2 / (2 * c^2)));
                    response(r, col) = v;
                end
            end
        end
        
        % Keep maximum response across scales
        vesselness = max(vesselness, response);
    end
    
    % Step 3: Thresholding & Morphological Cleaning
    % Normalize vesselness to [0, 1]
    vesselness = (vesselness - min(vesselness(:))) / (max(vesselness(:)) - min(vesselness(:)) + eps);
    vesselness(~roiMask) = 0;
    
    % Base threshold dependent on options.vesselSensitivity
    % Sensitivity range 0 to 1, higher sensitivity -> lower threshold (more vessels)
    baseThreshold = 0.15 + (1 - options.vesselSensitivity) * 0.15;
    
    % Combine global and local thresholding
    vesselMask = vesselness > baseThreshold;
    
    % Apply local adaptive thresholding to pick up smaller capillaries
    localThresh = imbinarize(vesselness, 'adaptive', 'Sensitivity', options.vesselSensitivity * 0.6);
    vesselMask = vesselMask | (localThresh & (vesselness > 0.05));
    
    % Apply ROI mask to clean up borders
    vesselMask = vesselMask & roiMask;
    
    % Remove tiny noise components (less than 30 pixels)
    vesselMask = bwareaopen(vesselMask, 30);
    
    % Smooth boundaries using morphological opening and closing
    vesselMask = imclose(vesselMask, strel('disk', 1));
    
    % Step 4: Skeletonization
    if exist('bwskel', 'file')
        vesselSkeleton = bwskel(vesselMask);
    else
        vesselSkeleton = bwmorph(vesselMask, 'skel', Inf);
    end
    vesselSkeleton = vesselSkeleton & roiMask;
    
    % Compute quantitative outputs
    vesselPixelCount = sum(vesselMask(:));
    totalRoiPixels = sum(roiMask(:));
    vesselDensity = double(vesselPixelCount) / double(totalRoiPixels);
    skeletonLength = double(sum(vesselSkeleton(:)));
    
    features = struct();
    features.vesselDensity = vesselDensity;
    features.vesselPixelCount = vesselPixelCount;
    features.skeletonLength = skeletonLength;
end

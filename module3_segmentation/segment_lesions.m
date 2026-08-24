function [exudateMask, microaneurysmMask, hemorrhageMask, lesionCombinedMask, features] = segment_lesions(enhancedImg, opticDiscMask, vesselMask, options)
% SEGMENT_LESIONS Segments hard/soft exudates, microaneurysms, and hemorrhages.
%
% Syntax:
%   [exudateMask, microaneurysmMask, hemorrhageMask, lesionCombinedMask, features] = segment_lesions(enhancedImg, opticDiscMask, vesselMask, options)
%
% Inputs:
%   enhancedImg    - RGB or grayscale retinal fundus image (uint8)
%   opticDiscMask  - Logical binary mask of the optic disc
%   vesselMask     - Logical binary mask of retinal vessels
%   options        - Struct with options (.roiMask, .enableLesions)
%
% Outputs:
%   exudateMask        - Logical binary mask of exudate candidates
%   microaneurysmMask   - Logical binary mask of microaneurysm candidates
%   hemorrhageMask     - Logical binary mask of hemorrhage candidates
%   lesionCombinedMask - Combined logical mask of all three lesions
%   features           - Struct with counts and areas:
%                          .exudateCount, .exudateArea
%                          .microaneurysmCount, .microaneurysmArea
%                          .hemorrhageCount, .hemorrhageArea

    [H, W, C] = size(enhancedImg);
    
    % Default outputs
    exudateMask = false(H, W);
    microaneurysmMask = false(H, W);
    hemorrhageMask = false(H, W);
    lesionCombinedMask = false(H, W);
    
    features = struct(...
        'exudateCount', 0, 'exudateArea', 0, ...
        'microaneurysmCount', 0, 'microaneurysmArea', 0, ...
        'hemorrhageCount', 0, 'hemorrhageArea', 0);
        
    if nargin < 4
        options = struct();
    end
    if ~isfield(options, 'enableLesions') || isempty(options.enableLesions)
        options.enableLesions = true;
    end
    if ~options.enableLesions
        return;
    end
    
    % Set up ROI mask
    if isfield(options, 'roiMask') && ~isempty(options.roiMask)
        roiMask = options.roiMask;
    else
        if C == 3
            gray = enhancedImg(:, :, 2);
        else
            gray = enhancedImg;
        end
        roiMask = gray > 15;
        roiMask = imfill(roiMask, 'holes');
        roiMask = imerode(roiMask, strel('disk', 10));
    end
    
    % Ensure correct channels
    if C == 3
        green = double(enhancedImg(:, :, 2)) / 255.0;
        red = double(enhancedImg(:, :, 1)) / 255.0;
    else
        green = double(enhancedImg) / 255.0;
        red = green;
    end
    
    % Denoise channels for lesion detection
    greenFiltered = imgaussfilt(green, 1.0);
    
    % Remove optic disc region to avoid massive false positives (both for bright disc and disc margins)
    se_disc_expand = strel('disk', 15);
    expandedDiscMask = imdilate(opticDiscMask, se_disc_expand);
    lesionRoi = roiMask & ~expandedDiscMask;
    
    %% 1. EXUDATE DETECTION (Bright Lesions)
    % Exudates are bright yellow/white lesions. They are highly visible in both green and red channels.
    % Use morphological top-hat to isolate small bright structures
    se_exudate = strel('disk', 12);
    tophatExudate = imtophat(greenFiltered, se_exudate);
    tophatExudate(~lesionRoi) = 0;
    
    % Adaptive thresholding of top-hat image
    exudateThresh = mean(tophatExudate(lesionRoi)) + 2.5 * std(tophatExudate(lesionRoi));
    exudateCandidates = tophatExudate > exudateThresh;
    
    % Filter Candidates based on size, solidity, and intensity
    cc_ex = bwconncomp(exudateCandidates);
    ex_stats = regionprops(cc_ex, 'Area', 'Solidity');
    
    for i = 1:cc_ex.NumObjects
        s = ex_stats(i);
        % Hard exudates are usually solid and range from small to medium sizes
        if s.Area >= 4 && s.Area <= 800 && s.Solidity > 0.5
            exudateMask(cc_ex.PixelIdxList{i}) = true;
        end
    end
    
    %% 2. MICROANEURYSM (MA) DETECTION (Small Dark Blobs)
    % MAs are small circular dark red spots. They show strong contrast in the green channel.
    % We must subtract vessels to avoid false positives along vessel edges.
    se_vessel_expand = strel('disk', 2);
    expandedVesselMask = imdilate(vesselMask, se_vessel_expand);
    maRoi = lesionRoi & ~expandedVesselMask;
    
    % Bottom-hat morphological filter extracts dark structures
    se_ma = strel('disk', 5);
    bothatMA = imbothat(greenFiltered, se_ma);
    bothatMA(~maRoi) = 0;
    
    % Multi-scale Laplacian of Gaussian (LoG) blob detector to highlight circular dark spots
    % We filter bottom-hat response with LoG kernels of different scales
    sigmas = [1.0, 1.5, 2.0];
    logResponse = zeros(size(green));
    for sig = sigmas
        % Define Gaussian kernel
        kSize = ceil(3 * sig) * 2 + 1;
        [X, Y] = meshgrid(-(kSize-1)/2:(kSize-1)/2, -(kSize-1)/2:(kSize-1)/2);
        % LoG equation
        LoG = -1 / (pi * sig^4) * (1 - (X.^2 + Y.^2) / (2 * sig^2)) .* exp(-(X.^2 + Y.^2) / (2 * sig^2));
        LoG = LoG - mean(LoG(:)); % zero-mean normalization
        
        response = imfilter(bothatMA, LoG, 'replicate');
        logResponse = max(logResponse, response);
    end
    
    % Threshold the blob-enhanced map
    logResponse(~maRoi) = 0;
    maThresh = mean(logResponse(maRoi)) + 3.0 * std(logResponse(maRoi));
    maCandidates = logResponse > maThresh;
    
    % Filter candidates based on circularity, size, and eccentricity
    cc_ma = bwconncomp(maCandidates);
    ma_stats = regionprops(cc_ma, 'Area', 'Eccentricity', 'Solidity');
    
    for i = 1:cc_ma.NumObjects
        s = ma_stats(i);
        % MAs must be very small and circular
        if s.Area >= 1 && s.Area <= 25 && s.Eccentricity < 0.85
            microaneurysmMask(cc_ma.PixelIdxList{i}) = true;
        end
    end
    
    %% 3. HEMORRHAGE (HE) DETECTION (Larger Dark Pools)
    % Hemorrhages are larger, irregular dark spots.
    % Bottom-hat filter with a larger structuring element
    se_he = strel('disk', 15);
    bothatHE = imbothat(greenFiltered, se_he);
    bothatHE(~maRoi) = 0;
    
    heThresh = mean(bothatHE(maRoi)) + 2.0 * std(bothatHE(maRoi));
    heCandidates = bothatHE > heThresh;
    
    % Filter connected components based on size and aspect ratio
    cc_he = bwconncomp(heCandidates);
    he_stats = regionprops(cc_he, 'Area', 'Solidity', 'Eccentricity');
    
    for i = 1:cc_he.NumObjects
        s = he_stats(i);
        % Hemorrhages are larger than microaneurysms and don't necessarily have to be circular
        if s.Area > 25 && s.Area <= 1500 && s.Solidity > 0.45
            hemorrhageMask(cc_he.PixelIdxList{i}) = true;
        end
    end
    
    % Ensure no overlap between lesions (exudate vs dark lesions)
    microaneurysmMask = microaneurysmMask & ~exudateMask;
    hemorrhageMask = hemorrhageMask & ~exudateMask & ~microaneurysmMask;
    
    % Combined mask
    lesionCombinedMask = exudateMask | microaneurysmMask | hemorrhageMask;
    
    % Calculate quantitative metrics
    % Exudates
    cc_final_ex = bwconncomp(exudateMask);
    exudateCount = cc_final_ex.NumObjects;
    exudateArea = sum(exudateMask(:));
    
    % Microaneurysms
    cc_final_ma = bwconncomp(microaneurysmMask);
    maCount = cc_final_ma.NumObjects;
    maArea = sum(microaneurysmMask(:));
    
    % Hemorrhages
    cc_final_he = bwconncomp(hemorrhageMask);
    heCount = cc_final_he.NumObjects;
    heArea = sum(hemorrhageMask(:));
    
    features = struct();
    features.exudateCount = exudateCount;
    features.exudateArea = double(exudateArea);
    features.microaneurysmCount = maCount;
    features.microaneurysmArea = double(maArea);
    features.hemorrhageCount = heCount;
    features.hemorrhageArea = double(heArea);
end

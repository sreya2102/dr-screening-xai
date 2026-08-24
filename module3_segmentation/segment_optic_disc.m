function [opticDiscMask, opticCupMask, opticDiscCenter, opticDiscRadius, confidence, discCupFeatures] = segment_optic_disc(enhancedImg, options)
% SEGMENT_OPTIC_DISC Segments the optic disc and optic cup, calculating cup-to-disc ratio (CDR).
%
% Syntax:
%   [opticDiscMask, opticCupMask, opticDiscCenter, opticDiscRadius, confidence, discCupFeatures] = segment_optic_disc(enhancedImg, options)
%
% Inputs:
%   enhancedImg - RGB or grayscale retinal fundus image (uint8)
%   options     - Configuration struct with fields:
%                   .roiMask - Retinal Field of View mask (logical)
%
% Outputs:
%   opticDiscMask    - Binary mask of the optic disc (logical)
%   opticCupMask     - Binary mask of the optic cup (logical)
%   opticDiscCenter  - Centroid coordinates [x, y] of the optic disc
%   opticDiscRadius  - Estimated radius of the optic disc
%   confidence       - Scalar confidence value [0.1 to 1.0]
%   discCupFeatures  - Struct with area metrics and CDR

    if nargin < 2
        options = struct();
    end

    [H, W, C] = size(enhancedImg);
    
    % Get ROI mask
    if isfield(options, 'roiMask') && ~isempty(options.roiMask)
        roiMask = options.roiMask;
    else
        % Estimate ROI mask
        if C == 3
            gray = enhancedImg(:, :, 2);
        else
            gray = enhancedImg;
        end
        roiMask = gray > 15;
        roiMask = imfill(roiMask, 'holes');
        roiMask = imerode(roiMask, strel('disk', 10));
    end
    
    % Extract channels
    if C == 3
        % Red channel has highest intensity for optic disc structure
        discChannel = double(enhancedImg(:, :, 1)) / 255.0;
        % Green channel is also useful to verify boundaries
        greenChannel = double(enhancedImg(:, :, 2)) / 255.0;
    else
        discChannel = double(enhancedImg) / 255.0;
        greenChannel = discChannel;
    end
    
    % Step 1: Pre-filter to smooth out vessels
    se_vessels = strel('disk', 5);
    discChannelFiltered = imclose(discChannel, se_vessels);
    discChannelFiltered = imgaussfilt(discChannelFiltered, 2);
    
    % Step 2: Brightness-based search & candidate generation
    % Optic disc is typically in the brightest 5% of the retinal mask
    roiPixels = discChannelFiltered(roiMask);
    if isempty(roiPixels)
        % Default fallback if ROI is empty
        opticDiscMask = false(H, W);
        opticCupMask = false(H, W);
        opticDiscCenter = [W/2, H/2];
        opticDiscRadius = min(H, W) * 0.1;
        confidence = 0.1;
        discCupFeatures = struct('opticDiscArea', 0, 'opticCupArea', 0, 'cupToDiscRatio', 0);
        return;
    end
    
    brightThreshold = prctile(roiPixels, 95);
    brightRegions = (discChannelFiltered > brightThreshold) & roiMask;
    
    % Morphological cleaning of bright regions
    brightRegions = imopen(brightRegions, strel('disk', 3));
    
    % Analyze connected components of bright regions
    cc = bwconncomp(brightRegions);
    stats = regionprops(cc, 'Area', 'Centroid', 'Solidity', 'Eccentricity', 'EquivDiameter');
    
    bestCandidateIdx = 0;
    bestScore = -1;
    
    % Expected optic disc radius in pixels (approx 5% to 15% of retina width)
    expectedRadiusMin = min(H, W) * 0.04;
    expectedRadiusMax = min(H, W) * 0.15;
    
    for i = 1:numel(stats)
        s = stats(i);
        radius = s.EquivDiameter / 2;
        
        % Filter out extremely small or large components
        if radius < expectedRadiusMin || radius > expectedRadiusMax
            continue;
        end
        
        % Calculate circularity/solidity score
        % Solidity represents how dense the shape is. Disc should be highly solid.
        solidity = s.Solidity;
        
        % Brightness score: average intensity of component
        mask_comp = false(H, W);
        mask_comp(cc.PixelIdxList{i}) = true;
        avgBrightness = mean(discChannelFiltered(mask_comp));
        
        % Anatomical score: distance from boundary
        % Retinal disc is usually located nasal (away from temporal/fovea), not on the extreme edge
        distFromCenter = sqrt((s.Centroid(1) - W/2)^2 + (s.Centroid(2) - H/2)^2);
        maxDist = sqrt((W/2)^2 + (H/2)^2);
        edgePenalty = 1.0 - (distFromCenter / maxDist); % Prefer non-edge regions
        
        % Combine metrics into candidate score
        score = avgBrightness * solidity * edgePenalty * (1.0 - s.Eccentricity);
        
        if score > bestScore
            bestScore = score;
            bestCandidateIdx = i;
        end
    end
    
    % Fallback circle finding using imfindcircles if connected components failed
    useHough = false;
    if bestCandidateIdx == 0
        rRange = [round(expectedRadiusMin), round(expectedRadiusMax)];
        [centers, radii, metric] = imfindcircles(enhancedImg, rRange, 'Sensitivity', 0.85, 'ObjectPolarity', 'bright');
        
        % Find centers within the ROI mask
        validIdx = [];
        for idx = 1:size(centers, 1)
            cx = round(centers(idx, 1));
            cy = round(centers(idx, 2));
            if cx > 0 && cx <= W && cy > 0 && cy <= H && roiMask(cy, cx)
                validIdx(end+1) = idx; %#ok<AGROW>
            end
        end
        
        if ~isempty(validIdx)
            useHough = true;
            % Select top Hough circle
            bestIdx = validIdx(1);
            opticDiscCenter = centers(bestIdx, :);
            opticDiscRadius = radii(bestIdx);
            confidence = metric(bestIdx) * 0.8; % Slightly lower confidence for Hough fallback
        end
    end
    
    if bestCandidateIdx > 0 && ~useHough
        s = stats(bestCandidateIdx);
        opticDiscCenter = s.Centroid;
        opticDiscRadius = s.EquivDiameter / 2;
        confidence = bestScore;
    elseif bestCandidateIdx == 0 && ~useHough
        % Absolute fallback: center of the image/ROI
        [yCoords, xCoords] = find(roiMask);
        if ~isempty(yCoords)
            opticDiscCenter = [mean(xCoords), mean(yCoords)];
        else
            opticDiscCenter = [W/2, H/2];
        end
        opticDiscRadius = min(H, W) * 0.08;
        confidence = 0.1;
    end
    
    % Step 3: Refine Optic Disc Mask using localized Active Contour/Thresholding
    % Create a circular base mask at the detected center and radius
    [X, Y] = meshgrid(1:W, 1:H);
    discCircleMask = ((X - opticDiscCenter(1)).^2 + (Y - opticDiscCenter(2)).^2) <= (opticDiscRadius^2);
    discCircleMask = discCircleMask & roiMask;
    
    % Smooth boundaries to get final disc mask
    % Local threshold inside a bounding box around the center
    boundingBox = [max(1, round(opticDiscCenter(1) - opticDiscRadius*1.5)), ...
                   max(1, round(opticDiscCenter(2) - opticDiscRadius*1.5)), ...
                   min(W - 1, round(opticDiscRadius*3.0)), ...
                   min(H - 1, round(opticDiscRadius*3.0))];
               
    croppedDisc = discChannelFiltered(boundingBox(2):boundingBox(2)+boundingBox(4), ...
                                      boundingBox(1):boundingBox(1)+boundingBox(3));
    croppedMask = discCircleMask(boundingBox(2):boundingBox(2)+boundingBox(4), ...
                                 boundingBox(1):boundingBox(1)+boundingBox(3));
                             
    % Refine locally using otsu or localized thresholding
    if ~isempty(croppedDisc)
        localLevel = graythresh(croppedDisc(croppedMask));
        localMask = (croppedDisc > (localLevel * 0.9)) & croppedMask;
        
        % Insert refined local mask back
        opticDiscMask = false(H, W);
        opticDiscMask(boundingBox(2):boundingBox(2)+boundingBox(4), ...
                      boundingBox(1):boundingBox(1)+boundingBox(3)) = localMask;
        
        % Clean up the refined mask
        opticDiscMask = imfill(opticDiscMask, 'holes');
        opticDiscMask = bwareaopen(opticDiscMask, 100);
        opticDiscMask = opticDiscMask & roiMask;
    else
        opticDiscMask = discCircleMask;
    end
    
    % If refined mask is empty, fallback to circular mask
    if sum(opticDiscMask(:)) == 0
        opticDiscMask = discCircleMask;
    end
    
    % Step 4: Segment Optic Cup inside the Optic Disc region
    % The cup is the highly pale/brightest central region within the disc.
    opticCupMask = false(H, W);
    if sum(opticDiscMask(:)) > 0
        discPixels = greenChannel(opticDiscMask);
        if ~isempty(discPixels)
            % Cup threshold is higher than average disc intensity
            cupThresh = mean(discPixels) + 0.3 * std(discPixels);
            rawCupMask = (greenChannel > cupThresh) & opticDiscMask;
            
            % Restrict to central area of disc to avoid border artifacts
            se_erode = strel('disk', round(opticDiscRadius * 0.1));
            discEroded = imerode(opticDiscMask, se_erode);
            rawCupMask = rawCupMask & discEroded;
            
            % Find connected components and keep the largest one inside the disc
            cc_cup = bwconncomp(rawCupMask);
            if cc_cup.NumObjects > 0
                cupSizes = cellfun(@numel, cc_cup.PixelIdxList);
                [~, largestCupIdx] = max(cupSizes);
                
                % Ensure the cup is a reasonable size compared to the disc
                if cupSizes(largestCupIdx) > 20
                    opticCupMask(cc_cup.PixelIdxList{largestCupIdx}) = true;
                    opticCupMask = imfill(opticCupMask, 'holes');
                end
            end
        end
    end
    
    % Ensure cup is strictly a subset of disc
    opticCupMask = opticCupMask & opticDiscMask;
    
    % Step 5: Calculate Areas and Cup-to-Disc Ratio (CDR)
    opticDiscArea = sum(opticDiscMask(:));
    opticCupArea = sum(opticCupMask(:));
    
    if opticDiscArea > 0
        % Area-based cup-to-disc ratio (standard research surrogate)
        cupToDiscRatio = sqrt(double(opticCupArea) / double(opticDiscArea));
    else
        cupToDiscRatio = 0.0;
    end
    
    % Cap confidence between 0.1 and 1.0
    confidence = min(1.0, max(0.1, confidence));
    
    % Populate features structure
    discCupFeatures = struct();
    discCupFeatures.opticDiscArea = double(opticDiscArea);
    discCupFeatures.opticCupArea = double(opticCupArea);
    discCupFeatures.cupToDiscRatio = double(cupToDiscRatio);
    discCupFeatures.confidence = double(confidence);
end

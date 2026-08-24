function [foveaMask, foveaX, foveaY, foveaConfidence] = segment_fovea(enhancedImg, opticDiscCenter, opticDiscRadius, roiMask)
% SEGMENT_FOVEA Estimates the fovea location based on anatomical geometry relative to the optic disc.
%
% Syntax:
%   [foveaMask, foveaX, foveaY, foveaConfidence] = segment_fovea(enhancedImg, opticDiscCenter, opticDiscRadius, roiMask)
%
% Inputs:
%   enhancedImg      - RGB or grayscale fundus image (uint8)
%   opticDiscCenter  - Coordinates [x, y] of the optic disc center
%   opticDiscRadius  - Estimated radius of the optic disc
%   roiMask          - Retinal Field of View mask (logical)
%
% Outputs:
%   foveaMask       - Logical binary mask identifying the estimated fovea region
%   foveaX, foveaY  - Estimated coordinates of the fovea
%   foveaConfidence - Double scalar representing localization confidence

    % Check inputs
    [H, W, C] = size(enhancedImg);
    if nargin < 4 || isempty(roiMask)
        roiMask = true(H, W);
    end

    % Anatomical geometry: Fovea is temporal to the optic disc.
    % In fundus images, the optic disc is located nasally and the fovea is located temporally.
    % 1. Determine eye side (Left Eye OS vs Right Eye OD):
    % If the optic disc center is in the right half of the image, the eye is OS (Left Eye),
    % and temporal (fovea) is to the left of the optic disc.
    % If the optic disc center is in the left half of the image, the eye is OD (Right Eye),
    % and temporal (fovea) is to the right of the optic disc.
    
    odX = opticDiscCenter(1);
    odY = opticDiscCenter(2);
    
    % Fovea is located at approximately 2.5 disc diameters (5 disc radii) temporally from the disc center
    temporalOffset = 5.0 * opticDiscRadius;
    
    % Slightly below the horizontal axis of the optic disc (approx 0.2 * disc radius downward in image coords)
    verticalOffset = 0.2 * opticDiscRadius;
    
    if odX > W / 2
        % Left Eye (OS): Temporal is to the left of the disc
        estFoveaX = odX - temporalOffset;
    else
        % Right Eye (OD): Temporal is to the right of the disc
        estFoveaX = odX + temporalOffset;
    end
    
    estFoveaY = odY + verticalOffset;
    
    % Verify estimated fovea is within image boundaries and ROI mask
    estFoveaX = max(1, min(W, estFoveaX));
    estFoveaY = max(1, min(H, estFoveaY));
    
    % Refinement: Fovea is a dark, avascular circular spot.
    % Search in a local neighborhood (1.0 disc radius) around the estimated point for the darkest intensity
    searchRadius = round(opticDiscRadius * 1.0);
    xRange = max(1, round(estFoveaX - searchRadius)):min(W, round(estFoveaX + searchRadius));
    yRange = max(1, round(estFoveaY - searchRadius)):min(H, round(estFoveaY + searchRadius));
    
    % Default localization if search fails
    foveaX = estFoveaX;
    foveaY = estFoveaY;
    foveaConfidence = 0.5; % Geometry estimation confidence
    
    if ~isempty(xRange) && ~isempty(yRange)
        % Extract green channel (highest contrast for macula / fovea region)
        if C == 3
            maculaRegion = double(enhancedImg(yRange, xRange, 2)) / 255.0;
        else
            maculaRegion = double(enhancedImg(yRange, xRange)) / 255.0;
        end
        
        % Smooth to ignore small vessel noise
        maculaSmoothed = imgaussfilt(maculaRegion, 3);
        
        % Find the darkest local minimum inside the ROI mask
        localRoi = roiMask(yRange, xRange);
        maculaSmoothed(~localRoi) = Inf; % Ignore non-retina pixels
        
        [minVal, minIdx] = min(maculaSmoothed(:));
        if ~isinf(minVal)
            [localY, localX] = ind2sub(size(maculaSmoothed), minIdx);
            
            % Refined coordinates
            refinedX = xRange(localX);
            refinedY = yRange(localY);
            
            % Update fovea coordinate
            foveaX = refinedX;
            foveaY = refinedY;
            foveaConfidence = 0.75; % Higher confidence with local intensity matching
        end
    end
    
    % Verify final coordinate lies inside the ROI mask
    foveaX = round(foveaX);
    foveaY = round(foveaY);
    if foveaX <= 0 || foveaX > W || foveaY <= 0 || foveaY > H || ~roiMask(foveaY, foveaX)
        % Revert to base geometry estimate
        foveaX = round(estFoveaX);
        foveaY = round(estFoveaY);
        foveaConfidence = 0.3;
    end
    
    % Create estimated fovea mask (a circle of 0.25 optic disc radius around the centroid)
    foveaRadius = max(5, round(opticDiscRadius * 0.25));
    [X, Y] = meshgrid(1:W, 1:H);
    foveaMask = ((X - foveaX).^2 + (Y - foveaY).^2) <= (foveaRadius^2);
    foveaMask = foveaMask & roiMask;
    
    % Print explanation details as required by specification
    fprintf('Estimated fovea location: [%d, %d]\n', foveaX, foveaY);
    disp('Fovea position is estimated from retinal anatomical geometry and should be treated as a prototype localization.');
end

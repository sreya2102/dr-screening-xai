function fovMask = extract_fov_mask(img)
% EXTRACT_FOV_MASK Extracts binary mask of retinal fundus Field of View (FOV).
%
% Inputs:
%   img - RGB image (M x N x 3) or Grayscale image (M x N)
%
% Outputs:
%   fovMask - Logical binary matrix (M x N) where true indicates fundus ROI.

    % Convert input to double grayscale image in range [0, 255]
    if size(img, 3) == 3
        % Use Red channel or luminance weighted average
        % Red channel typically has highest fundus background intensity
        gray = double(img(:,:,1));
    else
        gray = double(img);
    end
    
    if max(gray(:)) <= 1.0 && max(gray(:)) > 0
        gray = gray * 255;
    end
    
    [rows, cols] = size(gray);
    
    % Basic intensity thresholding to separate fundus from black borders
    thresh = max(10, 0.08 * max(gray(:)));
    binaryRaw = gray > thresh;
    
    % Morphological cleanup: remove small artifacts and fill holes
    SE = fspecial('disk', 5) > 0;
    binaryClean = imclose(binaryRaw, SE);
    binaryClean = imfill(binaryClean, 'holes');
    
    % Find largest connected component (the primary fundus mask)
    CC = bwconncomp(binaryClean);
    if CC.NumObjects == 0
        fovMask = false(rows, cols);
        return;
    end
    
    numPixels = cellfun(@numel, CC.PixelIdxList);
    [maxArea, maxIdx] = max(numPixels);
    
    % If largest region is extremely small (< 1% of image), mask is invalid
    if maxArea < (0.01 * rows * cols)
        fovMask = false(rows, cols);
        return;
    end
    
    fovMask = false(rows, cols);
    fovMask(CC.PixelIdxList{maxIdx}) = true;
    
    % Smooth mask edges using morphological opening
    SE_smooth = fspecial('disk', 7) > 0;
    fovMask = imopen(fovMask, SE_smooth);
    fovMask = imfill(fovMask, 'holes');
end

function overlayImg = create_segmentation_overlay(enhancedImg, results, mode)
% CREATE_SEGMENTATION_OVERLAY Generates an RGB uint8 image with annotated segmentation masks.
%
% Syntax:
%   overlayImg = create_segmentation_overlay(enhancedImg, results, mode)
%
% Inputs:
%   enhancedImg - RGB fundus image (uint8)
%   results     - Struct containing the logical masks:
%                   .vesselMask
%                   .opticDiscMask
%                   .foveaMask
%                   .exudateMask
%                   .microaneurysmMask
%                   .hemorrhageMask
%                   .vesselAnalysis (for tortuosity segments)
%   mode        - Visualization mode: 'normal' or 'tortuosity' (default: 'normal')
%
% Outputs:
%   overlayImg - RGB uint8 composite image with overlay

    if nargin < 3 || isempty(mode)
        mode = 'normal';
    end

    [H, W, C] = size(enhancedImg);
    
    % Ensure base image is RGB uint8
    if C == 1
        rgbBase = cat(3, enhancedImg, enhancedImg, enhancedImg);
    else
        rgbBase = enhancedImg;
    end
    
    % Initialize output as a double for easy blending operations
    rgbOut = double(rgbBase);
    
    % Define custom colors (RGB [0, 255])
    colorVesselsNormal = [0, 255, 0];       % Green
    colorVesselLowTort = [0, 255, 0];       % Green
    colorVesselModTort = [255, 128, 0];     % Orange
    colorVesselHighTort = [255, 0, 0];      % Red
    
    colorDiscBoundary = [0, 128, 255];      % Bright Blue
    colorFovea = [255, 0, 255];             % Purple/Magenta
    colorExudate = [255, 255, 0];           % Yellow
    colorMA = [255, 165, 0];                % Orange (Microaneurysm)
    colorHemorrhage = [255, 0, 0];          % Red (Hemorrhage)
    
    alpha = 0.5; % Blending factor for solid overlays
    
    if strcmp(mode, 'tortuosity')
        % TORTUOSITY MODE: Color-code vessels by segment tortuosity
        % Get segment information from vessel analysis
        if isfield(results, 'vesselAnalysis') && isfield(results.vesselAnalysis, 'segments')
            segments = results.vesselAnalysis.segments;
            
            % Draw unsegmented skeleton pixels in dim green first
            skelMask = results.vesselSkeleton;
            for ch = 1:3
                layer = rgbOut(:, :, ch);
                layer(skelMask) = 100 * (ch == 2); % Dim green for background skeleton
                rgbOut(:, :, ch) = layer;
            end
            
            % Overlay segments colored by tortuosity
            for idx = 1:numel(segments)
                seg = segments(idx);
                pixelIdxs = seg.pixels;
                
                % Determine color based on segment tortuosity
                if seg.tortuosity <= 1.10
                    col = colorVesselLowTort;
                elseif seg.tortuosity <= 1.25
                    col = colorVesselModTort;
                else
                    col = colorVesselHighTort;
                end
                
                % Dilate the segment pixel indexes for better visibility in overlay
                segMask = false(H, W);
                segMask(pixelIdxs) = true;
                segMaskExpanded = imdilate(segMask, strel('disk', 1));
                expandedIdxs = find(segMaskExpanded);
                
                for ch = 1:3
                    layer = rgbOut(:, :, ch);
                    layer(expandedIdxs) = col(ch);
                    rgbOut(:, :, ch) = layer;
                end
            end
        else
            % Fallback if vessel analysis details are missing
            vMask = results.vesselMask;
            for ch = 1:3
                layer = rgbOut(:, :, ch);
                layer(vMask) = colorVesselsNormal(ch);
                rgbOut(:, :, ch) = layer;
            end
        end
    else
        % NORMAL MODE: Solid color segmentation overlay
        % 1. Vessels (Green)
        vMask = results.vesselMask;
        for ch = 1:3
            layer = rgbOut(:, :, ch);
            layer(vMask) = (1-alpha) * layer(vMask) + alpha * colorVesselsNormal(ch);
            rgbOut(:, :, ch) = layer;
        end
    end
    
    % 2. Optic Disc Boundary (Blue)
    if isfield(results, 'opticDiscMask') && sum(results.opticDiscMask(:)) > 0
        % Find boundary of the optic disc using morphological gradient
        discBoundary = imdilate(results.opticDiscMask, strel('disk', 1)) & ~results.opticDiscMask;
        % Make the boundary line thicker for visualization
        discBoundary = imdilate(discBoundary, strel('disk', 2));
        
        for ch = 1:3
            layer = rgbOut(:, :, ch);
            layer(discBoundary) = colorDiscBoundary(ch);
            rgbOut(:, :, ch) = layer;
        end
    end
    
    % 3. Exudates (Yellow)
    if isfield(results, 'exudateMask') && sum(results.exudateMask(:)) > 0
        exMask = results.exudateMask;
        % Slightly dilate exudate candidates to make them visible
        exMaskVis = imdilate(exMask, strel('disk', 1));
        for ch = 1:3
            layer = rgbOut(:, :, ch);
            layer(exMaskVis) = (1-alpha) * layer(exMaskVis) + alpha * colorExudate(ch);
            rgbOut(:, :, ch) = layer;
        end
    end
    
    % 4. Hemorrhages (Red)
    if isfield(results, 'hemorrhageMask') && sum(results.hemorrhageMask(:)) > 0
        heMask = results.hemorrhageMask;
        heMaskVis = imdilate(heMask, strel('disk', 1));
        for ch = 1:3
            layer = rgbOut(:, :, ch);
            layer(heMaskVis) = (1-alpha) * layer(heMaskVis) + alpha * colorHemorrhage(ch);
            rgbOut(:, :, ch) = layer;
        end
    end
    
    % 5. Microaneurysms (Orange)
    if isfield(results, 'microaneurysmMask') && sum(results.microaneurysmMask(:)) > 0
        maMask = results.microaneurysmMask;
        % Microaneurysms are very small, dilate them to form visible dots
        maMaskVis = imdilate(maMask, strel('disk', 2));
        for ch = 1:3
            layer = rgbOut(:, :, ch);
            layer(maMaskVis) = colorMA(ch);
            rgbOut(:, :, ch) = layer;
        end
    end
    
    % 6. Fovea Location (Purple)
    if isfield(results, 'foveaMask') && sum(results.foveaMask(:)) > 0
        % Draw an outer crosshair marker for fovea position
        foveaBoundary = imdilate(results.foveaMask, strel('disk', 1)) & ~results.foveaMask;
        foveaBoundary = imdilate(foveaBoundary, strel('disk', 1));
        
        for ch = 1:3
            layer = rgbOut(:, :, ch);
            layer(foveaBoundary) = colorFovea(ch);
            rgbOut(:, :, ch) = layer;
        end
    end
    
    % Convert final blended double matrix back to uint8 RGB
    overlayImg = uint8(min(255, max(0, rgbOut)));
end

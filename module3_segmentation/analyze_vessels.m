function [vesselAnalysis, features] = analyze_vessels(vesselMask, vesselSkeleton, roiMask)
% ANALYZE_VESSELS Analyzes retinal vessel morphology including branching, tortuosity, and width.
%
% Syntax:
%   [vesselAnalysis, features] = analyze_vessels(vesselMask, vesselSkeleton, roiMask)
%
% Inputs:
%   vesselMask     - Logical binary mask of vessels
%   vesselSkeleton - Logical binary skeleton of vessels
%   roiMask        - Logical binary mask of retinal Field-of-View (FOV)
%
% Outputs:
%   vesselAnalysis - Struct containing detailed measurements and scores
%   features       - Struct containing summary metrics for downstream tasks

    % Calculate total retinal area in pixels
    retinalArea = sum(roiMask(:));
    if retinalArea == 0
        retinalArea = numel(roiMask);
    end

    % 1. Detect Branch Points and End Points
    % Compute the number of 8-neighbors for each skeleton pixel using a convolution
    kernel = [1 1 1; 1 0 1; 1 1 1];
    neighborCount = conv2(double(vesselSkeleton), kernel, 'same');
    neighborCount(~vesselSkeleton) = 0;
    
    % Branch points: skeleton pixels with 3 or more neighbors
    branchPointsMask = (neighborCount >= 3) & vesselSkeleton;
    
    % End points: skeleton pixels with exactly 1 neighbor
    endPointsMask = (neighborCount == 1) & vesselSkeleton;
    
    branchPointCount = sum(branchPointsMask(:));
    endPointCount = sum(endPointsMask(:));
    
    % Normalize branching density by retinal area (per million pixels for readability)
    branchingDensity = (double(branchPointCount) / double(retinalArea)) * 1e6;
    
    % 2. Extract Vessel Segments (remove branch points to isolate segments)
    segmentSkeleton = vesselSkeleton & ~branchPointsMask;
    cc = bwconncomp(segmentSkeleton, 8);
    
    % Initialize variables for tortuosity analysis
    minSegmentLength = 10; % Ignore very short/noisy segments
    tortuosityVals = [];
    segmentCount = 0;
    
    % Struct to store segment details for visualization or analysis
    segments = struct('pixels', {}, 'length', {}, 'endpoints', {}, 'endpointDistance', {}, 'tortuosity', {});
    
    for i = 1:cc.NumObjects
        pixelIdxs = cc.PixelIdxList{i};
        arcLength = numel(pixelIdxs);
        
        if arcLength < minSegmentLength
            continue;
        end
        
        % Get coordinates of pixels in this segment
        [r, c] = ind2sub(size(vesselSkeleton), pixelIdxs);
        
        % Find the endpoints of this segment (pixels with <= 1 neighbor in the segment)
        segmentMask = false(size(vesselSkeleton));
        segmentMask(pixelIdxs) = true;
        segNeighbors = conv2(double(segmentMask), kernel, 'same');
        segNeighbors(~segmentMask) = 0;
        segEndPoints = find(segNeighbors <= 1 & segmentMask);
        
        if numel(segEndPoints) >= 2
            % Take the first and last endpoints found
            [r1, c1] = ind2sub(size(vesselSkeleton), segEndPoints(1));
            [r2, c2] = ind2sub(size(vesselSkeleton), segEndPoints(end));
            endpointDistance = sqrt((r1 - r2)^2 + (c1 - c2)^2);
        else
            % Fallback: use max coordinate distance as straight-line distance
            rMin = min(r); rMax = max(r);
            cMin = min(c); cMax = max(c);
            endpointDistance = sqrt((rMax - rMin)^2 + (cMax - cMin)^2);
        end
        
        % Avoid division by zero and handle straight vessels
        if endpointDistance < 1
            endpointDistance = 1;
        end
        
        segmentTortuosity = double(arcLength) / double(endpointDistance);
        if segmentTortuosity < 1.0
            segmentTortuosity = 1.0; % Tortuosity cannot be less than 1.0
        end
        
        segmentCount = segmentCount + 1;
        tortuosityVals(end+1) = segmentTortuosity; %#ok<AGROW>
        
        segments(segmentCount).pixels = pixelIdxs;
        segments(segmentCount).length = arcLength;
        segments(segmentCount).endpointDistance = endpointDistance;
        segments(segmentCount).tortuosity = segmentTortuosity;
    end
    
    % Tortuosity statistics
    if isempty(tortuosityVals)
        meanTortuosity = 1.0;
        medianTortuosity = 1.0;
        maxTortuosity = 1.0;
        highTortuosityPercentage = 0.0;
    else
        meanTortuosity = mean(tortuosityVals);
        medianTortuosity = median(tortuosityVals);
        maxTortuosity = max(tortuosityVals);
        % High tortuosity threshold (e.g. tortuosity > 1.25)
        highTortuosityPercentage = sum(tortuosityVals > 1.25) / numel(tortuosityVals) * 100;
    end
    
    % 3. Estimate Vessel Widths
    % Distance transform of vessel mask gives radius of vessel at each skeleton pixel
    distMap = bwdist(~vesselMask);
    skeletonDistances = distMap(vesselSkeleton);
    
    if isempty(skeletonDistances)
        meanVesselWidth = 0.0;
        vesselWidthStd = 0.0;
        vesselWidthCV = 0.0;
    else
        % Local width is 2 * local radius
        vesselWidths = 2 * double(skeletonDistances);
        meanVesselWidth = mean(vesselWidths);
        vesselWidthStd = std(vesselWidths);
        if meanVesselWidth > 0
            vesselWidthCV = vesselWidthStd / meanVesselWidth;
        else
            vesselWidthCV = 0.0;
        end
    end
    
    % Width irregularity defined as CV * 100 for percentage scale
    widthIrregularity = vesselWidthCV * 100;
    
    % 4. Compute Vessel Abnormality Score (0 to 100 scale)
    % A. Tortuosity Score (maps typical mean tortuosity [1.0, 1.4] to [0, 100])
    tortuosityScore = min(100, max(0, (meanTortuosity - 1.0) / 0.4 * 70 + (highTortuosityPercentage / 100) * 30));
    
    % B. Branching Score (maps branching density per million pixels [0, 1500] to [0, 100])
    branchingScore = min(100, max(0, (branchingDensity / 1500.0) * 100));
    
    % C. Width Irregularity Score (maps CV [0, 0.6] to [0, 100])
    widthIrregularityScore = min(100, max(0, (vesselWidthCV / 0.6) * 100));
    
    % Weighted combination
    % These weights are prototype research heuristics and are NOT clinically validated.
    wTortuosity = 0.50;
    wBranching = 0.25;
    wWidth = 0.25;
    
    vesselAbnormalityScore = wTortuosity * tortuosityScore + ...
                             wBranching * branchingScore + ...
                             wWidth * widthIrregularityScore;
                         
    % Clamp score to [0, 100]
    vesselAbnormalityScore = min(100, max(0, vesselAbnormalityScore));
    
    % Determine score interpretation text
    if vesselAbnormalityScore <= 30
        interpretation = 'Lower vessel irregularity detected';
    elseif vesselAbnormalityScore <= 60
        interpretation = 'Moderate vessel irregularity detected';
    else
        interpretation = 'Higher vessel irregularity detected';
    end
    
    % Store detailed analysis
    vesselAnalysis = struct();
    vesselAnalysis.branchPointsMask = branchPointsMask;
    vesselAnalysis.endPointsMask = endPointsMask;
    vesselAnalysis.segments = segments;
    vesselAnalysis.tortuosityScore = tortuosityScore;
    vesselAnalysis.branchingScore = branchingScore;
    vesselAnalysis.widthIrregularityScore = widthIrregularityScore;
    vesselAnalysis.vesselAbnormalityScore = vesselAbnormalityScore;
    vesselAnalysis.interpretation = interpretation;
    vesselAnalysis.disclaimer = 'Screening-oriented research indicator - not a medical diagnosis.';
    
    % Populate features for output
    features = struct();
    features.branchPointCount = branchPointCount;
    features.branchingDensity = branchingDensity;
    features.meanTortuosity = meanTortuosity;
    features.medianTortuosity = medianTortuosity;
    features.maxTortuosity = maxTortuosity;
    features.highTortuosityPercentage = highTortuosityPercentage;
    features.meanVesselWidth = meanVesselWidth;
    features.stdVesselWidth = vesselWidthStd;
    features.vesselWidthCV = vesselWidthCV;
    features.widthIrregularity = widthIrregularity;
    features.vesselAbnormalityScore = vesselAbnormalityScore;
    features.tortuosityScore = tortuosityScore;
    features.branchingScore = branchingScore;
    features.widthIrregularityScore = widthIrregularityScore;
end

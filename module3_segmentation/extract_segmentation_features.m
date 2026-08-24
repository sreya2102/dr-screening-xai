function features = extract_segmentation_features(vesselFeatures, vesselAnalysis, discCupFeatures, lesionFeatures, roiMask)
% EXTRACT_SEGMENTATION_FEATURES Consolidates features from all submodules into a single struct.
%
% Syntax:
%   features = extract_segmentation_features(vesselFeatures, vesselAnalysis, discCupFeatures, lesionFeatures, roiMask)
%
% Inputs:
%   vesselFeatures   - Struct from segment_vessels
%   vesselAnalysis   - Struct from analyze_vessels
%   discCupFeatures  - Struct from segment_optic_disc
%   lesionFeatures   - Struct from segment_lesions
%   roiMask          - Logical Field of View mask
%
% Outputs:
%   features - Consolidated features structure with all required fields

    % Calculate total retinal ROI area in pixels
    totalRoiArea = sum(roiMask(:));
    if totalRoiArea == 0
        totalRoiArea = numel(roiMask);
    end

    features = struct();
    
    % Vessel Features
    features.vesselDensity = double(vesselFeatures.vesselDensity);
    features.vesselPixelCount = double(vesselFeatures.vesselPixelCount);
    features.skeletonLength = double(vesselFeatures.skeletonLength);
    
    % Vessel Analysis Features
    features.branchPointCount = double(vesselFeatures.branchPointCount);
    features.branchingDensity = double(vesselFeatures.branchingDensity);
    features.meanTortuosity = double(vesselFeatures.meanTortuosity);
    features.medianTortuosity = double(vesselFeatures.medianTortuosity);
    features.maxTortuosity = double(vesselFeatures.maxTortuosity);
    features.highTortuosityPercentage = double(vesselFeatures.highTortuosityPercentage);
    features.meanVesselWidth = double(vesselFeatures.meanVesselWidth);
    features.stdVesselWidth = double(vesselFeatures.stdVesselWidth);
    features.vesselWidthCV = double(vesselFeatures.vesselWidthCV);
    features.widthIrregularity = double(vesselFeatures.widthIrregularity);
    
    % Optic Disc & Cup Features
    features.opticDiscArea = double(discCupFeatures.opticDiscArea);
    features.opticCupArea = double(discCupFeatures.opticCupArea);
    features.cupToDiscRatio = double(discCupFeatures.cupToDiscRatio);
    
    % Lesion Features
    features.exudateCount = double(lesionFeatures.exudateCount);
    features.exudateArea = double(lesionFeatures.exudateArea);
    features.exudateAreaPercentage = (features.exudateArea / double(totalRoiArea)) * 100;
    
    features.microaneurysmCount = double(lesionFeatures.microaneurysmCount);
    features.microaneurysmArea = double(lesionFeatures.microaneurysmArea);
    
    features.hemorrhageCount = double(lesionFeatures.hemorrhageCount);
    features.hemorrhageArea = double(lesionFeatures.hemorrhageArea);
    
    % Abnormality Score Features
    features.vesselAbnormalityScore = double(vesselAnalysis.vesselAbnormalityScore);
    features.tortuosityScore = double(vesselAnalysis.tortuosityScore);
    features.branchingScore = double(vesselAnalysis.branchingScore);
    features.widthIrregularityScore = double(vesselAnalysis.widthIrregularityScore);
end

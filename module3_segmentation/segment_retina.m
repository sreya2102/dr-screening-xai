function [segmentationResults, overlayImg] = segment_retina(enhancedImg, options)
% SEGMENT_RETINA Main coordinator for the RetinaScan Retinal & Lesion Segmentation module.
%
% Syntax:
%   [segmentationResults, overlayImg] = segment_retina(enhancedImg, options)
%
% Inputs:
%   enhancedImg - RGB uint8 retinal fundus image, grayscale, or compatible numeric matrix.
%   options     - (Optional) Struct containing parameters:
%                   .vesselSensitivity - Sensitivity parameter (0 to 1, default: 0.5)
%                   .enableLesions     - Enable lesion candidate detection (default: true)
%                   .roiMask           - User-provided Field of View mask (logical)
%
% Outputs:
%   segmentationResults - Struct containing logical masks, quantitative features, and scores.
%   overlayImg          - RGB uint8 image with color-coded annotated findings.

    % --- Phase 1: Input Validation & Image Normalization ---
    if nargin < 1 || isempty(enhancedImg)
        error('RetinaScan:InvalidInput', 'Input enhancedImage must not be empty.');
    end
    
    % Initialize options if missing
    if nargin < 2 || isempty(options)
        options = struct();
    end
    
    if ~isfield(options, 'vesselSensitivity') || isempty(options.vesselSensitivity)
        options.vesselSensitivity = 0.5;
    end
    if ~isfield(options, 'enableLesions') || isempty(options.enableLesions)
        options.enableLesions = true;
    end
    
    % Handle dimensions and format conversions
    [H, W, C] = size(enhancedImg);
    
    % Safe validation: check if dimensions are too small
    if H < 10 || W < 10
        error('RetinaScan:SizeError', 'Image size is too small for processing.');
    end
    
    % Handle RGBA (4 channels)
    if C == 4
        enhancedImg = enhancedImg(:, :, 1:3);
        C = 3;
    end
    
    % Handle grayscale (convert to RGB representation for pipeline compatibility)
    if C == 1
        rgbImg = cat(3, enhancedImg, enhancedImg, enhancedImg);
    else
        rgbImg = enhancedImg;
    end
    
    % Ensure image is uint8
    if ~isa(rgbImg, 'uint8')
        % Scale double/single values to [0, 255] uint8
        if max(rgbImg(:)) <= 1.0
            rgbImg = uint8(rgbImg * 255);
        else
            rgbImg = uint8(rgbImg);
        end
    end

    % --- Phase 2: Retinal Field-of-View (FOV) Detection & Preprocessing ---
    % PREPROCESSING STAND-IN — this is not the complete upstream
    % retinal image quality-gate module.
    if isfield(options, 'roiMask') && ~isempty(options.roiMask)
        roiMask = options.roiMask;
    else
        % Estimate Retinal FOV
        grayImg = rgbImg(:, :, 2); % Green channel
        % Threshold out black background
        fovEst = grayImg > 15;
        % Clean up holes and noise
        fovEst = imfill(fovEst, 'holes');
        fovEst = bwareaopen(fovEst, round(H * W * 0.05)); % Remove tiny objects
        % Erode to avoid boundary/border artifacts
        se_fov = strel('disk', 15);
        roiMask = imerode(fovEst, se_fov);
    end
    options.roiMask = roiMask;

    % Create empty outputs for errors/low-confidence defaults
    try
        % --- Phase 3: Optic Disc & Cup Segmentation ---
        [opticDiscMask, opticCupMask, odCenter, odRadius, odConfidence, discCupFeatures] = ...
            segment_optic_disc(rgbImg, options);
            
        % --- Phase 4: Fovea Localization ---
        [foveaMask, foveaX, foveaY, foveaConfidence] = ...
            segment_fovea(rgbImg, odCenter, odRadius, roiMask);
            
        % --- Phase 5 & 6: Retinal Vessel Segmentation & Skeletonization ---
        [vesselMask, vesselSkeleton, vesselFeatures] = ...
            segment_vessels(rgbImg, options);
            
        % --- Phase 7, 8, 9 & 10: Vessel Graph Morphology, Tortuosity, Width, & Score ---
        [vesselAnalysis, vesselMorphFeatures] = ...
            analyze_vessels(vesselMask, vesselSkeleton, roiMask);
            
        % Merge vessel feature structures
        vesselMergedFeatures = vesselFeatures;
        vesselFields = fieldnames(vesselMorphFeatures);
        for f = 1:numel(vesselFields)
            vesselMergedFeatures.(vesselFields{f}) = vesselMorphFeatures.(vesselFields{f});
        end
        
        % --- Phase 11, 12 & 13: Lesion Candidate Detection ---
        if options.enableLesions
            [exudateMask, microaneurysmMask, hemorrhageMask, lesionCombinedMask, lesionFeatures] = ...
                segment_lesions(rgbImg, opticDiscMask, vesselMask, options);
        else
            exudateMask = false(H, W);
            microaneurysmMask = false(H, W);
            hemorrhageMask = false(H, W);
            lesionCombinedMask = false(H, W);
            lesionFeatures = struct('exudateCount', 0, 'exudateArea', 0, ...
                                    'microaneurysmCount', 0, 'microaneurysmArea', 0, ...
                                    'hemorrhageCount', 0, 'hemorrhageArea', 0);
        end
        
        % --- Phase 14: Consolidated Feature Extraction ---
        features = extract_segmentation_features(vesselMergedFeatures, vesselAnalysis, ...
                                                 discCupFeatures, lesionFeatures, roiMask);
        
    catch ME
        % Graceful degradation: in case of internal failure, output default zero/empty masks
        warning('RetinaScan:PipelineError', 'An error occurred during pipeline execution: %s. Returning default outputs.', ME.message);
        
        opticDiscMask = false(H, W);
        opticCupMask = false(H, W);
        foveaMask = false(H, W);
        foveaX = W/2; foveaY = H/2; foveaConfidence = 0.0;
        vesselMask = false(H, W);
        vesselSkeleton = false(H, W);
        exudateMask = false(H, W);
        microaneurysmMask = false(H, W);
        hemorrhageMask = false(H, W);
        lesionCombinedMask = false(H, W);
        
        vesselAnalysis = struct('vesselAbnormalityScore', 0, 'tortuosityScore', 0, ...
                                'branchingScore', 0, 'widthIrregularityScore', 0, ...
                                'interpretation', 'Unable to calculate score', ...
                                'segments', [], 'disclaimer', 'Pipeline error fallback.');
                                
        features = struct(...
            'vesselDensity', 0.0, 'vesselPixelCount', 0, 'skeletonLength', 0, ...
            'branchPointCount', 0, 'branchingDensity', 0, ...
            'meanTortuosity', 1.0, 'medianTortuosity', 1.0, 'maxTortuosity', 1.0, 'highTortuosityPercentage', 0, ...
            'meanVesselWidth', 0.0, 'stdVesselWidth', 0.0, 'vesselWidthCV', 0.0, 'widthIrregularity', 0, ...
            'opticDiscArea', 0, 'opticCupArea', 0, 'cupToDiscRatio', 0.0, ...
            'exudateCount', 0, 'exudateArea', 0, 'exudateAreaPercentage', 0.0, ...
            'microaneurysmCount', 0, 'microaneurysmArea', 0, ...
            'hemorrhageCount', 0, 'hemorrhageArea', 0, ...
            'vesselAbnormalityScore', 0.0, ...
            'tortuosityScore', 0.0, 'branchingScore', 0.0, 'widthIrregularityScore', 0.0);
    end

    % --- Populate Output Structure ---
    segmentationResults = struct();
    segmentationResults.vesselMask = vesselMask;
    segmentationResults.vesselSkeleton = vesselSkeleton;
    segmentationResults.opticDiscMask = opticDiscMask;
    segmentationResults.opticCupMask = opticCupMask;
    segmentationResults.foveaMask = foveaMask;
    segmentationResults.fovea = struct('x', foveaX, 'y', foveaY, 'confidence', foveaConfidence);
    segmentationResults.exudateMask = exudateMask;
    segmentationResults.microaneurysmMask = microaneurysmMask;
    segmentationResults.hemorrhageMask = hemorrhageMask;
    segmentationResults.lesionCombinedMask = lesionCombinedMask;
    
    segmentationResults.features = features;
    segmentationResults.vesselAnalysis = vesselAnalysis;
    
    segmentationResults.confidence = struct(...
        'opticDisc', features.cupToDiscRatio * 0.2 + 0.8, ... % simple relative indicator
        'fovea', foveaConfidence);
        
    segmentationResults.metadata = struct(...
        'dimensions', [H, W], ...
        'vesselSensitivityUsed', options.vesselSensitivity, ...
        'sihProblemStatement', 'SIH260038', ...
        'timestamp', datetime('now'));
        
    % --- Phase 15: Explainability Reasoning ---
    segmentationResults.explanations = struct(...
        'vessel', 'Hessian-based multi-scale Frangi filter highlighting vesselness response + local adaptive binarization and morphological area cleaning.', ...
        'opticDisc', 'Connected-component multi-cue ranking (brightness, circularity, solidity, position) refined with Otsu thresholding.', ...
        'opticCup', 'Brightest central region within the segmented optic disc using green channel intensity thresholding.', ...
        'fovea', 'Estimated temporal offset (5 radii) and horizontal displacement relative to optic disc, refined via local dark-pixel intensity minima search.', ...
        'exudates', 'Morphological top-hat bright blob detection and local std thresholding outside the segmented optic disc region.', ...
        'microaneurysms', 'Small dark circular spots detected using morphological bottom-hat, multi-scale LoG, circularity (<0.85) and size filters (<=25px) outside vessels.', ...
        'hemorrhages', 'Larger dark irregular regions detected via bottom-hat, shape filters (solidity > 0.45) and size (>25px) criteria outside vessels.', ...
        'vesselScore', 'Morphological abnormality score combining mean segment tortuosity (50%), branching density (25%), and vessel-width irregularity (25%).' ...
    );

    % --- Phase 16: Visual Overlay Generation ---
    overlayImg = create_segmentation_overlay(rgbImg, segmentationResults, 'normal');
end

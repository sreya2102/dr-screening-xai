function tests = test_vessel_analysis
% TEST_VESSEL_ANALYSIS Unit tests for vessel skeleton morphology and score analysis.
    tests = functiontests(localfunctions);
end

function test_vessel_skeleton_metrics(testCase)
    H = 120; W = 120;
    vesselMask = false(H, W);
    % Create a vertical vessel line
    vesselMask(10:110, 58:62) = true;
    % Create a branch line
    vesselMask(48:52, 60:90) = true;
    
    vesselSkeleton = false(H, W);
    vesselSkeleton(10:110, 60) = true;
    vesselSkeleton(50, 60:90) = true;
    
    roiMask = false(H, W);
    [X, Y] = meshgrid(1:W, 1:H);
    roiMask(((X - 60).^2 + (Y - 60).^2) <= 55^2) = true;
    
    [vesselAnalysis, features] = analyze_vessels(vesselMask, vesselSkeleton, roiMask);
    
    verifyTrue(testCase, isstruct(vesselAnalysis));
    verifyTrue(testCase, isstruct(features));
    verifyTrue(isfield(features, 'vesselAbnormalityScore'));
    verifyTrue(isfield(features, 'branchPointCount'));
    verifyTrue(isfield(features, 'meanTortuosity'));
    verifyTrue(isfield(features, 'meanVesselWidth'));
    
    % Abnormality Score range check
    verifyGreaterThanOrEqual(testCase, features.vesselAbnormalityScore, 0.0);
    verifyLessThanOrEqual(testCase, features.vesselAbnormalityScore, 100.0);
    
    % Assert branch points count is detected (connection at [50, 60])
    verifyGreaterThanOrEqual(testCase, features.branchPointCount, 1);
end

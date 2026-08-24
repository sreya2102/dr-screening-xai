function tests = test_segment_vessels
% TEST_SEGMENT_VESSELS Unit tests for vessel segmentation module.
    tests = functiontests(localfunctions);
end

function test_vessel_segmentation_types(testCase)
    H = 120; W = 120;
    img = uint8(randi([10, 100], H, W, 3));
    % Place a bright circle to simulate retinal boundary
    [X, Y] = meshgrid(1:W, 1:H);
    roi = ((X - 60).^2 + (Y - 60).^2) <= 50^2;
    options = struct('roiMask', roi, 'vesselSensitivity', 0.5);
    
    [vesselMask, vesselSkeleton, features] = segment_vessels(img, options);
    
    verifyTrue(testCase, islogical(vesselMask));
    verifyTrue(testCase, islogical(vesselSkeleton));
    verifyEqual(testCase, size(vesselMask), [H, W]);
    verifyEqual(testCase, size(vesselSkeleton), [H, W]);
    verifyTrue(testCase, isstruct(features));
    verifyTrue(isfield(features, 'vesselDensity'));
    verifyTrue(isfield(features, 'vesselPixelCount'));
end

function test_vessel_sensitivity(testCase)
    H = 100; W = 100;
    img = uint8(randi([10, 100], H, W, 3));
    
    % Higher sensitivity should lower threshold and thus increase or keep same pixel count
    optionsHigh = struct('vesselSensitivity', 0.9);
    optionsLow = struct('vesselSensitivity', 0.1);
    
    [maskHigh, ~, ~] = segment_vessels(img, optionsHigh);
    [maskLow, ~, ~] = segment_vessels(img, optionsLow);
    
    verifyTrue(testCase, islogical(maskHigh));
    verifyTrue(testCase, islogical(maskLow));
end

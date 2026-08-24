function tests = test_segment_retina
% TEST_SEGMENT_RETINA Unit tests for main segment_retina coordinator.
    tests = functiontests(localfunctions);
end

function test_normal_rgb_image(testCase)
    % Test with a synthetic RGB image
    H = 100; W = 100;
    img = uint8(randi([0, 255], H, W, 3));
    
    [results, overlay] = segment_retina(img);
    
    % Assert types and sizes
    verifyEqual(testCase, size(overlay), [H, W, 3]);
    verifyClass(testCase, overlay, 'uint8');
    verifyTrue(testCase, islogical(results.vesselMask));
    verifyTrue(testCase, islogical(results.opticDiscMask));
    verifyTrue(testCase, isstruct(results.features));
    verifyGreaterThanOrEqual(testCase, results.features.vesselAbnormalityScore, 0.0);
    verifyLessThanOrEqual(testCase, results.features.vesselAbnormalityScore, 100.0);
end

function test_grayscale_image(testCase)
    % Test grayscale inputs
    H = 80; W = 80;
    img = uint8(randi([0, 255], H, W));
    
    [results, overlay] = segment_retina(img);
    
    verifyEqual(testCase, size(overlay), [H, W, 3]);
    verifyTrue(testCase, islogical(results.vesselMask));
    verifyEqual(testCase, size(results.vesselMask), [H, W]);
end

function test_rgba_image(testCase)
    % Test RGBA (4 channels) input conversion
    H = 80; W = 80;
    img = uint8(randi([0, 255], H, W, 4));
    
    [results, overlay] = segment_retina(img);
    
    verifyEqual(testCase, size(overlay), [H, W, 3]);
    verifyTrue(testCase, islogical(results.vesselMask));
end

function test_invalid_dimensions(testCase)
    % Test error handling for very small images
    img = uint8(randi([0, 255], 5, 5, 3));
    verifyError(testCase, @() segment_retina(img), 'RetinaScan:SizeError');
end

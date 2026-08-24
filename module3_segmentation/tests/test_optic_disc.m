function tests = test_optic_disc
% TEST_OPTIC_DISC Unit tests for optic disc and cup segmentation module.
    tests = functiontests(localfunctions);
end

function test_optic_disc_outputs(testCase)
    H = 120; W = 120;
    img = uint8(randi([10, 50], H, W, 3));
    % Draw a bright optic disc region to test detection
    [X, Y] = meshgrid(1:W, 1:H);
    odMask = ((X - 60).^2 + (Y - 60).^2) <= 15^2;
    for c = 1:3
        layer = img(:, :, c);
        layer(odMask) = 240;
        img(:, :, c) = layer;
    end
    
    [discMask, cupMask, center, radius, confidence, features] = segment_optic_disc(img);
    
    verifyTrue(testCase, islogical(discMask));
    verifyTrue(testCase, islogical(cupMask));
    verifyEqual(testCase, size(discMask), [H, W]);
    verifyEqual(testCase, size(cupMask), [H, W]);
    verifyTrue(testCase, isstruct(features));
    verifyTrue(isfield(features, 'opticDiscArea'));
    verifyTrue(isfield(features, 'cupToDiscRatio'));
    
    % Assert cup is a subset of disc
    verifyTrue(testCase, all(cupMask(discMask) | ~cupMask(:)));
    verifyGreaterThanOrEqual(testCase, features.cupToDiscRatio, 0.0);
    verifyLessThanOrEqual(testCase, features.cupToDiscRatio, 1.0);
end

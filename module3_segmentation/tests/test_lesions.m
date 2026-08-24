function tests = test_lesions
% TEST_LESIONS Unit tests for retinal lesion segmentation.
    tests = functiontests(localfunctions);
end

function test_lesion_detection_outputs(testCase)
    H = 120; W = 120;
    img = uint8(randi([10, 80], H, W, 3));
    
    % Draw some exudate-like spots
    [X, Y] = meshgrid(1:W, 1:H);
    exSpot = ((X - 40).^2 + (Y - 40).^2) <= 3^2;
    for c = 1:3
        layer = img(:, :, c);
        layer(exSpot) = 240;
        img(:, :, c) = layer;
    end
    
    % Draw some hemorrhage-like spots
    heSpot = ((X - 80).^2 + (Y - 80).^2) <= 5^2;
    for c = 1:3
        layer = img(:, :, c);
        layer(heSpot) = 15;
        img(:, :, c) = layer;
    end
    
    discMask = false(H, W);
    discMask(50:70, 50:70) = true;
    
    vesselMask = false(H, W);
    
    [exMask, maMask, heMask, combMask, features] = segment_lesions(img, discMask, vesselMask);
    
    verifyTrue(testCase, islogical(exMask));
    verifyTrue(testCase, islogical(maMask));
    verifyTrue(testCase, islogical(heMask));
    verifyTrue(testCase, islogical(combMask));
    verifyEqual(testCase, size(combMask), [H, W]);
    
    verifyTrue(testCase, isstruct(features));
    verifyTrue(isfield(features, 'exudateCount'));
    verifyTrue(isfield(features, 'microaneurysmCount'));
    verifyTrue(isfield(features, 'hemorrhageCount'));
end

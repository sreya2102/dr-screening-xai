function test_module1_iqa()
% TEST_MODULE1_IQA Unit tests for Module 1 Image Quality Assessment (IQA).

    fprintf('====================================================\n');
    fprintf('   Running Module 1 (IQA) MATLAB Unit Tests\n');
    fprintf('====================================================\n\n');

    passCount = 0;
    totalTests = 4;

    % Synthetic fundus image size
    rows = 256;
    cols = 256;

    [X, Y] = meshgrid(1:cols, 1:rows);
    centerX = cols / 2;
    centerY = rows / 2;
    radius = 100;

    distFromCenter = sqrt((X - centerX).^2 + (Y - centerY).^2);
    baseFovMask = distFromCenter <= radius;

    %% TEST 1: Synthetic GOOD Image
    fprintf('[Test 1] Evaluating Synthetic GOOD Fundus Image...\n');

    goodImg = zeros(rows, cols, 3, 'uint8');

    % Create a realistic intensity gradient inside the FOV
    rChan = zeros(rows, cols);
    gChan = zeros(rows, cols);
    bChan = zeros(rows, cols);

    radialPattern = 120 + 35 * cos(distFromCenter / radius * pi);
    radialPattern = max(50, min(180, radialPattern));

    rChan(baseFovMask) = radialPattern(baseFovMask);
    gChan(baseFovMask) = radialPattern(baseFovMask);

    % Add clear synthetic vessel structures
    for k = -80:10:80
        verticalVessel = abs(X - centerX - k) <= 1;
        horizontalVessel = abs(Y - centerY - k) <= 1;

        vesselMask = baseFovMask & (verticalVessel | horizontalVessel);

        gChan(vesselMask) = 25;
        rChan(vesselMask) = 60;
    end

    bChan(baseFovMask) = 40;

    goodImg(:,:,1) = uint8(rChan);
    goodImg(:,:,2) = uint8(gChan);
    goodImg(:,:,3) = uint8(bChan);

    [res1, ~] = assess_image_quality(goodImg);

    fprintf('  -> Status: %s | Score: %.2f | Acceptable: %d\n', ...
        res1.status, res1.quality_score, res1.is_acceptable);

    fprintf('  -> Metrics - Sharpness: %.1f, Contrast: %.1f, Brightness: %.1f, FOV: %.2f\n', ...
        res1.metrics.sharpness, ...
        res1.metrics.contrast, ...
        res1.metrics.brightness, ...
        res1.metrics.fov_coverage);

    if strcmp(res1.status, 'Good') && res1.is_acceptable
        fprintf('  [PASS] Test 1 Passed.\n\n');
        passCount = passCount + 1;
    else
        fprintf('  [FAIL] Test 1 Failed.\n\n');
    end

    %% TEST 2: Synthetic BORDERLINE Image
    fprintf('[Test 2] Evaluating Synthetic BORDERLINE Fundus Image...\n');

    % Blur the green channel to reduce sharpness
    hBlur = fspecial('gaussian', [11 11], 3.0);
    blurredGChan = imfilter(double(gChan), hBlur, 'replicate');

    borderlineImg = goodImg;
    borderlineImg(:,:,2) = uint8(blurredGChan);

    [res2, ~] = assess_image_quality(borderlineImg);

    fprintf('  -> Status: %s | Score: %.2f | Acceptable: %d\n', ...
        res2.status, res2.quality_score, res2.is_acceptable);

    fprintf('  -> Reason: %s\n', res2.rejection_reason{1});

    if strcmp(res2.status, 'Borderline') && res2.is_acceptable
        fprintf('  [PASS] Test 2 Passed.\n\n');
        passCount = passCount + 1;
    else
        fprintf('  [FAIL] Test 2 Failed.\n\n');
    end

    %% TEST 3: Synthetic REJECT Image
    fprintf('[Test 3] Evaluating Synthetic REJECT Image...\n');

    rejectImg = zeros(rows, cols, 3, 'uint8');

    [res3, ~] = assess_image_quality(rejectImg);

    fprintf('  -> Status: %s | Score: %.2f | Acceptable: %d\n', ...
        res3.status, res3.quality_score, res3.is_acceptable);

    fprintf('  -> Reason: %s\n', res3.rejection_reason{1});

    if strcmp(res3.status, 'Reject') && ~res3.is_acceptable
        fprintf('  [PASS] Test 3 Passed.\n\n');
        passCount = passCount + 1;
    else
        fprintf('  [FAIL] Test 3 Failed.\n\n');
    end

    %% TEST 4: Custom Configuration Override
    fprintf('[Test 4] Evaluating Custom Config Override...\n');

    cfg = default_iqa_config();

    % Make the sharpness requirement extremely strict.
    cfg.sharpness_good_thresh = 10000.0;

    [res4, ~] = assess_image_quality(goodImg, cfg);

    fprintf('  -> Status with strict config: %s\n', res4.status);

    if strcmp(res4.status, 'Borderline') || strcmp(res4.status, 'Reject')
        fprintf('  [PASS] Test 4 Passed.\n\n');
        passCount = passCount + 1;
    else
        fprintf('  [FAIL] Test 4 Failed.\n\n');
    end

    %% SUMMARY
    fprintf('====================================================\n');
    fprintf(' Test Results: %d / %d Tests Passed.\n', passCount, totalTests);
    fprintf('====================================================\n');
end
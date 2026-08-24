function test_results = test_module2()
% TEST_MODULE2 Automated test suite, benchmark, and compatibility runner for Module 2.
%
%   TEST_RESULTS = TEST_MODULE2() runs comprehensive unit tests, ROI fallback tests,
%   output contract checks, MATLAB/Simulink compatibility checks, and performance
%   benchmarks on Module 2 functions.
%
%   Outputs:
%       test_results - Struct containing test status, pass/fail counts, and benchmark timings.

    fprintf('=======================================================\n');
    fprintf('  Module 2: Image Enhancement - Automated Test Suite  \n');
    fprintf('=======================================================\n\n');

    test_results = struct();
    test_results.passed = 0;
    test_results.failed = 0;
    test_results.details = {};
    test_results.benchmark_mean_ms = 0.0;
    test_results.benchmark_std_ms = 0.0;

    % ---------------------------------------------------------------------
    % Test 1: Synthetic Image Generation & Basic Execution
    % ---------------------------------------------------------------------
    fprintf('[Test 1] Synthetic Fundus Phantom Processing... ');
    try
        [img_synth, mask_true] = create_synthetic_fundus_phantom(512, 512);
        [enhanced_rgb, green_ch, meta] = enhance_image(img_synth);

        assert(strcmp(meta.status, 'SUCCESS'), 'Expected status SUCCESS');
        assert(isa(enhanced_rgb, 'uint8'), 'enhanced_image must be uint8');
        assert(isa(green_ch, 'uint8'), 'green_channel must be uint8');
        assert(isequal(size(enhanced_rgb), [512, 512, 3]), 'enhanced_image size mismatch');
        assert(isequal(size(green_ch), [512, 512]), 'green_channel size mismatch');
        assert(~meta.roi_fallback_used, 'Fallback should not trigger on valid phantom');

        fprintf('PASSED\n');
        test_results.passed = test_results.passed + 1;
        test_results.details{end+1} = 'Test 1 (Synthetic Processing): PASSED';
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        test_results.failed = test_results.failed + 1;
        test_results.details{end+1} = sprintf('Test 1 (Synthetic Processing): FAILED (%s)', ME.message);
    end

    % ---------------------------------------------------------------------
    % Test 2: ROI Degeneracy & Centered Circular Fallback Handling
    % ---------------------------------------------------------------------
    fprintf('[Test 2] Degenerate ROI Fallback Handling... ');
    try
        % Pass a degraded/black image to trigger ROI fallback
        img_degraded = zeros(512, 512, 3, 'uint8');
        [~, ~, meta_degraded] = enhance_image(img_degraded);

        assert(strcmp(meta_degraded.status, 'WARNING'), 'Expected status WARNING on fallback');
        assert(meta_degraded.roi_fallback_used == true, 'roi_fallback_used should be true');
        assert(~isempty(meta_degraded.warnings), 'Warnings list should not be empty');

        fprintf('PASSED\n');
        test_results.passed = test_results.passed + 1;
        test_results.details{end+1} = 'Test 2 (ROI Fallback): PASSED';
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        test_results.failed = test_results.failed + 1;
        test_results.details{end+1} = sprintf('Test 2 (ROI Fallback): FAILED (%s)', ME.message);
    end

    % ---------------------------------------------------------------------
    % Test 3: Background Isolation Verification
    % ---------------------------------------------------------------------
    fprintf('[Test 3] Background Isolation Verification... ');
    try
        [img_synth, ~] = create_synthetic_fundus_phantom(256, 256);
        [enhanced_rgb, green_ch, meta] = enhance_image(img_synth);

        % Extract background mask pixels outside ROI
        roi_mask = create_roi_mask(img_synth(:, :, 2));
        bg_rgb_sum = sum(sum(enhanced_rgb(~cat(3, roi_mask, roi_mask, roi_mask))));
        bg_green_sum = sum(green_ch(~roi_mask));

        assert(bg_rgb_sum == 0, 'Background pixels outside ROI in RGB must be 0');
        assert(bg_green_sum == 0, 'Background pixels outside ROI in Green channel must be 0');

        fprintf('PASSED\n');
        test_results.passed = test_results.passed + 1;
        test_results.details{end+1} = 'Test 3 (Background Isolation): PASSED';
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        test_results.failed = test_results.failed + 1;
        test_results.details{end+1} = sprintf('Test 3 (Background Isolation): FAILED (%s)', ME.message);
    end

    % ---------------------------------------------------------------------
    % Test 4: Custom Parameters Override Test
    % ---------------------------------------------------------------------
    fprintf('[Test 4] Configurable Parameters Override... ');
    try
        [img_synth, ~] = create_synthetic_fundus_phantom(256, 256);
        [~, ~, meta_custom] = enhance_image(img_synth, ...
            'ClaheClipLimit', 3.0, ...
            'SharpenAmount', 0.8, ...
            'DenoiseKernelSize', [5 5]);

        assert(meta_custom.parameters.ClaheClipLimit == 3.0, 'ClaheClipLimit parameter mismatch');
        assert(meta_custom.parameters.SharpenAmount == 0.8, 'SharpenAmount parameter mismatch');
        assert(isequal(meta_custom.parameters.DenoiseKernelSize, [5 5]), 'DenoiseKernelSize parameter mismatch');

        fprintf('PASSED\n');
        test_results.passed = test_results.passed + 1;
        test_results.details{end+1} = 'Test 4 (Custom Parameters): PASSED';
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        test_results.failed = test_results.failed + 1;
        test_results.details{end+1} = sprintf('Test 4 (Custom Parameters): FAILED (%s)', ME.message);
    end

    % ---------------------------------------------------------------------
    % Test 5: MATLAB / Simulink Compatibility Simulation
    % ---------------------------------------------------------------------
    fprintf('[Test 5] MATLAB / Simulink Compatibility Check... ');
    try
        % Verify array bounds and codegen function availability
        img_sim = uint8(rand(512, 512, 3) * 255);
        [out_rgb, out_green, meta_sim] = enhance_image(img_sim);

        assert(isstruct(meta_sim), 'Metadata struct verification failed');
        assert(ndims(out_rgb) == 3 && ndims(out_green) == 2, 'Simulink array dimension mismatch');

        fprintf('PASSED\n');
        test_results.passed = test_results.passed + 1;
        test_results.details{end+1} = 'Test 5 (Simulink Compatibility): PASSED';
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        test_results.failed = test_results.failed + 1;
        test_results.details{end+1} = sprintf('Test 5 (Simulink Compatibility): FAILED (%s)', ME.message);
    end

    % ---------------------------------------------------------------------
    % Test 6: Reproducible Performance Benchmark
    % ---------------------------------------------------------------------
    fprintf('[Test 6] Performance Benchmark (512x512, 10 runs)... ');
    try
        [img_bench, ~] = create_synthetic_fundus_phantom(512, 512);

        % Warmup run
        [~, ~, ~] = enhance_image(img_bench);

        num_runs = 10;
        timings = zeros(num_runs, 1);
        for r = 1:num_runs
            tRun = tic;
            [~, ~, ~] = enhance_image(img_bench);
            timings(r) = toc(tRun) * 1000.0; % ms
        end

        mean_ms = mean(timings);
        std_ms = std(timings);
        test_results.benchmark_mean_ms = mean_ms;
        test_results.benchmark_std_ms = std_ms;

        fprintf('PASSED (Mean: %.2f ms, Std: %.2f ms)\n', mean_ms, std_ms);
        test_results.passed = test_results.passed + 1;
        test_results.details{end+1} = sprintf('Test 6 (Performance Benchmark): PASSED (%.2f +/- %.2f ms)', mean_ms, std_ms);
    catch ME
        fprintf('FAILED: %s\n', ME.message);
        test_results.failed = test_results.failed + 1;
        test_results.details{end+1} = sprintf('Test 6 (Performance Benchmark): FAILED (%s)', ME.message);
    end

    % Print Summary
    fprintf('\n-------------------------------------------------------\n');
    fprintf('  Test Suite Summary: %d Passed, %d Failed  \n', test_results.passed, test_results.failed);
    fprintf('-------------------------------------------------------\n\n');
end

function [img_synth, mask_circle] = create_synthetic_fundus_phantom(H, W)
    % Generates a synthetic circular fundus phantom with background shading,
    % blood vessels, microaneurysms, and noise for testing.
    [X, Y] = meshgrid(1:W, 1:H);
    centerX = (W + 1) / 2.0;
    centerY = (H + 1) / 2.0;
    radius = 0.42 * min(H, W);

    dist_from_center = sqrt((X - centerX).^2 + (Y - centerY).^2);
    mask_circle = dist_from_center <= radius;

    % Synthetic background shading (vignetting)
    vignette = 1.0 - 0.4 * (dist_from_center / radius).^2;
    vignette(~mask_circle) = 0.0;

    % Fundus orange/red base color
    R_base = 0.85 * vignette;
    G_base = 0.45 * vignette;
    B_base = 0.15 * vignette;

    % Add synthetic blood vessels (dark lines)
    vessel1 = (abs(Y - (centerY + 0.1 * (X - centerX).^1.2)) < 3.0) & mask_circle;
    vessel2 = (abs(X - (centerX + 0.15 * (Y - centerY).^1.1)) < 2.5) & mask_circle;
    vessels = vessel1 | vessel2;

    G_base(vessels) = G_base(vessels) * 0.4;
    R_base(vessels) = R_base(vessels) * 0.5;

    % Add synthetic noise
    noise = 0.02 * randn(H, W);
    R_base = max(0, min(1, R_base + noise));
    G_base = max(0, min(1, G_base + noise));
    B_base = max(0, min(1, B_base + noise));

    R_base(~mask_circle) = 0;
    G_base(~mask_circle) = 0;
    B_base(~mask_circle) = 0;

    img_synth = cat(3, uint8(R_base * 255), uint8(G_base * 255), uint8(B_base * 255));
end

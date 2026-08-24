function run_module3_demo()
% RUN_MODULE3_DEMO Demonstrates the RetinaScan Retinal & Lesion Segmentation pipeline.
%
% This script loads a retinal fundus image from demo_samples (or generates
% a synthetic fundus image if none are found) and runs segment_retina,
% displaying all intermediate masks, skeleton tortuosity overlays, and scores.

    fprintf('============================================================\n');
    fprintf('RetinaScan — Module 3 Retinal & Lesion Segmentation Demo\n');
    fprintf('SIH 2026 — Problem Statement SIH260038\n');
    fprintf('============================================================\n\n');

    % 1. Locate or generate sample fundus image
    demoDir = fullfile(fileparts(mfilename('fullpath')), '..', 'demo_samples');
    imageFiles = [dir(fullfile(demoDir, '*.jpg')); ...
                  dir(fullfile(demoDir, '*.jpeg')); ...
                  dir(fullfile(demoDir, '*.png'))];
              
    if ~isempty(imageFiles)
        imgPath = fullfile(demoDir, imageFiles(1).name);
        fprintf('Loading image: %s\n', imageFiles(1).name);
        img = imread(imgPath);
    else
        fprintf('No user-provided images found in demo_samples/.\n');
        fprintf('Generating synthetic retinal fundus image for demonstration...\n\n');
        img = generate_synthetic_fundus();
    end

    % 2. Execute primary segment_retina API
    fprintf('Running segment_retina pipeline...\n');
    options = struct();
    options.vesselSensitivity = 0.5;
    options.enableLesions = true;
    
    tic;
    [results, overlayImg] = segment_retina(img, options);
    elapsedTime = toc;
    fprintf('Pipeline completed in %.2f seconds.\n\n', elapsedTime);

    % 3. Print quantitative feature metrics
    f = results.features;
    fprintf('------------------------------------------------------------\n');
    fprintf('EXTRACTED QUANTITATIVE FEATURES & SCORES:\n');
    fprintf('------------------------------------------------------------\n');
    fprintf('Vessels:\n');
    fprintf('  Vessel Density:             %.4f (%% of retinal FOV)\n', f.vesselDensity);
    fprintf('  Vessel Pixel Count:         %d pixels\n', int32(f.vesselPixelCount));
    fprintf('  Skeleton Length:            %d pixels\n', int32(f.skeletonLength));
    fprintf('  Branch Point Count:         %d\n', int32(f.branchPointCount));
    fprintf('  Branching Density:          %.2f points / million px\n', f.branchingDensity);
    fprintf('  Vessel Mean Tortuosity:     %.4f\n', f.meanTortuosity);
    fprintf('  Vessel Max Tortuosity:      %.4f\n', f.maxTortuosity);
    fprintf('  High Tortuosity Segments:   %.2f%%\n', f.highTortuosityPercentage);
    fprintf('  Vessel Mean Width:          %.2f pixels\n', f.meanVesselWidth);
    fprintf('  Vessel Width Std:           %.2f pixels\n', f.stdVesselWidth);
    fprintf('  Vessel Width CV (Irreg):    %.4f (CV = std/mean)\n', f.vesselWidthCV);
    fprintf('\nOptic Disc & Cup:\n');
    fprintf('  Optic Disc Area:            %.2f pixels\n', f.opticDiscArea);
    fprintf('  Optic Cup Area:             %.2f pixels\n', f.opticCupArea);
    fprintf('  Cup-to-Disc Ratio (CDR):    %.4f (Area surrogate)\n', f.cupToDiscRatio);
    fprintf('\nFovea:\n');
    fprintf('  Fovea Centroid:             [%d, %d]\n', int32(results.fovea.x), int32(results.fovea.y));
    fprintf('  Localization Confidence:    %.2f\n', results.fovea.confidence);
    fprintf('\nDiabetic Retinopathy Lesions:\n');
    fprintf('  Exudate Candidate Count:    %d\n', int32(f.exudateCount));
    fprintf('  Exudate Candidate Area:     %.2f pixels (%.4f%% of FOV)\n', f.exudateArea, f.exudateAreaPercentage);
    fprintf('  Microaneurysm Candidate:    %d\n', int32(f.microaneurysmCount));
    fprintf('  Hemorrhage Candidate Count: %d\n', int32(f.hemorrhageCount));
    fprintf('  Hemorrhage Candidate Area:  %.2f pixels\n', f.hemorrhageArea);
    fprintf('\n------------------------------------------------------------\n');
    fprintf('VESSEL ABNORMALITY INDICATOR (PRIMARY DIFFERENTIATOR):\n');
    fprintf('------------------------------------------------------------\n');
    fprintf('  Tortuosity Score:           %.2f / 100\n', f.tortuosityScore);
    fprintf('  Branching Score:            %.2f / 100\n', f.branchingScore);
    fprintf('  Width Irregularity Score:   %.2f / 100\n', f.widthIrregularityScore);
    fprintf('  --> Vessel Abnormality Score: %.2f / 100\n', f.vesselAbnormalityScore);
    fprintf('  Classification:             %s\n', results.vesselAnalysis.interpretation);
    fprintf('  Note:                       %s\n', results.vesselAnalysis.disclaimer);
    fprintf('------------------------------------------------------------\n\n');

    % 4. Create Tortuosity-specific overlay
    overlayTort = create_segmentation_overlay(img, results, 'tortuosity');

    % 5. Plotting results in a multi-pane layout
    figure('Name', 'RetinaScan - Module 3 Segmentation Demonstration', 'NumberTitle', 'off', 'Position', [100 100 1100 800]);
    
    subplot(3, 3, 1);
    imshow(img);
    title('1. Enhanced Fundus Image');
    
    subplot(3, 3, 2);
    imshow(results.vesselMask);
    title('2. Segmented Blood Vessels');
    
    subplot(3, 3, 3);
    imshow(results.vesselSkeleton);
    title('3. Skeletonized Vessels');
    
    subplot(3, 3, 4);
    % Show disc and cup on local region
    imshow(results.opticDiscMask | results.opticCupMask);
    title('4. Optic Disc & Cup Mask');
    
    subplot(3, 3, 5);
    % Combined lesion mask
    imshow(results.lesionCombinedMask);
    title('5. Detected DR Lesions');
    
    subplot(3, 3, 6);
    % Fovea localization
    imshow(results.foveaMask);
    title('6. Fovea Position Mask');
    
    subplot(3, 3, 7);
    imshow(overlayImg);
    title('7. Composite Segmentation Overlay');
    
    subplot(3, 3, 8);
    imshow(overlayTort);
    title('8. Vessel Tortuosity Overlay');
    
    % Display metadata & score info in the 9th panel
    subplot(3, 3, 9);
    axis off;
    text(0.05, 0.9, 'RetinaScan Module 3 Summary', 'FontSize', 12, 'FontWeight', 'bold');
    text(0.05, 0.75, sprintf('Abnormality Score: %.1f / 100', f.vesselAbnormalityScore), 'FontSize', 11, 'Color', [0.8 0.2 0]);
    text(0.05, 0.65, results.vesselAnalysis.interpretation, 'FontSize', 10, 'FontWeight', 'bold');
    text(0.05, 0.50, sprintf('Vessels Density: %.2f%%', f.vesselDensity * 100), 'FontSize', 9);
    text(0.05, 0.42, sprintf('Optic Disc Area: %d px', int32(f.opticDiscArea)), 'FontSize', 9);
    text(0.05, 0.34, sprintf('Cup-to-Disc Ratio: %.3f', f.cupToDiscRatio), 'FontSize', 9);
    text(0.05, 0.26, sprintf('Exudates Count: %d', int32(f.exudateCount)), 'FontSize', 9);
    text(0.05, 0.18, sprintf('Hemorrhages Count: %d', int32(f.hemorrhageCount)), 'FontSize', 9);
    text(0.05, 0.05, 'SIH260038 Screening Research Prototype', 'FontSize', 8, 'FontAngle', 'italic');
    
    shg;
end

function img = generate_synthetic_fundus()
% Generates a realistic synthetic retinal fundus image with structures & lesions.
    H = 512; W = 512;
    img = zeros(H, W, 3, 'uint8');
    
    % 1. Create a dark circular retinal field-of-view (FOV) background
    [X, Y] = meshgrid(1:W, 1:H);
    centerX = W/2; centerY = H/2;
    fovRadius = 220;
    fovMask = ((X - centerX).^2 + (Y - centerY).^2) <= (fovRadius^2);
    
    % Retinal tissue base color (orange-reddish)
    for c = 1:3
        layer = img(:, :, c);
        if c == 1
            layer(fovMask) = 210; % Red
        elseif c == 2
            layer(fovMask) = 90;  % Green
        elseif c == 3
            layer(fovMask) = 25;  % Blue
        end
        img(:, :, c) = layer;
    end
    
    % Add gentle intensity shading (darker near the borders)
    distFromCenter = sqrt((X - centerX).^2 + (Y - centerY).^2);
    shadingFactor = 1.0 - (distFromCenter / fovRadius) * 0.4;
    shadingFactor(~fovMask) = 0;
    img = uint8(double(img) .* repmat(shadingFactor, [1, 1, 3]));
    
    % 2. Draw Optic Disc (Cream yellow)
    odX = 170; odY = 240; odRadius = 32;
    odMask = ((X - odX).^2 + (Y - odY).^2) <= (odRadius^2);
    
    % 3. Draw Optic Cup (Brighter white-yellow inside Optic Disc)
    ocRadius = 14;
    ocMask = ((X - odX).^2 + (Y - odY).^2) <= (ocRadius^2);
    
    for c = 1:3
        layer = img(:, :, c);
        if c == 1
            layer(odMask) = 245;
            layer(ocMask) = 255;
        elseif c == 2
            layer(odMask) = 205;
            layer(ocMask) = 240;
        elseif c == 3
            layer(odMask) = 110;
            layer(ocMask) = 180;
        end
        img(:, :, c) = layer;
    end
    
    % 4. Draw Fovea (Dark reddish-brown spot temporally located)
    % Since Optic Disc is at X=170 (left), temporal side is to the right
    foveaX = odX + 160; foveaY = odY + 10; foveaRadius = 18;
    foveaMask = ((X - foveaX).^2 + (Y - foveaY).^2) <= (foveaRadius^2);
    for c = 1:3
        layer = img(:, :, c);
        if c == 1
            layer(foveaMask) = 130;
        elseif c == 2
            layer(foveaMask) = 50;
        elseif c == 3
            layer(foveaMask) = 15;
        end
        img(:, :, c) = layer;
    end
    
    % 5. Draw Branching Retinal Vessel Tree (Dark red lines originating from OD)
    vesselMask = false(H, W);
    
    % Define parametric curves for temporal/nasal arcades
    t = 0:0.02:2*pi;
    % Main branches
    % Upper temporal arcade
    utX = odX + 80 * t;
    utY = odY - 100 * sin(t * 0.8) - 15 * t;
    % Lower temporal arcade
    ltX = odX + 80 * t;
    ltY = odY + 100 * sin(t * 0.8) + 15 * t;
    % Upper nasal arcade
    unX = odX - 50 * t;
    unY = odY - 60 * sin(t * 0.9) - 10 * t;
    % Lower nasal arcade
    lnX = odX - 50 * t;
    lnY = odY + 60 * sin(t * 0.9) + 10 * t;
    
    % Add tortuous segment for demonstration (highly curved sinus wave)
    tortX = odX + 120 + 20 * sin(t * 8.0);
    tortY = odY + 80 + 30 * t;
    
    % Plot curves on vessel mask
    vesselMask = draw_curve(vesselMask, utX, utY, 4.0, H, W);
    vesselMask = draw_curve(vesselMask, ltX, ltY, 3.5, H, W);
    vesselMask = draw_curve(vesselMask, unX, unY, 3.0, H, W);
    vesselMask = draw_curve(vesselMask, lnX, lnY, 2.5, H, W);
    vesselMask = draw_curve(vesselMask, tortX, tortY, 2.0, H, W);
    
    % Apply FOV constraint to vessels
    vesselMask = vesselMask & fovMask;
    
    % Overlay vessels as darker red/brown channels
    for c = 1:3
        layer = double(img(:, :, c));
        if c == 1
            layer(vesselMask) = layer(vesselMask) * 0.55; % Slightly darker red
        elseif c == 2
            layer(vesselMask) = layer(vesselMask) * 0.25; % Drastically block green
        elseif c == 3
            layer(vesselMask) = layer(vesselMask) * 0.15; % Block blue
        end
        img(:, :, c) = uint8(layer);
    end
    
    % 6. Draw Hard Exudates (Bright yellow spots)
    exudates = [350, 160; 370, 150; 360, 180; 390, 170; 240, 130];
    for idx = 1:size(exudates, 1)
        cx = exudates(idx, 1); cy = exudates(idx, 2);
        rad = randi([2, 5]);
        spotMask = ((X - cx).^2 + (Y - cy).^2) <= (rad^2);
        for c = 1:3
            layer = img(:, :, c);
            if c == 1, layer(spotMask) = 245; end
            if c == 2, layer(spotMask) = 240; end
            if c == 3, layer(spotMask) = 90;  end % Yellow
            img(:, :, c) = layer;
        end
    end
    
    % 7. Draw Microaneurysms (Tiny dark red dots)
    mas = [280, 270; 300, 290; 320, 280; 340, 290; 310, 310];
    for idx = 1:size(mas, 1)
        cx = mas(idx, 1); cy = mas(idx, 2);
        spotMask = ((X - cx).^2 + (Y - cy).^2) <= (2^2);
        for c = 1:3
            layer = img(:, :, c);
            if c == 1, layer(spotMask) = 110; end
            if c == 2, layer(spotMask) = 20;  end
            if c == 3, layer(spotMask) = 5;   end
            img(:, :, c) = layer;
        end
    end
    
    % 8. Draw Hemorrhages (Larger dark red pools)
    hems = [260, 340; 270, 350; 380, 330];
    for idx = 1:size(hems, 1)
        cx = hems(idx, 1); cy = hems(idx, 2);
        rad = randi([6, 12]);
        spotMask = ((X - cx).^2 + (Y - cy).^2) <= (rad^2);
        % Make irregular using morphological distort
        spotMask = imdilate(spotMask, strel('disk', 2));
        for c = 1:3
            layer = img(:, :, c);
            if c == 1, layer(spotMask) = 100; end
            if c == 2, layer(spotMask) = 25;  end
            if c == 3, layer(spotMask) = 10;  end
            img(:, :, c) = layer;
        end
    end
    
    % Add background noise & mild gaussian blur
    noise = randn(H, W) * 2;
    for c = 1:3
        layer = double(img(:, :, c)) + noise;
        img(:, :, c) = uint8(min(255, max(0, layer)));
    end
    img = imgaussfilt(img, 0.6);
    % Clip out the FOV borders strictly to keep black background clean
    for c = 1:3
        layer = img(:, :, c);
        layer(~fovMask) = 0;
        img(:, :, c) = layer;
    end
end

function mask = draw_curve(mask, px, py, thickness, H, W)
% Helper to draw curves of specific thickness on a logical mask
    numPts = numel(px);
    [X, Y] = meshgrid(1:W, 1:H);
    for i = 1:numPts
        cx = px(i); cy = py(i);
        if cx >= 1 && cx <= W && cy >= 1 && cy <= H
            ptMask = ((X - cx).^2 + (Y - cy).^2) <= (thickness/2)^2;
            mask = mask | ptMask;
        end
    end
end

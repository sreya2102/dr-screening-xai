function retina_segmentation_app()
% RETINA_SEGMENTATION_APP Programmatic MATLAB dashboard for RetinaScan Module 3.
%
% This application provides a graphical user interface (GUI) to load retinal
% fundus images, configure segmentation parameters, execute the pipeline,
% and visualize interactive overlays (vessels, disc/cup, fovea, lesions) 
% alongside quantitative metrics and the Vessel Abnormality Score.
%
% Run this function directly in MATLAB to launch the dashboard.

    % Create the main UI Figure
    fig = uifigure('Name', 'RetinaScan — Retinal & Lesion Segmentation UI Dashboard', ...
                   'Position', [100, 100, 1200, 850], ...
                   'Color', [0.12, 0.12, 0.14]); % Modern dark theme
               
    % Main Grid Layout (1 row, 2 columns: Left Controls, Right Display)
    mainGrid = uigridlayout(fig, [1, 2]);
    mainGrid.ColumnWidth = {340, '1x'};
    mainGrid.RowHeight = {'1x'};
    mainGrid.BackgroundColor = [0.12, 0.12, 0.14];

    % --- STATE VARIABLES ---
    currentImage = [];
    resultsData = [];
    overlayNormal = [];
    overlayTort = [];
    
    % --- LEFT CONTROL PANEL ---
    controlPanel = uipanel(mainGrid, 'Title', 'RetinaScan Control & Metrics', ...
                           'BackgroundColor', [0.16, 0.16, 0.18], ...
                           'ForegroundColor', [0.95, 0.95, 0.95], ...
                           'FontWeight', 'bold', ...
                           'FontSize', 12);
    controlPanel.Layout.Column = 1;
    
    % Scrollable Grid inside Left Panel
    controlGrid = uigridlayout(controlPanel, [12, 1]);
    controlGrid.RowHeight = {40, 45, 40, 60, 50, 110, 110, 110, 120, '1x'};
    controlGrid.BackgroundColor = [0.16, 0.16, 0.18];
    
    % Title Banner
    lblTitle = uilabel(controlGrid, 'Text', 'RetinaScan Segmentation', ...
                       'FontWeight', 'bold', 'FontSize', 16, ...
                       'TextColor', [0.0, 0.8, 1.0], ...
                       'HorizontalAlignment', 'center');
    lblTitle.Layout.Row = 1;
    
    % Load Image Button
    btnLoad = uibutton(controlGrid, 'push', 'Text', '📁 Load Fundus Image', ...
                       'BackgroundColor', [0.22, 0.25, 0.3], ...
                       'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                       'FontSize', 11, ...
                       'ButtonPushedFcn', @(~,~) load_image_callback());
    btnLoad.Layout.Row = 2;
    
    % Vessel Sensitivity Label & Slider
    sliderGrid = uigridlayout(controlGrid, [2, 1]);
    sliderGrid.RowHeight = {15, 20};
    sliderGrid.Padding = [0 0 0 0];
    sliderGrid.BackgroundColor = [0.16, 0.16, 0.18];
    sliderGrid.Layout.Row = 3;
    
    lblSens = uilabel(sliderGrid, 'Text', 'Vessel Sensitivity (default: 0.50):', ...
                       'TextColor', [0.8, 0.8, 0.8], 'FontSize', 10);
    lblSens.Layout.Row = 1;
    
    sldSens = uislider(sliderGrid, 'Limits', [0.0, 1.0], 'Value', 0.50, ...
                        'FontColor', [0.8, 0.8, 0.8], ...
                        'ValueChangedFcn', @(~,~) update_slider_label());
    sldSens.Layout.Row = 2;
    
    % Run Pipeline Button
    btnRun = uibutton(controlGrid, 'push', 'Text', '⚡ Run Retinal Analysis', ...
                      'BackgroundColor', [0.0, 0.6, 0.8], ...
                      'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                      'FontSize', 12, ...
                      'ButtonPushedFcn', @(~,~) run_analysis_callback());
    btnRun.Layout.Row = 4;
    
    % Abnormality Score Display Panel
    scorePanel = uipanel(controlGrid, 'Title', 'Vessel Abnormality Indicator', ...
                         'BackgroundColor', [0.2, 0.2, 0.22], ...
                         'ForegroundColor', [0.9, 0.9, 0.9], ...
                         'FontWeight', 'bold', 'FontSize', 10);
    scorePanel.Layout.Row = 5;
    scoreGrid = uigridlayout(scorePanel, [2, 1]);
    scoreGrid.RowHeight = {20, 20};
    scoreGrid.Padding = [5 5 5 5];
    scoreGrid.BackgroundColor = [0.2, 0.2, 0.22];
    
    lblScore = uilabel(scoreGrid, 'Text', 'Score: --', ...
                        'FontWeight', 'bold', 'FontSize', 14, ...
                        'TextColor', [1, 0.8, 0]);
    lblScore.Layout.Row = 1;
    
    lblInterpretation = uilabel(scoreGrid, 'Text', 'Interpretation: --', ...
                                 'FontSize', 10, 'TextColor', [0.8, 0.8, 0.8]);
    lblInterpretation.Layout.Row = 2;
    
    % Structure Metrics Panels (Vessels, Disc, Lesions)
    vesselPanel = uipanel(controlGrid, 'Title', 'Vascular Metrics', ...
                           'BackgroundColor', [0.18, 0.18, 0.2], ...
                           'ForegroundColor', [0.8, 0.95, 0.8]);
    vesselPanel.Layout.Row = 6;
    vesselGrid = uigridlayout(vesselPanel, [4, 1]);
    vesselGrid.RowHeight = {18, 18, 18, 18};
    vesselGrid.Padding = [5 5 5 5];
    vesselGrid.BackgroundColor = [0.18, 0.18, 0.2];
    
    lblVesDensity = uilabel(vesselGrid, 'Text', 'Vessel Density: --', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 10);
    lblVesDensity.Layout.Row = 1;
    lblVesLength = uilabel(vesselGrid, 'Text', 'Skeleton Length: --', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 10);
    lblVesLength.Layout.Row = 2;
    lblVesBranches = uilabel(vesselGrid, 'Text', 'Branch Points: --', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 10);
    lblVesBranches.Layout.Row = 3;
    lblVesWidth = uilabel(vesselGrid, 'Text', 'Vessel Width: --', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 10);
    lblVesWidth.Layout.Row = 4;
    
    discPanel = uipanel(controlGrid, 'Title', 'Optic Disc & Cup', ...
                         'BackgroundColor', [0.18, 0.18, 0.2], ...
                         'ForegroundColor', [0.8, 0.8, 0.95]);
    discPanel.Layout.Row = 7;
    discGrid = uigridlayout(discPanel, [3, 1]);
    discGrid.RowHeight = {18, 18, 18};
    discGrid.Padding = [5 5 5 5];
    discGrid.BackgroundColor = [0.18, 0.18, 0.2];
    
    lblDiscArea = uilabel(discGrid, 'Text', 'Optic Disc Area: --', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 10);
    lblDiscArea.Layout.Row = 1;
    lblCupArea = uilabel(discGrid, 'Text', 'Optic Cup Area: --', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 10);
    lblCupArea.Layout.Row = 2;
    lblCDR = uilabel(discGrid, 'Text', 'Cup-to-Disc Ratio (CDR): --', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 10);
    lblCDR.Layout.Row = 3;
    
    lesionPanel = uipanel(controlGrid, 'Title', 'Lesion Candidates', ...
                           'BackgroundColor', [0.18, 0.18, 0.2], ...
                           'ForegroundColor', [0.95, 0.8, 0.8]);
    lesionPanel.Layout.Row = 8;
    lesionGrid = uigridlayout(lesionPanel, [3, 1]);
    lesionGrid.RowHeight = {18, 18, 18};
    lesionGrid.Padding = [5 5 5 5];
    lesionGrid.BackgroundColor = [0.18, 0.18, 0.2];
    
    lblExudate = uilabel(lesionGrid, 'Text', 'Exudates: --', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 10);
    lblExudate.Layout.Row = 1;
    lblMA = uilabel(lesionGrid, 'Text', 'Microaneurysms: --', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 10);
    lblMA.Layout.Row = 2;
    lblHems = uilabel(lesionGrid, 'Text', 'Hemorrhages: --', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 10);
    lblHems.Layout.Row = 3;
    
    % Explainability Text Area
    explainPanel = uipanel(controlGrid, 'Title', 'Algorithmic Explanations', ...
                            'BackgroundColor', [0.14, 0.14, 0.16], ...
                            'ForegroundColor', [0.9, 0.9, 0.9]);
    explainPanel.Layout.Row = 9;
    explainGrid = uigridlayout(explainPanel, [1, 1]);
    explainGrid.Padding = [2 2 2 2];
    explainGrid.BackgroundColor = [0.14, 0.14, 0.16];
    
    txtExplain = uitextarea(explainGrid, 'Editable', 'off', ...
                            'BackgroundColor', [0.1, 0.1, 0.12], ...
                            'FontColor', [0.85, 0.85, 0.85], ...
                            'FontSize', 9, ...
                            'Value', {'Run analysis to see explainability text.'});
                        
    % Medical Disclaimer Notice
    lblDisclaimer = uilabel(controlGrid, 'WordWrap', 'on', ...
                            'Text', 'Disclaimer: This prototype is intended for research and hackathon demonstration purposes. It is not a medical diagnostic device.', ...
                            'FontAngle', 'italic', 'FontSize', 8, ...
                            'TextColor', [0.65, 0.65, 0.65]);
    lblDisclaimer.Layout.Row = 10;

    % --- RIGHT DISPLAY PANEL ---
    displayGrid = uigridlayout(mainGrid, [2, 1]);
    displayGrid.RowHeight = {40, '1x'};
    displayGrid.Layout.Column = 2;
    displayGrid.BackgroundColor = [0.12, 0.12, 0.14];
    
    % Tabs / Mode Selectors at the Top
    tabPanel = uipanel(displayGrid, 'BackgroundColor', [0.14, 0.14, 0.16], 'BorderType', 'none');
    tabPanel.Layout.Row = 1;
    tabGrid = uigridlayout(tabPanel, [1, 4]);
    tabGrid.ColumnWidth = {'1x', '1x', '1x', '1x'};
    tabGrid.Padding = [2 2 2 2];
    tabGrid.BackgroundColor = [0.14, 0.14, 0.16];
    
    btnTabOriginal = uibutton(tabGrid, 'state', 'Text', 'Original Fundus', 'Value', true, ...
                               'BackgroundColor', [0.2, 0.22, 0.26], 'FontColor', [1 1 1], ...
                               'ValueChangedFcn', @(src,~) switch_tab_callback(src, 'original'));
    btnTabOriginal.Layout.Column = 1;
    
    btnTabOverlay = uibutton(tabGrid, 'state', 'Text', 'Segmentation Overlay', ...
                              'BackgroundColor', [0.16, 0.16, 0.18], 'FontColor', [0.8 0.8 0.8], ...
                              'ValueChangedFcn', @(src,~) switch_tab_callback(src, 'overlay'));
    btnTabOverlay.Layout.Column = 2;
    
    btnTabTortuosity = uibutton(tabGrid, 'state', 'Text', 'Vessel Tortuosity', ...
                                 'BackgroundColor', [0.16, 0.16, 0.18], 'FontColor', [0.8 0.8 0.8], ...
                                 'ValueChangedFcn', @(src,~) switch_tab_callback(src, 'tortuosity'));
    btnTabTortuosity.Layout.Column = 3;
    
    btnTabLesions = uibutton(tabGrid, 'state', 'Text', 'DR Lesions Map', ...
                              'BackgroundColor', [0.16, 0.16, 0.18], 'FontColor', [0.8 0.8 0.8], ...
                              'ValueChangedFcn', @(src,~) switch_tab_callback(src, 'lesions'));
    btnTabLesions.Layout.Column = 4;
    
    % Main Visual Axes Area
    axesPanel = uipanel(displayGrid, 'BackgroundColor', [0.1, 0.1, 0.12], 'BorderType', 'none');
    axesPanel.Layout.Row = 2;
    axesGrid = uigridlayout(axesPanel, [1, 1]);
    axesGrid.Padding = [5 5 5 5];
    axesGrid.BackgroundColor = [0.1, 0.1, 0.12];
    
    axDisplay = uiaxes(axesGrid, 'Color', [0.1, 0.1, 0.12]);
    axDisplay.XAxis.Visible = 'off';
    axDisplay.YAxis.Visible = 'off';
    title(axDisplay, 'Image Viewport', 'Color', [0.8 0.8 0.8]);

    % --- DEMO INITIALIZATION ---
    % Auto-generate synthetic fundus for out-of-the-box demo
    currentImage = generate_synthetic_fundus_app();
    imshow(currentImage, 'Parent', axDisplay);
    title(axDisplay, 'Demo Fundus Loaded (Click Run Retinal Analysis)', 'Color', [0.0 0.8 1.0]);

    % --- CALLBACK FUNCTIONS ---
    
    function update_slider_label()
        lblSens.Text = sprintf('Vessel Sensitivity: %.2f', sldSens.Value);
    end

    function load_image_callback()
        % File selection dialog
        [file, path] = uigetfile({'*.jpg;*.jpeg;*.png;*.tif;*.tiff', 'Image Files (*.jpg, *.png, *.tif)'}, ...
                                'Select retinal fundus image');
        if isequal(file, 0)
            return; % User cancelled
        end
        
        imgPath = fullfile(path, file);
        try
            currentImage = imread(imgPath);
            % Reset UI states
            resultsData = [];
            overlayNormal = [];
            overlayTort = [];
            
            % Reset visual tab states
            btnTabOriginal.Value = true;
            btnTabOverlay.Value = false;
            btnTabTortuosity.Value = false;
            btnTabLesions.Value = false;
            
            % Update buttons display colors
            reset_tab_colors();
            btnTabOriginal.BackgroundColor = [0.2, 0.22, 0.26];
            btnTabOriginal.FontColor = [1 1 1];
            
            % Draw loaded image
            imshow(currentImage, 'Parent', axDisplay);
            title(axDisplay, sprintf('Loaded: %s', file), 'Color', [1 1 1]);
            
            % Clear metrics
            clear_metrics_text();
            txtExplain.Value = {'Image loaded. Adjust settings and click Run Retinal Analysis.'};
        catch ME
            uialert(fig, sprintf('Failed to load image: %s', ME.message), 'Error loading image');
        end
    end

    function run_analysis_callback()
        if isempty(currentImage)
            uialert(fig, 'Please load a retinal fundus image first.', 'No image loaded');
            return;
        end
        
        % Set up options from controls
        options = struct();
        options.vesselSensitivity = sldSens.Value;
        options.enableLesions = true;
        
        % Disable button during processing
        btnRun.Enable = 'off';
        btnRun.Text = '🔄 Analyzing Retina...';
        drawnow;
        
        try
            % Execute pipeline
            [resultsData, overlayNormal] = segment_retina(currentImage, options);
            
            % Generate secondary overlays
            overlayTort = create_segmentation_overlay(currentImage, resultsData, 'tortuosity');
            
            % Update displays based on active tab
            if btnTabOriginal.Value
                imshow(currentImage, 'Parent', axDisplay);
                title(axDisplay, 'Original Fundus Image', 'Color', [1 1 1]);
            elseif btnTabOverlay.Value
                imshow(overlayNormal, 'Parent', axDisplay);
                title(axDisplay, 'Retina Segmentation Composite Overlay', 'Color', [0.0 0.8 1.0]);
            elseif btnTabTortuosity.Value
                imshow(overlayTort, 'Parent', axDisplay);
                title(axDisplay, 'Retinal Vessel Segment Tortuosity (Green: Low, Orange: Mod, Red: High)', 'Color', [0.8 0.2 0]);
            elseif btnTabLesions.Value
                imshow(resultsData.lesionCombinedMask, 'Parent', axDisplay);
                title(axDisplay, 'Combined Diabetic Retinopathy Lesions Mask', 'Color', [1 0.4 0.4]);
            end
            
            % Update Metrics Displays
            update_metrics_displays();
            
        catch ME
            uialert(fig, sprintf('Analysis failed: %s', ME.message), 'Analysis Error');
        end
        
        btnRun.Enable = 'on';
        btnRun.Text = '⚡ Run Retinal Analysis';
    end

    function switch_tab_callback(clickedBtn, tabName)
        % Enforce exclusive mutual exclusion for state buttons
        btnTabOriginal.Value = false;
        btnTabOverlay.Value = false;
        btnTabTortuosity.Value = false;
        btnTabLesions.Value = false;
        
        clickedBtn.Value = true;
        
        % Reset colors
        reset_tab_colors();
        clickedBtn.BackgroundColor = [0.2, 0.22, 0.26];
        clickedBtn.FontColor = [1 1 1];
        
        if isempty(currentImage)
            return;
        end
        
        % Draw appropriate map
        switch tabName
            case 'original'
                imshow(currentImage, 'Parent', axDisplay);
                title(axDisplay, 'Original Retinal Fundus View', 'Color', [1 1 1]);
            case 'overlay'
                if ~isempty(overlayNormal)
                    imshow(overlayNormal, 'Parent', axDisplay);
                    title(axDisplay, 'Composite Segmentation Overlay', 'Color', [0.0 0.8 1.0]);
                else
                    imshow(currentImage, 'Parent', axDisplay);
                    title(axDisplay, 'Click Run Analysis to generate overlay', 'Color', [1 0.8 0]);
                end
            case 'tortuosity'
                if ~isempty(overlayTort)
                    imshow(overlayTort, 'Parent', axDisplay);
                    title(axDisplay, 'Vessel Segment Tortuosity Map (Green <=1.10, Orange <=1.25, Red >1.25)', 'Color', [0.8 0.2 0]);
                else
                    imshow(currentImage, 'Parent', axDisplay);
                    title(axDisplay, 'Click Run Analysis to generate tortuosity', 'Color', [1 0.8 0]);
                end
            case 'lesions'
                if ~isempty(resultsData)
                    imshow(resultsData.lesionCombinedMask, 'Parent', axDisplay);
                    title(axDisplay, 'DR Lesion Candidates Combined Mask (White = Lesion)', 'Color', [1 0.4 0.4]);
                else
                    imshow(currentImage, 'Parent', axDisplay);
                    title(axDisplay, 'Click Run Analysis to generate lesion mask', 'Color', [1 0.8 0]);
                end
        end
    end

    function reset_tab_colors()
        btnTabOriginal.BackgroundColor = [0.16, 0.16, 0.18];
        btnTabOriginal.FontColor = [0.8, 0.8, 0.8];
        btnTabOverlay.BackgroundColor = [0.16, 0.16, 0.18];
        btnTabOverlay.FontColor = [0.8, 0.8, 0.8];
        btnTabTortuosity.BackgroundColor = [0.16, 0.16, 0.18];
        btnTabTortuosity.FontColor = [0.8, 0.8, 0.8];
        btnTabLesions.BackgroundColor = [0.16, 0.16, 0.18];
        btnTabLesions.FontColor = [0.8, 0.8, 0.8];
    end

    function clear_metrics_text()
        lblScore.Text = 'Score: --';
        lblScore.TextColor = [0.8, 0.8, 0.8];
        lblInterpretation.Text = 'Interpretation: --';
        lblVesDensity.Text = 'Vessel Density: --';
        lblVesLength.Text = 'Skeleton Length: --';
        lblVesBranches.Text = 'Branch Points: --';
        lblVesWidth.Text = 'Vessel Width: --';
        lblDiscArea.Text = 'Optic Disc Area: --';
        lblCupArea.Text = 'Optic Cup Area: --';
        lblCDR.Text = 'Cup-to-Disc Ratio (CDR): --';
        lblExudate.Text = 'Exudates: --';
        lblMA.Text = 'Microaneurysms: --';
        lblHems.Text = 'Hemorrhages: --';
    end

    function update_metrics_displays()
        if isempty(resultsData)
            return;
        end
        f = resultsData.features;
        
        % Abnormality Score
        lblScore.Text = sprintf('Score: %.1f / 100', f.vesselAbnormalityScore);
        if f.vesselAbnormalityScore <= 30
            lblScore.TextColor = [0.0, 0.8, 0.4]; % Green
        elseif f.vesselAbnormalityScore <= 60
            lblScore.TextColor = [1.0, 0.6, 0.0]; % Orange
        else
            lblScore.TextColor = [1.0, 0.2, 0.2]; % Red
        end
        lblInterpretation.Text = sprintf('Interpretation: %s', resultsData.vesselAnalysis.interpretation);
        
        % Vessels
        lblVesDensity.Text = sprintf('Vessel Density: %.2f%% of FOV', f.vesselDensity * 100);
        lblVesLength.Text = sprintf('Skeleton Length: %d pixels', int32(f.skeletonLength));
        lblVesBranches.Text = sprintf('Branch Points: %d (Density: %.1f)', int32(f.branchPointCount), f.branchingDensity);
        lblVesWidth.Text = sprintf('Vessel Width: %.2f px (CV: %.2f)', f.meanVesselWidth, f.vesselWidthCV);
        
        % Disc/Cup
        lblDiscArea.Text = sprintf('Optic Disc Area: %d pixels', int32(f.opticDiscArea));
        lblCupArea.Text = sprintf('Optic Cup Area: %d pixels', int32(f.opticCupArea));
        lblCDR.Text = sprintf('Cup-to-Disc Ratio: %.3f (surrogate)', f.cupToDiscRatio);
        
        % Lesions
        lblExudate.Text = sprintf('Exudates Count: %d (Area: %d px)', int32(f.exudateCount), int32(f.exudateArea));
        lblMA.Text = sprintf('Microaneurysms Count: %d', int32(f.microaneurysmCount));
        lblHems.Text = sprintf('Hemorrhages Count: %d', int32(f.hemorrhageCount));
        
        % Populate Explainability Box
        exp = resultsData.explanations;
        explainVals = {
            'EXPLAINABLE REASONING REPORT:';
            '';
            ['• Vessel Segmentation: ' exp.vessel];
            '';
            ['• Optic Disc Detection: ' exp.opticDisc];
            '';
            ['• Optic Cup Detection: ' exp.opticCup];
            '';
            ['• Fovea Estimation: ' exp.fovea];
            '';
            ['• Exudate Candidates: ' exp.exudates];
            '';
            ['• Microaneurysms: ' exp.microaneurysms];
            '';
            ['• Hemorrhage Candidates: ' exp.hemorrhages];
            '';
            ['• Vessel Abnormality Score: ' exp.vesselScore]
        };
        txtExplain.Value = explainVals;
    end
end

function img = generate_synthetic_fundus_app()
% Generates a realistic synthetic fundus image for demonstration inside App.
    H = 512; W = 512;
    img = zeros(H, W, 3, 'uint8');
    
    [X, Y] = meshgrid(1:W, 1:H);
    centerX = W/2; centerY = H/2;
    fovRadius = 220;
    fovMask = ((X - centerX).^2 + (Y - centerY).^2) <= (fovRadius^2);
    
    % Base orange-red retina
    for c = 1:3
        layer = img(:, :, c);
        if c == 1, layer(fovMask) = 210; end
        if c == 2, layer(fovMask) = 90;  end
        if c == 3, layer(fovMask) = 25;  end
        img(:, :, c) = layer;
    end
    
    % Vignette shading
    distFromCenter = sqrt((X - centerX).^2 + (Y - centerY).^2);
    shadingFactor = 1.0 - (distFromCenter / fovRadius) * 0.4;
    shadingFactor(~fovMask) = 0;
    img = uint8(double(img) .* repmat(shadingFactor, [1, 1, 3]));
    
    % Optic Disc & Cup
    odX = 170; odY = 240; odRadius = 32;
    odMask = ((X - odX).^2 + (Y - odY).^2) <= (odRadius^2);
    ocMask = ((X - odX).^2 + (Y - odY).^2) <= (14^2);
    
    for c = 1:3
        layer = img(:, :, c);
        if c == 1
            layer(odMask) = 245; layer(ocMask) = 255;
        elseif c == 2
            layer(odMask) = 205; layer(ocMask) = 240;
        elseif c == 3
            layer(odMask) = 110; layer(ocMask) = 180;
        end
        img(:, :, c) = layer;
    end
    
    % Fovea
    foveaX = odX + 160; foveaY = odY + 10; foveaRadius = 18;
    foveaMask = ((X - foveaX).^2 + (Y - foveaY).^2) <= (foveaRadius^2);
    for c = 1:3
        layer = img(:, :, c);
        if c == 1, layer(foveaMask) = 130; end
        if c == 2, layer(foveaMask) = 50;  end
        if c == 3, layer(foveaMask) = 15;  end
        img(:, :, c) = layer;
    end
    
    % Vessels
    vesselMask = false(H, W);
    t = 0:0.02:2*pi;
    utX = odX + 80 * t; utY = odY - 100 * sin(t * 0.8) - 15 * t;
    ltX = odX + 80 * t; ltY = odY + 100 * sin(t * 0.8) + 15 * t;
    unX = odX - 50 * t; unY = odY - 60 * sin(t * 0.9) - 10 * t;
    lnX = odX - 50 * t; lnY = odY + 60 * sin(t * 0.9) + 10 * t;
    
    % Tortuous vessel
    tortX = odX + 120 + 20 * sin(t * 8.0); tortY = odY + 80 + 30 * t;
    
    % Draw on mask
    vesselMask = draw_curve_app(vesselMask, utX, utY, 4.0, H, W);
    vesselMask = draw_curve_app(vesselMask, ltX, ltY, 3.5, H, W);
    vesselMask = draw_curve_app(vesselMask, unX, unY, 3.0, H, W);
    vesselMask = draw_curve_app(vesselMask, lnX, lnY, 2.5, H, W);
    vesselMask = draw_curve_app(vesselMask, tortX, tortY, 2.0, H, W);
    vesselMask = vesselMask & fovMask;
    
    for c = 1:3
        layer = double(img(:, :, c));
        if c == 1, layer(vesselMask) = layer(vesselMask) * 0.55; end
        if c == 2, layer(vesselMask) = layer(vesselMask) * 0.25; end
        if c == 3, layer(vesselMask) = layer(vesselMask) * 0.15; end
        img(:, :, c) = uint8(layer);
    end
    
    % Exudates
    exudates = [350, 160; 370, 150; 360, 180; 390, 170; 240, 130];
    for idx = 1:size(exudates, 1)
        cx = exudates(idx, 1); cy = exudates(idx, 2);
        spotMask = ((X - cx).^2 + (Y - cy).^2) <= (randi([2, 5])^2);
        for c = 1:3
            layer = img(:, :, c);
            if c == 1, layer(spotMask) = 245; end
            if c == 2, layer(spotMask) = 240; end
            if c == 3, layer(spotMask) = 90;  end
            img(:, :, c) = layer;
        end
    end
    
    % Microaneurysms
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
    
    % Hemorrhages
    hems = [260, 340; 270, 350; 380, 330];
    for idx = 1:size(hems, 1)
        cx = hems(idx, 1); cy = hems(idx, 2);
        spotMask = ((X - cx).^2 + (Y - cy).^2) <= (randi([6, 12])^2);
        spotMask = imdilate(spotMask, strel('disk', 2));
        for c = 1:3
            layer = img(:, :, c);
            if c == 1, layer(spotMask) = 100; end
            if c == 2, layer(spotMask) = 25;  end
            if c == 3, layer(spotMask) = 10;  end
            img(:, :, c) = layer;
        end
    end
    
    % Add background noise & gaussian filter
    noise = randn(H, W) * 2;
    for c = 1:3
        layer = double(img(:, :, c)) + noise;
        img(:, :, c) = uint8(min(255, max(0, layer)));
    end
    img = imgaussfilt(img, 0.6);
    for c = 1:3
        layer = img(:, :, c);
        layer(~fovMask) = 0;
        img(:, :, c) = layer;
    end
end

function mask = draw_curve_app(mask, px, py, thickness, H, W)
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

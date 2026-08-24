function retina_segmentation_app()
% RETINA_SEGMENTATION_APP Advanced Interactive UI Dashboard for RetinaScan Module 3.
%
% Features:
%   1. Real-time Multi-Layer Visibility Checkboxes (Vessels, Disc, Cup, Fovea, Lesions).
%   2. Live Alpha-Blending Transparency Slider (0% to 100%).
%   3. Side-by-Side Dual Synchronized Viewports (Original vs Analysis).
%   4. Embedded Vessel Abnormality Score Graphical Breakdown Chart.
%   5. 4 Clinical Case Presets (Normal, Mild DR, Severe DR, High Tortuosity).
%   6. Interactive Click-to-Probe / Diagnostic Inspector for pixel annotations.
%   7. One-Click Clinical Screening Report Exporter (PNG).

    % Create the main UI Figure
    fig = uifigure('Name', 'RetinaScan — Retinal & Lesion Segmentation Interactive Dashboard', ...
                   'Position', [50, 50, 1380, 880], ...
                   'Color', [0.10, 0.10, 0.12]); % Sleek medical dark mode
               
    % Main Layout (1 row, 2 columns: 380px Sidebar, 1x Visualization Canvas)
    mainGrid = uigridlayout(fig, [1, 2]);
    mainGrid.ColumnWidth = {400, '1x'};
    mainGrid.RowHeight = {'1x'};
    mainGrid.BackgroundColor = [0.10, 0.10, 0.12];

    % --- STATE VARIABLES ---
    currentImage = [];
    resultsData = [];
    overlayNormal = [];
    overlayTort = [];
    currentPreset = 'Normal';
    
    % --- SIDEBAR CONTROL PANEL (SCROLLABLE) ---
    controlPanel = uipanel(mainGrid, 'Title', 'RETINASCAN CONTROL & DIAGNOSTICS', ...
                           'BackgroundColor', [0.14, 0.14, 0.16], ...
                           'ForegroundColor', [0.0, 0.8, 1.0], ...
                           'FontWeight', 'bold', 'FontSize', 11, ...
                           'Scrollable', 'on');
    controlPanel.Layout.Column = 1;
    
    controlGrid = uigridlayout(controlPanel, [14, 1]);
    controlGrid.RowHeight = {35, 35, 45, 40, 45, 120, 110, 150, 110, 110, 110, 130, 40, 40};
    controlGrid.BackgroundColor = [0.14, 0.14, 0.16];
    
    % 1. Header Banner
    lblTitle = uilabel(controlGrid, 'Text', 'RetinaScan XAI Screening', ...
                       'FontWeight', 'bold', 'FontSize', 15, ...
                       'TextColor', [0.0, 0.9, 1.0], ...
                       'HorizontalAlignment', 'center');
    lblTitle.Layout.Row = 1;
    
    % 2. Clinical Case Preset Dropdown
    presetGrid = uigridlayout(controlGrid, [1, 2]);
    presetGrid.ColumnWidth = {110, '1x'};
    presetGrid.Padding = [0 0 0 0];
    presetGrid.BackgroundColor = [0.14, 0.14, 0.16];
    presetGrid.Layout.Row = 2;
    
    uilabel(presetGrid, 'Text', 'Case Preset:', 'TextColor', [0.8, 0.8, 0.8], 'FontWeight', 'bold');
    ddPreset = uidropdown(presetGrid, ...
        'Items', {'Normal Healthy Retina', 'Mild NPDR (Early MAs)', 'Severe DR (Exudates + Hems)', 'High Vessel Tortuosity'}, ...
        'Value', 'Normal Healthy Retina', ...
        'BackgroundColor', [0.2, 0.22, 0.26], 'FontColor', [1 1 1], ...
        'ValueChangedFcn', @(src,~) preset_change_callback(src.Value));
    
    % 3. Action Buttons (Load Image & Run Pipeline)
    btnGrid = uigridlayout(controlGrid, [1, 2]);
    btnGrid.ColumnWidth = {'1x', '1x'};
    btnGrid.Padding = [0 0 0 0];
    btnGrid.BackgroundColor = [0.14, 0.14, 0.16];
    btnGrid.Layout.Row = 3;
    
    btnLoad = uibutton(btnGrid, 'push', 'Text', '📁 Load Image', ...
                       'BackgroundColor', [0.22, 0.25, 0.32], ...
                       'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                       'ButtonPushedFcn', @(~,~) load_image_callback());
                   
    btnRun = uibutton(btnGrid, 'push', 'Text', '⚡ Run Analysis', ...
                      'BackgroundColor', [0.0, 0.65, 0.85], ...
                      'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                      'ButtonPushedFcn', @(~,~) run_analysis_callback());
                  
    % 4. Sensitivity & Parameter Sliders
    sensGrid = uigridlayout(controlGrid, [2, 1]);
    sensGrid.RowHeight = {15, 20};
    sensGrid.Padding = [0 0 0 0];
    sensGrid.BackgroundColor = [0.14, 0.14, 0.16];
    sensGrid.Layout.Row = 4;
    
    lblSens = uilabel(sensGrid, 'Text', 'Vessel Sensitivity: 0.50', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 10);
    sldSens = uislider(sensGrid, 'Limits', [0.0, 1.0], 'Value', 0.50, ...
                       'FontColor', [0.8, 0.8, 0.8], ...
                       'ValueChangedFcn', @(~,~) update_sensitivity_label());
                   
    % 5. Layer Overlay Alpha Transparency Slider
    alphaGrid = uigridlayout(controlGrid, [2, 1]);
    alphaGrid.RowHeight = {15, 20};
    alphaGrid.Padding = [0 0 0 0];
    alphaGrid.BackgroundColor = [0.14, 0.14, 0.16];
    alphaGrid.Layout.Row = 5;
    
    lblAlpha = uilabel(alphaGrid, 'Text', 'Overlay Opacity (Alpha): 60%', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 10);
    sldAlpha = uislider(alphaGrid, 'Limits', [0.0, 1.0], 'Value', 0.60, ...
                        'FontColor', [0.8, 0.8, 0.8], ...
                        'ValueChangedFcn', @(~,~) render_custom_overlay());
                    
    % 6. Interactive Multi-Layer Toggle Checkboxes
    layerPanel = uipanel(controlGrid, 'Title', 'Interactive Layer Toggles', ...
                         'BackgroundColor', [0.18, 0.18, 0.22], ...
                         'ForegroundColor', [0.0, 0.9, 1.0], ...
                         'FontWeight', 'bold', 'FontSize', 10);
    layerPanel.Layout.Row = 6;
    layerGrid = uigridlayout(layerPanel, [3, 2]);
    layerGrid.RowHeight = {22, 22, 22};
    layerGrid.ColumnWidth = {'1x', '1x'};
    layerGrid.Padding = [4 4 4 4];
    layerGrid.BackgroundColor = [0.18, 0.18, 0.22];
    
    cbVessels = uicheckbox(layerGrid, 'Text', 'Vessels (Green)', 'Value', true, ...
                          'FontColor', [0.2, 1.0, 0.4], 'ValueChangedFcn', @(~,~) render_custom_overlay());
    cbDisc = uicheckbox(layerGrid, 'Text', 'Optic Disc (Blue)', 'Value', true, ...
                       'FontColor', [0.2, 0.7, 1.0], 'ValueChangedFcn', @(~,~) render_custom_overlay());
    cbCup = uicheckbox(layerGrid, 'Text', 'Optic Cup (Cyan)', 'Value', true, ...
                      'FontColor', [0.0, 1.0, 0.9], 'ValueChangedFcn', @(~,~) render_custom_overlay());
    cbFovea = uicheckbox(layerGrid, 'Text', 'Fovea (Purple)', 'Value', true, ...
                        'FontColor', [0.9, 0.4, 1.0], 'ValueChangedFcn', @(~,~) render_custom_overlay());
    cbExudates = uicheckbox(layerGrid, 'Text', 'Exudates (Yellow)', 'Value', true, ...
                           'FontColor', [1.0, 0.9, 0.2], 'ValueChangedFcn', @(~,~) render_custom_overlay());
    cbDarkLesions = uicheckbox(layerGrid, 'Text', 'MA / Hems (Red)', 'Value', true, ...
                              'FontColor', [1.0, 0.3, 0.3], 'ValueChangedFcn', @(~,~) render_custom_overlay());
                          
    % 7. Vessel Abnormality Indicator Gauge & Score
    scorePanel = uipanel(controlGrid, 'Title', 'Vessel Abnormality Score (Differentiator)', ...
                         'BackgroundColor', [0.18, 0.18, 0.22], ...
                         'ForegroundColor', [1.0, 0.8, 0.2], ...
                         'FontWeight', 'bold', 'FontSize', 10);
    scorePanel.Layout.Row = 7;
    scoreGrid = uigridlayout(scorePanel, [2, 1]);
    scoreGrid.RowHeight = {24, 40};
    scoreGrid.Padding = [4 4 4 4];
    scoreGrid.BackgroundColor = [0.18, 0.18, 0.22];
    
    lblScore = uilabel(scoreGrid, 'Text', 'Abnormality Score: -- / 100', ...
                        'FontWeight', 'bold', 'FontSize', 14, ...
                        'TextColor', [1.0, 0.85, 0.1]);
    lblScore.Layout.Row = 1;
    
    lblInterpretation = uilabel(scoreGrid, 'WordWrap', 'on', ...
                                 'Text', 'Classification: Run analysis to calculate.', ...
                                 'FontSize', 10, 'TextColor', [0.85, 0.85, 0.85]);
    lblInterpretation.Layout.Row = 2;
    
    % 8. Score Breakdown Mini-Bar Chart (Embedded Axes)
    chartPanel = uipanel(controlGrid, 'Title', 'Score Weight Breakdown', ...
                         'BackgroundColor', [0.14, 0.14, 0.16], ...
                         'ForegroundColor', [0.9, 0.9, 0.9], 'FontSize', 9);
    chartPanel.Layout.Row = 8;
    chartGrid = uigridlayout(chartPanel, [1, 1]);
    chartGrid.Padding = [2 2 2 2];
    chartGrid.BackgroundColor = [0.14, 0.14, 0.16];
    
    axChart = uiaxes(chartGrid, 'Color', [0.14, 0.14, 0.16], ...
                     'XColor', [0.7 0.7 0.7], 'YColor', [0.7 0.7 0.7]);
    title(axChart, 'Weights: Tort (50%), Branch (25%), Width (25%)', 'FontSize', 8, 'Color', [0.8 0.8 0.8]);
    
    % 9. Vascular Metrics Panel
    vesPanel = uipanel(controlGrid, 'Title', 'Vascular Network Features', ...
                       'BackgroundColor', [0.16, 0.16, 0.18], 'ForegroundColor', [0.8, 0.95, 0.8]);
    vesPanel.Layout.Row = 9;
    vesGrid = uigridlayout(vesPanel, [4, 1]);
    vesGrid.RowHeight = {16, 16, 16, 16};
    vesGrid.Padding = [4 4 4 4];
    vesGrid.BackgroundColor = [0.16, 0.16, 0.18];
    
    lblVesDensity = uilabel(vesGrid, 'Text', 'Vessel Density: --', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 9);
    lblVesLength = uilabel(vesGrid, 'Text', 'Skeleton Length: --', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 9);
    lblVesBranches = uilabel(vesGrid, 'Text', 'Branch Points: --', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 9);
    lblVesWidth = uilabel(vesGrid, 'Text', 'Vessel Width (CV): --', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 9);
    
    % 10. Optic Disc & Fovea Panel
    odPanel = uipanel(controlGrid, 'Title', 'Optic Disc & Fovea Features', ...
                      'BackgroundColor', [0.16, 0.16, 0.18], 'ForegroundColor', [0.8, 0.8, 0.95]);
    odPanel.Layout.Row = 10;
    odGrid = uigridlayout(odPanel, [3, 1]);
    odGrid.RowHeight = {16, 16, 16};
    odGrid.Padding = [4 4 4 4];
    odGrid.BackgroundColor = [0.16, 0.16, 0.18];
    
    lblDiscArea = uilabel(odGrid, 'Text', 'Disc Area: --', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 9);
    lblCupArea = uilabel(odGrid, 'Text', 'Cup Area: --', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 9);
    lblCDR = uilabel(odGrid, 'Text', 'Cup-to-Disc Ratio (CDR): --', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 9);
    
    % 11. Lesion Findings Panel
    lesPanel = uipanel(controlGrid, 'Title', 'Diabetic Lesion Findings', ...
                       'BackgroundColor', [0.16, 0.16, 0.18], 'ForegroundColor', [0.95, 0.8, 0.8]);
    lesPanel.Layout.Row = 11;
    lesGrid = uigridlayout(lesPanel, [3, 1]);
    lesGrid.RowHeight = {16, 16, 16};
    lesGrid.Padding = [4 4 4 4];
    lesGrid.BackgroundColor = [0.16, 0.16, 0.18];
    
    lblExudates = uilabel(lesGrid, 'Text', 'Exudate Candidates: --', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 9);
    lblMAs = uilabel(lesGrid, 'Text', 'Microaneurysms: --', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 9);
    lblHems = uilabel(lesGrid, 'Text', 'Hemorrhages: --', 'TextColor', [0.8, 0.8, 0.8], 'FontSize', 9);
    
    % 12. Algorithmic Explanations Text Area
    expPanel = uipanel(controlGrid, 'Title', 'XAI Reasoning Summary', ...
                       'BackgroundColor', [0.12, 0.12, 0.14], 'ForegroundColor', [0.9, 0.9, 0.9]);
    expPanel.Layout.Row = 12;
    expGrid = uigridlayout(expPanel, [1, 1]);
    expGrid.Padding = [2 2 2 2];
    expGrid.BackgroundColor = [0.12, 0.12, 0.14];
    
    txtExplain = uitextarea(expGrid, 'Editable', 'off', ...
                            'BackgroundColor', [0.08, 0.08, 0.10], ...
                            'FontColor', [0.8, 0.8, 0.8], 'FontSize', 9, ...
                            'Value', {'Run analysis to generate explainability report.'});
                        
    % 13. Export Report Button
    btnExport = uibutton(controlGrid, 'push', 'Text', '📄 Export Screening Report (PNG)', ...
                         'BackgroundColor', [0.2, 0.45, 0.35], ...
                         'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                         'ButtonPushedFcn', @(~,~) export_report_callback());
    btnExport.Layout.Row = 13;
    
    % 14. Probe Tooltip / Inspector Status
    lblProbe = uilabel(controlGrid, 'Text', 'Inspector: Click image to inspect pixel & pathology.', ...
                       'FontAngle', 'italic', 'FontSize', 9, 'TextColor', [0.7, 0.7, 0.7]);
    lblProbe.Layout.Row = 14;

    % --- RIGHT VISUALIZATION CANVAS (DUAL VIEWPORT) ---
    displayGrid = uigridlayout(mainGrid, [2, 1]);
    displayGrid.RowHeight = {45, '1x'};
    displayGrid.Layout.Column = 2;
    displayGrid.BackgroundColor = [0.10, 0.10, 0.12];
    
    % Top Navigation / View Mode Selectors
    topNavPanel = uipanel(displayGrid, 'BackgroundColor', [0.14, 0.14, 0.16], 'BorderType', 'none');
    topNavPanel.Layout.Row = 1;
    topNavGrid = uigridlayout(topNavPanel, [1, 5]);
    topNavGrid.ColumnWidth = {'1x', '1x', '1x', '1x', '1x'};
    topNavGrid.Padding = [3 3 3 3];
    topNavGrid.BackgroundColor = [0.14, 0.14, 0.16];
    
    btnModeSingle = uibutton(topNavGrid, 'state', 'Text', 'Single View', 'Value', true, ...
                             'BackgroundColor', [0.22, 0.25, 0.32], 'FontColor', [1 1 1], ...
                             'ValueChangedFcn', @(src,~) switch_view_mode(src, 'single'));
    btnModeDual = uibutton(topNavGrid, 'state', 'Text', 'Dual Side-by-Side', 'Value', false, ...
                           'BackgroundColor', [0.16, 0.16, 0.18], 'FontColor', [0.8 0.8 0.8], ...
                           'ValueChangedFcn', @(src,~) switch_view_mode(src, 'dual'));
    btnTabOverlay = uibutton(topNavGrid, 'state', 'Text', 'Composite Overlay', 'Value', true, ...
                             'BackgroundColor', [0.22, 0.25, 0.32], 'FontColor', [1 1 1], ...
                             'ValueChangedFcn', @(src,~) switch_tab_mode(src, 'overlay'));
    btnTabTort = uibutton(topNavGrid, 'state', 'Text', 'Vessel Tortuosity', 'Value', false, ...
                          'BackgroundColor', [0.16, 0.16, 0.18], 'FontColor', [0.8 0.8 0.8], ...
                          'ValueChangedFcn', @(src,~) switch_tab_mode(src, 'tortuosity'));
    btnTabLesions = uibutton(topNavGrid, 'state', 'Text', 'Lesions Only', 'Value', false, ...
                            'BackgroundColor', [0.16, 0.16, 0.18], 'FontColor', [0.8 0.8 0.8], ...
                            'ValueChangedFcn', @(src,~) switch_tab_mode(src, 'lesions'));

    % Viewport Panel containing Axes
    viewportPanel = uipanel(displayGrid, 'BackgroundColor', [0.08, 0.08, 0.10], 'BorderType', 'none');
    viewportPanel.Layout.Row = 2;
    viewportGrid = uigridlayout(viewportPanel, [1, 2]);
    viewportGrid.ColumnWidth = {'1x', 0}; % Start in single mode (Right axis hidden)
    viewportGrid.Padding = [4 4 4 4];
    viewportGrid.BackgroundColor = [0.08, 0.08, 0.10];
    
    % Primary Viewport Axes
    axLeft = uiaxes(viewportGrid, 'Color', [0.08, 0.08, 0.10]);
    axLeft.XAxis.Visible = 'off';
    axLeft.YAxis.Visible = 'off';
    title(axLeft, 'Primary Viewport', 'Color', [0.8 0.8 0.8], 'FontSize', 11);
    
    % Secondary Viewport Axes (Dual Mode)
    axRight = uiaxes(viewportGrid, 'Color', [0.08, 0.08, 0.10]);
    axRight.XAxis.Visible = 'off';
    axRight.YAxis.Visible = 'off';
    title(axRight, 'Comparison Viewport (Original)', 'Color', [0.8 0.8 0.8], 'FontSize', 11);
    
    % Enable Click-to-Probe callback on axes
    axLeft.ButtonDownFcn = @(src, event) probe_pixel_callback(event);

    % --- INITIALIZE WITH DEFAULT PRESET ---
    load_preset_image('Normal Healthy Retina');
    run_analysis_callback();

    % =========================================================================
    % CALLBACK FUNCTIONS
    % =========================================================================
    
    function update_sensitivity_label()
        lblSens.Text = sprintf('Vessel Sensitivity: %.2f', sldSens.Value);
    end

    function preset_change_callback(selectedPreset)
        currentPreset = selectedPreset;
        load_preset_image(selectedPreset);
        run_analysis_callback();
    end

    function load_preset_image(presetName)
        switch presetName
            case 'Normal Healthy Retina'
                currentImage = generate_preset_fundus('normal');
            case 'Mild NPDR (Early MAs)'
                currentImage = generate_preset_fundus('mild_dr');
            case 'Severe DR (Exudates + Hems)'
                currentImage = generate_preset_fundus('severe_dr');
            case 'High Vessel Tortuosity'
                currentImage = generate_preset_fundus('tortuous');
        end
    end

    function load_image_callback()
        [file, path] = uigetfile({'*.jpg;*.jpeg;*.png;*.tif;*.tiff', 'Fundus Image (*.jpg, *.png, *.tif)'}, ...
                                'Select retinal fundus image');
        if isequal(file, 0), return; end
        
        imgPath = fullfile(path, file);
        try
            currentImage = imread(imgPath);
            ddPreset.Value = 'Normal Healthy Retina';
            run_analysis_callback();
        catch ME
            uialert(fig, sprintf('Failed to load image: %s', ME.message), 'Image Load Error');
        end
    end

    function run_analysis_callback()
        if isempty(currentImage), return; end
        
        btnRun.Enable = 'off';
        btnRun.Text = '🔄 Processing...';
        drawnow;
        
        options = struct();
        options.vesselSensitivity = sldSens.Value;
        options.enableLesions = true;
        
        try
            [resultsData, overlayNormal] = segment_retina(currentImage, options);
            overlayTort = create_segmentation_overlay(currentImage, resultsData, 'tortuosity');
            
            % Update displays & score breakdown chart
            render_custom_overlay();
            update_metrics();
            update_breakdown_chart();
            
        catch ME
            uialert(fig, sprintf('Analysis error: %s', ME.message), 'Processing Error');
        end
        
        btnRun.Enable = 'on';
        btnRun.Text = '⚡ Run Analysis';
    end

    function render_custom_overlay()
        if isempty(resultsData), return; end
        
        alphaVal = sldAlpha.Value;
        lblAlpha.Text = sprintf('Overlay Opacity (Alpha): %d%%', round(alphaVal * 100));
        
        % Build dynamic custom overlay according to checkboxes
        customMaskStruct = resultsData;
        if ~cbVessels.Value, customMaskStruct.vesselMask = false(size(resultsData.vesselMask)); end
        if ~cbDisc.Value, customMaskStruct.opticDiscMask = false(size(resultsData.opticDiscMask)); end
        if ~cbCup.Value, customMaskStruct.opticCupMask = false(size(resultsData.opticCupMask)); end
        if ~cbFovea.Value, customMaskStruct.foveaMask = false(size(resultsData.foveaMask)); end
        if ~cbExudates.Value, customMaskStruct.exudateMask = false(size(resultsData.exudateMask)); end
        if ~cbDarkLesions.Value
            customMaskStruct.microaneurysmMask = false(size(resultsData.microaneurysmMask));
            customMaskStruct.hemorrhageMask = false(size(resultsData.hemorrhageMask));
        end
        
        % Generate dynamic blended overlay
        if btnTabTort.Value
            dynOverlay = create_segmentation_overlay(currentImage, customMaskStruct, 'tortuosity');
        elseif btnTabLesions.Value
            % Black background with colored lesions
            H = size(currentImage, 1); W = size(currentImage, 2);
            dynOverlay = zeros(H, W, 3, 'uint8');
            if cbExudates.Value
                dynOverlay = apply_mask_color(dynOverlay, resultsData.exudateMask, [255 255 0]);
            end
            if cbDarkLesions.Value
                dynOverlay = apply_mask_color(dynOverlay, resultsData.microaneurysmMask, [255 165 0]);
                dynOverlay = apply_mask_color(dynOverlay, resultsData.hemorrhageMask, [255 0 0]);
            end
        else
            dynOverlay = create_segmentation_overlay(currentImage, customMaskStruct, 'normal');
        end
        
        % Draw on Left Axis
        imshow(dynOverlay, 'Parent', axLeft);
        title(axLeft, 'Interactive RetinaScan Viewport', 'Color', [0.0 0.9 1.0], 'FontSize', 11);
        
        % Draw on Right Axis (if dual mode)
        if btnModeDual.Value
            imshow(currentImage, 'Parent', axRight);
            title(axRight, 'Reference Fundus Viewport', 'Color', [0.8 0.8 0.8], 'FontSize', 11);
        end
    end

    function imgOut = apply_mask_color(imgIn, mask, rgbColor)
        imgOut = imgIn;
        for ch = 1:3
            layer = imgOut(:, :, ch);
            layer(mask) = rgbColor(ch);
            imgOut(:, :, ch) = layer;
        end
    end

    function switch_view_mode(clickedBtn, modeName)
        btnModeSingle.Value = strcmp(modeName, 'single');
        btnModeDual.Value = strcmp(modeName, 'dual');
        
        reset_btn_color(btnModeSingle);
        reset_btn_color(btnModeDual);
        
        if strcmp(modeName, 'dual')
            viewportGrid.ColumnWidth = {'1x', '1x'};
        else
            viewportGrid.ColumnWidth = {'1x', 0};
        end
        render_custom_overlay();
    end

    function switch_tab_mode(clickedBtn, tabName)
        btnTabOverlay.Value = strcmp(tabName, 'overlay');
        btnTabTort.Value = strcmp(tabName, 'tortuosity');
        btnTabLesions.Value = strcmp(tabName, 'lesions');
        
        reset_btn_color(btnTabOverlay);
        reset_btn_color(btnTabTort);
        reset_btn_color(btnTabLesions);
        
        render_custom_overlay();
    end

    function reset_btn_color(btn)
        if btn.Value
            btn.BackgroundColor = [0.22, 0.25, 0.32];
            btn.FontColor = [1 1 1];
        else
            btn.BackgroundColor = [0.16, 0.16, 0.18];
            btn.FontColor = [0.8 0.8 0.8];
        end
    end

    function update_metrics()
        f = resultsData.features;
        
        % Abnormality Score & Interpretation
        lblScore.Text = sprintf('Abnormality Score: %.1f / 100', f.vesselAbnormalityScore);
        if f.vesselAbnormalityScore <= 30
            lblScore.TextColor = [0.2, 0.9, 0.4]; % Green
        elseif f.vesselAbnormalityScore <= 60
            lblScore.TextColor = [1.0, 0.65, 0.1]; % Orange
        else
            lblScore.TextColor = [1.0, 0.25, 0.25]; % Red
        end
        lblInterpretation.Text = sprintf('Classification: %s', resultsData.vesselAnalysis.interpretation);
        
        % Features
        lblVesDensity.Text = sprintf('Vessel Density: %.2f%% | Skeleton: %d px', f.vesselDensity * 100, int32(f.skeletonLength));
        lblVesBranches.Text = sprintf('Branch Points: %d (Density: %.1f/Mpx)', int32(f.branchPointCount), f.branchingDensity);
        lblVesWidth.Text = sprintf('Vessel Width: %.2f px (Irreg CV: %.2f)', f.meanVesselWidth, f.vesselWidthCV);
        
        lblDiscArea.Text = sprintf('Optic Disc Area: %d pixels', int32(f.opticDiscArea));
        lblCupArea.Text = sprintf('Optic Cup Area: %d pixels', int32(f.opticCupArea));
        lblCDR.Text = sprintf('Cup-to-Disc Ratio (CDR): %.3f', f.cupToDiscRatio);
        
        lblExudates.Text = sprintf('Exudates: %d detected (Area: %d px)', int32(f.exudateCount), int32(f.exudateArea));
        lblMAs.Text = sprintf('Microaneurysms: %d candidates', int32(f.microaneurysmCount));
        lblHems.Text = sprintf('Hemorrhages: %d candidate pools', int32(f.hemorrhageCount));
        
        % Explanations
        exp = resultsData.explanations;
        txtExplain.Value = {
            'EXPLAINABLE REASONING REPORT:';
            ['• Vessel Network: ' exp.vessel];
            ['• Optic Disc/Cup: ' exp.opticDisc ' ' exp.opticCup];
            ['• Fovea Location: ' exp.fovea];
            ['• Exudate Findings: ' exp.exudates];
            ['• Microaneurysms: ' exp.microaneurysms];
            ['• Hemorrhage Findings: ' exp.hemorrhages];
            ['• Abnormality Score: ' exp.vesselScore]
        };
    end

    function update_breakdown_chart()
        f = resultsData.features;
        cla(axChart);
        
        categories = {'Tortuosity (50%)', 'Branching (25%)', 'Width Var (25%)', 'Combined Score'};
        scores = [f.tortuosityScore, f.branchingScore, f.widthIrregularityScore, f.vesselAbnormalityScore];
        
        b = barh(axChart, 1:4, scores, 'FaceColor', 'flat');
        b.CData(1, :) = [0.2, 0.8, 0.4];
        b.CData(2, :) = [0.2, 0.6, 0.9];
        b.CData(3, :) = [0.9, 0.7, 0.2];
        b.CData(4, :) = [1.0, 0.4, 0.3];
        
        axChart.YTick = 1:4;
        axChart.YTickLabel = categories;
        axChart.XLim = [0, 100];
        axChart.FontSize = 8;
    end

    function probe_pixel_callback(event)
        if isempty(resultsData), return; end
        
        coords = round(event.IntersectionPoint(1:2));
        x = coords(1); y = coords(2);
        [H, W, ~] = size(currentImage);
        
        if x < 1 || x > W || y < 1 || y > H
            lblProbe.Text = 'Inspector: Clicked outside valid image bounds.';
            return;
        end
        
        % Check findings at (y, x)
        finding = 'Background / Normal Retina';
        if resultsData.exudateMask(y, x)
            finding = '⚠️ Hard Exudate Candidate';
        elseif resultsData.microaneurysmMask(y, x)
            finding = '⚠️ Microaneurysm Candidate (MA)';
        elseif resultsData.hemorrhageMask(y, x)
            finding = '⚠️ Retinal Hemorrhage Pool';
        elseif resultsData.opticCupMask(y, x)
            finding = '👁️ Optic Cup (Central Excavation)';
        elseif resultsData.opticDiscMask(y, x)
            finding = '👁️ Optic Disc Region';
        elseif resultsData.vesselMask(y, x)
            finding = '🩸 Retinal Blood Vessel';
        elseif resultsData.foveaMask(y, x)
            finding = '🎯 Macula / Fovea Center';
        end
        
        rgb = currentImage(y, x, :);
        lblProbe.Text = sprintf('Inspector [%d, %d]: %s (RGB: %d, %d, %d)', x, y, finding, rgb(1), rgb(2), rgb(3));
    end

    function export_report_callback()
        if isempty(resultsData)
            uialert(fig, 'Run analysis before exporting report.', 'No Data');
            return;
        end
        
        [file, path] = uiputfile('RetinaScan_Screening_Report.png', 'Save Clinical Screening Report');
        if isequal(file, 0), return; end
        
        savePath = fullfile(path, file);
        % Create export summary canvas
        repFig = figure('Visible', 'off', 'Position', [100 100 1000 650], 'Color', [1 1 1]);
        
        subplot(1, 2, 1);
        imshow(create_segmentation_overlay(currentImage, resultsData, 'normal'));
        title('RetinaScan Segmentation Overlay', 'FontSize', 12, 'FontWeight', 'bold');
        
        subplot(1, 2, 2);
        axis off;
        f = resultsData.features;
        text(0.05, 0.95, 'RetinaScan AI Screening Report', 'FontSize', 16, 'FontWeight', 'bold', 'Color', [0 0.4 0.7]);
        text(0.05, 0.88, sprintf('Timestamp: %s', datestr(now)), 'FontSize', 9, 'FontAngle', 'italic');
        text(0.05, 0.80, sprintf('Vessel Abnormality Score: %.1f / 100', f.vesselAbnormalityScore), 'FontSize', 13, 'FontWeight', 'bold', 'Color', [0.8 0.2 0]);
        text(0.05, 0.72, sprintf('Classification: %s', resultsData.vesselAnalysis.interpretation), 'FontSize', 11, 'FontWeight', 'bold');
        
        text(0.05, 0.60, sprintf('Vascular Density: %.2f%%', f.vesselDensity * 100), 'FontSize', 10);
        text(0.05, 0.54, sprintf('Vessel Branch Points: %d', int32(f.branchPointCount)), 'FontSize', 10);
        text(0.05, 0.48, sprintf('Vessel Mean Tortuosity: %.3f', f.meanTortuosity), 'FontSize', 10);
        text(0.05, 0.42, sprintf('Cup-to-Disc Ratio (CDR): %.3f', f.cupToDiscRatio), 'FontSize', 10);
        text(0.05, 0.36, sprintf('Hard Exudates Count: %d', int32(f.exudateCount)), 'FontSize', 10);
        text(0.05, 0.30, sprintf('Microaneurysms Count: %d', int32(f.microaneurysmCount)), 'FontSize', 10);
        text(0.05, 0.24, sprintf('Hemorrhages Count: %d', int32(f.hemorrhageCount)), 'FontSize', 10);
        
        text(0.05, 0.08, 'Disclaimer: Research prototype for SIH260038. Not a diagnostic device.', 'FontSize', 8, 'FontAngle', 'italic', 'Color', [0.5 0.5 0.5]);
        
        saveas(repFig, savePath);
        close(repFig);
        uialert(fig, sprintf('Screening report saved successfully to:\n%s', savePath), 'Report Exported');
    end
end

% =========================================================================
% PRESET SYNTHETIC FUNDUS GENERATOR
% =========================================================================
function img = generate_preset_fundus(presetType)
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
    
    % Shading
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
        if c == 1, layer(odMask) = 245; layer(ocMask) = 255; end
        if c == 2, layer(odMask) = 205; layer(ocMask) = 240; end
        if c == 3, layer(odMask) = 110; layer(ocMask) = 180; end
        img(:, :, c) = layer;
    end
    
    % Fovea
    foveaX = odX + 160; foveaY = odY + 10;
    foveaMask = ((X - foveaX).^2 + (Y - foveaY).^2) <= (18^2);
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
    
    if strcmp(presetType, 'tortuous')
        tortX = odX + 100 + 35 * sin(t * 12.0);
        tortY = odY + 40 + 40 * t;
        vesselMask = draw_curve_preset(vesselMask, tortX, tortY, 4.0, H, W);
    else
        tortX = odX + 120 + 15 * sin(t * 6.0);
        tortY = odY + 80 + 30 * t;
        vesselMask = draw_curve_preset(vesselMask, tortX, tortY, 2.0, H, W);
    end
    
    vesselMask = draw_curve_preset(vesselMask, utX, utY, 4.0, H, W);
    vesselMask = draw_curve_preset(vesselMask, ltX, ltY, 3.5, H, W);
    vesselMask = draw_curve_preset(vesselMask, unX, unY, 3.0, H, W);
    vesselMask = draw_curve_preset(vesselMask, lnX, lnY, 2.5, H, W);
    vesselMask = vesselMask & fovMask;
    
    for c = 1:3
        layer = double(img(:, :, c));
        if c == 1, layer(vesselMask) = layer(vesselMask) * 0.55; end
        if c == 2, layer(vesselMask) = layer(vesselMask) * 0.25; end
        if c == 3, layer(vesselMask) = layer(vesselMask) * 0.15; end
        img(:, :, c) = uint8(layer);
    end
    
    % Lesions based on preset
    exudates = []; mas = []; hems = [];
    switch presetType
        case 'mild_dr'
            mas = [280, 270; 300, 290; 320, 280; 340, 290; 310, 310];
            exudates = [370, 150; 360, 180];
        case 'severe_dr'
            exudates = [350, 160; 370, 150; 360, 180; 390, 170; 240, 130; 380, 210; 400, 220; 340, 190];
            mas = [280, 270; 300, 290; 320, 280; 340, 290; 310, 310; 330, 260; 350, 300];
            hems = [260, 340; 270, 350; 380, 330; 290, 360; 310, 380];
        case 'tortuous'
            mas = [310, 290];
    end
    
    % Draw Exudates
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
    
    % Draw MAs
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
    
    % Draw Hemorrhages
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
    
    % Add mild noise & blur
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

function mask = draw_curve_preset(mask, px, py, thickness, H, W)
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

function [fig_handle, summary_canvas_img] = build_summary_figure(screening_data, xai_maps, clinical_text, save_path)
% BUILD_SUMMARY_FIGURE Creates a 2x3 multi-panel diagnostic summary canvas.
%
% Inputs:
%   screening_data    - Struct with images, metadata, dr_grading_result
%   xai_maps          - Struct with gradcam_overlay, lesion_overlay
%   clinical_text     - Struct with diagnostic_summary, recommendations
%   save_path         - (Optional) Filepath to export PNG image
%
% Outputs:
%   fig_handle        - Figure handle
%   summary_canvas_img - RGB matrix of the combined 2x3 grid canvas

    if nargin < 4; save_path = ''; end

    % Create invisible figure for headless / automated execution
    fig_handle = figure('Visible', 'off', 'Position', [100, 100, 1200, 800], 'Color', [0.96, 0.96, 0.98]);

    % Panel 1: Raw Fundus Image
    subplot(2, 3, 1);
    imshow(screening_data.raw_image);
    title('1. Raw Fundus Image', 'FontSize', 12, 'FontWeight', 'bold');
    
    % Panel 2: Enhanced Fundus Image
    subplot(2, 3, 2);
    imshow(screening_data.enhanced_image);
    title('2. Enhanced Image (Module 2)', 'FontSize', 12, 'FontWeight', 'bold');
    
    % Panel 3: Lesion Segmentation Overlay
    subplot(2, 3, 3);
    imshow(xai_maps.lesion_overlay);
    title('3. Lesion Segmentation (Module 3)', 'FontSize', 12, 'FontWeight', 'bold');
    
    % Panel 4: Grad-CAM XAI Heatmap
    subplot(2, 3, 4);
    imshow(xai_maps.gradcam_overlay);
    title('4. Grad-CAM XAI Heatmap (Module 5)', 'FontSize', 12, 'FontWeight', 'bold');
    
    % Panel 5: Class Probabilities Bar Chart
    subplot(2, 3, 5);
    probs = screening_data.dr_grading_result.class_probabilities;
    b = bar(0:4, probs * 100, 'FaceColor', [0.2, 0.5, 0.8]);
    ylim([0, 100]);
    xlabel('DR Grade (0:Normal ... 4:PDR)', 'FontSize', 10);
    ylabel('Probability (%)', 'FontSize', 10);
    title('5. DR Grade Probabilities', 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    
    % Highlight predicted grade bar
    pred_grade = screening_data.dr_grading_result.predicted_grade;
    hold on;
    bar(pred_grade, probs(pred_grade + 1) * 100, 'FaceColor', [0.85, 0.25, 0.2]);
    hold off;
    
    % Panel 6: Textual Clinical Summary Box
    subplot(2, 3, 6);
    axis off;
    
    summary_box_text = sprintf([ ...
        'PATIENT METADATA:\n' ...
        '  ID: %s  |  Eye: %s\n' ...
        '  Name: %s (Age: %d)\n\n' ...
        'DIAGNOSTIC RESULT:\n' ...
        '  IQA Status: %s (Score: %.2f)\n' ...
        '  Grade: %s\n' ...
        '  Confidence: %.1f%%\n\n' ...
        'RECOMMENDATION:\n' ...
        '  %s' ...
    ], ...
    screening_data.patient_id, screening_data.eye_side, ...
    screening_data.patient_name, screening_data.age, ...
    screening_data.iqa_result.status, screening_data.iqa_result.quality_score, ...
    screening_data.dr_grading_result.grade_label, ...
    screening_data.dr_grading_result.confidence * 100, ...
    clinical_text.recommendations);

    text(0.05, 0.95, summary_box_text, ...
        'Units', 'normalized', ...
        'VerticalAlignment', 'top', ...
        'FontSize', 9.5, ...
        'FontName', 'Courier', ...
        'BackgroundColor', [1, 1, 1], ...
        'EdgeColor', [0.7, 0.7, 0.8], ...
        'Margin', 8);
    title('6. Clinical Summary', 'FontSize', 12, 'FontWeight', 'bold');

    % Capture canvas frame as image matrix
    drawnow;
    frame = getframe(fig_handle);
    summary_canvas_img = frame.cdata;

    % Export to PNG if path provided
    if ~isempty(save_path)
        if exist('exportgraphics', 'file')
            exportgraphics(fig_handle, save_path, 'Resolution', 150);
        else
            imwrite(summary_canvas_img, save_path);
        end
    end
end

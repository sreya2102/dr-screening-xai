function report_data = generate_report(screening_data, output_dir)
% GENERATE_REPORT Primary Module 5 function for XAI map & report generation.
%
% Usage:
%   report_data = generate_report(screening_data)
%   report_data = generate_report(screening_data, 'results/reports')
%
% Inputs:
%   screening_data - Struct containing patient metadata, raw & enhanced images,
%                    IQA results, lesion segmentation masks, and DR grade predictions.
%   output_dir     - (Optional) Directory path to save generated report files.
%
% Output:
%   report_data    - Struct containing generated XAI maps, clinical text,
%                    lesion importance breakdown, summary canvas image, and file paths.

    if nargin < 2 || isempty(output_dir)
        output_dir = fullfile(pwd, 'output_reports');
    end

    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    % 1. Generate XAI Visual Explanation Maps (Grad-CAM, Saliency, Lesion Composite)
    xai_maps = generate_xai_maps(screening_data);

    % 2. Compute Lesion Importance Breakdown
    dr_grade = screening_data.dr_grading_result.predicted_grade;
    lesion_importance = compute_lesion_importance(screening_data.segmentation_results, dr_grade);

    % 3. Synthesize Natural Language Clinical Text & Recommendations
    clinical_text = generate_clinical_text(screening_data.dr_grading_result, ...
                                           screening_data.iqa_result, ...
                                           lesion_importance);

    % 4. Build 2x3 Diagnostic Summary Canvas Figure
    summary_png_path = fullfile(output_dir, sprintf('Summary_Canvas_%s.png', screening_data.patient_id));
    [fig_handle, summary_canvas_img] = build_summary_figure(screening_data, xai_maps, clinical_text, summary_png_path);
    close(fig_handle);

    % 5. Export Standalone HTML Clinical Report
    html_report_path = fullfile(output_dir, sprintf('Screening_Report_%s.html', screening_data.patient_id));
    export_html_report(screening_data, xai_maps, clinical_text, lesion_importance, html_report_path);

    % 6. Save MAT Structured Summary File
    mat_report_path = fullfile(output_dir, sprintf('Report_Data_%s.mat', screening_data.patient_id));
    
    % Assemble master report_data struct
    report_data = struct(...
        'patient_id', screening_data.patient_id, ...
        'patient_name', screening_data.patient_name, ...
        'eye_side', screening_data.eye_side, ...
        'dr_grade', screening_data.dr_grading_result.grade_label, ...
        'confidence', screening_data.dr_grading_result.confidence, ...
        'iqa_status', screening_data.iqa_result.status, ...
        'xai_maps', xai_maps, ...
        'lesion_importance', lesion_importance, ...
        'clinical_text', clinical_text, ...
        'summary_canvas_img', summary_canvas_img, ...
        'report_files', struct(...
            'html_path', html_report_path, ...
            'summary_png_path', summary_png_path, ...
            'mat_path', mat_report_path ...
        )...
    );

    % Save .mat file
    save(mat_report_path, 'report_data');
end

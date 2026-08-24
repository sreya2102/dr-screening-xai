function html_file_path = export_html_report(screening_data, xai_maps, clinical_text, lesion_importance, save_path)
% EXPORT_HTML_REPORT Generates a responsive, standalone clinical HTML screening report.
%
% Inputs:
%   screening_data    - Struct with metadata, images, and grading outputs
%   xai_maps          - Struct with gradcam_overlay and lesion_overlay
%   clinical_text     - Struct with diagnostic summary and recommendations
%   lesion_importance - Struct with counts and percentages
%   save_path         - Filepath to output HTML file
%
% Output:
%   html_file_path    - Full path to created HTML file

    if nargin < 5 || isempty(save_path)
        save_path = fullfile(pwd, sprintf('DR_Screening_Report_%s.html', screening_data.patient_id));
    end

    % Convert images to PNG temporary files or base64 strings
    b64_gradcam = image_to_base64(xai_maps.gradcam_overlay);
    b64_lesion = image_to_base64(xai_maps.lesion_overlay);
    b64_raw = image_to_base64(screening_data.raw_image);

    % Color badges for DR grades
    grade_colors = {'#28a745', '#17a2b8', '#ffc107', '#fd7e14', '#dc3545'};
    dr_grade = screening_data.dr_grading_result.predicted_grade;
    badge_color = grade_colors{min(dr_grade + 1, 5)};

    % Construct HTML document
    fid = fopen(save_path, 'w', 'n', 'UTF-8');
    if fid == -1
        error('Failed to create HTML report file at %s', save_path);
    end

    fprintf(fid, '<!DOCTYPE html>\n<html lang="en">\n<head>\n');
    fprintf(fid, '<meta charset="UTF-8">\n');
    fprintf(fid, '<title>Diabetic Retinopathy Screening Report - %s</title>\n', screening_data.patient_id);
    fprintf(fid, '<style>\n');
    fprintf(fid, '  body { font-family: "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background-color: #f4f7f9; color: #2c3e50; margin: 0; padding: 20px; }\n');
    fprintf(fid, '  .container { max-width: 960px; margin: 0 auto; background: #ffffff; padding: 30px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.08); }\n');
    fprintf(fid, '  .header { display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #eef2f5; padding-bottom: 15px; margin-bottom: 25px; }\n');
    fprintf(fid, '  .header h1 { font-size: 24px; margin: 0; color: #1a365d; }\n');
    fprintf(fid, '  .badge { padding: 6px 14px; border-radius: 20px; color: #fff; font-weight: bold; font-size: 14px; }\n');
    fprintf(fid, '  .section { margin-bottom: 25px; }\n');
    fprintf(fid, '  .section-title { font-size: 18px; font-weight: 600; color: #2b6cb0; border-left: 4px solid #3182ce; padding-left: 10px; margin-bottom: 15px; }\n');
    fprintf(fid, '  .grid-3 { display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px; }\n');
    fprintf(fid, '  .card { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 15px; text-align: center; }\n');
    fprintf(fid, '  .card img { max-width: 100%%; height: auto; border-radius: 6px; border: 1px solid #cbd5e0; }\n');
    fprintf(fid, '  table { width: 100%%; border-collapse: collapse; margin-top: 10px; }\n');
    fprintf(fid, '  th, td { padding: 10px 12px; border: 1px solid #e2e8f0; text-align: left; font-size: 14px; }\n');
    fprintf(fid, '  th { background-color: #edf2f7; color: #4a5568; font-weight: 600; }\n');
    fprintf(fid, '  .recommendation-box { background: #fffaf0; border-left: 5px solid #dd6b20; padding: 15px; border-radius: 4px; margin-top: 15px; }\n');
    fprintf(fid, '  .footer { text-align: center; font-size: 12px; color: #a0aec0; margin-top: 30px; border-top: 1px solid #e2e8f0; padding-top: 15px; }\n');
    fprintf(fid, '</style>\n</head>\n<body>\n');

    fprintf(fid, '<div class="container">\n');
    fprintf(fid, '  <div class="header">\n');
    fprintf(fid, '    <div>\n');
    fprintf(fid, '      <h1>Diabetic Retinopathy Screening & XAI Report</h1>\n');
    fprintf(fid, '      <small>Automated Explainable AI Screening System</small>\n');
    fprintf(fid, '    </div>\n');
    fprintf(fid, '    <div class="badge" style="background-color: %s;">Grade %d: %s</div>\n', badge_color, dr_grade, screening_data.dr_grading_result.grade_label);
    fprintf(fid, '  </div>\n');

    % Patient Details Table
    fprintf(fid, '  <div class="section">\n');
    fprintf(fid, '    <div class="section-title">Patient Information</div>\n');
    fprintf(fid, '    <table>\n');
    fprintf(fid, '      <tr><th>Patient ID</th><td>%s</td><th>Patient Name</th><td>%s</td></tr>\n', screening_data.patient_id, screening_data.patient_name);
    fprintf(fid, '      <tr><th>Age</th><td>%d</td><th>Eye Examined</th><td>%s</td></tr>\n', screening_data.age, screening_data.eye_side);
    fprintf(fid, '      <tr><th>Screening Date</th><td>%s</td><th>Image Quality (IQA)</th><td>%s (Score: %.2f)</td></tr>\n', screening_data.date, screening_data.iqa_result.status, screening_data.iqa_result.quality_score);
    fprintf(fid, '    </table>\n');
    fprintf(fid, '  </div>\n');

    % Visual XAI Grid
    fprintf(fid, '  <div class="section">\n');
    fprintf(fid, '    <div class="section-title">XAI Visual Explanations</div>\n');
    fprintf(fid, '    <div class="grid-3">\n');
    fprintf(fid, '      <div class="card"><h4>Original Fundus Image</h4><img src="data:image/png;base64,%s" alt="Raw Image"></div>\n', b64_raw);
    fprintf(fid, '      <div class="card"><h4>Lesion Segmentation Overlay</h4><img src="data:image/png;base64,%s" alt="Lesion Overlay"></div>\n', b64_lesion);
    fprintf(fid, '      <div class="card"><h4>Grad-CAM Heatmap Overlay</h4><img src="data:image/png;base64,%s" alt="Grad-CAM Overlay"></div>\n', b64_gradcam);
    fprintf(fid, '    </div>\n');
    fprintf(fid, '  </div>\n');

    % Lesion Breakdown Table
    fprintf(fid, '  <div class="section">\n');
    fprintf(fid, '    <div class="section-title">Quantitative Lesion Breakdown</div>\n');
    fprintf(fid, '    <table>\n');
    fprintf(fid, '      <tr><th>Lesion Feature Type</th><th>Count Detected</th><th>Relative Diagnostic Weight</th></tr>\n');
    fprintf(fid, '      <tr><td>Microaneurysms</td><td>%d</td><td>%.1f%%</td></tr>\n', lesion_importance.microaneurysms_count, lesion_importance.microaneurysms_impact_pct);
    fprintf(fid, '      <tr><td>Hemorrhages</td><td>%d</td><td>%.1f%%</td></tr>\n', lesion_importance.hemorrhages_count, lesion_importance.hemorrhages_impact_pct);
    fprintf(fid, '      <tr><td>Exudates</td><td>%d</td><td>%.1f%%</td></tr>\n', lesion_importance.exudates_count, lesion_importance.exudates_impact_pct);
    fprintf(fid, '    </table>\n');
    fprintf(fid, '  </div>\n');

    % Clinical Text & Recommendations
    fprintf(fid, '  <div class="section">\n');
    fprintf(fid, '    <div class="section-title">Clinical Diagnostic Summary & Recommendations</div>\n');
    fprintf(fid, '    <p><strong>Diagnostic Finding:</strong> %s</p>\n', clinical_text.diagnostic_summary);
    fprintf(fid, '    <p><strong>XAI Attention Rationale:</strong> %s</p>\n', clinical_text.xai_explanation);
    fprintf(fid, '    <div class="recommendation-box">\n');
    fprintf(fid, '      <strong>Clinical Recommendation:</strong><br>%s\n', clinical_text.recommendations);
    fprintf(fid, '    </div>\n');
    fprintf(fid, '  </div>\n');

    fprintf(fid, '  <div class="footer">Generated by XAI Diabetic Retinopathy Screening System | Module 5 Explainability Engine</div>\n');
    fprintf(fid, '</div>\n</body>\n</html>\n');

    fclose(fid);
    html_file_path = save_path;
end

function b64 = image_to_base64(img_rgb)
    tmp_path = [tempname, '.png'];
    imwrite(img_rgb, tmp_path);
    fid = fopen(tmp_path, 'rb');
    bytes = fread(fid, Inf, '*uint8');
    fclose(fid);
    delete(tmp_path);
    
    % Encode base64
    b64 = char(matlab.net.base64encode(bytes));
end

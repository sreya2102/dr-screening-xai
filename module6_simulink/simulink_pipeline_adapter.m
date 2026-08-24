function [iqa_gate, dr_grade_out, max_conf_out, risk_score_out, triage_action_out] = simulink_pipeline_adapter(img_in)
% SIMULINK_PIPELINE_ADAPTER Gateway adapter for Simulink MATLAB Function blocks.
%
% Integrates Modules 1 to 5 with strict Simulink signal interfaces (arrays/scalars).
% Can run seamlessly in standard MATLAB or inside a Simulink Model.
%
% Inputs:
%   img_in            : uint8 RGB image matrix (e.g. 224x224x3 or dynamic)
%
% Outputs:
%   iqa_gate          : uint8 (0: Reject, 1: Borderline, 2: Good)
%   dr_grade_out      : double (0: No DR, 1: Mild, 2: Moderate, 3: Severe, 4: PDR)
%   max_conf_out      : double (0.0 to 1.0)
%   risk_score_out    : double (0.0 to 1.0)
%   triage_action_out : uint8 (0: Retake, 1: Routine, 2: Follow-up, 3: Refer, 4: Urgent)

    % Step 1: Module 1 (IQA)
    try
        if exist('iqa_evaluate', 'file') == 2
            iqa_res = iqa_evaluate(img_in);
        else
            iqa_res = mock_pipeline_stubs('iqa', img_in);
        end
    catch
        iqa_res = mock_pipeline_stubs('iqa', img_in);
    end

    switch lower(iqa_res.status)
        case 'reject'
            iqa_gate = uint8(0);
        case 'borderline'
            iqa_gate = uint8(1);
        case 'good'
            iqa_gate = uint8(2);
        otherwise
            iqa_gate = uint8(2);
    end

    % If image is rejected, early exit to save computation
    if iqa_gate == 0
        dr_grade_out = 0.0;
        max_conf_out = 0.0;
        risk_score_out = 0.0;
        triage_action_out = uint8(0); % Retake
        return;
    end

    % Step 2: Module 2 (Enhancement)
    try
        if exist('enhance_fundus_image', 'file') == 2
            enh_res = enhance_fundus_image(img_in);
        else
            enh_res = mock_pipeline_stubs('enhancement', img_in);
        end
    catch
        enh_res = mock_pipeline_stubs('enhancement', img_in);
    end

    % Step 3: Module 3 (Segmentation)
    try
        if exist('segment_retinal_features', 'file') == 2
            seg_res = segment_retinal_features(enh_res);
        else
            seg_res = mock_pipeline_stubs('segmentation', enh_res);
        end
    catch
        seg_res = mock_pipeline_stubs('segmentation', enh_res);
    end

    % Step 4: Module 4 (DR Grading)
    try
        if exist('classify_dr_grade', 'file') == 2
            grade_res = classify_dr_grade(enh_res, seg_res);
        else
            grade_res = mock_pipeline_stubs('dr_grading', seg_res);
        end
    catch
        grade_res = mock_pipeline_stubs('dr_grading', seg_res);
    end

    dr_grade_out = double(grade_res.dr_grade);
    max_conf_out = double(max(grade_res.confidence_scores));
    risk_score_out = double(grade_res.risk_score);

    % Step 5: Decision Logic & Triage Action
    [triage_action_out, ~, ~, ~] = dr_decision_logic(iqa_gate, dr_grade_out, max_conf_out, risk_score_out);
end

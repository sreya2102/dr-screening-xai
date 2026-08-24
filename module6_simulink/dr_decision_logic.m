function [action_code, action_text, triage_priority, referral_urgency] = dr_decision_logic(iqa_status, dr_grade, max_confidence, risk_score)
% DR_DECISION_LOGIC Stateflow / Simulink compatible decision and triage logic.
%
% Inputs:
%   iqa_status     : uint8, double, char, or string (0/'Reject', 1/'Borderline', 2/'Good')
%   dr_grade       : double/uint8 (0: No DR, 1: Mild, 2: Moderate, 3: Severe, 4: PDR)
%   max_confidence : double (0.0 to 1.0, optional)
%   risk_score     : double (0.0 to 1.0, optional)
%
% Outputs:
%   action_code      : uint8 (0: Retake, 1: Routine, 2: Follow-up, 3: Prompt Referral, 4: Urgent Referral)
%   action_text      : string/char clinical recommendation
%   triage_priority  : uint8 (1: Low, 2: Medium, 3: High, 4: Critical)
%   referral_urgency : string ('Image Retake Required', 'Routine Follow-up', 'Semi-Annual Review', 'Prompt Ophthalmology Referral', 'Urgent Specialist Referral')
%
% Clinical Guidelines:
%   - If IQA is Reject -> Action: Retake Image Immediately.
%   - If Grade 0 (No DR) -> Routine Follow-up (12-mo).
%   - If Grade 1 (Mild NPDR) -> Semi-Annual Review (6-mo).
%   - If Grade 2 (Moderate NPDR) -> Prompt Ophthalmology Referral (1-mo).
%   - If Grade 3 (Severe NPDR) -> Urgent Specialist Referral (<2-wk).
%   - If Grade 4 (PDR) -> Urgent Specialist Referral (<1-wk).
%   - If Borderline IQA -> Flagged in clinical notes for closer inspection.

    % Normalize IQA status
    if ischar(iqa_status) || isstring(iqa_status)
        switch lower(char(iqa_status))
            case 'reject'
                iqa_num = uint8(0);
            case 'borderline'
                iqa_num = uint8(1);
            case 'good'
                iqa_num = uint8(2);
            otherwise
                iqa_num = uint8(2);
        end
    else
        iqa_num = uint8(iqa_status);
    end

    if nargin < 3 || isempty(max_confidence)
        max_confidence = 0.85;
    end
    if nargin < 4 || isempty(risk_score)
        risk_score = double(dr_grade) / 4.0;
    end

    % Gating Check: Image Quality Reject
    if iqa_num == 0
        action_code = uint8(0);
        action_text = 'Image Quality Insufficient: Retake retinal fundus photograph.';
        triage_priority = uint8(2);
        referral_urgency = 'Image Retake Required';
        return;
    end

    % Clinical Grading Triage
    switch uint8(dr_grade)
        case 0  % No DR
            if max_confidence >= 0.60
                action_code = uint8(1);
                action_text = 'No apparent retinopathy detected. Routine annual follow-up recommended (12 months).';
                triage_priority = uint8(1);
                referral_urgency = 'Routine Follow-up';
            else
                % Low confidence Normal -> Recommend shorter follow-up
                action_code = uint8(2);
                action_text = 'No obvious lesions, but low classification confidence. Follow-up in 6 months.';
                triage_priority = uint8(2);
                referral_urgency = 'Semi-Annual Review';
            end

        case 1  % Mild NPDR
            action_code = uint8(2);
            action_text = 'Mild Non-Proliferative DR (microaneurysms only). Schedule follow-up screening in 6 months.';
            triage_priority = uint8(2);
            referral_urgency = 'Semi-Annual Review';

        case 2  % Moderate NPDR
            action_code = uint8(3);
            action_text = 'Moderate Non-Proliferative DR. Refer to Comprehensive Ophthalmologist within 1 month.';
            triage_priority = uint8(3);
            referral_urgency = 'Prompt Ophthalmology Referral';

        case 3  % Severe NPDR
            action_code = uint8(4);
            action_text = 'Severe Non-Proliferative DR (High risk of progression). Urgent referral to Retina Specialist within 2 weeks.';
            triage_priority = uint8(4);
            referral_urgency = 'Urgent Specialist Referral';

        case 4  % PDR
            action_code = uint8(4);
            action_text = 'Proliferative Diabetic Retinopathy / Sight-Threatening DR. Immediate emergency referral to Retina Specialist (<1 week).';
            triage_priority = uint8(4);
            referral_urgency = 'Urgent Specialist Referral';

        otherwise
            action_code = uint8(0);
            action_text = 'Uncertain clinical diagnosis. Requires manual clinician review.';
            triage_priority = uint8(3);
            referral_urgency = 'Manual Review';
    end

    % Adjust if borderline quality reduced grading confidence
    if iqa_num == 1 && action_code <= 2 && max_confidence < 0.70
        action_text = [action_text, ' (Note: Borderline image quality - repeat image if symptoms present).'];
    end
end

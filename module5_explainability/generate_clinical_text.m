function clinical_text = generate_clinical_text(dr_grading_result, iqa_result, lesion_importance)
% GENERATE_CLINICAL_TEXT Synthesizes clinical text explanations and recommendations.
%
% Inputs:
%   dr_grading_result - Struct with predicted_grade, confidence, grade_label
%   iqa_result        - Struct with status and quality_score
%   lesion_importance - Struct with counts and impact percentages
%
% Output:
%   clinical_text     - Struct with:
%                           .diagnostic_summary
%                           .xai_explanation
%                           .recommendations

    dr_grade = dr_grading_result.predicted_grade;
    confidence_pct = round(dr_grading_result.confidence * 100, 1);
    
    iqa_status = 'Good';
    if isstruct(iqa_result) && isfield(iqa_result, 'status')
        iqa_status = iqa_result.status;
    end

    % 1. Handle Quality Rejection
    if strcmpi(iqa_status, 'Reject')
        diagnostic_summary = sprintf('UNSATISFACTORY IMAGE QUALITY (IQA Score: %.2f). Retinal evaluation cannot be reliably completed.', iqa_result.quality_score);
        xai_explanation = 'The input retinal fundus image failed quality validation due to excessive blur, illumination artifacts, or poor pupil dilation. Automated grading is suspended to avoid false diagnostic output.';
        recommendations = 'Immediate re-imaging required. Ensure proper focus, illumination, and patient fixation before re-submitting for screening.';
        
        clinical_text = struct(...
            'diagnostic_summary', diagnostic_summary, ...
            'xai_explanation', xai_explanation, ...
            'recommendations', recommendations ...
        );
        return;
    end

    % 2. Clinical Explanations per Grade
    switch dr_grade
        case 0
            diagnostic_summary = sprintf('Grade 0: No Diabetic Retinopathy (Confidence: %.1f%%).', confidence_pct);
            xai_explanation = 'Deep Learning model attention is distributed across normal retinal landmarks (optic disc and macula). No significant microaneurysms, hemorrhages, or exudates were detected.';
            recommendations = 'Routine annual rescreening as per standard clinical protocol.';

        case 1
            diagnostic_summary = sprintf('Grade 1: Mild NPDR (Confidence: %.1f%%).', confidence_pct);
            xai_explanation = sprintf('Model attention highlights %d microaneurysms (accounting for %.1f%% of explanation weight). Retinal microvasculature shows early localized changes without significant exudation.', ...
                lesion_importance.microaneurysms_count, lesion_importance.microaneurysms_impact_pct);
            recommendations = 'Follow-up screening in 6–12 months. Recommend metabolic and glycemic control optimization (HbA1c monitoring).';

        case 2
            diagnostic_summary = sprintf('Grade 2: Moderate NPDR (Confidence: %.1f%%).', confidence_pct);
            xai_explanation = sprintf('Model identified key DR features: %d microaneurysms, %d hemorrhages, and %d hard exudates. Saliency maps show concentrated neural attention over paramacular lesion clusters.', ...
                lesion_importance.microaneurysms_count, lesion_importance.hemorrhages_count, lesion_importance.exudates_count);
            recommendations = 'Referral to an Ophthalmologist / Retina Specialist within 4 to 8 weeks. Monitor closely for macular edema.';

        case 3
            diagnostic_summary = sprintf('Grade 3: Severe NPDR (Confidence: %.1f%%).', confidence_pct);
            xai_explanation = sprintf('High diagnostic urgency. Dense lesion cluster detected (%d hemorrhages, %d exudates). Grad-CAM maps indicate severe neural response across multiple quadrants, signifying progressive capillary non-perfusion.', ...
                lesion_importance.hemorrhages_count, lesion_importance.exudates_count);
            recommendations = 'Urgent referral to a Retina Specialist within 2 weeks. Comprehensive dilated fundus examination and OCT imaging recommended.';

        case 4
            diagnostic_summary = sprintf('Grade 4: Proliferative DR (Confidence: %.1f%%).', confidence_pct);
            xai_explanation = sprintf('Critical finding: Proliferative Diabetic Retinopathy. XAI attention heatmaps demonstrate intense neural focus over widespread lesions (%d total lesion focal points) consistent with high-risk proliferative changes.', ...
                lesion_importance.total_lesions);
            recommendations = 'Immediate referral to a Retina Specialist within 1 week for evaluation of anti-VEGF therapy or panretinal photocoagulation (PRP).';

        otherwise
            diagnostic_summary = sprintf('DR Grade %d (Confidence: %.1f%%).', dr_grade, confidence_pct);
            xai_explanation = 'Retinal screening evaluation completed with automated feature extraction.';
            recommendations = 'Clinical evaluation by a certified eye care professional recommended.';
    end

    % Append IQA note if Borderline
    if strcmpi(iqa_status, 'Borderline')
        xai_explanation = [xai_explanation ' Note: Image quality rated Borderline (score: ' sprintf('%.2f', iqa_result.quality_score) '); findings should be interpreted with clinical caution.'];
    end

    clinical_text = struct(...
        'diagnostic_summary', diagnostic_summary, ...
        'xai_explanation', xai_explanation, ...
        'recommendations', recommendations ...
    );
end

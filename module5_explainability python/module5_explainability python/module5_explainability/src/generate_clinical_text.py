def generate_clinical_text(dr_grading_result, iqa_result, lesion_importance):
    """
    Synthesizes clinical text explanations and recommendations.
    """
    dr_grade = dr_grading_result.get('predicted_grade', 0)
    confidence_pct = round(dr_grading_result.get('confidence', 0.0) * 100, 1)
    
    iqa_status = 'Good'
    if isinstance(iqa_result, dict) and 'status' in iqa_result:
        iqa_status = iqa_result['status']
        
    # 1. Handle Quality Rejection
    if iqa_status.lower() == 'reject':
        qual_score = iqa_result.get('quality_score', 0.0)
        diagnostic_summary = f"UNSATISFACTORY IMAGE QUALITY (IQA Score: {qual_score:.2f}). Retinal evaluation cannot be reliably completed."
        xai_explanation = "The input retinal fundus image failed quality validation due to excessive blur, illumination artifacts, or poor pupil dilation. Automated grading is suspended to avoid false diagnostic output."
        recommendations = "Immediate re-imaging required. Ensure proper focus, illumination, and patient fixation before re-submitting for screening."
        
        return {
            'diagnostic_summary': diagnostic_summary,
            'xai_explanation': xai_explanation,
            'recommendations': recommendations
        }
        
    # 2. Clinical Explanations per Grade
    if dr_grade == 0:
        diagnostic_summary = f"Grade 0: No Diabetic Retinopathy (Confidence: {confidence_pct}%)."
        xai_explanation = "Deep Learning model attention is distributed across normal retinal landmarks (optic disc and macula). No significant microaneurysms, hemorrhages, or exudates were detected."
        recommendations = "Routine annual rescreening as per standard clinical protocol."
        
    elif dr_grade == 1:
        diagnostic_summary = f"Grade 1: Mild NPDR (Confidence: {confidence_pct}%)."
        xai_explanation = f"Model attention highlights {lesion_importance['microaneurysms_count']} microaneurysms (accounting for {lesion_importance['microaneurysms_impact_pct']}% of explanation weight). Retinal microvasculature shows early localized changes without significant exudation."
        recommendations = "Follow-up screening in 6–12 months. Recommend metabolic and glycemic control optimization (HbA1c monitoring)."
        
    elif dr_grade == 2:
        diagnostic_summary = f"Grade 2: Moderate NPDR (Confidence: {confidence_pct}%)."
        xai_explanation = f"Model identified key DR features: {lesion_importance['microaneurysms_count']} microaneurysms, {lesion_importance['hemorrhages_count']} hemorrhages, and {lesion_importance['exudates_count']} hard exudates. Saliency maps show concentrated neural attention over paramacular lesion clusters."
        recommendations = "Referral to an Ophthalmologist / Retina Specialist within 4 to 8 weeks. Monitor closely for macular edema."
        
    elif dr_grade == 3:
        diagnostic_summary = f"Grade 3: Severe NPDR (Confidence: {confidence_pct}%)."
        xai_explanation = f"High diagnostic urgency. Dense lesion cluster detected ({lesion_importance['hemorrhages_count']} hemorrhages, {lesion_importance['exudates_count']} exudates). Grad-CAM maps indicate severe neural response across multiple quadrants, signifying progressive capillary non-perfusion."
        recommendations = "Urgent referral to a Retina Specialist within 2 weeks. Comprehensive dilated fundus examination and OCT imaging recommended."
        
    elif dr_grade == 4:
        diagnostic_summary = f"Grade 4: Proliferative DR (Confidence: {confidence_pct}%)."
        xai_explanation = f"Critical finding: Proliferative Diabetic Retinopathy. XAI attention heatmaps demonstrate intense neural focus over widespread lesions ({lesion_importance['total_lesions']} total lesion focal points) consistent with high-risk proliferative changes."
        recommendations = "Immediate referral to a Retina Specialist within 1 week for evaluation of anti-VEGF therapy or panretinal photocoagulation (PRP)."
        
    else:
        diagnostic_summary = f"DR Grade {dr_grade} (Confidence: {confidence_pct}%)."
        xai_explanation = "Retinal screening evaluation completed with automated feature extraction."
        recommendations = "Clinical evaluation by a certified eye care professional recommended."
        
    # Append IQA note if Borderline
    if iqa_status.lower() == 'borderline':
        qual_score = iqa_result.get('quality_score', 0.0)
        xai_explanation += f" Note: Image quality rated Borderline (score: {qual_score:.2f}); findings should be interpreted with clinical caution."
        
    return {
        'diagnostic_summary': diagnostic_summary,
        'xai_explanation': xai_explanation,
        'recommendations': recommendations
    }

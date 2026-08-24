"""
Clinical Diagnostic Text Synthesizer (Python).
"""

def generate_clinical_text(dr_grading_result, iqa_result, lesion_importance):
    dr_grade = dr_grading_result['predicted_grade']
    confidence_pct = round(dr_grading_result['confidence'] * 100, 1)
    iqa_status = iqa_result.get('status', 'Good') if isinstance(iqa_result, dict) else 'Good'

    if str(iqa_status).lower() == 'reject':
        return {
            'diagnostic_summary': f"UNSATISFACTORY IMAGE QUALITY (IQA Score: {iqa_result.get('quality_score', 0.0):.2f}). Evaluation cannot be completed.",
            'xai_explanation': "Image failed quality validation due to excessive blur or illumination artifacts. Automated grading is suspended to avoid false diagnosis.",
            'recommendations': "Immediate re-imaging required. Ensure proper focus and illumination before re-submitting."
        }

    explanations = {
        0: (
            f"Grade 0: No Diabetic Retinopathy (Confidence: {confidence_pct}%).",
            "Model attention is distributed across normal retinal landmarks (optic disc and macula). No significant microaneurysms, hemorrhages, or exudates detected.",
            "Routine annual rescreening as per standard clinical protocol."
        ),
        1: (
            f"Grade 1: Mild NPDR (Confidence: {confidence_pct}%).",
            f"Model attention highlights {lesion_importance['microaneurysms_count']} microaneurysms ({lesion_importance['microaneurysms_impact_pct']}% explanation weight). Retinal microvasculature shows early localized changes.",
            "Follow-up screening in 6–12 months. Recommend metabolic and glycemic control optimization."
        ),
        2: (
            f"Grade 2: Moderate NPDR (Confidence: {confidence_pct}%).",
            f"Model identified key DR features: {lesion_importance['microaneurysms_count']} microaneurysms, {lesion_importance['hemorrhages_count']} hemorrhages, and {lesion_importance['exudates_count']} hard exudates. Saliency maps show concentrated attention over paramacular lesion clusters.",
            "Referral to an Ophthalmologist / Retina Specialist within 4 to 8 weeks. Monitor closely for macular edema."
        ),
        3: (
            f"Grade 3: Severe NPDR (Confidence: {confidence_pct}%).",
            f"High diagnostic urgency. Dense lesion cluster detected ({lesion_importance['hemorrhages_count']} hemorrhages, {lesion_importance['exudates_count']} exudates). Grad-CAM maps indicate severe neural response across multiple quadrants.",
            "Urgent referral to a Retina Specialist within 2 weeks. Comprehensive dilated fundus examination and OCT imaging recommended."
        ),
        4: (
            f"Grade 4: Proliferative DR (Confidence: {confidence_pct}%).",
            f"Critical finding: Proliferative Diabetic Retinopathy. XAI heatmaps demonstrate intense neural focus over widespread lesions ({lesion_importance['total_lesions']} total lesion focal points).",
            "Immediate referral to a Retina Specialist within 1 week for evaluation of anti-VEGF therapy or panretinal photocoagulation (PRP)."
        )
    }

    diag, xai, rec = explanations.get(dr_grade, (f"DR Grade {dr_grade}", "Evaluation completed.", "Clinical evaluation recommended."))

    if str(iqa_status).lower() == 'borderline':
        xai += f" Note: Image quality rated Borderline (score: {iqa_result.get('quality_score', 0.0):.2f}); findings should be interpreted with caution."

    return {
        'diagnostic_summary': diag,
        'xai_explanation': xai,
        'recommendations': rec
    }

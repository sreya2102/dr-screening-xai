def dr_decision_logic(iqa_status, dr_grade, max_confidence=0.85, risk_score=None):
    """
    Simulink compatible decision and triage logic.
    """
    # Normalize IQA status
    if isinstance(iqa_status, str):
        status_lower = iqa_status.lower()
        if status_lower == 'reject':
            iqa_num = 0
        elif status_lower == 'borderline':
            iqa_num = 1
        elif status_lower == 'good':
            iqa_num = 2
        else:
            iqa_num = 2
    else:
        iqa_num = int(iqa_status)
        
    dr_grade = int(dr_grade)
    
    if risk_score is None:
        risk_score = float(dr_grade) / 4.0
        
    # Gating Check: Image Quality Reject
    if iqa_num == 0:
        action_code = 0
        action_text = 'Image Quality Insufficient: Retake retinal fundus photograph.'
        triage_priority = 2
        referral_urgency = 'Image Retake Required'
        return action_code, action_text, triage_priority, referral_urgency
        
    # Clinical Grading Triage
    if dr_grade == 0:
        if max_confidence >= 0.60:
            action_code = 1
            action_text = 'No apparent retinopathy detected. Routine annual follow-up recommended (12 months).'
            triage_priority = 1
            referral_urgency = 'Routine Follow-up'
        else:
            action_code = 2
            action_text = 'No obvious lesions, but low classification confidence. Follow-up in 6 months.'
            triage_priority = 2
            referral_urgency = 'Semi-Annual Review'
            
    elif dr_grade == 1:
        action_code = 2
        action_text = 'Mild Non-Proliferative DR (microaneurysms only). Schedule follow-up screening in 6 months.'
        triage_priority = 2
        referral_urgency = 'Semi-Annual Review'
        
    elif dr_grade == 2:
        action_code = 3
        action_text = 'Moderate Non-Proliferative DR. Refer to Comprehensive Ophthalmologist within 1 month.'
        triage_priority = 3
        referral_urgency = 'Prompt Ophthalmology Referral'
        
    elif dr_grade == 3:
        action_code = 4
        action_text = 'Severe Non-Proliferative DR (High risk of progression). Urgent referral to Retina Specialist within 2 weeks.'
        triage_priority = 4
        referral_urgency = 'Urgent Specialist Referral'
        
    elif dr_grade == 4:
        action_code = 4
        action_text = 'Proliferative Diabetic Retinopathy / Sight-Threatening DR. Immediate emergency referral to Retina Specialist (<1 week).'
        triage_priority = 4
        referral_urgency = 'Urgent Specialist Referral'
        
    else:
        action_code = 0
        action_text = 'Uncertain clinical diagnosis. Requires manual clinician review.'
        triage_priority = 3
        referral_urgency = 'Manual Review'
        
    # Adjust if borderline quality reduced grading confidence
    if iqa_num == 1 and action_code <= 2 and max_confidence < 0.70:
        action_text += ' (Note: Borderline image quality - repeat image if symptoms present).'
        
    return action_code, action_text, triage_priority, referral_urgency

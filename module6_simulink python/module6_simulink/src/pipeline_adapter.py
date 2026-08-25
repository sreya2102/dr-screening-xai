import sys
from dr_decision_logic import dr_decision_logic

def mock_pipeline_stubs(module_name, input_data):
    if module_name == 'iqa':
        return {'status': 'Good', 'quality_score': 0.9}
    elif module_name == 'enhancement':
        return input_data # Returns the image as-is for mock
    elif module_name == 'segmentation':
        return {'vessels_mask': None, 'optic_disc_mask': None, 'microaneurysms_mask': None, 'hemorrhages_mask': None, 'exudates_mask': None}
    elif module_name == 'dr_grading':
        return {'predicted_grade': 2, 'confidence': 0.88, 'class_probabilities': [0.0, 0.1, 0.88, 0.02, 0.0]}
    return None

def pipeline_adapter(img_in):
    """
    Gateway adapter that integrates Modules 1 to 5.
    Returns standard decision logic outputs.
    """
    # Step 1: Module 1 (IQA)
    try:
        from compute_iqa_metrics import compute_iqa_metrics
        # Assuming typical setup, we might just call a main function.
        # For simplicity, we use mock if not in path
        iqa_res = mock_pipeline_stubs('iqa', img_in)
    except ImportError:
        iqa_res = mock_pipeline_stubs('iqa', img_in)
        
    status = iqa_res.get('status', 'Good').lower()
    if status == 'reject':
        iqa_gate = 0
    elif status == 'borderline':
        iqa_gate = 1
    else:
        iqa_gate = 2
        
    # Early exit
    if iqa_gate == 0:
        dr_grade_out = 0.0
        max_conf_out = 0.0
        risk_score_out = 0.0
        triage_action_out = 0 # Retake
        return iqa_gate, dr_grade_out, max_conf_out, risk_score_out, triage_action_out
        
    # Step 2: Module 2 (Enhancement)
    try:
        from enhance_image import enhance_image
        enh_res = mock_pipeline_stubs('enhancement', img_in)
    except ImportError:
        enh_res = mock_pipeline_stubs('enhancement', img_in)
        
    # Step 3: Module 3 (Segmentation)
    try:
        from segment_lesions import segment_lesions
        seg_res = mock_pipeline_stubs('segmentation', enh_res)
    except ImportError:
        seg_res = mock_pipeline_stubs('segmentation', enh_res)
        
    # Step 4: Module 4 (DR Grading)
    try:
        from grade_dr import grade_dr
        grade_res = mock_pipeline_stubs('dr_grading', seg_res)
    except ImportError:
        grade_res = mock_pipeline_stubs('dr_grading', seg_res)
        
    dr_grade_out = float(grade_res.get('predicted_grade', 0))
    max_conf_out = float(grade_res.get('confidence', 0.0))
    risk_score_out = dr_grade_out / 4.0
    
    # Step 5: Decision Logic & Triage Action
    triage_action_out, _, _, _ = dr_decision_logic(iqa_gate, dr_grade_out, max_conf_out, risk_score_out)
    
    return iqa_gate, dr_grade_out, max_conf_out, risk_score_out, triage_action_out

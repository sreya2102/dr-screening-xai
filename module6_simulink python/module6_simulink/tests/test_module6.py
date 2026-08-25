import os
import sys

sys.path.append(os.path.join(os.path.dirname(os.path.dirname(__file__)), 'src'))

from dr_decision_logic import dr_decision_logic
from pipeline_adapter import pipeline_adapter
from screening_queue_simulation import screening_queue_simulation

def test_module6():
    print("=======================================================")
    print("  Module 6: Simulink & Queueing - Automated Test Suite ")
    print("=======================================================\n")
    
    test_results = {'passed': 0, 'failed': 0, 'details': []}
    
    print("[Test 1] Decision Logic (Reject IQA)... ", end="")
    try:
        action_code, action_text, triage_priority, referral_urgency = dr_decision_logic('Reject', 2)
        assert action_code == 0
        assert referral_urgency == 'Image Retake Required'
        print("PASSED")
        test_results['passed'] += 1
    except Exception as e:
        print(f"FAILED: {str(e)}")
        test_results['failed'] += 1
        
    print("[Test 2] Decision Logic (Grade 4 PDR)... ", end="")
    try:
        action_code, action_text, triage_priority, referral_urgency = dr_decision_logic('Good', 4)
        assert action_code == 4
        assert referral_urgency == 'Urgent Specialist Referral'
        print("PASSED")
        test_results['passed'] += 1
    except Exception as e:
        print(f"FAILED: {str(e)}")
        test_results['failed'] += 1
        
    print("[Test 3] Pipeline Adapter Mock... ", end="")
    try:
        import numpy as np
        dummy_img = np.zeros((100, 100, 3), dtype=np.uint8)
        iqa_gate, dr_grade_out, max_conf_out, risk_score_out, triage_action_out = pipeline_adapter(dummy_img)
        # Mock returns iqa=Good, Grade=2
        assert iqa_gate == 2
        assert dr_grade_out == 2.0
        assert triage_action_out == 3 # Prompt Referral
        print("PASSED")
        test_results['passed'] += 1
    except Exception as e:
        print(f"FAILED: {str(e)}")
        test_results['failed'] += 1
        
    print("[Test 4] Screening Queue Simulation... ", end="")
    try:
        params = {
            'num_screening_centers': 2,
            'patients_per_day_per_center': 20,
            'sim_duration_days': 2
        }
        # Avoid print spam during test
        import sys, io
        old_stdout = sys.stdout
        sys.stdout = io.StringIO()
        sim_results = screening_queue_simulation(params)
        sys.stdout = old_stdout
        
        assert 60 <= sim_results['total_patients_arrived'] <= 100 # Approx 80
        assert 'total_referrals_generated' in sim_results
        assert sim_results['human_review_utilization_pct'] >= 0.0
        print("PASSED")
        test_results['passed'] += 1
    except Exception as e:
        sys.stdout = old_stdout
        import traceback
        traceback.print_exc()
        print(f"FAILED: {str(e)}")
        test_results['failed'] += 1
        
    print("\n-------------------------------------------------------")
    print(f"  Test Suite Summary: {test_results['passed']} Passed, {test_results['failed']} Failed  ")
    print("-------------------------------------------------------\n")

if __name__ == "__main__":
    test_module6()

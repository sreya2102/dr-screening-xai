import os
import sys
import numpy as np
import shutil
import cv2

sys.path.append(os.path.join(os.path.dirname(os.path.dirname(__file__)), 'src'))

from generate_report import generate_report

def create_mock_screening_data():
    H, W = 400, 400
    
    # Dummy raw & enhanced image
    raw_img = np.zeros((H, W, 3), dtype=np.uint8)
    cv2.circle(raw_img, (200, 200), 180, (200, 100, 50), -1) # Fundus circle
    enhanced_img = raw_img.copy()
    cv2.circle(enhanced_img, (200, 200), 180, (220, 120, 70), -1) 
    
    # Dummy masks
    vessels = np.zeros((H, W), dtype=np.uint8)
    cv2.line(vessels, (200, 200), (300, 300), 1, 3)
    
    od = np.zeros((H, W), dtype=np.uint8)
    cv2.circle(od, (250, 200), 30, 1, -1)
    
    ma = np.zeros((H, W), dtype=np.uint8)
    cv2.circle(ma, (150, 150), 3, 1, -1)
    cv2.circle(ma, (160, 180), 3, 1, -1)
    
    hem = np.zeros((H, W), dtype=np.uint8)
    cv2.circle(hem, (180, 250), 8, 1, -1)
    
    ex = np.zeros((H, W), dtype=np.uint8)
    cv2.circle(ex, (120, 220), 5, 1, -1)
    
    screening_data = {
        'patient_id': 'PAT-TEST-001',
        'patient_name': 'Test User',
        'age': 55,
        'eye_side': 'OD',
        'date': '2026-08-24',
        'raw_image': raw_img,
        'enhanced_image': enhanced_img,
        'iqa_result': {
            'status': 'Good',
            'quality_score': 0.95
        },
        'segmentation_results': {
            'vessels_mask': vessels,
            'optic_disc_mask': od,
            'microaneurysms_mask': ma,
            'hemorrhages_mask': hem,
            'exudates_mask': ex,
            'lesion_counts': {
                'microaneurysms': 2,
                'hemorrhages': 1,
                'exudates': 1
            }
        },
        'dr_grading_result': {
            'predicted_grade': 2,
            'grade_label': 'Moderate NPDR',
            'confidence': 0.89,
            'class_probabilities': [0.01, 0.05, 0.89, 0.04, 0.01]
        }
    }
    
    return screening_data

def test_module5():
    print("=======================================================")
    print("  Module 5: Explainability - Automated Test Suite ")
    print("=======================================================\n")
    
    test_results = {'passed': 0, 'failed': 0, 'details': []}
    
    output_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'test_output')
    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)
        
    print("[Test 1] Mock Data Generation... ", end="")
    try:
        mock_data = create_mock_screening_data()
        assert mock_data['patient_id'] == 'PAT-TEST-001'
        print("PASSED")
        test_results['passed'] += 1
    except Exception as e:
        print(f"FAILED: {str(e)}")
        test_results['failed'] += 1
        
    print("[Test 2] Full XAI & Report Generation Pipeline... ", end="")
    try:
        # Avoid showing plots during test
        import matplotlib
        matplotlib.use('Agg')
        
        report_data = generate_report(mock_data, output_dir)
        
        assert os.path.exists(report_data['report_files']['html_path']), "HTML report missing"
        assert os.path.exists(report_data['report_files']['summary_png_path']), "Summary PNG missing"
        assert os.path.exists(report_data['report_files']['pkl_path']), "PKL report missing"
        
        # Check clinical text
        assert "Moderate NPDR" in report_data['clinical_text']['diagnostic_summary']
        assert report_data['lesion_importance']['microaneurysms_count'] == 2
        
        print("PASSED")
        test_results['passed'] += 1
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"FAILED: {str(e)}")
        test_results['failed'] += 1
        
    # Test rejection logic
    print("[Test 3] Reject IQA Handling... ", end="")
    try:
        mock_data_reject = create_mock_screening_data()
        mock_data_reject['iqa_result']['status'] = 'Reject'
        mock_data_reject['iqa_result']['quality_score'] = 0.2
        
        report_data_reject = generate_report(mock_data_reject, output_dir)
        assert "UNSATISFACTORY IMAGE QUALITY" in report_data_reject['clinical_text']['diagnostic_summary']
        print("PASSED")
        test_results['passed'] += 1
    except Exception as e:
        print(f"FAILED: {str(e)}")
        test_results['failed'] += 1
        
    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)
        
    print("\n-------------------------------------------------------")
    print(f"  Test Suite Summary: {test_results['passed']} Passed, {test_results['failed']} Failed  ")
    print("-------------------------------------------------------\n")
    
if __name__ == "__main__":
    test_module5()

"""
Primary Module 5 Entry Point (Python / DemoViewer).
"""

import os
import json
from generate_xai_maps import generate_xai_maps
from compute_lesion_importance import compute_lesion_importance
from generate_clinical_text import generate_clinical_text
from export_html_report import export_html_report

def generate_report(screening_data, output_dir=None):
    if output_dir is None:
        output_dir = os.path.join(os_path_dir := os.path.dirname(os.path.abspath(__file__)), 'output_reports')
    os.makedirs(output_dir, exist_ok=True)

    # 1. Generate XAI Maps
    xai_maps = generate_xai_maps(screening_data)

    # 2. Compute Lesion Importance
    dr_grade = screening_data['dr_grading_result']['predicted_grade']
    lesion_importance = compute_lesion_importance(screening_data.get('segmentation_results'), dr_grade)

    # 3. Synthesize Clinical Text
    clinical_text = generate_clinical_text(screening_data['dr_grading_result'],
                                           screening_data['iqa_result'],
                                           lesion_importance)

    # 4. Export HTML Report
    patient_id = screening_data['patient_id']
    html_path = os.path.join(output_dir, f"Screening_Report_{patient_id}.html")
    export_html_report(screening_data, xai_maps, clinical_text, lesion_importance, html_path)

    # 5. Save JSON Data File
    json_path = os.path.join(output_dir, f"Report_Data_{patient_id}.json")
    json_data = {
        'patient_id': patient_id,
        'patient_name': screening_data['patient_name'],
        'eye_side': screening_data['eye_side'],
        'dr_grade': screening_data['dr_grading_result']['grade_label'],
        'confidence': screening_data['dr_grading_result']['confidence'],
        'iqa_status': screening_data['iqa_result']['status'],
        'lesion_importance': lesion_importance,
        'clinical_text': clinical_text,
        'report_files': {
            'html_path': html_path,
            'json_path': json_path
        }
    }

    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(json_data, f, indent=4)

    return {
        'patient_id': patient_id,
        'patient_name': screening_data['patient_name'],
        'eye_side': screening_data['eye_side'],
        'dr_grade': screening_data['dr_grading_result']['grade_label'],
        'confidence': screening_data['dr_grading_result']['confidence'],
        'iqa_status': screening_data['iqa_result']['status'],
        'xai_maps': xai_maps,
        'lesion_importance': lesion_importance,
        'clinical_text': clinical_text,
        'report_files': json_data['report_files']
    }

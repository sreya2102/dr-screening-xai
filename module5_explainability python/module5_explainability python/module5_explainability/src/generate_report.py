import os
import pickle

from generate_xai_maps import generate_xai_maps
from compute_lesion_importance import compute_lesion_importance
from generate_clinical_text import generate_clinical_text
from build_summary_figure import build_summary_figure
from export_html_report import export_html_report

def generate_report(screening_data, output_dir=None):
    """
    Primary Module 5 function for XAI map & report generation.
    """
    if output_dir is None:
        output_dir = os.path.join(os.getcwd(), 'output_reports')
        
    os.makedirs(output_dir, exist_ok=True)
    
    patient_id = screening_data.get('patient_id', 'Unknown')
    
    # 1. Generate XAI Visual Explanation Maps
    xai_maps = generate_xai_maps(screening_data)
    
    # 2. Compute Lesion Importance Breakdown
    dr_grade = screening_data.get('dr_grading_result', {}).get('predicted_grade', 0)
    seg_results = screening_data.get('segmentation_results', {})
    lesion_importance = compute_lesion_importance(seg_results, dr_grade)
    
    # 3. Synthesize Natural Language Clinical Text & Recommendations
    clinical_text = generate_clinical_text(
        screening_data.get('dr_grading_result', {}),
        screening_data.get('iqa_result', {}),
        lesion_importance
    )
    
    # 4. Build 2x3 Diagnostic Summary Canvas Figure
    summary_png_path = os.path.join(output_dir, f'Summary_Canvas_{patient_id}.png')
    fig, summary_canvas_img = build_summary_figure(screening_data, xai_maps, clinical_text, summary_png_path)
    
    # 5. Export Standalone HTML Clinical Report
    html_report_path = os.path.join(output_dir, f'Screening_Report_{patient_id}.html')
    export_html_report(screening_data, xai_maps, clinical_text, lesion_importance, html_report_path)
    
    # 6. Save Structured Summary File
    pkl_report_path = os.path.join(output_dir, f'Report_Data_{patient_id}.pkl')
    
    report_data = {
        'patient_id': patient_id,
        'patient_name': screening_data.get('patient_name', 'N/A'),
        'eye_side': screening_data.get('eye_side', 'N/A'),
        'dr_grade': screening_data.get('dr_grading_result', {}).get('grade_label', 'N/A'),
        'confidence': screening_data.get('dr_grading_result', {}).get('confidence', 0.0),
        'iqa_status': screening_data.get('iqa_result', {}).get('status', 'N/A'),
        'xai_maps': xai_maps,
        'lesion_importance': lesion_importance,
        'clinical_text': clinical_text,
        'summary_canvas_img': summary_canvas_img,
        'report_files': {
            'html_path': html_report_path,
            'summary_png_path': summary_png_path,
            'pkl_path': pkl_report_path
        }
    }
    
    with open(pkl_report_path, 'wb') as f:
        pickle.dump(report_data, f)
        
    return report_data

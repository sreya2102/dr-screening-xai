import os
import cv2
import base64

def image_to_base64(img_rgb):
    # Ensure standard BGR format for cv2.imencode if the image is in RGB
    if len(img_rgb.shape) == 3 and img_rgb.shape[2] == 3:
        img_bgr = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2BGR)
    else:
        img_bgr = img_rgb
        
    _, buffer = cv2.imencode('.png', img_bgr)
    b64_str = base64.b64encode(buffer).decode('utf-8')
    return b64_str

def export_html_report(screening_data, xai_maps, clinical_text, lesion_importance, save_path=None):
    """
    Generates a responsive, standalone clinical HTML screening report.
    """
    if not save_path:
        patient_id = screening_data.get('patient_id', 'Unknown')
        save_path = os.path.join(os.getcwd(), f'DR_Screening_Report_{patient_id}.html')
        
    b64_gradcam = image_to_base64(xai_maps['gradcam_overlay'])
    b64_lesion = image_to_base64(xai_maps['lesion_overlay'])
    b64_raw = image_to_base64(screening_data['raw_image'])
    
    grade_colors = ['#28a745', '#17a2b8', '#ffc107', '#fd7e14', '#dc3545']
    dr_grade = screening_data['dr_grading_result'].get('predicted_grade', 0)
    badge_color = grade_colors[min(dr_grade, 4)]
    
    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Diabetic Retinopathy Screening Report - {screening_data.get('patient_id', 'N/A')}</title>
<style>
  body {{ font-family: "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background-color: #f4f7f9; color: #2c3e50; margin: 0; padding: 20px; }}
  .container {{ max-width: 960px; margin: 0 auto; background: #ffffff; padding: 30px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.08); }}
  .header {{ display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #eef2f5; padding-bottom: 15px; margin-bottom: 25px; }}
  .header h1 {{ font-size: 24px; margin: 0; color: #1a365d; }}
  .badge {{ padding: 6px 14px; border-radius: 20px; color: #fff; font-weight: bold; font-size: 14px; background-color: {badge_color}; }}
  .section {{ margin-bottom: 25px; }}
  .section-title {{ font-size: 18px; font-weight: 600; color: #2b6cb0; border-left: 4px solid #3182ce; padding-left: 10px; margin-bottom: 15px; }}
  .grid-3 {{ display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px; }}
  .card {{ background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 15px; text-align: center; }}
  .card img {{ max-width: 100%; height: auto; border-radius: 6px; border: 1px solid #cbd5e0; }}
  table {{ width: 100%; border-collapse: collapse; margin-top: 10px; }}
  th, td {{ padding: 10px 12px; border: 1px solid #e2e8f0; text-align: left; font-size: 14px; }}
  th {{ background-color: #edf2f7; color: #4a5568; font-weight: 600; }}
  .recommendation-box {{ background: #fffaf0; border-left: 5px solid #dd6b20; padding: 15px; border-radius: 4px; margin-top: 15px; }}
  .footer {{ text-align: center; font-size: 12px; color: #a0aec0; margin-top: 30px; border-top: 1px solid #e2e8f0; padding-top: 15px; }}
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <div>
      <h1>Diabetic Retinopathy Screening & XAI Report</h1>
      <small>Automated Explainable AI Screening System</small>
    </div>
    <div class="badge">Grade {dr_grade}: {screening_data['dr_grading_result'].get('grade_label', 'N/A')}</div>
  </div>
  
  <div class="section">
    <div class="section-title">Patient Information</div>
    <table>
      <tr><th>Patient ID</th><td>{screening_data.get('patient_id', 'N/A')}</td><th>Patient Name</th><td>{screening_data.get('patient_name', 'N/A')}</td></tr>
      <tr><th>Age</th><td>{screening_data.get('age', 'N/A')}</td><th>Eye Examined</th><td>{screening_data.get('eye_side', 'N/A')}</td></tr>
      <tr><th>Screening Date</th><td>{screening_data.get('date', 'N/A')}</td><th>Image Quality (IQA)</th><td>{screening_data.get('iqa_result', {}).get('status', 'N/A')} (Score: {screening_data.get('iqa_result', {}).get('quality_score', 0.0):.2f})</td></tr>
    </table>
  </div>
  
  <div class="section">
    <div class="section-title">XAI Visual Explanations</div>
    <div class="grid-3">
      <div class="card"><h4>Original Fundus Image</h4><img src="data:image/png;base64,{b64_raw}" alt="Raw Image"></div>
      <div class="card"><h4>Lesion Segmentation Overlay</h4><img src="data:image/png;base64,{b64_lesion}" alt="Lesion Overlay"></div>
      <div class="card"><h4>Grad-CAM Heatmap Overlay</h4><img src="data:image/png;base64,{b64_gradcam}" alt="Grad-CAM Overlay"></div>
    </div>
  </div>
  
  <div class="section">
    <div class="section-title">Quantitative Lesion Breakdown</div>
    <table>
      <tr><th>Lesion Feature Type</th><th>Count Detected</th><th>Relative Diagnostic Weight</th></tr>
      <tr><td>Microaneurysms</td><td>{lesion_importance.get('microaneurysms_count', 0)}</td><td>{lesion_importance.get('microaneurysms_impact_pct', 0.0):.1f}%</td></tr>
      <tr><td>Hemorrhages</td><td>{lesion_importance.get('hemorrhages_count', 0)}</td><td>{lesion_importance.get('hemorrhages_impact_pct', 0.0):.1f}%</td></tr>
      <tr><td>Exudates</td><td>{lesion_importance.get('exudates_count', 0)}</td><td>{lesion_importance.get('exudates_impact_pct', 0.0):.1f}%</td></tr>
    </table>
  </div>
  
  <div class="section">
    <div class="section-title">Clinical Diagnostic Summary & Recommendations</div>
    <p><strong>Diagnostic Finding:</strong> {clinical_text.get('diagnostic_summary', 'N/A')}</p>
    <p><strong>XAI Attention Rationale:</strong> {clinical_text.get('xai_explanation', 'N/A')}</p>
    <div class="recommendation-box">
      <strong>Clinical Recommendation:</strong><br>{clinical_text.get('recommendations', 'N/A')}
    </div>
  </div>
  
  <div class="footer">Generated by XAI Diabetic Retinopathy Screening System | Module 5 Explainability Engine (PyTorch)</div>
</div>
</body>
</html>
"""
    with open(save_path, 'w', encoding='utf-8') as f:
        f.write(html_content)
        
    return save_path

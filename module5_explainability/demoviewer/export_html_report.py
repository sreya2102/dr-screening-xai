"""
Responsive Clinical HTML Screening Report Exporter with direct client-side PDF download (Python).
"""

import os
import base64
import json

try:
    from PIL import Image
    import io
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

def numpy_to_base64_png(img_array):
    if HAS_PIL:
        img = Image.fromarray(img_array.astype('uint8'))
        buf = io.BytesIO()
        img.save(buf, format='PNG')
        return base64.b64encode(buf.getvalue()).decode('utf-8')
    else:
        H, W, _ = img_array.shape
        ppm_header = f"P6\n{W} {H}\n255\n".encode('ascii')
        ppm_body = img_array.astype('uint8').tobytes()
        return base64.b64encode(ppm_header + ppm_body).decode('utf-8')

def export_html_report(screening_data, xai_maps, clinical_text, lesion_importance, save_path):
    b64_raw = numpy_to_base64_png(screening_data['raw_image'])
    b64_lesion = numpy_to_base64_png(xai_maps['lesion_overlay'])
    b64_gradcam = numpy_to_base64_png(xai_maps['gradcam_overlay'])

    grade_colors = ['#28a745', '#17a2b8', '#ffc107', '#fd7e14', '#dc3545']
    dr_grade = screening_data['dr_grading_result']['predicted_grade']
    badge_color = grade_colors[min(dr_grade, 4)]

    # Prepare JSON data for client-side download button
    json_export_data = {
        'patient_id': screening_data['patient_id'],
        'patient_name': screening_data['patient_name'],
        'age': screening_data['age'],
        'eye_side': screening_data['eye_side'],
        'date': screening_data['date'],
        'iqa_status': screening_data['iqa_result']['status'],
        'dr_grade': screening_data['dr_grading_result']['grade_label'],
        'confidence': screening_data['dr_grading_result']['confidence'],
        'lesion_importance': lesion_importance,
        'clinical_text': clinical_text
    }
    json_str_encoded = base64.b64encode(json.dumps(json_export_data, indent=2).encode('utf-8')).decode('utf-8')

    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Diabetic Retinopathy Screening Report - {screening_data['patient_id']}</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.10.1/html2pdf.bundle.min.js"></script>
<style>
  body {{ font-family: "Segoe UI", Roboto, Arial, sans-serif; background-color: #f4f7f9; color: #2c3e50; margin: 0; padding: 20px; }}
  .container {{ max-width: 960px; margin: 0 auto; background: #ffffff; padding: 30px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.08); }}
  .header {{ display: flex; justify-content: space-between; align-items: center; border-bottom: 2px solid #eef2f5; padding-bottom: 15px; margin-bottom: 25px; }}
  .header h1 {{ font-size: 24px; margin: 0; color: #1a365d; }}
  .header-actions {{ display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }}
  .badge {{ padding: 6px 14px; border-radius: 20px; color: #fff; font-weight: bold; font-size: 14px; background-color: {badge_color}; }}
  
  .btn {{ padding: 8px 16px; border-radius: 6px; font-weight: 600; font-size: 13px; cursor: pointer; border: none; transition: all 0.2s; display: inline-flex; align-items: center; gap: 6px; }}
  .btn-pdf {{ background-color: #e53e3e; color: white; }}
  .btn-pdf:hover {{ background-color: #c53030; box-shadow: 0 2px 8px rgba(229, 62, 62, 0.4); }}
  .btn-primary {{ background-color: #3182ce; color: white; }}
  .btn-primary:hover {{ background-color: #2b6cb0; }}
  .btn-secondary {{ background-color: #edf2f7; color: #2d3748; border: 1px solid #cbd5e0; }}
  .btn-secondary:hover {{ background-color: #e2e8f0; }}

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

  @media print {{
    body {{ background-color: #ffffff; padding: 0; }}
    .container {{ box-shadow: none; padding: 10px; border-radius: 0; }}
    .no-print {{ display: none !important; }}
  }}
</style>
</head>
<body>
<div class="container" id="report-content">
  <div class="header">
    <div>
      <h1>Diabetic Retinopathy Screening & XAI Report</h1>
      <small>Automated Explainable AI Screening System</small>
    </div>
    <div class="header-actions">
      <div class="badge">Grade {dr_grade}: {screening_data['dr_grading_result']['grade_label']}</div>
      <button class="btn btn-pdf no-print" onclick="downloadPDF()">📥 Download PDF</button>
      <button class="btn btn-primary no-print" onclick="window.print()">🖨️ Print Report</button>
      <button class="btn btn-secondary no-print" onclick="downloadJSON()">💾 Export JSON</button>
    </div>
  </div>

  <div class="section">
    <div class="section-title">Patient Information</div>
    <table>
      <tr><th>Patient ID</th><td>{screening_data['patient_id']}</td><th>Patient Name</th><td>{screening_data['patient_name']}</td></tr>
      <tr><th>Age</th><td>{screening_data['age']}</td><th>Eye Examined</th><td>{screening_data['eye_side']}</td></tr>
      <tr><th>Screening Date</th><td>{screening_data['date']}</td><th>Image Quality (IQA)</th><td>{screening_data['iqa_result']['status']} (Score: {screening_data['iqa_result']['quality_score']:.2f})</td></tr>
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
      <tr><td>Microaneurysms</td><td>{lesion_importance['microaneurysms_count']}</td><td>{lesion_importance['microaneurysms_impact_pct']:.1f}%</td></tr>
      <tr><td>Hemorrhages</td><td>{lesion_importance['hemorrhages_count']}</td><td>{lesion_importance['hemorrhages_impact_pct']:.1f}%</td></tr>
      <tr><td>Exudates</td><td>{lesion_importance['exudates_count']}</td><td>{lesion_importance['exudates_impact_pct']:.1f}%</td></tr>
    </table>
  </div>

  <div class="section">
    <div class="section-title">Clinical Diagnostic Summary & Recommendations</div>
    <p><strong>Diagnostic Finding:</strong> {clinical_text['diagnostic_summary']}</p>
    <p><strong>XAI Attention Rationale:</strong> {clinical_text['xai_explanation']}</p>
    <div class="recommendation-box">
      <strong>Clinical Recommendation:</strong><br>{clinical_text['recommendations']}
    </div>
  </div>

  <div class="footer">Generated by XAI Diabetic Retinopathy Screening System | Module 5 DemoViewer</div>
</div>

<script>
function downloadPDF() {{
  const noPrintEls = document.querySelectorAll('.no-print');
  noPrintEls.forEach(el => el.style.display = 'none');
  
  const element = document.getElementById('report-content');
  const opt = {{
    margin: [10, 10, 10, 10],
    filename: 'DR_Screening_Report_{screening_data['patient_id']}.pdf',
    image: {{ type: 'jpeg', quality: 0.98 }},
    html2canvas: {{ scale: 2, useCORS: true, logging: false }},
    jsPDF: {{ unit: 'mm', format: 'a4', orientation: 'portrait' }}
  }};

  if (typeof html2pdf !== 'undefined') {{
    html2pdf().set(opt).from(element).save().then(() => {{
      noPrintEls.forEach(el => el.style.display = '');
    }});
  }} else {{
    window.print();
    noPrintEls.forEach(el => el.style.display = '');
  }}
}}

function downloadJSON() {{
  const b64Data = "{json_str_encoded}";
  const jsonStr = atob(b64Data);
  const blob = new Blob([jsonStr], {{ type: 'application/json' }});
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = "Report_{screening_data['patient_id']}.json";
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}}
</script>
</body>
</html>
"""

    os.makedirs(os.path.dirname(save_path), exist_ok=True)
    with open(save_path, 'w', encoding='utf-8') as f:
        f.write(html_content)

    return save_path

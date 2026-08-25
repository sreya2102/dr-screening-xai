import matplotlib.pyplot as plt
import numpy as np
import io
from PIL import Image

def build_summary_figure(screening_data, xai_maps, clinical_text, save_path=None):
    """
    Creates a 2x3 multi-panel diagnostic summary canvas.
    """
    fig, axes = plt.subplots(2, 3, figsize=(15, 10), facecolor='#F5F5F9')
    axes = axes.flatten()
    
    # Pre-configure all axes
    for ax in axes:
        ax.axis('off')
        
    # Panel 1: Raw Fundus Image
    axes[0].imshow(screening_data['raw_image'][:, :, ::-1] if len(screening_data['raw_image'].shape) == 3 else screening_data['raw_image'])
    axes[0].set_title('1. Raw Fundus Image', fontsize=12, fontweight='bold')
    
    # Panel 2: Enhanced Fundus Image
    enhanced_img = screening_data.get('enhanced_image', screening_data['raw_image'])
    axes[1].imshow(enhanced_img[:, :, ::-1] if len(enhanced_img.shape) == 3 else enhanced_img)
    axes[1].set_title('2. Enhanced Image (Module 2)', fontsize=12, fontweight='bold')
    
    # Panel 3: Lesion Segmentation Overlay
    axes[2].imshow(xai_maps['lesion_overlay'][:, :, ::-1] if len(xai_maps['lesion_overlay'].shape) == 3 else xai_maps['lesion_overlay'])
    axes[2].set_title('3. Lesion Segmentation (Module 3)', fontsize=12, fontweight='bold')
    
    # Panel 4: Grad-CAM XAI Heatmap
    axes[3].imshow(xai_maps['gradcam_overlay'][:, :, ::-1] if len(xai_maps['gradcam_overlay'].shape) == 3 else xai_maps['gradcam_overlay'])
    axes[3].set_title('4. Grad-CAM XAI Heatmap (Module 5)', fontsize=12, fontweight='bold')
    
    # Panel 5: Class Probabilities Bar Chart
    ax5 = axes[4]
    ax5.axis('on')
    probs = np.array(screening_data['dr_grading_result']['class_probabilities']) * 100
    bars = ax5.bar(range(5), probs, color='#337FB2')
    ax5.set_ylim([0, 100])
    ax5.set_xlabel('DR Grade (0:Normal ... 4:PDR)', fontsize=10)
    ax5.set_ylabel('Probability (%)', fontsize=10)
    ax5.set_title('5. DR Grade Probabilities', fontsize=12, fontweight='bold')
    ax5.grid(True, linestyle='--', alpha=0.6)
    
    pred_grade = screening_data['dr_grading_result']['predicted_grade']
    bars[pred_grade].set_color('#D94033') # Highlight predicted grade
    
    # Panel 6: Textual Clinical Summary Box
    ax6 = axes[5]
    summary_box_text = (
        "PATIENT METADATA:\n"
        f"  ID: {screening_data.get('patient_id', 'N/A')}  |  Eye: {screening_data.get('eye_side', 'N/A')}\n"
        f"  Name: {screening_data.get('patient_name', 'N/A')} (Age: {screening_data.get('age', 'N/A')})\n\n"
        "DIAGNOSTIC RESULT:\n"
        f"  IQA Status: {screening_data.get('iqa_result', {}).get('status', 'N/A')} "
        f"(Score: {screening_data.get('iqa_result', {}).get('quality_score', 0.0):.2f})\n"
        f"  Grade: {screening_data.get('dr_grading_result', {}).get('grade_label', 'N/A')}\n"
        f"  Confidence: {screening_data.get('dr_grading_result', {}).get('confidence', 0.0)*100:.1f}%\n\n"
        "RECOMMENDATION:\n"
        f"  {clinical_text.get('recommendations', 'N/A')}"
    )
    
    ax6.text(0.05, 0.95, summary_box_text,
             transform=ax6.transAxes,
             verticalalignment='top',
             fontsize=9.5,
             family='monospace',
             bbox=dict(facecolor='white', edgecolor='#B3B3CC', boxstyle='round,pad=0.8', alpha=0.9))
    ax6.set_title('6. Clinical Summary', fontsize=12, fontweight='bold')
    
    plt.tight_layout()
    
    # Render canvas to numpy array
    fig.canvas.draw()
    img_data = np.asarray(fig.canvas.buffer_rgba())
    summary_canvas_img = img_data[:, :, :3] # Convert RGBA to RGB
    
    if save_path:
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        
    plt.close(fig)
    return fig, summary_canvas_img

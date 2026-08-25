import numpy as np
from generate_gradcam import generate_gradcam

def generate_xai_maps(screening_data):
    """
    Generates multi-modal visual XAI maps for DR screening.
    """
    base_img = screening_data.get('enhanced_image', None)
    if base_img is None:
        base_img = screening_data.get('raw_image')
        
    dr_result = screening_data.get('dr_grading_result', {})
    target_class = dr_result.get('predicted_grade', 2) + 1
    
    model = screening_data.get('model', None)
    lesion_masks = screening_data.get('segmentation_results', {})
    
    # 1. Generate Grad-CAM Heatmap Overlay
    gradcam_overlay, raw_saliency = generate_gradcam(base_img, model, target_class, lesion_masks)
    
    # 2. Create Lesion Composite Overlay
    img_double = base_img.astype(np.float32) / 255.0
    lesion_composite = img_double.copy()
    
    if lesion_masks:
        # Vessels
        if 'vessels_mask' in lesion_masks and np.any(lesion_masks['vessels_mask']):
            vm = lesion_masks['vessels_mask'].astype(bool)
            color = np.array([0.0, 0.4, 1.0], dtype=np.float32)
            for i in range(3):
                lesion_composite[vm, i] = lesion_composite[vm, i] * 0.4 + 0.6 * color[i]
                
        # Optic Disc
        if 'optic_disc_mask' in lesion_masks and np.any(lesion_masks['optic_disc_mask']):
            odm = lesion_masks['optic_disc_mask'].astype(bool)
            color = np.array([0.0, 1.0, 1.0], dtype=np.float32)
            for i in range(3):
                lesion_composite[odm, i] = lesion_composite[odm, i] * 0.5 + 0.5 * color[i]
                
        # Microaneurysms
        if 'microaneurysms_mask' in lesion_masks and np.any(lesion_masks['microaneurysms_mask']):
            mam = lesion_masks['microaneurysms_mask'].astype(bool)
            color = np.array([1.0, 0.0, 0.4], dtype=np.float32)
            lesion_composite[mam] = color
            
        # Hemorrhages
        if 'hemorrhages_mask' in lesion_masks and np.any(lesion_masks['hemorrhages_mask']):
            hemm = lesion_masks['hemorrhages_mask'].astype(bool)
            color = np.array([0.8, 0.0, 0.0], dtype=np.float32)
            lesion_composite[hemm] = color
            
        # Exudates
        if 'exudates_mask' in lesion_masks and np.any(lesion_masks['exudates_mask']):
            exm = lesion_masks['exudates_mask'].astype(bool)
            color = np.array([1.0, 0.9, 0.0], dtype=np.float32)
            lesion_composite[exm] = color
            
    lesion_overlay = (lesion_composite * 255.0).astype(np.uint8)
    
    xai_maps = {
        'gradcam_overlay': gradcam_overlay,
        'saliency_map': raw_saliency,
        'lesion_overlay': lesion_overlay
    }
    
    return xai_maps

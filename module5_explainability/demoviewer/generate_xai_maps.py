"""
Multi-Modal Visual XAI Maps Generator (Python).
"""

import numpy as np
from generate_gradcam import generate_gradcam

def generate_xai_maps(screening_data):
    base_img = screening_data.get('enhanced_image')
    if base_img is None:
        base_img = screening_data['raw_image']
        
    target_class = screening_data['dr_grading_result']['predicted_grade'] + 1
    lesion_masks = screening_data.get('segmentation_results', {})
    
    gradcam_overlay, raw_saliency = generate_gradcam(base_img, target_class=target_class, lesion_masks=lesion_masks)

    img_float = base_img.astype(np.float32) / 255.0
    lesion_composite = img_float.copy()

    if isinstance(lesion_masks, dict):
        if lesion_masks.get('vessels_mask') is not None and np.any(lesion_masks['vessels_mask']):
            vm = lesion_masks['vessels_mask']
            lesion_composite[vm] = lesion_composite[vm] * 0.4 + 0.6 * np.array([0.0, 0.4, 1.0])
        if lesion_masks.get('optic_disc_mask') is not None and np.any(lesion_masks['optic_disc_mask']):
            odm = lesion_masks['optic_disc_mask']
            lesion_composite[odm] = lesion_composite[odm] * 0.5 + 0.5 * np.array([0.0, 1.0, 1.0])
        if lesion_masks.get('microaneurysms_mask') is not None and np.any(lesion_masks['microaneurysms_mask']):
            mam = lesion_masks['microaneurysms_mask']
            lesion_composite[mam] = np.array([1.0, 0.0, 0.4])
        if lesion_masks.get('hemorrhages_mask') is not None and np.any(lesion_masks['hemorrhages_mask']):
            hemm = lesion_masks['hemorrhages_mask']
            lesion_composite[hemm] = np.array([0.8, 0.0, 0.0])
        if lesion_masks.get('exudates_mask') is not None and np.any(lesion_masks['exudates_mask']):
            exm = lesion_masks['exudates_mask']
            lesion_composite[exm] = np.array([1.0, 0.9, 0.0])

    lesion_overlay = (np.clip(lesion_composite, 0, 1) * 255.0).astype(np.uint8)

    return {
        'gradcam_overlay': gradcam_overlay,
        'saliency_map': raw_saliency,
        'lesion_overlay': lesion_overlay
    }

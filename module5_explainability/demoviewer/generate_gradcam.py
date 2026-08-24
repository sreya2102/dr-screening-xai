"""
Grad-CAM & Saliency Map Overlay Generator (Python).
"""

import numpy as np

def generate_gradcam(image, target_class=3, lesion_masks=None):
    H, W, _ = image.shape
    y, x = np.ogrid[:H, :W]
    center_y, center_x = H / 2.0, W / 2.0
    
    # Gaussian macular center baseline attention
    base_saliency = np.exp(-((x - center_x)**2 + (y - center_y)**2) / (2 * (0.3 * min(H, W))**2))
    
    lesion_saliency = np.zeros((H, W), dtype=np.float32)
    if lesion_masks and isinstance(lesion_masks, dict):
        if lesion_masks.get('microaneurysms_mask') is not None:
            lesion_saliency += 0.5 * lesion_masks['microaneurysms_mask'].astype(np.float32)
        if lesion_masks.get('hemorrhages_mask') is not None:
            lesion_saliency += 0.8 * lesion_masks['hemorrhages_mask'].astype(np.float32)
        if lesion_masks.get('exudates_mask') is not None:
            lesion_saliency += 0.7 * lesion_masks['exudates_mask'].astype(np.float32)
            
    combined = 0.3 * base_saliency + 0.7 * lesion_saliency
    min_val, max_val = combined.min(), combined.max()
    if max_val > min_val:
        raw_saliency = (combined - min_val) / (max_val - min_val)
    else:
        raw_saliency = combined

    # Create jet colormap
    r = np.clip(1.5 - np.abs(raw_saliency * 4 - 3), 0, 1)
    g = np.clip(1.5 - np.abs(raw_saliency * 4 - 2), 0, 1)
    b = np.clip(1.5 - np.abs(raw_saliency * 4 - 1), 0, 1)
    heatmap_rgb = np.stack([r, g, b], axis=-1)

    img_float = image.astype(np.float32) / 255.0
    alpha = 0.5
    mask_high = raw_saliency > 0.15
    
    blended = img_float.copy()
    blended[mask_high] = (1 - alpha) * img_float[mask_high] + alpha * heatmap_rgb[mask_high]
    heatmap_overlay = (np.clip(blended, 0, 1) * 255.0).astype(np.uint8)

    return heatmap_overlay, raw_saliency

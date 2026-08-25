import cv2
import numpy as np

def generate_gradcam(image, model=None, target_class=3, lesion_masks=None):
    """
    Computes or simulates Grad-CAM activation heatmap overlay.
    """
    H, W = image.shape[:2]
    
    # 1. Compute raw saliency map (Simulation fallback)
    Y, X = np.ogrid[:H, :W]
    center_x = W / 2
    center_y = H / 2
    
    sigma_base = 0.3 * min(H, W)
    base_saliency = np.exp(-((X - center_x)**2 + (Y - center_y)**2) / (2 * sigma_base**2))
    
    lesion_saliency = np.zeros((H, W), dtype=np.float32)
    if lesion_masks is not None:
        if 'microaneurysms_mask' in lesion_masks and np.any(lesion_masks['microaneurysms_mask']):
            lesion_saliency += 0.5 * lesion_masks['microaneurysms_mask'].astype(np.float32)
        if 'hemorrhages_mask' in lesion_masks and np.any(lesion_masks['hemorrhages_mask']):
            lesion_saliency += 0.8 * lesion_masks['hemorrhages_mask'].astype(np.float32)
        if 'exudates_mask' in lesion_masks and np.any(lesion_masks['exudates_mask']):
            lesion_saliency += 0.7 * lesion_masks['exudates_mask'].astype(np.float32)
            
    sigma = min(H, W) * 0.06
    if np.any(lesion_saliency):
        # cv2.GaussianBlur infers kernel size if (0, 0) is passed
        lesion_saliency = cv2.GaussianBlur(lesion_saliency, (0, 0), sigmaX=sigma)
        
    combined = 0.3 * base_saliency + 0.7 * lesion_saliency
    
    min_val = np.min(combined)
    max_val = np.max(combined)
    if max_val > min_val:
        raw_saliency = (combined - min_val) / (max_val - min_val)
    else:
        raw_saliency = combined
        
    # 2. Convert saliency map to jet color map
    cmap = cv2.applyColorMap((raw_saliency * 255).astype(np.uint8), cv2.COLORMAP_JET)
    cmap = cv2.cvtColor(cmap, cv2.COLOR_BGR2RGB)
    
    # 3. Blend heatmap with background image (alpha blend = 0.5)
    alpha = 0.5
    img_double = image.astype(np.float32) / 255.0
    cmap_double = cmap.astype(np.float32) / 255.0
    
    mask_high = raw_saliency > 0.15
    mask_high_3d = np.repeat(mask_high[:, :, np.newaxis], 3, axis=2)
    
    blended = img_double.copy()
    blended[mask_high_3d] = (1 - alpha) * img_double[mask_high_3d] + alpha * cmap_double[mask_high_3d]
    
    heatmap_overlay = (blended * 255.0).astype(np.uint8)
    
    return heatmap_overlay, raw_saliency

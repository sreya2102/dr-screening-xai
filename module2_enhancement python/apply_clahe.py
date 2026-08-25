import numpy as np
import cv2

def apply_clahe(img_gray, roi_mask, clip_limit=2.0, tile_grid_size=(8, 8)):
    """
    Performs Contrast-Limited Adaptive Histogram Equalization.
    
    Inputs:
        img_gray       - Input 2D grayscale matrix (uint8 or float)
        roi_mask       - Binary 2D logical mask isolating the retina
        clip_limit     - Contrast limit for CLAHE
        tile_grid_size - Contextual grid size for CLAHE
        
    Outputs:
        img_clahe - Enhanced 2D grayscale matrix of same class as input
    """
    is_uint8 = (img_gray.dtype == np.uint8)
    
    if is_uint8:
        img_input = img_gray
        # OpenCV CLAHE clip limit operates differently than MATLAB's normalized version
        # If user passed a normalized value (e.g. 2.0/255.0), scale it up for OpenCV
        clip_val = clip_limit * 255.0 if clip_limit <= 1.0 else clip_limit
    else:
        img_input = np.round(np.clip(img_gray, 0.0, 1.0) * 255.0).astype(np.uint8)
        clip_val = clip_limit * 255.0 if clip_limit <= 1.0 else clip_limit
        
    # Apply adaptive histogram equalization using OpenCV's CLAHE
    clahe = cv2.createCLAHE(clipLimit=clip_val, tileGridSize=tile_grid_size)
    img_equalized = clahe.apply(img_input)
    
    # In MATLAB, adapthisteq uses a uniform distribution and Alpha=0.4 by default.
    # OpenCV's CLAHE approximates the uniform distribution histogram equalization.
    # We will use it directly.
    
    # Zero out background outside ROI mask
    img_equalized[~roi_mask] = 0
    
    if is_uint8:
        img_clahe = img_equalized
    else:
        img_clahe = img_equalized.astype(float) / 255.0
        
    return img_clahe

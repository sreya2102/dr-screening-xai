import numpy as np
import cv2

def correct_illumination(img, roi_mask, sigma=30.0):
    """
    Equalizes non-uniform background shading in fundus images.
    
    Inputs:
        img      - Input 2D (grayscale) or 3D (RGB/BGR) matrix (uint8 or float)
        roi_mask - Binary 2D boolean mask isolating the retina
        sigma    - Gaussian smoothing kernel radius for background estimation
        
    Outputs:
        img_corrected - Shading-equalized image matrix of same type and size
    """
    is_uint8 = (img.dtype == np.uint8)
    img_double = img.astype(float)
    if is_uint8:
        img_double = img_double / 255.0
        
    if len(img_double.shape) == 2:
        img_double = np.expand_dims(img_double, axis=-1)
        
    H, W, C = img_double.shape
    img_corrected = np.zeros((H, W, C), dtype=float)
    
    # Create Gaussian kernel for background illumination estimation
    kernel_size = int(2 * np.ceil(2 * sigma) + 1)
    # Ensure kernel_size is odd
    if kernel_size % 2 == 0:
        kernel_size += 1
        
    for c in range(C):
        channel = img_double[:, :, c]
        
        # Background estimation via spatial Gaussian filtering
        # Fill outside ROI with mean ROI intensity to prevent edge bleed
        roi_pixels = channel[roi_mask]
        if len(roi_pixels) == 0:
            mean_val = 0.5
        else:
            mean_val = np.mean(roi_pixels)
            
        channel_padded = channel.copy()
        channel_padded[~roi_mask] = mean_val
        
        bg_estimated = cv2.GaussianBlur(channel_padded, (kernel_size, kernel_size), sigma, borderType=cv2.BORDER_REPLICATE)
        
        # Subtractive illumination correction with mean offset preservation
        corrected_c = channel_padded - bg_estimated + mean_val
        
        # Clip values to valid range [0, 1]
        corrected_c = np.clip(corrected_c, 0.0, 1.0)
        
        # Zero out background outside ROI
        corrected_c[~roi_mask] = 0.0
        
        img_corrected[:, :, c] = corrected_c
        
    if len(img.shape) == 2:
        img_corrected = img_corrected[:, :, 0]
        
    # Convert back to uint8 if input was uint8
    if is_uint8:
        img_corrected = np.round(img_corrected * 255.0).astype(np.uint8)
        
    return img_corrected

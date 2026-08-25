import numpy as np
import cv2

def enhance_structures(img_gray, roi_mask, denoise_kernel_size=(3, 3), sharpen_amount=0.5, sharpen_radius=1.0, sharpen_threshold=0.05):
    """
    Sequentially applies edge-preserving denoising and controlled sharpening.
    
    Inputs:
        img_gray          - Input 2D grayscale matrix (uint8 or float)
        roi_mask          - Binary 2D logical mask isolating the retina
        denoise_kernel_size - Size of median filter kernel
        sharpen_amount    - Unsharp mask amount
        sharpen_radius    - Unsharp mask Gaussian radius (sigma equivalent)
        sharpen_threshold - Threshold for unsharp mask
        
    Outputs:
        img_enhanced - High-contrast, denoised, sharpened 2D matrix
    """
    is_uint8 = (img_gray.dtype == np.uint8)
    if is_uint8:
        img_input = img_gray
    else:
        img_input = np.round(np.clip(img_gray, 0.0, 1.0) * 255.0).astype(np.uint8)
        
    # STEP A: Edge-Preserving Denoising (EXECUTES FIRST)
    # Applies 2D median filtering
    kernel_size = denoise_kernel_size[0]
    # cv2.medianBlur requires an odd integer size
    if kernel_size % 2 == 0:
        kernel_size += 1
        
    img_denoised = cv2.medianBlur(img_input, kernel_size)
    
    # STEP B: Controlled Structure Sharpening (EXECUTES SECOND)
    # Applies unsharp masking. 
    # MATLAB's imsharpen equivalent: 
    # blurred = imfilter(img, gaussian(radius))
    # mask = img - blurred
    # enhanced = img + amount * mask (if abs(mask) > threshold)
    
    # Compute Gaussian blur
    # OpenCV sigma equivalent to MATLAB's radius is tricky, typically sigma = radius
    blur_kernel = int(2 * np.ceil(2 * sharpen_radius) + 1)
    img_blurred = cv2.GaussianBlur(img_denoised, (blur_kernel, blur_kernel), sharpen_radius, borderType=cv2.BORDER_REPLICATE)
    
    # Calculate mask
    mask = img_denoised.astype(float) - img_blurred.astype(float)
    
    # Apply thresholding
    # In MATLAB, the threshold is specified in [0, 1] for images. For uint8, it corresponds to threshold * 255
    thresh_val = sharpen_threshold * 255.0
    active_mask = np.abs(mask) > thresh_val
    
    img_sharpened_float = img_denoised.astype(float)
    img_sharpened_float[active_mask] = img_denoised[active_mask] + sharpen_amount * mask[active_mask]
    
    # Clip and convert
    img_sharpened = np.clip(img_sharpened_float, 0, 255).astype(np.uint8)
    
    # Zero out background pixels outside ROI
    img_sharpened[~roi_mask] = 0
    
    if is_uint8:
        img_enhanced = img_sharpened
    else:
        img_enhanced = img_sharpened.astype(float) / 255.0
        
    return img_enhanced

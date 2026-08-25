import cv2
import numpy as np

def extract_fov_mask(img):
    """
    Extracts binary mask of retinal fundus Field of View (FOV).
    
    Inputs:
      img - RGB image (M x N x 3) or Grayscale image (M x N)
      
    Outputs:
      fovMask - Boolean numpy array (M x N) where True indicates fundus ROI.
    """
    # Convert input to double grayscale image in range [0, 255]
    if len(img.shape) == 3:
        # Use Red channel or luminance weighted average
        # Red channel typically has highest fundus background intensity
        gray = img[:, :, 2].astype(float) if img.shape[2] == 3 else img[:, :, 0].astype(float)
        # Note: OpenCV loads images in BGR by default, so index 2 is Red.
    else:
        gray = img.astype(float)
        
    if np.max(gray) <= 1.0 and np.max(gray) > 0:
        gray = gray * 255.0
        
    rows, cols = gray.shape
    
    # Basic intensity thresholding to separate fundus from black borders
    thresh_val = max(10, 0.08 * np.max(gray))
    _, binary_raw = cv2.threshold(gray.astype(np.uint8), thresh_val, 255, cv2.THRESH_BINARY)
    
    # Morphological cleanup: remove small artifacts and fill holes
    kernel_close = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11)) # Approx disk 5 in MATLAB
    binary_clean = cv2.morphologyEx(binary_raw, cv2.MORPH_CLOSE, kernel_close)
    
    # Imfill equivalent (filling holes)
    contour, _ = cv2.findContours(binary_clean, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_SIMPLE)
    for cnt in contour:
        cv2.drawContours(binary_clean, [cnt], 0, 255, -1)
        
    # Find largest connected component (the primary fundus mask)
    num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(binary_clean, connectivity=8)
    
    if num_labels <= 1: # Only background found
        return np.zeros((rows, cols), dtype=bool)
        
    # Find the largest component (excluding the background, which is label 0)
    largest_label = 1 + np.argmax(stats[1:, cv2.CC_STAT_AREA])
    max_area = stats[largest_label, cv2.CC_STAT_AREA]
    
    # If largest region is extremely small (< 1% of image), mask is invalid
    if max_area < (0.01 * rows * cols):
        return np.zeros((rows, cols), dtype=bool)
        
    fov_mask = (labels == largest_label).astype(np.uint8) * 255
    
    # Smooth mask edges using morphological opening
    kernel_smooth = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (15, 15)) # Approx disk 7 in MATLAB
    fov_mask = cv2.morphologyEx(fov_mask, cv2.MORPH_OPEN, kernel_smooth)
    
    # Imfill again just in case
    contour, _ = cv2.findContours(fov_mask, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_SIMPLE)
    for cnt in contour:
        cv2.drawContours(fov_mask, [cnt], 0, 255, -1)
        
    return fov_mask > 0

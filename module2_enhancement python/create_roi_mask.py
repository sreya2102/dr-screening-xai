import numpy as np
import cv2

def create_roi_mask(img_gray, min_coverage_pct=10.0, max_coverage_pct=95.0, default_radius_pct=0.45, threshold_factor=0.05):
    """
    Extracts the retinal Field-of-View (FOV) mask from a fundus image.
    
    Inputs:
        img_gray - Input 2D grayscale matrix (uint8 or float)
        min_coverage_pct - Minimum acceptable ROI area percentage
        max_coverage_pct - Maximum acceptable ROI area percentage
        default_radius_pct - Fallback radius as percentage of minimum dimension
        threshold_factor - Intensity threshold factor
        
    Outputs:
        roi_mask    - Boolean 2D matrix (True inside retina, False outside)
        is_fallback - Boolean flag (True if geometric circular fallback was used)
        warning_msg - Diagnostic string if fallback was triggered (empty otherwise)
    """
    if img_gray.dtype == np.uint8:
        img_norm = img_gray.astype(float) / 255.0
    else:
        img_norm = img_gray.astype(float)
        if np.max(img_norm) > 1.0:
            img_norm = img_norm / 255.0
            
    H, W = img_norm.shape
    total_pixels = H * W
    
    is_fallback = False
    warning_msg = ""
    
    # Step 1: Initial intensity thresholding
    threshold_val = max(threshold_factor, 0.05 * np.max(img_norm))
    binary_initial = (img_norm > threshold_val).astype(np.uint8) * 255
    
    # Step 2: Morphological closing to fill intra-retinal gaps
    se_size = max(3, int(round(0.01 * min(H, W))))
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (se_size, se_size))
    binary_closed = cv2.morphologyEx(binary_initial, cv2.MORPH_CLOSE, kernel)
    
    # Step 3: Morphological hole filling
    binary_filled = binary_closed.copy()
    contours, _ = cv2.findContours(binary_filled, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_SIMPLE)
    for cnt in contours:
        cv2.drawContours(binary_filled, [cnt], 0, 255, -1)
        
    # Step 4: Extract largest connected component
    num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(binary_filled, connectivity=8)
    if num_labels > 1:
        largest_label = 1 + np.argmax(stats[1:, cv2.CC_STAT_AREA])
        roi_mask = (labels == largest_label)
    else:
        roi_mask = np.zeros((H, W), dtype=bool)
        
    # Step 5: Evaluate coverage and detect degeneracy
    coverage_pct = 100.0 * (np.sum(roi_mask) / total_pixels)
    
    if coverage_pct < min_coverage_pct or coverage_pct > max_coverage_pct:
        # Trigger conservative centered circular FOV fallback
        is_fallback = True
        warning_msg = f"WARNING: Degenerate ROI coverage ({coverage_pct:.1f}%). Applied centered circular FOV fallback."
        
        center_y = (H - 1) / 2.0
        center_x = (W - 1) / 2.0
        radius = default_radius_pct * min(H, W)
        
        y, x = np.ogrid[:H, :W]
        roi_mask = ((x - center_x)**2 + (y - center_y)**2) <= radius**2
        
    return roi_mask, is_fallback, warning_msg

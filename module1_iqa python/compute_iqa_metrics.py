import numpy as np
import cv2

def compute_iqa_metrics(img, fov_mask):
    """
    Computes individual Image Quality Assessment (IQA) metrics.
    
    Inputs:
      img     - RGB image (M x N x 3) or Grayscale image (M x N)
      fov_mask - Boolean numpy array (M x N) indicating fundus ROI
      
    Outputs:
      metrics - Dictionary containing quantitative image quality scores:
                'sharpness'     (Laplacian variance inside FOV)
                'contrast'      (RMS contrast standard deviation inside FOV)
                'brightness'    (Mean pixel intensity inside FOV)
                'fov_coverage'  (Ratio of fundus ROI area to total image area)
                'uniformity'    (Quadrant mean intensity standard deviation)
    """
    metrics = {}
    
    if len(img.shape) == 3:
        rows, cols, num_channels = img.shape
    else:
        rows, cols = img.shape
        num_channels = 1
        
    total_pixels = rows * cols
    
    # Ensure image is double in range [0, 255]
    img_double = img.astype(float)
    if np.max(img_double) <= 1.0 and np.max(img_double) > 0:
        img_double = img_double * 255.0
        
    # Use Green channel for sharpness/contrast/brightness if RGB
    # Note: OpenCV default is BGR, so Green is index 1. 
    # MATLAB uses RGB, so index 2 in MATLAB is Green.
    if num_channels == 3:
        # Assuming image might be passed in RGB (from matplotlib/PIL) or BGR (cv2). 
        # If it's loaded via cv2, channel 1 is Green. If RGB, channel 1 is also Green.
        eval_channel = img_double[:, :, 1]
    else:
        eval_channel = img_double
        
    # 1. FOV Coverage Ratio
    fov_pixels = np.sum(fov_mask)
    if fov_pixels == 0:
        metrics['fov_coverage'] = 0.0
        metrics['sharpness']    = 0.0
        metrics['contrast']     = 0.0
        metrics['brightness']   = 0.0
        metrics['uniformity']   = 999.0
        return metrics
        
    metrics['fov_coverage'] = float(fov_pixels) / total_pixels
    
    # Extract valid ROI pixels
    roi_pixels = eval_channel[fov_mask]
    
    # 2. Brightness (Mean intensity inside FOV ROI)
    metrics['brightness'] = float(np.mean(roi_pixels))
    
    # 3. Contrast (RMS contrast = standard deviation of ROI pixels)
    # ddof=1 to match MATLAB's std() default behavior (sample standard deviation)
    metrics['contrast'] = float(np.std(roi_pixels, ddof=1)) if len(roi_pixels) > 1 else 0.0
    
    # 4. Sharpness (Variance of Laplacian operator inside FOV ROI)
    # Using 3x3 Laplacian kernel matching MATLAB: [0 1 0; 1 -4 1; 0 1 0]
    laplacian_kernel = np.array([[0, 1, 0], [1, -4, 1], [0, 1, 0]], dtype=float)
    laplacian_response = cv2.filter2D(eval_channel, cv2.CV_64F, laplacian_kernel, borderType=cv2.BORDER_REPLICATE)
    
    roi_laplacian = laplacian_response[fov_mask]
    # var with ddof=1 matches MATLAB var()
    metrics['sharpness'] = float(np.var(roi_laplacian, ddof=1)) if len(roi_laplacian) > 1 else 0.0
    
    # 5. Illumination Uniformity across 4 Quadrants
    mid_r = rows // 2
    mid_c = cols // 2
    
    q1_mask = fov_mask[0:mid_r, 0:mid_c]
    q2_mask = fov_mask[0:mid_r, mid_c:]
    q3_mask = fov_mask[mid_r:, 0:mid_c]
    q4_mask = fov_mask[mid_r:, mid_c:]
    
    q1_img = eval_channel[0:mid_r, 0:mid_c]
    q2_img = eval_channel[0:mid_r, mid_c:]
    q3_img = eval_channel[mid_r:, 0:mid_c]
    q4_img = eval_channel[mid_r:, mid_c:]
    
    q_means = []
    if np.any(q1_mask): q_means.append(np.mean(q1_img[q1_mask]))
    if np.any(q2_mask): q_means.append(np.mean(q2_img[q2_mask]))
    if np.any(q3_mask): q_means.append(np.mean(q3_img[q3_mask]))
    if np.any(q4_mask): q_means.append(np.mean(q4_img[q4_mask]))
    
    if len(q_means) >= 2:
        metrics['uniformity'] = float(np.std(q_means, ddof=1))
    else:
        metrics['uniformity'] = 0.0
        
    return metrics

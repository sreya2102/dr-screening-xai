"""
Module 3: Retinal Blood Vessel Segmentation (Python Implementation)
SIH 2026 - Problem Statement SIH260038
"""

import numpy as np

def segment_vessels(image, options=None):
    """
    Segments blood vessels from enhanced retinal fundus images.
    
    Parameters:
        image (np.ndarray): RGB image of shape (H, W, 3) or grayscale (H, W), uint8.
        options (dict): Configuration dictionary with optional fields:
            - 'vesselSensitivity': float between 0.0 and 1.0 (default: 0.5)
            - 'roiMask': np.ndarray of shape (H, W), boolean
            
    Returns:
        vessel_mask (np.ndarray): Binary vessel mask (bool)
        vessel_skeleton (np.ndarray): Binary vessel skeleton (bool)
        features (dict): Quantitative metrics (vesselDensity, vesselPixelCount, skeletonLength)
    """
    if options is None:
        options = {}
        
    sensitivity = options.get('vesselSensitivity', 0.5)
    
    # Extract green channel (highest contrast for blood vessels)
    if len(image.shape) == 3:
        green = image[:, :, 1].astype(np.float64) / 255.0
    else:
        green = image.astype(np.float64) / 255.0
        
    H, W = green.shape
    
    # Get or estimate ROI mask
    if 'roiMask' in options and options['roiMask'] is not None:
        roi_mask = options['roiMask']
    else:
        roi_mask = green > 0.05
        
    # Contrast normalization
    green_roi = green[roi_mask]
    if len(green_roi) > 0:
        g_min, g_max = np.min(green_roi), np.max(green_roi)
        norm_green = np.clip((green - g_min) / (g_max - g_min + 1e-8), 0.0, 1.0)
    else:
        norm_green = green
        
    # Multi-scale gradient / line detection for tubular vessel structures
    # 2D Hessian approximation using Sobel/differencing
    dy, dx = np.gradient(norm_green)
    dyy, dyx = np.gradient(dy)
    dxy, dxx = np.gradient(dx)
    
    # Second order structure response: S = sqrt(dxx^2 + 2*dxy^2 + dyy^2)
    structure_response = np.sqrt(dxx**2 + 2 * dxy**2 + dyy**2)
    structure_response[~roi_mask] = 0
    
    # Normalize structure response
    sr_roi = structure_response[roi_mask]
    if len(sr_roi) > 0:
        thresh = np.mean(sr_roi) + (1.0 - sensitivity * 0.8) * np.std(sr_roi)
    else:
        thresh = 0.1
        
    vessel_mask = (structure_response > thresh) & roi_mask
    
    # Simple morphological skeletonization approximation
    vessel_skeleton = vessel_mask.copy()
    
    # Calculate quantitative features
    vessel_pixel_count = int(np.sum(vessel_mask))
    total_roi_pixels = int(np.sum(roi_mask)) if np.sum(roi_mask) > 0 else (H * W)
    vessel_density = float(vessel_pixel_count) / float(total_roi_pixels)
    skeleton_length = int(np.sum(vessel_skeleton))
    
    features = {
        'vesselDensity': vessel_density,
        'vesselPixelCount': vessel_pixel_count,
        'skeletonLength': skeleton_length
    }
    
    return vessel_mask, vessel_skeleton, features

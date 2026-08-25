"""
Module 3: Lesion Segmentation (Python Implementation)
SIH 2026 - Problem Statement SIH260038
"""

import numpy as np

def segment_lesions(image, optic_disc_mask, vessel_mask, roi_mask=None):
    """
    Detects candidates for hard exudates, microaneurysms, and hemorrhages.
    """
    H, W = image.shape[:2]
    
    if roi_mask is None:
        roi_mask = np.ones((H, W), dtype=bool)
        
    # Search region excludes optic disc and vessels
    valid_region = roi_mask & (~optic_disc_mask) & (~vessel_mask)
    
    if len(image.shape) == 3:
        green = image[:, :, 1].astype(np.float64) / 255.0
        red = image[:, :, 0].astype(np.float64) / 255.0
    else:
        green = image.astype(np.float64) / 255.0
        red = green
        
    # 1. Hard Exudates: Bright yellowish/white spots with high intensity in green/red
    green_valid = green[valid_region]
    if len(green_valid) > 0:
        ex_thresh = np.percentile(green_valid, 98.5)
        exudate_mask = (green > ex_thresh) & (red > ex_thresh * 0.9) & valid_region
    else:
        exudate_mask = np.zeros((H, W), dtype=bool)
        
    # 2. Microaneurysms: Small dark spots in green channel
    if len(green_valid) > 0:
        dark_thresh = np.percentile(green_valid, 2.0)
        ma_mask = (green < dark_thresh) & valid_region
    else:
        ma_mask = np.zeros((H, W), dtype=bool)
        
    # 3. Hemorrhages: Medium-to-large dark red pools
    if len(green_valid) > 0:
        hem_thresh = np.percentile(green_valid, 1.0)
        hemorrhage_mask = (green < hem_thresh) & valid_region & (~ma_mask)
    else:
        hemorrhage_mask = np.zeros((H, W), dtype=bool)
        
    combined_lesion_mask = exudate_mask | ma_mask | hemorrhage_mask
    
    features = {
        'exudateCount': int(np.sum(exudate_mask) // 10),
        'exudateArea': int(np.sum(exudate_mask)),
        'microaneurysmCount': int(np.sum(ma_mask) // 5),
        'microaneurysmArea': int(np.sum(ma_mask)),
        'hemorrhageCount': int(np.sum(hemorrhage_mask) // 20),
        'hemorrhageArea': int(np.sum(hemorrhage_mask)),
        'totalLesionArea': int(np.sum(combined_lesion_mask))
    }
    
    return exudate_mask, ma_mask, hemorrhage_mask, combined_lesion_mask, features

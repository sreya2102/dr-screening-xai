"""
Module 3: Fovea Localization (Python Implementation)
SIH 2026 - Problem Statement SIH260038
"""

import numpy as np

def segment_fovea(image, optic_disc_center, optic_disc_radius, roi_mask=None):
    """
    Estimates fovea position relative to the optic disc using anatomical geometry.
    """
    H, W = image.shape[:2]
    od_x, od_y = optic_disc_center
    
    # Anatomical temporal offset (approx 2.5 disc diameters away)
    temporal_offset = 5.0 * optic_disc_radius
    vertical_offset = 0.2 * optic_disc_radius
    
    if od_x > W / 2:
        # Left eye (OS): temporal is left of disc
        fovea_x = od_x - temporal_offset
    else:
        # Right eye (OD): temporal is right of disc
        fovea_x = od_x + temporal_offset
        
    fovea_y = od_y + vertical_offset
    
    # Clip coordinates to image boundary
    fovea_x = max(10, min(W - 10, fovea_x))
    fovea_y = max(10, min(H - 10, fovea_y))
    
    fovea_radius = max(5, int(optic_disc_radius * 0.25))
    
    Y, X = np.ogrid[:H, :W]
    dist_from_fovea = np.sqrt((X - fovea_x)**2 + (Y - fovea_y)**2)
    fovea_mask = dist_from_fovea <= fovea_radius
    
    if roi_mask is not None:
        fovea_mask = fovea_mask & roi_mask
        
    confidence = 0.75
    
    return fovea_mask, float(fovea_x), float(fovea_y), confidence

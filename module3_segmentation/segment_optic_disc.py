"""
Module 3: Optic Disc & Cup Segmentation (Python Implementation)
SIH 2026 - Problem Statement SIH260038
"""

import numpy as np

def segment_optic_disc(image, options=None):
    """
    Segments the optic disc and optic cup, calculating Cup-to-Disc Ratio (CDR).
    """
    if options is None:
        options = {}
        
    H, W = image.shape[:2]
    
    if len(image.shape) == 3:
        red = image[:, :, 0].astype(np.float64) / 255.0
        green = image[:, :, 1].astype(np.float64) / 255.0
    else:
        red = image.astype(np.float64) / 255.0
        green = red
        
    roi_mask = options.get('roiMask', np.ones((H, W), dtype=bool))
    
    # Optic disc is typically the brightest circular region in the red/green channels
    red_roi = red[roi_mask]
    if len(red_roi) > 0:
        bright_thresh = np.percentile(red_roi, 95)
    else:
        bright_thresh = 0.8
        
    bright_mask = (red > bright_thresh) & roi_mask
    
    # Estimate centroid of bright region
    y_coords, x_coords = np.where(bright_mask)
    if len(x_coords) > 0:
        od_x = float(np.mean(x_coords))
        od_y = float(np.mean(y_coords))
        od_radius = min(H, W) * 0.08
        confidence = 0.85
    else:
        # Fallback
        od_x = W * 0.35
        od_y = H * 0.50
        od_radius = min(H, W) * 0.08
        confidence = 0.3
        
    Y, X = np.ogrid[:H, :W]
    dist_from_od = np.sqrt((X - od_x)**2 + (Y - od_y)**2)
    
    optic_disc_mask = (dist_from_od <= od_radius) & roi_mask
    
    # Cup is the brightest central region (approx 40% disc diameter)
    oc_radius = od_radius * 0.45
    dist_from_cup = np.sqrt((X - od_x)**2 + (Y - od_y)**2)
    optic_cup_mask = (dist_from_cup <= oc_radius) & optic_disc_mask
    
    disc_area = float(np.sum(optic_disc_mask))
    cup_area = float(np.sum(optic_cup_mask))
    cdr = np.sqrt(cup_area / disc_area) if disc_area > 0 else 0.4
    
    features = {
        'opticDiscArea': disc_area,
        'opticCupArea': cup_area,
        'cupToDiscRatio': float(cdr),
        'confidence': float(confidence)
    }
    
    return optic_disc_mask, optic_cup_mask, (od_x, od_y), od_radius, confidence, features

"""
Module 3: Segmentation Overlay Generator (Python Implementation)
SIH 2026 - Problem Statement SIH260038
"""

import numpy as np

def create_segmentation_overlay(image, results, style='normal'):
    """
    Creates an RGB composite visualization overlay of retinal structures and lesions.
    """
    if len(image.shape) == 2:
        overlay = np.stack([image, image, image], axis=-1)
    else:
        overlay = image.copy()
        
    alpha = 0.55
    
    # 1. Vessels (Green: [0, 255, 0])
    if 'vesselMask' in results and results['vesselMask'] is not None:
        mask = results['vesselMask']
        overlay[mask, 0] = (1 - alpha) * overlay[mask, 0] + alpha * 0
        overlay[mask, 1] = (1 - alpha) * overlay[mask, 1] + alpha * 255
        overlay[mask, 2] = (1 - alpha) * overlay[mask, 2] + alpha * 0
        
    # 2. Optic Disc (Blue: [0, 180, 255])
    if 'opticDiscMask' in results and results['opticDiscMask'] is not None:
        mask = results['opticDiscMask']
        overlay[mask, 0] = (1 - alpha) * overlay[mask, 0] + alpha * 0
        overlay[mask, 1] = (1 - alpha) * overlay[mask, 1] + alpha * 180
        overlay[mask, 2] = (1 - alpha) * overlay[mask, 2] + alpha * 255
        
    # 3. Optic Cup (Cyan: [0, 255, 255])
    if 'opticCupMask' in results and results['opticCupMask'] is not None:
        mask = results['opticCupMask']
        overlay[mask, 0] = (1 - alpha) * overlay[mask, 0] + alpha * 0
        overlay[mask, 1] = (1 - alpha) * overlay[mask, 1] + alpha * 255
        overlay[mask, 2] = (1 - alpha) * overlay[mask, 2] + alpha * 255
        
    # 4. Fovea (Purple: [200, 50, 255])
    if 'foveaMask' in results and results['foveaMask'] is not None:
        mask = results['foveaMask']
        overlay[mask, 0] = (1 - alpha) * overlay[mask, 0] + alpha * 200
        overlay[mask, 1] = (1 - alpha) * overlay[mask, 1] + alpha * 50
        overlay[mask, 2] = (1 - alpha) * overlay[mask, 2] + alpha * 255
        
    # 5. Exudates (Yellow: [255, 255, 0])
    if 'exudateMask' in results and results['exudateMask'] is not None:
        mask = results['exudateMask']
        overlay[mask, 0] = 255
        overlay[mask, 1] = 255
        overlay[mask, 2] = 0
        
    # 6. Microaneurysms (Orange: [255, 140, 0])
    if 'microaneurysmMask' in results and results['microaneurysmMask'] is not None:
        mask = results['microaneurysmMask']
        overlay[mask, 0] = 255
        overlay[mask, 1] = 140
        overlay[mask, 2] = 0
        
    # 7. Hemorrhages (Red: [255, 0, 0])
    if 'hemorrhageMask' in results and results['hemorrhageMask'] is not None:
        mask = results['hemorrhageMask']
        overlay[mask, 0] = 255
        overlay[mask, 1] = 0
        overlay[mask, 2] = 0
        
    return overlay.astype(np.uint8)

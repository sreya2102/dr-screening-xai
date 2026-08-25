def default_iqa_config():
    """
    Returns default parameters and thresholds for IQA.
    
    RATIONALE & THRESHOLD SELECTION:
    1. Sharpness (Laplacian Variance / Tenengrad):
       - Retinal fundus images require clear vessel boundaries and optic disc edges.
       - Laplacian variance < 15.0 indicates severe defocus blur (REJECT).
       - Laplacian variance between 15.0 and 45.0 indicates mild blur (BORDERLINE).
       - Laplacian variance >= 45.0 indicates crisp focus (GOOD).
    
    2. Contrast (RMS Contrast inside FOV ROI):
       - RMS contrast measures grayscale standard deviation inside the fundus area.
       - RMS contrast < 12.0 means lesions/vessels cannot be distinguished (REJECT).
       - RMS contrast between 12.0 and 25.0 represents low contrast (BORDERLINE).
       - RMS contrast >= 25.0 provides adequate dynamic range (GOOD).
    
    3. Brightness / Exposure (Mean intensity inside FOV ROI):
       - Fundus images should not be underexposed (too dark) or overexposed (glare).
       - Mean ROI brightness < 30.0 indicates severe underexposure (REJECT).
       - Mean ROI brightness > 220.0 indicates severe overexposure/glare (REJECT).
       - Mean ROI brightness between [30, 50] or [190, 220] is sub-optimal (BORDERLINE).
       - Mean ROI brightness between [50, 190] is optimal exposure (GOOD).
    
    4. FOV Coverage Ratio (Retinal area / total image area):
       - FOV coverage ratio < 0.15 indicates an empty/corrupt image or missed eye (REJECT).
       - FOV coverage ratio between 0.15 and 0.30 indicates clipping/partial view (BORDERLINE).
       - FOV coverage ratio >= 0.30 represents standard circular fundus framing (GOOD).
    
    5. Illumination Uniformity (Quadrant intensity standard deviation):
       - Measures variance of mean intensities across 4 fundus quadrants.
       - Uniformity std > 40.0 indicates severe vignetting or directional shadow (BORDERLINE/REJECT).
    """
    config = {
        # Sharpness Thresholds (Laplacian Variance)
        'sharpness_reject_thresh': 15.0,
        'sharpness_good_thresh': 45.0,
        
        # Contrast Thresholds (RMS Contrast inside FOV)
        'contrast_reject_thresh': 12.0,
        'contrast_good_thresh': 25.0,
        
        # Brightness / Exposure Bounds (Mean ROI Intensity 0-255)
        'brightness_min_reject': 30.0,
        'brightness_min_good': 50.0,
        'brightness_max_good': 190.0,
        'brightness_max_reject': 220.0,
        
        # Field of View (FOV) Coverage Ratio
        'fov_ratio_reject_thresh': 0.15,
        'fov_ratio_good_thresh': 0.30,
        
        # Illumination Uniformity (Quadrant Intensity Variance)
        'uniformity_max_borderline': 35.0,
        'uniformity_max_reject': 50.0,
        
        # Scoring Weights for Composite Score (Sum to 1.0)
        'weight_sharpness': 0.35,
        'weight_contrast': 0.30,
        'weight_brightness': 0.20,
        'weight_fov': 0.15
    }
    return config

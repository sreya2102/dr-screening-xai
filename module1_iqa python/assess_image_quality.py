import os
import cv2
import numpy as np

from default_iqa_config import default_iqa_config
from extract_fov_mask import extract_fov_mask
from compute_iqa_metrics import compute_iqa_metrics

def assess_image_quality(input_image, config=None):
    """
    Evaluates retinal fundus image quality.
    
    Inputs:
      input_image - Image array (M x N x 3 or M x N) OR file path string
      config      - (Optional) Custom threshold configuration dict.
                    If omitted, default_iqa_config() is used.
                    
    Outputs:
      quality_result - Dictionary containing quality classification and details:
                       'status'           : 'Good', 'Borderline', or 'Reject'
                       'quality_score'    : Composite quality score (0.0 to 1.0)
                       'is_acceptable'    : Boolean (True for Good/Borderline, False for Reject)
                       'metrics'          : Detailed dict of computed metrics
                       'rejection_reason' : List of warning/rejection descriptions
      fov_mask       - Boolean numpy array of retinal FOV ROI.
    """
    if config is None:
        config = default_iqa_config()
        
    quality_result = {}
    reasons = []
    
    if isinstance(input_image, str):
        if not os.path.exists(input_image):
            quality_result['status']           = 'Reject'
            quality_result['quality_score']    = 0.0
            quality_result['is_acceptable']    = False
            quality_result['metrics']          = {'sharpness': 0, 'contrast': 0, 'brightness': 0, 'fov_coverage': 0, 'uniformity': 999}
            quality_result['rejection_reason'] = ['File not found']
            fov_mask                           = np.zeros((100, 100), dtype=bool)
            return quality_result, fov_mask
            
        # OpenCV loads images in BGR format
        img = cv2.imread(input_image)
        if img is None:
            quality_result['status']           = 'Reject'
            quality_result['quality_score']    = 0.0
            quality_result['is_acceptable']    = False
            quality_result['metrics']          = {'sharpness': 0, 'contrast': 0, 'brightness': 0, 'fov_coverage': 0, 'uniformity': 999}
            quality_result['rejection_reason'] = ['Unable to read image']
            fov_mask                           = np.zeros((100, 100), dtype=bool)
            return quality_result, fov_mask
    else:
        img = input_image
        
    # Step 1: Extract Retinal Field of View (FOV) Mask
    fov_mask = extract_fov_mask(img)
    
    # Step 2: Compute Quantitative Quality Metrics
    metrics = compute_iqa_metrics(img, fov_mask)
    quality_result['metrics'] = metrics
    
    # Step 3: Rule-based Decision Tree & Defect Identification
    has_reject_trigger = False
    has_borderline_trigger = False
    
    # Check FOV Coverage
    if metrics['fov_coverage'] < config['fov_ratio_reject_thresh']:
        has_reject_trigger = True
        reasons.append(f"Invalid/Missing Retinal FOV (Coverage: {metrics['fov_coverage']:.2f} < {config['fov_ratio_reject_thresh']:.2f})")
    elif metrics['fov_coverage'] < config['fov_ratio_good_thresh']:
        has_borderline_trigger = True
        reasons.append(f"Partial FOV Framing (Coverage: {metrics['fov_coverage']:.2f})")
        
    # Check Sharpness (Defocus Blur)
    if metrics['sharpness'] < config['sharpness_reject_thresh']:
        has_reject_trigger = True
        reasons.append(f"Severe Defocus Blur (Sharpness: {metrics['sharpness']:.1f} < {config['sharpness_reject_thresh']:.1f})")
    elif metrics['sharpness'] < config['sharpness_good_thresh']:
        has_borderline_trigger = True
        reasons.append(f"Mild Image Blur (Sharpness: {metrics['sharpness']:.1f})")
        
    # Check Contrast
    if metrics['contrast'] < config['contrast_reject_thresh']:
        has_reject_trigger = True
        reasons.append(f"Severe Low Contrast (Contrast: {metrics['contrast']:.1f} < {config['contrast_reject_thresh']:.1f})")
    elif metrics['contrast'] < config['contrast_good_thresh']:
        has_borderline_trigger = True
        reasons.append(f"Sub-optimal Contrast (Contrast: {metrics['contrast']:.1f})")
        
    # Check Brightness / Exposure Bounds
    if metrics['brightness'] < config['brightness_min_reject']:
        has_reject_trigger = True
        reasons.append(f"Severe Underexposure (Brightness: {metrics['brightness']:.1f} < {config['brightness_min_reject']:.1f})")
    elif metrics['brightness'] > config['brightness_max_reject']:
        has_reject_trigger = True
        reasons.append(f"Severe Overexposure/Glare (Brightness: {metrics['brightness']:.1f} > {config['brightness_max_reject']:.1f})")
    elif metrics['brightness'] < config['brightness_min_good']:
        has_borderline_trigger = True
        reasons.append(f"Mild Underexposure (Brightness: {metrics['brightness']:.1f})")
    elif metrics['brightness'] > config['brightness_max_good']:
        has_borderline_trigger = True
        reasons.append(f"Mild Overexposure (Brightness: {metrics['brightness']:.1f})")
        
    # Check Illumination Uniformity
    if metrics['uniformity'] > config['uniformity_max_reject']:
        has_reject_trigger = True
        reasons.append(f"Severe Illumination Gradient (Uniformity std: {metrics['uniformity']:.1f} > {config['uniformity_max_reject']:.1f})")
    elif metrics['uniformity'] > config['uniformity_max_borderline']:
        has_borderline_trigger = True
        reasons.append(f"Uneven Illumination (Uniformity std: {metrics['uniformity']:.1f})")
        
    # Step 4: Compute Normalized Composite Quality Score (0.0 to 1.0)
    score_sharpness  = min(1.0, metrics['sharpness'] / config['sharpness_good_thresh'])
    score_contrast   = min(1.0, metrics['contrast'] / config['contrast_good_thresh'])
    score_fov        = min(1.0, metrics['fov_coverage'] / config['fov_ratio_good_thresh'])
    
    # Brightness score peaked around ideal intensity (120)
    ideal_brightness = 120.0
    max_bright_dev   = 100.0
    bright_dev       = abs(metrics['brightness'] - ideal_brightness)
    score_brightness = max(0.0, 1.0 - (bright_dev / max_bright_dev))
    
    composite_score = (config['weight_sharpness']  * score_sharpness)  + \
                      (config['weight_contrast']   * score_contrast)   + \
                      (config['weight_brightness'] * score_brightness) + \
                      (config['weight_fov']        * score_fov)
                      
    quality_result['quality_score'] = min(1.0, max(0.0, composite_score))
    
    # Step 5: Final Classification Assignment
    if has_reject_trigger:
        quality_result['status']        = 'Reject'
        quality_result['is_acceptable'] = False
    elif has_borderline_trigger:
        quality_result['status']        = 'Borderline'
        quality_result['is_acceptable'] = True
    else:
        quality_result['status']        = 'Good'
        quality_result['is_acceptable'] = True
        
    if len(reasons) == 0:
        quality_result['rejection_reason'] = ['Image quality meets all optimal standards']
    else:
        quality_result['rejection_reason'] = reasons
        
    return quality_result, fov_mask

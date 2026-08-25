import time
import os
import cv2
import numpy as np

from create_roi_mask import create_roi_mask
from correct_illumination import correct_illumination
from apply_clahe import apply_clahe
from enhance_structures import enhance_structures

def enhance_image(input_image, **kwargs):
    """
    Primary entry point for Module 2: Image Enhancement.
    
    Inputs:
        input_image - Image array (M x N x 3 or M x N) OR file path string
        **kwargs    - Optional enhancement parameters overrides.
        
    Outputs:
        enhanced_image - uint8 (H x W x 3) enhanced RGB image
        green_channel  - uint8 (H x W) enhanced grayscale image
        metadata       - dict containing execution diagnostics and parameters
    """
    t_start = time.time()
    
    opts = {
        'RoiMinCoveragePct': kwargs.get('RoiMinCoveragePct', 10.0),
        'RoiMaxCoveragePct': kwargs.get('RoiMaxCoveragePct', 95.0),
        'IllumSigma': kwargs.get('IllumSigma', 30.0),
        'ClaheClipLimit': kwargs.get('ClaheClipLimit', 2.0),
        'ClaheTileGrid': kwargs.get('ClaheTileGrid', (8, 8)),
        'DenoiseKernelSize': kwargs.get('DenoiseKernelSize', (3, 3)),
        'SharpenAmount': kwargs.get('SharpenAmount', 0.5),
        'SharpenRadius': kwargs.get('SharpenRadius', 1.0),
        'SharpenThreshold': kwargs.get('SharpenThreshold', 0.05)
    }
    
    metadata = {
        'status': 'SUCCESS',
        'input_dimensions': (0, 0, 0),
        'output_dimensions': (0, 0, 0),
        'roi_coverage_pct': 0.0,
        'roi_fallback_used': False,
        'techniques_applied': [],
        'parameters': opts.copy(),
        'execution_time_ms': 0.0,
        'warnings': [],
        'channel_info': {'color_space': 'RGB', 'primary_channel': 'Green'}
    }
    
    try:
        # STAGE 1: Input Validation & Image Reading
        if isinstance(input_image, str):
            if not os.path.exists(input_image):
                raise FileNotFoundError(f"Input image file not found: {input_image}")
            # OpenCV loads as BGR, convert to RGB for standard processing
            img_bgr = cv2.imread(input_image)
            if img_bgr is None:
                raise ValueError("Unable to read image.")
            img_data = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
        else:
            img_data = input_image
            
        # Standardize input to uint8
        if img_data.dtype != np.uint8:
            if np.max(img_data) <= 1.0:
                img_data = np.round(img_data * 255.0).astype(np.uint8)
            else:
                img_data = np.round(img_data).astype(np.uint8)
                
        if len(img_data.shape) == 3:
            H, W, C = img_data.shape
        else:
            H, W = img_data.shape
            C = 1
            
        metadata['input_dimensions'] = (H, W, C)
        
        if C == 1:
            img_rgb = np.stack([img_data, img_data, img_data], axis=-1)
            metadata['warnings'].append('Input is grayscale 1-channel image; expanded to 3-channel RGB.')
        elif C == 3:
            img_rgb = img_data
        else:
            raise ValueError(f"Unsupported number of image channels: {C}")
            
        # STAGE 2: Retinal Field ROI Masking & Fallback Check
        # MATLAB index 2 is Green. In Python (RGB), index 1 is Green.
        green_raw = img_rgb[:, :, 1]
        roi_mask, is_fallback, roi_warn = create_roi_mask(green_raw, 
                                                          min_coverage_pct=opts['RoiMinCoveragePct'], 
                                                          max_coverage_pct=opts['RoiMaxCoveragePct'])
                                                          
        metadata['roi_coverage_pct'] = 100.0 * (np.sum(roi_mask) / (H * W))
        metadata['roi_fallback_used'] = is_fallback
        
        if is_fallback:
            metadata['status'] = 'WARNING'
            metadata['warnings'].append(roi_warn)
        metadata['techniques_applied'].append('ROI_Masking')
        
        # STAGE 3: Illumination Correction (Shading Equalization)
        img_illum = correct_illumination(img_rgb, roi_mask, sigma=opts['IllumSigma'])
        metadata['techniques_applied'].append('Illumination_Correction')
        
        # STAGE 4: Green Channel Isolation & Contrast Enhancement (CLAHE)
        green_illum = img_illum[:, :, 1]
        green_clahe = apply_clahe(green_illum, roi_mask, 
                                  clip_limit=opts['ClaheClipLimit'], 
                                  tile_grid_size=opts['ClaheTileGrid'])
        metadata['techniques_applied'].append('CLAHE')
        
        # STAGE 5: Structure Enhancement (Step A: Denoise -> Step B: Sharpen)
        green_enhanced = enhance_structures(green_clahe, roi_mask, 
                                            denoise_kernel_size=opts['DenoiseKernelSize'], 
                                            sharpen_amount=opts['SharpenAmount'], 
                                            sharpen_radius=opts['SharpenRadius'], 
                                            sharpen_threshold=opts['SharpenThreshold'])
        metadata['techniques_applied'].append('StepA_MedianDenoise')
        metadata['techniques_applied'].append('StepB_UnsharpSharpen')
        
        green_channel = green_enhanced
        
        # STAGE 6: RGB Output Reconstruction
        # Reconstruct RGB by modulating original color channel ratios with enhanced luminance
        green_base = img_illum[:, :, 1].astype(float) + 1.0
        enhancement_ratio = green_enhanced.astype(float) / green_base
        
        enhanced_rgb = np.zeros((H, W, 3), dtype=np.uint8)
        for c in range(3):
            channel_c = img_illum[:, :, c].astype(float)
            channel_enhanced = channel_c * enhancement_ratio
            channel_enhanced[~roi_mask] = 0
            enhanced_rgb[:, :, c] = np.round(np.clip(channel_enhanced, 0.0, 255.0)).astype(np.uint8)
            
        enhanced_image = enhanced_rgb
        metadata['output_dimensions'] = enhanced_image.shape
        
    except Exception as e:
        metadata['status'] = 'FAILED'
        metadata['warnings'].append(f"ERROR: {str(e)}")
        
        # Fallback outputs to prevent crash
        if 'img_data' in locals() and img_data is not None:
            enhanced_image = img_data
            if len(img_data.shape) == 3:
                green_channel = img_data[:, :, 1]
            else:
                green_channel = img_data
        else:
            enhanced_image = np.zeros((512, 512, 3), dtype=np.uint8)
            green_channel = np.zeros((512, 512), dtype=np.uint8)
            
    metadata['execution_time_ms'] = (time.time() - t_start) * 1000.0
    
    return enhanced_image, green_channel, metadata

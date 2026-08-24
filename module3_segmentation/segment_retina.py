"""
Module 3: Retinal & Lesion Segmentation Main Pipeline Coordinator (Python Implementation)
SIH 2026 - Problem Statement SIH260038
"""

import numpy as np
from segment_vessels import segment_vessels
from segment_optic_disc import segment_optic_disc
from segment_fovea import segment_fovea
from segment_lesions import segment_lesions
from analyze_vessels import analyze_vessels
from create_segmentation_overlay import create_segmentation_overlay

def segment_retina(image, options=None):
    """
    Main entry point for Module 3 retinal structure & lesion segmentation.
    
    Parameters:
        image (np.ndarray): Input retinal fundus image (RGB, uint8).
        options (dict): Configuration options dictionary.
        
    Returns:
        results (dict): Structured segmentation masks, features, and XAI explanations.
        overlay (np.ndarray): Color-coded segmentation overlay image.
    """
    if options is None:
        options = {}
        
    H, W = image.shape[:2]
    
    # 1. FOV Mask Estimation
    if len(image.shape) == 3:
        gray = np.mean(image, axis=2)
    else:
        gray = image
        
    roi_mask = gray > 15
    options['roiMask'] = roi_mask
    
    # 2. Vessel Segmentation & Morphology
    vessel_mask, vessel_skel, ves_features = segment_vessels(image, options)
    branch_pts, end_pts, ves_analysis = analyze_vessels(vessel_skel, vessel_mask, roi_mask)
    
    # 3. Optic Disc & Cup
    od_mask, oc_mask, od_center, od_radius, od_conf, od_features = segment_optic_disc(image, options)
    
    # 4. Fovea Localization
    fovea_mask, fovea_x, fovea_y, fovea_conf = segment_fovea(image, od_center, od_radius, roi_mask)
    
    # 5. Lesions Detection
    ex_mask, ma_mask, he_mask, comb_mask, les_features = segment_lesions(image, od_mask, vessel_mask, roi_mask)
    
    # Consolidate Features
    features = {
        'vesselDensity': ves_features['vesselDensity'],
        'vesselPixelCount': ves_features['vesselPixelCount'],
        'skeletonLength': ves_features['skeletonLength'],
        'branchPointCount': ves_analysis['branchPointCount'],
        'endpointCount': ves_analysis['endpointCount'],
        'branchingDensity': ves_analysis['branchingDensity'],
        'meanTortuosity': ves_analysis['meanTortuosity'],
        'tortuosityStd': ves_analysis['tortuosityStd'],
        'meanVesselWidth': ves_analysis['meanVesselWidth'],
        'vesselWidthStd': ves_analysis['vesselWidthStd'],
        'vesselWidthCV': ves_analysis['vesselWidthCV'],
        'opticDiscArea': od_features['opticDiscArea'],
        'opticCupArea': od_features['opticCupArea'],
        'cupToDiscRatio': od_features['cupToDiscRatio'],
        'foveaCenterX': fovea_x,
        'foveaCenterY': fovea_y,
        'exudateCount': les_features['exudateCount'],
        'exudateArea': les_features['exudateArea'],
        'microaneurysmCount': les_features['microaneurysmCount'],
        'microaneurysmArea': les_features['microaneurysmArea'],
        'hemorrhageCount': les_features['hemorrhageCount'],
        'hemorrhageArea': les_features['hemorrhageArea'],
        'totalLesionArea': les_features['totalLesionArea'],
        'tortuosityScore': ves_analysis['tortuosityScore'],
        'branchingScore': ves_analysis['branchingScore'],
        'widthIrregularityScore': ves_analysis['widthIrregularityScore'],
        'vesselAbnormalityScore': ves_analysis['vesselAbnormalityScore']
    }
    
    # Explanations
    explanations = {
        'vessel': f"Vascular network segmented with density {features['vesselDensity']*100:.1f}%.",
        'opticDisc': f"Optic disc segmented with CDR {features['cupToDiscRatio']:.2f}.",
        'fovea': f"Fovea localized at ({fovea_x:.0f}, {fovea_y:.0f}).",
        'lesions': f"Detected {features['exudateCount']} exudates, {features['microaneurysmCount']} microaneurysms, {features['hemorrhageCount']} hemorrhages.",
        'vesselScore': f"Vessel Abnormality Score: {features['vesselAbnormalityScore']:.1f}/100 ({ves_analysis['interpretation']})"
    }
    
    results = {
        'vesselMask': vessel_mask,
        'vesselSkeleton': vessel_skel,
        'opticDiscMask': od_mask,
        'opticCupMask': oc_mask,
        'foveaMask': fovea_mask,
        'exudateMask': ex_mask,
        'microaneurysmMask': ma_mask,
        'hemorrhageMask': he_mask,
        'lesionMask': comb_mask,
        'vesselAnalysis': ves_analysis,
        'features': features,
        'explanations': explanations
    }
    
    overlay = create_segmentation_overlay(image, results, 'normal')
    
    return results, overlay

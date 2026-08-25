def compute_lesion_importance(segmentation_results, dr_grade=0):
    """
    Computes feature importance breakdown for lesions.
    """
    ma_count = 0
    hem_count = 0
    ex_count = 0
    
    if isinstance(segmentation_results, dict):
        if 'lesion_counts' in segmentation_results:
            lc = segmentation_results['lesion_counts']
            ma_count = lc.get('microaneurysms', 0)
            hem_count = lc.get('hemorrhages', 0)
            ex_count = lc.get('exudates', 0)
            
    # Weight factors reflecting clinical severity impact
    ma_weight = 1.0
    hem_weight = 3.0
    ex_weight = 2.5
    
    total_weighted = ma_count * ma_weight + hem_count * hem_weight + ex_count * ex_weight
    
    if total_weighted > 0:
        ma_impact = (ma_count * ma_weight) / total_weighted * 100
        hem_impact = (hem_count * hem_weight) / total_weighted * 100
        ex_impact = (ex_count * ex_weight) / total_weighted * 100
    else:
        ma_impact = 0.0
        hem_impact = 0.0
        ex_impact = 0.0
        
    importance_struct = {
        'microaneurysms_count': ma_count,
        'microaneurysms_impact_pct': round(ma_impact, 1),
        'hemorrhages_count': hem_count,
        'hemorrhages_impact_pct': round(hem_impact, 1),
        'exudates_count': ex_count,
        'exudates_impact_pct': round(ex_impact, 1),
        'total_lesions': ma_count + hem_count + ex_count
    }
    
    return importance_struct

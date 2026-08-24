"""
Lesion Importance Weighting Calculator (Python).
"""

def compute_lesion_importance(segmentation_results, dr_grade=0):
    ma_count = 0
    hem_count = 0
    ex_count = 0

    if isinstance(segmentation_results, dict):
        lc = segmentation_results.get('lesion_counts', {})
        ma_count = lc.get('microaneurysms', 0)
        hem_count = lc.get('hemorrhages', 0)
        ex_count = lc.get('exudates', 0)

    ma_weight, hem_weight, ex_weight = 1.0, 3.0, 2.5
    total_weighted = ma_count * ma_weight + hem_count * hem_weight + ex_count * ex_weight

    if total_weighted > 0:
        ma_impact = (ma_count * ma_weight) / total_weighted * 100
        hem_impact = (hem_count * hem_weight) / total_weighted * 100
        ex_impact = (ex_count * ex_weight) / total_weighted * 100
    else:
        ma_impact, hem_impact, ex_impact = 0.0, 0.0, 0.0

    return {
        'microaneurysms_count': ma_count,
        'microaneurysms_impact_pct': round(ma_impact, 1),
        'hemorrhages_count': hem_count,
        'hemorrhages_impact_pct': round(hem_impact, 1),
        'exudates_count': ex_count,
        'exudates_impact_pct': round(ex_impact, 1),
        'total_lesions': ma_count + hem_count + ex_count
    }

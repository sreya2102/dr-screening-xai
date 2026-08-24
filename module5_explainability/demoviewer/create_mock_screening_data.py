"""
Synthetic Screening Data Generator for Module 5 (Python).
Generates mock retinal images, lesion masks, IQA status, and DR grading predictions.
"""

import numpy as np
from datetime import datetime

def create_mock_screening_data(dr_grade=2, iqa_status='Good'):
    img_shape = (512, 512)
    
    # 1. Retinal Background
    y, x = np.ogrid[:img_shape[0], :img_shape[1]]
    center = (256, 256)
    dist_from_center = np.sqrt((x - center[1])**2 + (y - center[0])**2)
    retina_mask = dist_from_center <= 230
    
    raw_img = np.zeros((*img_shape, 3), dtype=np.uint8)
    raw_img[retina_mask, 0] = np.random.randint(180, 220, size=np.sum(retina_mask))
    raw_img[retina_mask, 1] = np.random.randint(60, 90, size=np.sum(retina_mask))
    raw_img[retina_mask, 2] = np.random.randint(15, 30, size=np.sum(retina_mask))
    
    # Optic Disc (bright yellow circle)
    od_center = (256, 380)
    od_dist = np.sqrt((x - od_center[1])**2 + (y - od_center[0])**2)
    od_mask = od_dist <= 35
    raw_img[od_mask] = [255, 240, 150]
    
    # Vessels (dark curves)
    vessels_mask = np.zeros(img_shape, dtype=bool)
    vessels_mask[240:270, 100:380] = True
    vessels_mask[150:380, 370:390] = True
    vessels_mask = vessels_mask & retina_mask & ~od_mask
    raw_img[vessels_mask] = (raw_img[vessels_mask] * 0.3).astype(np.uint8)
    
    # 2. Lesion Masks based on DR Grade
    ma_mask = np.zeros(img_shape, dtype=bool)
    hem_mask = np.zeros(img_shape, dtype=bool)
    ex_mask = np.zeros(img_shape, dtype=bool)
    
    if dr_grade >= 1:
        ma_coords = [(200, 220), (210, 250), (280, 200), (300, 240)]
        for r, c in ma_coords:
            ma_mask[max(0, r-3):min(img_shape[0], r+3), max(0, c-3):min(img_shape[1], c+3)] = True
            
    if dr_grade >= 2:
        hem_coords = [(250, 180), (320, 220), (190, 180)]
        for r, c in hem_coords:
            h_dist = np.sqrt((x - c)**2 + (y - r)**2)
            hem_mask = hem_mask | (h_dist <= 8)
            
        ex_coords = [(220, 280), (240, 300), (260, 290)]
        for r, c in ex_coords:
            e_dist = np.sqrt((x - c)**2 + (y - r)**2)
            ex_mask = ex_mask | (e_dist <= 7)
            
    if dr_grade >= 3:
        hem_coords_extra = [(150, 250), (350, 180), (310, 300)]
        for r, c in hem_coords_extra:
            h_dist = np.sqrt((x - c)**2 + (y - r)**2)
            hem_mask = hem_mask | (h_dist <= 11)
            
    if dr_grade >= 4:
        ex_coords_extra = [(180, 200), (300, 350)]
        for r, c in ex_coords_extra:
            e_dist = np.sqrt((x - c)**2 + (y - r)**2)
            ex_mask = ex_mask | (e_dist <= 13)

    enhanced_img = raw_img.copy()
    enhanced_img[:, :, 1] = np.clip(raw_img[:, :, 1].astype(np.float32) * 1.3, 0, 255).astype(np.uint8)

    grade_labels = ['No DR (Normal)', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR']
    probs = np.zeros(5, dtype=np.float32)
    probs[dr_grade] = 0.85
    rem = 0.15 / 4
    for i in range(5):
        if i != dr_grade:
            probs[i] = rem

    q_score = 0.92 if iqa_status == 'Good' else (0.65 if iqa_status == 'Borderline' else 0.35)

    return {
        'patient_id': 'PAT-2026-9042',
        'patient_name': 'John Smith',
        'age': 62,
        'eye_side': 'OD',
        'date': datetime.now().strftime('%Y-%m-%d'),
        'raw_image': raw_img,
        'enhanced_image': enhanced_img,
        'iqa_result': {'status': iqa_status, 'quality_score': q_score},
        'segmentation_results': {
            'vessels_mask': vessels_mask,
            'optic_disc_mask': od_mask,
            'microaneurysms_mask': ma_mask,
            'hemorrhages_mask': hem_mask,
            'exudates_mask': ex_mask,
            'lesion_counts': {
                'microaneurysms': int(np.sum(ma_mask)),
                'hemorrhages': int(np.sum(hem_mask)),
                'exudates': int(np.sum(ex_mask))
            }
        },
        'dr_grading_result': {
            'predicted_grade': dr_grade,
            'grade_label': grade_labels[dr_grade],
            'confidence': float(probs[dr_grade]),
            'class_probabilities': probs.tolist()
        }
    }

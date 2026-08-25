import numpy as np
import cv2
from assess_image_quality import assess_image_quality
from default_iqa_config import default_iqa_config

def test_module1_iqa():
    print("====================================================")
    print("   Running Module 1 (IQA) Python Unit Tests")
    print("====================================================\n")
    
    pass_count = 0
    total_tests = 4
    
    # Synthetic fundus image size
    rows = 256
    cols = 256
    
    x = np.arange(cols)
    y = np.arange(rows)
    X, Y = np.meshgrid(x, y)
    
    center_x = cols / 2.0
    center_y = rows / 2.0
    radius = 100.0
    
    dist_from_center = np.sqrt((X - center_x)**2 + (Y - center_y)**2)
    base_fov_mask = dist_from_center <= radius
    
    # TEST 1: Synthetic GOOD Image
    print("[Test 1] Evaluating Synthetic GOOD Fundus Image...")
    
    good_img = np.zeros((rows, cols, 3), dtype=np.uint8)
    
    r_chan = np.zeros((rows, cols), dtype=float)
    g_chan = np.zeros((rows, cols), dtype=float)
    b_chan = np.zeros((rows, cols), dtype=float)
    
    radial_pattern = 120 + 35 * np.cos(dist_from_center / radius * np.pi)
    radial_pattern = np.clip(radial_pattern, 50, 180)
    
    r_chan[base_fov_mask] = radial_pattern[base_fov_mask]
    g_chan[base_fov_mask] = radial_pattern[base_fov_mask]
    
    # Add clear synthetic vessel structures
    for k in range(-80, 81, 10):
        vertical_vessel = np.abs(X - center_x - k) <= 1
        horizontal_vessel = np.abs(Y - center_y - k) <= 1
        
        vessel_mask = base_fov_mask & (vertical_vessel | horizontal_vessel)
        
        g_chan[vessel_mask] = 25
        r_chan[vessel_mask] = 60
        
    b_chan[base_fov_mask] = 40
    
    # Format as BGR for OpenCV
    good_img[:, :, 0] = b_chan.astype(np.uint8)
    good_img[:, :, 1] = g_chan.astype(np.uint8)
    good_img[:, :, 2] = r_chan.astype(np.uint8)
    
    res1, _ = assess_image_quality(good_img)
    
    print(f"  -> Status: {res1['status']} | Score: {res1['quality_score']:.2f} | Acceptable: {res1['is_acceptable']}")
    print(f"  -> Metrics - Sharpness: {res1['metrics']['sharpness']:.1f}, Contrast: {res1['metrics']['contrast']:.1f}, Brightness: {res1['metrics']['brightness']:.1f}, FOV: {res1['metrics']['fov_coverage']:.2f}")
    
    if res1['status'] == 'Good' and res1['is_acceptable']:
        print("  [PASS] Test 1 Passed.\n")
        pass_count += 1
    else:
        print("  [FAIL] Test 1 Failed.\n")
        
    # TEST 2: Synthetic BORDERLINE Image
    print("[Test 2] Evaluating Synthetic BORDERLINE Fundus Image...")
    
    # Blur the green channel to reduce sharpness
    blurred_g_chan = cv2.GaussianBlur(g_chan, (5, 5), 2.0)
    
    borderline_img = good_img.copy()
    borderline_img[:, :, 1] = blurred_g_chan.astype(np.uint8)
    
    res2, _ = assess_image_quality(borderline_img)
    
    print(f"  -> Status: {res2['status']} | Score: {res2['quality_score']:.2f} | Acceptable: {res2['is_acceptable']}")
    print(f"  -> Reason: {res2['rejection_reason'][0]}")
    
    if res2['status'] == 'Borderline' and res2['is_acceptable']:
        print("  [PASS] Test 2 Passed.\n")
        pass_count += 1
    else:
        print("  [FAIL] Test 2 Failed.\n")
        
    # TEST 3: Synthetic REJECT Image
    print("[Test 3] Evaluating Synthetic REJECT Image...")
    
    reject_img = np.zeros((rows, cols, 3), dtype=np.uint8)
    
    res3, _ = assess_image_quality(reject_img)
    
    print(f"  -> Status: {res3['status']} | Score: {res3['quality_score']:.2f} | Acceptable: {res3['is_acceptable']}")
    print(f"  -> Reason: {res3['rejection_reason'][0]}")
    
    if res3['status'] == 'Reject' and not res3['is_acceptable']:
        print("  [PASS] Test 3 Passed.\n")
        pass_count += 1
    else:
        print("  [FAIL] Test 3 Failed.\n")
        
    # TEST 4: Custom Configuration Override
    print("[Test 4] Evaluating Custom Config Override...")
    
    cfg = default_iqa_config()
    cfg['sharpness_good_thresh'] = 10000.0
    
    res4, _ = assess_image_quality(good_img, cfg)
    
    print(f"  -> Status with strict config: {res4['status']}")
    
    if res4['status'] in ['Borderline', 'Reject']:
        print("  [PASS] Test 4 Passed.\n")
        pass_count += 1
    else:
        print("  [FAIL] Test 4 Failed.\n")
        
    # SUMMARY
    print("====================================================")
    print(f" Test Results: {pass_count} / {total_tests} Tests Passed.")
    print("====================================================")

if __name__ == "__main__":
    test_module1_iqa()

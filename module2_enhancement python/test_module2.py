import time
import numpy as np
from enhance_image import enhance_image
from create_roi_mask import create_roi_mask

def create_synthetic_fundus_phantom(H, W):
    """
    Generates a synthetic circular fundus phantom with background shading,
    blood vessels, microaneurysms, and noise for testing.
    """
    y, x = np.ogrid[:H, :W]
    center_x = (W - 1) / 2.0
    center_y = (H - 1) / 2.0
    radius = 0.42 * min(H, W)
    
    dist_from_center = np.sqrt((x - center_x)**2 + (y - center_y)**2)
    mask_circle = dist_from_center <= radius
    
    # Synthetic background shading (vignetting)
    vignette = 1.0 - 0.4 * (dist_from_center / radius)**2
    vignette[~mask_circle] = 0.0
    
    # Fundus orange/red base color
    R_base = 0.85 * vignette
    G_base = 0.45 * vignette
    B_base = 0.15 * vignette
    
    # Add synthetic blood vessels (dark lines)
    vessel1 = (np.abs(y - (center_y + 0.1 * np.power(np.abs(x - center_x), 1.2))) < 3.0) & mask_circle
    vessel2 = (np.abs(x - (center_x + 0.15 * np.power(np.abs(y - center_y), 1.1))) < 2.5) & mask_circle
    vessels = vessel1 | vessel2
    
    G_base[vessels] = G_base[vessels] * 0.4
    R_base[vessels] = R_base[vessels] * 0.5
    
    # Add synthetic noise
    noise = 0.02 * np.random.randn(H, W)
    R_base = np.clip(R_base + noise, 0, 1)
    G_base = np.clip(G_base + noise, 0, 1)
    B_base = np.clip(B_base + noise, 0, 1)
    
    R_base[~mask_circle] = 0
    G_base[~mask_circle] = 0
    B_base[~mask_circle] = 0
    
    img_synth = np.stack([
        np.round(R_base * 255).astype(np.uint8),
        np.round(G_base * 255).astype(np.uint8),
        np.round(B_base * 255).astype(np.uint8)
    ], axis=-1)
    
    return img_synth, mask_circle

def test_module2():
    print("=======================================================")
    print("  Module 2: Image Enhancement - Automated Test Suite  ")
    print("=======================================================\n")
    
    test_results = {
        'passed': 0,
        'failed': 0,
        'details': [],
        'benchmark_mean_ms': 0.0,
        'benchmark_std_ms': 0.0
    }
    
    # Test 1: Synthetic Image Generation & Basic Execution
    print("[Test 1] Synthetic Fundus Phantom Processing... ", end="")
    try:
        img_synth, mask_true = create_synthetic_fundus_phantom(512, 512)
        enhanced_rgb, green_ch, meta = enhance_image(img_synth)
        
        assert meta['status'] == 'SUCCESS', "Expected status SUCCESS"
        assert enhanced_rgb.dtype == np.uint8, "enhanced_image must be uint8"
        assert green_ch.dtype == np.uint8, "green_channel must be uint8"
        assert enhanced_rgb.shape == (512, 512, 3), "enhanced_image size mismatch"
        assert green_ch.shape == (512, 512), "green_channel size mismatch"
        assert not meta['roi_fallback_used'], "Fallback should not trigger on valid phantom"
        
        print("PASSED")
        test_results['passed'] += 1
        test_results['details'].append("Test 1 (Synthetic Processing): PASSED")
    except Exception as e:
        print(f"FAILED: {str(e)}")
        test_results['failed'] += 1
        test_results['details'].append(f"Test 1 (Synthetic Processing): FAILED ({str(e)})")
        
    # Test 2: ROI Degeneracy & Centered Circular Fallback Handling
    print("[Test 2] Degenerate ROI Fallback Handling... ", end="")
    try:
        img_degraded = np.zeros((512, 512, 3), dtype=np.uint8)
        _, _, meta_degraded = enhance_image(img_degraded)
        
        assert meta_degraded['status'] == 'WARNING', "Expected status WARNING on fallback"
        assert meta_degraded['roi_fallback_used'] == True, "roi_fallback_used should be true"
        assert len(meta_degraded['warnings']) > 0, "Warnings list should not be empty"
        
        print("PASSED")
        test_results['passed'] += 1
        test_results['details'].append("Test 2 (ROI Fallback): PASSED")
    except Exception as e:
        print(f"FAILED: {str(e)}")
        test_results['failed'] += 1
        test_results['details'].append(f"Test 2 (ROI Fallback): FAILED ({str(e)})")
        
    # Test 3: Background Isolation Verification
    print("[Test 3] Background Isolation Verification... ", end="")
    try:
        img_synth, _ = create_synthetic_fundus_phantom(256, 256)
        enhanced_rgb, green_ch, meta = enhance_image(img_synth)
        
        roi_mask, _, _ = create_roi_mask(img_synth[:, :, 1])
        bg_rgb_sum = np.sum(enhanced_rgb[~roi_mask])
        bg_green_sum = np.sum(green_ch[~roi_mask])
        
        assert bg_rgb_sum == 0, "Background pixels outside ROI in RGB must be 0"
        assert bg_green_sum == 0, "Background pixels outside ROI in Green channel must be 0"
        
        print("PASSED")
        test_results['passed'] += 1
        test_results['details'].append("Test 3 (Background Isolation): PASSED")
    except Exception as e:
        print(f"FAILED: {str(e)}")
        test_results['failed'] += 1
        test_results['details'].append(f"Test 3 (Background Isolation): FAILED ({str(e)})")
        
    # Test 4: Custom Parameters Override Test
    print("[Test 4] Configurable Parameters Override... ", end="")
    try:
        img_synth, _ = create_synthetic_fundus_phantom(256, 256)
        _, _, meta_custom = enhance_image(img_synth, 
                                          ClaheClipLimit=3.0, 
                                          SharpenAmount=0.8, 
                                          DenoiseKernelSize=(5, 5))
                                          
        assert meta_custom['parameters']['ClaheClipLimit'] == 3.0, "ClaheClipLimit parameter mismatch"
        assert meta_custom['parameters']['SharpenAmount'] == 0.8, "SharpenAmount parameter mismatch"
        assert meta_custom['parameters']['DenoiseKernelSize'] == (5, 5), "DenoiseKernelSize parameter mismatch"
        
        print("PASSED")
        test_results['passed'] += 1
        test_results['details'].append("Test 4 (Custom Parameters): PASSED")
    except Exception as e:
        print(f"FAILED: {str(e)}")
        test_results['failed'] += 1
        test_results['details'].append(f"Test 4 (Custom Parameters): FAILED ({str(e)})")
        
    # Test 5: MATLAB / Simulink Compatibility Simulation (Python equivalent)
    print("[Test 5] Python / Pipeline Compatibility Check... ", end="")
    try:
        img_sim = np.random.randint(0, 256, (512, 512, 3), dtype=np.uint8)
        out_rgb, out_green, meta_sim = enhance_image(img_sim)
        
        assert isinstance(meta_sim, dict), "Metadata dict verification failed"
        assert len(out_rgb.shape) == 3 and len(out_green.shape) == 2, "Array dimension mismatch"
        
        print("PASSED")
        test_results['passed'] += 1
        test_results['details'].append("Test 5 (Pipeline Compatibility): PASSED")
    except Exception as e:
        print(f"FAILED: {str(e)}")
        test_results['failed'] += 1
        test_results['details'].append(f"Test 5 (Pipeline Compatibility): FAILED ({str(e)})")
        
    # Test 6: Reproducible Performance Benchmark
    print("[Test 6] Performance Benchmark (512x512, 10 runs)... ", end="")
    try:
        img_bench, _ = create_synthetic_fundus_phantom(512, 512)
        
        # Warmup run
        _, _, _ = enhance_image(img_bench)
        
        num_runs = 10
        timings = np.zeros(num_runs)
        for r in range(num_runs):
            t_run = time.time()
            _, _, _ = enhance_image(img_bench)
            timings[r] = (time.time() - t_run) * 1000.0 # ms
            
        mean_ms = np.mean(timings)
        std_ms = np.std(timings, ddof=1)
        test_results['benchmark_mean_ms'] = mean_ms
        test_results['benchmark_std_ms'] = std_ms
        
        print(f"PASSED (Mean: {mean_ms:.2f} ms, Std: {std_ms:.2f} ms)")
        test_results['passed'] += 1
        test_results['details'].append(f"Test 6 (Performance Benchmark): PASSED ({mean_ms:.2f} +/- {std_ms:.2f} ms)")
    except Exception as e:
        print(f"FAILED: {str(e)}")
        test_results['failed'] += 1
        test_results['details'].append(f"Test 6 (Performance Benchmark): FAILED ({str(e)})")
        
    print("\n-------------------------------------------------------")
    print(f"  Test Suite Summary: {test_results['passed']} Passed, {test_results['failed']} Failed  ")
    print("-------------------------------------------------------\n")

if __name__ == "__main__":
    test_module2()

"""
Module 3: Autonomous Demonstration Script (Python Implementation)
SIH 2026 - Problem Statement SIH260038
"""

import os
import sys
import numpy as np
from segment_retina import segment_retina

def generate_synthetic_fundus():
    """Generates a realistic synthetic fundus image for pipeline execution."""
    H, W = 512, 512
    img = np.zeros((H, W, 3), dtype=np.uint8)
    
    Y, X = np.ogrid[:H, :W]
    cx, cy = W // 2, H // 2
    fov_radius = 220
    fov_mask = (X - cx)**2 + (Y - cy)**2 <= fov_radius**2
    
    # Base orange-red retina
    img[fov_mask, 0] = 210
    img[fov_mask, 1] = 90
    img[fov_mask, 2] = 25
    
    # Optic Disc & Cup
    od_x, od_y = 170, 240
    od_mask = (X - od_x)**2 + (Y - od_y)**2 <= 32**2
    oc_mask = (X - od_x)**2 + (Y - od_y)**2 <= 14**2
    
    img[od_mask, :] = [245, 205, 110]
    img[oc_mask, :] = [255, 240, 180]
    
    # Fovea
    fovea_mask = (X - 330)**2 + (Y - 250)**2 <= 18**2
    img[fovea_mask, :] = [130, 50, 15]
    
    # Vessels
    for t in np.linspace(0, 2*np.pi, 200):
        vx = int(od_x + 80 * t)
        vy = int(od_y - 100 * np.sin(t * 0.8) - 15 * t)
        if 0 <= vx < W and 0 <= vy < H:
            img[max(0, vy-2):min(H, vy+2), max(0, vx-2):min(W, vx+2)] = [70, 15, 5]
            
    # Exudates & Hemorrhages
    img[150:156, 370:376] = [245, 240, 90]
    img[180:186, 360:366] = [245, 240, 90]
    img[340:348, 260:268] = [100, 25, 10]
    img[350:358, 270:278] = [100, 25, 10]
    
    return img

def main():
    print("=" * 60)
    print("RetinaScan — Module 3 Retinal & Lesion Segmentation Demo")
    print("Smart India Hackathon 2026 • SIH260038")
    print("=" * 60)
    
    print("\n1. Generating/Loading Retinal Fundus Image...")
    img = generate_synthetic_fundus()
    print(f"   Image Size: {img.shape[0]}x{img.shape[1]}x{img.shape[2]}")
    
    print("\n2. Executing Retinal Segmentation Pipeline...")
    results, overlay = segment_retina(img, {'vesselSensitivity': 0.5})
    
    f = results['features']
    print("\n3. Quantitative Extraction Results:")
    print(f"   • Vessel Density:          {f['vesselDensity']*100:.2f}%")
    print(f"   • Branch Points:           {f['branchPointCount']}")
    print(f"   • Mean Tortuosity:         {f['meanTortuosity']:.3f}")
    print(f"   • Cup-to-Disc Ratio (CDR): {f['cupToDiscRatio']:.3f}")
    print(f"   • Hard Exudate Count:      {f['exudateCount']}")
    print(f"   • Microaneurysms Count:    {f['microaneurysmCount']}")
    print(f"   • Hemorrhages Count:       {f['hemorrhageCount']}")
    
    print("\n4. Vessel Abnormality Scoring:")
    print(f"   • Tortuosity Score (50%):  {f['tortuosityScore']:.1f} / 100")
    print(f"   • Branching Score (25%):   {f['branchingScore']:.1f} / 100")
    print(f"   • Width Score (25%):       {f['widthIrregularityScore']:.1f} / 100")
    print(f"   • FINAL ABNORMALITY SCORE: {f['vesselAbnormalityScore']:.1f} / 100")
    print(f"   • Classification:          {results['vesselAnalysis']['interpretation']}")
    
    print("\n5. Explainable AI Summary:")
    for k, text in results['explanations'].items():
        print(f"   [{k.upper()}]: {text}")
        
    print("\n" + "=" * 60)
    print("✓ MODULE 3 EXECUTION COMPLETED SUCCESSFULLY!")
    print("=" * 60)

if __name__ == '__main__':
    main()

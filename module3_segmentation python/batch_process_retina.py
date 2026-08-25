"""
Module 3: Batch Screening & Processing Engine (Python Implementation)
SIH 2026 - Problem Statement SIH260038
"""

import os
import glob
import csv
import numpy as np
from PIL import Image
from segment_retina import segment_retina

def batch_process_retina(input_dir=None, output_dir=None, options=None):
    """
    Processes an entire folder of retinal fundus images, extracts biomarkers,
    saves segmentation masks and overlays, and writes a consolidated CSV summary.
    """
    curr_dir = os.path.dirname(os.path.abspath(__file__))
    if input_dir is None:
        input_dir = os.path.join(curr_dir, '..', 'demo_samples')
    if output_dir is None:
        output_dir = os.path.join(curr_dir, '..', 'results', 'segmentation')
    if options is None:
        options = {}

    os.makedirs(output_dir, exist_ok=True)

    extensions = ('*.jpg', '*.jpeg', '*.png', '*.tif', '*.tiff')
    img_files = []
    for ext in extensions:
        img_files.extend(glob.glob(os.path.join(input_dir, ext)))

    print("=" * 65)
    print("RetinaScan Module 3: Batch Screening Pipeline (Python)")
    print(f"Input Directory:  {input_dir}")
    print(f"Found Images:     {len(img_files)}")
    print(f"Output Directory: {output_dir}")
    print("=" * 65)

    if not img_files:
        print("No images found in input directory. Creating a test patient scan...")
        from run_module3_demo import generate_synthetic_fundus
        test_img = generate_synthetic_fundus()
        test_path = os.path.join(input_dir, 'patient_scan_001.png')
        os.makedirs(input_dir, exist_ok=True)
        Image.fromarray(test_img).save(test_path)
        img_files = [test_path]

    records = []
    
    for idx, fpath in enumerate(img_files, start=1):
        fname = os.path.basename(fpath)
        base_name = os.path.splitext(fname)[0]
        print(f"[{idx}/{len(img_files)}] Processing: {fname} ...", end=" ")

        try:
            pil_img = Image.open(fpath).convert('RGB')
            img_arr = np.array(pil_img)
            
            results, overlay = segment_retina(img_arr, options)
            
            # Save overlay image
            overlay_path = os.path.join(output_dir, f"{base_name}_overlay.png")
            Image.fromarray(overlay).save(overlay_path)
            
            # Save logical masks
            Image.fromarray((results['vesselMask'] * 255).astype(np.uint8)).save(
                os.path.join(output_dir, f"{base_name}_vessels.png")
            )
            Image.fromarray((results['opticDiscMask'] * 255).astype(np.uint8)).save(
                os.path.join(output_dir, f"{base_name}_optic_disc.png")
            )
            Image.fromarray((results['lesionMask'] * 255).astype(np.uint8)).save(
                os.path.join(output_dir, f"{base_name}_lesions.png")
            )

            f = results['features']
            rec = {
                'ImageName': fname,
                'VesselDensity': f"{f['vesselDensity']:.4f}",
                'SkeletonLength': f['skeletonLength'],
                'BranchPoints': f['branchPointCount'],
                'MeanTortuosity': f"{f['meanTortuosity']:.3f}",
                'MeanWidth': f"{f['meanVesselWidth']:.2f}",
                'WidthCV': f"{f['vesselWidthCV']:.2f}",
                'CDR': f"{f['cupToDiscRatio']:.3f}",
                'ExudatesCount': f['exudateCount'],
                'MicroaneurysmsCount': f['microaneurysmCount'],
                'HemorrhagesCount': f['hemorrhageCount'],
                'VesselAbnormalityScore': f"{f['vesselAbnormalityScore']:.1f}",
                'Interpretation': results['vesselAnalysis']['interpretation']
            }
            records.append(rec)
            print(f"DONE (Abnormality Score: {f['vesselAbnormalityScore']:.1f})")

        except Exception as e:
            print(f"FAILED ({e})")
            records.append({'ImageName': fname, 'Interpretation': f"Error: {e}"})

    # Export to CSV
    csv_path = os.path.join(output_dir, 'screening_biomarkers_summary.csv')
    if records:
        fieldnames = list(records[0].keys())
        with open(csv_path, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(records)

    print("\n" + "=" * 65)
    print("✓ Batch Screening Complete!")
    print(f"Summary CSV Report saved to: {csv_path}")
    print("=" * 65)

if __name__ == '__main__':
    batch_process_retina()

import os
import numpy as np
import cv2

def generate_dummy_dataset(data_folder, num_images_per_class=5):
    """
    Generates synthetic fundus images for each of the 
    5 DR severity grades (0 to 4) for tests and pipeline validation.
    """
    if data_folder is None or data_folder == "":
        data_folder = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'data', 'dummy')
        
    np.random.seed(42)
    
    for c in range(5):
        class_folder = os.path.join(data_folder, str(c))
        os.makedirs(class_folder, exist_ok=True)
        
    for c in range(5):
        class_folder = os.path.join(data_folder, str(c))
        for i in range(1, num_images_per_class + 1):
            img = np.zeros((256, 256, 3), dtype=np.uint8)
            
            y, x = np.ogrid[0:256, 0:256]
            # MATLAB uses 1-indexed, here we shift slightly but it's fine.
            dist_from_center = np.sqrt((x - 127)**2 + (y - 127)**2)
            fundus_mask = dist_from_center <= 100
            
            # Base color
            R_base = 220
            G_base = 100
            B_base = 50
            
            shading = 1.0 - 0.2 * (dist_from_center / 100)**2
            
            img[:, :, 2] = np.where(fundus_mask, R_base * shading, 0) # R
            img[:, :, 1] = np.where(fundus_mask, G_base * shading, 0) # G
            img[:, :, 0] = np.where(fundus_mask, B_base * shading, 0) # B (OpenCV uses BGR)
            
            # Optic disc
            disc_center = (167, 107) # (x, y)
            disc_mask = np.sqrt((x - disc_center[0])**2 + (y - disc_center[1])**2) <= 15
            disc_mask = disc_mask & fundus_mask
            
            img[disc_mask, 2] = 255 # R
            img[disc_mask, 1] = 255 # G
            img[disc_mask, 0] = 150 # B
            
            # Blood vessels
            for angle in range(0, 316, 45):
                rad = np.deg2rad(angle + np.random.randn()*10)
                x_val = disc_center[0]
                y_val = disc_center[1]
                for step in range(80):
                    x_val += np.cos(rad) * 1.0
                    y_val += np.sin(rad) * 1.0
                    ix = int(round(x_val))
                    iy = int(round(y_val))
                    if 0 <= ix < 256 and 0 <= iy < 256 and fundus_mask[iy, ix]:
                        img[iy, ix, 2] = 150
                        img[iy, ix, 1] = 30
                        img[iy, ix, 0] = 10
                        
            # Lesions
            # Class 1: Microaneurysms
            if c >= 1:
                num_MAs = c * 5 + np.random.randint(0, 6)
                for _ in range(num_MAs):
                    rx = 127 + np.random.randint(-70, 71)
                    ry = 127 + np.random.randint(-70, 71)
                    if 1 <= ry < 255 and 1 <= rx < 255 and fundus_mask[ry, rx]:
                        img[ry-1:ry+2, rx-1:rx+2, 2] = 255
                        img[ry-1:ry+2, rx-1:rx+2, 1] = 10
                        img[ry-1:ry+2, rx-1:rx+2, 0] = 10
                        
            # Class 2: Exudates
            if c >= 2:
                num_EXs = (c - 1) * 3 + np.random.randint(0, 4)
                for _ in range(num_EXs):
                    bx = 127 + np.random.randint(-60, 61)
                    by = 127 + np.random.randint(-60, 61)
                    blob_mask = np.sqrt((x - bx)**2 + (y - by)**2) <= 3 + np.random.randint(0, 4)
                    blob_mask = blob_mask & fundus_mask
                    img[blob_mask, 2] = 250
                    img[blob_mask, 1] = 240
                    img[blob_mask, 0] = 180
                    
            # Class 3: Hemorrhages
            if c >= 3:
                num_HEs = (c - 2) * 2 + np.random.randint(0, 3)
                for _ in range(num_HEs):
                    bx = 127 + np.random.randint(-60, 61)
                    by = 127 + np.random.randint(-60, 61)
                    blob_mask = np.sqrt((x - bx)**2 + (y - by)**2) <= 6 + np.random.randint(0, 5)
                    blob_mask = blob_mask & fundus_mask
                    img[blob_mask, 2] = 160
                    img[blob_mask, 1] = 10
                    img[blob_mask, 0] = 10
                    
            # Class 4: NV
            if c >= 4:
                for _ in range(3):
                    bx = 127 + np.random.randint(-50, 51)
                    by = 127 + np.random.randint(-50, 51)
                    for step in range(40):
                        bx += np.random.randn()*1.5
                        by += np.random.randn()*1.5
                        ix = int(round(bx))
                        iy = int(round(by))
                        if 1 <= ix < 255 and 1 <= iy < 255 and fundus_mask[iy, ix]:
                            img[iy-1:iy+2, ix-1:ix+2, 2] = 255
                            img[iy-1:iy+2, ix-1:ix+2, 1] = 50
                            img[iy-1:iy+2, ix-1:ix+2, 0] = 20
                            
            filename = os.path.join(class_folder, f"patient{c}_{i:03d}_PP.png")
            cv2.imwrite(filename, img)
            
    print(f"Successfully generated synthetic dataset under {data_folder}")

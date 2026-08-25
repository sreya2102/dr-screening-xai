import numpy as np
import cv2

def preprocess_image(img):
    """
    Crops black borders, pads to a square to preserve aspect
    ratio, resizes to 224x224, and normalizes using ImageNet statistics.
    
    Inputs:
      img - RGB image (uint8 or float, any size)
    Outputs:
      img_tensor - Preprocessed float32 224x224x3 image array 
                   (Can be converted to PyTorch tensor [3, 224, 224] later)
    """
    # Convert input image to double in [0, 1] range
    img_double = img.astype(float)
    if np.max(img_double) > 1.0:
        img_double = img_double / 255.0
        
    # Ensure 3 color channels
    if len(img_double.shape) == 2:
        img_double = np.stack([img_double, img_double, img_double], axis=-1)
    elif img_double.shape[2] > 3:
        img_double = img_double[:, :, :3]
        
    # 1. Crop black margins
    # Convert to grayscale for thresholding
    gray = img_double[:, :, 0] * 0.2989 + img_double[:, :, 1] * 0.5870 + img_double[:, :, 2] * 0.1140
    mask = gray > 0.05
    
    rows, cols = np.where(mask)
    
    if len(rows) > 0 and len(cols) > 0:
        min_row, max_row = np.min(rows), np.max(rows)
        min_col, max_col = np.min(cols), np.max(cols)
        img_double = img_double[min_row:max_row+1, min_col:max_col+1, :]
        
    # 2. Pad to square to preserve aspect ratio
    h, w, c = img_double.shape
    if h > w:
        pad_total = h - w
        pad_left = pad_total // 2
        pad_right = pad_total - pad_left
        img_double = np.pad(img_double, ((0, 0), (pad_left, pad_right), (0, 0)), mode='constant', constant_values=0)
    elif w > h:
        pad_total = w - h
        pad_top = pad_total // 2
        pad_bottom = pad_total - pad_top
        img_double = np.pad(img_double, ((pad_top, pad_bottom), (0, 0), (0, 0)), mode='constant', constant_values=0)
        
    # 3. Resize to 224x224
    img_resized = cv2.resize(img_double, (224, 224), interpolation=cv2.INTER_LINEAR)
    
    # 4. Normalization (ImageNet mean and std dev)
    mean_val = np.array([0.485, 0.456, 0.406]).reshape(1, 1, 3)
    std_val = np.array([0.229, 0.224, 0.225]).reshape(1, 1, 3)
    img_norm = (img_resized - mean_val) / std_val
    
    # 5. Convert to single precision
    return img_norm.astype(np.float32)

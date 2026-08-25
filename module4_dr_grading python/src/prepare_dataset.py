import os
import glob
import re
import numpy as np
import cv2
import torch
from torch.utils.data import Dataset, DataLoader, Subset
import sys

# Import preprocess_image
sys.path.append(os.path.join(os.path.dirname(__file__), 'utils'))
from preprocess_image import preprocess_image

def get_patient_id(filepath):
    filename = os.path.basename(filepath)
    name, _ = os.path.splitext(filename)
    
    # Pattern 1: Messidor-2 style
    m1 = re.match(r'^\d+_(\d+)_\d+_PP$', name)
    if m1:
        return m1.group(1)
        
    # Pattern 2: Simple prefix split by underscore
    m2 = re.match(r'^([^_]+)_', name)
    if m2:
        return m2.group(1)
        
    return name

def make_coral_targets(labels):
    n_images = len(labels)
    n_classes = 5
    targets = np.zeros((n_images, n_classes - 1), dtype=np.float32)
    for k in range(n_images):
        grade = int(labels[k])
        if grade > 0:
            targets[k, 0:grade] = 1.0
    return targets

def make_mock_lesions(labels):
    np.random.seed(100) # Reset seed locally to ensure reproducibility
    n_images = len(labels)
    lesions = np.zeros((n_images, 8), dtype=np.float32)
    
    for k in range(n_images):
        grade = int(labels[k])
        v = np.zeros(8, dtype=np.float32)
        v[6] = 1.0 # I_avail
        v[7] = 0.0 # I_missing
        
        if grade == 0:
            v[0] = np.log1p(np.random.randint(0, 2))
            v[1] = np.random.rand() * 0.01
            v[2] = np.random.rand() * 0.01
            v[3] = 0.5 + np.random.rand() * 0.2
            v[4] = 0.0
            v[5] = 0.8 + np.random.rand() * 0.2
        elif grade == 1:
            v[0] = np.log1p(np.random.randint(1, 6))
            v[1] = np.random.rand() * 0.02
            v[2] = np.random.rand() * 0.01
            v[3] = 0.5 + np.random.rand() * 0.2
            v[4] = 0.0
            v[5] = np.random.rand() * 0.8
        elif grade == 2:
            v[0] = np.log1p(np.random.randint(5, 16))
            v[1] = np.random.rand() * 0.05
            v[2] = np.random.rand() * 0.08
            v[3] = 0.4 + np.random.rand() * 0.2
            v[4] = 0.0
            v[5] = np.random.rand() * 0.7
        elif grade == 3:
            v[0] = np.log1p(np.random.randint(15, 41))
            v[1] = 0.05 + np.random.rand() * 0.15
            v[2] = 0.08 + np.random.rand() * 0.15
            v[3] = 0.3 + np.random.rand() * 0.2
            v[4] = np.random.rand() * 0.05
            v[5] = np.random.rand() * 0.5
        elif grade == 4:
            v[0] = np.log1p(np.random.randint(30, 81))
            v[1] = 0.10 + np.random.rand() * 0.25
            v[2] = 0.10 + np.random.rand() * 0.25
            v[3] = 0.2 + np.random.rand() * 0.2
            v[4] = 0.1 + np.random.rand() * 0.4
            v[5] = np.random.rand() * 0.4
            
        # 10% probability of M3 module failure simulation
        if np.random.rand() < 0.10:
            v = np.zeros(8, dtype=np.float32)
            v[7] = 1.0
            
        lesions[k, :] = v
        
    return lesions

class DRDataset(Dataset):
    def __init__(self, filepaths, labels, mode='fusion'):
        self.filepaths = filepaths
        self.labels = labels
        self.mode = mode
        
        self.targets = make_coral_targets(self.labels)
        if self.mode in ['lesion-only', 'fusion']:
            self.lesions = make_mock_lesions(self.labels)
            
    def __len__(self):
        return len(self.filepaths)
        
    def __getitem__(self, idx):
        target = torch.tensor(self.targets[idx], dtype=torch.float32)
        
        if self.mode == 'lesion-only':
            lesion = torch.tensor(self.lesions[idx], dtype=torch.float32)
            return lesion, target
            
        # Load image (OpenCV returns BGR, convert to RGB)
        img_bgr = cv2.imread(self.filepaths[idx])
        img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
        img_preprocessed = preprocess_image(img_rgb)
        # Convert HWC to CHW for PyTorch
        img_tensor = torch.tensor(img_preprocessed.transpose(2, 0, 1), dtype=torch.float32)
        
        if self.mode == 'cnn-only':
            return img_tensor, target
            
        # fusion
        lesion = torch.tensor(self.lesions[idx], dtype=torch.float32)
        return img_tensor, lesion, target

def prepare_dataset(data_folder, split_ratios=(0.7, 0.15, 0.15), mode='fusion'):
    # Find all images
    filepaths = []
    labels = []
    
    for c in range(5):
        class_folder = os.path.join(data_folder, str(c))
        if os.path.isdir(class_folder):
            files = glob.glob(os.path.join(class_folder, '*.png')) + glob.glob(os.path.join(class_folder, '*.jpg'))
            filepaths.extend(files)
            labels.extend([c] * len(files))
            
    n_files = len(filepaths)
    patient_ids = [get_patient_id(f) for f in filepaths]
    
    unique_patients = list(set(patient_ids))
    n_patients = len(unique_patients)
    
    # Deterministic random shuffle of patients
    np.random.seed(42)
    np.random.shuffle(unique_patients)
    
    n_train = int(round(split_ratios[0] * n_patients))
    n_val = int(round(split_ratios[1] * n_patients))
    
    train_patients_idx = set(unique_patients[:n_train])
    val_patients_idx = set(unique_patients[n_train : n_train+n_val])
    test_patients_idx = set(unique_patients[n_train+n_val :])
    
    train_files, train_labels = [], []
    val_files, val_labels = [], []
    test_files, test_labels = [], []
    
    for idx, pid in enumerate(patient_ids):
        if pid in train_patients_idx:
            train_files.append(filepaths[idx])
            train_labels.append(labels[idx])
        elif pid in val_patients_idx:
            val_files.append(filepaths[idx])
            val_labels.append(labels[idx])
        elif pid in test_patients_idx:
            test_files.append(filepaths[idx])
            test_labels.append(labels[idx])
            
    train_ds = DRDataset(train_files, train_labels, mode)
    val_ds = DRDataset(val_files, val_labels, mode)
    test_ds = DRDataset(test_files, test_labels, mode)
    
    return train_ds, val_ds, test_ds

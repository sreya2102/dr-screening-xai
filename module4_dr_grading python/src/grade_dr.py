import os
import torch
import numpy as np

import sys
sys.path.append(os.path.dirname(__file__))
from utils.preprocess_image import preprocess_image
from utils.validate_lesion_features import validate_lesion_features
from utils.coral import reconstruct_grade
from build_model import build_model

def grade_dr(image, model_path_or_data, lesion_features=None, return_activations=False):
    """
    Performs Diabetic Retinopathy severity grading from an input 
    fundus image and optional Module 3 lesion features.
    """
    # 1. Load the model
    if isinstance(model_path_or_data, str):
        if not os.path.exists(model_path_or_data):
            raise FileNotFoundError(f"Model file not found: {model_path_or_data}")
        model_data = torch.load(model_path_or_data, map_location='cpu')
    else:
        model_data = model_path_or_data
        
    mode = model_data.get('mode', 'fusion')
    backbone = model_data.get('backbone', 'resnet50')
    
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    
    # Initialize and load weights
    model = build_model(backbone_name=backbone, mode=mode)
    model.load_state_dict(model_data['state_dict'])
    model.to(device)
    model.eval()
    
    # 2. Image preprocessing
    preprocessed_img = preprocess_image(image)
    # Convert HWC to CHW
    img_tensor = torch.tensor(preprocessed_img.transpose(2, 0, 1), dtype=torch.float32).unsqueeze(0).to(device)
    
    # 3. Lesion features preprocessing
    lesion_vec = validate_lesion_features(lesion_features)
    lesion_tensor = torch.tensor(lesion_vec, dtype=torch.float32).unsqueeze(0).to(device)
    
    # 4. Forward Prediction
    with torch.no_grad():
        if mode == 'fusion':
            probabilities = model(img=img_tensor, lesions=lesion_tensor)
        elif mode == 'cnn-only':
            probabilities = model(img=img_tensor)
        elif mode == 'lesion-only':
            probabilities = model(lesions=lesion_tensor)
            
    probs = probabilities.cpu().numpy()[0] # shape (4,)
    
    # 5. Probability Calibration
    # Compute logit: log(p / (1 - p))
    probs_clipped = np.clip(probs, 1e-7, 1.0 - 1e-7)
    logits = np.log(probs_clipped / (1.0 - probs_clipped))
    logits = np.clip(logits, -20.0, 20.0)
    
    calib_params = model_data.get('calibrationParams', {})
    if 'temperature' in calib_params:
        T = calib_params['temperature']
        calib_probs = 1.0 / (1.0 + np.exp(-logits / T))
    elif 'a' in calib_params and 'b' in calib_params:
        a = calib_params['a']
        b = calib_params['b']
        calib_probs = 1.0 / (1.0 + np.exp(-(a * logits + b)))
    else:
        calib_probs = probs
        
    # 7. Reconstruct grade
    grade, confidence, p_class = reconstruct_grade(calib_probs)
    grade = grade[0]
    confidence = confidence[0]
    p_class = p_class[0]
    
    # 8. Evaluate Referable DR
    referable_prob = calib_probs[1] # P(Grade >= 2)
    referable_threshold = model_data.get('referableThreshold', 0.5)
    referable_dr = bool(referable_prob >= referable_threshold)
    
    # 9. Package output
    result = {
        'grade': int(grade),
        'confidence': float(confidence),
        'classProbabilities': p_class.tolist(),
        'referableDR': referable_dr,
        'referableProbability': float(referable_prob),
        'referableThreshold': float(referable_threshold),
        'logits': logits.tolist(),
        'modelVersion': model_data.get('version', 'v1.0.0')
    }
    
    activations = None # Hooks for M5 can be added here if return_activations is true
    
    return result, activations

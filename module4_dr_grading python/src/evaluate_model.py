import torch
import numpy as np
from sklearn.metrics import confusion_matrix, cohen_kappa_score, f1_score, mean_absolute_error
from grade_dr import grade_dr

def evaluate_model(model_path, test_ds):
    """
    Evaluates the trained model on a test datastore, computing
    standard and clinical grading metrics, including accuracy, macro F1,
    MAE, QWK, referable sensitivity/specificity, ECE, and Brier Score.
    """
    model_data = torch.load(model_path, map_location='cpu')
    
    true_grades = []
    pred_grades = []
    confidences = []
    class_probs_list = []
    referable_probs = []
    referable_true = []
    referable_pred = []
    
    print("Running evaluation on testing dataset...")
    for idx in range(len(test_ds)):
        if model_data['mode'] == 'fusion':
            img, lesions, target = test_ds[idx]
        elif model_data['mode'] == 'cnn-only':
            img, target = test_ds[idx]
            lesions = None
        else: # lesion-only
            lesions, target = test_ds[idx]
            img = torch.zeros(3, 224, 224, dtype=torch.float32) # Dummy
            
        true_grade = int(torch.sum(target).item())
        
        # We need to pass numpy arrays to grade_dr as it handles preprocessing.
        # However, grade_dr expects raw image, but our dataset already returns preprocessed tensor.
        # We should slightly modify how we call grade_dr for evaluation, or recreate the forward pass here.
        # For simplicity, we'll recreate the forward pass logic here directly to avoid redundant preprocessing.
        
        device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        
        # This is a bit redundant but ensures we use the exact grade_dr API if we want.
        # Actually, let's just use the model directly to be faster and consistent with testDS format.
        
        import sys
        import os
        sys.path.append(os.path.dirname(__file__))
        from build_model import build_model
        from utils.coral import reconstruct_grade
        
        model = build_model(model_data['backbone'], model_data['mode'])
        model.load_state_dict(model_data['state_dict'])
        model.to(device)
        model.eval()
        
        with torch.no_grad():
            if model_data['mode'] == 'fusion':
                probs = model(img.unsqueeze(0).to(device), lesions.unsqueeze(0).to(device))
            elif model_data['mode'] == 'cnn-only':
                probs = model(img=img.unsqueeze(0).to(device))
            elif model_data['mode'] == 'lesion-only':
                probs = model(lesions=lesions.unsqueeze(0).to(device))
                
        probs = probs.cpu().numpy()[0]
        
        # Calibration
        probs_clipped = np.clip(probs, 1e-7, 1.0 - 1e-7)
        logits = np.log(probs_clipped / (1.0 - probs_clipped))
        logits = np.clip(logits, -20.0, 20.0)
        
        calib_params = model_data.get('calibrationParams', {})
        if 'temperature' in calib_params:
            T = calib_params['temperature']
            calib_probs = 1.0 / (1.0 + np.exp(-logits / T))
        else:
            calib_probs = probs
            
        grade, confidence, p_class = reconstruct_grade(calib_probs)
        pred_grade = grade[0]
        conf = confidence[0]
        p_c = p_class[0]
        
        ref_prob = calib_probs[1]
        ref_thresh = model_data.get('referableThreshold', 0.5)
        ref_pred = ref_prob >= ref_thresh
        ref_true = true_grade >= 2
        
        true_grades.append(true_grade)
        pred_grades.append(pred_grade)
        confidences.append(conf)
        class_probs_list.append(p_c)
        referable_probs.append(ref_prob)
        referable_true.append(ref_true)
        referable_pred.append(ref_pred)
        
    true_grades = np.array(true_grades)
    pred_grades = np.array(pred_grades)
    confidences = np.array(confidences)
    class_probs_list = np.array(class_probs_list)
    referable_true = np.array(referable_true)
    referable_pred = np.array(referable_pred)
    
    # 2. Calculate core metrics
    metrics = {}
    C = confusion_matrix(true_grades, pred_grades, labels=[0, 1, 2, 3, 4])
    metrics['ConfusionMatrix'] = C.tolist()
    
    metrics['Accuracy'] = np.sum(np.diag(C)) / np.sum(C) if np.sum(C) > 0 else 0
    metrics['MAE'] = mean_absolute_error(true_grades, pred_grades)
    metrics['QWK'] = cohen_kappa_score(true_grades, pred_grades, weights='quadratic')
    metrics['MacroF1'] = f1_score(true_grades, pred_grades, average='macro')
    
    # Referable DR metrics
    tp_ref = np.sum(referable_true & referable_pred)
    fn_ref = np.sum(referable_true & ~referable_pred)
    fp_ref = np.sum(~referable_true & referable_pred)
    tn_ref = np.sum(~referable_true & ~referable_pred)
    
    metrics['ReferableSensitivity'] = tp_ref / (tp_ref + fn_ref) if (tp_ref + fn_ref) > 0 else 0
    metrics['ReferableSpecificity'] = tn_ref / (tn_ref + fp_ref) if (tn_ref + fp_ref) > 0 else 0
    
    # ECE
    accuracies = (true_grades == pred_grades).astype(float)
    n = len(confidences)
    ece = 0
    num_bins = 10
    bin_edges = np.linspace(0, 1, num_bins + 1)
    
    for b in range(num_bins):
        in_bin = (confidences > bin_edges[b]) & (confidences <= bin_edges[b+1])
        bin_size = np.sum(in_bin)
        if bin_size > 0:
            bin_acc = np.mean(accuracies[in_bin])
            bin_conf = np.mean(confidences[in_bin])
            ece += (bin_size / n) * np.abs(bin_acc - bin_conf)
    metrics['ECE'] = ece
    
    # Brier Score
    one_hot_targets = np.zeros((len(true_grades), 5))
    for k in range(len(true_grades)):
        one_hot_targets[k, true_grades[k]] = 1.0
    metrics['BrierScore'] = np.mean(np.sum((class_probs_list - one_hot_targets)**2, axis=1))
    
    return metrics

import os
import sys
import torch
import numpy as np
import shutil

# Add src to path
src_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'src')
sys.path.append(src_path)

from generate_dummy_dataset import generate_dummy_dataset
from prepare_dataset import prepare_dataset
from train_model import train_model
from evaluate_model import evaluate_model
from grade_dr import grade_dr

def test_module4():
    print("=======================================================")
    print("  Module 4: DR Grading - Automated Test Suite (PyTorch) ")
    print("=======================================================\n")
    
    test_results = {'passed': 0, 'failed': 0, 'details': []}
    
    dummy_data_folder = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'data', 'dummy_test')
    
    # 1. Dataset Generation
    print("[Test 1] Dummy Dataset Generation... ", end="")
    try:
        if os.path.exists(dummy_data_folder):
            shutil.rmtree(dummy_data_folder)
        generate_dummy_dataset(dummy_data_folder, num_images_per_class=3)
        print("PASSED")
        test_results['passed'] += 1
        test_results['details'].append("Test 1 (Dataset Generation): PASSED")
    except Exception as e:
        print(f"FAILED: {str(e)}")
        test_results['failed'] += 1
        test_results['details'].append(f"Test 1 (Dataset Generation): FAILED ({str(e)})")
        
    # 2. Dataloader & CORAL Targets Preparation
    print("[Test 2] Dataset Preparation & Splitting... ", end="")
    try:
        train_ds, val_ds, test_ds = prepare_dataset(dummy_data_folder, split_ratios=(0.6, 0.2, 0.2), mode='fusion')
        assert len(train_ds) > 0, "Train dataset is empty"
        img, lesion, target = train_ds[0]
        assert img.shape == (3, 224, 224), "Image shape mismatch"
        assert lesion.shape == (8,), "Lesion vector shape mismatch"
        assert target.shape == (4,), "CORAL target shape mismatch"
        print("PASSED")
        test_results['passed'] += 1
        test_results['details'].append("Test 2 (Dataset Preparation): PASSED")
    except Exception as e:
        print(f"FAILED: {str(e)}")
        test_results['failed'] += 1
        test_results['details'].append(f"Test 2 (Dataset Preparation): FAILED ({str(e)})")
        
    # 3. Model Build & Overfit single epoch
    print("[Test 3] Model Training Loop (1 Epoch)... ", end="")
    try:
        options = {
            'backboneName': 'resnet50',
            'mode': 'fusion',
            'epochs': 1,
            'miniBatchSize': 2,
            'learningRate': 1e-3,
            'savePath': os.path.join(os.path.dirname(os.path.dirname(__file__)), 'trained_models', 'test_model.pth')
        }
        
        # Train on small subset to be fast
        model, info = train_model(train_ds, val_ds, options)
        assert len(info['TrainLossHistory']) == 1, "Loss history not tracked"
        assert os.path.exists(options['savePath']), "Model checkpoint not saved"
        print("PASSED")
        test_results['passed'] += 1
        test_results['details'].append("Test 3 (Model Training Loop): PASSED")
    except Exception as e:
        print(f"FAILED: {str(e)}")
        test_results['failed'] += 1
        test_results['details'].append(f"Test 3 (Model Training Loop): FAILED ({str(e)})")
        
    # 4. Evaluation Metrics
    print("[Test 4] Evaluation Metrics Calculation... ", end="")
    try:
        model_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'trained_models', 'test_model.pth')
        metrics = evaluate_model(model_path, test_ds)
        assert 'Accuracy' in metrics, "Accuracy missing"
        assert 'QWK' in metrics, "QWK missing"
        print("PASSED")
        test_results['passed'] += 1
        test_results['details'].append("Test 4 (Evaluation Metrics): PASSED")
    except Exception as e:
        print(f"FAILED: {str(e)}")
        test_results['failed'] += 1
        test_results['details'].append(f"Test 4 (Evaluation Metrics): FAILED ({str(e)})")
        
    # 5. Inference API & Fallback
    print("[Test 5] Inference API & M3 Fallback... ", end="")
    try:
        img_mock = np.zeros((224, 224, 3), dtype=np.uint8)
        lesion_mock = {'maCount': 5, 'isAvailable': True}
        model_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'trained_models', 'test_model.pth')
        
        # Valid features
        res1, _ = grade_dr(img_mock, model_path, lesion_mock)
        assert res1['grade'] in [0, 1, 2, 3, 4], "Invalid grade prediction"
        
        # Missing features fallback
        lesion_mock_fail = {'isAvailable': False}
        res2, _ = grade_dr(img_mock, model_path, lesion_mock_fail)
        assert res2['grade'] in [0, 1, 2, 3, 4], "Fallback prediction failed"
        
        print("PASSED")
        test_results['passed'] += 1
        test_results['details'].append("Test 5 (Inference API): PASSED")
    except Exception as e:
        print(f"FAILED: {str(e)}")
        test_results['failed'] += 1
        test_results['details'].append(f"Test 5 (Inference API): FAILED ({str(e)})")
        
    # Cleanup
    if os.path.exists(dummy_data_folder):
        shutil.rmtree(dummy_data_folder)
        
    print("\n-------------------------------------------------------")
    print(f"  Test Suite Summary: {test_results['passed']} Passed, {test_results['failed']} Failed  ")
    print("-------------------------------------------------------\n")
    
if __name__ == "__main__":
    test_module4()

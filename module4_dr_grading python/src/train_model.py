import os
import time
import torch
import torch.optim as optim
from torch.utils.data import DataLoader
from datetime import datetime

import sys
sys.path.append(os.path.dirname(__file__))
from build_model import build_model
from utils.coral import coral_loss

def evaluate_validation_loss(model, val_loader, device, mode):
    model.eval()
    total_loss = 0.0
    steps = 0
    
    with torch.no_grad():
        for batch in val_loader:
            steps += 1
            if mode == 'fusion':
                imgs, lesions, targets = batch
                imgs, lesions, targets = imgs.to(device), lesions.to(device), targets.to(device)
                preds = model(imgs, lesions)
            elif mode == 'cnn-only':
                imgs, targets = batch
                imgs, targets = imgs.to(device), targets.to(device)
                preds = model(img=imgs)
            elif mode == 'lesion-only':
                lesions, targets = batch
                lesions, targets = lesions.to(device), targets.to(device)
                preds = model(lesions=lesions)
                
            loss = coral_loss(preds, targets)
            total_loss += loss.item()
            
    return total_loss / steps if steps > 0 else 0.0

def train_model(train_ds, val_ds, options=None):
    if options is None:
        options = {}
        
    backbone_name = options.get('backboneName', 'resnet50')
    mode = options.get('mode', 'fusion')
    epochs = options.get('epochs', 10)
    batch_size = options.get('miniBatchSize', 8)
    learning_rate = options.get('learningRate', 1e-3)
    
    save_path = options.get('savePath', os.path.join(
        os.path.dirname(os.path.dirname(__file__)), 'trained_models', 'dr_grading_model.pth'
    ))
    
    save_dir = os.path.dirname(save_path)
    if save_dir and not os.path.exists(save_dir):
        os.makedirs(save_dir, exist_ok=True)
        
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"Training on: {device}")
    
    # 1. Build the network
    model = build_model(backbone_name=backbone_name, mode=mode)
    model.to(device)
    
    # 2. Setup DataLoaders
    train_loader = DataLoader(train_ds, batch_size=batch_size, shuffle=True, drop_last=False)
    val_loader = DataLoader(val_ds, batch_size=batch_size, shuffle=False, drop_last=False)
    
    # 3. Setup Optimizer
    optimizer = optim.Adam(model.parameters(), lr=learning_rate)
    
    # 4. Custom Training Loop
    train_loss_history = []
    val_loss_history = []
    best_val_loss = float('inf')
    
    print("Starting Custom Training Loop...")
    for epoch in range(1, epochs + 1):
        model.train()
        epoch_loss = 0.0
        epoch_steps = 0
        
        for batch in train_loader:
            epoch_steps += 1
            optimizer.zero_grad()
            
            if mode == 'fusion':
                imgs, lesions, targets = batch
                imgs, lesions, targets = imgs.to(device), lesions.to(device), targets.to(device)
                preds = model(imgs, lesions)
            elif mode == 'cnn-only':
                imgs, targets = batch
                imgs, targets = imgs.to(device), targets.to(device)
                preds = model(img=imgs)
            elif mode == 'lesion-only':
                lesions, targets = batch
                lesions, targets = lesions.to(device), targets.to(device)
                preds = model(lesions=lesions)
                
            loss = coral_loss(preds, targets)
            loss.backward()
            optimizer.step()
            
            epoch_loss += loss.item()
            
        avg_train_loss = epoch_loss / epoch_steps if epoch_steps > 0 else 0.0
        train_loss_history.append(avg_train_loss)
        
        # 5. Compute Validation Loss
        val_loss = evaluate_validation_loss(model, val_loader, device, mode)
        val_loss_history.append(val_loss)
        
        print(f"Epoch {epoch}/{epochs} - Train Loss: {avg_train_loss:.4f} | Val Loss: {val_loss:.4f}")
        
        # 6. Model Checkpointing
        if val_loss < best_val_loss:
            best_val_loss = val_loss
            
            model_data = {
                'state_dict': model.state_dict(),
                'version': 'v1.0.0',
                'backbone': backbone_name,
                'mode': mode,
                'featureSchemaVersion': 'v1.0',
                'inputSize': [224, 224, 3],
                'normalizationStats': {'mean': [0.485, 0.456, 0.406], 'std': [0.229, 0.224, 0.225]},
                'calibrationParams': {'temperature': 1.0},
                'referableThreshold': 0.5,
                'classNames': ['Normal', 'Mild', 'Moderate', 'Severe', 'Proliferative'],
                'trainingMetadata': {
                    'Epochs': epochs,
                    'MiniBatchSize': batch_size,
                    'LearningRate': learning_rate,
                    'BestValLoss': best_val_loss,
                    'Timestamp': str(datetime.now())
                }
            }
            
            torch.save(model_data, save_path)
            print(f" -> Saved new best model checkpoint to {save_path}")
            
    info = {
        'TrainLossHistory': train_loss_history,
        'ValLossHistory': val_loss_history
    }
    
    return model, info

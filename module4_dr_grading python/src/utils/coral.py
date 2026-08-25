import torch
import torch.nn as nn
import torch.nn.functional as F

class CoralLayer(nn.Module):
    """
    CORALLAYER Custom layer enforcing consistent rank logits (CORAL).
    Parameterizes thresholds as a cumulative sum of exponentials to ensure
    b_1 <= b_2 <= b_3 <= b_4.
    
    Input shape:  [BatchSize, 1] (scalar shared logit)
    Output shape: [BatchSize, 4] (logits for the 4 ordinal cumulative tasks)
    """
    def __init__(self):
        super(CoralLayer, self).__init__()
        # Initialize the learnable parameter vector (4,)
        self.theta = nn.Parameter(torch.zeros(4, dtype=torch.float32))
        
    def forward(self, x):
        # x is [BatchSize, 1]
        
        # Enforce monotonicity: b_i = b_{i-1} + exp(theta_i)
        # b will be of shape [4]
        # In PyTorch, we can do a cumulative sum of exponentials for i >= 1
        # But theta[0] is just b_0.
        exps = torch.exp(self.theta[1:])
        b = torch.cat([self.theta[0:1], exps], dim=0)
        b = torch.cumsum(b, dim=0)
        
        # Broadcast subtraction: x is [BatchSize, 1], b is [4]
        # output is [BatchSize, 4]
        y = x - b.unsqueeze(0)
        return y


def coral_loss(predictions, targets):
    """
    Computes the Consistent Rank Logits (CORAL) ordinal loss.
    
    Inputs:
      predictions - tensor of size [BatchSize, 4] containing predicted cumulative probabilities
      targets     - tensor of size [BatchSize, 4] containing ground-truth cumulative binary labels
    Outputs:
      loss        - scalar tensor representing the Consistent Rank Logits loss
    """
    # Clip predictions to prevent log(0) and numerical instability
    epsilon = 1e-7
    pred_clipped = torch.clamp(predictions, epsilon, 1.0 - epsilon)
    
    # Binary Cross Entropy formula
    bce = - (targets * torch.log(pred_clipped) + (1.0 - targets) * torch.log(1.0 - pred_clipped))
    
    # Sum over cumulative tasks (dim=1), and take average over batch (dim=0)
    loss = torch.mean(torch.sum(bce, dim=1))
    return loss


def reconstruct_grade(probabilities):
    """
    Converts cumulative probabilities from the CORAL head 
    into integer severity grades and confidence scores.
    
    Inputs:
      probabilities - Array/tensor of size [BatchSize, 4] containing cumulative probabilities
    Outputs:
      grade       - list/array of predicted class indices (0 to 4)
      confidence  - list/array of confidence scores for the predicted grade
      p_class     - matrix of size [BatchSize, 5] containing mutually exclusive class probabilities
    """
    if isinstance(probabilities, torch.Tensor):
        preds = probabilities.detach().cpu().numpy()
    else:
        preds = probabilities
        
    if len(preds.shape) == 1:
        preds = preds.reshape(1, -1)
        
    batch_size = preds.shape[0]
    grade = np.zeros(batch_size, dtype=int)
    confidence = np.zeros(batch_size, dtype=float)
    p_class = np.zeros((batch_size, 5), dtype=float)
    
    for k in range(batch_size):
        p = preds[k, :]
        # Ensure monotonicity by sorting in descending order (Platt scaling safe-guard)
        p = np.sort(p)[::-1]
        
        # Count how many cumulative heads exceed the threshold (0.5)
        predicted_grade = np.sum(p >= 0.5)
        grade[k] = predicted_grade
        
        # Reconstruct 5 mutually exclusive class probabilities
        p_class[k, 0] = 1.0 - p[0]
        p_class[k, 1] = p[0] - p[1]
        p_class[k, 2] = p[1] - p[2]
        p_class[k, 3] = p[2] - p[3]
        p_class[k, 4] = p[3]
        
        # Clamp to zero and normalize for numerical safety
        p_class[k, :] = np.maximum(0, p_class[k, :])
        sum_prob = np.sum(p_class[k, :])
        if sum_prob > 0:
            p_class[k, :] = p_class[k, :] / sum_prob
        else:
            p_class[k, :] = np.array([1, 0, 0, 0, 0]) # Fallback default
            
        # Confidence corresponds to the probability of the predicted grade
        confidence[k] = p_class[k, predicted_grade]
        
    return grade, confidence, p_class

import numpy as np

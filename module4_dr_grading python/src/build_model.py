import torch
import torch.nn as nn
from torchvision.models import resnet50, ResNet50_Weights
import sys
import os

# Add src to path so utils can be found dynamically if run from outside
sys.path.append(os.path.dirname(__file__))
from utils.coral import CoralLayer

class DRGradingModel(nn.Module):
    def __init__(self, backbone_name='resnet50', mode='fusion'):
        """
        Builds a multi-stream fusion network or single-stream baseline 
        network for Consistent Rank Logits (CORAL) ordinal grading.
        
        Inputs:
          backbone_name - String: Name of the CNN backbone ('resnet50')
          mode          - String: Network configuration mode ('cnn-only', 'lesion-only', 'fusion')
        """
        super(DRGradingModel, self).__init__()
        self.mode = mode
        
        # 1. Build Visual Stream
        if self.mode in ['fusion', 'cnn-only']:
            if backbone_name == 'resnet50':
                # Load pre-trained ResNet-50
                resnet = resnet50(weights=ResNet50_Weights.IMAGENET1K_V1)
                
                # Remove final fully connected layer
                self.visual_backbone = nn.Sequential(*list(resnet.children())[:-1])
                
                # Visual embedding layers (2048 -> 128)
                self.visual_embed = nn.Sequential(
                    nn.Flatten(),
                    nn.Linear(2048, 128),
                    nn.ReLU(inplace=True)
                )
            else:
                raise ValueError(f"Unsupported backbone: {backbone_name}")
                
        # 2. Build Clinical Stream
        if self.mode in ['fusion', 'lesion-only']:
            # Clinical lesion features input stream (8-D to 32-D projection)
            self.clinical_embed = nn.Sequential(
                nn.Linear(8, 32),
                nn.ReLU(inplace=True)
            )
            
        # 3. Assemble Fusion or Baseline Streams with custom CORAL layers
        if self.mode == 'fusion':
            # Concat visual (128) + clinical (32) = 160
            self.coral_logit = nn.Linear(160, 1, bias=False)
            self.coral_layer = CoralLayer()
            
        elif self.mode == 'lesion-only':
            self.coral_logit = nn.Linear(32, 1, bias=False)
            self.coral_layer = CoralLayer()
            
        elif self.mode == 'cnn-only':
            self.coral_logit = nn.Linear(128, 1, bias=False)
            self.coral_layer = CoralLayer()
            
    def forward(self, img=None, lesions=None):
        """
        Forward pass.
        Inputs:
          img - Tensor of shape [B, 3, 224, 224] (Optional depending on mode)
          lesions - Tensor of shape [B, 8] (Optional depending on mode)
        Outputs:
          probabilities - Tensor of shape [B, 4] containing cumulative probabilities
        """
        if self.mode == 'fusion':
            v_feat = self.visual_backbone(img)
            v_embed = self.visual_embed(v_feat)
            
            c_embed = self.clinical_embed(lesions)
            
            # Concatenate
            concat_feat = torch.cat((v_embed, c_embed), dim=1)
            
            logit = self.coral_logit(concat_feat)
            
        elif self.mode == 'cnn-only':
            v_feat = self.visual_backbone(img)
            v_embed = self.visual_embed(v_feat)
            logit = self.coral_logit(v_embed)
            
        elif self.mode == 'lesion-only':
            c_embed = self.clinical_embed(lesions)
            logit = self.coral_logit(c_embed)
            
        # Apply CoralLayer
        ordinal_logits = self.coral_layer(logit)
        
        # Sigmoid to get cumulative probabilities
        probabilities = torch.sigmoid(ordinal_logits)
        
        return probabilities

def build_model(backbone_name='resnet50', mode='fusion'):
    return DRGradingModel(backbone_name, mode)

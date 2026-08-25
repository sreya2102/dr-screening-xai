import numpy as np

def validate_lesion_features(lesion_features=None):
    """
    Validates the lesion feature dict from Module 3,
    normalizes the elements, and outputs an 8-D vector with availability flags.
    
    Inputs:
      lesion_features - Dict containing lesion metrics
    Outputs:
      v - 1x8 float32 numpy array:
          [maCount, hemorrhageArea, exudateArea, vesselDensity, nvScore, opticDiscDistance, I_avail, I_missing]
    """
    # Initialize default feature vector representing missing/unavailable state
    v = np.zeros(8, dtype=np.float32)
    v[7] = 1.0 # I_missing = 1.0, I_avail = 0.0
    
    # Check if input is a valid dict and isAvailable is True
    if lesion_features is not None and isinstance(lesion_features, dict) and lesion_features.get('isAvailable', False):
        # Set availability indicators
        v[6] = 1.0 # I_avail = 1.0
        v[7] = 0.0 # I_missing = 0.0
        
        # 1. maCount (Count >= 0, normalized with log1p)
        if 'maCount' in lesion_features and lesion_features['maCount'] is not None:
            val = float(lesion_features['maCount'])
            val = max(0.0, val)
            v[0] = np.log1p(val)
            
        # 2. hemorrhageArea (Ratio in [0, 1])
        if 'hemorrhageArea' in lesion_features and lesion_features['hemorrhageArea'] is not None:
            val = float(lesion_features['hemorrhageArea'])
            v[1] = min(1.0, max(0.0, val))
            
        # 3. exudateArea (Ratio in [0, 1])
        if 'exudateArea' in lesion_features and lesion_features['exudateArea'] is not None:
            val = float(lesion_features['exudateArea'])
            v[2] = min(1.0, max(0.0, val))
            
        # 4. vesselDensity (Ratio in [0, 1])
        if 'vesselDensity' in lesion_features and lesion_features['vesselDensity'] is not None:
            val = float(lesion_features['vesselDensity'])
            v[3] = min(1.0, max(0.0, val))
            
        # 5. nvScore (Ratio in [0, 1])
        if 'nvScore' in lesion_features and lesion_features['nvScore'] is not None:
            val = float(lesion_features['nvScore'])
            v[4] = min(1.0, max(0.0, val))
            
        # 6. opticDiscDistance (Ratio in [0, 1])
        if 'opticDiscDistance' in lesion_features and lesion_features['opticDiscDistance'] is not None:
            val = float(lesion_features['opticDiscDistance'])
            v[5] = min(1.0, max(0.0, val))
            
    return v

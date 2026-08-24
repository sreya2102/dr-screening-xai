function config = default_iqa_config()
% DEFAULT_IQA_CONFIG Returns default parameters and thresholds for IQA.
%
% RATIONALE & THRESHOLD SELECTION:
% 1. Sharpness (Laplacian Variance / Tenengrad):
%    - Retinal fundus images require clear vessel boundaries and optic disc edges.
%    - Laplacian variance < 15.0 indicates severe defocus blur (REJECT).
%    - Laplacian variance between 15.0 and 45.0 indicates mild blur (BORDERLINE).
%    - Laplacian variance >= 45.0 indicates crisp focus (GOOD).
%
% 2. Contrast (RMS Contrast inside FOV ROI):
%    - RMS contrast measures grayscale standard deviation inside the fundus area.
%    - RMS contrast < 12.0 means lesions/vessels cannot be distinguished (REJECT).
%    - RMS contrast between 12.0 and 25.0 represents low contrast (BORDERLINE).
%    - RMS contrast >= 25.0 provides adequate dynamic range (GOOD).
%
% 3. Brightness / Exposure (Mean intensity inside FOV ROI):
%    - Fundus images should not be underexposed (too dark) or overexposed (glare).
%    - Mean ROI brightness < 30.0 indicates severe underexposure (REJECT).
%    - Mean ROI brightness > 220.0 indicates severe overexposure/glare (REJECT).
%    - Mean ROI brightness between [30, 50] or [190, 220] is sub-optimal (BORDERLINE).
%    - Mean ROI brightness between [50, 190] is optimal exposure (GOOD).
%
% 4. FOV Coverage Ratio (Retinal area / total image area):
%    - FOV coverage ratio < 0.15 indicates an empty/corrupt image or missed eye (REJECT).
%    - FOV coverage ratio between 0.15 and 0.30 indicates clipping/partial view (BORDERLINE).
%    - FOV coverage ratio >= 0.30 represents standard circular fundus framing (GOOD).
%
% 5. Illumination Uniformity (Quadrant intensity standard deviation):
%    - Measures variance of mean intensities across 4 fundus quadrants.
%    - Uniformity std > 40.0 indicates severe vignetting or directional shadow (BORDERLINE/REJECT).

    config = struct();
    
    % Sharpness Thresholds (Laplacian Variance)
    config.sharpness_reject_thresh     = 15.0;  % Below this -> Reject (Severe Blur)
    config.sharpness_good_thresh       = 45.0;  % Above this -> Good focus
    
    % Contrast Thresholds (RMS Contrast inside FOV)
    config.contrast_reject_thresh      = 12.0;  % Below this -> Reject (No contrast)
    config.contrast_good_thresh        = 25.0;  % Above this -> Good contrast
    
    % Brightness / Exposure Bounds (Mean ROI Intensity 0-255)
    config.brightness_min_reject       = 30.0;  % Below this -> Reject (Underexposed)
    config.brightness_min_good         = 50.0;  % Below this -> Borderline underexposed
    config.brightness_max_good         = 190.0; % Above this -> Borderline overexposed
    config.brightness_max_reject       = 220.0; % Above this -> Reject (Overexposed/Glare)
    
    % Field of View (FOV) Coverage Ratio
    config.fov_ratio_reject_thresh     = 0.15;  % Below this -> Reject (Invalid fundus mask)
    config.fov_ratio_good_thresh       = 0.30;  % Above this -> Normal fundus framing
    
    % Illumination Uniformity (Quadrant Intensity Variance)
    config.uniformity_max_borderline   = 35.0;  % Above this -> Warning / Borderline
    config.uniformity_max_reject       = 50.0;  % Above this -> Reject (Severe uneven lighting)

    % Scoring Weights for Composite Score (Sum to 1.0)
    config.weight_sharpness  = 0.35;
    config.weight_contrast   = 0.30;
    config.weight_brightness = 0.20;
    config.weight_fov        = 0.15;
end

# Module 1 – Image Quality Assessment (IQA)

## Overview
Module 1 performs automated Image Quality Assessment (IQA) on raw retinal fundus photographs before passing them to downstream image enhancement, vessel segmentation, DR grading, and explainability modules.

The primary function of Module 1 is to classify incoming images into three diagnostic tiers:
- **`Good`**: Image exceeds optimal quality standards (sharp focus, clear contrast, correct framing and exposure). Proceeds directly to downstream processing.
- **`Borderline`**: Image exhibits minor quality flaws (slight blur, sub-optimal exposure, or mild illumination gradient). Flagged and passed to **Module 2 (Image Enhancement)** for targeted correction.
- **`Reject`**: Image is unviable for clinical diagnosis (severe defocus blur, extreme under/overexposure, zero or missing field of view). Rejected early with descriptive warning codes.

---

## File Structure (`module1_iqa/`)

| File | Description |
| :--- | :--- |
| [`assess_image_quality.m`](file:///d:/dr-screening-xai/module1_iqa/assess_image_quality.m) | Main entry-point function for Module 1. Evaluates image and returns structured quality result. |
| [`compute_iqa_metrics.m`](file:///d:/dr-screening-xai/module1_iqa/compute_iqa_metrics.m) | Computes sharpness, RMS contrast, mean brightness, FOV coverage, and illumination uniformity. |
| [`extract_fov_mask.m`](file:///d:/dr-screening-xai/module1_iqa/extract_fov_mask.m) | Extracts binary mask isolating the circular fundus Field of View (FOV) ROI. |
| [`default_iqa_config.m`](file:///d:/dr-screening-xai/module1_iqa/default_iqa_config.m) | Defines configurable quality threshold parameters and documents their technical/clinical rationale. |
| [`test_module1_iqa.m`](file:///d:/dr-screening-xai/module1_iqa/test_module1_iqa.m) | MATLAB unit test suite verifying `Good`, `Borderline`, and `Reject` test cases. |

---

## Usage Example (MATLAB)

```matlab
% 1. Load an image or pass image file path
imgPath = 'data/sample_fundus.jpg';

% 2. Evaluate quality using default thresholds
[qualityResult, fovMask] = assess_image_quality(imgPath);

% 3. Inspect results
fprintf('Quality Grade : %s\n', qualityResult.status);
fprintf('Quality Score : %.2f\n', qualityResult.quality_score);
fprintf('Is Acceptable : %d\n', qualityResult.is_acceptable);

if ~qualityResult.is_acceptable
    fprintf('Rejection Reason: %s\n', qualityResult.rejection_reason{1});
end
```

### Custom Configuration Example
```matlab
% Customize thresholds if stricter criteria are required
config = default_iqa_config();
config.sharpness_reject_thresh = 25.0; % Increase blur rejection sensitivity

[qualityResult, fovMask] = assess_image_quality(imgPath, config);
```

---

## Configurable Quality Metrics & Threshold Rationale

1. **Sharpness (Laplacian Variance inside FOV)**:
   - *Rationale*: Retinal microaneurysms and fine vessel branches require crisp edges.
   - *Thresholds*: `< 15.0` (Reject), `15.0 - 45.0` (Borderline), `>= 45.0` (Good).

2. **Contrast (RMS Luminance Contrast inside FOV)**:
   - *Rationale*: Measures grayscale standard deviation to ensure sufficient dynamic range between lesions and background.
   - *Thresholds*: `< 12.0` (Reject), `12.0 - 25.0` (Borderline), `>= 25.0` (Good).

3. **Exposure / Brightness (Mean ROI Intensity [0, 255])**:
   - *Rationale*: Avoids dark underexposed images or overexposed camera flash glare.
   - *Thresholds*: `< 30` or `> 220` (Reject), `30-50` or `190-220` (Borderline), `50-190` (Good).

4. **Field of View (FOV) Coverage Ratio**:
   - *Rationale*: Verifies that the circular fundus region is properly framed and present.
   - *Thresholds*: `< 0.15` (Reject), `0.15 - 0.30` (Borderline), `>= 0.30` (Good).

5. **Illumination Uniformity (Quadrant Standard Deviation)**:
   - *Rationale*: Detects strong directional lighting gradients or vignetting.
   - *Thresholds*: `> 50.0` (Reject), `35.0 - 50.0` (Borderline), `< 35.0` (Good).

---

## Verification & Testing
To run the automated MATLAB unit test suite:
```matlab
% In MATLAB command window or script:
test_module1_iqa();
```

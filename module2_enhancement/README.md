# Module 2 – Image Enhancement

**Diabetic Retinopathy Screening System (XAI)**
**Developer / Member:** Member 3
**Implementation Language:** MATLAB (`.m`)
**Git Branch:** `feature/enhancement`

---

## Overview

Module 2 accepts retinal fundus images (passed from Module 1: Image Quality Assessment) and executes a structure-preserving image enhancement pipeline. The module standardizes spatial illumination, isolates the retinal Field of View (ROI), applies contrast-limited adaptive histogram equalization (CLAHE), and performs a strict two-step structure enhancement sequence (**Denoising BEFORE Sharpening**) to accentuate fine vascular trees and early retinal lesions (microaneurysms, hemorrhages, exudates).

---

## Primary API Interface

```matlab
[enhanced_image, green_channel, metadata] = enhance_image(input_image, varargin)
```

### Inputs

| Parameter | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `input_image` | `uint8` / `double` array or `char` filepath | Yes | Input RGB/grayscale fundus image or valid file path string. |
| `RoiMinCoveragePct` | `double` | Optional (default: 10.0) | Minimum valid ROI coverage percentage before triggering fallback. |
| `RoiMaxCoveragePct` | `double` | Optional (default: 95.0) | Maximum valid ROI coverage percentage before triggering fallback. |
| `IllumSigma` | `double` | Optional (default: 30.0) | Gaussian filter radius for background illumination estimation. |
| `ClaheClipLimit` | `double` | Optional (default: 2.0) | Contrast clip limit for local histogram equalization. |
| `ClaheTileGrid` | `double[2]` | Optional (default: [8 8]) | Contextual tile grid dimensions for CLAHE. |
| `DenoiseKernelSize` | `double[2]` | Optional (default: [3 3]) | Window size for median filter denoising (Step A). |
| `SharpenAmount` | `double` | Optional (default: 0.5) | Unsharp masking strength for structure sharpening (Step B). |
| `SharpenRadius` | `double` | Optional (default: 1.0) | Unsharp mask radius. |
| `SharpenThreshold` | `double` | Optional (default: 0.05) | Noise threshold fraction for unsharp mask. |

### Outputs

1. **`enhanced_image`** (`uint8`, `H x W x 3`):
   - Illumination-corrected, contrast-enhanced RGB image.
   - Intended consumers: **Module 4 (DR Grading)** & **Module 5 (Explainability/XAI)**.
2. **`green_channel`** (`uint8`, `H x W`):
   - High-contrast, ROI-masked 1-channel grayscale image derived from the green spectrum.
   - Intended consumer: **Module 3 (Segmentation)** for vessel and lesion extraction.
3. **`metadata`** (`struct`):
   - Structured diagnostic details (`status`, `input_dimensions`, `output_dimensions`, `roi_coverage_pct`, `roi_fallback_used`, `execution_time_ms`, `techniques_applied`, `parameters`, `warnings`, `channel_info`).

---

## File Architecture

All files reside strictly inside `module2_enhancement/`:

- `enhance_image.m`: Main entry point orchestrator function.
- `create_roi_mask.m`: Retinal field / FOV mask extraction with centered circular fallback logic.
- `correct_illumination.m`: Background illumination estimation and spatial shading equalizer.
- `apply_clahe.m`: Mask-aware Contrast-Limited Adaptive Histogram Equalization.
- `enhance_structures.m`: Sequential Denoising (Step A) ➔ Sharpening (Step B) module.
- `test_module2.m`: Automated verification, benchmark, and MATLAB/Simulink compatibility runner.

---

## Execution Order Guarantee

The enhancement pipeline strictly enforces the following sequence:

1. Input Validation & RGB Normalization
2. Retinal ROI Masking & Fallback Check
3. Illumination Correction
4. Green Channel Isolation
5. CLAHE (Local Contrast Equalization)
6. **STEP A: Edge-Preserving Median Denoising** *(Suppresses sensor noise first)*
7. **STEP B: Controlled Unsharp Sharpening** *(Sharpens vessels and lesions safely second)*
8. RGB Reconstruction & Background Isolation
9. Metadata Compilation & Execution Timing

---

## MATLAB / Simulink Compatibility

All functions in Module 2 are built using C-accelerated MATLAB Image Processing Toolbox routines (`adapthisteq`, `medfilt2`, `imfilter`, `imbinarize`, `rgb2lab`, `imsharpen`, `imclose`, `imopen`) compatible with MATLAB Function Blocks for top-level system integration in Module 6 (`module6_simulink/`).

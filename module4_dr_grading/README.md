# Module 4 – Diabetic Retinopathy Severity Grading

This module implements a research-grade, multi-stream Diabetic Retinopathy (DR) severity grading pipeline using Consistent Rank Logits (CORAL) ordinal classification. It combines global visual representations from fundus images with clinical quantitative features from Module 3 segmentations, incorporating robust fallback paths for missing data, validation-set calibration, and automatic explainability hooks for Module 5.

---

## 1. Directory Structure

All source files are modularly structured within this folder:

```text
module4_dr_grading/
├── README.md                           % API Documentation & Setup Instructions
├── walkthrough.md                      % Detailed implementation walkthrough
├── trained_models/                     % Directory for checkpointing trained models (.mat)
│   └── dr_grading_model.mat            % Exported best model file
├── src/                                % Source Code
│   ├── generateDummyDataset.m          % Generates high-fidelity circular mock fundus data
│   ├── prepareDataset.m                % Groups data by patient ID and returns datastores
│   ├── buildModel.m                    % Builds ResNet-50 visual and clinical MLP model layers
│   ├── trainModel.m                    % Custom adamupdate training loop & validation ECE evaluation
│   ├── gradeDR.m                       % Primary inference grading API
│   ├── evaluateModel.m                 % Tests metrics (Accuracy, F1, MAE, QWK, ECE, Brier)
│   ├── calibrateModel.m                % Platt scaling and Temperature scaling optimizer
│   └── utils/
│       ├── coralLoss.m                 % Custom Consistent Rank Logits loss
│       ├── reconstructGrade.m          % Reconstructs grade & confidence from sigmoids
│       ├── preprocessImage.m           % Borders crop, pads to square, resizes to 224x224
│       ├── validateLesionFeatures.m    % Handles M3 missing data & indicators mapping
│       ├── extractActivations.m        % M5 activation hook
│       └── getGradCAMGradients.m       % M5 gradient hook
└── tests/                              % Test Suite
    ├── runTests.m                      % Master script to execute all unit tests
    ├── testDataset.m                   % Tests patient-level splits and preprocessing
    ├── testModel.m                     % Tests forward pass activations and layer connectivity
    ├── testOrdinalLoss.m               % Tests CORAL loss properties
    └── testInference.m                 % Tests prediction and M3 fallbacks on mock models
```

---

## 2. API Design

### A. Dataset Preparation
```matlab
[trainDS, valDS, testDS] = prepareDataset(dataFolder, targetSize, splitRatios, mode)
```
* **Inputs:**
  * `dataFolder`: Path to image root folder.
  * `targetSize`: Vector (default: `[224, 224]`).
  * `splitRatios`: Vector (default: `[0.7, 0.15, 0.15]`).
  * `mode`: `'cnn-only'`, `'lesion-only'`, or `'fusion'`.
* **Outputs:**
  * `trainDS, valDS, testDS`: Combined datastores returning `{img, target}` or `{img, lesionVec, target}`. Splits are partition-isolated by patient ID extracted from filenames to prevent leakage.

### B. Training Loop
```matlab
[net, info] = trainModel(trainDS, valDS, options)
```
* Hyperparameters (epochs, batch size, learning rate, and checkpoints saving path) are passed in `options`. The function executes a custom training loop, tracks training and validation loss, and saves the best model checkpoint to disk.

### C. Main Prediction API
```matlab
[result, activations] = gradeDR(image, modelPath, lesionFeatures, returnActivations)
```
* **Inputs:**
  * `image`: Raw RGB image matrix.
  * `modelPath`: Path to the saved `.mat` file (or loaded struct).
  * `lesionFeatures`: Module 3 features struct.
  * `returnActivations` (Optional): Logical flag requesting activation maps for Module 5.
* **Outputs:**
  * `result`: Struct with fields:
    * `result.grade`: Integer $\{0..4\}$.
    * `result.confidence`: Calibrated confidence probability.
    * `result.classProbabilities`: $1 \times 5$ array of calibrated probabilities.
    * `result.referableDR`: Logical flag indicating referable DR (Grade $\ge 2$).
    * `result.referableProbability`: $P(\text{Grade} \ge 2)$.
    * `result.referableThreshold`: Tuned validation threshold $\tau$.
    * `result.logits`: Raw logit scores from the CORAL head.
    * `result.modelVersion`: Version string (e.g., `'v1.0.0'`).
  * `activations` (Optional): Activation maps of the final convolutional layer.

---

## 3. Integration Contracts

### M3 ──→ M4 Lesion Contract
Module 3 must supply a struct containing quantitative metrics. M4 maps this to an 8-dimensional clinical representation incorporating availability indicator flags:
```matlab
% Interface Schema
lesionFeatures.maCount = 0;              % Double: raw Microaneurysm count (>= 0)
lesionFeatures.hemorrhageArea = 0.0;     % Double: ratio of hemorrhage area in [0, 1]
lesionFeatures.exudateArea = 0.0;        % Double: ratio of exudate area in [0, 1]
lesionFeatures.vesselDensity = 0.0;      % Double: ratio of vessel pixels in [0, 1]
lesionFeatures.nvScore = 0.0;            % Double: Neovascularization area ratio in [0, 1]
lesionFeatures.opticDiscDistance = 0.0;  % Double: distance of closest lesion to optic disc in [0, 1]
lesionFeatures.isAvailable = true;       % Logical: M3 success flag (true = valid, false = failure)
```
* **Robust Fallback:** If `isAvailable = false` (M3 module fails), the clinical projection is bypassed and the network isolates prediction onto the global CNN visual stream.

### M4 ──→ M5 Explainability Contract
To allow Module 5 to compute Grad-CAM evidence maps, M4 exposes:
1. **Target Activation Layer:** Final convolutional layer of the backbone (programmatically scanned, e.g., `'activation_49_relu'` for ResNet-50).
2. **Gradient Hooks:** `src/utils/getGradCAMGradients.m` computes derivatives of the selected class score with respect to convolutional activations using automatic differentiation:
   ```matlab
   gradients = getGradCAMGradients(net, dlImage, targetClassIndex, targetLayerName)
   ```

---

## 4. How to Execute Tests

Launch MATLAB and execute the master test runner from the repository root:
```matlab
% Run from MATLAB Command Window
addpath(fullfile(pwd, 'module4_dr_grading', 'tests'));
run('runTests.m');
```
This script will automatically generate a mock dataset under `data/dummy/`, verify datastores, inspect model layers, evaluate the CORAL loss function, test inference fallbacks, and print a final pass/fail summary.

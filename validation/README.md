# Validation and Testing Framework

## Overview
This directory contains the verification, clinical evaluation, and benchmarking suite for the **Diabetic Retinopathy Screening System**.

---

## 1. Metrics Computed (`compute_metrics.m`)
- **Multi-class Classification**:
  - Accuracy
  - Per-class & Macro Sensitivity (Recall), Specificity, Precision, F1-Score
  - Quadratic Weighted Kappa (QWK)
  - Cohen's Kappa
  - One-vs-Rest ROC-AUC
- **Referable DR Clinical Screening (Grade ≥ 2)**:
  - Clinical Sensitivity, Specificity, Accuracy, F1-Score
- **Robustness**:
  - Handles missing classes without `NaN` propagation.
  - Safe zero-denominator guards.
  - Auto-normalizes numeric, string, and categorical labels.

---

## 2. Benchmark & Report Generation
- [`benchmark_latency.m`](file:///c:/Users/Vishal%20Raj%20.N%20.D/dr-screening-xai/validation/benchmark_latency.m): Profiles execution time across every module (IQA, Enhancement, Segmentation, Grading, XAI) and measures throughput (FPS).
- [`generate_validation_report.m`](file:///c:/Users/Vishal%20Raj%20.N%20.D/dr-screening-xai/validation/generate_validation_report.m): Exports summary `.json` and markdown `.md` reports in `validation/reports/`.
- [`mock_pipeline_stubs.m`](file:///c:/Users/Vishal%20Raj%20.N%20.D/dr-screening-xai/validation/mock_pipeline_stubs.m): Provides fallback implementations and deterministic test overrides for Modules 1–5.
- [`test_member6_suite.m`](file:///c:/Users/Vishal%20Raj%20.N%20.D/dr-screening-xai/validation/test_member6_suite.m): 17 automated tests verifying decision logic, metrics, stubs, latency, and report generation.

---

## 3. Integration Interface Contract for Teammates (Modules 1–5)
When teammates merge their implementations, [`simulink_pipeline_adapter.m`](file:///c:/Users/Vishal%20Raj%20.N%20.D/dr-screening-xai/module6_simulink/simulink_pipeline_adapter.m) seamlessly connects to their functions:
- **Module 1 (IQA)**: `iqa_res = iqa_evaluate(img)` → expects `.status` (`'Good'|'Borderline'|'Reject'`), `.quality_score`, `.rejection_reason`.
- **Module 2 (Enhancement)**: `enh_res = enhance_fundus_image(img)` → expects `.enhanced_img`, `.green_channel`.
- **Module 3 (Segmentation)**: `seg_res = segment_retinal_features(enh_res)` → expects `.vessel_mask`, `.optic_disc_mask`, `.lesion_density`.
- **Module 4 (DR Grading)**: `grade_res = classify_dr_grade(enh_res, seg_res)` → expects `.dr_grade` (0 to 4), `.confidence_scores` (1x5 vector), `.risk_score`.
- **Module 5 (Explainability)**: `xai_res = explain_prediction(enh_res, grade_res)` → expects `.cam_heatmap`, `.overlay_img`, `.explanation_summary`.

---

## 4. Running the Test Suite
In MATLAB:
```matlab
% Add paths
addpath(genpath('.'));

% Run automated test suite
results = test_member6_suite();

% Run full validation evaluation
[metrics, benchmark_data] = run_full_validation();
```

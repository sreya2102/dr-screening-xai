# Module 5 – Explainability & Report Generation

## Overview
Module 5 provides **Explainable AI (XAI) visual explanations** and **automated clinical screening report generation** for the Diabetic Retinopathy (DR) Screening System.

---

## Directory Structure & Component Manifest

All files for Module 5 are contained strictly inside `module5_explainability/`:

```
module5_explainability/
├── README.md                     # Module documentation & API reference
│
├── demoviewer/                   # Separate Python engine directory (No MATLAB required)
│   ├── create_mock_screening_data.py  # Synthetic input generator
│   ├── generate_gradcam.py            # Grad-CAM & saliency heatmap generator
│   ├── generate_xai_maps.py           # Multi-modal visual XAI maps generator
│   ├── compute_lesion_importance.py   # Lesion weighting calculator
│   ├── generate_clinical_text.py      # Clinical text & recommendation synthesizer
│   ├── export_html_report.py          # Responsive HTML clinical report exporter
│   ├── generate_report.py             # Master entry point (Python)
│   ├── demo_module5.py                # Standalone demo script (Python)
│   └── tests/
│       └── test_module5.py            # Python unit test suite
│
└── MATLAB Implementation:
    ├── create_mock_screening_data.m   # Synthetic input generator (MATLAB)
    ├── generate_gradcam.m             # Grad-CAM & saliency overlay map generator
    ├── generate_xai_maps.m            # Multi-modal XAI visualization engine
    ├── compute_lesion_importance.m    # Lesion weighting calculator
    ├── generate_clinical_text.m       # Clinical text synthesizer
    ├── build_summary_figure.m         # 2x3 multi-panel diagnostic canvas builder
    ├── export_html_report.m           # HTML clinical report exporter
    ├── generate_report.m              # Primary entry point function (MATLAB)
    ├── demo_module5.m                 # Standalone demo script (MATLAB)
    └── tests/
        └── test_module5.m             # MATLAB unit test suite
```

---

## Running DemoViewer (Python - No MATLAB Required)

### 1. Run Demo Script
```bash
python module5_explainability/demoviewer/demo_module5.py
```

### 2. Run Unit Test Suite
```bash
python -m unittest module5_explainability/demoviewer/tests/test_module5.py
```

---

## Running MATLAB Engine

### 1. Run Demo Script
```matlab
run('module5_explainability/demo_module5.m')
```

### 2. Run Unit Test Suite
```matlab
runtests('module5_explainability/tests/test_module5.m')
```

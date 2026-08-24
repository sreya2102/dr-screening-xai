# Module 6: Simulink Simulation & Discrete-Event Queueing Automation

## Overview
Module 6 implements the **Simulink Simulation System, Clinical Triage Automation, and Discrete-Event Queueing Model** for the Diabetic Retinopathy Screening System.

---

## 1. Pipeline Simulation Architecture
The sequential screening pipeline models the clinical workflow:
```text
Raw Image
   ↓
[Module 1: IQA Gate] ───(Reject: Blur / Illumination)──► [Image Retake Required (Early Exit)]
   ↓ (Good / Borderline)
[Module 2: Enhancement]
   ↓
[Module 3: Segmentation / Lesion Features]
   ↓
[Module 4: DR Grading (0 to 4)]
   ↓
[Module 5: Explainability (Grad-CAM / Overlay)]
   ↓
[Module 6: Clinical Decision Logic] ──► [Triage & Referral Urgency]
```

### Clinical Decision Rules (`dr_decision_logic.m`)
- **IQA Reject**: `Image Retake Required` (Action 0). Early exit prevents wasted downstream compute.
- **Good + Grade 0 (Normal)**: `Routine Follow-up` (12 months).
- **Good + Grade 1 (Mild NPDR)**: `Semi-Annual Review` (6 months).
- **Good + Grade 2 (Moderate NPDR)**: `Prompt Ophthalmology Referral` (within 1 month).
- **Good + Grade 3 (Severe NPDR)**: `Urgent Specialist Referral` (within 2 weeks).
- **Good + Grade 4 (PDR)**: `Urgent Specialist Referral` (within 1 week).
- **Borderline IQA**: Continues grading but attaches a cautionary clinical note.

---

## 2. Discrete-Event & Queueing Simulation (`screening_queue_simulation.m`)
Models real-world screening center operations:
```text
Patient/Image Arrival (Poisson Process)
        ↓
Screening Center Upload Queue (Bandwidth: e.g. 20 Mbps, 15 MB/case)
        ↓
AI Inference Server Queue (Latency: ~250 ms)
        ↓
AI Diagnosis & IQA Gating
        ├── Non-Referable / Normal (70%) ──► Routine Follow-up
        ├── IQA Reject (8%) ──► Immediate Retake Alert
        └── Referable DR (Grade >= 2, 22%)
                 ↓
      Ophthalmologist Review Queue
                 ↓
      Human Review Server (Review Time: ~3 min/case)
                 ↓
      Final Specialist Referral & Care Plan
```

### Configurable Parameters
- `num_screening_centers`: Number of satellite clinics connected.
- `patients_per_day_per_center`: Daily patient intake per clinic.
- `image_size_mb` & `upload_bandwidth_mbps`: Network constraints.
- `ai_inference_ms`: AI server latency.
- `human_review_min` & `num_ophthalmologists`: Clinician staffing.
- `sim_duration_days`: Simulation horizon (e.g. 5-day work week).

---

## 3. File Inventory
- [`create_simulink_model.m`](file:///c:/Users/Vishal%20Raj%20.N%20.D/dr-screening-xai/module6_simulink/create_simulink_model.m): Programmatic generator for Simulink `.slx` and architectural descriptor.
- [`dr_decision_logic.m`](file:///c:/Users/Vishal%20Raj%20.N%20.D/dr-screening-xai/module6_simulink/dr_decision_logic.m): Clinical triage decision engine.
- [`simulink_pipeline_adapter.m`](file:///c:/Users/Vishal%20Raj%20.N%20.D/dr-screening-xai/module6_simulink/simulink_pipeline_adapter.m): Gateway adapter connecting Modules 1–5 with early-exit gating.
- [`run_simulink_simulation.m`](file:///c:/Users/Vishal%20Raj%20.N%20.D/dr-screening-xai/module6_simulink/run_simulink_simulation.m): Discrete simulation execution harness.
- [`screening_queue_simulation.m`](file:///c:/Users/Vishal%20Raj%20.N%20.D/dr-screening-xai/module6_simulink/screening_queue_simulation.m): Discrete-event throughput, queueing, and reviewer capacity simulation.

---

## 4. How to Run
In MATLAB:
```matlab
% Add project paths
addpath(genpath('.'));

% 1. Run pipeline simulation
results = run_simulink_simulation();

% 2. Run queueing throughput simulation (e.g., 5 centers, 200 patients/day)
queue_stats = screening_queue_simulation();
```

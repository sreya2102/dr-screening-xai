% DEMO_MODULE5 Executable demonstration script for Module 5.
%
% This script generates mock screening data, runs Module 5 XAI explanation
% and clinical report generation, and saves output reports to disk.

clc; clear; close all;

fprintf('=======================================================\n');
fprintf('  Module 5: Explainability & Report Generation Demo\n');
fprintf('=======================================================\n\n');

% 1. Create Synthetic Input Data (Grade 2 - Moderate NPDR)
fprintf('[Step 1] Creating synthetic screening data (Grade 2 Moderate NPDR)...\n');
screening_data = create_mock_screening_data(2, 'Good');

% 2. Run Module 5 Report Generation
fprintf('[Step 2] Running Module 5 XAI maps & report generation...\n');
output_dir = fullfile(fileparts(mfilename('fullpath')), 'output_demo_reports');
report_data = generate_report(screening_data, output_dir);

% 3. Display Results Summary
fprintf('\n-------------------------------------------------------\n');
fprintf('  REPORT GENERATION COMPLETE\n');
fprintf('-------------------------------------------------------\n');
fprintf('Patient ID           : %s\n', report_data.patient_id);
fprintf('Patient Name         : %s\n', report_data.patient_name);
fprintf('IQA Status           : %s\n', report_data.iqa_status);
fprintf('Predicted DR Grade   : %s\n', report_data.dr_grade);
fprintf('Confidence           : %.2f%%\n', report_data.confidence * 100);
fprintf('\nClinical Summary     :\n  %s\n', report_data.clinical_text.diagnostic_summary);
fprintf('\nXAI Explanation      :\n  %s\n', report_data.clinical_text.xai_explanation);
fprintf('\nRecommendations      :\n  %s\n', report_data.clinical_text.recommendations);

fprintf('\n-------------------------------------------------------\n');
fprintf('  GENERATED REPORT FILES\n');
fprintf('-------------------------------------------------------\n');
fprintf('1. HTML Clinical Report : %s\n', report_data.report_files.html_path);
fprintf('2. PNG Summary Canvas   : %s\n', report_data.report_files.summary_png_path);
fprintf('3. MAT Data File        : %s\n', report_data.report_files.mat_path);
fprintf('=======================================================\n');

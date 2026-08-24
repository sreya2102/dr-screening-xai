% DEMO_MODULE5 Interactive 3-step workflow demonstration for Module 5.
%
% Runs Module 5 XAI explanation and report generation and opens the
% interactive 3-step web application.

clc; clear; close all;

fprintf('=======================================================\n');
fprintf('  Module 5: 3-Step Interactive XAI Screening Workflow\n');
fprintf('=======================================================\n\n');

% 1. Create Dynamic Screening Input
fprintf('[Step 1] Initializing screening inputs...\n');
screening_data = create_mock_screening_data(2, 'Good');

% 2. Run Module 5 Report Generation Engine
fprintf('[Step 2] Running XAI visual maps & report generator...\n');
module_dir = fileparts(mfilename('fullpath'));
output_dir = fullfile(module_dir, 'output_demo_reports');
report_data = generate_report(screening_data, output_dir);

% 3. Open Interactive Web Application
index_html = fullfile(module_dir, 'demoviewer', 'index.html');
fprintf('[Step 3] Opening interactive 3-step application in browser:\n');
fprintf('         %s\n\n', index_html);

web(index_html, '-browser');

fprintf('=======================================================\n');
fprintf('  3-Step Workflow Loaded:\n');
fprintf('    1. Screening Input  -> Enter Patient Data & Upload Fundus Image\n');
fprintf('    2. XAI Analysis     -> View Grad-CAM, Saliency & Lesion Overlays\n');
fprintf('    3. Clinical Report  -> Light-Theme SIH Report with Download PDF\n');
fprintf('=======================================================\n');

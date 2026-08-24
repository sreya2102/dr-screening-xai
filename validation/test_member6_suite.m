function results = test_member6_suite()
% TEST_MEMBER6_SUITE Comprehensive test suite for Member 6 deliverables.
%
% Tests:
%   1. Decision Logic - Case 1: IQA Reject -> Image Retake Required
%   2. Decision Logic - Case 2: Good + Grade 0 -> Routine Follow-up
%   3. Decision Logic - Case 3: Good + Grade 1 -> Semi-Annual Review
%   4. Decision Logic - Case 4: Good + Grade 2 -> Prompt Ophthalmology Referral
%   5. Decision Logic - Case 5: Good + Grade 3 -> Urgent Specialist Referral
%   6. Decision Logic - Case 6: Good + Grade 4 -> Urgent Specialist Referral
%   7. Decision Logic - Borderline IQA flagging
%   8. Metrics - Standard 5x5 confusion matrix, QWK, Cohen Kappa, Referable DR Sens/Spec
%   9. Metrics - Missing classes & edge cases (zero denominator handling)
%  10. Metrics - Multiclass ROC-AUC computation
%  11. Mock Pipeline Stubs - Modules 1-5 standalone response
%  12. Simulink Pipeline Adapter - Early exit on IQA reject
%  13. Simulink Pipeline Adapter - Correct signal routing across all grades
%  14. Discrete-Event Queueing Simulation - Screening throughput, queue delays, and reviewer workload
%  15. Latency Benchmarking - Module timings and throughput calculation
%  16. Validation Report Generator - File generation (.json and .md)
%  17. Simulink Model Generator - Structure descriptor generation
%
% Usage:
%   results = test_member6_suite();

    fprintf('=================================================================\n');
    fprintf('           MEMBER 6 INTEGRATION & VERIFICATION TEST SUITE        \n');
    fprintf('=================================================================\n\n');

    tests_run = 0;
    tests_passed = 0;
    results = struct();

    % --- TEST 1: Decision Logic - IQA Reject ---
    tests_run = tests_run + 1;
    [code, txt, prio, urg] = dr_decision_logic('Reject', 3, 0.90, 0.80);
    pass1 = (code == 0) && strcmp(urg, 'Image Retake Required');
    report_test('Decision Logic (IQA Reject -> Retake)', 'Image Retake Required', urg, pass1);
    if pass1, tests_passed = tests_passed + 1; end

    % --- TEST 2: Decision Logic - Grade 0 (No DR) ---
    tests_run = tests_run + 1;
    [code, txt, prio, urg] = dr_decision_logic('Good', 0, 0.95, 0.05);
    pass2 = (code == 1) && strcmp(urg, 'Routine Follow-up');
    report_test('Decision Logic (Good + Grade 0 -> Routine)', 'Routine Follow-up', urg, pass2);
    if pass2, tests_passed = tests_passed + 1; end

    % --- TEST 3: Decision Logic - Grade 1 (Mild NPDR) ---
    tests_run = tests_run + 1;
    [code, txt, prio, urg] = dr_decision_logic('Good', 1, 0.85, 0.25);
    pass3 = (code == 2) && strcmp(urg, 'Semi-Annual Review');
    report_test('Decision Logic (Good + Grade 1 -> Semi-Annual)', 'Semi-Annual Review', urg, pass3);
    if pass3, tests_passed = tests_passed + 1; end

    % --- TEST 4: Decision Logic - Grade 2 (Moderate NPDR) ---
    tests_run = tests_run + 1;
    [code, txt, prio, urg] = dr_decision_logic('Good', 2, 0.80, 0.50);
    pass4 = (code == 3) && strcmp(urg, 'Prompt Ophthalmology Referral');
    report_test('Decision Logic (Good + Grade 2 -> Prompt Referral)', 'Prompt Ophthalmology Referral', urg, pass4);
    if pass4, tests_passed = tests_passed + 1; end

    % --- TEST 5: Decision Logic - Grade 3 (Severe NPDR) ---
    tests_run = tests_run + 1;
    [code, txt, prio, urg] = dr_decision_logic('Good', 3, 0.88, 0.75);
    pass5 = (code == 4) && strcmp(urg, 'Urgent Specialist Referral');
    report_test('Decision Logic (Good + Grade 3 -> Urgent Referral)', 'Urgent Specialist Referral', urg, pass5);
    if pass5, tests_passed = tests_passed + 1; end

    % --- TEST 6: Decision Logic - Grade 4 (PDR) ---
    tests_run = tests_run + 1;
    [code, txt, prio, urg] = dr_decision_logic('Good', 4, 0.92, 0.95);
    pass6 = (code == 4) && strcmp(urg, 'Urgent Specialist Referral');
    report_test('Decision Logic (Good + Grade 4 -> Urgent Referral)', 'Urgent Specialist Referral', urg, pass6);
    if pass6, tests_passed = tests_passed + 1; end

    % --- TEST 7: Decision Logic - Borderline IQA ---
    tests_run = tests_run + 1;
    [code, txt, prio, urg] = dr_decision_logic('Borderline', 1, 0.60, 0.25);
    pass7 = contains(txt, 'Borderline image quality');
    report_test('Decision Logic (Borderline IQA Note Added)', 'Contains Borderline note', txt(1:min(end, 35)), pass7);
    if pass7, tests_passed = tests_passed + 1; end

    % --- TEST 8: Compute Metrics on Deterministic Ground Truth ---
    tests_run = tests_run + 1;
    y_true = [0; 0; 1; 1; 2; 2; 3; 3; 4; 4];
    y_pred = [0; 0; 1; 2; 2; 2; 3; 4; 4; 4];
    m = compute_metrics(y_true, y_pred);
    % Accuracy: 8/10 = 0.80
    % Referable (>=2): True=[2,2,3,3,4,4] (6), Pred=[2,2,2,3,4,4,4] (7, 1 FP from true 1, 6 TP)
    % Referable Sens = 6/6 = 1.0, Spec = 3/4 = 0.75
    pass8 = (abs(m.accuracy - 0.80) < 1e-4) && ...
            (abs(m.referable_dr.sensitivity - 1.0) < 1e-4) && ...
            (abs(m.referable_dr.specificity - 0.75) < 1e-4) && ...
            (m.quadratic_weighted_kappa > 0.85);
    report_test('Compute Metrics (Deterministic Cohort)', 'Acc=0.80, RefSens=1.00, RefSpec=0.75', ...
        sprintf('Acc=%.2f, RefSens=%.2f, RefSpec=%.2f', m.accuracy, m.referable_dr.sensitivity, m.referable_dr.specificity), pass8);
    if pass8, tests_passed = tests_passed + 1; end

    % --- TEST 9: Compute Metrics (Missing Classes & Empty/Zero Denominators) ---
    tests_run = tests_run + 1;
    y_true_sparse = [0; 0; 0];
    y_pred_sparse = [0; 0; 0];
    m_sparse = compute_metrics(y_true_sparse, y_pred_sparse);
    pass9 = ~isnan(m_sparse.macro_f1_score) && ~isnan(m_sparse.referable_dr.sensitivity) && (m_sparse.accuracy == 1.0);
    report_test('Compute Metrics (Missing Classes Edge Case)', 'No NaNs, Acc=1.0', ...
        sprintf('Acc=%.2f, MacroF1=%.2f', m_sparse.accuracy, m_sparse.macro_f1_score), pass9);
    if pass9, tests_passed = tests_passed + 1; end

    % --- TEST 10: Multiclass ROC-AUC Calculation ---
    tests_run = tests_run + 1;
    y_true_auc = [0; 1; 2; 3; 4];
    y_probs_auc = eye(5); % Perfect diagonal
    m_auc = compute_metrics(y_true_auc, y_true_auc, y_probs_auc);
    pass10 = (abs(m_auc.macro_auc_roc - 1.0) < 1e-4);
    report_test('Compute Metrics (Multiclass ROC-AUC)', 'Macro AUC=1.00', sprintf('Macro AUC=%.2f', m_auc.macro_auc_roc), pass10);
    if pass10, tests_passed = tests_passed + 1; end

    % --- TEST 11: Mock Pipeline Stubs across all 5 Modules ---
    tests_run = tests_run + 1;
    m1 = mock_pipeline_stubs('iqa');
    m2 = mock_pipeline_stubs('enhancement');
    m3 = mock_pipeline_stubs('segmentation');
    m4 = mock_pipeline_stubs('dr_grading');
    m5 = mock_pipeline_stubs('explainability');
    pass11 = isfield(m1, 'status') && isfield(m2, 'enhanced_img') && ...
             isfield(m3, 'vessel_mask') && isfield(m4, 'dr_grade') && isfield(m5, 'cam_heatmap');
    report_test('Mock Pipeline Stubs (Modules 1-5)', 'All structs present and valid', 'Valid', pass11);
    if pass11, tests_passed = tests_passed + 1; end

    % --- TEST 12: Simulink Adapter Early Exit on IQA Reject ---
    tests_run = tests_run + 1;
    dark_img = uint8(5 * ones(224, 224, 3)); % Dark image -> Trigger Reject
    [iqa_g, dr_g, max_c, risk_s, triage_a] = simulink_pipeline_adapter(dark_img);
    pass12 = (iqa_g == 0) && (triage_a == 0) && (dr_g == 0);
    report_test('Simulink Adapter (Early Exit on Reject)', 'iqa_g=0, triage_a=0 (Retake)', ...
        sprintf('iqa_g=%d, triage_a=%d', iqa_g, triage_a), pass12);
    if pass12, tests_passed = tests_passed + 1; end

    % --- TEST 13: Simulink Adapter Processing on Normal Image ---
    tests_run = tests_run + 1;
    norm_img = uint8(120 * ones(224, 224, 3));
    [iqa_g2, dr_g2, max_c2, risk_s2, triage_a2] = simulink_pipeline_adapter(norm_img);
    pass13 = (iqa_g2 == 2) && (triage_a2 == 1 || triage_a2 == 2);
    report_test('Simulink Adapter (Good Image Flow)', 'iqa_g=2, valid triage_a', ...
        sprintf('iqa_g=%d, triage_a=%d', iqa_g2, triage_a2), pass13);
    if pass13, tests_passed = tests_passed + 1; end

    % --- TEST 14: Discrete-Event Queueing Simulation ---
    tests_run = tests_run + 1;
    q_params.num_screening_centers = 3;
    q_params.patients_per_day_per_center = 20;
    q_params.sim_duration_days = 2;
    q_results = screening_queue_simulation(q_params);
    pass14 = (q_results.total_patients_processed > 0) && ...
             (q_results.ai_server_utilization_pct > 0) && ...
             (q_results.recommended_reviewers_needed >= 1);
    report_test('Discrete-Event Queueing Simulation', 'Patients processed > 0, Valid utilization', ...
        sprintf('Processed=%d, AI_Util=%.1f%%, Reviewers=%d', ...
        q_results.total_patients_processed, q_results.ai_server_utilization_pct, q_results.recommended_reviewers_needed), pass14);
    if pass14, tests_passed = tests_passed + 1; end

    % --- TEST 15: Latency Benchmark Profiler ---
    tests_run = tests_run + 1;
    bench = benchmark_latency(5);
    pass15 = (bench.total_mean_ms > 0) && (bench.fps > 0);
    report_test('Latency Benchmark Profiler', 'Total latency > 0 ms, FPS > 0', ...
        sprintf('Latency=%.2f ms, FPS=%.1f', bench.total_mean_ms, bench.fps), pass15);
    if pass15, tests_passed = tests_passed + 1; end

    % --- TEST 16: Validation Report Generator ---
    tests_run = tests_run + 1;
    test_rep_dir = fullfile(pwd, 'validation', 'reports');
    generate_validation_report(m, bench, test_rep_dir);
    rep_json = fullfile(test_rep_dir, 'validation_summary.json');
    rep_md = fullfile(test_rep_dir, 'validation_report.md');
    pass16 = (exist(rep_json, 'file') == 2) && (exist(rep_md, 'file') == 2);
    report_test('Validation Report Generator', 'Generated .json & .md reports', 'Created successfully', pass16);
    if pass16, tests_passed = tests_passed + 1; end

    % --- TEST 17: Simulink Model Builder & Structure Descriptor ---
    tests_run = tests_run + 1;
    mdl_name = create_simulink_model('dr_screening_pipeline');
    desc_path = fullfile(pwd, 'module6_simulink', 'dr_screening_pipeline_structure.json');
    pass17 = ~isempty(mdl_name) || (exist(desc_path, 'file') == 2);
    report_test('Simulink Model Generator', 'Model / Architecture Descriptor created', mdl_name, pass17);
    if pass17, tests_passed = tests_passed + 1; end

    % Summary
    fprintf('\n=================================================================\n');
    fprintf('  TEST SUMMARY: %d / %d Tests Passed (%.1f%%)\n', ...
        tests_passed, tests_run, (tests_passed / tests_run) * 100);
    if tests_passed == tests_run
        fprintf('  STATUS: ALL TESTS PASSED (MEMBER 6 INTEGRATION READY)\n');
    else
        fprintf('  STATUS: SOME TESTS FAILED\n');
    end
    fprintf('=================================================================\n');

    results.tests_run = tests_run;
    results.tests_passed = tests_passed;
    results.all_passed = (tests_passed == tests_run);
end

function report_test(name, expected, actual, is_pass)
    if is_pass
        st = 'PASS';
    else
        st = 'FAIL';
    end
    fprintf('Test    : %s\n', name);
    fprintf('Expected: %s\n', expected);
    fprintf('Actual  : %s\n', actual);
    fprintf('Status  : [%s]\n\n', st);
end

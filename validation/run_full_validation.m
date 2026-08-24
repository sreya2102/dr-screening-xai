function [metrics, benchmark_data] = run_full_validation(test_images, true_labels)
% RUN_FULL_VALIDATION Executes comprehensive end-to-end testing and validation.
%
% Usage:
%   [metrics, benchmark_data] = run_full_validation()
%   [metrics, benchmark_data] = run_full_validation(image_paths, labels)

    if nargin < 1 || isempty(test_images) || nargin < 2 || isempty(true_labels)
        % Generate synthetic evaluation cohort covering all 5 DR grades + IQA rejects
        fprintf('Generating comprehensive evaluation test cohort (100 cases)...\n');
        rng(42); % Reproducible seed
        num_samples = 100;
        true_labels = randi([0, 4], num_samples, 1);
        test_images = cell(num_samples, 1);
        
        for k = 1:num_samples
            g = true_labels(k);
            % Generate synthetic fundus image matrix with varying intensities
            base_intensity = uint8(60 + g * 30 + randi([-15, 15]));
            img = repmat(base_intensity, [224, 224, 3]);
            test_images{k} = img;
        end
    end

    num_samples = length(test_images);
    pred_labels = zeros(num_samples, 1);
    pred_probs  = zeros(num_samples, 5);

    fprintf('Executing screening pipeline across %d validation samples...\n', num_samples);

    for i = 1:num_samples
        img = test_images{i};
        
        % Run Simulink Adapter Pipeline
        [iqa_gate, dr_grade, max_conf, risk_score, ~] = simulink_pipeline_adapter(img);

        if iqa_gate == 0
            % If rejected by IQA, mark as uncertain/unclassified
            pred_labels(i) = 0;
            pred_probs(i, :) = [0.2, 0.2, 0.2, 0.2, 0.2];
        else
            pred_labels(i) = round(dr_grade);
            
            % Generate smooth probability vector centered on predicted grade
            probs = 0.05 * ones(1, 5);
            probs(pred_labels(i) + 1) = max_conf;
            rem = (1.0 - max_conf) / 4.0;
            probs(probs == 0.05) = rem;
            pred_probs(i, :) = probs / sum(probs);
        end
    end

    % 1. Compute Clinical Metrics
    fprintf('\nComputing statistical validation metrics...\n');
    metrics = compute_metrics(true_labels, pred_labels, pred_probs);

    % 2. Run Latency Benchmark
    fprintf('Running subsystem latency benchmarks...\n');
    benchmark_data = benchmark_latency(25);

    % 3. Generate Report
    report_folder = fullfile(pwd, 'validation', 'reports');
    generate_validation_report(metrics, benchmark_data, report_folder);

    fprintf('\n=======================================================\n');
    fprintf('  VALIDATION SUMMARY                                   \n');
    fprintf('=======================================================\n');
    fprintf('  Multi-class Accuracy           : %6.2f %%\n', metrics.accuracy * 100);
    fprintf('  Quadratic Weighted Kappa (QWK) : %6.4f\n', metrics.quadratic_weighted_kappa);
    fprintf('  Cohen''s Kappa                 : %6.4f\n', metrics.cohen_kappa);
    fprintf('  Macro F1-Score                 : %6.4f\n', metrics.macro_f1_score);
    fprintf('  Referable DR Sensitivity       : %6.2f %%\n', metrics.referable_dr.sensitivity * 100);
    fprintf('  Referable DR Specificity       : %6.2f %%\n', metrics.referable_dr.specificity * 100);
    fprintf('=======================================================\n\n');
end

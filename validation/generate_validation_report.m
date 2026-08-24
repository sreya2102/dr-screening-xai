function generate_validation_report(metrics, benchmark_data, output_dir)
% GENERATE_VALIDATION_REPORT Formats and saves clinical validation metrics and report.
%
% Usage:
%   generate_validation_report(metrics, benchmark_data, 'results/validation_report')

    if nargin < 3 || isempty(output_dir)
        output_dir = fullfile(pwd, 'validation', 'reports');
    end

    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    % 1. Export JSON Summary
    report_data.metrics = metrics;
    if nargin >= 2 && ~isempty(benchmark_data)
        report_data.benchmark = benchmark_data;
    end
    report_data.timestamp = char(datetime('now'));

    json_path = fullfile(output_dir, 'validation_summary.json');
    fid = fopen(json_path, 'w');
    if fid ~= -1
        fprintf(fid, '%s', jsonencode(report_data));
        fclose(fid);
    end

    % 2. Export Markdown Report
    md_path = fullfile(output_dir, 'validation_report.md');
    fid_md = fopen(md_path, 'w');
    if fid_md ~= -1
        fprintf(fid_md, '# Diabetic Retinopathy Screening System - Validation Report\n\n');
        fprintf(fid_md, '**Generated Date:** %s\n\n', report_data.timestamp);
        
        fprintf(fid_md, '## 1. Overall Clinical Performance\n\n');
        fprintf(fid_md, '| Metric | Value |\n');
        fprintf(fid_md, '| :--- | :--- |\n');
        fprintf(fid_md, '| **Overall Multi-class Accuracy** | **%.2f%%** |\n', metrics.accuracy * 100);
        fprintf(fid_md, '| **Quadratic Weighted Kappa (QWK)** | **%.4f** |\n', metrics.quadratic_weighted_kappa);
        fprintf(fid_md, '| **Cohen''s Kappa** | **%.4f** |\n', metrics.cohen_kappa);
        fprintf(fid_md, '| **Macro F1-Score** | **%.4f** |\n', metrics.macro_f1_score);
        fprintf(fid_md, '| **Referable DR Sensitivity (Grade >= 2)** | **%.2f%%** |\n', metrics.referable_dr.sensitivity * 100);
        fprintf(fid_md, '| **Referable DR Specificity (Grade >= 2)** | **%.2f%%** |\n', metrics.referable_dr.specificity * 100);
        if ~isnan(metrics.macro_auc_roc)
            fprintf(fid_md, '| **Macro AUC-ROC** | **%.4f** |\n', metrics.macro_auc_roc);
        end
        fprintf(fid_md, '\n');

        fprintf(fid_md, '## 2. Per-Class Diagnostic Performance\n\n');
        fprintf(fid_md, '| Grade / Category | Sensitivity | Specificity | Precision | F1-Score |\n');
        fprintf(fid_md, '| :--- | :--- | :--- | :--- | :--- |\n');
        grade_labels = {'Grade 0 (No DR)', 'Grade 1 (Mild)', 'Grade 2 (Moderate)', 'Grade 3 (Severe)', 'Grade 4 (PDR)'};
        for c = 1:5
            fprintf(fid_md, '| %s | %.2f%% | %.2f%% | %.2f%% | %.4f |\n', ...
                grade_labels{c}, ...
                metrics.per_class.sensitivity(c) * 100, ...
                metrics.per_class.specificity(c) * 100, ...
                metrics.per_class.precision(c) * 100, ...
                metrics.per_class.f1_score(c));
        end
        fprintf(fid_md, '\n');

        fprintf(fid_md, '## 3. Confusion Matrix\n\n');
        fprintf(fid_md, '```\n');
        fprintf(fid_md, '        Pred 0   Pred 1   Pred 2   Pred 3   Pred 4\n');
        for r = 1:5
            fprintf(fid_md, 'True %d:  %6d   %6d   %6d   %6d   %6d\n', ...
                r - 1, metrics.confusion_matrix(r, :));
        end
        fprintf(fid_md, '```\n\n');

        if nargin >= 2 && ~isempty(benchmark_data)
            fprintf(fid_md, '## 4. Subsystem Latency & Throughput Benchmark\n\n');
            fprintf(fid_md, '| Subsystem Module | Mean Latency (ms) | Std Dev (ms) |\n');
            fprintf(fid_md, '| :--- | :--- | :--- |\n');
            fprintf(fid_md, '| Module 1: IQA Gating | %.2f ms | ± %.2f |\n', benchmark_data.iqa_mean_ms, benchmark_data.iqa_std_ms);
            fprintf(fid_md, '| Module 2: Image Enhancement | %.2f ms | ± %.2f |\n', benchmark_data.enh_mean_ms, benchmark_data.enh_std_ms);
            fprintf(fid_md, '| Module 3: Feature Segmentation | %.2f ms | ± %.2f |\n', benchmark_data.seg_mean_ms, benchmark_data.seg_std_ms);
            fprintf(fid_md, '| Module 4: DR Classification | %.2f ms | ± %.2f |\n', benchmark_data.grade_mean_ms, benchmark_data.grade_std_ms);
            fprintf(fid_md, '| Module 5: Explainability | %.2f ms | ± %.2f |\n', benchmark_data.xai_mean_ms, benchmark_data.xai_std_ms);
            fprintf(fid_md, '| **Total Pipeline Latency** | **%.2f ms** | **± %.2f** |\n', benchmark_data.total_mean_ms, benchmark_data.total_std_ms);
            fprintf(fid_md, '| **System Throughput** | **%.2f FPS** | - |\n', benchmark_data.fps);
        end

        fclose(fid_md);
    end

    fprintf('Validation report successfully written to:\n  - %s\n  - %s\n', json_path, md_path);
end

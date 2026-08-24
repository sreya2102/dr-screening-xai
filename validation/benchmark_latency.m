function benchmark_data = benchmark_latency(num_runs, sample_img)
% BENCHMARK_LATENCY Measures execution timing across each module in the pipeline.
%
% Usage:
%   benchmark_data = benchmark_latency();
%   benchmark_data = benchmark_latency(50);

    if nargin < 1 || isempty(num_runs)
        num_runs = 20;
    end

    if nargin < 2 || isempty(sample_img)
        sample_img = uint8(120 * ones(224, 224, 3));
    end

    fprintf('Benchmarking screening pipeline latency across %d iterations...\n', num_runs);

    times_iqa   = zeros(num_runs, 1);
    times_enh   = zeros(num_runs, 1);
    times_seg   = zeros(num_runs, 1);
    times_grade = zeros(num_runs, 1);
    times_xai   = zeros(num_runs, 1);
    times_total = zeros(num_runs, 1);

    % Warmup
    try
        mock_pipeline_stubs('iqa', sample_img);
    catch
    end

    for i = 1:num_runs
        t_start = tic;

        % Module 1
        t_sub = tic;
        iqa_res = mock_pipeline_stubs('iqa', sample_img);
        times_iqa(i) = toc(t_sub) * 1000;

        % Module 2
        t_sub = tic;
        enh_res = mock_pipeline_stubs('enhancement', sample_img);
        times_enh(i) = toc(t_sub) * 1000;

        % Module 3
        t_sub = tic;
        seg_res = mock_pipeline_stubs('segmentation', enh_res);
        times_seg(i) = toc(t_sub) * 1000;

        % Module 4
        t_sub = tic;
        grade_res = mock_pipeline_stubs('dr_grading', seg_res);
        times_grade(i) = toc(t_sub) * 1000;

        % Module 5
        t_sub = tic;
        xai_res = mock_pipeline_stubs('explainability', enh_res);
        times_xai(i) = toc(t_sub) * 1000;

        times_total(i) = toc(t_start) * 1000;
    end

    benchmark_data.num_runs = num_runs;
    benchmark_data.iqa_mean_ms   = mean(times_iqa);
    benchmark_data.iqa_std_ms    = std(times_iqa);
    benchmark_data.enh_mean_ms   = mean(times_enh);
    benchmark_data.enh_std_ms    = std(times_enh);
    benchmark_data.seg_mean_ms   = mean(times_seg);
    benchmark_data.seg_std_ms    = std(times_seg);
    benchmark_data.grade_mean_ms = mean(times_grade);
    benchmark_data.grade_std_ms  = std(times_grade);
    benchmark_data.xai_mean_ms   = mean(times_xai);
    benchmark_data.xai_std_ms    = std(times_xai);
    benchmark_data.total_mean_ms = mean(times_total);
    benchmark_data.total_std_ms  = std(times_total);
    benchmark_data.fps           = 1000.0 / benchmark_data.total_mean_ms;

    fprintf('\n================== Pipeline Latency Benchmark ==================\n');
    fprintf('  Module 1 (IQA Gating)        : %6.2f ms (± %4.2f)\n', benchmark_data.iqa_mean_ms, benchmark_data.iqa_std_ms);
    fprintf('  Module 2 (Enhancement)       : %6.2f ms (± %4.2f)\n', benchmark_data.enh_mean_ms, benchmark_data.enh_std_ms);
    fprintf('  Module 3 (Segmentation)      : %6.2f ms (± %4.2f)\n', benchmark_data.seg_mean_ms, benchmark_data.seg_std_ms);
    fprintf('  Module 4 (DR Grading)        : %6.2f ms (± %4.2f)\n', benchmark_data.grade_mean_ms, benchmark_data.grade_std_ms);
    fprintf('  Module 5 (Explainability)    : %6.2f ms (± %4.2f)\n', benchmark_data.xai_mean_ms, benchmark_data.xai_std_ms);
    fprintf('----------------------------------------------------------------\n');
    fprintf('  Total Pipeline Latency       : %6.2f ms (± %4.2f)\n', benchmark_data.total_mean_ms, benchmark_data.total_std_ms);
    fprintf('  Estimated Throughput         : %6.2f FPS (Images/sec)\n', benchmark_data.fps);
    fprintf('================================================================\n\n');
end

function sim_results = run_simulink_simulation(input_images, model_name)
% RUN_SIMULINK_SIMULATION Runs the Diabetic Retinopathy Simulink Screening System
%
% Can execute via Simulink engine (`sim`) or directly via high-performance 
% discrete simulation runtime harness.
%
% Usage:
%   sim_results = run_simulink_simulation()
%   sim_results = run_simulink_simulation('path/to/test.jpg')
%   sim_results = run_simulink_simulation(image_array, 'dr_screening_pipeline')

    if nargin < 1 || isempty(input_images)
        % Create synthetic test samples covering all stages
        input_images = { ...
            struct('name', 'Normal_Fundus_Sample', 'img', uint8(120 * ones(224, 224, 3)), 'true_grade', 0), ...
            struct('name', 'Mild_NPDR_Sample', 'img', uint8(100 * ones(224, 224, 3)), 'true_grade', 1), ...
            struct('name', 'Severe_NPDR_Sample', 'img', uint8(80 * ones(224, 224, 3)), 'true_grade', 3), ...
            struct('name', 'Dark_Rejected_Sample', 'img', uint8(5 * ones(224, 224, 3)), 'true_grade', -1) ...
        };
    end

    if nargin < 2 || isempty(model_name)
        model_name = 'dr_screening_pipeline';
    end

    fprintf('=======================================================\n');
    fprintf('  DR Screening System - Simulink Simulation Harness   \n');
    fprintf('=======================================================\n');

    num_samples = length(input_images);
    sim_results = repmat(struct(...
        'sample_name', '', ...
        'iqa_gate', uint8(0), ...
        'iqa_status_text', '', ...
        'dr_grade', 0, ...
        'max_confidence', 0, ...
        'risk_score', 0, ...
        'triage_action_code', uint8(0), ...
        'triage_action_text', '', ...
        'triage_priority', uint8(0), ...
        'referral_urgency', '', ...
        'latency_ms', 0 ...
    ), num_samples, 1);

    for i = 1:num_samples
        sample = input_images{i};
        if isstruct(sample)
            s_name = sample.name;
            img_data = sample.img;
        elseif ischar(sample) || isstring(sample)
            [~, s_name, ~] = fileparts(sample);
            img_data = imread(sample);
        else
            s_name = sprintf('Image_Sample_%03d', i);
            img_data = sample;
        end

        tic;
        % Execute Simulation Pipeline
        [iqa_gate, dr_grade, max_conf, risk_score, triage_code] = simulink_pipeline_adapter(img_data);
        [action_code, action_text, triage_priority, referral_urgency] = dr_decision_logic(iqa_gate, dr_grade, max_conf, risk_score);
        elapsed_time = toc * 1000; % ms

        % Translate IQA Gate
        switch iqa_gate
            case 0
                iqa_text = 'Reject';
            case 1
                iqa_text = 'Borderline';
            case 2
                iqa_text = 'Good';
            otherwise
                iqa_text = 'Unknown';
        end

        sim_results(i).sample_name = s_name;
        sim_results(i).iqa_gate = iqa_gate;
        sim_results(i).iqa_status_text = iqa_text;
        sim_results(i).dr_grade = dr_grade;
        sim_results(i).max_confidence = max_conf;
        sim_results(i).risk_score = risk_score;
        sim_results(i).triage_action_code = action_code;
        sim_results(i).triage_action_text = action_text;
        sim_results(i).triage_priority = triage_priority;
        sim_results(i).referral_urgency = referral_urgency;
        sim_results(i).latency_ms = elapsed_time;

        fprintf('[Sample %d/%d] %s\n', i, num_samples, s_name);
        fprintf('  - IQA Gate         : %s (Code: %d)\n', iqa_text, iqa_gate);
        fprintf('  - DR Grade         : %d | Risk: %.2f | Conf: %.2f\n', dr_grade, risk_score, max_conf);
        fprintf('  - Clinical Triage  : %s [%s]\n', referral_urgency, action_text);
        fprintf('  - Execution Time   : %.2f ms\n\n', elapsed_time);
    end

    fprintf('Simulation completed successfully for %d samples.\n', num_samples);
end

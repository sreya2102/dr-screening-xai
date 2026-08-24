function sim_results = screening_queue_simulation(params)
% SCREENING_QUEUE_SIMULATION Discrete-Event & Queueing Model for Screening Center Throughput.
%
% Models patient image arrival, upload queues, AI inference server,
% referral filtering, ophthalmologist review capacity, backlog, and latency.
%
% Provides native discrete-event queueing simulation that executes in base MATLAB 
% or can be connected with SimEvents when available.
%
% Inputs:
%   params : (Optional) Struct containing:
%       - num_screening_centers : default 5 centers
%       - patients_per_day_per_center : default 40 patients/day/center (Total: 200/day)
%       - image_size_mb         : default 15 MB / image set
%       - upload_bandwidth_mbps : default 20 Mbps per center
%       - ai_inference_ms       : default 250 ms (0.25 s per case)
%       - human_review_min      : default 3.0 minutes per referable case
%       - num_ophthalmologists  : default 2 clinicians
%       - working_hours_per_day : default 8.0 hours
%       - sim_duration_days     : default 5 days (1 work week)
%       - referable_dr_rate     : default 0.22 (22% positive referable rate)
%       - iqa_reject_rate       : default 0.08 (8% ungradable/reject rate)
%
% Outputs:
%   sim_results : Struct with complete queueing performance metrics:
%       - total_patients_arrived
%       - total_patients_processed
%       - total_iqa_rejects
%       - total_referrals_generated
%       - total_human_reviews_completed
%       - ai_server_utilization_pct
%       - human_review_utilization_pct
%       - avg_upload_wait_sec
%       - avg_ai_turnaround_sec
%       - avg_human_review_wait_hours
%       - end_of_week_backlog_cases
%       - recommended_reviewers_needed
%       - hourly_backlog_trace
%
% Usage:
%   results = screening_queue_simulation();
%   results = screening_queue_simulation(custom_params);

    if nargin < 1 || isempty(params)
        params = struct();
    end

    % Default parameters
    if ~isfield(params, 'num_screening_centers'), params.num_screening_centers = 5; end
    if ~isfield(params, 'patients_per_day_per_center'), params.patients_per_day_per_center = 40; end
    if ~isfield(params, 'image_size_mb'), params.image_size_mb = 15; end % MB
    if ~isfield(params, 'upload_bandwidth_mbps'), params.upload_bandwidth_mbps = 20; end % Mbps
    if ~isfield(params, 'ai_inference_ms'), params.ai_inference_ms = 250; end % ms
    if ~isfield(params, 'human_review_min'), params.human_review_min = 3.0; end % minutes
    if ~isfield(params, 'num_ophthalmologists'), params.num_ophthalmologists = 2; end
    if ~isfield(params, 'working_hours_per_day'), params.working_hours_per_day = 8.0; end
    if ~isfield(params, 'sim_duration_days'), params.sim_duration_days = 5; end % 5 working days
    if ~isfield(params, 'referable_dr_rate'), params.referable_dr_rate = 0.22; end % 22% referable
    if ~isfield(params, 'iqa_reject_rate'), params.iqa_reject_rate = 0.08; end % 8% IQA reject

    total_sim_hours = params.sim_duration_days * params.working_hours_per_day;
    total_sim_seconds = total_sim_hours * 3600;

    % Arrival rate calculation
    total_daily_patients = params.num_screening_centers * params.patients_per_day_per_center;
    total_expected_patients = total_daily_patients * params.sim_duration_days;
    mean_interarrival_sec = (params.working_hours_per_day * 3600) / total_daily_patients;

    % Bandwidth upload time: Size(Mbits) / Bandwidth(Mbps)
    upload_time_sec = (params.image_size_mb * 8) / params.upload_bandwidth_mbps;
    ai_service_time_sec = params.ai_inference_ms / 1000.0;
    human_service_time_sec = params.human_review_min * 60.0;

    % Discrete-Event Simulation Loop
    rng(42); % Seed for reproducible discrete arrival events
    
    % Generate Poisson/Exponential arrival stream
    curr_time = 0;
    arrival_times = [];
    while curr_time < total_sim_seconds
        inter_arrival = -log(max(1e-6, rand())) * mean_interarrival_sec;
        curr_time = curr_time + inter_arrival;
        if curr_time < total_sim_seconds
            arrival_times(end+1) = curr_time; %#ok<AGROW>
        end
    end

    num_patients = length(arrival_times);

    % Event tracking arrays
    upload_complete_times = zeros(num_patients, 1);
    ai_start_times        = zeros(num_patients, 1);
    ai_complete_times     = zeros(num_patients, 1);
    is_rejected_iqa       = false(num_patients, 1);
    is_referable          = false(num_patients, 1);
    human_start_times     = zeros(num_patients, 1);
    human_complete_times  = zeros(num_patients, 1);

    % 1. Upload & AI Server Simulation
    ai_server_free_time = 0;
    for i = 1:num_patients
        arr_t = arrival_times(i);
        upl_t = arr_t + upload_time_sec * (0.8 + 0.4 * rand()); % small upload jitter
        upload_complete_times(i) = upl_t;

        % AI Server Queue
        ai_start = max(upl_t, ai_server_free_time);
        ai_complete = ai_start + ai_service_time_sec;
        ai_server_free_time = ai_complete;

        ai_start_times(i) = ai_start;
        ai_complete_times(i) = ai_complete;

        % Stochastic Case Outcome
        p_rand = rand();
        if p_rand < params.iqa_reject_rate
            is_rejected_iqa(i) = true;
        elseif p_rand < (params.iqa_reject_rate + params.referable_dr_rate)
            is_referable(i) = true;
        end
    end

    % 2. Human Ophthalmologist Review Server Simulation (Multi-server queue)
    reviewer_free_times = zeros(params.num_ophthalmologists, 1);
    referable_indices = find(is_referable);
    num_referrals = length(referable_indices);

    for k = 1:num_referrals
        p_idx = referable_indices(k);
        case_available_time = ai_complete_times(p_idx);

        % Assign to earliest available ophthalmologist
        [earliest_free, rev_id] = min(reviewer_free_times);
        h_start = max(case_available_time, earliest_free);
        h_duration = human_service_time_sec * (0.7 + 0.6 * rand()); % variability in review time
        h_complete = h_start + h_duration;

        reviewer_free_times(rev_id) = h_complete;
        human_start_times(p_idx) = h_start;
        human_complete_times(p_idx) = h_complete;
    end

    % Aggregate Statistics
    total_ai_busy_time = sum(ai_complete_times - ai_start_times);
    ai_utilization = (total_ai_busy_time / total_sim_seconds) * 100;

    reviews_done_in_sim = sum(human_complete_times(referable_indices) <= total_sim_seconds);
    total_human_busy_time = 0;
    for k = 1:num_referrals
        p_idx = referable_indices(k);
        if human_start_times(p_idx) < total_sim_seconds
            t_end = min(total_sim_seconds, human_complete_times(p_idx));
            total_human_busy_time = total_human_busy_time + (t_end - human_start_times(p_idx));
        end
    end
    human_utilization = (total_human_busy_time / (params.num_ophthalmologists * total_sim_seconds)) * 100;

    % Delays and wait times
    upload_delays = upload_complete_times - arrival_times(:);
    ai_queue_waits = ai_start_times - upload_complete_times;
    
    if num_referrals > 0
        human_queue_waits = (human_start_times(referable_indices) - ai_complete_times(referable_indices)) / 3600.0; % hours
        avg_human_wait_hrs = mean(human_queue_waits);
        backlog_at_end = sum(human_complete_times(referable_indices) > total_sim_seconds);
    else
        avg_human_wait_hrs = 0.0;
        backlog_at_end = 0;
    end

    % Capacity Recommendation
    referral_arrival_rate_per_hour = (total_daily_patients * params.referable_dr_rate) / params.working_hours_per_day;
    clinician_service_rate_per_hour = 60.0 / params.human_review_min;
    recommended_reviewers = ceil(referral_arrival_rate_per_hour / (clinician_service_rate_per_hour * 0.80)); % target 80% load

    % Build output struct
    sim_results.params = params;
    sim_results.total_patients_arrived = num_patients;
    sim_results.total_patients_processed = num_patients;
    sim_results.total_iqa_rejects = sum(is_rejected_iqa);
    sim_results.total_referrals_generated = num_referrals;
    sim_results.total_human_reviews_completed = reviews_done_in_sim;
    sim_results.ai_server_utilization_pct = min(100.0, ai_utilization);
    sim_results.human_review_utilization_pct = min(100.0, human_utilization);
    sim_results.avg_upload_time_sec = mean(upload_delays);
    sim_results.avg_ai_queue_wait_sec = mean(ai_queue_waits);
    sim_results.avg_ai_turnaround_sec = mean(upload_delays + ai_queue_waits + ai_service_time_sec);
    sim_results.avg_human_review_wait_hours = avg_human_wait_hrs;
    sim_results.end_of_week_backlog_cases = backlog_at_end;
    sim_results.recommended_reviewers_needed = recommended_reviewers;
    sim_results.system_throughput_patients_per_day = num_patients / params.sim_duration_days;

    % Print Summary
    fprintf('=================================================================\n');
    fprintf('    Discrete-Event Screening Center Throughput Simulation        \n');
    fprintf('=================================================================\n');
    fprintf('  Simulation Period            : %d Days (%d Working Hours)\n', params.sim_duration_days, total_sim_hours);
    fprintf('  Screening Centers Connected  : %d centers (%d patients/day total)\n', params.num_screening_centers, total_daily_patients);
    fprintf('  Total Patients Arrived       : %d cases\n', num_patients);
    fprintf('  IQA Immediate Retakes (8%%)   : %d cases\n', sim_results.total_iqa_rejects);
    fprintf('  Referable DR Flagged (22%%)   : %d cases\n', num_referrals);
    fprintf('  Human Reviews Completed      : %d cases\n', reviews_done_in_sim);
    fprintf('-----------------------------------------------------------------\n');
    fprintf('  AI Server Utilization        : %6.2f %%\n', sim_results.ai_server_utilization_pct);
    fprintf('  Avg Upload Time (15MB/20Mbps): %6.2f sec\n', sim_results.avg_upload_time_sec);
    fprintf('  Avg AI Turnaround Time       : %6.2f sec\n', sim_results.avg_ai_turnaround_sec);
    fprintf('  Ophthalmologist Utilization  : %6.2f %% (%d Reviewers Active)\n', sim_results.human_review_utilization_pct, params.num_ophthalmologists);
    fprintf('  Avg Human Review Wait Time   : %6.2f hours\n', sim_results.avg_human_review_wait_hours);
    fprintf('  End-of-Week Case Backlog     : %d cases\n', sim_results.end_of_week_backlog_cases);
    fprintf('  Recommended Reviewers Needed : %d Clinicians (for <80%% load)\n', sim_results.recommended_reviewers_needed);
    fprintf('=================================================================\n\n');
end

import random
import math

def screening_queue_simulation(params=None):
    """
    Discrete-Event & Queueing Model for Screening Center Throughput.
    Models patient image arrival, upload queues, AI inference server,
    referral filtering, ophthalmologist review capacity, backlog, and latency.
    """
    if params is None:
        params = {}
        
    num_screening_centers = params.get('num_screening_centers', 5)
    patients_per_day_per_center = params.get('patients_per_day_per_center', 40)
    image_size_mb = params.get('image_size_mb', 15)
    upload_bandwidth_mbps = params.get('upload_bandwidth_mbps', 20)
    ai_inference_ms = params.get('ai_inference_ms', 250)
    human_review_min = params.get('human_review_min', 3.0)
    num_ophthalmologists = params.get('num_ophthalmologists', 2)
    working_hours_per_day = params.get('working_hours_per_day', 8.0)
    sim_duration_days = params.get('sim_duration_days', 5)
    referable_dr_rate = params.get('referable_dr_rate', 0.22)
    iqa_reject_rate = params.get('iqa_reject_rate', 0.08)
    
    total_sim_hours = sim_duration_days * working_hours_per_day
    total_sim_seconds = total_sim_hours * 3600
    
    total_daily_patients = num_screening_centers * patients_per_day_per_center
    total_expected_patients = total_daily_patients * sim_duration_days
    mean_interarrival_sec = (working_hours_per_day * 3600) / total_daily_patients
    
    upload_time_sec = (image_size_mb * 8) / upload_bandwidth_mbps
    ai_service_time_sec = ai_inference_ms / 1000.0
    human_service_time_sec = human_review_min * 60.0
    
    random.seed(42)
    
    # 1. Generate Arrivals
    curr_time = 0
    arrival_times = []
    while curr_time < total_sim_seconds:
        inter_arrival = -math.log(max(1e-6, random.random())) * mean_interarrival_sec
        curr_time += inter_arrival
        if curr_time < total_sim_seconds:
            arrival_times.append(curr_time)
            
    num_patients = len(arrival_times)
    
    upload_complete_times = [0] * num_patients
    ai_start_times = [0] * num_patients
    ai_complete_times = [0] * num_patients
    is_rejected_iqa = [False] * num_patients
    is_referable = [False] * num_patients
    
    # 2. Upload & AI Server Simulation
    ai_server_free_time = 0
    for i in range(num_patients):
        arr_t = arrival_times[i]
        upl_t = arr_t + upload_time_sec * (0.8 + 0.4 * random.random())
        upload_complete_times[i] = upl_t
        
        ai_start = max(upl_t, ai_server_free_time)
        ai_complete = ai_start + ai_service_time_sec
        ai_server_free_time = ai_complete
        
        ai_start_times[i] = ai_start
        ai_complete_times[i] = ai_complete
        
        p_rand = random.random()
        if p_rand < iqa_reject_rate:
            is_rejected_iqa[i] = True
        elif p_rand < (iqa_reject_rate + referable_dr_rate):
            is_referable[i] = True
            
    # 3. Human Review Server Simulation
    human_start_times = [0] * num_patients
    human_complete_times = [0] * num_patients
    reviewer_free_times = [0] * num_ophthalmologists
    
    referable_indices = [i for i, val in enumerate(is_referable) if val]
    num_referrals = len(referable_indices)
    
    for p_idx in referable_indices:
        case_available_time = ai_complete_times[p_idx]
        
        earliest_free = min(reviewer_free_times)
        rev_id = reviewer_free_times.index(earliest_free)
        
        h_start = max(case_available_time, earliest_free)
        h_duration = human_service_time_sec * (0.7 + 0.6 * random.random())
        h_complete = h_start + h_duration
        
        reviewer_free_times[rev_id] = h_complete
        human_start_times[p_idx] = h_start
        human_complete_times[p_idx] = h_complete
        
    # Aggregate stats
    total_ai_busy_time = sum([ai_complete_times[i] - ai_start_times[i] for i in range(num_patients)])
    ai_utilization = (total_ai_busy_time / total_sim_seconds) * 100
    
    reviews_done_in_sim = sum([1 for p_idx in referable_indices if human_complete_times[p_idx] <= total_sim_seconds])
    total_human_busy_time = 0
    for p_idx in referable_indices:
        if human_start_times[p_idx] < total_sim_seconds:
            t_end = min(total_sim_seconds, human_complete_times[p_idx])
            total_human_busy_time += (t_end - human_start_times[p_idx])
            
    human_utilization = (total_human_busy_time / (num_ophthalmologists * total_sim_seconds)) * 100
    
    upload_delays = [upload_complete_times[i] - arrival_times[i] for i in range(num_patients)]
    ai_queue_waits = [ai_start_times[i] - upload_complete_times[i] for i in range(num_patients)]
    
    if num_referrals > 0:
        human_queue_waits = [(human_start_times[i] - ai_complete_times[i]) / 3600.0 for i in referable_indices]
        avg_human_wait_hrs = sum(human_queue_waits) / len(human_queue_waits)
        backlog_at_end = sum([1 for p_idx in referable_indices if human_complete_times[p_idx] > total_sim_seconds])
    else:
        avg_human_wait_hrs = 0.0
        backlog_at_end = 0
        
    referral_arrival_rate_per_hour = (total_daily_patients * referable_dr_rate) / working_hours_per_day
    clinician_service_rate_per_hour = 60.0 / human_review_min
    recommended_reviewers = math.ceil(referral_arrival_rate_per_hour / (clinician_service_rate_per_hour * 0.80))
    
    sim_results = {
        'total_patients_arrived': num_patients,
        'total_patients_processed': num_patients,
        'total_iqa_rejects': sum(is_rejected_iqa),
        'total_referrals_generated': num_referrals,
        'total_human_reviews_completed': reviews_done_in_sim,
        'ai_server_utilization_pct': min(100.0, ai_utilization),
        'human_review_utilization_pct': min(100.0, human_utilization),
        'avg_upload_time_sec': sum(upload_delays) / len(upload_delays) if upload_delays else 0,
        'avg_ai_queue_wait_sec': sum(ai_queue_waits) / len(ai_queue_waits) if ai_queue_waits else 0,
        'avg_ai_turnaround_sec': (sum(upload_delays) + sum(ai_queue_waits) + ai_service_time_sec * num_patients) / num_patients if num_patients > 0 else 0,
        'avg_human_review_wait_hours': avg_human_wait_hrs,
        'end_of_week_backlog_cases': backlog_at_end,
        'recommended_reviewers_needed': recommended_reviewers
    }
    
    # Print Summary
    print('=================================================================')
    print('    Discrete-Event Screening Center Throughput Simulation        ')
    print('=================================================================')
    print(f'  Simulation Period            : {sim_duration_days} Days ({total_sim_hours} Working Hours)')
    print(f'  Screening Centers Connected  : {num_screening_centers} centers ({total_daily_patients} patients/day total)')
    print(f'  Total Patients Arrived       : {num_patients} cases')
    print(f'  IQA Immediate Retakes (8%)   : {sim_results["total_iqa_rejects"]} cases')
    print(f'  Referable DR Flagged (22%)   : {num_referrals} cases')
    print(f'  Human Reviews Completed      : {reviews_done_in_sim} cases')
    print('-----------------------------------------------------------------')
    print(f'  AI Server Utilization        : {sim_results["ai_server_utilization_pct"]:6.2f} %')
    print(f'  Avg Upload Time (15MB/20Mbps): {sim_results["avg_upload_time_sec"]:6.2f} sec')
    print(f'  Avg AI Turnaround Time       : {sim_results["avg_ai_turnaround_sec"]:6.2f} sec')
    print(f'  Ophthalmologist Utilization  : {sim_results["human_review_utilization_pct"]:6.2f} % ({num_ophthalmologists} Reviewers Active)')
    print(f'  Avg Human Review Wait Time   : {sim_results["avg_human_review_wait_hours"]:6.2f} hours')
    print(f'  End-of-Week Case Backlog     : {sim_results["end_of_week_backlog_cases"]} cases')
    print(f'  Recommended Reviewers Needed : {sim_results["recommended_reviewers_needed"]} Clinicians (for <80% load)')
    print('=================================================================\n')
    
    return sim_results

function screening_data = create_mock_screening_data(dr_grade, iqa_status)
% CREATE_MOCK_SCREENING_DATA Generates synthetic screening data for Module 5 testing.
%
% Usage:
%   screening_data = create_mock_screening_data()
%   screening_data = create_mock_screening_data(2, 'Good')
%
% Inputs:
%   dr_grade   - (Optional) Int 0 to 4 (Default: 2 - Moderate NPDR)
%   iqa_status - (Optional) String 'Good', 'Borderline', or 'Reject' (Default: 'Good')

    if nargin < 1 || isempty(dr_grade)
        dr_grade = 2;
    end
    if nargin < 2 || isempty(iqa_status)
        iqa_status = 'Good';
    end

    % Image dimensions
    img_size = [512, 512];
    
    % 1. Create synthetic fundus background (reddish-orange circular retina)
    [X, Y] = meshgrid(1:img_size(2), 1:img_size(1));
    center = [img_size(1)/2, img_size(2)/2];
    radius = 230;
    dist_from_center = sqrt((X - center(2)).^2 + (Y - center(1)).^2);
    mask_retina = dist_from_center <= radius;
    
    % RGB channels for fundus color
    R = zeros(img_size, 'uint8');
    G = zeros(img_size, 'uint8');
    B = zeros(img_size, 'uint8');
    
    R(mask_retina) = uint8(190 + 30 * rand(sum(mask_retina(:)), 1));
    G(mask_retina) = uint8(70 + 20 * rand(sum(mask_retina(:)), 1));
    B(mask_retina) = uint8(20 + 10 * rand(sum(mask_retina(:)), 1));
    
    % Optic disc (bright yellow circle)
    od_center = [256, 380];
    od_radius = 35;
    od_dist = sqrt((X - od_center(2)).^2 + (Y - od_center(1)).^2);
    od_mask = od_dist <= od_radius;
    
    R(od_mask) = 255;
    G(od_mask) = 240;
    B(od_mask) = 150;
    
    % Vessels (dark tree-like branching curves)
    vessels_mask = false(img_size);
    vessels_mask(240:270, 100:380) = true;
    vessels_mask(150:380, 370:390) = true;
    vessels_mask(100:200, 200:370) = true;
    vessels_mask = vessels_mask & mask_retina & ~od_mask;
    
    R(vessels_mask) = uint8(double(R(vessels_mask)) * 0.4);
    G(vessels_mask) = uint8(double(G(vessels_mask)) * 0.2);
    B(vessels_mask) = uint8(double(B(vessels_mask)) * 0.2);
    
    raw_img = cat(3, R, G, B);
    
    % 2. Create Lesion Masks based on DR grade
    ma_mask = false(img_size);
    hem_mask = false(img_size);
    ex_mask = false(img_size);
    
    if dr_grade >= 1 % Mild NPDR
        % Microaneurysms (small red dots)
        ma_coords = [200, 220; 210, 250; 280, 200; 300, 240; 180, 310];
        for i = 1:size(ma_coords, 1)
            ma_mask(max(1, ma_coords(i,1)-2):min(img_size(1), ma_coords(i,1)+2), ...
                    max(1, ma_coords(i,2)-2):min(img_size(2), ma_coords(i,2)+2)) = true;
        end
    end
    
    if dr_grade >= 2 % Moderate NPDR
        % Hemorrhages (larger dark red blobs)
        hem_coords = [250, 180; 320, 220; 190, 180];
        for i = 1:size(hem_coords, 1)
            [hX, hY] = meshgrid(1:img_size(2), 1:img_size(1));
            h_dist = sqrt((hX - hem_coords(i,2)).^2 + (hY - hem_coords(i,1)).^2);
            hem_mask = hem_mask | (h_dist <= 7);
        end
        
        % Hard Exudates (bright yellowish flecks)
        ex_coords = [220, 280; 240, 300; 260, 290; 230, 310];
        for i = 1:size(ex_coords, 1)
            [eX, eY] = meshgrid(1:img_size(2), 1:img_size(1));
            e_dist = sqrt((eX - ex_coords(i,2)).^2 + (eY - ex_coords(i,1)).^2);
            ex_mask = ex_mask | (e_dist <= 6);
        end
    end
    
    if dr_grade >= 3 % Severe NPDR
        % Additional dense hemorrhages
        hem_coords_extra = [150, 250; 350, 180; 310, 300; 270, 150];
        for i = 1:size(hem_coords_extra, 1)
            [hX, hY] = meshgrid(1:img_size(2), 1:img_size(1));
            h_dist = sqrt((hX - hem_coords_extra(i,2)).^2 + (hY - hem_coords_extra(i,1)).^2);
            hem_mask = hem_mask | (h_dist <= 10);
        end
    end
    
    if dr_grade >= 4 % Proliferative DR
        % Neovascularization / severe exudates
        ex_coords_extra = [180, 200; 300, 350; 340, 280];
        for i = 1:size(ex_coords_extra, 1)
            [eX, eY] = meshgrid(1:img_size(2), 1:img_size(1));
            e_dist = sqrt((eX - ex_coords_extra(i,2)).^2 + (eY - ex_coords_extra(i,1)).^2);
            ex_mask = ex_mask | (e_dist <= 12);
        end
    end
    
    % Enhanced image (green channel contrast enhanced)
    enhanced_img = raw_img;
    enhanced_img(:,:,2) = uint8(min(255, double(raw_img(:,:,2)) * 1.3));
    
    % DR Grade Labels
    grade_labels = {'No DR (Normal)', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'};
    
    % Probabilities vector
    probs = zeros(1, 5);
    probs(dr_grade + 1) = 0.82 + 0.15 * rand();
    remaining_prob = 1.0 - probs(dr_grade + 1);
    other_indices = setdiff(1:5, dr_grade + 1);
    probs(other_indices) = remaining_prob / length(other_indices);
    
    % Quality score
    if strcmp(iqa_status, 'Good')
        q_score = 0.92;
    elseif strcmp(iqa_status, 'Borderline')
        q_score = 0.65;
    else
        q_score = 0.35;
    end

    % Construct screening_data struct
    screening_data = struct(...
        'patient_id', 'PAT-2026-9042', ...
        'patient_name', 'John Smith', ...
        'age', 62, ...
        'eye_side', 'OD', ...
        'date', char(datetime('today', 'Format', 'yyyy-MM-dd')), ...
        'raw_image', raw_img, ...
        'enhanced_image', enhanced_img, ...
        'iqa_result', struct('status', iqa_status, 'quality_score', q_score), ...
        'segmentation_results', struct(...
            'vessels_mask', vessels_mask, ...
            'optic_disc_mask', od_mask, ...
            'microaneurysms_mask', ma_mask, ...
            'hemorrhages_mask', hem_mask, ...
            'exudates_mask', ex_mask, ...
            'lesion_counts', struct(...
                'microaneurysms', sum(ma_mask(:)), ...
                'hemorrhages', sum(hem_mask(:)), ...
                'exudates', sum(ex_mask(:))...
            )...
        ), ...
        'dr_grading_result', struct(...
            'predicted_grade', dr_grade, ...
            'grade_label', grade_labels{dr_grade + 1}, ...
            'confidence', probs(dr_grade + 1), ...
            'class_probabilities', probs...
        )...
    );
end

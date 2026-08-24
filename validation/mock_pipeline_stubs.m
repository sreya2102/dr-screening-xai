function result = mock_pipeline_stubs(stage, input_data)
% MOCK_PIPELINE_STUBS Fallback / Mock implementations for Modules 1 to 5
%   Provides reliable, high-fidelity default stubs matching teammate interfaces
%   so Simulink simulation and validation suites can run end-to-end immediately.
%
%   Usage:
%       result = mock_pipeline_stubs('iqa', img)
%       result = mock_pipeline_stubs('enhancement', img)
%       result = mock_pipeline_stubs('segmentation', img)
%       result = mock_pipeline_stubs('dr_grading', img)
%       result = mock_pipeline_stubs('explainability', img)

    if nargin < 2
        input_data = [];
    end

    switch lower(stage)
        case 'iqa'
            % Module 1: Image Quality Assessment
            % Returns: struct with status, quality_score, rejection_reason, is_acceptable
            if isempty(input_data)
                result.status = 'Good';
                result.quality_score = 0.88;
                result.rejection_reason = 'None';
                result.is_acceptable = true;
            elseif isstruct(input_data) && isfield(input_data, 'forced_status')
                % Deterministic mock override for testing
                result.status = input_data.forced_status;
                result.quality_score = input_data.forced_quality;
                result.rejection_reason = input_data.forced_reason;
                result.is_acceptable = ~strcmpi(result.status, 'Reject');
            else
                % Basic heuristic check if image matrix is passed
                if ischar(input_data) || isstring(input_data)
                    img = imread(input_data);
                else
                    img = input_data;
                end
                
                % Compute simple mean brightness & sharpness metric
                gray = rgb2gray_safe(img);
                mean_val = mean(double(gray(:))) / 255.0;
                
                % Fallback 2D convolution for sharpness without requiring Toolboxes
                gray_d = double(gray);
                lap_var = compute_sharpness_variance(gray_d);
                
                if mean_val < 0.10
                    result.status = 'Reject';
                    result.quality_score = 0.20;
                    result.rejection_reason = 'Under-illuminated (Too Dark)';
                    result.is_acceptable = false;
                elseif mean_val > 0.90
                    result.status = 'Reject';
                    result.quality_score = 0.25;
                    result.rejection_reason = 'Over-exposed (Glared)';
                    result.is_acceptable = false;
                elseif lap_var < 5.0 && (mean_val > 0.10 && mean_val < 0.90)
                    result.status = 'Borderline';
                    result.quality_score = 0.55;
                    result.rejection_reason = 'Mild Blur';
                    result.is_acceptable = true;
                else
                    result.status = 'Good';
                    result.quality_score = min(1.0, 0.70 + (lap_var / 500));
                    result.rejection_reason = 'None';
                    result.is_acceptable = true;
                end
            end

        case 'enhancement'
            % Module 2: Image Enhancement
            % Returns: enhanced_img, green_channel
            if isempty(input_data)
                result.enhanced_img = zeros(224, 224, 3, 'uint8');
                result.green_channel = zeros(224, 224, 'uint8');
            else
                if ischar(input_data) || isstring(input_data)
                    img = imread(input_data);
                else
                    img = input_data;
                end
                
                if size(img, 3) == 3
                    green = img(:, :, 2);
                else
                    green = img;
                    img = repmat(img, [1 1 3]);
                end
                
                % Histogram equalization / contrast stretch fallback (toolbox-independent)
                enhanced_green = simple_contrast_stretch(green);
                enhanced_rgb = img;
                enhanced_rgb(:, :, 2) = enhanced_green;
                
                result.enhanced_img = enhanced_rgb;
                result.green_channel = enhanced_green;
            end

        case 'segmentation'
            % Module 3: Lesion & Vessel Segmentation
            % Returns: vessel_mask, optic_disc_mask, lesion_features
            if isempty(input_data)
                result.vessel_mask = false(224, 224);
                result.optic_disc_mask = false(224, 224);
                result.lesion_density = 0.05;
                result.vessel_density = 0.12;
                result.microaneurysm_count = 3;
                result.hemorrhage_count = 1;
                result.hard_exudate_area = 0.02;
            else
                if isstruct(input_data) && isfield(input_data, 'green_channel')
                    g = input_data.green_channel;
                elseif size(input_data, 3) == 3
                    g = input_data(:, :, 2);
                else
                    g = input_data;
                end
                
                sz = size(g);
                % Thresholding without requiring Image Processing Toolbox
                thresh = mean(double(g(:)));
                result.vessel_mask = (double(g) < (thresh * 0.85));
                result.optic_disc_mask = (double(g) > (thresh * 1.30));
                
                % Estimate lesion stats
                result.vessel_density = sum(result.vessel_mask(:)) / numel(result.vessel_mask);
                result.lesion_density = 0.04;
                result.microaneurysm_count = round(result.lesion_density * 50);
                result.hemorrhage_count = round(result.lesion_density * 20);
                result.hard_exudate_area = result.lesion_density * 0.5;
            end

        case 'dr_grading'
            % Module 4: DR Classification & Severity Grading
            % Returns: grade (0-4), confidence_scores (1x5 vector), risk_score
            % Grades: 0-No DR, 1-Mild, 2-Moderate, 3-Severe, 4-PDR
            if isempty(input_data)
                result.dr_grade = 0;
                result.confidence_scores = [0.85, 0.10, 0.03, 0.01, 0.01];
                result.grade_name = 'No DR (Normal)';
                result.risk_score = 0.10;
            elseif isstruct(input_data) && isfield(input_data, 'forced_grade')
                % Deterministic grade override for unit testing
                g = input_data.forced_grade;
                conf = 0.02 * ones(1, 5);
                conf(g + 1) = 0.92;
                conf = conf / sum(conf);
                grade_names = {'No DR (Normal)', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR (PDR)'};
                result.dr_grade = g;
                result.confidence_scores = conf;
                result.grade_name = grade_names{g + 1};
                result.risk_score = double(g) / 4.0;
            else
                % Estimate based on lesion stats if provided
                if isstruct(input_data) && isfield(input_data, 'lesion_density')
                    ld = input_data.lesion_density;
                    if ld < 0.02
                        g = 0; conf = [0.88, 0.08, 0.02, 0.01, 0.01];
                    elseif ld < 0.05
                        g = 1; conf = [0.10, 0.75, 0.10, 0.03, 0.02];
                    elseif ld < 0.10
                        g = 2; conf = [0.03, 0.12, 0.70, 0.10, 0.05];
                    elseif ld < 0.18
                        g = 3; conf = [0.01, 0.04, 0.15, 0.68, 0.12];
                    else
                        g = 4; conf = [0.01, 0.02, 0.05, 0.18, 0.74];
                    end
                else
                    g = 0; conf = [0.80, 0.12, 0.05, 0.02, 0.01];
                end
                
                grade_names = {'No DR (Normal)', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR (PDR)'};
                result.dr_grade = g;
                result.confidence_scores = conf;
                result.grade_name = grade_names{g + 1};
                result.risk_score = sum(conf .* (0:4)) / 4.0;
            end

        case 'explainability'
            % Module 5: Explainability (Grad-CAM & Saliency Overlay)
            % Returns: heatmap, overlay_img, clinical_explanation
            if isempty(input_data)
                result.cam_heatmap = zeros(224, 224);
                result.overlay_img = zeros(224, 224, 3, 'uint8');
                result.explanation_summary = 'No significant pathological regions identified.';
            else
                if isstruct(input_data) && isfield(input_data, 'enhanced_img')
                    base_img = input_data.enhanced_img;
                elseif ismatrix(input_data)
                    base_img = input_data;
                else
                    base_img = zeros(224, 224, 3, 'uint8');
                end
                
                sz = size(base_img);
                [X, Y] = meshgrid(linspace(-1, 1, sz(2)), linspace(-1, 1, sz(1)));
                heatmap = exp(-(X.^2 + Y.^2) / 0.5);
                
                result.cam_heatmap = heatmap;
                result.overlay_img = base_img;
                result.explanation_summary = 'Attention concentrated on posterior pole microvascular structures.';
            end

        otherwise
            error('Unknown module stage: %s', stage);
    end
end

function gray = rgb2gray_safe(img)
    if size(img, 3) == 3
        gray = uint8(0.2989 * double(img(:,:,1)) + 0.5870 * double(img(:,:,2)) + 0.1140 * double(img(:,:,3)));
    else
        gray = uint8(img);
    end
end

function lap_var = compute_sharpness_variance(gray_d)
    % 2D Laplacian operator without requiring conv2 toolbox extensions
    [H, W] = size(gray_d);
    if H < 3 || W < 3
        lap_var = 100.0;
        return;
    end
    lap = -4 * gray_d(2:end-1, 2:end-1) + ...
          gray_d(1:end-2, 2:end-1) + gray_d(3:end, 2:end-1) + ...
          gray_d(2:end-1, 1:end-2) + gray_d(2:end-1, 3:end);
    lap_var = var(lap(:));
end

function out = simple_contrast_stretch(in)
    in_d = double(in);
    min_v = min(in_d(:));
    max_v = max(in_d(:));
    if max_v > min_v
        out = uint8(255 * (in_d - min_v) / (max_v - min_v));
    else
        out = in;
    end
end

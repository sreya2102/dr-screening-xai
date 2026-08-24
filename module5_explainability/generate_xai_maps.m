function xai_maps = generate_xai_maps(screening_data)
% GENERATE_XAI_MAPS Generates multi-modal visual XAI maps for DR screening.
%
% Input:
%   screening_data - Struct containing raw_image, enhanced_image, dr_grading_result, segmentation_results
%
% Output:
%   xai_maps - Struct containing:
%               .gradcam_overlay   (RGB image)
%               .saliency_map      (2D normalized float matrix)
%               .lesion_overlay    (RGB composite image with color-coded lesion masks)

    base_img = screening_data.enhanced_image;
    if isempty(base_img)
        base_img = screening_data.raw_image;
    end
    
    [H, W, ~] = size(base_img);
    
    % 1. Generate Grad-CAM Heatmap Overlay
    target_class = screening_data.dr_grading_result.predicted_grade + 1;
    model = [];
    if isfield(screening_data, 'model')
        model = screening_data.model;
    end
    
    lesion_masks = screening_data.segmentation_results;
    [gradcam_overlay, raw_saliency] = generate_gradcam(base_img, model, target_class, lesion_masks);

    % 2. Create Lesion Composite Overlay
    % Color legend:
    %   Optic Disc       - Cyan [0, 255, 255]
    %   Blood Vessels    - Blue [0, 100, 255]
    %   Microaneurysms   - Magenta/Red [255, 0, 100]
    %   Hemorrhages      - Dark Red [180, 0, 0]
    %   Exudates         - Yellow [255, 255, 0]
    
    img_double = double(base_img) / 255.0;
    lesion_composite = img_double;
    
    if isstruct(lesion_masks)
        % Vessels
        if isfield(lesion_masks, 'vessels_mask') && any(lesion_masks.vessels_mask(:))
            vm = repmat(lesion_masks.vessels_mask, [1, 1, 3]);
            lesion_composite(vm) = lesion_composite(vm) * 0.4 + 0.6 * [0, 0.4, 1.0];
        end
        % Optic Disc
        if isfield(lesion_masks, 'optic_disc_mask') && any(lesion_masks.optic_disc_mask(:))
            odm = repmat(lesion_masks.optic_disc_mask, [1, 1, 3]);
            lesion_composite(odm) = lesion_composite(odm) * 0.5 + 0.5 * [0, 1.0, 1.0];
        end
        % Microaneurysms
        if isfield(lesion_masks, 'microaneurysms_mask') && any(lesion_masks.microaneurysms_mask(:))
            mam = repmat(lesion_masks.microaneurysms_mask, [1, 1, 3]);
            lesion_composite(mam) = [1.0, 0.0, 0.4];
        end
        % Hemorrhages
        if isfield(lesion_masks, 'hemorrhages_mask') && any(lesion_masks.hemorrhages_mask(:))
            hemm = repmat(lesion_masks.hemorrhages_mask, [1, 1, 3]);
            lesion_composite(hemm) = [0.8, 0.0, 0.0];
        end
        % Exudates
        if isfield(lesion_masks, 'exudates_mask') && any(lesion_masks.exudates_mask(:))
            exm = repmat(lesion_masks.exudates_mask, [1, 1, 3]);
            lesion_composite(exm) = [1.0, 0.9, 0.0];
        end
    end
    
    lesion_overlay = uint8(lesion_composite * 255.0);

    % Construct output struct
    xai_maps = struct(...
        'gradcam_overlay', gradcam_overlay, ...
        'saliency_map', raw_saliency, ...
        'lesion_overlay', lesion_overlay...
    );
end

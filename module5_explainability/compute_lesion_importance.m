function importance_struct = compute_lesion_importance(segmentation_results, dr_grade)
% COMPUTE_LESION_IMPORTANCE Computes feature importance breakdown for lesions.
%
% Inputs:
%   segmentation_results - Struct containing lesion masks and counts
%   dr_grade             - Int 0 to 4
%
% Output:
%   importance_struct    - Struct with relative impact percentages & counts

    if nargin < 2; dr_grade = 0; end

    ma_count = 0;
    hem_count = 0;
    ex_count = 0;

    if isstruct(segmentation_results)
        if isfield(segmentation_results, 'lesion_counts')
            lc = segmentation_results.lesion_counts;
            if isfield(lc, 'microaneurysms'); ma_count = lc.microaneurysms; end
            if isfield(lc, 'hemorrhages'); hem_count = lc.hemorrhages; end
            if isfield(lc, 'exudates'); ex_count = lc.exudates; end
        end
    end

    % Weight factors reflecting clinical severity impact
    ma_weight = 1.0;
    hem_weight = 3.0;
    ex_weight = 2.5;

    total_weighted = ma_count * ma_weight + hem_count * hem_weight + ex_count * ex_weight;

    if total_weighted > 0
        ma_impact = (ma_count * ma_weight) / total_weighted * 100;
        hem_impact = (hem_count * hem_weight) / total_weighted * 100;
        ex_impact = (ex_count * ex_weight) / total_weighted * 100;
    else
        ma_impact = 0;
        hem_impact = 0;
        ex_impact = 0;
    end

    importance_struct = struct(...
        'microaneurysms_count', ma_count, ...
        'microaneurysms_impact_pct', round(ma_impact, 1), ...
        'hemorrhages_count', hem_count, ...
        'hemorrhages_impact_pct', round(hem_impact, 1), ...
        'exudates_count', ex_count, ...
        'exudates_impact_pct', round(ex_impact, 1), ...
        'total_lesions', ma_count + hem_count + ex_count ...
    );
end

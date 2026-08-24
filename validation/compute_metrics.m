function metrics = compute_metrics(y_true, y_pred, y_prob)
% COMPUTE_METRICS Comprehensive clinical and classification metrics for DR screening.
%
% Inputs:
%   y_true : Numeric, categorical, or string vector of true labels (0 to 4)
%   y_pred : Numeric, categorical, or string vector of predicted labels (0 to 4)
%   y_prob : (Optional) N x 5 matrix of class prediction probabilities
%
% Outputs:
%   metrics : Struct containing:
%       - accuracy
%       - sensitivity (per-class and macro)
%       - specificity (per-class and macro)
%       - precision (per-class and macro)
%       - f1_score (per-class and macro)
%       - quadratic_weighted_kappa (QWK)
%       - cohen_kappa
%       - confusion_matrix
%       - referable_dr (sensitivity, specificity, accuracy, f1_score)
%       - auc_roc (per-class and macro, if y_prob provided)

    % Convert categorical or string labels if needed
    if iscategorical(y_true) || iscell(y_true) || isstring(y_true)
        y_true = parse_labels_to_numeric(y_true);
    else
        y_true = double(y_true(:));
    end

    if iscategorical(y_pred) || iscell(y_pred) || isstring(y_pred)
        y_pred = parse_labels_to_numeric(y_pred);
    else
        y_pred = double(y_pred(:));
    end

    N = length(y_true);
    num_classes = 5; % DR Grades 0, 1, 2, 3, 4

    if N == 0
        metrics.accuracy = 0.0;
        metrics.confusion_matrix = zeros(num_classes, num_classes);
        metrics.per_class.sensitivity = zeros(num_classes, 1);
        metrics.per_class.specificity = zeros(num_classes, 1);
        metrics.per_class.precision   = zeros(num_classes, 1);
        metrics.per_class.f1_score    = zeros(num_classes, 1);
        metrics.macro_sensitivity = 0.0;
        metrics.macro_specificity = 0.0;
        metrics.macro_precision   = 0.0;
        metrics.macro_f1_score    = 0.0;
        metrics.quadratic_weighted_kappa = 0.0;
        metrics.cohen_kappa = 0.0;
        metrics.referable_dr.sensitivity = 0.0;
        metrics.referable_dr.specificity = 0.0;
        metrics.referable_dr.accuracy    = 0.0;
        metrics.referable_dr.f1_score    = 0.0;
        metrics.per_class.auc_roc = [];
        metrics.macro_auc_roc = NaN;
        return;
    end

    % 1. Overall Accuracy
    metrics.accuracy = safe_div(sum(y_true == y_pred), N);

    % 2. Multi-class Confusion Matrix (5x5)
    cm = zeros(num_classes, num_classes);
    for i = 1:N
        if y_true(i) >= 0 && y_true(i) < num_classes && y_pred(i) >= 0 && y_pred(i) < num_classes
            r = round(y_true(i)) + 1;
            c = round(y_pred(i)) + 1;
            cm(r, c) = cm(r, c) + 1;
        end
    end
    metrics.confusion_matrix = cm;

    % 3. Per-Class Sensitivity, Specificity, Precision, F1
    sens = zeros(num_classes, 1);
    spec = zeros(num_classes, 1);
    prec = zeros(num_classes, 1);
    f1   = zeros(num_classes, 1);

    for c = 1:num_classes
        tp = cm(c, c);
        fn = sum(cm(c, :)) - tp;
        fp = sum(cm(:, c)) - tp;
        tn = sum(cm(:)) - (tp + fn + fp);

        sens(c) = safe_div(tp, (tp + fn));
        spec(c) = safe_div(tn, (tn + fp));
        prec(c) = safe_div(tp, (tp + fp));
        
        if (prec(c) + sens(c)) == 0
            f1(c) = 0.0;
        else
            f1(c) = (2 * prec(c) * sens(c)) / (prec(c) + sens(c));
        end
    end

    metrics.per_class.sensitivity = sens;
    metrics.per_class.specificity = spec;
    metrics.per_class.precision   = prec;
    metrics.per_class.f1_score    = f1;

    metrics.macro_sensitivity = mean(sens);
    metrics.macro_specificity = mean(spec);
    metrics.macro_precision   = mean(prec);
    metrics.macro_f1_score    = mean(f1);

    % 4. Quadratic Weighted Kappa (QWK)
    metrics.quadratic_weighted_kappa = compute_qwk(cm, num_classes);

    % 5. Standard Cohen's Kappa
    metrics.cohen_kappa = compute_cohen_kappa(cm);

    % 6. Binary Referable DR Screening (Referable DR = Grade >= 2)
    ref_true = (y_true >= 2);
    ref_pred = (y_pred >= 2);
    ref_tp = sum(ref_true & ref_pred);
    ref_fn = sum(ref_true & ~ref_pred);
    ref_fp = sum(~ref_true & ref_pred);
    ref_tn = sum(~ref_true & ~ref_pred);

    metrics.referable_dr.sensitivity = safe_div(ref_tp, (ref_tp + ref_fn));
    metrics.referable_dr.specificity = safe_div(ref_tn, (ref_tn + ref_fp));
    metrics.referable_dr.accuracy    = safe_div((ref_tp + ref_tn), N);
    
    if (2 * ref_tp + ref_fp + ref_fn) == 0
        metrics.referable_dr.f1_score = 0.0;
    else
        metrics.referable_dr.f1_score = (2 * ref_tp) / (2 * ref_tp + ref_fp + ref_fn);
    end

    % 7. Multiclass AUC-ROC (One-vs-Rest)
    if nargin >= 3 && ~isempty(y_prob) && size(y_prob, 1) == N && size(y_prob, 2) == num_classes
        auc_vals = zeros(num_classes, 1);
        for c = 1:num_classes
            binary_true = (y_true == (c - 1));
            scores = y_prob(:, c);
            auc_vals(c) = compute_binary_auc(binary_true, scores);
        end
        metrics.per_class.auc_roc = auc_vals;
        metrics.macro_auc_roc = mean(auc_vals);
    else
        metrics.per_class.auc_roc = [];
        metrics.macro_auc_roc = NaN;
    end
end

function num_labels = parse_labels_to_numeric(labels)
    N = length(labels);
    num_labels = zeros(N, 1);
    for i = 1:N
        if iscell(labels)
            val = labels{i};
        elseif iscategorical(labels)
            val = char(labels(i));
        elseif isstring(labels)
            val = char(labels(i));
        else
            val = labels(i);
        end

        if isnumeric(val)
            num_labels(i) = double(val);
        else
            str_val = lower(strtrim(char(val)));
            switch str_val
                case {'0', 'no dr', 'normal', 'none', 'grade 0'}
                    num_labels(i) = 0;
                case {'1', 'mild', 'mild npdr', 'grade 1'}
                    num_labels(i) = 1;
                case {'2', 'moderate', 'moderate npdr', 'grade 2'}
                    num_labels(i) = 2;
                case {'3', 'severe', 'severe npdr', 'grade 3'}
                    num_labels(i) = 3;
                case {'4', 'pdr', 'proliferative', 'proliferative dr', 'grade 4'}
                    num_labels(i) = 4;
                otherwise
                    num_labels(i) = str2double(str_val);
                    if isnan(num_labels(i))
                        num_labels(i) = 0;
                    end
            end
        end
    end
end

function val = safe_div(num, denom)
    if denom == 0
        val = 0.0;
    else
        val = double(num) / double(denom);
    end
end

function qwk = compute_qwk(cm, num_classes)
    N = sum(cm(:));
    if N == 0
        qwk = 0.0;
        return;
    end
    
    % Weight matrix
    w = zeros(num_classes, num_classes);
    for i = 1:num_classes
        for j = 1:num_classes
            w(i, j) = ((i - j)^2) / ((num_classes - 1)^2);
        end
    end
    
    % Expected matrix
    row_sums = sum(cm, 2);
    col_sums = sum(cm, 1);
    expected = (row_sums * col_sums) / N;
    
    num = sum(sum(w .* cm));
    denom = sum(sum(w .* expected));
    
    if denom == 0
        qwk = 1.0;
    else
        qwk = 1.0 - (num / denom);
    end
end

function kappa = compute_cohen_kappa(cm)
    N = sum(cm(:));
    if N == 0
        kappa = 0.0;
        return;
    end
    po = sum(diag(cm)) / N;
    row_sums = sum(cm, 2);
    col_sums = sum(cm, 1);
    pe = sum(row_sums .* col_sums') / (N * N);
    if (1 - pe) == 0
        kappa = 1.0;
    else
        kappa = (po - pe) / (1 - pe);
    end
end

function auc = compute_binary_auc(y_true, scores)
    y_true = y_true(:);
    scores = scores(:);
    
    pos_count = sum(y_true == 1);
    neg_count = sum(y_true == 0);
    
    if pos_count == 0 || neg_count == 0
        auc = 0.5;
        return;
    end

    [sorted_scores, idx] = sort(scores, 'descend');
    sorted_labels = y_true(idx);
    
    tp = cumsum(sorted_labels == 1);
    fp = cumsum(sorted_labels == 0);
    
    tpr = [0; tp / pos_count; 1];
    fpr = [0; fp / neg_count; 1];
    
    auc = trapz(fpr, tpr);
    auc = max(0.0, min(1.0, auc));
end

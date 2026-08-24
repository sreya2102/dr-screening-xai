function img = preprocessImage(img)
% PREPROCESSIMAGE Crops black borders, pads to a square to preserve aspect
% ratio, resizes to 224x224, and normalizes using ImageNet statistics.
%
% Inputs:
%   img - RGB image (uint8 or double, any size)
% Outputs:
%   img - Preprocessed single-precision 224x224x3 image tensor

    % Convert input image to double in [0, 1] range
    img = double(img);
    if max(img(:)) > 1.0
        img = img / 255.0;
    end

    % Ensure 3 color channels
    [h, w, c] = size(img);
    if c == 1
        img = cat(3, img, img, img);
    elseif c > 3
        img = img(:, :, 1:3);
    end

    % 1. Crop black margins
    % Convert to grayscale for thresholding
    gray = img(:, :, 1) * 0.2989 + img(:, :, 2) * 0.5870 + img(:, :, 3) * 0.1140;
    mask = gray > 0.05;
    [rows, cols] = find(mask);
    
    if ~isempty(rows) && ~isempty(cols)
        minRow = min(rows);
        maxRow = max(rows);
        minCol = min(cols);
        maxCol = max(cols);
        img = img(minRow:maxRow, minCol:maxCol, :);
    end

    % 2. Pad to square to preserve aspect ratio
    [h, w, ~] = size(img);
    if h > w
        padTotal = h - w;
        padLeft = floor(padTotal / 2);
        padRight = padTotal - padLeft;
        img = padarray(img, [0, padLeft, 0], 0, 'pre');
        img = padarray(img, [0, padRight, 0], 0, 'post');
    elseif w > h
        padTotal = w - h;
        padTop = floor(padTotal / 2);
        padBottom = padTotal - padTop;
        img = padarray(img, [padTop, 0, 0], 0, 'pre');
        img = padarray(img, [padBottom, 0, 0], 0, 'post');
    end

    % 3. Resize to 224x224
    img = imresize(img, [224, 224]);

    % 4. Normalization (ImageNet mean and std dev)
    meanVal = reshape([0.485, 0.456, 0.406], [1, 1, 3]);
    stdVal = reshape([0.229, 0.224, 0.225], [1, 1, 3]);
    img = (img - meanVal) ./ stdVal;

    % 5. Convert to single precision
    img = single(img);
end

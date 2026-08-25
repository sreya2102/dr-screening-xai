function generateDummyDataset(dataFolder, numImagesPerClass)
% GENERATEDUMMYDATASET Generates synthetic fundus images for each of the 
% 5 DR severity grades (0 to 4) for tests and pipeline validation.
%
% Inputs:
%   dataFolder        - Path to store the generated dataset (default: data/dummy)
%   numImagesPerClass - Number of images to generate per grade (default: 5)

    if nargin < 1 || isempty(dataFolder)
        srcDir = fileparts(mfilename('fullpath'));
        moduleRoot = fileparts(srcDir);
        dataFolder = fullfile(moduleRoot, 'data', 'dummy');
    end
    if nargin < 2 || isempty(numImagesPerClass)
        numImagesPerClass = 5;
    end
    
    % Seed random generator for reproducibility
    rng(42);
    
    % Create directories for each class folder (0 to 4)
    for c = 0:4
        classFolder = fullfile(dataFolder, num2str(c));
        if ~exist(classFolder, 'dir')
            mkdir(classFolder);
        end
    end
    
    % Generate images for each class
    for c = 0:4
        classFolder = fullfile(dataFolder, num2str(c));
        for i = 1:numImagesPerClass
            % Generate base black canvas
            img = zeros(256, 256, 3, 'uint8');
            
            % Compute grid coordinates and mask for circular fundus
            [X, Y] = meshgrid(1:256, 1:256);
            distFromCenter = sqrt((X - 128).^2 + (Y - 128).^2);
            fundusMask = distFromCenter <= 100;
            
            % Set base color of fundus (orange-red: [220, 100, 50])
            for ch = 1:3
                if ch == 1
                    imgVal = 220;
                elseif ch == 2
                    imgVal = 100;
                else
                    imgVal = 50;
                end
                % Add low-frequency shading representing light attenuation
                shading = 1.0 - 0.2 * (distFromCenter / 100).^2;
                imgChan = uint8(imgVal * shading .* fundusMask);
                img(:, :, ch) = imgChan;
            end
            
            % Add optic disc (warm yellow circle)
            discCenter = [128 + 40, 128 - 20];
            discMask = sqrt((X - discCenter(1)).^2 + (Y - discCenter(2)).^2) <= 15;
            discMask = discMask & fundusMask;
            imgR = img(:, :, 1); imgR(discMask) = 255; img(:, :, 1) = imgR;
            imgG = img(:, :, 2); imgG(discMask) = 255; img(:, :, 2) = imgG;
            imgB = img(:, :, 3); imgB(discMask) = 150; img(:, :, 3) = imgB;
            
            % Add blood vessels radiating from the optic disc
            for angle = 0:45:315
                rad = deg2rad(angle + randn()*10);
                xVal = discCenter(1);
                yVal = discCenter(2);
                for step = 1:80
                    xVal = xVal + cos(rad) * 1.0;
                    yVal = yVal + sin(rad) * 1.0;
                    ix = round(xVal);
                    iy = round(yVal);
                    if ix >= 1 && ix <= 256 && iy >= 1 && iy <= 256 && fundusMask(iy, ix)
                        % Draw dark red vessel pixel
                        img(iy, ix, 1) = 150;
                        img(iy, ix, 2) = 30;
                        img(iy, ix, 3) = 10;
                    end
                end
            end
            
            % Add class-specific lesions
            % Class 1: Microaneurysms (MAs) - small red dots
            if c >= 1
                numMAs = c * 5 + randi([0, 5]);
                for dot = 1:numMAs
                    rx = 128 + randi([-70, 70]);
                    ry = 128 + randi([-70, 70]);
                    if fundusMask(ry, rx)
                        img(ry-1:ry+1, rx-1:rx+1, 1) = 255;
                        img(ry-1:ry+1, rx-1:rx+1, 2) = 10;
                        img(ry-1:ry+1, rx-1:rx+1, 3) = 10;
                    end
                end
            end
            
            % Class 2: Exudates (EXs) - bright yellow blobs
            if c >= 2
                numEXs = (c - 1) * 3 + randi([0, 3]);
                for blob = 1:numEXs
                    bx = 128 + randi([-60, 60]);
                    by = 128 + randi([-60, 60]);
                    blobMask = sqrt((X - bx).^2 + (Y - by).^2) <= 3 + randi([0, 3]);
                    blobMask = blobMask & fundusMask;
                    imgR = img(:, :, 1); imgR(blobMask) = 250; img(:, :, 1) = imgR;
                    imgG = img(:, :, 2); imgG(blobMask) = 240; img(:, :, 2) = imgG;
                    imgB = img(:, :, 3); imgB(blobMask) = 180; img(:, :, 3) = imgB;
                end
            end
            
            % Class 3: Hemorrhages (HEs) - dark red blobs
            if c >= 3
                numHEs = (c - 2) * 2 + randi([0, 2]);
                for blob = 1:numHEs
                    bx = 128 + randi([-60, 60]);
                    by = 128 + randi([-60, 60]);
                    blobMask = sqrt((X - bx).^2 + (Y - by).^2) <= 6 + randi([0, 4]);
                    blobMask = blobMask & fundusMask;
                    imgR = img(:, :, 1); imgR(blobMask) = 160; img(:, :, 1) = imgR;
                    imgG = img(:, :, 2); imgG(blobMask) = 10;  img(:, :, 2) = imgG;
                    imgB = img(:, :, 3); imgB(blobMask) = 10;  img(:, :, 3) = imgB;
                end
            end
            
            % Class 4: Neovascularization (NV) - extra high-intensity branching lines
            if c >= 4
                for l = 1:3
                    bx = 128 + randi([-50, 50]);
                    by = 128 + randi([-50, 50]);
                    for step = 1:40
                        bx = bx + randn()*1.5;
                        by = by + randn()*1.5;
                        ix = round(bx);
                        iy = round(by);
                        if ix >= 2 && ix <= 255 && iy >= 2 && iy <= 255 && fundusMask(iy, ix)
                            img(iy-1:iy+1, ix-1:ix+1, 1) = 255;
                            img(iy-1:iy+1, ix-1:ix+1, 2) = 50;
                            img(iy-1:iy+1, ix-1:ix+1, 3) = 20;
                        end
                    end
                end
            end
            
            % Write image to directory
            filename = fullfile(classFolder, sprintf('img_%03d.png', i));
            imwrite(img, filename);
        end
    end
    fprintf('Successfully generated synthetic dataset under %s\n', dataFolder);
end

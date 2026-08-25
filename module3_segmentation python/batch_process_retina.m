function summaryTable = batch_process_retina(inputDir, outputDir, options)
% BATCH_PROCESS_RETINA Batch screening and segmentation engine for Module 3.
%
% Syntax:
%   summaryTable = batch_process_retina(inputDir, outputDir, options)
%
% Inputs:
%   inputDir  - Directory containing input retinal fundus images (*.jpg, *.png, *.tif)
%   outputDir - Directory where segmentation masks, overlays, and CSV reports will be saved
%   options   - (Optional) Struct with pipeline configuration
%
% Outputs:
%   summaryTable - MATLAB table containing extracted biomarkers for all processed eyes

    if nargin < 1 || isempty(inputDir)
        inputDir = fullfile(fileparts(mfilename('fullpath')), '..', 'demo_samples');
    end
    if nargin < 2 || isempty(outputDir)
        outputDir = fullfile(fileparts(mfilename('fullpath')), '..', 'results', 'segmentation');
    end
    if nargin < 3
        options = struct();
    end

    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    % Supported image extensions
    imgFiles = [dir(fullfile(inputDir, '*.jpg')); ...
                dir(fullfile(inputDir, '*.jpeg')); ...
                dir(fullfile(inputDir, '*.png')); ...
                dir(fullfile(inputDir, '*.tif')); ...
                dir(fullfile(inputDir, '*.tiff'))];

    numFiles = numel(imgFiles);
    fprintf('============================================================\n');
    fprintf('RetinaScan Module 3: Batch Screening Pipeline\n');
    fprintf('Found %d image(s) in %s\n', numFiles, inputDir);
    fprintf('Output Directory: %s\n', outputDir);
    fprintf('============================================================\n\n');

    if numFiles == 0
        fprintf('No image files found in %s. Running with synthetic patient case.\n', inputDir);
        run_module3_demo();
        summaryTable = table();
        return;
    end

    % Preallocate results array
    records = cell(numFiles, 1);

    for i = 1:numFiles
        fileName = imgFiles(i).name;
        filePath = fullfile(inputDir, fileName);
        [~, baseName, ~] = fileparts(fileName);
        
        fprintf('[%d/%d] Processing: %s ... ', i, numFiles, fileName);
        
        try
            img = imread(filePath);
            [results, overlay] = segment_retina(img, options);
            
            % Save overlay image
            overlayPath = fullfile(outputDir, [baseName, '_overlay.png']);
            imwrite(overlay, overlayPath);
            
            % Save individual logical masks
            imwrite(uint8(results.vesselMask) * 255, fullfile(outputDir, [baseName, '_vessels.png']));
            imwrite(uint8(results.opticDiscMask) * 255, fullfile(outputDir, [baseName, '_optic_disc.png']));
            imwrite(uint8(results.lesionMask) * 255, fullfile(outputDir, [baseName, '_lesions.png']));
            
            f = results.features;
            rec = struct(...
                'ImageName', string(fileName), ...
                'VesselDensity', f.vesselDensity, ...
                'SkeletonLength', f.skeletonLength, ...
                'BranchPoints', f.branchPointCount, ...
                'MeanTortuosity', f.meanTortuosity, ...
                'MeanWidth', f.meanVesselWidth, ...
                'WidthCV', f.vesselWidthCV, ...
                'CDR', f.cupToDiscRatio, ...
                'ExudatesCount', f.exudateCount, ...
                'MicroaneurysmsCount', f.microaneurysmCount, ...
                'HemorrhagesCount', f.hemorrhageCount, ...
                'VesselAbnormalityScore', f.vesselAbnormalityScore, ...
                'Interpretation', string(results.vesselAnalysis.interpretation) ...
            );
            records{i} = rec;
            fprintf('DONE (Abnormality Score: %.1f)\n', f.vesselAbnormalityScore);
            
        catch ME
            fprintf('FAILED (%s)\n', ME.message);
            records{i} = struct('ImageName', string(fileName), 'Interpretation', "Error: " + string(ME.message));
        end
    end

    % Convert to table & export CSV
    summaryTable = struct2table(cell2mat(records(~cellfun(@isempty, records))));
    csvPath = fullfile(outputDir, 'screening_biomarkers_summary.csv');
    writetable(summaryTable, csvPath);
    
    fprintf('\n============================================================\n');
    fprintf('Batch Processing Complete!\n');
    fprintf('Summary CSV saved to: %s\n', csvPath);
    fprintf('============================================================\n');
end

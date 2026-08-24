function tests = test_module5
% TEST_MODULE5 Automated unit test suite for Module 5.
%
% Run in MATLAB using:
%   runtests('module5_explainability/tests/test_module5.m')

    tests = functiontests(localfunctions);
end

function testAllGradesExecution(testCase)
    % Test execution across DR grades 0 to 4
    for grade = 0:4
        data = create_mock_screening_data(grade, 'Good');
        out_dir = tempname;
        report = generate_report(data, out_dir);
        
        % Assertions
        verifyTrue(testCase, isstruct(report), 'Output must be a struct');
        verifyTrue(testCase, isfield(report, 'dr_grade'), 'Struct must contain dr_grade');
        verifyTrue(testCase, isfield(report, 'xai_maps'), 'Struct must contain xai_maps');
        verifyTrue(testCase, exist(report.report_files.html_path, 'file') == 2, 'HTML file must exist');
        verifyTrue(testCase, exist(report.report_files.summary_png_path, 'file') == 2, 'PNG canvas file must exist');
        verifyTrue(testCase, exist(report.report_files.mat_path, 'file') == 2, 'MAT data file must exist');
        
        % Clean up temp output dir
        if exist(out_dir, 'dir')
            rmdir(out_dir, 's');
        end
    end
end

function testIQARejectHandling(testCase)
    % Test quality rejection scenario
    data = create_mock_screening_data(2, 'Reject');
    out_dir = tempname;
    report = generate_report(data, out_dir);
    
    verifyEqual(testCase, report.iqa_status, 'Reject');
    verifyTrue(testCase, contains(report.clinical_text.diagnostic_summary, 'UNSATISFACTORY IMAGE QUALITY'), 'Summary must highlight quality issue');
    
    if exist(out_dir, 'dir')
        rmdir(out_dir, 's');
    end
end

function testLesionImportanceCalculation(testCase)
    % Test lesion weight calculation logic
    data = create_mock_screening_data(3, 'Good');
    dr_grade = data.dr_grading_result.predicted_grade;
    importance = compute_lesion_importance(data.segmentation_results, dr_grade);
    
    verifyTrue(testCase, isstruct(importance), 'Importance output must be struct');
    verifyGreaterThan(testCase, importance.total_lesions, 0, 'Total lesions for Grade 3 should be > 0');
end

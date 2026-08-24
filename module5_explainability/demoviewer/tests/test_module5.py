"""
Unit Test Suite for Module 5 DemoViewer.
Run using: python -m unittest module5_explainability/demoviewer/tests/test_module5.py
"""

import unittest
import tempfile
import os
import shutil
import sys

# Ensure demoviewer directory is in path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from create_mock_screening_data import create_mock_screening_data
from generate_report import generate_report
from compute_lesion_importance import compute_lesion_importance

class TestDemoViewer(unittest.TestCase):

    def test_all_grades_execution(self):
        for grade in range(5):
            data = create_mock_screening_data(dr_grade=grade, iqa_status='Good')
            out_dir = tempfile.mkdtemp()
            try:
                report = generate_report(data, out_dir)
                self.assertIsInstance(report, dict)
                self.assertIn('dr_grade', report)
                self.assertIn('xai_maps', report)
                self.assertTrue(os.path.exists(report['report_files']['html_path']))
                self.assertTrue(os.path.exists(report['report_files']['json_path']))
            finally:
                shutil.rmtree(out_dir, ignore_errors=True)

    def test_iqa_reject_handling(self):
        data = create_mock_screening_data(dr_grade=2, iqa_status='Reject')
        out_dir = tempfile.mkdtemp()
        try:
            report = generate_report(data, out_dir)
            self.assertEqual(report['iqa_status'], 'Reject')
            self.assertIn('UNSATISFACTORY IMAGE QUALITY', report['clinical_text']['diagnostic_summary'])
        finally:
            shutil.rmtree(out_dir, ignore_errors=True)

    def test_lesion_importance_calculation(self):
        data = create_mock_screening_data(dr_grade=3, iqa_status='Good')
        importance = compute_lesion_importance(data['segmentation_results'], dr_grade=3)
        self.assertIsInstance(importance, dict)
        self.assertGreater(importance['total_lesions'], 0)

if __name__ == '__main__':
    unittest.main()

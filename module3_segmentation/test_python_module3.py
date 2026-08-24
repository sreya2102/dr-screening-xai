"""
Module 3: Unit Tests (Python Implementation)
SIH 2026 - Problem Statement SIH260038
"""

import unittest
import numpy as np
from segment_retina import segment_retina
from segment_vessels import segment_vessels
from segment_optic_disc import segment_optic_disc
from segment_fovea import segment_fovea
from segment_lesions import segment_lesions
from analyze_vessels import analyze_vessels

class TestModule3(unittest.TestCase):

    def setUp(self):
        # Create test synthetic image
        self.H, self.W = 256, 256
        self.img = np.zeros((self.H, self.W, 3), dtype=np.uint8)
        self.img[30:220, 30:220, :] = [200, 80, 20]
        self.img[100:130, 80:110, :] = [240, 200, 100] # Disc

    def test_pipeline_execution(self):
        results, overlay = segment_retina(self.img)
        self.assertIsNotNone(results)
        self.assertEqual(overlay.shape, (self.H, self.W, 3))
        self.assertIn('features', results)
        self.assertIn('vesselAbnormalityScore', results['features'])
        score = results['features']['vesselAbnormalityScore']
        self.assertTrue(0.0 <= score <= 100.0)

    def test_vessel_segmentation(self):
        vessel_mask, skel, feats = segment_vessels(self.img)
        self.assertEqual(vessel_mask.shape, (self.H, self.W))
        self.assertEqual(vessel_mask.dtype, bool)
        self.assertIn('vesselDensity', feats)

    def test_optic_disc(self):
        od_mask, oc_mask, center, radius, conf, feats = segment_optic_disc(self.img)
        self.assertEqual(od_mask.shape, (self.H, self.W))
        self.assertTrue(0.0 <= feats['cupToDiscRatio'] <= 1.0)

    def test_lesions(self):
        od_mask = np.zeros((self.H, self.W), dtype=bool)
        vessel_mask = np.zeros((self.H, self.W), dtype=bool)
        ex, ma, he, comb, feats = segment_lesions(self.img, od_mask, vessel_mask)
        self.assertEqual(comb.shape, (self.H, self.W))
        self.assertIn('exudateCount', feats)

if __name__ == '__main__':
    unittest.main()

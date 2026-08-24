# Dataset Configuration & Attribution

## Primary Research Dataset: IDRiD (Indian Diabetic Retinopathy Image Dataset)
- **Dataset Name**: Indian Diabetic Retinopathy Image Dataset (IDRiD)
- **Official Source**: [https://idrid.grand-challenge.org/](https://idrid.grand-challenge.org/)
- **Attribution**: Porwal et al., "IDRiD: Indian Diabetic Retinopathy Image Dataset", IEEE Access, 2018.
- **Licensing & Terms**: Creative Commons Attribution 4.0 International (CC BY 4.0).
- **Download Instructions**:
  1. Access the official grand-challenge portal above.
  2. Download the testing/training fundus images and ground-truth segmentation masks (vessels, optic disc, exudates, microaneurysms, hemorrhages).
  3. Extract images into `data/idrid/` directory locally.

## SIH Dataset Check (SIH260038)
- **Status**: No official SIH dataset was bundled with Problem Statement SIH260038; IDRiD is used as the primary public research dataset.
- Note: External datasets are not redistributed in this Git repository. Place locally downloaded images into `demo_samples/` or `data/idrid/`.

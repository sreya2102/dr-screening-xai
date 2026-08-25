"""
Module 2: Image Enhancement - Standalone Python Demo Viewer
-------------------------------------------------------------
Diabetic Retinopathy Screening System (XAI)

Pipeline:
Input
  ↓
ROI Masking
  ↓
Illumination Correction
  ↓
Green Channel Extraction
  ↓
CLAHE
  ↓
Median Denoising
  ↓
Unsharp Sharpening
  ↓
RGB Reconstruction
  ↓
Enhanced Retinal Image
"""

import sys
import os
import time

import numpy as np
import cv2

import matplotlib
matplotlib.use("Agg")

import matplotlib.pyplot as plt


# ============================================================
# 1. ROI MASK CREATION
# ============================================================

def create_roi_mask(
    img_gray,
    min_coverage_pct=10.0,
    max_coverage_pct=95.0,
    default_radius_pct=0.45,
    threshold_factor=0.05
):
    """
    Extract retinal Field of View (FOV) mask.

    If automatic ROI detection produces a degenerate region,
    a conservative centered circular fallback is used.
    """

    if img_gray is None:
        raise ValueError("ROI input image is None.")

    if img_gray.ndim != 2:
        raise ValueError(
            f"ROI input must be grayscale 2D image. "
            f"Received shape: {img_gray.shape}"
        )

    H, W = img_gray.shape

    if H == 0 or W == 0:
        raise ValueError("Image has invalid dimensions.")

    total_pixels = H * W

    # Convert image to float [0, 1]
    img_float = img_gray.astype(np.float32)

    max_value = float(np.max(img_float))

    if max_value > 1.0:
        img_norm = img_float / 255.0
    else:
        img_norm = img_float

    img_norm = np.clip(img_norm, 0.0, 1.0)

    # --------------------------------------------------------
    # Step 1: Thresholding
    # --------------------------------------------------------

    thresh_val = max(
        float(threshold_factor),
        0.05 * float(img_norm.max())
    )

    binary_initial = (
        img_norm > thresh_val
    ).astype(np.uint8) * 255

    # --------------------------------------------------------
    # Step 2: Morphological Closing
    # --------------------------------------------------------

    se_size = max(
        3,
        int(0.01 * min(H, W))
    )

    # OpenCV requires odd kernel dimensions for many operations
    if se_size % 2 == 0:
        se_size += 1

    kernel = cv2.getStructuringElement(
        cv2.MORPH_ELLIPSE,
        (se_size, se_size)
    )

    binary_closed = cv2.morphologyEx(
        binary_initial,
        cv2.MORPH_CLOSE,
        kernel
    )

    # --------------------------------------------------------
    # Step 3: Morphological Opening
    # --------------------------------------------------------

    binary_clean = cv2.morphologyEx(
        binary_closed,
        cv2.MORPH_OPEN,
        kernel
    )

    # --------------------------------------------------------
    # Step 4: Largest Connected Component
    # --------------------------------------------------------

    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(
        binary_clean,
        connectivity=8
    )

    if num_labels > 1:

        areas = stats[1:, cv2.CC_STAT_AREA]

        largest_index = int(np.argmax(areas)) + 1

        roi_mask = labels == largest_index

    else:

        roi_mask = np.zeros(
            (H, W),
            dtype=bool
        )

    # --------------------------------------------------------
    # Step 5: ROI Coverage Check
    # --------------------------------------------------------

    coverage_pct = (
        100.0 *
        float(np.sum(roi_mask)) /
        float(total_pixels)
    )

    is_fallback = False
    warning_msg = ""

    if (
        coverage_pct < min_coverage_pct
        or coverage_pct > max_coverage_pct
    ):

        is_fallback = True

        warning_msg = (
            f"Degenerate ROI coverage "
            f"({coverage_pct:.2f}%). "
            f"Applied centered circular FOV fallback."
        )

        center_y = H / 2.0
        center_x = W / 2.0

        radius = (
            default_radius_pct *
            min(H, W)
        )

        Y, X = np.ogrid[:H, :W]

        roi_mask = (
            (X - center_x) ** 2 +
            (Y - center_y) ** 2
            <= radius ** 2
        )

    return (
        roi_mask.astype(bool),
        is_fallback,
        warning_msg,
        coverage_pct
    )


# ============================================================
# 2. ILLUMINATION CORRECTION
# ============================================================

def correct_illumination(
    img_rgb,
    roi_mask,
    sigma=30.0
):
    """
    Corrects uneven illumination using Gaussian
    background estimation.
    """

    if img_rgb.ndim != 3 or img_rgb.shape[2] != 3:
        raise ValueError(
            "Expected RGB image with shape (H, W, 3)."
        )

    H, W, C = img_rgb.shape

    img_float = (
        img_rgb.astype(np.float32) / 255.0
    )

    img_corrected = np.zeros_like(
        img_float,
        dtype=np.float32
    )

    # Calculate Gaussian kernel size
    kernel_size = int(
        2 * np.ceil(2 * sigma) + 1
    )

    if kernel_size < 3:
        kernel_size = 3

    if kernel_size % 2 == 0:
        kernel_size += 1

    for c in range(C):

        channel = img_float[:, :, c].copy()

        # Get ROI pixels
        roi_pixels = channel[roi_mask]

        if roi_pixels.size > 0:
            mean_val = float(
                np.mean(roi_pixels)
            )
        else:
            mean_val = float(
                np.mean(channel)
            )

        # Fill outside ROI with mean intensity
        channel_padded = channel.copy()

        channel_padded[~roi_mask] = mean_val

        # Estimate low-frequency illumination
        bg_estimated = cv2.GaussianBlur(
            channel_padded,
            (kernel_size, kernel_size),
            sigmaX=sigma,
            sigmaY=sigma
        )

        # Illumination correction
        corrected_c = (
            channel_padded
            - bg_estimated
            + mean_val
        )

        corrected_c = np.clip(
            corrected_c,
            0.0,
            1.0
        )

        # Remove outside ROI
        corrected_c[~roi_mask] = 0.0

        img_corrected[:, :, c] = corrected_c

    return (
        img_corrected * 255.0
    ).astype(np.uint8)


# ============================================================
# 3. CLAHE
# ============================================================

def apply_clahe(
    img_gray,
    roi_mask,
    clip_limit=2.0,
    tile_grid=(8, 8)
):
    """
    Applies CLAHE to the retinal ROI.
    """

    if img_gray.ndim != 2:
        raise ValueError(
            "CLAHE input must be grayscale."
        )

    if img_gray.dtype != np.uint8:
        img_gray = np.clip(
            img_gray,
            0,
            255
        ).astype(np.uint8)

    clahe = cv2.createCLAHE(
        clipLimit=float(clip_limit),
        tileGridSize=tile_grid
    )

    img_equalized = clahe.apply(
        img_gray
    )

    img_equalized[
        ~roi_mask
    ] = 0

    return img_equalized


# ============================================================
# 4. STRUCTURE ENHANCEMENT
# ============================================================

def enhance_structures(
    img_gray,
    roi_mask,
    denoise_kernel=3,
    sharpen_amount=0.5,
    sharpen_radius=1.0,
    sharpen_threshold=0.05
):
    """
    Step A: Median filtering
    Step B: Unsharp masking
    """

    # Ensure valid median kernel
    denoise_kernel = int(denoise_kernel)

    if denoise_kernel < 3:
        denoise_kernel = 3

    if denoise_kernel % 2 == 0:
        denoise_kernel += 1

    # --------------------------------------------------------
    # STEP A: Median Denoising
    # --------------------------------------------------------

    img_denoised = cv2.medianBlur(
        img_gray,
        denoise_kernel
    )

    # --------------------------------------------------------
    # STEP B: Unsharp Masking
    # --------------------------------------------------------

    blur_kernel = int(
        2 * np.ceil(2 * sharpen_radius) + 1
    )

    if blur_kernel < 3:
        blur_kernel = 3

    if blur_kernel % 2 == 0:
        blur_kernel += 1

    blurred = cv2.GaussianBlur(
        img_denoised,
        (blur_kernel, blur_kernel),
        sigmaX=sharpen_radius,
        sigmaY=sharpen_radius
    )

    # Difference between original and blurred image
    diff = (
        img_denoised.astype(np.float32)
        - blurred.astype(np.float32)
    )

    # Prevent amplification of very small differences
    threshold = (
        float(sharpen_threshold)
        * 255.0
    )

    mask_diff = (
        np.abs(diff) > threshold
    )

    diff[~mask_diff] = 0.0

    # Sharpen
    sharpened = (
        img_denoised.astype(np.float32)
        + float(sharpen_amount) * diff
    )

    sharpened = np.clip(
        sharpened,
        0.0,
        255.0
    ).astype(np.uint8)

    sharpened[~roi_mask] = 0

    return sharpened


# ============================================================
# 5. MAIN ENHANCEMENT PIPELINE
# ============================================================

def enhance_image(
    input_image,
    clip_limit=2.0,
    tile_grid=(8, 8),
    denoise_kernel=3,
    sharpen_amount=0.5
):
    """
    Main Module 2 enhancement pipeline.
    """

    start_time = time.time()

    metadata = {
        "status": "SUCCESS",
        "warnings": [],
        "techniques_applied": []
    }

    # --------------------------------------------------------
    # Stage 1: Load / Validate Image
    # --------------------------------------------------------

    if isinstance(input_image, str):

        if not os.path.isfile(input_image):
            raise FileNotFoundError(
                f"Image file not found:\n{input_image}"
            )

        img_bgr = cv2.imread(
            input_image,
            cv2.IMREAD_COLOR
        )

        if img_bgr is None:
            raise ValueError(
                f"OpenCV could not decode image:\n"
                f"{input_image}"
            )

        img_rgb = cv2.cvtColor(
            img_bgr,
            cv2.COLOR_BGR2RGB
        )

    else:

        img_rgb = np.asarray(
            input_image
        ).copy()

        # Handle grayscale input
        if img_rgb.ndim == 2:

            img_rgb = cv2.cvtColor(
                img_rgb.astype(np.uint8),
                cv2.COLOR_GRAY2RGB
            )

        # Handle RGBA input
        elif (
            img_rgb.ndim == 3
            and img_rgb.shape[2] == 4
        ):

            img_rgb = img_rgb[:, :, :3]

        if (
            img_rgb.ndim != 3
            or img_rgb.shape[2] != 3
        ):
            raise ValueError(
                "Input must have shape (H, W, 3). "
                f"Received: {img_rgb.shape}"
            )

        if img_rgb.dtype != np.uint8:

            if img_rgb.max() <= 1.0:

                img_rgb = (
                    img_rgb * 255.0
                ).astype(np.uint8)

            else:

                img_rgb = np.clip(
                    img_rgb,
                    0,
                    255
                ).astype(np.uint8)

    H, W, C = img_rgb.shape

    metadata["input_dimensions"] = (
        H,
        W,
        C
    )

    # --------------------------------------------------------
    # Stage 2: ROI Mask
    # --------------------------------------------------------

    green_raw = img_rgb[:, :, 1]

    (
        roi_mask,
        is_fallback,
        roi_warn,
        coverage_pct
    ) = create_roi_mask(
        green_raw
    )

    metadata["roi_coverage_pct"] = float(
        coverage_pct
    )

    metadata["roi_fallback_used"] = (
        is_fallback
    )

    metadata["techniques_applied"].append(
        "ROI_Masking"
    )

    if is_fallback:

        metadata["status"] = "WARNING"

        metadata["warnings"].append(
            roi_warn
        )

    # --------------------------------------------------------
    # Stage 3: Illumination Correction
    # --------------------------------------------------------

    img_illum = correct_illumination(
        img_rgb,
        roi_mask
    )

    metadata["techniques_applied"].append(
        "Illumination_Correction"
    )

    # --------------------------------------------------------
    # Stage 4: Green Channel + CLAHE
    # --------------------------------------------------------

    green_illum = img_illum[:, :, 1]

    green_clahe = apply_clahe(
        green_illum,
        roi_mask,
        clip_limit=clip_limit,
        tile_grid=tile_grid
    )

    metadata["techniques_applied"].append(
        "CLAHE"
    )

    # --------------------------------------------------------
    # Stage 5: Structure Enhancement
    # --------------------------------------------------------

    green_enhanced = enhance_structures(
        green_clahe,
        roi_mask,
        denoise_kernel=denoise_kernel,
        sharpen_amount=sharpen_amount
    )

    metadata["techniques_applied"].extend([
        "Median_Denoising",
        "Unsharp_Sharpening"
    ])

    # --------------------------------------------------------
    # Stage 6: RGB Reconstruction
    # --------------------------------------------------------

    green_base = (
        green_illum.astype(np.float32)
        + 1.0
    )

    enhancement_ratio = (
        green_enhanced.astype(np.float32)
        / green_base
    )

    # Prevent invalid numerical values
    enhancement_ratio = np.nan_to_num(
        enhancement_ratio,
        nan=1.0,
        posinf=1.0,
        neginf=1.0
    )

    enhanced_rgb = np.zeros_like(
        img_illum,
        dtype=np.uint8
    )

    for c in range(3):

        channel = (
            img_illum[:, :, c]
            .astype(np.float32)
        )

        enhanced_channel = (
            channel * enhancement_ratio
        )

        enhanced_channel[
            ~roi_mask
        ] = 0

        enhanced_rgb[:, :, c] = np.clip(
            enhanced_channel,
            0,
            255
        ).astype(np.uint8)

    metadata["output_dimensions"] = (
        enhanced_rgb.shape
    )

    metadata["execution_time_ms"] = (
        time.time() - start_time
    ) * 1000.0

    return (
        enhanced_rgb,
        green_enhanced,
        roi_mask,
        metadata,
        green_illum
    )


# ============================================================
# 6. SYNTHETIC FUNDUS IMAGE
# ============================================================

def generate_synthetic_fundus_phantom(
    H=512,
    W=512
):
    """
    Generates a synthetic retinal fundus image
    for testing when no real image is supplied.
    """

    Y, X = np.ogrid[:H, :W]

    center_y = H / 2.0
    center_x = W / 2.0

    radius = 0.42 * min(H, W)

    dist = np.sqrt(
        (X - center_x) ** 2
        + (Y - center_y) ** 2
    )

    mask_circle = dist <= radius

    # Avoid division by zero
    normalized_dist = (
        dist / max(radius, 1.0)
    )

    vignette = (
        1.0
        - 0.4 * normalized_dist ** 2
    )

    vignette = np.clip(
        vignette,
        0.0,
        1.0
    )

    vignette[
        ~mask_circle
    ] = 0.0

    # Base fundus channels
    r_base = 0.85 * vignette
    g_base = 0.45 * vignette
    b_base = 0.15 * vignette

    # Synthetic vessels
    vessel1 = (
        np.abs(
            Y - (
                center_y
                + 0.1
                * (
                    np.abs(X - center_x)
                    ** 1.2
                )
            )
        ) < 3.0
    ) & mask_circle

    vessel2 = (
        np.abs(
            X - (
                center_x
                + 0.15
                * (
                    np.abs(Y - center_y)
                    ** 1.1
                )
            )
        ) < 2.5
    ) & mask_circle

    vessels = vessel1 | vessel2

    g_base[vessels] *= 0.35
    r_base[vessels] *= 0.50

    # Add sensor noise
    noise = np.random.normal(
        0,
        0.02,
        (H, W)
    )

    r_base = np.clip(
        r_base + noise,
        0,
        1
    )

    g_base = np.clip(
        g_base + noise,
        0,
        1
    )

    b_base = np.clip(
        b_base + noise,
        0,
        1
    )

    r_base[~mask_circle] = 0
    g_base[~mask_circle] = 0
    b_base[~mask_circle] = 0

    img_rgb = np.stack(
        [
            (r_base * 255).astype(np.uint8),
            (g_base * 255).astype(np.uint8),
            (b_base * 255).astype(np.uint8)
        ],
        axis=-1
    )

    return img_rgb


# ============================================================
# 7. DEMO RUNNER
# ============================================================

def run_demo(input_path=None):

    print("=" * 70)
    print("       MODULE 2: IMAGE ENHANCEMENT DEMO")
    print("       Diabetic Retinopathy Screening System")
    print("=" * 70)

    # --------------------------------------------------------
    # Load image
    # --------------------------------------------------------

    if input_path:

        if not os.path.isfile(input_path):

            print(
                "\nERROR: Image file does not exist."
            )

            print(
                f"Path: {input_path}"
            )

            return

        print(
            f"\nLoading image:\n{input_path}"
        )

        try:

            img_bgr = cv2.imread(
                input_path,
                cv2.IMREAD_COLOR
            )

            if img_bgr is None:
                raise ValueError(
                    "OpenCV could not decode the image."
                )

            img_rgb = cv2.cvtColor(
                img_bgr,
                cv2.COLOR_BGR2RGB
            )

        except Exception as e:

            print(
                f"\nERROR while loading image: {e}"
            )

            return

    else:

        print(
            "\nNo image supplied."
        )

        print(
            "Generating synthetic fundus image..."
        )

        img_rgb = (
            generate_synthetic_fundus_phantom()
        )

    # --------------------------------------------------------
    # Run pipeline
    # --------------------------------------------------------

    try:

        (
            enhanced_rgb,
            green_enhanced,
            roi_mask,
            meta,
            green_illum
        ) = enhance_image(
            img_rgb
        )

    except Exception as e:

        print(
            "\nERROR during Module 2 processing:"
        )

        print(
            str(e)
        )

        return

    # --------------------------------------------------------
    # Diagnostics
    # --------------------------------------------------------

    print("\n--- Execution Diagnostics ---")

    print(
        f"Status              : "
        f"{meta['status']}"
    )

    print(
        f"Input Dimensions    : "
        f"{meta['input_dimensions']}"
    )

    print(
        f"Output Dimensions   : "
        f"{meta['output_dimensions']}"
    )

    print(
        f"ROI Coverage        : "
        f"{meta['roi_coverage_pct']:.2f}%"
    )

    print(
        f"ROI Fallback Used   : "
        f"{meta['roi_fallback_used']}"
    )

    print(
        f"Execution Time      : "
        f"{meta['execution_time_ms']:.2f} ms"
    )

    print(
        "Techniques Applied  :"
    )

    for technique in meta[
        "techniques_applied"
    ]:

        print(
            f"  - {technique}"
        )

    if meta["warnings"]:

        print("\nWarnings:")

        for warning in meta["warnings"]:

            print(
                f"  - {warning}"
            )

    # --------------------------------------------------------
    # Visualization
    # --------------------------------------------------------

    try:

        fig, axes = plt.subplots(
            2,
            3,
            figsize=(14, 9)
        )

        fig.suptitle(
            "Module 2: Image Enhancement Pipeline",
            fontsize=16,
            fontweight="bold"
        )

        # 1. Original
        axes[0, 0].imshow(
            img_rgb
        )

        axes[0, 0].set_title(
            "1. Original Fundus Image"
        )

        axes[0, 0].axis("off")

        # 2. ROI
        axes[0, 1].imshow(
            roi_mask,
            cmap="gray"
        )

        fallback_text = (
            " - Fallback"
            if meta["roi_fallback_used"]
            else ""
        )

        axes[0, 1].set_title(
            "2. Retinal ROI Mask"
            + fallback_text
        )

        axes[0, 1].axis("off")

        # 3. Illumination map
        axes[0, 2].imshow(
            green_illum,
            cmap="gray"
        )

        axes[0, 2].set_title(
            "3. Illumination-Corrected "
            "Green Channel"
        )

        axes[0, 2].axis("off")

        # 4. Enhanced green
        axes[1, 0].imshow(
            green_enhanced,
            cmap="gray"
        )

        axes[1, 0].set_title(
            "4. Enhanced Green Channel"
        )

        axes[1, 0].axis("off")

        # 5. Final RGB
        axes[1, 1].imshow(
            enhanced_rgb
        )

        axes[1, 1].set_title(
            "5. Final Enhanced RGB"
        )

        axes[1, 1].axis("off")

        # 6. Histogram
        original_green = (
            img_rgb[:, :, 1][roi_mask]
        )

        enhanced_green = (
            green_enhanced[roi_mask]
        )

        if original_green.size > 0:

            axes[1, 2].hist(
                original_green,
                bins=64,
                alpha=0.5,
                label="Original"
            )

        if enhanced_green.size > 0:

            axes[1, 2].hist(
                enhanced_green,
                bins=64,
                alpha=0.5,
                label="Enhanced"
            )

        axes[1, 2].set_title(
            "6. ROI Intensity Histogram"
        )

        axes[1, 2].set_xlabel(
            "Pixel Intensity"
        )

        axes[1, 2].set_ylabel(
            "Frequency"
        )

        axes[1, 2].legend()

        axes[1, 2].grid(
            True,
            linestyle="--",
            alpha=0.4
        )

        plt.tight_layout()

        output_png = os.path.join(
            os.path.dirname(
                os.path.abspath(__file__)
            ),
            "demo_output.png"
        )

        plt.savefig(
            output_png,
            dpi=150,
            bbox_inches="tight"
        )

        plt.close(fig)

        print(
            f"\nSUCCESS: Demo output saved to:"
        )

        print(
            output_png
        )

    except Exception as e:

        print(
            "\nERROR while generating visualization:"
        )

        print(
            str(e)
        )


# ============================================================
# 8. PROGRAM ENTRY POINT
# ============================================================

if __name__ == "__main__":

    image_arg = (
        sys.argv[1]
        if len(sys.argv) > 1
        else None
    )

    run_demo(
        image_arg
    )
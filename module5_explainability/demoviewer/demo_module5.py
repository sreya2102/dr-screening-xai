"""
Executable Demonstration Script for Module 5 DemoViewer (3-Step Interactive Workflow).
Run using: python module5_explainability/demoviewer/demo_module5.py
"""

import os
import sys
import webbrowser
from http.server import HTTPServer, SimpleHTTPRequestHandler

def main():
    print("=======================================================")
    print("  Module 5: 3-Step Interactive XAI Screening Workflow")
    print("=======================================================\n")

    script_dir = os.path.dirname(os.path.abspath(__file__))
    index_html_path = os.path.join(script_dir, "index.html")

    if not os.path.exists(index_html_path):
        print(f"Error: index.html not found at {index_html_path}")
        sys.exit(1)

    print("[Step 1] Initializing Interactive Web Application...")
    print(f"[Step 2] Opening 3-step screening interface in your web browser:")
    print(f"         {index_html_path}\n")

    # Open HTML directly in default browser
    webbrowser.open(f"file:///{index_html_path.replace(os.sep, '/')}")

    print("-------------------------------------------------------")
    print("  WORKFLOW STEPS READY IN YOUR BROWSER:")
    print("    Step 1: Patient & Screening Input (Upload Retina & Parameters)")
    print("    Step 2: XAI Analysis (Grad-CAM, Saliency & Lesion Overlays)")
    print("    Step 3: Clinical Report (Light-Theme, Download PDF, Export JSON)")
    print("=======================================================")

if __name__ == '__main__':
    main()

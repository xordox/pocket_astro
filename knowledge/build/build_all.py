#!/usr/bin/env python3
"""Rebuild every runtime KB asset, then recompile prediction.json.

    python3 knowledge/build/build_all.py

The two scanners that need PyMuPDF (build_catalog.py and extract_chapters.py)
are skipped unless the library venv is used:

    /Users/ambition/Desktop/astrology_ebooks/.venv/bin/python \
        knowledge/build/build_all.py --scan
"""
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]

# Order matters: build_degrees needs the extracted full text; compile last.
MODULES = [
    "build_ashtakavarga.py",
    "build_nakshatras.py",
    "build_planets.py",
    "build_houses.py",
    "build_yogas.py",
    "build_doshas.py",
    "build_dashas.py",
    "build_transits.py",
    "build_strength.py",
    "build_divisionals.py",
    "build_panchanga.py",
    "build_remedies.py",
    "build_interpretation.py",
    "build_degrees.py",
]
SCANNERS = ["build_catalog.py", "extract_chapters.py"]


def run(script, cwd=HERE):
    print(f"--- {script}")
    r = subprocess.run([sys.executable, str(cwd / script)], cwd=ROOT)
    if r.returncode != 0:
        sys.exit(f"{script} failed")


def main():
    if "--scan" in sys.argv:
        try:
            import fitz  # noqa: F401
        except ImportError:
            sys.exit("--scan needs PyMuPDF; run with the ebook library venv.")
        for s in SCANNERS:
            run(s)
    for m in MODULES:
        run(m)
    print("--- tool/compile_prediction_kb.py")
    r = subprocess.run([sys.executable, str(ROOT / "tool/compile_prediction_kb.py")], cwd=ROOT)
    if r.returncode != 0:
        sys.exit("compile_prediction_kb.py failed")
    print("\nDone. Verify with: flutter test test/kb_test.dart")


if __name__ == "__main__":
    main()

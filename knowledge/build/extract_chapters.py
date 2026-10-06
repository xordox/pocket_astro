#!/usr/bin/env python3
"""Extract the technical chapters the runtime KB was compiled from.

This is the reproducible provenance step: every table in `assets/kb/` traces
back to one of these extracts. Writes plain text into
`knowledge/extract/deep/`, one file per chapter.

Run with the PyMuPDF venv:
    /Users/ambition/Desktop/astrology_ebooks/.venv/bin/python extract_chapters.py
"""
import re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = Path("/Users/ambition/Desktop/astrology_ebooks")
OUT = ROOT / "knowledge/extract/deep"

try:
    import fitz  # PyMuPDF
except ImportError:
    sys.exit("PyMuPDF required: use /Users/ambition/Desktop/astrology_ebooks/.venv/bin/python")

CHARAK = "_OceanofPDF.com_Elements_of_Vedic_Astrology_-_Dr_K_S_charak.pdf"
SUTTON = "_OceanofPDF.com_The_Essentials_Of_Vedic_Astrology_-_Komilla_Sutton.pdf"
LEVACY = "_OceanofPDF.com_Beneath_a_Vedic_Sky_-_William_R_Levacy.pdf"
BRAHA = "_OceanofPDF.com_Ancient_Hindu_Astrology_for_the_Modern_Western_Astrologer_-_James_Braha.pdf"
DICARA = "_OceanofPDF.com_27_Stars_27_Gods_The_Astrological_Mythology_of_Ancient_India_-_Vic_DiCara.pdf"
HOULDING = "_OceanofPDF.com_Houses_-_Deborah_Houlding.pdf"
RUSHMAN = "_OceanofPDF.com_The_Art_of_Predictive_Astrology_Forecasting_Your_Life_Events_-_Carol_Rushman.pdf"
TOMPKINS = "_OceanofPDF.com_The_Contemporary_Astrologers_Handbook_-_Sue_Tompkins.pdf"
HILL = "_OceanofPDF.com_360_degrees_of_wisdom_-_Lynda_Hill.pdf"

# (pdf, first_page, last_page, output stem, what it feeds)
JOBS = [
    (CHARAK, 72, 106, "charak_05-07_signs_houses_planets", "houses.json, planets.json"),
    (CHARAK, 128, 155, "charak_10-11_vargas_subplanets", "divisionals.json"),
    (CHARAK, 156, 173, "charak_12-13_avastha_graha_bala", "strength.json"),
    (CHARAK, 174, 233, "charak_14-15_dashas_and_interpretation", "dashas.json"),
    (CHARAK, 234, 248, "charak_16_balarishta_arishta_bhanga", "doshas.json"),
    (CHARAK, 249, 262, "charak_17_lords_of_houses", "houses.json (144 lord-in-house cells)"),
    (CHARAK, 263, 277, "charak_18_planets_in_houses", "planets.json (in_house)"),
    (CHARAK, 278, 305, "charak_19_planets_in_signs", "planets.json (in_sign)"),
    (CHARAK, 306, 317, "charak_20_nabhasa_yogas", "yogas.json (32 nabhasa)"),
    (CHARAK, 318, 334, "charak_21_ownership_yogas", "yogas.json (raja, dhana, arishta, parivartana)"),
    (CHARAK, 335, 350, "charak_22_specific_yogas", "yogas.json (mahapurusha, chandra, ravi, misc)"),
    (CHARAK, 351, 367, "charak_23_longevity", "interpretation.json (refusal policy)"),
    (CHARAK, 368, 384, "charak_24_health_and_disease", "interpretation.json (health topic)"),
    (CHARAK, 385, 394, "charak_25_varshaphala", "not yet runtime"),
    (CHARAK, 395, 408, "charak_26_muhurta", "panchanga.json"),
    (CHARAK, 409, 421, "charak_27_matching", "ashtakoota.json, doshas.json"),
    (CHARAK, 429, 437, "charak_29_gochara", "transits.json (vedha + 12-house results)"),
    (CHARAK, 438, 452, "charak_30_ashtakavarga", "ashtakavarga.json (BAV tables)"),
    (CHARAK, 453, 462, "charak_31_sudarshana_chakra", "interpretation.json"),
    (SUTTON, 126, 165, "sutton_nakshatras", "nakshatras.json"),
    (SUTTON, 166, 200, "sutton_dashas_gochara_vargas", "dashas.json, divisionals.json"),
    (LEVACY, 350, 362, "levacy_16_remedial_measures", "remedies.json"),
    (LEVACY, 360, 400, "levacy_17_compatibility_and_transits", "transits.json, ashtakoota.json"),
    (BRAHA, 1, 60, "braha_front_and_method", "interpretation.json"),
    (DICARA, 1, 60, "dicara_nakshatra_myth_a", "nakshatras.json (deity, shakti)"),
    (DICARA, 60, 161, "dicara_nakshatra_myth_b", "nakshatras.json (deity, shakti)"),
    (HOULDING, 1, 80, "houlding_house_derivation", "houses.json"),
    (RUSHMAN, 1, 80, "rushman_transit_method", "transits.json (western stack)"),
    (TOMPKINS, 1, 60, "tompkins_aspects_and_synthesis", "interpretation.json"),
    (HILL, 1, 40, "hill_sabian_method", "degrees.json"),
]


def extract(pdf, a, b):
    doc = fitz.open(SRC / pdf)
    parts = []
    for i in range(a - 1, min(b, doc.page_count)):
        parts.append(f"\n<<<PAGE {i + 1}>>>\n" + doc[i].get_text("text"))
    doc.close()
    return re.sub(r"\n{3,}", "\n\n", "".join(parts))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    for pdf, a, b, stem, feeds in JOBS:
        if not (SRC / pdf).exists():
            print("skip (missing):", pdf)
            continue
        text = extract(pdf, a, b)
        header = (f"# source: {pdf}\n# pages: {a}-{b}\n"
                  f"# compiled into: {feeds}\n"
                  f"# regenerate: knowledge/build/extract_chapters.py\n\n")
        (OUT / f"{stem}.txt").write_text(header + text)
        manifest.append((stem, pdf, a, b, len(text), feeds))
        print(f"{stem}: {len(text):,} chars")
    lines = ["# Deep extracts — provenance for the compiled KB",
             "",
             "| extract | source PDF | pages | chars | compiled into |",
             "|---|---|---|---|---|"]
    for stem, pdf, a, b, n, feeds in manifest:
        lines.append(f"| `{stem}.txt` | {pdf} | {a}-{b} | {n:,} | {feeds} |")
    (OUT / "README.md").write_text("\n".join(lines) + "\n")
    print(f"\n{len(manifest)} extracts -> {OUT}")


if __name__ == "__main__":
    main()

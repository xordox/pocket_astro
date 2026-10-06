#!/usr/bin/env python3
"""Extract specific technical pages from core Vedic/Western PDFs."""
from pathlib import Path
import fitz

SRC = Path("/Users/ambition/Desktop/astrology_ebooks")
OUT = Path("/Users/ambition/flutter_projects/_pocketastro_extract/deep")
OUT.mkdir(parents=True, exist_ok=True)

JOBS = [
    ("_OceanofPDF.com_Elements_of_Vedic_Astrology_-_Dr_K_S_charak.pdf", {
        "intro_signs_houses": list(range(1, 12)) + list(range(40, 55)),
        "dasha": list(range(155, 185)),
        "house_lords_yogas": list(range(200, 230)),
        "matching": list(range(405, 425)),
        "transits_ashtaka": list(range(425, 450)),
        "health_longevity_muhurta": list(range(360, 400)),
    }),
    ("_OceanofPDF.com_Beneath_a_Vedic_Sky_-_William_R_Levacy.pdf", {
        "planets_signs_houses": list(range(36, 75)),
        "yogas": list(range(207, 232)),
        "nakshatras": list(range(229, 260)),
        "navamsa_predict": list(range(258, 315)),
        "gochara": list(range(307, 352)),
        "compatibility": list(range(358, 370)),
        "appendix": list(range(387, 412)),
    }),
    ("_OceanofPDF.com_Ancient_Hindu_Astrology_for_the_Modern_Western_Astrologer_-_James_Braha.pdf", {
        "front": list(range(1, 12)),
        "tech_a": list(range(20, 45)),
        "tech_b": list(range(60, 80)),
        "tech_c": list(range(155, 175)),
        "tech_d": list(range(250, 300)),
        "tech_e": list(range(340, 364)),
    }),
    ("_OceanofPDF.com_The_Essentials_Of_Vedic_Astrology_-_Komilla_Sutton.pdf", {
        "core": list(range(1, 90)),
        "later": list(range(90, 180)),
        "end": list(range(180, 239)),
    }),
    ("_OceanofPDF.com_27_Stars_27_Gods_The_Astrological_Mythology_of_Ancient_India_-_Vic_DiCara.pdf", {
        "intro": list(range(4, 10)),
        "interpret": list(range(148, 161)),
    }),
    ("_OceanofPDF.com_How_to_Be_an_Astrologer_-_Constance_Stellas.pdf", {
        "ingredients": list(range(10, 45)),
        "predict": list(range(126, 155)),
        "compat": list(range(152, 178)),
        "tables": list(range(280, 295)),
    }),
    ("_OceanofPDF.com_The_Art_of_Predictive_Astrology_Forecasting_Your_Life_Events_-_Carol_Rushman.pdf", {
        "front": list(range(1, 40)),
        "mid": list(range(70, 110)),
        "late": list(range(140, 180)),
        "end": list(range(210, 250)),
    }),
    ("_OceanofPDF.com_Houses_-_Deborah_Houlding.pdf", {
        "practice": list(range(74, 104)),
        "index": list(range(171, 194)),
    }),
    ("_OceanofPDF.com_The_astrology_of_human_relationships_-_Frances_Sakoian.pdf", {
        "rules": list(range(10, 70)),
    }),
    ("The_Secret_Language_of_Relationships_repaired.pdf", {
        "front": list(range(1, 25)),
        "method": list(range(25, 50)),
    }),
    ("_OceanofPDF.com_The_Contemporary_Astrologers_Handbook_-_Sue_Tompkins.pdf", {
        "elements": list(range(26, 42)),
        "aspects": list(range(328, 375)),
        "houses": list(range(370, 420)),
        "synth": list(range(435, 450)),
    }),
]


def grab(pdf_name, pages):
    path = SRC / pdf_name
    doc = fitz.open(path)
    n = doc.page_count
    chunks = []
    for i in pages:
        if i < 1 or i > n:
            continue
        t = doc.load_page(i - 1).get_text("text") or ""
        t = t.strip()
        if not t:
            continue
        chunks.append("\n\n===== PAGE %d / %d =====\n\n%s" % (i, n, t[:8000]))
    doc.close()
    return "\n".join(chunks)


def main():
    for pdf, groups in JOBS:
        print("FILE", pdf[:70], flush=True)
        for gname, pages in groups.items():
            text = grab(pdf, pages)
            safe = pdf.replace(".pdf", "")[:50]
            out = OUT / ("%s__%s.txt" % (safe, gname))
            out.write_text(text, encoding="utf-8")
            print("  wrote", out.name, "chars", len(text), flush=True)


if __name__ == "__main__":
    main()

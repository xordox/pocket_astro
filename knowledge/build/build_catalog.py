#!/usr/bin/env python3
"""Re-scan every PDF in the ebook library and rebuild the source catalog.

The original scan sampled pages; this one extracts every page, so `text_chars`
is the true extractable-text volume and `image_like` is reliable.

Run with the PyMuPDF venv:
    /Users/ambition/Desktop/astrology_ebooks/.venv/bin/python build_catalog.py
"""
import json, os, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = Path("/Users/ambition/Desktop/astrology_ebooks")

try:
    import fitz  # PyMuPDF
except ImportError:
    sys.exit("PyMuPDF required: use /Users/ambition/Desktop/astrology_ebooks/.venv/bin/python")

ROLE_RULES = [
    (("charak", "elements_of_vedic"), "vedic_core"),
    (("braha", "ancient_hindu"), "vedic_core"),
    (("sutton", "essentials_of_vedic"), "vedic_core"),
    (("levacy", "beneath_a_vedic"), "vedic_core"),
    (("27_stars", "dicara"), "nakshatra"),
    (("rushman", "predictive"), "western_predict"),
    (("houlding", "_houses_"), "houses"),
    (("tompkins", "contemporary"), "western_natal"),
    (("sakoian", "human_relationships"), "synastry"),
    (("360_degrees", "lynda_hill"), "degrees"),
    (("how_to_be_an_astrologer",), "western_predict"),
    (("secret_language_of_relationships", "cosmic_coupling", "astrology_of_you_and_me",
      "sextrology", "love_sex", "sexual_astrology", "erotic_astrology",
      "astrology_of_love_and_sex", "astrologically_incorrect", "star_crossed",
      "love_on_a_rotten_day"), "relationship"),
    (("financial_universe",), "financial"),
    (("body_astrology", "self-care", "self_care", "moon_book", "luna"), "wellbeing"),
    (("natal_reading", "vedic_prediction", "questions_answered", "questions_simple",
      "complete_life", "home_and_money", "life_questions", "psychology_in_depth",
      "start_now"), "method_template"),
]

# What each source actually contributed to the compiled runtime KB.
CONTRIBUTION = {
    "vedic_core": ["planets", "houses", "yogas", "doshas", "dashas", "transits",
                   "ashtakavarga", "strength", "divisionals", "panchanga", "interpretation"],
    "nakshatra": ["nakshatras"],
    "degrees": ["degrees"],
    "houses": ["houses"],
    "western_predict": ["transits", "interpretation"],
    "western_natal": ["planets", "interpretation"],
    "synastry": ["interpretation"],
    "relationship": [],
    "financial": [],
    "wellbeing": [],
    "method_template": ["interpretation"],
    "support": [],
}


def role_for(name):
    n = name.lower()
    for keys, role in ROLE_RULES:
        if any(k in n for k in keys):
            return role
    return "support"


records = []
for f in sorted(os.listdir(SRC)):
    if not f.lower().endswith(".pdf"):
        continue
    rec = {"file": f, "size_bytes": (SRC / f).stat().st_size}
    try:
        doc = fitz.open(SRC / f)
    except Exception as exc:  # noqa: BLE001 - catalog must not abort on one file
        rec.update(pages=None, error=str(exc), text_chars=0, image_like=None, toc=[])
        records.append(rec)
        continue
    chars = 0
    for page in doc:
        chars += len(page.get_text("text"))
    toc = [{"level": lv, "title": ti, "page": pg} for lv, ti, pg in doc.get_toc()]
    role = role_for(f)
    rec.update(
        pages=doc.page_count,
        error=None,
        text_chars=chars,
        chars_per_page=round(chars / doc.page_count, 1) if doc.page_count else 0,
        image_like=chars < 200,
        scan_mode="full_text",
        role=role,
        contributes_to=CONTRIBUTION.get(role, []),
        has_toc=bool(toc),
        toc=toc[:80],
    )
    doc.close()
    records.append(rec)

extractable = [r for r in records if not r.get("image_like")]
DOC = {
    "engine": "pocketastro-catalog",
    "version": 2,
    "library_path": str(SRC),
    "pdf_count": len(records),
    "extractable_count": len(extractable),
    "image_only": [r["file"] for r in records if r.get("image_like")],
    "total_pages": sum(r.get("pages") or 0 for r in records),
    "total_text_chars": sum(r.get("text_chars") or 0 for r in records),
    "scan": "full text of every page (PyMuPDF), not a page sample",
    "sources": records,
}

(ROOT / "knowledge/extract/_catalog_full.json").write_text(
    json.dumps(DOC, indent=1, ensure_ascii=False) + "\n")
# Keep the flat list shape that tool/compile_prediction_kb.py consumes.
(ROOT / "knowledge/extract/_catalog.json").write_text(
    json.dumps(records, indent=1, ensure_ascii=False) + "\n")
(ROOT / "assets/kb/catalog.json").write_text(
    json.dumps(DOC, indent=1, ensure_ascii=False) + "\n")
print(f"{len(records)} PDFs, {DOC['total_pages']} pages, "
      f"{DOC['total_text_chars']:,} chars, "
      f"{len(DOC['image_only'])} image-only")

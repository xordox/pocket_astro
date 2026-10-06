#!/usr/bin/env python3
"""360 zodiacal degree symbols (Sabian symbols) with keywords and cautions.

Extracted from Lynda Hill, *360 Degrees of Wisdom* (the Marc Edmund Jones /
Elsie Wheeler Sabian symbols with Hill's commentary). One entry per tropical
degree; degree N covers longitude (N-1, N].

These are a TROPICAL-zodiac layer. PocketAstro applies them to tropical
longitudes only and labels them as the Western stack, never as Jyotisha.
"""
import json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PDF = Path("/Users/ambition/Desktop/astrology_ebooks/"
           "_OceanofPDF.com_360_degrees_of_wisdom_-_Lynda_Hill.pdf")
CACHE = ROOT / "knowledge/extract/deep/hill_360_degrees_fulltext.txt"
OUT_ASSET = ROOT / "assets/kb/degrees.json"
SIGNS = ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
         "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"]


def source_text():
    """Page-marked full text of the Hill PDF, cached next to the extracts."""
    if CACHE.exists():
        return CACHE.read_text()
    try:
        import fitz  # PyMuPDF
    except ImportError:
        sys.exit(
            "No cached text at knowledge/extract/deep/hill_360_degrees_fulltext.txt "
            "and PyMuPDF is unavailable. Re-run with the ebook library venv:\n"
            "  /Users/ambition/Desktop/astrology_ebooks/.venv/bin/python "
            "knowledge/build/build_degrees.py"
        )
    if not PDF.exists():
        sys.exit(f"Source PDF not found: {PDF}")
    doc = fitz.open(PDF)
    parts = [f"\n<<<PAGE {i + 1}>>>\n" + doc[i].get_text("text")
             for i in range(doc.page_count)]
    doc.close()
    text = "".join(parts)
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    CACHE.write_text(text)
    return text

def _titlecase(s):
    """Caps-lock source text -> readable title case, without mangling apostrophes."""
    s = re.sub(r"([,.;:!?])(?=[^\s])", r"\1 ", s)          # missing space after punctuation
    s = re.sub(r"\s+", " ", s).strip()
    small = {"a", "an", "and", "as", "at", "by", "for", "from", "in", "into", "of",
             "on", "or", "the", "to", "with", "its", "his", "her", "their"}
    words = s.lower().split(" ")
    out = []
    for i, w in enumerate(words):
        core = w.strip("\u2018\u2019'\"")
        if i > 0 and core in small:
            out.append(w)
        else:
            out.append(w[:1].upper() + w[1:])
    return " ".join(out)


text = source_text()
parts = re.split(r"<<<PAGE (\d+)>>>", text)
pages = [(int(parts[i]), parts[i + 1]) for i in range(1, len(parts) - 1, 2)]
deg_re = re.compile(r"\b(%s)\s+(\d{1,2})\s*$" % "|".join(SIGNS), re.M)

raw = {}
for idx, (num, txt) in enumerate(pages):
    if "SYMBOL say to you" not in txt:
        continue
    label = None
    for back in (1, 2):
        if idx - back >= 0:
            m = list(deg_re.finditer(pages[idx - back][1]))
            if m:
                label = (m[-1].group(1), int(m[-1].group(2)))
                break
    if not label:
        continue
    body = txt.split("SYMBOL say to you?", 1)[1]
    sym = []
    for line in body.splitlines():
        s = line.strip()
        if not s:
            continue
        if s.startswith("Commentary"):
            break
        if re.fullmatch(r"[A-Z0-9 ,'’\-\.\&\(\)/]+", s) and len(s) > 3:
            sym.append(s)
    if not sym:
        continue
    kw = re.search(r"Keywords:(.*?)(?:The Caution:|$)", body, re.S)
    ca = re.search(r"The Caution:(.*?)(?:\n[A-Z][a-z]|$)", body, re.S)
    # The degree label printed on the preceding page belongs to the PREVIOUS
    # symbol, so this page's symbol is one degree later.
    i = SIGNS.index(label[0]) * 30 + label[1] - 1 + 1
    if i >= 360:
        continue
    raw[i] = {
        "symbol": _titlecase(" ".join(" ".join(sym).split())),
        "keywords": " ".join(kw.group(1).split()) if kw else "",
        "caution": " ".join(ca.group(1).split())[:420] if ca else "",
    }

# Aries 1 is the one entry with no preceding degree label in the scan.
raw.setdefault(0, {
    "symbol": "A Woman Rises Out Of Water, A Seal Rises And Embraces Her",
    "keywords": "Emergence. Instinct meeting consciousness. A new cycle beginning. "
                "Being drawn back by what you came from.",
    "caution": "Being pulled under by old instincts just as something new begins.",
})

missing = [i for i in range(360) if i not in raw]
assert not missing, f"missing degrees: {missing}"

degrees = []
for i in range(360):
    r = raw[i]
    degrees.append({
        "index": i,
        "sign": SIGNS[i // 30],
        "degree": i % 30 + 1,
        "label": f"{SIGNS[i // 30]} {i % 30 + 1}",
        "from_lon": float(i),
        "to_lon": float(i + 1),
        "symbol": r["symbol"],
        "keywords": r["keywords"],
        "caution": r["caution"],
    })

DOC = {
    "engine": "pocketastro-degrees",
    "version": 1,
    "zodiac": "tropical",
    "source": "Lynda Hill, 360 Degrees of Wisdom (Sabian symbols of Marc Edmund Jones and Elsie Wheeler).",
    "usage": (
        "A degree symbol covers the whole degree: 0°00'-0°59' of Aries is 'Aries 1'. Round up, "
        "never down. Read the symbol of the tropical Ascendant, Sun, Moon and chart ruler for "
        "texture; it is a Western layer and is never mixed into a Jyotisha verdict."
    ),
    "caution": (
        "Degree symbols are evocative, not predictive. PocketAstro shows them as colour on a "
        "reading and never lets one raise or lower a forecast's confidence."
    ),
    "degrees": degrees,
}
for out in (ROOT / "assets/kb/degrees.json", ROOT / "knowledge/extract/degrees.json"):
    out.write_text(json.dumps(DOC, indent=1, ensure_ascii=False) + "\n")
print("degrees.json", len(json.dumps(DOC)), "bytes,", len(degrees), "degrees")

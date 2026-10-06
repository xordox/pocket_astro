#!/usr/bin/env python3
"""Fast scan of astrology PDFs: metadata, TOC, sampled text, technical pages."""
from __future__ import print_function
import json
import re
import sys
from pathlib import Path

import fitz

SRC = Path("/Users/ambition/Desktop/astrology_ebooks")
OUT = Path("/Users/ambition/flutter_projects/_pocketastro_extract")
OUT.mkdir(parents=True, exist_ok=True)

DEEP_KEYS = (
    "vedic", "hindu", "elements", "essentials", "beneath", "27_stars",
    "predictive", "houses", "only_astrology", "only_way", "relationships",
    "human_relationships", "natal", "questions", "complete_life",
    "psychology", "start_now", "home_and_money", "charak", "braha",
    "sutton", "levacy", "dicara", "360_degrees", "contemporary",
    "all_around", "astrology_-_carole", "how_to_be", "secrets_of_astrology",
    "love_and_sex", "you_and_me", "cosmic_coupling",
)

TECH_PAGE = re.compile(
    r"(nakshatra|vimshottari|dasha|ayanamsa|lahiri|ashtakoot|guna milan|"
    r"koota milan|nadi dosha|bhakoot|mangal dosha|kuja dosha|navamsa|"
    r"shadbala|gochara|sade.?sati|whole.?sign|placidus|sabian|"
    r"secondary progress|solar return|synastry|composite|"
    r"exaltation|debilitation|yogakaraka|drishti|divisional)",
    re.I,
)


def stem_name(name):
    return re.sub(r"[^A-Za-z0-9._-]+", "_", name)[:90]


def page_text(doc, i):
    try:
        return doc.load_page(i).get_text("text") or ""
    except Exception:
        return ""


def sample_indices(n, want):
    if n <= want:
        return list(range(n))
    # front, middle, back
    idxs = set(range(min(6, n)))
    idxs.update(range(max(0, n - 3), n))
    step = max(1, n // (want - 9))
    for i in range(6, n - 3, step):
        idxs.add(i)
        if len(idxs) >= want:
            break
    return sorted(idxs)


def extract_one(path):
    rec = {
        "file": path.name,
        "size_bytes": path.stat().st_size,
        "error": None,
        "pages": 0,
        "toc": [],
        "metadata": {},
        "is_small": False,
        "deep": False,
        "text_chars": 0,
        "image_like": False,
        "samples": [],
        "tech_pages": [],
        "full_text": None,
    }
    doc = fitz.open(path)
    rec["pages"] = doc.page_count
    rec["metadata"] = doc.metadata or {}
    toc = doc.get_toc(simple=True) or []
    rec["toc"] = [{"level": a, "title": str(b)[:180], "page": c} for a, b, c in toc[:120]]
    rec["is_small"] = rec["size_bytes"] < 120_000 or rec["pages"] <= 25
    name_l = path.name.lower()
    rec["deep"] = any(k in name_l for k in DEEP_KEYS)

    if rec["is_small"]:
        buf = []
        total = 0
        for i in range(doc.page_count):
            t = page_text(doc, i)
            total += len(t)
            buf.append("\n\n===== PAGE %d =====\n\n%s" % (i + 1, t))
        rec["full_text"] = "".join(buf)
        rec["text_chars"] = total
        doc.close()
        return rec

    want = 48 if rec["deep"] else 18
    idxs = sample_indices(doc.page_count, want)
    total = 0
    nonempty = 0
    for i in idxs:
        t = page_text(doc, i)
        total += len(t)
        if t.strip():
            nonempty += 1
        rec["samples"].append({"page": i + 1, "text": t[:3500]})

    rec["text_chars"] = total
    rec["image_like"] = nonempty < max(2, len(idxs) // 4)

    # Hunt a few extra technical pages (skip if image-like)
    if rec["deep"] and not rec["image_like"]:
        found = 0
        step = max(1, doc.page_count // 80)
        for i in range(0, doc.page_count, step):
            if found >= 18:
                break
            t = page_text(doc, i)
            if TECH_PAGE.search(t or ""):
                rec["tech_pages"].append({"page": i + 1, "text": t[:4500]})
                found += 1

    doc.close()
    return rec


def main():
    pdfs = sorted(SRC.glob("*.pdf"))
    print("Found %d PDFs" % len(pdfs), flush=True)
    catalog = []
    for p in pdfs:
        try:
            rec = extract_one(p)
            print(
                "OK %-72s pages=%4d deep=%s small=%s chars=%d img=%s toc=%d"
                % (
                    p.name[:72],
                    rec["pages"],
                    rec["deep"],
                    rec["is_small"],
                    rec["text_chars"],
                    rec["image_like"],
                    len(rec["toc"]),
                ),
                flush=True,
            )
        except Exception as e:
            rec = {"file": p.name, "size_bytes": p.stat().st_size, "error": str(e)}
            print("ERR %s: %s" % (p.name, e), flush=True)
        outp = OUT / (stem_name(p.name) + ".json")
        with open(outp, "w", encoding="utf-8") as f:
            json.dump(rec, f, ensure_ascii=False, indent=2)
        slim = {k: rec.get(k) for k in (
            "file", "size_bytes", "pages", "error", "is_small", "deep",
            "text_chars", "image_like", "toc",
        )}
        slim["toc"] = rec.get("toc", [])[:40]
        catalog.append(slim)

    with open(OUT / "_catalog.json", "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
    print("DONE", len(catalog), "files", flush=True)


if __name__ == "__main__":
    main()

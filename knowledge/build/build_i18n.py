#!/usr/bin/env python3
"""Translation tooling for the knowledge base and the engine string table.

The English knowledge base in `assets/kb/` is the single structural truth. A
locale adds `assets/kb/i18n/<locale>/<module>.json` carrying the *same key
paths* with translated leaf strings. At load time the app deep-merges the
overlay onto the base, so:

* an overlay can never add a key, change a number, or alter the shape the
  engine reads — it translates text and nothing else;
* a partial translation is not a broken app: every key the overlay omits keeps
  its English text, which is more useful to a reader than a blank.

That makes partial translation safe, and this script makes it *visible*.

    python3 knowledge/build/build_i18n.py                  # coverage report
    python3 knowledge/build/build_i18n.py --skeleton ne    # writeable stubs
    python3 knowledge/build/build_i18n.py --check          # CI gate

`--skeleton` writes every untranslated string into the overlay prefixed with
`TODO ` so a translator can work in place and the report can count progress.
Existing translations are never overwritten.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KB = ROOT / "assets/kb"
I18N = KB / "i18n"

LOCALES = ["ne", "hi"]

# Files that are deliberately not translated, and why.
SKIP_FILES = {
    "catalog.json": "book titles, filenames and page counts — proper nouns",
    "degrees.json": "the optional Western Sabian layer, 45k words the KB itself "
                    "labels as colour on a reading",
}

# Keys whose values are identifiers, paths or classical Sanskrit terms the
# engine matches on. Translating these would break lookups.
SKIP_KEYS = {
    "engine", "version", "id", "key", "asset", "implementation", "file",
    "source", "sources", "match", "type", "conditions", "cancellation_checks",
    "requires_lagna", "precedence", "weight", "category", "contributors",
    "bhinnashtakavarga", "planet_totals", "modules", "ashtakoota_asset",
    "scan", "library_path", "toc", "role", "contributes_to",
}

MIN_WORDS = 3

TODO = "TODO "


def translatable(path, value):
    """True when a leaf is prose a reader would see."""
    if not isinstance(value, str):
        return False
    if len(value.split()) < MIN_WORDS:
        return False
    return not any(part in SKIP_KEYS for part in path)


def walk(node, path=()):
    """Yields (path, value) for every translatable leaf."""
    if isinstance(node, dict):
        for k, v in node.items():
            if k in SKIP_KEYS and not isinstance(v, (dict, list)):
                continue
            yield from walk(v, path + (k,))
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from walk(v, path + (i,))
    elif translatable(path, node):
        yield path, node


def get_at(node, path):
    for step in path:
        if isinstance(node, dict):
            if step not in node:
                return None
            node = node[step]
        elif isinstance(node, list):
            if not isinstance(step, int) or step >= len(node):
                return None
            node = node[step]
        else:
            return None
    return node


def set_at(node, path, value):
    """Creates the minimal nesting needed to hold `path`."""
    for i, step in enumerate(path[:-1]):
        nxt = path[i + 1]
        if isinstance(step, int):
            while len(node) <= step:
                node.append([] if isinstance(nxt, int) else {})
            if node[step] in (None, {}, []):
                node[step] = [] if isinstance(nxt, int) else {}
            node = node[step]
        else:
            if step not in node or not isinstance(node[step], (dict, list)):
                node[step] = [] if isinstance(nxt, int) else {}
            node = node[step]
    last = path[-1]
    if isinstance(last, int):
        while len(node) <= last:
            node.append(None)
        node[last] = value
    else:
        node[last] = value


def kb_modules():
    for f in sorted(KB.glob("*.json")):
        if f.name in SKIP_FILES:
            continue
        yield f


def engine_keys():
    """Keys in the compiled-in English engine table."""
    src = (ROOT / "lib/l10n/engine_strings.dart").read_text()
    body = src[src.index("const _en = <String, String>{"):]
    out, i = [], 0
    while True:
        i = body.find("\n  '", i)
        if i < 0:
            break
        j = body.index("':", i)
        out.append(body[i + 4:j])
        i = j
    return out


def report():
    print("Knowledge base\n" + "-" * 68)
    grand = {loc: [0, 0] for loc in LOCALES}
    for base_file in kb_modules():
        base = json.loads(base_file.read_text())
        leaves = list(walk(base))
        if not leaves:
            continue
        row = f"{base_file.name:<24} {len(leaves):>5} strings"
        for loc in LOCALES:
            over_path = I18N / loc / base_file.name
            over = json.loads(over_path.read_text()) if over_path.exists() else {}
            done = sum(
                1 for p, _ in leaves
                if isinstance(get_at(over, p), str)
                and not get_at(over, p).startswith(TODO)
            )
            grand[loc][0] += done
            grand[loc][1] += len(leaves)
            row += f"   {loc} {done * 100 // len(leaves):>3}%"
        print(row)

    print("\nEngine string table\n" + "-" * 68)
    ek = engine_keys()
    for loc in LOCALES:
        path = I18N / loc / "engine.json"
        table = json.loads(path.read_text()) if path.exists() else {}
        done = sum(1 for k in ek if k in table)
        print(f"{'engine.json':<24} {len(ek):>5} strings   "
              f"{loc} {done * 100 // len(ek):>3}%")

    print("\nOverall knowledge-base coverage\n" + "-" * 68)
    for loc in LOCALES:
        done, total = grand[loc]
        pct = done * 100 // total if total else 0
        print(f"  {loc}: {done}/{total} strings ({pct}%)")

    print("\nNot translated by design\n" + "-" * 68)
    for name, why in SKIP_FILES.items():
        print(f"  {name}: {why}")


def skeleton(locale):
    """Fills an overlay with TODO stubs for everything still untranslated."""
    target = I18N / locale
    target.mkdir(parents=True, exist_ok=True)
    added = 0
    for base_file in kb_modules():
        base = json.loads(base_file.read_text())
        leaves = list(walk(base))
        if not leaves:
            continue
        out_path = target / base_file.name
        over = json.loads(out_path.read_text()) if out_path.exists() else {}
        for path, value in leaves:
            if isinstance(get_at(over, path), str):
                continue  # never overwrite a translator's work
            set_at(over, path, TODO + value)
            added += 1
        out_path.write_text(
            json.dumps(over, ensure_ascii=False, indent=1) + "\n",
            encoding="utf-8",
        )
    print(f"{locale}: {added} stubs added")


def check():
    """CI gate: an overlay must never introduce a key the base lacks."""
    problems = []
    for loc in LOCALES:
        for over_path in sorted((I18N / loc).glob("*.json")):
            if over_path.name == "engine.json":
                continue
            base_path = KB / over_path.name
            if not base_path.exists():
                problems.append(f"{loc}/{over_path.name}: no such base module")
                continue
            base = json.loads(base_path.read_text())
            over = json.loads(over_path.read_text())
            for path, value in walk(over):
                target = get_at(base, path)
                if target is None:
                    problems.append(
                        f"{loc}/{over_path.name}: key not in base → "
                        f"{'.'.join(str(p) for p in path)}")
                elif not isinstance(target, str):
                    problems.append(
                        f"{loc}/{over_path.name}: base is not a string → "
                        f"{'.'.join(str(p) for p in path)}")
    if problems:
        print("Overlay problems:")
        for p in problems[:40]:
            print("  " + p)
        sys.exit(1)
    print("Overlays are structurally valid.")


if __name__ == "__main__":
    if "--skeleton" in sys.argv:
        skeleton(sys.argv[sys.argv.index("--skeleton") + 1])
    elif "--check" in sys.argv:
        check()
    else:
        report()

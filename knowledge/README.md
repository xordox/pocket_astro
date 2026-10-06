# PocketAstro knowledge base

Everything the app needs to read a chart offline. The runtime tables live in
`assets/kb/` and are bundled into the app; everything in `knowledge/` is the
source material and the build pipeline that produces them.

## Layout

| Path | What it is |
|---|---|
| `build/` | The builders. One script per runtime table; `build_all.py` runs them in order. |
| `extract/_catalog.json` | Flat source list consumed by `tool/compile_prediction_kb.py`. |
| `extract/_catalog_full.json` | Full scan report: 56 PDFs, 15,555 pages, 25.1M characters, TOCs, role, and which tables each source fed. |
| `extract/deep/` | The technical chapters the tables were compiled from — one file per chapter, with a `README.md` provenance index. |
| `extract/scans/` | Per-PDF page dumps from the original sampling scan, kept for reference. |
| `extract/*.json` | Mirrors of the compiled tables, so the build output is reviewable in git without opening the asset bundle. |
| `../POCKETASTRO_KNOWLEDGE_BASE.md` | The compiled engine spec: what is implemented, what is data-only, and what is out of scope. |

## Runtime tables (`assets/kb/`)

`prediction.json` is the entry point. It carries the shortcuts the forecast
engine reads directly and indexes the modules below.

| Asset | Contents |
|---|---|
| `prediction.json` | Forecast shortcuts, 14 event recipes, gochara and vedha for all nine grahas, the judgment protocol, the confidence model, the refusal list, and the module index. |
| `planets.json` | Nine grahas: dignity, karaka, body, professions, gems, aspects, friendships; 108 planet-in-sign and 108 planet-in-house readings; functional benefic/malefic/yogakaraka/maraka/badhaka tables for all twelve lagnas. |
| `houses.json` | Twelve bhavas in full, plus all 144 house-lord-in-house placements and the rules for judging a house. |
| `nakshatras.json` | 27 nakshatras: lord, deity, symbol, shakti and its result, gana, yoni, nadi, muhurta class, body part, careers, shadow, and all four padas with their navamsa. Plus gandanta, gandmool and Abhijit. |
| `yogas.json` | 77 yogas with machine-checkable conditions, effects, strength notes and cancellations — pancha mahapurusha, chandra, ravi, raja, dhana, vipreeta, parivartana, arishta, and all 32 Nabhasa. All of them are evaluated at runtime by `lib/engine/yoga.dart`. |
| `doshas.json` | 15 doshas, each with an honest reading, a full cancellation list and a matched remedy. No dosha is reportable before its cancellations are evaluated. |
| `dashas.json` | Vimshottari mechanics, per-graha mahadasha results, antardasha by house-distance and by relation, all 81 MD/AD cells, plus Yogini, Ashtottari, Chara, Kalachakra and Narayana, and the chara karakas. |
| `transits.json` | Gochara for all nine grahas through all twelve houses from the Moon, the complete Charak XXIX vedha table with its father-son exceptions, timing within a sign, returns, maturity ages, retrogression, eclipses, and the Western transit stack. |
| `ashtakavarga.json` | The full bhinnashtakavarga benefic-point tables (verified against the classical 337 total), sarvashtakavarga thresholds, per-bindu readings, kakshya, and the house-comparison rules. Computed at runtime by `lib/engine/ashtakavarga.dart`. |
| `strength.json` | Shadbala components and required minima, bhava bala, the three avastha systems, dignity order, combustion orbs, and planetary war. |
| `divisionals.json` | All sixteen vargas with construction rules and what each is read for; the four vimshopaka weighting schemes; birth-time accuracy per varga. |
| `panchanga.json` | 30 tithis, 27 yogas, 11 karanas, weekday qualities, Rahu kaal / yamaganda / gulika, Abhijit, choghadiya, panchaka, tarabala, chandrabala, and muhurta rules for seven activities. |
| `remedies.json` | Gemstone, metal, finger, day, mantra, japa count, charity, fast and deity for each graha — each paired with the practical counterpart PocketAstro leads with. |
| `interpretation.json` | The order of judgment, the two-technique rule, the confidence model, window rules, refusals, delivery rules, and 14 per-topic prediction recipes. |
| `degrees.json` | 360 tropical degree symbols with keywords and cautions (Western layer only, never mixed into a Jyotisha verdict). |
| `ashtakoota.json` | The 36-guna matching tables. |
| `catalog.json` | The source library scan. |

## Languages

The app ships English, Nepali and Hindi. Three layers carry text, and each has
its own home:

| Layer | Lives in | Covers |
|---|---|---|
| Widget strings | `lib/l10n/arb/app_<code>.arb` | every label, button, hint and note in the UI |
| Engine strings | `lib/l10n/engine_strings.dart` (English baseline) + `assets/kb/i18n/<code>/engine.json` | graha, sign and nakshatra names, house titles, band and verdict labels, koota glosses, the whole Q&A trace |
| Knowledge base | `assets/kb/*.json` + `assets/kb/i18n/<code>/*.json` | the classical interpretive prose |

The knowledge-base overlay carries the **same key paths** as the English base
and is deep-merged over it at load time. An overlay can never add a key, change
a number, or alter the shape the engine reads — it replaces leaf strings and
nothing else. A key the overlay omits keeps its English text, so a partial
translation is a partly translated app rather than a broken one.

**Adding a language** means adding one ARB file, one
`assets/kb/i18n/<code>/engine.json`, and the code to `supportedLocaleCodes` in
`engine_strings.dart`. No other Dart changes.

```bash
python3 knowledge/build/build_i18n.py               # coverage report
python3 knowledge/build/build_i18n.py --skeleton ne # writeable TODO stubs
python3 knowledge/build/build_i18n.py --check       # structural CI gate
```

`--skeleton` fills an overlay with every untranslated string prefixed `TODO `,
so a translator works in place and the report counts real progress. Existing
translations are never overwritten. Two files are excluded by design:
`catalog.json` (book titles and filenames — proper nouns) and `degrees.json`
(the optional Western Sabian layer, 45k words the KB itself labels as colour on
a reading).

## Rebuilding

```bash
# tables only (no PDF access needed)
python3 knowledge/build/build_all.py

# also re-scan the PDF library and regenerate the provenance extracts
/Users/ambition/Desktop/astrology_ebooks/.venv/bin/python \
    knowledge/build/build_all.py --scan

# verify
flutter test test/kb_test.dart
```

`test/yoga_test.dart` builds one synthetic chart per yoga, to its classical
definition, and asserts that all 77 are detected — plus the coded
cancellations, the Charak XX Nabhasa precedence rules, and that no lagna-bound
yoga runs without a birth time. It enumerates the catalogue rather than a fixed
list, so adding a yoga without a fixture fails the suite.

`test/ashtakavarga_test.dart` tests the bindu arithmetic against its invariants
across 200 pseudo-random charts — the per-graha totals, the 337 sarva sum, and
the 8- and 56-bindu ceilings — plus the direction of counting and the forecast
integration.

`test/kb_test.dart` is the guard: it checks the ashtakavarga totals against the
classical 337, the 81 MD/AD sub-period lengths against the Vimshottari formula,
the vimshopaka weights against 20, every pada navamsa against the engine's own
`navamsaSign`, and the KB's dignity and functional tables against
`lib/engine/tables.dart`. If a builder regresses, this fails before a user sees
a wrong reading.

## Sources

56 PDFs, 15,555 pages. Two are image-only and contributed nothing
(`All Around The Zodiac`, `The Only Way to Learn Astrology`) — they remain
catalogued as sources.

The Jyotisha tables come from Dr K. S. Charak, *Elements of Vedic Astrology*
(the primary source: chapters VII, X, XII–XXII, XXIV, XXVI, XXVII, XXIX, XXX),
Komilla Sutton, *The Essentials of Vedic Astrology*, William Levacy, *Beneath a
Vedic Sky*, James Braha, *Ancient Hindu Astrology for the Modern Western
Astrologer*, and Vic DiCara, *27 Stars, 27 Gods*. The Western layer comes from
Carol Rushman, *The Art of Predictive Astrology*, Deborah Houlding, *The
Houses*, Sue Tompkins, *The Contemporary Astrologer's Handbook*, and Lynda
Hill, *360 Degrees of Wisdom*. `extract/deep/README.md` maps each chapter to
the table it produced.

## Editorial policy

The classical sources are followed for structure and rule, and restated in
modern language. Where a classical aphorism is fatalistic, misogynistic, or
makes a mortality claim, the underlying astrological signal is kept and the
framing is not. Three rules are enforced in the data itself:

- Every dosha carries its cancellations, and is not reportable without them.
- Every remedy carries a practical counterpart, and that is what leads.
- The refusal list in `interpretation.json` is part of the compiled KB, not a
  UI afterthought: no death, no diagnosis, no verdicts, no lottery.

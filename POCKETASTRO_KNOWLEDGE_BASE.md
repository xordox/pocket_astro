# PocketAstro Knowledge Base

**Product:** PocketAstro — offline Vedic + Western astrology  
**Generated:** 14 September 2026 · **Revised:** 15 September 2026 (full-text re-scan, 16 runtime tables)  
**Source corpus:** 56 PDF files in `/Users/ambition/Desktop/astrology_ebooks`  
**How to use this file:** ship it (and the JSON tables derived from it) inside the app. Chart math uses an ephemeris. Interpretation uses the rules and dictionaries below. Do not call the network for any of it — the single permitted network call in the whole app is birthplace search, described in §1.1.1, and it is reached only on an explicit tap.

---

## 0. Accuracy — what 99.99% can and cannot mean

PocketAstro can be **astronomically precise**. It cannot be scientifically 99.99% accurate at “predicting a person’s future.” That claim is not supported by the scanned books, by Jyotish, or by Western astrology. The app must never present a forecast as medical, legal, or financial advice.

| Layer | Realistic target | What the library supports |
|---|---|---|
| Planet / node longitudes (1900–2100) | Sub-arcsecond with Swiss Ephemeris | Braha, Charak, Sutton, Woolfolk: use a published ephemeris, name the ayanamsa |
| Sidereal signs / nakshatras | Exact if ayanamsa + birth time are exact | Lahiri is the PocketAstro default (Government of India / Charak / Braha / prior Kathmandu readings) |
| Lagna | ~0.25° per minute of clock error | Braha: 2–3° of Moon can shift dasha start by years; D9 lagna can flip in a few minutes |
| Vimshottari dates | Seconds if Moon longitude is exact | Charak XIV–XV; Levacy ch.13 |
| Event prediction | **Confidence score**, never a certainty | Dasha promises; transits time; vargas refine; yogas qualify. Rushman: stack lunations + progressed Moon + transits |
| Marriage matching | 36-point Ashtakoota + full-chart overlay | Charak XXVII; Levacy ch.17; never Ashtakoota alone |

**PocketAstro accuracy contract**

1. Compute positions with Swiss Ephemeris (or equivalent JPL-quality files bundled on device).  
2. Show **system, ayanamsa, house system, node type, and birth-time uncertainty** on every chart.  
3. Require **two agreeing techniques** before an event is labelled “likely” (example: dasha of 7th/Venus **and** Jupiter gochara on 7th). One technique = “possible.” Conflict = “do not claim.”  
4. Attach a **confidence** `0–100` from data quality × rule agreement, never from marketing.  
5. If birth time is unknown, refuse lagna-, navamsa-, and house-based claims; offer sunrise/Moon-only readings and say so.

Books in this folder that are **image-only** (no extractable text): *All Around the Zodiac* (Bil Tierney), *The Only Way to Learn Astrology* (Marion D. March). Their methods are not in this file.

Copyright: this knowledge base **paraphrases method** from the ebooks and records **traditional public Jyotish / Western tables**. It is not a reprint of any book.

---

## 1. PocketAstro product specification

### 1.1 On-device runtime

The installed app must include:

| Asset | Why |
|---|---|
| Swiss Ephemeris files (`seas_18.se1`, `semo_18.se1`, `sepl_18.se1` or DE431 subset) | Planet/Moon/node longitudes without internet |
| IAU / house-cusp routines | Placidus, Equal, Whole Sign, Sripati |
| Timezone database (tzdb, historical) | Kathmandu NST, IST, DST, UTC offsets |
| City atlas (lat/lon/tz) | Offline fallback and demo data; birthplace search is tier 3 (§1.1.1) |
| This knowledge base compiled to JSON | Interpretations + Q&A |
| Lahiri (and optional Raman, KP, True Chitrapaksha) ayanamsa constants | Sidereal conversion |

No chart, match, forecast, save, or Q&A answer may depend on a live API. This
rule survives the geocoding feature and constrains its design: birthplace
search is the one network call, and a chart can always be created without it —
from a place already used, from the 25 bundled cities, or from coordinates
typed by hand.

#### 1.1.1 Birthplace search — the one network call

Three tiers, and only the third leaves the device:

1. **Places this reader has used before**, persisted by `LocalStore` in
   `pocketastro_places.json`. A place found online once works offline forever.
2. **The bundled atlas** in `data/atlas.dart`, unchanged, 25 cities.
3. **Open-Meteo geocoding**, reached only from an explicit "Search online" tap
   or by submitting the field.

Tiers 1 and 2 are synchronous, so `onChanged` cannot open a socket. That is a
property of the call graph, not a debounce interval that could be tuned wrong,
and `test/birth_form_test.dart` asserts it directly.

**Why Open-Meteo rather than Nominatim or Google.** The hard part of geocoding
a birthplace is not the coordinates, it is the timezone: `toUtc` feeds
`place.timezone` to `tz.getLocation`, and a birth decades ago needs that zone's
historical DST rules. Neither Nominatim nor Google Geocoding returns an IANA
id — Google sells a separate, billed Time Zone API for it. Open-Meteo returns
`timezone` in the same response, with no key. The alternatives considered and
rejected were a 4 MB polygon package, a second billed API call, a generated
`zone.tab` country table, and snapping to the nearest bundled city (which puts
Lagos in Dubai — three hours, about 45° of ascendant).

**The single gate.** `placeFromGeoJson` in `data/geocoder.dart` is the only
place in the app that builds a `Place` from remote data. It is total — returns
null, never throws — and its last check is `isKnownZone(timezone)`. A zone the
database cannot resolve is dropped rather than stored, so an unusable id cannot
reach `BirthInput`, storage, or the engine. A second construction site would
reopen that hazard; do not add one.

The app loads `timezone/data/latest_all.dart`, not `latest`. GeoNames emits
backward-compatibility ids (`Asia/Calcutta`, `Europe/Kiev`) which are valid
IANA zones that `latest` omits; under `latest` a reader in Kolkata would be
told their city does not exist.

### 1.2 Screens

The audience is the general public, not astrologers. Two rules follow from
that and govern every screen:

* **A reader can stop at the first sentence.** Every card leads with one plain
  sentence and folds the classical reasoning behind a "Why this?" control. The
  jargon is never removed, only demoted.
* **Colour never carries meaning alone.** Every tint is paired with a word —
  "Supported", "Under pressure", "Helpful graha" — so the app works for a
  colour-blind reader and in a screenshot.

**Home** (`ui/library_screen.dart`) — three jobs in the order a returning
reader wants them: what today is, open a chart, go somewhere next. The daily
card is first because it is the only part of the app that changes without the
reader doing anything. Learn and Compatibility are labelled tiles rather than
app-bar glyphs — compatibility previously sat behind an unlabelled heart icon,
which is a destination nobody finds by accident. The birth-details form lives
in the same file.

**Daily reading** (`ui/rashifal_screen.dart`, `/rashifal`) — twelve moon signs,
see §1.2.3.

**Learn** (`ui/learn_screen.dart`, `/learn`) — the same course as the chart tab,
reachable without opening a chart. It passes the first saved profile so the
worked examples still resolve, and `syllabusFor(null)` degrades to the lessons
alone when there is no chart at all.

**Chart** (`ui/chart_screen.dart`) — seven tabs, in the order a reader needs
them rather than the order the engine computes them:

1. **Overview** — who you are in one sentence, the running period with a
   progress bar, the three life areas the chart most supports and the two under
   most pressure, and any standout yoga.
2. **Today** (`ui/today_tab.dart`) — the day graded in one word, what it is
   classically suited to and unsuited to, the muhurta windows inside its
   daylight, the five limbs of the panchanga, and the day's two Moon strengths
   measured against the birth Moon. Engines in `engine/panchanga.dart` and
   `engine/today.dart`; see §1.2.2.
3. **Kundali** — the interactive chart (below), the legend, a graha selector,
   and the exact degree tables folded away under "Exact positions".
4. **Life areas** — the twelve houses as plain-titled cards ("Money you keep,
   and your voice"), each opening a sheet that justifies its own colour, then
   the classical readings in full.
5. **Timing** — the running period, a proportional life-long dasha strip, the
   sub-periods, and the windows where two techniques agree.
6. **Ask** — questions in plain language, with the reasoning shown live.
7. **Learn** (`ui/learn_tab.dart`) — a fifteen-lesson course from the basics to
   the limits of the method, each lesson ending in the reader's own chart.
   Syllabus in `assets/kb/learn.json`, engine in `engine/learn.dart`; see
   §1.2.3.

**Match** (`ui/match_screen.dart`) — two profiles, 36 gunas, Mangal, overlay.

Both people can be added from this screen. Previously it refused to draw its
picker until two charts already existed, and showed a sentence telling the
reader to go and save one somewhere else — a dead end with no button on it,
reachable from a home-screen tile. The two slots are now always live and are
themselves the empty state: each offers the saved charts and, always, "Add a
new chart", which pushes `BirthFormScreen` on the app's own Navigator rather
than through GoRouter, so the comparison underneath keeps its state and its
other selection. The form takes optional `onSaved`, `saveLabel` and `title`, so
it hands the chart back to the slot instead of navigating to it, names the slot
being filled, and still writes to the library like any other chart.

Two details worth keeping:

* Clearing a slot is a control **on the slot card**, not a row in the sheet. It
  was in the sheet first, at the bottom of a lazy `ListView`; on a phone with a
  couple of saved charts that row sits past the viewport and is never built, so
  the action was unreachable. `test/match_flow_test.dart` caught it.
* The screen re-validates the cubit's selection against the live profile list
  on every build, so a person deleted elsewhere in the app cannot leave a score
  on screen that has outlived its own input.

Both people can be added from this screen. Previously the screen refused to
draw its picker until two charts already existed and showed a sentence telling
the reader to go and save one somewhere else — a dead end with no button on it,
reachable from a home-screen tile. Now the two slots are always live and are
themselves the empty state: each offers the saved charts and, always, "Add a new
chart", which pushes `BirthFormScreen` on the app's own Navigator (not through
GoRouter) so the comparison underneath keeps its state and its other selection.
The form takes an optional `onSaved`, `saveLabel` and `title`, so it hands the
chart back to the slot instead of navigating to it, names the slot being filled,
and still writes to the library like any other chart.

Two details worth keeping:

* Clearing a slot is a control **on the slot card**, not a row in the sheet. It
  was in the sheet first, at the bottom of a lazy `ListView`; on a phone with a
  couple of saved charts that row sits past the viewport and is never built, so
  the action was unreachable. A widget test caught it.
* The screen re-validates the cubit's selection against the live profile list
  every build, so a person deleted elsewhere in the app cannot leave a score on
  screen that outlives its own input.

**Export** — the same reading as a PDF.

### 1.2.1 The kundali widget

`ui/widgets/kundali.dart` draws both traditions from one cell model, so
tapping, tinting and aspect lines behave identically in either:

* **North Indian** holds the houses still and rotates the signs; house 1 is the
  top-centre diamond and the numbering runs anticlockwise.
* **South Indian** holds the signs still in the 4×4 ring and marks the rising
  sign "Asc".

Three things are encoded visually:

* the **fill** of a house is how the chart supports that area of life, from
  `engine/house_quality.dart`;
* the **colour of a graha** is whether it acts as a benefic or a malefic here,
  from `engine/nature.dart`;
* selecting a graha draws **arcs to every house it aspects**, with the special
  aspects of Mars, Jupiter, Saturn and the nodes applied, and names those
  houses in words underneath.

House quality is the one piece of synthesis the app performs rather than
quotes. Its weights live in `interpretation.json` under `house_quality`, marked
there as PocketAstro's own, and every score is reported with the reasons that
produced it — so the colour on the chart always matches the explanation in the
sheet. The relationship is asserted in `test/ui_test.dart`.

### 1.2.2 The day

`engine/panchanga.dart` describes the day for everybody in a place;
`engine/today.dart` reads it against one chart. They are kept apart because
only the second half is personal.

The Vedic day runs sunrise to sunrise, so sunrise is computed first: the Sun's
altitude is scanned across the local civil day and the crossing of the
refracted horizon (−0°50′) bisected to the second. A scan rather than a closed
form, because it degrades honestly — above the Arctic circle there is no
crossing, and the day falls back to a stated 6am–6pm convention rather than to
a NaN. Opening the app before dawn reads the *previous* Vedic day, which is
still the one running.

From that sunrise come the five limbs (tithi, vara, nakshatra, yoga, karana),
each reported with the moment it gives way — the part a reader actually plans
around. The muhurta windows are fractions of the daylight: Rahu kaal, Yamaganda
and Gulika are the weekday's eighths, and Abhijit is the eighth of fifteen
muhurtas, marked weak on Wednesday as the classics have it.

The personal half is three measures, and a small tally over them:

* **Tarabala** — today's Moon nakshatra counted inclusively from the birth
  Moon's, reduced to one of nine taras.
* **Chandrabala** — the transiting Moon's whole-sign house from the janma
  rashi.
* **Kakshya count** — today's seven grahas judged against the natal
  bhinnashtakavarga. Withheld without a birth time, since the lagna is the
  ashtakavarga's eighth contributor.

`DayGrade` is deliberately a **tone, not a verdict**, and no single filter can
swing it alone. The screen says so at the bottom: a day can colour what the
chart and the running dasha already promised, and cannot add to it or take it
away. That is the same order of judgment the rest of the app follows.

One localisation hazard is worth naming, because a test now guards it: the
knowledge base flags an inauspicious yoga, karana or tara **by name**, so an
overlay that translates the names must translate the flag lists with the same
index mapping, or the day would silently grade differently in Nepali than in
English. `test/today_test.dart` asserts the grade is identical in all three
languages, and that an overlay never translates a value the engine looks up by
(a tithi group, a vara lord).

### 1.2.3 The daily reading (rashifal)

The popular surface, and the app's least precise one. Both facts are on screen.

It is *rashifal* as the tradition actually does it: gochara counted from a moon
sign, not sun-sign copy written by a person. Every sentence comes from
`results_from_moon` in `assets/kb/transits.json`, selected by the house a graha
genuinely occupies from that rashi at the governing sunrise. Nothing is composed
prose. All nine grahas are shown, not a curated three, and vedha is applied —
a benefic transit whose paired obstructing house is occupied is marked
obstructed and scores zero rather than positive.

**Calibration is the part that took work.** The raw tally is structurally
negative: benefic houses are a minority for most grahas (Saturn, Mars, Rahu and
Ketu are favourable in three houses out of twelve), so summing ±weight across
nine grahas centres near −2.7 rather than zero. Grading that tally directly put
every sign in "guarded" on the first day tested. Two corrections followed:

1. `_neutralBaseline()` derives the neutral score from `beneficTransitHouses`
   itself, so the scale re-centres if the tables are ever recompiled instead of
   silently drifting.
2. The four cut points sit near the 24th, 58th and 83rd percentiles of a
   full-year sample (4,380 readings), because the distribution is left-skewed —
   its median sits about 2.3 below its mean. Measured over a year the bands
   land at roughly 24 % guarded, 33 % mixed, 26 % workable, 16 % favourable.

`test/rashifal_test.dart` asserts no band takes more than 55 % or less than 5 %
of a season. That is the regression guard that matters: an uncentred scale
fails no single-day assertion, it just quietly turns the feature into noise.

`assets/kb/transits.json` gained `ne` and `hi` overlays for all 108 readings
(9 grahas × 12 houses). This is the one screen a Nepali or Hindi reader is most
likely to open daily, and English paragraphs under a Devanagari heading would
have made it ornamental.

### 1.2.4 Learning astrology

Fifteen lessons in three levels — Basics, Intermediate, Advanced — running
from what a chart physically is to the order of judgment and what the method
must refuse to claim. The last lesson is deliberately the ethics one: a course
that ends on technique teaches a reader to over-claim.

Two decisions shape the design.

**The prose is knowledge base, not code.** `assets/kb/learn.json` holds every
title, hook, point and self-check, so a translation is an overlay file under
`assets/kb/i18n/<locale>/learn.json` and not a Dart change — the same rule the
rest of the classical text follows. Nepali and Hindi ship complete; a test
asserts every leaf is translated and that no overlay alters a lesson `id`,
because progress is keyed on those ids and a translated id would silently lose
a reader's course.

**Every lesson ends in the reader's own chart.** `engine/learn.dart` computes a
worked example per lesson from the open `NatalChart` — the reader's ayanamsa
gap for the two-zodiac lesson, their lagna lord's house for the house-lords
lesson, their 10th-house sarvashtakavarga total for the ashtakavarga lesson.
That is the part a textbook cannot do, and it is what makes a syllabus inside a
chart app worth more than a syllabus outside one. Where an example needs an
ascendant, an unknown birth time withholds it and says why, exactly as
everywhere else in the app.

Nothing is locked. A reader who wants the ashtakavarga lesson on day one may
have it; the levels are an ordering, not a gate, because gating assumes the app
knows what the reader already knows. Progress is a set of finished lesson ids
in `LearnCubit`, stored on the device by `LocalStore`, and resettable — progress
a reader cannot clear is progress they cannot trust.

### 1.2.5 Languages

English, Nepali and Hindi, with a picker in the library app bar. Switching
language does three things in one place so the app can never be half
translated: it swaps the Flutter locale, installs the matching engine string
table, and reloads the knowledge base with that locale's overlay.

Astrology is a domain where Devanagari is the *native* register — ग्रह, भाव,
दशा, कुण्डली — so the Nepali and Hindi readings are in several places more
natural than the English they were translated from.

Three layers carry text:

* **Widget strings** — generated from ARB files. 139 strings, complete in all
  three languages.
* **Engine strings** — a plain-Dart table with English compiled in as a
  guaranteed baseline and other locales loaded from
  `assets/kb/i18n/<code>/engine.json`. The engine has no `BuildContext` and
  must not import Flutter, so it cannot use the generated lookups. 230 strings,
  complete in all three: every graha, sign and nakshatra name, the twelve house
  titles and topics, the band and verdict labels, the koota glosses, and the
  whole Q&A reasoning trace.
* **Knowledge base** — per-locale overlays deep-merged onto the English base.
  The overlay can never add a key, change a number, or alter the shape the
  engine reads. A key it omits keeps its English text, so a partial translation
  degrades to English rather than to a blank.

That last property is the design decision worth stating plainly. The
interpretive prose is 33,000 words before translation; that is a translation
project, not an engineering one. Rather than fabricate it, the pipeline makes
what is outstanding **measurable**: `knowledge/build/build_i18n.py` reports
coverage per module per locale, `--skeleton` writes TODO stubs a translator
fills in place, and `--check` gates the structure in CI. The highest-visibility
prose is translated — the yoga effects shown as Overview leads, the Manglik
text the match screen renders verbatim, and the nine dasha vocabularies — and
the long classical paragraphs currently read in English with the rest of the
interface in the reader's language.

### 1.2.6 Showing the work

`engine/qa.dart` returns a `QaStep` trace alongside every answer, and the Ask
tab reveals it a step at a time: the question's subject, the chart opened, the
houses that govern the topic and who rules them, the running Vimshottari
period, where the slow grahas are now, what the ashtakavarga point count said,
and the rule that caps confidence at 75. Each step carries the value the engine
actually read and names the source file the rule came from; a step with nothing
to report is dropped rather than faked. It is a replay of real reasoning, not a
progress bar. A refused question produces a two-step trace that never opens the
chart at all.

### 1.3 Save locally

Use SQLite (or Isar / Hive) on device only.

```
profiles(id, name, birth_utc, tz, lat, lon, place, time_source, notes)
charts(id, profile_id, system, ayanamsa, house_system, json_blob, created_at)
reports(id, profile_id, type, json_blob, created_at)
matches(id, profile_a, profile_b, score_json, created_at)
qa_log(id, profile_id, question, intent, answer, created_at)
exports(id, report_id, path, created_at)
```

`json_blob` stores the computed chart so a report can be reopened without recomputing, plus a `engine_version` so old saves can be rebuilt after a rule update.

### 1.4 Export readable PDF

Required sections (A4, print-safe, not a screenshot dump):

1. Cover — name, birth data, systems used, generated date.  
2. Disclaimer.  
3. Vedic rasi table + South/North diagram.  
4. Navamsa (D9) table.  
5. Western natal table + aspects.  
6. Yogas / dignity summary.  
7. Current dasha + 12–36 month calendar.  
8. Life areas (career, money, marriage, family, health).  
9. If match: Ashtakoota table + Mangal + overlay notes.  
10. Optional Q&A appendix.  
11. Footer: “Interpretive astrology, not advice.”

Flutter: `package:pdf` + `printing`. Write files under app documents. Share sheet for export. No cloud.

---

## 2. Source catalog (all 56 PDFs)

### 2.1 Core calculation & Vedic prediction (highest weight)

| File | Pages | Role in PocketAstro |
|---|---|---|
| `Elements of Vedic Astrology` — K.S. Charak | 468 | Houses, grahas, avasthas, Vimshottari, yogas, matching (Ashtakoota), gochara, ashtakavarga, muhurta, longevity/health **method** |
| `Ancient Hindu Astrology for the Modern Western Astrologer` — James Braha | 364 | Ayanamsa choice, yogakaraka, house lords, Western-to-Vedic bridge, dasha caution |
| `The Essentials of Vedic Astrology` — Komilla Sutton | 239 | Jyotish pedagogy, nakshatra wheel, nodes, synthesis |
| `Beneath a Vedic Sky` — William R. Levacy | 438 | Planets/signs/houses, yogas, nakshatras, navamsa, gochara, **compatibility ch.17**, muhurta, remedies |
| `27 Stars, 27 Gods` — Vic DiCara | 161 | Nakshatra mythology and interpretive tone for Moon/lagna stars |

### 2.2 Western natal, houses, predictive

| File | Pages | Role |
|---|---|---|
| `Houses` — Deborah Houlding | 208 | Traditional house meanings; 12th as self-undoing; angular/succeedent/cadent |
| `The Art of Predictive Astrology` — Carol Rushman | 290 | Event stacking: transits + progressed Moon + lunations + solar return |
| `The Contemporary Astrologer’s Handbook` — Sue Tompkins | 514 | Elements, modes, planets, aspects, house synthesis |
| `Astrology` — Carole Taylor | 236 | Signs, planets, houses, aspects, chart reading |
| `The Secrets of Astrology` — DK | 192 | Same Western grammar, visual/reference |
| `How to Be an Astrologer` — Constance Stellas | 306 | Daily motions, predictions, **Western compatibility**, reference tables |
| `The Only Astrology Book You’ll Ever Need` — Joanna Martine Woolfolk | 782 | Sun-sign + tables 1900–2100 (do not ship copyrighted tables; use ephemeris instead) |
| `360 Degrees of Wisdom` — Lynda Hill | 386 | Sabian degree symbols (optional flavour text, never event proof) |
| `Astrology for Yourself` — Douglas Bloch | 389 | Workbook natal psychology |
| `The Astrology of Self-Discovery` — Tracy Marks | 347 | Outer-planet / growth work |
| `The Development of Personality` — Liz Greene | 317 | Psychological astrology; do not use as event timing |
| `You Were Born for This` — Chani Nicholas | 226 | Purpose / nodes (Western) |
| `This Is Your Destiny` — Aliza Kelly | 216 | Nodes, timing language |
| `Trust Your Timing` — Alice Bell | 238 | Transits as timing psychology |
| `The Astrology of Success` — Jan Spiller | 150 | Nodes / vocation |
| `Exploring the Financial Universe` — Christeen Skinner | 227 | Mundane/finance transits — optional market flavour, not personal wealth law |
| `Astrology for Adults` — Joan Quigley | 328 | Mid-20th-century Western natal |
| `Astrology for Happiness & Success` — Mecca Woods | 247 | Applied life-area Western |
| `The Astrology Advantage` — Edut | 279 | Pop-practical Western |
| `Everyday Radiance` — Heidi Rose Robbins | 389 | Rising-sign tone |
| `The Witch’s Complete Guide to Astrology` — Elsie Wild | 176 | Cycle / year magic — optional |
| `Luna` — Tamara Driessen | 218 | Moon cycle |
| `The Moon Book` — Sarah Faith Gottesdiener | 335 | Moon practice |
| `Body Astrology` — Claire Gallagher | 482 | Body/sign overlays — **not medical diagnosis** |
| `The Little Book of Self-Care for Aries` — Stellas | 154 | Sun-sign care templates (extend to 12 signs in-app, do not copy book) |
| `The Astrological Guide to Self-Care` — Stellas | 497 | Care by placement |
| `The Everything Birthday Personology Book` — Marian Singer | 342 | Degree/birthday colour — low predictive weight |
| `Astrology SOS` — The Woke Mystix | 187 | Contemporary counselling tone |

### 2.3 Relationships, sex, synastry (Western) + Vedic overlay

| File | Pages | Role |
|---|---|---|
| `The astrology of human relationships` — Frances Sakoian | 404 | Synastry rules: house overlays, conjunctions planet-by-planet |
| `The Secret Language of Relationships` (repaired) | 320 | Personology / relationship language — **not** Ashtakoota |
| `The Astrology of You and Me` — Gary Goldschneider | 550 | Sign-to-sign work/love/family |
| `Cosmic Coupling` — Stella Starsky | 820 | Pairing narratives |
| `The Astrology of Love and Sex` — Annabel Gat | 295 | Love/sex by chart |
| `Astrologically Incorrect for Lovers` — Terry Marlowe | 173 | Informal couple dynamics |
| `Love on a Rotten Day` — Hazel Dixon-Cooper | 260 | Humour / caution |
| `Love, sex and astrology` — Teri King | 258 | Sign love |
| `Sexual Astrology` — Joanna Woolfolk | 260 | Sexual tone by sign |
| `Sextrology` — Cox & Starsky | 906 | Gendered sign essays — optional, keep off the prediction path |
| `Erotic Astrology` — Phyllis Vega | 283 | Same |
| `Star-Crossed Seduction` — Jenny Brown | 239 | Fiction — **do not use for prediction** |

### 2.4 Worked example PDFs already generated from this library

These are **not** textbooks. They show how the method was applied to one nativity (14 April 1992, 3:57 AM NST, Kathmandu) and how Q&A should be structured.

| File | Use |
|---|---|
| `Natal_Reading_14_April_1992_Kathmandu.pdf` | Western + Vedic natal template |
| `Vedic_Prediction_14_April_1992_Kathmandu.pdf` | Dasha + gochara prediction template |
| `Astrologer_Questions_Answered_14_April_1992.pdf` | 62-question sitting (full) |
| `Astrologer_Questions_Simple_Answers_14_April_1992.pdf` | Same 62, plain language |
| `Complete_Life_Answers_14_April_1992.pdf` | Life-area pack |
| `Life_Questions_Simple_Answers_14_April_1992.pdf` | Simple life Q&A |
| `Psychology_In_Depth_14_April_1992.pdf` | Psychological layer |
| `Start_Now_Guide_14_April_1992.pdf` | Action calendar |
| `Home_and_Money_Plan_14_April_1992.pdf` | 4th/2nd house plan |

**Engine constants used in those readings (PocketAstro defaults):** Swiss Ephemeris, **Lahiri** ayanamsa (~23°45' in 1992), **whole-sign** Vedic houses, **True Node**, **Vimshottari from natal Moon**, Western comparison in **Placidus** when shown.

### 2.5 Unusable / unused for engine

- Image-only textbooks (Tierney, March).  
- Romance fiction (`Star-Crossed Seduction`).  
- OceanofPDF watermarks — ignore.

---

## 3. Birth data the app must capture

| Field | Required | Notes |
|---|---|---|
| Name | yes | Display / PDF |
| Calendar date | yes | Store Gregorian; if Vikram Samvat entered, convert |
| Clock time | strongly | Unknown → Moon-sign + dasha-from-Moon still possible; refuse lagna |
| Timezone + UTC offset at birth | yes | Kathmandu is UTC+5:45; never assume IST |
| Latitude / longitude | yes | From atlas |
| Time source | yes | `hospital` / `memory` / `rectified` / `unknown` |
| Sex / gender (optional) | no | Classical texts use Jupiter/Venus as spouse significators; offer a non-binary path using 7th lord + Venus + Jupiter equally |
| Partner profile | for matching | Same fields |

**Rectification flags (Levacy ch.11, Braha, Q1 of the 62):** if D9 lagna is within 1° of a sign boundary, warn. If user disputes spouse/parent events, offer rectification checklist (appearance, a parent event, dasha onset) — do not silently change time.

---

## 4. Calculation engine

### 4.1 Time

1. Local civil time → UTC using tzdb for that date.  
2. Compute Julian Day UT.  
3. Delta-T for TT (Swiss Ephemeris handles this).

### 4.2 Tropical longitudes

Swiss Ephemeris `SEFLG_SWIEPH` (or `SEFLG_JPLEPH` if DE files ship). Bodies:

`Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn, Uranus, Neptune, Pluto, mean/true Node, Chiron (optional), Lilith (optional).`

Vedic charts **omit** Uranus, Neptune, Pluto, Chiron from rasi prediction unless a “modern overlay” toggle is on. Western charts include them.

### 4.3 Ayanamsa (sidereal)

`sidereal_lon = tropical_lon − ayanamsa`

**Default: Lahiri (Chitrapaksha).** Braha’s 1 Jan 1950 value: **23°09′34″**, ~48″/year. PocketAstro must use the Swiss Ephemeris built-in `SE_SIDM_LAHIRI`, not a linear 48″ approximation.

Also expose (labelled, not default): Raman, Krishnamurti, True Chitrapaksha, Fagan-Bradley (Western sidereal).

### 4.4 House systems

| System | Vedic default | Western default |
|---|---|---|
| Whole sign (each house = one rashi from lagna) | **Yes** | Optional |
| Sripati / Porphyry-like bhava chalit | Optional overlay | — |
| Placidus | Comparison only | **Yes** |
| Equal (from ASC) | Optional | Optional |

**Lagna** = tropical or sidereal longitude of the eastern horizon, matching the zodiac in use.

### 4.5 Nakshatra / pada

Each nakshatra = **13°20′** (800′). Each pada = **3°20′** (200′).

```
index = floor(sidereal_lon / (13 + 1/3))   # 0..26
pada  = floor((sidereal_lon % (13+1/3)) / (3+1/3)) + 1  # 1..4
```

Vimshottari lord of the Moon’s nakshatra starts the dasha sequence.

### 4.6 Vimshottari dasha

Order and years (120-year cycle), starting from the **Moon nakshatra lord**:

| Lord | Years |
|---|---|
| Ketu | 7 |
| Venus | 20 |
| Sun | 6 |
| Moon | 10 |
| Mars | 7 |
| Rahu | 18 |
| Jupiter | 16 |
| Saturn | 19 |
| Mercury | 17 |

**Balance at birth**

Let `elapsed` = Moon’s travel inside its nakshatra ÷ 13°20′.  
`balance_years = (1 − elapsed) × lord_years`.

Mahadasha dates: from birth, remaining of current lord, then full periods in order.

**Antardasha** of lord A inside mahadasha M:

`AD_years = years(M) × years(A) / 120`

Sequence of ADs: start from M itself, then the same order.

**Pratyantara:** same formula nested again (`PD_years = AD_years × years(P) / 120`).

Ship a unit-tested implementation; the 1992 Kathmandu example in the folder is a regression fixture (Moon 17° Leo, Purva Phalguni, Venus remainder ≈ 14.38 years).

### 4.7 Vedic aspects (graha drishti)

All grahas aspect the **7th** from themselves (whole-sign count, inclusive of start). Special:

| Graha | Extra aspects (whole-sign) |
|---|---|
| Mars | 4th and 8th |
| Jupiter | 5th and 9th |
| Saturn | 3rd and 10th |
| Rahu / Ketu | Schools differ; PocketAstro default: 5th, 7th, 9th (Jupiter-like), **toggle** to 7th-only |

Rasi drishti (sign aspect) is an optional Jaimini layer, off by default.

### 4.8 Western aspects

| Aspect | Angle | Default orb (luminaries / planets) |
|---|---|---|
| Conjunction | 0° | 8° / 6° |
| Opposition | 180° | 8° / 6° |
| Trine | 120° | 8° / 6° |
| Square | 90° | 7° / 5° |
| Sextile | 60° | 5° / 4° |
| Quincunx | 150° | 3° / 2° |
| Semi-sextile | 30° | 2° |
| Semi-square | 45° | 2° |
| Sesquiquadrate | 135° | 2° |

Applying vs separating: if faster planet is moving toward exact, **applying** (stronger for events — Rushman / Tompkins).

### 4.9 Divisional charts (vargas)

Minimum to compute:

| Varga | Division | Use |
|---|---|---|
| D1 rasi | 1 | Life, lords, yogas |
| D9 navamsa | 9 | Marriage, inner dharma, dignity (vargottama if same sign as D1) |
| D10 dasamsa | 10 | Career |
| D7 saptamsa | 7 | Children |
| D12 dwadasamsa | 12 | Parents |
| D30 / D60 | optional | Only if time is hospital-grade |

Navamsa: each 3°20′ of a sign maps to a navamsa sign (movable signs start from themselves; fixed from 9th; dual from 5th — Parashara). Test against known charts.

### 4.10 Dignity (Vedic)

| Planet | Exaltation | Debilitation | Own signs | Moolatrikona |
|---|---|---|---|---|
| Sun | 10° Aries | 10° Libra | Leo | 0–20° Leo |
| Moon | 3° Taurus | 3° Scorpio | Cancer | 3–20° Taurus |
| Mars | 28° Capricorn | 28° Cancer | Aries, Scorpio | 0–12° Aries |
| Mercury | 15° Virgo | 15° Pisces | Gemini, Virgo | 16–20° Virgo |
| Jupiter | 5° Cancer | 5° Capricorn | Sagittarius, Pisces | 0–10° Sagittarius |
| Venus | 27° Pisces | 27° Virgo | Taurus, Libra | 0–15° Libra |
| Saturn | 20° Libra | 20° Aries | Capricorn, Aquarius | 0–20° Aquarius |
| Rahu* | Taurus (common) | Scorpio | — | — |
| Ketu* | Scorpio (common) | Taurus | — | — |

\*Node dignity is school-dependent; label it.

**Neecha bhanga (cancellation of debilitation)** — Charak / Braha working rules for the app:

1. Lord of the debilitation sign is in a kendra from lagna or Moon.  
2. The debilitated planet is conjunct or aspected by its exaltation lord.  
3. The planet is exalted in navamsa.  
4. The exaltation lord of that planet is in a kendra.

If (1) or (3) plus a kendra-lord involvement: allow **Neecha Bhanga Raja Yoga** language: “fails first, succeeds after correction.” Never say “debility vanished.”

**Friendship (natural, Parashara)** — used in Graha-maitri and dignity:

- Sun friends: Moon, Mars, Jupiter. Enemies: Venus, Saturn. Neutral: Mercury.  
- Moon friends: Sun, Mercury. Enemies: none. Neutral: Mars, Jupiter, Venus, Saturn.  
- Mars friends: Sun, Moon, Jupiter. Enemies: Mercury. Neutral: Venus, Saturn.  
- Mercury friends: Sun, Venus. Enemies: Moon. Neutral: Mars, Jupiter, Saturn.  
- Jupiter friends: Sun, Moon, Mars. Enemies: Mercury, Venus. Neutral: Saturn.  
- Venus friends: Mercury, Saturn. Enemies: Sun, Moon. Neutral: Mars, Jupiter.  
- Saturn friends: Mercury, Venus. Enemies: Sun, Moon, Mars. Neutral: Jupiter.

Temporary friendship: planets in 2, 3, 4, 10, 11, 12 from each other are temporary friends; 1, 5, 6, 7, 8, 9 temporary enemies. Combine natural + temporary → five-fold (great friend … great enemy).

---

## 5. Twelve rashis / signs (both systems)

Western uses **tropical** dates (approx.; always compute, do not hardcode calendar dates). Vedic uses **sidereal** signs after ayanamsa.

| # | Sign | Sanskrit | Element | Mode | Ruler | Body (Vedic, Braha) | Body (Western) | Life tone |
|---|---|---|---|---|---|---|---|---|
| 1 | Aries | Mesha | Fire | Cardinal | Mars | Head | Head | initiate, heat, courage |
| 2 | Taurus | Vrisha | Earth | Fixed | Venus | Face/throat | Throat | hold, value, land |
| 3 | Gemini | Mithuna | Air | Mutable | Mercury | Shoulders/arms | Arms/lungs | speech, skill, siblings |
| 4 | Cancer | Karka | Water | Cardinal | Moon | Chest | Chest/stomach | home, mother, protect |
| 5 | Leo | Simha | Fire | Fixed | Sun | Heart/upper belly | Heart/spine | pride, children, stage |
| 6 | Virgo | Kanya | Earth | Mutable | Mercury | Gut | Gut/nerves | edit, service, health |
| 7 | Libra | Tula | Air | Cardinal | Venus | Lower belly | Kidneys/lumbar | other, contract, balance |
| 8 | Scorpio | Vrischika | Water | Fixed | Mars | Genitals | Genitals/elimination | depth, tax, sex, occult |
| 9 | Sagittarius | Dhanu | Fire | Mutable | Jupiter | Thighs | Hips/thighs | dharma, travel, teacher |
| 10 | Capricorn | Makara | Earth | Cardinal | Saturn | Knees | Knees/bones | duty, status, time |
| 11 | Aquarius | Kumbha | Air | Fixed | Saturn | Calves | Circulation/ankles | network, odd, future |
| 12 | Pisces | Meena | Water | Mutable | Jupiter | Feet | Feet/lymph | dissolve, foreign, sleep |

**Elements & modes (Tompkins / Taylor):** fire wants action, earth wants results, air wants meaning, water wants bond; cardinal starts, fixed sustains, mutable adapts. Use for psychology, not events.

---

## 6. Houses / bhavas

Count **whole-sign** for Vedic: house 1 = lagna rashi, house 2 = next rashi, etc.

| House | Vedic (Charak / Levacy / Braha) | Western (Houlding / Tompkins / Taylor) |
|---|---|---|
| 1 | Tanu: body, self, fame, health start | Identity, appearance, ASC |
| 2 | Dhana: speech, family, food, savings | Money, values, movable goods |
| 3 | Sahaja: courage, siblings, short travel, craft | Communication, siblings, local life |
| 4 | Sukha: mother, home, vehicles, land, chest | Home, parent, IC, roots |
| 5 | Putra: children, intellect, romance, poorvapunya | Creativity, romance, children, speculation |
| 6 | Ripu: enemies, debt, illness, service, pets | Work, health, employees, duty |
| 7 | Kalatra: spouse, partner, open other, travel | Marriage, contracts, DESC |
| 8 | Ayur: death/transformation, in-laws, occult, tax, sex, other’s money | Shared money, crisis, intimacy |
| 9 | Dharma: father, guru, luck, law, long travel | Belief, travel, publishing, higher mind |
| 10 | Karma: career, status, government, actions | Vocation, MC, public name |
| 11 | Labha: gains, friends, networks, elder sibling, income | Friends, groups, hopes, income |
| 12 | Vyaya: loss, sleep, foreign, ashram, hospital, moksha, expenses | Retreat, exile, undoing, charity |

**Strength:** kendras 1,4,7,10; trikonas 1,5,9; dusthanas 6,8,12; upachayas 3,6,10,11 (grow with time). Marakas: 2 and 7 (and their lords) — use for *end of a chapter*, never as a death sentence (Charak’s caution in the Kathmandu method notes).

**Yogakaraka** (Braha / Charak): planet that owns **both a kendra and a trikona** for that lagna.

| Lagna | Yogakaraka |
|---|---|
| Aries | Sun (5) is trikona only; **none classic** like Venus for Aquarius — Mars is lagnesh. Treat Sun + Jupiter carefully |
| Taurus | Saturn (9+10) |
| Gemini | none single; Venus (5+12) mixed |
| Cancer | Mars (5+10) |
| Leo | Mars (4+9) |
| Virgo | none clean; Venus mixed |
| Libra | Saturn (4+5) |
| Scorpio | Moon is 9; Mars lagnesh — Jupiter (2+5) beneficial |
| Sagittarius | none like Saturn for Libra |
| Capricorn | Venus (5+10) |
| Aquarius | **Venus (4+9)** |
| Pisces | Mars (2+9) / Moon mixed |

Implement yogakaraka as: `owns at least one of {4,7,10} AND at least one of {5,9}` (1 is both but lagnesh is not automatically yogakaraka).

**Empty houses** are read through their **lords** (Q14 method). Never say “nothing happens in an empty house.”

---

## 7. Nakshatras (complete)

Spans are **sidereal**, from 0° Mesha. Nadi column follows **Charak XXVII** (PocketAstro matching default). Yoni/Gana follow Charak + Levacy.

| # | Nakshatra | Span | Lord | Yoni | Gana | Nadi | Nature | Deity | Pivot meaning |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Ashwini | 000°00'–013°20' | Ketu | Horse | Deva | Adya | Light | Ashvini Kumaras | start, heal, speed |
| 2 | Bharani | 013°20'–026°40' | Venus | Elephant | Manushya | Madhya | Fierce | Yama | carry, birth, restraint |
| 3 | Krittika | 026°40'–040°00' | Sun | Goat | Rakshasa | Antya | Sharp | Agni | cut, purify, ambition |
| 4 | Rohini | 040°00'–053°20' | Moon | Cobra | Manushya | Antya | Fixed | Brahma | grow, beauty, fertility |
| 5 | Mrigashira | 053°20'–066°40' | Mars | Serpent | Deva | Madhya | Soft | Soma | search, quest |
| 6 | Ardra | 066°40'–080°00' | Rahu | Dog | Manushya | Adya | Sharp | Rudra | storm, intellect |
| 7 | Punarvasu | 080°00'–093°20' | Jupiter | Cat | Deva | Adya | Movable | Aditi | return, renew |
| 8 | Pushya | 093°20'–106°40' | Saturn | Goat | Deva | Madhya | Light | Brihaspati | nourish, dharma |
| 9 | Ashlesha | 106°40'–120°00' | Mercury | Cat | Rakshasa | Antya | Sharp | Nagas | coil, research |
| 10 | Magha | 120°00'–133°20' | Ketu | Rat | Rakshasa | Antya | Fierce | Pitris | throne, ancestors |
| 11 | Purva Phalguni | 133°20'–146°40' | Venus | Rat | Manushya | Madhya | Fierce | Bhaga | pleasure, romance |
| 12 | Uttara Phalguni | 146°40'–160°00' | Sun | Cow | Manushya | Adya | Fixed | Aryaman | vows, patronage |
| 13 | Hasta | 160°00'–173°20' | Moon | Buffalo | Deva | Adya | Light | Savitar | hands, craft |
| 14 | Chitra | 173°20'–186°40' | Mars | Tiger | Rakshasa | Madhya | Soft | Tvashtar | design, brilliance |
| 15 | Swati | 186°40'–200°00' | Rahu | Buffalo | Deva | Antya | Movable | Vayu | independence |
| 16 | Vishakha | 200°00'–213°20' | Jupiter | Tiger | Rakshasa | Antya | Sharp | Indra-Agni | forked drive |
| 17 | Anuradha | 213°20'–226°40' | Saturn | Deer | Deva | Madhya | Tender | Mitra | devotion, ally |
| 18 | Jyeshtha | 226°40'–240°00' | Mercury | Deer | Rakshasa | Adya | Sharp | Indra | seniority |
| 19 | Mula | 240°00'–253°20' | Ketu | Dog | Rakshasa | Adya | Sharp | Nirriti | uproot, root |
| 20 | Purva Ashadha | 253°20'–266°40' | Venus | Monkey | Manushya | Madhya | Fierce | Apas | early victory |
| 21 | Uttara Ashadha | 266°40'–280°00' | Sun | Mongoose | Manushya | Antya | Fixed | Vishvedevas | lasting victory |
| 22 | Shravana | 280°00'–293°20' | Moon | Monkey | Deva | Antya | Movable | Vishnu | listen, path |
| 23 | Dhanishta | 293°20'–306°40' | Mars | Lion | Rakshasa | Madhya | Movable | Vasus | rhythm, wealth |
| 24 | Shatabhisha | 306°40'–320°00' | Rahu | Horse | Rakshasa | Adya | Movable | Varuna | veil, heal, solitude |
| 25 | Purva Bhadrapada | 320°00'–333°20' | Jupiter | Lion | Manushya | Adya | Fierce | Aja Ekapada | intensity |
| 26 | Uttara Bhadrapada | 333°20'–346°40' | Saturn | Cow | Manushya | Madhya | Fixed | Ahirbudhnya | depth, finish |
| 27 | Revati | 346°40'–360°00' | Mercury | Elephant | Deva | Antya | Soft | Pushan | nourish, crossing |

**Pada** (navamsa mapping inside the star): padas 1–4 = the four navamsas of that 13°20′. For matching, whole-star yoni/gana/nadi are enough; for character, use pada + DiCara tone of the star.

**Abhijit** (optional, Charak yoni): 6°40′00″–10°53′20″ Makara. Not used in Vimshottari. Used only in yoni if 28-star mode is on.

**Gandanta (muhurta / birth caution):** last pada of Ashlesha, Jyeshtha, Revati and first pada of Ashwini, Magha, Mula — junctions of water/fire. Warn; do not curse.

---

## 8. Kundli matching (marriage)

Pipeline — **never Ashtakoota alone** (Charak: modify for modern life; Levacy: three layers).

### 8.1 Layer A — Can this person marry at all?

For each chart:

- 7th house, 7th lord, Venus (men/all), Jupiter (women/all).  
- Afflicted 7th + 5th + weak Venus/Jupiter → “commitment capacity low,” not “never marry.”  
- D9 lagna and D9 7th.  
- Levacy: timing must exist (dasha of 7th/Venus/Jupiter + gochara) or the bond starts on rocky ground.

### 8.2 Layer B — Mangal / Kuja dosha (Charak XXVII)

Mars in **1, 4, 7, 8, or 12** from **lagna or Moon** = Mangal dosha in that frame.

**Cancellations / mitigations to encode:**

1. Both charts have Mangal dosha (match the blemish).  
2. Other malefic (Sun, Saturn, Rahu, Ketu) occupies 1/4/7/8/12 in the other chart.  
3. Levacy exception used in the Kathmandu notes: **Mars in Leo or Aquarius** often treated as not giving classical Kuja — **expose as a toggle**, default **middle path**: do not call a curse; still honour Mars’ 4/7/8 aspects.  
4. Mars in own/exaltation, or in 1st in some South-Indian lists excepted — show school.

**Never** predict death of spouse. Language: “heat on 4th/7th/8th; needs an equal, not a yes-person.”

### 8.3 Layer C — Ashtakoota (36 gunas)

Based on **Moon sign + Moon nakshatra** of both people.

| # | Koota | Max gunas | Rule (Charak) |
|---|---|---|---|
| 1 | Varna | 1 | Moon-sign caste: 4,8,12 Brahmin; 1,5,9 Kshatriya; 2,6,10 Vaishya; 3,7,11 Shudra. Groom same or higher than bride → 1 |
| 2 | Vashya | 2 | Same animal-class of rashi, or bride in groom’s vashya. Classes: quadruped (Aries, Taurus, 2nd half Sag, 1st half Cap); human (Gemini, Virgo, Libra, 1st half Sag, Aquarius); aquatic (Cancer, Pisces, 2nd half Cap); wild (Leo); insect (Scorpio). Encode Charak table XXVII-2 as JSON |
| 3 | Taara | 3 | Count nakshatras bride→groom inclusive, mod 9. Remainder 3,5,7 = 0 else 1.5. Same groom→bride. Sum |
| 4 | Yoni | 4 | Same yoni 4; friendly 3; neutral 2; unfriendly 1; mortal-enemy 0. Enemy pairs: horse–buffalo, elephant–lion, goat–monkey, serpent–mongoose, dog–deer, cat–rat, cow–tiger (standard lists; ship full 14×14 matrix) |
| 5 | Graha-maitri | 5 | Lords of the two Moon signs: friends/same=5; friend+neutral=4; both neutral=3; friend+enemy=1; neutral+enemy=0.5; both enemies=0 |
| 6 | Gana | 6 | Same gana best. Deva–Manushya ok-ish. Rakshasa–Deva worst. Table: same=6; Deva+Manushya=5 or 6 by school; Manushya+Rakshasa=1 or 0; Deva+Rakshasa=0. Ship Charak XXVII-6 |
| 7 | Bhakoot | 7 | Moon-sign distance 2/12, 6/8, 5/9 → 0 else 7. Mitigations: friendly lords on 2/12; 6/8 with friendly lords; same rashi different nakshatra is good |
| 8 | Nadi | 8 | **Same nadi = 0** (Nadi dosha). Different = 8. Exceptions: same rashi different nakshatra; same nakshatra different rashi |

**Score bands (Charak):** 24–36 excellent; 12–24 mediocre; **&lt;12** traditionally not recommended — but **override** if Layer A+D are strong and the couple already has a living bond (Charak: love match needs no matching; still show the numbers honestly).

**Nadi groups (Charak, implement exactly):**

- **Adya:** Ashwini, Ardra, Punarvasu, Uttara Phalguni, Hasta, Jyeshtha, Mula, Shatabhisha, Purva Bhadrapada  
- **Madhya:** Bharani, Mrigashira, Pushya, Purva Phalguni, Chitra, Anuradha, Purva Ashadha, Dhanishta, Uttara Bhadrapada  
- **Antya:** Krittika, Rohini, Ashlesha, Magha, Swati, Vishakha, Uttara Ashadha, Shravana, Revati  

### 8.4 Layer D — Overlay (Levacy + Sakoian + Stellas)

Score separately (0–100) and show beside Ashtakoota:

| Theme | Look for |
|---|---|
| Attraction | Lagna/Moon/Sun conjunction or opposition across charts (rasi or D9). Exception: Sun–Sun same/opposite = ego clash (“two kings”) |
| Karma | Rahu/Ketu to the other’s Sun/Moon/ASC |
| Passion | Mars–Venus; Mars–Mars (heat, not durability); Mars–Saturn (heat then duty) |
| Talk | Mercury contacts |
| Comfort | Moon–Venus, Jupiter–Venus, Venus–Venus |
| Security | Saturn–Jupiter; Saturn on 7th |
| Western synastry | Sakoian: planet of A in houses of B (especially 1, 5, 7, 8); conjunctions of personal planets |

**Spouse significators (Levacy):** woman’s partner ~ Jupiter; man’s ~ Venus; app should also always read **7th lord**. Mars = passion, not husband, in Levacy’s working rule.

### 8.5 Layer E — Timing the wedding

Do not bless a date unless **both** charts show:

- Dasha/antardasha of 7th lord, Venus, Jupiter, or lagna lord, **and**  
- Jupiter gochara on natal 7th, 7th lord, or Venus (Sutton), **and**  
- Avoid Mars-Ketu style cutting periods, Rahu-on-lagna fog, and classical muhurta blemishes (Vishti/Bhadra, Vyatipata, Vaidhriti, gandanta) when user asks for a **muhurta**.

---

## 9. Prediction engine (future)

### 9.1 Vedic order of operations (Charak + Braha + Levacy)

1. **Promise** — house, house lord, occupants, aspects, yogas, dignity, D9/D10. If the house does not promise a result, dasha will not invent it.  
2. **Dasha** — mahadasha sets the decade; antardasha sets the year; pratyantara sets the month. Read the AD planet **from the MD planet** (2nd from MD = money of that dasha, etc.).  
3. **Gochara** — times what dasha already allows. Primary: Saturn, Jupiter, Rahu/Ketu, Mars.  
4. **Vargas** — confirm (D9 marriage, D10 career).  
5. **Ashtakavarga** — optional strength of transiting sign (Charak XXX).  
6. **Remedies** — only after the calendar; gems never replace sleep, contracts, or medicine.

### 9.2 Dasha interpretation keys (Charak XV, condensed)

During a planet’s period, mix: (a) what the planet **is** (karaka), (b) **houses it owns**, (c) **house it sits in**, (d) **aspects**, (e) **avastha**.

| Planet | Native timing flavour |
|---|---|
| Sun | authority, father, title, vitality, government, pride |
| Moon | mind, mother, public, fluids, home mood, popularity |
| Mars | courage, land, siblings, surgery of life, conflict, career if 10th lord |
| Mercury | documents, speech, trade, nervous system, skill |
| Jupiter | spouse (for many), teacher, children, law, expansion, grace |
| Venus | marriage, vehicles, arts, money-comfort, yogakaraka when 4+9 or 5+10 |
| Saturn | delay, duty, longevity, grief, structure, foreign/12th work |
| Rahu | hunger, foreign, unconventional, scale, smoke, obsession |
| Ketu | cutting, moksha, loss of story, surgery, spiritual reset |

**Avasthas (Charak XII) — weight results, do not zero them:**

- Bala 0–6° odd / 24–30° even → ~25%  
- Kumara 6–12° odd / 18–24° even → ~50%  
- Yuva 12–18° → full  
- Vriddha 18–24° odd / 6–12° even → little  
- Mrita 24–30° odd / 0–6° even → weak / harsh  

Jagrad (own/exalt) full; swapna (friend/neutral) medium; sushupti (enemy/debil) weak — **prefer navamsa** for this triad (Jataka Parijata note in Charak).

### 9.3 Gochara (Levacy ch.14 / Charak XXIX)

| Transit | Meaning |
|---|---|
| Saturn on Moon (**Sade Sati**: 12th, 1st, **2nd** from Moon — ~7.5 years) | Pressure on mind, body, family money, and duty |
| Saturn 8th from Moon (**Ashtama Shani**) | Hidden tests, tax, elder health, delay — toll, not deletion of dasha |
| Jupiter on lagna / 7th / 5th / 9th / natal Jupiter / Venus | Opportunity, marriage talks, children, dharma — **event if dasha agrees** |
| Rahu/Ketu on lagna or 7th | Identity restlessness, fog; do not tattoo a new self |
| Mars on 1/4/7/8/12 | Heat, accident-caution, fights |
| Double transit (Saturn + Jupiter on same house/lord) | Classic event window |

**Vedha / obstruction:** some gochara results are blocked by planets in vedha places — optional advanced toggle.

### 9.4 Western predictive stack (Rushman)

For each event type (marriage, job, move, health scare):

1. Natal **promise** (7th for marriage, 10th/MC for career, etc.).  
2. **Secondary progressed Moon** changing sign/house or hitting natal planet (~1°/month).  
3. **Outer-planet transits** (Saturn, Uranus, Neptune, Pluto) to natal ASC/MC/Sun/Moon/Venus.  
4. **Lunations** (New/Full Moon) on natal angles.  
5. **Solar return** as the year’s stage.

Confidence += 1 for each agreeing layer. PocketAstro should **prefer Vedic dasha+gochara for event dates** in the default “Jyotish” mode, and Rushman stack in “Western” mode. Dual mode shows both and flags agreement.

### 9.5 Life-area routers

| User topic | Vedic houses / karakas | Western |
|---|---|---|
| Self / health | 1, 6, lagnesh, Sun, Moon, Mars | ASC, 6th, Sun, Saturn |
| Money | 2, 11, 8, Jupiter, 2nd lord | 2nd, 8th, Venus, Jupiter |
| Career | 10, 6, 7, 10th lord, Saturn, Sun | MC, Saturn, 10th, 6th |
| Marriage | 7, 2, 8, Venus, Jupiter, D9 | 7th, Venus, DESC, Juno optional |
| Home / mother | 4, Moon, Venus (vehicles) | IC, Moon, 4th |
| Father / luck | 9, Sun, Jupiter | 9th, Sun, Jupiter |
| Children / romance | 5, Jupiter, D7 | 5th |
| Foreign / loss / sleep | 12, 9, Rahu | 12th, 9th |
| Education | 4, 5, 9, Mercury, Jupiter | 3rd, 9th, Mercury |

**Profession** from 10th lord sign/nakshatra + planets in 10th + D10. Ashwini + Mars in lagna type: healing, speed, independent craft, short decisive work — example of dictionary lookup, not a job title stamp.

### 9.6 Yogas (detect, don’t spam)

Implement detectors; only print if **active by dasha or dignity**:

- Raja yogas: kendra lord + trikona lord conjunct / mutual aspect / exchange.  
- Dhana yogas: 2nd/11th lords with 1/5/9.  
- Neecha bhanga as above.  
- Viparita raja: dusthana lords in dusthanas (Levacy).  
- Kemadruma: Moon with no planet 2nd/12th and no ken-dra planet with Moon — loneliness of mind.  
- Gaja Kesari: Moon–Jupiter in kendra from each other.  
- Kuja dosha as matching layer.  
- Combust: planet within Sun’s orb (~6–8°, Mercury tighter exception).  
- Retrograde: internalised / delayed / redo (Jupiter Rx = inner guru).

Charak XX–XXII has nabhasa and ownership yogas — encode the named ones as functions; do not dump all 300 names onto a mobile screen. Show top 5 by strength.

### 9.7 Muhurta (electional) — Charak XXVI

When user picks a date for marriage/launch:

Avoid: Vishti karana (Bhadra), Vyatipata, Vaidhriti, gandanta, Mrityu yoga nakshatra-weekday combos, Taara 3/5/7 from janma nakshatra in Krishna paksha.  
Prefer: lagna with benefics in kendra/trikona, malefics in 3/6/11; Abhijit muhurta (±24 min local noon) if nothing else is clean.  
Match the lagna to the topic (Libra/Pisces/Gemini often used for marriage — Charak’s lagna list).

### 9.8 Health language (mandatory)

Body rulerships may **suggest systems to take seriously**. The app must say: not diagnosis. Charak XXIV and Body Astrology are **flavour**, not ICD codes. Prefer: sleep, checkup, pitta-calming routine, accident caution in Mars dashas.

### 9.9 Remedies (Levacy XVI) — ranked

1. Behaviour that matches the planet (Mars: training; Saturn: schedule; Mercury: write once and file).  
2. Dana / service / mantra if user wants ritual.  
3. Colour/day of week.  
4. Gemstones **last**, and only if the planet is a functional benefic. Never sell a stone as a cure.

---

## 10. Western natal dictionary (pivot)

**Planets (Taylor / Tompkins / Stellas):**

| Planet | Verb |
|---|---|
| Sun | identity, vitality, father/boss, purpose |
| Moon | need, body-clock, mother, public mood |
| Mercury | think, say, trade, learn |
| Venus | attract, value, art, glue |
| Mars | act, anger, desire, cut |
| Jupiter | grow, mean, teach, luck |
| Saturn | limit, age, structure, fear, mastery |
| Uranus | wake, break, invent |
| Neptune | dissolve, imagine, leak, mystic |
| Pluto | compel, purge, power |
| North Node | hunger / growth (Western); Rahu in Jyotish |
| South Node | default / release; Ketu |
| Chiron | wound/skill (optional) |

**Angles:** ASC = how you meet the world; DESC = the other; MC = vocation; IC = root.

**Synthesis (Tompkins ch.8):** element imbalance → coping style; aspect patterns (T-square, grand trine, yod, stellium) → plot; house emphasis → stage of life.

**Degree symbols (Hill):** optional one-liner for Sun/Moon/ASC degree. Never use as timing.

---

## 11. Ask PocketAstro (offline Q&A)

No internet. Answers = **intent classification** + **chart facts** + **templates from this file**.

### 11.1 Intents (map user text)

Reuse the 62-question taxonomy from the library’s Q&A PDFs, generalised off the 1992 example:

| Intent id | Examples | Data pulled |
|---|---|---|
| `birth_time_ok` | Is my time accurate? | Lagna degree to next sign; D9 boundary; Moon speed |
| `system` | Vedic or Western? | Active settings |
| `not_promised` | What won’t happen easily? | Weak houses, no yoga, dusthana lords |
| `now_dasha` | What period am I in? | MD/AD/PD + dates |
| `next_window` | Best time to marry / launch | Cross dasha × gochara next 5 years |
| `forbidden_window` | What should I not start? | Ketu AD, Rahu-on-lagna, Ashtama Shani |
| `career` | Job vs business, fields | 10th lord, Mars/Sun/Saturn, D10 |
| `money` | Wealth, delay, foreign money | 2/11/12, Venus, Saturn aspects |
| `marriage_if` | Is marriage promised? | 7th, D9, Jupiter/Venus |
| `spouse_type` | What is the partner like? | 7th sign/lord, planets in 7th, D9 |
| `manglik` | Am I manglik? | Mars 1/4/7/8/12 + exceptions |
| `match_check` | Will we work? | Full matching pipeline |
| `children` | Kids? | 5th, D7, Jupiter, Ketu-in-5 |
| `home` | House, move, mother | 4th lord, Moon, Saturn 4th |
| `parents` | Father/mother karma | 9th/4th, Sun/Moon, D12 |
| `foreign` | Abroad? | 12th, 9th, Rahu, Saturn |
| `health` | Body, burnout | 1/6/8, Mars/Moon, transits — + disclaimer |
| `psychology` | Why do I sabotage? | 12th, Saturn, Mercury, pattern language |
| `remedy` | Gems, mantra | Functional benefics + behaviour first |
| `90_days` | What now? | Immediate AD/PD + gochara |
| `calendar` | Push / wait / sign / rest | Month grid |
| `muhurta` | Pick a date | Electional engine |

If intent is unclear, ask one clarifying question. If the question needs a second chart, ask to add a partner profile.

### 11.2 Answer template

```
1. Direct answer (1–3 sentences), with confidence %.
2. Why (houses, lords, dasha, transit) — named system.
3. Window (dates) or “not timed.”
4. What would weaken this.
5. Disclaimer if health/legal/money.
```

### 11.3 Worked Q&A style (from the folder, generalised)

The 62 questions are the **product’s question bank**. Surface them as chips. Examples of routing:

- “When should I marry?” → `next_window` + marriage houses, not Sun-sign romance text.  
- “Are we compatible?” → matching pipeline, show 36 + overlay + timing.  
- “Will I be rich?” → 2nd/11th promise + Saturn delay language; never a number.  
- “Will I die / will they die?” → **refuse**. Offer “endings of chapters,” maraka as stress, emergency resources if self-harm.

### 11.4 Language packs

- **Technical** (Charak/Braha vocabulary).  
- **Simple** (the Simple Answers PDF tone).  
Keep both; user toggle.

---

## 12. Report generators

### 12.1 Natal report outline

1. Engine stamp (Lahiri, whole-sign, Placidus, true node).  
2. Lagna paragraph (sign + lord placement).  
3. Moon / nakshatra paragraph (DiCara tone).  
4. Sun paragraph.  
5. Each planet: dignity, house, lordship, aspect highlights.  
6. Yogas (top).  
7. D9 summary.  
8. Psychological pattern (Greene/Marks **as psychology**, not fate).  
9. Current dasha + 24-month calendar.  
10. Life areas.  
11. “Not promised.”  
12. Next 90 days.

### 12.2 Match report outline

1. Two birth stamps.  
2. Ashtakoota table (8 rows + total).  
3. Nadi / Gana / Bhakoot flags with mitigations.  
4. Mangal both sides.  
5. Overlay (attraction / talk / heat / duty).  
6. D9 overlay.  
7. Timing overlap.  
8. Counsel: what each must not do to keep peace (12th-house habits vs 7th heat).

### 12.3 Confidence formula (app)

```
data = 1.0 if hospital time else 0.7 if clock else 0.3 unknown
agree = agreeing_techniques / 3   # dasha, transit, varga
yoga = 1.0 if supporting yoga else 0.6
score = 100 * data * (0.5 + 0.5*agree) * yoga
```

Cap event claims at **75** even if math is perfect. Astronomy can be 99.99% of an inch; biography cannot.

---

## 13. Flutter / offline implementation notes

| Piece | Suggestion |
|---|---|
| Ephemeris | `sweph` / bundled Swiss files, or FFI to `libswe` |
| Atlas | Offline cities SQLite (Nepal + world capitals + user-added) |
| Charts | CustomPainter wheels; North + South Indian Vedic; Western 360° |
| State | Riverpod / Bloc; all local |
| PDF | `pdf` + `printing` |
| Q&A | Rule engine + this MD compiled to `assets/kb/*.json` |
| i18n | English + Nepali labels for grahas/rashis |
| Tests | Golden: 1992-04-14 03:57 Asia/Kathmandu → Kumbha lagna ~23°, Moon Leo Purva Phalguni, exalted Sun Aries, Venus Pisces, Mars Aquarius |

**Do not** ship copyrighted ebook PDFs inside the app. Ship **rules and tables**.

---

## 14. Compiled runtime tables (`assets/kb/`)

Built by `knowledge/build/*.py`; run `python3 knowledge/build/build_all.py` to
regenerate, `flutter test test/kb_test.dart` to verify. `prediction.json` is the
entry point and indexes the rest through `PredictionKb.moduleAssets`.

| Asset | Contents | Primary source |
|---|---|---|
| `prediction.json` | Forecast shortcuts, 14 event recipes, gochara + vedha for all nine grahas, order of judgment, confidence model, refusal list, module index | compiled from the modules below |
| `planets.json` | 9 grahas in full; 108 planet-in-sign + 108 planet-in-house readings; functional benefic/malefic/yogakaraka/maraka/badhaka for all 12 lagnas | Charak VI–VII, XII, XVIII–XIX; Braha; Levacy |
| `houses.json` | 12 bhavas in full + all 144 house-lord-in-house cells + rules for judging a house | Charak VII, XVII; Houlding |
| `nakshatras.json` | 27 records: lord, deity, symbol, shakti + result, gana, yoni, nadi, muhurta class, body part, careers, shadow, 4 padas with navamsa; gandanta, gandmool, Abhijit | Charak XXVI–XXVII; Sutton; DiCara |
| `yogas.json` | 77 yogas with machine-checkable conditions, effects, strength notes, cancellations — incl. all 32 Nabhasa | Charak XX–XXII |
| `doshas.json` | 15 doshas, each with an honest reading, full cancellation list and matched remedy | Charak XVI, XXVII; Sutton; Levacy 16 |
| `dashas.json` | Vimshottari mechanics, per-graha MD results, AD by house-distance and by relation, all 81 MD/AD cells, Yogini / Ashtottari / Chara / Kalachakra / Narayana, chara karakas | Charak XIV–XV; Sutton |
| `transits.json` | Gochara for 9 grahas × 12 houses from the Moon, the complete vedha table with its father-son exceptions, timing within a sign, returns, maturity ages, retrogression, eclipses, Western stack | Charak XXIX; Levacy 14; Rushman |
| `ashtakavarga.json` | Full bhinnashtakavarga benefic-point tables (verified against the classical 337), sarva thresholds, per-bindu readings, kakshya, house comparisons | Charak XXX |
| `strength.json` | Shadbala components + required minima, bhava bala, the three avastha systems, dignity order, combustion orbs, planetary war | Charak XII–XIII |
| `divisionals.json` | All 16 vargas with construction rules and what each reads; 4 vimshopaka schemes; birth-time accuracy per varga | Charak X; Sutton |
| `panchanga.json` | 30 tithis, 27 yogas, 11 karanas, weekday qualities, Rahu kaal / yamaganda / gulika, Abhijit, choghadiya, panchaka, tarabala, chandrabala, muhurta for 7 activities | Charak XXVI, XXIX |
| `remedies.json` | Gem, metal, finger, day, mantra, japa count, charity, fast, deity per graha — each paired with the practical counterpart the app leads with | Levacy 16; Charak XXIV |
| `interpretation.json` | Order of judgment, two-technique rule, confidence model, window rules, refusals, delivery rules, 14 per-topic prediction recipes | Charak VII/XV/XXIX/XXX; Levacy; Rushman; Sutton |
| `degrees.json` | 360 tropical degree symbols with keywords and cautions (Western layer only) | Hill |
| `ashtakoota.json` | 36-guna matching tables | Charak XXVII |
| `catalog.json` | Full library scan: 56 PDFs, 15,555 pages, 25.1M characters | PyMuPDF full-text pass |

### 14.1 What the engine reads today

`lib/engine/kb.dart` exposes every table above through typed accessors. Live in
the forecast and interpretation paths:

- Vimshottari MD/AD/PD with dasa chidra, AD-from-MD-lord house, and the Ketu veto.
- Gochara for all nine grahas from the Moon, plus Mars from lagna, with the full
  Charak XXIX vedha table and its Sun/Saturn and Moon/Mercury exceptions.
- Sade Sati, Ashtama Shani, kantaka Shani, Saturn upachaya, Jupiter's aspect on
  transiting Saturn.
- 14 event topics scored by the two-technique rule with a 75 confidence ceiling.
- Planet-in-sign and planet-in-house for all nine grahas; house-lord-in-house for
  all 144 cells; nakshatra depth on the Moon; functional nature per lagna;
  remedies matched to the lagna lord, yogakaraka and running dasha lord.
- **All 77 yogas**, evaluated by `lib/engine/yoga.dart` against the declarative
  `conditions` in `yogas.json`. See §14.3.
- **Ashtakavarga bindus**, computed by `lib/engine/ashtakavarga.dart`. See §14.4.
- Health as lifestyle flags drawn from the graha body/disease tables.
- 36-guna matching.

### 14.2 Data present, evaluator not yet written

These tables ship and are reachable, but no runtime detector consumes them yet:

- Shadbala as a computed number.
- Vargas beyond D9 and D10.
- Panchanga and muhurta as a computed clock.
- The 360 degree symbols as a UI layer.

### 14.3 The yoga evaluator

`lib/engine/yoga.dart` reads the declarative `conditions` on each yoga and
tests them against a chart. Thirty-one condition types cover the catalogue,
from `kendra_from` to `contiguous_houses` to `neecha_bhanga`; the vocabulary is
documented at the top of `knowledge/build/build_yogas.py`, and an unknown
condition type never fires rather than defaulting to true.

Three things it does beyond matching:

1. **Cancellations in code, not just in prose.** Thirteen yogas carry
   `cancellation_checks` that the evaluator actually runs — Kemadruma's four
   escape routes, combustion and malefic-only aspect on the pancha mahapurusha
   yogas, a strong Jupiter and Moon defusing Shakata, a graha sharing a sign
   with a node breaking Kala Sarpa, a maraka being required before Daridra
   bites. A cancelled yoga is still reported, with the reason. Kemadruma,
   Shakata and Kala Sarpa are the three most over-sold combinations in popular
   astrology; silently dropping them is as dishonest as silently asserting them.
2. **Nabhasa precedence (Charak XX).** An Aakriti or Dala yoga supersedes an
   Aashraya yoga, and both supersede a Sankhya yoga. Gola is the stated
   exception: it survives and cancels the Aashraya yoga instead.
3. **Named placements.** Every hit reports what formed it on this chart —
   "4th lord Venus and 5th lord Mercury are conjunct in Pisces" — not a restated
   definition.

Two judgment calls are worth knowing about, because they change results:

- **The seven, not the nine.** Nabhasa, Aakriti and Sankhya yogas are evaluated
  on the Sun through Saturn only. Rahu and Ketu take no part, per Charak XX.
  The nodes *are* counted for Kemadruma, Sunapha and Anapha, which are
  complements of one another and must use the same exclusion set.
- **Conditional benefics.** The Moon counts as a natural benefic only between
  90° and 270° of elongation — the careful reading of paksha bala, not "any
  waxing Moon". Mercury is corrupted by sharing a sign with Mars, Saturn, a
  node or a waning Moon, but *not* by the Sun, since Sun with Mercury is the
  auspicious Budhaditya. Both thresholds live in `planets.json` under
  `natural_benefic_rules` so they can be argued with in data.

`test/yoga_test.dart` builds one synthetic chart per yoga, to its classical
definition, and asserts detection on all 77 — plus the cancellation behaviour,
the precedence rules, and that no lagna-bound yoga runs without a birth time.
Adding a yoga to the catalogue without a fixture fails the suite.

### 14.4 The ashtakavarga evaluator

`lib/engine/ashtakavarga.dart` turns the benefic-point tables into numbers for
a chart. For each of the seven grahas it walks the eight contributors, counts
the listed house from each contributor's own sign, and records *which*
contributor placed each bindu — the prastara. From that it derives:

- the seven bhinnashtakavargas, by sign and by house;
- the sarvashtakavarga, with the strong and weak houses and the sharpest step
  between adjacent houses (Charak XXX point 10);
- the kakshya a transiting graha occupies, and the 0-to-7 day grade from how
  many grahas sit in a kakshya that carries a bindu;
- the transit verdict — delivers at 5+, mixed at 4, withholds at 0-3;
- the sarvashtakavarga house comparisons, evaluated rather than merely listed;
- the dignity override, where bindus and dignity disagree (Charak XXX points 7
  and 8): an exalted graha on three bindus, or a debilitated one on seven.

**It gates the forecast, it does not merely decorate it.** A Jupiter transit
that lands on the right house but holds fewer than four bindus there stops
counting as a confirming technique — a veto applied before the two-technique
rule, in the same place vedha is applied. Above that line it contributes the
±5 the confidence model specifies.

**It is withheld without a birth time.** The lagna is one of the eight
contributors; without it the totals cannot reach 337 and the 28-bindu average
is meaningless. A seven-eighths version would look authoritative and be wrong,
so the engine returns nothing and says why.

**Trikona and ekadhipatya shodhana are deliberately absent.** The reductions
are not in the extracted corpus — Charak calls the elaborate parts of the
technique out of scope — and their principal classical use is Ayurdaya, which
PocketAstro refuses. Implementing an unsourced reduction to feed a refused
calculation would be worse than the gap.

`test/ashtakavarga_test.dart` tests the arithmetic against its invariants
rather than a single fixture: across 200 pseudo-random charts the per-graha
totals must stay at 48/49/39/54/56/52/39, the sarva must stay at 337, and no
sign may exceed 8 bindus in a bhinna or 56 in the sarva. A counting-direction
or modular-arithmetic bug breaks at least one of those. Separate tests pin the
direction of counting (house 1 is the contributor's own sign, house 11 lands
ten signs later), confirm that moving the lagna moves only the lagna's
contributions, and check the forecast integration end to end.

---

## 15. Per-book method notes (paraphrase only)

**Charak** — Predictive Jyotish is lords + dasha + gochara. Matching is Moon-based 36 gunas plus Mangal. Muhurta is panchanga hygiene. Do not literalise death/king language.

**Braha** — Name the ayanamsa. Yogakaraka is the royal planet. House lords in D1 are the backbone; vargas refine. Dasha start is hypersensitive to Moon.

**Sutton** — Jyotish as a guide for living in a cosmic framework; Jupiter transits can be events, not only moods.

**Levacy** — Compatibility = attraction + capacity to commit + shared timing. Nakshatras time muhurta and dasha. Nodes = destiny lessons. Remedies and Vastu are adjuncts.

**DiCara** — Each star is a god/story; use for flavour of Moon, lagna, dasha lord’s star.

**Houlding** — Houses are places in the sky, not just 12 topics; 12th is cadent undoing; 7th is the other.

**Rushman** — Forecasts fail when only transits are used; stack progressions and lunations.

**Tompkins** — Synthesise elements, aspects, houses; don’t list planets in isolation.

**Sakoian** — Synastry is planet-in-the-other’s-houses plus conjunctions.

**Stellas** — Western compatibility + prediction pedagogy; good for UI teaching copy.

**Woolfolk / Taylor / DK** — Western ABC: signs, planets, houses, aspects, chart.

**Greene / Marks / Nicholas** — Psychology and nodes; never override dasha timing.

**Goldschneider / Starsky / Gat** — Sign-pair colour for love reports; subordinate to kundli match.

**Hill** — Sabian degrees as optional poetry.

**Skinner** — Markets/mundane; keep out of personal kundli unless user opens “world” mode.

**Fiction and erotic sign-books** — entertainment modules only.

---

## 16. Ethical rules baked into the engine

1. No death dates, no “you will be a widow.”  
2. No medical diagnosis; body notes are lifestyle flags.  
3. No guaranteed lottery, conception, or court outcome.  
4. Nadi dosha and Mangal are **discussion**, not a ban on love.  
5. A living consensual relationship outranks a 16/36 score.  
6. Always print system settings.  
7. Always print that this is interpretive.  
8. Q&A must refuse self-harm methods and redirect to local help.

---

## 17. Minimum test nativity (from this folder)

Use as CI fixture (values from the library’s own generated readings; recompute with Swiss Ephemeris and Lahiri):

- 14 April 1992, 03:57 Asia/Kathmandu, 27.7172°N 85.3240°E  
- Lagna ~ 23° Aquarius, nakshatra Purva Bhadrapada  
- Sun ~ 0° Aries Ashwini, exalted, vargottama, 3rd whole-sign  
- Moon ~ 17° Leo Purva Phalguni, 7th  
- Mars ~ 19° Aquarius Shatabhisha, 1st (MD lord from 2022)  
- Mercury ~ 6° Pisces, 2nd, debilitated with neecha bhanga  
- Jupiter Rx ~ 11° Leo Magha, 7th  
- Venus ~ 14° Pisces, exalted yogakaraka, 2nd  
- Saturn ~ 23° Capricorn Shravana, 12th, own sign (lagna lord)  
- Rahu ~ 10° Sagittarius Mula, 11th; Ketu Gemini 5th  
- D9 lagna Gemini (time-sensitive)

If PocketAstro disagrees by more than ~1° on grahas or a different lagna, the engine is wrong.

---

## 18. What was scanned vs what is in this file

**Second pass (full text).** Every one of the 56 PDFs was re-opened and every
page extracted — 15,555 pages, 25,128,486 characters, against the ~2.1M
characters the first sampling scan saw. `knowledge/extract/_catalog_full.json`
records pages, characters, characters-per-page, table of contents, role and
which runtime tables each source fed. Two books remain image-only and
contributed nothing: *All Around the Zodiac* (Bil Tierney) and *The Only Way to
Learn Astrology* (Marion D. March); they stay catalogued as sources. OCR of
those two is the one remaining way to widen the corpus.

The technical chapters the tables were compiled from are extracted verbatim into
`knowledge/extract/deep/`, one file per chapter, with a `README.md` mapping each
extract to the table it produced. `knowledge/build/extract_chapters.py`
regenerates them, so every number in `assets/kb/` is traceable to a page range.

Textbooks with extractable text contributed **method**. Personal and generated
PDFs contributed **templates and the test nativity**. Relationship
coffee-table books contributed **tone for love copy**, not timing.

Two figures were checked against their classical invariants rather than taken on
trust: the bhinnashtakavarga tables sum to the canonical 48/49/39/54/56/52/39 and
a grand total of 337, and the 81 Vimshottari sub-periods reproduce
`parent × sub ÷ 120`. Both are asserted in `test/kb_test.dart`.

This file is the pivot: **tables + pipelines + product rules** sufficient to
build PocketAstro offline — charts, matching, forecasts with confidence, local
save, PDF export, and on-device Q&A.

When a rule in Charak and Levacy conflicts, **show both** and default to Charak
for matching numbers and Levacy for overlay/timing language, because that is how
the existing Kathmandu reports in this folder already work.

### 18.1 Editorial policy on the classical sources

The classics are followed for structure and rule, and restated in modern
language. Where an aphorism is fatalistic, misogynistic, or makes a mortality
claim, the astrological signal is kept and the framing is not. Three of the
ethical rules in §16 are enforced in the data itself rather than in the UI:

- every dosha carries its cancellations and is not reportable without them;
- every remedy carries a practical counterpart, and that is what leads;
- the refusal list lives in `interpretation.json` and compiles into
  `prediction.json`, so it travels with the data.

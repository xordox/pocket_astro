# PocketAstro

Vedic and Western astrology for iOS, Android, and macOS. No account.

Charts, matching, forecasts, the knowledge base and Q&A are computed entirely on
your device and never touch the network. One feature does: searching for a
birthplace by name, and only when you tap **Search online**. Typing never sends
anything. A bundled atlas of 34,000 places, everywhere you have used before, and
manual coordinates all work with no connection at all, so a chart can always be
created offline.

The home screen opens on a daily reading by moon sign, computed from where the
grahas actually are rather than written in advance. A fifteen-lesson course is
reachable from there too, and from inside any chart.

Place data is [GeoNames](https://www.geonames.org/) (CC BY 4.0), bundled offline
as `assets/atlas/cities.txt` and rebuilt by `tool/build_atlas.py`. Online search
for anything outside it uses [Open-Meteo](https://open-meteo.com/) over the same
source; its free tier is non-commercial, and the provider sits behind a one-class
`Geocoder` interface if that needs to change.

Historical timezone offsets come from the IANA database via the `timezone`
package, which carries the full transition history — Madras Mean Time at +05:21
before 1906, Eastern War Time in 1943, British Double Summer Time in 1947. The
birth form shows the offset a chart will be built with before you save it,
because a one-hour error moves the ascendant fifteen degrees.

## What it does

**Charts**
- Dual natal charts — sidereal Vedic and tropical Western, from one computation
- Nine ayanamsas (Lahiri, True Chitra, Raman, KP, Fagan–Bradley, Yukteshwar,
  J. N. Bhasin, Pushya-paksha, Galactic Centre) and ten house systems
  (Placidus, Koch, Porphyry, Regiomontanus, Campanus, Alcabitius, Topocentric,
  Equal, Whole Sign, Sripati) — chosen per chart, recorded on every chart
- Mean or true node; geocentric or topocentric
- North Indian, South Indian and Western circular wheels, plus bi-wheels for
  transits and progressions
- Whole-sign and bhava chalit houses side by side, with disagreements marked
- Retrograde, stationary and daily speed for every graha

**Vedic**
- The full Shodashavarga — sixteen divisional charts, each with its own lagna
- Shadbala, Bhava bala, Ishta/Kashta phala, Vimshopaka bala
- Avasthas (Baladi, Jagradadi, Deeptadi), combustion, graha yuddha
- Vimshottari to five levels, from the Moon, Lagna or Sun; Ashtottari with its
  applicability rule; Yogini
- Jaimini — chara karakas, arudha padas, karakamsa, rashi drishti, argala,
  chara dasha
- Ashtakavarga with prastara, kakshya, trikona and ekadhipatya reductions and
  sodhya pinda
- Neecha bhanga, kuja dosha bhanga and kemadruma bhanga, computed not suggested
- Varshaphal — solar return, Muntha, Varshesha, Tajika aspects, Mudda dasha
- KP — sub-lords, the 249 divisions, four-step significators, cuspal sub-lords,
  ruling planets, horary
- Muhurta — electional search over a date range against a stated purpose
- Sudarshana chakra

**Western**
- Aspect engine with minor aspects, editable orbs, applying/separating, exact
  dates, out-of-sign flags and pattern detection
- Declinations, parallels, antiscia, midpoints
- Chiron, Lilith, Ceres, Pallas, Juno, Vesta, Part of Fortune and Spirit,
  Vertex, East Point
- Secondary and tertiary progressions, solar arc directions
- Solar, lunar and planetary returns; relocation
- Traditional layer — sect, full essential dignity scoring, almuten figuris,
  the Hermetic lots
- Time lords — profections, zodiacal releasing, firdaria
- Synastry, composite and Davison charts
- Harmonic and draconic charts

**Timing**
- Transit timeline with exact dates, retrograde triple passes, stations,
  ingresses, nakshatra changes, lunations and eclipses
- Sade sati windows, dated
- Ephemeris viewer — a month at a time

**Calendar and election**
- Full Hindu calendar — samvatsara, Shaka and Vikram years, ritu, ayana,
  sankrantis, festivals, Ekadashi — in both amanta and purnimanta reckoning
- Muhurta electional search against a stated purpose
- Western horary with considerations before judgment, significators,
  perfection, and unequal planetary hours
- Ephemeris viewer, a month at a time

**Practice**
- 34,000-place offline atlas, with the offset a chart will use shown before it
  is saved, and an explicit local-mean-time mode for older records
- Tags, search across names, places, tags and notes, and a dated session log
- JSON backup and CSV import/export
- Rectification workbench: live sensitivity slider, and event fitting
- Kundli matching — Ashtakoota plus Rajju, Vedha, Mahendra, Stree-Deergha,
  Papasamya, nadi exceptions, navamsa compatibility and dasha sandhi
- Life-area report with confidence scores
- On-device Q&A from the open chart
- Save kundlis locally and export a readable PDF
- A provenance panel on every chart saying exactly how it was computed

## Accuracy

Positions come from a truncated VSOP87 solar theory and the full Meeus lunar
series, with ΔT, nutation, annual aberration and light-time correction applied,
and an optional topocentric reduction. `test/conformance_test.dart` checks them
against Meeus's published worked examples on every build:

| Body | Agreement |
| --- | --- |
| Sun | ~2 arcseconds |
| Moon | ~10 arcseconds |
| Mercury–Mars | ~1 arcminute |
| Jupiter–Pluto | ~2 arcminutes |
| Chiron, asteroids | approximate — no perturbations |

That is natal-chart grade. It is **not** Swiss Ephemeris grade for the planets,
and the app says so in its own accuracy panel rather than implying otherwise.
Interpretations are traditional rules, not guaranteed events. The app never
presents forecasts as medical, legal, or financial advice.

Knowledge lives **inside this repo** (nothing required from `_pocketastro_extract`):

- `POCKETASTRO_KNOWLEDGE_BASE.md` — compiled engine spec
- `assets/kb/` — runtime tables (`ashtakoota.json`, `catalog.json`)
- `knowledge/extract/` — ebook catalog, deep chapter extracts, and scan scripts


## Run

```bash
cd PocketAstro
flutter pub get
flutter test
flutter run
```

Demo kundli: **14 April 1992, 3:57 AM, Kathmandu** (button on the empty library).

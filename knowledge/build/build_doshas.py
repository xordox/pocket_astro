#!/usr/bin/env python3
"""Dosha catalogue with detection conditions, cancellations and honest framing.

Sources: Charak, Elements of Vedic Astrology, ch. XVI (balarishta and arishta
bhanga), XXVII (matching — kuja dosha and its cancellations), XXIX (gochara);
Sutton (the karmic axis); Levacy, ch. 16 (remedial measures).

Every dosha in this file carries an explicit cancellation list. PocketAstro's
rule: a dosha is never reported without first evaluating its cancellations.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

D = [
 dict(id="kuja", name="Kuja Dosha (Manglik / Mangal Dosha)", severity="moderate",
   detect={"type": "planet_in_houses", "planet": "Mars",
           "houses": [1, 2, 4, 7, 8, 12], "from": ["lagna", "Moon", "Venus"]},
   description=(
     "Mars in the 1st, 2nd, 4th, 7th, 8th or 12th — counted from the lagna, and also "
     "checked from the Moon and from Venus. Classically read as friction, heat and "
     "impatience inside marriage."),
   honest_reading=(
     "What it actually describes is a person who brings a lot of force into intimacy. "
     "It is a compatibility parameter, not a defect. Roughly one chart in four carries it, "
     "and it is cancelled more often than not."),
   cancellations=[
     "Both partners are manglik — the dosha is mutually cancelled. This is the most common resolution.",
     "Mars is in its own sign (Aries, Scorpio) or exalted (Capricorn) in the dosha house.",
     "Mars is in Cancer or Leo in the 7th, or in Aquarius in the 4th, or in Sagittarius or Pisces in the 12th (sign-based exemptions).",
     "Mars is aspected by or conjunct Jupiter or the Moon.",
     "Mars is conjunct or aspected by a strong benefic, or sits in a benefic's sign.",
     "Saturn occupies the same house as Mars, or aspects it.",
     "The chart is Aries or Scorpio lagna, where Mars is the lagna lord.",
     "Both partners are past 28; the classical severity is read as diminishing with age.",
   ],
   remedy=["Hanuman Chalisa or Mangal beej mantra on Tuesdays",
           "red coral only if Mars is also a functional benefic for the lagna — never on the dosha alone",
           "physical outlet for the heat: sport, hard training, manual work"],
   never="Never use kuja dosha to tell someone a marriage will fail. It is one of eight-plus parameters."),

 dict(id="kala_sarpa", name="Kala Sarpa Dosha", severity="moderate",
   detect={"type": "node_axis_hemmed"},
   description="All seven grahas hemmed inside the Rahu–Ketu axis.",
   honest_reading=(
     "A life organised on a single axis: concentrated effort, results that arrive late "
     "and then all at once, and a strong sense of being carried by something. It correlates "
     "with unusual achievement as often as with struggle. It is a later, non-Parashari construct."),
   cancellations=[
     "Any graha conjunct Rahu or Ketu breaks the enclosure's force.",
     "One graha outside the axis makes it partial (Kala Amrita) rather than full.",
     "A strong lagna lord, or a raja yoga elsewhere, reduces it to a background theme.",
   ],
   remedy=["Rahu and Ketu beej mantras", "Nag Panchami observance", "serving strangers and the unhoused"],
   never="Never sold as a curse. It is a shape, not a sentence."),

 dict(id="sade_sati", name="Sade Sati", severity="major_transit",
   detect={"type": "transit_saturn_from_moon", "houses": [12, 1, 2]},
   description="Saturn transiting the 12th, 1st and 2nd from the natal Moon — about seven and a half years.",
   honest_reading=(
     "Three distinct phases, not one long punishment. The 12th-from-Moon phase drains sleep, "
     "money and old structures. The 1st-from-Moon phase presses identity and the body directly. "
     "The 2nd-from-Moon phase works on income, family and speech. It removes what was never load-bearing "
     "and makes permanent whatever survives it."),
   phases={
     "12": "Rising phase. Expenses, isolation, sleep loss, foreign moves, endings. Start the hygiene now.",
     "1": "Peak phase. Identity, body and duty all press at once. Structure the day; do not self-erase.",
     "2": "Setting phase. Income, family and speech under weight. Save more than you display.",
   },
   cancellations=[
     "Saturn strong (own sign, exalted, moolatrikona) in transit gives a working Sade Sati rather than a crushing one.",
     "Jupiter aspecting transiting Saturn lightens the toll materially.",
     "A favourable running dasha reduces it to a period of hard, productive work.",
     "Saturn as a functional benefic for the lagna (Taurus, Libra, Capricorn, Aquarius) is notably easier.",
   ],
   remedy=["Saturday discipline: fixed sleep, honest accounts, service",
           "Hanuman Chalisa", "Shani mantra", "donation of black sesame, iron, or a hot meal to a worker",
           "blue sapphire only after a trial period and only if Saturn is a functional benefic"],
   never="Never predicted as death, ruin or the end of a career."),

 dict(id="ashtama_shani", name="Ashtama Shani", severity="major_transit",
   detect={"type": "transit_saturn_from_moon", "houses": [8]},
   description="Saturn transiting the 8th from the natal Moon — about two and a half years.",
   honest_reading=(
     "Hidden tests: tax, insurance, elders' health, chronic worry, the slow surfacing of "
     "things postponed. It is a toll on the running dasha, not a deletion of the chart's yogas."),
   cancellations=["Jupiter's aspect on transiting Saturn", "a strong 8th lord", "a supportive running dasha"],
   remedy=["Get the medical and financial paperwork current", "sleep", "Shani remedies as for Sade Sati"],
   never="Not a mortality indicator."),

 dict(id="kemadruma", name="Kemadruma Dosha", severity="moderate",
   detect={"type": "empty_from", "from": "Moon", "houses": [2, 12],
           "exclude": ["Sun", "Rahu", "Ketu"]},
   description=("Both the 2nd and 12th from the Moon are empty. The Sun and the two "
                "nodes do not count as support, which is the same exclusion Sunapha "
                "and Anapha use."),
   honest_reading="The mind has no buffer: events land without padding. It correlates with emotional self-reliance as much as with loneliness.",
   cancellations=[
     "Grahas in kendras from the lagna.",
     "Grahas in kendras from the Moon.",
     "All grahas aspecting the Moon.",
     "A strong Moon in a kendra, joined to or aspected by Mercury, Jupiter or Venus.",
   ],
   remedy=["Monday observance", "Chandra mantra", "deliberate community — the remedy is structural, not mineral"],
   never="Almost always cancelled. Check all four before mentioning it."),

 dict(id="gandmool", name="Gandmool Dosha", severity="minor",
   detect={"type": "moon_in_nakshatra", "nakshatras": ["Ashwini", "Ashlesha", "Magha", "Jyeshtha", "Mula", "Revati"]},
   description="Moon in a Ketu- or Mercury-ruled junction nakshatra.",
   honest_reading=(
     "An intense, uprooting start — often a difficult first few years for the family. "
     "It matures into unusual depth once the person stops fighting their own intensity."),
   cancellations=["Birth in the later padas of the nakshatra is milder.",
                  "A strong, well-aspected Moon largely neutralises it.",
                  "Traditional mool shanti performed at 27 days."],
   remedy=["Mool shanti at the 27th day (traditional)", "Ganesha or Ketu mantra", "Durga worship"],
   never="Not a marker of bad character or of harm to relatives."),

 dict(id="gandanta", name="Gandanta", severity="moderate",
   detect={"type": "planet_near_gandanta", "orb_deg": 3.3333,
           "junctions": [120.0, 240.0, 360.0]},
   description="A graha or the lagna within the water–fire seam: the last pada of Revati, Ashlesha or Jyeshtha into the first of Ashwini, Magha or Mula.",
   honest_reading=(
     "A karmic knot. The matter signified by that graha has to be re-founded in this life "
     "rather than inherited. Moon gandanta is felt emotionally; lagna gandanta physically."),
   cancellations=["Distance from the exact junction reduces it proportionally.",
                  "Benefic aspect on the gandanta graha.",
                  "Vargottama status of the gandanta graha."],
   remedy=["Traditional gandanta shanti", "the relevant graha's mantra", "patience with late starts in that domain"],
   never="Not an accident or mortality indicator."),

 dict(id="grahan", name="Grahan Dosha (eclipse affliction)", severity="moderate",
   detect={"type": "conjunct_node", "planets": ["Sun", "Moon"], "orb_deg": 10.0},
   description="The Sun or Moon conjunct Rahu or Ketu within about 10°.",
   honest_reading=(
     "Sun–node: the father, authority or the sense of self is obscured or foreign. "
     "Moon–node: the mind runs hot and the mother's story is unfinished. Both correlate "
     "with unusual capability in the eclipsed graha's domain once the person stops "
     "seeking ordinary validation there."),
   cancellations=["Wide orb (beyond 10°)", "strong benefic aspect", "the luminary in its own or exalted sign"],
   remedy=["Surya or Chandra mantra as appropriate", "Rahu/Ketu remedies",
           "concrete work on the father or mother relationship — this one is psychological before it is ritual"],
   never="Not an eye-disease or mental-illness prediction."),

 dict(id="pitru", name="Pitru Dosha", severity="moderate",
   detect={"type": "sun_or_9th_afflicted_by_nodes"},
   description="Sun, the 9th house or the 9th lord afflicted by Rahu, Ketu or Saturn.",
   honest_reading=(
     "Unfinished business in the paternal line — an interrupted inheritance, an absent or "
     "diminished father, or a dharma that was not handed down. Read it as a line of work, not a debt."),
   cancellations=["Jupiter's aspect on the 9th or on the Sun", "a strong, well-placed 9th lord"],
   remedy=["Shraddha and tarpana for the ancestors (traditional)", "feeding the elderly",
           "Surya Namaskar and Aditya Hridayam", "Pitru Paksha observance"],
   never="Not a claim about the father's fate."),

 dict(id="shrapit", name="Shrapit Dosha", severity="moderate",
   detect={"type": "conjunct", "a": "Saturn", "b": "Rahu", "same_house": True},
   description="Saturn and Rahu together in one house.",
   honest_reading=(
     "A heavy, obstructive combination: ambition under a ceiling, delay stacked on hunger. "
     "Its own remedy is time — it usually resolves after the Saturn maturity years."),
   cancellations=["Jupiter's aspect on the pair", "either graha in its own or exalted sign",
                  "the pair in an upachaya house (3, 6, 10, 11), where it becomes productive"],
   remedy=["Shani and Rahu mantras", "Saturday service", "Hanuman worship"],
   never="Not a curse from a past life to be paid for with money."),

 dict(id="angarak", name="Angarak Dosha", severity="minor",
   detect={"type": "conjunct", "a": "Mars", "b": "Rahu", "same_house": True},
   description="Mars conjunct Rahu.",
   honest_reading="Explosive drive: excellent for anything requiring nerve and terrible for anything requiring patience. Accident and anger flag.",
   cancellations=["Jupiter's aspect", "placement in an upachaya house", "Mars strong by sign"],
   remedy=["Hanuman Chalisa", "physical discipline", "no speculation during Mars or Rahu periods"],
   never="Not an accident prediction. A caution about pace."),

 dict(id="chandal", name="Guru Chandal Yoga", severity="moderate",
   detect={"type": "conjunct", "a": "Jupiter", "b": "Rahu", "same_house": True},
   description="Jupiter conjunct Rahu (Guru Chandal); with Ketu it is read similarly but more inwardly.",
   honest_reading=(
     "Wisdom mixed with hunger. Unorthodox belief, brilliant unconventional teaching, and a real "
     "risk of following — or becoming — the wrong teacher. Common in innovators."),
   cancellations=["Jupiter strong in its own or exalted sign", "benefic aspect on the pair",
                  "the pair in the 3rd, 6th, 10th or 11th"],
   remedy=["Guru mantra on Thursdays", "study with a real teacher rather than alone", "Vishnu worship"],
   never="Not a statement that the person is dishonest."),

 dict(id="daridra", name="Daridra Yoga", severity="moderate",
   detect={"type": "exchange", "a_house": 1, "b_house": 12},
   description="Lagna lord in the 12th with the 12th lord in the lagna, or the lagna lord afflicted in a trik house with the 2nd lord weak.",
   honest_reading="Money moves through without settling. The fix is structural — expenditure design, not earning harder.",
   cancellations=["A strong 2nd or 11th lord", "a dhana yoga elsewhere", "benefic aspect on the lagna lord"],
   remedy=["Lakshmi practice (traditional)", "an actual expenditure system", "Friday charity"],
   never="Never told to anyone as a prediction of poverty."),

 dict(id="nadi", name="Nadi Dosha (matching)", severity="matching",
   detect={"type": "same_nadi"},
   description="Both partners' Moons in the same nadi group (adya, madhya or antya). Scores zero of eight gunas.",
   honest_reading=(
     "The heaviest single koota in the 36-guna system, classically read for constitutional "
     "compatibility and progeny. It is one parameter among eight and has well-established exceptions."),
   cancellations=[
     "Both Moons in the same rashi but different nakshatras.",
     "Both Moons in the same nakshatra but different rashis.",
     "Both Moons in the same nakshatra and the same pada is the only truly unmitigated case.",
     "Rashi lords are the same, or are mutual friends.",
     "Strong 7th houses and a good bhakoot score in both charts.",
   ],
   remedy=["Maha Mrityunjaya japa (traditional)", "a frank medical conversation, which is the actual modern equivalent"],
   never="Never used alone to stop a marriage."),

 dict(id="bhakoot", name="Bhakoot Dosha (matching)", severity="matching",
   detect={"type": "moon_sign_distance", "bad": ["2/12", "6/8", "5/9"]},
   description="Moon signs 2/12, 6/8 or 5/9 apart. Scores zero of seven gunas.",
   honest_reading="Classically read for prosperity and longevity of the union; practically, for whether the two nervous systems run on the same clock.",
   cancellations=["2/12 and 6/8 are mitigated when the rashi lords are mutual friends or the same graha.",
                  "A strong graha maitri score offsets it.",
                  "Same rashi with different nakshatras is favourable rather than adverse."],
   remedy=["Not a mineral problem. Deliberate scheduling and separate recovery time."],
   never="Never used alone to stop a marriage."),
]

DOC = {
    "engine": "pocketastro-doshas",
    "version": 1,
    "sources": [
        "Charak, Elements of Vedic Astrology — ch. XVI (arishta bhanga), XXVII (matching), XXIX (gochara).",
        "Sutton, The Essentials of Vedic Astrology — Rahu and Ketu, the karmic axis.",
        "Levacy, Beneath a Vedic Sky — ch. 16, remedial measures.",
    ],
    "delivery_protocol": [
        "Evaluate every listed cancellation before a dosha is shown to a user at all.",
        "Report a surviving dosha as a parameter with a named remedy, never as a verdict.",
        "Never chain doshas into a prediction of death, divorce, childlessness or ruin.",
        "Where a dosha has a psychological reading, lead with that; the ritual remedy is secondary.",
        "Matching doshas (nadi, bhakoot) are reported as scores inside the 36-guna result, never as standalone refusals.",
    ],
    "doshas": D,
}
for out in (ROOT / "assets/kb/doshas.json", ROOT / "knowledge/extract/doshas.json"):
    out.write_text(json.dumps(DOC, indent=1, ensure_ascii=False) + "\n")
print("doshas.json", len(json.dumps(DOC)), "bytes,", len(D), "doshas")

#!/usr/bin/env python3
"""The judgment protocol: how PocketAstro converts chart data into a forecast.

Per-topic prediction recipes (houses, karakas, varga, dasha triggers, transit
triggers, negations, confidence weights) plus the order of judgment and the
delivery rules.

Sources: Charak, Elements of Vedic Astrology, ch. VII, XV, XXIX, XXX (the
promise / dasha / transit / ashtakavarga stack); Levacy, Beneath a Vedic Sky
(skills IV-VI); Braha; Rushman, The Art of Predictive Astrology (Western
confirmation); Sutton (putting it all together).
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def topic(key, title, houses, karakas, varga, dasha, jup_lagna, jup_moon,
          sat_ok, negations, evidence, language, western=""):
    return dict(
        key=key, title=title,
        houses=houses,
        primary_house=houses[0],
        karakas=karakas,
        varga=varga,
        dasha_planets=dasha,
        jupiter_gochara_houses_from_lagna=jup_lagna,
        jupiter_gochara_houses_from_moon=jup_moon,
        saturn_supportive_houses_from_moon=sat_ok,
        avoid_ad=negations["avoid_ad"],
        negations=negations,
        evidence=evidence,
        language=language,
        western=western,
    )


TOPICS = [
 topic("marriage", "Marriage / partnership",
   houses=[7, 2, 11, 8], karakas=["Venus", "Jupiter", "Moon"],
   varga=["D9 (navamsa) is decisive — read the D9 lagna, the D9 7th, and Venus in D9",
          "Vargottama Venus or a vargottama 7th lord upgrades the whole reading"],
   dasha=["Venus", "Jupiter", "7th lord", "2nd lord", "11th lord", "Darakaraka", "the graha in the 7th"],
   jup_lagna=[1, 5, 7, 9], jup_moon=[2, 5, 7, 11], sat_ok=[3, 6, 11],
   negations=dict(avoid_ad=["Ketu"],
     factors=["Ketu antardasha or pratyantara",
              "Ketu transiting the 5th, 7th or 10th from the Moon",
              "7th lord in a dusthana with no benefic aspect",
              "Venus combust and also weak in D9",
              "Saturn transiting the 7th from the Moon (contracts get real, but the romance does not)",
              "Ashtama Shani running"]),
   evidence=["natal promise: 7th house, 7th lord, Venus, and the D9",
             "dasha: a period lord connected to the 7th, 2nd, 11th, Venus or Jupiter",
             "gochara: Jupiter on the 1/5/7/9 from lagna or the 2/5/7/11 from the Moon",
             "ashtakavarga: 5+ bindus for Jupiter in the sign it is transiting"],
   language=("Say whether marriage is promised and what kind of partner the 7th describes. "
             "Give a window, not a date. Never name a person, never predict divorce, "
             "never use kuja dosha as a veto."),
   western="Transiting Jupiter or Saturn to the natal Descendant or Venus; progressed Moon to natal Venus or the 7th cusp (Rushman)."),

 topic("career", "Career / profession",
   houses=[10, 6, 1, 11], karakas=["Sun", "Saturn", "Mercury", "Jupiter"],
   varga=["D10 (dashamsa) is decisive — read the D10 lagna and the D10 10th lord",
          "Amatyakaraka in D10 names the field"],
   dasha=["Sun", "Saturn", "Mercury", "Mars", "10th lord", "6th lord", "Amatyakaraka", "Yogakaraka"],
   jup_lagna=[10, 11, 1, 2], jup_moon=[2, 9, 10, 11], sat_ok=[3, 6, 10, 11],
   negations=dict(avoid_ad=["Ketu"],
     factors=["10th lord in the 12th with no benefic aspect",
              "Saturn transiting the 10th from the Moon (obstacles, though the work still counts)",
              "Ketu antardasha for a job change requiring a permanent commitment",
              "Ashtakavarga: fewer than 4 bindus in the 10th"]),
   evidence=["natal promise: 10th house and lord, the D10, and the strongest graha in a kendra",
             "dasha: a period lord tied to the 10th, 6th, 11th or the Sun/Saturn/Mercury stack",
             "gochara: Jupiter on the 10th/11th from lagna, Saturn in an upachaya from the Moon",
             "ashtakavarga: 11th bindus higher than 10th means gain for less labour"],
   language=("Say whether the chart runs better as employment or as named work, and which "
             "window favours a move. Never name an employer. Never guarantee a salary."),
   western="Transiting Saturn or Jupiter to the natal Midheaven; Saturn return for a structural career reset (Rushman)."),

 topic("money", "Money / wealth",
   houses=[2, 11, 5, 9], karakas=["Jupiter", "Venus", "Mercury"],
   varga=["D2 (hora) for sustenance", "D9 for whether the dhana yoga actually delivers"],
   dasha=["Jupiter", "Venus", "Mercury", "2nd lord", "11th lord", "5th lord", "9th lord"],
   jup_lagna=[2, 5, 9, 11], jup_moon=[2, 5, 9, 11], sat_ok=[3, 6, 11],
   negations=dict(avoid_ad=["Ketu"],
     factors=["12th bindus exceeding 11th in sarvashtakavarga — spending outruns earning",
              "2nd and 11th lords both in dusthanas",
              "Rahu dasha with leverage involved",
              "Saturn transiting the 2nd from the Moon during Sade Sati's setting phase"]),
   evidence=["natal promise: a dhana yoga linking 1/2/5/9/11 lords, with a strong lagna lord",
             "dasha: a period lord inside that dhana yoga",
             "gochara: Jupiter on the 2nd or 11th from lagna or Moon",
             "ashtakavarga: 2nd bindus above 12th means accumulation beats expenditure"],
   language=("Describe the route money takes in this chart — salary, trade, property, "
             "inheritance, network. Give a window for improvement. Never give a figure, "
             "never endorse a speculation, never call a lottery."),
   western="Transiting Jupiter to natal Venus or the 2nd cusp; Pluto to the 8th for other people's money (Rushman)."),

 topic("home", "Home / property / vehicles",
   houses=[4, 12, 2, 11], karakas=["Moon", "Venus", "Mars", "Saturn"],
   varga=["D4 (chaturthamsha) for fixed property", "D16 for vehicles and comforts"],
   dasha=["Moon", "Venus", "Mars", "Saturn", "4th lord", "2nd lord", "11th lord"],
   jup_lagna=[4, 2, 11], jup_moon=[4, 2, 11], sat_ok=[3, 6, 11],
   negations=dict(avoid_ad=["Ketu"],
     factors=["4th lord in the 12th or 8th",
              "Saturn or Rahu transiting the 4th from the Moon — a move is possible but slow and expensive",
              "Mars afflicting the 4th for a disputed title"]),
   evidence=["natal promise: 4th house and lord, Mars for land, Venus for vehicles, the D4",
             "dasha: a period lord tied to the 4th, 2nd, 11th or Mars/Venus/Moon",
             "gochara: Jupiter on the 4th from lagna or Moon",
             "ashtakavarga: 4+ bindus for the transiting graha in the 4th sign"],
   language="Give the window and the likely route (inherited, financed, built, foreign). Never value a property.",
   western="Transiting Jupiter or Saturn to the natal IC (Rushman)."),

 topic("children", "Children / creativity",
   houses=[5, 9, 2, 11], karakas=["Jupiter"],
   varga=["D7 (saptamsha) is decisive", "D9 for the partner's side of it"],
   dasha=["Jupiter", "5th lord", "the graha in the 5th", "Putrakaraka", "2nd lord", "11th lord"],
   jup_lagna=[5, 1, 9], jup_moon=[5, 2, 11], sat_ok=[3, 6, 11],
   negations=dict(avoid_ad=["Ketu"],
     factors=["Ketu in the 5th or in the 5th from the Moon",
              "Saturn in the 5th with no benefic aspect (delay, not denial)",
              "5th lord combust or in a dusthana",
              "Ketu antardasha for a planned pregnancy"]),
   evidence=["natal promise: 5th house and lord, Jupiter, the D7",
             "dasha: a period lord tied to the 5th, 9th, 2nd or 11th, or Jupiter",
             "gochara: Jupiter on the 5th from lagna or Moon"],
   language=("Read the 5th as children, creativity and inherited merit together. Delay is the "
             "common classical reading, not denial. PocketAstro never predicts infertility and "
             "never advises against medical consultation."),
   western="Transiting Jupiter to the natal 5th cusp or the Moon (Rushman)."),

 topic("education", "Education / learning",
   houses=[4, 5, 9, 2], karakas=["Mercury", "Jupiter"],
   varga=["D24 (chaturvimshamsha) is decisive", "D9 for whether a degree is completed"],
   dasha=["Mercury", "Jupiter", "4th lord", "5th lord", "9th lord"],
   jup_lagna=[4, 5, 9], jup_moon=[2, 5, 9, 11], sat_ok=[3, 6, 11],
   negations=dict(avoid_ad=[],
     factors=["Mercury combust and afflicted in D24",
              "4th and 5th lords both weak",
              "Rahu on the 5th for a lost year rather than a lost capacity"]),
   evidence=["natal promise: 4th, 5th and 9th houses with Mercury and Jupiter; the D24",
             "dasha: a period lord tied to those houses",
             "gochara: Jupiter on the 4th, 5th or 9th"],
   language="Name the subject areas the chart supports and the window for a course or exam. Never predict an exam result.",
   western="Transiting Jupiter to natal Mercury or the 9th cusp (Rushman)."),

 topic("foreign", "Foreign travel / living abroad",
   houses=[12, 9, 3, 7], karakas=["Rahu", "Saturn", "Moon"],
   varga=["D9 for whether the move holds", "D10 if the move is for work"],
   dasha=["Rahu", "Saturn", "12th lord", "9th lord", "3rd lord", "7th lord"],
   jup_lagna=[9, 12, 3], jup_moon=[9, 12, 3], sat_ok=[3, 6, 11, 12],
   negations=dict(avoid_ad=[],
     factors=["4th lord very strong and the 12th empty with a weak 12th lord — the chart prefers home",
              "Ketu on the 12th can mean retreat rather than relocation"]),
   evidence=["natal promise: 12th and 9th houses, Rahu's placement, the nodal axis",
             "dasha: Rahu, Saturn, or a period lord tied to the 12th, 9th or 3rd",
             "gochara: Rahu or Saturn crossing the 12th or 9th; Jupiter on the 9th"],
   language=("Distinguish foreign income from foreign residence — they are different readings. "
             "Never promise a visa outcome."),
   western="Transiting Uranus or Jupiter to the natal IC/MC axis; Saturn to the 4th for a forced move (Rushman)."),

 topic("health", "Health / vitality",
   houses=[1, 6, 8, 12], karakas=["Sun", "Moon", "Mars", "Saturn"],
   varga=["D30 (trimshamsha) for the nature of difficulty", "D1 lagna and lagna lord for constitution"],
   dasha=["6th lord", "8th lord", "12th lord", "the maraka lords as stress markers only"],
   jup_lagna=[1, 5, 9, 11], jup_moon=[1, 5, 9, 11], sat_ok=[3, 6, 11],
   negations=dict(avoid_ad=[],
     factors=["Sade Sati or Ashtama Shani running",
              "Malefic transit over the natal lagna degree",
              "Lagna and 8th both below 28 bindus in sarvashtakavarga"]),
   evidence=["constitution: lagna, lagna lord, the Moon, and the sarvashtakavarga of the 1st and 8th",
             "stress windows: Saturn's transit from the Moon, the 6th lord's dasha",
             "body areas: the signs and nakshatras holding afflicted grahas"],
   language=("Lifestyle flags only. Name the body systems classically associated with the "
             "afflicted graha, and say plainly that this is not a diagnosis. Never predict "
             "an illness, a surgery outcome, or a lifespan. Always point to a clinician."),
   western=""),

 topic("business", "Business / self-employment",
   houses=[7, 10, 11, 3], karakas=["Mercury", "Jupiter", "Rahu"],
   varga=["D10 for the field", "D9 for whether a partnership holds"],
   dasha=["Mercury", "Jupiter", "Rahu", "7th lord", "10th lord", "11th lord", "3rd lord"],
   jup_lagna=[7, 10, 11, 2], jup_moon=[2, 7, 10, 11], sat_ok=[3, 6, 10, 11],
   negations=dict(avoid_ad=["Ketu"],
     factors=["Ketu antardasha for incorporation",
              "7th lord afflicted for a partnership specifically",
              "Rahu dasha with borrowed capital",
              "Fewer than 4 bindus in the 10th or 11th"]),
   evidence=["natal promise: 7th (partnership), 10th (action), 11th (gain), 3rd (initiative)",
             "dasha: a period lord tied to those houses or to Mercury/Jupiter",
             "gochara: Jupiter on the 7th, 10th or 11th; Saturn in an upachaya"],
   language="Say whether the chart supports going alone or with a partner. Never advise on capital.",
   western="Transiting Jupiter to the natal MC or 11th cusp (Rushman)."),

 topic("litigation", "Litigation / disputes",
   houses=[6, 7, 1, 11], karakas=["Mars", "Saturn", "Mercury"],
   varga=["D1 alone is usually enough; D9 for whether a settlement holds"],
   dasha=["Mars", "Saturn", "6th lord", "11th lord"],
   jup_lagna=[6, 11, 1], jup_moon=[3, 6, 11], sat_ok=[3, 6, 11],
   negations=dict(avoid_ad=[],
     factors=["6th lord stronger than the lagna lord — the opponent has the better position",
              "Saturn transiting the 1st or 8th from the Moon",
              "Mars retrograde over the natal 6th or 7th"]),
   evidence=["strength of lagna lord against the 6th lord",
             "Mars and Saturn transits over the 6th and 7th",
             "ashtakavarga bindus in the 6th against the 1st"],
   language="Frame as position strength and timing, never as a verdict. Always recommend a lawyer.",
   western=""),

 topic("spiritual", "Spiritual practice / inner life",
   houses=[12, 9, 5, 8, 4], karakas=["Ketu", "Jupiter", "Saturn"],
   varga=["D20 (vimshamsha) is decisive"],
   dasha=["Ketu", "Jupiter", "Saturn", "12th lord", "9th lord", "5th lord"],
   jup_lagna=[5, 9, 12], jup_moon=[5, 9, 12], sat_ok=[3, 6, 11, 12],
   negations=dict(avoid_ad=[], factors=[]),
   evidence=["natal: Ketu's house, the 12th, the 9th, the Atmakaraka, and the D20",
             "dasha: Ketu, Jupiter or Saturn periods open practice",
             "the moksha houses (4, 8, 12) and their lords"],
   language="Name the practice the chart leans toward — devotional, analytical, meditative, ritual, service. Never claim spiritual attainment for someone.",
   western=""),

 topic("fame", "Public name / recognition",
   houses=[10, 1, 11, 5], karakas=["Sun", "Jupiter", "Moon", "Rahu"],
   varga=["D10 for the arena", "D1 kendras for whether it lands"],
   dasha=["Sun", "Jupiter", "Rahu", "10th lord", "1st lord", "11th lord"],
   jup_lagna=[1, 10, 11], jup_moon=[10, 11], sat_ok=[3, 6, 10, 11],
   negations=dict(avoid_ad=[],
     factors=["Amala yoga absent and the 10th holding only malefics",
              "Rahu on the 10th brings scale with exposure — read the ethics line"]),
   evidence=["Amala yoga, a strong 10th lord, a strong Sun, and grahas in kendras",
             "dasha of the 10th or 1st lord",
             "Jupiter or Saturn crossing the 10th"],
   language="Distinguish visibility from standing. Never promise fame.",
   western="Transiting Pluto or Uranus to the natal MC (Rushman)."),

 topic("vehicle", "Vehicle",
   houses=[4, 11, 2], karakas=["Venus", "Moon", "Mars"],
   varga=["D16 (shodashamsha)"],
   dasha=["Venus", "Moon", "4th lord", "11th lord"],
   jup_lagna=[4, 11, 2], jup_moon=[4, 11, 2], sat_ok=[3, 6, 11],
   negations=dict(avoid_ad=[], factors=["Mars afflicting the 4th — accident caution, not a purchase veto"]),
   evidence=["4th house, Venus, the D16", "dasha of Venus or the 4th lord", "Jupiter on the 4th"],
   language="A window and a caution, nothing more.",
   western=""),

 topic("job_change", "Job change / relocation of work",
   houses=[10, 6, 3, 12, 9], karakas=["Saturn", "Sun", "Mercury", "Rahu"],
   varga=["D10"],
   dasha=["Saturn", "Rahu", "10th lord", "6th lord", "3rd lord", "12th lord"],
   jup_lagna=[3, 10, 11], jup_moon=[3, 10, 11], sat_ok=[3, 6, 10, 11],
   negations=dict(avoid_ad=["Ketu"],
     factors=["Ketu antardasha for signing a new contract",
              "Saturn transiting the 8th from the Moon — a move now is a lateral one",
              "Mercury retrograde over the natal 10th for the signing date specifically"]),
   evidence=["10th and 6th lords' dasha", "Saturn crossing a kendra from the Moon",
             "Jupiter on the 3rd, 10th or 11th", "10th house bindus in the transiting sign"],
   language="Give a window for the move and a separate, narrower window for the signing.",
   western="Transiting Uranus to the natal MC for a rupture; Saturn for a structural move (Rushman)."),
]

DOC = {
 "engine": "pocketastro-interpretation",
 "version": 1,
 "sources": [
   "Charak, Elements of Vedic Astrology — ch. VII, XV, XXIX, XXX (promise / dasha / transit / ashtakavarga).",
   "Levacy, Beneath a Vedic Sky — skills IV to VI.",
   "Braha, Ancient Hindu Astrology for the Modern Western Astrologer.",
   "Rushman, The Art of Predictive Astrology — the Western confirmation stack.",
   "Sutton, The Essentials of Vedic Astrology — Putting it All Together.",
 ],
 "order_of_judgment": [
   "1. Verify the birth time. Without a reliable clock time, withhold the lagna, the houses and every varga; read the Moon chart only.",
   "2. Lagna, lagna lord, and the Moon. These set the ceiling on everything below.",
   "3. The 9th lord — fortune decides how much effort the rest will cost.",
   "4. The house of the question, its lord, and the natural karaka. All three must be checked.",
   "5. Yogas that touch those significators, with their cancellations evaluated.",
   "6. The relevant varga — D9, D10, D7, D4, D24 or D20 — to confirm or downgrade.",
   "7. Shadbala or, failing that, dignity plus avastha, to judge whether the promise can be delivered.",
   "8. The running Vimshottari mahadasha, antardasha and pratyantara.",
   "9. Gochara from the Moon and from the lagna, with vedha applied.",
   "10. Ashtakavarga bindus in the transited sign, as the final filter.",
   "11. The Western stack (Rushman transits) as a second opinion only.",
 ],
 "two_technique_rule": {
   "statement": "An event is called likely only when at least two independent techniques agree.",
   "techniques": ["natal promise (house + lord + karaka)", "Vimshottari dasha",
                  "gochara with vedha", "ashtakavarga bindus", "varga confirmation",
                  "Western transit (supporting only)"],
   "verdicts": {
     "likely": "Natal promise present AND dasha agrees AND transit agrees. No active negation.",
     "possible": "Exactly one of dasha or transit agrees, with the natal promise present.",
     "caution": "Techniques agree but a negation (Ketu period, Ashtama Shani, dusthana lord, vedha) is active.",
     "do_not_claim": "No natal promise, or the techniques contradict each other.",
   },
 },
 "confidence_model": {
   "base_with_birth_time": 48,
   "base_without_birth_time": 38,
   "bonuses": {
     "natal_promise": 10, "dasha_agrees": 10, "transit_agrees": 10,
     "both_dasha_and_transit": 8, "varga_confirms": 6,
     "ashtakavarga_5_plus": 5, "western_confirms": 3, "vargottama_significator": 4,
   },
   "penalties": {
     "no_birth_time": -15, "negation_active": "clamp to 20-40",
     "vedha_cancels_transit": -10, "significator_combust": -6,
     "significator_in_dusthana": -6, "ashtakavarga_below_4": -5,
     "dasa_chidra": -6, "ad_in_6_8_12_from_md_lord": -6,
   },
   "ceiling": 75,
   "floor": 20,
   "rationale": (
     "The ceiling is deliberate. An offline ephemeris, whole-sign houses and a mean node "
     "do not support a claim above 75. Anything presented at higher confidence than the "
     "method supports is a lie about the method, not a stronger prediction."
   ),
 },
 "window_rules": [
   "Report windows as month ranges, never as dates, unless the pratyantara and a fast transit both narrow it.",
   "A mahadasha alone gives a chapter of years. An antardasha gives months. A pratyantara gives weeks.",
   "The transiting Moon clinches the day; PocketAstro does not offer day-level event predictions.",
   "Scan 24 months forward by default and report at most the eight strongest windows.",
   "A window that depends on a single technique is labelled 'possible', never 'likely'.",
 ],
 "refusals": {
   "never_predict": [
     "death, a date of dying, or the death of a named relative",
     "a medical diagnosis, a test result, or a surgery outcome",
     "the sex of an unborn child",
     "infertility or an inability to have children",
     "that a marriage will fail, or that a named person is wrong for someone",
     "a legal verdict",
     "a specific financial return, a lottery result, or a stock movement",
     "anything about a third party who did not consent to the reading",
   ],
   "crisis_response": (
     "If a question signals crisis, stop the reading and point to human help. "
     "In the US, call or text 988. PocketAstro is not a substitute for care."
   ),
   "longevity_language": (
     "Classical longevity combinations are read as caution about health, conflict or "
     "authority — never as a lifespan. Ayurdaya is not computed."
   ),
 },
 "delivery_rules": [
   "Lead with what the chart actually promises, not with what it warns about.",
   "Name the technique behind every claim, so the user can check the reasoning.",
   "Give a confidence number with every verdict, and state the method's ceiling.",
   "Where a difficulty is real, give the remedy in the same breath — and lead with the practical one.",
   "Never use fear to produce engagement.",
   "State the birth-time source and what is withheld without a reliable one.",
   "Distinguish Jyotisha claims from the Western layer explicitly; never blend them into one verdict.",
 ],
 "birth_time": {
   "unknown": "Withhold lagna, all houses, all vargas and every house-based yoga. Vimshottari from the Moon still runs. Report chart-wide confidence at the no-time base.",
   "approximate": "Report lagna with a boundary warning if within 4 minutes of a sign change; withhold D60 always and flag D10 and D24 as provisional.",
   "recorded": "Full reading available, including D60 if the record gives seconds.",
   "rectification_note": "PocketAstro does not rectify birth times automatically; it reports how close the lagna is to a boundary and what that costs.",
 },
 "house_quality": {
   "note": (
     "PocketAstro's synthesis, not a classical formula. The classics say to judge a "
     "house three ways \u2014 its occupants, its lord's placement and dignity, and the "
     "aspects onto it (houses.json, reading_rules) \u2014 and Charak XXX adds that the "
     "sarvashtakavarga shows 'the promise inherent in a horoscopic chart'. This block "
     "turns those four inputs into one score so a general reader can see at a glance "
     "which areas of life the chart supports. The weights are tunable here rather than "
     "buried in code, and every score is reported with the reasons that produced it."
   ),
   "inputs": ["sarvashtakavarga bindus", "occupants by natural nature",
              "house lord placement and dignity", "aspects received",
              "functional nature of the lord for this lagna"],
   "weights": {
     "sav_well_above": 2, "sav_above": 1, "sav_below": -1, "sav_well_below": -2,
     "benefic_occupant": 2, "malefic_occupant": -2,
     "malefic_in_upachaya": 1,
     "lord_in_kendra_or_trikona": 2, "lord_in_dusthana": -2,
     "lord_exalted_or_own": 2, "lord_debilitated": -2, "lord_combust": -1,
     "lord_is_functional_benefic": 1, "lord_is_functional_malefic": -1,
     "jupiter_aspect": 2, "benefic_aspect": 1, "malefic_aspect": -1,
     "yogakaraka_involved": 2,
   },
   "sav_thresholds": {"well_above": 32, "above": 28, "below": 25},
   "bands": {
     "prosperous": 3,
     "strained": -3,
     "note": "At or above the prosperous cut the house reads as supported; at or below the strained cut it reads as under pressure; between them it is steady."
   },
   "band_language": {
     "prosperous": "The chart supports this area. The payout is available; the dasha decides when.",
     "steady": "This area works, unevenly or with effort. Nothing here is blocked.",
     "strained": "This area is under pressure. Pressure has a cause and a remedy \u2014 it is never a verdict."
   },
   "upachaya_houses": [3, 6, 10, 11],
   "caution": (
     "A house score is a reading aid, never a prediction. It is never converted into a "
     "probability, and a strained house is never described as a bad outcome."
   ),
 },
 "topics": TOPICS,
}
for out in (ROOT / "assets/kb/interpretation.json", ROOT / "knowledge/extract/interpretation.json"):
    out.write_text(json.dumps(DOC, indent=1, ensure_ascii=False) + "\n")
print("interpretation.json", len(json.dumps(DOC)), "bytes,", len(TOPICS), "topics")

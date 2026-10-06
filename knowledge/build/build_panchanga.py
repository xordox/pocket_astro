#!/usr/bin/env python3
"""Panchanga and muhurta: tithi, vara, nakshatra, yoga, karana, plus the
election rules an offline app needs.

Source: Charak, Elements of Vedic Astrology, ch. XXVI (Muhurta or the
Astrology of Election) and XXIX; standard Panchanga practice.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

TITHI_NAMES = ["Pratipada", "Dwitiya", "Tritiya", "Chaturthi", "Panchami", "Shashthi",
               "Saptami", "Ashtami", "Navami", "Dashami", "Ekadashi", "Dwadashi",
               "Trayodashi", "Chaturdashi", "Purnima"]
TITHI_DEITY = ["Agni", "Brahma", "Gauri", "Ganesha", "the Nagas", "Kartikeya", "Surya",
               "Shiva", "Durga", "Yama", "the Vishvadevas", "Vishnu", "Kamadeva",
               "Shiva (Kali)", "Chandra"]
GROUP = {1: "nanda", 6: "nanda", 11: "nanda", 2: "bhadra", 7: "bhadra", 12: "bhadra",
         3: "jaya", 8: "jaya", 13: "jaya", 4: "rikta", 9: "rikta", 14: "rikta",
         5: "purna", 10: "purna", 15: "purna"}
GROUP_MEANING = {
 "nanda": "Nanda (joyful) — good for celebration, art, new clothes, festivity. Ruled by Venus.",
 "bhadra": "Bhadra (auspicious) — good for construction, marriage, travel, learning. Ruled by Mercury.",
 "jaya": "Jaya (victorious) — good for contest, litigation, competition, confrontation. Ruled by Mars.",
 "rikta": "Rikta (empty) — avoid for anything you want to keep. Good only for demolition, debt recovery, ending things. Ruled by Saturn.",
 "purna": "Purna (full) — good for completion, journeys, marriage, anything requiring fullness. Ruled by Jupiter.",
}

tithis = []
for paksha in ("shukla", "krishna"):
    for i in range(1, 16):
        name = TITHI_NAMES[i - 1]
        if paksha == "krishna" and i == 15:
            name = "Amavasya"
        tithis.append({
            "number": i, "paksha": paksha, "name": name,
            "deity": "the Pitris" if (paksha == "krishna" and i == 15) else TITHI_DEITY[i - 1],
            "group": GROUP[i], "group_meaning": GROUP_MEANING[GROUP[i]],
            "arc_deg": 12.0,
        })

YOGAS = ["Vishkambha", "Priti", "Ayushman", "Saubhagya", "Shobhana", "Atiganda",
         "Sukarma", "Dhriti", "Shula", "Ganda", "Vriddhi", "Dhruva", "Vyaghata",
         "Harshana", "Vajra", "Siddhi", "Vyatipata", "Variyana", "Parigha", "Shiva",
         "Siddha", "Sadhya", "Shubha", "Shukla", "Brahma", "Indra", "Vaidhriti"]
BAD_YOGAS = {"Vishkambha", "Atiganda", "Shula", "Ganda", "Vyaghata", "Vajra",
             "Vyatipata", "Parigha", "Vaidhriti"}

KARANA_CHARA = ["Bava", "Balava", "Kaulava", "Taitila", "Gara", "Vanija", "Vishti"]
KARANA_STHIRA = ["Shakuni", "Chatushpada", "Naga", "Kimstughna"]

VARA = {
 "Sunday": dict(lord="Sun", nature="fixed and fierce", good_for=["government work", "medicine", "authority", "anything in your own name"],
                avoid=["starting a journey west", "beginning a long partnership"], rahu_segment=8, yamaganda_segment=5, gulika_segment=7),
 "Monday": dict(lord="Moon", nature="movable and mild", good_for=["travel", "public dealings", "water and liquids", "domestic matters", "planting"],
                avoid=["confrontation", "surgery"], rahu_segment=2, yamaganda_segment=4, gulika_segment=6),
 "Tuesday": dict(lord="Mars", nature="fierce", good_for=["surgery", "litigation", "competition", "property", "debt recovery"],
                 avoid=["marriage", "lending money", "starting anything meant to be peaceful"], rahu_segment=7, yamaganda_segment=3, gulika_segment=5),
 "Wednesday": dict(lord="Mercury", nature="mixed", good_for=["study", "trade", "writing", "contracts", "negotiation"],
                   avoid=["nothing specific; Abhijit muhurta is the one exception, being weak on Wednesday"], rahu_segment=5, yamaganda_segment=2, gulika_segment=4),
 "Thursday": dict(lord="Jupiter", nature="mild and swift", good_for=["marriage", "education", "religious work", "finance", "new ventures"],
                  avoid=["deception of any kind — it reliably rebounds"], rahu_segment=6, yamaganda_segment=1, gulika_segment=3),
 "Friday": dict(lord="Venus", nature="mild", good_for=["marriage", "art", "vehicles", "luxury purchases", "partnership"],
                avoid=["austerity and renunciation"], rahu_segment=4, yamaganda_segment=7, gulika_segment=2),
 "Saturday": dict(lord="Saturn", nature="fixed and slow", good_for=["long-term foundations", "iron and machinery", "service", "hiring", "discipline"],
                  avoid=["marriage", "buying vehicles", "starting a journey east"], rahu_segment=3, yamaganda_segment=6, gulika_segment=1),
}

TARA = [
 ("Janma", 1, "Your own star. Mixed — good for personal matters, poor for risk."),
 ("Sampat", 2, "Wealth. Auspicious for gain and acquisition."),
 ("Vipat", 3, "Danger. Avoid for anything important."),
 ("Kshema", 4, "Well-being. Auspicious."),
 ("Pratyari", 5, "Obstacle. Avoid."),
 ("Sadhaka", 6, "Accomplishment. Auspicious for undertakings."),
 ("Vadha", 7, "Injury. Avoid — the worst of the nine."),
 ("Mitra", 8, "Friend. Auspicious."),
 ("Ati-Mitra", 9, "Great friend. Most auspicious."),
]

ACTIVITY = {
 "marriage": dict(
   tithi=["2", "3", "5", "7", "10", "11", "13"], avoid_tithi=["4", "9", "14", "Amavasya", "Purnima (secondary)"],
   nakshatra=["Rohini", "Mrigashira", "Magha", "Uttara Phalguni", "Hasta", "Swati", "Anuradha",
              "Mula", "Uttara Ashadha", "Uttara Bhadrapada", "Revati"],
   vara=["Monday", "Wednesday", "Thursday", "Friday"],
   lagna_rules=["The 8th from the muhurta lagna and from the Moon must be free of grahas and of affliction — Charak XXIX.",
                "Venus and Jupiter should be strong and unafflicted.",
                "Avoid a lagna in which the 7th house holds a malefic.",
                "Avoid the periods when Jupiter or Venus is combust."]),
 "housewarming": dict(tithi=["2", "3", "5", "7", "10", "11", "13"], avoid_tithi=["4", "9", "14"],
   nakshatra=["Rohini", "Mrigashira", "Uttara Phalguni", "Chitra", "Anuradha", "Uttara Ashadha",
              "Dhanishta", "Uttara Bhadrapada", "Revati"],
   vara=["Monday", "Wednesday", "Thursday", "Friday"],
   lagna_rules=["A fixed sign rising is preferred.", "The 4th house should be clean and its lord strong."]),
 "business_start": dict(tithi=["2", "3", "5", "7", "10", "11", "13"], avoid_tithi=["4", "9", "14"],
   nakshatra=["Ashwini", "Pushya", "Hasta", "Chitra", "Swati", "Anuradha", "Uttara Ashadha",
              "Shravana", "Dhanishta", "Revati"],
   vara=["Wednesday", "Thursday", "Friday"],
   lagna_rules=["Mercury and Jupiter strong; the 10th and 11th lords well placed.",
                "Avoid Rahu kaal entirely for the moment of signing."]),
 "travel": dict(tithi=["2", "3", "5", "7", "10", "11", "13"], avoid_tithi=["4", "9", "14"],
   nakshatra=["Ashwini", "Mrigashira", "Punarvasu", "Pushya", "Hasta", "Anuradha",
              "Shravana", "Dhanishta", "Revati"],
   vara=["Monday", "Wednesday", "Thursday", "Friday"],
   lagna_rules=["Avoid a journey in the direction of the day's disha shula.",
                "The Moon should be in the 1st, 3rd, 6th, 7th, 10th or 11th from the natal Moon."]),
 "surgery": dict(tithi=["4", "9", "14"], avoid_tithi=["Amavasya", "Purnima"],
   nakshatra=["Ardra", "Ashlesha", "Jyeshtha", "Mula", "Bharani", "Magha"],
   vara=["Tuesday", "Saturday"],
   lagna_rules=["Keep the Moon away from the sign ruling the body part being operated on.",
                "A waning Moon is preferred for removal, a waxing Moon for reconstruction.",
                "This is guidance, not medical advice. The surgeon's schedule wins."]),
 "education_start": dict(tithi=["2", "3", "5", "10", "11", "12"], avoid_tithi=["4", "9", "14"],
   nakshatra=["Ashwini", "Punarvasu", "Pushya", "Hasta", "Chitra", "Swati", "Anuradha",
              "Shravana", "Dhanishta", "Revati"],
   vara=["Wednesday", "Thursday", "Friday"],
   lagna_rules=["Mercury and Jupiter strong; the 4th and 5th houses clean."]),
 "vehicle_purchase": dict(tithi=["2", "3", "5", "7", "10", "11", "13"], avoid_tithi=["4", "9", "14"],
   nakshatra=["Ashwini", "Rohini", "Mrigashira", "Punarvasu", "Pushya", "Hasta", "Chitra",
              "Swati", "Anuradha", "Revati"],
   vara=["Monday", "Wednesday", "Thursday", "Friday"],
   lagna_rules=["Venus strong and unafflicted; the 4th house clean."]),
}

DOC = {
 "engine": "pocketastro-panchanga",
 "version": 1,
 "sources": ["Charak, Elements of Vedic Astrology — ch. XXVI (Muhurta) and XXIX (Gochara).",
             "Standard Panchanga practice for tithi, yoga, karana and the kaal segments."],
 "five_limbs": ["tithi (lunar day)", "vara (weekday)", "nakshatra (lunar mansion)",
                "yoga (Sun+Moon sum)", "karana (half-tithi)"],
 "tithi": {
   "arc_deg": 12.0,
   "rule": "Tithi number = floor((Moon longitude - Sun longitude, normalised to 0-360) / 12) + 1, counted 1-30 from the new Moon.",
   "groups": GROUP_MEANING,
   "list": tithis,
 },
 "vara": VARA,
 "yoga": {
   "count": 27, "arc_deg": 13.3333,
   "rule": "Yoga number = floor(((Sun longitude + Moon longitude) mod 360) / 13°20') + 1.",
   "names": YOGAS,
   "inauspicious": sorted(BAD_YOGAS),
   "note": "The nine inauspicious yogas are avoided for beginnings. Vyatipata and Vaidhriti are the two most strongly avoided.",
 },
 "karana": {
   "count_per_tithi": 2, "arc_deg": 6.0,
   "movable": KARANA_CHARA, "fixed": KARANA_STHIRA,
   "rule": ("Sixty karanas fill a lunar month. The four fixed karanas occur once each: Kimstughna in "
            "the second half of Krishna Chaturdashi, then Shakuni, Chatushpada and Naga. The seven "
            "movable karanas repeat eight times."),
   "inauspicious": ["Vishti (Bhadra)"],
   "note": "Vishti karana is avoided for every auspicious beginning. It lasts about half a tithi.",
 },
 "inauspicious_periods": {
   "rahu_kaal": {"rule": "One eighth of the daylight period; the segment number varies by weekday.",
                 "segments": {d: v["rahu_segment"] for d, v in VARA.items()},
                 "use": "Avoid signing, launching and departing. Ongoing work is unaffected."},
   "yamaganda": {"segments": {d: v["yamaganda_segment"] for d, v in VARA.items()},
                 "use": "Secondary avoidance window."},
   "gulika_kaal": {"segments": {d: v["gulika_segment"] for d, v in VARA.items()},
                   "use": "Classically the worst of the three for anything meant to last; also used deliberately for things meant to be permanent in some traditions."},
   "durmuhurta": "Two short windows in each day, computed from the 15 muhurtas of daylight; avoided for beginnings.",
 },
 "abhijit_muhurta": {
   "rule": "The eighth of the fifteen daylight muhurtas — roughly 24 minutes centred on local apparent noon.",
   "quality": "Among the most auspicious windows of any day, and it overrides most minor blemishes.",
   "exception": "Weak on Wednesday.",
 },
 "choghadiya": {
   "segments": ["Udveg", "Chal", "Labh", "Amrit", "Kaal", "Shubh", "Rog"],
   "good": ["Amrit", "Shubh", "Labh", "Chal"],
   "bad": ["Udveg", "Kaal", "Rog"],
   "rule": "Eight equal segments of daylight and eight of night; the starting segment rotates by weekday.",
 },
 "panchaka": {
   "nakshatras": ["Dhanishta (second half)", "Shatabhisha", "Purva Bhadrapada",
                  "Uttara Bhadrapada", "Revati"],
   "avoid": ["roofing a house", "buying fuel", "travelling south", "making a bed", "cremation rites"],
   "note": "A narrow, specific prohibition — not a general 'bad period'.",
 },
 "tarabala": {
   "rule": "Count nakshatras inclusively from the natal Moon's nakshatra to today's; the remainder after division by nine gives the tara.",
   "taras": [{"name": n, "number": i, "reading": r} for n, i, r in TARA],
   "malefic_taras": ["Vipat", "Pratyari", "Vadha"],
 },
 "chandrabala": {
   "good_houses_from_janma_rashi": [1, 3, 6, 7, 10, 11],
   "bad_houses_from_janma_rashi": [4, 8, 12],
   "rule": "The transiting Moon's house from the natal Moon sign. A poor chandrabala cancels an otherwise good muhurta.",
 },
 "priority": [
   "Tarabala and chandrabala are checked first — a muhurta that fails either is discarded.",
   "Then tithi group, then nakshatra class, then vara, then yoga and karana.",
   "Then the muhurta lagna: the house relevant to the undertaking should be clean and its lord strong.",
   "Ashtakavarga refinement last: pick a lagna from which the relevant house holds above-average bindus.",
   "Rahu kaal, Vishti karana and rikta tithi are the three most commonly applied vetoes.",
 ],
 "activities": ACTIVITY,
 "disclaimer": (
   "Muhurta improves the odds on a discretionary start. It does not override the natal promise or "
   "the running dasha, and it is never a reason to delay medical care."
 ),
}
for out in (ROOT / "assets/kb/panchanga.json", ROOT / "knowledge/extract/panchanga.json"):
    out.write_text(json.dumps(DOC, indent=1, ensure_ascii=False) + "\n")
print("panchanga.json", len(json.dumps(DOC)), "bytes,", len(tithis), "tithis")

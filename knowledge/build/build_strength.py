#!/usr/bin/env python3
"""Graha and bhava strength: shadbala, avasthas, dignity states, combustion.

Sources: Charak, Elements of Vedic Astrology, ch. XII (planetary states of
being) and XIII (graha bala); Parashara via Charak for the bhava bala rules.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

DOC = {
 "engine": "pocketastro-strength",
 "version": 1,
 "sources": ["Charak, Elements of Vedic Astrology — ch. XII and XIII.",
             "Parashara (Brihat Parashara Hora Shastra) as cited by Charak."],
 "units": {"shashtiamsha": 1, "rupa": 60,
           "note": "Strength is counted in shashtiamshas; sixty make one rupa."},
 "shadbala": {
   "components": {
     "sthana_bala": {
       "meaning": "Positional strength.",
       "parts": ["Uchcha bala — proximity to the exaltation degree; 60 shashtiamshas at exact exaltation, 0 at exact debilitation.",
                 "Saptavargaja bala — dignity across the seven vargas (D1, D2, D3, D7, D9, D12, D30).",
                 "Ojhayugmarashiamsha bala — strength from odd/even sign and navamsa, by the graha's own gender.",
                 "Kendradi bala — 60 in a kendra, 30 in a panapara, 15 in an apoklima.",
                 "Drekkana bala — males strong in the 1st drekkana, neuters in the 2nd, females in the 3rd."],
     },
     "dig_bala": {
       "meaning": "Directional strength. Full 60 shashtiamshas at the strong angle, zero at the opposite one.",
       "strong_house": {"Jupiter": 1, "Mercury": 1, "Moon": 4, "Venus": 4,
                        "Saturn": 7, "Sun": 10, "Mars": 10},
     },
     "kaala_bala": {
       "meaning": "Temporal strength.",
       "parts": ["Nathonatha bala — day strength for Sun, Jupiter, Venus; night strength for Moon, Mars, Saturn; Mercury always.",
                 "Paksha bala — waxing Moon and benefics gain, waning Moon and malefics gain in the dark half.",
                 "Tribhaga bala — one third of day or night favours a particular graha.",
                 "Varsha, Masa, Dina and Hora bala — lords of the year, month, day and hour gain strength.",
                 "Ayana bala — declination; grahas gain in their preferred ayana.",
                 "Yuddha bala — planetary war: the winner gains what the loser loses."],
     },
     "cheshta_bala": {
       "meaning": "Motional strength. A retrograde graha gains cheshta bala and delivers forcefully.",
       "note": "The Sun and Moon take their cheshta bala from ayana bala instead.",
       "states": {"vakra": "retrograde — maximum (60)", "anuvakra": "retrograde re-entry into the prior sign (30)",
                  "manda": "slow (15)", "mandatara": "very slow (7.5)", "sama": "mean motion (30)",
                  "chara": "fast (30)", "atichara": "very fast (45)", "vikala": "stationary (15)"},
   },
     "naisargika_bala": {
       "meaning": "Inherent natural strength, fixed for each graha.",
       "values": {"Sun": 60.0, "Moon": 51.43, "Venus": 42.86, "Jupiter": 34.29,
                  "Mercury": 25.71, "Mars": 17.14, "Saturn": 8.57},
     },
     "drik_bala": {
       "meaning": "Aspectual strength. Sum the benefic aspects received minus the malefic ones, divided by four.",
       "note": "Positive or negative; added last to the total.",
     },
   },
   "required_minimum_rupas": {"Sun": 6.5, "Moon": 6.0, "Mars": 5.0, "Mercury": 7.0,
                              "Jupiter": 6.5, "Venus": 5.5, "Saturn": 5.0},
   "reading": (
     "A graha above its required minimum can deliver what it promises. Below it, the promise "
     "stands but the delivery is partial and usually late. Shadbala measures capacity, never "
     "benevolence — a strong malefic is strongly malefic."
   ),
 },
 "bhava_bala": {
   "components": ["Strength of the house lord.",
                  "Drik bala on the house cusp — benefic aspects minus malefic ones, over four.",
                  "Dig bala by the rising sign's class: biped signs from the 7th cusp, quadruped from the 4th, "
                  "insect signs (Cancer, Scorpio) from the lagna, watery signs from the 10th."],
   "sign_classes": {
     "dwipada_biped": ["Gemini", "Virgo", "Libra", "Aquarius", "Sagittarius (first half)"],
     "chatushpada_quadruped": ["Aries", "Taurus", "Leo", "Sagittarius (second half)", "Capricorn (first half)"],
     "keeta_insect": ["Cancer", "Scorpio"],
     "jalachara_watery": ["Pisces", "Capricorn (second half)"],
   },
 },
 "avastha": {
   "baladi": {
     "meaning": "Physical state by position within the sign — a fifth of a sign each.",
     "odd_sign_deg": {"bala": [0, 6], "kumara": [6, 12], "yuva": [12, 18], "vriddha": [18, 24], "mrita": [24, 30]},
     "even_sign_deg": {"mrita": [0, 6], "vriddha": [6, 12], "yuva": [12, 18], "kumara": [18, 24], "bala": [24, 30]},
     "yield": {"bala": 0.25, "kumara": 0.5, "yuva": 1.0, "vriddha": 0.25, "mrita": 0.0},
     "timing_use": (
       "Charak's suggested application: a graha in balavastha gives its results early in its dasha, "
       "and the later avasthas progressively later. Alternatively, the avastha points to the stage "
       "of life when that graha delivers."
     ),
     "caution": "Not to be applied literally. No graha is ever entirely functionless.",
   },
   "jagradadi": {
     "meaning": "State of consciousness, judged in the navamsa (Jataka Parijata) rather than the rashi chart.",
     "jagrad": "Exalted or own sign — awake; full results.",
     "swapna": "Friend's or neutral's sign — dreaming; medium results.",
     "sushupti": "Debilitated or enemy's sign — asleep; little function.",
   },
   "deeptadi": {
     "deepta": "Exalted or in moolatrikona — high status, courage, wealth, vehicles, favour from authority.",
     "swastha": "Own sign — health, education, fame, land, partnership, favour from authority.",
     "mudita": "In a great friend's sign — delighted; comfort and support.",
     "shanta": "In a friend's sign — peaceful; steady modest results.",
     "shakta": "In direct swift motion or well-placed — capable.",
     "peedita": "Defeated in planetary war or afflicted — pained.",
     "deena": "In an enemy's sign — poor results.",
     "vikala": "Combust — incapacitated.",
     "khala": "Debilitated or in a malefic's sign with malefics — harmful.",
   },
 },
 "dignity": {
   "order_best_to_worst": ["exalted", "moolatrikona", "own sign", "great friend's sign",
                           "friend's sign", "neutral sign", "enemy's sign", "great enemy's sign", "debilitated"],
   "temporal_friendship": (
     "Beyond natural friendship, compute temporal (tatkalika) friendship: grahas in the 2nd, 3rd, 4th, "
     "10th, 11th or 12th from each other are temporal friends; the rest are temporal enemies. Combine "
     "natural and temporal to get the five-fold (panchadha) relationship used for dignity."
   ),
   "vargottama": "Same sign in D1 and D9. The graha delivers exactly what it promises, without dilution.",
   "pushkara_navamsa": "Certain navamsas (the 8th and 10th of movable, 4th and 6th of fixed, 2nd and 8th of dual signs, by one common reckoning) are held to purify a graha placed in them.",
 },
 "combustion": {
   "orbs_deg": {"Moon": 12.0, "Mars": 17.0, "Mercury": 14.0, "Mercury_retrograde": 12.0,
                "Jupiter": 11.0, "Venus": 10.0, "Venus_retrograde": 8.0, "Saturn": 15.0},
   "reading": ("A combust graha keeps its ownership duties but cannot deliver independent results. "
               "Mercury and Venus suffer least, being never far from the Sun. The Moon and Mars suffer most."),
   "cazimi": "Within about 17 arc-minutes of the Sun's centre the graha is classically 'in the heart' and strengthened rather than burnt.",
 },
 "planetary_war": {
   "condition_deg": 1.0,
   "applies_to": ["Mars", "Mercury", "Jupiter", "Venus", "Saturn"],
   "winner": "The graha further north in celestial latitude, or the brighter, wins.",
   "effect": "The loser withholds its results for the period; the winner gains what the loser loses.",
 },
 "judgment_order": [
   "Lagna and lagna lord first — they set the ceiling on everything else.",
   "The 9th lord second — fortune determines how much effort is required.",
   "Then the karaka of the question, then the house, then the house lord.",
   "Check dignity, then shadbala capacity, then avastha timing, then varga confirmation.",
   "Only then read the dasha and the transit.",
 ],
}

for out in (ROOT / "assets/kb/strength.json", ROOT / "knowledge/extract/strength.json"):
    out.write_text(json.dumps(DOC, indent=1, ensure_ascii=False) + "\n")
print("strength.json", len(json.dumps(DOC)), "bytes")

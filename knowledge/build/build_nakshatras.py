#!/usr/bin/env python3
"""Full nakshatra runtime table (27 records, all classical attributes).

Sources: Charak, *Elements of Vedic Astrology* (ch. XXVII matching attributes,
ch. XXVI muhurta classification); Komilla Sutton, *The Essentials of Vedic
Astrology* (symbol, deity, sign-lord interplay); Vic DiCara, *27 Stars, 27 Gods*
(deity mythology and shakti); William Levacy, *Beneath a Vedic Sky* (career
and remedial use). Parashari shakti formulae per the classical Shakti list.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SIGNS = ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
         "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"]
SIGN_LORD = ["Mars", "Venus", "Mercury", "Moon", "Sun", "Mercury",
             "Venus", "Mars", "Jupiter", "Saturn", "Saturn", "Jupiter"]

# name, lord, deity, symbol, gana, yoni, yoni_gender, nadi, type, shakti,
# shakti_result, body, keywords, career, shadow
N = [
 ("Ashwini", "Ketu", "Ashvini Kumaras (twin celestial physicians)", "Horse's head",
  "deva", "Horse", "male", "adya", "kshipra",
  "shidhra vyapani shakti — the power to reach things quickly",
  "The world is freed of disease.",
  "Knees, top of the feet",
  "speed, first aid, fresh starts, restlessness",
  ["emergency medicine", "surgery", "sports", "transport", "veterinary", "rescue work", "startups"],
  "Starts everything, finishes little; impatience read as courage."),
 ("Bharani", "Venus", "Yama (lord of death and dharma)", "Yoni — the female organ of generation",
  "manushya", "Elephant", "male", "madhya", "ugra",
  "apabharani shakti — the power to carry things away",
  "The soul is moved from one state to the next.",
  "Head, forehead, soles of the feet",
  "bearing, extremes, restraint, birth and ending",
  ["obstetrics", "hospice and funeral work", "law", "creative arts", "agriculture", "hospitality"],
  "Excess in whatever it touches; will not stop on its own. Saturn falls here."),
 ("Krittika", "Sun", "Agni (god of fire)", "A razor, a flame, an axe",
  "rakshasa", "Goat", "female", "antya", "mishra",
  "dahana shakti — the power to burn and purify",
  "Negativity is burned away.",
  "Hips, loins, eyes",
  "cutting, purification, sharp speech, ambition",
  ["surgery", "engineering", "military", "cooking", "metallurgy", "editing", "criticism"],
  "Cuts what should have been nursed; sharpness mistaken for honesty. Moon is exalted here."),
 ("Rohini", "Moon", "Brahma (the creator)", "An ox-cart, a banyan tree",
  "manushya", "Serpent", "male", "antya", "dhruva",
  "rohana shakti — the power of growth and creation",
  "Creation takes physical form.",
  "Ankles, shins, forehead",
  "growth, beauty, fertility, material charm",
  ["agriculture", "luxury goods", "fashion", "music", "banking", "real estate", "food"],
  "Attachment to comfort and to being desired; possessiveness. Moon is exalted in this span."),
 ("Mrigashira", "Mars", "Soma (the Moon god)", "The head of a deer",
  "deva", "Serpent", "female", "madhya", "mridu",
  "prinana shakti — the power to give fulfilment",
  "Enjoyment is found.",
  "Eyebrows, eyes, chin, cheeks",
  "search, curiosity, scent for quality, travel",
  ["research", "writing", "travel trade", "textiles", "perfume", "real estate scouting", "sales"],
  "Never arrives — always one more thing to sample; suspicion and nervousness."),
 ("Ardra", "Rahu", "Rudra (the storm, the howler)", "A teardrop, a diamond, a human head",
  "manushya", "Dog", "female", "adya", "tikshna",
  "yatna shakti — the power of effort",
  "A hard change is brought about.",
  "Hair, eyes, front of the head",
  "storm, breakthrough, analytic mind, grief",
  ["research", "data and analytics", "psychology", "pharma", "engineering", "activism", "crisis work"],
  "Destroys to feel alive; sharp words in a storm that pass, but the damage does not."),
 ("Punarvasu", "Jupiter", "Aditi (mother of the gods, boundless space)", "A quiver of arrows, a house",
  "deva", "Cat", "female", "adya", "chara",
  "vasutva prapana shakti — the power to regain wealth and substance",
  "Plants are revitalized; what was lost returns.",
  "Fingers, nose, lungs",
  "return, renewal, second chances, philosophy",
  ["teaching", "counselling", "publishing", "spirituality", "hospitality", "housing", "restoration work"],
  "Repeats the same lesson because it trusts the reset; scattered, hard to pin down."),
 ("Pushya", "Saturn", "Brihaspati (guru of the gods)", "A cow's udder, a lotus, an arrow",
  "deva", "Goat", "male", "madhya", "kshipra",
  "brahmavarchasa shakti — the power to create spiritual energy",
  "Spiritual energy is generated.",
  "Mouth, face, ribs, stomach",
  "nourishment, dharma, duty, the good counsellor",
  ["teaching", "priesthood", "food and dairy", "nursing", "government service", "finance", "childcare"],
  "Moralizing, over-caretaking, rigidity about the one right way."),
 ("Ashlesha", "Mercury", "The Nagas (serpent deities)", "A coiled serpent",
  "rakshasa", "Cat", "male", "antya", "tikshna",
  "visasleshana shakti — the power to inflict poison, and to withdraw it",
  "The target is undone.",
  "Nails, joints, ears, elbows",
  "coiling, hypnosis, penetration, secrets",
  ["research", "psychology", "pharmacology", "intelligence work", "negotiation", "occult studies", "toxicology"],
  "Manipulation rationalised as insight; clinging. Gandanta at its end."),
 ("Magha", "Ketu", "The Pitris (the ancestors)", "A royal throne, a palanquin",
  "rakshasa", "Rat", "male", "antya", "ugra",
  "tyage kshepani shakti — the power to leave the body",
  "One passes to the world of the ancestors.",
  "Nose, lips, chin",
  "throne, lineage, inherited authority, ritual",
  ["government", "administration", "history and archaeology", "law", "family business", "ritual work"],
  "Entitlement inherited rather than earned; pride that cannot be corrected. Gandanta at its start."),
 ("Purva Phalguni", "Venus", "Bhaga (god of delight and marital bliss)", "The front legs of a bed, a hammock",
  "manushya", "Rat", "female", "madhya", "ugra",
  "prajanana shakti — the power of procreation",
  "The child is conceived.",
  "Right hand, genitals, lips",
  "pleasure, romance, rest, creative play",
  ["entertainment", "music", "hospitality", "fashion", "event work", "wedding trades", "design"],
  "Indulgence and laziness dressed up as self-care; vanity."),
 ("Uttara Phalguni", "Sun", "Aryaman (god of patronage, contracts and friendship)", "The back legs of a bed",
  "manushya", "Cow", "male", "adya", "dhruva",
  "chayani shakti — the power to accumulate through union",
  "Prosperity through partnership.",
  "Left hand, liver, intestines",
  "vows, patronage, generous authority, contracts",
  ["administration", "charity", "medicine", "consulting", "HR", "marriage and partnership work"],
  "Gives to be indispensable; contracts entered for status rather than fit."),
 ("Hasta", "Moon", "Savitar (the creative Sun)", "An open hand, a fist",
  "deva", "Buffalo", "female", "adya", "kshipra",
  "hasta sthapaniya agama shakti — the power to put a thing in your hand",
  "What was sought is gained.",
  "Hands, fingers, wrists",
  "craft, dexterity, cleverness, healing hands",
  ["craft and trades", "surgery", "massage and bodywork", "art", "accounting", "programming", "agriculture"],
  "Sleight of hand; cleverness used to cut corners; anxiety in the details."),
 ("Chitra", "Mars", "Tvashtar / Vishvakarma (the celestial architect)", "A bright jewel, a pearl",
  "rakshasa", "Tiger", "female", "madhya", "mridu",
  "punya chayani shakti — the power to accumulate merit",
  "Honour and recognition follow the work.",
  "Forehead, neck, kidneys",
  "design, brilliance, form, visible excellence",
  ["architecture", "design", "engineering", "jewellery", "photography", "surgery", "fashion"],
  "Style over substance; performs the self it wants seen."),
 ("Swati", "Rahu", "Vayu (god of wind)", "A young shoot swaying in the wind, a coral",
  "deva", "Buffalo", "male", "antya", "chara",
  "pradhvamsa shakti — the power to scatter like the wind",
  "Form is transformed; what was fixed disperses.",
  "Chest, intestines, skin",
  "independence, trade, balance, self-made movement",
  ["trade and business", "aviation", "diplomacy", "law", "import-export", "music", "self-employment"],
  "Cannot be held to anything; freedom defended past the point of usefulness."),
 ("Vishakha", "Jupiter", "Indra and Agni (the paired gods of power and fire)", "A triumphal archway, a potter's wheel",
  "rakshasa", "Tiger", "male", "antya", "mishra",
  "vyapani shakti — the power to achieve many and varied fruits",
  "The harvest is reaped.",
  "Arms, breasts, bladder",
  "forked drive, goal-fixation, ambition, late ripening",
  ["politics", "research", "science", "banking", "public speaking", "military", "goal-driven business"],
  "Burns relationships for the goal; never satisfied at the finish line."),
 ("Anuradha", "Saturn", "Mitra (god of friendship and contracts)", "A lotus, a triumphal archway",
  "deva", "Deer", "female", "madhya", "mridu",
  "radhana shakti — the power of worship and devotion",
  "Honour and fame come to the devoted.",
  "Stomach, breasts, womb, bowels",
  "devotion, friendship, organising people, endurance abroad",
  ["management", "organising and NGO work", "foreign postings", "occult and devotional practice", "mining", "research"],
  "Devotion to the wrong object; suppressed resentment in loyal service."),
 ("Jyeshtha", "Mercury", "Indra (king of the gods)", "An earring, an umbrella, a talisman",
  "rakshasa", "Deer", "male", "adya", "tikshna",
  "arohana shakti — the power to rise and to conquer",
  "Courage is gained.",
  "Neck, right torso, colon",
  "seniority, protection, hidden burden, authority",
  ["management", "military and police", "occult work", "engineering", "surgery", "administration"],
  "Carries everyone and resents it; secrecy; pride that isolates. Gandanta at its end."),
 ("Mula", "Ketu", "Nirriti (goddess of dissolution)", "A bunch of tied roots, an elephant goad",
  "rakshasa", "Dog", "male", "adya", "tikshna",
  "barhana shakti — the power to ruin and uproot",
  "What was rotten is destroyed so that new roots can take.",
  "Feet, hips, thighs",
  "root, investigation, uprooting, spiritual severity",
  ["research", "medicine and herbalism", "philosophy", "investigation", "demolition and reconstruction", "pharmacy"],
  "Pulls out the root before checking what was holding; extremism. Gandanta at its start."),
 ("Purva Ashadha", "Venus", "Apas (the cosmic waters)", "An elephant's tusk, a winnowing basket",
  "manushya", "Monkey", "male", "madhya", "ugra",
  "varchograhana shakti — the power of invigoration",
  "Lustre and strength are gained.",
  "Thighs, back, hips",
  "early victory, conviction, persuasion, water",
  ["debate and law", "shipping and water trade", "politics", "teaching", "performing arts", "naval work"],
  "Cannot admit being wrong; conviction hardening into arrogance."),
 ("Uttara Ashadha", "Sun", "The Vishvadevas (the ten universal gods)", "An elephant's tusk, a plank of a bed",
  "manushya", "Mongoose", "female", "antya", "dhruva",
  "apradhrisya shakti — the unchallengeable power to win",
  "Victory that cannot be taken back.",
  "Thighs, waist",
  "lasting victory, integrity, slow durable rise",
  ["government", "leadership", "law", "military", "social reform", "long-cycle business"],
  "Starts slowly and blames the world for it; rigid about principle. Holds the Abhijit overlap."),
 ("Shravana", "Moon", "Vishnu (the preserver)", "An ear, three footprints",
  "deva", "Monkey", "female", "antya", "chara",
  "samhanana shakti — the power to connect",
  "All things are linked together.",
  "Ears, skin, genitals",
  "listening, learning, tradition, reputation",
  ["teaching", "media and broadcasting", "languages", "counselling", "audiology", "scriptural study", "PR"],
  "Lives on what is said about it; gossip; learning that substitutes for doing."),
 ("Dhanishta", "Mars", "The eight Vasus (gods of abundance)", "A drum, a flute",
  "rakshasa", "Lion", "female", "madhya", "chara",
  "khyapayitri shakti — the power to give fame and abundance",
  "Fame and prosperity are announced.",
  "Back, anus",
  "rhythm, wealth, music, group timing",
  ["music and rhythm work", "real estate", "engineering", "finance", "sports", "defence", "event production"],
  "Wealth measured against others; marital friction is classically flagged here."),
 ("Shatabhisha", "Rahu", "Varuna (god of cosmic waters and oaths)", "An empty circle, a hundred healers",
  "rakshasa", "Horse", "female", "adya", "chara",
  "bheshaja shakti — the power of healing",
  "Freedom from calamity.",
  "Jaw, right thigh, calves",
  "veil, solitude, research, unorthodox healing",
  ["medicine and epidemiology", "research", "astrology", "electricity and tech", "alternative healing", "aviation"],
  "Isolation defended as independence; secrecy and addiction risk."),
 ("Purva Bhadrapada", "Jupiter", "Aja Ekapada (the one-footed goat, a form of Rudra)", "A two-faced man, a funeral cot",
  "manushya", "Lion", "male", "adya", "ugra",
  "yajamana udyamana shakti — the power to raise the spiritual person",
  "One is lifted to a higher plane.",
  "Left thigh, soles, ribs",
  "intensity, two faces, penance, mysticism",
  ["priesthood and ritual", "occult work", "statistics", "surgery", "crematory and funeral trades", "research"],
  "Zeal without proportion; pessimism; punishes the body for the idea."),
 ("Uttara Bhadrapada", "Saturn", "Ahirbudhnya (the serpent of the deep)", "The back legs of a funeral cot, a water serpent",
  "manushya", "Cow", "female", "madhya", "dhruva",
  "varshodyamana shakti — the power to bring the rain",
  "The land becomes fertile.",
  "Shins, feet, sides of the legs",
  "depth, finishing, quiet wisdom, inherited grace",
  ["counselling", "occult and yogic practice", "charity", "writing", "shipping", "long research"],
  "Withdraws instead of engaging; deep water that never surfaces."),
 ("Revati", "Mercury", "Pushan (the nourisher, protector of travellers)", "A fish, a drum",
  "deva", "Elephant", "female", "antya", "mridu",
  "kshiradyapani shakti — the power of nourishment, symbolised by milk",
  "The whole world is nourished.",
  "Feet, ankles, abdomen",
  "nourishing, crossing over, safe passage, endings",
  ["travel and logistics", "childcare", "teaching", "music and art", "hospice and care work", "marine trades"],
  "Gives past its own limit; loses shape in other people. Gandanta at its end."),
]

WIDTH = 360.0 / 27.0            # 13°20'
PADA = WIDTH / 4                # 3°20'

TYPE_MEANING = {
 "kshipra": "Swift / light. Good for trade, travel, medicine, art, quick undertakings.",
 "ugra": "Fierce / severe. Good for demolition, confrontation, debt recovery, hard discipline; bad for weddings and launches.",
 "mishra": "Mixed / ordinary. Good for routine and remedial work, fire rituals; ambiguous for anything irreversible.",
 "dhruva": "Fixed / permanent. Good for foundations, planting, coronation, marriage, anything meant to last.",
 "mridu": "Tender / mild. Good for arts, romance, friendship, clothing, healing, celebration.",
 "chara": "Movable. Good for travel, vehicles, moving house, changing jobs, machinery.",
 "tikshna": "Sharp / dreadful. Good for surgery, exorcism, breaking bad habits, litigation; bad for anything gentle.",
}

def navamsa_sign_index(lon):
    sign = int(lon // 30) % 12
    n = int((lon % 30) / (10.0 / 3.0))
    if sign % 3 == 0:
        start = sign
    elif sign % 3 == 1:
        start = (sign + 8) % 12
    else:
        start = (sign + 4) % 12
    return (start + n) % 12

GANDANTA = {
    "Ashlesha": "end", "Jyeshtha": "end", "Revati": "end",
    "Magha": "start", "Mula": "start", "Ashwini": "start",
}
GANDMOOL = {"Ashwini", "Ashlesha", "Magha", "Jyeshtha", "Mula", "Revati"}

# Exaltation / debilitation / moolatrikona degrees that land inside each nakshatra
SPECIAL_POINTS = {
    "Ashwini": ["Sun is exalted at 10\u00b0 Aries \u2014 Ashwini pada 4."],
    "Bharani": ["Saturn is debilitated at 20\u00b0 Aries \u2014 Bharani pada 3."],
    "Krittika": ["Moon is exalted at 3\u00b0 Taurus \u2014 Krittika pada 2."],
    "Punarvasu": ["Jupiter's exaltation sign (Cancer) opens in Punarvasu pada 4."],
    "Pushya": ["Jupiter is exalted at 5\u00b0 Cancer \u2014 Pushya pada 1. Pushya is classically the single most auspicious nakshatra."],
    "Ashlesha": ["Mars is debilitated at 28\u00b0 Cancer \u2014 Ashlesha pada 4.", "Gandanta closes at Ashlesha's end."],
    "Hasta": ["Mercury is exalted at 15\u00b0 Virgo \u2014 Hasta pada 2."],
    "Chitra": ["Venus is debilitated at 27\u00b0 Virgo \u2014 Chitra pada 2."],
    "Swati": ["Sun is debilitated at 10\u00b0 Libra \u2014 Swati pada 2.", "Saturn is exalted at 20\u00b0 Libra \u2014 the Swati / Vishakha boundary."],
    "Vishakha": ["Moon is debilitated at 3\u00b0 Scorpio \u2014 Vishakha pada 4."],
    "Uttara Ashadha": ["Jupiter is debilitated at 5\u00b0 Capricorn \u2014 Uttara Ashadha pada 3.", "Abhijit, the 28th nakshatra (276\u00b040'\u2013280\u00b053'20\"), overlaps this nakshatra's last pada and Shravana's first."],
    "Dhanishta": ["Mars is exalted at 28\u00b0 Capricorn \u2014 Dhanishta pada 2."],
    "Uttara Bhadrapada": ["Mercury is debilitated at 15\u00b0 Pisces \u2014 Uttara Bhadrapada pada 4."],
    "Revati": ["Venus is exalted at 27\u00b0 Pisces \u2014 Revati pada 4.", "The zodiac's final gandanta closes here."],
}

records = []
for i, (name, lord, deity, symbol, gana, yoni, ygen, nadi, ntype,
        shakti, shakti_result, body, keywords, career, shadow) in enumerate(N):
    start = i * WIDTH
    end = start + WIDTH
    padas = []
    for p in range(4):
        plon = start + p * PADA + PADA / 2
        d9 = navamsa_sign_index(plon)
        padas.append({
            "pada": p + 1,
            "start_deg": round(start + p * PADA, 4),
            "end_deg": round(start + (p + 1) * PADA, 4),
            "rashi": SIGNS[int((start + p * PADA) // 30) % 12],
            "navamsa": SIGNS[d9],
            "navamsa_lord": SIGN_LORD[d9],
        })
    records.append({
        "index": i,
        "number": i + 1,
        "name": name,
        "start_deg": round(start, 4),
        "end_deg": round(end, 4),
        "rashi_span": sorted({SIGNS[int(start // 30) % 12], SIGNS[int((end - 0.001) // 30) % 12]},
                             key=lambda s: SIGNS.index(s)),
        "lord": lord,
        "deity": deity,
        "symbol": symbol,
        "shakti": shakti,
        "shakti_result": shakti_result,
        "gana": gana,
        "yoni": yoni,
        "yoni_gender": ygen,
        "nadi": nadi,
        "type": ntype,
        "type_meaning": TYPE_MEANING[ntype],
        "body_part": body,
        "keywords": keywords,
        "career": career,
        "shadow": shadow,
        "gandanta": GANDANTA.get(name),
        "gandmool": name in GANDMOOL,
        "special_points": SPECIAL_POINTS.get(name, []),
        "padas": padas,
    })

DOC = {
    "engine": "pocketastro-nakshatras",
    "version": 1,
    "width_deg": WIDTH,
    "pada_deg": PADA,
    "sources": [
        "Charak, Elements of Vedic Astrology — ch. XXVI (muhurta classes), XXVII (gana/yoni/nadi).",
        "Komilla Sutton, The Essentials of Vedic Astrology — symbol, deity, sign interplay.",
        "Vic DiCara, 27 Stars 27 Gods — deity mythology.",
        "William Levacy, Beneath a Vedic Sky — nakshatra in practice, remedial use.",
    ],
    "abhijit": {
        "start_deg": 276.6667,
        "end_deg": 280.8889,
        "note": (
            "Abhijit, the 28th nakshatra, spans the last quarter of Uttara Ashadha and "
            "the first fifteenth of Shravana. It is not used in Vimshottari dasha, only "
            "in muhurta, where it is among the most auspicious spans for victory."
        ),
    },
    "gandanta": {
        "junctions": [
            {"water": "Revati", "fire": "Ashwini", "at_deg": 360.0},
            {"water": "Ashlesha", "fire": "Magha", "at_deg": 120.0},
            {"water": "Jyeshtha", "fire": "Mula", "at_deg": 240.0},
        ],
        "orb_deg": 3.3333,
        "meaning": (
            "The last pada of a water-sign nakshatra joined to the first pada of a fire-sign "
            "nakshatra is a karmic knot. Read it as a seam requiring rites and care, never as doom."
        ),
    },
    "gandmool": {
        "list": sorted(GANDMOOL),
        "meaning": (
            "Moon in a Ketu- or Mercury-ruled junction nakshatra. Classically flagged for "
            "birth shanti. In practice: an intense, uprooting start that matures well once "
            "the person stops fighting their own depth."
        ),
    },
    "yoni_enemies": [
        ["Cow", "Tiger"], ["Horse", "Buffalo"], ["Elephant", "Lion"],
        ["Goat", "Monkey"], ["Serpent", "Mongoose"], ["Dog", "Deer"], ["Cat", "Rat"],
    ],
    "vimshottari_years": {
        "Ketu": 7, "Venus": 20, "Sun": 6, "Moon": 10, "Mars": 7,
        "Rahu": 18, "Jupiter": 16, "Saturn": 19, "Mercury": 17,
    },
    "nakshatras": records,
}

for out in (ROOT / "assets/kb/nakshatras.json", ROOT / "knowledge/extract/nakshatras.json"):
    out.write_text(json.dumps(DOC, indent=1, ensure_ascii=False) + "\n")
print("nakshatras.json", len(json.dumps(DOC)), "bytes,", len(records), "records")

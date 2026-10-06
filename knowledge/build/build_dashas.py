#!/usr/bin/env python3
"""Dasha runtime table: Vimshottari mechanics, per-graha results, the 81
mahadasha x antardasha matrix, and the other dasha systems.

Sources: Charak, Elements of Vedic Astrology, ch. XIV (the dashas) and
XV (interpretation of the Vimshottari dasha); Sutton, Vimshottari Dashas —
The System of Prediction; Braha; Levacy.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

ORDER = ["Ketu", "Venus", "Sun", "Moon", "Mars", "Rahu", "Jupiter", "Saturn", "Mercury"]
YEARS = {"Ketu": 7, "Venus": 20, "Sun": 6, "Moon": 10, "Mars": 7,
         "Rahu": 18, "Jupiter": 16, "Saturn": 19, "Mercury": 17}
NAK_LORD = ["Ketu", "Venus", "Sun", "Moon", "Mars", "Rahu", "Jupiter", "Saturn", "Mercury"] * 3

MD = {
 "Sun": dict(
   years=6, karaka="soul, father, authority, government, the eye, bone",
   favourable=("Gain in standing and in resources; recognition from those above you; "
               "favours from authority. With the 5th lord, a child. With the 2nd or 4th lord, "
               "property and vehicles."),
   adverse=("Loss of position, disfavour from authority, forced relocation, friction with "
            "father or employer, strain on the heart and eyes."),
   push="Apply for the title, the promotion, the licence. Act in your own name.",
   wait="Do not fight authority head-on, and do not gamble reputation on a single confrontation.",
   body="heart, eyes, bones, blood pressure", themes=["status", "father", "government", "health of the heart"]),
 "Moon": dict(
   years=10, karaka="mind, mother, the public, home, fluids",
   favourable=("Renown, prosperity, auspicious events at home, favour from those in charge, "
               "childbirth, a settled mind. Especially good with the Moon in the 2nd."),
   adverse=("Loss of resources, mental and physical strain, worry about the mother, "
            "trouble with dependents, opposition from authority."),
   push="Move house, marry, expand the family, go public. The Moon's dasha rewards visibility.",
   wait="Do not make decisions in the first week of a low mood; the Moon's dasha amplifies moods into policy.",
   body="sleep, digestion, fluid balance, mental health", themes=["mother", "home", "public life", "emotional cycle"]),
 "Mars": dict(
   years=7, karaka="courage, land, siblings, conflict, surgery",
   favourable=("Rise in standing, benefit from land, gain of resources, vehicles, "
               "gains abroad, and generally good for siblings. In a kendra or the 3rd: "
               "gains through personal effort early in the dasha, with friction at the end."),
   adverse=("Loss of face, opponents on top, accident-proneness, inflammation, surgery, "
            "quarrels that cost more than they win."),
   push="Buy or develop land, start the physical build, take the competitive role, have the surgery.",
   wait="Do not litigate from anger, and do not sign anything in the first 48 hours after a fight.",
   body="blood, inflammation, accidents, surgery", themes=["property", "siblings", "conflict", "physical drive"]),
 "Mercury": dict(
   years=17, karaka="speech, intellect, commerce, documents, skill",
   favourable=("Learning, trade, writing and negotiation all favoured; income through skill "
               "and communication; good for education and for contracts."),
   adverse=("Nervous strain, disputes over documents, unreliable partners, speech that costs money, "
            "skin and nerve complaints."),
   push="Study, publish, trade, negotiate, incorporate, take the exam.",
   wait="Read every contract twice; Mercury's dasha is where a careless clause becomes a decade.",
   body="nerves, skin, speech, lungs", themes=["education", "commerce", "writing", "documents"]),
 "Jupiter": dict(
   years=16, karaka="wisdom, teacher, children, wealth, dharma",
   favourable=("Learning, teaching, children, marriage, wealth, travel and recognition. "
               "Jupiter's dasha is the classic window for the socially sanctioned event — "
               "marriage, a child, a degree, a house."),
   adverse=("Over-extension, weight and liver strain, misplaced faith in a teacher or a scheme, "
            "generosity that becomes debt."),
   push="Marry, have the child, take the degree, buy the house, accept the teaching role.",
   wait="Do not over-commit on optimism. Jupiter expands the mistake as readily as the merit.",
   body="liver, weight, circulation, ears", themes=["marriage", "children", "education", "wealth", "dharma"]),
 "Venus": dict(
   years=20, karaka="marriage, art, vehicles, comfort, desire",
   favourable=("Marriage, partnership, vehicles, property, art, luxury and social ease. "
               "The longest dasha and usually the most comfortable."),
   adverse=("Indulgence, relationship entanglement, reproductive and urinary complaints, "
            "money spent on appearance, diabetes risk."),
   push="Marry, partner, buy the vehicle, build the home, launch the creative or aesthetic work.",
   wait="Do not confuse comfort with progress. A 20-year Venus dasha can pass pleasantly and produce nothing.",
   body="reproductive system, kidneys, sugar, throat", themes=["marriage", "art", "comfort", "vehicles", "partnership"]),
 "Saturn": dict(
   years=19, karaka="duty, delay, structure, longevity, labour",
   favourable=("Durable achievement through labour; authority earned by endurance; land, "
               "mass work, service and long-cycle building. Whatever is completed in a Saturn "
               "dasha tends to stay completed."),
   adverse=("Delay, chronic illness, depression, isolation, loss of seniors, obstacles that "
            "cannot be argued with."),
   push="Build the structure meant to last: the institution, the house, the practice, the discipline.",
   wait="Do not take a shortcut. Saturn's dasha invoices shortcuts with interest.",
   body="joints, nerves, teeth, chronic fatigue, depression", themes=["career structure", "duty", "endurance", "loss"]),
 "Rahu": dict(
   years=18, karaka="obsession, foreign lands, technology, sudden scale",
   favourable=("Varied comforts, prosperity, honour abroad, recognition from foreign or "
               "unconventional quarters, ceremonies and celebration, sudden expansion."),
   adverse=("Displacement, mental anguish, separation from family, unclean food and illness, "
            "loss of resources, scandal, compulsive decisions."),
   push="Go abroad, take the unconventional route, scale the platform, enter the new technology.",
   wait="Do not leverage. Rahu's dasha is where borrowed money and borrowed identity both come due.",
   body="poisoning, addiction, undiagnosable complaints, skin, phobias",
   themes=["foreign life", "technology", "ambition", "scandal", "sudden change"]),
 "Ketu": dict(
   years=7, karaka="detachment, moksha, past-life skill, cutting",
   favourable=("Spiritual progress, research breakthroughs, healing capacity, freedom from "
               "something that had become a cage, and competence that appears without training."),
   adverse=("Sudden loss, separation, confusion about direction, undiagnosed complaints, "
            "the collapse of arrangements that were not real to begin with."),
   push="Retreat, research, learn the deep skill, close what should have been closed years ago.",
   wait="Do not stamp a permanent arrangement in a Ketu period — marriage, incorporation, a planned pregnancy, or a leveraged bet.",
   body="undiagnosed pain, low fevers, surgery, hearing", themes=["detachment", "research", "loss", "spiritual turn"]),
}

# Antardasha result by the AD lord's house-distance from the MD lord.
AD_BY_HOUSE = {
 1: "AD lord with the MD lord: the dasha's own theme intensifies; no second agenda.",
 2: "AD in the 2nd from the MD lord: money, family and speech become the channel.",
 3: "AD in the 3rd from the MD lord: effort, siblings, short travel and self-made moves.",
 4: "AD in the 4th from the MD lord: home, mother, land and vehicles; peace of mind is the issue.",
 5: "AD in the 5th from the MD lord: children, intellect, romance and speculation — a creative sub-period.",
 6: "AD in the 6th from the MD lord: work, debt, illness and opposition. Charak XV: a hard chapter — do not stamp events.",
 7: "AD in the 7th from the MD lord: partnership, marriage and public dealings drive the period.",
 8: "AD in the 8th from the MD lord: obstruction, delay, other people's money, sudden turns. Charak XV: do not stamp events.",
 9: "AD in the 9th from the MD lord: fortune, father, teachers and travel — the most favourable sub-period.",
 10: "AD in the 10th from the MD lord: career and public action carry the period.",
 11: "AD in the 11th from the MD lord: gains, networks and the fulfilment of the dasha's desire.",
 12: "AD in the 12th from the MD lord: expenditure, foreign ground, retreat and release. Charak XV: do not stamp events.",
}

RELATION = {
 "same": "MD and AD are the same graha: the dasha runs undiluted — its best and its worst at once.",
 "friend": "Natural friends: the sub-period cooperates with the dasha's agenda.",
 "neutral": "Naturally neutral: the sub-period neither helps nor blocks; the house-distance and functional nature decide.",
 "enemy": "Natural enemies: the sub-period pulls against the dasha's agenda. Expect divided effort and half-finished moves.",
}

PAIR_NOTES = {
 ("Jupiter", "Venus"): "Classically among the strongest windows for marriage, children and a home purchase — if the natal 7th, 5th or 4th supports it.",
 ("Venus", "Jupiter"): "The same window read from the other side: partnership, ceremony, grace. The most commonly cited marriage period in Jyotisha.",
 ("Saturn", "Mercury"): "Structure meets paperwork: the best sub-period in a Saturn dasha for contracts, qualifications and incorporation.",
 ("Saturn", "Venus"): "Saturn's discipline over Venus's desire: relationships get formalised or ended. Rarely neutral.",
 ("Saturn", "Sun"): "Authority against authority. Friction with employers, fathers and institutions; bones and heart need care.",
 ("Saturn", "Mars"): "The hardest common pairing: obstruction meeting force. Accidents, litigation, burnout. Slow everything down.",
 ("Rahu", "Saturn"): "Ambition under a ceiling. Long, heavy, transformative; results arrive after the sub-period, not during it.",
 ("Rahu", "Jupiter"): "Guru-Chandal in time: unorthodox expansion. Brilliant or badly advised, rarely in between.",
 ("Rahu", "Ketu"): "The axis turns on itself. Disorientation about direction; a poor window for anything irreversible.",
 ("Ketu", "Rahu"): "The same reversal. Endings that are genuinely endings. Do not fight them.",
 ("Ketu", "Venus"): "Detachment applied to attachment. A classical caution for marriage and for new partnerships.",
 ("Mercury", "Venus"): "Trade, art, negotiation and partnership all align. Good for contracts and creative launches.",
 ("Mars", "Saturn"): "Force against obstruction. Property disputes, surgery, litigation. Do not escalate.",
 ("Moon", "Saturn"): "The mind under weight. Watch sleep and mood; postpone irreversible emotional decisions.",
 ("Sun", "Saturn"): "Authority tested by duty. Career pressure that is survivable and formative.",
 ("Jupiter", "Saturn"): "Expansion meeting structure: slow, real, durable growth. Good for institutions and long builds.",
 ("Venus", "Saturn"): "Desire disciplined. Marriages formalised, or relationships that were never real ending quietly.",
 ("Jupiter", "Ketu"): "Faith detaching from its container. Strong for practice and research, weak for ceremony.",
 ("Mercury", "Ketu"): "The mind goes quiet and deep. Excellent for research, poor for negotiation.",
}

matrix = {}
for md in ORDER:
    for ad in ORDER:
        key = f"{md}-{ad}"
        entry = {
            "md": md, "ad": ad,
            "ad_years": round(YEARS[md] * YEARS[ad] / 120.0, 4),
            "note": PAIR_NOTES.get((md, ad), ""),
        }
        matrix[key] = entry

DOC = {
 "engine": "pocketastro-dashas",
 "version": 1,
 "sources": [
   "Charak, Elements of Vedic Astrology — ch. XIV (the dashas) and XV (interpretation of the Vimshottari dasha).",
   "Sutton, The Essentials of Vedic Astrology — Vimshottari Dashas, The System of Prediction.",
   "Braha, Ancient Hindu Astrology for the Modern Western Astrologer.",
   "Levacy, Beneath a Vedic Sky — dasa periods.",
 ],
 "vimshottari": {
   "total_years": 120,
   "order": ORDER,
   "years": YEARS,
   "nakshatra_lords": NAK_LORD,
   "balance_rule": (
     "The birth dasha is the lord of the Moon's nakshatra. The unelapsed portion of that "
     "nakshatra, as a fraction of 13°20', times that lord's years, gives the balance at birth."
   ),
   "sub_rule": "Each sub-period is (parent years x sub lord years) / 120, and the sub-order starts from the parent lord itself.",
   "levels": ["mahadasha", "antardasha (bhukti)", "pratyantardasha", "sookshma", "prana"],
   "year_length_days": 365.2425,
 },
 "judgment_rules": [
   "A graha gives favourable results in its dasha when it is strong, exalted, in its own sign or moolatrikona, in a friend's sign, under benefic aspect, and placed in a kendra, trikona, the 2nd or the 11th, or joined to the 9th or 10th lord.",
   "It gives adverse results when weak, debilitated, in an enemy's sign, combust, placed in the 6th, 8th or 12th, or under malefic aspect.",
   "House ownership dominates natural nature. During its dasha a graha suddenly activates the house it owns.",
   "Timing within the dasha follows the drekkana: a graha in the first drekkana of its sign delivers early in the dasha, the second drekkana in the middle, the third at the end. For a retrograde graha the order reverses.",
   "A graha delivers the results of the house it occupies as much as the house it owns; read both.",
   "The mahadasha sets the chapter, the antardasha the paragraph, the pratyantara the sentence. Never predict a dated event from the mahadasha alone.",
   "Confirm every dasha reading against the running gochara. Two techniques must agree before an event is called likely.",
   "Read the dasha lord's position in the relevant varga — D9 for marriage and character, D10 for career, D7 for children.",
 ],
 "dasa_chidra": {
   "definition": "The last tenth of a mahadasha, and specifically the final antardasha within it.",
   "reading": "A closing-out window. Do not launch a new life on the leftover of an expiring mahadasha; finish, settle and hand over instead.",
 },
 "dasha_sandhi": {
   "definition": "The junction between two mahadashas, roughly the last and first few months.",
   "reading": "The most disorienting stretch in the Vimshottari cycle. Results of the old dasha stop arriving before the new one starts paying.",
 },
 "ketu_antardasha_caution": {
   "forbidden": ["marriage registration", "company incorporation", "pregnancy-as-plan", "leveraged speculation"],
   "reason": "Ketu severs rather than binds. Anything requiring a permanent binding is poorly timed under a Ketu sub-period.",
   "still_good_for": ["research", "retreat", "closing an old obligation", "learning a deep skill", "medical diagnosis"],
 },
 "mahadasha": MD,
 "antardasha_by_house_from_md_lord": AD_BY_HOUSE,
 "antardasha_by_relation": RELATION,
 "md_ad_matrix": matrix,
 "other_systems": {
   "yogini": {
     "total_years": 36,
     "order": ["Mangala", "Pingala", "Dhanya", "Bhramari", "Bhadrika", "Ulka", "Siddha", "Sankata"],
     "lords": {"Mangala": "Moon", "Pingala": "Sun", "Dhanya": "Jupiter", "Bhramari": "Mars",
               "Bhadrika": "Mercury", "Ulka": "Saturn", "Siddha": "Venus", "Sankata": "Rahu"},
     "years": {"Mangala": 1, "Pingala": 2, "Dhanya": 3, "Bhramari": 4,
               "Bhadrika": 5, "Ulka": 6, "Siddha": 7, "Sankata": 8},
     "start_rule": "Add 3 to the Moon's nakshatra number, divide by 8; the remainder gives the starting yogini (0 counts as 8).",
     "use": "A fast cross-check on Vimshottari. Sankata (Rahu) and Ulka (Saturn) periods are the classic difficulty flags.",
   },
   "ashtottari": {
     "total_years": 108,
     "order": ["Sun", "Moon", "Mars", "Mercury", "Saturn", "Jupiter", "Rahu", "Venus"],
     "years": {"Sun": 6, "Moon": 15, "Mars": 8, "Mercury": 17, "Saturn": 10,
               "Jupiter": 19, "Rahu": 12, "Venus": 21},
     "applicability": "Classically applied when Rahu occupies a kendra or trikona from the lagna lord.",
     "use": "A secondary clock; never used to override Vimshottari.",
   },
   "chara_jaimini": {
     "basis": "Sign-based dasha counted from the lagna; each sign's length equals the count from that sign to its lord.",
     "use": "Jaimini timing, read with the chara karakas (Atmakaraka to Darakaraka) and the Arudha lagna.",
     "note": "PocketAstro treats Jaimini as a second opinion, not a primary clock.",
   },
   "kalachakra": {
     "basis": "Derived from the Moon's nakshatra pada; each pada maps to a nine-sign deha/jeeva sequence.",
     "use": "Specialist system; strong for longevity and journey questions in the classical literature.",
   },
   "narayana": {
     "basis": "Rashi dasha from the 1st house, used for bhava-level timing.",
     "use": "Cross-check for property and career windows.",
   },
 },
 "chara_karakas": {
   "order": ["Atmakaraka", "Amatyakaraka", "Bhratrikaraka", "Matrikaraka",
             "Pitrikaraka", "Putrakaraka", "Gnatikaraka", "Darakaraka"],
   "rule": "Rank the seven grahas (optionally with Rahu, counted in reverse) by degrees within their sign, highest first.",
   "meanings": {
     "Atmakaraka": "the soul's agenda — the one lesson the life is actually about",
     "Amatyakaraka": "career and counsel",
     "Bhratrikaraka": "siblings, courage, guru",
     "Matrikaraka": "mother, home",
     "Pitrikaraka": "father",
     "Putrakaraka": "children, creativity",
     "Gnatikaraka": "obstacles, illness, relatives",
     "Darakaraka": "spouse",
   },
 },
}

for out in (ROOT / "assets/kb/dashas.json", ROOT / "knowledge/extract/dashas.json"):
    out.write_text(json.dumps(DOC, indent=1, ensure_ascii=False) + "\n")
print("dashas.json", len(json.dumps(DOC)), "bytes,", len(matrix), "MD-AD cells")

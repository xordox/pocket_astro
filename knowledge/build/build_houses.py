#!/usr/bin/env python3
"""Bhava runtime table: significations + all 144 house-lord placements.

The 144 cells are composed from a classical frame — Charak, *Elements of Vedic
Astrology*, ch. XVII (Placement of Lords of Houses), which follows Parashara —
restated in modern, non-fatalistic language. Where the classics give a
distinctive ruling for a specific cell, it is carried as an explicit note.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

HOUSES = {
 1: dict(sanskrit="Tanu bhava", topics="self, body, vitality, head, general fortune, how you arrive in a room",
   karakas=["Sun"], body="head, brain, complexion, overall constitution",
   people=["the native"], classes=["kendra", "trikona"], purushartha="dharma",
   detail="The lagna is the chart's engine. Every other promise is delivered through the strength of the 1st house and its lord. A weak lagna lord shrinks even a strong raja yoga."),
 2: dict(sanskrit="Dhana bhava", topics="accumulated wealth, speech, food, face, immediate family, values",
   karakas=["Jupiter"], body="face, right eye, mouth, teeth, throat, tongue",
   people=["immediate family", "dependents"], classes=["panapara", "maraka"], purushartha="artha",
   detail="Savings rather than income — the 11th earns, the 2nd keeps. Also the voice, literally and as reputation. A maraka house: its lord governs the body's exit as well as its sustenance."),
 3: dict(sanskrit="Sahaja bhava", topics="courage, initiative, younger siblings, short travel, hands, skill, writing",
   karakas=["Mars"], body="arms, hands, shoulders, ears, throat",
   people=["younger siblings", "neighbours", "collaborators"], classes=["upachaya", "apoklima"], purushartha="kama",
   detail="An upachaya house: malefics here improve over time. This is the house of self-effort — the part of the chart that is not inherited."),
 4: dict(sanskrit="Sukha bhava", topics="home, mother, land, vehicles, education's foundation, inner contentment",
   karakas=["Moon", "Mercury (formal education)"], body="chest, heart, lungs, breasts",
   people=["mother", "household"], classes=["kendra", "moksha-adjacent"], purushartha="moksha",
   detail="The seat of the chart — what you return to. Also the house of the final resting place, and of whether the mind has a floor under it."),
 5: dict(sanskrit="Putra bhava", topics="children, intelligence, romance, speculation, mantra, past-life merit",
   karakas=["Jupiter"], body="stomach, upper abdomen, liver, spine",
   people=["children", "students", "lovers"], classes=["trikona"], purushartha="dharma",
   detail="Purva punya — the credit balance carried in. The 5th shows what comes easily because it was earned before. It is also the house of mantra, and therefore of remedy."),
 6: dict(sanskrit="Ripu bhava", topics="work and service, illness, debt, enemies, litigation, daily routine, pets",
   karakas=["Mars", "Saturn"], body="intestines, navel, kidneys, digestive tract",
   people=["employees", "opponents", "creditors", "maternal uncle"], classes=["dusthana", "upachaya", "trik"], purushartha="artha",
   detail="A dusthana that is also an upachaya: it hurts, and it improves with effort. Strong 6th = the ability to out-work opposition, at the price of never quite resting."),
 7: dict(sanskrit="Kalatra bhava", topics="marriage, partner, business partnership, public dealings, the other person",
   karakas=["Venus"], body="pelvis, lower back, reproductive organs, urinary tract",
   people=["spouse", "business partner", "open opponents"], classes=["kendra", "maraka"], purushartha="kama",
   detail="The mirror house — whatever the 1st will not own, the 7th delivers through another person. Also a maraka: the second exit door of the chart."),
 8: dict(sanskrit="Randhra bhava", topics="longevity, transformation, inheritance, tax and insurance, the occult, in-laws, sudden events",
   karakas=["Saturn"], body="external genitals, anus, chronic and hidden conditions",
   people=["in-laws", "those who hold your money"], classes=["dusthana", "trik", "panapara"], purushartha="moksha",
   detail="The house of what you did not choose. It is the house of longevity, not of death; PocketAstro reads it for endurance, research capacity and other people's money, never for a date."),
 9: dict(sanskrit="Dharma bhava", topics="fortune, father, guru, long travel, higher learning, law, faith",
   karakas=["Jupiter", "Sun"], body="hips, thighs, arterial system",
   people=["father", "teacher", "priest", "in-laws' family"], classes=["trikona", "apoklima"], purushartha="dharma",
   detail="The single most fortunate house. Its lord's condition sets the ceiling on luck — a strong 9th lord rescues a difficult chart more reliably than any yoga."),
 10: dict(sanskrit="Karma bhava", topics="career, status, public name, authority, action in the world",
   karakas=["Sun", "Mercury", "Jupiter", "Saturn"], body="knees, joints, bones of the leg",
   people=["employer", "government", "the public as audience"], classes=["kendra", "upachaya"], purushartha="artha",
   detail="Not the job but the standing. Judge with the D10 (dashamsa) before making a career call. An empty 10th is normal — the payout runs through the 10th lord."),
 11: dict(sanskrit="Labha bhava", topics="gains, income, elder siblings, friends, networks, fulfilment of desire",
   karakas=["Jupiter"], body="shins, calves, ankles, left ear",
   people=["elder siblings", "friends", "patrons", "networks"], classes=["upachaya", "panapara"], purushartha="kama",
   detail="Income, as distinct from savings. The 11th is the strongest upachaya — even malefics gain here. Its shadow is that desire keeps regenerating."),
 12: dict(sanskrit="Vyaya bhava", topics="expenditure, loss, foreign lands, sleep, isolation, liberation, the bed",
   karakas=["Saturn", "Ketu"], body="feet, left eye, lymphatic system",
   people=["those abroad", "hidden opponents", "hospital and prison staff"], classes=["dusthana", "trik", "apoklima", "moksha"], purushartha="moksha",
   detail="Everything that leaves — money, sleep, the country, the self. A strong 12th is not poverty; it is a person whose real life happens off-stage."),
}

# What a house, as an owner, carries into wherever its lord sits.
OWNER = {
 1: "the body, the name and the personal engine of the chart",
 2: "savings, speech, food and the family's resources",
 3: "courage, initiative, craft and the younger siblings",
 4: "home, mother, land, vehicles and inner contentment",
 5: "children, intelligence, romance and inherited merit",
 6: "work, debt, illness, opposition and daily routine",
 7: "marriage, partnership and dealings with the other",
 8: "longevity, inheritance, crisis and what is hidden",
 9: "fortune, father, teachers, law and long travel",
 10: "career, status and public action",
 11: "income, friends, networks and the fulfilment of desire",
 12: "expenditure, foreign ground, retreat and release",
}

# The field a lord lands in.
FIELD = {
 1: ("the 1st — the body and the name", "it becomes personal: the native carries it themselves, visibly, and is identified with it"),
 2: ("the 2nd — savings, speech and family", "it is monetised and spoken about; family becomes a stakeholder"),
 3: ("the 3rd — effort, craft and siblings", "it has to be worked for by hand; results come through initiative and short reach, not through position"),
 4: ("the 4th — home, mother and land", "it moves indoors: home, mother, property and peace of mind become the channel"),
 5: ("the 5th — children, intellect and merit", "it runs through intelligence, creativity, children, or something already earned in a past cycle"),
 6: ("the 6th — work, debt and opposition", "it costs friction: service, debt, litigation or health become the route, and the result is won rather than given"),
 7: ("the 7th — partnership and the public", "it arrives through another person: spouse, partner, or the public; rarely alone"),
 8: ("the 8th — crisis, inheritance and the hidden", "it goes underground: delays, other people's money, research, and sudden turns. Results are real but not on schedule"),
 9: ("the 9th — fortune, father and dharma", "it is blessed: luck, teachers, law and long travel carry it further than effort alone would"),
 10: ("the 10th — career and status", "it becomes public and professional; the native is known for it"),
 11: ("the 11th — income, friends and networks", "it multiplies: gains, patrons and networks feed it, and it grows over the life"),
 12: ("the 12th — loss, foreign ground and retreat", "it is spent, exported, or given up; it works abroad, in private, or not at all in the obvious form"),
}

# Distinctive classical rulings worth carrying verbatim in substance.
NOTES = {
 (1, 1): "Sound health and a long constitution; the chart stands on its own feet.",
 (1, 6): "Health and opposition are both live themes; if afflicted, illness and rivals — if clean, the native destroys opposition and earns from their own labour.",
 (1, 8): "Longevity is supported but health is not; good for occult and research work, hard on the body's comfort. Read Saturn before judging.",
 (1, 10): "One of the best placements in the chart — self-made status recognised by authority.",
 (1, 12): "Bodily comfort is thin and the life tends to run abroad or in retreat. Benefic aspect on the 12th materially reduces the difficulty.",
 (2, 4): "Wealth through property and the mother's side. Exalted, or with Jupiter or Venus, this is a near-royal money placement. Mars here acts as a maraka.",
 (2, 6): "Money is earned through and from opposition — litigation, competition, service. With malefics, loss and stress instead.",
 (2, 8): "Income from land and other people's money; comfort from partner is reduced. Classically the hardest cell for the 2nd lord.",
 (2, 11): "Widely known, well-off, and responsible for many people's needs.",
 (3, 3): "Healthy, courageous, supported by siblings and friends; self-effort pays directly.",
 (3, 8): "Effort meets obstruction; hard on siblings; do not sign for other people's risk.",
 (4, 4): "Owns substantial property; steady, well-informed, comfortable; a natural minister or administrator.",
 (4, 8): "Little comfort from home or parents; the domestic base has to be rebuilt from scratch.",
 (4, 10): "Excellent health and standing; property and career reinforce each other.",
 (4, 12): "Home is elsewhere — foreign residence, or a father who lived away.",
 (5, 5): "Learning, pride and progeny. Under benefic influence, excellent for children; under malefic influence, children are delayed or few.",
 (5, 6): "Strain around a child or a creative venture; opposition from those one has taught or raised.",
 (5, 8): "Hard on progeny and on the nerves; deep intellect turned toward crisis.",
 (5, 11): "Very learned and well-off; writing, publishing and teaching pay. One of the best 5th-lord placements.",
 (5, 12): "Children are few, distant, or the creative life runs abroad or in private.",
 (6, 6): "Hostile to one's own circle, friendly to outsiders; ordinary wealth but genuinely good health (a vipreeta pattern).",
 (6, 8): "Vipreeta raja yoga (Harsha — 6th lord in the 8th): sustained gain out of other people's crises, but the 8th lord must not be afflicted by marakas. Classically read for the mode of a health crisis — treat it as a lifestyle flag, never a prediction.",
 (6, 11): "Gains directly out of opposition; thefts and disputes are recurring but survivable.",
 (6, 12): "Vipreeta raja yoga (Harsha — 6th lord in the 12th): loss cancels debt. Money leaks into avoidable pursuits unless the person is deliberate.",
 (7, 1): "Very clever and attractive; strongly attached to the partner. Watch vata-type complaints.",
 (7, 6): "Friction inside the marriage; the partner's health or temper is a live issue.",
 (7, 7): "A genuinely good marriage placement — learned, well known, well partnered.",
 (7, 8): "Marriage is unstable or the partner's health is a theme. The classic flag; read D9 and the 7th lord's dignity before saying anything.",
 (7, 11): "Earns through the partner; partnership is profitable.",
 (7, 12): "Expenditure through the partner; the marriage may be abroad, or lived at a distance.",
 (8, 1): "Physical strain and injuries; not a comfortable placement, but excellent for depth work.",
 (8, 6): "Vipreeta raja yoga (Sarala — 8th lord in the 6th): the native overcomes opposition and illness, though childhood health may be poor.",
 (8, 8): "Long life and good health; famous in some hidden domain. A strong 8th lord in the 8th is protective.",
 (8, 12): "Vipreeta raja yoga (Sarala — 8th lord in the 12th): hidden losses cancel; the body needs care.",
 (9, 1): "Learned, fortunate, honoured; among the best cells in the chart.",
 (9, 9): "Very fortunate — the classical marker of a life with luck on tap.",
 (9, 10): "Dharma and career align: status through legitimate, principled work. A first-class raja-yoga cell.",
 (9, 11): "Continuous inflow of money, long life, and standing through belief or teaching.",
 (9, 12): "Fortune is spent on charity and pilgrimage; honoured abroad rather than at home.",
 (10, 1): "Progressive rise in wealth and learning; sickly in childhood, healthy later.",
 (10, 6): "Skilled but obstructed; the career fights for every inch. Health, however, holds.",
 (10, 9): "A king or their modern equivalent — the strongest career cell.",
 (10, 10): "Truthful, capable and comfortable; the career is the life.",
 (10, 12): "Work abroad, or work that is deliberately out of public view. Expenditure through authority.",
 (11, 1): "Steady inflow of money and a sattvic, even-handed nature.",
 (11, 2): "Very wealthy and charitable, but the classics flag health; do not read this as a lifespan claim.",
 (11, 6): "Powerful enemies and residence abroad; gains are contested.",
 (11, 11): "Gains from every direction; renown through learning and possessions. The best cell for the 11th lord.",
 (12, 1): "Spendthrift tendency and a body that needs deliberate care; often a life lived away from where it started.",
 (12, 6): "Vipreeta raja yoga (Vimala — 12th lord in the 6th): expenditure cancels debt. Good for competitive and service work.",
 (12, 8): "Vipreeta raja yoga (Vimala — 12th lord in the 8th): loss is converted into inheritance, research or hidden gain.",
 (12, 12): "Expenditure is structural; a strong contemplative or foreign life. Read it as design, not misfortune.",
}

def _o(n):
    return {1: "1st", 2: "2nd", 3: "3rd"}.get(n, f"{n}th")


cells = {}
for owner in range(1, 13):
    for field in range(1, 13):
        label, effect = FIELD[field]
        line = f"The {_o(owner)} lord carries {OWNER[owner]} into {label}: {effect}."
        note = NOTES.get((owner, field))
        if note:
            line += " " + note
        cells[f"{owner}-{field}"] = line

DOC = {
    "engine": "pocketastro-houses",
    "version": 1,
    "sources": [
        "Charak, Elements of Vedic Astrology — ch. VII (significations) and XVII (lords of houses).",
        "Deborah Houlding, The Houses: Temples of the Sky — house derivation and classical topics.",
        "Sutton, The Essentials of Vedic Astrology — bhavas and the four purusharthas.",
    ],
    "classes": {
        "kendra": [1, 4, 7, 10], "trikona": [1, 5, 9], "dusthana": [6, 8, 12],
        "trik": [6, 8, 12], "upachaya": [3, 6, 10, 11], "maraka": [2, 7],
        "panapara": [2, 5, 8, 11], "apoklima": [3, 6, 9, 12],
        "dharma": [1, 5, 9], "artha": [2, 6, 10], "kama": [3, 7, 11], "moksha": [4, 8, 12],
    },
    "reading_rules": [
        "Judge a house three ways: occupants, its lord's placement and dignity, and aspects onto it. All three must be weighed before a verdict.",
        "An empty house is normal and is not weak. The payout simply runs through the lord.",
        "Bhavat bhavam: the matter of a house is confirmed by the same count taken again from it — the 7th from the 7th (the lagna) for marriage, the 4th from the 4th (the 7th) for property, the 9th from the 9th (the 5th) for fortune.",
        "Kendradhipati dosha: a natural benefic owning a kendra loses beneficence; a natural malefic owning a kendra gains it.",
        "A trikona lord is always benefic for that lagna; a lord of 3, 6 or 11 is always functionally malefic.",
        "Dusthana lords placed in another dusthana form vipreeta raja yoga — relief through reversal.",
        "The most reliable single strength test in a natal chart is the condition of the lagna lord and the 9th lord.",
    ],
    "houses": {str(k): v for k, v in HOUSES.items()},
    "owner_theme": {str(k): v for k, v in OWNER.items()},
    "lord_in_house": cells,
}

for out in (ROOT / "assets/kb/houses.json", ROOT / "knowledge/extract/houses.json"):
    out.write_text(json.dumps(DOC, indent=1, ensure_ascii=False) + "\n")
print("houses.json", len(json.dumps(DOC)), "bytes,", len(cells), "lord-in-house cells")

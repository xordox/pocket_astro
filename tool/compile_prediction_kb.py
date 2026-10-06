#!/usr/bin/env python3
"""Compile runtime prediction KB from PocketAstro extracts + classical tables."""
import json
from pathlib import Path

ROOT = Path("/Users/ambition/flutter_projects/PocketAstro")
catalog = json.loads((ROOT / "knowledge/extract/_catalog.json").read_text())

sources = []
for rec in catalog:
    name = rec.get("file") or ""
    role = "support"
    n = name.lower()
    if any(k in n for k in ("charak", "elements_of_vedic")):
        role = "vedic_core"
    elif "braha" in n or "ancient_hindu" in n:
        role = "vedic_core"
    elif "sutton" in n or "essentials_of_vedic" in n:
        role = "vedic_core"
    elif "levacy" in n or "beneath_a_vedic" in n:
        role = "vedic_core"
    elif "27_stars" in n or "dicara" in n:
        role = "nakshatra"
    elif "rushman" in n or "predictive" in n:
        role = "western_predict"
    elif "houlding" in n:
        role = "houses"
    elif "tompkins" in n or "contemporary" in n:
        role = "western_natal"
    elif "sakoian" in n or "human_relationships" in n:
        role = "synastry"
    elif "stellas" in n and "how_to_be" in n:
        role = "western_predict"
    elif any(k in n for k in ("natal_reading", "vedic_prediction", "questions_answered")):
        role = "method_template"
    sources.append({
        "file": name,
        "pages": rec.get("pages"),
        "role": role,
        "image_like": rec.get("image_like"),
        "has_toc": bool(rec.get("toc")),
    })

houses = {
    str(i): t for i, t in enumerate([
        "",
        "self, body, fame",
        "speech, family, savings",
        "courage, siblings, craft",
        "home, mother, vehicles, land",
        "children, intellect, romance",
        "work, illness, enemies, debt",
        "spouse, partner, the other",
        "transformation, tax, in-laws, occult",
        "dharma, father, luck, long travel",
        "career, status, public name",
        "gains, friends, networks",
        "loss, sleep, foreign, retreat",
    ], 0) if i
}

saturn_from_moon = {
    "1": "Sade Sati peak: identity, body, and duty press the mind. Structure the day; do not self-erase.",
    "2": "Sade Sati money/family chapter: delayed income, family duty, speech under weight. Save more than you display.",
    "3": "Effort, siblings, short travel, and craft take labour. Courage is available if paced.",
    "4": "Home, mother, vehicles, and chest/sleep need care. Moves happen slowly and last.",
    "5": "Children, romance, and speculation: caution, not freeze. Romance needs maturity.",
    "6": "Work, debt, illness, enemies. Can defeat opposition through routine. Health: chronic grind, not drama.",
    "7": "Partnership tests. Contracts get real. Do not marry only to end a lonely Saturn.",
    "8": "Ashtama Shani: hidden tests, tax, elder health, chronic worry. Toll on the dasha — not deletion of yoga. Pay in sleep, accounts, honesty.",
    "9": "Father, dharma, long travel delayed then made durable. Study and law take time.",
    "10": "Career pressure and status through labour. Public name if you stay visible.",
    "11": "Gains slowly; elder or serious friends. Networks that last.",
    "12": "Sade Sati begins (12th from Moon): expenses, isolation, foreign, sleep. Start the hygiene now.",
}

jupiter_from_moon = {
    "1": "Growth of self and body-confidence. Teaching or blessing finds you.",
    "2": "Speech and savings expand. Good for study and family money talks.",
    "3": "Skill, writing, siblings. Short decisive journeys.",
    "4": "Home and mother ease. Property talks possible if dasha agrees.",
    "5": "Children, intellect, romance, poorvapunya. Opportunity — event if dasha of 5th/Jupiter agrees.",
    "6": "Help with work/health through counsel. Not a vacation; a better strategy.",
    "7": "Classic marriage/partnership transit (Sutton). Event if dasha of 7th/Venus/Jupiter also runs; otherwise hope and talks.",
    "8": "Shared money, research, in-laws. Grace inside intensity.",
    "9": "Luck, guru, long travel, dharma. Strong fortune if dasha supports.",
    "10": "Career expansion, titles, teaching role.",
    "11": "Gains, friends, fulfilment of hopes.",
    "12": "Charity, foreign, spiritual retreat. Expenses with meaning.",
}

mars_from_lagna = {
    "1": "Heat in body and will. Accident caution, surgery of schedule.",
    "4": "Home heat; vehicles; mother stress. Do not pick family fights for sport.",
    "7": "Open conflict or passion in partnership. Needs an equal.",
    "8": "Sudden bills, surgery themes, occult heat. Ordinary precautions > gems.",
    "12": "Sleep leak, hidden anger, foreign haste.",
}

dasha = {
    "Sun": {
        "flavour": "Authority, father, title, vitality, government, pride.",
        "push": "Claim a name. Formalise. Do not pick a fight with the boss for sport.",
        "wait": "Ego wars, head/heat, father conflict.",
        "sources": ["Charak XV", "Braha"],
    },
    "Moon": {
        "flavour": "Mind, mother, public, fluids, home mood, popularity.",
        "push": "Public goodwill, care, home, the closing of a chapter.",
        "wait": "Mood-as-verdict, leaving a quarrel half-fought.",
        "sources": ["Charak XV"],
    },
    "Mars": {
        "flavour": "Courage, land, siblings, surgery of life, self-made career if 10th lord.",
        "push": "Act, build, name the work. Peak if Mars is kendra/lagna lord.",
        "wait": "Angry messages, high-risk bets in Ketu AD inside Mars MD.",
        "sources": ["Charak XV", "Braha yogakaraka notes"],
    },
    "Mercury": {
        "flavour": "Documents, speech, trade, exams, visas, nervous system.",
        "push": "Write, file, revise once. Neecha bhanga: first no, then yes.",
        "wait": "Endless revision (12th pretending to be Mercury), rush-sign in Rahu PD.",
        "sources": ["Charak XV"],
    },
    "Jupiter": {
        "flavour": "Spouse-grace, teacher, children, law, expansion, harvest.",
        "push": "Teaching, legal, marriage talks, dharma work.",
        "wait": "Over-promising, preaching instead of contracting.",
        "sources": ["Charak XV", "Sutton"],
    },
    "Venus": {
        "flavour": "Marriage, vehicles, arts, money-comfort. Yogakaraka when 4+9 or 5+10.",
        "push": "Marry, rate card, property, public face — especially as AD inside kendra-lord MD.",
        "wait": "Pleasure without a contract; delaying the harvest into a hungrier Rahu MD.",
        "sources": ["Charak XV", "Braha yogakaraka", "Levacy"],
    },
    "Saturn": {
        "flavour": "Delay, duty, longevity, structure, foreign/12th work.",
        "push": "Finish, systematise, take the long apprenticeship.",
        "wait": "Launching on exhaustion; treating delay as proof of unsuitability.",
        "sources": ["Charak XV", "Houlding 12th"],
    },
    "Rahu": {
        "flavour": "Hunger, foreign, unconventional, scale, smoke, obsession.",
        "push": "Multiply what a prior dasha already started. Networks, abroad.",
        "wait": "Inventing a life from a mood; signing in fog; Rahu-on-lagna theatre.",
        "sources": ["Levacy nodes", "Sutton nodes", "DiCara Mula"],
    },
    "Ketu": {
        "flavour": "Cutting, moksha, loss of story, spiritual reset, endings.",
        "push": "End false roles, retreat, surgery of the schedule.",
        "wait": "Wedding, company incorporation, pregnancy-as-plan, leveraged bets.",
        "sources": ["Charak XV", "Levacy", "DiCara"],
    },
}

nak = {
    "Ashwini": "Begin, heal, move fast. Initiate; do not wait to be chosen.",
    "Bharani": "Carry, birth, restrain. Do not drop the weight or it drops you.",
    "Krittika": "Cut, purify, ambition. Sharp speech; use it as a blade for work not kin.",
    "Rohini": "Grow, beauty, fertility. Make something last.",
    "Mrigashira": "Search, quest. Curiosity is the path; restlessness is the leak.",
    "Ardra": "Storm, intellect. Transformation through mind; do not romanticise chaos.",
    "Punarvasu": "Return, renew. Second chances that are ethical.",
    "Pushya": "Nourish, dharma. Care as career.",
    "Ashlesha": "Research, coil, strategy. Do not manipulate kin.",
    "Magha": "Throne, ancestors. Dignity; a partner or role with lineage weight.",
    "Purva Phalguni": "Pleasure, romance, creativity. Civilized Venus — contract it.",
    "Uttara Phalguni": "Vows, patronage, friendship. Lasting alliances.",
    "Hasta": "Hands, craft, skill. Make the thing.",
    "Chitra": "Design, brilliance, form. Build the beautiful structure.",
    "Swati": "Independence, air, selfhood. Do not exile yourself as freedom.",
    "Vishakha": "Forked drive, ambition. Pick one summit.",
    "Anuradha": "Devotion, ally. Loyalty that is not self-erasure.",
    "Jyeshtha": "Seniority, protection, heat. Lead without dominating.",
    "Mula": "Uproot, investigate. Success after the false root is pulled.",
    "Purva Ashadha": "Early victory, pride. Do not celebrate before the stamp.",
    "Uttara Ashadha": "Lasting victory, duty. The long win.",
    "Shravana": "Listen, path, learning. Ears before mouth.",
    "Dhanishta": "Rhythm, wealth, drums. Time the beat.",
    "Shatabhisha": "Veil, heal, solitude. Medicine and mystery; not disappearance as identity.",
    "Purva Bhadrapada": "Intensity, fire, transformation. Two faces; choose the adult one.",
    "Uttara Bhadrapada": "Depth, rain, completion. Finish.",
    "Revati": "Nourish, crossing, ending-as-beginning. Safe passage.",
}

event_keys = {
    "marriage": {
        "dasha_planets": ["Venus", "Jupiter"],
        "houses": [7, 2, 8],
        "jupiter_gochara_houses_from_lagna": [1, 5, 7, 9],
        "avoid_ad": ["Ketu"],
        "western": "Progressed Moon to natal Venus/DSC or transiting Saturn/Jupiter on 7th (Rushman stack).",
    },
    "career": {
        "dasha_planets": ["Sun", "Mars", "Saturn", "Mercury"],
        "houses": [10, 6, 1],
        "jupiter_gochara_houses_from_lagna": [10, 11, 1],
        "avoid_ad": ["Ketu"],
        "western": "Saturn/Jupiter on MC; progressed Moon through 10th.",
    },
    "money": {
        "dasha_planets": ["Venus", "Jupiter", "Mercury"],
        "houses": [2, 11, 8],
        "jupiter_gochara_houses_from_lagna": [2, 11],
        "avoid_ad": ["Ketu"],
        "western": "Jupiter on 2nd/8th; Venus transits.",
    },
    "home": {
        "dasha_planets": ["Moon", "Venus", "Mars", "Saturn"],
        "houses": [4, 12],
        "jupiter_gochara_houses_from_lagna": [4],
        "avoid_ad": ["Ketu"],
        "western": "Saturn on IC; progressed Moon in 4th.",
    },
    "children": {
        "dasha_planets": ["Jupiter", "Mercury"],
        "houses": [5],
        "jupiter_gochara_houses_from_lagna": [5],
        "avoid_ad": ["Ketu"],
        "western": "Jupiter on 5th.",
    },
}

kb = {
    "engine": "PocketAstro",
    "version": 2,
    "disclaimer": "Interpretive astrology compiled from the ebook library (Charak, Braha, Sutton, Levacy, DiCara, Houlding, Rushman, Tompkins, Sakoian, Stellas). Not medical, legal, or financial advice. Two techniques must agree before an event is called likely. Confidence caps at 75.",
    "accuracy": {
        "positions": "Meeus/Kepler natal-grade, Lahiri ayanamsa",
        "events": "rule coverage from the library, never scientific certainty",
        "two_technique_rule": "dasha promise AND gochara/transit timing",
    },
    "sade_sati_houses_from_moon": [12, 1, 2],
    "ashtama_shani_house_from_moon": 8,
    "sources": sources,
    "houses": houses,
    "dasha": dasha,
    "gochara_saturn_from_moon": saturn_from_moon,
    "gochara_jupiter_from_moon": jupiter_from_moon,
    "gochara_mars_from_lagna": mars_from_lagna,
    "nakshatra_tone": nak,
    "event_keys": event_keys,
    "ketu_ad_forbidden": ["marriage stamp", "company incorporation", "pregnancy-as-plan", "leveraged speculation"],
    "rahu_lagna_caution": "Identity restlessness and foreign pull. Do not emigrate, operate, or tattoo a new self on a mood.",
    "western_outers": {
        "Saturn": "Duty, delay, mastery — event when on angles or luminaries (Rushman).",
        "Uranus": "Rupture, invention — possible, not required.",
        "Neptune": "Fog, leak, mysticism — do not sign.",
        "Pluto": "Purge, power — long chapter.",
        "Jupiter": "Opportunity; confirm with natal 7th/10th promise.",
    },
    "saturn_upachaya_from_moon": [3, 6, 11],
    "dasa_chidra": "Last tenth of a mahadasha is dasa chidra (Levacy): do not launch a new life on the leftover of an old chapter.",
    "gochara_rahu_from_moon": {
        "1": "Identity hunger, foreign pull, restlessness. Do not emigrate on a mood.",
        "5": "Unconventional romance/speculation. High voltage, low contract.",
        "7": "Unusual partner or foreign alliance. Timing still needs dasha of 7th/Venus.",
        "8": "Obsession, hidden deals, research rabbit-holes.",
        "11": "Networks, scale, unconventional gains.",
        "12": "Exile, visa fog, sleep leak.",
    },
    "gochara_ketu_from_moon": {
        "1": "Cutting the persona. Spiritual reset, not a rebrand stunt.",
        "5": "Romance/children thin or spiritualize. No pregnancy-as-plan.",
        "7": "Detachment from the other. Do not solemnize.",
        "10": "Career role-shedding. Finish, do not incorporate.",
    },
    "saturn_best_from_moon": "Levacy: Saturn gives better results transiting 3, 6, 11 from Moon (effort, work, gains).",
    "jupiter_aspect_on_saturn": "A favourable Jupiter aspect on transiting Saturn reduces the toll (Levacy).",
    "vedha": {
        "Sun": {"benefic": [3, 6, 10, 11], "vedha": [9, 12, 4, 5]},
        "Moon": {"benefic": [1, 3, 6, 7, 10, 11], "vedha": [5, 9, 12, 2, 4, 8]},
        "Mars": {"benefic": [3, 6, 11], "vedha": [12, 9, 5]},
        "Mercury": {"benefic": [2, 4, 6, 8, 10, 11], "vedha": [5, 3, 9, 1, 8, 12]},
        "Jupiter": {"benefic": [2, 5, 7, 9, 11], "vedha": [12, 4, 3, 10, 8]},
        "Venus": {"benefic": [1, 2, 3, 4, 5, 8, 9, 11, 12], "vedha": [8, 7, 1, 10, 9, 5, 11, 3, 6]},
        "Saturn": {"benefic": [3, 6, 11], "vedha": [12, 9, 5]},
        "Rahu": {"benefic": [3, 6, 11], "vedha": [12, 9, 5]},
        "Ketu": {"benefic": [3, 6, 11], "vedha": [12, 9, 5]},
        "note": "Charak XXIX: a graha in the matching vedha house from the Moon cancels that benefic gochara, and equally blocks the adverse result of a transit over a vedha house. Sun/Saturn and Moon/Mercury do not cause vedha to each other.",
    },
    "kantaka_shani_house_from_moon": 4,
    "vargas": {
        "D9": "Navamsa colours dasha quality and marriage (Braha / Levacy ch.10). Fallen in D9 mixed even if exalted in D1.",
        "D10": "Dashamsa colours career/purpose (Levacy).",
        "D7": "Saptamsa for children — not yet a runtime clock.",
    },
    "ashtakoota_asset": "assets/kb/ashtakoota.json",
    "yogas_runtime": ["Gaja Kesari", "Yogakaraka kendra-trikona lord", "exalt/debil", "vargottama lagna"],
    "not_yet_runtime": [
        "Varshaphala / solar-return year chart (tables present in panchanga.json, no runtime clock)",
        "Secondary progressed Moon as a computed timer",
        "Shadbala as a computed number (components documented in strength.json)",
        "Jaimini chara dasha as a second clock",
        "Prashna / horary",
    ],
    "modules": {
        "planets": "assets/kb/planets.json",
        "houses": "assets/kb/houses.json",
        "nakshatras": "assets/kb/nakshatras.json",
        "yogas": "assets/kb/yogas.json",
        "doshas": "assets/kb/doshas.json",
        "dashas": "assets/kb/dashas.json",
        "transits": "assets/kb/transits.json",
        "ashtakavarga": "assets/kb/ashtakavarga.json",
        "strength": "assets/kb/strength.json",
        "divisionals": "assets/kb/divisionals.json",
        "panchanga": "assets/kb/panchanga.json",
        "remedies": "assets/kb/remedies.json",
        "interpretation": "assets/kb/interpretation.json",
        "degrees": "assets/kb/degrees.json",
        "matching": "assets/kb/ashtakoota.json",
    },
}

# ---------------------------------------------------------------------------
# Merge the module KBs compiled by knowledge/build/*.py.
# prediction.json stays the entry point: it carries the runtime shortcuts the
# forecast engine reads directly, and points at the modules for the rest.
# ---------------------------------------------------------------------------
KB_DIR = ROOT / "assets/kb"


def _load(name):
    path = KB_DIR / name
    return json.loads(path.read_text()) if path.exists() else None


transits = _load("transits.json")
if transits:
    res = transits["results_from_moon"]
    kb["gochara_from_moon"] = res
    # Keep the legacy per-graha keys the engine already reads, now complete.
    kb["gochara_sun_from_moon"] = res["Sun"]
    kb["gochara_moon_from_moon"] = res["Moon"]
    kb["gochara_mars_from_moon"] = res["Mars"]
    kb["gochara_mercury_from_moon"] = res["Mercury"]
    kb["gochara_venus_from_moon"] = res["Venus"]
    kb["gochara_rahu_from_moon"] = res["Rahu"]
    kb["gochara_ketu_from_moon"] = res["Ketu"]
    kb["benefic_transit_houses_from_moon"] = transits["benefic_houses_from_moon"]
    kb["transit_timing_within_sign"] = transits["timing_within_sign"]
    kb["transit_modifiers"] = transits["modifiers"]
    kb["returns"] = transits["returns"]
    kb["planetary_maturity_ages"] = transits["planetary_maturity_ages"]

interp = _load("interpretation.json")
if interp:
    # event_keys stays backward-compatible in shape; every topic now has an entry.
    for t in interp["topics"]:
        kb["event_keys"][t["key"]] = {
            "dasha_planets": [p for p in t["dasha_planets"] if p in (
                "Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn", "Rahu", "Ketu")],
            "houses": t["houses"],
            "jupiter_gochara_houses_from_lagna": t["jupiter_gochara_houses_from_lagna"],
            "jupiter_gochara_houses_from_moon": t["jupiter_gochara_houses_from_moon"],
            "saturn_supportive_houses_from_moon": t["saturn_supportive_houses_from_moon"],
            "avoid_ad": t["avoid_ad"],
            "negations": t["negations"]["factors"],
            "varga": t["varga"],
            "karakas": t["karakas"],
            "evidence": t["evidence"],
            "language": t["language"],
            "western": t["western"],
            "title": t["title"],
        }
    kb["order_of_judgment"] = interp["order_of_judgment"]
    kb["two_technique_rule_detail"] = interp["two_technique_rule"]
    kb["confidence_model"] = interp["confidence_model"]
    kb["window_rules"] = interp["window_rules"]
    kb["refusals"] = interp["refusals"]
    kb["delivery_rules"] = interp["delivery_rules"]
    kb["birth_time_policy"] = interp["birth_time"]

av = _load("ashtakavarga.json")
if av:
    kb["ashtakavarga"] = {
        "asset": "assets/kb/ashtakavarga.json",
        "implementation": "lib/engine/ashtakavarga.dart",
        "sarva_average": av["sarva"]["average_per_sign"],
        "sarva_total": av["sarva_total"],
        "bhinna_transit_threshold": av["bhinna_transit_threshold"],
        "bhinna_mixed_at": av["bhinna_mixed_at"],
        "transit_rule": av["transit_rule"],
        "computed": [
            "seven bhinnashtakavargas with their prastara (which contributor gave each bindu)",
            "sarvashtakavarga by sign and by house",
            "kakshya of a transiting graha, and the 0-7 day grade",
            "transit verdict: delivers / mixed / withholds",
            "the sarvashtakavarga house comparisons",
            "the dignity override, where bindus and dignity disagree",
        ],
        "not_computed": {
            "trikona_and_ekadhipatya_shodhana": (
                "Deliberately absent. The reductions are not in the extracted corpus "
                "(Charak XXX calls the elaborate parts out of scope), and their main "
                "classical use is Ayurdaya, which PocketAstro refuses."
            ),
        },
        "gating_rule": (
            "A transit that lands on the right house but holds fewer than four bindus "
            "does not count as a confirming technique. That is a veto, not a confidence "
            "tweak, and it is applied before the two-technique rule is evaluated."
        ),
        "requires_birth_time": (
            "The lagna is one of the eight contributors, so ashtakavarga is withheld "
            "entirely without a birth time rather than computed from seven."
        ),
    }

dashas = _load("dashas.json")
if dashas:
    kb["dasha_judgment_rules"] = dashas["judgment_rules"]
    kb["dasha_sandhi"] = dashas["dasha_sandhi"]
    kb["ketu_antardasha_caution"] = dashas["ketu_antardasha_caution"]
    for lord, row in dashas["mahadasha"].items():
        if lord in kb["dasha"]:
            kb["dasha"][lord]["favourable"] = row["favourable"]
            kb["dasha"][lord]["adverse"] = row["adverse"]
            kb["dasha"][lord]["body"] = row["body"]
            kb["dasha"][lord]["themes"] = row["themes"]
            kb["dasha"][lord]["years"] = row["years"]

yogas = _load("yogas.json")
if yogas:
    # Every catalogued yoga is evaluated at runtime by lib/engine/yoga.dart;
    # test/yoga_test.dart proves each one fires on a chart built to its
    # classical definition.
    kb["yogas_runtime"] = [y["name"] for y in yogas["yogas"]]
    kb["yogas_runtime_count"] = len(yogas["yogas"])
    kb["yoga_judgment_rules"] = yogas["judgment_rules"]
    kb["yoga_evaluator"] = {
        "asset": "assets/kb/yogas.json",
        "implementation": "lib/engine/yoga.dart",
        "coverage": "all catalogued yogas evaluate; see test/yoga_test.dart",
        "cancellations_in_code": sorted(
            y["id"] for y in yogas["yogas"] if y.get("cancellation_checks")
        ),
        "precedence": (
            "Charak XX: an Aakriti or Dala yoga supersedes an Aashraya yoga, and "
            "both supersede a Sankhya yoga. Gola is the exception and cancels the "
            "Aashraya yoga instead."
        ),
        "reporting": (
            "A cancelled or superseded yoga is still reported, with the reason. "
            "Kemadruma, Shakata and Kala Sarpa are the three most over-sold "
            "combinations in popular astrology and must never be silently dropped "
            "or silently asserted."
        ),
    }

doshas = _load("doshas.json")
if doshas:
    kb["dosha_delivery_protocol"] = doshas["delivery_protocol"]
    kb["doshas_indexed"] = [d["id"] for d in doshas["doshas"]]

nak = _load("nakshatras.json")
if nak:
    kb["gandanta"] = nak["gandanta"]
    kb["gandmool"] = nak["gandmool"]
    kb["abhijit"] = nak["abhijit"]

out_assets = ROOT / "assets/kb/prediction.json"
out_know = ROOT / "knowledge/extract/prediction.json"
text = json.dumps(kb, ensure_ascii=False, indent=2)
out_assets.write_text(text)
out_know.write_text(text)
print("wrote", out_assets, "chars", len(text), "sources", len(sources))

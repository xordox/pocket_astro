#!/usr/bin/env python3
"""Yoga catalogue with machine-checkable conditions.

Sources: Charak, Elements of Vedic Astrology, ch. XX (Nabhasa yogas),
XXI (yogas from house ownership: raja, dhana, arishta, parivartana) and
XXII (pancha-mahapurusha, chandra, ravi and miscellaneous yogas);
Sutton, The Essentials of Vedic Astrology (the yogas); Braha.

Condition vocabulary (the runtime evaluates these):
  kendra_from            {a, b}                planet a in 1/4/7/10 from planet b
  house_from             {a, b, houses}        planet a in one of `houses` from b
  dignified_in_kendra    {planet}              exalted or own sign AND in a kendra from lagna
  occupied_from          {from, houses, exclude, min}   count of grahas in those houses from `from`
  empty_from             {from, houses, exclude}        those houses from `from` are empty
  lords_related          {a_houses, b_houses}  a lord of any a_house related to a lord of any b_house
                                               (conjunction, mutual aspect, exchange, or one in the
                                               other's sign aspected by it)
  lord_in_houses         {lord_of, houses}     lord of house X sits in one of `houses`
  planet_in_houses       {planet, houses}
  planet_in_house_from_lagna {planet, houses}
  all_in_modes           {modes}               all seven grahas in signs of these modes
  all_in_houses          {houses}              all seven grahas confined to these houses
  contiguous_houses      {start, span}         seven grahas fill `span` contiguous houses from `start`
  distinct_sign_count    {n}                   the seven grahas occupy exactly n signs
  benefics_in_houses     {houses, all}         natural benefics occupy those houses
  malefics_in_houses     {houses, all}
  debilitated            {planet}
  exchange               {a_house, b_house}    lords of a_house and b_house exchange signs
  aspected_by            {target, by}
  conjunct               {a, b}
  same_house             {planets}
  node_axis_hemmed       {}                    all seven grahas between Rahu and Ketu

Shared modifiers:
  from                  "lagna" | a graha name; houses are counted from there
  mode                  "all_benefics_within" (every graha in the pool sits in
                        the listed houses) | "each_house_occupied" (each listed
                        house holds at least one)
  planets               restricts the pool to these grahas, where the classics
                        name them (Charak's Adhi yoga is Mercury/Jupiter/Venus)
  no_malefics           the listed houses must hold no natural malefic
  all_in_kendras        the seven grahas must also fill the four kendras
  start_any_of          contiguous_houses may begin at any of these houses

Derived per yoga (added below, read by lib/engine/yoga.dart):
  requires_lagna        true when the yoga cannot be judged without a birth time
  precedence            Nabhasa group rank: aakriti/dala 3 > aashraya 2 > sankhya 1
  cancellation_checks   ids the evaluator tests in code, not just prints
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
Y = []


def y(id, name, category, effect, conditions, all_of=True, strength=None,
      cancellation=None, source="Charak XXII", weight=3, caution=None):
    Y.append({
        "id": id, "name": name, "category": category,
        "match": "all" if all_of else "any",
        "conditions": conditions,
        "effect": effect,
        "strength": strength,
        "cancellation": cancellation,
        "weight": weight,
        "caution": caution,
        "source": source,
    })


# ---------------- Pancha Mahapurusha ----------------
MAHA = [("ruchaka", "Ruchaka", "Mars",
         "Bold, physically capable, commanding. Competence in anything that requires force applied with skill — surgery, engineering, command, sport. Classically a leader of armies."),
        ("bhadra", "Bhadra", "Mercury",
         "Learned, articulate, commercially sharp; a scholar's intelligence attached to a practical trade."),
        ("hamsa", "Hamsa", "Jupiter",
         "Fair-dealing, principled, well regarded; a teacher's grace and a reputation that outlasts the career."),
        ("malavya", "Malavya", "Venus",
         "Graceful, attractive, comfortable; art, taste and partnership all favoured. Wealth arrives through what is beautiful or enjoyable."),
        ("shasha", "Shasha", "Saturn",
         "Authority over people and resources; mass appeal, endurance, hard leadership. Rises late and holds.")]
for pid, pname, planet, eff in MAHA:
    y(pid, f"{pname} Yoga", "pancha_mahapurusha", eff,
      [{"type": "dignified_in_kendra", "planet": planet}],
      strength="Full results require a strong Sun and Moon as well; otherwise it gives good but ordinary results, mainly in that planet's dasha.",
      cancellation="Combustion, or the planet being aspected only by malefics, blunts the yoga. Confirm in the D9.",
      weight=5)

# ---------------- Chandra yogas ----------------
y("sunapha", "Sunapha Yoga", "chandra",
  "Status and self-earned wealth; the mind has support on the leading side. The exact flavour follows whichever graha sits in the 2nd from the Moon.",
  [{"type": "occupied_from", "from": "Moon", "houses": [2], "exclude": ["Sun", "Rahu", "Ketu"], "min": 1}],
  strength="Depends on the strength of the Moon and of the occupying graha.", weight=3)
y("anapha", "Anapha Yoga", "chandra",
  "Health, good name, eloquence and enjoyment. Where Sunapha accumulates, Anapha spends and enjoys.",
  [{"type": "occupied_from", "from": "Moon", "houses": [12], "exclude": ["Sun", "Rahu", "Ketu"], "min": 1}],
  weight=3)
y("durudhara", "Durudhara Yoga", "chandra",
  "Both possession and enjoyment — wealth, vehicles, help, and freedom from enemies. The Moon is supported on both sides.",
  [{"type": "occupied_from", "from": "Moon", "houses": [2], "exclude": ["Sun", "Rahu", "Ketu"], "min": 1},
   {"type": "occupied_from", "from": "Moon", "houses": [12], "exclude": ["Sun", "Rahu", "Ketu"], "min": 1}],
  strength="Formed by benefics it is strongly auspicious; formed by malefics it constricts the Moon and gives the opposite.",
  weight=4)
y("kemadruma", "Kemadruma Yoga", "chandra",
  "The Moon stands unsupported: the 2nd and 12th from it are both empty. Classically read as isolation, instability of mind and money, and the erosion of otherwise good raja yogas. In practice: the mind has no buffer, so everything lands directly.",
  [{"type": "empty_from", "from": "Moon", "houses": [2, 12],
    "exclude": ["Sun", "Rahu", "Ketu"]}],
  cancellation=("Cancelled if grahas occupy kendras from the lagna, or kendras from the Moon, "
                "or if all grahas aspect the Moon, or if a strong Moon sits in a kendra with or "
                "aspected by Mercury, Jupiter or Venus. Kemadruma is cancelled far more often than it stands."),
  caution="Never deliver Kemadruma as a verdict without checking all four cancellations first.",
  weight=4)
y("adhi", "Adhi Yoga", "chandra",
  "Benefics in the 6th, 7th and 8th from the Moon: high standing, command of people, good health and prosperity.",
  [{"type": "benefics_in_houses", "from": "Moon", "houses": [6, 7, 8],
    "planets": ["Mercury", "Jupiter", "Venus"],
    "mode": "all_benefics_within", "no_malefics": True}],
  cancellation="Malefics in those houses spoil it.", weight=5)
y("chandra_dhana", "Chandra Dhana Yoga", "chandra",
  "All three natural benefics in upachaya houses (3, 6, 10, 11) from the Moon: great wealth. Two of them gives medium wealth, one gives ordinary wealth.",
  [{"type": "benefics_in_houses", "from": "Moon", "houses": [3, 6, 10, 11],
    "planets": ["Mercury", "Jupiter", "Venus"],
    "mode": "all_benefics_within"}], weight=4)
y("gaja_kesari", "Gaja Kesari Yoga", "chandra",
  "Jupiter in a kendra from the Moon: standing, learning, virtue and lasting fame. Extremely common — read it judiciously rather than as a headline.",
  [{"type": "kendra_from", "a": "Jupiter", "b": "Moon"}],
  strength=("Fructifies only if Jupiter is not combust and is aspected by or joined to benefics, "
            "and if the Moon is neither combust nor debilitated. The best form has both in Cancer."),
  weight=3)
y("shakata", "Shakata Yoga", "chandra",
  "Jupiter in the 6th, 8th or 12th from the Moon while not itself in a kendra from lagna: fortunes that rise and fall like a cartwheel, with sustained effort behind each rise.",
  [{"type": "house_from", "a": "Jupiter", "b": "Moon", "houses": [6, 8, 12]},
   {"type": "planet_in_house_from_lagna", "planet": "Jupiter", "houses": [2, 3, 5, 6, 8, 9, 11, 12]}],
  cancellation="If both Jupiter and the Moon are strong (own sign, moolatrikona or exalted) the yoga is largely inoperative. Jupiter in the 6th, 7th or 8th from the Moon can equally form Adhi yoga.",
  caution="Do not deliver Shakata as a life sentence; Nehru had it.", weight=2)

# ---------------- Ravi yogas ----------------
y("veshi", "Veshi Yoga", "ravi",
  "A graha other than the Moon in the 2nd from the Sun: a balanced, truthful outlook. Benefics make it eloquent and prosperous; malefics coarsen it.",
  [{"type": "occupied_from", "from": "Sun", "houses": [2], "exclude": ["Moon", "Rahu", "Ketu"], "min": 1}], weight=2)
y("voshi", "Voshi Yoga", "ravi",
  "A graha other than the Moon in the 12th from the Sun: learning, memory, charity. Benefics make it scientific and wealthy.",
  [{"type": "occupied_from", "from": "Sun", "houses": [12], "exclude": ["Moon", "Rahu", "Ketu"], "min": 1}], weight=2)
y("ubhayachari", "Ubhayachari Yoga", "ravi",
  "Grahas other than the Moon on both sides of the Sun: physical strength, capacity for responsibility, learning and comfort.",
  [{"type": "occupied_from", "from": "Sun", "houses": [2], "exclude": ["Moon", "Rahu", "Ketu"], "min": 1},
   {"type": "occupied_from", "from": "Sun", "houses": [12], "exclude": ["Moon", "Rahu", "Ketu"], "min": 1}], weight=3)
y("budhaditya", "Budhaditya Yoga", "ravi",
  "Sun and Mercury together: a sharp, articulate, administratively capable intelligence.",
  [{"type": "conjunct", "a": "Sun", "b": "Mercury"}],
  strength="Weakened if Mercury is deeply combust (within about 3°); at that distance the intelligence is there but rarely heard.",
  weight=3, source="Parashara; Braha")

# ---------------- Raja yogas ----------------
y("raja_kendra_trikona", "Raja Yoga (kendra–trikona)", "raja",
  "A kendra lord and a trikona lord related by conjunction, mutual aspect, exchange, or one sitting in the other's sign under its aspect. This is the core elevation combination of the chart: standing, authority and recognised position.",
  [{"type": "lords_related", "a_houses": [1, 4, 7, 10], "b_houses": [1, 5, 9]}],
  strength=("Manifests fully when the planets involved are strong and in benefic houses. "
            "The 9th–10th pairing and any pairing involving the lagna lord with the 9th, 10th, 4th or 5th "
            "lord are the most productive. Weak or dusthana-placed constituents give the yoga with obstruction."),
  weight=6, source="Charak XXI")
y("raja_5_9", "Dharma–Karmadhipati / 5th–9th Raja Yoga", "raja",
  "The 5th and 9th lords conjunct or in mutual aspect. Classically kingship; in a modern chart, senior standing, and unusually good luck through merit already earned.",
  [{"type": "lords_related", "a_houses": [5], "b_houses": [9]}], weight=6, source="Charak XXI")
y("raja_9_10", "Dharma–Karmadhipati Yoga (9th–10th)", "raja",
  "The 9th and 10th lords related: fortune and career reinforce each other. The single most reliable raja yoga for professional standing.",
  [{"type": "lords_related", "a_houses": [9], "b_houses": [10]}], weight=6, source="Charak XXI")
y("raja_4_10_exchange", "4th–10th Exchange Raja Yoga", "raja",
  "Exchange between the 4th and 10th lords, supported by the 5th or 9th lord: high official position.",
  [{"type": "exchange", "a_house": 4, "b_house": 10}], weight=5, source="Charak XXI")
y("vipreeta_harsha", "Harsha Yoga (vipreeta raja)", "vipreeta",
  "The 6th lord in the 8th or 12th: opposition, debt and illness turn on themselves. Rise through other people's difficulties, and unusual resilience.",
  [{"type": "lord_in_houses", "lord_of": 6, "houses": [8, 12]}], weight=4, source="Charak XXI")
y("vipreeta_sarala", "Sarala Yoga (vipreeta raja)", "vipreeta",
  "The 8th lord in the 6th or 12th: longevity supported, crises defanged, fearlessness in the face of upheaval.",
  [{"type": "lord_in_houses", "lord_of": 8, "houses": [6, 12]}], weight=4, source="Charak XXI")
y("vipreeta_vimala", "Vimala Yoga (vipreeta raja)", "vipreeta",
  "The 12th lord in the 6th or 8th: expenditure cancels debt; independent, frugal, well-regarded for conduct.",
  [{"type": "lord_in_houses", "lord_of": 12, "houses": [6, 8]}], weight=4, source="Charak XXI")
y("neecha_bhanga", "Neecha Bhanga Raja Yoga", "raja",
  "A debilitated planet whose debilitation is cancelled. What looked like a weakness becomes the engine of a rise, usually mid-life and usually after a public failure in that planet's domain.",
  [{"type": "neecha_bhanga"}],
  strength=("Cancellation obtains when the debilitation-sign lord, or the exaltation-sign lord of the "
            "debilitated planet, sits in a kendra from lagna or Moon; or when either of those lords "
            "joins or aspects the debilitated planet; or when the debilitated planet exchanges signs "
            "with its debilitation lord; or when two debilitated planets aspect each other."),
  weight=5, source="Charak XXII")

# ---------------- Dhana yogas ----------------
y("dhana_core", "Dhana Yoga", "dhana",
  "A relationship between any of the wealth lords — 1st, 2nd, 5th, 9th, 11th. Money is structurally available; the dasha decides when.",
  [{"type": "lords_related", "a_houses": [1, 2, 5, 9, 11], "b_houses": [1, 2, 5, 9, 11], "distinct": True}],
  strength="Requires a strong lagna and lagna lord to manifest. Without those, the yoga describes money that passes through rather than money that stays.",
  weight=5, source="Charak XXI")
y("dhana_2_11", "2nd–11th Dhana Yoga", "dhana",
  "The lords of savings and of income related: earning and keeping are joined. The most direct money yoga in the chart.",
  [{"type": "lords_related", "a_houses": [2], "b_houses": [11]}], weight=5, source="Charak XXI")
y("chandra_mangala", "Chandra–Mangala Yoga", "dhana",
  "Moon and Mars conjunct or in mutual aspect: money made through drive, property or trade. Classically a strong financial combination; it also makes the temper commercial.",
  [{"type": "lords_related_planets", "a": "Moon", "b": "Mars"}], weight=4, source="Charak XXI/XXII")
y("lakshmi", "Lakshmi Yoga", "dhana",
  "A strong lagna lord with the 9th lord in a kendra in its own sign, moolatrikona or exaltation: durable wealth, standing and good name.",
  [{"type": "lord_dignified_in_kendra", "lord_of": 9}], weight=5, source="Charak XXII")
y("amala", "Amala (Amala-Kirti) Yoga", "dhana",
  "A natural benefic in the 10th from lagna or from the Moon: a clean professional reputation that outlasts any single job.",
  [{"type": "benefic_in_house", "from": "lagna", "house": 10},
   {"type": "benefic_in_house", "from": "Moon", "house": 10}], all_of=False, weight=4, source="Charak XXII")

# ---------------- Kartari / structural ----------------
y("shubha_kartari", "Shubha Kartari Yoga", "structural",
  "Natural benefics in the 2nd and 12th from lagna: the self is protected on both sides — health, resources and standing all supported.",
  [{"type": "benefics_in_houses", "from": "lagna", "houses": [2, 12],
    "mode": "each_house_occupied"}], weight=4)
y("papa_kartari", "Papa Kartari Yoga", "structural",
  "Natural malefics in the 2nd and 12th from lagna: the self is hemmed. Read as constraint and pressure on the body, resources and freedom of movement — not as a moral verdict.",
  [{"type": "malefics_in_houses", "from": "lagna", "houses": [2, 12],
    "mode": "each_house_occupied"}],
  caution="A hemmed lagna is a health and stress flag, not a character judgment.", weight=3)
y("parvata", "Parvata Yoga", "structural",
  "Benefics in kendras with the 6th and 8th empty or benefic-only; or the lagna lord and 12th lord in mutual kendras under benefic aspect. Fame, wealth, generosity and leadership.",
  [{"type": "benefics_in_kendras", "count": 2},
   {"type": "houses_empty_or_benefic", "houses": [6, 8]}], weight=4)
y("chamara", "Chaamara Yoga", "structural",
  "An exalted lagna lord in a kendra aspected by Jupiter, or two benefics joined in the 1st, 7th, 9th or 10th: eloquence, skill and honour from authority.",
  [{"type": "lord_exalted_in_kendra_aspected_by", "lord_of": 1, "by": "Jupiter"}], all_of=False, weight=4)
y("chatussagara", "Chatussagara Yoga", "structural",
  "All seven grahas in the four kendras, or all in movable signs: many arishta yogas are destroyed; wealth and high status follow.",
  [{"type": "all_in_houses", "houses": [1, 4, 7, 10]},
   {"type": "all_in_modes", "modes": ["movable"]}], all_of=False, weight=5)
y("maha_bhagya", "Maha Bhagya Yoga", "structural",
  "For a day birth: odd lagna, odd Sun sign, odd Moon sign. For a night birth: even lagna, even Sun sign, even Moon sign. A highly fortunate pattern — good character, standing and resources.",
  [{"type": "maha_bhagya"}], weight=5)
y("vargottama", "Vargottama", "structural",
  "A graha (or the lagna) in the same sign in D1 and D9. Whatever that graha signifies is confirmed rather than promised — it delivers what it says.",
  [{"type": "vargottama", "planet": "any"}], weight=4, source="Parashara; Sutton (vargas)")
y("parivartana_maha", "Maha Parivartana Yoga", "parivartana",
  "An exchange of signs between the lords of the 1st, 2nd, 4th, 5th, 7th, 9th, 10th or 11th. The two matters become one machine — each feeds the other. Wealth, status and enjoyment.",
  [{"type": "exchange_between_sets", "houses": [1, 2, 4, 5, 7, 9, 10, 11]}], weight=5, source="Charak XXI (Mantreshwara)")
y("parivartana_dainya", "Dainya Parivartana Yoga", "parivartana",
  "An exchange involving the 6th, 8th or 12th lord with a good-house lord: the good house's matters are dragged through difficulty before they pay. Not denial — a toll.",
  [{"type": "exchange_with_trik"}],
  caution="Deliver as a route, not a refusal.", weight=3, source="Charak XXI")

# ---------------- Sanyasa / spiritual ----------------
y("pravrajya_kendra", "Pravrajya (Sanyasa) Yoga", "spiritual",
  "Four or more grahas together in one house, joined by the 10th lord, in a kendra or trikona: a life that turns away from ordinary acquisition toward practice, teaching or renunciation.",
  [{"type": "stellium_with_lord", "min": 4, "lord_of": 10, "houses": [1, 4, 5, 7, 9, 10]}], weight=4)
y("ketu_12_moksha", "Moksha Karaka placement", "spiritual",
  "Ketu in the 12th, or the 12th lord with Ketu or Jupiter: strong pull toward retreat, foreign life and practice. Read as design, not escape.",
  [{"type": "planet_in_houses", "planet": "Ketu", "houses": [12]}], all_of=False, weight=3, source="Sutton")

# ---------------- Arishta / difficulty ----------------
y("arishta_trik_link", "Arishta Yoga", "arishta",
  "A link between the lagna lord and a 6th, 8th or 12th lord, or between two trik lords. Health and stability need managing; other good yogas deliver less cleanly than their definitions promise.",
  [{"type": "lords_related", "a_houses": [1, 6, 8, 12], "b_houses": [6, 8, 12], "distinct": True}],
  caution="An arishta yoga is a maintenance flag. PocketAstro never converts it into a longevity or mortality claim.",
  weight=3, source="Charak XXI")
y("daridra_1_12", "Daridra Yoga (1st–12th exchange)", "arishta",
  "The lagna lord in the 12th and the 12th lord in the lagna, with maraka influence on either: resources drain as fast as they arrive. Fixable by design — expenditure discipline is the whole remedy.",
  [{"type": "exchange", "a_house": 1, "b_house": 12}], weight=3, source="Charak XXI")
y("kala_sarpa", "Kala Sarpa Yoga", "arishta",
  "All seven grahas hemmed between Rahu and Ketu. A life that runs on one axis: intense focus, delayed but concentrated results, and a sense of fate in whichever houses the nodes occupy.",
  [{"type": "node_axis_hemmed"}],
  cancellation="Partial (Kala Amrita) if one graha is just outside the axis. A graha conjunct a node breaks the yoga's force.",
  caution="Widely over-sold. Deliver it as a shape of life, never as a curse.", weight=3, source="Later classical; Sutton")
y("hatha_hanta", "Hatha-Hantaa Yoga", "arishta",
  "The Moon in the 11th with the Sun in Cancer: the classics warn of self-inflicted humiliation. Read it as a caution about impulsive, reputation-risking moves in pursuit of gain.",
  [{"type": "planet_in_house_from_lagna", "planet": "Moon", "houses": [11]},
   {"type": "planet_in_sign", "planet": "Sun", "sign": "Cancer"}], weight=2)

# ---------------- Nabhasa: Aashraya (3) ----------------
for nid, nname, mode, eff in [
    ("rajju", "Rajju Yoga", "movable", "All grahas in movable signs: fond of travel, drawn abroad, restless and hard to settle."),
    ("musala", "Musala Yoga", "fixed", "All grahas in fixed signs: learned, wealthy, proud, famous, stable of purpose."),
    ("nala", "Nala Yoga", "dual", "All grahas in dual signs: adaptable, very clever, attached to family; some physical asymmetry classically noted.")]:
    y(nid, nname, "nabhasa_aashraya", eff, [{"type": "all_in_modes", "modes": [mode]}], weight=3, source="Charak XX")

# ---------------- Nabhasa: Dala (2) ----------------
y("maala", "Maala (Srak) Yoga", "nabhasa_dala",
  "Benefics in three kendras with malefics outside them: constant enjoyment, vehicles, good living, pleasant company.",
  [{"type": "benefics_in_kendras", "count": 3}, {"type": "malefics_not_in_kendras"}], weight=3, source="Charak XX")
y("sarpa", "Sarpa Yoga", "nabhasa_dala",
  "Malefics in three kendras with benefics elsewhere: dependence, hardship and a struggle for autonomy. A structural difficulty, not a character flaw.",
  [{"type": "malefics_in_kendras", "count": 3}, {"type": "benefics_not_in_kendras"}], weight=3, source="Charak XX")

# ---------------- Nabhasa: Aakriti (20) ----------------
AKRITI = [
 ("gada", "Gada Yoga", {"type": "all_in_houses", "houses": "two_adjacent_kendras"},
  "All grahas in two adjacent kendras: wealthy, learned, permanently engaged in earning."),
 ("shakata_nabhasa", "Shakata Yoga (Aakriti)", {"type": "all_in_houses", "houses": [1, 7]},
  "All grahas in the 1st and 7th: health and money come only through hard labour; fortunes swing."),
 ("pakshi", "Pakshi (Vihaga) Yoga", {"type": "all_in_houses", "houses": [4, 10]},
  "All grahas in the 4th and 10th: a messenger's life — movement, errands, constant repositioning."),
 ("vajra", "Vajra Yoga", {"type": "benefics_malefics_split", "benefics": [1, 7], "malefics": [4, 10],
   "all_in_kendras": True},
  "Benefics in the 1st and 7th, malefics in the 4th and 10th: good looking, brave, happy in early life and in old age."),
 ("yava", "Yava Yoga", {"type": "benefics_malefics_split", "benefics": [4, 10], "malefics": [1, 7],
   "all_in_kendras": True},
  "Malefics in the 1st and 7th, benefics in the 4th and 10th: consistent and charitable; the middle of life is the good part."),
 ("kamala", "Kamala Yoga", {"type": "all_in_houses", "houses": [1, 4, 7, 10]},
  "All grahas in the four kendras: wide renown, long life, virtue and high standing. One of the strongest Nabhasa yogas."),
 ("vaapi", "Vaapi Yoga", {"type": "all_in_houses", "houses": [2, 3, 5, 6, 8, 9, 11, 12]},
  "All grahas outside the kendras: accumulates steadily, keeps what it gets, small but lasting comforts."),
 ("shringataka", "Shringataka Yoga", {"type": "all_in_houses", "houses": [1, 5, 9]},
  "All grahas in the trikonas: comfortable, combative when needed, wealthy."),
 ("hala", "Hala Yoga", {"type": "all_in_houses", "houses": "one_trinal_set_non_kendra"},
  "All grahas in one non-kendra trinal set (2/6/10, 3/7/11 or 4/8/12): a life of labour, often on the land or in service."),
 ("yoopa", "Yoopa Yoga", {"type": "contiguous_houses", "start": 1, "span": 4},
  "Grahas filling houses 1 to 4: self, resources, effort and home — dutiful, ritual-minded, valorous."),
 ("shara", "Shara Yoga", {"type": "contiguous_houses", "start": 4, "span": 4},
  "Grahas filling houses 4 to 7: sharp, hunting energy; works in enforcement, security or contest."),
 ("shakti", "Shakti Yoga", {"type": "contiguous_houses", "start": 7, "span": 4},
  "Grahas filling houses 7 to 10: long-lived and stable but tormented by failures; slow to profit."),
 ("danda", "Danda Yoga", {"type": "contiguous_houses", "start": 10, "span": 4},
  "Grahas filling houses 10 to 1: work, gain, loss and self — thin on comfort and on close ties."),
 ("nauka", "Nauka Yoga", {"type": "contiguous_houses", "start": 1, "span": 7},
  "Grahas filling houses 1 to 7: famous, ambitious, careful with money; earnings connected to water or to travel."),
 ("koota", "Koota Yoga", {"type": "contiguous_houses", "start": 4, "span": 7},
  "Grahas filling houses 4 to 10: guarded, fortress-minded, drawn to high or remote ground."),
 ("chhatra", "Chhatra Yoga", {"type": "contiguous_houses", "start": 7, "span": 7},
  "Grahas filling houses 7 to 1: kind, wise, long-lived; looks after dependents; comfortable at both ends of life."),
 ("chaapa", "Dhanusha (Chaapa) Yoga", {"type": "contiguous_houses", "start": 10, "span": 7},
  "Grahas filling houses 10 to 4: brave and mobile; the middle of life is the happiest part."),
 ("ardha_chandra", "Ardha-Chandra Yoga", {"type": "contiguous_houses", "start_any_of": [2, 3, 5, 6, 8, 9, 11, 12], "span": 7},
  "Seven grahas in seven contiguous houses starting from a non-kendra: a commander's yoga — good looks, courage, wealth and official honour."),
 ("chakra", "Chakra Yoga", {"type": "all_in_houses", "houses": [1, 3, 5, 7, 9, 11]},
  "Grahas in the six odd houses: royal standing, or its modern equivalent."),
 ("samudra", "Samudra Yoga", {"type": "all_in_houses", "houses": [2, 4, 6, 8, 10, 12]},
  "Grahas in the six even houses: wealthy, comfortable, likeable and steady of mind."),
]
for nid, nname, cond, eff in AKRITI:
    y(nid, nname, "nabhasa_aakriti", eff, [cond], weight=3, source="Charak XX")

# ---------------- Nabhasa: Sankhya (7) ----------------
SANKHYA = [(7, "veena", "Veena Yoga", "Grahas spread over seven signs: musical, skilful, wealthy, a natural leader."),
           (6, "daama", "Daama Yoga", "Grahas over six signs: liberal, renowned, wealthy, earns by legitimate means."),
           (5, "paasha", "Paasha Yoga", "Grahas over five signs: large household, adept at work, skilful at earning, blunt."),
           (4, "kedaara", "Kedaara Yoga", "Grahas over four signs: useful to many, truthful, wealthy; drawn to land."),
           (3, "shoola", "Shoola Yoga", "Grahas over three signs: concentrated, combative, scarred by conflict."),
           (2, "yuga", "Yuga Yoga", "Grahas over two signs: extreme concentration of life force; heterodox, socially at odds."),
           (1, "gola", "Gola Yoga", "All grahas in one sign: total concentration in one domain, at the cost of everything else.")]
for n, nid, nname, eff in SANKHYA:
    y(nid, nname, "nabhasa_sankhya", eff, [{"type": "distinct_sign_count", "n": n}], weight=2,
      source="Charak XX",
      cancellation="Sankhya yogas apply only when no Aakriti or Aashraya yoga is present. Kedaara, Shoola and Yuga are inoperative alongside an Aashraya yoga; Gola remains operative and cancels the Aashraya yoga instead.")


# ---------------------------------------------------------------------------
# Derived fields the runtime evaluator needs.
# ---------------------------------------------------------------------------

# Condition types that are measured from the lagna, so the yoga cannot be
# judged at all when the birth time is unknown.
LAGNA_BOUND = {
    "dignified_in_kendra", "lords_related", "lord_in_houses",
    "lord_dignified_in_kendra", "lord_exalted_in_kendra_aspected_by",
    "planet_in_houses", "planet_in_house_from_lagna", "all_in_houses",
    "contiguous_houses", "benefics_in_kendras", "malefics_in_kendras",
    "benefics_not_in_kendras", "malefics_not_in_kendras",
    "benefics_malefics_split", "houses_empty_or_benefic", "exchange",
    "exchange_between_sets", "exchange_with_trik", "stellium_with_lord",
    "maha_bhagya",
}


def _needs_lagna(y):
    """True when the yoga cannot be judged at all without a birth time.

    For an all-match yoga, one lagna-bound condition is enough. For an
    any-match yoga, every branch has to be lagna-bound before the whole yoga
    becomes unjudgeable.
    """
    bound = [c["type"] in LAGNA_BOUND or c.get("from") == "lagna"
             for c in y["conditions"]]
    return all(bound) if y["match"] == "any" else any(bound)


# Charak XX: an Aakriti yoga takes precedence over an Aashraya yoga, and both
# over a Sankhya yoga. Gola is the exception -- it survives and cancels the
# Aashraya yoga instead.
PRECEDENCE = {
    "nabhasa_aakriti": 3, "nabhasa_dala": 3,
    "nabhasa_aashraya": 2, "nabhasa_sankhya": 1,
}

# Cancellations the evaluator checks in code rather than only printing.
CANCELLATION_CHECKS = {
    "kemadruma": ["grahas_in_kendra_from_lagna", "grahas_in_kendra_from_moon",
                  "all_grahas_aspect_moon", "strong_moon_in_kendra_with_benefic"],
    "gaja_kesari": ["jupiter_combust", "moon_combust", "moon_debilitated",
                    "jupiter_without_benefic_support"],
    "shakata": ["jupiter_and_moon_both_strong"],
    "kala_sarpa": ["graha_conjunct_node", "graha_outside_axis"],
    "ruchaka": ["planet_combust", "only_malefic_aspects"],
    "bhadra": ["planet_combust", "only_malefic_aspects"],
    "hamsa": ["planet_combust", "only_malefic_aspects"],
    "malavya": ["planet_combust", "only_malefic_aspects"],
    "shasha": ["planet_combust", "only_malefic_aspects"],
    "adhi": ["malefic_in_adhi_houses"],
    "maala": ["malefic_in_kendra"],
    "sarpa": ["benefic_in_kendra"],
    "daridra_1_12": ["no_maraka_influence"],
    "papa_kartari": [],
}

for _y in Y:
    _y["requires_lagna"] = _needs_lagna(_y)
    _y["precedence"] = PRECEDENCE.get(_y["category"], 0)
    _y["cancellation_checks"] = CANCELLATION_CHECKS.get(_y["id"], [])

DOC = {
    "engine": "pocketastro-yogas",
    "version": 1,
    "sources": [
        "Charak, Elements of Vedic Astrology — ch. XX (Nabhasa), XXI (ownership yogas), XXII (specific yogas).",
        "Sutton, The Essentials of Vedic Astrology — The Yogas.",
        "Braha, Ancient Hindu Astrology for the Modern Western Astrologer.",
    ],
    "judgment_rules": [
        "A yoga is a promise, not an event. It delivers in the dasha or antardasha of the grahas that form it.",
        "Yoga-forming grahas must be strong and free of affliction for the yoga to manifest fully. Weak constituents give the yoga with struggle attached.",
        "Confirm every headline yoga in the relevant varga — D9 for character and marriage, D10 for career, D7 for children.",
        "A raja yoga formed by grahas sitting in dusthanas gives status through struggle and loses it more easily.",
        "Kemadruma, Shakata and Kala Sarpa are the three most over-delivered yogas in popular astrology. Check every cancellation before mentioning any of them.",
        "Aakriti yogas take precedence over Aashraya yogas; both take precedence over Sankhya yogas.",
        "Nabhasa yogas operate all life long and do not wait for a dasha.",
    ],
    "categories": sorted({v["category"] for v in Y}),
    "yogas": Y,
}

for out in (ROOT / "assets/kb/yogas.json", ROOT / "knowledge/extract/yogas.json"):
    out.write_text(json.dumps(DOC, indent=1, ensure_ascii=False) + "\n")
print("yogas.json", len(json.dumps(DOC)), "bytes,", len(Y), "yogas")

#!/usr/bin/env python3
"""Gochara runtime table: all nine grahas through all twelve houses from the
natal Moon (and from lagna), the complete vedha table, returns, retrogression,
eclipses and transits to natal points.

Sources: Charak, Elements of Vedic Astrology, ch. XXIX (Gochara) — benefic
transit houses, vedha positions and the twelve-house results, transcribed
directly; Levacy, Beneath a Vedic Sky ch. 14; Carol Rushman, The Art of
Predictive Astrology (the Western transit stack).
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# Charak XXIX: benefic transit houses paired with their vedha (obstruction) house.
VEDHA = {
 "Sun":     {3: 9, 6: 12, 10: 4, 11: 5},
 "Moon":    {1: 5, 3: 9, 6: 12, 7: 2, 10: 4, 11: 8},
 "Mars":    {3: 12, 6: 9, 11: 5},
 "Mercury": {2: 5, 4: 3, 6: 9, 8: 1, 10: 8, 11: 12},
 "Jupiter": {2: 12, 5: 4, 7: 3, 9: 10, 11: 8},
 "Venus":   {1: 8, 2: 7, 3: 1, 4: 10, 5: 9, 8: 5, 9: 11, 11: 3, 12: 6},
 "Saturn":  {3: 12, 6: 9, 11: 5},
 "Rahu":    {3: 12, 6: 9, 11: 5},
 "Ketu":    {3: 12, 6: 9, 11: 5},
}
BENEFIC_HOUSES = {p: sorted(v) for p, v in VEDHA.items()}

# Charak XXIX classical twelve-house results, restated without fatalism.
RESULTS = {
 "Sun": [
  "Vitality dips and travel begins. Do not schedule the confrontation here.",
  "Money goes out; speech costs more than it earns. Guard the budget and the tongue.",
  "Benefic house. Health and resources both improve; courage is available. Strong for launching self-directed work.",
  "Domestic strain and low energy. Home matters need attention rather than action.",
  "Mental pressure; strain around children or a creative venture. Poor for speculation.",
  "Benefic house. Opposition, debt and illness are all beatable now. Excellent for litigation and competitive work.",
  "Travel, and strain on the partner or partnership. Weak for signing.",
  "Reputation exposed; low vitality. Keep the profile low and the paperwork clean.",
  "Friction with father, teachers or institutions; morale low. Study rather than argue.",
  "Benefic house. Undertakings succeed; authority notices. The strongest Sun transit for career moves.",
  "Benefic house. Standing rises and gains arrive. Ask for the title now.",
  "Expenditure and low health. Rest; do not launch."],
 "Moon": [
  "Benefic house. Good fortune, visibility, emotional clarity on the day.",
  "Money leaks; family and food take focus.",
  "Benefic house. Victory in small contests; courage for the short move.",
  "Apprehension and domestic sensitivity. Stay home; do not decide.",
  "Low mood, romantic or creative strain. Poor for irreversible emotional moves.",
  "Benefic house. Freedom from illness; work goes well.",
  "Benefic house. Comfort through others; excellent for meetings and public dealings.",
  "Unexpected turns; emotional exposure. A poor day to be visible.",
  "Low health, restlessness; travel is unsatisfying.",
  "Benefic house. Undertakings succeed; the day's work lands.",
  "Benefic house. Gains and easy happiness. The best Moon transit of the cycle.",
  "Expenditure, tiredness, need for sleep. Withdraw deliberately."],
 "Mars": [
  "Mental torment and a short fuse. Do not send it.",
  "Resources drain; harsh speech costs money.",
  "Benefic house. Victory through effort; the best Mars transit for initiative and siblings.",
  "Displacement from home or workplace; friction over property.",
  "Mental anguish; strain around children or speculation. No leverage.",
  "Benefic house. Enemies, debt and illness all defeated. Surgery, litigation and competition favoured.",
  "Discord with the partner. Do not escalate at home.",
  "Sudden turns and accident-proneness. Slow everything physical down.",
  "Health and resources both under strain; friction with father or teachers.",
  "Obstacles and heavy physical exertion in the career.",
  "Benefic house. Gain of health and resources. Push the competitive move.",
  "Energy leaks; hidden opposition. Train, do not fight."],
 "Mercury": [
  "Resources drain through poor decisions; the mind is scattered.",
  "Benefic house. Gain through speech, trade and documents.",
  "Fear from opponents; communication misfires.",
  "Benefic house. Multiple gains through home, property and study.",
  "Discord with partner and children; poor for negotiation.",
  "Benefic house. Dominance over opponents; excellent for audits and legal work.",
  "Quarrels in partnership; contracts misread.",
  "Benefic house. Gain of resources, but watch health and nerves.",
  "Obstacles to undertakings; travel and study frustrated.",
  "Benefic house. All comforts; career communication lands.",
  "Benefic house. Multiple gains through networks and trade.",
  "Opponents on top; documents work against you. Reread everything."],
 "Jupiter": [
  "Displacement and expenditure. Jupiter over the Moon is famously mixed — growth that costs.",
  "Benefic house. Gain of resources; excellent for family money and study.",
  "Health dips; effort is unrewarded.",
  "Discord at home; opponents multiply.",
  "Benefic house. Happiness, and the classical window for the birth of a child.",
  "Trouble from opponents; debt expands rather than resolves.",
  "Benefic house. Comfort from partner and children; auspicious journeys. The classic marriage transit.",
  "Unwanted travel and loss of resources.",
  "Benefic house. Virtuous pursuits and many gains; the fortune transit.",
  "Apprehension about career; the profession feels stuck even when it is not.",
  "Benefic house. Acquisition of wealth and status. The strongest Jupiter transit of the cycle.",
  "Loss of resources; expenditure on good causes."],
 "Venus": [
  "Benefic house. Physical ease and pleasure.",
  "Benefic house. Inflow of resources.",
  "Benefic house. Varied gains through effort and communication.",
  "Benefic house. More friends; domestic comfort improves.",
  "Benefic house. Romance and creativity; classically the birth of a child.",
  "Misfortunes through indulgence; health of the reproductive and urinary system.",
  "Trouble to or from the partner. Poor for starting a relationship.",
  "Benefic house. Gain of health and resources through others' money.",
  "Benefic house. Varied comforts; good travel.",
  "Quarrels in the career; charm does not work here.",
  "Benefic house. Gain of wealth, with some apprehension attached.",
  "Benefic house. Acquisition of wealth; comfort found privately or abroad."],
 "Saturn": [
  "Sade Sati peak. Identity, body and duty all press. Structure the day; do not self-erase.",
  "Sade Sati closing phase. Delayed income, family duty, speech under weight. Save more than you display.",
  "Benefic house (upachaya). Rise in standing through effort; siblings and craft supported.",
  "Discord at home; property and mother need patient attention. Moves are slow and permanent.",
  "Strain around children and creativity; mental weight. No speculation.",
  "Benefic house (upachaya). Dominance over opponents, debt and illness through routine. The professional's transit.",
  "Difficult journeys and strain on the partner. Contracts get real; do not marry only to end loneliness.",
  "Ashtama Shani. Hidden tests, tax, elders' health, chronic worry. A toll on the dasha, not a deletion of yoga.",
  "Father, dharma and long travel delayed then made durable. Study and law take time.",
  "Obstacles in the career, and status through labour. Visibility must be maintained deliberately.",
  "Benefic house (upachaya). Steady inflow and serious allies. The best Saturn transit of the cycle.",
  "Sade Sati begins. Expenditure, isolation, foreign ground, sleep loss. Start the hygiene now."],
 "Rahu": [
  "Illness and disorientation; identity feels borrowed.",
  "Resources drain; speech and family under odd pressure.",
  "Benefic house (upachaya). Varied pleasures and productive boldness.",
  "Domestic unease; the home does not feel like one.",
  "Loss through speculation; strain around children.",
  "Benefic house (upachaya). Comfort through defeating opposition; good for competitive and foreign work.",
  "Humiliation in partnership; poor judgment about the other person.",
  "Serious health and crisis flag. Handle paperwork, tax and insurance.",
  "Losses; belief and father both feel unreliable.",
  "Comfort and visible ambition in the career.",
  "Benefic house (upachaya). Good fortune and large gains. The best Rahu transit.",
  "Excessive expenditure; foreign ground calls."],
 "Ketu": [
  "Self-doubt and detachment from the body.",
  "Resources and speech both cut back.",
  "Benefic house (upachaya). Quiet competence; effort without fuss.",
  "Home feels distant; withdraw rather than force.",
  "Detachment from children, romance and speculation. Strong for mantra practice.",
  "Benefic house (upachaya). Illness, debt and opposition are cut through. Good for diagnosis.",
  "Detachment inside partnership; do not read it as the end.",
  "Sudden endings and deep research capacity.",
  "Doubt about doctrine and teachers; direct experience replaces belief.",
  "Career held loosely; a good time to leave what is finished.",
  "Benefic house (upachaya). Gains arrive, then dissolve. Take them.",
  "Strong moksha pull. Retreat, research, foreign ground."],
}

DOC = {
 "engine": "pocketastro-transits",
 "version": 1,
 "sources": [
   "Charak, Elements of Vedic Astrology — ch. XXIX (Gochara): benefic houses, vedha table, twelve-house results.",
   "Levacy, Beneath a Vedic Sky — ch. 14 (transits).",
   "Carol Rushman, The Art of Predictive Astrology — the Western transit stack.",
 ],
 "primacy_rule": (
   "Transits are subservient to the natal chart and to the dasha. The chart carries the "
   "promise, the dasha unfolds it, the transit clinches the moment. A transit alone never "
   "creates an event the natal chart does not promise."
 ),
 "reference_point": (
   "Classically reckoned from the natal Moon (Janma Rashi). Charak notes that transits from "
   "the lagna work equally well and are more individualised. PocketAstro reads both and "
   "reports agreement between them as a confidence gain."
 ),
 "benefic_houses_from_moon": BENEFIC_HOUSES,
 "vedha": {
   "pairs": VEDHA,
   "rule": (
     "A graha's benefic transit house is cancelled if another graha occupies the paired "
     "vedha house at the same time. Vedha obstructs adverse results just as it obstructs "
     "benefic ones — a malefic transit over a vedha house is itself blocked when the paired "
     "benefic house is occupied."
   ),
   "exceptions": [
     "Sun and Saturn do not cause vedha to each other (the father-son pair).",
     "Moon and Mercury do not cause vedha to each other (the father-son pair).",
   ],
 },
 "results_from_moon": {p: {str(i + 1): RESULTS[p][i] for i in range(12)} for p in RESULTS},
 "timing_within_sign": {
   "Sun": "gives results immediately on entering the sign",
   "Mars": "gives results immediately on entering the sign",
   "Jupiter": "gives results in the middle of the sign",
   "Venus": "gives results in the middle of the sign",
   "Moon": "gives results in the final third of the sign",
   "Saturn": "gives results in the final third of the sign",
   "Mercury": "follows its dispositor and its speed; fastest when direct and swift",
 },
 "modifiers": [
   "A benefic transit house that is also the graha's debilitation or enemy sign gives foreshortened benefit.",
   "Debilitation coinciding with an adverse transit house gives the full adverse result.",
   "Transit through the graha's own or exaltation sign is favourable regardless of house.",
   "Malefic transits over natal malefics are particularly harmful; note the degree, not just the sign.",
   "Read the transit sign's ashtakavarga bindu count for that graha: 5+ bindus delivers, 0-3 withholds.",
   "The transiting Moon clinches the day an event occurs; the slow grahas set the season.",
 ],
 "sade_sati": {
   "houses_from_moon": [12, 1, 2],
   "duration_years": 7.5,
   "phases": {"12": "rising", "1": "peak", "2": "setting"},
   "note": "Also read the two 'small panotis': Saturn in the 4th and in the 8th from the Moon, of about 2.5 years each.",
 },
 "ashtama_shani": {"house_from_moon": 8, "duration_years": 2.5},
 "kantaka_shani": {"house_from_moon": 4, "duration_years": 2.5,
                   "note": "Ardha-ashtama / kantaka shani: domestic and health pressure, a smaller version of the 8th."},
 "saturn_upachaya": [3, 6, 11],
 "returns": {
   "saturn_return": {"age_years": [29.5, 59, 88], "meaning":
     "Saturn returns to its natal sign: the structure of the life is audited. What is real is kept; what was borrowed is repossessed."},
   "jupiter_return": {"age_years": [12, 24, 36, 48, 60, 72, 84], "meaning":
     "Jupiter returns to its natal sign every ~12 years: a new chapter of growth, faith and opportunity opens."},
   "rahu_ketu_return": {"age_years": [18.6, 37.2, 55.8, 74.4], "meaning":
     "The nodal axis returns every ~18.6 years: the same karmic theme reappears with more resources to meet it."},
   "nodal_reversal": {"age_years": [9.3, 27.9, 46.5, 65.1], "meaning":
     "The nodes reach the opposite of their natal position: the axis flips and the compensating side of the life demands attention."},
 },
 "planetary_maturity_ages": {
   "Sun": 22, "Moon": 24, "Mars": 28, "Mercury": 32, "Jupiter": 16,
   "Venus": 25, "Saturn": 36, "Rahu": 42, "Ketu": 48,
   "note": "A graha's promised results consolidate from its maturity age onward. Before that age it works in draft.",
 },
 "retrograde": {
   "rule": "A retrograde graha in transit revisits the same degrees three times: first pass raises the matter, retrograde pass renegotiates it, direct pass settles it.",
   "vedic_note": "Classically a retrograde graha gains cheshta bala (motional strength) and delivers its results more forcefully, not more weakly.",
   "practice": "Do not sign or launch during the retrograde pass of the graha that owns the relevant house. Wait for the direct station plus a few days.",
   "never_retrograde": ["Sun", "Moon"],
   "always_retrograde_mean": ["Rahu", "Ketu"],
 },
 "combustion_transit": (
   "A graha combust in transit withholds its transit result until it separates from the Sun. "
   "Check combustion before calling any transit window."
 ),
 "eclipses": {
   "rule": "An eclipse within about 12° of a natal graha or angle activates that point for the following six months.",
   "solar": "Solar eclipse: the matter of the affected house restarts, usually through an external decision.",
   "lunar": "Lunar eclipse: the matter of the affected house culminates or ends.",
   "caution": "PocketAstro never predicts harm from an eclipse. It is a timing marker, nothing more.",
 },
 "western_stack": {
   "source": "Rushman, The Art of Predictive Astrology",
   "orb_deg": 6.0,
   "points_watched": ["Ascendant", "Midheaven", "Sun", "Moon", "Venus", "chart ruler"],
   "transiting_bodies": ["Saturn", "Uranus", "Neptune", "Pluto", "Jupiter"],
   "meanings": {
     "Saturn": "Structural test and consolidation of the house and planet contacted.",
     "Jupiter": "Opening, opportunity and over-extension in equal measure.",
     "Uranus": "Rupture and awakening; the arrangement that was tolerated becomes intolerable.",
     "Neptune": "Dissolution, idealisation and fog; a poor window for contracts.",
     "Pluto": "Compulsion, purge and the transfer of power.",
   },
   "rule": "A Western transit hit is a second opinion. It never overrides the Vimshottari x gochara verdict; it raises or lowers confidence.",
 },
 "progressions": {
   "secondary": "A day for a year. The progressed Moon changes sign about every 2.5 years and marks the emotional chapter.",
   "progressed_moon_return": "Age ~27.3 and ~54.6: the emotional cycle restarts.",
   "use": "PocketAstro treats progressions as supporting texture, not as an event clock.",
 },
}

for out in (ROOT / "assets/kb/transits.json", ROOT / "knowledge/extract/transits.json"):
    out.write_text(json.dumps(DOC, indent=1, ensure_ascii=False) + "\n")
n = sum(len(v) for v in DOC["results_from_moon"].values())
print("transits.json", len(json.dumps(DOC)), "bytes,", n, "gochara cells")

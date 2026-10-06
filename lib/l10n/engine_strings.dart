/// Localisation for text the *engine* produces.
///
/// The widget layer uses generated ARB lookups keyed off a `BuildContext`. The
/// engine has no context and must not import Flutter, so it gets this instead:
/// a plain-Dart table with English compiled in as the guaranteed baseline and
/// every other locale loaded from `assets/kb/i18n/<locale>/engine.json`.
///
/// Three rules hold this together:
///
/// * **English is never missing.** It is in the binary, so a failed asset load
///   degrades to English rather than to blank text.
/// * **A missing key is loud, not silent.** `t()` returns the key itself, and
///   a test asserts no rendered string ever looks like a key.
/// * **Adding a language is adding a directory.** No Dart change is required
///   to support a new locale here or in the knowledge base.
library;

import 'dart:convert';

/// Locales the app ships. Extend this list and add the matching asset
/// directory; nothing else needs to change.
const supportedLocaleCodes = ['en', 'ne', 'hi'];

const localeNames = <String, String>{
  'en': 'English',
  'ne': 'नेपाली',
  'hi': 'हिन्दी',
};

/// Engine-side strings for one locale.
class EngineStrings {
  EngineStrings(this.locale, this._table);

  final String locale;
  final Map<String, String> _table;

  /// The instance the engine reads. Swapped when the user changes language.
  static EngineStrings current = EngineStrings('en', const {});

  /// Per-locale overlays loaded from assets, keyed by locale code.
  static final Map<String, Map<String, String>> _loaded = {};

  static void install(String locale) {
    current = EngineStrings(locale, _loaded[locale] ?? const {});
  }

  /// Registers a locale overlay. Called at startup for each shipped locale.
  static void register(String locale, String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return;
    _loaded[locale] = {
      for (final e in decoded.entries)
        if (e.value is String) e.key: e.value as String,
    };
  }

  static void registerMap(String locale, Map<String, String> table) {
    _loaded[locale] = table;
  }

  /// Keys present for a locale, for the coverage report.
  static Set<String> keysFor(String locale) =>
      locale == 'en' ? _en.keys.toSet() : (_loaded[locale]?.keys.toSet() ?? {});

  static Set<String> get baselineKeys => _en.keys.toSet();

  /// Looks up [key], falling back to English, then to the key itself.
  ///
  /// Placeholders are written `{name}` and substituted from [args].
  String t(String key, [Map<String, Object?> args = const {}]) {
    final raw = _table[key] ?? _en[key] ?? key;
    if (args.isEmpty) return raw;
    var out = raw;
    for (final e in args.entries) {
      out = out.replaceAll('{${e.key}}', '${e.value}');
    }
    return out;
  }

  /// True when this locale actually carries [key] rather than falling back.
  bool has(String key) => _table.containsKey(key);

  /// Share of the baseline this locale covers, 0 to 1.
  double get coverage {
    if (locale == 'en') return 1;
    if (_en.isEmpty) return 1;
    final have = _en.keys.where(_table.containsKey).length;
    return have / _en.length;
  }
}

/// Shorthand used throughout the engine.
String tr(String key, [Map<String, Object?> args = const {}]) =>
    EngineStrings.current.t(key, args);

// ---------------------------------------------------------------------------
// English baseline
// ---------------------------------------------------------------------------

const _en = <String, String>{
  // --- grahas -------------------------------------------------------------
  'graha.Sun': 'Sun',
  'graha.Moon': 'Moon',
  'graha.Mars': 'Mars',
  'graha.Mercury': 'Mercury',
  'graha.Jupiter': 'Jupiter',
  'graha.Venus': 'Venus',
  'graha.Saturn': 'Saturn',
  'graha.Rahu': 'Rahu',
  'graha.Ketu': 'Ketu',
  'graha.Lagna': 'Ascendant',
  'graha.Uranus': 'Uranus',
  'graha.Neptune': 'Neptune',
  'graha.Pluto': 'Pluto',

  // --- signs --------------------------------------------------------------
  'sign.Aries': 'Aries',
  'sign.Taurus': 'Taurus',
  'sign.Gemini': 'Gemini',
  'sign.Cancer': 'Cancer',
  'sign.Leo': 'Leo',
  'sign.Virgo': 'Virgo',
  'sign.Libra': 'Libra',
  'sign.Scorpio': 'Scorpio',
  'sign.Sagittarius': 'Sagittarius',
  'sign.Capricorn': 'Capricorn',
  'sign.Aquarius': 'Aquarius',
  'sign.Pisces': 'Pisces',

  // --- nakshatras ---------------------------------------------------------
  'nakshatra.Ashwini': 'Ashwini',
  'nakshatra.Bharani': 'Bharani',
  'nakshatra.Krittika': 'Krittika',
  'nakshatra.Rohini': 'Rohini',
  'nakshatra.Mrigashira': 'Mrigashira',
  'nakshatra.Ardra': 'Ardra',
  'nakshatra.Punarvasu': 'Punarvasu',
  'nakshatra.Pushya': 'Pushya',
  'nakshatra.Ashlesha': 'Ashlesha',
  'nakshatra.Magha': 'Magha',
  'nakshatra.Purva Phalguni': 'Purva Phalguni',
  'nakshatra.Uttara Phalguni': 'Uttara Phalguni',
  'nakshatra.Hasta': 'Hasta',
  'nakshatra.Chitra': 'Chitra',
  'nakshatra.Swati': 'Swati',
  'nakshatra.Vishakha': 'Vishakha',
  'nakshatra.Anuradha': 'Anuradha',
  'nakshatra.Jyeshtha': 'Jyeshtha',
  'nakshatra.Mula': 'Mula',
  'nakshatra.Purva Ashadha': 'Purva Ashadha',
  'nakshatra.Uttara Ashadha': 'Uttara Ashadha',
  'nakshatra.Shravana': 'Shravana',
  'nakshatra.Dhanishta': 'Dhanishta',
  'nakshatra.Shatabhisha': 'Shatabhisha',
  'nakshatra.Purva Bhadrapada': 'Purva Bhadrapada',
  'nakshatra.Uttara Bhadrapada': 'Uttara Bhadrapada',
  'nakshatra.Revati': 'Revati',

  // --- ordinals -----------------------------------------------------------
  'ord.1': '1st', 'ord.2': '2nd', 'ord.3': '3rd', 'ord.4': '4th',
  'ord.5': '5th', 'ord.6': '6th', 'ord.7': '7th', 'ord.8': '8th',
  'ord.9': '9th', 'ord.10': '10th', 'ord.11': '11th', 'ord.12': '12th',

  // --- house plain titles -------------------------------------------------
  'house.plain.1': 'You and your body',
  'house.plain.2': 'Money you keep, and your voice',
  'house.plain.3': 'Courage, skill and siblings',
  'house.plain.4': 'Home, mother and peace of mind',
  'house.plain.5': 'Children, learning and creativity',
  'house.plain.6': 'Work, health and competition',
  'house.plain.7': 'Marriage and partnership',
  'house.plain.8': 'Change, inheritance and the hidden',
  'house.plain.9': 'Luck, father and belief',
  'house.plain.10': 'Career and public standing',
  'house.plain.11': 'Income, friends and networks',
  'house.plain.12': 'Rest, letting go and life abroad',

  // --- house topics -------------------------------------------------------
  'house.topic.1': 'self, body, fame',
  'house.topic.2': 'speech, family, savings',
  'house.topic.3': 'courage, siblings, craft',
  'house.topic.4': 'home, mother, vehicles, land',
  'house.topic.5': 'children, intellect, romance',
  'house.topic.6': 'work, illness, enemies, debt',
  'house.topic.7': 'spouse, partner, the other',
  'house.topic.8': 'transformation, tax, in-laws, occult',
  'house.topic.9': 'dharma, father, luck, long travel',
  'house.topic.10': 'career, status, public name',
  'house.topic.11': 'gains, friends, networks',
  'house.topic.12': 'loss, sleep, foreign, retreat',

  // --- house bands --------------------------------------------------------
  'band.prosperous': 'Supported',
  'band.steady': 'Steady',
  'band.strained': 'Under pressure',
  'band.summary.prosperous':
      'The chart supports this area. The payout is available; the period decides when.',
  'band.summary.steady':
      'This area works, unevenly or with effort. Nothing here is blocked.',
  'band.summary.strained':
      'This area is under pressure. Pressure has a cause and a remedy — it is never a verdict.',

  // --- verdicts -----------------------------------------------------------
  'verdict.likely': 'Likely',
  'verdict.possible': 'Possible',
  'verdict.caution': 'Take care',
  'verdict.do_not_claim': 'Not indicated',
  'verdict.lead.likely':
      'Two techniques agree, so this is a genuine window.',
  'verdict.lead.possible':
      'One technique supports this. Worth preparing for, not worth betting on.',
  'verdict.lead.caution':
      'The timing works, but something is pulling against it.',
  'verdict.lead.do_not_claim':
      'Nothing in the chart points to this right now.',

  // --- nature -------------------------------------------------------------
  'nature.benefic': 'Helpful graha',
  'nature.malefic': 'Demanding graha',
  'nature.helpful_here': 'Helpful here',
  'nature.demanding_here': 'Demanding here',
  'nature.reason.always_benefic': 'A natural benefic in every chart.',
  'nature.reason.moon_bright':
      'Waxing and bright ({pct}% of the way from the Sun), so it acts as a benefic here.',
  'nature.reason.moon_dark':
      'Close to the Sun ({pct}% of the way round), so it is thin on light and acts as a malefic here.',
  'nature.reason.mercury_clean':
      'Keeping good company, so it acts as a benefic here.',
  'nature.reason.mercury_spoiled':
      'Sharing a sign with a malefic, whose nature it takes on.',
  'nature.reason.sun':
      'A natural malefic — hot and separative, though never unkind.',
  'nature.reason.mars': 'A natural malefic — sharp and forceful.',
  'nature.reason.saturn':
      'A natural malefic — slow, restricting, and the one that makes things last.',
  'nature.reason.node':
      'A shadow graha. It has no body of its own and borrows the nature of its sign lord.',
  'nature.reason.outer':
      'Carried for the Western reading only; it takes no part in a Vedic judgment.',

  // --- aspects ------------------------------------------------------------
  'aspect.base': 'Every graha looks straight across at the 7th house from itself.',
  'aspect.extra.Mars': 'Mars also strikes the 4th and 8th from itself.',
  'aspect.extra.Jupiter': 'Jupiter also blesses the 5th and 9th from itself.',
  'aspect.extra.Saturn': 'Saturn also weighs on the 3rd and 10th from itself.',
  'aspect.extra.node':
      'The nodes take Jupiter’s reach — the 5th, 7th and 9th from themselves.',

  // --- house quality reasons ----------------------------------------------
  'hq.sav.well_above':
      'Strong point count here — {n} of a possible 56, against an average of 28.',
  'hq.sav.above': 'Point count is above average — {n} against 28.',
  'hq.sav.below': 'Point count is slightly below average — {n} against 28.',
  'hq.sav.well_below': 'Low point count — only {n} against an average of 28.',
  'hq.occupant.benefic':
      '{graha} sits here, and is working as a benefic in this chart.',
  'hq.occupant.malefic':
      '{graha} sits here, and is working as a malefic in this chart.',
  'hq.occupant.upachaya':
      '{graha} sits here. In a house of growth like the {ord}, a hard graha builds strength over the years rather than blocking.',
  'hq.lord.strong':
      'Its ruler {lord} sits in the {ord}, one of the chart’s strong positions.',
  'hq.lord.dusthana':
      'Its ruler {lord} sits in the {ord}, a difficult position, so results come late or by a roundabout route.',
  'hq.lord.exalted': 'Its ruler {lord} is exalted in {sign}.',
  'hq.lord.own': 'Its ruler {lord} is in its own sign, {sign}.',
  'hq.lord.debilitated':
      'Its ruler {lord} is weak in {sign} — check whether the weakness is cancelled before reading it as a limit.',
  'hq.lord.combust': 'Its ruler {lord} is too close to the Sun to act freely.',
  'hq.lord.functional_benefic':
      '{lord} is one of the helpful grahas for your rising sign.',
  'hq.lord.functional_malefic':
      '{lord} is one of the difficult grahas for your rising sign.',
  'hq.lord.yogakaraka': '{lord} is the single best graha for your rising sign.',
  'hq.aspect.jupiter':
      'Jupiter looks at this house, which protects and expands it.',
  'hq.aspect.benefic': '{graha} looks at this house, which helps it.',
  'hq.aspect.malefic':
      '{graha} looks at this house, which puts pressure on it.',
  'hq.yogakaraka_here':
      '{graha} — the best graha for your rising sign — sits here.',

  // --- matching -----------------------------------------------------------
  'koota.Varna.title': 'Outlook and work',
  'koota.Varna.means':
      'Whether the two approach duty and ambition from compatible places.',
  'koota.Vashya.title': 'Natural pull',
  'koota.Vashya.means':
      'Who tends to lead and who tends to follow, and whether that sits well.',
  'koota.Taara.title': 'Fortune and health',
  'koota.Taara.means':
      'Whether the pairing tends to bring each other good or difficult stretches.',
  'koota.Yoni.title': 'Physical compatibility',
  'koota.Yoni.means':
      'Instinctive and bodily temperament, read through the birth-star animal.',
  'koota.Graha-maitri.title': 'Mental friendship',
  'koota.Graha-maitri.means':
      'Whether the two minds actually like each other — the parameter that matters most day to day.',
  'koota.Gana.title': 'Temperament type',
  'koota.Gana.means': 'Gentle, worldly or intense, and how those three mix.',
  'koota.Bhakoot.title': 'Shared rhythm',
  'koota.Bhakoot.means':
      'Whether the two nervous systems run on the same clock. Carries the most points after Nadi.',
  'koota.Nadi.title': 'Constitution',
  'koota.Nadi.means':
      'Classically read for health and children. The heaviest parameter, and the one with the most exceptions.',
  'match.verdict.strong':
      'A strong traditional match. The classical parameters line up well.',
  'match.verdict.workable':
      'A workable traditional match. Some parameters agree, some do not — which is true of most real couples.',
  'match.verdict.low':
      'A low traditional score. It points at where effort will be needed, not at whether the relationship can work.',
  'match.verdict.very_low':
      'A low traditional score. Treat it as a conversation starter about temperament and health, never as a reason to end something real.',
  'match.band.excellent': 'excellent',
  'match.band.mediocre': 'mixed',
  'match.band.adverse': 'not recommended',

  // --- Q&A trace ----------------------------------------------------------
  'qa.step.question': 'Reading your question',
  'qa.step.chart': 'Opening your chart',
  'qa.step.karakas': 'Reading the grahas that signify it',
  'qa.step.house': 'Checking the houses that govern this',
  'qa.step.dasha': 'Running your Vimshottari periods',
  'qa.step.transit': 'Checking where the slow grahas are now',
  'qa.step.bindu': 'Weighing the point count',
  'qa.step.library': 'Applying the rules',
  'qa.step.refusal': 'Checking the refusal list',
  'qa.detail.subject': 'This is about {subject}.',
  'qa.detail.no_time':
      'No birth time on file, so the rising sign and all twelve houses are withheld. The Moon still carries the reading.',
  'qa.detail.chart': '{rising} rising, Moon in {moonSign} ({nakshatra}).',
  'qa.detail.house':
      'House {houses}. The {ord} is ruled by {lord}, which sits in the {lordOrd} — {band}.',
  'qa.detail.dasha': '{md} major period{ad}, to {end}.',
  'qa.detail.dasha_sub': ', {ad} sub-period',
  'qa.detail.transit':
      'Saturn {satOrd} from your Moon, Jupiter {jupOrd}.{extra}',
  'qa.detail.sade_sati': ' Sade Sati is running.',
  'qa.detail.ashtama': ' Ashtama Shani is running.',
  'qa.detail.bindu':
      'Jupiter holds {n} of 8 points in the sign it is crossing. {note}',
  'qa.detail.bindu.delivers': 'Enough to deliver.',
  'qa.detail.bindu.mixed': 'Mixed.',
  'qa.detail.bindu.withholds': 'Not enough — the transit withholds.',
  'qa.detail.rules':
      'Two techniques must agree before anything is called likely, and confidence never goes above 75.',
  'qa.detail.refused_death': 'This asks for a death prediction.',
  'qa.detail.refused_list':
      'The knowledge base forbids this answer, so no chart is read.',
  'qa.detail.refused_crisis':
      'This needs a person, not a chart. Stopping here.',
  'qa.source.books': '{n} source books compiled offline',

  // --- Q&A intents --------------------------------------------------------
  'qa.intent.birth_time_ok': 'how reliable your birth time is',
  'qa.intent.system': 'which system this app uses',
  'qa.intent.not_promised': 'what this chart does not promise',
  'qa.intent.now_dasha': 'the life period you are in',
  'qa.intent.next_window': 'timing and good windows',
  'qa.intent.career': 'work and career',
  'qa.intent.money': 'money',
  'qa.intent.marriage_if': 'marriage',
  'qa.intent.spouse_type': 'the kind of partner your chart describes',
  'qa.intent.manglik': 'Manglik (Kuja dosha)',
  'qa.intent.children': 'children and creativity',
  'qa.intent.home': 'home, property and family',
  'qa.intent.foreign': 'living or earning abroad',
  'qa.intent.health': 'health, as lifestyle flags only',
  'qa.intent.psychology': 'patterns that get in your own way',
  'qa.intent.remedy': 'remedies',
  'qa.intent.90_days': 'the next ninety days',
  'qa.intent.general': 'your chart in general',
  'qa.intent.refused_crisis': 'something that needs a person, not an app',
  'qa.intent.refused_death': 'a question this app will not answer',

  // --- Q&A headlines ------------------------------------------------------
  'qa.head.period': 'You are in a {period} period — a chapter, not a sentence.',
  'qa.head.period_unknown': 'Your period could not be worked out.',
  'qa.head.window': 'The clearest window ahead is {title}.',
  'qa.head.no_window':
      'No standout window in the next two years. Steady work is the plan.',
  'qa.head.health': 'Lifestyle flags only. Nothing here is a diagnosis.',
  'qa.head.remedy': 'Behaviour first, ritual second, stones last.',
  'qa.head.manglik':
      'Manglik is a compatibility setting, not a verdict on your life.',
  'qa.head.no_time':
      'Read from your Moon. Add a birth time to unlock the houses.',
  'qa.head.default':
      'Read from your {rising} rising chart, under a {period} period.',
  'qa.head.refused_crisis': 'Please talk to a person, not an app.',
  'qa.head.refused_death':
      'This app does not predict death, and that is deliberate.',

  // --- questions the app suggests ----------------------------------------
  'qa.ask.now_dasha': 'My period now',
  'qa.ask.next_window': 'Good windows',
  'qa.ask.career': 'Career',
  'qa.ask.money': 'Money',
  'qa.ask.marriage_if': 'Marriage',
  'qa.ask.spouse_type': 'My partner',
  'qa.ask.children': 'Children',
  'qa.ask.home': 'Home',
  'qa.ask.foreign': 'Abroad',
  'qa.ask.health': 'Health',
  'qa.ask.remedy': 'Remedies',
  'qa.ask.manglik': 'Manglik?',
  'qa.ask.90_days': 'Next 90 days',
  'qa.ask.psychology': 'My patterns',
  'qa.ask.birth_time_ok': 'Is my time right?',
  'qa.ask.not_promised': 'What is not promised',
  'qa.ask.system': 'Which system?',

  // --- the day: panchanga limbs and windows -------------------------------
  'panchanga.limb.tithi': 'Tithi',
  'panchanga.limb.vara': 'Weekday',
  'panchanga.limb.nakshatra': 'Nakshatra',
  'panchanga.limb.yoga': 'Yoga',
  'panchanga.limb.karana': 'Karana',
  'panchanga.paksha.shukla': 'waxing fortnight',
  'panchanga.paksha.krishna': 'waning fortnight',
  'panchanga.window.rahu': 'Rahu kaal',
  'panchanga.window.yamaganda': 'Yamaganda',
  'panchanga.window.gulika': 'Gulika kaal',
  'panchanga.window.abhijit': 'Abhijit muhurta',
  'vara.Monday': 'Monday',
  'vara.Tuesday': 'Tuesday',
  'vara.Wednesday': 'Wednesday',
  'vara.Thursday': 'Thursday',
  'vara.Friday': 'Friday',
  'vara.Saturday': 'Saturday',
  'vara.Sunday': 'Sunday',

  // --- the day: how it reads ----------------------------------------------
  'today.grade.favourable': 'Favourable',
  'today.grade.favourable.sub':
      'The day\u2019s filters agree. A good one to start something.',
  'today.grade.workable': 'Workable',
  'today.grade.workable.sub':
      'More support than friction. Ordinary work goes well.',
  'today.grade.mixed': 'Mixed',
  'today.grade.mixed.sub':
      'Support and friction roughly balance. Keep plans modest.',
  'today.grade.guarded': 'Guarded',
  'today.grade.guarded.sub':
      'Several filters are against beginnings. Continue, do not launch.',

  // --- the day: why a suggestion is there ---------------------------------
  'today.why.vara_good': '{vara} is classically suited to this.',
  'today.why.vara_avoid': '{vara} is classically unsuited to this.',
  'today.why.tithi': '{tithi} of the {paksha}.',
  'today.why.karana': 'The karana running is {karana}.',
  'today.why.moon_house': 'The Moon transits your {house} house today.',

  // --- the day: the suggestions themselves --------------------------------
  'today.cue.tara_bad': 'Anything you cannot repeat tomorrow',
  'today.cue.tara_good': 'Starting something that has to last',
  'today.cue.chandra_bad':
      'Travel and signings \u2014 the Moon is {house} from your birth Moon',
  'today.cue.chandra_good':
      'Meetings and approaches \u2014 the Moon is {house} from your birth Moon',
  'today.cue.vishti': 'Beginnings, while Vishti karana runs',
  'today.cue.kakshya_low': 'Big commitments \u2014 few grahas carry a bindu',
  'today.cue.kakshya_high': 'Pushing on what is already moving',
  'today.cue.moon_house': 'Attention on {topic}',

  // --- the day: the paragraph a reader can stop at ------------------------
  'today.guide.open':
      'Today reads {grade}. It is {tithi} of the {paksha}, the Moon is in '
          '{nakshatra}, and it is {vara}.',
  'today.guide.moon':
      'The Moon is moving through {sign}, your {house} house \u2014 so '
          '{topic} is where the day puts its weight.',
  'today.guide.dasha':
      'You are in a {md} period with {ad} running underneath. {push} {wait}',
  'today.guide.soft_day':
      'The Moon is weak against your birth Moon today. Keep the day for work '
          'already under way rather than for new ground.',
  'today.guide.strong_day':
      'The Moon is strong against your birth Moon. If something has been '
          'waiting for a day to begin on, this is one.',
  'today.guide.abhijit':
      'Abhijit muhurta is the safe window if you need one thing to go well.',
  'today.guide.order':
      'A day can colour what your chart and your period already promised. It '
          'cannot add to it or take it away.',
  'today.remedy': '{graha} carries today. {practical}',

  // --- dignity, as a word rather than a table cell -------------------------
  'dignity.exalted': 'exalted',
  'dignity.debilitated': 'debilitated',
  'dignity.own': 'in its own sign',

  // --- the syllabus: each lesson's idea, found in the reader's chart -------
  'learn.example.what_a_chart_is':
      'Your chart is the sky over {place} \u2014 {lat}\u00b0, {lon}\u00b0 \u2014 at the '
          'moment you were born, and nothing more than that.',
  'learn.example.two_zodiacs':
      'Your Sun is at {sidereal} sidereally and {tropical} tropically. The '
          '{ayanamsa}\u00b0 between those two readings is the ayanamsa.',
  'learn.example.nine_grahas':
      'Your {graha} is {dignity}, in {sign} \u2014 the strongest dignity your '
          'chart holds.',
  'learn.example.nine_grahas_none':
      'No graha in your chart is exalted or in its own sign. That is ordinary, '
          'not a fault: most charts are read from placement and lordship.',
  'learn.example.twelve_houses':
      'Your 10th house \u2014 {topic} \u2014 is {sign}, so it answers to {lord}.',
  'learn.example.three_signs':
      '{rising} rising, Moon in {moon}, Sun in {sun}. A Vedic reader starts '
          'with the first two.',
  'learn.example.three_signs_no_time':
      'Moon in {moon}, Sun in {sun}. Your rising sign is withheld until a '
          'birth time is on file.',
  'learn.example.house_lords':
      'You have {rising} rising, so {lord} is your lagna lord \u2014 and it '
          'sits in your {house} house, among {topic}.',
  'learn.example.aspects':
      'Your Saturn sits in the {house} house, so by the special drishti it '
          'looks at these houses: {houses}.',
  'learn.example.nakshatras':
      'Your Moon is in {nakshatra}, pada {pada}, owned by {lord} \u2014 which '
          'is why your dasha sequence opens where it does.',
  'learn.example.dignity':
      'Your {graha} is {dignity}, in {sign}.',
  'learn.example.dignity_none':
      'Your {graha} is in {sign}, holding no special dignity \u2014 so it is '
          'judged on placement, lordship and aspect instead.',
  'learn.example.vimshottari':
      'Your Moon sits in {nakshatra}, owned by {lord}, so your life opened in '
          'a {lord} mahadasha \u2014 the {years}-year share of the wheel.',
  'learn.example.yogas':
      '{count} yogas stand in your chart once cancellation is applied. The '
          'weightiest is {name}.',
  'learn.example.yogas_none':
      'No named yoga stands in your chart after cancellation. That is common, '
          'and it says nothing about the life.',
  'learn.example.vargas':
      'You have {rising} rising in the birth chart and {navamsa} rising in the '
          'navamsa. Both are read, and they are read for different things.',
  'learn.example.ashtakavarga':
      'Your 10th house carries {bindus} sarvashtakavarga bindus of 56, {verdict} '
          'the average of 28.',
  'learn.av.above': 'above',
  'learn.av.below': 'at or below',
  'learn.example.gochara':
      'Every transit in this app is counted from your Moon in {moon}, in '
          '{nakshatra} \u2014 not from your rising sign.',
  'learn.example.order':
      'Every reading in this app was produced in that order, and the '
          'confidence figure beside each one says how far it can be trusted.',
  'learn.example.needs_time':
      'This example needs your birth time. The ascendant moves a degree every '
          'four minutes, so PocketAstro withholds it rather than guessing.',

  // --- the daily reading by moon sign --------------------------------------
  'rashi.headline.favourable':
      'A good day for {sign}. The Moon is in your {house} house, and most of '
          'what is moving is moving with you.',
  'rashi.headline.workable':
      'A workable day for {sign}. The Moon is in your {house} house, with more '
          'support than friction.',
  'rashi.headline.mixed':
      'A mixed day for {sign}. The Moon is in your {house} house, and support '
          'and friction roughly cancel.',
  'rashi.headline.guarded':
      'A guarded day for {sign}. The Moon is in your {house} house, and several '
          'transits are against beginnings.',
  'rashi.line.house': '{graha} in your {house} house',
  'rashi.line.obstructed':
      'Helpful, but obstructed by vedha \u2014 a graha sits in the house that '
          'cancels it.',
  'rashi.coarse':
      'A rashi is one twelfth of everybody. Your own chart reads the same '
          'transits against your birth Moon, your dasha and your ashtakavarga.',
};

import '../domain/models.dart';
import 'ashtakavarga.dart';
import 'astronomy.dart';
import 'dasha.dart';
import 'kb.dart';
import 'tables.dart';

class TransitSnap {
  const TransitSnap({
    required this.utc,
    required this.sidereal,
    required this.tropical,
    required this.fromMoon,
    required this.fromLagna,
    required this.sadeSati,
    required this.ashtamaShani,
    required this.saturnUpachaya,
    this.av,
    this.avTransits = const {},
  });

  final DateTime utc;
  final Map<String, double> sidereal;
  final Map<String, double> tropical;
  final Map<String, int> fromMoon;
  final Map<String, int> fromLagna;
  final bool sadeSati;
  final bool ashtamaShani;
  final bool saturnUpachaya;

  /// The natal ashtakavarga, or null when the birth time is unknown.
  final AshtakavargaChart? av;

  /// Each transiting graha judged against its own bhinnashtakavarga.
  final Map<String, AvTransit> avTransits;

  /// Bindus [planet] holds in the sign it is transiting, or null when the
  /// ashtakavarga could not be computed.
  int? bindusFor(String planet) => avTransits[planet]?.bindus;
}

class ForecastHit {
  const ForecastHit({
    required this.title,
    required this.verdict,
    required this.confidence,
    required this.body,
    required this.techniques,
  });

  /// likely | possible | caution | do_not_claim
  final String verdict;
  final String title;
  final int confidence;
  final String body;
  final List<String> techniques;
}

class ForecastReport {
  const ForecastReport({
    required this.now,
    required this.md,
    required this.ad,
    required this.pd,
    required this.hits,
    required this.windows,
    required this.dasaChidra,
  });

  final TransitSnap now;
  final DashaSpan? md;
  final DashaSpan? ad;
  final DashaSpan? pd;
  final List<ForecastHit> hits;
  final List<ForecastHit> windows;
  final bool dasaChidra;
}

const _slow = ['Saturn', 'Jupiter', 'Rahu', 'Ketu', 'Mars'];

TransitSnap gocharaAt(NatalChart natal, DateTime utc) {
  final trop = computeTropical(
    utc: utc,
    latitude: natal.input.place.latitude,
    longitudeEast: natal.input.place.longitude,
  );
  final moonSign = signIndex(natal.graha('Moon').siderealLon);
  final lagnaSign = natal.input.timeUnknown
      ? moonSign
      : signIndex(natal.lagnaSidereal);
  final sidereal = <String, double>{};
  final tropical = <String, double>{};
  final fromMoon = <String, int>{};
  final fromLagna = <String, int>{};
  for (final name in _slow) {
    final t = trop.bodies[name]!;
    tropical[name] = t;
    final sid = trop.siderealOf(name);
    sidereal[name] = sid;
    fromMoon[name] = wholeSignHouse(moonSign, signIndex(sid));
    fromLagna[name] = wholeSignHouse(lagnaSign, signIndex(sid));
  }
  final satMoon = fromMoon['Saturn']!;
  final kb = PredictionKb.current;

  // Ashtakavarga needs the lagna as its eighth contributor, so it is only
  // available when the birth time is known.
  final av = ashtakavargaFor(natal);
  final avTransits = <String, AvTransit>{};
  if (av != null) {
    for (final name in avPlanets) {
      final t = trop.bodies[name];
      if (t == null) continue;
      final sid = trop.siderealOf(name);
      sidereal.putIfAbsent(name, () => sid);
      tropical.putIfAbsent(name, () => t);
      final judged = judgeTransit(av, name, sid);
      if (judged != null) avTransits[name] = judged;
    }
  }

  return TransitSnap(
    utc: utc,
    sidereal: sidereal,
    tropical: tropical,
    fromMoon: fromMoon,
    fromLagna: fromLagna,
    sadeSati: kb.sadeSatiHouses.contains(satMoon),
    ashtamaShani: satMoon == kb.ashtamaHouse,
    saturnUpachaya: kb.saturnUpachaya.contains(satMoon),
    av: av,
    avTransits: avTransits,
  );
}

ForecastReport forecastChart(NatalChart chart, {DateTime? now}) {
  now ??= DateTime.now().toUtc();
  final md = chart.mahadashaAt(now);
  final ad = chart.antardashaAt(now);
  final pd = ad == null ? null : pratyantaraAt(ad, now);
  final snap = gocharaAt(chart, now);
  final dasaChidra = md != null && _isDasaChidra(md, now);

    final hits = <ForecastHit>[
    _dashaHit(chart, md, ad, pd, dasaChidra),
    _gocharaHit(chart, snap),
    _event(chart, snap, md, ad, pd, 'marriage'),
    _event(chart, snap, md, ad, pd, 'career'),
    _event(chart, snap, md, ad, pd, 'money'),
    _event(chart, snap, md, ad, pd, 'home'),
    _event(chart, snap, md, ad, pd, 'children'),
    _western(chart, snap),
  ];

  final windows = <ForecastHit>[];
  for (var i = 0; i < 24; i++) {
    final t = DateTime.utc(now.year, now.month + i, 15);
    final m = chart.mahadashaAt(t);
    final a = chart.antardashaAt(t);
    final p = a == null ? null : pratyantaraAt(a, t);
    final g = gocharaAt(chart, t);
    for (final key in const ['marriage', 'career', 'money', 'home']) {
      final hit = _event(chart, g, m, a, p, key, when: t);
      if (hit.verdict == 'likely' ||
          (hit.verdict == 'caution' && key == 'marriage')) {
        windows.add(hit);
      }
    }
    if (g.sadeSati || g.ashtamaShani) {
      windows.add(
        ForecastHit(
          title: g.ashtamaShani ? 'Ashtama Shani' : 'Sade Sati',
          verdict: 'caution',
          confidence: 58,
          body:
              '${_fmt(t)}: Saturn ${g.fromMoon['Saturn']} from natal Moon. '
              '${g.ashtamaShani ? PredictionKb.current.saturnFromMoon(8) : PredictionKb.current.saturnFromMoon(g.fromMoon['Saturn']!)} '
              'Toll on the current dasha — not deletion of yoga.',
          techniques: const ['gochara Saturn from Moon (Levacy/Charak)'],
        ),
      );
    }
  }

  return ForecastReport(
    now: snap,
    md: md,
    ad: ad,
    pd: pd,
    hits: hits,
    windows: _dedupeWindows(windows),
    dasaChidra: dasaChidra,
  );
}

/// Ashtakavarga lines for the gochara hit: the slow grahas judged against
/// their own bindus in the sign they are crossing.
List<String> _avLines(TransitSnap snap) {
  final av = snap.av;
  if (av == null) {
    return const [
      'Ashtakavarga is withheld: the lagna is one of its eight contributors, '
          'so it needs a birth time.',
    ];
  }
  final out = <String>[];
  for (final p in const ['Saturn', 'Jupiter', 'Mars']) {
    final t = snap.avTransits[p];
    if (t != null) out.add(t.line);
  }
  final sav = av.sarvaInSign(signIndex(snap.sidereal['Saturn']!));
  out.add(
    'Sarvashtakavarga of the sign Saturn is crossing: $sav of 56 '
    '(${sav > PredictionKb.current.sarvaAverage ? 'above' : 'at or below'} '
    'the average of ${PredictionKb.current.sarvaAverage}).',
  );
  return out;
}

ForecastHit _dashaHit(
  NatalChart chart,
  DashaSpan? md,
  DashaSpan? ad,
  DashaSpan? pd,
  bool chidra,
) {
  if (md == null) {
    return const ForecastHit(
      title: 'Vimshottari',
      verdict: 'do_not_claim',
      confidence: 20,
      body: 'Dasha could not be computed.',
      techniques: ['Vimshottari'],
    );
  }
  final kb = PredictionKb.current;
  final flavour = kb.dashaFlavour(md.lord);
  final push = kb.dashaPush(md.lord);
  final wait = kb.dashaWait(md.lord);
  final moonNak = nakshatraOf(chart.graha('Moon').siderealLon);
  final tone = kb.nakshatraTone(moonNak.name);
  final ketu = ad?.lord == 'Ketu';
  String d9bit = '';
  try {
    final lon = chart.graha(md.lord).siderealLon;
    final d9 = signs[navamsaSign(lon)];
    d9bit =
        ' ${md.lord} in navamsa ${d9.name} — D9 colours this dasha (Braha/Levacy).';
  } catch (_) {}
  String adFromMd = '';
  var adTrika = false;
  if (ad != null && ad.lord != md.lord) {
    try {
      final h = wholeSignHouse(
        signIndex(chart.graha(md.lord).siderealLon),
        signIndex(chart.graha(ad.lord).siderealLon),
      );
      final rel = relation(md.lord, ad.lord);
      adFromMd =
          'AD ${ad.lord} sits house $h from the MD lord ($rel to ${md.lord}).';
      if (const {6, 8, 12}.contains(h)) {
        adTrika = true;
        adFromMd +=
            ' Charak XV: AD in 6/8/12 from the MD lord is a hard chapter — do not stamp events.';
      }
    } catch (_) {}
  }
  final bits = <String>[
    'Mahadasha ${md.lord} (${_fmt(md.start)} – ${_fmt(md.end)}).',
    if (ad != null) 'Antardasha ${ad.lord} until ${_fmt(ad.end)}.',
    if (pd != null) 'Pratyantara ${pd.lord} until ${_fmt(pd.end)}.',
    if (flavour.isNotEmpty) flavour,
    if (push.isNotEmpty) 'Push: $push',
    if (wait.isNotEmpty) 'Wait: $wait',
    if (adFromMd.isNotEmpty) adFromMd,
    if (tone.isNotEmpty) 'Moon nakshatra ${moonNak.name}: $tone',
    if (d9bit.isNotEmpty) d9bit.trim(),
    if (ketu)
      'Ketu AD: do not ${kb.ketuForbidden().join(', ')}.',
    if (chidra) kb.data['dasa_chidra'] as String? ??
        'Dasa chidra: do not launch a new life on the leftover of this mahadasha.',
  ];
  return ForecastHit(
    title: 'Current dasha',
    verdict: ketu || chidra || adTrika ? 'caution' : 'possible',
    confidence: _cap(chart, ketu || chidra || adTrika ? 52 : 64),
    body: bits.join(' '),
    techniques: const ['Vimshottari (Charak XV / Levacy)'],
  );
}

ForecastHit _gocharaHit(NatalChart chart, TransitSnap snap) {
  final kb = PredictionKb.current;
  final satH = snap.fromMoon['Saturn']!;
  final jupH = snap.fromMoon['Jupiter']!;
  final marsH = snap.fromLagna['Mars']!;
  final rahuH = snap.fromMoon['Rahu']!;
  final ketuH = snap.fromMoon['Ketu']!;
  final jupAspectsSat = _jupiterAspectsSaturn(snap);
  final jupVedha = _vedhaOn(snap, 'Jupiter');
  final satVedha = _vedhaOn(snap, 'Saturn');
  /// Charak XXIX result for [name], preferring the full module table.
  String fromMoon(String name, int house, String legacy) {
    final v = kb.gocharaFromMoon(name, house);
    return v.isNotEmpty ? v : legacy;
  }

  final bits = <String>[
    'Saturn ${signOf(snap.sidereal['Saturn']!).name}, house $satH from Moon. '
        '${fromMoon('Saturn', satH, kb.saturnFromMoon(satH))}'
        '${_beneficNote(kb, 'Saturn', satH)}',
    'Jupiter ${signOf(snap.sidereal['Jupiter']!).name}, house $jupH from Moon. '
        '${fromMoon('Jupiter', jupH, kb.jupiterFromMoon(jupH))}'
        '${_beneficNote(kb, 'Jupiter', jupH)}',
    'Mars ${signOf(snap.sidereal['Mars']!).name}, house '
        '${snap.fromMoon['Mars']} from Moon. '
        '${fromMoon('Mars', snap.fromMoon['Mars']!, '')}',
    if (kb.marsFromLagna(marsH).isNotEmpty)
      'Mars house $marsH from lagna: ${kb.marsFromLagna(marsH)}',
    'Rahu house $rahuH from Moon: ${fromMoon('Rahu', rahuH, kb.rahuFromMoon(rahuH))}',
    'Ketu house $ketuH from Moon: ${fromMoon('Ketu', ketuH, kb.ketuFromMoon(ketuH))}',
    if (snap.sadeSati) 'Sade Sati is on (Saturn 12/1/2 from natal Moon).',
    if (snap.ashtamaShani)
      'Ashtama Shani is on (Saturn 8th from natal Moon). Toll, not deletion.',
    if (snap.saturnUpachaya)
      'Saturn in upachaya (3/6/11 from Moon): effort, work, and gains can still land (Levacy).',
    if (jupAspectsSat)
      'Jupiter aspects transiting Saturn — Levacy: the toll lightens; still a chapter of duty.',
    if (jupVedha)
      'Jupiter gochara is under Vedha (Charak XXIX): another planet occupies the obstructing house from the Moon. Do not treat this Jupiter as a free green light.',
    if (satVedha)
      'Saturn’s upachaya transit is under Vedha — the easy 3/6/11 reading is blocked.',
    ..._avLines(snap),
  ];
  return ForecastHit(
    title: 'Gochara now',
    verdict: snap.ashtamaShani || snap.sadeSati ? 'caution' : 'possible',
    confidence: _cap(chart, 60),
    body: bits.where((s) => s.trim().isNotEmpty).join(' '),
    techniques: const ['Gochara from Moon (Charak XXIX / Levacy 14)'],
  );
}

ForecastHit _event(
  NatalChart chart,
  TransitSnap snap,
  DashaSpan? md,
  DashaSpan? ad,
  DashaSpan? pd,
  String key, {
  DateTime? when,
}) {
  final kb = PredictionKb.current;
  final spec = kb.eventKey(key) ?? _fallbackEvent(key);
  final planets = (spec['dasha_planets'] as List).map((e) => e.toString()).toList();
  final houses = (spec['houses'] as List).map((e) => (e as num).toInt()).toList();
  final jupHouses = (spec['jupiter_gochara_houses_from_lagna'] as List)
      .map((e) => (e as num).toInt())
      .toList();
  final avoid = (spec['avoid_ad'] as List?)?.map((e) => e.toString()).toList() ??
      const ['Ketu'];

  final lords = chart.input.timeUnknown
      ? <String>{}
      : {for (final h in houses) _lordOfHouse(chart, h)};
  final yk = chart.input.timeUnknown
      ? <String>{}
      : yogakarakaFor(signIndex(chart.lagnaSidereal));

  final dashaNames = {md?.lord, ad?.lord, pd?.lord}.whereType<String>().toSet();
  final dashaHits = dashaNames.any(
    (p) => planets.contains(p) || lords.contains(p) || yk.contains(p),
  );
  final jupFromLagna = snap.fromLagna['Jupiter']!;
  var transitHits = jupHouses.contains(jupFromLagna) ||
      jupHouses.contains(snap.fromMoon['Jupiter']!);
  if (transitHits && _vedhaOn(snap, 'Jupiter')) {
    transitHits = false;
  }
  // Charak XXX: a graha transiting a sign where it holds fewer than four
  // bindus withholds its promised result. That is a veto on the transit
  // technique, not a small confidence tweak.
  final jupBindus = snap.bindusFor('Jupiter');
  var avVeto = false;
  var avBonus = 0;
  if (jupBindus != null) {
    if (transitHits && jupBindus < kb.avMixedAt) {
      transitHits = false;
      avVeto = true;
    } else if (transitHits) {
      avBonus = avConfidenceDelta(jupBindus);
    }
  }
  final ketuGochara = {5, 7, 10}.contains(snap.fromMoon['Ketu']);
  final ketuBlock = (ad != null && avoid.contains(ad.lord)) ||
      (pd != null && avoid.contains(pd.lord)) ||
      (ketuGochara && (key == 'marriage' || key == 'children' || key == 'career'));
  final western = spec['western'] as String? ?? '';

  String verdict;
  var conf = chart.input.timeUnknown ? 38 : 48;
  final techniques = <String>[];
  if (dashaHits) {
    conf += 10;
    techniques.add('dasha of ${dashaNames.join('/')} (promise)');
  }
  if (transitHits) {
    conf += 10 + avBonus;
    techniques.add('Jupiter gochara house $jupFromLagna from lagna (Sutton/Levacy)');
    if (jupBindus != null) {
      techniques.add('ashtakavarga: Jupiter holds $jupBindus bindus there');
    }
  } else if (avVeto) {
    techniques.add('ashtakavarga veto: Jupiter holds only $jupBindus bindus');
  }
  if (dashaHits && transitHits) {
    conf += 8;
    verdict = ketuBlock ? 'caution' : 'likely';
  } else if (dashaHits || transitHits) {
    verdict = ketuBlock ? 'do_not_claim' : 'possible';
  } else {
    verdict = 'do_not_claim';
  }
  if (ketuBlock) {
    conf = (conf.clamp(20, 40)).toInt();
    techniques.add('Ketu veto (AD/PD or gochara on 5/7/10 from Moon)');
  }
  if (snap.ashtamaShani && key == 'marriage') {
    techniques.add('Ashtama Shani toll');
    if (verdict == 'likely') verdict = 'possible';
  }
  String natalPromise = '';
  if (!chart.input.timeUnknown && houses.isNotEmpty) {
    final focus = houses.first;
    final lord = _lordOfHouse(chart, focus);
    try {
      final sit = chart.graha(lord).house;
      natalPromise = '$focus-lord $lord sits in house $sit.';
      if (const {6, 8, 12}.contains(sit) && verdict == 'likely') {
        verdict = 'possible';
        techniques.add('$focus-lord in dusthana');
      }
      if (key == 'career') {
        final d10 = signs[dashamsaSign(chart.graha(lord).siderealLon)].name;
        natalPromise += ' Dashamsa (D10) of $lord: $d10 (Levacy career).';
      }
      if (key == 'marriage') {
        final d9 = signs[navamsaSign(chart.graha(lord).siderealLon)].name;
        natalPromise += ' Navamsa of $lord: $d9 (Braha/Levacy spouse).';
      }
    } catch (_) {}
  }
  conf = _cap(chart, conf);

  final whenBit = when == null ? 'Now' : _fmt(when);
  final dashaLine = md == null
      ? ''
      : 'Dasha ${md.lord}${ad == null ? '' : '/${ad.lord}'}${pd == null ? '' : '/${pd.lord}'}';
  final body = [
    '$whenBit: $key — $verdict.',
    if (dashaLine.isNotEmpty) dashaLine,
    if (natalPromise.isNotEmpty) natalPromise,
    if (dashaHits)
      'Dasha activates karakas (${planets.join(', ')}) or house lords (${lords.join(', ')}).'
    else
      'Current dasha is not the karaka/lord stack for $key.',
    if (transitHits)
      'Jupiter times the house (gochara $jupFromLagna from lagna / ${snap.fromMoon['Jupiter']} from Moon).'
    else if (avVeto)
      'Jupiter is on the right house but holds only $jupBindus bindus there, '
          'so the transit withholds its result (Charak XXX).'
    else
      'Jupiter is not on the ${jupHouses.join('/')} from lagna or Moon (or Vedha cancelled it).',
    if (ketuBlock) 'Ketu is active: do not stamp this event.',
    if (western.isNotEmpty) 'Western stack: $western',
    'Two techniques must agree for “likely.” One technique = possible. Conflict = do not claim.',
  ].join(' ');

  return ForecastHit(
    title: when == null ? _title(key) : '${_title(key)} ${_fmt(when)}',
    verdict: verdict,
    confidence: conf,
    body: body,
    techniques: techniques.isEmpty ? const ['natal promise scan'] : techniques,
  );
}

ForecastHit _western(NatalChart chart, TransitSnap snap) {
  final hits = <String>[];
  void check(String planet, double natalLon, String label) {
    final t = snap.tropical[planet];
    if (t == null) return;
    final d = _ang(t, natalLon);
    if (d <= 6) {
      hits.add('Transiting $planet within ${d.toStringAsFixed(1)}° of natal $label (Rushman).');
    }
  }

  check('Saturn', chart.lagnaTropical, 'ASC');
  check('Saturn', chart.mcTropical, 'MC');
  check('Saturn', chart.graha('Sun').tropicalLon, 'Sun');
  check('Saturn', chart.graha('Moon').tropicalLon, 'Moon');
  check('Jupiter', chart.lagnaTropical, 'ASC');
  check('Jupiter', chart.graha('Venus').tropicalLon, 'Venus');

  final body = hits.isEmpty
      ? 'No outer-planet hit within 6° of natal ASC/MC/Sun/Moon/Venus. '
          'Western transits are a second stack (Rushman); Vedic dasha × gochara remains the event clock.'
      : '${hits.join(' ')} Confirm with Vimshottari before calling an event.';
  return ForecastHit(
    title: 'Western transits',
    verdict: hits.isEmpty ? 'do_not_claim' : 'possible',
    confidence: _cap(chart, hits.isEmpty ? 40 : 55),
    body: body,
    techniques: const ['Rushman transits to natal angles/luminaries'],
  );
}

Map<String, dynamic> _fallbackEvent(String key) {
  switch (key) {
    case 'career':
      return {
        'dasha_planets': ['Sun', 'Mars', 'Saturn', 'Mercury'],
        'houses': [10, 6, 1],
        'jupiter_gochara_houses_from_lagna': [10, 11, 1],
        'avoid_ad': ['Ketu'],
        'western': 'Saturn/Jupiter on MC.',
      };
    case 'money':
      return {
        'dasha_planets': ['Venus', 'Jupiter', 'Mercury'],
        'houses': [2, 11, 8],
        'jupiter_gochara_houses_from_lagna': [2, 11],
        'avoid_ad': ['Ketu'],
      };
    case 'home':
      return {
        'dasha_planets': ['Moon', 'Venus', 'Mars', 'Saturn'],
        'houses': [4, 12],
        'jupiter_gochara_houses_from_lagna': [4],
        'avoid_ad': ['Ketu'],
      };
    case 'children':
      return {
        'dasha_planets': ['Jupiter', 'Mercury'],
        'houses': [5],
        'jupiter_gochara_houses_from_lagna': [5],
        'avoid_ad': ['Ketu'],
      };
    default:
      return {
        'dasha_planets': ['Venus', 'Jupiter'],
        'houses': [7, 2, 8],
        'jupiter_gochara_houses_from_lagna': [1, 5, 7, 9],
        'avoid_ad': ['Ketu'],
        'western': 'Progressed Moon to natal Venus/DSC (Rushman).',
      };
  }
}

String _lordOfHouse(NatalChart chart, int house) {
  final lagna = signIndex(chart.lagnaSidereal);
  return signs[(lagna + house - 1) % 12].ruler;
}

bool _isDasaChidra(DashaSpan md, DateTime now) {
  final total = md.end.difference(md.start).inMilliseconds;
  if (total <= 0) return false;
  final used = now.difference(md.start).inMilliseconds;
  return used / total >= 0.9;
}

int _cap(NatalChart chart, int conf) {
  var c = conf;
  if (chart.input.timeUnknown) c -= 15;
  return c.clamp(20, 75);
}

double _ang(double a, double b) {
  var d = (a - b).abs() % 360;
  if (d > 180) d = 360 - d;
  return d;
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _title(String key) {
  switch (key) {
    case 'marriage':
      return 'Marriage / partner';
    case 'career':
      return 'Career';
    case 'money':
      return 'Money';
    case 'home':
      return 'Home';
    case 'children':
      return 'Children / romance';
    default:
      return key;
  }
}

List<ForecastHit> _dedupeWindows(List<ForecastHit> raw) {
  final seen = <String>{};
  final out = <ForecastHit>[];
  for (final h in raw) {
    final n = h.body.length < 40 ? h.body.length : 40;
    final k = '${h.title}|${h.verdict}|${h.body.substring(0, n)}';
    if (seen.add(k)) out.add(h);
  }
  return out.take(18).toList();
}

bool _jupiterAspectsSaturn(TransitSnap snap) {
  final j = signIndex(snap.sidereal['Jupiter']!);
  final s = signIndex(snap.sidereal['Saturn']!);
  return const {5, 7, 9}.contains(wholeSignHouse(j, s));
}

/// Flags a transit that lands on one of the graha's classically benefic
/// houses from the Moon (Charak XXIX).
String _beneficNote(PredictionKb kb, String planet, int house) {
  final benefic = kb.beneficTransitHouses(planet);
  if (benefic.isEmpty) return '';
  return benefic.contains(house)
      ? ' (a benefic gochara house for $planet)'
      : '';
}

/// Charak XXIX: a benefic gochara house from the Moon is cancelled when
/// another graha occupies the paired vedha house.
///
/// The table comes from `assets/kb/transits.json` (all nine grahas); the
/// literal below is the fallback if that module failed to load.
bool _vedhaOn(TransitSnap snap, String planet) {
  final house = snap.fromMoon[planet];
  if (house == null) return false;
  var pairs = PredictionKb.current.vedhaPairs(planet);
  if (pairs.isEmpty) {
    const fallback = <String, Map<int, int>>{
      'Sun': {3: 9, 6: 12, 10: 4, 11: 5},
      'Moon': {1: 5, 3: 9, 6: 12, 7: 2, 10: 4, 11: 8},
      'Mars': {3: 12, 6: 9, 11: 5},
      'Mercury': {2: 5, 4: 3, 6: 9, 8: 1, 10: 8, 11: 12},
      'Jupiter': {2: 12, 5: 4, 7: 3, 9: 10, 11: 8},
      'Venus': {1: 8, 2: 7, 3: 1, 4: 10, 5: 9, 8: 5, 9: 11, 11: 3, 12: 6},
      'Saturn': {3: 12, 6: 9, 11: 5},
      'Rahu': {3: 12, 6: 9, 11: 5},
      'Ketu': {3: 12, 6: 9, 11: 5},
    };
    pairs = fallback[planet] ?? const {};
  }
  final v = pairs[house];
  if (v == null) return false;
  return snap.fromMoon.entries.any(
    (e) => e.key != planet && e.value == v && !_noVedhaBetween(planet, e.key),
  );
}

/// Charak XXIX: the two father-son pairs do not cause vedha to each other.
bool _noVedhaBetween(String a, String b) {
  const pairs = [
    {'Sun', 'Saturn'},
    {'Moon', 'Mercury'},
  ];
  return pairs.any((p) => p.contains(a) && p.contains(b));
}

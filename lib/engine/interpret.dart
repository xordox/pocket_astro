import '../domain/models.dart';
import 'ashtakavarga.dart';
import 'forecast.dart';
import 'kb.dart';
import 'tables.dart';
import 'yoga.dart';

/// The chart's ashtakavarga: which houses are structurally strong, which are
/// thin, and where the slow grahas are currently standing.
LifeArea _ashtakavargaArea(NatalChart chart, ForecastReport forecast) {
  final av = forecast.now.av;
  if (av == null) {
    return const LifeArea(
      title: 'Ashtakavarga',
      confidence: 30,
      body: 'Withheld. The lagna is one of the eight contributors to every '
          'bhinnashtakavarga, so without a birth time the totals cannot reach '
          '337 and the 28-bindu average means nothing. PocketAstro does not '
          'show a seven-eighths version that would look authoritative.',
    );
  }

  final avg = PredictionKb.current.sarvaAverage;
  final rows = <String>[];
  for (var h = 1; h <= 12; h++) {
    final n = av.sarvaInHouse(h);
    rows.add('$h:$n');
  }

  final strong = av.strongHouses;
  final weak = av.weakHouses;
  final jump = av.biggestJump;

  final bits = <String>[
    'Sarvashtakavarga by house (average $avg, maximum 56): ${rows.join('  ')}. '
        'Total ${av.sarvaTotal}, which is always 337 in a correct chart.',
    if (strong.isNotEmpty)
      'Above average: ${strong.join(', ')}. These houses deliver when a graha '
          'crosses them.',
    if (weak.isNotEmpty)
      'Below average: ${weak.join(', ')}. Transits here cost more than they pay.',
    'Sharpest step: house ${jump.fromHouse} to ${jump.toHouse}, '
        '${jump.delta > 0 ? '+' : ''}${jump.delta} bindus. Charak reads a jump '
        'of this size as a real rise or fall as slow grahas cross that boundary.',
  ];

  for (final c in av.comparisons.where((c) => c.holds)) {
    bits.add(c.means);
  }

  for (final g in chart.grahas) {
    if (!avPlanets.contains(g.name) || g.dignity.isEmpty) continue;
    final note = av.dignityOverride(g.name, g.dignity);
    if (note != null) bits.add(note);
  }

  final transits = forecast.now.avTransits.values
      .where((t) => const ['Saturn', 'Jupiter', 'Mars'].contains(t.planet))
      .map((t) => t.line)
      .toList();
  if (transits.isNotEmpty) {
    bits.add('Right now:');
    bits.addAll(transits);
  }

  bits.add('Ashtakavarga is a transit filter. It is subservient to the natal '
      'promise and to the running dasha, and never creates an event on its own.');

  return LifeArea(
    title: 'Ashtakavarga',
    confidence: 62,
    body: bits.join('\n\n'),
  );
}

/// The full yoga read: what stands, and what looked like a yoga but does not.
///
/// Showing the cancelled ones matters. Kemadruma, Shakata and Kala Sarpa are
/// the three most over-sold combinations in popular astrology, and a user who
/// has been told they have one deserves to see the cancellation rather than a
/// silent omission.
LifeArea _yogaArea(NatalChart chart) {
  final report = yogaReport(chart);
  if (report.hits.isEmpty) {
    return LifeArea(
      title: 'Yogas on this chart',
      confidence: 50,
      body: chart.input.timeUnknown
          ? 'Without a birth time, ${report.skippedForNoBirthTime} of the '
              'catalogue’s yogas cannot be judged, and none of the remaining '
              'Moon- and Sun-based ones formed. House lords still operate.'
          : 'No catalogued yoga fired on this chart. That is ordinary — house '
              'lords and the dasha still run the life.',
    );
  }

  final standing = report.standing;
  final broken = report.cancelled;
  final bits = <String>[];

  if (standing.isEmpty) {
    bits.add('No yoga stands on this chart once the classical cancellations '
        'are applied.');
  } else {
    bits.add('${standing.length} yoga${standing.length == 1 ? '' : 's'} '
        'stand${standing.length == 1 ? 's' : ''} on this chart. A yoga is a '
        'promise, not an event — it pays out in the dasha of the grahas that '
        'form it.');
    bits.addAll(standing.map((h) => '• ${h.line}'));
  }

  if (broken.isNotEmpty) {
    bits.add('Formed but not standing — shown so nothing is hidden:');
    bits.addAll(broken.map((h) => '• ${h.line}'));
  }

  if (report.skippedForNoBirthTime > 0) {
    bits.add('${report.skippedForNoBirthTime} further yogas need a lagna and '
        'are withheld without a birth time.');
  }

  return LifeArea(
    title: 'Yogas on this chart',
    confidence: chart.input.timeUnknown ? 45 : 58,
    body: bits.join('\n\n'),
  );
}

/// The nine grahas. Uranus, Neptune and Pluto are carried in the chart for the
/// Western layer and must never be read as occupants of a Vedic bhava.
const _navagraha = <String>{
  'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn', 'Rahu', 'Ketu',
};

List<LifeArea> interpretChart(NatalChart chart, {DateTime? now}) {
  now ??= DateTime.now().toUtc();
  final md = chart.mahadashaAt(now);
  final ad = chart.antardashaAt(now);
  final timeOk = !chart.input.timeUnknown;
  final conf = timeOk ? 62 : 40;
  final forecast = forecastChart(chart, now: now);
  final kb = PredictionKb.current;

  String g(String n) {
    final r = chart.graha(n);
    final d = r.dignity.isEmpty ? '' : ', ${r.dignity}';
    final h = r.house == 0 ? '' : ', house ${r.house}';
    return '${r.sign} ${formatDms(r.siderealLon)} ${r.nakshatra} pada ${r.pada}$d$h';
  }

  final lagna = timeOk
      ? '${signOf(chart.lagnaSidereal).sanskrit} (${signOf(chart.lagnaSidereal).name}) ${formatDms(chart.lagnaSidereal)}'
      : 'unknown (no birth time)';

  final areas = <LifeArea>[
    LifeArea(
      title: 'Engine',
      confidence: 90,
      body:
          '${chart.engineStamp}. Ayanamsa ${chart.ayanamsa.toStringAsFixed(4)}°. '
          'Birth time source: ${chart.input.timeSource.name}. '
          '${kb.disclaimer} '
          'Library coverage: ${kb.sourceCount == 0 ? 'bundled rules' : '${kb.sourceCount} PDF sources compiled'}.',
    ),
    ...forecast.hits.map(
      (h) => LifeArea(
        title: 'Predict · ${h.title}',
        confidence: h.confidence,
        body: '${h.verdict.toUpperCase()}. ${h.body} [${h.techniques.join('; ')}]',
      ),
    ),
    if (forecast.windows.isNotEmpty)
      LifeArea(
        title: 'Predict · next 24 months',
        confidence: 58,
        body: forecast.windows
            .take(8)
            .map((w) => '${w.title}: ${w.verdict} (${w.confidence}/100). ${w.body}')
            .join('\n\n'),
      ),
    LifeArea(
      title: 'Self / lagna',
      confidence: conf,
      body: timeOk
          ? 'Lagna $lagna, nakshatra ${nakshatraOf(chart.lagnaSidereal).name} '
              '(${nakshatraOf(chart.lagnaSidereal).meaning}). '
              'Lagna lord ${signOf(chart.lagnaSidereal).ruler} is the chart’s engine. '
              'Navamsa lagna: ${signs[chart.navamsaLagna].name}.'
          : 'Without a clock time, lagna and houses are withheld. Personality is read from the Moon (${g('Moon')}) and Sun (${g('Sun')}).',
    ),
    LifeArea(
      title: 'Mind / Moon',
      confidence: 70,
      body:
          'Moon ${g('Moon')}. ${nakshatraOf(chart.graha('Moon').siderealLon).meaning}. '
          '${planetKaraka['Moon']}. '
          '${kb.planetInSign('Moon', chart.graha('Moon').sign)}',
    ),
    _nakshatraArea(chart, kb),
    _functionalArea(chart, kb),
    _placementArea(chart, kb),
    _ashtakavargaArea(chart, forecast),
    LifeArea(
      title: 'Current timing',
      confidence: md == null ? 30 : 68,
      body: md == null
          ? 'Dasha could not be computed.'
          : 'Vimshottari mahadasha ${md.lord} '
              '(${_fmt(md.start)} – ${_fmt(md.end)}). '
              '${ad == null ? '' : 'Antardasha ${ad.lord} (${_fmt(ad.start)} – ${_fmt(ad.end)}). '}'
              '${planetKaraka[md.lord]}. '
              'This is a chapter, not a sentence. Transits of Saturn and Jupiter time what this dasha already allows.',
    ),
    _area(chart, 'Career', const [10, 6, 1], 'Sun', 'Mars', 'Saturn', conf),
    _area(chart, 'Money', const [2, 11, 8], 'Jupiter', 'Venus', 'Mercury', conf),
    _area(chart, 'Marriage / partner', const [7, 2, 8], 'Venus', 'Jupiter', 'Moon', conf),
    _area(chart, 'Home / family', const [4, 12, 9], 'Moon', 'Venus', 'Saturn', conf),
    _area(chart, 'Children / romance', const [5, 7, 9], 'Jupiter', 'Venus', 'Mercury', conf),
    _healthArea(chart, kb, forecast),
    _yogaArea(chart),
    LifeArea(
      title: 'Not promised as an easy default',
      confidence: 50,
      body: _notPromised(chart),
    ),
    _remedyArea(chart, kb, md?.lord),
  ];
  return areas;
}

LifeArea _area(
  NatalChart chart,
  String title,
  List<int> houses,
  String k1,
  String k2,
  String k3,
  int conf,
) {
  if (chart.input.timeUnknown) {
    return LifeArea(
      title: title,
      confidence: 38,
      body:
          'Houses withheld. Read $k1 (${chart.graha(k1).sign}), '
          '$k2 (${chart.graha(k2).sign}), $k3 (${chart.graha(k3).sign}) as significators only.',
    );
  }
  final bits = <String>[];
  for (final h in houses) {
    final occupants = chart.grahas
        .where((g) => g.house == h && _navagraha.contains(g.name))
        .map((g) => g.name);
    final lord = _lordOfHouse(chart, h);
    String lordSit = lord;
    try {
      final row = chart.graha(lord);
      lordSit =
          '$lord sits in house ${row.house} (${row.sign}${row.dignity.isEmpty ? '' : ', ${row.dignity}'})';
    } catch (_) {}
    final lordHouse = _houseOfLord(chart, lord);
    final cell = lordHouse == 0
        ? ''
        : ' ${PredictionKb.current.lordInHouse(h, lordHouse)}';
    final occupantLines = occupants
        .map((n) => PredictionKb.current.planetInHouse(n, h))
        .where((t) => t.isNotEmpty)
        .join(' ');
    bits.add(
      'House $h (${houseTopics[h]}): lord $lordSit'
      '${occupants.isEmpty ? ', house empty — payout runs through the lord' : ', occupied by ${occupants.join(', ')}'}.'
      '$cell'
      '${occupantLines.isEmpty ? '' : ' $occupantLines'}',
    );
  }
  return LifeArea(title: title, confidence: conf, body: bits.join(' '));
}


/// Lifestyle flags drawn from the compiled body/disease tables. Never a
/// diagnosis, never a prediction — the classical body areas of the grahas the
/// chart puts under pressure, plus the current Saturn transit.
LifeArea _healthArea(
  NatalChart chart,
  PredictionKb kb,
  ForecastReport forecast,
) {
  final flags = <String>[];
  final stressed = <String>{};

  for (final name in _navagraha) {
    final GrahaRow row;
    try {
      row = chart.graha(name);
    } catch (_) {
      continue;
    }
    final inDusthana =
        !chart.input.timeUnknown && const {6, 8, 12}.contains(row.house);
    if (row.dignity == 'debilitated' || inDusthana) stressed.add(name);
  }
  if (!chart.input.timeUnknown) {
    // Lord of the 6th is the classical health significator for this lagna.
    final lagna = signIndex(chart.lagnaSidereal);
    stressed.add(signs[(lagna + 5) % 12].ruler);
  }

  for (final name in stressed) {
    final row = kb.planet(name);
    if (row.isEmpty) continue;
    final diseases = ((row['diseases'] as List?) ?? const []).join(', ');
    flags.add('$name — body: ${row['body']}. Classically watched: $diseases.');
  }

  final moonNak = kb.nakshatraNamed(
    nakshatraOf(chart.graha('Moon').siderealLon).name,
  );
  if (moonNak.isNotEmpty) {
    flags.add(
      'Birth star ${moonNak['name']} governs ${moonNak['body_part']} in the '
      'classical kalapurusha scheme.',
    );
  }

  final satH = forecast.now.fromMoon['Saturn'];
  if (forecast.now.sadeSati) {
    flags.add(
      'Sade Sati is running (Saturn $satH from the Moon). Sleep, joints and '
      'mood are the three things worth protecting deliberately.',
    );
  } else if (forecast.now.ashtamaShani) {
    flags.add(
      'Ashtama Shani is running. The classical advice is unglamorous and '
      'correct: get the checkups and the paperwork current.',
    );
  }

  return LifeArea(
    title: 'Health (not diagnosis)',
    confidence: 35,
    body: [
      'Read the 1st, 6th and 8th as lifestyle flags only.',
      ...flags,
      'PocketAstro does not diagnose, does not predict illness, and does not '
      'predict a lifespan. A gemstone will not replace sleep, a checkup, or '
      'leaving a schedule that is burning you. Take anything here to a '
      'clinician, not to a jeweller.',
    ].join(' '),
  );
}

/// Depth on the Moon's nakshatra: deity, shakti, career grain and shadow.
LifeArea _nakshatraArea(NatalChart chart, PredictionKb kb) {
  final moon = chart.graha('Moon');
  final n = nakshatraOf(moon.siderealLon);
  final row = kb.nakshatraNamed(n.name);
  if (row.isEmpty) {
    return LifeArea(
      title: 'Birth star',
      confidence: 60,
      body: '${n.name} pada ${padaOf(moon.siderealLon)} — ${n.meaning}. '
          'Ruled by ${n.lord}, deity ${n.deity}.',
    );
  }
  final pada = padaOf(moon.siderealLon);
  final padas = (row['padas'] as List?) ?? const [];
  final padaRow = pada >= 1 && pada <= padas.length
      ? padas[pada - 1] as Map<String, dynamic>
      : const <String, dynamic>{};
  final career = ((row['career'] as List?) ?? const []).join(', ');
  final bits = <String>[
    '${row['name']} pada $pada, lord ${row['lord']}.',
    'Symbol: ${row['symbol']}. Deity: ${row['deity']}.',
    'Shakti — ${row['shakti']}. ${row['shakti_result']}',
    if (padaRow.isNotEmpty)
      'Pada $pada falls in navamsa ${padaRow['navamsa']} '
          '(lord ${padaRow['navamsa_lord']}), which colours how this star acts.',
    'Gana ${row['gana']}, yoni ${row['yoni']}, nadi ${row['nadi']} — '
        'these three drive the 36-guna matching score.',
    'Muhurta class ${row['type']}: ${row['type_meaning']}',
    'Body: ${row['body_part']}.',
    if (career.isNotEmpty) 'Classical fields: $career.',
    'Shadow: ${row['shadow']}',
    if (row['gandmool'] == true)
      'Gandmool star. Classically flagged for birth shanti; read it as an '
          'intense start that matures, never as a defect.',
    if (row['gandanta'] != null)
      'This star touches a gandanta seam (${row['gandanta']}) — a karmic knot '
          'that has to be re-founded in this life rather than inherited.',
  ];
  return LifeArea(
    title: 'Birth star (nakshatra)',
    confidence: 66,
    body: bits.join(' '),
  );
}

/// Which grahas are functionally benefic, malefic, maraka or badhaka for this
/// rising sign — the table that decides whether a graha helps or hurts here.
LifeArea _functionalArea(NatalChart chart, PredictionKb kb) {
  if (chart.input.timeUnknown) {
    return const LifeArea(
      title: 'Functional nature',
      confidence: 30,
      body: 'Functional benefics and malefics depend on the lagna, which is '
          'withheld without a clock time.',
    );
  }
  final sign = signOf(chart.lagnaSidereal).name;
  final f = kb.functionalFor(sign);
  if (f.isEmpty) {
    return const LifeArea(
      title: 'Functional nature',
      confidence: 30,
      body: 'Functional table unavailable.',
    );
  }
  String join(String key) =>
      ((f[key] as List?) ?? const []).map((e) => e.toString()).join(', ');
  final yk = join('yogakaraka');
  final lagnaKendra = join('lagna_lord_also_kendra_lord');
  return LifeArea(
    title: 'Functional nature for $sign lagna',
    confidence: 64,
    body: [
      'Lagna lord ${f['lagna_lord']}.',
      'Functional benefics: ${join('functional_benefics')}.',
      'Functional malefics: ${join('functional_malefics')}.',
      'Neutral: ${join('functional_neutrals')}.',
      if (yk.isNotEmpty)
        'Yogakaraka: $yk — one graha owning both a kendra and a trikona. '
            'Its dasha is the chart’s best window.'
      else
        'No yogakaraka for this lagna; elevation has to come from a '
            'kendra-trikona lord pairing instead.',
      if (lagnaKendra.isNotEmpty)
        '$lagnaKendra rules both the lagna and a kendra — strongly benefic '
            'here, though not a yogakaraka in the strict sense.',
      'Marakas (2nd and 7th lords): ${join('marakas')}. '
          'PocketAstro reads marakas as stress and transition markers, never '
          'as mortality indicators.',
      'Badhaka: house ${f['badhaka_house']}, lord ${f['badhaka_lord']} — '
          'the classical source of obstruction for this lagna.',
      'Never strengthen a functional malefic with a gemstone.',
    ].join(' '),
  );
}

/// Sign and house reading for every graha, from the compiled 108+108 tables.
LifeArea _placementArea(NatalChart chart, PredictionKb kb) {
  const order = [
    'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn',
    'Rahu', 'Ketu',
  ];
  final lines = <String>[];
  for (final name in order) {
    final GrahaRow row;
    try {
      row = chart.graha(name);
    } catch (_) {
      continue;
    }
    final inSign = kb.planetInSign(name, row.sign);
    final inHouse =
        chart.input.timeUnknown || row.house == 0 ? '' : kb.planetInHouse(name, row.house);
    if (inSign.isEmpty && inHouse.isEmpty) continue;
    final where = chart.input.timeUnknown || row.house == 0
        ? row.sign
        : '${row.sign}, house ${row.house}';
    lines.add('$name in $where. $inSign${inHouse.isEmpty ? '' : ' $inHouse'}');
  }
  return LifeArea(
    title: 'Graha by graha',
    confidence: chart.input.timeUnknown ? 45 : 60,
    body: lines.isEmpty
        ? 'Placement tables unavailable.'
        : lines.join('\n\n'),
  );
}

/// Remedies matched to the lagna lord and the running dasha lord, leading
/// with the practical step rather than the stone.
LifeArea _remedyArea(NatalChart chart, PredictionKb kb, String? dashaLord) {
  final targets = <String>{};
  if (!chart.input.timeUnknown) {
    targets.add(signOf(chart.lagnaSidereal).ruler);
    final f = kb.functionalFor(signOf(chart.lagnaSidereal).name);
    for (final p in (f['yogakaraka'] as List?) ?? const []) {
      targets.add(p.toString());
    }
  }
  if (dashaLord != null) targets.add(dashaLord);
  if (targets.isEmpty) targets.add('Moon');

  final malefics = chart.input.timeUnknown
      ? const <String>{}
      : ((kb.functionalFor(signOf(chart.lagnaSidereal).name)['functional_malefics']
                  as List?) ??
              const [])
          .map((e) => e.toString())
          .toSet();

  final bits = <String>[];
  for (final t in targets) {
    final r = kb.remedyFor(t);
    if (r.isEmpty) continue;
    final blocked = malefics.contains(t);
    bits.add(
      '$t — do this: ${r['practical']} '
      'Mantra: ${r['beej_mantra']} (${r['japa']} repetitions, ${r['day']}). '
      'Charity: ${((r['charity'] as List?) ?? const []).join(', ')}. '
      '${blocked ? 'Gemstone withheld: $t is a functional malefic for this lagna, so the stone (${r['gem']}) is the wrong tool — use the charity and the discipline instead.' : 'Stone if you want one: ${r['gem']}, ${r['metal']}, ${r['finger']}, first worn on ${r['day']}.'}'
      '${r['caution'] == null ? '' : ' ${r['caution']}'}',
    );
  }
  bits.add(
    'A remedy is a structured intention. Mantra, charity and discipline change '
    'behaviour, and behaviour is most of what a dasha actually operates on. No '
    'stone replaces sleep, a medical appointment, a lawyer, or leaving a job '
    'that is burning you.',
  );
  return LifeArea(
    title: 'Remedies that match this chart',
    confidence: 55,
    body: bits.join('\n\n'),
  );
}

/// House 1..12 occupied by [lord], or 0 when houses are withheld.
int _houseOfLord(NatalChart chart, String lord) {
  try {
    return chart.graha(lord).house;
  } catch (_) {
    return 0;
  }
}

String _lordOfHouse(NatalChart chart, int house) {
  final lagna = signIndex(chart.lagnaSidereal);
  final sign = (lagna + house - 1) % 12;
  return signs[sign].ruler;
}

String _notPromised(NatalChart chart) {
  if (chart.input.timeUnknown) {
    return 'Without lagna, do not chase house-specific promises. Time the clock first.';
  }
  final bits = <String>[];
  final tenthEmpty = chart.grahas
      .where((g) => g.house == 10 && _navagraha.contains(g.name))
      .isEmpty;
  if (tenthEmpty) {
    bits.add('The 10th is empty — career still runs through the 10th lord; neglecting visibility is the usual miss.');
  }
  final ketu5 = chart.grahas.any((g) => g.name == 'Ketu' && g.house == 5);
  if (ketu5) bits.add('Ketu in the 5th: children/romance/speculation may thin or spiritualize rather than follow a family timetable.');
  if (bits.isEmpty) {
    bits.add('Lottery, overnight fame, and a conflict-free life are not the fruit of a real kundali. Built name and timed work are.');
  }
  return bits.join(' ');
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

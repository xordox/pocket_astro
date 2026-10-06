/// Builds a natal chart from a birth record.
///
/// Rewritten so that the chart is assembled from a real [Sky] rather than a
/// bag of longitudes. Concretely, what changed:
///
///   * Western houses come from the reader's chosen system, and the tenth
///     cusp is the midheaven (G-02). The old `_placidusLike` returned equal
///     house under a borrowed name and never used the MC at all.
///   * Every graha carries speed, so retrograde motion exists (G-01).
///   * Latitude and declination survive (G-08).
///   * A bhava chalit house sits alongside the whole-sign one (G-16).
///   * The chart records the ayanamsa, house system, node type and
///     topocentric mode it was computed under (G-46).
library;

import '../domain/models.dart';
import 'aspects.dart';
import 'astronomy.dart';
import 'dasha.dart';
import 'dignity.dart';
import 'tables.dart';
import 'yoga.dart';

/// The bodies a Vedic chart lists, in the classical order.
const _vedicOrder = [
  'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn', 'Rahu', 'Ketu',
];

/// Everything else a Western chart wants alongside them.
const _westernExtras = [
  'Uranus', 'Neptune', 'Pluto', 'Chiron', 'Lilith', 'Ceres', 'Pallas', 'Juno', 'Vesta',
];

/// A one-line description of how this chart was computed.
///
/// Built per chart now rather than being a constant, because every part of it
/// is a reader's choice.
String engineStampFor(ChartSettings s) => [
      'PocketAstro 0.2',
      s.ayanamsa == Ayanamsa.none ? 'tropical' : s.ayanamsa.label,
      '${s.vedicHouseSystem.label} Vedic',
      '${s.houseSystem.label} Western',
      s.trueNode ? 'true node' : 'mean node',
      if (s.topocentric) 'topocentric',
      'VSOP87/ELP2000 truncation with ΔT, nutation and aberration (offline)',
    ].join(' · ');

/// Kept so that call sites that only want a label still compile.
const engineStamp =
    'PocketAstro 0.2 · Lahiri · whole-sign Vedic · Placidus Western · mean node · '
    'VSOP87/ELP2000 truncation with ΔT, nutation and aberration (offline)';

NatalChart buildChart(
  BirthInput input,
  DateTime utc, {
  ChartSettings settings = const ChartSettings(),
}) {
  // The Vedic chart wants whole sign by default; the chalit column wants
  // Sripati. Both are computed so the reader can see them disagree.
  final effective = settings.copyWith(
    vedicHouseSystem: settings.vedicHouseSystem,
  );

  final sky = computeSky(
    utc: utc,
    latitude: input.place.latitude,
    longitudeEast: input.place.longitude,
    settings: effective,
    bodyNames: [
      ..._vedicOrder,
      ...(effective.includeMinorBodies
          ? _westernExtras
          : const ['Uranus', 'Neptune', 'Pluto']),
    ],
  );

  // A separate Sripati solution for the chalit column, independent of whatever
  // the reader picked for the main Vedic chart.
  final chalit = computeHouses(
    ramc: sky.localSiderealTime,
    latitude: input.place.latitude,
    obliquity: sky.obliquity,
    system: HouseSystem.sripati,
  );

  final lagnaSid = sky.siderealAscendant;
  final lagnaSign = signIndex(lagnaSid);
  final noTime = input.timeUnknown;

  GrahaRow row(BodyPosition b) {
    final sid = norm360(b.longitude - sky.ayanamsaValue);
    final s = signOf(sid);
    return GrahaRow(
      name: b.name,
      tropicalLon: b.longitude,
      siderealLon: sid,
      sign: s.name,
      house: noTime ? 0 : wholeSignHouse(lagnaSign, s.index),
      nakshatra: nakshatraOf(sid).name,
      pada: padaOf(sid),
      dignity: dignityLabel(b.name, sid),
      westernHouse: noTime ? 0 : sky.western.houseOf(b.longitude),
      speed: b.speed,
      latitude: b.latitude,
      declination: b.declination,
      chalitHouse: noTime ? 0 : chalit.houseOf(b.longitude),
    );
  }

  final grahas = <GrahaRow>[
    if (!noTime)
      GrahaRow(
        name: 'Lagna',
        tropicalLon: sky.western.ascendant,
        siderealLon: lagnaSid,
        sign: signOf(lagnaSid).name,
        house: 1,
        nakshatra: nakshatraOf(lagnaSid).name,
        pada: padaOf(lagnaSid),
        dignity: '',
        westernHouse: 1,
        chalitHouse: 1,
      ),
    for (final name in [..._vedicOrder, ..._westernExtras])
      if (sky.bodies[name] != null) row(sky.bodies[name]!),
  ];

  final moon = grahas.firstWhere((g) => g.name == 'Moon');
  final dasha = vimshottari(birth: utc, moonSidereal: moon.siderealLon);

  return NatalChart(
    input: input,
    utc: utc,
    jd: sky.jdUt,
    ayanamsa: sky.ayanamsaValue,
    lagnaSidereal: lagnaSid,
    lagnaTropical: sky.western.ascendant,
    mcTropical: sky.western.midheaven,
    grahas: grahas,
    navamsaLagna: navamsaSign(lagnaSid),
    dasha: dasha.mahadashas,
    antardashas: dasha.antardashas,
    westernAspects: westernAspects(grahas, sky: sky),
    yogas: _detectYogas(grahas, lagnaSid, noTime),
    engineStamp: engineStampFor(effective),
    sky: sky,
    settings: effective,
  );
}

/// Yogas plus the plain chart facts worth stating alongside them.
///
/// The catalogue lives in `yoga.dart`; this adds the notes that are chart facts
/// rather than named combinations, and now runs the cancellation rules that the
/// old build only told the reader to go and check for themselves (G-17).
List<String> _detectYogas(
  List<GrahaRow> grahas,
  double lagnaSidereal,
  bool noLagna,
) {
  final out = <String>[];
  final lagnaSign = signIndex(lagnaSidereal);

  final report = detectYogas(
    grahas: grahas,
    lagnaSidereal: lagnaSidereal,
    noLagna: noLagna,
  );
  for (final h in report.standing) {
    out.add(h.line);
  }

  GrahaRow? g(String n) {
    for (final x in grahas) {
      if (x.name == n) return x;
    }
    return null;
  }

  if (!noLagna) {
    for (final p in yogakarakaFor(lagnaSign)) {
      final row = g(p);
      if (row != null) {
        out.add(
          'Yogakaraka $p for ${signs[lagnaSign].name} lagna sits in house '
          '${row.house} (${row.sign}'
          '${row.dignity.isEmpty ? '' : ', ${row.dignity}'}). Its dasha is the '
          'chart’s best window.',
        );
      }
    }
  }

  // Retrograde is a chart fact worth stating plainly, and until now the app
  // could not state it at all.
  final vakri = grahas.where((x) => x.showsMotionMarker).toList();
  if (vakri.isNotEmpty) {
    out.add(
      'Vakri (retrograde): ${vakri.map((x) => x.name).join(', ')}. A retrograde '
      'graha gives its results inwardly and late rather than not at all.',
    );
  }

  for (final p in const ['Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn']) {
    final row = g(p);
    if (row == null) continue;
    if (row.dignity == 'exalted') out.add('$p is exalted in ${row.sign}.');
    if (row.dignity == 'debilitated') {
      final cancel = neechaBhangaFor(p, grahas, lagnaSign);
      if (cancel != null) {
        out.add('$p is debilitated in ${row.sign}, but neecha bhanga applies: '
            '${cancel.reason} Treat it as raised, not ruined.');
      } else {
        out.add('$p is debilitated in ${row.sign} and no neecha bhanga applies.');
      }
    }
  }

  if (report.hits.isEmpty) {
    final moon = g('Moon');
    final jup = g('Jupiter');
    if (moon != null && jup != null) {
      final d =
          (signIndex(moon.siderealLon) - signIndex(jup.siderealLon)).abs() % 12;
      if (const {0, 3, 6, 9}.contains(d)) {
        out.add('Gaja Kesari: Moon and Jupiter in kendra from each other.');
      }
    }
  }
  return out;
}

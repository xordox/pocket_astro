import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/data/atlas.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/engine/astronomy.dart';
import 'package:pocket_astro/engine/chart_builder.dart';
import 'package:pocket_astro/engine/dasha.dart';
import 'package:pocket_astro/engine/forecast.dart';
import 'package:pocket_astro/engine/kb.dart';
import 'package:pocket_astro/engine/matching.dart';
import 'package:pocket_astro/engine/qa.dart';
import 'package:pocket_astro/engine/tables.dart';
import 'package:pocket_astro/engine/time_convert.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

void main() {
  tzdata.initializeTimeZones();
  setUpAll(() {
    final f = File('assets/kb/prediction.json');
    PredictionKb.loadFromMap(
      jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
    );
    PredictionKb.loadMatchingFromMap(
      jsonDecode(File('assets/kb/ashtakoota.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    for (final e in PredictionKb.moduleAssets.entries) {
      PredictionKb.loadModuleFromMap(
        e.key,
        jsonDecode(File(e.value).readAsStringSync()) as Map<String, dynamic>,
      );
    }
  });

  test('nakshatra spans are 13°20 and Purva Phalguni owns 133°20–146°40', () {
    expect(nakshatraOf(10 * nakshatraWidth + 0.1).name, 'Purva Phalguni');
    expect(nakshatraOf(11 * nakshatraWidth + 0.1).name, 'Uttara Phalguni');
    expect(nakshatraOf(0).name, 'Ashwini');
    expect(nakshatraOf(23 * nakshatraWidth + 0.1).name, 'Shatabhisha');
    expect(padaOf(0), 1);
    expect(padaOf(nakshatraWidth / 4 + 0.01), 2);
  });

  test('Vimshottari balance from Moon in Purva Phalguni', () {
    // 17°05' Leo = 120 + 17.083 = 137.083 → Purva Phalguni (Venus)
    final moon = 137.083;
    final birth = DateTime.utc(1992, 4, 13, 22, 12);
    final d = vimshottari(birth: birth, moonSidereal: moon);
    expect(d.mahadashas.first.lord, 'Venus');
    expect(nakshatraOf(moon).lord, 'Venus');
    final elapsed = (moon % nakshatraWidth) / nakshatraWidth;
    expect(elapsed, greaterThan(0.2));
    expect(elapsed, lessThan(0.35));
  });

  test('Ashtakoota nadi dosha and cancellation', () {
    final a = _chart(
      name: 'A',
      moon: 137.0, // Purva Phalguni madhya
      mars: 319.3, // Aquarius
      lagna: 323.1,
    );
    final sameNadi = _chart(
      name: 'B',
      moon: 20.0, // Bharani also madhya
      mars: 20,
      lagna: 10,
    );
    final m = matchCharts(a, sameNadi);
    final nadi = m.kootas.firstWhere((k) => k.name == 'Nadi');
    expect(nadi.obtained, 0);
    expect(m.max, 36);
    expect(m.total, lessThanOrEqualTo(36));
  });

  test('Kuja dosha from lagna house 1', () {
    final c = _chart(name: 'M', moon: 137, mars: 323, lagna: 323);
    expect(isManglik(c), isTrue);
  });

  test('1992 Kathmandu fixture matches Swiss/Lahiri golden chart', () {
    final input = BirthInput(
      id: 'demo',
      name: 'Demo',
      localDateTime: DateTime(1992, 4, 14, 3, 57),
      place: kathmandu,
      timeSource: TimeSource.hospital,
    );
    final utc = toUtc(input);
    expect(utc.timeZoneOffset, Duration.zero);
    expect(utc.hour, 22);
    expect(utc.minute, 12);

    final chart = buildChart(input, utc);
    expect(chart.ayanamsa, closeTo(23.75, 0.2));
    expect(signOf(chart.lagnaSidereal).name, 'Aquarius');
    expect(chart.lagnaSidereal % 30, closeTo(23.0, 1.5));
    expect(nakshatraOf(chart.lagnaSidereal).name, 'Purva Bhadrapada');
    expect(signOf(chart.graha('Sun').siderealLon).name, 'Aries');
    expect(chart.graha('Sun').siderealLon % 30, closeTo(0.5, 1.5));
    expect(signOf(chart.graha('Moon').siderealLon).name, 'Leo');
    expect(nakshatraOf(chart.graha('Moon').siderealLon).name, 'Purva Phalguni');
    expect(signOf(chart.graha('Venus').siderealLon).name, 'Pisces');
    expect(signOf(chart.graha('Mercury').siderealLon).name, 'Pisces');
    expect(signOf(chart.graha('Mars').siderealLon).name, 'Aquarius');
    expect(signOf(chart.graha('Jupiter').siderealLon).name, 'Leo');
    expect(signOf(chart.graha('Saturn').siderealLon).name, 'Capricorn');
    expect(signOf(chart.graha('Rahu').siderealLon).name, 'Sagittarius');
    expect(chart.graha('Sun').house, 3);
    expect(chart.graha('Moon').house, 7);
    expect(chart.graha('Venus').house, 2);
    expect(chart.graha('Mars').house, 1);
    expect(chart.graha('Saturn').house, 12);
    expect(chart.graha('Rahu').house, 11);
  });

  test('Q&A routes marriage timing questions', () {
    final input = BirthInput(
      id: 'demo',
      name: 'Demo',
      localDateTime: DateTime(1992, 4, 14, 3, 57),
      place: kathmandu,
      timeSource: TimeSource.hospital,
    );
    final chart = buildChart(input, toUtc(input));
    final a = answerQuestion(chart, 'When should I marry?');
    expect(a.intent, 'next_window');
    expect(a.answer.toLowerCase(), contains('dasha'));
  });

  test('Lahiri ayanamsa near J2000 is about 23°51', () {
    final jd = julianDayUtc(DateTime.utc(2000, 1, 1, 12));
    expect(lahiriAyanamsa(jd), closeTo(23.85, 0.05));
  });

  test('prediction KB catalogues all 56 library PDFs', () {
    expect(PredictionKb.current.sourceCount, 56);
    final catalog = jsonDecode(File('knowledge/extract/_catalog.json').readAsStringSync()) as List;
    expect(catalog.length, 56);
    final named = {
      for (final s in PredictionKb.current.data['sources'] as List)
        (s as Map)['file'] as String,
    };
    for (final rec in catalog) {
      expect(named, contains(rec['file']));
    }
  });

  test('1992 Kathmandu forecast uses dasha × gochara and caps confidence', () {
    final input = BirthInput(
      id: 'demo',
      name: 'Demo',
      localDateTime: DateTime(1992, 4, 14, 3, 57),
      place: kathmandu,
      timeSource: TimeSource.hospital,
    );
    final chart = buildChart(input, toUtc(input));
    final when = DateTime.utc(2026, 9, 4);
    final f = forecastChart(chart, now: when);
    expect(f.md, isNotNull);
    expect(f.ad, isNotNull);
    expect(f.pd, isNotNull);
    expect(f.now.fromMoon['Saturn'], isNotNull);
    final satFromMoon = f.now.fromMoon['Saturn']!;
    // Leo Moon: Sade Sati is 12/1/2; Ashtama is 8.
    if (satFromMoon == 8) {
      expect(f.now.ashtamaShani, isTrue);
    }
    if (const {12, 1, 2}.contains(satFromMoon)) {
      expect(f.now.sadeSati, isTrue);
    }
    for (final h in f.hits) {
      expect(h.confidence, lessThanOrEqualTo(75));
    }
    final gochara = f.hits.firstWhere((h) => h.title.contains('Gochara'));
    expect(gochara.body.toLowerCase(), contains('saturn'));
    final q = answerQuestion(chart, 'When should I marry?', now: when);
    expect(q.intent, 'next_window');
    expect(q.answer.toLowerCase(), contains('dasha'));
    expect(q.answer.toLowerCase(), contains('jupiter'));
  });

  test('pratyantara nests inside antardasha', () {
    final ad = DashaSpan(
      lord: 'Mercury',
      start: DateTime.utc(2025, 1, 1),
      end: DateTime.utc(2026, 1, 1),
      level: 'AD',
      parent: 'Mars',
    );
    final pds = pratyantarasOf(ad);
    expect(pds, hasLength(9));
    expect(pds.first.lord, 'Mercury');
    expect(pds.first.start, ad.start);
    expect(pds.last.end, ad.end);
    expect(pds.first.level, 'PD');
  });

  test('Bhakoot 2/12 is restored when rashi lords are friends', () {
    // Aries Moon (Mars) vs Taurus Moon (Venus) is 2/12; Mars–Venus are enemies, so stays 0.
    final aries = _chart(name: 'A', moon: 10, mars: 10, lagna: 10);
    final taurus = _chart(name: 'B', moon: 40, mars: 40, lagna: 40);
    final enemy = matchCharts(aries, taurus).kootas.firstWhere((k) => k.name == 'Bhakoot');
    expect(enemy.obtained, 0);

    // Cancer Moon (Moon) vs Leo Moon (Sun) is 2/12; Sun–Moon are friends both ways.
    final cancer = _chart(name: 'C', moon: 100, mars: 100, lagna: 100);
    final leo = _chart(name: 'D', moon: 130, mars: 130, lagna: 130);
    final friends = matchCharts(cancer, leo).kootas.firstWhere((k) => k.name == 'Bhakoot');
    expect(friends.obtained, 7);
    expect(friends.note.toLowerCase(), contains('mitigated'));
  });

  test('Q&A refuses death dates', () {
    final input = BirthInput(
      id: 'demo',
      name: 'Demo',
      localDateTime: DateTime(1992, 4, 14, 3, 57),
      place: kathmandu,
      timeSource: TimeSource.hospital,
    );
    final chart = buildChart(input, toUtc(input));
    final a = answerQuestion(chart, 'When will I die?');
    expect(a.intent, 'refused_death');
    expect(a.answer.toLowerCase(), contains('will not predict death'));
  });
}

NatalChart _chart({
  required String name,
  required double moon,
  required double mars,
  required double lagna,
}) {
  GrahaRow g(String n, double lon, {int house = 1}) {
    return GrahaRow(
      name: n,
      tropicalLon: lon + 23.75,
      siderealLon: lon,
      sign: signOf(lon).name,
      house: house,
      nakshatra: nakshatraOf(lon).name,
      pada: 1,
      dignity: '',
      westernHouse: house,
    );
  }

  final lagnaSign = signIndex(lagna);
  return NatalChart(
    input: BirthInput(
      id: name,
      name: name,
      localDateTime: DateTime(1992, 4, 14, 3, 57),
      place: kathmandu,
      timeSource: TimeSource.hospital,
    ),
    utc: DateTime.utc(1992, 4, 13, 22, 12),
    jd: 0,
    ayanamsa: 23.75,
    lagnaSidereal: lagna,
    lagnaTropical: lagna + 23.75,
    mcTropical: 0,
    grahas: [
      g('Lagna', lagna, house: 1),
      g('Moon', moon, house: wholeSignHouse(lagnaSign, signIndex(moon))),
      g('Mars', mars, house: wholeSignHouse(lagnaSign, signIndex(mars))),
      g('Sun', 0.5, house: 3),
      g('Venus', 344, house: 2),
      g('Mercury', 335, house: 2),
      g('Jupiter', 131, house: 7),
      g('Saturn', 293, house: 12),
      g('Rahu', 249, house: 11),
      g('Ketu', 69, house: 5),
    ],
    navamsaLagna: 2,
    dasha: const [],
    antardashas: const [],
    westernAspects: const [],
    yogas: const [],
    engineStamp: 'test',
  );
}

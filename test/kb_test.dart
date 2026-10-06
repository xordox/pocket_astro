import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/engine/kb.dart';
import 'package:pocket_astro/engine/tables.dart';

/// Integrity checks on the compiled knowledge base. These guard the data the
/// forecast engine reads: if a builder in `knowledge/build/` regresses, these
/// fail before a user sees a wrong reading.
void main() {
  setUpAll(() {
    PredictionKb.loadFromMap(
      jsonDecode(File('assets/kb/prediction.json').readAsStringSync())
          as Map<String, dynamic>,
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

  test('every declared module asset exists and parses', () {
    for (final e in PredictionKb.moduleAssets.entries) {
      expect(File(e.value).existsSync(), isTrue, reason: '${e.value} missing');
      expect(PredictionKb.modules[e.key], isNotEmpty, reason: '${e.key} empty');
    }
  });

  test('bhinnashtakavarga totals match the classical 337', () {
    final kb = PredictionKb.current;
    const expected = {
      'Sun': 48,
      'Moon': 49,
      'Mars': 39,
      'Mercury': 54,
      'Jupiter': 56,
      'Venus': 52,
      'Saturn': 39,
    };
    var grand = 0;
    for (final e in expected.entries) {
      final rows = kb.bhinnashtakavarga[e.key] as Map<String, dynamic>;
      expect(rows.length, 8, reason: '${e.key} needs 8 contributors');
      var total = 0;
      for (final v in rows.values) {
        final houses = (v as List).map((h) => (h as num).toInt()).toList();
        expect(houses.toSet().length, houses.length,
            reason: '${e.key} has a duplicate house');
        expect(houses.every((h) => h >= 1 && h <= 12), isTrue);
        total += houses.length;
      }
      expect(total, e.value, reason: '${e.key} bindu total');
      grand += total;
    }
    expect(grand, 337);
    expect(kb.sarvaAverage, 28);
    expect(kb.kakshyaOrder.first, 'Saturn');
    expect(kb.kakshyaOrder.length, 8);
  });

  test('bhinnashtakavarga readings cover 0..8 bindus', () {
    for (var i = 0; i <= 8; i++) {
      expect(PredictionKb.current.bhinnaReading(i), isNotEmpty);
    }
  });

  test('27 nakshatras, contiguous spans, 4 padas each', () {
    final rows =
        PredictionKb.modules['nakshatras']!['nakshatras'] as List<dynamic>;
    expect(rows.length, 27);
    for (var i = 0; i < 27; i++) {
      final n = rows[i] as Map<String, dynamic>;
      expect(n['name'], nakshatras[i].name);
      expect(n['lord'], nakshatras[i].lord);
      expect(n['gana'], nakshatras[i].gana);
      expect(n['nadi'], nakshatras[i].nadi);
      expect(n['yoni'], nakshatras[i].yoni);
      expect((n['start_deg'] as num).toDouble(),
          closeTo(i * nakshatraWidth, 0.001));
      expect((n['padas'] as List).length, 4);
      expect(n['shakti'], isNotEmpty);
      expect(n['deity'], isNotEmpty);
      expect((n['career'] as List), isNotEmpty);
    }
  });

  test('nakshatra pada navamsas agree with the engine', () {
    final rows =
        PredictionKb.modules['nakshatras']!['nakshatras'] as List<dynamic>;
    for (final r in rows) {
      for (final p in (r as Map)['padas'] as List) {
        final mid = ((p as Map)['start_deg'] as num).toDouble() +
            (nakshatraWidth / 8);
        expect(signs[navamsaSign(mid)].name, p['navamsa'],
            reason: '${r['name']} pada ${p['pada']}');
      }
    }
  });

  test('144 house-lord cells and 12 house records', () {
    final kb = PredictionKb.current;
    for (var owner = 1; owner <= 12; owner++) {
      expect(kb.house(owner)['topics'], isNotEmpty);
      for (var field = 1; field <= 12; field++) {
        expect(kb.lordInHouse(owner, field), isNotEmpty,
            reason: 'cell $owner-$field');
      }
    }
  });

  test('every graha has sign and house interpretations and dignity', () {
    final kb = PredictionKb.current;
    const grahas = [
      'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn',
      'Rahu', 'Ketu',
    ];
    for (final g in grahas) {
      final row = kb.planet(g);
      expect(row, isNotEmpty, reason: g);
      for (final s in signs) {
        expect(kb.planetInSign(g, s.name), isNotEmpty, reason: '$g in ${s.name}');
      }
      for (var h = 1; h <= 12; h++) {
        expect(kb.planetInHouse(g, h), isNotEmpty, reason: '$g in house $h');
      }
      expect(row['karaka'], isNotEmpty);
      expect(row['beej_mantra'], isNotEmpty);
    }
  });

  test('KB dignity agrees with the engine tables for the seven grahas', () {
    final kb = PredictionKb.current;
    for (final e in dignity.entries) {
      final row = kb.planet(e.key);
      expect((row['exalt'] as Map)['sign'], signs[e.value.exaltSign].name,
          reason: '${e.key} exaltation');
      expect((row['debil'] as Map)['sign'], signs[e.value.debilSign].name,
          reason: '${e.key} debilitation');
      expect(
        (row['own'] as List).map((s) => s.toString()).toSet(),
        e.value.own.map((i) => signs[i].name).toSet(),
        reason: '${e.key} own signs',
      );
    }
  });

  test('functional tables agree with the engine yogakaraka detector', () {
    final kb = PredictionKb.current;
    for (var i = 0; i < 12; i++) {
      final row = kb.functionalFor(signs[i].name);
      expect(row['lagna_lord'], signs[i].ruler);
      expect(
        (row['yogakaraka'] as List).map((e) => e.toString()).toSet(),
        yogakarakaFor(i),
        reason: '${signs[i].name} yogakaraka',
      );
      final lords = row['house_lords'] as Map<String, dynamic>;
      for (var h = 1; h <= 12; h++) {
        expect(lords['$h'], signs[(i + h - 1) % 12].ruler);
      }
    }
  });

  test('yogas all carry a condition, an effect and a source', () {
    final yogas = PredictionKb.current.yogas;
    expect(yogas.length, greaterThanOrEqualTo(60));
    final ids = <String>{};
    for (final y in yogas) {
      expect(ids.add(y['id'] as String), isTrue, reason: 'duplicate ${y['id']}');
      expect((y['conditions'] as List), isNotEmpty, reason: '${y['id']}');
      expect(y['effect'], isNotEmpty);
      expect(y['source'], isNotEmpty);
      expect(y['match'], anyOf('all', 'any'));
    }
    expect(ids, contains('gaja_kesari'));
    expect(ids, contains('neecha_bhanga'));
    expect(ids, contains('vipreeta_harsha'));
  });

  test('every dosha carries cancellations and a never-clause', () {
    final doshas = PredictionKb.current.doshas;
    expect(doshas.length, greaterThanOrEqualTo(12));
    for (final d in doshas) {
      expect((d['cancellations'] as List), isNotEmpty, reason: '${d['id']}');
      expect(d['honest_reading'], isNotEmpty);
      expect(d['never'], isNotEmpty);
    }
    expect(PredictionKb.current.dosha('kuja')['name'], contains('Manglik'));
  });

  test('Vimshottari years in the KB match the engine and total 120', () {
    final v =
        PredictionKb.modules['dashas']!['vimshottari'] as Map<String, dynamic>;
    final years = v['years'] as Map<String, dynamic>;
    var total = 0.0;
    for (final e in vimshottariYears.entries) {
      expect((years[e.key] as num).toDouble(), e.value, reason: e.key);
      total += e.value;
    }
    expect(total, 120);
    expect((v['order'] as List).map((e) => e.toString()).toList(),
        vimshottariOrder);
  });

  test('81 MD/AD cells with correct sub-period lengths', () {
    final m =
        PredictionKb.modules['dashas']!['md_ad_matrix'] as Map<String, dynamic>;
    expect(m.length, 81);
    for (final md in vimshottariOrder) {
      var sum = 0.0;
      for (final ad in vimshottariOrder) {
        final cell = m['$md-$ad'] as Map<String, dynamic>;
        final yrs = (cell['ad_years'] as num).toDouble();
        expect(yrs,
            closeTo(vimshottariYears[md]! * vimshottariYears[ad]! / 120, 1e-3));
        sum += yrs;
      }
      expect(sum, closeTo(vimshottariYears[md]!, 1e-2), reason: '$md total');
    }
  });

  test('gochara covers 9 grahas x 12 houses, with vedha pairs in range', () {
    final kb = PredictionKb.current;
    const grahas = [
      'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn',
      'Rahu', 'Ketu',
    ];
    for (final g in grahas) {
      for (var h = 1; h <= 12; h++) {
        expect(kb.gocharaFromMoon(g, h), isNotEmpty, reason: '$g house $h');
      }
      final benefic = kb.beneficTransitHouses(g);
      expect(benefic, isNotEmpty, reason: '$g benefic houses');
      final pairs = kb.vedhaPairs(g);
      expect(pairs.keys.toSet(), benefic.toSet(),
          reason: '$g vedha keys must match its benefic houses');
      for (final e in pairs.entries) {
        expect(e.value, inInclusiveRange(1, 12));
        expect(e.value, isNot(e.key), reason: '$g house ${e.key} vedhas itself');
      }
    }
    // Charak XXIX spot checks.
    expect(kb.vedhaPairs('Jupiter')[11], 8);
    expect(kb.vedhaPairs('Saturn')[3], 12);
    expect(kb.vedhaPairs('Sun')[10], 4);
    expect(kb.vedhaPairs('Moon')[7], 2);
  });

  test('16 divisional charts with vimshopaka weights summing to 20', () {
    final d = PredictionKb.modules['divisionals'] as Map<String, dynamic>;
    expect((d['vargas'] as List).length, 16);
    final schemes = d['vimshopaka_schemes'] as Map<String, dynamic>;
    for (final name in ['shadvarga', 'saptavarga', 'dashavarga', 'shodashavarga']) {
      final w = (schemes[name] as Map)['weights'] as Map<String, dynamic>;
      final total = w.values.fold<double>(0, (a, b) => a + (b as num));
      expect(total, closeTo(20, 1e-6), reason: name);
    }
    expect(PredictionKb.current.varga('D9')['name'], 'Navamsha');
    expect(PredictionKb.current.varga('D10')['name'], 'Dashamsha');
  });

  test('panchanga has 30 tithis, 27 yogas and 11 karanas', () {
    final p = PredictionKb.modules['panchanga'] as Map<String, dynamic>;
    final t = p['tithi'] as Map<String, dynamic>;
    expect((t['list'] as List).length, 30);
    expect(((p['yoga'] as Map)['names'] as List).length, 27);
    final k = p['karana'] as Map<String, dynamic>;
    expect((k['movable'] as List).length + (k['fixed'] as List).length, 11);
    expect(PredictionKb.current.tithiGroupMeaning('rikta'), isNotEmpty);
    expect(PredictionKb.current.muhurtaFor('marriage')['nakshatra'], isNotEmpty);
    // Rahu kaal segments must be a permutation of 1..8 minus one.
    final rahu = ((p['inauspicious_periods'] as Map)['rahu_kaal']
        as Map)['segments'] as Map<String, dynamic>;
    expect(rahu.length, 7);
    expect(rahu.values.map((e) => (e as num).toInt()).toSet().length, 7);
  });

  test('remedies cover all nine grahas and lead with a practical step', () {
    final kb = PredictionKb.current;
    for (final g in [
      'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn',
      'Rahu', 'Ketu',
    ]) {
      final r = kb.remedyFor(g);
      expect(r['gem'], isNotEmpty, reason: g);
      expect(r['beej_mantra'], isNotEmpty, reason: g);
      expect(r['practical'], isNotEmpty, reason: g);
      expect((r['charity'] as List), isNotEmpty, reason: g);
    }
    expect(kb.remedyFor('Saturn')['caution'], isNotEmpty);
  });

  test('every interpretation topic has a full prediction recipe', () {
    final topics =
        PredictionKb.modules['interpretation']!['topics'] as List<dynamic>;
    expect(topics.length, greaterThanOrEqualTo(12));
    for (final t in topics.cast<Map<String, dynamic>>()) {
      expect((t['houses'] as List), isNotEmpty, reason: '${t['key']} houses');
      expect((t['karakas'] as List), isNotEmpty);
      expect((t['evidence'] as List), isNotEmpty);
      expect(t['language'], isNotEmpty);
      expect(PredictionKb.current.topic(t['key'] as String), isNotEmpty);
      // Every topic must be reachable through the legacy event_keys shortcut.
      expect(PredictionKb.current.eventKey(t['key'] as String), isNotNull,
          reason: '${t['key']} missing from event_keys');
    }
    expect(PredictionKb.current.orderOfJudgment.length, greaterThan(8));
    expect(PredictionKb.current.confidenceModel['ceiling'], 75);
  });

  test('360 degree symbols, one per tropical degree', () {
    final rows = PredictionKb.modules['degrees']!['degrees'] as List<dynamic>;
    expect(rows.length, 360);
    for (var i = 0; i < 360; i++) {
      final r = rows[i] as Map<String, dynamic>;
      expect(r['index'], i);
      expect(r['sign'], signs[i ~/ 30].name);
      expect(r['degree'], i % 30 + 1);
      expect(r['symbol'], isNotEmpty);
    }
    expect(PredictionKb.current.degreeSymbol(0.4)['label'], 'Aries 1');
    expect(PredictionKb.current.degreeSymbol(359.9)['label'], 'Pisces 30');
    expect(PredictionKb.current.degreeSymbol(120.0)['label'], 'Leo 1');
  });

  test('strength module exposes shadbala minima and combustion orbs', () {
    final kb = PredictionKb.current;
    expect(kb.requiredRupas('Mercury'), 7.0);
    expect(kb.requiredRupas('Saturn'), 5.0);
    expect(kb.combustionOrb('Moon'), 12.0);
    expect(kb.combustionOrb('Mars'), 17.0);
    expect(kb.combustionOrb('Rahu'), 0.0);
  });

  test('refusal list is present and covers the hard limits', () {
    final r = PredictionKb.current.data['refusals'] as Map<String, dynamic>;
    final never = (r['never_predict'] as List).join(' ').toLowerCase();
    for (final term in ['death', 'diagnosis', 'sex of an unborn', 'lottery']) {
      expect(never, contains(term));
    }
    expect(r['crisis_response'], contains('988'));
  });
}

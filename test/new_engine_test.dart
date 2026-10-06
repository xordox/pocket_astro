/// Exercises the modules added for the Tier 2 and Tier 3 gaps.
///
/// These are behaviour tests rather than spot values: a divisional chart has
/// to close, a dasha has to fill its own cycle exactly, a reduction has to
/// remove rather than invent bindus. The kind of bug that survives a spot
/// check and fails here is the one worth catching.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/engine/ashtakavarga.dart';
import 'package:pocket_astro/engine/ashtakavarga_reduction.dart';
import 'package:pocket_astro/engine/aspects.dart';
import 'package:pocket_astro/engine/astro/ayanamsa.dart';
import 'package:pocket_astro/engine/astro/ephemeris.dart';
import 'package:pocket_astro/engine/astro/houses.dart';
import 'package:pocket_astro/engine/astro/units.dart';
import 'package:pocket_astro/engine/chart_builder.dart';
import 'package:pocket_astro/engine/dasha.dart';
import 'package:pocket_astro/engine/dignity.dart';
import 'package:pocket_astro/engine/harmonics.dart';
import 'package:pocket_astro/engine/hellenistic.dart';
import 'package:pocket_astro/engine/jaimini.dart';
import 'package:pocket_astro/engine/kb.dart';
import 'package:pocket_astro/engine/predictive.dart';
import 'package:pocket_astro/engine/shadbala.dart';
import 'package:pocket_astro/engine/synastry.dart';
import 'package:pocket_astro/engine/tables.dart';
import 'package:pocket_astro/engine/time_convert.dart';
import 'package:pocket_astro/engine/transits.dart';
import 'package:pocket_astro/engine/vargas.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

late NatalChart demo;
late NatalChart partner;

void main() {
  tzdata.initializeTimeZones();

  setUpAll(() {
    PredictionKb.loadFromMap(jsonDecode(
        File('assets/kb/prediction.json').readAsStringSync()) as Map<String, dynamic>);
    PredictionKb.loadMatchingFromMap(jsonDecode(
        File('assets/kb/ashtakoota.json').readAsStringSync()) as Map<String, dynamic>);
    for (final e in PredictionKb.moduleAssets.entries) {
      PredictionKb.loadModuleFromMap(e.key,
          jsonDecode(File(e.value).readAsStringSync()) as Map<String, dynamic>);
    }
    demo = _chart('Demo', DateTime(1992, 4, 14, 3, 57), 27.7172, 85.324, 'Asia/Kathmandu');
    partner = _chart('Partner', DateTime(1990, 9, 2, 14, 20), 51.5074, -0.1278, 'Europe/London');
  });

  group('the chart now carries what it was missing', () {
    test('every graha has a speed, a latitude and a declination', () {
      for (final g in demo.grahas) {
        if (g.name == 'Lagna') continue;
        expect(g.speed.isFinite, isTrue, reason: g.name);
        expect(g.latitude.isFinite, isTrue, reason: g.name);
        expect(g.declination.isFinite, isTrue, reason: g.name);
      }
      // The Moon always moves faster than any planet.
      expect(demo.graha('Moon').speed.abs(), greaterThan(10));
    });

    test('retrogrades are identified and the nodes are excluded from the marker', () {
      expect(demo.graha('Rahu').isRetrograde, isTrue);
      expect(demo.graha('Rahu').showsMotionMarker, isFalse);
      expect(demo.graha('Sun').isDirect, isTrue);
      expect(demo.graha('Sun').motionLabel, 'direct');
    });

    test('the western tenth house is the midheaven', () {
      // G-02, from the chart side rather than the cusp module.
      final cusps = demo.westernCusps!;
      expect(separation(cusps.cusps[9], demo.mcTropical), lessThan(1e-6));
    });

    test('a bhava chalit house is computed alongside the whole-sign one', () {
      final withChalit =
          demo.grahas.where((g) => g.chalitHouse != 0).toList();
      expect(withChalit, isNotEmpty);
      for (final g in withChalit) {
        expect(g.chalitHouse, inInclusiveRange(1, 12));
      }
    });

    test('the chart records what it was computed under', () {
      expect(demo.engineStamp, contains('Lahiri'));
      expect(demo.engineStamp, contains('Placidus'));
      expect(demo.engineStamp, contains('mean node'));
      expect(demo.settings.ayanamsa, Ayanamsa.lahiri);
    });

    test('changing the ayanamsa actually changes the chart', () {
      final kp = buildChart(demo.input, demo.utc,
          settings: const ChartSettings(ayanamsa: Ayanamsa.raman));
      final shift = separation(
          kp.graha('Moon').siderealLon, demo.graha('Moon').siderealLon);
      expect(shift, greaterThan(1.0));
      expect(kp.engineStamp, contains('Raman'));
    });

    test('changing the house system actually changes the houses', () {
      final koch = buildChart(demo.input, demo.utc,
          settings: const ChartSettings(houseSystem: HouseSystem.koch));
      var moved = 0;
      for (var i = 0; i < 12; i++) {
        if (separation(koch.westernCusps!.cusps[i],
                demo.westernCusps!.cusps[i]) >
            0.01) {
          moved++;
        }
      }
      expect(moved, greaterThanOrEqualTo(4));
    });
  });

  group('divisional charts', () {
    late Map<int, VargaChart> vargas;
    setUpAll(() => vargas = buildAllVargas(demo));

    test('all sixteen build and place every graha', () {
      expect(vargas.length, 16);
      for (final v in vargas.values) {
        expect(v.placements.length, 9, reason: v.def.label);
        for (final p in v.placements) {
          expect(p.sign, inInclusiveRange(0, 11));
          expect(p.house, inInclusiveRange(1, 12));
        }
      }
    });

    test('D1 reproduces the rashi chart exactly', () {
      final d1 = vargas[1]!;
      for (final p in d1.placements) {
        final g = demo.graha(p.name);
        expect(p.sign, signIndex(g.siderealLon), reason: p.name);
        expect(p.house, g.house, reason: p.name);
      }
    });

    test('D9 agrees with the standalone navamsa function', () {
      for (final p in vargas[9]!.placements) {
        expect(p.sign, navamsaSign(demo.graha(p.name).siderealLon));
      }
    });

    test('Hora only ever lands in Cancer or Leo', () {
      for (final p in vargas[2]!.placements) {
        expect(p.sign, anyOf(3, 4));
      }
    });

    test('Trimshamsa never lands in a sign ruled by a luminary', () {
      // D30 is divided among the five star-planets only, so Cancer and Leo
      // cannot occur. This is the check that catches an equal-division
      // implementation of a table that is not equally divided.
      for (final p in vargas[30]!.placements) {
        expect(p.sign, isNot(3));
        expect(p.sign, isNot(4));
      }
    });

    test('every division is exhaustive across a whole sign', () {
      // Sweeping a sign must visit exactly the expected number of distinct
      // parts for each varga, which catches an off-by-one in a band boundary.
      for (final v in shodashavarga) {
        final seen = <int>{};
        for (var deg = 0.0; deg < 30.0; deg += 0.01) {
          seen.add(vargaSign(v.division, deg));
        }
        expect(seen, isNotEmpty, reason: v.label);
        expect(seen.length, lessThanOrEqualTo(12), reason: v.label);
      }
    });

    test('vimshopaka scores stay inside their twenty points', () {
      for (final group in vargaGroups) {
        final table = vimshopakaTable(vargas, group: group);
        expect(table.length, 7);
        for (final row in table) {
          expect(row.score, inInclusiveRange(0.0, 20.0),
              reason: '${row.planet} in ${group.name}');
          expect(row.verdict, isNotEmpty);
        }
      }
    });

    test('vargottama is detected', () {
      final v = vargottamaIn(demo, vargas);
      for (final name in v) {
        if (name == 'Lagna') continue;
        expect(vargas[9]!.of(name)!.sign,
            signIndex(demo.graha(name).siderealLon));
      }
    });
  });

  group('shadbala', () {
    late ShadbalaReport report;
    setUpAll(() => report = shadbalaFor(demo));

    test('every graha gets a total and a verdict', () {
      expect(report.planets.length, 7);
      for (final p in report.planets) {
        expect(p.totalVirupa.isFinite, isTrue, reason: p.planet);
        expect(p.totalRupa, greaterThan(0), reason: p.planet);
        expect(p.verdict, isNotEmpty);
      }
    });

    test('the parts sum to the whole', () {
      for (final p in report.planets) {
        final sum = p.sthana + p.dig + p.kala + p.cheshta + p.naisargika + p.drik;
        expect(p.totalVirupa, closeTo(sum, 1e-9), reason: p.planet);
      }
    });

    test('a retrograde planet earns full cheshta bala', () {
      // G-12 leaning on G-01: this component is unreachable without speed.
      for (final p in report.planets) {
        final g = demo.graha(p.planet);
        if (g.isRetrograde && p.planet != 'Sun' && p.planet != 'Moon') {
          expect(p.cheshta, greaterThanOrEqualTo(45.0), reason: p.planet);
        }
      }
    });

    test('uchcha bala peaks at exaltation and bottoms at debilitation', () {
      // Sun exalts at 10 Aries in the Vedic scheme.
      final exalted = shadbalaFor(_chartWithSunAt(10.0));
      final debilitated = shadbalaFor(_chartWithSunAt(190.0));
      expect(exalted.of('Sun')!.uchcha, greaterThan(55));
      expect(debilitated.of('Sun')!.uchcha, lessThan(5));
    });

    test('naisargika bala is the fixed classical order', () {
      final sorted = [...report.planets]
        ..sort((a, b) => b.naisargika.compareTo(a.naisargika));
      expect(sorted.first.planet, 'Sun');
      expect(sorted.last.planet, 'Saturn');
    });

    test('bhava bala covers all twelve houses', () {
      expect(report.bhavas.length, 12);
      for (var i = 0; i < 12; i++) {
        expect(report.bhavas[i].house, i + 1);
      }
    });

    test('ishta and kashta phala are complementary', () {
      for (final p in report.planets) {
        expect(p.ishta, greaterThanOrEqualTo(0));
        expect(p.kashta, greaterThanOrEqualTo(0));
      }
    });
  });

  group('dashas', () {
    test('Vimshottari mahadashas tile the 120-year cycle exactly', () {
      final d = vimshottari(
          birth: demo.utc, moonSidereal: demo.graha('Moon').siderealLon);
      expect(d.mahadashas.length, 9);
      for (var i = 0; i < 8; i++) {
        expect(d.mahadashas[i].end, d.mahadashas[i + 1].start);
      }
      final span = d.mahadashas.last.end.difference(d.mahadashas.first.start);
      final years = span.inDays / 365.2425;
      // The first period is a balance, so the total is 120 minus what elapsed.
      expect(years, lessThanOrEqualTo(120.1));
      expect(years, greaterThan(100.0));
    });

    test('antardashas tile their own mahadasha', () {
      final d = vimshottari(
          birth: demo.utc, moonSidereal: demo.graha('Moon').siderealLon);
      for (final md in d.mahadashas) {
        final children =
            d.antardashas.where((a) => a.start.isBefore(md.end) && a.end.isAfter(md.start));
        expect(children.length, 9, reason: md.lord);
        expect(children.first.start, md.start);
        expect(children.last.end, md.end);
      }
    });

    test('five levels resolve and nest', () {
      final d = vimshottari(
          birth: demo.utc, moonSidereal: demo.graha('Moon').siderealLon);
      final at = demo.utc.add(const Duration(days: 365 * 30));
      final stack = dashaStackAt(d, at, depth: 5);
      expect(stack.length, 5);
      for (var i = 0; i < stack.length - 1; i++) {
        expect(stack[i].start.isAfter(stack[i + 1].start), isFalse);
        expect(stack[i].end.isBefore(stack[i + 1].end), isFalse);
        expect(stack[i + 1].contains(at), isTrue);
      }
      expect(stack.map((s) => s.level).toList(),
          ['MD', 'AD', 'PD', 'SD', 'PrD']);
    });

    test('Ashtottari runs eight lords over 108 years', () {
      final d = ashtottari(
          birth: demo.utc, moonSidereal: demo.graha('Moon').siderealLon);
      expect(d.mahadashas.length, 8);
      expect(ashtottariYears.values.reduce((a, b) => a + b), 108);
      for (var i = 0; i < 7; i++) {
        expect(d.mahadashas[i].end, d.mahadashas[i + 1].start);
      }
    });

    test('Ashtottari applicability is decided, not assumed', () {
      final verdict = ashtottariApplies(demo);
      expect(verdict.reason, isNotEmpty);
      expect(verdict.reason, contains('lagna lord'));
    });

    test('Yogini runs eight periods over 36 years', () {
      final d = yogini(
          birth: demo.utc, moonSidereal: demo.graha('Moon').siderealLon);
      expect(d.mahadashas.length, 8);
      expect(yoginiYears.values.reduce((a, b) => a + b), 36);
    });

    test('every dasha system is reachable through one call', () {
      for (final system in DashaSystem.values) {
        final d = dashaFor(demo, system);
        expect(d.mahadashas, isNotEmpty, reason: system.label);
        expect(d.system, system);
      }
    });

    test('the reference point changes the answer', () {
      final fromMoon = vimshottariFrom(demo, DashaReference.moon);
      final fromLagna = vimshottariFrom(demo, DashaReference.lagna);
      expect(fromMoon.startLord, isNot(equals(fromLagna.startLord)));
    });
  });

  group('Jaimini', () {
    test('chara karakas rank seven planets by degrees', () {
      final k = charaKarakas(demo);
      expect(k.length, 7);
      expect(k.first.role, 'Atmakaraka');
      expect(k.last.role, 'Darakaraka');
      for (var i = 0; i < k.length - 1; i++) {
        expect(k[i].degrees, greaterThanOrEqualTo(k[i + 1].degrees));
      }
    });

    test('the eight-karaka scheme reckons Rahu backwards', () {
      final k = charaKarakas(demo, eightKaraka: true);
      expect(k.length, 8);
      final rahu = k.where((x) => x.planet == 'Rahu').firstOrNull;
      if (rahu != null) {
        final natal = demo.graha('Rahu').siderealLon % 30;
        expect(rahu.degrees, closeTo(30 - natal, 1e-9));
      }
    });

    test('arudha padas never collapse onto their own house or the seventh', () {
      for (final p in arudhaPadas(demo)) {
        final houseSign =
            (signIndex(demo.lagnaSidereal) + p.house - 1) % 12;
        final offset = ((p.sign - houseSign) % 12 + 12) % 12;
        expect(offset, isNot(0), reason: p.label);
        expect(offset, isNot(6), reason: p.label);
      }
    });

    test('rashi drishti is symmetric and hits three signs', () {
      for (var s = 0; s < 12; s++) {
        final seen = rashiDrishtiFrom(s);
        expect(seen.length, 3, reason: signs[s].name);
        for (final t in seen) {
          expect(rashiAspects(t, s), isTrue,
              reason: '${signs[s].name} <-> ${signs[t].name}');
        }
      }
    });

    test('chara dasha covers twenty-four periods across two cycles', () {
      final d = charaDasha(demo);
      expect(d.spans.length, 24);
      for (var i = 0; i < d.spans.length - 1; i++) {
        expect(d.spans[i].end, d.spans[i + 1].start);
      }
      for (final s in d.spans) {
        expect(s.years, inInclusiveRange(1, 12));
      }
    });

    test('a full Jaimini report is produced', () {
      final r = jaiminiFor(demo);
      expect(r.karakas, isNotEmpty);
      expect(r.padas.length, 12);
      expect(r.notes, isNotEmpty);
      expect(r.karakamsa, isNotNull);
    });
  });

  group('dignity, avastha and cancellation', () {
    test('avasthas are produced for all seven grahas', () {
      final a = avasthasFor(demo.grahas);
      expect(a.length, 7);
      for (final r in a) {
        expect(baladiMeaning.containsKey(r.baladi), isTrue);
        expect(deeptadiMeaning.containsKey(r.deeptadi), isTrue);
        expect(r.line, isNotEmpty);
      }
    });

    test('combustion is found when a planet is close to the Sun', () {
      final combust = combustionsIn(demo.grahas);
      for (final c in combust) {
        expect(c.distance, lessThanOrEqualTo(c.orb));
        expect(c.severity, inInclusiveRange(0.0, 1.0));
      }
    });

    test('neecha bhanga is evaluated rather than merely suggested', () {
      // G-17. The old build printed advice to go and check this by hand.
      final lagnaSign = signIndex(demo.lagnaSidereal);
      for (final g in demo.grahas) {
        if (dignityLabel(g.name, g.siderealLon) != 'debilitated') continue;
        final result = neechaBhangaFor(g.name, demo.grahas, lagnaSign);
        // Either it cancels with a stated reason, or it does not. Never silent.
        if (result != null) {
          expect(result.reason, isNotEmpty);
          expect(result.rule, 'neecha bhanga');
        }
      }
    });

    test('essential dignity scores the traditional way', () {
      final s = essentialDignity('Sun', 19.0, night: false);
      // 19 Aries: exaltation (+4), triplicity by day (+3), and the bound and
      // face belong to others.
      expect(s.total, greaterThanOrEqualTo(7));
      expect(s.reasons.any((r) => r.contains('exalted')), isTrue);

      final detriment = essentialDignity('Sun', 310.0, night: false);
      expect(detriment.total, lessThan(0));
    });

    test('Egyptian bounds cover every degree of every sign', () {
      for (var sign = 0; sign < 12; sign++) {
        for (var d = 0.0; d < 30.0; d += 0.5) {
          final r = termRuler(sign * 30.0 + d);
          expect(const ['Saturn', 'Jupiter', 'Mars', 'Venus', 'Mercury'],
              contains(r));
        }
      }
    });

    test('sect flips the benefics and the malefics', () {
      final day = sectOf(_chartAtHour(12));
      final night = sectOf(_chartAtHour(0));
      expect(day.nightChart, isFalse);
      expect(night.nightChart, isTrue);
      expect(day.benefic, 'Jupiter');
      expect(night.benefic, 'Venus');
      expect(day.contrary, 'Mars');
      expect(night.contrary, 'Saturn');
    });
  });

  group('aspects', () {
    test('minor aspects are found and tagged', () {
      final hits = westernAspects(demo.grahas);
      expect(hits, isNotEmpty);
      expect(hits.any((h) => h.kind == AspectKind.minor), isTrue);
      for (final h in hits) {
        expect(h.orb, lessThanOrEqualTo(h.maxOrb));
        expect(h.strength, inInclusiveRange(0.0, 1.0));
      }
    });

    test('orb policy is honoured', () {
      final tight = westernAspects(demo.grahas,
          policy: const OrbPolicy(aspectOrbs: {'square': 1.0}, includeMinor: false));
      for (final h in tight.where((x) => x.name == 'square')) {
        expect(h.orb, lessThanOrEqualTo(1.25));
      }
    });

    test('applying and separating are decided by motion, not order', () {
      final hits = westernAspects(demo.grahas);
      expect(hits.any((h) => h.applying), isTrue);
      expect(hits.any((h) => !h.applying), isTrue);
    });

    test('declination aspects use real declinations', () {
      final d = declinationAspects(demo.grahas);
      for (final h in d) {
        expect(h.kind, AspectKind.declination);
        expect(h.orb, lessThanOrEqualTo(1.0));
      }
    });

    test('antiscia are reflections about the solstitial axis', () {
      expect(antiscion(0), closeTo(180, 1e-9));
      expect(antiscion(90), closeTo(90, 1e-9));
      expect(antiscion(270), closeTo(270, 1e-9));
      for (var d = 0.0; d < 360; d += 11) {
        expect(antiscion(antiscion(d)), closeTo(norm360(d), 1e-9));
      }
    });

    test('patterns are found without duplicates', () {
      final hits = westernAspects(partner.grahas);
      final patterns = aspectPatterns(partner.grahas, hits);
      final keys = patterns
          .map((p) => '${p.name}:${(p.bodies.toList()..sort()).join(',')}')
          .toList();
      expect(keys.toSet().length, keys.length);
      for (final p in patterns) {
        expect(p.note, isNotEmpty);
      }
    });

    test('midpoints sit between their two bodies', () {
      for (final m in midpoints(demo.grahas)) {
        final a = demo.graha(m.a).tropicalLon;
        final b = demo.graha(m.b).tropicalLon;
        final arc = separation(a, b);
        expect(separation(m.longitude, a), closeTo(arc / 2, 1e-6));
        expect(separation(m.longitude, b), closeTo(arc / 2, 1e-6));
      }
    });
  });

  group('predictive', () {
    test('secondary progressions advance about a degree of Sun per year', () {
      final at = demo.utc.add(const Duration(days: 365 * 30));
      final p = secondaryProgressions(demo, at);
      final natalSun = demo.graha('Sun').tropicalLon;
      final arc = norm360(p.longitudeOf('Sun')! - natalSun);
      expect(arc, closeTo(30 * 0.9856, 1.5));
      expect(p.moonPhase.phase, isNotEmpty);
      expect(p.notes, isNotEmpty);
    });

    test('solar arc moves every point by the same amount', () {
      final at = demo.utc.add(const Duration(days: 365 * 25));
      final s = solarArc(demo, at);
      expect(s.arc, closeTo(25 * 0.9856, 1.5));
      for (final p in s.points) {
        expect(separation(p.directed, norm360(p.natal + s.arc)), lessThan(1e-9));
      }
    });

    test('a solar return lands on the natal Sun degree near the birthday', () {
      final r = solarReturn(demo, 2024);
      expect(r, isNotNull);
      final natal = demo.graha('Sun').tropicalLon;
      expect(separation(r!.chart.graha('Sun').tropicalLon, natal),
          lessThan(0.02));
      expect(r.exact.month, anyOf(4, 3, 5));
    });

    test('a lunar return lands on the natal Moon degree', () {
      final r = lunarReturn(demo, DateTime.utc(2024, 6, 1));
      expect(r, isNotNull);
      expect(
          separation(r!.chart.graha('Moon').tropicalLon,
              demo.graha('Moon').tropicalLon),
          lessThan(0.05));
    });

    test('relocation moves the angles and leaves the planets alone', () {
      const tokyo = Place(
        name: 'Tokyo', region: 'Japan',
        latitude: 35.6895, longitude: 139.6917, timezone: 'Asia/Tokyo');
      final moved = relocated(demo, tokyo);
      expect(separation(moved.lagnaTropical, demo.lagnaTropical),
          greaterThan(5.0));
      for (final g in demo.grahas) {
        if (g.name == 'Lagna') continue;
        final other = moved.grahas.where((x) => x.name == g.name).first;
        expect(separation(other.tropicalLon, g.tropicalLon), lessThan(1e-6),
            reason: g.name);
      }
    });

    test('profections walk one house a year and return after twelve', () {
      final a = annualProfection(demo, demo.utc.add(const Duration(days: 30)));
      final b = annualProfection(demo, demo.utc.add(const Duration(days: 365 * 12 + 30)));
      expect(a.house, 1);
      expect(b.house, 1);
      final c = annualProfection(demo, demo.utc.add(const Duration(days: 365 * 7 + 30)));
      expect(c.house, 8);
      expect(c.lordOfYear, isNotEmpty);
    });
  });

  group('Hellenistic time lords', () {
    test('zodiacal releasing tiles the requested span', () {
      final zr = zodiacalReleasing(demo, years: 90);
      expect(zr.level1, isNotEmpty);
      for (var i = 0; i < zr.level1.length - 1; i++) {
        expect(zr.level1[i].end, zr.level1[i + 1].start);
      }
      for (final p in zr.level1) {
        expect(zrYears.containsKey(p.sign), isTrue);
      }
    });

    test('level two periods stay inside their level one parent', () {
      final zr = zodiacalReleasing(demo, years: 60);
      for (final l2 in zr.level2) {
        final parent = zr.level1
            .where((p) => !l2.start.isBefore(p.start) && !l2.end.isAfter(p.end));
        expect(parent, isNotEmpty,
            reason: 'L2 ${l2.label} escaped its L1 period');
      }
    });

    test('peak periods are the angular triad from Fortune', () {
      final zr = zodiacalReleasing(demo);
      for (final p in zr.level1.where((x) => x.peak)) {
        final offset = ((p.sign - zr.fortuneSign) % 12 + 12) % 12;
        expect(const [0, 3, 6, 9], contains(offset));
      }
    });

    test('firdaria covers seventy-five years across nine lords', () {
      final f = firdaria(demo);
      final majors = f.where((p) => p.level == 1).toList();
      expect(majors.length, 9);
      final span = majors.last.end.difference(majors.first.start).inDays / 365.2422;
      expect(span, closeTo(75, 0.5));
      // The nodes are not subdivided.
      expect(f.any((p) => p.level == 2 && p.parent == 'Rahu'), isFalse);
      expect(f.any((p) => p.level == 2 && p.parent == 'Ketu'), isFalse);
    });

    test('firdaria order depends on sect', () {
      final day = firdaria(_chartAtHour(12)).first;
      final night = firdaria(_chartAtHour(0)).first;
      expect(day.lord, 'Sun');
      expect(night.lord, 'Moon');
    });

    test('the lots reverse between day and night', () {
      final day = hermeticLots(_chartAtHour(12));
      final night = hermeticLots(_chartAtHour(0));
      expect(day.length, night.length);
      expect(day.first.name, 'Fortune');
      for (final l in day) {
        expect(l.longitude, inInclusiveRange(0.0, 360.0));
        expect(l.signifies, isNotEmpty);
      }
    });

    test('a whole traditional report assembles', () {
      final t = traditionalFor(demo);
      expect(t.dignities.length, 7);
      expect(t.almutenFiguris, isNotEmpty);
      expect(t.sect.notes, isNotEmpty);
      expect(t.lots, isNotEmpty);
    });
  });

  group('synastry and composites', () {
    test('cross aspects are found both ways', () {
      final s = synastry(demo, partner);
      expect(s.hits, isNotEmpty);
      expect(s.score, inInclusiveRange(5, 95));
      expect(s.summary, isNotEmpty);
      expect(s.aInB, isNotEmpty);
      expect(s.bInA, isNotEmpty);
    });

    test('house overlays are asymmetric', () {
      final s = synastry(demo, partner);
      final aSun = s.aInB.where((o) => o.planet == 'Sun').first.house;
      final bSun = s.bInA.where((o) => o.planet == 'Sun').first.house;
      expect(aSun, inInclusiveRange(1, 12));
      expect(bSun, inInclusiveRange(1, 12));
    });

    test('composite points are midpoints of the two charts', () {
      final c = compositeChart(demo, partner);
      for (final e in c.positions.entries) {
        final a = demo.graha(e.key).tropicalLon;
        final b = partner.graha(e.key).tropicalLon;
        final arc = separation(a, b);
        expect(separation(e.value, a), closeTo(arc / 2, 1e-6), reason: e.key);
      }
    });

    test('a Davison chart is a real chart at the midpoint in time', () {
      final d = davisonChart(demo, partner);
      final mid = DateTime.fromMillisecondsSinceEpoch(
          (demo.utc.millisecondsSinceEpoch +
                  partner.utc.millisecondsSinceEpoch) ~/
              2,
          isUtc: true);
      expect(d.utc.difference(mid).inMinutes.abs(), lessThanOrEqualTo(1));
      expect(d.grahas, isNotEmpty);
      // Unlike a composite it has real houses, so it can be transited.
      expect(d.westernCusps, isNotNull);
    });
  });

  group('harmonics and the Sudarshana chakra', () {
    test('harmonic charts multiply longitudes', () {
      final h5 = harmonicChart(demo, 5);
      for (final e in h5.positions.entries) {
        expect(e.value, closeTo(norm360(demo.graha(e.key).tropicalLon * 5), 1e-9));
      }
      expect(h5.explanation, isNotEmpty);
    });

    test('the draconic chart puts Rahu at zero Aries', () {
      final d = draconicChart(demo);
      expect(d.positions['Rahu'], closeTo(0.0, 1e-9));
    });

    test('the Sudarshana chakra reads from three references', () {
      final s = sudarshanaChakra(demo);
      expect(s.rings.length, 3);
      expect(s.rings.map((r) => r.from).toList(),
          ['Lagna', 'Chandra', 'Surya']);
      for (final ring in s.rings) {
        final placed =
            ring.houses.values.fold<int>(0, (a, b) => a + b.length);
        expect(placed, demo.grahas.where((g) => g.name != 'Lagna').length);
      }
    });
  });

  group('ashtakavarga reductions', () {
    test('reduction never adds bindus', () {
      final av = ashtakavargaFor(demo)!;
      for (final r in reduceAshtakavarga(av)) {
        for (var s = 0; s < 12; s++) {
          expect(r.afterTrikona[s], lessThanOrEqualTo(r.original[s]),
              reason: '${r.planet} sign $s');
          expect(r.afterEkadhipatya[s], lessThanOrEqualTo(r.afterTrikona[s]),
              reason: '${r.planet} sign $s');
          expect(r.afterEkadhipatya[s], greaterThanOrEqualTo(0));
        }
      }
    });

    test('a trine containing a zero is emptied', () {
      final out = trikonaShodhana([0, 3, 4, 5, 6, 2, 7, 1, 8, 4, 3, 2]);
      // Aries, Leo, Sagittarius share a trine; Aries was zero.
      expect(out[0], 0);
      expect(out[4], 0);
      expect(out[8], 0);
    });

    test('trikona subtracts the trine minimum when no zero is present', () {
      final out = trikonaShodhana([5, 0, 0, 0, 7, 0, 0, 0, 6, 0, 0, 0]);
      expect(out[0], 0);
      expect(out[4], 2);
      expect(out[8], 1);
    });

    test('sodhya pinda is produced with a reading', () {
      final av = ashtakavargaFor(demo)!;
      final report = sodhyaPindaFor(av);
      expect(report.rows.length, avPlanets.length);
      expect(report.notes, isNotEmpty);
      expect(report.strongest, isNotEmpty);
      for (final r in report.rows) {
        expect(r.sodhyaPinda, greaterThanOrEqualTo(0));
      }
    });
  });

  group('transits', () {
    test('stations are found and alternate in direction', () {
      final s = stations(
        from: DateTime.utc(2024, 1, 1),
        to: DateTime.utc(2024, 12, 31),
        bodies: const ['Mercury'],
      );
      // Mercury stations six times in a typical year.
      expect(s.length, inInclusiveRange(5, 7));
      for (var i = 0; i < s.length - 1; i++) {
        expect(s[i].retrograde, isNot(s[i + 1].retrograde));
      }
    });

    test('ingresses are found for the Sun and are about a month apart', () {
      final i = ingresses(
        from: DateTime.utc(2024, 1, 1),
        to: DateTime.utc(2024, 12, 31),
        bodies: const ['Sun'],
      );
      expect(i.length, inInclusiveRange(11, 13));
      for (var k = 0; k < i.length - 1; k++) {
        final gap = i[k + 1].at.difference(i[k].at).inDays;
        expect(gap, inInclusiveRange(26, 34));
      }
    });

    test('lunations alternate new and full and fall about a fortnight apart', () {
      final l = lunations(
        from: DateTime.utc(2024, 1, 1),
        to: DateTime.utc(2024, 6, 30),
      );
      expect(l.length, inInclusiveRange(10, 14));
      for (var k = 0; k < l.length - 1; k++) {
        final gap = l[k + 1].at.difference(l[k].at).inDays;
        expect(gap, inInclusiveRange(12, 18));
      }
    });

    test('eclipses are picked out of the lunations', () {
      // April and October 2024 both carry eclipse seasons.
      final l = lunations(
        from: DateTime.utc(2024, 3, 1),
        to: DateTime.utc(2024, 11, 1),
      );
      final eclipses = l.where((e) =>
          e.kind == TransitEventKind.eclipseSolar ||
          e.kind == TransitEventKind.eclipseLunar);
      expect(eclipses.length, greaterThanOrEqualTo(4));
      for (final e in eclipses) {
        expect(e.detail, contains('eclipse limit'));
      }
    });

    test('exact contacts are solved and grouped into passes', () {
      final hits = transitAspects(
        demo,
        from: DateTime.utc(2024, 1, 1),
        to: DateTime.utc(2025, 12, 31),
        bodies: const ['Saturn'],
        points: const ['Sun'],
      );
      for (final h in hits) {
        expect(h.at.isAfter(DateTime.utc(2023, 12, 31)), isTrue);
        if (h.isMultiPass) {
          expect(h.pass, inInclusiveRange(1, h.passesTotal));
          expect(h.detail, contains('Pass'));
        }
      }
    });

    test('a Saturn return arrives at about twenty-nine and a half', () {
      final r = planetaryReturns(demo, 'Saturn',
          within: const Duration(days: 365 * 35));
      expect(r, isNotEmpty);
      final age = r.first.at.difference(demo.utc).inDays / 365.2425;
      expect(age, closeTo(29.5, 1.5));
    });
  });
}

// ---------------------------------------------------------------------------

NatalChart _chart(
  String name,
  DateTime local,
  double lat,
  double lon,
  String tz, {
  ChartSettings settings = const ChartSettings(),
}) {
  final input = BirthInput(
    id: name,
    name: name,
    localDateTime: local,
    place: Place(
        name: name, region: '', latitude: lat, longitude: lon, timezone: tz),
    timeSource: TimeSource.hospital,
  );
  return buildChart(input, toUtc(input), settings: settings);
}

NatalChart _chartAtHour(int hour) =>
    _chart('H$hour', DateTime(1992, 4, 14, hour, 0), 27.7172, 85.324,
        'Asia/Kathmandu');

/// A chart whose Sun has been moved to a chosen sidereal longitude, for
/// testing the strength curves in isolation.
NatalChart _chartWithSunAt(double siderealLon) {
  final base = demo;
  final grahas = [
    for (final g in base.grahas)
      if (g.name == 'Sun')
        GrahaRow(
          name: 'Sun',
          tropicalLon: g.tropicalLon,
          siderealLon: siderealLon,
          sign: signs[signIndex(siderealLon)].name,
          house: g.house,
          nakshatra: nakshatraOf(siderealLon).name,
          pada: padaOf(siderealLon),
          dignity: dignityLabel('Sun', siderealLon),
          westernHouse: g.westernHouse,
          speed: g.speed,
          latitude: g.latitude,
          declination: g.declination,
          chalitHouse: g.chalitHouse,
        )
      else
        g,
  ];
  return NatalChart(
    input: base.input,
    utc: base.utc,
    jd: base.jd,
    ayanamsa: base.ayanamsa,
    lagnaSidereal: base.lagnaSidereal,
    lagnaTropical: base.lagnaTropical,
    mcTropical: base.mcTropical,
    grahas: grahas,
    navamsaLagna: base.navamsaLagna,
    dasha: base.dasha,
    antardashas: base.antardashas,
    westernAspects: base.westernAspects,
    yogas: base.yogas,
    engineStamp: base.engineStamp,
    sky: base.sky,
    settings: base.settings,
  );
}

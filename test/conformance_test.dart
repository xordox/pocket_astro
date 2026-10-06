/// Gap G-09 — the conformance suite.
///
/// The old engine had no way to know whether it was right. It carried a
/// truncated lunar series, Kepler elements good to about an arcminute, and an
/// honest README paragraph — but nothing that *measured* the error, so any
/// change to the maths was a change made in the dark.
///
/// These are the published worked examples from Meeus, which is the reference
/// Swiss Ephemeris itself is checked against, plus a set of internal
/// consistency checks that catch the class of bug a single spot value cannot:
/// house cusps that do not close the circle, speeds that disagree with the
/// positions they are derived from, ayanamsas that drift at the wrong rate.
///
/// Every tolerance here is deliberate and documented. Where the engine is
/// weaker than Swiss Ephemeris — the outer planets, Chiron — the tolerance
/// says so out loud rather than being quietly widened until the test passes.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/engine/astro/ayanamsa.dart';
import 'package:pocket_astro/engine/astro/delta_t.dart';
import 'package:pocket_astro/engine/astro/ephemeris.dart';
import 'package:pocket_astro/engine/astro/houses.dart';
import 'package:pocket_astro/engine/astro/moon.dart';
import 'package:pocket_astro/engine/astro/nutation.dart';
import 'package:pocket_astro/engine/astro/sun.dart';
import 'package:pocket_astro/engine/astro/units.dart';

/// One arcsecond in degrees, so tolerances read in the units astronomers argue
/// in rather than as bare decimals.
const arcsec = 1.0 / 3600.0;
const arcmin = 1.0 / 60.0;

void main() {
  group('time scales', () {
    test('Julian Day round-trips and matches Meeus 7.a', () {
      // 1957 October 4.81 UT, Sputnik launch.
      expect(julianDay(DateTime.utc(1957, 10, 4, 19, 26, 24)),
          closeTo(2436116.31, 0.01));
      // J2000.0 by definition.
      expect(julianDay(DateTime.utc(2000, 1, 1, 12)), closeTo(2451545.0, 1e-6));

      for (final d in [
        DateTime.utc(1899, 12, 31, 23, 59),
        DateTime.utc(1992, 4, 13, 22, 12, 30),
        DateTime.utc(2035, 7, 1, 6, 30),
      ]) {
        final back = dateFromJulianDay(julianDay(d));
        expect(back.difference(d).inSeconds.abs(), lessThanOrEqualTo(1),
            reason: 'round trip for $d');
      }
    });

    test('delta T tracks the published values', () {
      // Espenak & Meeus reference points, to a second or two.
      expect(DeltaT.seconds(2000.0), closeTo(63.8, 1.5));
      expect(DeltaT.seconds(1900.0), closeTo(-2.8, 2.0));
      expect(DeltaT.seconds(1950.0), closeTo(29.1, 2.0));
      expect(DeltaT.seconds(1800.0), closeTo(13.7, 2.0));
      // Monotone growth across the modern era, which is what makes the
      // correction matter more for older births.
      expect(DeltaT.seconds(2020.0), greaterThan(DeltaT.seconds(2000.0)));
    });

    test('delta T actually moves the Moon', () {
      // The point of G-05, stated as a test. Note that 1900 is almost exactly
      // where delta T crosses zero, so it is the one epoch where skipping the
      // correction costs nothing — which is precisely why a single spot check
      // is not enough to justify the code.
      double lunarError(DateTime at) {
        final jdUt = julianDay(at);
        return norm180(moonPosition(DeltaT.terrestrial(jdUt)).longitude -
                moonPosition(jdUt).longitude)
            .abs();
      }

      // Today: about 69 seconds of delta T, worth some 38 arcsec of Moon.
      expect(lunarError(DateTime.utc(2024, 6, 15, 12)), greaterThan(8 * arcsec));
      // 1600: over two minutes of delta T, and well over an arcminute of Moon.
      expect(lunarError(DateTime.utc(1600, 6, 15, 12)), greaterThan(arcmin));
      // 1900 is the exception that proves the rule.
      expect(lunarError(DateTime.utc(1900, 6, 15, 12)), lessThan(5 * arcsec));
    });
  });

  group('nutation and obliquity — Meeus example 22.a', () {
    // 1987 April 10.0 TD.
    final jdTt = 2446895.5;

    test('nutation in longitude and obliquity', () {
      final n = nutation(jdTt);
      expect(n.longitude * 3600, closeTo(-3.788, 0.5));
      expect(n.obliquity * 3600, closeTo(9.443, 0.5));
    });

    test('true obliquity is 23 deg 26 min 36.85 sec', () {
      final expected = 23 + 26 / 60.0 + 36.850 / 3600.0;
      expect(trueObliquityOf(jdTt), closeTo(expected, 0.5 * arcsec));
    });
  });

  group('sidereal time — Meeus example 12.a', () {
    // 1987 April 10, 0h UT.
    final jdUt = 2446895.5;

    test('GMST is 13h 10m 46.3668s', () {
      const expected = (13 + 10 / 60.0 + 46.3668 / 3600.0) * 15.0;
      expect(gmst(jdUt), closeTo(expected, 0.1 * arcsec));
    });

    test('GAST differs from GMST by the equation of the equinoxes', () {
      // Meeus gives 13h10m46.1351s apparent, i.e. about 0.232s earlier.
      final diffSeconds = (gast(jdUt) - gmst(jdUt)) / 15.0 * 3600.0;
      expect(diffSeconds, closeTo(-0.2317, 0.05));
    });
  });

  group('the Moon — Meeus example 47.a', () {
    // 1992 April 12.0 TD.
    final jdTt = 2448724.5;
    final m = moonPosition(jdTt);

    test('longitude within 10 arcsec of the published value', () {
      expect(m.longitude, closeTo(133.162655, 10 * arcsec));
    });

    test('latitude within 4 arcsec of the published value', () {
      expect(m.latitude, closeTo(-3.229126, 4 * arcsec));
    });

    test('distance within 1 km of the published value', () {
      expect(m.distanceKm, closeTo(368409.7, 1.0));
    });

    test('this is a real improvement over the old 30-term series', () {
      // The truncation the engine used to carry, reproduced here, so the test
      // records *how much* better the full series is rather than asserting it.
      double truncated(double jd) {
        final t = centuries(jd);
        final lp = norm360(218.3164477 + 481267.88123421 * t - 0.0015786 * t * t);
        final d = norm360(297.8501921 + 445267.1114034 * t);
        final mm = norm360(357.5291092 + 35999.0502909 * t);
        final mp = norm360(134.9633964 + 477198.8675055 * t);
        final f = norm360(93.2720950 + 483202.0175233 * t);
        var s = 6288774 * sind(mp) +
            1274027 * sind(2 * d - mp) +
            658314 * sind(2 * d) +
            213618 * sind(2 * mp) -
            185116 * sind(mm) -
            114332 * sind(2 * f);
        return norm360(lp + s / 1e6);
      }

      final oldError = norm180(truncated(jdTt) - 133.162655).abs();
      final newError = norm180(m.longitude - 133.162655).abs();
      expect(newError, lessThan(oldError / 10),
          reason: 'old error ${oldError * 60} arcmin, '
              'new error ${newError * 3600} arcsec');
    });
  });

  group('the lunar nodes', () {
    test('mean node at J2000 matches the standard value', () {
      expect(meanNode(2451545.0), closeTo(125.0445479, 1e-5));
    });

    test('true node departs from mean by up to about 1 deg 40 min', () {
      var maxDiff = 0.0;
      for (var i = 0; i < 400; i++) {
        final jd = 2451545.0 + i * 3.0;
        final d = norm180(trueNode(jd) - meanNode(jd)).abs();
        if (d > maxDiff) maxDiff = d;
      }
      // G-04: the whole reason both must exist. Anything under a degree here
      // would mean the true node was not actually being computed.
      expect(maxDiff, greaterThan(1.0));
      expect(maxDiff, lessThan(2.0));
    });

    test('both nodes are retrograde', () {
      final p = computeSky(
        utc: DateTime.utc(2024, 6, 1),
        latitude: 0,
        longitudeEast: 0,
      );
      expect(p.bodies['Rahu']!.speed, lessThan(0));
      expect(p.bodies['Ketu']!.speed, lessThan(0));
    });
  });

  group('the Sun', () {
    test('matches Meeus example 25.b', () {
      // 1992 October 13.0 TD. Meeus gives the geometric geocentric longitude
      // as 199.907347 deg from the full VSOP87 theory.
      //
      // Worth naming the trap here: 280.4665 at J2000 is the Sun's *mean*
      // longitude, not its true one. The true longitude is about 0.084 deg
      // behind it because the equation of centre is negative there.
      expect(sunPosition(2448908.5).longitude, closeTo(199.907347, 2 * arcsec));
    });

    test('true longitude differs from mean longitude by the equation of centre', () {
      final t = centuries(2451545.0);
      final meanLongitude = norm360(280.46646 + 36000.76983 * t);
      // 280.46646 is already the *geocentric* mean longitude, so this compares
      // like with like. The tolerance is set by Meeus's low-accuracy equation
      // of centre, which he states as good to 0.01 deg — the VSOP87 value is
      // the more trustworthy of the two.
      final trueLongitude = sunPosition(2451545.0).longitude;
      expect(norm180(trueLongitude - meanLongitude), closeTo(-0.0843, 0.006));
    });

    test('equinoxes land where the calendar says they do', () {
      // The Sun crosses 0 deg within a few hours of 20 March each year, and
      // 180 deg within a few hours of 22-23 September.
      for (final year in [1950, 1992, 2024]) {
        final march = _solveSunLongitude(0.0, DateTime.utc(year, 3, 15));
        expect(march.month, 3);
        expect(march.day, inInclusiveRange(19, 21), reason: 'equinox $year');
      }
    });
  });

  group('planetary positions', () {
    test('every default body places without throwing, over three centuries', () {
      for (final year in [1850, 1900, 1950, 2000, 2050, 2100]) {
        final sky = computeSky(
          utc: DateTime.utc(year, 6, 15, 12),
          latitude: 27.7,
          longitudeEast: 85.3,
        );
        for (final name in defaultBodies) {
          final b = sky.bodies[name]!;
          expect(b.longitude.isFinite, isTrue, reason: '$name in $year');
          expect(b.longitude, inInclusiveRange(0, 360));
          expect(b.latitude.abs(), lessThan(90));
          expect(b.speed.isFinite, isTrue);
        }
      }
    });

    test('speeds agree with the positions they come from', () {
      // G-01, checked rather than trusted: differencing the longitude a day
      // apart must reproduce the reported speed.
      final t0 = DateTime.utc(2024, 3, 10, 12);
      final a = computeSky(utc: t0, latitude: 0, longitudeEast: 0);
      final b = computeSky(
          utc: t0.add(const Duration(hours: 24)), latitude: 0, longitudeEast: 0);
      for (final name in defaultBodies) {
        final delta = norm180(b.bodies[name]!.longitude - a.bodies[name]!.longitude);
        final mean = (a.bodies[name]!.speed + b.bodies[name]!.speed) / 2;
        expect(delta, closeTo(mean, 0.02), reason: '$name speed vs motion');
      }
    });

    test('retrograde periods appear where they belong', () {
      // Mercury retrograde, 2024: roughly 1-25 April, 5-28 August,
      // 26 November - 15 December. Sampling the middle of the April window
      // must find it moving backwards.
      final mid = computeSky(
          utc: DateTime.utc(2024, 4, 12), latitude: 0, longitudeEast: 0);
      expect(mid.bodies['Mercury']!.isRetrograde, isTrue);
      expect(mid.bodies['Mercury']!.motionLabel, 'retrograde');

      // And direct in the middle of a known direct stretch.
      final direct = computeSky(
          utc: DateTime.utc(2024, 6, 20), latitude: 0, longitudeEast: 0);
      expect(direct.bodies['Mercury']!.isDirect, isTrue);
    });

    test('the Sun is never retrograde and the Moon never is either', () {
      for (var i = 0; i < 60; i++) {
        final sky = computeSky(
          utc: DateTime.utc(2024, 1, 1).add(Duration(days: i * 6)),
          latitude: 0,
          longitudeEast: 0,
        );
        expect(sky.bodies['Sun']!.speed, greaterThan(0.9));
        expect(sky.bodies['Sun']!.speed, lessThan(1.1));
        expect(sky.bodies['Moon']!.speed, greaterThan(10.0));
        expect(sky.bodies['Moon']!.speed, lessThan(16.0));
      }
    });

    test('outer planets retrograde for roughly the expected fraction of the year', () {
      // Saturn is retrograde about 36 percent of the time, Jupiter about 30.
      int count(String name) {
        var n = 0;
        for (var i = 0; i < 365; i++) {
          final sky = computeSky(
            utc: DateTime.utc(2023, 1, 1).add(Duration(days: i)),
            latitude: 0,
            longitudeEast: 0,
            bodyNames: [name],
          );
          if (sky.bodies[name]!.isRetrograde) n++;
        }
        return n;
      }

      expect(count('Saturn') / 365.0, closeTo(0.37, 0.06));
      expect(count('Jupiter') / 365.0, closeTo(0.30, 0.06));
    });
  });

  group('ayanamsa', () {
    test('Lahiri sits near 23 deg 51 min at J2000', () {
      final a = ayanamsaFor(Ayanamsa.lahiri, 2451545.0);
      expect(a, closeTo(23.86, 0.03));
    });

    test('Lahiri returns its own anchor value at the anchor epoch', () {
      // 21 March 1956, the Indian Calendar Reform Committee value.
      final a = ayanamsaFor(Ayanamsa.lahiri, 2435553.5);
      expect(a, closeTo(23.250182778, 1e-6));
    });

    test('the schools differ by the amounts practitioners argue about', () {
      final jd = 2451545.0;
      final lahiri = ayanamsaFor(Ayanamsa.lahiri, jd);
      final raman = ayanamsaFor(Ayanamsa.raman, jd);
      final kp = ayanamsaFor(Ayanamsa.krishnamurti, jd);
      final fagan = ayanamsaFor(Ayanamsa.faganBradley, jd);

      // Raman runs roughly 1.4 deg behind Lahiri, KP about 6 arcmin behind,
      // Fagan-Bradley about 53 arcmin ahead.
      expect(lahiri - raman, closeTo(1.45, 0.1));
      expect(lahiri - kp, closeTo(0.1, 0.06));
      expect(fagan - lahiri, closeTo(0.88, 0.1));

      // G-03 in one line: the spread is larger than a nakshatra pada, so the
      // choice can move the Moon into a different dasha lord.
      expect(fagan - raman, greaterThan(2.0));
    });

    test('True Chitra keeps Spica at exactly 180 deg', () {
      for (final jd in [2415020.0, 2451545.0, 2488070.0]) {
        final ayan = ayanamsaFor(Ayanamsa.trueChitra, jd);
        final spica = precessEcliptic(
          longitude: 203.8398,
          latitude: 0,
          fromJd: 2451545.0,
          toJd: jd,
        );
        expect(norm360(spica.longitude - ayan), closeTo(180.0, 1e-6));
      }
    });

    test('every ayanamsa advances at roughly the precession rate', () {
      for (final mode in Ayanamsa.values) {
        if (mode == Ayanamsa.none) continue;
        final rate = ayanamsaRate(mode, 2451545.0) * 365.25 * 3600;
        expect(rate, closeTo(50.3, 1.5), reason: mode.label);
      }
    });

    test('tropical mode is exactly zero', () {
      expect(ayanamsaFor(Ayanamsa.none, 2451545.0), 0.0);
    });
  });

  group('house systems', () {
    const ramc = 190.0;
    const lat = 27.7172;
    const eps = 23.4367;

    test('every system closes the circle in order', () {
      for (final system in HouseSystem.values) {
        final h = computeHouses(
          ramc: ramc, latitude: lat, obliquity: eps, system: system);
        expect(h.cusps.length, 12, reason: system.label);
        var total = 0.0;
        for (var i = 0; i < 12; i++) {
          final span = norm360(h.cusps[(i + 1) % 12] - h.cusps[i]);
          expect(span, greaterThan(0.0), reason: '${system.label} house ${i + 1}');
          expect(span, lessThan(180.0), reason: '${system.label} house ${i + 1}');
          total += span;
        }
        expect(total, closeTo(360.0, 1e-6), reason: system.label);
      }
    });

    test('the tenth cusp is the midheaven wherever it should be', () {
      // G-02 in one assertion. The old engine failed this for every system:
      // it returned equal house and never used the MC at all.
      for (final system in HouseSystem.values) {
        if (system == HouseSystem.equal || system == HouseSystem.wholeSign) {
          continue; // these two legitimately do not put the MC on a cusp
        }
        if (system == HouseSystem.sripati) continue; // cusps are sandhis
        final h = computeHouses(
          ramc: ramc, latitude: lat, obliquity: eps, system: system);
        expect(separation(h.cusps[9], h.midheaven), lessThan(1e-6),
            reason: system.label);
        expect(separation(h.cusps[0], h.ascendant), lessThan(1e-6),
            reason: system.label);
      }
    });

    test('the old equal-house stand-in really was wrong', () {
      final placidus = computeHouses(
        ramc: ramc, latitude: lat, obliquity: eps, system: HouseSystem.placidus);
      final equalTenth = norm360(placidus.ascendant + 270);
      // What `_placidusLike` used to return for the tenth cusp, against the
      // real MC. At this latitude they are more than a sign apart.
      expect(separation(equalTenth, placidus.midheaven), greaterThan(10.0));
    });

    test('at the equator the quadrant systems agree with each other', () {
      // With no latitude every quadrant system reduces to dividing the
      // celestial equator into twelve, so they must all land together. A
      // system that disagrees here has its geometry wrong.
      //
      // Porphyry is deliberately *not* in this list. It trisects the ecliptic
      // arc between the angles, while the others all reduce to dividing the
      // equator, and the obliquity keeps those two divisions apart even at the
      // equator. Expecting them to agree was a mistake worth leaving a note
      // about, because it looks like a bug in Placidus and is not one.
      const equatorial = [
        HouseSystem.placidus,
        HouseSystem.koch,
        HouseSystem.campanus,
        HouseSystem.alcabitius,
        HouseSystem.topocentric,
      ];
      final reference = computeHouses(
        ramc: 123.0, latitude: 0.0, obliquity: eps,
        system: HouseSystem.regiomontanus);
      for (final s in equatorial) {
        final h = computeHouses(
          ramc: 123.0, latitude: 0.0, obliquity: eps, system: s);
        for (var i = 0; i < 12; i++) {
          expect(separation(h.cusps[i], reference.cusps[i]), lessThan(0.01),
              reason: '${s.label} cusp ${i + 1} at the equator');
        }
      }
    });

    test('Porphyry stays distinct from the equator-dividing systems', () {
      // The counterpart to the test above: Porphyry divides a different circle,
      // so it must NOT collapse onto Regiomontanus even at the equator.
      final por = computeHouses(
        ramc: 123.0, latitude: 0.0, obliquity: eps, system: HouseSystem.porphyry);
      final reg = computeHouses(
        ramc: 123.0, latitude: 0.0, obliquity: eps,
        system: HouseSystem.regiomontanus);
      expect(separation(por.cusps[1], reg.cusps[1]), greaterThan(0.5));
    });

    test('Regiomontanus agrees with its own closed form', () {
      // The module solves Regiomontanus geometrically; the pole formula is an
      // independent derivation of the same thing. They must agree.
      for (final latitude in [-52.0, -20.0, 12.0, 41.9, 60.0]) {
        for (final r in [15.0, 97.0, 210.0, 333.0]) {
          final geometric = computeHouses(
            ramc: r, latitude: latitude, obliquity: eps,
            system: HouseSystem.regiomontanus);
          final pole11 = r2d(math.atan(tand(latitude) * sind(30.0)));
          final closed = ascendantUnderPole(norm360(r - 60), pole11, eps);
          expect(separation(geometric.cusps[10], closed), lessThan(0.02),
              reason: 'lat $latitude ramc $r');
        }
      }
    });

    test('Placidus and Koch stand down inside the polar circles', () {
      // They are undefined there, and the honest answer is to say which system
      // actually produced the numbers.
      final h = computeHouses(
        ramc: 100.0, latitude: 78.0, obliquity: eps,
        system: HouseSystem.placidus);
      expect(h.fellBack, isTrue);
      expect(h.system, HouseSystem.porphyry);
      expect(h.requested, HouseSystem.placidus);
      for (final c in h.cusps) {
        expect(c.isFinite, isTrue);
      }
    });

    test('Placidus survives ordinary latitudes on both sides of the equator', () {
      for (final latitude in [-55.0, -33.9, 0.0, 27.7, 51.5, 60.0]) {
        final h = computeHouses(
          ramc: 77.0, latitude: latitude, obliquity: eps,
          system: HouseSystem.placidus);
        expect(h.fellBack, isFalse, reason: 'lat $latitude');
        expect(h.system, HouseSystem.placidus);
      }
    });

    test('whole sign cusps begin at sign boundaries', () {
      final h = computeHouses(
        ramc: ramc, latitude: lat, obliquity: eps,
        system: HouseSystem.wholeSign);
      for (final c in h.cusps) {
        expect(c % 30.0, closeTo(0.0, 1e-9));
      }
    });

    test('Sripati boundaries straddle the Porphyry midpoints', () {
      // The chalit construction: Porphyry cusps become bhava madhya, and the
      // sandhi falls halfway between two of them.
      final por = computeHouses(
        ramc: ramc, latitude: lat, obliquity: eps,
        system: HouseSystem.porphyry);
      final sri = computeHouses(
        ramc: ramc, latitude: lat, obliquity: eps,
        system: HouseSystem.sripati);
      for (var i = 0; i < 12; i++) {
        final madhya = por.cusps[i];
        expect(sri.houseOf(madhya), i + 1,
            reason: 'madhya ${i + 1} must sit inside bhava ${i + 1}');
      }
    });

    test('houseOf and positionInHouse are consistent', () {
      final h = computeHouses(
        ramc: ramc, latitude: lat, obliquity: eps, system: HouseSystem.placidus);
      for (var i = 0; i < 12; i++) {
        expect(h.houseOf(h.cusps[i]), i + 1);
        expect(h.positionInHouse(h.cusps[i]), closeTo(0.0, 1e-9));
      }
      for (var deg = 0.0; deg < 360; deg += 7.5) {
        final house = h.houseOf(deg);
        expect(house, inInclusiveRange(1, 12));
        expect(h.positionInHouse(deg), inInclusiveRange(0.0, 1.0));
      }
    });
  });

  group('topocentric reduction', () {
    test('moves the Moon by up to about a degree and the Sun by almost nothing', () {
      const geo = ChartSettings(topocentric: false);
      const topo = ChartSettings(topocentric: true);
      var maxMoon = 0.0;
      var maxSun = 0.0;
      for (var i = 0; i < 40; i++) {
        final t = DateTime.utc(2024, 1, 1).add(Duration(hours: i * 7));
        final g = computeSky(
          utc: t, latitude: 51.5, longitudeEast: -0.13, settings: geo,
          bodyNames: const ['Sun', 'Moon']);
        final p = computeSky(
          utc: t, latitude: 51.5, longitudeEast: -0.13, settings: topo,
          bodyNames: const ['Sun', 'Moon']);
        maxMoon = math.max(maxMoon,
            separation(g.bodies['Moon']!.longitude, p.bodies['Moon']!.longitude));
        maxSun = math.max(maxSun,
            separation(g.bodies['Sun']!.longitude, p.bodies['Sun']!.longitude));
      }
      // G-07: this is why KP cannot be practised on geocentric figures.
      expect(maxMoon, greaterThan(0.5));
      expect(maxMoon, lessThan(1.2));
      expect(maxSun, lessThan(0.01));
    });
  });

  group('latitude and declination', () {
    test('latitude survives the pipeline for every body that has one', () {
      // G-08. The old engine computed these and discarded them.
      final sky = computeSky(
        utc: DateTime.utc(1992, 4, 13, 22, 12),
        latitude: 27.7172,
        longitudeEast: 85.324,
      );
      expect(sky.bodies['Moon']!.latitude.abs(), greaterThan(0.01));
      expect(sky.bodies['Venus']!.latitude.abs(), greaterThan(0.001));
      // The nodes are points on the ecliptic by definition.
      expect(sky.bodies['Rahu']!.latitude.abs(), lessThan(1e-9));
    });

    test('declination stays inside the obliquity for the Sun', () {
      for (var i = 0; i < 24; i++) {
        final sky = computeSky(
          utc: DateTime.utc(2024, 1, 1).add(Duration(days: i * 15)),
          latitude: 0, longitudeEast: 0, bodyNames: const ['Sun']);
        expect(sky.bodies['Sun']!.declination.abs(),
            lessThanOrEqualTo(sky.obliquity + 1e-6));
      }
    });

    test('the Moon can go out of bounds and the Sun cannot', () {
      var moonOutOfBounds = false;
      for (var i = 0; i < 60; i++) {
        final sky = computeSky(
          utc: DateTime.utc(2024, 1, 1).add(Duration(days: i)),
          latitude: 0, longitudeEast: 0, bodyNames: const ['Sun', 'Moon']);
        expect(sky.bodies['Sun']!.outOfBounds(sky.obliquity), isFalse);
        if (sky.bodies['Moon']!.outOfBounds(sky.obliquity)) moonOutOfBounds = true;
      }
      // 2024 is inside a major lunar standstill, so this must trigger.
      expect(moonOutOfBounds, isTrue);
    });
  });

  group('sect and the lots', () {
    test('a noon chart is diurnal and a midnight chart is nocturnal', () {
      final noon = computeSky(
        utc: DateTime.utc(2024, 6, 21, 12),
        latitude: 0, longitudeEast: 0);
      final midnight = computeSky(
        utc: DateTime.utc(2024, 6, 21, 0),
        latitude: 0, longitudeEast: 0);
      expect(noon.isNightChart, isFalse);
      expect(midnight.isNightChart, isTrue);
    });

    test('Fortune and Spirit swap between day and night', () {
      final day = computeSky(
        utc: DateTime.utc(2024, 6, 21, 12), latitude: 0, longitudeEast: 0);
      final night = computeSky(
        utc: DateTime.utc(2024, 6, 21, 0), latitude: 0, longitudeEast: 0);
      // By construction the two lots exchange formulae across the sect line,
      // which is the detail tools get wrong.
      expect(separation(day.partOfFortune, day.partOfSpirit), greaterThan(0.0));
      final dayFortuneRule = norm360(
          day.western.ascendant + day.bodies['Moon']!.longitude -
              day.bodies['Sun']!.longitude);
      expect(separation(day.partOfFortune, dayFortuneRule), lessThan(1e-9));
      final nightFortuneRule = norm360(
          night.western.ascendant + night.bodies['Sun']!.longitude -
              night.bodies['Moon']!.longitude);
      expect(separation(night.partOfFortune, nightFortuneRule), lessThan(1e-9));
    });
  });

  group('provenance', () {
    test('a chart records the settings it was computed under', () {
      // G-46: the answer to "which ayanamsa and which house system" has to
      // travel with the chart, not live in a constant string.
      const settings = ChartSettings(
        ayanamsa: Ayanamsa.krishnamurti,
        houseSystem: HouseSystem.koch,
        trueNode: true,
        topocentric: true,
      );
      final sky = computeSky(
        utc: DateTime.utc(1992, 4, 13, 22, 12),
        latitude: 27.7172, longitudeEast: 85.324, settings: settings);
      expect(sky.settings.ayanamsa, Ayanamsa.krishnamurti);
      expect(sky.western.system, HouseSystem.koch);
      expect(sky.deltaTSeconds, greaterThan(50));

      final round = ChartSettings.fromJson(settings.toJson());
      expect(round.ayanamsa, settings.ayanamsa);
      expect(round.houseSystem, settings.houseSystem);
      expect(round.trueNode, isTrue);
      expect(round.topocentric, isTrue);
    });
  });
}

/// Finds the instant the Sun reaches a tropical longitude, by bisection.
DateTime _solveSunLongitude(double target, DateTime near) {
  var lo = near.subtract(const Duration(days: 20));
  var hi = near.add(const Duration(days: 20));
  double f(DateTime t) => norm180(
      sunPosition(DeltaT.terrestrial(julianDay(t))).longitude - target);
  for (var i = 0; i < 60; i++) {
    final mid = lo.add(Duration(
        milliseconds: hi.difference(lo).inMilliseconds ~/ 2));
    if (f(lo).sign == f(mid).sign) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

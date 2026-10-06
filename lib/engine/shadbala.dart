/// Shadbala — the six-fold strength, with Bhava bala and Ishta/Kashta phala.
///
/// Gap G-12. The app had only the qualitative scoring in `house_quality.dart`.
/// Shadbala is the number every serious Vedic package puts on its front screen,
/// and it is what turns "Jupiter is in the ninth" into "Jupiter is the
/// strongest graha in this chart, so its dasha is the one to plan around".
///
/// One of the six, Cheshta bala, is *motional* strength. It could not be
/// computed at all before planetary speed existed (G-01), which is why that
/// gap had to close first.
///
/// Units are virupas throughout, 60 to the rupa, as the classics use. The
/// required minimums at the end are Parashara's, and a planet that fails its
/// own minimum is the one to be careful about however good the chart looks
/// elsewhere.
library;

import 'dart:math' as math;

import '../domain/models.dart';
import 'astro/units.dart';
import 'dignity.dart';
import 'panchanga.dart';
import 'tables.dart';

const _sevenGrahas = ['Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn'];

/// Classical mean daily motion, degrees. Used as the yardstick for Cheshta.
const Map<String, double> meanDailyMotion = {
  'Sun': 0.9856,
  'Moon': 13.1764,
  'Mars': 0.5240,
  'Mercury': 1.3833,
  'Jupiter': 0.0831,
  'Venus': 1.2000,
  'Saturn': 0.0335,
};

/// Naisargika bala — natural, permanent strength. Fixed by the tradition in
/// order of apparent brightness.
const Map<String, double> naisargikaBala = {
  'Sun': 60.0,
  'Moon': 51.43,
  'Venus': 42.86,
  'Jupiter': 34.29,
  'Mercury': 25.71,
  'Mars': 17.14,
  'Saturn': 8.57,
};

/// The house each graha is strongest in — Dig bala's reference point.
const Map<String, int> digBalaHouse = {
  'Jupiter': 1,
  'Mercury': 1,
  'Sun': 10,
  'Mars': 10,
  'Saturn': 7,
  'Moon': 4,
  'Venus': 4,
};

/// Minimum shadbala a graha needs, in rupas. Below this it does not deliver.
const Map<String, double> requiredRupas = {
  'Sun': 5.0,
  'Moon': 6.0,
  'Mars': 5.0,
  'Mercury': 7.0,
  'Jupiter': 6.5,
  'Venus': 5.5,
  'Saturn': 5.0,
};

const _benefics = {'Jupiter', 'Venus', 'Moon'};

class BalaBreakdown {
  const BalaBreakdown({
    required this.planet,
    required this.sthana,
    required this.uchcha,
    required this.saptavargaja,
    required this.ojhayugma,
    required this.kendradi,
    required this.drekkana,
    required this.dig,
    required this.kala,
    required this.nathonnatha,
    required this.paksha,
    required this.tribhaga,
    required this.varsha,
    required this.masa,
    required this.vara,
    required this.hora,
    required this.ayana,
    required this.yuddha,
    required this.cheshta,
    required this.naisargika,
    required this.drik,
  });

  final String planet;

  final double sthana;
  final double uchcha;
  final double saptavargaja;
  final double ojhayugma;
  final double kendradi;
  final double drekkana;

  final double dig;

  final double kala;
  final double nathonnatha;
  final double paksha;
  final double tribhaga;
  final double varsha;
  final double masa;
  final double vara;
  final double hora;
  final double ayana;
  final double yuddha;

  final double cheshta;
  final double naisargika;
  final double drik;

  /// Total in virupas.
  double get totalVirupa => sthana + dig + kala + cheshta + naisargika + drik;

  /// Total in rupas, which is how the classics quote it.
  double get totalRupa => totalVirupa / 60.0;

  double get required => requiredRupas[planet] ?? 5.0;

  /// Strength as a multiple of what this graha needs. Above 1.0 it delivers.
  double get ratio => totalRupa / required;

  bool get meetsMinimum => totalRupa >= required;

  /// Ishta phala — the benefic result the graha is capable of giving.
  double get ishta => math.sqrt(uchcha.clamp(0, 60) * cheshta.clamp(0, 60));

  /// Kashta phala — the difficulty it brings with it.
  double get kashta =>
      math.sqrt((60 - uchcha).clamp(0, 60) * (60 - cheshta).clamp(0, 60));

  String get verdict {
    if (ratio >= 1.5) return 'very strong';
    if (ratio >= 1.0) return 'strong enough to deliver';
    if (ratio >= 0.75) return 'short of its minimum';
    return 'weak — promises more than it pays';
  }
}

class ShadbalaReport {
  const ShadbalaReport({
    required this.planets,
    required this.bhavas,
    required this.strongest,
    required this.weakest,
  });

  final List<BalaBreakdown> planets;
  final List<BhavaBala> bhavas;
  final String strongest;
  final String weakest;

  BalaBreakdown? of(String planet) =>
      planets.where((p) => p.planet == planet).firstOrNull;

  /// Ranked strongest first, which is the order a jyotishi reads them in.
  List<BalaBreakdown> get ranked {
    final copy = [...planets];
    copy.sort((a, b) => b.totalVirupa.compareTo(a.totalVirupa));
    return copy;
  }
}

class BhavaBala {
  const BhavaBala({
    required this.house,
    required this.adhipati,
    required this.dig,
    required this.drishti,
  });
  final int house;

  /// Strength of the house lord, carried over from its shadbala.
  final double adhipati;

  /// Directional strength of the house itself.
  final double dig;

  /// Net aspect on the house.
  final double drishti;

  double get total => adhipati + dig + drishti;
  double get rupas => total / 60.0;
}

// ---------------------------------------------------------------------------
// Components
// ---------------------------------------------------------------------------

/// Uchcha bala — distance from the point of debilitation, 0 to 60.
double _uchchaBala(String planet, double siderealLon) {
  final d = dignityTable[planet];
  if (d == null) return 0;
  final debilitationPoint = norm360(d.exaltSign * 30.0 + d.exaltDeg + 180.0);
  final distance = separation(siderealLon, debilitationPoint);
  return distance / 3.0;
}

/// Saptavargaja bala — dignity summed across the seven vargas.
double _saptavargajaBala(String planet, double siderealLon) {
  const divisions = [1, 2, 3, 7, 9, 12, 30];
  var total = 0.0;
  for (final div in divisions) {
    final sign = _vargaSignFor(div, siderealLon);
    final label = dignityLabel(planet, sign * 30.0 + 15.0);
    final lord = signs[sign].ruler;
    if (label == 'exalted') {
      total += 45.0;
    } else if (label == 'own sign') {
      total += 30.0;
    } else if (label == 'debilitated') {
      total += 1.875;
    } else {
      total += switch (relation(planet, lord)) {
        'same' => 30.0,
        'friend' => 15.0,
        'enemy' => 3.75,
        _ => 7.5,
      };
    }
  }
  return total / divisions.length * (45.0 / 45.0);
}

/// Kept local so shadbala does not depend on the varga module, which depends
/// on `NatalChart` and would make a cycle.
int _vargaSignFor(int division, double siderealLon) {
  final sign = signIndex(siderealLon);
  final within = siderealLon % 30.0;
  final odd = sign % 2 == 0;
  switch (division) {
    case 1:
      return sign;
    case 2:
      return (within < 15) == odd ? 4 : 3;
    case 3:
      return (sign + (within / 10).floor().clamp(0, 2) * 4) % 12;
    case 7:
      final start = odd ? sign : (sign + 6) % 12;
      return (start + (within / (30 / 7)).floor().clamp(0, 6)) % 12;
    case 9:
      return navamsaSign(siderealLon);
    case 12:
      return (sign + (within / 2.5).floor().clamp(0, 11)) % 12;
    case 30:
      if (odd) {
        if (within < 5) return 0;
        if (within < 10) return 10;
        if (within < 18) return 8;
        if (within < 25) return 2;
        return 6;
      }
      if (within < 5) return 1;
      if (within < 12) return 5;
      if (within < 20) return 11;
      if (within < 25) return 9;
      return 7;
    default:
      return sign;
  }
}

/// Ojhayugma — odd and even, in the rashi and the navamsa.
double _ojhayugmaBala(String planet, double siderealLon) {
  final wantsEven = planet == 'Moon' || planet == 'Venus';
  var total = 0.0;
  final rashiOdd = signIndex(siderealLon) % 2 == 0;
  final navamsaOdd = navamsaSign(siderealLon) % 2 == 0;
  if (rashiOdd != wantsEven) total += 15;
  if (navamsaOdd != wantsEven) total += 15;
  return total;
}

/// Kendradi — angular houses are strongest.
double _kendradiBala(int house) {
  if (house == 0) return 0;
  if (const {1, 4, 7, 10}.contains(house)) return 60;
  if (const {2, 5, 8, 11}.contains(house)) return 30;
  return 15;
}

/// Drekkana bala — male, hermaphrodite and female planets each own a third of
/// the sign.
double _drekkanaBala(String planet, double siderealLon) {
  final third = ((siderealLon % 30.0) / 10.0).floor().clamp(0, 2);
  const male = {'Sun', 'Mars', 'Jupiter'};
  const neuter = {'Mercury', 'Saturn'};
  const female = {'Moon', 'Venus'};
  if (third == 0 && male.contains(planet)) return 15;
  if (third == 1 && neuter.contains(planet)) return 15;
  if (third == 2 && female.contains(planet)) return 15;
  return 0;
}

/// Dig bala — strongest in its own direction, weakest opposite.
double _digBala(String planet, double siderealLon, double lagnaSidereal) {
  final house = digBalaHouse[planet];
  if (house == null) return 0;
  // The strong point is the cusp of that house from the lagna degree.
  final strongPoint = norm360(lagnaSidereal + (house - 1) * 30.0);
  final weakPoint = norm360(strongPoint + 180.0);
  return separation(siderealLon, weakPoint) / 3.0;
}

/// Nathonnatha — day planets at noon, night planets at midnight.
double _nathonnathaBala(String planet, double fractionOfDayFromMidnight) {
  if (planet == 'Mercury') return 60;
  // Distance from midnight, 0..1 where 0.5 is noon.
  final fromMidnight = (fractionOfDayFromMidnight % 1.0);
  final nightStrength = (1 - 2 * (fromMidnight - 0.5).abs()) * 60;
  const nocturnal = {'Moon', 'Mars', 'Saturn'};
  return nocturnal.contains(planet) ? 60 - nightStrength : nightStrength;
}

/// Paksha bala — benefics wax with the Moon, malefics wane with it.
double _pakshaBala(String planet, double elongation) {
  final waxing = elongation <= 180 ? elongation : 360 - elongation;
  final benefic = _benefics.contains(planet);
  final value = waxing / 180.0 * 60.0;
  final result = benefic ? value : 60 - value;
  // The Moon's own paksha bala is doubled, which is the classical exception.
  return planet == 'Moon' ? result * 2 : result;
}

/// Tribhaga — each third of day and night has an owner.
double _tribhagaBala(String planet, bool daytime, int third) {
  if (planet == 'Jupiter') return 60;
  const dayOwners = ['Mercury', 'Sun', 'Saturn'];
  const nightOwners = ['Moon', 'Venus', 'Mars'];
  final owner = daytime ? dayOwners[third] : nightOwners[third];
  return owner == planet ? 60 : 0;
}

/// Ayana bala — strength from declination.
double _ayanaBala(String planet, double declination) {
  const northStrong = {'Sun', 'Mars', 'Jupiter', 'Venus', 'Mercury'};
  final signed = northStrong.contains(planet) ? declination : -declination;
  final value = (24.0 + signed) / 48.0 * 60.0;
  final clamped = value.clamp(0.0, 60.0);
  // The Sun's ayana bala is doubled.
  return planet == 'Sun' ? clamped * 2 : clamped;
}

/// The Parashara drishti curve, in virupas, by longitudinal distance.
double _drishtiValue(double distance) {
  // Parallel lists rather than a map, because Dart will not let a const map
  // be keyed on double.
  const at = <double>[0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 360];
  const value = <double>[0, 0, 15, 45, 30, 45, 60, 45, 30, 15, 0, 0];
  final d = norm360(distance);
  for (var i = 0; i < at.length - 1; i++) {
    if (d >= at[i] && d <= at[i + 1]) {
      final t = (d - at[i]) / (at[i + 1] - at[i]);
      return value[i] + (value[i + 1] - value[i]) * t;
    }
  }
  return 0;
}

/// Drik bala — the net of every aspect a graha receives.
double _drikBala(String planet, List<GrahaRow> grahas) {
  final target = grahas.where((g) => g.name == planet).firstOrNull;
  if (target == null) return 0;
  var total = 0.0;
  for (final other in grahas) {
    if (other.name == planet || other.name == 'Lagna') continue;
    if (!_sevenGrahas.contains(other.name) &&
        other.name != 'Rahu' &&
        other.name != 'Ketu') {
      continue;
    }
    final distance = norm360(target.siderealLon - other.siderealLon);
    var value = _drishtiValue(distance);

    // The special aspects: Mars on the 4th and 8th, Jupiter on the 5th and
    // 9th, Saturn on the 3rd and 10th, each at full strength.
    final houses = ((signIndex(target.siderealLon) -
                signIndex(other.siderealLon)) %
            12 +
        12) %
        12 + 1;
    if (aspectsFrom(other.name).contains(houses) && houses != 7) {
      value = math.max(value, 45);
    }

    final benefic = _benefics.contains(other.name) ||
        (other.name == 'Mercury' && !_isAfflictedMercury(grahas));
    total += benefic ? value / 4.0 : -value / 4.0;
  }
  return total;
}

/// Mercury takes the nature of its company, which is the one place a fixed
/// benefic/malefic list is wrong.
bool _isAfflictedMercury(List<GrahaRow> grahas) {
  final mercury = grahas.where((g) => g.name == 'Mercury').firstOrNull;
  if (mercury == null) return false;
  const malefics = {'Sun', 'Mars', 'Saturn', 'Rahu', 'Ketu'};
  for (final g in grahas) {
    if (!malefics.contains(g.name)) continue;
    if (signIndex(g.siderealLon) == signIndex(mercury.siderealLon)) return true;
  }
  return false;
}

/// Cheshta bala — motional strength, which retrogradation dominates.
///
/// The classical scheme grades a planet's motion into eight states and awards
/// virupas by state. Retrograde earns the maximum: a vakri graha is at its
/// closest to the Earth and, in the tradition's reading, at its most
/// insistent. Implemented against real computed speed rather than a table
/// lookup, which is only possible now that speed exists (G-01).
double _cheshtaBala(String planet, double speed) {
  if (planet == 'Sun' || planet == 'Moon') {
    // Neither ever retrogrades. The classics substitute ayana bala for the Sun
    // and paksha bala for the Moon; both are added separately, so returning
    // the neutral 30 here avoids double counting.
    return 30.0;
  }
  final mean = meanDailyMotion[planet] ?? 1.0;
  if (speed < -mean * 0.5) return 60.0; // vakra — full retrograde
  if (speed < 0) return 45.0;           // anuvakra — turning back
  if (speed.abs() < mean * 0.05) return 15.0; // vikala — stationary
  final ratio = speed / mean;
  if (ratio < 0.5) return 15.0;   // manda
  if (ratio < 0.9) return 22.5;   // mandatara
  if (ratio < 1.1) return 30.0;   // sama
  if (ratio < 1.5) return 30.0;   // chara
  return 45.0;                    // atichara
}

/// The state name, for display.
String cheshtaState(String planet, double speed) {
  if (planet == 'Sun' || planet == 'Moon') return 'sama';
  final mean = meanDailyMotion[planet] ?? 1.0;
  if (speed < -mean * 0.5) return 'vakra';
  if (speed < 0) return 'anuvakra';
  if (speed.abs() < mean * 0.05) return 'vikala';
  final ratio = speed / mean;
  if (ratio < 0.5) return 'manda';
  if (ratio < 0.9) return 'mandatara';
  if (ratio < 1.1) return 'sama';
  if (ratio < 1.5) return 'chara';
  return 'atichara';
}

const Map<String, String> cheshtaMeaning = {
  'vakra': 'retrograde — at its strongest and most insistent',
  'anuvakra': 'turning retrograde',
  'vikala': 'stationary — holding, neither giving nor withholding',
  'manda': 'slow',
  'mandatara': 'very slow',
  'sama': 'at its usual pace',
  'chara': 'moving freely',
  'atichara': 'racing — results come fast and pass quickly',
};

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

/// Computes shadbala for a chart.
///
/// [day] supplies sunrise and sunset so that the time-of-day components are
/// real rather than assumed; without it they fall back to a symmetric day,
/// which is honest for a chart with no birth time.
ShadbalaReport shadbalaFor(NatalChart chart, {PanchangaDay? day}) {
  final grahas = chart.grahas;
  final sun = grahas.where((g) => g.name == 'Sun').firstOrNull;
  final moon = grahas.where((g) => g.name == 'Moon').firstOrNull;
  final elongation =
      (sun == null || moon == null) ? 90.0 : norm360(moon.siderealLon - sun.siderealLon);

  // Where in the day the birth fell.
  double fractionFromMidnight = 0.5;
  var daytime = true;
  var third = 0;
  if (day != null) {
    final sunrise = day.daylight.sunrise;
    final sunset = day.daylight.sunset;
    final birth = chart.input.localDateTime;
    daytime = birth.isAfter(sunrise) && birth.isBefore(sunset);
    final spanStart = daytime ? sunrise : sunset;
    final spanEnd = daytime ? sunset : sunrise.add(const Duration(days: 1));
    final total = spanEnd.difference(spanStart).inSeconds;
    final into = birth.difference(spanStart).inSeconds;
    if (total > 0) {
      third = ((into / total) * 3).floor().clamp(0, 2);
    }
    fractionFromMidnight =
        (birth.hour + birth.minute / 60.0) / 24.0;
  } else {
    fractionFromMidnight = (chart.input.localDateTime.hour +
            chart.input.localDateTime.minute / 60.0) /
        24.0;
    daytime = chart.input.localDateTime.hour >= 6 &&
        chart.input.localDateTime.hour < 18;
  }

  // Day, month and year lords, which carry fixed virupa awards.
  final weekday = chart.input.localDateTime.weekday % 7;
  const varaLords = ['Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn'];
  final varaLord = varaLords[weekday];
  final horaLord = varaLords[(weekday * 24 + chart.input.localDateTime.hour) % 7];

  final wars = {for (final w in planetaryWars(grahas)) w.loser: w};

  final out = <BalaBreakdown>[];
  for (final planet in _sevenGrahas) {
    final g = grahas.where((x) => x.name == planet).firstOrNull;
    if (g == null) continue;

    final uchcha = _uchchaBala(planet, g.siderealLon);
    final sapta = _saptavargajaBala(planet, g.siderealLon);
    final ojha = _ojhayugmaBala(planet, g.siderealLon);
    final kendradi = _kendradiBala(g.house);
    final drekkana = _drekkanaBala(planet, g.siderealLon);
    final sthana = uchcha + sapta + ojha + kendradi + drekkana;

    final dig = chart.input.timeUnknown
        ? 0.0
        : _digBala(planet, g.siderealLon, chart.lagnaSidereal);

    final nathonnatha = _nathonnathaBala(planet, fractionFromMidnight);
    final paksha = _pakshaBala(planet, elongation);
    final tribhaga = _tribhagaBala(planet, daytime, third);
    final varsha = 0.0; // year lord: needs the samvatsara, see G-24
    final masa = 0.0;
    final vara = varaLord == planet ? 45.0 : 0.0;
    final hora = horaLord == planet ? 60.0 : 0.0;
    final ayana = _ayanaBala(planet, g.declination);
    final yuddha = wars.containsKey(planet) ? -30.0 : 0.0;
    final kala = nathonnatha + paksha + tribhaga + varsha + masa + vara + hora +
        ayana + yuddha;

    final cheshta = _cheshtaBala(planet, g.speed);
    final naisargika = naisargikaBala[planet] ?? 0;
    final drik = _drikBala(planet, grahas);

    out.add(BalaBreakdown(
      planet: planet,
      sthana: sthana,
      uchcha: uchcha,
      saptavargaja: sapta,
      ojhayugma: ojha,
      kendradi: kendradi,
      drekkana: drekkana,
      dig: dig,
      kala: kala,
      nathonnatha: nathonnatha,
      paksha: paksha,
      tribhaga: tribhaga,
      varsha: varsha,
      masa: masa,
      vara: vara,
      hora: hora,
      ayana: ayana,
      yuddha: yuddha,
      cheshta: cheshta,
      naisargika: naisargika,
      drik: drik,
    ));
  }

  final ranked = [...out]..sort((a, b) => b.totalVirupa.compareTo(a.totalVirupa));

  return ShadbalaReport(
    planets: out,
    bhavas: _bhavaBalas(chart, out),
    strongest: ranked.isEmpty ? '' : ranked.first.planet,
    weakest: ranked.isEmpty ? '' : ranked.last.planet,
  );
}

/// Bhava bala — the strength of the houses themselves.
List<BhavaBala> _bhavaBalas(NatalChart chart, List<BalaBreakdown> planets) {
  if (chart.input.timeUnknown) return const [];
  final lagnaSign = signIndex(chart.lagnaSidereal);
  final byPlanet = {for (final p in planets) p.planet: p};

  // Houses are strongest in the direction their natural significator favours.
  const bhavaDig = {
    1: 'Mercury', 2: 'Mercury', 3: 'Mars', 4: 'Moon', 5: 'Jupiter',
    6: 'Saturn', 7: 'Venus', 8: 'Saturn', 9: 'Jupiter', 10: 'Sun',
    11: 'Jupiter', 12: 'Saturn',
  };

  final out = <BhavaBala>[];
  for (var house = 1; house <= 12; house++) {
    final sign = (lagnaSign + house - 1) % 12;
    final lord = signs[sign].ruler;
    final adhipati = byPlanet[lord]?.totalVirupa ?? 0;

    final karaka = bhavaDig[house]!;
    final dig = byPlanet[karaka]?.dig ?? 0;

    // Net aspect on the house cusp.
    var drishti = 0.0;
    final cusp = norm360(chart.lagnaSidereal + (house - 1) * 30.0);
    for (final g in chart.grahas) {
      if (g.name == 'Lagna') continue;
      if (!_sevenGrahas.contains(g.name) &&
          g.name != 'Rahu' && g.name != 'Ketu') {
        continue;
      }
      final value = _drishtiValue(norm360(cusp - g.siderealLon));
      final benefic = _benefics.contains(g.name);
      drishti += benefic ? value / 4 : -value / 4;
    }

    out.add(BhavaBala(
      house: house,
      adhipati: adhipati,
      dig: dig,
      drishti: drishti,
    ));
  }
  return out;
}

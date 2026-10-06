/// House systems.
///
/// Gap G-02, the most consequential defect in the old engine. What was called
/// `_placidusLike` returned `asc + i * 30` — equal house under a name that
/// promised Placidus — and the midheaven was computed but never used as the
/// tenth cusp. Every Western chart the app drew had a tenth house that
/// disagreed with its own MC.
///
/// Ten systems are implemented here, covering what a Western practitioner and
/// a jyotishi each expect to find:
///
///   Placidus, Koch, Porphyry, Regiomontanus, Campanus, Alcabitius,
///   Topocentric, Equal, Whole Sign — and Sripati, the Vedic bhava chalit.
///
/// Campanus and Regiomontanus are solved as a genuine three-dimensional
/// intersection (house circle through the horizon's north and south points,
/// crossed with the ecliptic) rather than through a remembered closed form.
/// That is slower by a few microseconds and it cannot be subtly wrong.
///
/// High latitudes are handled honestly. Placidus and Koch are undefined
/// beyond the polar circles — a degree there simply never rises — so rather
/// than emitting a NaN the routine falls back to Porphyry and says which
/// system actually produced the numbers. Silence would be worse: a chart for
/// Tromsø would look computed when it was not.
library;

import 'dart:math' as math;

import 'units.dart';

enum HouseSystem {
  placidus,
  koch,
  porphyry,
  regiomontanus,
  campanus,
  alcabitius,
  topocentric,
  equal,
  wholeSign,
  /// Sripati — the Vedic bhava chalit. Porphyry cusps are read as bhava
  /// midpoints and the boundaries fall halfway between them.
  sripati,
}

extension HouseSystemInfo on HouseSystem {
  String get label => switch (this) {
        HouseSystem.placidus => 'Placidus',
        HouseSystem.koch => 'Koch',
        HouseSystem.porphyry => 'Porphyry',
        HouseSystem.regiomontanus => 'Regiomontanus',
        HouseSystem.campanus => 'Campanus',
        HouseSystem.alcabitius => 'Alcabitius',
        HouseSystem.topocentric => 'Topocentric',
        HouseSystem.equal => 'Equal',
        HouseSystem.wholeSign => 'Whole Sign',
        HouseSystem.sripati => 'Sripati (bhava chalit)',
      };

  /// One line on what the system divides. Shown beside the picker, because
  /// "which house system" is a question about method, not preference.
  String get principle => switch (this) {
        HouseSystem.placidus => 'Trisects the time each degree spends above the horizon.',
        HouseSystem.koch => 'Trisects the rising time of the MC degree.',
        HouseSystem.porphyry => 'Trisects the ecliptic arc between the angles.',
        HouseSystem.regiomontanus => 'Divides the celestial equator into twelve.',
        HouseSystem.campanus => 'Divides the prime vertical into twelve.',
        HouseSystem.alcabitius => 'Trisects the semi-arc of the ascending degree.',
        HouseSystem.topocentric => 'Polich–Page; poles scaled in thirds of the latitude.',
        HouseSystem.equal => 'Thirty degrees from the ascendant.',
        HouseSystem.wholeSign => 'One sign, one house — the oldest division.',
        HouseSystem.sripati => 'Porphyry midpoints, boundaries halfway between.',
      };

  /// Systems that cannot be computed inside the polar circles.
  bool get failsAtHighLatitude =>
      this == HouseSystem.placidus ||
      this == HouseSystem.koch ||
      this == HouseSystem.topocentric ||
      this == HouseSystem.alcabitius;

  String get storageKey => name;

  static HouseSystem fromKey(String? key) {
    if (key == null) return HouseSystem.placidus;
    for (final h in HouseSystem.values) {
      if (h.name == key) return h;
    }
    return HouseSystem.placidus;
  }
}

class HouseCusps {
  const HouseCusps({
    required this.cusps,
    required this.ascendant,
    required this.midheaven,
    required this.vertex,
    required this.eastPoint,
    required this.system,
    required this.requested,
    this.fellBack = false,
  });

  /// Twelve tropical ecliptic longitudes, cusps[0] is the first house.
  final List<double> cusps;

  final double ascendant;
  final double midheaven;

  /// The Vertex — where the ecliptic meets the prime vertical in the west.
  /// Part of G-31; it falls out of the same geometry as Campanus, so it is
  /// computed here rather than bolted on elsewhere.
  final double vertex;

  /// The East Point (Equatorial Ascendant).
  final double eastPoint;

  /// What actually produced these numbers.
  final HouseSystem system;

  /// What the reader asked for. Differs from [system] only when a polar
  /// latitude forced a fallback.
  final HouseSystem requested;

  /// True when the requested system was undefined here and Porphyry stood in.
  final bool fellBack;

  double get ic => norm360(midheaven + 180);
  double get descendant => norm360(ascendant + 180);

  /// House 1..12 holding a tropical longitude.
  int houseOf(double longitude) {
    for (var i = 0; i < 12; i++) {
      final a = cusps[i];
      final b = cusps[(i + 1) % 12];
      final span = norm360(b - a);
      final within = norm360(longitude - a);
      if (within < span) return i + 1;
    }
    return 1;
  }

  /// How far into its house a longitude sits, 0..1. Used by the strength
  /// modules, where a planet just inside a cusp is not the same as one at the
  /// midpoint of the house.
  double positionInHouse(double longitude) {
    final h = houseOf(longitude) - 1;
    final a = cusps[h];
    final span = norm360(cusps[(h + 1) % 12] - a);
    if (span <= 0) return 0;
    return (norm360(longitude - a) / span).clamp(0.0, 1.0);
  }
}

// ---------------------------------------------------------------------------
// Angles
// ---------------------------------------------------------------------------

/// Ecliptic longitude of the point on the ecliptic with the given right
/// ascension.
double _eclipticFromRa(double ra, double eps) =>
    norm360(atan2d(sind(ra), cosd(ra) * cosd(eps)));

/// Midheaven from the right ascension of the meridian.
double midheavenFrom(double ramc, double eps) => _eclipticFromRa(ramc, eps);

/// The ascendant, or any cusp, as "the ecliptic degree rising under a pole".
///
/// With `pole = latitude` and `h = ramc` this is the ordinary ascendant; the
/// quadrant systems reuse it with a reduced pole and a shifted meridian, which
/// is what makes Regiomontanus and Topocentric one line each.
double ascendantUnderPole(double h, double pole, double eps) {
  final y = cosd(h);
  final x = -(sind(h) * cosd(eps) + tand(pole) * sind(eps));
  return norm360(atan2d(y, x));
}

/// The ascendant proper.
double ascendantFrom(double ramc, double latitude, double eps) =>
    ascendantUnderPole(ramc, latitude, eps);

// ---------------------------------------------------------------------------
// Vector helpers for the circle-intersection systems
// ---------------------------------------------------------------------------

class _V3 {
  const _V3(this.x, this.y, this.z);
  final double x, y, z;

  _V3 cross(_V3 o) => _V3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  double dot(_V3 o) => x * o.x + y * o.y + z * o.z;

  _V3 get unit {
    final n = math.sqrt(x * x + y * y + z * z);
    return n == 0 ? const _V3(0, 0, 1) : _V3(x / n, y / n, z / n);
  }

  _V3 operator -() => _V3(-x, -y, -z);
}

_V3 _fromSpherical(double lon, double lat) =>
    _V3(cosd(lat) * cosd(lon), cosd(lat) * sind(lon), sind(lat));

/// Ecliptic longitude of an equatorial unit vector.
double _eclipticLongitudeOf(_V3 v, double eps) {
  final yEc = v.y * cosd(eps) + v.z * sind(eps);
  final xEc = v.x;
  return norm360(atan2d(yEc, xEc));
}

/// Intersects a great circle (given by its normal) with the ecliptic and
/// returns the ecliptic longitude of whichever crossing lies nearer [near].
double _eclipticCrossing(_V3 normal, double eps, double near) {
  // Pole of the ecliptic in equatorial coordinates.
  final eclipticNormal = _V3(0, -sind(eps), cosd(eps));
  final line = normal.cross(eclipticNormal).unit;
  final a = _eclipticLongitudeOf(line, eps);
  final b = _eclipticLongitudeOf(-line, eps);
  return separation(a, near) <= separation(b, near) ? a : b;
}

// ---------------------------------------------------------------------------
// The systems
// ---------------------------------------------------------------------------

List<double> _equalCusps(double asc) =>
    List<double>.generate(12, (i) => norm360(asc + i * 30.0));

List<double> _wholeSignCusps(double asc) {
  final start = (asc / 30).floor() * 30.0;
  return List<double>.generate(12, (i) => norm360(start + i * 30.0));
}

List<double> _porphyryCusps(double asc, double mc) {
  final ic = norm360(mc + 180);
  final dsc = norm360(asc + 180);
  // Arc from MC forward to ASC, and from ASC forward to IC.
  final q1 = norm360(asc - mc) / 3.0;
  final q2 = norm360(ic - asc) / 3.0;
  final c = List<double>.filled(12, 0);
  c[0] = asc;
  c[1] = norm360(asc + q2);
  c[2] = norm360(asc + 2 * q2);
  c[3] = ic;
  c[4] = norm360(ic + q1);
  c[5] = norm360(ic + 2 * q1);
  c[6] = dsc;
  c[7] = norm360(dsc + q2);
  c[8] = norm360(dsc + 2 * q2);
  c[9] = mc;
  c[10] = norm360(mc + q1);
  c[11] = norm360(mc + 2 * q1);
  return c;
}

/// Sripati: Porphyry cusps are bhava *madhya* (midpoints); the bhava
/// boundaries fall halfway between consecutive midpoints.
///
/// This is the chalit chart. Whole-sign and chalit disagree about roughly one
/// planet in three charts, and that disagreement is the commonest reason two
/// astrologers read the same kundali differently — which is why the app now
/// shows both rather than picking a side silently.
List<double> _sripatiCusps(double asc, double mc) {
  final madhya = _porphyryCusps(asc, mc);
  final c = List<double>.filled(12, 0);
  for (var i = 0; i < 12; i++) {
    final a = madhya[i];
    final prev = madhya[(i + 11) % 12];
    final gap = norm360(a - prev);
    c[i] = norm360(prev + gap / 2.0);
  }
  return c;
}

/// Placidus, by its actual definition: a cusp is the degree that has used up
/// one third or two thirds of the time it spends above (or below) the horizon.
List<double> _placidusCusps(double ramc, double lat, double eps) {
  double solve(double offsetSeed, double fraction, bool diurnal) {
    var offset = offsetSeed;
    for (var i = 0; i < 40; i++) {
      final ra = norm360(ramc + offset);
      final lon = _eclipticFromRa(ra, eps);
      final decl = asind(sind(eps) * sind(lon));
      final tanProduct = tand(lat) * tand(decl);
      if (tanProduct.abs() >= 1.0) return double.nan; // circumpolar
      final ad = asind(tanProduct);
      final semiArc = diurnal ? 90.0 + ad : 90.0 - ad;
      final next = diurnal ? fraction * semiArc : 180.0 - fraction * semiArc;
      if ((next - offset).abs() < 1e-9) return _eclipticFromRa(norm360(ramc + next), eps);
      offset = next;
    }
    return _eclipticFromRa(norm360(ramc + offset), eps);
  }

  final c11 = solve(30, 1 / 3, true);
  final c12 = solve(60, 2 / 3, true);
  final c2 = solve(120, 2 / 3, false);
  final c3 = solve(150, 1 / 3, false);
  if (c11.isNaN || c12.isNaN || c2.isNaN || c3.isNaN) return const [];

  final asc = ascendantFrom(ramc, lat, eps);
  final mc = midheavenFrom(ramc, eps);
  return [
    asc, c2, c3,
    norm360(mc + 180), norm360(c11 + 180), norm360(c12 + 180),
    norm360(asc + 180), norm360(c2 + 180), norm360(c3 + 180),
    mc, c11, c12,
  ];
}

/// Koch: the ascendant evaluated at three equally spaced sidereal times
/// across the rising of the MC degree.
List<double> _kochCusps(double ramc, double lat, double eps) {
  final mc = midheavenFrom(ramc, eps);
  final declMc = asind(sind(eps) * sind(mc));
  final tanProduct = tand(lat) * tand(declMc);
  if (tanProduct.abs() >= 1.0) return const [];
  final ad = asind(tanProduct);
  final semiDiurnal = 90.0 + ad;
  final semiNocturnal = 90.0 - ad;

  final asc = ascendantFrom(ramc, lat, eps);
  final c11 = ascendantFrom(norm360(ramc - 2 * semiDiurnal / 3), lat, eps);
  final c12 = ascendantFrom(norm360(ramc - semiDiurnal / 3), lat, eps);
  final c2 = ascendantFrom(norm360(ramc + semiNocturnal / 3), lat, eps);
  final c3 = ascendantFrom(norm360(ramc + 2 * semiNocturnal / 3), lat, eps);

  return [
    asc, c2, c3,
    norm360(mc + 180), norm360(c11 + 180), norm360(c12 + 180),
    norm360(asc + 180), norm360(c2 + 180), norm360(c3 + 180),
    mc, c11, c12,
  ];
}

/// Alcabitius: trisects the ascending degree's own semi-arc in right
/// ascension. The oldest of the quadrant systems still in general use.
List<double> _alcabitiusCusps(double ramc, double lat, double eps) {
  final asc = ascendantFrom(ramc, lat, eps);
  final mc = midheavenFrom(ramc, eps);
  final declAsc = asind(sind(eps) * sind(asc));
  final tanProduct = tand(lat) * tand(declAsc);
  if (tanProduct.abs() >= 1.0) return const [];
  final ad = asind(tanProduct);
  final sd = 90.0 + ad;
  final sn = 90.0 - ad;

  final c11 = _eclipticFromRa(norm360(ramc + sd / 3), eps);
  final c12 = _eclipticFromRa(norm360(ramc + 2 * sd / 3), eps);
  final c2 = _eclipticFromRa(norm360(ramc + sd + sn / 3), eps);
  final c3 = _eclipticFromRa(norm360(ramc + sd + 2 * sn / 3), eps);

  return [
    asc, c2, c3,
    norm360(mc + 180), norm360(c11 + 180), norm360(c12 + 180),
    norm360(asc + 180), norm360(c2 + 180), norm360(c3 + 180),
    mc, c11, c12,
  ];
}

/// Regiomontanus and Topocentric share the "ascendant under a reduced pole"
/// construction and differ only in how the pole is reduced.
List<double> _poleCusps(double ramc, double lat, double eps,
    {required bool topocentric}) {
  double pole(double thirds) => topocentric
      ? r2d(math.atan(tand(lat) * thirds))
      : r2d(math.atan(tand(lat) * sind(thirds * 90.0)));

  // thirds: 1/3 for cusps 11 and 3, 2/3 for cusps 12 and 2.
  final p13 = pole(1 / 3);
  final p23 = pole(2 / 3);

  final asc = ascendantFrom(ramc, lat, eps);
  final mc = midheavenFrom(ramc, eps);
  final c11 = ascendantUnderPole(norm360(ramc - 60), p13, eps);
  final c12 = ascendantUnderPole(norm360(ramc - 30), p23, eps);
  final c2 = ascendantUnderPole(norm360(ramc + 30), p23, eps);
  final c3 = ascendantUnderPole(norm360(ramc + 60), p13, eps);

  return [
    asc, c2, c3,
    norm360(mc + 180), norm360(c11 + 180), norm360(c12 + 180),
    norm360(asc + 180), norm360(c2 + 180), norm360(c3 + 180),
    mc, c11, c12,
  ];
}

/// Campanus — the prime vertical divided into twelve.
///
/// Solved geometrically. The house circle passes through the north and south
/// points of the horizon and through the division point on the prime vertical;
/// the cusp is where that circle crosses the ecliptic.
List<double> _campanusCusps(double ramc, double lat, double eps) {
  // South point of the horizon, in equatorial coordinates. The house circles
  // all contain this axis.
  final south = _fromSpherical(ramc, lat - 90.0);
  final asc = ascendantFrom(ramc, lat, eps);
  final mc = midheavenFrom(ramc, eps);
  final reference = _porphyryCusps(asc, mc);

  _V3 primeVerticalPoint(double altitude) {
    // Horizon frame: x south, y east, z zenith; azimuth due east.
    const xHor = 0.0;
    final yHor = cosd(altitude);
    final zHor = sind(altitude);
    // To the hour-angle frame.
    final xH = xHor * sind(lat) + zHor * cosd(lat);
    final yH = yHor;
    final zH = -xHor * cosd(lat) + zHor * sind(lat);
    // To the equatorial frame (hour-angle frame rotated by RAMC about z).
    return _V3(
      xH * cosd(ramc) - yH * sind(ramc),
      xH * sind(ramc) + yH * cosd(ramc),
      zH,
    ).unit;
  }

  double cusp(int house) {
    final m = (house - 10) % 12;
    final altitude = 90.0 - 30.0 * m;
    final p = primeVerticalPoint(altitude);
    final normal = south.cross(p).unit;
    return _eclipticCrossing(normal, eps, reference[house - 1]);
  }

  final out = List<double>.filled(12, 0);
  for (var h = 1; h <= 12; h++) {
    out[h - 1] = cusp(h);
  }
  out[0] = asc;
  out[9] = mc;
  out[6] = norm360(asc + 180);
  out[3] = norm360(mc + 180);
  return out;
}

/// Regiomontanus solved the same geometric way as Campanus, as a cross-check
/// on the closed form in [_poleCusps]. The equator, not the prime vertical, is
/// what gets divided.
List<double> _regiomontanusGeometric(double ramc, double lat, double eps) {
  final south = _fromSpherical(ramc, lat - 90.0);
  final asc = ascendantFrom(ramc, lat, eps);
  final mc = midheavenFrom(ramc, eps);
  final reference = _porphyryCusps(asc, mc);

  double cusp(int house) {
    final m = (house - 10) % 12;
    final p = _fromSpherical(norm360(ramc + 30.0 * m), 0);
    final normal = south.cross(p).unit;
    return _eclipticCrossing(normal, eps, reference[house - 1]);
  }

  final out = List<double>.filled(12, 0);
  for (var h = 1; h <= 12; h++) {
    out[h - 1] = cusp(h);
  }
  out[0] = asc;
  out[9] = mc;
  out[6] = norm360(asc + 180);
  out[3] = norm360(mc + 180);
  return out;
}

/// The Vertex: the ecliptic's western crossing of the prime vertical.
double _vertexOf(double ramc, double lat, double eps) {
  // The vertex is the ascendant computed for the co-latitude at the meridian
  // opposite, which is the standard construction.
  final coLat = 90.0 - lat.abs();
  final v = ascendantFrom(norm360(ramc + 180), lat >= 0 ? coLat : -coLat, eps);
  return norm360(v + 180);
}

/// The East Point, or Equatorial Ascendant: the ecliptic degree rising for an
/// observer at the equator with the same sidereal time.
double _eastPointOf(double ramc, double eps) =>
    ascendantUnderPole(ramc, 0, eps);

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

/// Computes cusps for [system].
///
/// [ramc] is the *apparent* local sidereal time in degrees — see
/// `nutation.dart`. Passing mean sidereal time here leaves about 17 arcsec of
/// error on every angle, which was gap G-06.
HouseCusps computeHouses({
  required double ramc,
  required double latitude,
  required double obliquity,
  required HouseSystem system,
}) {
  final safeLat = latitude.clamp(-89.9999, 89.9999).toDouble();
  final asc = ascendantFrom(ramc, safeLat, obliquity);
  final mc = midheavenFrom(ramc, obliquity);

  List<double> cusps;
  var used = system;
  var fellBack = false;

  switch (system) {
    case HouseSystem.equal:
      cusps = _equalCusps(asc);
    case HouseSystem.wholeSign:
      cusps = _wholeSignCusps(asc);
    case HouseSystem.porphyry:
      cusps = _porphyryCusps(asc, mc);
    case HouseSystem.sripati:
      cusps = _sripatiCusps(asc, mc);
    case HouseSystem.campanus:
      cusps = _campanusCusps(ramc, safeLat, obliquity);
    case HouseSystem.regiomontanus:
      cusps = _regiomontanusGeometric(ramc, safeLat, obliquity);
    case HouseSystem.topocentric:
      cusps = _poleCusps(ramc, safeLat, obliquity, topocentric: true);
    case HouseSystem.placidus:
      cusps = _placidusCusps(ramc, safeLat, obliquity);
    case HouseSystem.koch:
      cusps = _kochCusps(ramc, safeLat, obliquity);
    case HouseSystem.alcabitius:
      cusps = _alcabitiusCusps(ramc, safeLat, obliquity);
  }

  if (cusps.isEmpty || cusps.any((c) => c.isNaN)) {
    // Inside the polar circles the time-based systems have no answer. Say so
    // rather than returning a chart that looks computed.
    cusps = _porphyryCusps(asc, mc);
    used = HouseSystem.porphyry;
    fellBack = true;
  }

  return HouseCusps(
    cusps: cusps,
    ascendant: asc,
    midheaven: mc,
    vertex: _vertexOf(ramc, safeLat, obliquity),
    eastPoint: _eastPointOf(ramc, obliquity),
    system: used,
    requested: system,
    fellBack: fellBack,
  );
}

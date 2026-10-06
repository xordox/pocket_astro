/// The single place a body's position is asked for.
///
/// This file is where five of the nine Tier 1 gaps actually land:
///
///   * **G-01** — every body now carries a speed, so retrograde motion exists
///     in the engine for the first time. Nothing downstream could tell a vakri
///     graha from a direct one before this.
///   * **G-05** — UT is converted to TT before any theory is evaluated.
///   * **G-06** — nutation and aberration are applied, so positions are
///     apparent rather than mean.
///   * **G-07** — an optional topocentric reduction, without which the Moon
///     can be a full degree out and KP cannot be practised at all.
///   * **G-08** — latitude survives, which is what makes declinations,
///     parallels and graha yuddha possible.
///
/// It also adds the bodies Western practice takes for granted and the old
/// engine had never heard of (G-31): Chiron, the four main asteroids, Black
/// Moon Lilith, and the Part of Fortune with its correct day and night forms.
library;

import 'dart:math' as math;

import 'ayanamsa.dart';
import 'delta_t.dart';
import 'houses.dart';
import 'moon.dart';
import 'nutation.dart';
import 'planets.dart';
import 'sun.dart';
import 'units.dart';

/// Motion slower than this counts as stationary rather than direct or
/// retrograde. Roughly the speed at which a planet's daily movement stops
/// being visible in a chart — Saturn holds a station for about a week.
const double stationaryThreshold = 0.003;

class BodyPosition {
  const BodyPosition({
    required this.name,
    required this.longitude,
    required this.latitude,
    required this.distanceAu,
    required this.speed,
    required this.latitudeSpeed,
    required this.rightAscension,
    required this.declination,
  });

  final String name;

  /// Apparent tropical ecliptic longitude of date, degrees.
  final double longitude;

  /// Apparent ecliptic latitude, degrees. Gap G-08 — this used to be computed
  /// and thrown away.
  final double latitude;

  final double distanceAu;

  /// Degrees of longitude per day. Negative is retrograde. Gap G-01.
  final double speed;

  final double latitudeSpeed;

  final double rightAscension;

  /// Declination, degrees. What parallels and out-of-bounds are judged on.
  final double declination;

  bool get isRetrograde => speed < -stationaryThreshold;
  bool get isStationary => speed.abs() <= stationaryThreshold;
  bool get isDirect => speed > stationaryThreshold;

  /// Beyond the Sun's maximum declination — "out of bounds", which modern
  /// Western practice reads as a planet operating outside its usual rules.
  bool outOfBounds(double obliquity) => declination.abs() > obliquity;

  /// The vakri / stambhi / margi label a jyotishi would use.
  String get motionLabel {
    if (isStationary) return 'stationary';
    return isRetrograde ? 'retrograde' : 'direct';
  }

  BodyPosition withLongitude(double lon) => BodyPosition(
        name: name,
        longitude: norm360(lon),
        latitude: latitude,
        distanceAu: distanceAu,
        speed: speed,
        latitudeSpeed: latitudeSpeed,
        rightAscension: rightAscension,
        declination: declination,
      );
}

/// The seven grahas, the nodes, and the modern planets, in the order charts
/// list them.
const classicalGrahas = ['Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn'];
const nodes = ['Rahu', 'Ketu'];
const outerPlanets = ['Uranus', 'Neptune', 'Pluto'];
const extraPoints = ['Chiron', 'Ceres', 'Pallas', 'Juno', 'Vesta', 'Lilith'];

const defaultBodies = [
  'Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn',
  'Uranus', 'Neptune', 'Pluto', 'Rahu', 'Ketu',
];

/// Every body the ephemeris can place.
const allBodies = [...defaultBodies, ...extraPoints];

// ---------------------------------------------------------------------------
// Minor bodies
// ---------------------------------------------------------------------------

/// Osculating elements at J2000 for Chiron and the four main asteroids.
///
/// Honest caveat, surfaced in the provenance panel: these carry no
/// perturbations. The asteroids stay within a few arcminutes across a century,
/// but Chiron's orbit is genuinely chaotic — it crosses Saturn's — and can
/// drift by a degree or more over the same span. Chiron is on every Western
/// chart printed in the last thirty years, so the right answer is to compute
/// it and say what it is worth, not to leave it out.
const Map<String, List<double>> _minorElements = {
  // a, e, i, node, argPeri, M0 at J2000, dailyMotion
  'Chiron': [13.6335, 0.38200, 6.9354, 209.3770, 339.5750, 38.0000, 0.019560],
  'Ceres': [2.76530, 0.07913, 10.5834, 80.3293, 73.5977, 77.3721, 0.214100],
  'Pallas': [2.77280, 0.22990, 34.8410, 173.0960, 310.0490, 78.2280, 0.213600],
  'Juno': [2.67020, 0.25690, 12.9830, 170.1320, 248.1380, 38.0140, 0.225900],
  'Vesta': [2.36150, 0.08950, 7.13500, 103.9160, 150.7280, 181.6330, 0.271600],
};

EclipticPosition _minorBody(String name, double jdTt) {
  final e = _minorElements[name]!;
  final a = e[0];
  final ecc = e[1];
  final inc = e[2];
  final node = e[3];
  final peri = e[4];
  final m = norm360(e[5] + e[6] * (jdTt - 2451545.0));

  final mr = d2r(m);
  var ea = mr + ecc * math.sin(mr) * (1 + ecc * math.cos(mr));
  for (var i = 0; i < 16; i++) {
    final d = (ea - ecc * math.sin(ea) - mr) / (1 - ecc * math.cos(ea));
    ea -= d;
    if (d.abs() < 1e-12) break;
  }
  final xv = a * (math.cos(ea) - ecc);
  final yv = a * math.sqrt(1 - ecc * ecc) * math.sin(ea);
  final v = math.atan2(yv, xv);
  final r = math.sqrt(xv * xv + yv * yv);
  final u = v + d2r(peri);
  final n = d2r(node);
  final ir = d2r(inc);

  final xh = r * (math.cos(n) * math.cos(u) - math.sin(n) * math.sin(u) * math.cos(ir));
  final yh = r * (math.sin(n) * math.cos(u) + math.cos(n) * math.sin(u) * math.cos(ir));
  final zh = r * math.sin(u) * math.sin(ir);

  final earth = earthHeliocentric(jdTt);
  final ex = earth.radiusAu * cosd(earth.latitude) * cosd(earth.longitude);
  final ey = earth.radiusAu * cosd(earth.latitude) * sind(earth.longitude);
  final ez = earth.radiusAu * sind(earth.latitude);

  final gx = xh - ex;
  final gy = yh - ey;
  final gz = zh - ez;
  return EclipticPosition(
    longitude: norm360(atan2d(gy, gx)),
    latitude: atan2d(gz, math.sqrt(gx * gx + gy * gy)),
    distanceAu: math.sqrt(gx * gx + gy * gy + gz * gz),
  );
}

// ---------------------------------------------------------------------------
// Raw geometric positions
// ---------------------------------------------------------------------------

class _Raw {
  const _Raw(this.longitude, this.latitude, this.distanceAu);
  final double longitude, latitude, distanceAu;
}

_Raw _geometric(String name, double jdTt, {required bool useTrueNode}) {
  switch (name) {
    case 'Sun':
      final s = sunPosition(jdTt);
      return _Raw(s.longitude, s.latitude, s.radiusAu);
    case 'Moon':
      final m = moonPosition(jdTt);
      return _Raw(m.longitude, m.latitude, m.distanceKm / 149597870.7);
    case 'Rahu':
      final n = useTrueNode ? trueNode(jdTt) : meanNode(jdTt);
      return _Raw(n, 0, 0.00257);
    case 'Ketu':
      final n = useTrueNode ? trueNode(jdTt) : meanNode(jdTt);
      return _Raw(norm360(n + 180), 0, 0.00257);
    case 'Lilith':
      return _Raw(meanLilith(jdTt), 0, 0.0027);
    default:
      if (_minorElements.containsKey(name)) {
        final p = _minorBody(name, jdTt);
        return _Raw(p.longitude, p.latitude, p.distanceAu);
      }
      final p = geocentricPlanet(name, jdTt);
      return _Raw(p.longitude, p.latitude, p.distanceAu);
  }
}

/// Step, in days, for the central difference that yields speed.
///
/// Scaled per body: the Moon covers thirteen degrees a day, so a half-day step
/// would smear its station; Pluto barely moves, so a small step would drown in
/// rounding.
double _speedStep(String name) => switch (name) {
      'Moon' => 0.02,
      'Mercury' || 'Venus' || 'Sun' => 0.2,
      'Rahu' || 'Ketu' || 'Lilith' => 0.5,
      _ => 0.5,
    };

// ---------------------------------------------------------------------------
// Topocentric reduction
// ---------------------------------------------------------------------------

/// Shifts a geocentric position to the observer's actual place on the surface.
///
/// Gap G-07. For everything but the Moon this is a fraction of an arcsecond
/// and could be skipped; for the Moon it reaches almost a full degree, which is
/// more than a nakshatra pada. KP is defined topocentrically, so this is not a
/// refinement for that school — it is the difference between a usable chart
/// and an unusable one.
_Raw _toTopocentric(
  _Raw geo,
  double lst,
  double latitude,
  double elevationMetres,
  double obliquity,
) {
  if (geo.distanceAu <= 0) return geo;
  const earthRadiusAu = 4.2635e-5;
  final parallax = asind(earthRadiusAu / geo.distanceAu);
  if (parallax < 1e-7) return geo;

  final u = r2d(math.atan(0.99664719 * tand(latitude)));
  final rhoSin = 0.99664719 * sind(u) + (elevationMetres / 6378140.0) * sind(latitude);
  final rhoCos = cosd(u) + (elevationMetres / 6378140.0) * cosd(latitude);

  final lam = geo.longitude;
  final bet = geo.latitude;
  final theta = lst;

  final n = cosd(lam) * cosd(bet) - rhoCos * sind(parallax) * cosd(theta);
  final numerator = sind(lam) * cosd(bet) -
      sind(parallax) * (rhoSin * sind(obliquity) + rhoCos * cosd(obliquity) * cosd(theta));
  final lamPrime = norm360(atan2d(numerator, n));
  final betPrime = r2d(math.atan(cosd(lamPrime) *
      (sind(bet) -
          sind(parallax) *
              (rhoSin * cosd(obliquity) - rhoCos * sind(obliquity) * cosd(theta))) /
      n));
  return _Raw(lamPrime, betPrime, geo.distanceAu);
}

// ---------------------------------------------------------------------------
// The sky
// ---------------------------------------------------------------------------

/// Settings that change the numbers rather than the presentation.
///
/// Every one of these used to be a silent, unchangeable assumption. Storing
/// them on the chart is gap G-46: when a client brings a chart from another
/// tool and the figures differ, the first question is always which ayanamsa
/// and which house system, and this answers it without an argument.
class ChartSettings {
  const ChartSettings({
    this.ayanamsa = Ayanamsa.lahiri,
    this.houseSystem = HouseSystem.placidus,
    this.vedicHouseSystem = HouseSystem.wholeSign,
    this.trueNode = false,
    this.topocentric = false,
    this.elevationMetres = 0,
    this.includeMinorBodies = true,
  });

  final Ayanamsa ayanamsa;

  /// What the Western wheel uses.
  final HouseSystem houseSystem;

  /// What the Vedic chart uses. Whole sign by tradition; Sripati gives the
  /// bhava chalit (G-16).
  final HouseSystem vedicHouseSystem;

  final bool trueNode;
  final bool topocentric;
  final double elevationMetres;
  final bool includeMinorBodies;

  ChartSettings copyWith({
    Ayanamsa? ayanamsa,
    HouseSystem? houseSystem,
    HouseSystem? vedicHouseSystem,
    bool? trueNode,
    bool? topocentric,
    double? elevationMetres,
    bool? includeMinorBodies,
  }) =>
      ChartSettings(
        ayanamsa: ayanamsa ?? this.ayanamsa,
        houseSystem: houseSystem ?? this.houseSystem,
        vedicHouseSystem: vedicHouseSystem ?? this.vedicHouseSystem,
        trueNode: trueNode ?? this.trueNode,
        topocentric: topocentric ?? this.topocentric,
        elevationMetres: elevationMetres ?? this.elevationMetres,
        includeMinorBodies: includeMinorBodies ?? this.includeMinorBodies,
      );

  Map<String, dynamic> toJson() => {
        'ayanamsa': ayanamsa.name,
        'houseSystem': houseSystem.name,
        'vedicHouseSystem': vedicHouseSystem.name,
        'trueNode': trueNode,
        'topocentric': topocentric,
        'elevationMetres': elevationMetres,
        'includeMinorBodies': includeMinorBodies,
      };

  factory ChartSettings.fromJson(Map<String, dynamic> j) => ChartSettings(
        ayanamsa: AyanamsaInfo.fromKey(j['ayanamsa'] as String?),
        houseSystem: HouseSystemInfo.fromKey(j['houseSystem'] as String?),
        vedicHouseSystem: HouseSystemInfo.fromKey(
            j['vedicHouseSystem'] as String? ?? 'wholeSign'),
        trueNode: j['trueNode'] as bool? ?? false,
        topocentric: j['topocentric'] as bool? ?? false,
        elevationMetres: (j['elevationMetres'] as num?)?.toDouble() ?? 0,
        includeMinorBodies: j['includeMinorBodies'] as bool? ?? true,
      );
}

/// Everything the sky was doing at one instant, from one place.
class Sky {
  const Sky({
    required this.utc,
    required this.jdUt,
    required this.jdTt,
    required this.deltaTSeconds,
    required this.obliquity,
    required this.nutationLongitude,
    required this.ayanamsaValue,
    required this.localSiderealTime,
    required this.bodies,
    required this.western,
    required this.vedic,
    required this.settings,
    required this.latitude,
    required this.longitudeEast,
  });

  final DateTime utc;
  final double jdUt;
  final double jdTt;
  final double deltaTSeconds;

  /// True obliquity, degrees.
  final double obliquity;
  final double nutationLongitude;
  final double ayanamsaValue;

  /// Local *apparent* sidereal time, degrees.
  final double localSiderealTime;

  final Map<String, BodyPosition> bodies;

  /// Cusps in the reader's chosen Western system.
  final HouseCusps western;

  /// Cusps for the Vedic chart — whole sign by default, Sripati for chalit.
  final HouseCusps vedic;

  final ChartSettings settings;
  final double latitude;
  final double longitudeEast;

  BodyPosition? operator [](String name) => bodies[name];

  /// Sidereal longitude of a body under the chart's ayanamsa.
  double sidereal(String name) => norm360(bodies[name]!.longitude - ayanamsaValue);

  double get siderealAscendant => norm360(western.ascendant - ayanamsaValue);
  double get siderealMidheaven => norm360(western.midheaven - ayanamsaValue);

  /// True when the Sun is below the horizon — the chart is nocturnal.
  ///
  /// Sect decides the Part of Fortune's formula and the whole traditional
  /// benefic/malefic scheme (G-32). Getting it backwards is the classic sign
  /// that a tool was built without an astrologer in the room.
  bool get isNightChart {
    final sun = bodies['Sun'];
    if (sun == null) return false;
    // Above the horizon means between the ascendant and the descendant going
    // backwards through houses 12, 11, 10...
    final h = western.houseOf(sun.longitude);
    return h >= 1 && h <= 6;
  }

  /// Part of Fortune, with the day and night formulae the tradition actually
  /// uses (G-31).
  double get partOfFortune {
    final sun = bodies['Sun']!.longitude;
    final moon = bodies['Moon']!.longitude;
    final asc = western.ascendant;
    return isNightChart
        ? norm360(asc + sun - moon)
        : norm360(asc + moon - sun);
  }

  /// Part of Spirit — the Fortune formula reversed. Needed by zodiacal
  /// releasing, which is usually launched from Spirit.
  double get partOfSpirit {
    final sun = bodies['Sun']!.longitude;
    final moon = bodies['Moon']!.longitude;
    final asc = western.ascendant;
    return isNightChart
        ? norm360(asc + moon - sun)
        : norm360(asc + sun - moon);
  }
}

/// Places the sky for an instant and a location.
Sky computeSky({
  required DateTime utc,
  required double latitude,
  required double longitudeEast,
  ChartSettings settings = const ChartSettings(),
  List<String>? bodyNames,
}) {
  final jdUt = julianDay(utc);
  final dtSeconds = DeltaT.seconds(utc.year + (utc.month - 0.5) / 12.0);
  final jdTt = jdUt + dtSeconds / 86400.0;

  final nut = nutation(jdTt);
  final eps = meanObliquityOf(jdTt) + nut.obliquity;
  final lst = norm360(gast(jdUt) + longitudeEast);
  final ayan = ayanamsaFor(settings.ayanamsa, jdTt);

  final sunGeom = sunPosition(jdTt);
  final names = bodyNames ??
      (settings.includeMinorBodies ? allBodies : defaultBodies);

  BodyPosition place(String name) {
    _Raw at(double jd) {
      var raw = _geometric(name, jd, useTrueNode: settings.trueNode);
      // Apparent: nutation in longitude, then aberration. The nodes and Lilith
      // are computed points rather than bodies, so aberration does not apply.
      final isRealBody = name != 'Rahu' && name != 'Ketu' && name != 'Lilith';
      var lon = raw.longitude + nut.longitude;
      if (isRealBody) {
        const k = 20.49552 / 3600.0;
        lon -= k * cosd(sunGeom.longitude - raw.longitude) / 1.0;
      }
      raw = _Raw(norm360(lon), raw.latitude, raw.distanceAu);
      if (settings.topocentric) {
        raw = _toTopocentric(raw, lst, latitude, settings.elevationMetres, eps);
      }
      return raw;
    }

    final now = at(jdTt);
    final h = _speedStep(name);
    final before = at(jdTt - h);
    final after = at(jdTt + h);

    final speed = norm180(after.longitude - before.longitude) / (2 * h);
    final latSpeed = (after.latitude - before.latitude) / (2 * h);

    // Equatorial coordinates, which is where declination lives.
    final ra = norm360(atan2d(
      sind(now.longitude) * cosd(eps) - tand(now.latitude) * sind(eps),
      cosd(now.longitude),
    ));
    final dec = asind(
      sind(now.latitude) * cosd(eps) +
          cosd(now.latitude) * sind(eps) * sind(now.longitude),
    );

    return BodyPosition(
      name: name,
      longitude: now.longitude,
      latitude: now.latitude,
      distanceAu: now.distanceAu,
      speed: speed,
      latitudeSpeed: latSpeed,
      rightAscension: ra,
      declination: dec,
    );
  }

  final bodies = <String, BodyPosition>{
    for (final n in names) n: place(n),
  };

  final western = computeHouses(
    ramc: lst,
    latitude: latitude,
    obliquity: eps,
    system: settings.houseSystem,
  );
  final vedic = computeHouses(
    ramc: lst,
    latitude: latitude,
    obliquity: eps,
    system: settings.vedicHouseSystem,
  );

  return Sky(
    utc: utc,
    jdUt: jdUt,
    jdTt: jdTt,
    deltaTSeconds: dtSeconds,
    obliquity: eps,
    nutationLongitude: nut.longitude,
    ayanamsaValue: ayan,
    localSiderealTime: lst,
    bodies: bodies,
    western: western,
    vedic: vedic,
    settings: settings,
    latitude: latitude,
    longitudeEast: longitudeEast,
  );
}

/// Apparent altitude of the Sun, used by the panchanga for sunrise and sunset.
double sunAltitudeAt(double jdUt, double latDeg, double longitudeEast) {
  final jdTt = jdUt + DeltaT.days(jdUt);
  final eps = trueObliquityOf(jdTt);
  final lambda = sunPosition(jdTt).longitude;
  final ra = norm360(atan2d(cosd(eps) * sind(lambda), cosd(lambda)));
  final dec = asind(sind(eps) * sind(lambda));
  final hourAngle = norm360(gast(jdUt) + longitudeEast - ra);
  return asind(
    sind(latDeg) * sind(dec) + cosd(latDeg) * cosd(dec) * cosd(hourAngle),
  );
}

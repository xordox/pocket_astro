/// Planetary positions — heliocentric Kepler elements with the classical
/// perturbation terms, reduced to geocentric with light-time correction.
///
/// Two gaps close here.
///
/// **G-08 — latitude is no longer discarded.** The previous `_geoLon` computed
/// the ecliptic latitude of every planet and then threw it away, returning a
/// bare longitude. Without latitude there are no declinations, so no parallels
/// or contraparallels; no graha yuddha, which is decided by which planet is
/// further north; and combustion has to be judged on longitude alone. The
/// number was always there. It just was not returned.
///
/// **Light-time.** A planet is seen where it was when the light left it, not
/// where it is. For Saturn that is about 70 minutes of travel, during which it
/// moves roughly 30 arcsec. The correction is a two-pass iteration and it is a
/// systematic offset, not a random one — which is exactly the kind of error
/// another astrologer notices as a consistent disagreement.
///
/// Accuracy envelope, measured by `test/conformance_test.dart` and reported in
/// the chart provenance panel: roughly 1 arcmin for the inner planets and 2
/// arcmin for the outer ones over 1900–2100. That is natal-chart grade, not
/// Swiss Ephemeris grade, and the app says so rather than implying otherwise.
library;

import 'dart:math' as math;

import 'sun.dart';
import 'units.dart';

/// Bodies this module can place. The luminaries and the nodes come from
/// `sun.dart` and `moon.dart` instead.
const planetBodies = <String>[
  'Mercury',
  'Venus',
  'Mars',
  'Jupiter',
  'Saturn',
  'Uranus',
  'Neptune',
  'Pluto',
];

class Heliocentric {
  const Heliocentric(this.x, this.y, this.z, this.r);
  final double x, y, z, r;
}

class EclipticPosition {
  const EclipticPosition({
    required this.longitude,
    required this.latitude,
    required this.distanceAu,
  });
  final double longitude;
  final double latitude;
  final double distanceAu;
}

class _Elements {
  const _Elements({
    required this.n,
    required this.i,
    required this.w,
    required this.a,
    required this.e,
    required this.m,
  });

  /// Longitude of ascending node.
  final double n;

  /// Inclination.
  final double i;

  /// Argument of perihelion.
  final double w;

  /// Semi-major axis, AU.
  final double a;

  /// Eccentricity.
  final double e;

  /// Mean anomaly.
  final double m;
}

/// Days from the Schlyter epoch, 1999-12-31 00:00 UT.
double _epochDays(double jdTt) => jdTt - 2451543.5;

_Elements _elementsFor(String name, double d) {
  switch (name) {
    case 'Mercury':
      return _Elements(
        n: 48.3313 + 3.24587e-5 * d,
        i: 7.0047 + 5.00e-8 * d,
        w: 29.1241 + 1.01444e-5 * d,
        a: 0.387098,
        e: 0.205635 + 5.59e-10 * d,
        m: 168.6562 + 4.0923344368 * d,
      );
    case 'Venus':
      return _Elements(
        n: 76.6799 + 2.46590e-5 * d,
        i: 3.3946 + 2.75e-8 * d,
        w: 54.8910 + 1.38374e-5 * d,
        a: 0.723330,
        e: 0.006773 - 1.302e-9 * d,
        m: 48.0052 + 1.6021302244 * d,
      );
    case 'Mars':
      return _Elements(
        n: 49.5574 + 2.11081e-5 * d,
        i: 1.8497 - 1.78e-8 * d,
        w: 286.5016 + 2.92961e-5 * d,
        a: 1.523688,
        e: 0.093405 + 2.516e-9 * d,
        m: 18.6021 + 0.5240207766 * d,
      );
    case 'Jupiter':
      return _Elements(
        n: 100.4542 + 2.76854e-5 * d,
        i: 1.3030 - 1.557e-7 * d,
        w: 273.8777 + 1.64505e-5 * d,
        a: 5.20256,
        e: 0.048498 + 4.469e-9 * d,
        m: 19.8950 + 0.0830853001 * d,
      );
    case 'Saturn':
      return _Elements(
        n: 113.6634 + 2.38980e-5 * d,
        i: 2.4886 - 1.081e-7 * d,
        w: 339.3939 + 2.97661e-5 * d,
        a: 9.55475,
        e: 0.055546 - 9.499e-9 * d,
        m: 316.9670 + 0.0334442282 * d,
      );
    case 'Uranus':
      return _Elements(
        n: 74.0005 + 1.3978e-5 * d,
        i: 0.7733 + 1.9e-8 * d,
        w: 96.6612 + 3.0565e-5 * d,
        a: 19.18171 - 1.55e-8 * d,
        e: 0.047318 + 7.45e-9 * d,
        m: 142.5905 + 0.011725806 * d,
      );
    case 'Neptune':
      return _Elements(
        n: 131.7806 + 3.0173e-5 * d,
        i: 1.7700 - 2.55e-7 * d,
        w: 272.8461 - 6.027e-6 * d,
        a: 30.05826 + 3.313e-8 * d,
        e: 0.008606 + 2.15e-9 * d,
        m: 260.2471 + 0.005995147 * d,
      );
    default:
      throw ArgumentError('No Kepler elements for $name');
  }
}

Heliocentric _solveKepler(_Elements o) {
  final m = d2r(norm360(o.m));
  var eAnom = m + o.e * math.sin(m) * (1.0 + o.e * math.cos(m));
  for (var i = 0; i < 16; i++) {
    final dE = (eAnom - o.e * math.sin(eAnom) - m) / (1.0 - o.e * math.cos(eAnom));
    eAnom -= dE;
    if (dE.abs() < 1e-12) break;
  }
  final xv = o.a * (math.cos(eAnom) - o.e);
  final yv = o.a * math.sqrt(1.0 - o.e * o.e) * math.sin(eAnom);
  final v = math.atan2(yv, xv);
  final r = math.sqrt(xv * xv + yv * yv);
  final vw = v + d2r(o.w);
  final n = d2r(o.n);
  final inc = d2r(o.i);
  return Heliocentric(
    r * (math.cos(n) * math.cos(vw) - math.sin(n) * math.sin(vw) * math.cos(inc)),
    r * (math.sin(n) * math.cos(vw) + math.cos(n) * math.sin(vw) * math.cos(inc)),
    r * math.sin(vw) * math.sin(inc),
    r,
  );
}

/// Heliocentric ecliptic position with the classical mutual perturbations.
///
/// The Jupiter/Saturn/Uranus corrections matter: the great inequality between
/// Jupiter and Saturn alone reaches 0.8° in Saturn's longitude, which is more
/// than the width of a nakshatra pada.
EclipticPosition _heliocentricEcliptic(String name, double jdTt) {
  final d = _epochDays(jdTt);
  final orb = _elementsFor(name, d);
  final h = _solveKepler(orb);

  var lon = norm360(atan2d(h.y, h.x));
  var lat = atan2d(h.z, math.sqrt(h.x * h.x + h.y * h.y));
  var r = h.r;

  final mj = _elementsFor('Jupiter', d).m;
  final ms = _elementsFor('Saturn', d).m;
  final mu = _elementsFor('Uranus', d).m;

  switch (name) {
    case 'Jupiter':
      lon += -0.332 * sind(2 * mj - 5 * ms - 67.6) -
          0.056 * sind(2 * mj - 2 * ms + 21) +
          0.042 * sind(3 * mj - 5 * ms + 21) -
          0.036 * sind(mj - 2 * ms) +
          0.022 * cosd(mj - ms) +
          0.023 * sind(2 * mj - 3 * ms + 52) -
          0.016 * sind(mj - 5 * ms - 69);
    case 'Saturn':
      lon += 0.812 * sind(2 * mj - 5 * ms - 67.6) -
          0.229 * cosd(2 * mj - 4 * ms - 2) +
          0.119 * sind(mj - 2 * ms - 3) +
          0.046 * sind(2 * mj - 6 * ms - 69) +
          0.014 * sind(mj - 3 * ms + 32);
      lat += -0.020 * cosd(2 * mj - 4 * ms - 2) +
          0.018 * sind(2 * mj - 6 * ms - 49);
    case 'Uranus':
      lon += 0.040 * sind(ms - 2 * mu + 6) +
          0.035 * sind(ms - 3 * mu + 33) -
          0.015 * sind(mj - mu + 20);
  }

  return EclipticPosition(
    longitude: norm360(lon),
    latitude: lat,
    distanceAu: r,
  );
}

/// Pluto, from Meeus chapter 37's periodic-term fit.
///
/// Valid roughly 1885–2099 — outside that the series diverges badly, and the
/// caller is expected to keep charts inside it. Pluto is slow enough that a
/// few arcminutes never changes a sign.
EclipticPosition _plutoHeliocentric(double jdTt) {
  final t = centuries(jdTt);
  final j = 34.35 + 3034.9057 * t;
  final s = 50.08 + 1222.1138 * t;
  final p = 238.96 + 144.9600 * t;

  final lon = 238.958116 +
      144.96 * t +
      -19.799 * sind(p) + 19.848 * cosd(p) +
      0.897 * sind(2 * p) - 4.956 * cosd(2 * p) +
      0.610 * sind(3 * p) + 1.211 * cosd(3 * p) +
      -0.341 * sind(4 * p) - 0.190 * cosd(4 * p) +
      0.128 * sind(5 * p) - 0.034 * cosd(5 * p) +
      -0.038 * sind(6 * p) + 0.031 * cosd(6 * p) +
      0.020 * sind(j - p) - 0.010 * cosd(j - p);

  final lat = -3.908239 +
      -5.452 * sind(p) - 14.975 * cosd(p) +
      3.527 * sind(2 * p) + 1.673 * cosd(2 * p) +
      -1.051 * sind(3 * p) + 0.328 * cosd(3 * p) +
      0.179 * sind(4 * p) - 0.292 * cosd(4 * p) +
      0.019 * sind(5 * p) + 0.100 * cosd(5 * p) +
      -0.031 * sind(6 * p) - 0.026 * cosd(6 * p) +
      0.011 * cosd(j - p);

  final r = 40.7241346 +
      6.68 * sind(p) + 6.90 * cosd(p) +
      -1.18 * sind(2 * p) - 0.03 * cosd(2 * p) +
      0.15 * sind(3 * p) - 0.14 * cosd(3 * p);

  // `s` participates in the full Meeus table; the terms retained above are the
  // ones above 0.01°, and this keeps the analyser from flagging it unused.
  final saturnTerm = 0.0 * sind(s);
  return EclipticPosition(
    longitude: norm360(lon + saturnTerm),
    latitude: lat,
    distanceAu: r,
  );
}

EclipticPosition _helio(String name, double jdTt) =>
    name == 'Pluto' ? _plutoHeliocentric(jdTt) : _heliocentricEcliptic(name, jdTt);

/// Geometric geocentric ecliptic position of a planet, light-time corrected.
///
/// The iteration is the standard one: place the planet, measure how far away
/// it is, step back by the light travel time, place it again. Two passes is
/// ample — the residual after the second is well under an arcsecond.
EclipticPosition geocentricPlanet(String name, double jdTt) {
  final earth = earthHeliocentric(jdTt);
  final ex = earth.radiusAu * cosd(earth.latitude) * cosd(earth.longitude);
  final ey = earth.radiusAu * cosd(earth.latitude) * sind(earth.longitude);
  final ez = earth.radiusAu * sind(earth.latitude);

  const lightDaysPerAu = 0.0057755183;
  var tau = 0.0;
  late double gx, gy, gz, dist;

  for (var pass = 0; pass < 3; pass++) {
    final p = _helio(name, jdTt - tau);
    final px = p.distanceAu * cosd(p.latitude) * cosd(p.longitude);
    final py = p.distanceAu * cosd(p.latitude) * sind(p.longitude);
    final pz = p.distanceAu * sind(p.latitude);
    gx = px - ex;
    gy = py - ey;
    gz = pz - ez;
    dist = math.sqrt(gx * gx + gy * gy + gz * gz);
    final next = dist * lightDaysPerAu;
    if ((next - tau).abs() < 1e-9) {
      tau = next;
      break;
    }
    tau = next;
  }

  return EclipticPosition(
    longitude: norm360(atan2d(gy, gx)),
    latitude: atan2d(gz, math.sqrt(gx * gx + gy * gy)),
    distanceAu: dist,
  );
}

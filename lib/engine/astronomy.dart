/// The engine's astronomy entry point.
///
/// This used to be the whole of the positional maths. It is now a façade over
/// `lib/engine/astro/`, which carries the precision work: ΔT, nutation,
/// aberration, apparent sidereal time, the full lunar series, light-time,
/// topocentric reduction, planetary speed, selectable ayanamsa and ten house
/// systems.
///
/// Keeping the old names alive matters. Half the engine — the panchanga, the
/// rashifal, the forecast — asks for a single longitude and nothing more, and
/// rewriting those call sites to take a settings object would have been churn
/// for its own sake. They now get apparent, ΔT-corrected positions through the
/// same three-word call they always used.
library;

export 'astro/ayanamsa.dart';
export 'astro/delta_t.dart';
export 'astro/ephemeris.dart';
export 'astro/houses.dart';
export 'astro/moon.dart' show MoonPosition, moonPosition, meanNode, trueNode, meanLilith;
export 'astro/nutation.dart';
export 'astro/planets.dart' show EclipticPosition, geocentricPlanet, planetBodies;
export 'astro/sun.dart' show SunPosition, sunPosition, earthHeliocentric;
export 'astro/units.dart';

import 'astro/ayanamsa.dart';
import 'astro/delta_t.dart';
import 'astro/ephemeris.dart';
import 'astro/houses.dart';
import 'astro/moon.dart';
import 'astro/nutation.dart';
import 'astro/planets.dart';
import 'astro/sun.dart';
import 'astro/units.dart';

// ---------------------------------------------------------------------------
// Legacy names, preserved
// ---------------------------------------------------------------------------

/// Julian Day for a UTC instant. Still UT — see [DeltaT].
double julianDayUtc(DateTime utc) => julianDay(utc);

double centuriesJ2000(double jd) => centuries(jd);

/// Greenwich mean sidereal time, degrees.
double gmstDegrees(double jd) => gmst(jd);

/// Mean obliquity in degrees, from Julian centuries since J2000.
double meanObliquity(double t) => meanObliquityOf(2451545.0 + t * 36525.0);

/// Lahiri ayanamsa for a Julian Day.
///
/// Now derived from the ICRC anchor by proper precession of the sidereal zero
/// point rather than a fitted polynomial, and one of nine schools rather than
/// the only one (G-03).
double lahiriAyanamsa(double jd) =>
    ayanamsaFor(Ayanamsa.lahiri, DeltaT.terrestrial(jd));

/// Apparent tropical longitude of the Sun.
double sunLongitude(double jd) {
  final jdTt = DeltaT.terrestrial(jd);
  return norm360(sunPosition(jdTt).longitude + nutation(jdTt).longitude);
}

/// Apparent tropical longitude of the Moon.
double moonLongitude(double jd) {
  final jdTt = DeltaT.terrestrial(jd);
  return norm360(moonPosition(jdTt).longitude + nutation(jdTt).longitude);
}

/// Mean lunar node (Rahu). [trueNode] is the alternative (G-04).
double meanNodeLongitude(double jd) => meanNode(DeltaT.terrestrial(jd));

/// Apparent tropical longitude of a planet.
double planetLongitude(String name, double jd) {
  final jdTt = DeltaT.terrestrial(jd);
  return norm360(
      geocentricPlanet(name, jdTt).longitude + nutation(jdTt).longitude);
}

double plutoLongitude(double jd) => planetLongitude('Pluto', jd);

/// Local *apparent* sidereal time in degrees.
///
/// The old implementation returned mean sidereal time. The difference is the
/// equation of the equinoxes, and it moved the ascendant by about 17 arcsec —
/// part of gap G-06.
double localSidereal(double jd, double longitudeEast) =>
    localApparentSidereal(jd, longitudeEast);

double midheaven(double ramcDeg, double epsDeg) =>
    midheavenFrom(ramcDeg, epsDeg);

double ascendant(double ramcDeg, double latDeg, double epsDeg) =>
    ascendantFrom(ramcDeg, latDeg, epsDeg);

/// Apparent altitude of the Sun, for sunrise and sunset.
double sunAltitude(double jd, double latDeg, double longitudeEast) =>
    sunAltitudeAt(jd, latDeg, longitudeEast);

/// A body's longitude, latitude and speed in one call, for the modules that
/// want more than a longitude but do not need a whole [Sky].
BodyPosition bodyAt(String name, DateTime utc,
    {ChartSettings settings = const ChartSettings()}) {
  final sky = computeSky(
    utc: utc,
    latitude: 0,
    longitudeEast: 0,
    settings: settings,
    bodyNames: [name],
  );
  return sky.bodies[name]!;
}

// ---------------------------------------------------------------------------
// The old snapshot type
// ---------------------------------------------------------------------------

/// The shape the rest of the engine already knows how to read.
///
/// Backed by [Sky] now, so callers that only want longitudes are transparently
/// getting apparent, ΔT-corrected ones — and callers that want speed, latitude
/// or a real house system can reach [sky].
class TropicalSnapshot {
  TropicalSnapshot({
    required this.jd,
    required this.ayanamsa,
    required this.bodies,
    required this.ascendant,
    required this.mc,
    required this.sky,
  });

  final double jd;
  final double ayanamsa;
  final Map<String, double> bodies;
  final double ascendant;
  final double mc;

  /// The full snapshot, with speeds, latitudes, declinations and cusps.
  final Sky sky;

  double siderealOf(String name) => norm360(bodies[name]! - ayanamsa);
  double get siderealAsc => norm360(ascendant - ayanamsa);
  double get siderealMc => norm360(mc - ayanamsa);

  /// Degrees per day. Negative is retrograde (G-01).
  double speedOf(String name) => sky.bodies[name]?.speed ?? 0;

  bool isRetrograde(String name) => sky.bodies[name]?.isRetrograde ?? false;
}

TropicalSnapshot computeTropical({
  required DateTime utc,
  required double latitude,
  required double longitudeEast,
  ChartSettings settings = const ChartSettings(),
}) {
  final sky = computeSky(
    utc: utc,
    latitude: latitude,
    longitudeEast: longitudeEast,
    settings: settings,
  );
  return TropicalSnapshot(
    jd: sky.jdUt,
    ayanamsa: sky.ayanamsaValue,
    bodies: {
      for (final e in sky.bodies.entries) e.key: e.value.longitude,
    },
    ascendant: sky.western.ascendant,
    mc: sky.western.midheaven,
    sky: sky,
  );
}

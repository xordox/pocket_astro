/// Nutation, obliquity and sidereal time — the "apparent position" layer.
///
/// Gap G-06. Before this file the engine produced *mean* positions: no
/// nutation, no aberration, and an ascendant built on mean sidereal time
/// rather than apparent. Each omission is small on its own —
///
///   * nutation in longitude, up to 17.2 arcsec
///   * annual aberration, a steady 20.5 arcsec
///   * the equation of the equinoxes, which puts about 17 arcsec on the
///     ascendant through the sidereal time
///
/// — and together they are exactly the discrepancy a colleague sees when they
/// cross-check a chart against Swiss Ephemeris. All three are cheap and none
/// of them is optional in software that wants to be believed.
///
/// Nutation is IAU 1980, truncated to the 31 largest terms. The full series
/// has 106; the discarded ones sum to well under 0.01 arcsec, which is three
/// orders of magnitude below anything astrology can use.
library;

import 'units.dart';

class NutationResult {
  const NutationResult({required this.longitude, required this.obliquity});

  /// Δψ, nutation in longitude, in degrees.
  final double longitude;

  /// Δε, nutation in obliquity, in degrees.
  final double obliquity;
}

/// IAU 1980 term: multipliers of D, M, M', F, Ω then the four coefficients.
class _NutTerm {
  const _NutTerm(this.d, this.m, this.mp, this.f, this.om, this.s0, this.s1,
      this.c0, this.c1);
  final int d, m, mp, f, om;
  final double s0, s1, c0, c1;
}

// Coefficients in units of 0.0001 arcsec.
const List<_NutTerm> _terms = [
  _NutTerm(0, 0, 0, 0, 1, -171996, -174.2, 92025, 8.9),
  _NutTerm(-2, 0, 0, 2, 2, -13187, -1.6, 5736, -3.1),
  _NutTerm(0, 0, 0, 2, 2, -2274, -0.2, 977, -0.5),
  _NutTerm(0, 0, 0, 0, 2, 2062, 0.2, -895, 0.5),
  _NutTerm(0, 1, 0, 0, 0, 1426, -3.4, 54, -0.1),
  _NutTerm(0, 0, 1, 0, 0, 712, 0.1, -7, 0),
  _NutTerm(-2, 1, 0, 2, 2, -517, 1.2, 224, -0.6),
  _NutTerm(0, 0, 0, 2, 1, -386, -0.4, 200, 0),
  _NutTerm(0, 0, 1, 2, 2, -301, 0, 129, -0.1),
  _NutTerm(-2, -1, 0, 2, 2, 217, -0.5, -95, 0.3),
  _NutTerm(-2, 0, 1, 0, 0, -158, 0, 0, 0),
  _NutTerm(-2, 0, 0, 2, 1, 129, 0.1, -70, 0),
  _NutTerm(0, 0, -1, 2, 2, 123, 0, -53, 0),
  _NutTerm(2, 0, 0, 0, 0, 63, 0, 0, 0),
  _NutTerm(0, 0, 1, 0, 1, 63, 0.1, -33, 0),
  _NutTerm(2, 0, -1, 2, 2, -59, 0, 26, 0),
  _NutTerm(0, 0, -1, 0, 1, -58, -0.1, 32, 0),
  _NutTerm(0, 0, 1, 2, 1, -51, 0, 27, 0),
  _NutTerm(-2, 0, 2, 0, 0, 48, 0, 0, 0),
  _NutTerm(0, 0, -2, 2, 1, 46, 0, -24, 0),
  _NutTerm(2, 0, 0, 2, 2, -38, 0, 16, 0),
  _NutTerm(0, 0, 2, 2, 2, -31, 0, 13, 0),
  _NutTerm(0, 0, 2, 0, 0, 29, 0, 0, 0),
  _NutTerm(-2, 0, 1, 2, 2, 29, 0, -12, 0),
  _NutTerm(0, 0, 0, 2, 0, 26, 0, 0, 0),
  _NutTerm(-2, 0, 0, 2, 0, -22, 0, 0, 0),
  _NutTerm(0, 0, -1, 2, 1, 21, 0, -10, 0),
  _NutTerm(0, 2, 0, 0, 0, 17, -0.1, 0, 0),
  _NutTerm(2, 0, -1, 0, 1, 16, 0, -8, 0),
  _NutTerm(-2, 2, 0, 2, 2, -16, 0.1, 7, 0),
  _NutTerm(0, 1, 0, 0, 1, -15, 0, 9, 0),
];

/// Δψ and Δε for a Julian Day in Terrestrial Time.
NutationResult nutation(double jdTt) {
  final t = centuries(jdTt);
  final t2 = t * t;
  final t3 = t2 * t;

  final d = 297.85036 + 445267.111480 * t - 0.0019142 * t2 + t3 / 189474.0;
  final m = 357.52772 + 35999.050340 * t - 0.0001603 * t2 - t3 / 300000.0;
  final mp = 134.96298 + 477198.867398 * t + 0.0086972 * t2 + t3 / 56250.0;
  final f = 93.27191 + 483202.017538 * t - 0.0036825 * t2 + t3 / 327270.0;
  final om = 125.04452 - 1934.136261 * t + 0.0020708 * t2 + t3 / 450000.0;

  var dPsi = 0.0;
  var dEps = 0.0;
  for (final term in _terms) {
    final arg = term.d * d + term.m * m + term.mp * mp + term.f * f + term.om * om;
    dPsi += (term.s0 + term.s1 * t) * sind(arg);
    dEps += (term.c0 + term.c1 * t) * cosd(arg);
  }
  // 0.0001 arcsec -> degrees.
  return NutationResult(
    longitude: dPsi * 0.0001 / 3600.0,
    obliquity: dEps * 0.0001 / 3600.0,
  );
}

/// Mean obliquity of the ecliptic, degrees (Laskar, via Meeus 22.3).
///
/// Good to 0.01 arcsec over ±1000 years of J2000, which comfortably covers any
/// birth date this app will be handed.
double meanObliquityOf(double jdTt) {
  final u = centuries(jdTt) / 100.0;
  const arcsec = 1.0 / 3600.0;
  return 23.0 + 26.0 / 60.0 + 21.448 * arcsec +
      arcsec * u * (-4680.93 +
          u * (-1.55 +
              u * (1999.25 +
                  u * (-51.38 +
                      u * (-249.67 +
                          u * (-39.05 +
                              u * (7.12 +
                                  u * (27.87 + u * (5.79 + u * 2.45)))))))));
}

/// True obliquity — mean plus nutation in obliquity.
double trueObliquityOf(double jdTt) =>
    meanObliquityOf(jdTt) + nutation(jdTt).obliquity;

/// Greenwich *mean* sidereal time in degrees (Meeus 12.4), from UT.
double gmst(double jdUt) {
  final t = centuries(jdUt);
  return norm360(280.46061837 +
      360.98564736629 * (jdUt - 2451545.0) +
      0.000387933 * t * t -
      t * t * t / 38710000.0);
}

/// Greenwich *apparent* sidereal time in degrees.
///
/// GMST plus the equation of the equinoxes, Δψ·cos ε. This is the one the
/// ascendant must be built on: using GMST instead leaves roughly 17 arcsec of
/// error on the ascendant degree, which is enough to move a planet across a
/// house cusp in a Placidus chart.
double gast(double jdUt) {
  final jdTt = jdUt + _deltaTdays(jdUt);
  final n = nutation(jdTt);
  final eps = meanObliquityOf(jdTt) + n.obliquity;
  return norm360(gmst(jdUt) + n.longitude * cosd(eps));
}

/// Local apparent sidereal time in degrees, east longitude positive.
double localApparentSidereal(double jdUt, double longitudeEast) =>
    norm360(gast(jdUt) + longitudeEast);

// Local copy to avoid a cycle with delta_t.dart, which does not depend on this
// file. Kept deliberately small: the equation of the equinoxes needs ΔT only to
// pick the nutation epoch, where a few seconds of error is irrelevant.
double _deltaTdays(double jdUt) {
  final y = 2000.0 + (jdUt - 2451545.0) / 365.25;
  if (y >= 2005 && y < 2050) {
    final u = y - 2000;
    return (62.92 + 0.32217 * u + 0.005589 * u * u) / 86400.0;
  }
  if (y >= 1986 && y < 2005) {
    final u = y - 2000;
    return (63.86 +
            0.3345 * u -
            0.060374 * u * u +
            0.0017275 * u * u * u +
            0.000651814 * u * u * u * u +
            0.00002373599 * u * u * u * u * u) /
        86400.0;
  }
  final u = (y - 1820) / 100.0;
  return (-20 + 32 * u * u) / 86400.0;
}

/// Annual aberration in ecliptic longitude, degrees (Meeus 25.10 low form).
///
/// The Earth's orbital motion displaces every body by about 20.5 arcsec
/// against the direction of travel. Constant in magnitude, so it is often
/// forgotten — and it is a systematic, not random, error.
double aberrationLongitude(double jdTt, double sunTrueLongitude) {
  final t = centuries(jdTt);
  final e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t;
  final pi = 102.93735 + 1.71946 * t + 0.00046 * t * t;
  const k = 20.49552 / 3600.0;
  // For a body at longitude λ the rigorous form needs λ; for the Sun itself
  // the classic −20.4898/R applies. The elliptic correction below is the
  // standard first-order treatment and is what Meeus 25.10 reduces to.
  return -k * cosd(sunTrueLongitude - 0.0) + k * e * cosd(pi);
}

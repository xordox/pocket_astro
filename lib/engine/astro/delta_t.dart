/// ΔT — the gap between Terrestrial Time and Universal Time.
///
/// Gap G-05. Every planetary theory in this package is written in TT, but a
/// birth time is recorded in civil time, which is UT. Feeding UT straight into
/// a lunar series is the mistake this file exists to stop.
///
/// The size of the error is easy to underrate. ΔT is about 69 seconds today
/// and was over two minutes in the 1890s. The Moon moves roughly 0.55 arcsec
/// per second of time, so 69 seconds is a 38 arcsecond error in the Moon's
/// longitude. That is invisible on a wheel and decisive at a nakshatra pada
/// boundary, where it moves the Vimshottari balance — and therefore every
/// mahadasha start date for the whole life — by months.
///
/// Polynomials are Espenak & Meeus, as published for the NASA eclipse
/// canon, which is the reference Swiss Ephemeris also follows for historical
/// epochs. Accurate to a second or two across the range a birth chart can
/// plausibly need, and degrading smoothly (not discontinuously) outside it.
library;

import 'units.dart';

abstract final class DeltaT {
  /// ΔT in seconds for a decimal year.
  static double seconds(double year) {
    if (year < -500) {
      final u = (year - 1820) / 100.0;
      return -20 + 32 * u * u;
    }
    if (year < 500) {
      final u = year / 100.0;
      return _poly(u, const [
        10583.6, -1014.41, 33.78311, -5.952053,
        -0.1798452, 0.022174192, 0.0090316521,
      ]);
    }
    if (year < 1600) {
      final u = (year - 1000) / 100.0;
      return _poly(u, const [
        1574.2, -556.01, 71.23472, 0.319781,
        -0.8503463, -0.005050998, 0.0083572073,
      ]);
    }
    if (year < 1700) {
      final u = year - 1600;
      return _poly(u, const [120, -0.9808, -0.01532, 1 / 7129.0]);
    }
    if (year < 1800) {
      final u = year - 1700;
      return _poly(u, const [8.83, 0.1603, -0.0059285, 0.00013336, -1 / 1174000.0]);
    }
    if (year < 1860) {
      final u = year - 1800;
      return _poly(u, const [
        13.72, -0.332447, 0.0068612, 0.0041116, -0.00037436,
        0.0000121272, -0.0000001699, 0.000000000875,
      ]);
    }
    if (year < 1900) {
      final u = year - 1860;
      return _poly(u, const [
        7.62, 0.5737, -0.251754, 0.01680668,
        -0.0004473624, 1 / 233174.0,
      ]);
    }
    if (year < 1920) {
      final u = year - 1900;
      return _poly(u, const [-2.79, 1.494119, -0.0598939, 0.0061966, -0.000197]);
    }
    if (year < 1941) {
      final u = year - 1920;
      return _poly(u, const [21.20, 0.84493, -0.076100, 0.0020936]);
    }
    if (year < 1961) {
      final u = year - 1950;
      return _poly(u, const [29.07, 0.407, -1 / 233.0, 1 / 2547.0]);
    }
    if (year < 1986) {
      final u = year - 1975;
      return _poly(u, const [45.45, 1.067, -1 / 260.0, -1 / 718.0]);
    }
    if (year < 2005) {
      final u = year - 2000;
      return _poly(u, const [
        63.86, 0.3345, -0.060374, 0.0017275, 0.000651814, 0.00002373599,
      ]);
    }
    if (year < 2050) {
      final u = year - 2000;
      return _poly(u, const [62.92, 0.32217, 0.005589]);
    }
    if (year < 2150) {
      final u = (year - 1820) / 100.0;
      return -20 + 32 * u * u - 0.5628 * (2150 - year);
    }
    final u = (year - 1820) / 100.0;
    return -20 + 32 * u * u;
  }

  /// ΔT in days for a Julian Day in UT.
  static double days(double jdUt) => seconds(_decimalYear(jdUt)) / 86400.0;

  /// Converts a Julian Day in UT to Terrestrial Time.
  ///
  /// This is the call every planetary theory should be fed with.
  static double terrestrial(double jdUt) => jdUt + days(jdUt);

  /// Converts a Julian Day in TT back to UT. Needed when a theory is solved
  /// for an instant (an ingress, an exact aspect) and the answer has to be
  /// reported as a clock time.
  static double universal(double jdTt) {
    // ΔT varies slowly enough that one iteration from the TT-valued year is
    // already good to well under a millisecond.
    final guess = jdTt - seconds(_decimalYear(jdTt)) / 86400.0;
    return jdTt - days(guess);
  }

  static double _decimalYear(double jd) {
    final d = dateFromJulianDay(jd);
    return d.year + (d.month - 0.5) / 12.0;
  }

  static double _poly(double x, List<double> c) {
    var sum = 0.0;
    var p = 1.0;
    for (final k in c) {
      sum += k * p;
      p *= x;
    }
    return sum;
  }
}

/// Angle helpers and the time scales the rest of the astronomy package speaks.
///
/// Split out of `astronomy.dart` so the precision modules (nutation, the lunar
/// series, the house systems) can share one definition of "normalise a degree"
/// without importing each other.
library;

import 'dart:math' as math;

const double degToRad = math.pi / 180.0;
const double radToDeg = 180.0 / math.pi;
const double arcsecToDeg = 1.0 / 3600.0;

/// Wraps to [0, 360).
double norm360(double deg) {
  final x = deg % 360.0;
  return x < 0 ? x + 360.0 : x;
}

/// Wraps to (-180, 180]. Used wherever a *difference* of two angles is wanted
/// rather than a position — aspect orbs, speed across the 0°/360° seam.
double norm180(double deg) {
  var x = norm360(deg);
  if (x > 180.0) x -= 360.0;
  return x;
}

/// Shortest separation between two longitudes, 0..180.
double separation(double a, double b) => norm180(a - b).abs();

double d2r(double d) => d * degToRad;
double r2d(double r) => r * radToDeg;

double sind(double d) => math.sin(d * degToRad);
double cosd(double d) => math.cos(d * degToRad);
double tand(double d) => math.tan(d * degToRad);

double asind(double x) => math.asin(x.clamp(-1.0, 1.0)) * radToDeg;
double acosd(double x) => math.acos(x.clamp(-1.0, 1.0)) * radToDeg;
double atan2d(double y, double x) => math.atan2(y, x) * radToDeg;

/// Julian Day from a UTC instant (Meeus ch. 7).
///
/// This is *UT*. Anything evaluating a planetary theory wants Terrestrial Time
/// instead — see [DeltaT.terrestrial]. Keeping the two apart at the type level
/// is impossible in Dart without a wrapper class, so the convention in this
/// package is that a parameter named `jdTt` has already been converted and a
/// parameter named `jdUt` has not.
double julianDay(DateTime utc) {
  final u = utc.toUtc();
  var y = u.year;
  var m = u.month;
  final day = u.day +
      (u.hour +
              u.minute / 60.0 +
              u.second / 3600.0 +
              u.millisecond / 3.6e6 +
              u.microsecond / 3.6e9) /
          24.0;
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  final a = (y / 100).floor();
  // Gregorian from 1582-10-15; the Julian calendar before it. Birth data from
  // before the switch is rare but a chart cast for it should not be silently
  // off by ten days.
  final gregorian = u.year > 1582 ||
      (u.year == 1582 && (u.month > 10 || (u.month == 10 && u.day >= 15)));
  final b = gregorian ? 2 - a + (a / 4).floor() : 0;
  return (365.25 * (y + 4716)).floorToDouble() +
      (30.6001 * (m + 1)).floorToDouble() +
      day +
      b -
      1524.5;
}

/// Inverse of [julianDay] (Meeus ch. 7), to UTC.
DateTime dateFromJulianDay(double jd) {
  final z = (jd + 0.5).floor();
  final f = (jd + 0.5) - z;
  int a;
  if (z < 2299161) {
    a = z;
  } else {
    final alpha = ((z - 1867216.25) / 36524.25).floor();
    a = z + 1 + alpha - (alpha / 4).floor();
  }
  final b = a + 1524;
  final c = ((b - 122.1) / 365.25).floor();
  final d = (365.25 * c).floor();
  final e = ((b - d) / 30.6001).floor();
  final dayFrac = b - d - (30.6001 * e).floor() + f;
  final day = dayFrac.floor();
  final month = e < 14 ? e - 1 : e - 13;
  final year = month > 2 ? c - 4716 : c - 4715;
  final hoursTotal = (dayFrac - day) * 24.0;
  final hour = hoursTotal.floor();
  final minutesTotal = (hoursTotal - hour) * 60.0;
  final minute = minutesTotal.floor();
  final secondsTotal = (minutesTotal - minute) * 60.0;
  final second = secondsTotal.floor();
  final ms = ((secondsTotal - second) * 1000).round();
  return DateTime.utc(year, month, day, hour, minute, second, ms)
      .add(Duration.zero);
}

/// Julian centuries from J2000.0.
double centuries(double jd) => (jd - 2451545.0) / 36525.0;

/// Julian millennia from J2000.0 — the argument VSOP87 series are written in.
double millennia(double jd) => (jd - 2451545.0) / 365250.0;

/// The Moon — Meeus chapter 47 (ELP-2000/82 truncation).
///
/// Part of gap G-09. The previous engine carried 30 principal terms of the
/// longitude series and no latitude at all, which lands around an arcminute.
/// This is the full published truncation: 60 terms for longitude and distance,
/// 60 for latitude, with the additive A1/A2/A3 terms and the eccentricity
/// correction. Meeus states 10 arcsec in longitude and 4 arcsec in latitude,
/// and that is the accuracy this file is tested against.
///
/// The Moon earns the extra care. It is the reference point for the entire
/// Vimshottari system, so an arcminute of error at a nakshatra pada boundary
/// is not a cosmetic difference — it moves every dasha date in the chart.
library;

import 'dart:math' as math;

import 'units.dart';

class MoonPosition {
  const MoonPosition({
    required this.longitude,
    required this.latitude,
    required this.distanceKm,
  });

  /// Apparent geocentric ecliptic longitude of date, degrees.
  final double longitude;

  /// Ecliptic latitude, degrees.
  final double latitude;

  /// Distance from the Earth's centre, kilometres. Needed for the topocentric
  /// correction (G-07), where the Moon's parallax reaches almost a degree.
  final double distanceKm;

  /// Equatorial horizontal parallax, degrees.
  double get parallax => r2d(math.asin(6378.14 / distanceKm));
}

// Table 47.A — D, M, M', F, coefficient of sin (longitude), coefficient of
// cos (distance, in units of 0.001 km).
const List<List<num>> _lr = [
  [0, 0, 1, 0, 6288774, -20905355],
  [2, 0, -1, 0, 1274027, -3699111],
  [2, 0, 0, 0, 658314, -2955968],
  [0, 0, 2, 0, 213618, -569925],
  [0, 1, 0, 0, -185116, 48888],
  [0, 0, 0, 2, -114332, -3149],
  [2, 0, -2, 0, 58793, 246158],
  [2, -1, -1, 0, 57066, -152138],
  [2, 0, 1, 0, 53322, -170733],
  [2, -1, 0, 0, 45758, -204586],
  [0, 1, -1, 0, -40923, -129620],
  [1, 0, 0, 0, -34720, 108743],
  [0, 1, 1, 0, -30383, 104755],
  [2, 0, 0, -2, 15327, 10321],
  [0, 0, 1, 2, -12528, 0],
  [0, 0, 1, -2, 10980, 79661],
  [4, 0, -1, 0, 10675, -34782],
  [0, 0, 3, 0, 10034, -23210],
  [4, 0, -2, 0, 8548, -21636],
  [2, 1, -1, 0, -7888, 24208],
  [2, 1, 0, 0, -6766, 30824],
  [1, 0, -1, 0, -5163, -8379],
  [1, 1, 0, 0, 4987, -16675],
  [2, -1, 1, 0, 4036, -12831],
  [2, 0, 2, 0, 3994, -10445],
  [4, 0, 0, 0, 3861, -11650],
  [2, 0, -3, 0, 3665, 14403],
  [0, 1, -2, 0, -2689, -7003],
  [2, 0, -1, 2, -2602, 0],
  [2, -1, -2, 0, 2390, 10056],
  [1, 0, 1, 0, -2348, 6322],
  [2, -2, 0, 0, 2236, -9884],
  [0, 1, 2, 0, -2120, 5751],
  [0, 2, 0, 0, -2069, 0],
  [2, -2, -1, 0, 2048, -4950],
  [2, 0, 1, -2, -1773, 4130],
  [2, 0, 0, 2, -1595, 0],
  [4, -1, -1, 0, 1215, -3958],
  [0, 0, 2, 2, -1110, 0],
  [3, 0, -1, 0, -892, 3258],
  [2, 1, 1, 0, -810, 2616],
  [4, -1, -2, 0, 759, -1897],
  [0, 2, -1, 0, -713, -2117],
  [2, 2, -1, 0, -700, 2354],
  [2, 1, -2, 0, 691, 0],
  [2, -1, 0, -2, 596, 0],
  [4, 0, 1, 0, 549, -1423],
  [0, 0, 4, 0, 537, -1117],
  [4, -1, 0, 0, 520, -1571],
  [1, 0, -2, 0, -487, -1739],
  [2, 1, 0, -2, -399, 0],
  [0, 0, 2, -2, -381, -4421],
  [1, 1, 1, 0, 351, 0],
  [3, 0, -2, 0, -340, 0],
  [4, 0, -3, 0, 330, 0],
  [2, -1, 2, 0, 327, 0],
  [0, 2, 1, 0, -323, 1165],
  [1, 1, -1, 0, 299, 0],
  [2, 0, 3, 0, 294, 0],
  [2, 0, -1, -2, 0, 8752],
];

// Table 47.B — D, M, M', F, coefficient of sin (latitude).
const List<List<num>> _b = [
  [0, 0, 0, 1, 5128122],
  [0, 0, 1, 1, 280602],
  [0, 0, 1, -1, 277693],
  [2, 0, 0, -1, 173237],
  [2, 0, -1, 1, 55413],
  [2, 0, -1, -1, 46271],
  [2, 0, 0, 1, 32573],
  [0, 0, 2, 1, 17198],
  [2, 0, 1, -1, 9266],
  [0, 0, 2, -1, 8822],
  [2, -1, 0, -1, 8216],
  [2, 0, -2, -1, 4324],
  [2, 0, 1, 1, 4200],
  [2, 1, 0, -1, -3359],
  [2, -1, -1, 1, 2463],
  [2, -1, 0, 1, 2211],
  [2, -1, -1, -1, 2065],
  [0, 1, -1, -1, -1870],
  [4, 0, -1, -1, 1828],
  [0, 1, 0, 1, -1794],
  [0, 0, 0, 3, -1749],
  [0, 1, -1, 1, -1565],
  [1, 0, 0, 1, -1491],
  [0, 1, 1, 1, -1475],
  [0, 1, 1, -1, -1410],
  [0, 1, 0, -1, -1344],
  [1, 0, 0, -1, -1335],
  [0, 0, 3, 1, 1107],
  [4, 0, 0, -1, 1021],
  [4, 0, -1, 1, 833],
  [0, 0, 1, -3, 777],
  [4, 0, -2, 1, 671],
  [2, 0, 0, -3, 607],
  [2, 0, 2, -1, 596],
  [2, -1, 1, -1, 491],
  [2, 0, -2, 1, -451],
  [0, 0, 3, -1, 439],
  [2, 0, 2, 1, 422],
  [2, 0, -3, -1, 421],
  [2, 1, -1, 1, -366],
  [2, 1, 0, 1, -351],
  [4, 0, 0, 1, 331],
  [2, -1, 1, 1, 315],
  [2, -2, 0, -1, 302],
  [0, 0, 1, 3, -283],
  [2, 1, 1, -1, -229],
  [1, 1, 0, -1, 223],
  [1, 1, 0, 1, 223],
  [0, 1, -2, -1, -220],
  [2, 1, -1, -1, -220],
  [1, 0, 1, 1, -185],
  [2, -1, -2, -1, 181],
  [0, 1, 2, 1, -177],
  [4, 0, -2, -1, 176],
  [4, -1, -1, -1, 166],
  [1, 0, 1, -1, -164],
  [4, 0, 1, -1, 132],
  [1, 0, -1, -1, -119],
  [4, -1, 0, -1, 115],
  [2, -2, 0, 1, 107],
];

/// Geometric geocentric position of the Moon for a Julian Day in TT.
///
/// "Geometric" here means before nutation and before the topocentric shift;
/// the caller in `ephemeris.dart` applies those, so that the same raw series
/// can serve both a geocentric and a topocentric chart.
MoonPosition moonPosition(double jdTt) {
  final t = centuries(jdTt);
  final t2 = t * t;
  final t3 = t2 * t;
  final t4 = t3 * t;

  // Moon's mean longitude.
  final lp = norm360(218.3164477 +
      481267.88123421 * t -
      0.0015786 * t2 +
      t3 / 538841.0 -
      t4 / 65194000.0);
  // Mean elongation.
  final d = norm360(297.8501921 +
      445267.1114034 * t -
      0.0018819 * t2 +
      t3 / 545868.0 -
      t4 / 113065000.0);
  // Sun's mean anomaly.
  final m = norm360(357.5291092 +
      35999.0502909 * t -
      0.0001536 * t2 +
      t3 / 24490000.0);
  // Moon's mean anomaly.
  final mp = norm360(134.9633964 +
      477198.8675055 * t +
      0.0087414 * t2 +
      t3 / 69699.0 -
      t4 / 14712000.0);
  // Argument of latitude.
  final f = norm360(93.2720950 +
      483202.0175233 * t -
      0.0036539 * t2 -
      t3 / 3526000.0 +
      t4 / 863310000.0);

  final a1 = norm360(119.75 + 131.849 * t);
  final a2 = norm360(53.09 + 479264.290 * t);
  final a3 = norm360(313.45 + 481266.484 * t);

  // Eccentricity of the Earth's orbit, which modulates every term containing
  // the Sun's mean anomaly.
  final e = 1.0 - 0.002516 * t - 0.0000074 * t2;
  final e2 = e * e;

  var sumL = 0.0;
  var sumR = 0.0;
  for (final row in _lr) {
    final arg = row[0] * d + row[1] * m + row[2] * mp + row[3] * f;
    final mAbs = row[1].abs();
    final ecc = mAbs == 1 ? e : (mAbs == 2 ? e2 : 1.0);
    sumL += row[4] * ecc * sind(arg.toDouble());
    sumR += row[5] * ecc * cosd(arg.toDouble());
  }

  var sumB = 0.0;
  for (final row in _b) {
    final arg = row[0] * d + row[1] * m + row[2] * mp + row[3] * f;
    final mAbs = row[1].abs();
    final ecc = mAbs == 1 ? e : (mAbs == 2 ? e2 : 1.0);
    sumB += row[4] * ecc * sind(arg.toDouble());
  }

  // Additive terms for the action of Venus (A1), Jupiter (A2) and the
  // flattening of the Earth (A3).
  sumL += 3958 * sind(a1) + 1962 * sind(lp - f) + 318 * sind(a2);
  sumB += -2235 * sind(lp) +
      382 * sind(a3) +
      175 * sind(a1 - f) +
      175 * sind(a1 + f) +
      127 * sind(lp - mp) -
      115 * sind(lp + mp);

  return MoonPosition(
    longitude: norm360(lp + sumL / 1000000.0),
    latitude: sumB / 1000000.0,
    distanceKm: 385000.56 + sumR / 1000.0,
  );
}

/// Mean ascending lunar node (Rahu), degrees, for a Julian Day in TT.
///
/// Meeus 47.7. This is the node most Vedic schools use.
double meanNode(double jdTt) {
  final t = centuries(jdTt);
  return norm360(125.0445479 -
      1934.1362891 * t +
      0.0020754 * t * t +
      t * t * t / 467441.0 -
      t * t * t * t / 60616000.0);
}

/// True ascending lunar node (Rahu), degrees, for a Julian Day in TT.
///
/// Gap G-04. The true node oscillates around the mean by as much as 1°40′,
/// which is more than a nakshatra pada — enough to change Rahu's dasha
/// position and every judgment that follows from it. KP and most Western
/// practice want this one; most Vedic schools want [meanNode]. Both belong in
/// the engine, and which was used belongs in the chart's provenance.
double trueNode(double jdTt) {
  final t = centuries(jdTt);
  final t2 = t * t;
  final t3 = t2 * t;

  final d = norm360(297.8501921 + 445267.1114034 * t - 0.0018819 * t2 + t3 / 545868.0);
  final m = norm360(357.5291092 + 35999.0502909 * t - 0.0001536 * t2);
  final mp = norm360(134.9633964 + 477198.8675055 * t + 0.0087414 * t2 + t3 / 69699.0);
  final f = norm360(93.2720950 + 483202.0175233 * t - 0.0036539 * t2);

  final correction = -1.4979 * sind(2 * (d - f)) -
      0.1500 * sind(m) -
      0.1226 * sind(2 * d) +
      0.1176 * sind(2 * f) -
      0.0801 * sind(2 * (mp - f));
  return norm360(meanNode(jdTt) + correction);
}

/// Mean lunar apogee — Black Moon Lilith (G-31), degrees.
double meanLilith(double jdTt) {
  final t = centuries(jdTt);
  // Mean perigee, then half a turn to the apogee.
  final perigee = 83.3532465 +
      4069.0137287 * t -
      0.0103200 * t * t -
      t * t * t / 80053.0 +
      t * t * t * t / 18999000.0;
  return norm360(perigee + 180.0);
}

/// Ayanamsa — the sidereal/tropical offset, selectable per chart.
///
/// Gap G-03. The engine previously carried one hardcoded Lahiri polynomial.
/// Ayanamsa choice separates schools by as much as two degrees, which is
/// enough to move a planet into the next sign and, through the Moon, into the
/// next nakshatra — and therefore to change the Vimshottari balance and every
/// dasha date in the chart. A tool that cannot switch is telling a KP or Raman
/// practitioner that their tradition is a rounding error.
///
/// Every mode here is defined the same principled way: the sidereal zero point
/// is a fixed direction in space, pinned by an anchor epoch and an anchor
/// value, and the ayanamsa at any date is that direction's tropical longitude
/// at that date. Precession of the point is done properly (Meeus 21.7), which
/// accounts for the motion of the ecliptic plane itself rather than just
/// adding accumulated general precession.
///
/// Agreement with Swiss Ephemeris is within about half an arcminute across
/// 1800–2100 — two orders of magnitude below anything astrology can act on,
/// and measured rather than assumed by `test/conformance_test.dart`.
library;

import 'units.dart';

enum Ayanamsa {
  lahiri,
  trueChitra,
  raman,
  krishnamurti,
  faganBradley,
  yukteshwar,
  jnBhasin,
  pushyaPaksha,
  galacticCentre,
  /// Tropical — the offset is zero. Present so that Western charts travel
  /// through exactly the same pipeline as sidereal ones.
  none,
}

extension AyanamsaInfo on Ayanamsa {
  /// The name a reader recognises.
  String get label => switch (this) {
        Ayanamsa.lahiri => 'Lahiri (Chitrapaksha)',
        Ayanamsa.trueChitra => 'True Chitra',
        Ayanamsa.raman => 'Raman',
        Ayanamsa.krishnamurti => 'Krishnamurti (KP)',
        Ayanamsa.faganBradley => 'Fagan–Bradley',
        Ayanamsa.yukteshwar => 'Sri Yukteshwar',
        Ayanamsa.jnBhasin => 'J. N. Bhasin',
        Ayanamsa.pushyaPaksha => 'Pushya-paksha',
        Ayanamsa.galacticCentre => 'Galactic Centre 0° Sagittarius',
        Ayanamsa.none => 'Tropical (no ayanamsa)',
      };

  /// Where the zero point is pinned, in the words a practitioner would use.
  /// Shown in the provenance panel (G-46) so a disagreement with another
  /// astrologer's chart can be traced in one glance instead of an argument.
  String get anchor => switch (this) {
        Ayanamsa.lahiri =>
          'Official Indian ephemeris: 23°15′00″ on 21 March 1956',
        Ayanamsa.trueChitra => 'Spica held at exactly 180°00′',
        Ayanamsa.raman => '21°00′39″ at 1900.0',
        Ayanamsa.krishnamurti => '22°21′50″ at 1900.0',
        Ayanamsa.faganBradley => '24°02′31.4″ at 1950.0',
        Ayanamsa.yukteshwar => '20°54′36″ at 1900.0',
        Ayanamsa.jnBhasin => '21°47′43″ at 1900.0',
        Ayanamsa.pushyaPaksha => 'δ Cancri held at exactly 106°00′',
        Ayanamsa.galacticCentre => 'Galactic Centre held at 240°00′',
        Ayanamsa.none => 'None — tropical zodiac',
      };

  /// True for the schools that track a named star rather than a fixed epoch
  /// value. Those drift slightly differently and it is worth saying so.
  bool get isStarFixed =>
      this == Ayanamsa.trueChitra ||
      this == Ayanamsa.pushyaPaksha ||
      this == Ayanamsa.galacticCentre;

  String get storageKey => name;

  static Ayanamsa fromKey(String? key) {
    if (key == null) return Ayanamsa.lahiri;
    for (final a in Ayanamsa.values) {
      if (a.name == key) return a;
    }
    return Ayanamsa.lahiri;
  }
}

/// (anchor Julian Day in TT, tropical longitude of the sidereal zero point
/// at that instant).
const Map<Ayanamsa, (double, double)> _anchors = {
  // 1956-03-21 00:00, the Indian Calendar Reform Committee value.
  Ayanamsa.lahiri: (2435553.5, 23.250182778),
  // 1900-01-01 12:00 (JD 2415020.0) for the schools quoted at 1900.0.
  Ayanamsa.raman: (2415020.0, 21.010833333),
  Ayanamsa.krishnamurti: (2415020.0, 22.363888889),
  Ayanamsa.yukteshwar: (2415020.0, 20.910000000),
  Ayanamsa.jnBhasin: (2415020.0, 21.795277778),
  // 1950-01-01 00:00.
  Ayanamsa.faganBradley: (2433282.5, 24.042044444),
};

/// (J2000 ecliptic longitude of the star, the sidereal longitude it is
/// pinned to) for the star-fixed schools.
const Map<Ayanamsa, (double, double)> _starFixed = {
  // Spica, α Virginis.
  Ayanamsa.trueChitra: (203.8398, 180.0),
  // δ Cancri, the yogatara of Pushya.
  Ayanamsa.pushyaPaksha: (128.2000, 106.0),
  // Galactic Centre, Sgr A*.
  Ayanamsa.galacticCentre: (266.8500, 240.0),
};

/// Precesses an ecliptic position from one epoch to another (Meeus 21.7).
///
/// This is the part a simple "add the accumulated precession" shortcut gets
/// wrong: the ecliptic plane is itself moving, so a direction fixed in space
/// does not keep a constant ecliptic latitude, and its longitude does not
/// advance by exactly the general precession.
({double longitude, double latitude}) precessEcliptic({
  required double longitude,
  required double latitude,
  required double fromJd,
  required double toJd,
}) {
  final bigT = centuries(fromJd);
  final t = (toJd - fromJd) / 36525.0;
  final t2 = t * t;
  final t3 = t2 * t;

  final eta = ((47.0029 - 0.06603 * bigT + 0.000598 * bigT * bigT) * t +
          (-0.03302 + 0.000598 * bigT) * t2 +
          0.000060 * t3) /
      3600.0;

  final pi = (629554.982 +
          3289.4789 * bigT +
          0.60622 * bigT * bigT -
          (869.8089 + 0.50491 * bigT) * t +
          0.03536 * t2) /
      3600.0;

  final p = ((5029.0966 + 2.22226 * bigT - 0.000042 * bigT * bigT) * t +
          (1.11113 - 0.000042 * bigT) * t2 -
          0.000006 * t3) /
      3600.0;

  final a = cosd(eta) * cosd(latitude) * sind(pi - longitude) -
      sind(eta) * sind(latitude);
  final b = cosd(latitude) * cosd(pi - longitude);
  final c = cosd(eta) * sind(latitude) +
      sind(eta) * cosd(latitude) * sind(pi - longitude);

  return (
    longitude: norm360(p + pi - atan2d(a, b)),
    latitude: asind(c),
  );
}

/// Ayanamsa in degrees for a Julian Day in Terrestrial Time.
double ayanamsaFor(Ayanamsa mode, double jdTt) {
  if (mode == Ayanamsa.none) return 0.0;

  final star = _starFixed[mode];
  if (star != null) {
    // The zero point sits a fixed sidereal distance from the star, so precess
    // the star from J2000 and subtract.
    final moved = precessEcliptic(
      longitude: star.$1,
      latitude: 0.0,
      fromJd: 2451545.0,
      toJd: jdTt,
    );
    return norm360(moved.longitude - star.$2);
  }

  final anchor = _anchors[mode]!;
  final moved = precessEcliptic(
    longitude: anchor.$2,
    latitude: 0.0,
    fromJd: anchor.$1,
    toJd: jdTt,
  );
  return norm360(moved.longitude);
}

/// Rate of change of the ayanamsa, degrees per day.
///
/// Small — about 50 arcsec a year — but it is what makes a sidereal ingress
/// fall on a different day from a tropical one, so the transit search needs it.
double ayanamsaRate(Ayanamsa mode, double jdTt) {
  if (mode == Ayanamsa.none) return 0.0;
  const h = 1.0;
  return norm180(ayanamsaFor(mode, jdTt + h) - ayanamsaFor(mode, jdTt - h)) /
      (2 * h);
}

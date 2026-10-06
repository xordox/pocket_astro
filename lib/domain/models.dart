import '../engine/astro/ephemeris.dart';
import '../engine/zone_offset.dart';
import '../engine/astro/houses.dart';

class Place {
  const Place({
    required this.name,
    required this.region,
    required this.latitude,
    required this.longitude,
    required this.timezone,
  });

  final String name;
  final String region;
  final double latitude;
  final double longitude;
  final String timezone;

  String get label => region.isEmpty ? name : '$name, $region';

  /// True when this place can be used to build a chart.
  ///
  /// Checked at the two boundaries where a Place can arrive from outside the
  /// app: a geocoder response and a reader typing coordinates by hand. The
  /// timezone is deliberately NOT checked here — that needs the timezone
  /// database, and this file stays dependency-free.
  bool get isWellFormed =>
      name.trim().isNotEmpty &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;

  Map<String, dynamic> toJson() => {
        'name': name,
        'region': region,
        'latitude': latitude,
        'longitude': longitude,
        'timezone': timezone,
      };

  /// Tolerant of a missing field rather than throwing on one.
  ///
  /// This matters more than it looks: [LocalStore.loadProfiles] used to wrap
  /// the whole decode in one try/catch, so a single malformed record made the
  /// reader's entire library look deleted — and the next save overwrote the
  /// file with an empty list. A missing field now costs that field.
  factory Place.fromJson(Map<String, dynamic> j) => Place(
        name: j['name'] as String? ?? '',
        region: j['region'] as String? ?? '',
        latitude: (j['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (j['longitude'] as num?)?.toDouble() ?? 0,
        timezone: j['timezone'] as String? ?? '',
      );
}

enum TimeSource { hospital, memory, rectified, unknown }

class BirthInput {
  const BirthInput({
    required this.id,
    required this.name,
    required this.localDateTime,
    required this.place,
    required this.timeSource,
    this.notes = '',
    this.timeStandard = TimeStandard.zone,
    this.tags = const [],
  });

  final String id;
  final String name;
  final DateTime localDateTime;
  final Place place;
  final TimeSource timeSource;
  final String notes;

  /// How the recorded clock time should be read (G-40).
  ///
  /// A separate axis from [timeSource]: that says how *reliable* the time is,
  /// this says what the number on the record means. Before a place adopted
  /// standard time — and in older records well after — a birth time is often
  /// sun time at that longitude rather than zone time, and no timezone
  /// database can tell you which, because it is a fact about the record.
  final TimeStandard timeStandard;

  /// Free-form tags for finding this chart again (G-42).
  final List<String> tags;

  bool get timeUnknown => timeSource == TimeSource.unknown;

  BirthInput copyWith({
    String? name,
    DateTime? localDateTime,
    Place? place,
    TimeSource? timeSource,
    String? notes,
    TimeStandard? timeStandard,
    List<String>? tags,
  }) {
    return BirthInput(
      id: id,
      name: name ?? this.name,
      localDateTime: localDateTime ?? this.localDateTime,
      place: place ?? this.place,
      timeSource: timeSource ?? this.timeSource,
      notes: notes ?? this.notes,
      timeStandard: timeStandard ?? this.timeStandard,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'localDateTime': localDateTime.toIso8601String(),
        'place': place.toJson(),
        'timeSource': timeSource.name,
        'notes': notes,
        'timeStandard': timeStandard.name,
        'tags': tags,
      };

  factory BirthInput.fromJson(Map<String, dynamic> j) => BirthInput(
        id: j['id'] as String,
        name: j['name'] as String,
        localDateTime: DateTime.parse(j['localDateTime'] as String),
        place: Place.fromJson(j['place'] as Map<String, dynamic>),
        timeSource: TimeSource.values.byName(j['timeSource'] as String),
        notes: j['notes'] as String? ?? '',
        // Absent in records written before the setting existed, and `zone` is
        // what those records meant.
        timeStandard: TimeStandardInfo.fromKey(j['timeStandard'] as String?),
        tags: [
          for (final t in (j['tags'] as List? ?? const []))
            if (t is String) t,
        ],
      );
}

class GrahaRow {
  const GrahaRow({
    required this.name,
    required this.tropicalLon,
    required this.siderealLon,
    required this.sign,
    required this.house,
    required this.nakshatra,
    required this.pada,
    required this.dignity,
    required this.westernHouse,
    this.speed = 0,
    this.latitude = 0,
    this.declination = 0,
    this.chalitHouse = 0,
  });

  final String name;
  final double tropicalLon;
  final double siderealLon;
  final String sign;
  final int house;
  final String nakshatra;
  final int pada;
  final String dignity;
  final int westernHouse;

  /// Degrees of longitude per day. Negative means retrograde.
  ///
  /// Gap G-01. Before this field existed nothing in the app could tell a vakri
  /// graha from a direct one — not the chart, not the strength calculations,
  /// not the transit engine. Half the Vedic and Western apparatus that follows
  /// is built on it.
  final double speed;

  /// Ecliptic latitude, degrees (G-08). Declinations, parallels and graha
  /// yuddha all need it; it used to be computed and discarded.
  final double latitude;

  /// Declination, degrees. What out-of-bounds and parallel aspects read.
  final double declination;

  /// Bhava chalit house under the Sripati cusps (G-16), or 0 when the birth
  /// time is unknown.
  ///
  /// Kept alongside [house] rather than replacing it, because the two
  /// disagreeing is information: it is the commonest reason two astrologers
  /// read the same kundali differently, and the app shows both instead of
  /// picking a side.
  final int chalitHouse;

  bool get isRetrograde => speed < -0.003;
  bool get isStationary => speed.abs() <= 0.003;
  bool get isDirect => speed > 0.003;

  /// Rahu and Ketu are always retrograde, so the marker is noise on them; the
  /// luminaries never are.
  bool get showsMotionMarker =>
      isRetrograde && name != 'Rahu' && name != 'Ketu' && name != 'Lagna';

  /// The label a jyotishi uses: vakri, stambhi, margi.
  String get motionLabel {
    if (name == 'Lagna') return '';
    if (isStationary) return 'stationary';
    return isRetrograde ? 'retrograde' : 'direct';
  }

  /// True when [house] and [chalitHouse] disagree — worth surfacing.
  bool get chalitDiffers => chalitHouse != 0 && chalitHouse != house;

  GrahaRow copyWith({int? house, int? chalitHouse, int? westernHouse}) => GrahaRow(
        name: name,
        tropicalLon: tropicalLon,
        siderealLon: siderealLon,
        sign: sign,
        house: house ?? this.house,
        nakshatra: nakshatra,
        pada: pada,
        dignity: dignity,
        westernHouse: westernHouse ?? this.westernHouse,
        speed: speed,
        latitude: latitude,
        declination: declination,
        chalitHouse: chalitHouse ?? this.chalitHouse,
      );
}

class AspectHit {
  const AspectHit({
    required this.a,
    required this.b,
    required this.name,
    required this.angle,
    required this.orb,
    this.applying = false,
    this.outOfSign = false,
    this.maxOrb = 0,
    this.kind = AspectKind.major,
  });

  final String a;
  final String b;
  final String name;

  /// The exact angle the aspect is made at.
  final double angle;

  /// How far from exact, degrees.
  final double orb;

  /// True when the faster body is still closing on the aspect.
  ///
  /// Part of G-29, and impossible before planetary speed existed (G-01). It is
  /// the difference between something about to happen and something already
  /// over, and it is the first question asked in horary.
  final bool applying;

  /// True when the aspect perfects across a sign boundary — a square between
  /// signs that are not actually in square. Traditional practice weakens or
  /// discounts these; modern practice usually keeps them but wants them
  /// flagged.
  final bool outOfSign;

  /// The orb allowed for this pair, so the UI can draw strength as a fraction
  /// rather than a bare number.
  final double maxOrb;

  final AspectKind kind;

  /// 1.0 at exact, falling to 0 at the edge of orb.
  double get strength => maxOrb <= 0 ? 0 : (1.0 - orb / maxOrb).clamp(0.0, 1.0);

  String get motion => applying ? 'applying' : 'separating';
}

enum AspectKind { major, minor, declination, antiscion }

class DashaSpan {
  const DashaSpan({
    required this.lord,
    required this.start,
    required this.end,
    this.level = 'MD',
    this.parent,
  });

  final String lord;
  final DateTime start;
  final DateTime end;
  final String level;
  final String? parent;

  bool contains(DateTime t) =>
      !t.isBefore(start) && t.isBefore(end);
}

class KootaScore {
  const KootaScore({
    required this.name,
    required this.obtained,
    required this.max,
    required this.note,
  });
  final String name;
  final double obtained;
  final double max;
  final String note;
}

class MatchResult {
  const MatchResult({
    required this.kootas,
    required this.total,
    required this.max,
    required this.band,
    required this.mangalA,
    required this.mangalB,
    required this.overlay,
    required this.confidence,
  });

  final List<KootaScore> kootas;
  final double total;
  final double max;
  final String band;
  final bool mangalA;
  final bool mangalB;
  final List<String> overlay;
  final int confidence;
}

class LifeArea {
  const LifeArea({required this.title, required this.body, required this.confidence});
  final String title;
  final String body;
  final int confidence;
}

class NatalChart {
  NatalChart({
    required this.input,
    required this.utc,
    required this.jd,
    required this.ayanamsa,
    required this.lagnaSidereal,
    required this.lagnaTropical,
    required this.mcTropical,
    required this.grahas,
    required this.navamsaLagna,
    required this.dasha,
    required this.antardashas,
    required this.westernAspects,
    required this.yogas,
    required this.engineStamp,
    this.sky,
    this.settings = const ChartSettings(),
  });

  /// The full positional snapshot the chart was built from.
  ///
  /// Carries speeds, latitudes, declinations and real house cusps. Nullable
  /// only so that a chart can still be hand-assembled in a test without
  /// standing up a whole sky.
  final Sky? sky;

  /// What the chart was computed under (G-46).
  ///
  /// Ayanamsa, house system, node type and topocentric mode used to be silent
  /// assumptions baked into a constant string. Now they travel with the chart,
  /// which is what makes a disagreement with another astrologer's figures a
  /// one-glance question instead of an argument.
  final ChartSettings settings;

  HouseCusps? get westernCusps => sky?.western;
  HouseCusps? get vedicCusps => sky?.vedic;

  /// True when the Sun was below the horizon. Sect governs the Part of
  /// Fortune's formula and the whole traditional dignity scheme.
  bool get isNightChart => sky?.isNightChart ?? false;

  double? get partOfFortune => sky?.partOfFortune;
  double? get partOfSpirit => sky?.partOfSpirit;
  double? get vertex => sky?.western.vertex;
  double? get eastPoint => sky?.western.eastPoint;

  /// Grahas that are retrograde, in chart order. The nodes are excluded —
  /// they always are, so marking them says nothing.
  List<GrahaRow> get retrogrades =>
      grahas.where((g) => g.showsMotionMarker).toList();

  final BirthInput input;
  final DateTime utc;
  final double jd;
  final double ayanamsa;
  final double lagnaSidereal;
  final double lagnaTropical;
  final double mcTropical;
  final List<GrahaRow> grahas;
  final int navamsaLagna;
  final List<DashaSpan> dasha;
  final List<DashaSpan> antardashas;
  final List<AspectHit> westernAspects;
  final List<String> yogas;
  final String engineStamp;

  GrahaRow graha(String name) => grahas.firstWhere((g) => g.name == name);

  DashaSpan? mahadashaAt(DateTime t) {
    for (final d in dasha) {
      if (d.contains(t)) return d;
    }
    return dasha.isEmpty ? null : dasha.last;
  }

  DashaSpan? antardashaAt(DateTime t) {
    for (final d in antardashas) {
      if (d.contains(t)) return d;
    }
    return null;
  }
}

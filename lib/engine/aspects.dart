/// The Western aspect engine.
///
/// Gaps G-29 and G-30. What was here before: five aspects, orbs hardcoded at
/// 8° for the luminaries and 6° for everything else, no notion of applying or
/// separating, and no patterns. Orbs are a matter of school, and a tool that
/// fixes them is telling the astrologer their judgment is wrong.
///
/// What this adds:
///
///   * the minor aspects — semi-sextile, semi-square, quintile,
///     sesquiquadrate, biquintile and quincunx;
///   * an orb table that is per-aspect and per-body and can be edited;
///   * applying versus separating, which needed planetary speed to exist
///     at all (G-01);
///   * an out-of-sign flag, which traditional practice reads as a weakened
///     aspect and modern practice at least wants to know about;
///   * aspect patterns — T-square, grand trine, grand cross, yod, kite,
///     mystic rectangle and stellium;
///   * parallels and contraparallels of declination, which many astrologers
///     weight as heavily as a conjunction, and which needed latitude to
///     survive the pipeline (G-08);
///   * antiscia and contra-antiscia;
///   * a midpoint tree.
library;

import '../domain/models.dart';
import 'astro/ephemeris.dart';
import 'astro/units.dart';

class AspectDef {
  const AspectDef(this.name, this.angle, this.kind, this.baseOrb, {this.glyph = ''});
  final String name;
  final double angle;
  final AspectKind kind;

  /// Default orb before the per-body multiplier.
  final double baseOrb;
  final String glyph;
}

const majorAspects = <AspectDef>[
  AspectDef('conjunction', 0, AspectKind.major, 8, glyph: '☌'),
  AspectDef('sextile', 60, AspectKind.major, 6, glyph: '⚹'),
  AspectDef('square', 90, AspectKind.major, 8, glyph: '□'),
  AspectDef('trine', 120, AspectKind.major, 8, glyph: '△'),
  AspectDef('opposition', 180, AspectKind.major, 8, glyph: '☍'),
];

const minorAspects = <AspectDef>[
  AspectDef('semi-sextile', 30, AspectKind.minor, 2, glyph: '⚺'),
  AspectDef('semi-square', 45, AspectKind.minor, 2, glyph: '∠'),
  AspectDef('quintile', 72, AspectKind.minor, 2, glyph: 'Q'),
  AspectDef('sesquiquadrate', 135, AspectKind.minor, 2, glyph: '⚼'),
  AspectDef('biquintile', 144, AspectKind.minor, 2, glyph: 'bQ'),
  AspectDef('quincunx', 150, AspectKind.minor, 3, glyph: '⚻'),
];

const allAspects = [...majorAspects, ...minorAspects];

/// How much of the base orb a body is allowed.
///
/// The luminaries get the widest orbs, the outer planets and the points the
/// narrowest. Orbs are taken as the *larger* of the two bodies' allowances,
/// which is the common convention — a Sun–Pluto square is judged on the Sun's
/// orb, not Pluto's.
const Map<String, double> defaultOrbFactor = {
  'Sun': 1.25,
  'Moon': 1.25,
  'Mercury': 1.0,
  'Venus': 1.0,
  'Mars': 1.0,
  'Jupiter': 1.0,
  'Saturn': 1.0,
  'Uranus': 0.75,
  'Neptune': 0.75,
  'Pluto': 0.75,
  'Rahu': 0.5,
  'Ketu': 0.5,
  'Chiron': 0.5,
  'Lilith': 0.4,
  'Ceres': 0.4,
  'Pallas': 0.4,
  'Juno': 0.4,
  'Vesta': 0.4,
  'Lagna': 1.0,
};

/// A reader-editable orb policy.
class OrbPolicy {
  const OrbPolicy({
    this.aspectOrbs = const {},
    this.bodyFactors = defaultOrbFactor,
    this.includeMinor = true,
    this.declinationOrb = 1.0,
    this.antiscionOrb = 1.5,
  });

  /// Overrides the base orb of a named aspect.
  final Map<String, double> aspectOrbs;
  final Map<String, double> bodyFactors;
  final bool includeMinor;
  final double declinationOrb;
  final double antiscionOrb;

  double baseFor(AspectDef d) => aspectOrbs[d.name] ?? d.baseOrb;

  double orbFor(AspectDef d, String a, String b) {
    final fa = bodyFactors[a] ?? 0.6;
    final fb = bodyFactors[b] ?? 0.6;
    return baseFor(d) * (fa > fb ? fa : fb);
  }

  OrbPolicy copyWith({
    Map<String, double>? aspectOrbs,
    Map<String, double>? bodyFactors,
    bool? includeMinor,
    double? declinationOrb,
    double? antiscionOrb,
  }) =>
      OrbPolicy(
        aspectOrbs: aspectOrbs ?? this.aspectOrbs,
        bodyFactors: bodyFactors ?? this.bodyFactors,
        includeMinor: includeMinor ?? this.includeMinor,
        declinationOrb: declinationOrb ?? this.declinationOrb,
        antiscionOrb: antiscionOrb ?? this.antiscionOrb,
      );

  Map<String, dynamic> toJson() => {
        'aspectOrbs': aspectOrbs,
        'includeMinor': includeMinor,
        'declinationOrb': declinationOrb,
        'antiscionOrb': antiscionOrb,
      };

  factory OrbPolicy.fromJson(Map<String, dynamic> j) => OrbPolicy(
        aspectOrbs: {
          for (final e in (j['aspectOrbs'] as Map? ?? {}).entries)
            e.key as String: (e.value as num).toDouble(),
        },
        includeMinor: j['includeMinor'] as bool? ?? true,
        declinationOrb: (j['declinationOrb'] as num?)?.toDouble() ?? 1.0,
        antiscionOrb: (j['antiscionOrb'] as num?)?.toDouble() ?? 1.5,
      );
}

/// Bodies that take part in the aspect grid, in wheel order.
const aspectBodies = [
  'Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn',
  'Uranus', 'Neptune', 'Pluto', 'Chiron', 'Rahu', 'Lagna',
];

/// Computes the aspect grid for a chart.
List<AspectHit> westernAspects(
  List<GrahaRow> grahas, {
  Sky? sky,
  OrbPolicy policy = const OrbPolicy(),
}) {
  final byName = {for (final g in grahas) g.name: g};
  final present = aspectBodies.where(byName.containsKey).toList();
  final defs = policy.includeMinor ? allAspects : majorAspects;
  final hits = <AspectHit>[];

  for (var i = 0; i < present.length; i++) {
    for (var j = i + 1; j < present.length; j++) {
      final a = byName[present[i]]!;
      final b = byName[present[j]]!;
      final delta = separation(a.tropicalLon, b.tropicalLon);

      for (final def in defs) {
        final maxOrb = policy.orbFor(def, a.name, b.name);
        final orb = (delta - def.angle).abs();
        if (orb > maxOrb) continue;

        hits.add(AspectHit(
          a: a.name,
          b: b.name,
          name: def.name,
          angle: def.angle,
          orb: orb,
          maxOrb: maxOrb,
          kind: def.kind,
          applying: _isApplying(a, b, def.angle),
          outOfSign: _isOutOfSign(a, b, def.angle),
        ));
      }
    }
  }

  hits.sort((x, y) {
    if (x.kind != y.kind) return x.kind.index.compareTo(y.kind.index);
    return x.orb.compareTo(y.orb);
  });
  return hits;
}

/// True when the two bodies are still closing on the exact angle.
///
/// The test is on the *rate of change of the separation*, not on which body is
/// ahead: a retrograde Mars closing on a direct Venus is applying just as
/// surely as the other way round, and that is the case a naive implementation
/// gets backwards.
bool _isApplying(GrahaRow a, GrahaRow b, double angle) {
  const h = 0.01;
  double sepAt(double days) {
    final la = a.tropicalLon + a.speed * days;
    final lb = b.tropicalLon + b.speed * days;
    return (separation(la, lb) - angle).abs();
  }

  return sepAt(h) < sepAt(-h);
}

/// True when the aspect perfects across a sign boundary.
bool _isOutOfSign(GrahaRow a, GrahaRow b, double angle) {
  final signA = (a.tropicalLon / 30).floor() % 12;
  final signB = (b.tropicalLon / 30).floor() % 12;
  final signDistance = ((signB - signA) % 12 + 12) % 12;
  final expected = (angle / 30).round();
  return signDistance != expected && (12 - signDistance) != expected;
}

// ---------------------------------------------------------------------------
// Declination
// ---------------------------------------------------------------------------

/// Parallels and contraparallels (G-30).
///
/// A parallel behaves like a conjunction and a contraparallel like an
/// opposition, regardless of how far apart the two bodies are in longitude.
/// That is why they surprise people, and why leaving them out hides a real
/// contact.
List<AspectHit> declinationAspects(
  List<GrahaRow> grahas, {
  OrbPolicy policy = const OrbPolicy(),
}) {
  final present =
      grahas.where((g) => aspectBodies.contains(g.name) && g.name != 'Lagna').toList();
  final out = <AspectHit>[];
  for (var i = 0; i < present.length; i++) {
    for (var j = i + 1; j < present.length; j++) {
      final a = present[i];
      final b = present[j];
      final parallel = (a.declination - b.declination).abs();
      final contra = (a.declination + b.declination).abs();
      if (parallel <= policy.declinationOrb) {
        out.add(AspectHit(
          a: a.name, b: b.name, name: 'parallel', angle: 0,
          orb: parallel, maxOrb: policy.declinationOrb,
          kind: AspectKind.declination,
        ));
      }
      if (contra <= policy.declinationOrb) {
        out.add(AspectHit(
          a: a.name, b: b.name, name: 'contraparallel', angle: 180,
          orb: contra, maxOrb: policy.declinationOrb,
          kind: AspectKind.declination,
        ));
      }
    }
  }
  out.sort((x, y) => x.orb.compareTo(y.orb));
  return out;
}

/// Antiscia — points equidistant from the solstitial axis, which the
/// tradition treats as a hidden conjunction.
double antiscion(double longitude) => norm360(360 - longitude + 180);
double contraAntiscion(double longitude) => norm360(antiscion(longitude) + 180);

List<AspectHit> antiscionAspects(
  List<GrahaRow> grahas, {
  OrbPolicy policy = const OrbPolicy(),
}) {
  final present =
      grahas.where((g) => aspectBodies.contains(g.name)).toList();
  final out = <AspectHit>[];
  for (var i = 0; i < present.length; i++) {
    for (var j = 0; j < present.length; j++) {
      if (i == j) continue;
      final a = present[i];
      final b = present[j];
      if (a.name.compareTo(b.name) >= 0) continue;
      final d1 = separation(antiscion(a.tropicalLon), b.tropicalLon);
      final d2 = separation(contraAntiscion(a.tropicalLon), b.tropicalLon);
      if (d1 <= policy.antiscionOrb) {
        out.add(AspectHit(
          a: a.name, b: b.name, name: 'antiscion', angle: 0,
          orb: d1, maxOrb: policy.antiscionOrb, kind: AspectKind.antiscion));
      }
      if (d2 <= policy.antiscionOrb) {
        out.add(AspectHit(
          a: a.name, b: b.name, name: 'contra-antiscion', angle: 180,
          orb: d2, maxOrb: policy.antiscionOrb, kind: AspectKind.antiscion));
      }
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Patterns
// ---------------------------------------------------------------------------

class AspectPattern {
  const AspectPattern({
    required this.name,
    required this.bodies,
    required this.note,
  });
  final String name;
  final List<String> bodies;
  final String note;
}

/// Finds the configurations an astrologer reads as a unit rather than as
/// separate aspects.
List<AspectPattern> aspectPatterns(List<GrahaRow> grahas, List<AspectHit> hits) {
  final out = <AspectPattern>[];
  final byName = {for (final g in grahas) g.name: g};

  bool has(String a, String b, String aspect) => hits.any((h) =>
      h.name == aspect &&
      ((h.a == a && h.b == b) || (h.a == b && h.b == a)));

  final names = grahas
      .where((g) => aspectBodies.contains(g.name))
      .map((g) => g.name)
      .toList();

  // Stellium: three or more bodies inside one sign.
  final bySign = <int, List<String>>{};
  for (final n in names) {
    if (n == 'Lagna') continue;
    final sign = (byName[n]!.tropicalLon / 30).floor() % 12;
    bySign.putIfAbsent(sign, () => []).add(n);
  }
  for (final e in bySign.entries) {
    if (e.value.length >= 3) {
      out.add(AspectPattern(
        name: 'Stellium',
        bodies: e.value,
        note: '${e.value.length} bodies packed into one sign. That area of the '
            'chart carries far more weight than its house alone suggests.',
      ));
    }
  }

  for (var i = 0; i < names.length; i++) {
    for (var j = i + 1; j < names.length; j++) {
      // T-square: two in opposition, both square a third.
      if (has(names[i], names[j], 'opposition')) {
        for (final k in names) {
          if (k == names[i] || k == names[j]) continue;
          if (has(k, names[i], 'square') && has(k, names[j], 'square')) {
            out.add(AspectPattern(
              name: 'T-square',
              bodies: [names[i], names[j], k],
              note: 'An opposition braced by a square. $k is the release '
                  'point and takes the strain.',
            ));
          }
        }
        // Mystic rectangle: two oppositions joined by sextiles and trines.
        for (var m = 0; m < names.length; m++) {
          for (var n = m + 1; n < names.length; n++) {
            if ({names[m], names[n]}.intersection({names[i], names[j]}).isNotEmpty) {
              continue;
            }
            if (has(names[m], names[n], 'opposition') &&
                has(names[i], names[m], 'sextile') &&
                has(names[j], names[n], 'sextile') &&
                has(names[i], names[n], 'trine') &&
                has(names[j], names[m], 'trine')) {
              out.add(AspectPattern(
                name: 'Mystic rectangle',
                bodies: [names[i], names[j], names[m], names[n]],
                note: 'Two oppositions laced together by trines and sextiles — '
                    'tension with a built-in way to work it.',
              ));
            }
          }
        }
      }

      // Yod: two in sextile, both quincunx a third.
      if (has(names[i], names[j], 'sextile')) {
        for (final k in names) {
          if (k == names[i] || k == names[j]) continue;
          if (has(k, names[i], 'quincunx') && has(k, names[j], 'quincunx')) {
            out.add(AspectPattern(
              name: 'Yod',
              bodies: [names[i], names[j], k],
              note: 'Two quincunxes onto $k from a sextile base. Pressure '
                  'toward an adjustment that never feels natural.',
            ));
          }
        }
      }

      // Grand trine, and the kite that can sit on it.
      if (has(names[i], names[j], 'trine')) {
        for (final k in names) {
          if (k == names[i] || k == names[j]) continue;
          if (k.compareTo(names[j]) <= 0) continue;
          if (has(k, names[i], 'trine') && has(k, names[j], 'trine')) {
            out.add(AspectPattern(
              name: 'Grand trine',
              bodies: [names[i], names[j], k],
              note: 'A closed circuit of ease. Talent that tends not to be '
                  'pushed until something outside it applies pressure.',
            ));
            for (final apex in names) {
              if ([names[i], names[j], k].contains(apex)) continue;
              final opposed = [names[i], names[j], k]
                  .where((x) => has(apex, x, 'opposition'))
                  .toList();
              if (opposed.length == 1) {
                out.add(AspectPattern(
                  name: 'Kite',
                  bodies: [names[i], names[j], k, apex],
                  note: 'A grand trine with $apex opposite one corner — the '
                      'outlet the grand trine otherwise lacks.',
                ));
              }
            }
          }
        }
      }
    }
  }

  // Grand cross: two oppositions square to each other.
  final oppositions = hits.where((h) => h.name == 'opposition').toList();
  for (var i = 0; i < oppositions.length; i++) {
    for (var j = i + 1; j < oppositions.length; j++) {
      final o1 = oppositions[i];
      final o2 = oppositions[j];
      final members = {o1.a, o1.b, o2.a, o2.b};
      if (members.length != 4) continue;
      if (has(o1.a, o2.a, 'square') &&
          has(o1.a, o2.b, 'square') &&
          has(o1.b, o2.a, 'square') &&
          has(o1.b, o2.b, 'square')) {
        out.add(AspectPattern(
          name: 'Grand cross',
          bodies: members.toList(),
          note: 'Four corners locked in square and opposition. Nothing here '
              'moves without the other three moving too.',
        ));
      }
    }
  }

  // Deduplicate: the same set found from two directions is one pattern.
  final seen = <String>{};
  return out.where((p) {
    final key = '${p.name}:${(p.bodies.toList()..sort()).join(',')}';
    return seen.add(key);
  }).toList();
}

// ---------------------------------------------------------------------------
// Midpoints
// ---------------------------------------------------------------------------

class Midpoint {
  const Midpoint(this.a, this.b, this.longitude);
  final String a;
  final String b;
  final double longitude;
  String get label => '$a/$b';
}

/// Every midpoint, and the bodies sitting on one.
///
/// The Ebertin method reads a planet on a midpoint as a sentence: Sun on
/// Venus/Mars is not the same statement as Venus square Mars.
List<Midpoint> midpoints(List<GrahaRow> grahas) {
  final present =
      grahas.where((g) => aspectBodies.contains(g.name)).toList();
  final out = <Midpoint>[];
  for (var i = 0; i < present.length; i++) {
    for (var j = i + 1; j < present.length; j++) {
      final a = present[i];
      final b = present[j];
      // The near midpoint, on the short arc.
      final diff = norm180(b.tropicalLon - a.tropicalLon);
      out.add(Midpoint(a.name, b.name, norm360(a.tropicalLon + diff / 2)));
    }
  }
  return out;
}

class MidpointHit {
  const MidpointHit(this.body, this.midpoint, this.orb, this.hard);
  final String body;
  final Midpoint midpoint;
  final double orb;

  /// True when the contact is on the 90° dial — conjunction, square or
  /// opposition to the midpoint, which is what cosmobiology reads.
  final bool hard;
}

List<MidpointHit> midpointContacts(
  List<GrahaRow> grahas, {
  double orb = 1.5,
}) {
  final mids = midpoints(grahas);
  final present =
      grahas.where((g) => aspectBodies.contains(g.name)).toList();
  final out = <MidpointHit>[];
  for (final m in mids) {
    for (final g in present) {
      if (g.name == m.a || g.name == m.b) continue;
      for (final target in [0.0, 90.0, 180.0, 270.0]) {
        final d = separation(g.tropicalLon, norm360(m.longitude + target));
        if (d <= orb) {
          out.add(MidpointHit(g.name, m, d, true));
        }
      }
    }
  }
  out.sort((a, b) => a.orb.compareTo(b.orb));
  return out;
}

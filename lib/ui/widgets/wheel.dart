/// The Western circular chart wheel.
///
/// Gap G-45. The app drew North and South Indian kundalis well and had no way
/// to show a Western chart the way Western astrologers read it — which also
/// meant bi-wheels for transits and synastry had nowhere to render.
///
/// Design decisions worth stating, because a wheel is easy to draw badly:
///
///   * **The ascendant is pinned to the left, horizontal**, as every printed
///     Western chart has it. The wheel rotates; the page does not.
///   * **Cusps are real.** With Placidus at a high latitude houses become very
///     unequal, and a wheel that draws twelve equal slices while the numbers
///     say otherwise is lying in the most visible way available to it.
///   * **Glyph collision is solved by spreading, not by hiding.** Bodies
///     within a few degrees are fanned apart along the radius and a leader
///     line ties each back to its true degree, so nothing is dropped.
///   * **Retrograde is marked on the glyph**, since that is now known (G-01).
///   * Colour is never the only encoding: every body carries its abbreviation.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../engine/astro/houses.dart';
import '../../engine/astro/units.dart';
import '../../engine/tables.dart';
import '../../theme/tokens.dart';

/// Short labels. Glyph fonts are not bundled, so the wheel uses the
/// abbreviations practitioners write by hand.
const wheelAbbreviations = <String, String>{
  'Sun': 'Su', 'Moon': 'Mo', 'Mercury': 'Me', 'Venus': 'Ve', 'Mars': 'Ma',
  'Jupiter': 'Ju', 'Saturn': 'Sa', 'Uranus': 'Ur', 'Neptune': 'Ne',
  'Pluto': 'Pl', 'Rahu': 'Ra', 'Ketu': 'Ke', 'Chiron': 'Ch', 'Lilith': 'Li',
  'Ceres': 'Ce', 'Pallas': 'Pa', 'Juno': 'Jn', 'Vesta': 'Vs', 'Lagna': 'Asc',
};

const _signGlyphs = [
  '♈', '♉', '♊', '♋', '♌', '♍', '♎', '♏', '♐', '♑', '♒', '♓',
];

/// One body placed on a wheel ring.
class WheelBody {
  const WheelBody({
    required this.name,
    required this.longitude,
    required this.retrograde,
    this.ring = 0,
  });
  final String name;
  final double longitude;
  final bool retrograde;

  /// 0 for the inner (natal) ring, 1 for the outer ring of a bi-wheel.
  final int ring;

  factory WheelBody.fromGraha(GrahaRow g, {int ring = 0}) => WheelBody(
        name: g.name,
        longitude: g.tropicalLon,
        retrograde: g.showsMotionMarker,
        ring: ring,
      );
}

class ChartWheel extends StatelessWidget {
  const ChartWheel({
    super.key,
    required this.bodies,
    required this.cusps,
    this.aspects = const [],
    this.outerBodies = const [],
    this.outerLabel,
    this.showAspectLines = true,
    this.sidereal = false,
    this.ayanamsa = 0,
  });

  final List<WheelBody> bodies;
  final HouseCusps cusps;
  final List<AspectHit> aspects;

  /// A second ring — transits, a progressed chart, or a partner's.
  final List<WheelBody> outerBodies;
  final String? outerLabel;

  final bool showAspectLines;

  /// When true the sign ring is labelled sidereally.
  final bool sidereal;
  final double ayanamsa;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, 520.0);
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _WheelPainter(
                bodies: bodies,
                outerBodies: outerBodies,
                cusps: cusps,
                aspects: showAspectLines ? aspects : const [],
                sidereal: sidereal,
                ayanamsa: ayanamsa,
                textDirection: Directionality.of(context),
              ),
              child: Semantics(
                label: _semanticSummary(),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }

  String _semanticSummary() {
    final parts = <String>[
      'Chart wheel.',
      'Ascendant ${formatDms(cusps.ascendant)} '
          '${signs[signIndex(cusps.ascendant)].name}.',
      'Midheaven ${formatDms(cusps.midheaven)} '
          '${signs[signIndex(cusps.midheaven)].name}.',
      for (final b in bodies)
        '${b.name} ${formatDms(b.longitude)} '
            '${signs[signIndex(b.longitude)].name}'
            '${b.retrograde ? ' retrograde' : ''}.',
    ];
    return parts.join(' ');
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.bodies,
    required this.outerBodies,
    required this.cusps,
    required this.aspects,
    required this.sidereal,
    required this.ayanamsa,
    required this.textDirection,
  });

  final List<WheelBody> bodies;
  final List<WheelBody> outerBodies;
  final HouseCusps cusps;
  final List<AspectHit> aspects;
  final bool sidereal;
  final double ayanamsa;
  final TextDirection textDirection;

  /// Screen angle for an ecliptic longitude.
  ///
  /// The ascendant sits at the left of the wheel (180° on screen) and
  /// longitude increases anticlockwise, which is what makes the tenth house
  /// appear at the top.
  double _angleFor(double longitude) =>
      d2r(180.0 - norm360(longitude - cusps.ascendant));

  Offset _point(Offset centre, double radius, double longitude) {
    final a = _angleFor(longitude);
    return Offset(
      centre.dx + radius * math.cos(a),
      centre.dy - radius * math.sin(a),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final outer = size.width / 2 - 2;
    final signRingInner = outer * 0.86;
    final houseRingInner = outer * 0.60;
    final bodyRadius = outer * 0.735;
    final outerBodyRadius = outer * 0.805;
    final aspectRadius = houseRingInner - 2;

    _paintSignRing(canvas, centre, outer, signRingInner);
    _paintHouses(canvas, centre, signRingInner, houseRingInner);
    if (aspects.isNotEmpty) {
      _paintAspects(canvas, centre, aspectRadius);
    }
    _paintBodies(canvas, centre, bodyRadius, signRingInner, bodies);
    if (outerBodies.isNotEmpty) {
      _paintBodies(canvas, centre, outerBodyRadius, signRingInner, outerBodies,
          outerRing: true);
    }
    _paintAngles(canvas, centre, outer, houseRingInner);
  }

  void _paintSignRing(
      Canvas canvas, Offset centre, double outer, double inner) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = hairline;

    canvas.drawCircle(centre, outer, ring);
    canvas.drawCircle(centre, inner, ring);

    for (var i = 0; i < 12; i++) {
      final boundary = i * 30.0 + (sidereal ? ayanamsa : 0);
      final a = _point(centre, inner, boundary);
      final b = _point(centre, outer, boundary);
      canvas.drawLine(a, b, ring);

      // Element tint, so the four triplicities read at a glance.
      final wedge = Path()
        ..moveTo(centre.dx, centre.dy)
        ..arcTo(
          Rect.fromCircle(center: centre, radius: outer),
          _angleFor(boundary) * -1,
          d2r(-30),
          false,
        )
        ..close();
      canvas.save();
      canvas.clipPath(Path()
        ..addOval(Rect.fromCircle(center: centre, radius: outer))
        ..addOval(Rect.fromCircle(center: centre, radius: inner))
        ..fillType = PathFillType.evenOdd);
      canvas.drawPath(
        wedge,
        Paint()..color = _elementTint(i).withValues(alpha: 0.5),
      );
      canvas.restore();

      final mid = boundary + 15;
      _text(
        canvas,
        _point(centre, (outer + inner) / 2, mid),
        _signGlyphs[i],
        TextStyle(fontSize: outer * 0.055, color: inkSoft),
      );
    }

    // Degree ticks every five degrees, longer every ten.
    final tick = Paint()..color = hairline..strokeWidth = 1;
    for (var d = 0; d < 360; d += 5) {
      final lon = d.toDouble() + (sidereal ? ayanamsa : 0);
      final length = d % 10 == 0 ? outer * 0.030 : outer * 0.018;
      canvas.drawLine(
        _point(centre, inner, lon),
        _point(centre, inner - length, lon),
        tick,
      );
    }
  }

  Color _elementTint(int sign) => switch (signs[sign].element) {
        'Fire' => const Color(0xFFFBE9E2),
        'Earth' => const Color(0xFFEDF0E6),
        'Air' => const Color(0xFFE9EFF6),
        _ => const Color(0xFFE6EFF0),
      };

  void _paintHouses(
      Canvas canvas, Offset centre, double outerEdge, double inner) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = hairline;
    canvas.drawCircle(centre, inner, line);

    for (var i = 0; i < 12; i++) {
      final cusp = cusps.cusps[i];
      final isAngle = i == 0 || i == 3 || i == 6 || i == 9;
      canvas.drawLine(
        _point(centre, inner, cusp),
        _point(centre, outerEdge, cusp),
        Paint()
          ..strokeWidth = isAngle ? 1.8 : 1
          ..color = isAngle ? ink : hairline,
      );

      // House number, at the middle of the house rather than at its cusp —
      // which is why unequal houses have to be measured, not assumed.
      final next = cusps.cusps[(i + 1) % 12];
      final span = norm360(next - cusp);
      final mid = norm360(cusp + span / 2);
      _text(
        canvas,
        _point(centre, inner + (outerEdge - inner) * 0.12, mid),
        '${i + 1}',
        TextStyle(fontSize: outerEdge * 0.035, color: inkFaint),
      );
    }
  }

  void _paintAspects(Canvas canvas, Offset centre, double radius) {
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = hairline,
    );

    final byName = {for (final b in bodies) b.name: b.longitude};
    for (final a in aspects) {
      if (a.kind != AspectKind.major) continue;
      final from = byName[a.a];
      final to = byName[a.b];
      if (from == null || to == null) continue;

      final colour = switch (a.name) {
        'trine' || 'sextile' => beneficColor,
        'square' || 'opposition' => maleficColor,
        _ => neutralColor,
      };
      canvas.drawLine(
        _point(centre, radius, from),
        _point(centre, radius, to),
        Paint()
          ..strokeWidth = a.name == 'conjunction' ? 0.8 : 1.0 + a.strength
          ..color = colour.withValues(alpha: 0.22 + 0.5 * a.strength),
      );
    }
  }

  /// Places glyphs, fanning apart any that would overlap.
  ///
  /// The naive approach — draw each body at its own degree — turns a stellium
  /// into an unreadable smear. Spreading along the radius keeps every body
  /// visible and keeps its true degree recoverable from the leader line.
  void _paintBodies(
    Canvas canvas,
    Offset centre,
    double radius,
    double tickRadius,
    List<WheelBody> list, {
    bool outerRing = false,
  }) {
    final sorted = [...list]
      ..sort((a, b) => norm360(a.longitude - cusps.ascendant)
          .compareTo(norm360(b.longitude - cusps.ascendant)));

    // Group anything within six degrees of its neighbour.
    final clusters = <List<WheelBody>>[];
    for (final b in sorted) {
      if (clusters.isEmpty ||
          separation(clusters.last.last.longitude, b.longitude) > 6.0) {
        clusters.add([b]);
      } else {
        clusters.last.add(b);
      }
    }

    final fontSize = radius * 0.062;
    for (final cluster in clusters) {
      for (var i = 0; i < cluster.length; i++) {
        final body = cluster[i];
        // Step each member of a cluster inward so none is hidden.
        final step = radius * 0.085;
        final r = outerRing
            ? radius + i * step * 0.55
            : radius - i * step;

        // Leader line back to the true degree on the ring.
        canvas.drawLine(
          _point(centre, tickRadius, body.longitude),
          _point(centre, tickRadius - radius * 0.045, body.longitude),
          Paint()
            ..strokeWidth = 1.2
            ..color = grahaColors[body.name] ?? inkSoft,
        );

        final at = _point(centre, r, body.longitude);
        final colour = grahaColors[body.name] ?? inkSoft;

        // A disc behind the label, so a glyph crossing an aspect line stays
        // legible.
        canvas.drawCircle(
          at,
          fontSize * 0.95,
          Paint()..color = paper.withValues(alpha: outerRing ? 0.85 : 0.95),
        );

        _text(
          canvas,
          at,
          wheelAbbreviations[body.name] ?? body.name.substring(0, 2),
          TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: colour,
          ),
        );

        if (body.retrograde) {
          _text(
            canvas,
            Offset(at.dx + fontSize * 1.05, at.dy + fontSize * 0.55),
            '℞',
            TextStyle(fontSize: fontSize * 0.8, color: colour),
          );
        }
      }
    }
  }

  void _paintAngles(
      Canvas canvas, Offset centre, double outer, double inner) {
    for (final (longitude, label) in [
      (cusps.ascendant, 'ASC'),
      (cusps.midheaven, 'MC'),
      (cusps.descendant, 'DSC'),
      (cusps.ic, 'IC'),
    ]) {
      _text(
        canvas,
        _point(centre, outer * 0.955, longitude),
        label,
        TextStyle(
          fontSize: outer * 0.038,
          fontWeight: FontWeight.w700,
          color: navy,
        ),
      );
    }
  }

  void _text(Canvas canvas, Offset at, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(
      canvas,
      Offset(at.dx - painter.width / 2, at.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) =>
      old.bodies != bodies ||
      old.outerBodies != outerBodies ||
      old.cusps != cusps ||
      old.aspects != aspects ||
      old.sidereal != sidereal;
}

/// A compact legend for the wheel, because colour alone is not an encoding.
class WheelLegend extends StatelessWidget {
  const WheelLegend({super.key, required this.bodies, this.outerLabel});

  final List<WheelBody> bodies;
  final String? outerLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Gap.md,
      runSpacing: Gap.sm,
      children: [
        for (final b in bodies)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: grahaColors[b.name] ?? inkSoft,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Gap.xs),
              Text(
                '${wheelAbbreviations[b.name] ?? b.name} '
                '${formatDms(b.longitude)} '
                '${_signGlyphs[signIndex(b.longitude)]}'
                '${b.retrograde ? ' ℞' : ''}',
                style: Type.micro.copyWith(color: inkSoft),
              ),
            ],
          ),
      ],
    );
  }
}

/// The Western wheel.
///
/// The Vedic kundali moved to `kundali.dart`, which draws both the North and
/// South Indian traditions from one interactive model. This file keeps the
/// tropical wheel, which is a different projection and stays its own widget.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../theme/tokens.dart';

class WesternWheel extends StatelessWidget {
  const WesternWheel({super.key, required this.chart, this.size = 280});

  final NatalChart chart;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _WheelPainter(chart: chart),
      // A wheel is decorative here; the same positions are listed in the table
      // beside it, which is what a screen reader should read.
      isComplex: true,
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.chart});

  final NatalChart chart;

  /// Bodies drawn on the wheel. The lunar nodes belong to the Vedic chart and
  /// are left off the tropical one.
  static const _bodies = [
    'Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    final ring = Paint()
      ..color = hairline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(centre, r, ring);
    canvas.drawCircle(centre, r * 0.72, ring);

    // House cusps, counted from the ascendant so the 1st opens on the left.
    for (var i = 0; i < 12; i++) {
      final a = _angleFor(i * 30.0);
      canvas.drawLine(
        centre + Offset(math.cos(a), math.sin(a)) * (r * 0.72),
        centre + Offset(math.cos(a), math.sin(a)) * r,
        ring,
      );
    }

    for (final name in _bodies) {
      final row = chart.grahas.where((g) => g.name == name).firstOrNull;
      if (row == null) continue;
      final a = _angleFor(row.tropicalLon);
      final at = centre + Offset(math.cos(a), math.sin(a)) * (r * 0.55);
      canvas.drawCircle(at, 3.5, Paint()..color = grahaColor(name));
      final label = TextPainter(
        text: TextSpan(
          text: shortName(name),
          style: Type.micro.copyWith(color: grahaColor(name)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, at + const Offset(5, -5));
    }
  }

  /// Zero degrees sits on the ascendant, and the zodiac runs anticlockwise.
  double _angleFor(double tropicalLon) =>
      (180 - (tropicalLon - chart.lagnaTropical)) * math.pi / 180;

  @override
  bool shouldRepaint(covariant _WheelPainter old) => old.chart != chart;
}

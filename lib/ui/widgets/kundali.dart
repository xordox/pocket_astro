/// The kundali: one widget, two traditional layouts, fully interactive.
///
/// North Indian holds the *houses* still and rotates the signs; South Indian
/// holds the *signs* still and marks the rising sign. Both are drawn from the
/// same cell model, so tapping, tinting and aspect lines work identically in
/// either.
///
/// Three things are encoded visually, and each is also stated in words
/// somewhere on screen, because colour alone is not an accessible encoding:
///
/// * the **fill** of a house is how the chart supports that area of life;
/// * the **colour of a graha** is whether it acts as a benefic or a malefic;
/// * when a graha is selected, **lines** run to every house it aspects.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../engine/house_quality.dart';
import '../../engine/nature.dart';
import '../../engine/tables.dart';
import '../../theme/tokens.dart';

enum KundaliStyle { north, south }

extension KundaliStyleLabel on KundaliStyle {
  String get label =>
      this == KundaliStyle.north ? 'North Indian' : 'South Indian';

  String get hint => this == KundaliStyle.north
      ? 'Houses stay in place; the signs move with your rising sign.'
      : 'Signs stay in place; your rising sign is marked “Asc”.';
}

/// One drawable cell of the chart.
class KundaliCell {
  const KundaliCell({
    required this.house,
    required this.sign,
    required this.path,
    required this.center,
    required this.labelAnchor,
  });

  final int house;
  final int sign;
  final Path path;
  final Offset center;

  /// Where the small sign or house number is written.
  final Offset labelAnchor;
}

// ---------------------------------------------------------------------------
// Geometry
// ---------------------------------------------------------------------------

/// North Indian: a square with both diagonals and the mid-point rhombus.
///
/// House 1 is the top-centre diamond and the numbers run anticlockwise, which
/// is the convention every printed North Indian kundali uses.
List<KundaliCell> _northCells(Size size, int lagnaSign) {
  final w = size.width, h = size.height;
  Offset p(double x, double y) => Offset(x * w, y * h);

  final tl = p(0, 0), tr = p(1, 0), br = p(1, 1), bl = p(0, 1);
  final t = p(0.5, 0), r = p(1, 0.5), b = p(0.5, 1), l = p(0, 0.5);
  final c = p(0.5, 0.5);
  // Where the diagonals cross the rhombus.
  final q1 = p(0.25, 0.25); // between L and T
  final q2 = p(0.75, 0.75); // between R and B
  final q3 = p(0.75, 0.25); // between T and R
  final q4 = p(0.25, 0.75); // between B and L

  Path poly(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    return path..close();
  }

  Offset mid(List<Offset> pts) {
    var x = 0.0, y = 0.0;
    for (final o in pts) {
      x += o.dx;
      y += o.dy;
    }
    return Offset(x / pts.length, y / pts.length);
  }

  // house -> polygon, running anticlockwise from the top-centre diamond.
  final shapes = <int, List<Offset>>{
    1: [t, q3, c, q1],
    2: [tl, t, q1],
    3: [tl, q1, l],
    4: [l, q1, c, q4],
    5: [bl, l, q4],
    6: [bl, q4, b],
    7: [b, q4, c, q2],
    8: [br, b, q2],
    9: [br, q2, r],
    10: [r, q2, c, q3],
    11: [tr, r, q3],
    12: [tr, q3, t],
  };

  return [
    for (final e in shapes.entries)
      KundaliCell(
        house: e.key,
        sign: (lagnaSign + e.key - 1) % 12,
        path: poly(e.value),
        center: mid(e.value),
        labelAnchor: mid(e.value),
      ),
  ];
}

/// South Indian: a fixed 4×4 ring with Aries second along the top row.
List<KundaliCell> _southCells(Size size, int lagnaSign) {
  const grid = <List<int?>>[
    [11, 0, 1, 2],
    [10, null, null, 3],
    [9, null, null, 4],
    [8, 7, 6, 5],
  ];
  final cw = size.width / 4, ch = size.height / 4;
  final out = <KundaliCell>[];
  for (var row = 0; row < 4; row++) {
    for (var col = 0; col < 4; col++) {
      final sign = grid[row][col];
      if (sign == null) continue;
      final rect = Rect.fromLTWH(col * cw, row * ch, cw, ch);
      out.add(
        KundaliCell(
          house: ((sign - lagnaSign) % 12) + 1,
          sign: sign,
          path: Path()..addRect(rect),
          center: rect.center,
          labelAnchor: rect.center,
        ),
      );
    }
  }
  return out;
}

List<KundaliCell> kundaliCells(Size size, KundaliStyle style, int lagnaSign) =>
    style == KundaliStyle.north
        ? _northCells(size, lagnaSign)
        : _southCells(size, lagnaSign);

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class KundaliChart extends StatelessWidget {
  const KundaliChart({
    super.key,
    required this.chart,
    required this.style,
    required this.readings,
    this.selectedPlanet,
    this.selectedHouse,
    this.onPlanetTap,
    this.onHouseTap,
    this.showQuality = true,
  });

  final NatalChart chart;
  final KundaliStyle style;

  /// House quality, empty when there is no birth time.
  final List<HouseReading> readings;

  final String? selectedPlanet;
  final int? selectedHouse;
  final ValueChanged<String>? onPlanetTap;
  final ValueChanged<int>? onHouseTap;

  /// When false the houses are drawn plain, for users who prefer no tinting.
  final bool showQuality;

  @override
  Widget build(BuildContext context) {
    final lagnaSign = chart.input.timeUnknown
        ? signIndex(chart.graha('Moon').siderealLon)
        : signIndex(chart.lagnaSidereal);

    final nature = GrahaNature({
      for (final g in chart.grahas)
        if (navagraha.contains(g.name)) g.name: g.siderealLon,
    });

    final bySign = <int, List<GrahaRow>>{};
    for (final g in chart.grahas) {
      if (g.name == 'Lagna' || !navagraha.contains(g.name)) continue;
      bySign.putIfAbsent(signIndex(g.siderealLon), () => []).add(g);
    }

    final highlighted = selectedPlanet == null
        ? const <int>{}
        : aspectedHouses(chart, selectedPlanet!).toSet();

    final planetHouse = selectedPlanet == null
        ? null
        : chart.grahas
            .where((g) => g.name == selectedPlanet)
            .map((g) => g.house)
            .firstOrNull;

    final bands = {for (final r in readings) r.house: r.band};

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, 360.0);
        final size = Size.square(side);
        final cells = kundaliCells(size, style, lagnaSign);

        return SizedBox(
          width: side,
          height: side,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final p = details.localPosition;
              for (final cell in cells) {
                if (!cell.path.contains(p)) continue;
                final here = bySign[cell.sign] ?? const [];
                // A tap on a cell holding exactly one graha selects the graha,
                // which is what a reader almost always means. Otherwise it
                // opens the house.
                if (here.length == 1 && onPlanetTap != null) {
                  onPlanetTap!(here.single.name);
                } else {
                  onHouseTap?.call(cell.house);
                }
                return;
              }
            },
            child: CustomPaint(
              size: size,
              painter: _KundaliPainter(
                cells: cells,
                bySign: bySign,
                nature: nature,
                bands: showQuality ? bands : const {},
                lagnaSign: lagnaSign,
                style: style,
                selectedPlanet: selectedPlanet,
                selectedHouse: selectedHouse,
                highlighted: highlighted,
                sourceHouse: planetHouse,
                noBirthTime: chart.input.timeUnknown,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KundaliPainter extends CustomPainter {
  _KundaliPainter({
    required this.cells,
    required this.bySign,
    required this.nature,
    required this.bands,
    required this.lagnaSign,
    required this.style,
    required this.selectedPlanet,
    required this.selectedHouse,
    required this.highlighted,
    required this.sourceHouse,
    required this.noBirthTime,
  });

  final List<KundaliCell> cells;
  final Map<int, List<GrahaRow>> bySign;
  final GrahaNature nature;
  final Map<int, HouseBand> bands;
  final int lagnaSign;
  final KundaliStyle style;
  final String? selectedPlanet;
  final int? selectedHouse;
  final Set<int> highlighted;
  final int? sourceHouse;
  final bool noBirthTime;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Paint()
      ..color = hairline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = paperRaised,
    );

    for (final cell in cells) {
      _paintCellFill(canvas, cell);
    }

    // Aspect lines sit under the glyphs so they never obscure a label.
    if (selectedPlanet != null && sourceHouse != null && sourceHouse! > 0) {
      _paintAspectLines(canvas);
    }

    for (final cell in cells) {
      canvas.drawPath(cell.path, frame);
    }
    if (style == KundaliStyle.south) {
      final cw = size.width / 4;
      canvas.drawRect(Rect.fromLTWH(cw, cw, cw * 2, cw * 2), frame);
    }

    for (final cell in cells) {
      _paintCellContents(canvas, cell, size);
    }
  }

  void _paintCellFill(Canvas canvas, KundaliCell cell) {
    final band = bands[cell.house];
    var fill = switch (band) {
      HouseBand.prosperous => prosperousTint,
      HouseBand.strained => strainedTint,
      HouseBand.steady => steadyTint,
      null => paperRaised,
    };
    if (highlighted.contains(cell.house)) {
      fill = Color.alphaBlend(gold.withValues(alpha: 0.28), fill);
    }
    canvas.drawPath(cell.path, Paint()..color = fill);

    final isSelected = selectedHouse == cell.house ||
        (sourceHouse != null && sourceHouse == cell.house);
    if (isSelected) {
      canvas.drawPath(
        cell.path,
        Paint()
          ..color = navy
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    }
  }

  void _paintAspectLines(Canvas canvas) {
    final from = cells.where((c) => c.house == sourceHouse).firstOrNull;
    if (from == null) return;
    final stroke = Paint()
      ..color = grahaColor(selectedPlanet!).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    for (final house in highlighted) {
      final to = cells.where((c) => c.house == house).firstOrNull;
      if (to == null) continue;
      // A gentle arc reads as a glance across the chart; a straight line reads
      // as a wall through the middle of it.
      final mid = Offset(
        (from.center.dx + to.center.dx) / 2,
        (from.center.dy + to.center.dy) / 2,
      );
      final normal = Offset(
        -(to.center.dy - from.center.dy),
        to.center.dx - from.center.dx,
      );
      final len = normal.distance;
      final control = len == 0
          ? mid
          : mid + (normal / len) * (len * 0.06);
      final path = Path()
        ..moveTo(from.center.dx, from.center.dy)
        ..quadraticBezierTo(control.dx, control.dy, to.center.dx, to.center.dy);
      canvas.drawPath(path, stroke);
      canvas.drawCircle(
        to.center,
        3.2,
        Paint()..color = grahaColor(selectedPlanet!),
      );
    }
  }

  void _paintCellContents(Canvas canvas, KundaliCell cell, Size size) {
    final compact = size.width < 300;

    // Corner label: the sign in a North chart (it moves), the house number in
    // a South chart (it moves). Whichever is not fixed is the one worth
    // printing.
    final label = style == KundaliStyle.north
        ? '${cell.sign + 1}'
        : signs[cell.sign].sanskrit;
    final labelPainter = TextPainter(
      text: TextSpan(text: label, style: Type.micro),
      textDirection: TextDirection.ltr,
    )..layout();

    final anchorY = style == KundaliStyle.north
        ? cell.labelAnchor.dy - 22
        : cell.labelAnchor.dy - 26;
    labelPainter.paint(
      canvas,
      Offset(cell.labelAnchor.dx - labelPainter.width / 2, anchorY),
    );

    // The rising sign is called out by name, not only by a tint.
    if (cell.sign == lagnaSign && !noBirthTime) {
      final asc = TextPainter(
        text: TextSpan(
          text: 'Asc',
          style: Type.micro.copyWith(
            color: navy,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      asc.paint(
        canvas,
        Offset(cell.labelAnchor.dx - asc.width / 2, anchorY + 11),
      );
    }

    final here = bySign[cell.sign] ?? const [];
    if (here.isEmpty) return;

    // Two glyphs per row keeps a corner triangle legible.
    const perRow = 2;
    final rows = (here.length / perRow).ceil();
    final rowHeight = compact ? 13.0 : 15.0;
    var y = cell.center.dy - (rows - 1) * rowHeight / 2 - 1;

    for (var i = 0; i < here.length; i += perRow) {
      final slice = here.skip(i).take(perRow).toList();
      final painters = <TextPainter>[];
      for (final g in slice) {
        final selected = g.name == selectedPlanet;
        final benefic = nature.isBenefic(g.name);
        painters.add(
          TextPainter(
            text: TextSpan(
              text: shortName(g.name),
              style: Type.glyph.copyWith(
                color: selected
                    ? Colors.white
                    : (benefic ? beneficColor : maleficColor),
                fontSize: compact ? 10.5 : 11.5,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(),
        );
      }
      final totalWidth =
          painters.fold<double>(0, (a, p) => a + p.width) + (slice.length - 1) * 6;
      var x = cell.center.dx - totalWidth / 2;
      for (var k = 0; k < slice.length; k++) {
        final p = painters[k];
        if (slice[k].name == selectedPlanet) {
          final r = RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 3, y - 1.5, p.width + 6, p.height + 3),
            const Radius.circular(4),
          );
          canvas.drawRRect(r, Paint()..color = grahaColor(slice[k].name));
        }
        p.paint(canvas, Offset(x, y));
        x += p.width + 6;
      }
      y += rowHeight;
    }
  }

  @override
  bool shouldRepaint(covariant _KundaliPainter old) =>
      old.selectedPlanet != selectedPlanet ||
      old.selectedHouse != selectedHouse ||
      old.highlighted.length != highlighted.length ||
      old.style != style ||
      old.bands.length != bands.length ||
      old.lagnaSign != lagnaSign;
}

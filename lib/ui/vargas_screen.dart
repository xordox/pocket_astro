/// The divisional charts.
///
/// Gap G-10's user-facing half. Sixteen charts is a lot to put on a phone, so
/// the screen is built around one decision: *which question are you asking?*
/// The vargas are listed by what they are consulted for — marriage, children,
/// career, property — rather than by D-number, because "D7" means nothing to
/// anyone who does not already know, and the people who do know can read the
/// number in the same row.
library;

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../engine/tables.dart';
import '../engine/vargas.dart';
import '../theme/tokens.dart';
import 'widgets/atoms.dart';

class VargasScreen extends StatefulWidget {
  const VargasScreen({super.key, required this.chart});
  final NatalChart chart;

  @override
  State<VargasScreen> createState() => _VargasScreenState();
}

class _VargasScreenState extends State<VargasScreen> {
  late final Map<int, VargaChart> vargas = buildAllVargas(widget.chart);
  int selected = 9;
  VargaGroup group = shodashavargaGroup;

  @override
  Widget build(BuildContext context) {
    final chart = vargas[selected]!;
    final vargottama = vargottamaIn(widget.chart, vargas);

    return Scaffold(
      appBar: AppBar(title: const Text('Divisional charts')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
        children: [
          const QuietNote(
            'A jyotishi does not read marriage from the rashi chart. Marriage '
            'comes from the navamsa, children from the saptamsa, career from '
            'the dashamsa — and the final word on a graha’s strength from the '
            'shashtiamsa. Pick the question, not the number.',
            icon: Icons.grid_view_rounded,
          ),
          const SizedBox(height: Gap.lg),
          _VargaPicker(
            selected: selected,
            onSelect: (d) => setState(() => selected = d),
          ),
          const SizedBox(height: Gap.lg),
          _VargaHeader(def: chart.def),
          const SizedBox(height: Gap.md),
          VargaGrid(chart: chart, rashiSigns: _rashiSigns()),
          const SizedBox(height: Gap.lg),
          _PlacementTable(chart: chart, rashiSigns: _rashiSigns()),
          if (vargottama.isNotEmpty) ...[
            const SizedBox(height: Gap.lg),
            _VargottamaCard(names: vargottama),
          ],
          const SizedBox(height: Gap.xl),
          _VimshopakaSection(
            vargas: vargas,
            group: group,
            onGroup: (g) => setState(() => group = g),
          ),
        ],
      ),
    );
  }

  Map<String, int> _rashiSigns() => {
        for (final g in widget.chart.grahas)
          if (g.name != 'Lagna') g.name: signIndex(g.siderealLon),
      };
}

// ---------------------------------------------------------------------------

class _VargaPicker extends StatelessWidget {
  const _VargaPicker({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final v in shodashavarga)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.xs),
            child: Material(
              color: selected == v.division
                  ? navy.withValues(alpha: 0.07)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.chip),
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.chip),
                onTap: () => onSelect(v.division),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Gap.md, vertical: Gap.sm),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(
                          v.label,
                          style: Type.body.copyWith(
                            fontWeight: selected == v.division
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected == v.division ? navy : inkSoft,
                          ),
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.name, style: Type.body),
                            Text(v.signifies, style: Type.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _VargaHeader extends StatelessWidget {
  const _VargaHeader({required this.def});
  final VargaDef def;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${def.label} · ${def.name}', style: Type.display),
              const SizedBox(height: 2),
              Text(
                'Read for ${def.signifies}.',
                style: Type.bodySoft,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The grid
// ---------------------------------------------------------------------------

/// A South-Indian style varga grid.
///
/// Fixed signs in a 4×4 ring with Aries second along the top, which is the
/// layout every printed South Indian chart uses — so a reader who knows the
/// form can find a sign without reading its name.
class VargaGrid extends StatelessWidget {
  const VargaGrid({
    super.key,
    required this.chart,
    required this.rashiSigns,
  });

  final VargaChart chart;

  /// Rashi sign of each graha, so vargottama can be marked in place.
  final Map<String, int> rashiSigns;

  /// Sign index at each cell of the 4×4 ring, clockwise from Pisces.
  static const _layout = [
    11, 0, 1, 2,
    10, -1, -1, 3,
    9, -1, -1, 4,
    8, 7, 6, 5,
  ];

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
        ),
        itemCount: 16,
        itemBuilder: (context, i) {
          final sign = _layout[i];
          if (sign < 0) return _centreCell(i);
          return _SignCell(
            sign: sign,
            chart: chart,
            rashiSigns: rashiSigns,
          );
        },
      ),
    );
  }

  Widget _centreCell(int i) {
    // The four middle cells carry the chart's own identity rather than being
    // left blank, which wastes a quarter of the drawing area.
    if (i != 5) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(Gap.sm),
      alignment: Alignment.center,
      child: FittedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(chart.def.label,
                style: Type.display.copyWith(color: inkFaint)),
            Text(chart.def.name, style: Type.caption),
            const SizedBox(height: Gap.xs),
            Text('Lagna ${signs[chart.lagnaSign].sanskrit}',
                style: Type.micro),
          ],
        ),
      ),
    );
  }
}

class _SignCell extends StatelessWidget {
  const _SignCell({
    required this.sign,
    required this.chart,
    required this.rashiSigns,
  });
  final int sign;
  final VargaChart chart;
  final Map<String, int> rashiSigns;

  @override
  Widget build(BuildContext context) {
    final here = chart.inSign(sign);
    final isLagna = chart.lagnaSign == sign;
    final house = ((sign - chart.lagnaSign) % 12 + 12) % 12 + 1;

    return Container(
      margin: const EdgeInsets.all(1),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isLagna ? navy.withValues(alpha: 0.06) : paperRaised,
        border: Border.all(
          color: isLagna ? navy.withValues(alpha: 0.5) : hairline,
          width: isLagna ? 1.4 : 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(signs[sign].sanskrit.substring(0, 3),
                  style: Type.micro.copyWith(color: inkFaint)),
              const Spacer(),
              if (isLagna)
                Text('Asc',
                    style: Type.micro.copyWith(
                        color: navy, fontWeight: FontWeight.w700))
              else
                Text('$house', style: Type.micro),
            ],
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Wrap(
              spacing: 3,
              runSpacing: 1,
              children: [
                for (final p in here) _PlanetChip(p: p, rashiSigns: rashiSigns),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanetChip extends StatelessWidget {
  const _PlanetChip({required this.p, required this.rashiSigns});
  final VargaPlacement p;
  final Map<String, int> rashiSigns;

  @override
  Widget build(BuildContext context) {
    final vargottama = rashiSigns[p.name] == p.sign;
    final colour = grahaColors[p.name] ?? inkSoft;
    return Text(
      '${p.name.substring(0, 2)}'
      '${p.retrograde ? '℞' : ''}'
      '${p.dignity == 'exalted' ? '↑' : p.dignity == 'debilitated' ? '↓' : ''}'
      '${vargottama ? '*' : ''}',
      style: Type.glyph.copyWith(
        color: colour,
        decoration: vargottama ? TextDecoration.underline : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PlacementTable extends StatelessWidget {
  const _PlacementTable({required this.chart, required this.rashiSigns});
  final VargaChart chart;
  final Map<String, int> rashiSigns;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 78, child: Text('Graha', style: Type.micro)),
                const Expanded(child: Text('Sign', style: Type.micro)),
                const SizedBox(width: 44, child: Text('House', style: Type.micro)),
                SizedBox(width: 82, child: Text('Dignity', style: Type.micro)),
              ],
            ),
            const Divider(height: Gap.md, color: hairline),
            for (final p in chart.placements)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 78,
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: grahaColors[p.name] ?? inkSoft,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: Gap.xs),
                          // Graha names are localised and Nepali and Hindi run
                          // longer than English, so the cell clips rather than
                          // overflowing the row.
                          Expanded(
                            child: Text(
                              grahaName(p.name),
                              style: Type.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              signName(p.sign),
                              style: Type.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (rashiSigns[p.name] == p.sign) ...[
                            const SizedBox(width: Gap.xs),
                            Text('vargottama',
                                style: Type.micro.copyWith(color: beneficColor)),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: 44, child: Text('${p.house}', style: Type.body)),
                    SizedBox(
                      width: 82,
                      child: Text(
                        p.dignity.isEmpty ? '—' : p.dignity,
                        style: Type.caption.copyWith(
                          color: p.dignity == 'exalted'
                              ? beneficColor
                              : p.dignity == 'debilitated'
                                  ? maleficColor
                                  : inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VargottamaCard extends StatelessWidget {
  const _VargottamaCard({required this.names});
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: beneficTint,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vargottama',
              style: Type.title.copyWith(color: beneficColor)),
          const SizedBox(height: Gap.xs),
          Text(
            '${names.map(grahaName).join(', ')} '
            '${names.length == 1 ? 'holds' : 'hold'} the same sign in the rashi '
            'chart and the navamsa. It is the cheapest strong signal in the '
            'whole system: whatever that graha promises, it keeps.',
            style: Type.bodySoft,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vimshopaka
// ---------------------------------------------------------------------------

class _VimshopakaSection extends StatelessWidget {
  const _VimshopakaSection({
    required this.vargas,
    required this.group,
    required this.onGroup,
  });
  final Map<int, VargaChart> vargas;
  final VargaGroup group;
  final ValueChanged<VargaGroup> onGroup;

  @override
  Widget build(BuildContext context) {
    final table = vimshopakaTable(vargas, group: group)
      ..sort((a, b) => b.score.compareTo(a.score));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          'Vimshopaka bala',
          subtitle: 'Strength weighted across the divisions, out of twenty. '
              'This is how to choose between two well-placed grahas: the one '
              'that keeps its dignity down through the vargas is the one whose '
              'dasha pays.',
        ),
        Wrap(
          spacing: Gap.sm,
          children: [
            for (final g in vargaGroups)
              ChoiceChip(
                label: Text('${g.name} (${g.divisions.length})'),
                selected: group == g,
                onSelected: (_) => onGroup(g),
              ),
          ],
        ),
        const SizedBox(height: Gap.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              children: [
                for (final row in table) _VimshopakaRow(row: row),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VimshopakaRow extends StatelessWidget {
  const _VimshopakaRow({required this.row});
  final Vimshopaka row;

  @override
  Widget build(BuildContext context) {
    final fraction = (row.score / 20).clamp(0.0, 1.0);
    final colour = fraction >= 0.65
        ? beneficColor
        : fraction >= 0.35
            ? steadyColor
            : maleficColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 74, child: Text(grahaName(row.planet), style: Type.body)),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 7,
                    backgroundColor: neutralTint,
                    valueColor: AlwaysStoppedAnimation(colour),
                  ),
                ),
              ),
              const SizedBox(width: Gap.sm),
              SizedBox(
                width: 42,
                child: Text(
                  row.score.toStringAsFixed(1),
                  textAlign: TextAlign.right,
                  style: Type.caption.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 74, top: 2),
            child: Text(
              row.positionName.isEmpty
                  ? row.verdict
                  : '${row.positionName} — dignified in ${row.dignifiedIn} '
                      'varga${row.dignifiedIn == 1 ? '' : 's'}. ${row.verdict}',
              style: Type.micro,
            ),
          ),
        ],
      ),
    );
  }
}

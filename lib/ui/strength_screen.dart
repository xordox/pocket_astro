/// Planetary strength.
///
/// Gaps G-12, G-11, G-15 and G-22 in one screen, because they answer one
/// question: which graha in this chart actually delivers?
///
/// The design problem is that shadbala is six numbers summed from twenty
/// components, and a table of twenty numbers tells a reader nothing. So the
/// screen leads with the verdict — does this graha clear its own classical
/// minimum, yes or no — and folds the arithmetic away underneath for anyone
/// who wants to check it.
library;

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../engine/ashtakavarga.dart';
import '../engine/ashtakavarga_reduction.dart';
import '../engine/dignity.dart';
import '../engine/shadbala.dart';
import '../engine/tables.dart';
import '../theme/tokens.dart';
import 'widgets/atoms.dart';

class StrengthScreen extends StatelessWidget {
  const StrengthScreen({super.key, required this.chart});
  final NatalChart chart;

  @override
  Widget build(BuildContext context) {
    final report = shadbalaFor(chart);
    final avasthas = avasthasFor(chart.grahas);
    final av = ashtakavargaFor(chart);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Strength'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Shadbala'),
              Tab(text: 'Avastha'),
              Tab(text: 'Bhava bala'),
              Tab(text: 'Ashtakavarga'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ShadbalaTab(report: report, chart: chart),
            _AvasthaTab(avasthas: avasthas, chart: chart),
            _BhavaTab(report: report),
            _ReductionTab(av: av),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shadbala
// ---------------------------------------------------------------------------

class _ShadbalaTab extends StatelessWidget {
  const _ShadbalaTab({required this.report, required this.chart});
  final ShadbalaReport report;
  final NatalChart chart;

  @override
  Widget build(BuildContext context) {
    final ranked = report.ranked;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
      children: [
        _Headline(report: report),
        const SizedBox(height: Gap.lg),
        for (final p in ranked) ...[
          _ShadbalaCard(bala: p, chart: chart),
          const SizedBox(height: Gap.sm),
        ],
        const SizedBox(height: Gap.md),
        const QuietNote(
          'Strength is measured in virupas, sixty to the rupa. Each graha has '
          'its own minimum — Mercury needs seven rupas, the Sun only five — so '
          'the bar shows the ratio to that minimum rather than a raw total. A '
          'graha below its own line promises more than it pays, however good '
          'its placement looks.',
          icon: Icons.straighten,
        ),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.report});
  final ShadbalaReport report;

  @override
  Widget build(BuildContext context) {
    final failing = report.planets.where((p) => !p.meetsMinimum).toList();
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: paperRaised,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${grahaName(report.strongest)} is the strongest graha here',
              style: Type.title),
          const SizedBox(height: Gap.xs),
          Text(
            'Its dasha is the window to plan around. '
            '${grahaName(report.weakest)} carries the least strength.',
            style: Type.bodySoft,
          ),
          if (failing.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            Text(
              '${failing.map((f) => grahaName(f.planet)).join(', ')} '
              '${failing.length == 1 ? 'falls' : 'fall'} below the classical '
              'minimum. Be careful about what you promise from '
              '${failing.length == 1 ? 'it' : 'them'}.',
              style: Type.caption.copyWith(color: strainedColor),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShadbalaCard extends StatelessWidget {
  const _ShadbalaCard({required this.bala, required this.chart});
  final BalaBreakdown bala;
  final NatalChart chart;

  @override
  Widget build(BuildContext context) {
    final ratio = bala.ratio.clamp(0.0, 2.0) / 2.0;
    final colour = bala.meetsMinimum ? beneficColor : strainedColor;
    final g = chart.grahas.where((x) => x.name == bala.planet).firstOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: grahaColors[bala.planet] ?? inkSoft,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(grahaName(bala.planet), style: Type.title),
                ),
                Text(
                  '${bala.totalRupa.toStringAsFixed(2)} rupas',
                  style: Type.caption.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 9,
                    backgroundColor: neutralTint,
                    valueColor: AlwaysStoppedAnimation(colour),
                  ),
                ),
                // The minimum line, at the halfway mark of a 0–2× scale.
                Positioned(
                  left: 0,
                  right: 0,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 9,
                      alignment: Alignment.centerRight,
                      child: Container(width: 1.5, height: 9, color: ink),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.xs),
            Row(
              children: [
                Text(bala.verdict,
                    style: Type.caption.copyWith(
                        color: colour, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('needs ${bala.required.toStringAsFixed(1)}',
                    style: Type.micro),
              ],
            ),
            if (g != null && g.showsMotionMarker) ...[
              const SizedBox(height: Gap.xs),
              Text(
                'Retrograde — ${cheshtaMeaning[cheshtaState(bala.planet, g.speed)]}. '
                'That is why its cheshta bala is high.',
                style: Type.micro.copyWith(color: inkSoft),
              ),
            ],
            const SizedBox(height: Gap.sm),
            DisclosurePanel(
              title: 'The six strengths',
              children: [
                _BalaRow('Sthana — position', bala.sthana, [
                  ('uchcha (exaltation)', bala.uchcha),
                  ('saptavargaja', bala.saptavargaja),
                  ('ojhayugma (odd/even)', bala.ojhayugma),
                  ('kendradi (angularity)', bala.kendradi),
                  ('drekkana', bala.drekkana),
                ]),
                _BalaRow('Dig — direction', bala.dig, const []),
                _BalaRow('Kala — time', bala.kala, [
                  ('nathonnatha (day/night)', bala.nathonnatha),
                  ('paksha (lunar phase)', bala.paksha),
                  ('tribhaga', bala.tribhaga),
                  ('vara (weekday lord)', bala.vara),
                  ('hora (hour lord)', bala.hora),
                  ('ayana (declination)', bala.ayana),
                  if (bala.yuddha != 0) ('yuddha (planetary war)', bala.yuddha),
                ]),
                _BalaRow('Cheshta — motion', bala.cheshta, const []),
                _BalaRow('Naisargika — natural', bala.naisargika, const []),
                _BalaRow('Drik — aspect', bala.drik, const []),
                const Divider(height: Gap.lg, color: hairline),
                Row(
                  children: [
                    Expanded(
                      child: Text('Ishta phala (benefit)', style: Type.caption),
                    ),
                    Text(bala.ishta.toStringAsFixed(1), style: Type.caption),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text('Kashta phala (difficulty)', style: Type.caption),
                    ),
                    Text(bala.kashta.toStringAsFixed(1), style: Type.caption),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BalaRow extends StatelessWidget {
  const _BalaRow(this.label, this.value, this.parts);
  final String label;
  final double value;
  final List<(String, double)> parts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(label,
                      style: Type.body.copyWith(fontWeight: FontWeight.w600))),
              Text(
                value.toStringAsFixed(1),
                style: Type.body.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          for (final p in parts)
            Padding(
              padding: const EdgeInsets.only(left: Gap.md, top: 1),
              child: Row(
                children: [
                  Expanded(child: Text(p.$1, style: Type.micro)),
                  Text(p.$2.toStringAsFixed(1), style: Type.micro),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avastha
// ---------------------------------------------------------------------------

class _AvasthaTab extends StatelessWidget {
  const _AvasthaTab({required this.avasthas, required this.chart});
  final List<AvasthaReport> avasthas;
  final NatalChart chart;

  @override
  Widget build(BuildContext context) {
    final wars = planetaryWars(chart.grahas);
    final combust = combustionsIn(chart.grahas);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
      children: [
        const QuietNote(
          'Avasthas are the qualifiers that stop a chart reading being a list '
          'of placements. A combust Mercury does not deliver what an uncombust '
          'one does, and a graha in mrita avastha gives nothing however well '
          'it is placed.',
          icon: Icons.local_fire_department_outlined,
        ),
        const SizedBox(height: Gap.lg),
        for (final a in avasthas) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: grahaColors[a.planet] ?? inkSoft,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      Text(grahaName(a.planet), style: Type.title),
                      const Spacer(),
                      if (a.combust) const _Flag('combust', maleficColor),
                      if (a.lostWar) const _Flag('lost war', maleficColor),
                      if (a.retrograde) const _Flag('vakri', neutralColor),
                    ],
                  ),
                  const SizedBox(height: Gap.sm),
                  _AvasthaLine('Baladi', a.baladi, baladiMeaning[a.baladi] ?? ''),
                  _AvasthaLine(
                      'Deeptadi', a.deeptadi, deeptadiMeaning[a.deeptadi] ?? ''),
                  _AvasthaLine('Jagradadi', a.jagradadi, switch (a.jagradadi) {
                    'jagrat' => 'awake — fully present in its results',
                    'swapna' => 'dreaming — its results come indirectly',
                    _ => 'asleep — barely operative',
                  }),
                  if (a.baladiPotency < 0.5) ...[
                    const SizedBox(height: Gap.xs),
                    Text(
                      'Only ${(a.baladiPotency * 100).round()}% of its results '
                      'come through at this degree.',
                      style: Type.caption.copyWith(color: strainedColor),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.sm),
        ],
        if (wars.isNotEmpty) ...[
          const SizedBox(height: Gap.md),
          const SectionHeader('Planetary war',
              subtitle: 'Two grahas within a degree. The one further north '
                  'wins, and the loser gives up most of what it promised.'),
          for (final w in wars)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Text(
                  '${grahaName(w.winner)} defeats ${grahaName(w.loser)} — they '
                  'stand ${w.separationDegrees.toStringAsFixed(2)}° apart and '
                  '${grahaName(w.winner)} holds the higher latitude.',
                  style: Type.body,
                ),
              ),
            ),
        ],
        if (combust.isNotEmpty) ...[
          const SizedBox(height: Gap.md),
          const SectionHeader('Combustion'),
          for (final c in combust)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Text(
                  c.deeplyCombust
                      ? '${grahaName(c.planet)} is within a degree of the Sun — '
                          'cazimi. The tradition reverses the judgment here and '
                          'calls it strengthened rather than burnt.'
                      : '${grahaName(c.planet)} is combust: '
                          '${c.distance.toStringAsFixed(1)}° from the Sun, '
                          'inside its ${c.orb.toStringAsFixed(0)}° orb.',
                  style: Type.body,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _AvasthaLine extends StatelessWidget {
  const _AvasthaLine(this.label, this.value, this.meaning);
  final String label;
  final String value;
  final String meaning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label, style: Type.micro)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Type.caption,
                children: [
                  TextSpan(
                      text: value,
                      style: Type.caption.copyWith(
                          fontWeight: FontWeight.w700, color: ink)),
                  if (meaning.isNotEmpty) TextSpan(text: ' — $meaning'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag(this.label, this.colour);
  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: Gap.xs),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: Type.micro.copyWith(color: colour, fontWeight: FontWeight.w700)),
    );
  }
}

// ---------------------------------------------------------------------------
// Bhava bala
// ---------------------------------------------------------------------------

class _BhavaTab extends StatelessWidget {
  const _BhavaTab({required this.report});
  final ShadbalaReport report;

  @override
  Widget build(BuildContext context) {
    if (report.bhavas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(Gap.lg),
        child: QuietNote(
          'Bhava bala is measured from the houses, so it needs a birth time.',
        ),
      );
    }
    final maxTotal = report.bhavas
        .map((b) => b.total)
        .reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
      children: [
        const SectionHeader('Bhava bala',
            subtitle: 'How much each house can actually carry, from the '
                'strength of its lord, its own direction, and the aspects on '
                'it.'),
        for (final b in report.bhavas)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(ordinal(b.house), style: Type.body),
                    ),
                    Expanded(child: Text(houseTopic(b.house), style: Type.caption)),
                    Text(b.rupas.toStringAsFixed(2),
                        style: Type.caption.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: maxTotal <= 0 ? 0 : (b.total / maxTotal).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: neutralTint,
                    valueColor: AlwaysStoppedAnimation(
                      b.total >= maxTotal * 0.6 ? prosperousColor : steadyColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Ashtakavarga reductions
// ---------------------------------------------------------------------------

class _ReductionTab extends StatelessWidget {
  const _ReductionTab({required this.av});
  final AshtakavargaChart? av;

  @override
  Widget build(BuildContext context) {
    if (av == null) {
      return const Padding(
        padding: EdgeInsets.all(Gap.lg),
        child: QuietNote(
          'The lagna is one of the eight contributors to an ashtakavarga, so '
          'without a birth time the totals cannot reach 337 and every '
          'threshold in the technique becomes meaningless. Nothing is shown '
          'rather than a seven-eighths version that looks authoritative.',
        ),
      );
    }

    final report = sodhyaPindaFor(av!);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
      children: [
        for (final note in report.notes) ...[
          QuietNote(note, icon: Icons.filter_alt_outlined),
          const SizedBox(height: Gap.sm),
        ],
        const SizedBox(height: Gap.md),
        for (final row in report.rows) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(grahaName(row.planet), style: Type.title)),
                      Text('pinda ${row.sodhyaPinda}',
                          style: Type.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          )),
                    ],
                  ),
                  const SizedBox(height: Gap.sm),
                  _BinduRow('Raw', row.original),
                  _BinduRow('After trikona', row.afterTrikona),
                  _BinduRow('After ekadhipatya', row.afterEkadhipatya,
                      emphasise: true),
                  const SizedBox(height: Gap.xs),
                  Text(
                    '${row.originalTotal} bindus reduce to ${row.reducedTotal}. '
                    'Rashi pinda ${row.rashiPinda}, graha pinda '
                    '${row.grahaPinda}.',
                    style: Type.micro,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.sm),
        ],
      ],
    );
  }
}

class _BinduRow extends StatelessWidget {
  const _BinduRow(this.label, this.values, {this.emphasise = false});
  final String label;
  final List<int> values;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(width: 108, child: Text(label, style: Type.micro)),
          for (var i = 0; i < 12; i++)
            Expanded(
              child: Text(
                '${values[i]}',
                textAlign: TextAlign.center,
                style: Type.glyph.copyWith(
                  color: values[i] == 0
                      ? inkFaint
                      : emphasise
                          ? ink
                          : inkSoft,
                  fontWeight: emphasise ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

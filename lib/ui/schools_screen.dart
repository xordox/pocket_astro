/// Jaimini, the traditional Western layer, and the derived charts.
///
/// Gaps G-14, G-32, G-34 and G-23. These are grouped because they share a
/// shape: each is a whole *school* rather than another technique, with its own
/// vocabulary and its own answer to the same chart. The screen says so at the
/// top of each tab, because a reader who lands on "Atmakaraka" or "zodiacal
/// releasing" with no framing will bounce off it.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import '../engine/harmonics.dart';
import '../engine/hellenistic.dart';
import '../engine/jaimini.dart';
import '../engine/predictive.dart';
import '../engine/tables.dart';
import '../theme/tokens.dart';
import 'widgets/atoms.dart';

final _date = DateFormat('d MMM yyyy');

class SchoolsScreen extends StatelessWidget {
  const SchoolsScreen({super.key, required this.chart});
  final NatalChart chart;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Other schools'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Jaimini'),
              Tab(text: 'Traditional'),
              Tab(text: 'Time lords'),
              Tab(text: 'Derived charts'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _JaiminiTab(chart: chart),
            _TraditionalTab(chart: chart),
            _TimeLordTab(chart: chart),
            _DerivedTab(chart: chart),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Jaimini
// ---------------------------------------------------------------------------

class _JaiminiTab extends StatelessWidget {
  const _JaiminiTab({required this.chart});
  final NatalChart chart;

  @override
  Widget build(BuildContext context) {
    if (chart.input.timeUnknown) {
      return const Padding(
        padding: EdgeInsets.all(Gap.lg),
        child: QuietNote(
          'Jaimini is built on the lagna and the arudha padas, both of which '
          'need a birth time.',
        ),
      );
    }

    final report = jaiminiFor(chart);
    final dasha = report.charaDasha;
    final now = DateTime.now().toUtc();
    final current = dasha.at(now);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
      children: [
        const QuietNote(
          'Jaimini is a second school, not an extra technique. It ranks the '
          'grahas by degree rather than by house, reads images (arudha padas) '
          'alongside the things themselves, and times the life by sign rather '
          'than by planet.',
          icon: Icons.account_tree_outlined,
        ),
        const SizedBox(height: Gap.lg),
        const SectionHeader('Chara karakas',
            subtitle: 'Ranked by degrees within their sign, highest first.'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              children: [
                for (final k in report.karakas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: BoxDecoration(
                            color: grahaColors[k.planet] ?? inkSoft,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        SizedBox(
                          width: 78,
                          child: Text(grahaName(k.planet), style: Type.body),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(k.role,
                                  style: Type.body
                                      .copyWith(fontWeight: FontWeight.w700)),
                              Text(k.meaning, style: Type.caption),
                            ],
                          ),
                        ),
                        Text('${k.degrees.toStringAsFixed(2)}°',
                            style: Type.micro),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),
        const SectionHeader('Arudha padas',
            subtitle: 'The image of a house, as distinct from the house '
                'itself. How things look, not how they are.'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              children: [
                for (final p in report.padas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 42,
                          child: Text(p.label,
                              style: Type.body.copyWith(
                                fontWeight: p.label == 'AL' || p.label == 'UL'
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: p.label == 'AL' || p.label == 'UL'
                                    ? navy
                                    : ink,
                              )),
                        ),
                        SizedBox(
                          width: 88,
                          child: Text(signName(p.sign), style: Type.body),
                        ),
                        Expanded(child: Text(p.signifies, style: Type.caption)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (report.karakamsa != null) ...[
          const SizedBox(height: Gap.lg),
          _Callout(
            title: 'Karakamsa — ${signName(report.karakamsa!)}',
            body: 'The navamsa sign of the Atmakaraka, read as a lagna. What '
                'occupies and aspects it in the navamsa describes what this '
                'person is actually here to do.',
          ),
        ],
        const SizedBox(height: Gap.lg),
        SectionHeader(
          'Chara dasha',
          subtitle: 'Timed by sign rather than by graha, running '
              '${dasha.direct ? 'forward' : 'backward'} from '
              '${signName(dasha.startSign)} because the lagna is in an '
              '${dasha.direct ? 'odd' : 'even'}-footed sign.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              children: [
                for (final span in dasha.spans.take(12))
                  _CharaRow(span: span, isCurrent: span == current),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),
        for (final note in report.notes) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Text(note, style: Type.body),
            ),
          ),
          const SizedBox(height: Gap.sm),
        ],
      ],
    );
  }
}

class _CharaRow extends StatelessWidget {
  const _CharaRow({required this.span, required this.isCurrent});
  final CharaDashaSpan span;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 5),
      decoration: BoxDecoration(
        color: isCurrent ? navy.withValues(alpha: 0.07) : null,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              signName(span.sign),
              style: Type.body.copyWith(
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              '${_date.format(span.start.toLocal())} — '
              '${_date.format(span.end.toLocal())}',
              style: Type.caption,
            ),
          ),
          Text('${span.years}y', style: Type.micro),
          if (isCurrent) ...[
            const SizedBox(width: Gap.xs),
            const Icon(Icons.circle, size: 7, color: navy),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Traditional
// ---------------------------------------------------------------------------

class _TraditionalTab extends StatelessWidget {
  const _TraditionalTab({required this.chart});
  final NatalChart chart;

  @override
  Widget build(BuildContext context) {
    final report = traditionalFor(chart);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
      children: [
        _Callout(
          title: 'A ${report.sect.label} chart',
          body: report.sect.notes.take(2).join(' '),
          tone: report.sect.nightChart ? navy : gold,
        ),
        const SizedBox(height: Gap.lg),
        const SectionHeader('Essential dignity',
            subtitle: 'Rulership, exaltation, triplicity by sect, Egyptian '
                'bounds and Chaldean faces, scored the way Lilly scored them.'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              children: [
                for (final d in report.dignities)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 74,
                          child: Text(grahaName(d.planet), style: Type.body),
                        ),
                        SizedBox(
                          width: 38,
                          child: Text(
                            d.total > 0 ? '+${d.total}' : '${d.total}',
                            style: Type.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: d.total > 0
                                  ? beneficColor
                                  : d.total < 0
                                      ? maleficColor
                                      : inkSoft,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            d.reasons.isEmpty
                                ? 'no dignity here'
                                : d.reasons.join(', '),
                            style: Type.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.md),
        _Callout(
          title: 'Almuten figuris — ${grahaName(report.almutenFiguris)}',
          body: 'Scored across the lights, the ascendant and the Part of '
              'Fortune. The tradition calls this the lord of the nativity: '
              'the planet whose condition governs the chart as a whole.',
        ),
        const SizedBox(height: Gap.lg),
        const SectionHeader('The lots',
            subtitle: 'Every one of these reverses between a day chart and a '
                'night chart.'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              children: [
                for (final lot in report.lots)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 78,
                          child: Text(lot.name, style: Type.body),
                        ),
                        SizedBox(
                          width: 104,
                          child: Text(
                            '${formatDms(lot.longitude)} ${signName(lot.sign)}',
                            style: Type.caption,
                          ),
                        ),
                        Expanded(child: Text(lot.signifies, style: Type.caption)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Time lords
// ---------------------------------------------------------------------------

class _TimeLordTab extends StatelessWidget {
  const _TimeLordTab({required this.chart});
  final NatalChart chart;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final profection = annualProfection(chart, now);
    final zr = zodiacalReleasing(chart, from: 'Spirit');
    final fd = firdaria(chart);
    final zrNow = zr.l1At(now);
    final zr2Now = zr.l2At(now);
    final fdNow = firdariaAt(fd, now, 1);
    final fdSub = firdariaAt(fd, now, 2);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
      children: [
        const QuietNote(
          'Time lords are the Western equivalent of the dasha system: one '
          'planet or sign takes charge of a stretch of life, and its transits '
          'matter more than everything else put together while it does.',
          icon: Icons.schedule,
        ),
        const SizedBox(height: Gap.lg),
        _Callout(
          title: 'Profected year — the ${ordinal(profection.house)} house',
          body: profection.note,
          tone: navy,
        ),
        const SizedBox(height: Gap.lg),
        SectionHeader(
          'Zodiacal releasing from Spirit',
          subtitle: zrNow == null
              ? 'Released from the Lot of Spirit, which governs career and '
                  'deliberate action.'
              : 'Currently in a ${signName(zrNow.sign)} period'
                  '${zrNow.peak ? ' — a peak period.' : '.'}',
        ),
        if (zrNow != null)
          _Callout(
            title: '${signName(zrNow.sign)} · '
                '${_date.format(zrNow.start.toLocal())} — '
                '${_date.format(zrNow.end.toLocal())}',
            body: zrNow.peak
                ? 'This falls in the angular triad from the Lot of Fortune — '
                    'a peak period, where eminence and visible activity '
                    'concentrate.'
                : 'Ruled by ${grahaName(zrNow.lord)}. '
                    '${zr2Now == null ? '' : 'Inside it, a ${signName(zr2Now.sign)} sub-period runs to ${_date.format(zr2Now.end.toLocal())}.'}',
            tone: zrNow.peak ? gold : null,
          ),
        const SizedBox(height: Gap.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              children: [
                for (final p in zr.level1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 92,
                          child: Text(signName(p.sign),
                              style: Type.body.copyWith(
                                  fontWeight: p == zrNow
                                      ? FontWeight.w700
                                      : FontWeight.w500)),
                        ),
                        Expanded(
                          child: Text(
                            '${_date.format(p.start.toLocal())} — '
                            '${_date.format(p.end.toLocal())}',
                            style: Type.caption,
                          ),
                        ),
                        if (p.peak)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('peak',
                                style: Type.micro.copyWith(
                                    color: gold, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),
        SectionHeader(
          'Firdaria',
          subtitle: fdNow == null
              ? 'The Persian system: seventy-five years across nine lords.'
              : 'Currently ${grahaName(fdNow.lord)}'
                  '${fdSub == null ? '' : ' / ${grahaName(fdSub.lord)}'}.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              children: [
                for (final p in fd.where((x) => x.level == 1))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 92,
                          child: Text(grahaName(p.lord),
                              style: Type.body.copyWith(
                                  fontWeight: p == fdNow
                                      ? FontWeight.w700
                                      : FontWeight.w500)),
                        ),
                        Expanded(
                          child: Text(
                            '${_date.format(p.start.toLocal())} — '
                            '${_date.format(p.end.toLocal())}',
                            style: Type.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Derived charts
// ---------------------------------------------------------------------------

class _DerivedTab extends StatefulWidget {
  const _DerivedTab({required this.chart});
  final NatalChart chart;

  @override
  State<_DerivedTab> createState() => _DerivedTabState();
}

class _DerivedTabState extends State<_DerivedTab> {
  int harmonic = 5;

  @override
  Widget build(BuildContext context) {
    final h = harmonicChart(widget.chart, harmonic);
    final draconic = draconicChart(widget.chart);
    final sudarshana = sudarshanaChakra(widget.chart);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
      children: [
        const SectionHeader('Harmonic charts',
            subtitle: 'Multiply every longitude and a hidden symmetry becomes '
                'a conjunction.'),
        Wrap(
          spacing: Gap.sm,
          children: [
            for (final n in const [4, 5, 7, 9, 10, 11, 12])
              ChoiceChip(
                label: Text('H$n'),
                selected: harmonic == n,
                onSelected: (_) => setState(() => harmonic = n),
              ),
          ],
        ),
        const SizedBox(height: Gap.md),
        _DerivedCard(chart: h),
        const SizedBox(height: Gap.lg),
        const SectionHeader('Draconic'),
        _DerivedCard(chart: draconic),
        const SizedBox(height: Gap.lg),
        const SectionHeader('Sudarshana chakra',
            subtitle: 'The same placements read from the Lagna, the Moon and '
                'the Sun at once.'),
        if (sudarshana.agreements.isEmpty)
          const QuietNote(
            'No graha falls in the same house from all three references in '
            'this chart. That is common, and it means no single result is '
            'triply confirmed.',
          )
        else
          for (final a in sudarshana.agreements) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Text(a, style: Type.body),
              ),
            ),
            const SizedBox(height: Gap.sm),
          ],
      ],
    );
  }
}

class _DerivedCard extends StatelessWidget {
  const _DerivedCard({required this.chart});
  final DerivedChart chart;

  @override
  Widget build(BuildContext context) {
    final entries = chart.positions.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chart.title, style: Type.title),
            const SizedBox(height: 2),
            Text(chart.explanation, style: Type.caption),
            const Divider(height: Gap.lg, color: hairline),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text(grahaName(e.key), style: Type.body),
                    ),
                    Expanded(
                      child: Text(
                        '${formatDms(e.value)} ${signName(signIndex(e.value))}',
                        style: Type.caption,
                      ),
                    ),
                  ],
                ),
              ),
            if (chart.aspects.isNotEmpty) ...[
              const SizedBox(height: Gap.sm),
              Text(
                'Tightest contacts: '
                '${chart.aspects.take(3).map((a) => '${grahaName(a.a)} ${a.name} ${grahaName(a.b)}').join(', ')}.',
                style: Type.micro,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Callout extends StatelessWidget {
  const _Callout({required this.title, required this.body, this.tone});
  final String title;
  final String body;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final colour = tone ?? navy;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border(left: BorderSide(color: colour, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Type.title.copyWith(color: colour, fontSize: 15.5)),
          const SizedBox(height: Gap.xs),
          Text(body, style: Type.bodySoft),
        ],
      ),
    );
  }
}

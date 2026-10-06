/// Varshaphal — the annual chart.
///
/// Gap G-18's user-facing half. In Indian practice the annual chart is how a
/// year-ahead consultation is conducted, so the screen is organised the way
/// that conversation goes: which year, what is it about (the Muntha), who runs
/// it (the Varshesha), what completes and what has already slipped (Ithasala
/// and Ishrafa), and when inside the year (Mudda dasha).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import '../engine/tables.dart';
import '../engine/varshaphal.dart';
import '../theme/tokens.dart';
import 'widgets/atoms.dart';

final _date = DateFormat('d MMM yyyy');
final _stamp = DateFormat('d MMM yyyy, HH:mm');

class VarshaphalScreen extends StatefulWidget {
  const VarshaphalScreen({super.key, required this.chart});
  final NatalChart chart;

  @override
  State<VarshaphalScreen> createState() => _VarshaphalScreenState();
}

class _VarshaphalScreenState extends State<VarshaphalScreen> {
  late int year = DateTime.now().year;
  VarshaphalChart? annual;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final built = varshaphalFor(widget.chart, year);
    if (!mounted) return;
    setState(() {
      annual = built;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final thisYear = DateTime.now().year;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Varshaphal'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              children: [
                for (var y = thisYear - 3; y <= thisYear + 5; y++)
                  Padding(
                    padding: const EdgeInsets.only(right: Gap.sm),
                    child: ChoiceChip(
                      label: Text('$y'),
                      selected: year == y,
                      onSelected: loading
                          ? null
                          : (_) {
                              setState(() => year = y);
                              _load();
                            },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : annual == null
              ? const Padding(
                  padding: EdgeInsets.all(Gap.lg),
                  child: QuietNote(
                    'The solar return for this year could not be solved. That '
                    'usually means the birth date sits outside the range the '
                    'ephemeris covers.',
                  ),
                )
              : _Body(annual: annual!, natal: widget.chart),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.annual, required this.natal});
  final VarshaphalChart annual;
  final NatalChart natal;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final currentMudda =
        annual.mudda.where((d) => d.contains(now)).firstOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
      children: [
        _PraveshCard(annual: annual),
        const SizedBox(height: Gap.lg),
        _MunthaCard(muntha: annual.muntha),
        const SizedBox(height: Gap.lg),
        _VarshesaCard(annual: annual),
        const SizedBox(height: Gap.lg),
        const SectionHeader(
          'Tajika aspects',
          subtitle: 'Ithasala is applying — the matter completes. Ishrafa is '
              'separating — the moment has gone. It is a question about motion, '
              'not position.',
        ),
        if (annual.aspects.isEmpty)
          const QuietNote('No Tajika aspect falls inside its deeptamsha this '
              'year. An unusually quiet annual chart.')
        else
          for (final a in annual.aspects.take(10)) _AspectCard(aspect: a),
        const SizedBox(height: Gap.lg),
        SectionHeader(
          'Mudda dasha',
          subtitle: 'Vimshottari compressed into the year — the same order and '
              'proportions, scaled so 120 years becomes 365 days.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              children: [
                for (final d in annual.mudda)
                  Container(
                    margin: const EdgeInsets.only(bottom: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: Gap.sm, vertical: 5),
                    decoration: BoxDecoration(
                      color: d == currentMudda
                          ? navy.withValues(alpha: 0.07)
                          : null,
                      borderRadius: BorderRadius.circular(Radii.chip),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: grahaColors[d.lord] ?? inkSoft,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        SizedBox(
                          width: 84,
                          child: Text(
                            grahaName(d.lord),
                            style: Type.body.copyWith(
                              fontWeight: d == currentMudda
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${_date.format(d.start.toLocal())} — '
                            '${_date.format(d.end.toLocal())}',
                            style: Type.caption,
                          ),
                        ),
                        if (d == currentMudda)
                          const Icon(Icons.circle, size: 7, color: navy),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),
        for (final note in annual.notes) ...[
          QuietNote(note),
          const SizedBox(height: Gap.sm),
        ],
      ],
    );
  }
}

class _PraveshCard extends StatelessWidget {
  const _PraveshCard({required this.annual});
  final VarshaphalChart annual;

  @override
  Widget build(BuildContext context) {
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
          Text('Varsha Pravesh', style: Type.micro),
          Text(_stamp.format(annual.pravesh.toLocal()), style: Type.display),
          const SizedBox(height: Gap.xs),
          Text(
            'The Sun returns to its natal sidereal degree here — a different '
            'instant from the birthday, and the one the year is cast for. '
            'Age ${annual.age}.',
            style: Type.bodySoft,
          ),
          const SizedBox(height: Gap.sm),
          Text(
            '${signName(signIndex(annual.chart.lagnaSidereal))} rises on the '
            'annual chart.',
            style: Type.caption,
          ),
        ],
      ),
    );
  }
}

class _MunthaCard extends StatelessWidget {
  const _MunthaCard({required this.muntha});
  final Muntha muntha;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border(left: BorderSide(color: gold, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Muntha in ${signName(muntha.sign)}',
              style: Type.title.copyWith(color: gold)),
          Text('the ${ordinal(muntha.house)} house of the year',
              style: Type.caption),
          const SizedBox(height: Gap.xs),
          Text(
            'This is what the year is about: ${muntha.reading}. '
            '${grahaName(muntha.lord)} rules it.',
            style: Type.bodySoft,
          ),
        ],
      ),
    );
  }
}

class _VarshesaCard extends StatelessWidget {
  const _VarshesaCard({required this.annual});
  final VarshaphalChart annual;

  @override
  Widget build(BuildContext context) {
    final sorted = [...annual.offices]..sort((a, b) => b.bala.compareTo(a.bala));
    final maxBala = sorted.first.bala;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Varshesha — ${grahaName(annual.varshesha)}',
          subtitle: 'The year lord, chosen from five offices on panchavargiya '
              'strength. Read the year through it.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              children: [
                for (final o in sorted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(o.office, style: Type.caption),
                            ),
                            Text(
                              grahaName(o.planet),
                              style: Type.body.copyWith(
                                fontWeight: o.planet == annual.varshesha
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: o.planet == annual.varshesha
                                    ? navy
                                    : ink,
                              ),
                            ),
                            const SizedBox(width: Gap.sm),
                            SizedBox(
                              width: 36,
                              child: Text(
                                o.bala.toStringAsFixed(1),
                                textAlign: TextAlign.right,
                                style: Type.caption,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: maxBala <= 0 ? 0 : o.bala / maxBala,
                            minHeight: 4,
                            backgroundColor: neutralTint,
                            valueColor: AlwaysStoppedAnimation(
                              o.planet == annual.varshesha ? navy : steadyColor,
                            ),
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

class _AspectCard extends StatelessWidget {
  const _AspectCard({required this.aspect});
  final TajikaAspect aspect;

  Color get _tone => switch (aspect.yoga) {
        TajikaYoga.ithasala => beneficColor,
        TajikaYoga.ishrafa => strainedColor,
        TajikaYoga.kamboola => navy,
        _ => neutralColor,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${grahaName(aspect.faster)} ${aspect.aspect} '
                      '${grahaName(aspect.slower)}',
                      style: Type.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _tone.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      aspect.yoga.name,
                      style: Type.micro.copyWith(
                          color: _tone, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.xs),
              Text(aspect.reading, style: Type.bodySoft),
              Text(
                'Orb ${aspect.orb.toStringAsFixed(2)}° of '
                '${aspect.allowed.toStringAsFixed(1)}° deeptamsha.',
                style: Type.micro,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

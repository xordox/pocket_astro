/// The transit timeline.
///
/// Gap G-28's user-facing half. The engine can now solve an exact contact to
/// the minute; the design question is what to do with that.
///
/// The answer this screen takes: **dates, grouped by month, with multi-pass
/// transits shown as one story rather than three events.** A client does not
/// book a consultation about the fact that Pluto is currently squaring their
/// Sun — they book it about the three dates it perfects, and about which of
/// those three is the one that settles the matter.
///
/// Computing a year of exact contacts is real work, so the search runs off the
/// main thread and the screen says what it is doing while it does it.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import '../engine/tables.dart';
import '../engine/transits.dart';
import '../theme/tokens.dart';
import 'widgets/atoms.dart';

final _day = DateFormat('EEE d MMM yyyy');
final _month = DateFormat('MMMM yyyy');

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key, required this.chart});
  final NatalChart chart;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  static const _spans = <(String, Duration)>[
    ('6 months', Duration(days: 183)),
    ('1 year', Duration(days: 365)),
    ('3 years', Duration(days: 1095)),
  ];

  int spanIndex = 1;
  TransitTimeline? timeline;
  bool loading = true;
  Set<TransitEventKind> hidden = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    // Yield a frame so the progress state paints before the search begins.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final result = buildTimeline(
      widget.chart,
      from: DateTime.now().toUtc(),
      span: _spans[spanIndex].$2,
    );
    if (!mounted) return;
    setState(() {
      timeline = result;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
            child: Row(
              children: [
                for (var i = 0; i < _spans.length; i++) ...[
                  ChoiceChip(
                    label: Text(_spans[i].$1),
                    selected: spanIndex == i,
                    onSelected: loading
                        ? null
                        : (_) {
                            setState(() => spanIndex = i);
                            _load();
                          },
                  ),
                  const SizedBox(width: Gap.sm),
                ],
              ],
            ),
          ),
        ),
      ),
      body: loading ? const _Searching() : _body(),
    );
  }

  Widget _body() {
    final t = timeline!;
    final visible =
        t.events.where((e) => !hidden.contains(e.kind)).toList();
    final byMonth = <String, List<TransitEvent>>{};
    for (final e in visible) {
      byMonth.putIfAbsent(_month.format(e.at.toLocal()), () => []).add(e);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
      children: [
        _Filters(
          hidden: hidden,
          onToggle: (k) => setState(() {
            hidden.contains(k) ? hidden.remove(k) : hidden.add(k);
          }),
        ),
        const SizedBox(height: Gap.md),
        if (t.multiPass.isNotEmpty) ...[
          const SectionHeader(
            'Transits that perfect more than once',
            subtitle: 'A retrograde loop makes three contacts on the same '
                'point. That is the shape of the story: arrival, retreat, '
                'resolution.',
          ),
          for (final m in t.multiPass) _MultiPassCard(first: m, all: t.events),
          const SizedBox(height: Gap.lg),
        ],
        for (final entry in byMonth.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: Gap.md, bottom: Gap.sm),
            child: Text(entry.key, style: Type.title),
          ),
          for (final e in entry.value) _EventRow(event: e),
        ],
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: Gap.xl),
            child: QuietNote('Nothing in this window with the current filters.'),
          ),
      ],
    );
  }
}

class _Searching extends StatelessWidget {
  const _Searching();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(height: Gap.md),
          Text('Solving exact contacts…', style: Type.body),
          const SizedBox(height: Gap.xs),
          SizedBox(
            width: 260,
            child: Text(
              'Each date is found by bracketing the crossing and bisecting to '
              'the minute, not by scanning for “within orb”.',
              textAlign: TextAlign.center,
              style: Type.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.hidden, required this.onToggle});
  final Set<TransitEventKind> hidden;
  final ValueChanged<TransitEventKind> onToggle;

  static const _labels = <TransitEventKind, String>{
    TransitEventKind.aspect: 'Aspects',
    TransitEventKind.station: 'Stations',
    TransitEventKind.ingress: 'Ingresses',
    TransitEventKind.newMoon: 'New Moons',
    TransitEventKind.fullMoon: 'Full Moons',
    TransitEventKind.eclipseSolar: 'Solar eclipses',
    TransitEventKind.eclipseLunar: 'Lunar eclipses',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.xs,
      children: [
        for (final e in _labels.entries)
          FilterChip(
            label: Text(e.value),
            selected: !hidden.contains(e.key),
            onSelected: (_) => onToggle(e.key),
            showCheckmark: false,
          ),
      ],
    );
  }
}

class _MultiPassCard extends StatelessWidget {
  const _MultiPassCard({required this.first, required this.all});
  final TransitEvent first;
  final List<TransitEvent> all;

  @override
  Widget build(BuildContext context) {
    final passes = all
        .where((e) =>
            e.body == first.body &&
            e.target == first.target &&
            e.aspect == first.aspect &&
            e.passesTotal == first.passesTotal)
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));

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
                    color: grahaColors[first.body] ?? inkSoft,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    '${grahaName(first.body)} ${first.aspect} '
                    'natal ${grahaName(first.target)}',
                    style: Type.title,
                  ),
                ),
                Text('${first.passesTotal} passes', style: Type.micro),
              ],
            ),
            const SizedBox(height: Gap.sm),
            for (var i = 0; i < passes.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == passes.length - 1
                            ? navy
                            : navy.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: Type.micro.copyWith(
                          color: i == passes.length - 1 ? Colors.white : navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_day.format(passes[i].at.toLocal()),
                              style: Type.body),
                          Text(
                            passes[i].detail.replaceFirst(
                                RegExp(r'^Pass \d+ of \d+[^.]*\. '), ''),
                            style: Type.caption,
                          ),
                        ],
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

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});
  final TransitEvent event;

  Color get _tone => switch (event.kind) {
        TransitEventKind.eclipseSolar ||
        TransitEventKind.eclipseLunar =>
          maleficColor,
        TransitEventKind.station => gold,
        TransitEventKind.ingress => navy,
        _ => inkSoft,
      };

  IconData get _icon => switch (event.kind) {
        TransitEventKind.station => Icons.pause_circle_outline,
        TransitEventKind.ingress => Icons.login,
        TransitEventKind.newMoon => Icons.brightness_3,
        TransitEventKind.fullMoon => Icons.brightness_1_outlined,
        TransitEventKind.eclipseSolar => Icons.brightness_2,
        TransitEventKind.eclipseLunar => Icons.nightlight_round,
        _ => Icons.adjust,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${event.at.toLocal().day}',
                    style: Type.title.copyWith(fontSize: 19)),
                Text(DateFormat('EEE').format(event.at.toLocal()),
                    style: Type.micro),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(_icon, size: 15, color: _tone),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.kind == TransitEventKind.aspect
                            ? '${grahaName(event.body)} ${event.aspect} '
                                'natal ${grahaName(event.target)}'
                            : event.title,
                        style: Type.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (event.retrograde &&
                        event.kind == TransitEventKind.aspect)
                      Text('℞', style: Type.caption.copyWith(color: _tone)),
                  ],
                ),
                if (event.detail.isNotEmpty)
                  Text(event.detail, style: Type.caption),
                if (event.isMultiPass)
                  Text('Pass ${event.pass} of ${event.passesTotal}',
                      style: Type.micro.copyWith(color: navy)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rectification.
///
/// Gap G-38's user-facing half, and the screen where the app stops being a
/// calculator. A large share of consultations begin with a birth time that is
/// wrong by twenty minutes; this is the workbench for fixing it.
///
/// Two modes, in the order a practitioner actually works:
///
///   1. **What moves?** A slider over the uncertainty window with the lagna,
///      the navamsa lagna and the dasha lord updating live — so the first
///      question, "does the time even matter here", gets answered before any
///      effort goes into events.
///   2. **Fit to events.** Dated life events scored against candidate times.
///
/// The result is always a ranked list with its working, never one number. A
/// tool that hands back a single "rectified time" invites more trust than the
/// method can carry.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import '../engine/rectification.dart';
import '../engine/tables.dart';
import '../theme/tokens.dart';
import 'widgets/atoms.dart';

final _time = DateFormat('HH:mm:ss');
final _date = DateFormat('d MMM yyyy');

class RectificationScreen extends StatefulWidget {
  const RectificationScreen({super.key, required this.input});
  final BirthInput input;

  @override
  State<RectificationScreen> createState() => _RectificationScreenState();
}

class _RectificationScreenState extends State<RectificationScreen> {
  double offsetMinutes = 0;
  int windowMinutes = 60;
  final events = <LifeEvent>[];
  RectificationResult? result;
  bool running = false;

  DateTime get _candidateTime => widget.input.localDateTime
      .add(Duration(seconds: (offsetMinutes * 60).round()));

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rectify'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'What moves?'),
              Tab(text: 'Fit to events'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SensitivityTab(
              input: widget.input,
              windowMinutes: windowMinutes,
              offsetMinutes: offsetMinutes,
              onWindow: (v) => setState(() => windowMinutes = v),
              onOffset: (v) => setState(() => offsetMinutes = v),
              candidateTime: _candidateTime,
            ),
            _EventsTab(
              input: widget.input,
              events: events,
              result: result,
              running: running,
              windowMinutes: windowMinutes,
              onAdd: (e) => setState(() {
                events.add(e);
                result = null;
              }),
              onRemove: (e) => setState(() {
                events.remove(e);
                result = null;
              }),
              onRun: _run,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _run() async {
    setState(() => running = true);
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final r = rectify(
      widget.input,
      events,
      window: Duration(minutes: windowMinutes),
      step: Duration(minutes: windowMinutes <= 60 ? 2 : 5),
    );
    if (!mounted) return;
    setState(() {
      result = r;
      running = false;
    });
  }
}

// ---------------------------------------------------------------------------

class _SensitivityTab extends StatelessWidget {
  const _SensitivityTab({
    required this.input,
    required this.windowMinutes,
    required this.offsetMinutes,
    required this.onWindow,
    required this.onOffset,
    required this.candidateTime,
  });

  final BirthInput input;
  final int windowMinutes;
  final double offsetMinutes;
  final ValueChanged<int> onWindow;
  final ValueChanged<double> onOffset;
  final DateTime candidateTime;

  @override
  Widget build(BuildContext context) {
    final sensitivity =
        sensitivityOf(input, window: Duration(minutes: windowMinutes));
    final live = ascendantAt(input, candidateTime);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
      children: [
        const QuietNote(
          'Before fitting anything to events, find out whether the time even '
          'matters. Some charts are stable across an hour; some change '
          'ascendant twice in ten minutes.',
          icon: Icons.tune,
        ),
        const SizedBox(height: Gap.lg),
        const SectionHeader('How uncertain is the time?'),
        Row(
          children: [
            for (final m in const [15, 30, 60, 120, 240]) ...[
              ChoiceChip(
                label: Text(m < 60 ? '±${m ~/ 2}m' : '±${m ~/ 120}h'),
                selected: windowMinutes == m,
                onSelected: (_) => onWindow(m),
              ),
              const SizedBox(width: Gap.sm),
            ],
          ],
        ),
        const SizedBox(height: Gap.lg),
        _LiveReadout(time: candidateTime, live: live),
        Slider(
          value: offsetMinutes.clamp(-windowMinutes / 2, windowMinutes / 2),
          min: -windowMinutes / 2,
          max: windowMinutes / 2,
          divisions: windowMinutes * 2,
          label: '${offsetMinutes >= 0 ? '+' : ''}'
              '${offsetMinutes.toStringAsFixed(1)} min',
          onChanged: onOffset,
        ),
        Center(
          child: Text(
            'Drag to move the birth time. Everything above updates with it.',
            style: Type.caption,
          ),
        ),
        const SizedBox(height: Gap.xl),
        SectionHeader(
          sensitivity.isStable
              ? 'This chart barely moves'
              : 'What changes across the window',
        ),
        for (final note in sensitivity.notes) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Text(note, style: Type.body),
            ),
          ),
          const SizedBox(height: Gap.sm),
        ],
        if (sensitivity.isStable)
          const QuietNote(
            'Nothing structural changes here, so event fitting cannot separate '
            'the candidates either. Widen the window, or accept the time as '
            'good enough for the questions being asked.',
            icon: Icons.check_circle_outline,
          ),
      ],
    );
  }
}

class _LiveReadout extends StatelessWidget {
  const _LiveReadout({required this.time, required this.live});
  final DateTime time;
  final ({int sign, double degree, int navamsa}) live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        children: [
          Text(_time.format(time), style: Type.display),
          const SizedBox(height: Gap.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Readout(
                label: 'Lagna',
                value: '${live.degree.toStringAsFixed(2)}°',
                sub: signName(live.sign),
              ),
              _Readout(
                label: 'Navamsa lagna',
                value: signName(live.navamsa),
                sub: 'nine times as sensitive',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.label, required this.value, required this.sub});
  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Type.micro),
        Text(value, style: Type.title),
        Text(sub, style: Type.micro),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _EventsTab extends StatelessWidget {
  const _EventsTab({
    required this.input,
    required this.events,
    required this.result,
    required this.running,
    required this.windowMinutes,
    required this.onAdd,
    required this.onRemove,
    required this.onRun,
  });

  final BirthInput input;
  final List<LifeEvent> events;
  final RectificationResult? result;
  final bool running;
  final int windowMinutes;
  final ValueChanged<LifeEvent> onAdd;
  final ValueChanged<LifeEvent> onRemove;
  final VoidCallback onRun;

  Future<void> _addEvent(BuildContext context) async {
    final template = await showModalBottomSheet<({String label, List<int> houses})>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
            child: Text(
              'What happened? The houses matter more than the label, and these '
              'templates name them for you.',
              style: Type.caption,
            ),
          ),
          for (final t in eventTemplates)
            ListTile(
              title: Text(t.label),
              subtitle: Text(
                'Houses ${t.houses.map(ordinal).join(', ')}',
                style: Type.caption,
              ),
              onTap: () => Navigator.of(context).pop(t),
            ),
        ],
      ),
    );
    if (template == null || !context.mounted) return;

    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: input.localDateTime,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'When did it happen?',
    );
    if (date == null) return;

    onAdd(LifeEvent(
      when: date.toUtc(),
      description: template.label,
      houses: template.houses,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
      children: [
        const QuietNote(
          'Add dated events and the app scores candidate times against them. '
          'Only the fast-moving tests count — the dasha lords’ houses, solar '
          'arc onto the angles, and the profected year. Three events is the '
          'practical minimum; five or more is better.',
          icon: Icons.event_note_outlined,
        ),
        const SizedBox(height: Gap.lg),
        for (final e in events)
          Card(
            child: ListTile(
              title: Text(e.description),
              subtitle: Text(
                '${_date.format(e.when.toLocal())} · houses '
                '${e.houses.map(ordinal).join(', ')}',
                style: Type.caption,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => onRemove(e),
              ),
            ),
          ),
        const SizedBox(height: Gap.sm),
        OutlinedButton.icon(
          onPressed: () => _addEvent(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add an event'),
        ),
        const SizedBox(height: Gap.md),
        FilledButton.icon(
          onPressed: events.isEmpty || running ? null : onRun,
          icon: const Icon(Icons.search, size: 18),
          label: Text(running ? 'Scoring…' : 'Score candidate times'),
        ),
        if (result != null) ...[
          const SizedBox(height: Gap.xl),
          const SectionHeader(
            'Ranked candidates',
            subtitle: 'A ranking, not an answer.',
          ),
          for (final c in result!.candidates) _CandidateCard(candidate: c),
          const SizedBox(height: Gap.md),
          for (final note in result!.notes) ...[
            QuietNote(note),
            const SizedBox(height: Gap.sm),
          ],
        ],
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate});
  final CandidateTime candidate;

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
                    child: Text(_time.format(candidate.time), style: Type.title),
                  ),
                  Text(
                    '${signName(candidate.lagnaSign)} '
                    '${candidate.lagnaDegree.toStringAsFixed(1)}°',
                    style: Type.caption,
                  ),
                  const SizedBox(width: Gap.sm),
                  Text(
                    candidate.score.toStringAsFixed(1),
                    style: Type.title.copyWith(color: navy),
                  ),
                ],
              ),
              if (candidate.matches.isNotEmpty) ...[
                const SizedBox(height: Gap.xs),
                for (final m in candidate.matches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(m, style: Type.caption),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

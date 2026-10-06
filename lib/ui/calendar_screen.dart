/// The Hindu calendar.
///
/// Gap G-24's user-facing half. The panchanga screen answers "what is today
/// like"; this answers "when is it", which is a different question and the one
/// people open a calendar for.
///
/// The screen makes one thing unmissable that a lesser implementation would
/// hide: when the amanta and purnimanta reckonings disagree — which is the
/// whole dark fortnight, every month — both names are shown. A calendar that
/// silently picks one is wrong for half its readers.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import '../engine/hindu_calendar.dart';
import '../engine/panchanga.dart';
import '../theme/tokens.dart';
import 'widgets/atoms.dart';

final _dayLabel = DateFormat('EEE d MMM');
final _monthLabel = DateFormat('MMMM yyyy');

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.place});
  final Place place;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Observance>? observances;
  HinduDate? today;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 16));

    final now = DateTime.now().toUtc();
    final day = panchangaFor(
      at: now,
      latitude: widget.place.latitude,
      longitudeEast: widget.place.longitude,
      timezone: widget.place.timezone,
    );

    final found = observancesBetween(
      from: DateTime.utc(month.year, month.month, 1),
      to: DateTime.utc(month.year, month.month + 1, 1),
      latitude: widget.place.latitude,
      longitudeEast: widget.place.longitude,
      timezone: widget.place.timezone,
    );

    if (!mounted) return;
    setState(() {
      today = hinduDateFor(day: day);
      observances = found;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding:
                  const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
              children: [
                if (today != null) _TodayCard(date: today!),
                const SizedBox(height: Gap.lg),
                _MonthBar(
                  month: month,
                  onChange: (m) {
                    setState(() => month = m);
                    _load();
                  },
                ),
                const SizedBox(height: Gap.md),
                ..._observanceList(),
              ],
            ),
    );
  }

  List<Widget> _observanceList() {
    final all = observances ?? const <Observance>[];
    final festivals = all
        .where((o) =>
            o.name != 'Purnima' &&
            o.name != 'Amavasya' &&
            !o.name.contains('Ekadashi'))
        .toList();
    final moons = all
        .where((o) =>
            o.name == 'Purnima' ||
            o.name == 'Amavasya' ||
            o.name.contains('Ekadashi'))
        .toList();

    return [
      if (festivals.isEmpty)
        const QuietNote('No festivals this month.')
      else ...[
        const SectionHeader('Festivals'),
        for (final o in festivals) _ObservanceRow(observance: o),
      ],
      const SizedBox(height: Gap.lg),
      const SectionHeader(
        'Moons and fasts',
        subtitle: 'A tithi can span two sunrises, which is why an Ekadashi '
            'sometimes falls on two consecutive days.',
      ),
      for (final o in moons) _ObservanceRow(observance: o),
    ];
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.month, required this.onChange});
  final DateTime month;
  final ValueChanged<DateTime> onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => onChange(DateTime(month.year, month.month - 1)),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            _monthLabel.format(month),
            textAlign: TextAlign.center,
            style: Type.title,
          ),
        ),
        IconButton(
          onPressed: () => onChange(DateTime(month.year, month.month + 1)),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.date});
  final HinduDate date;

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
          Text('Today', style: Type.micro),
          Text(
            '${date.tithiName} · ${date.paksha} paksha',
            style: Type.display,
          ),
          const SizedBox(height: Gap.xs),
          Text(date.monthLine, style: Type.lead),
          if (!date.monthNamesAgree) ...[
            const SizedBox(height: Gap.xs),
            Text(
              'The two reckonings disagree through every dark fortnight: the '
              'south ends a month at the new moon, the north at the full one. '
              'Both names are correct.',
              style: Type.caption,
            ),
          ],
          if (date.isAdhikaMasa) ...[
            const SizedBox(height: Gap.sm),
            Container(
              padding: const EdgeInsets.all(Gap.sm),
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.chip),
              ),
              child: Text(
                'Adhika masa — an intercalary month, in which the Sun changes '
                'no sign. Festivals are kept in the nija month that follows, '
                'not this one.',
                style: Type.caption.copyWith(color: gold),
              ),
            ),
          ],
          const Divider(height: Gap.lg, color: hairline),
          Wrap(
            spacing: Gap.lg,
            runSpacing: Gap.sm,
            children: [
              _Fact('Samvatsara', date.samvatsara),
              _Fact('Shaka', '${date.shakaYear}'),
              _Fact('Vikram Samvat', '${date.vikramYear}'),
              _Fact('Ritu', '${date.ritu} — ${date.ritmuMeaning}'),
              _Fact('Ayana', date.ayana),
              _Fact('Sun in', date.solarMonth),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'Next sankranti: the Sun enters ${date.nextSankrantiSign} on '
            '${_dayLabel.format(date.nextSankranti.toLocal())}.',
            style: Type.caption,
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Type.micro),
        Text(value, style: Type.body),
      ],
    );
  }
}

class _ObservanceRow extends StatelessWidget {
  const _ObservanceRow({required this.observance});
  final Observance observance;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${observance.date.day}',
                    style: Type.title.copyWith(fontSize: 18)),
                Text(DateFormat('EEE').format(observance.date),
                    style: Type.micro),
              ],
            ),
          ),
          if (observance.isFast)
            const Padding(
              padding: EdgeInsets.only(top: 3, right: Gap.xs),
              child: Icon(Icons.brightness_low, size: 14, color: inkFaint),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(observance.name,
                    style: Type.body.copyWith(fontWeight: FontWeight.w600)),
                Text(observance.note, style: Type.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

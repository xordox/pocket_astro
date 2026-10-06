/// Western horary.
///
/// Gap G-33's user-facing half. The screen follows the order a horary chart is
/// actually judged in, and refuses to skip the first step: the considerations
/// come before the answer, and when one of them blocks, the answer is not
/// shown at all.
///
/// That refusal is the design. A tool that prints "yes" under a chart the
/// tradition says is unfit to read is worse than one that prints nothing,
/// because the reader will believe it.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import '../engine/chart_builder.dart';
import '../engine/horary.dart';
import '../engine/tables.dart';
import '../engine/time_convert.dart';
import '../theme/tokens.dart';
import 'widgets/atoms.dart';

final _stamp = DateFormat('d MMM yyyy, HH:mm');

class HoraryScreen extends StatefulWidget {
  const HoraryScreen({super.key, required this.place});
  final Place place;

  @override
  State<HoraryScreen> createState() => _HoraryScreenState();
}

class _HoraryScreenState extends State<HoraryScreen> {
  String question = horaryHouses.keys.first;
  DateTime asked = DateTime.now();
  HoraryJudgment? judgment;

  void _cast() {
    final input = BirthInput(
      id: 'horary-${asked.millisecondsSinceEpoch}',
      name: question,
      localDateTime: asked,
      place: widget.place,
      timeSource: TimeSource.hospital,
    );
    final chart = buildChart(input, toUtc(input), settings: horarySettings);
    setState(() {
      judgment = judgeHorary(
        chart: chart,
        question: question,
        house: horaryHouses[question]!.house,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Horary')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
        children: [
          const QuietNote(
            'A horary chart is cast for the moment the question is understood, '
            'not for the moment it was born. Tropical, Regiomontanus cusps, '
            'and the seven visible planets — the chart the technique was built '
            'on.',
            icon: Icons.help_outline,
          ),
          const SizedBox(height: Gap.lg),
          const SectionHeader('The question'),
          RadioGroup<String>(
            groupValue: question,
            onChanged: (v) => setState(() {
              question = v ?? question;
              judgment = null;
            }),
            child: Column(
              children: [
                for (final entry in horaryHouses.entries)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: entry.key,
                    title: Text(entry.key, style: Type.body),
                    subtitle: Text(
                      '${ordinal(entry.value.house)} house — '
                      '${entry.value.about}',
                      style: Type.caption,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Gap.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Asked at'),
            subtitle: Text(_stamp.format(asked), style: Type.body),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: asked,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
              );
              if (d == null || !context.mounted) return;
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(asked),
              );
              setState(() {
                asked = DateTime(
                    d.year, d.month, d.day, t?.hour ?? asked.hour,
                    t?.minute ?? asked.minute);
                judgment = null;
              });
            },
          ),
          const SizedBox(height: Gap.sm),
          FilledButton.icon(
            onPressed: _cast,
            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: const Text('Cast and judge'),
          ),
          if (judgment != null) ...[
            const SizedBox(height: Gap.xl),
            _Judgment(judgment: judgment!),
          ],
        ],
      ),
    );
  }
}

class _Judgment extends StatelessWidget {
  const _Judgment({required this.judgment});
  final HoraryJudgment judgment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          'Considerations before judgment',
          subtitle: 'Each of these says the chart is not a picture of the '
              'question. An astrologer who reads through them is reading '
              'something else.',
        ),
        for (final c in judgment.considerations)
          if (c.applies) _ConsiderationRow(consideration: c),
        if (!judgment.considerations.any((c) => c.applies))
          const QuietNote('Nothing stands in the way. The chart is fit to read.',
              icon: Icons.check_circle_outline),
        const SizedBox(height: Gap.lg),
        if (!judgment.fitToJudge)
          const _Blocked()
        else ...[
          _Answer(judgment: judgment),
          const SizedBox(height: Gap.lg),
          const SectionHeader('Significators'),
          _SignificatorRow(significator: judgment.querent),
          _SignificatorRow(significator: judgment.moon),
          _SignificatorRow(significator: judgment.quesited),
          const SizedBox(height: Gap.lg),
          const SectionHeader('Perfection'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(judgment.perfection.note, style: Type.body),
                  if (judgment.perfection.denied &&
                      judgment.perfection.denialReason != 'no perfection') ...[
                    const SizedBox(height: Gap.sm),
                    Text(judgment.perfection.denialReason,
                        style: Type.bodySoft.copyWith(color: strainedColor)),
                  ],
                  if (judgment.perfection.perfects &&
                      judgment.perfection.daysAway > 0) ...[
                    const SizedBox(height: Gap.sm),
                    Text(
                      'The aspect perfects in about '
                      '${judgment.perfection.daysAway.toStringAsFixed(1)} '
                      'degrees of relative motion. Horary converts that to the '
                      'querent’s own units by the mode of the signs involved — '
                      'days, weeks or months — which is a judgment rather than '
                      'arithmetic, and is left to you.',
                      style: Type.caption,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.lg),
          const SectionHeader('Essential dignity of the significators'),
          for (final d in judgment.dignities)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 74, child: Text(d.planet, style: Type.body)),
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
                      d.reasons.isEmpty ? 'no dignity' : d.reasons.join(', '),
                      style: Type.caption,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _Blocked extends StatelessWidget {
  const _Blocked();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: strainedTint,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border(left: BorderSide(color: strainedColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Not fit to judge',
              style: Type.title.copyWith(color: strainedColor)),
          const SizedBox(height: Gap.xs),
          Text(
            'No answer is shown, on purpose. A chart the tradition says is '
            'unreadable will still produce a "yes" or a "no" if you ask it — '
            'and you would believe it. Ask again when the question has settled.',
            style: Type.bodySoft,
          ),
        ],
      ),
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({required this.judgment});
  final HoraryJudgment judgment;

  @override
  Widget build(BuildContext context) {
    final yes = judgment.answer.startsWith('yes');
    final tone = yes ? prosperousColor : strainedColor;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border(left: BorderSide(color: tone, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(judgment.question, style: Type.caption),
          Text(judgment.answer, style: Type.display.copyWith(color: tone)),
          const SizedBox(height: Gap.xs),
          Text(judgment.voidMoon.note, style: Type.bodySoft),
        ],
      ),
    );
  }
}

class _ConsiderationRow extends StatelessWidget {
  const _ConsiderationRow({required this.consideration});
  final Consideration consideration;

  @override
  Widget build(BuildContext context) {
    final blocks = consideration.severity == 'blocks';
    final tone = blocks ? maleficColor : gold;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              blocks ? Icons.block : Icons.warning_amber_outlined,
              size: 17,
              color: tone,
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(consideration.name,
                    style: Type.body.copyWith(
                        fontWeight: FontWeight.w700, color: tone)),
                Text(consideration.note, style: Type.bodySoft),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignificatorRow extends StatelessWidget {
  const _SignificatorRow({required this.significator});
  final Significator significator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: grahaColors[significator.planet] ?? inkSoft,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: Gap.sm),
          SizedBox(
            width: 96,
            child: Text(significator.role, style: Type.caption),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${significator.planet}'
                  '${significator.house > 0 ? ' in the ${ordinal(significator.house)}' : ''}',
                  style: Type.body.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(significator.why, style: Type.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

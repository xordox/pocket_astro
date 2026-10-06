/// The offset this chart will actually be built with.
///
/// Gap G-40's second half, and the one that matters at the point of entry.
/// A one-hour timezone error moves the ascendant by fifteen degrees, and it is
/// the commonest cause of a wrong reading in the whole field — so the offset
/// has to be visible *before* the chart is saved, not buried in a provenance
/// panel afterwards.
///
/// The panel stays quiet when there is nothing to say. It raises its voice
/// only for the three cases that actually catch people out: a wartime clock
/// rule, a place that had not yet adopted standard time, and a summer-time
/// rule that the record may or may not have been adjusted for.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models.dart';
import '../../engine/zone_offset.dart';
import '../../theme/tokens.dart';

final _dateLabel = DateFormat('d MMMM yyyy');

class ZoneConfirmation extends StatelessWidget {
  const ZoneConfirmation({
    super.key,
    required this.place,
    required this.localDateTime,
    required this.standard,
    required this.onStandard,
  });

  final Place place;
  final DateTime localDateTime;
  final TimeStandard standard;
  final ValueChanged<TimeStandard> onStandard;

  @override
  Widget build(BuildContext context) {
    final ZoneReading reading;
    try {
      reading = readZone(
        localDateTime: localDateTime,
        place: place,
        standard: standard,
      );
    } catch (_) {
      // An unresolvable zone is already caught on save; there is nothing
      // useful to show here and a thrown widget would be worse than silence.
      return const SizedBox.shrink();
    }

    final loud = reading.worthConfirming;
    final tone = loud ? strainedColor : navy;

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: loud ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border(left: BorderSide(color: tone, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                loud ? Icons.priority_high : Icons.schedule,
                size: 17,
                color: tone,
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${reading.formatted} ${reading.abbreviation}',
                      style: Type.title.copyWith(color: tone),
                    ),
                    Text(
                      'on ${_dateLabel.format(localDateTime)} at '
                      '${place.name}',
                      style: Type.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (reading.notes.isNotEmpty) ...[
            const SizedBox(height: Gap.sm),
            for (final note in reading.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.xs),
                child: Text(note, style: Type.bodySoft),
              ),
          ],
          const SizedBox(height: Gap.sm),
          Text('How was the time recorded?', style: Type.caption),
          const SizedBox(height: Gap.xs),
          SegmentedButton<TimeStandard>(
            segments: [
              for (final s in TimeStandard.values)
                ButtonSegment(value: s, label: Text(s.label)),
            ],
            selected: {standard},
            onSelectionChanged: (s) => onStandard(s.first),
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(height: Gap.xs),
          Text(standard.explanation, style: Type.micro),
          if (standard == TimeStandard.zone &&
              reading.disagreement.inMinutes.abs() >= 1) ...[
            const SizedBox(height: Gap.xs),
            Text(
              'Local mean time here would be ${reading.localMeanFormatted}, '
              '${reading.disagreement.inMinutes.abs()} minutes '
              '${reading.disagreement.isNegative ? 'later' : 'earlier'} — '
              'about ${reading.ascendantDegrees.abs().toStringAsFixed(1)}° of '
              'ascendant.',
              style: Type.micro,
            ),
          ],
        ],
      ),
    );
  }
}

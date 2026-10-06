import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../engine/panchanga.dart';
import '../engine/tables.dart';
import '../engine/today.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/tokens.dart';
import 'widgets/atoms.dart';

/// The day, read against one chart.
///
/// The order of the screen is the order of the judgment: how the day reads,
/// then what it is suited to, then the classical working-out that produced
/// both. The grade sits at the top because it is what a reader came for; the
/// footnote at the bottom says plainly that a day cannot overrule a chart.
class TodayTab extends StatelessWidget {
  const TodayTab({super.key, required this.report});

  final TodayReport report;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pan = report.panchanga;
    final favour = report.favour;
    final hold = report.hold;

    return ListView(
      key: const PageStorageKey('today'),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
      children: [
        _DayCard(report: report),
        const SizedBox(height: Gap.md),
        if (report.guidance.isNotEmpty) ...[
          SectionHeader(l.todayGuidance),
          _GuidanceCard(lines: report.guidance, remedy: report.remedy),
          const SizedBox(height: Gap.lg),
        ],
        if (favour.isNotEmpty) ...[
          SectionHeader(l.todayLeanInto, subtitle: l.todayLeanIntoSub),
          _CueList(cues: favour),
          const SizedBox(height: Gap.lg),
        ],
        if (hold.isNotEmpty) ...[
          SectionHeader(l.todayHoldOff, subtitle: l.todayHoldOffSub),
          _CueList(cues: hold),
          const SizedBox(height: Gap.lg),
        ],
        SectionHeader(l.todayWindows, subtitle: l.todayWindowsSub),
        for (final w in pan.windows) ...[
          _WindowRow(window: w, now: report.now),
          const SizedBox(height: 6),
        ],
        if (pan.daylight.estimated) ...[
          const SizedBox(height: Gap.sm),
          QuietNote(l.todayEstimatedLight, icon: Icons.wb_twilight_outlined),
        ],
        const SizedBox(height: Gap.lg),
        SectionHeader(l.todayPanchanga, subtitle: l.todayPanchangaSub),
        _LimbTable(panchanga: pan),
        const SizedBox(height: Gap.lg),
        SectionHeader(l.todayMoonStrength, subtitle: l.todayMoonStrengthSub),
        _MoonStrength(report: report),
        const SizedBox(height: Gap.lg),
        QuietNote(l.todayFootnote, icon: Icons.balance_outlined),
      ],
    );
  }
}

/// The verdict card: grade, date, and where the day was reckoned from.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.report});

  final TodayReport report;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pan = report.panchanga;
    final accent = gradeColor(report.grade);
    final time = DateFormat.Hm();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat.yMMMMEEEEd().format(pan.date),
                        style: Type.caption,
                      ),
                      const SizedBox(height: 2),
                      Text(report.grade.label, style: Type.display),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.md,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Radii.chip),
                  ),
                  child: Text(
                    '${pan.tithi.name} · ${pan.pakshaName}',
                    style: Type.micro.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(report.grade.summary, style: Type.lead),
            const SizedBox(height: Gap.md),
            const Divider(height: 1, color: hairline),
            const SizedBox(height: Gap.md),
            Text(
              l.todaySunTimes(
                time.format(pan.daylight.sunrise),
                time.format(pan.daylight.sunset),
              ),
              style: Type.caption,
            ),
            Text(l.todayReckoned(report.place.label), style: Type.caption),
          ],
        ),
      ),
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({required this.lines, required this.remedy});

  final List<String> lines;
  final String remedy;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines) ...[
              Text(line, style: Type.body),
              if (line != lines.last) const SizedBox(height: Gap.sm),
            ],
            if (remedy.isNotEmpty) ...[
              const SizedBox(height: Gap.md),
              const Divider(height: 1, color: hairline),
              const SizedBox(height: Gap.md),
              Text(
                l.todayCarrying.toUpperCase(),
                style: Type.micro.copyWith(letterSpacing: 0.8),
              ),
              const SizedBox(height: Gap.xs),
              Text(remedy, style: Type.bodySoft),
            ],
          ],
        ),
      ),
    );
  }
}

/// Suggestions, each one able to show the classical rule behind it.
class _CueList extends StatelessWidget {
  const _CueList({required this.cues});

  final List<DayCue> cues;

  @override
  Widget build(BuildContext context) {
    final accent = cues.first.favour ? prosperousColor : strainedColor;
    final tint = cues.first.favour ? prosperousTint : strainedTint;
    return Column(
      children: [
        for (final cue in cues)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Tooltip(
              message: cue.because,
              triggerMode: TooltipTriggerMode.tap,
              showDuration: const Duration(seconds: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md,
                  vertical: Gap.sm + 2,
                ),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(Radii.chip),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      cue.favour
                          ? Icons.check_rounded
                          : Icons.pause_circle_outline_rounded,
                      size: 16,
                      color: accent,
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(child: Text(cue.text, style: Type.body)),
                    Icon(Icons.info_outline, size: 14, color: inkFaint),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Rahu kaal and friends, plus Abhijit. Highlighted while running.
class _WindowRow extends StatelessWidget {
  const _WindowRow({required this.window, required this.now});

  final DayWindow window;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final time = DateFormat.Hm();
    final running =
        !now.isBefore(window.start.toUtc()) && now.isBefore(window.end.toUtc());
    final accent = window.favourable ? prosperousColor : strainedColor;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.md,
        vertical: Gap.sm + 2,
      ),
      decoration: BoxDecoration(
        color: running ? accent.withValues(alpha: 0.10) : null,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(
          color: running ? accent.withValues(alpha: 0.45) : hairline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(window.title, style: Type.body),
                if (window.use.isNotEmpty)
                  Text(
                    window.use,
                    style: Type.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${time.format(window.start)}–${time.format(window.end)}',
                style: Type.micro.copyWith(fontWeight: FontWeight.w700),
              ),
              if (running)
                Text(
                  l.todayWindowNow,
                  style: Type.micro.copyWith(color: accent),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The five limbs, each with the moment it gives way.
class _LimbTable extends StatelessWidget {
  const _LimbTable({required this.panchanga});

  final PanchangaDay panchanga;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final time = DateFormat.Hm();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.sm,
        ),
        child: Column(
          children: [
            for (final limb in panchanga.limbs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(limb.label, style: Type.caption),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(limb.name, style: Type.body),
                              ),
                              if (!limb.auspicious) ...[
                                const SizedBox(width: Gap.xs),
                                Icon(
                                  Icons.error_outline,
                                  size: 14,
                                  color: strainedColor,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            limb.endsAt == null
                                ? l.todayAllDay
                                : l.todayUntil(time.format(limb.endsAt!)),
                            style: Type.micro,
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

/// Tarabala, chandrabala and the kakshya count — the personal half.
class _MoonStrength extends StatelessWidget {
  const _MoonStrength({required this.report});

  final TodayReport report;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final tara = report.tarabala;
    final chandra = report.chandrabala;
    final kakshya = report.kakshya;

    return Column(
      children: [
        _StrengthRow(
          title: l.todayTarabala,
          value: l.todayTarabalaValue(tara.name, '${tara.count}'),
          note: tara.reading,
          good: !tara.malefic && tara.tara != 1,
          bad: tara.malefic,
        ),
        _StrengthRow(
          title: l.todayChandrabala,
          value: l.todayChandrabalaValue(ordinal(chandra.house)),
          note: chandra.rule,
          good: chandra.good,
          bad: chandra.bad,
        ),
        if (kakshya != null)
          _StrengthRow(
            title: l.todayKakshya,
            value: l.todayKakshyaValue('${kakshya.score}'),
            note: kakshya.quality,
            good: kakshya.score >= 5,
            bad: kakshya.score <= 2,
          )
        else
          QuietNote(l.todayNoKakshya, icon: Icons.schedule_outlined),
        const SizedBox(height: Gap.sm),
        DisclosurePanel(
          title: l.todayWorkingOut,
          children: [
            Text(l.todayScoreLine('${report.score}'), style: Type.bodySoft),
            const SizedBox(height: Gap.sm),
            for (final cue in report.cues)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.xs),
                child: Text(
                  '${cue.favour ? '+' : '−'} ${cue.text} — ${cue.because}',
                  style: Type.caption,
                ),
              ),
            if (kakshya != null)
              Text(kakshya.line, style: Type.caption),
          ],
        ),
      ],
    );
  }
}

class _StrengthRow extends StatelessWidget {
  const _StrengthRow({
    required this.title,
    required this.value,
    required this.note,
    required this.good,
    required this.bad,
  });

  final String title;
  final String value;
  final String note;
  final bool good;
  final bool bad;

  @override
  Widget build(BuildContext context) {
    final accent = good
        ? prosperousColor
        : bad
            ? strainedColor
            : steadyColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: paperRaised,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(),
                    style: Type.micro.copyWith(letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(value, style: Type.body),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(note, style: Type.caption),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


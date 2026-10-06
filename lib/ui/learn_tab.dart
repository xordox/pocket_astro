import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../engine/learn.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/learn_cubit.dart';
import '../theme/tokens.dart';
import 'widgets/atoms.dart';

/// The course.
///
/// Three levels, each a list of lessons, each lesson a sheet. The design
/// decision worth naming is that nothing is locked: a reader who wants to open
/// the ashtakavarga lesson on day one may. The levels are an ordering, not a
/// gate — gating a syllabus assumes the app knows what the reader already
/// knows, and it does not.
class LearnTab extends StatelessWidget {
  const LearnTab({super.key, required this.syllabus});

  final Syllabus syllabus;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (syllabus.lessonCount == 0) {
      return Center(child: QuietNote(l.learnEmpty));
    }

    return BlocBuilder<LearnCubit, Set<String>>(
      builder: (context, done) {
        final next = syllabus.nextAfter(done);
        return ListView(
          key: const PageStorageKey('learn'),
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
          children: [
            _ProgressCard(syllabus: syllabus, done: done, next: next),
            const SizedBox(height: Gap.lg),
            for (final level in syllabus.levels) ...[
              SectionHeader(
                level.title,
                subtitle: level.blurb,
                trailing: _LevelCount(
                  done: syllabus.doneIn(level, done),
                  total: level.lessons.length,
                ),
              ),
              for (final lesson in level.lessons) ...[
                _LessonRow(
                  lesson: lesson,
                  total: syllabus.lessonCount,
                  done: done.contains(lesson.id),
                  syllabus: syllabus,
                ),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: Gap.lg),
            ],
            QuietNote(l.learnFootnote, icon: Icons.school_outlined),
            const SizedBox(height: Gap.md),
            Center(
              child: TextButton.icon(
                onPressed: done.isEmpty ? null : () => _confirmReset(context),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text(l.learnReset),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final l = L.of(context);
    final cubit = context.read<LearnCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.learnResetTitle),
        content: Text(l.learnResetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.learnReset),
          ),
        ],
      ),
    );
    if (ok == true) await cubit.reset();
  }
}

/// Where the reader is, and the one button that matters.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.syllabus,
    required this.done,
    required this.next,
  });

  final Syllabus syllabus;
  final Set<String> done;
  final Lesson? next;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final total = syllabus.lessonCount;
    final finished = next == null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.learnTitle, style: Type.display),
            const SizedBox(height: Gap.xs),
            Text(finished ? l.learnFinishedSub : l.learnSub, style: Type.lead),
            const SizedBox(height: Gap.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done.length / total,
                minHeight: 6,
                backgroundColor: hairline,
                valueColor: const AlwaysStoppedAnimation(navy),
              ),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              finished
                  ? l.learnFinished
                  : l.learnProgress('${done.length}', '$total'),
              style: Type.caption,
            ),
            if (next != null) ...[
              const SizedBox(height: Gap.md),
              const Divider(height: 1, color: hairline),
              const SizedBox(height: Gap.md),
              Text(
                l.learnNextUp.toUpperCase(),
                style: Type.micro.copyWith(letterSpacing: 0.8),
              ),
              const SizedBox(height: Gap.xs),
              Text(next!.title, style: Type.title),
              const SizedBox(height: Gap.md),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: () => openLesson(context, next!, syllabus),
                  child: Text(
                    done.isEmpty ? l.learnStart : l.learnContinue,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelCount extends StatelessWidget {
  const _LevelCount({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final complete = done == total && total > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 3),
      decoration: BoxDecoration(
        color: complete ? prosperousTint : hairline.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Text(
        L.of(context).learnLevelProgress('$done', '$total'),
        style: Type.micro.copyWith(
          color: complete ? prosperousColor : inkSoft,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.lesson,
    required this.total,
    required this.done,
    required this.syllabus,
  });

  final Lesson lesson;
  final int total;
  final bool done;
  final Syllabus syllabus;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return InkWell(
      onTap: () => openLesson(context, lesson, syllabus),
      borderRadius: BorderRadius.circular(Radii.chip),
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: paperRaised,
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(
            color: done ? prosperousColor.withValues(alpha: 0.4) : hairline,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: done ? prosperousColor : navy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: done
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : Text(
                      '${lesson.number}',
                      style: Type.micro.copyWith(
                        color: navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson.title, style: Type.body),
                  const SizedBox(height: 1),
                  Text(l.learnMinutes('${lesson.minutes}'), style: Type.micro),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: inkFaint, size: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The lesson itself
// ---------------------------------------------------------------------------

/// Opens [lesson] as a sheet. Exposed because the progress card, the lesson
/// list and the "next lesson" button at the foot of a sheet all open one.
Future<void> openLesson(
  BuildContext context,
  Lesson lesson,
  Syllabus syllabus,
) {
  final cubit = context.read<LearnCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (sheetContext) => BlocProvider.value(
      value: cubit,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        maxChildSize: 0.95,
        builder: (context, controller) => _LessonSheet(
          lesson: lesson,
          syllabus: syllabus,
          controller: controller,
        ),
      ),
    ),
  );
}

class _LessonSheet extends StatelessWidget {
  const _LessonSheet({
    required this.lesson,
    required this.syllabus,
    required this.controller,
  });

  final Lesson lesson;
  final Syllabus syllabus;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final all = syllabus.lessons;
    final at = all.indexWhere((e) => e.id == lesson.id);
    final next = at >= 0 && at + 1 < all.length ? all[at + 1] : null;

    return BlocBuilder<LearnCubit, Set<String>>(
      builder: (context, done) {
        final isDone = done.contains(lesson.id);
        return ListView(
          key: PageStorageKey('lesson-${lesson.id}'),
          controller: controller,
          padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xxl),
          children: [
            Text(
              l.learnLessonOf('${lesson.number}', '${syllabus.lessonCount}')
                  .toUpperCase(),
              style: Type.micro.copyWith(letterSpacing: 0.8),
            ),
            const SizedBox(height: Gap.xs),
            Text(lesson.title, style: Type.display),
            const SizedBox(height: Gap.sm),
            Text(lesson.hook, style: Type.lead),
            const SizedBox(height: Gap.lg),
            for (final point in lesson.points) ...[
              Text(
                point.heading,
                style: Type.body.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: Gap.xs),
              Text(point.body, style: Type.body),
              const SizedBox(height: Gap.md),
            ],
            if (lesson.inYourChart.isNotEmpty) ...[
              const SizedBox(height: Gap.xs),
              _InYourChart(text: lesson.inYourChart),
              const SizedBox(height: Gap.lg),
            ],
            if (lesson.check.question.isNotEmpty) ...[
              _CheckCard(check: lesson.check),
              const SizedBox(height: Gap.lg),
            ],
            Row(
              children: [
                Expanded(
                  child: isDone
                      ? OutlinedButton.icon(
                          onPressed: () =>
                              context.read<LearnCubit>().toggle(lesson.id),
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: Text(l.learnMarkNotDone),
                        )
                      : FilledButton.icon(
                          onPressed: () =>
                              context.read<LearnCubit>().toggle(lesson.id),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text(l.learnMarkDone),
                        ),
                ),
                if (next != null) ...[
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        openLesson(context, next, syllabus);
                      },
                      child: Text(l.learnNextLesson),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

/// The lesson's idea, found in the reader's own chart. This is the part a
/// textbook cannot do, so it gets the emphasis.
class _InYourChart extends StatelessWidget {
  const _InYourChart({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border(left: BorderSide(color: navy, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 14, color: navy),
              const SizedBox(width: Gap.xs),
              Text(
                L.of(context).learnInYourChart.toUpperCase(),
                style: Type.micro.copyWith(color: navy, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(text, style: Type.body),
        ],
      ),
    );
  }
}

/// One question, with the answer hidden until the reader has tried.
class _CheckCard extends StatefulWidget {
  const _CheckCard({required this.check});

  final LessonCheck check;

  @override
  State<_CheckCard> createState() => _CheckCardState();
}

class _CheckCardState extends State<_CheckCard> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: paperRaised,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.learnCheck.toUpperCase(),
            style: Type.micro.copyWith(letterSpacing: 0.8),
          ),
          const SizedBox(height: Gap.sm),
          Text(widget.check.question, style: Type.body),
          const SizedBox(height: Gap.sm),
          if (_shown) ...[
            Text(widget.check.answer, style: Type.bodySoft),
            const SizedBox(height: Gap.xs),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _shown = !_shown),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(_shown ? l.learnHideAnswer : l.learnShowAnswer),
            ),
          ),
        ],
      ),
    );
  }
}

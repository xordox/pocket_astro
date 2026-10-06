import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/atlas.dart';
import '../domain/models.dart';
import '../engine/panchanga.dart';
import '../engine/rashifal.dart';
import '../engine/today.dart' show DayGrade, DayGradeText;
import '../engine/tables.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/library_bloc.dart';
import '../theme/tokens.dart';
import 'widgets/atoms.dart';

/// The daily reading, twelve signs at once.
///
/// Design position: this is the popular surface — the thing people open a
/// astrology app for every morning — and the app's least precise reading. Both
/// facts are shown rather than one hidden. The reader's own rashi is lifted to
/// the top and given the full treatment; the other eleven are a grid they can
/// open. Every screen that shows a rashi reading also offers the route to the
/// chart-level Today tab, which reads the same transits properly.
class RashifalScreen extends StatelessWidget {
  const RashifalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return BlocBuilder<LibraryBloc, LibraryState>(
      builder: (context, state) {
        final profiles = state.profiles;

        // Reckoned at a saved birthplace when there is one, so sunrise and the
        // panchanga are local to the reader rather than to a default city.
        final place = profiles.isEmpty ? kathmandu : profiles.first.place;

        // Which rashis belong to saved charts, so they can be marked.
        final mine = <int, String>{};
        for (final p in profiles) {
          try {
            mine.putIfAbsent(moonRashiOf(p), () => p.name);
          } catch (_) {
            // A profile the engine cannot place is simply not marked.
          }
        }

        final days = rashifalForAll(place: place);
        final yours = mine.keys.isEmpty ? null : days[mine.keys.first];

        return Scaffold(
          appBar: AppBar(title: Text(l.rashifalTitle)),
          body: ListView(
            key: const PageStorageKey('rashifal'),
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
            children: [
              _DayStrip(place: place),
              const SizedBox(height: Gap.lg),
              if (yours != null) ...[
                SectionHeader(
                  l.rashifalYoursFor(mine[yours.sign]!),
                  subtitle: l.rashifalSub,
                ),
                _FeatureCard(
                  day: yours,
                  profileId: _idForRashi(profiles, yours.sign),
                ),
                const SizedBox(height: Gap.lg),
                SectionHeader(l.rashifalPickSign),
              ] else ...[
                SectionHeader(l.rashifalPickSign, subtitle: l.rashifalSub),
                QuietNote(l.rashifalNoChart, icon: Icons.person_add_alt),
                const SizedBox(height: Gap.sm),
              ],
              _SignGrid(days: days, mine: mine.keys.toSet()),
              const SizedBox(height: Gap.lg),
              QuietNote(l.rashifalBetterReadSub, icon: Icons.balance_outlined),
            ],
          ),
        );
      },
    );
  }

  static String? _idForRashi(List<BirthInput> profiles, int rashi) {
    for (final p in profiles) {
      try {
        if (moonRashiOf(p) == rashi) return p.id;
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}

/// Today's date and panchanga — true for everyone, and the frame the readings
/// below are computed in.
class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.place});
  final Place place;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pan = panchangaFor(
      at: DateTime.now().toUtc(),
      latitude: place.latitude,
      longitudeEast: place.longitude,
      timezone: place.timezone,
    );
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat.yMMMMEEEEd().format(pan.date),
            style: Type.title.copyWith(color: navy),
          ),
          const SizedBox(height: 2),
          Text(
            l.panchangaToday(
              '${pan.tithi.name} (${pan.pakshaName})',
              pan.nakshatra.name,
              pan.vara.name,
            ),
            style: Type.caption,
          ),
        ],
      ),
    );
  }
}

/// The reader's own rashi, opened out.
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.day, this.profileId});

  final RashiDay day;
  final String? profileId;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final accent = gradeColor(day.grade);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SignDisc(sign: day.sign, grade: day.grade, large: true),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(day.name, style: Type.title),
                      Text(day.grade.label,
                          style: Type.caption.copyWith(color: accent)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            Text(day.headline, style: Type.lead),
            const SizedBox(height: Gap.md),
            for (final line in day.highlights) ...[
              _LineRow(line: line),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                TextButton(
                  onPressed: () => openRashiSheet(context, day),
                  child: Text(l.rashifalWhatMoves),
                ),
                const Spacer(),
                if (profileId != null)
                  FilledButton.tonal(
                    onPressed: () => context.push('/chart/$profileId'),
                    child: Text(l.homeReadYourDay),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignGrid extends StatelessWidget {
  const _SignGrid({required this.days, required this.mine});

  final List<RashiDay> days;
  final Set<int> mine;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // Two columns on a phone, three when there is room. A fixed count
        // would either waste a tablet or crush a small phone.
        final columns = box.maxWidth > 520 ? 3 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: Gap.sm,
          mainAxisSpacing: Gap.sm,
          childAspectRatio: 2.5,
          children: [
            for (final day in days)
              _SignTile(day: day, yours: mine.contains(day.sign)),
          ],
        );
      },
    );
  }
}

class _SignTile extends StatelessWidget {
  const _SignTile({required this.day, required this.yours});

  final RashiDay day;
  final bool yours;

  @override
  Widget build(BuildContext context) {
    final accent = gradeColor(day.grade);
    return InkWell(
      onTap: () => openRashiSheet(context, day),
      borderRadius: BorderRadius.circular(Radii.chip),
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: paperRaised,
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(
            color: yours ? navy.withValues(alpha: 0.5) : hairline,
            width: yours ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            _SignDisc(sign: day.sign, grade: day.grade),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day.name,
                    style: Type.body.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    day.grade.label,
                    style: Type.micro.copyWith(color: accent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (yours)
                    Text(
                      L.of(context).rashifalYours,
                      style: Type.micro.copyWith(color: navy),
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

/// The sign's initial in a tinted disc — a shape to scan for, since twelve
/// names in a grid all look alike at a glance.
class _SignDisc extends StatelessWidget {
  const _SignDisc({
    required this.sign,
    required this.grade,
    this.large = false,
  });

  final int sign;
  final DayGrade grade;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 44.0 : 28.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: gradeTint(grade),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        signs[sign].sanskrit.characters.first,
        style: (large ? Type.title : Type.glyph).copyWith(
          color: gradeColor(grade),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});
  final RashiLine line;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final helps = line.score > 0;
    final quiet = line.score == 0;
    final accent = quiet
        ? steadyColor
        : helps
            ? prosperousColor
            : strainedColor;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 5),
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      l.rashifalLineTitle(
                          grahaName(line.graha), ordinal(line.house)),
                      style: Type.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (line.obstructed) ...[
                    const SizedBox(width: Gap.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: steadyTint,
                        borderRadius: BorderRadius.circular(Radii.chip),
                      ),
                      child: Text(
                        l.rashifalObstructed,
                        style: Type.micro.copyWith(color: steadyColor),
                      ),
                    ),
                  ],
                ],
              ),
              Text(line.reading, style: Type.caption),
            ],
          ),
        ),
      ],
    );
  }
}

/// All nine grahas for one rashi, with the caveat and the way out.
Future<void> openRashiSheet(BuildContext context, RashiDay day) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (sheetContext) {
      final l = L.of(sheetContext);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          key: PageStorageKey('rashi-${day.sign}'),
          controller: controller,
          padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xxl),
          children: [
            Row(
              children: [
                _SignDisc(sign: day.sign, grade: day.grade, large: true),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(day.name, style: Type.display),
                      Text(
                        '${l.rashifalMoonSign} · ${day.grade.label}',
                        style: Type.caption.copyWith(
                          color: gradeColor(day.grade),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            Text(day.headline, style: Type.lead),
            const SizedBox(height: Gap.lg),
            Text(
              l.rashifalWhatMoves.toUpperCase(),
              style: Type.micro.copyWith(letterSpacing: 0.8),
            ),
            const SizedBox(height: Gap.sm),
            for (final line in day.lines) ...[
              _LineRow(line: line),
              const SizedBox(height: Gap.sm),
            ],
            const SizedBox(height: Gap.md),
            QuietNote(l.rashifalBetterReadSub, icon: Icons.balance_outlined),
          ],
        ),
      );
    },
  );
}

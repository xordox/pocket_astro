import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';

import '../data/pdf_export.dart';
import '../domain/models.dart';
import '../engine/kb.dart';
import '../engine/matching.dart';
import '../engine/matching_extended.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/library_bloc.dart';
import '../state/match_cubit.dart';
import 'library_screen.dart' show BirthFormScreen;
import '../theme/tokens.dart';
import 'widgets/atoms.dart';

/// Kundli matching, written for two people rather than for an astrologer.
///
/// The score is shown as a dial with a sentence under it, each koota explains
/// what it weighs before it shows a number, and Manglik gets an honest card
/// with its cancellations rather than a scary boolean. Nothing on this screen
/// tells anyone not to marry.
class MatchScreen extends StatelessWidget {
  const MatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.navCompatibility)),
      body: BlocBuilder<LibraryBloc, LibraryState>(
        builder: (context, library) {
          final list = library.profiles;
          return BlocBuilder<MatchCubit, MatchSelection>(
            builder: (context, selection) {
              // Anything the cubit still points at that has since been deleted
              // is not a selection any more.
              final ids = list.map((e) => e.id).toSet();
              final aId = ids.contains(selection.aId) ? selection.aId : null;
              final bId = ids.contains(selection.bId) ? selection.bId : null;
              final ready = aId != null && bId != null && aId != bId;

              return ListView(
                key: const PageStorageKey('match'),
                padding: const EdgeInsets.fromLTRB(
                  Gap.lg, Gap.lg, Gap.lg, Gap.xxl,
                ),
                children: [
                  // The old screen refused to draw the picker at all until two
                  // charts already existed, which left a reader with one chart
                  // — or none — looking at a sentence telling them to go and do
                  // it somewhere else. The slots are the empty state now.
                  if (list.length < 2) ...[
                    _NeedTwo(saved: list.length),
                    const SizedBox(height: Gap.lg),
                  ],
                  _PersonPicker(
                    profiles: list,
                    aId: aId,
                    bId: bId,
                    canSwap: ready,
                  ),
                  const SizedBox(height: Gap.lg),
                  if (ready)
                    _Result(aId: aId, bId: bId)
                  else
                    QuietNote(
                      list.length < 2 ? l.matchSavedNote : l.pickTwoNote,
                      icon: Icons.people_outline_rounded,
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Shown above the slots while there are fewer than two charts to compare.
///
/// It is a heading, not a wall: the slots underneath it are fully usable, and
/// the copy now names the action the reader can take here rather than sending
/// them to another screen.
class _NeedTwo extends StatelessWidget {
  const _NeedTwo({required this.saved});

  final int saved;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: rust.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_outline_rounded,
                  size: 20, color: rust),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(l.twoChartsNeeded, style: Type.title),
            ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        Text(l.twoChartsNeededSub, style: Type.bodySoft),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Choosing the two people
// ---------------------------------------------------------------------------

class _PersonPicker extends StatelessWidget {
  const _PersonPicker({
    required this.profiles,
    required this.aId,
    required this.bId,
    required this.canSwap,
  });

  final List<BirthInput> profiles;
  final String? aId;
  final String? bId;
  final bool canSwap;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MatchCubit>();
    final l = L.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _PersonSlot(
            label: l.firstPerson,
            profiles: profiles,
            selectedId: aId,
            onPick: cubit.selectA,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
          child: IconButton(
            tooltip: l.swap,
            onPressed: canSwap
                ? () {
                    cubit.selectA(bId);
                    cubit.selectB(aId);
                  }
                : null,
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
        ),
        Expanded(
          child: _PersonSlot(
            label: l.secondPerson,
            profiles: profiles,
            selectedId: bId,
            onPick: cubit.selectB,
          ),
        ),
      ],
    );
  }
}

enum _SlotAction { pick, add }

/// What the slot sheet came back with.
class _SlotResult {
  const _SlotResult.pick(this.id) : kind = _SlotAction.pick;
  const _SlotResult.add()
      : kind = _SlotAction.add,
        id = null;

  final _SlotAction kind;
  final String? id;
}

/// Opens the birth form as a page and returns the chart it created.
///
/// Pushed on the app's own Navigator rather than routed through GoRouter, so
/// the comparison underneath keeps its state and its selection — a reader
/// adding a second person should come back to the screen they left, not to a
/// rebuilt one. The form still writes to the library, so the new chart appears
/// on the home screen too.
Future<BirthInput?> addChartForSlot(BuildContext context, String label) {
  return Navigator.of(context).push<BirthInput>(
    MaterialPageRoute<BirthInput>(
      builder: (routeContext) => BirthFormScreen(
        title: label,
        saveLabel: L.of(routeContext).saveAndCompare,
        onSaved: (input) => Navigator.of(routeContext).pop(input),
      ),
    ),
  );
}

class _PersonSlot extends StatelessWidget {
  const _PersonSlot({
    required this.label,
    required this.profiles,
    required this.selectedId,
    required this.onPick,
  });

  final String label;
  final List<BirthInput> profiles;
  final String? selectedId;
  final ValueChanged<String?> onPick;


  /// Offers the saved charts and, always, the option to add someone new.
  ///
  /// "Add a new chart" is not tucked at the bottom of the list — with no saved
  /// charts it is the only thing here, and with several it is still the action
  /// a reader comparing a new partner needs. Adding returns them to the
  /// comparison with the slot already filled.
  Future<void> _open(BuildContext context) async {
    final l = L.of(context);
    final result = await showModalBottomSheet<_SlotResult>(
      context: context,
      showDragHandle: true,
      backgroundColor: paper,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          key: const PageStorageKey('match-picker'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: Text(label, style: Type.title),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: navy.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add_alt_1_outlined,
                    size: 20, color: navy),
              ),
              title: Text(l.matchAddNew,
                  style: Type.body.copyWith(fontWeight: FontWeight.w700)),
              subtitle: Text(l.matchSavedNote, style: Type.caption),
              onTap: () => Navigator.pop(sheetContext, const _SlotResult.add()),
            ),
            if (profiles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.md),
                child: Text(l.matchNoSaved, style: Type.caption),
              )
            else ...[
              const Divider(height: Gap.lg, color: hairline),
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.xs),
                child: Text(
                  l.matchChooseSaved.toUpperCase(),
                  style: Type.micro.copyWith(letterSpacing: 0.8),
                ),
              ),
              for (final p in profiles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _Avatar(name: p.name),
                  title: Text(p.name, style: Type.body),
                  subtitle: Text(p.place.name, style: Type.caption),
                  selected: p.id == selectedId,
                  onTap: () =>
                      Navigator.pop(sheetContext, _SlotResult.pick(p.id)),
                ),
            ],
          ],
        ),
      ),
    );

    if (result == null || !context.mounted) return;
    switch (result.kind) {
      case _SlotAction.pick:
        onPick(result.id);
      case _SlotAction.add:
        final created = await addChartForSlot(context, label);
        if (created != null) onPick(created.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chosen =
        profiles.where((p) => p.id == selectedId).firstOrNull;
    final l = L.of(context);
    return Card(
      child: Stack(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(Radii.card),
            onTap: () => _open(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.lg,
              ),
              child: Column(
                children: [
                  _Avatar(name: chosen?.name),
                  const SizedBox(height: Gap.sm),
                  Text(
                    chosen?.name ?? l.choosePerson,
                    style: Type.body.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(label, style: Type.micro, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          // Clearing sits on the slot rather than inside the sheet. It was in
          // the sheet first, at the bottom of a lazy ListView — which on a
          // phone with a few saved charts is past the viewport and therefore
          // never built at all. On the card it is always reachable, and it is
          // one tap instead of three.
          if (chosen != null)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: l.matchClear,
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                onPressed: () => onPick(null),
                icon: const Icon(Icons.close_rounded, color: inkFaint),
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    final initial = (name == null || name!.isEmpty)
        ? null
        : name!.characters.first.toUpperCase();
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: initial == null
            ? neutralTint
            : navy.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: initial == null
          ? const Icon(Icons.person_add_alt_1_rounded,
              size: 20, color: inkFaint)
          : Text(initial, style: Type.title.copyWith(color: navy)),
    );
  }
}

// ---------------------------------------------------------------------------
// The result
// ---------------------------------------------------------------------------

class _Result extends StatelessWidget {
  const _Result({required this.aId, required this.bId});

  final String aId;
  final String bId;

  @override
  Widget build(BuildContext context) {
    final list = context.watch<LibraryBloc>().state.profiles;
    final a = list.firstWhere((e) => e.id == aId);
    final b = list.firstWhere((e) => e.id == bId);
    final ca = chartFor(a);
    final cb = chartFor(b);
    final m = matchCharts(ca, cb);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScoreCard(result: m, aName: a.name, bName: b.name),
        const SizedBox(height: Gap.lg),
        SectionHeader(L.of(context).eightParameters,
            subtitle: L.of(context).eightParametersSub),
        for (final k in m.kootas) ...[
          _KootaRow(koota: k),
          const SizedBox(height: Gap.sm),
        ],
        const SizedBox(height: Gap.md),
        _ManglikCard(result: m, aName: a.name, bName: b.name),
        const SizedBox(height: Gap.lg),
        _BeyondKootas(a: ca, b: cb),
        if (m.overlay.isNotEmpty) ...[
          const SizedBox(height: Gap.lg),
          SectionHeader(L.of(context).beyondScore,
              subtitle: L.of(context).beyondScoreSub),
          for (final note in m.overlay) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome_outlined,
                        size: 18, color: gold),
                    const SizedBox(width: Gap.sm),
                    Expanded(child: Text(note, style: Type.body)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Gap.sm),
          ],
        ],
        const SizedBox(height: Gap.lg),
        QuietNote(L.of(context).matchNote,
            icon: Icons.favorite_outline_rounded),
        const SizedBox(height: Gap.lg),
        FilledButton.icon(
          onPressed: () async {
            final bytes = await buildReportPdf(chart: ca, match: m, partner: cb);
            await Printing.layoutPdf(onLayout: (_) async => bytes);
          },
          icon: const Icon(Icons.ios_share_rounded),
          label: Text(L.of(context).saveComparison),
        ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.result,
    required this.aName,
    required this.bName,
  });

  final MatchResult result;
  final String aName;
  final String bName;

  @override
  Widget build(BuildContext context) {
    final ratio = result.max <= 0 ? 0.0 : result.total / result.max;
    final color = ratio >= 0.66
        ? prosperousColor
        : ratio >= 0.33
            ? navy
            : strainedColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: _ScoreDial(ratio: ratio, color: color),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        result.total.toStringAsFixed(
                          result.total == result.total.roundToDouble() ? 0 : 1,
                        ),
                        style: Type.display.copyWith(fontSize: 38, color: color),
                      ),
                      Text(
                        L.of(context)
                            .outOfMax(result.max.toStringAsFixed(0)),
                        style: Type.caption,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Gap.md),
            Text(
              L.of(context).pairTitle(aName, bName),
              style: Type.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Gap.xs),
            Text(
              matchVerdict(result.total, result.max),
              style: Type.lead,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Gap.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    L.of(context)
                        .traditionallyBand(matchBandLabel(result.band)),
                    style: Type.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ConfidenceMeter(result.confidence),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreDial extends CustomPainter {
  _ScoreDial({required this.ratio, required this.color});

  final double ratio;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 7;
    const start = 2.356; // 135°, so the gap sits at the bottom
    const sweep = 4.712; // 270°

    final track = Paint()
      ..color = hairline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    final value = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: centre, radius: radius);
    canvas.drawArc(rect, start, sweep, false, track);
    if (ratio > 0) {
      canvas.drawArc(rect, start, sweep * ratio.clamp(0.0, 1.0), false, value);
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreDial old) =>
      old.ratio != ratio || old.color != color;
}

class _KootaRow extends StatelessWidget {
  const _KootaRow({required this.koota});

  final KootaScore koota;

  @override
  Widget build(BuildContext context) {
    final plain = kootaPlain(koota.name);
    final ratio = koota.max <= 0 ? 0.0 : koota.obtained / koota.max;
    final color = ratio >= 0.99
        ? prosperousColor
        : ratio > 0
            ? navy
            : strainedColor;

    return ExplainCard(
      title: plain.title,
      accent: color,
      lead: plain.means,
      detail: '${koota.name} — ${koota.note}',
      detailLabel: L.of(context).whatChartSaid,
      badge: Text(
        '${_fmt(koota.obtained)} / ${_fmt(koota.max)}',
        style: Type.body.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: ratio,
          minHeight: 6,
          backgroundColor: hairline,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// Manglik, told honestly.
///
/// The cancellations come straight from `doshas.json`, where every dosha is
/// required to carry them. The rule this app follows is written there too: a
/// dosha is never reported without them.
class _ManglikCard extends StatelessWidget {
  const _ManglikCard({
    required this.result,
    required this.aName,
    required this.bName,
  });

  final MatchResult result;
  final String aName;
  final String bName;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final dosha = PredictionKb.current.dosha('kuja');
    final both = result.mangalA && result.mangalB;
    final either = result.mangalA || result.mangalB;

    final String lead;
    final Color accent;
    if (!either) {
      lead = l.manglikNone;
      accent = prosperousColor;
    } else if (both) {
      lead = l.manglikBoth;
      accent = prosperousColor;
    } else {
      lead = l.manglikOne(result.mangalA ? aName : bName);
      accent = navy;
    }

    final cancellations =
        ((dosha['cancellations'] as List?) ?? const []).cast<String>();

    return ExplainCard(
      title: l.manglikTitle,
      accent: accent,
      lead: lead,
      badge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Text(
          !either
              ? l.manglikBadgeNone
              : both
                  ? l.manglikBadgeCancelled
                  : l.manglikBadgeOne,
          style: Type.caption.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      detail: either && cancellations.isNotEmpty
          ? '${l.manglikCancellations}\n\n'
              '${cancellations.map((c) => '• $c').join('\n')}'
              '\n\n${dosha['never'] ?? ''}'
          : (dosha['honest_reading'] as String?),
      detailLabel: l.howCancelled,
      footnote: l.manglikFootnote,
    );
  }
}


// ===========================================================================
// Beyond the eight kootas (G-25)
// ===========================================================================

/// Rajju, Vedha, Mahendra, Stree-Deergha, Papasamya and the nadi exceptions.
///
/// These sit below the score rather than inside it on purpose. Rajju in
/// particular is not a koota and does not add points — South Indian practice
/// weighs it *above* the total — so folding it into thirty-six would have
/// misrepresented how it is actually used.
class _BeyondKootas extends StatelessWidget {
  const _BeyondKootas({required this.a, required this.b});

  final NatalChart a;
  final NatalChart b;

  @override
  Widget build(BuildContext context) {
    final extended = extendedMatch(a, b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          'Beyond the eight kootas',
          subtitle: 'Thirty-six points is the headline. No astrologer decides '
              'a marriage on it alone.',
        ),
        for (final c in extended.checks) ...[
          _CheckRow(check: c),
          const SizedBox(height: Gap.sm),
        ],
        if (extended.nadiCleared.isNotEmpty) ...[
          const SizedBox(height: Gap.sm),
          Container(
            padding: const EdgeInsets.all(Gap.md),
            decoration: BoxDecoration(
              color: beneficTint,
              borderRadius: BorderRadius.circular(Radii.chip),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_outlined,
                    size: 18, color: beneficColor),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nadi dosha is cancelled',
                          style: Type.title.copyWith(color: beneficColor)),
                      const SizedBox(height: Gap.xs),
                      for (final e in extended.nadiCleared)
                        Text(e.reason, style: Type.bodySoft),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Gap.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Text(navamsaCompatibility(a, b), style: Type.body),
          ),
        ),
        if (extended.dashaSandhi.isNotEmpty) ...[
          const SizedBox(height: Gap.md),
          const SectionHeader('Dasha sandhi',
              subtitle: 'Two lives turning over at the same moment — invisible '
                  'to every koota, and worth planning for.'),
          for (final note in extended.dashaSandhi.take(3)) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Text(note, style: Type.body),
              ),
            ),
            const SizedBox(height: Gap.sm),
          ],
        ],
        const SizedBox(height: Gap.md),
        for (final line in extended.summary) ...[
          QuietNote(line, icon: Icons.notes_outlined),
          const SizedBox(height: Gap.sm),
        ],
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});
  final ExtendedCheck check;

  @override
  Widget build(BuildContext context) {
    final serious = !check.passes && check.severity == 'serious';
    final colour = check.passes
        ? beneficColor
        : (serious ? maleficColor : steadyColor);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                check.passes
                    ? Icons.check_circle_outline
                    : (serious ? Icons.error_outline : Icons.remove_circle_outline),
                size: 18,
                color: colour,
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(check.name, style: Type.title),
                      if (serious) ...[
                        const SizedBox(width: Gap.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: maleficTint,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('weigh this',
                              style: Type.micro.copyWith(
                                  color: maleficColor,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: Gap.xs),
                  Text(check.note, style: Type.bodySoft),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

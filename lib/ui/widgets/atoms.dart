/// Small shared pieces. Every one of them pairs colour with a word, so the
/// app stays readable for someone who cannot distinguish the hues.
library;

import 'package:flutter/material.dart';

import '../../engine/house_quality.dart';
import '../../l10n/engine_strings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../engine/today.dart';
import '../../theme/tokens.dart';

// ---------------------------------------------------------------------------
// Structure
// ---------------------------------------------------------------------------

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Type.title),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: Type.caption),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A card with a title, a one-line plain answer, and the detail folded away.
///
/// This is the app's core pattern: a reader gets the sentence, and only opens
/// the reasoning if they want it.
class ExplainCard extends StatefulWidget {
  const ExplainCard({
    super.key,
    required this.title,
    required this.lead,
    this.detail,
    this.accent,
    this.badge,
    this.footnote,
    this.initiallyOpen = false,
    this.detailLabel,
    this.child,
  });

  final String title;

  /// The sentence a reader should be able to stop at.
  final String lead;

  /// The technical reasoning, hidden until asked for.
  final String? detail;

  final Color? accent;
  final Widget? badge;
  final String? footnote;
  final bool initiallyOpen;

  /// Defaults to the localised "Why this?".
  final String? detailLabel;

  /// Extra content shown above the fold.
  final Widget? child;

  @override
  State<ExplainCard> createState() => _ExplainCardState();
}

class _ExplainCardState extends State<ExplainCard> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? navy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 18,
                  margin: const EdgeInsets.only(top: 2, right: Gap.sm),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(child: Text(widget.title, style: Type.title)),
                if (widget.badge != null) widget.badge!,
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(widget.lead, style: Type.lead),
            if (widget.child != null) ...[
              const SizedBox(height: Gap.md),
              widget.child!,
            ],
            if (widget.detail != null && widget.detail!.trim().isNotEmpty) ...[
              const SizedBox(height: Gap.sm),
              InkWell(
                onTap: () => setState(() => _open = !_open),
                borderRadius: BorderRadius.circular(Radii.chip),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _open
                            ? L.of(context).hideDetail
                            : (widget.detailLabel ?? L.of(context).whyThis),
                        style: Type.caption.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(
                        _open ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: accent,
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 2),
                  child: Text(widget.detail!, style: Type.bodySoft),
                ),
                crossFadeState:
                    _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 180),
                sizeCurve: Curves.easeOutCubic,
              ),
            ],
            if (widget.footnote != null) ...[
              const SizedBox(height: Gap.sm),
              Text(widget.footnote!, style: Type.micro),
            ],
          ],
        ),
      ),
    );
  }
}

/// A titled section that folds away.
///
/// Deliberately not `ExpansionTile`. That widget stores its expanded flag in
/// `PageStorage`, keyed by the `PageStorageKey`s on the path above it — which
/// is the same path any unkeyed scrollable *inside* it computes. The two then
/// share one bucket entry and the scrollable reads the tile's `bool` as a
/// scroll offset, which throws. Owning the state here removes the whole class
/// of bug.
class DisclosurePanel extends StatefulWidget {
  const DisclosurePanel({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.initiallyOpen = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool initiallyOpen;

  @override
  State<DisclosurePanel> createState() => _DisclosurePanelState();
}

class _DisclosurePanelState extends State<DisclosurePanel> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(Radii.chip),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: Type.title),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(widget.subtitle!, style: Type.caption),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      color: inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_open)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.children,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Badges
// ---------------------------------------------------------------------------

class BandPill extends StatelessWidget {
  const BandPill(this.band, {super.key, this.compact = false});

  final HouseBand band;
  final bool compact;

  static (Color, Color) colorsFor(HouseBand band) => switch (band) {
        HouseBand.prosperous => (prosperousColor, prosperousTint),
        HouseBand.steady => (steadyColor, steadyTint),
        HouseBand.strained => (strainedColor, strainedTint),
      };

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = colorsFor(band);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 9,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text(
        band.label,
        style: (compact ? Type.micro : Type.caption).copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class VerdictBadge extends StatelessWidget {
  const VerdictBadge(this.verdict, {super.key});

  final String verdict;

  /// The colour for a verdict. The label comes from the engine's own string
  /// table, so it is localised alongside the reading it belongs to.
  static Color colorFor(String verdict) => switch (verdict) {
        'likely' => verdictLikely,
        'possible' => verdictPossible,
        'caution' => verdictCaution,
        _ => verdictQuiet,
      };

  static String labelFor(String verdict) => tr('verdict.$verdict');

  @override
  Widget build(BuildContext context) {
    final label = labelFor(verdict);
    final color = colorFor(verdict);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Type.caption.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Confidence as a short bar plus the number. The app's ceiling is 75, so the
/// bar is scaled against 75 rather than 100 — a full bar means "as sure as
/// this method can be", not "certain".
class ConfidenceMeter extends StatelessWidget {
  const ConfidenceMeter(this.value, {super.key, this.width = 54});

  final int value;
  final double width;

  @override
  Widget build(BuildContext context) {
    final ratio = (value / 75).clamp(0.0, 1.0);
    final color = ratio > 0.75
        ? prosperousColor
        : ratio > 0.5
            ? navy
            : inkFaint;
    return Semantics(
      label: L.of(context).confidenceSemantic('$value'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: width,
            height: 5,
            decoration: BoxDecoration(
              color: hairline,
              borderRadius: BorderRadius.circular(999),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text('$value', style: Type.micro.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Legend
// ---------------------------------------------------------------------------

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, this.showQuality = true});

  final bool showQuality;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Wrap(
      spacing: Gap.md,
      runSpacing: Gap.sm,
      children: [
        _swatch(beneficColor, l.legendBenefic),
        _swatch(maleficColor, l.legendMalefic),
        if (showQuality) ...[
          _swatch(prosperousColor, l.legendSupported, filled: prosperousTint),
          _swatch(steadyColor, l.legendSteady, filled: steadyTint),
          _swatch(strainedColor, l.legendStrained, filled: strainedTint),
        ],
      ],
    );
  }

  Widget _swatch(Color color, String label, {Color? filled}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: filled ?? color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Type.micro),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty and quiet states
// ---------------------------------------------------------------------------

class QuietNote extends StatelessWidget {
  const QuietNote(this.text, {super.key, this.icon = Icons.info_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: neutralTint,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: inkSoft),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text(text, style: Type.caption)),
        ],
      ),
    );
  }
}

/// The colour a day-grade reads in. Shared so the Today tab and the daily
/// rashifal cannot drift into two different visual scales for one vocabulary.
Color gradeColor(DayGrade grade) => switch (grade) {
      DayGrade.favourable => verdictLikely,
      DayGrade.workable => verdictPossible,
      DayGrade.mixed => verdictQuiet,
      DayGrade.guarded => verdictCaution,
    };

Color gradeTint(DayGrade grade) => gradeColor(grade).withValues(alpha: 0.12);

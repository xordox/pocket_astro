/// Ask a question, and watch the chart actually being read.
///
/// The trace shown here is not a loading animation. The engine returns the
/// steps it genuinely performed — which houses it opened, which period it
/// found, where the slow grahas are, what the point count said — and this
/// widget reveals them in order so the reader can follow the reasoning
/// instead of being handed a verdict. Every step carries a real value, and
/// the source file it came from is named.
library;

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../engine/qa.dart';
import '../../l10n/engine_strings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import 'atoms.dart';

/// Icon per step kind. The engine never names an icon; it names a kind.
IconData _iconFor(String kind) => switch (kind) {
      'question' => Icons.help_outline_rounded,
      'chart' => Icons.auto_awesome_outlined,
      'house' => Icons.grid_view_rounded,
      'dasha' => Icons.timelapse_rounded,
      'transit' => Icons.public_rounded,
      'bindu' => Icons.scatter_plot_outlined,
      'library' => Icons.menu_book_outlined,
      _ => Icons.check_circle_outline_rounded,
    };

class AskPanel extends StatefulWidget {
  const AskPanel({super.key, required this.chart});

  final NatalChart chart;

  @override
  State<AskPanel> createState() => _AskPanelState();
}

class _AskPanelState extends State<AskPanel> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _history = <QaAnswer>[];

  QaAnswer? _running;
  int _revealed = 0;
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ask(String question) async {
    final q = question.trim();
    if (q.isEmpty || _running != null) return;
    FocusScope.of(context).unfocus();

    // The engine is synchronous and fast. The pacing below replays the steps
    // it really took, so the reader can follow them; it never invents work.
    final answer = answerQuestion(widget.chart, q);
    setState(() {
      _controller.clear();
      _running = answer;
      _revealed = 0;
      _done = false;
    });

    for (var i = 0; i < answer.steps.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted || _running != answer) return;
      setState(() => _revealed = i + 1);
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted || _running != answer) return;
    setState(() {
      _done = true;
      _history.insert(0, answer);
      _running = null;
    });
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final busy = _running != null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.sm),
          child: TextField(
            controller: _controller,
            enabled: !busy,
            textInputAction: TextInputAction.send,
            style: Type.body,
            decoration: InputDecoration(
              hintText: l.askHint,
              prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_upward_rounded),
                tooltip: l.askAction,
                onPressed: busy ? null : () => _ask(_controller.text),
              ),
            ),
            onSubmitted: _ask,
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            key: const PageStorageKey('ask-suggestions'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
            children: [
              for (final e in questionBank.entries)
                Padding(
                  padding: const EdgeInsets.only(right: Gap.sm),
                  child: ActionChip(
                    label: Text(_shortLabel(e.key, e.value)),
                    onPressed: busy ? null : () => _ask(e.value),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Gap.sm),
        Expanded(
          child: ListView(
            key: const PageStorageKey('ask-log'),
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            children: [
              if (busy)
                _TracePanel(
                  answer: _running!,
                  revealed: _revealed,
                  done: _done,
                ),
              if (!busy && _history.isEmpty)
                QuietNote(l.askEmptyNote,
                    icon: Icons.lightbulb_outline_rounded),
              for (final a in _history) ...[
                _AnswerCard(answer: a),
                const SizedBox(height: Gap.md),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Chips need to be short, and they are localised. The full English
  /// question still goes to the engine, which is what the intent matcher is
  /// written against.
  String _shortLabel(String key, String full) {
    final short = tr('qa.ask.$key');
    return short == 'qa.ask.$key' ? full : short;
  }
}

/// The live trace, revealed a step at a time.
class _TracePanel extends StatelessWidget {
  const _TracePanel({
    required this.answer,
    required this.revealed,
    required this.done,
  });

  final QaAnswer answer;
  final int revealed;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation(navy),
                    value: answer.steps.isEmpty
                        ? null
                        : revealed / answer.steps.length,
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Text(L.of(context).readingYourChart, style: Type.title),
              ],
            ),
            const SizedBox(height: Gap.xs),
            Text(answer.question, style: Type.caption),
            const SizedBox(height: Gap.md),
            for (var i = 0; i < answer.steps.length; i++)
              AnimatedOpacity(
                opacity: i < revealed ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: AnimatedSlide(
                  offset: i < revealed ? Offset.zero : const Offset(0, 0.12),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: _StepRow(
                    step: answer.steps[i],
                    active: i == revealed - 1,
                    last: i == answer.steps.length - 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.active, required this.last});

  final QaStep step;
  final bool active;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = active ? navy : inkSoft;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: active ? navy.withValues(alpha: 0.10) : neutralTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconFor(step.kind), size: 15, color: color),
              ),
              if (!last)
                Expanded(
                  child: Container(width: 1.5, color: hairline),
                ),
            ],
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: Type.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(step.detail, style: Type.body),
                  if (step.source != null) ...[
                    const SizedBox(height: Gap.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: neutralTint,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(step.source!, style: Type.micro),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.answer});

  final QaAnswer answer;

  @override
  Widget build(BuildContext context) {
    final refused = answer.intent.startsWith('refused');
    final accent = refused ? strainedColor : navy;
    // The trailing confidence sentence is shown as a footnote, not buried in
    // the body, so the body stays readable.
    final parts = answer.answer.split('\n\nConfidence ');
    final body = parts.first;

    return ExplainCard(
      title: answer.question,
      lead: answer.headline.isEmpty ? body : answer.headline,
      detail: answer.headline.isEmpty ? null : body,
      detailLabel: L.of(context).readFullAnswer,
      initiallyOpen: answer.headline.isEmpty,
      accent: accent,
      badge: refused ? null : ConfidenceMeter(answer.confidence),
      footnote: refused ? null : L.of(context).askFootnote,
      child: answer.steps.isEmpty
          ? null
          : _CollapsedTrace(steps: answer.steps),
    );
  }
}

/// The trace stays available after the answer lands, folded away.
class _CollapsedTrace extends StatefulWidget {
  const _CollapsedTrace({required this.steps});

  final List<QaStep> steps;

  @override
  State<_CollapsedTrace> createState() => _CollapsedTraceState();
}

class _CollapsedTraceState extends State<_CollapsedTrace> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(Radii.chip),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.route_outlined, size: 16, color: inkSoft),
                const SizedBox(width: 6),
                Text(
                  _open
                      ? L.of(context).hideSteps
                      : L.of(context)
                          .howWorkedOut('${widget.steps.length}'),
                  style: Type.caption.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(top: Gap.sm),
            child: Column(
              children: [
                for (var i = 0; i < widget.steps.length; i++)
                  _StepRow(
                    step: widget.steps[i],
                    active: false,
                    last: i == widget.steps.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

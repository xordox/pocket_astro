/// Muhurta — choosing a moment.
///
/// Gap G-21's user-facing half. The interaction is deliberately the opposite
/// of the panchanga's: there the reader brings a date and asks what it is
/// like; here they bring a purpose and a range, and the app brings the dates.
///
/// Every window shows its reasons. An electional recommendation a
/// practitioner cannot inspect is one they cannot defend to a client, and a
/// bare score would be exactly that.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import '../engine/muhurta.dart';
import '../engine/tables.dart';
import '../theme/tokens.dart';
import 'widgets/atoms.dart';

final _dayFormat = DateFormat('EEE d MMM');
final _timeFormat = DateFormat('HH:mm');

class MuhurtaScreen extends StatefulWidget {
  const MuhurtaScreen({super.key, required this.place, this.native});

  final Place place;

  /// When supplied, tarabala and chandrabala are judged from this person's
  /// Moon — which is what turns an almanac into an election for them.
  final NatalChart? native;

  @override
  State<MuhurtaScreen> createState() => _MuhurtaScreenState();
}

class _MuhurtaScreenState extends State<MuhurtaScreen> {
  MuhurtaPurpose purpose = MuhurtaPurpose.general;
  int days = 14;
  MuhurtaSearch? result;
  bool searching = false;

  Future<void> _search() async {
    setState(() => searching = true);
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final now = DateTime.now().toUtc();
    final found = searchMuhurta(
      purpose: purpose,
      from: now,
      to: now.add(Duration(days: days)),
      place: widget.place,
      native: widget.native,
      step: const Duration(minutes: 30),
    );
    if (!mounted) return;
    setState(() {
      result = found;
      searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a moment')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
        children: [
          const QuietNote(
            '“When should I do this?” is a search, not a description. Pick the '
            'purpose and a window, and the almanac is read forward rather than '
            'reported for today.',
            icon: Icons.event_available_outlined,
          ),
          const SizedBox(height: Gap.lg),
          const SectionHeader('What is it for?'),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.xs,
            children: [
              for (final p in MuhurtaPurpose.values)
                ChoiceChip(
                  label: Text(p.label),
                  selected: purpose == p,
                  onSelected: (_) => setState(() {
                    purpose = p;
                    result = null;
                  }),
                ),
            ],
          ),
          if (purpose.caution.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            QuietNote(purpose.caution, icon: Icons.info_outline),
          ],
          const SizedBox(height: Gap.lg),
          const SectionHeader('How far ahead?'),
          Row(
            children: [
              for (final d in const [7, 14, 30, 60]) ...[
                ChoiceChip(
                  label: Text('$d days'),
                  selected: days == d,
                  onSelected: (_) => setState(() {
                    days = d;
                    result = null;
                  }),
                ),
                const SizedBox(width: Gap.sm),
              ],
            ],
          ),
          const SizedBox(height: Gap.lg),
          if (widget.native != null)
            QuietNote(
              'Windows will be judged against ${widget.native!.input.name}’s '
              'natal Moon, so they are for them and not for anyone else.',
              icon: Icons.person_outline,
            ),
          const SizedBox(height: Gap.md),
          FilledButton.icon(
            onPressed: searching ? null : _search,
            icon: const Icon(Icons.search, size: 18),
            label: Text(searching ? 'Searching…' : 'Find windows'),
          ),
          if (result != null) ...[
            const SizedBox(height: Gap.xl),
            _Results(result: result!),
          ],
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.result});
  final MuhurtaSearch result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          result.windows.isEmpty
              ? 'Nothing cleared'
              : '${result.windows.length} windows',
          subtitle: '${result.rejected} moments were refused outright — inside '
              'Rahu kaal, Yamaganda, Gulika or a Vishti karana.',
        ),
        for (final w in result.windows) _WindowCard(window: w),
        const SizedBox(height: Gap.md),
        for (final note in result.notes) ...[
          QuietNote(note),
          const SizedBox(height: Gap.sm),
        ],
      ],
    );
  }
}

class _WindowCard extends StatelessWidget {
  const _WindowCard({required this.window});
  final MuhurtaWindow window;

  Color get _tone => switch (window.verdict) {
        'strong' => prosperousColor,
        'workable' => steadyColor,
        'thin' => strainedColor,
        _ => maleficColor,
      };

  @override
  Widget build(BuildContext context) {
    final start = window.start.toLocal();
    final end = window.end.toLocal();

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
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
                        Text(_dayFormat.format(start), style: Type.title),
                        Text(
                          '${_timeFormat.format(start)} – '
                          '${_timeFormat.format(end)}',
                          style: Type.lead,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: _tone.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _tone.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      window.verdict,
                      style: Type.caption.copyWith(
                          color: _tone, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.xs),
              Text(
                '${window.vara} · ${window.tithi} · ${window.nakshatra} · '
                '${signName(window.lagnaSign)} rising',
                style: Type.caption,
              ),
              const Divider(height: Gap.lg, color: hairline),
              for (final f in window.helps) _FactorRow(factor: f),
              for (final f in window.hurts) _FactorRow(factor: f),
            ],
          ),
        ),
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({required this.factor});
  final MuhurtaFactor factor;

  @override
  Widget build(BuildContext context) {
    final positive = factor.points > 0;
    final colour = positive ? beneficColor : maleficColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(
              positive ? Icons.add_circle_outline : Icons.remove_circle_outline,
              size: 13,
              color: colour,
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text(factor.note, style: Type.caption)),
          Text(
            positive ? '+${factor.points}' : '${factor.points}',
            style: Type.micro.copyWith(color: colour, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// The KP screen.
///
/// Gap G-19's user-facing half. KP inverts the Parashari instinct in a way
/// that has to be said out loud or the screen reads as broken: a planet
/// standing in the *star* of a house occupant outranks the house lord itself,
/// and the cuspal sub-lord can deny a matter the rest of the chart promises.
///
/// So the screen leads with the verdict per house — promises, denies, mixed —
/// and keeps the four-step working one tap below it.
library;

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../engine/chart_builder.dart';
import '../engine/kp.dart';
import '../engine/tables.dart';
import '../engine/time_convert.dart';
import '../theme/tokens.dart';
import 'widgets/atoms.dart';

class KpScreen extends StatefulWidget {
  const KpScreen({super.key, required this.input});
  final BirthInput input;

  @override
  State<KpScreen> createState() => _KpScreenState();
}

class _KpScreenState extends State<KpScreen> {
  late NatalChart chart;
  int? expandedHouse;

  @override
  void initState() {
    super.initState();
    // KP is defined under its own settings, so the screen recasts the chart
    // rather than borrowing whatever the reader has set globally. Using the
    // Lahiri ayanamsa here would produce a chart no KP practitioner would
    // recognise.
    chart = buildChart(
      widget.input,
      toUtc(widget.input),
      settings: kpSettings,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('KP'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Cusps'),
              Tab(text: 'Planets'),
              Tab(text: 'Horary'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CuspTab(chart: chart),
            _PlanetTab(chart: chart),
            HoraryTab(place: widget.input.place),
          ],
        ),
      ),
    );
  }
}

class _KpPreamble extends StatelessWidget {
  const _KpPreamble();

  @override
  Widget build(BuildContext context) {
    return const QuietNote(
      'This chart is recast under KP’s own settings — the Krishnamurti '
      'ayanamsa, Placidus cusps and topocentric positions. All three together, '
      'because one without the others is not KP.',
      icon: Icons.settings_suggest_outlined,
    );
  }
}

// ---------------------------------------------------------------------------

class _CuspTab extends StatelessWidget {
  const _CuspTab({required this.chart});
  final NatalChart chart;

  @override
  Widget build(BuildContext context) {
    if (chart.input.timeUnknown) {
      return const Padding(
        padding: EdgeInsets.all(Gap.lg),
        child: QuietNote(
          'KP is built entirely on cusps, and a cusp needs a birth time. Cast '
          'a horary chart instead — that is what the horary tab is for, and it '
          'is the technique KP reaches for when the birth data is unusable.',
        ),
      );
    }

    final cusps = cuspalSubLords(chart);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
      children: [
        const _KpPreamble(),
        const SizedBox(height: Gap.md),
        const QuietNote(
          'In KP the cuspal sub-lord decides. A house whose sub-lord signifies '
          'the house is a promise; one whose sub-lord signifies its negation — '
          'the sixth, eighth or twelfth from it — is a denial, however good the '
          'rest of the chart looks.',
          icon: Icons.gavel_outlined,
        ),
        const SizedBox(height: Gap.lg),
        for (final c in cusps) _CuspCard(cusp: c, chart: chart),
      ],
    );
  }
}

class _CuspCard extends StatelessWidget {
  const _CuspCard({required this.cusp, required this.chart});
  final CuspalSubLord cusp;
  final NatalChart chart;

  Color get _tone => switch (cusp.verdict) {
        'promises' => beneficColor,
        'denies' => maleficColor,
        _ => neutralColor,
      };

  @override
  Widget build(BuildContext context) {
    final sig = significatorsFor(chart, cusp.house);
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
                  SizedBox(
                    width: 34,
                    child: Text(ordinal(cusp.house), style: Type.title),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(houseTopic(cusp.house), style: Type.caption),
                        const SizedBox(height: 2),
                        Text(
                          'Sub-lord ${grahaName(cusp.pointer.subLord)}',
                          style: Type.body.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(cusp.pointer.notation, style: Type.micro),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _tone.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      cusp.verdict,
                      style: Type.micro.copyWith(
                          color: _tone, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              Text(
                'The sub-lord signifies '
                '${cusp.signifies.map(ordinal).join(', ')}.',
                style: Type.bodySoft,
              ),
              const SizedBox(height: Gap.xs),
              DisclosurePanel(
                title: 'Four-step significators',
                children: [
                  _SigStep(1, 'In the star of an occupant', sig.starOfOccupants,
                      'The strongest signification in KP, and the one that '
                      'surprises a jyotishi first.'),
                  _SigStep(2, 'Occupying the house', sig.occupants, ''),
                  _SigStep(3, 'In the star of the house lord', sig.starOfLord, ''),
                  _SigStep(4, 'The house lord', [sig.lord],
                      'The weakest of the four, which inverts the Parashari '
                      'habit entirely.'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SigStep extends StatelessWidget {
  const _SigStep(this.step, this.label, this.planets, this.note);
  final int step;
  final String label;
  final List<String> planets;
  final String note;

  @override
  Widget build(BuildContext context) {
    final names =
        planets.where((p) => p.isNotEmpty).map(grahaName).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: navy.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text('$step',
                style: Type.micro.copyWith(
                    color: navy, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Type.caption),
                Text(
                  names.isEmpty ? 'none' : names.join(', '),
                  style: Type.body.copyWith(
                    color: names.isEmpty ? inkFaint : ink,
                  ),
                ),
                if (note.isNotEmpty) Text(note, style: Type.micro),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PlanetTab extends StatelessWidget {
  const _PlanetTab({required this.chart});
  final NatalChart chart;

  @override
  Widget build(BuildContext context) {
    const bodies = [
      'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn',
      'Rahu', 'Ketu',
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
      children: [
        const _KpPreamble(),
        const SizedBox(height: Gap.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              children: [
                Row(
                  children: const [
                    SizedBox(width: 72, child: Text('Graha', style: Type.micro)),
                    Expanded(child: Text('Star lord', style: Type.micro)),
                    Expanded(child: Text('Sub', style: Type.micro)),
                    Expanded(child: Text('Sub-sub', style: Type.micro)),
                  ],
                ),
                const Divider(height: Gap.md, color: hairline),
                for (final name in bodies)
                  if (chart.grahas.any((g) => g.name == name))
                    _PlanetRow(
                      name: name,
                      pointer: kpPointer(
                          chart.grahas.firstWhere((g) => g.name == name).siderealLon),
                      signifies: chart.input.timeUnknown
                          ? const []
                          : housesSignifiedBy(chart, name),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.md),
        const QuietNote(
          'A planet gives the results of the houses its star lord signifies, '
          'not primarily its own. That is the sentence the whole system rests '
          'on.',
          icon: Icons.star_outline,
        ),
      ],
    );
  }
}

class _PlanetRow extends StatelessWidget {
  const _PlanetRow({
    required this.name,
    required this.pointer,
    required this.signifies,
  });
  final String name;
  final KpPointer pointer;
  final List<int> signifies;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 72,
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: grahaColors[name] ?? inkSoft,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: Gap.xs),
                    Expanded(
                      child: Text(grahaName(name),
                          style: Type.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              Expanded(
                  child: Text(grahaName(pointer.starLord), style: Type.body)),
              Expanded(
                child: Text(
                  grahaName(pointer.subLord),
                  style: Type.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                  child: Text(grahaName(pointer.subSubLord), style: Type.caption)),
            ],
          ),
          if (signifies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 72, top: 1),
              child: Text(
                'signifies ${signifies.map(ordinal).join(', ')}',
                style: Type.micro,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Horary
// ---------------------------------------------------------------------------

/// KP horary, cast from a number between 1 and 249.
///
/// This is the technique KP reaches for when the birth data is unusable, which
/// makes it the right answer to the app's own unknown-birth-time problem
/// (G-39) rather than a separate curiosity.
class HoraryTab extends StatefulWidget {
  const HoraryTab({super.key, required this.place});
  final Place place;

  @override
  State<HoraryTab> createState() => _HoraryTabState();
}

class _HoraryTabState extends State<HoraryTab> {
  final controller = TextEditingController();
  int? number;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final ruling = rulingPlanets(
      utc: now,
      latitude: widget.place.latitude,
      longitudeEast: widget.place.longitude,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
      children: [
        const QuietNote(
          'Ask the querent for a number between 1 and 249, then cast for the '
          'moment they gave it. The number selects the ascendant; everything '
          'else comes from the clock.',
          icon: Icons.help_outline,
        ),
        const SizedBox(height: Gap.lg),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Number (1–249)',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            final parsed = int.tryParse(v);
            setState(() {
              number = (parsed != null && parsed >= 1 && parsed <= 249)
                  ? parsed
                  : null;
            });
          },
        ),
        if (number != null) ...[
          const SizedBox(height: Gap.lg),
          _HoraryResult(number: number!, place: widget.place),
        ],
        const SizedBox(height: Gap.xl),
        const SectionHeader(
          'Ruling planets, now',
          subtitle: 'KP treats these as a shortlist: whatever is going to '
              'happen is signified by something here, so a judgment involving '
              'none of them is probably wrong.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.xs,
                  children: [
                    for (var i = 0; i < ruling.ordered.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (grahaColors[ruling.ordered[i]] ?? inkSoft)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${i + 1}. ${grahaName(ruling.ordered[i])}',
                          style: Type.caption.copyWith(
                            color: grahaColors[ruling.ordered[i]] ?? inkSoft,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const Divider(height: Gap.lg, color: hairline),
                Text('Ascendant: ${ruling.ascendant.notation}',
                    style: Type.caption),
                Text('Moon: ${ruling.moon.notation}', style: Type.caption),
                Text('Day lord: ${grahaName(ruling.dayLord)}',
                    style: Type.caption),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HoraryResult extends StatelessWidget {
  const _HoraryResult({required this.number, required this.place});
  final int number;
  final Place place;

  @override
  Widget build(BuildContext context) {
    final division = horaryDivisionFor(number);
    final ascendant = horaryAscendantFor(number);

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border(left: BorderSide(color: navy, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Number $number', style: Type.title.copyWith(color: navy)),
          const SizedBox(height: Gap.xs),
          Text(division.label, style: Type.lead),
          const SizedBox(height: Gap.sm),
          Text(
            'The horary ascendant falls at ${formatDms(ascendant)} '
            '${signName(signIndex(ascendant))}, the midpoint of a division '
            'spanning ${formatDms(division.start)} to '
            '${formatDms(division.end)}.',
            style: Type.bodySoft,
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'Cast the rest of the chart for the moment the question was asked, '
            'at ${place.label}, then judge the cuspal sub-lord of the house the '
            'question belongs to.',
            style: Type.caption,
          ),
        ],
      ),
    );
  }
}

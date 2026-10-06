/// The Western wheel, with its bi-wheel modes.
///
/// Gap G-45's user-facing half. A wheel is not just a second way of drawing
/// the same table — it is the form in which Western astrologers actually see a
/// chart, and it is the only sensible way to show two charts at once.
///
/// Three modes, because each answers a different question:
///
///   * **Natal** — the chart alone.
///   * **Transits** — today's sky on the outside of the birth chart, which is
///     how a forecast is read.
///   * **Progressed** — the secondary-progressed chart outside the natal one.
library;

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../engine/aspects.dart';
import '../engine/astro/ephemeris.dart';
import '../engine/astro/houses.dart';
import '../engine/predictive.dart';
import '../engine/tables.dart';
import '../theme/tokens.dart';
import 'widgets/atoms.dart';
import 'widgets/wheel.dart';

enum WheelMode { natal, transits, progressed }

extension _WheelModeLabel on WheelMode {
  String get label => switch (this) {
        WheelMode.natal => 'Natal',
        WheelMode.transits => 'Transits',
        WheelMode.progressed => 'Progressed',
      };

  String get note => switch (this) {
        WheelMode.natal => 'The birth chart alone.',
        WheelMode.transits =>
          'Today’s sky on the outer ring, the birth chart on the inner.',
        WheelMode.progressed =>
          'Secondary progressions outside, a day after birth for each year of '
              'life.',
      };
}

class WheelScreen extends StatefulWidget {
  const WheelScreen({super.key, required this.chart});
  final NatalChart chart;

  @override
  State<WheelScreen> createState() => _WheelScreenState();
}

class _WheelScreenState extends State<WheelScreen> {
  WheelMode mode = WheelMode.natal;
  bool showAspectLines = true;

  @override
  Widget build(BuildContext context) {
    final chart = widget.chart;
    if (chart.westernCusps == null || chart.input.timeUnknown) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wheel')),
        body: const Padding(
          padding: EdgeInsets.all(Gap.lg),
          child: QuietNote(
            'A wheel is mostly a picture of the houses, and the houses need a '
            'birth time. The graha table still holds everything that does not.',
          ),
        ),
      );
    }

    final inner = [
      for (final g in chart.grahas)
        if (g.name != 'Lagna' && _onWheel(g.name)) WheelBody.fromGraha(g),
    ];

    final outer = _outerRing();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wheel'),
        actions: [
          IconButton(
            tooltip: showAspectLines ? 'Hide aspect lines' : 'Show aspect lines',
            onPressed: () =>
                setState(() => showAspectLines = !showAspectLines),
            icon: Icon(showAspectLines
                ? Icons.hub
                : Icons.hub_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
        children: [
          SegmentedButton<WheelMode>(
            segments: [
              for (final m in WheelMode.values)
                ButtonSegment(value: m, label: Text(m.label)),
            ],
            selected: {mode},
            onSelectionChanged: (s) => setState(() => mode = s.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: Gap.sm),
          Text(mode.note, style: Type.caption, textAlign: TextAlign.center),
          const SizedBox(height: Gap.md),
          ChartWheel(
            bodies: inner,
            outerBodies: outer,
            cusps: chart.westernCusps!,
            aspects: chart.westernAspects,
            showAspectLines: showAspectLines,
          ),
          const SizedBox(height: Gap.lg),
          _AngleStrip(chart: chart),
          const SizedBox(height: Gap.lg),
          const SectionHeader('Positions'),
          WheelLegend(bodies: inner),
          if (outer.isNotEmpty) ...[
            const SizedBox(height: Gap.lg),
            SectionHeader(mode == WheelMode.transits
                ? 'Transits, outer ring'
                : 'Progressed, outer ring'),
            WheelLegend(bodies: outer),
          ],
          const SizedBox(height: Gap.lg),
          _AspectGrid(chart: chart),
        ],
      ),
    );
  }

  bool _onWheel(String name) => const {
        'Sun', 'Moon', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn',
        'Uranus', 'Neptune', 'Pluto', 'Rahu', 'Ketu', 'Chiron',
      }.contains(name);

  List<WheelBody> _outerRing() {
    switch (mode) {
      case WheelMode.natal:
        return const [];
      case WheelMode.transits:
        final sky = computeSky(
          utc: DateTime.now().toUtc(),
          latitude: widget.chart.input.place.latitude,
          longitudeEast: widget.chart.input.place.longitude,
          settings: widget.chart.settings,
        );
        return [
          for (final b in sky.bodies.values)
            if (_onWheel(b.name))
              WheelBody(
                name: b.name,
                longitude: b.longitude,
                retrograde: b.isRetrograde && b.name != 'Rahu' && b.name != 'Ketu',
                ring: 1,
              ),
        ];
      case WheelMode.progressed:
        final p = secondaryProgressions(widget.chart, DateTime.now().toUtc());
        return [
          for (final b in p.positions.values)
            if (_onWheel(b.name))
              WheelBody(
                name: b.name,
                longitude: b.longitude,
                retrograde: b.isRetrograde && b.name != 'Rahu' && b.name != 'Ketu',
                ring: 1,
              ),
        ];
    }
  }
}

class _AngleStrip extends StatelessWidget {
  const _AngleStrip({required this.chart});
  final NatalChart chart;

  @override
  Widget build(BuildContext context) {
    final cusps = chart.westernCusps!;
    final entries = <(String, double)>[
      ('Asc', cusps.ascendant),
      ('MC', cusps.midheaven),
      ('Vertex', cusps.vertex),
      ('East Point', cusps.eastPoint),
      if (chart.partOfFortune != null) ('Fortune', chart.partOfFortune!),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: Gap.lg,
              runSpacing: Gap.sm,
              children: [
                for (final e in entries)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.$1, style: Type.micro),
                      Text(
                        '${formatDms(e.$2)} ${signName(signIndex(e.$2))}',
                        style: Type.body,
                      ),
                    ],
                  ),
              ],
            ),
            const Divider(height: Gap.lg, color: hairline),
            Text(
              '${cusps.system.label} houses. ${cusps.system.principle}'
              '${cusps.fellBack ? ' ${cusps.requested.label} is undefined at this latitude, so Porphyry stood in.' : ''}',
              style: Type.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _AspectGrid extends StatelessWidget {
  const _AspectGrid({required this.chart});
  final NatalChart chart;

  @override
  Widget build(BuildContext context) {
    final major =
        chart.westernAspects.where((a) => a.kind == AspectKind.major).toList();
    final minor =
        chart.westernAspects.where((a) => a.kind == AspectKind.minor).toList();
    final declinations = declinationAspects(chart.grahas);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Aspects',
            subtitle: 'Applying means the faster body is still closing on it — '
                'about to happen rather than already over.'),
        for (final a in major) _AspectRow(hit: a),
        if (minor.isNotEmpty)
          DisclosurePanel(
            title: 'Minor aspects',
            subtitle: '${minor.length} found',
            children: [for (final a in minor) _AspectRow(hit: a)],
          ),
        if (declinations.isNotEmpty)
          DisclosurePanel(
            title: 'Parallels of declination',
            subtitle: 'A parallel behaves like a conjunction however far apart '
                'the two bodies are in longitude.',
            children: [for (final a in declinations) _AspectRow(hit: a)],
          ),
      ],
    );
  }
}

class _AspectRow extends StatelessWidget {
  const _AspectRow({required this.hit});
  final AspectHit hit;

  @override
  Widget build(BuildContext context) {
    final colour = switch (hit.name) {
      'trine' || 'sextile' || 'parallel' => beneficColor,
      'square' || 'opposition' || 'contraparallel' => maleficColor,
      _ => neutralColor,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(grahaName(hit.a), style: Type.body),
          ),
          SizedBox(
            width: 104,
            child: Text(
              hit.name,
              style: Type.body.copyWith(color: colour, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 76,
            child: Text(grahaName(hit.b), style: Type.body),
          ),
          Expanded(
            child: Text(
              '${hit.orb.toStringAsFixed(2)}°'
              '${hit.kind == AspectKind.declination ? '' : ' ${hit.motion}'}'
              '${hit.outOfSign ? ' · out of sign' : ''}',
              textAlign: TextAlign.right,
              style: Type.micro,
            ),
          ),
        ],
      ),
    );
  }
}

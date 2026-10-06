/// How this chart was computed.
///
/// Gap G-46. `engineStamp` was a good instinct trapped in a constant string.
/// Now that ayanamsa, house system, node type, ΔT and topocentric mode are all
/// choices, each chart has to record the settings it was built under.
///
/// The practical case for this panel: a client brings a chart from another
/// astrologer and the figures differ. The first question is always *which
/// ayanamsa and which house system* — and this answers it in one glance
/// instead of an argument. It is also what lets the app be checked rather than
/// trusted, which is the difference between a tool and an oracle.
library;

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../engine/astronomy.dart';
import '../../theme/tokens.dart';
import 'atoms.dart';

class ProvenancePanel extends StatelessWidget {
  const ProvenancePanel({super.key, required this.chart});
  final NatalChart chart;

  @override
  Widget build(BuildContext context) {
    final s = chart.settings;
    final sky = chart.sky;
    final cusps = chart.westernCusps;

    return DisclosurePanel(
      title: 'How this chart was computed',
      subtitle: '${s.ayanamsa.label} · ${s.houseSystem.label}',
      children: [
        _Row('Ayanamsa', s.ayanamsa.label, s.ayanamsa.anchor),
        if (sky != null)
          _Row(
            'Ayanamsa value',
            _dms(sky.ayanamsaValue),
            'At this chart’s moment.',
          ),
        _Row('Vedic houses', s.vedicHouseSystem.label,
            s.vedicHouseSystem.principle),
        _Row('Western houses', s.houseSystem.label, s.houseSystem.principle),
        if (cusps != null && cusps.fellBack)
          _Row(
            'House fallback',
            cusps.system.label,
            '${cusps.requested.label} is undefined at this latitude — a degree '
                'there never rises — so Porphyry produced these cusps instead.',
            tone: strainedColor,
          ),
        _Row(
          'Lunar node',
          s.trueNode ? 'True node' : 'Mean node',
          s.trueNode
              ? 'The true node oscillates around the mean by up to 1°40′.'
              : 'The smoothed node most Vedic schools use.',
        ),
        _Row(
          'Vantage',
          s.topocentric ? 'Topocentric' : 'Geocentric',
          s.topocentric
              ? 'Seen from the birthplace. The Moon can differ from the '
                  'geocentric position by almost a degree.'
              : 'Seen from the centre of the Earth.',
        ),
        if (sky != null)
          _Row(
            'ΔT applied',
            '${sky.deltaTSeconds.toStringAsFixed(1)} s',
            'The gap between Terrestrial Time and Universal Time at this date. '
                'Ignoring it would move the Moon by about '
                '${(sky.deltaTSeconds * 0.55).toStringAsFixed(0)} arcseconds.',
          ),
        if (sky != null)
          _Row(
            'Obliquity',
            _dms(sky.obliquity),
            'True obliquity, with nutation applied.',
          ),
        if (sky != null)
          _Row(
            'Sidereal time',
            _dms(sky.localSiderealTime),
            'Local apparent sidereal time — the angles are built on this.',
          ),
        const Divider(height: Gap.lg, color: hairline),
        Text('Positions', style: Type.caption.copyWith(
            fontWeight: FontWeight.w700, color: ink)),
        const SizedBox(height: Gap.xs),
        Text(
          'Truncated VSOP87 for the Sun and the full Meeus lunar series, with '
          'nutation, annual aberration and light-time correction. Checked '
          'against Meeus’s published worked examples on every build: the Sun '
          'to about 2 arcseconds, the Moon to about 10, the planets to an '
          'arcminute or two. Chiron and the asteroids carry no perturbations '
          'and are approximate.',
          style: Type.caption,
        ),
        const SizedBox(height: Gap.sm),
        Text(
          'That is natal-chart grade, not Swiss Ephemeris grade for the '
          'planets — and it is measured rather than claimed.',
          style: Type.micro,
        ),
        const SizedBox(height: Gap.md),
        SelectableText(chart.engineStamp, style: Type.micro),
      ],
    );
  }

  static String _dms(double deg) {
    final d = deg.floor();
    final mFull = (deg - d) * 60;
    final m = mFull.floor();
    final s = ((mFull - m) * 60).round();
    return "$d°${m.toString().padLeft(2, '0')}'${s.toString().padLeft(2, '0')}\"";
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, this.note, {this.tone});
  final String label;
  final String value;
  final String note;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 118, child: Text(label, style: Type.caption)),
              Expanded(
                child: Text(
                  value,
                  style: Type.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tone ?? ink,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 118, top: 1),
            child: Text(note, style: Type.micro),
          ),
        ],
      ),
    );
  }
}

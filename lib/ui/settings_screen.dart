/// Calculation settings.
///
/// This screen is the user-facing half of gaps G-02, G-03, G-04, G-07 and
/// G-46. Every control here used to be a constant compiled into the engine.
///
/// The design rule throughout: a setting is never offered as a bare name.
/// "Placidus" tells a reader nothing; "trisects the time each degree spends
/// above the horizon" tells them what they are choosing between. Where a
/// choice has a consequence the reader can feel, the screen states it — how
/// far the ayanamsa moves the Moon, which systems fail at polar latitudes,
/// why KP needs three settings at once rather than one.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/models.dart';
import '../engine/aspects.dart';
import '../engine/astronomy.dart';
import '../engine/tables.dart';
import '../state/settings_cubit.dart';
import '../theme/tokens.dart';
import 'widgets/atoms.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.sampleChart});

  /// An open chart, if there is one. Used to show the live consequence of a
  /// choice rather than describing it in the abstract.
  final NatalChart? sampleChart;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, AppSettings>(
      builder: (context, settings) {
        final cubit = context.read<SettingsCubit>();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Calculation'),
            actions: [
              TextButton(
                onPressed: settings.isDefault ? null : cubit.resetAll,
                child: const Text('Reset'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
            children: [
              const _Preamble(),
              const SizedBox(height: Gap.xl),
              _Presets(settings: settings, cubit: cubit),
              const SizedBox(height: Gap.xl),
              _AyanamsaSection(
                settings: settings,
                cubit: cubit,
                sample: sampleChart,
              ),
              const SizedBox(height: Gap.xl),
              _HouseSection(settings: settings, cubit: cubit),
              const SizedBox(height: Gap.xl),
              _PositionSection(settings: settings, cubit: cubit),
              const SizedBox(height: Gap.xl),
              _DisplaySection(settings: settings, cubit: cubit),
              const SizedBox(height: Gap.xl),
              _OrbSection(settings: settings, cubit: cubit),
              const SizedBox(height: Gap.xl),
              const _AccuracyNote(),
            ],
          ),
        );
      },
    );
  }
}

class _Preamble extends StatelessWidget {
  const _Preamble();

  @override
  Widget build(BuildContext context) {
    return const QuietNote(
      'These settings change the numbers, not the presentation. Whatever is '
      'chosen here is recorded on every chart you build, so when a chart from '
      'another astrologer disagrees with yours, the reason is one tap away '
      'instead of an argument.',
      icon: Icons.tune,
    );
  }
}

// ---------------------------------------------------------------------------
// Presets
// ---------------------------------------------------------------------------

class _Presets extends StatelessWidget {
  const _Presets({required this.settings, required this.cubit});
  final AppSettings settings;
  final SettingsCubit cubit;

  bool _matches(SettingsPreset p) =>
      p.settings.ayanamsa == settings.chart.ayanamsa &&
      p.settings.houseSystem == settings.chart.houseSystem &&
      p.settings.vedicHouseSystem == settings.chart.vedicHouseSystem &&
      p.settings.trueNode == settings.chart.trueNode &&
      p.settings.topocentric == settings.chart.topocentric;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          'Tradition',
          subtitle: 'These settings travel in groups. Pick a school and the '
              'rest follow.',
        ),
        for (final preset in settingsPresets) ...[
          _PresetCard(
            preset: preset,
            selected: _matches(preset),
            onTap: () => cubit.applyPreset(preset),
          ),
          const SizedBox(height: Gap.sm),
        ],
      ],
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });
  final SettingsPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? navy.withValues(alpha: 0.06) : paperRaised,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Container(
          padding: const EdgeInsets.all(Gap.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(
              color: selected ? navy : hairline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(preset.name, style: Type.title),
                    const SizedBox(height: Gap.xs),
                    Text(preset.description, style: Type.bodySoft),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: Gap.sm),
                const Icon(Icons.check_circle, color: navy, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ayanamsa
// ---------------------------------------------------------------------------

class _AyanamsaSection extends StatelessWidget {
  const _AyanamsaSection({
    required this.settings,
    required this.cubit,
    this.sample,
  });
  final AppSettings settings;
  final SettingsCubit cubit;
  final NatalChart? sample;

  @override
  Widget build(BuildContext context) {
    final current = settings.chart.ayanamsa;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          'Ayanamsa',
          subtitle: 'Where the sidereal zodiac begins. The schools differ by '
              'up to two degrees — more than a nakshatra pada.',
        ),
        Card(
          child: Column(
            children: [
              for (final a in Ayanamsa.values)
                _ChoiceTile(
                  title: a.label,
                  subtitle: a.anchor,
                  selected: current == a,
                  trailing: _AyanamsaValue(mode: a, sample: sample),
                  onTap: () => cubit.setAyanamsa(a),
                ),
            ],
          ),
        ),
        if (sample != null) ...[
          const SizedBox(height: Gap.md),
          _AyanamsaConsequence(sample: sample!, current: current),
        ],
      ],
    );
  }
}

/// The ayanamsa's value at the sample chart's date, so the difference between
/// two schools is a number rather than an assertion.
class _AyanamsaValue extends StatelessWidget {
  const _AyanamsaValue({required this.mode, this.sample});
  final Ayanamsa mode;
  final NatalChart? sample;

  @override
  Widget build(BuildContext context) {
    if (sample == null || mode == Ayanamsa.none) return const SizedBox.shrink();
    final jdTt = DeltaT.terrestrial(sample!.jd);
    final value = ayanamsaFor(mode, jdTt);
    final d = value.floor();
    final m = ((value - d) * 60).round();
    return Text(
      "$d°${m.toString().padLeft(2, '0')}'",
      style: Type.caption.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _AyanamsaConsequence extends StatelessWidget {
  const _AyanamsaConsequence({required this.sample, required this.current});
  final NatalChart sample;
  final Ayanamsa current;

  @override
  Widget build(BuildContext context) {
    final jdTt = DeltaT.terrestrial(sample.jd);
    final tropicalMoon = sample.graha('Moon').tropicalLon;

    String placementUnder(Ayanamsa mode) {
      final sid = norm360(tropicalMoon - ayanamsaFor(mode, jdTt));
      return '${nakshatraOf(sid).name} pada ${padaOf(sid)} '
          '(${nakshatraOf(sid).lord} dasha)';
    }

    final here = placementUnder(current);
    final differing = <Ayanamsa>[];
    for (final a in Ayanamsa.values) {
      if (a == current || a == Ayanamsa.none) continue;
      if (placementUnder(a) != here) differing.add(a);
    }

    if (differing.isEmpty) {
      return QuietNote(
        'On ${sample.input.name}’s chart the Moon lands in $here under every '
        'school, so the choice does not move the dasha here. It will on other '
        'charts.',
        icon: Icons.check_circle_outline,
      );
    }

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: strainedTint,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_vert, size: 17, color: strainedColor),
              const SizedBox(width: Gap.sm),
              Text('This choice moves the dasha',
                  style: Type.caption.copyWith(
                      color: strainedColor, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'On ${sample.input.name}’s chart the Moon sits in $here. '
            'Under ${differing.map((d) => d.label).take(3).join(', ')}'
            '${differing.length > 3 ? ' and others' : ''} it lands elsewhere, '
            'which changes the Vimshottari balance and every mahadasha date '
            'in the life.',
            style: Type.bodySoft,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Houses
// ---------------------------------------------------------------------------

class _HouseSection extends StatelessWidget {
  const _HouseSection({required this.settings, required this.cubit});
  final AppSettings settings;
  final SettingsCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          'Houses',
          subtitle: 'What gets divided into twelve — the ecliptic, the '
              'equator, the prime vertical, or time itself.',
        ),
        Text('Western chart', style: Type.caption),
        const SizedBox(height: Gap.sm),
        Card(
          child: Column(
            children: [
              for (final h in HouseSystem.values)
                if (h != HouseSystem.sripati)
                  _ChoiceTile(
                    title: h.label,
                    subtitle: h.principle,
                    selected: settings.chart.houseSystem == h,
                    trailing: h.failsAtHighLatitude
                        ? const _PolarChip()
                        : null,
                    onTap: () => cubit.setHouseSystem(h),
                  ),
            ],
          ),
        ),
        const SizedBox(height: Gap.lg),
        Text('Vedic chart', style: Type.caption),
        const SizedBox(height: Gap.sm),
        Card(
          child: Column(
            children: [
              for (final h in const [
                HouseSystem.wholeSign,
                HouseSystem.sripati,
                HouseSystem.equal,
                HouseSystem.placidus,
              ])
                _ChoiceTile(
                  title: h.label,
                  subtitle: h == HouseSystem.wholeSign
                      ? 'One sign, one bhava. The classical default.'
                      : h.principle,
                  selected: settings.chart.vedicHouseSystem == h,
                  onTap: () => cubit.setVedicHouseSystem(h),
                ),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        const QuietNote(
          'Whole sign and chalit disagree about roughly one planet in three '
          'charts, and that disagreement is the commonest reason two '
          'astrologers read the same kundali differently. The chart shows both '
          'rather than picking a side — look for the chalit column in the '
          'graha table.',
          icon: Icons.compare_arrows,
        ),
      ],
    );
  }
}

class _PolarChip extends StatelessWidget {
  const _PolarChip();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Undefined inside the polar circles. Charts there fall back to '
          'Porphyry, and say so.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: neutralTint,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text('polar limit', style: Type.micro),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Positions
// ---------------------------------------------------------------------------

class _PositionSection extends StatelessWidget {
  const _PositionSection({required this.settings, required this.cubit});
  final AppSettings settings;
  final SettingsCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Positions'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                value: settings.chart.trueNode,
                onChanged: cubit.setTrueNode,
                title: const Text('True lunar node'),
                subtitle: const Text(
                  'The true node oscillates around the mean by as much as '
                  '1°40′ — more than a nakshatra pada, so it can change Rahu’s '
                  'dasha position. Most Vedic schools use the mean node; KP '
                  'and most Western practice use the true one.',
                  style: Type.bodySoft,
                ),
                isThreeLine: true,
              ),
              const Divider(height: 1, color: hairline),
              SwitchListTile(
                value: settings.chart.topocentric,
                onChanged: cubit.setTopocentric,
                title: const Text('Topocentric positions'),
                subtitle: const Text(
                  'Seen from the birthplace rather than the centre of the '
                  'Earth. Almost nothing moves except the Moon, which can '
                  'shift by a full degree. KP is defined topocentrically.',
                  style: Type.bodySoft,
                ),
                isThreeLine: true,
              ),
              if (settings.chart.topocentric) ...[
                const Divider(height: 1, color: hairline),
                _ElevationRow(settings: settings, cubit: cubit),
              ],
              const Divider(height: 1, color: hairline),
              SwitchListTile(
                value: settings.chart.includeMinorBodies,
                onChanged: cubit.setMinorBodies,
                title: const Text('Chiron, Lilith and the asteroids'),
                subtitle: const Text(
                  'Chiron, Black Moon Lilith, Ceres, Pallas, Juno and Vesta. '
                  'Chiron’s orbit is genuinely chaotic and its position here '
                  'is approximate — see the accuracy note below.',
                  style: Type.bodySoft,
                ),
                isThreeLine: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ElevationRow extends StatelessWidget {
  const _ElevationRow({required this.settings, required this.cubit});
  final AppSettings settings;
  final SettingsCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Elevation', style: Type.body)),
              Text('${settings.chart.elevationMetres.round()} m',
                  style: Type.caption),
            ],
          ),
          Slider(
            value: settings.chart.elevationMetres.clamp(0, 5000),
            max: 5000,
            divisions: 50,
            label: '${settings.chart.elevationMetres.round()} m',
            onChanged: (v) => cubit.setElevation(v),
          ),
          Text(
            'Only matters above a few hundred metres, and only for the Moon.',
            style: Type.caption,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Display
// ---------------------------------------------------------------------------

class _DisplaySection extends StatelessWidget {
  const _DisplaySection({required this.settings, required this.cubit});
  final AppSettings settings;
  final SettingsCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('What the chart shows'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                value: settings.showChalit,
                onChanged: cubit.setShowChalit,
                title: const Text('Bhava chalit column'),
                subtitle: const Text(
                  'Shows the chalit house beside the whole-sign one, and marks '
                  'the grahas where the two disagree.',
                  style: Type.bodySoft,
                ),
              ),
              const Divider(height: 1, color: hairline),
              SwitchListTile(
                value: settings.showMinorAspects,
                onChanged: cubit.setMinorAspects,
                title: const Text('Minor aspects'),
                subtitle: const Text(
                  'Semi-sextile, semi-square, quintile, sesquiquadrate, '
                  'biquintile and quincunx.',
                  style: Type.bodySoft,
                ),
              ),
              const Divider(height: 1, color: hairline),
              SwitchListTile(
                value: settings.showDeclinations,
                onChanged: cubit.setShowDeclinations,
                title: const Text('Parallels of declination'),
                subtitle: const Text(
                  'Parallels behave like conjunctions and contraparallels like '
                  'oppositions, however far apart the two bodies are in '
                  'longitude.',
                  style: Type.bodySoft,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Orbs
// ---------------------------------------------------------------------------

class _OrbSection extends StatelessWidget {
  const _OrbSection({required this.settings, required this.cubit});
  final AppSettings settings;
  final SettingsCubit cubit;

  @override
  Widget build(BuildContext context) {
    final defs = settings.showMinorAspects ? allAspects : majorAspects;
    return DisclosurePanel(
      title: 'Orbs',
      subtitle: 'How wide an aspect counts. A matter of school, not of fact.',
      children: [
        Text(
          'These are the base orbs. The luminaries get a quarter more and the '
          'outer bodies rather less, so a Sun–Pluto square is judged on the '
          'Sun’s allowance.',
          style: Type.bodySoft,
        ),
        const SizedBox(height: Gap.md),
        for (final d in defs) _OrbSlider(def: d, settings: settings, cubit: cubit),
        const SizedBox(height: Gap.sm),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: cubit.resetOrbs,
            child: const Text('Restore default orbs'),
          ),
        ),
      ],
    );
  }
}

class _OrbSlider extends StatelessWidget {
  const _OrbSlider({
    required this.def,
    required this.settings,
    required this.cubit,
  });
  final AspectDef def;
  final AppSettings settings;
  final SettingsCubit cubit;

  @override
  Widget build(BuildContext context) {
    final value = settings.orbs.baseFor(def);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        children: [
          SizedBox(
            width: 128,
            child: Text(
              '${def.glyph.isEmpty ? '' : '${def.glyph}  '}${def.name}',
              style: Type.body,
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(0.5, 12.0),
              min: 0.5,
              max: 12,
              divisions: 23,
              onChanged: (v) => cubit.setAspectOrb(def.name, v),
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              '${value.toStringAsFixed(1)}°',
              textAlign: TextAlign.right,
              style: Type.caption.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Accuracy
// ---------------------------------------------------------------------------

class _AccuracyNote extends StatelessWidget {
  const _AccuracyNote();

  @override
  Widget build(BuildContext context) {
    return DisclosurePanel(
      title: 'How accurate is this?',
      subtitle: 'Measured, not asserted.',
      children: [
        Text(
          'Positions are computed on the device from a truncated VSOP87 solar '
          'theory and the full Meeus lunar series, with ΔT, nutation, '
          'aberration and light-time applied. The conformance suite checks '
          'them against Meeus’s published worked examples on every build.',
          style: Type.bodySoft,
        ),
        const SizedBox(height: Gap.md),
        const _AccuracyRow('Sun', 'about 2 arcseconds'),
        const _AccuracyRow('Moon', 'about 10 arcseconds'),
        const _AccuracyRow('Mercury to Mars', 'about 1 arcminute'),
        const _AccuracyRow('Jupiter to Pluto', 'about 2 arcminutes'),
        const _AccuracyRow('Chiron and the asteroids',
            'approximate — no perturbations, so up to a degree over a century'),
        const SizedBox(height: Gap.md),
        Text(
          'That is natal-chart grade. It is not Swiss Ephemeris grade for the '
          'planets, and the app says so rather than implying otherwise. A '
          'position accurate to an arcminute will never move a graha into a '
          'different sign or nakshatra except within an arcminute of the '
          'boundary — and where that happens, the chart flags it.',
          style: Type.bodySoft,
        ),
      ],
    );
  }
}

class _AccuracyRow extends StatelessWidget {
  const _AccuracyRow(this.body, this.accuracy);
  final String body;
  final String accuracy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(body, style: Type.body)),
          Expanded(child: Text(accuracy, style: Type.caption)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.trailing,
  });
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.lg, Gap.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: selected ? navy : inkFaint,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Type.body.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Type.caption),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: Gap.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

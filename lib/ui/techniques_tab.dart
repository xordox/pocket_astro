/// The index of deeper techniques.
///
/// A professional tool has more surface than a phone tab bar can carry. Rather
/// than cramming five more tabs in, this one tab is a menu — and the menu
/// earns its place by saying what each technique is *for*.
///
/// That framing is the whole design. "Shodashavarga" and "zodiacal releasing"
/// are names, and a name is only useful to someone who already knows it. "Read
/// marriage from the navamsa, career from the dashamsa" is an invitation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/models.dart';
import '../engine/astronomy.dart';
import '../engine/dasha.dart';
import '../engine/tables.dart';
import '../state/settings_cubit.dart';
import '../theme/tokens.dart';
import 'calendar_screen.dart';
import 'consultations_screen.dart';
import 'ephemeris_screen.dart';
import 'horary_screen.dart';
import 'kp_screen.dart';
import 'muhurta_screen.dart';
import 'rectification_screen.dart';
import 'schools_screen.dart';
import 'settings_screen.dart';
import 'strength_screen.dart';
import 'timeline_screen.dart';
import 'vargas_screen.dart';
import 'varshaphal_screen.dart';
import 'wheel_screen.dart';
import 'widgets/atoms.dart';
import 'widgets/provenance.dart';

class TechniquesTab extends StatelessWidget {
  const TechniquesTab({super.key, required this.chart});
  final NatalChart chart;

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final recommendation = recommendDasha(chart);
    final ashtottari = chart.input.timeUnknown
        ? null
        : ashtottariApplies(chart);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.xxl),
      children: [
        if (chart.input.timeUnknown) ...[
          const UnknownTimeNotice(),
          const SizedBox(height: Gap.lg),
        ],
        const SectionHeader(
          'Go deeper',
          subtitle: 'Each of these answers a different question. Pick the '
              'question.',
        ),
        _TechniqueCard(
          title: 'Divisional charts',
          subtitle: 'Sixteen vargas',
          body: 'Marriage from the navamsa, children from the saptamsa, career '
              'from the dashamsa, the final word on strength from the '
              'shashtiamsa.',
          icon: Icons.grid_view_rounded,
          onTap: () => _open(context, VargasScreen(chart: chart)),
        ),
        _TechniqueCard(
          title: 'Strength',
          subtitle: 'Shadbala, avasthas, ashtakavarga reductions',
          body: 'Which graha actually delivers, measured against the minimum '
              'the classics set for it — and what combustion, planetary war '
              'and retrogradation do to that.',
          icon: Icons.straighten,
          onTap: () => _open(context, StrengthScreen(chart: chart)),
        ),
        _TechniqueCard(
          title: 'Timeline',
          subtitle: 'Exact dates, stations, eclipses',
          body: 'Not "Saturn is squaring your Sun" but the three dates it '
              'perfects, and which of them settles the matter.',
          icon: Icons.timeline,
          onTap: () => _open(context, TimelineScreen(chart: chart)),
        ),
        _TechniqueCard(
          title: 'Western wheel',
          subtitle: 'Natal, transits and progressions',
          body: 'The chart in the form Western practice reads it, with today’s '
              'sky or the progressed chart on the outer ring.',
          icon: Icons.donut_large,
          onTap: () => _open(context, WheelScreen(chart: chart)),
          enabled: !chart.input.timeUnknown,
          disabledReason: 'A wheel is mostly a picture of the houses.',
        ),
        _TechniqueCard(
          title: 'Varshaphal',
          subtitle: 'The annual chart, in the Tajika tradition',
          body: 'The solar return, the Muntha, the year lord, and which '
              'matters complete this year rather than having already slipped.',
          icon: Icons.cake_outlined,
          onTap: () => _open(context, VarshaphalScreen(chart: chart)),
        ),
        _TechniqueCard(
          title: 'KP',
          subtitle: 'Sub-lords, significators, horary',
          body: 'Krishnamurti Paddhati, recast under its own ayanamsa and '
              'cusps. The cuspal sub-lord decides whether a house delivers at '
              'all.',
          icon: Icons.tag,
          onTap: () => _open(context, KpScreen(input: chart.input)),
        ),
        _TechniqueCard(
          title: 'Choose a moment',
          subtitle: 'Muhurta — electional search',
          body: 'Search forward for a good time to marry, travel, sign or '
              'begin, filtered against this person’s own Moon.',
          icon: Icons.event_available_outlined,
          onTap: () => _open(context, MuhurtaScreen(
            place: chart.input.place,
            native: chart,
          )),
        ),
        _TechniqueCard(
          title: 'Sessions',
          subtitle: 'What you discussed, and when',
          body: 'Dated notes rather than one growing field, so the second '
              'appointment can start from the first.',
          icon: Icons.history_edu_outlined,
          onTap: () =>
              _open(context, ConsultationsScreen(input: chart.input)),
        ),
        _TechniqueCard(
          title: 'Rectify the birth time',
          subtitle: 'Sensitivity and event fitting',
          body: 'Find out whether the time even matters here, then score '
              'candidate times against dated life events.',
          icon: Icons.schedule_outlined,
          onTap: () => _open(context, RectificationScreen(input: chart.input)),
        ),
        _TechniqueCard(
          title: 'Horary',
          subtitle: 'A question, cast for the moment it was asked',
          body: 'The traditional Western method: considerations before '
              'judgment, significators, and whether the matter perfects — by '
              'application, translation or collection.',
          icon: Icons.contact_support_outlined,
          onTap: () => _open(context, HoraryScreen(place: chart.input.place)),
        ),
        _TechniqueCard(
          title: 'Calendar',
          subtitle: 'Months, years, seasons, festivals',
          body: 'Samvatsara, Shaka and Vikram years, ritu and ayana, '
              'sankrantis, and the festivals — with both the amanta and '
              'purnimanta month names, because they disagree every dark '
              'fortnight.',
          icon: Icons.calendar_month_outlined,
          onTap: () => _open(context, CalendarScreen(place: chart.input.place)),
        ),
        _TechniqueCard(
          title: 'Ephemeris',
          subtitle: 'Positions, ingresses, stations, sunrise',
          body: 'A month at a time, to scan rather than query. Half of what an '
              'ephemeris is for is noticing what you were not looking for.',
          icon: Icons.table_chart_outlined,
          onTap: () => _open(context, EphemerisScreen(
            place: chart.input.place,
            settings: chart.settings,
          )),
        ),
        _TechniqueCard(
          title: 'Other schools',
          subtitle: 'Jaimini, traditional Western, time lords, harmonics',
          body: 'Chara karakas and arudha padas; sect, essential dignity and '
              'the lots; profections, zodiacal releasing and firdaria.',
          icon: Icons.account_tree_outlined,
          onTap: () => _open(context, SchoolsScreen(chart: chart)),
        ),
        const SizedBox(height: Gap.xl),
        const SectionHeader('Which dasha system fits this chart?'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recommendation.reason, style: Type.body),
                if (ashtottari != null) ...[
                  const Divider(height: Gap.lg, color: hairline),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        ashtottari.applies
                            ? Icons.check_circle_outline
                            : Icons.remove_circle_outline,
                        size: 17,
                        color: ashtottari.applies ? beneficColor : inkFaint,
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(ashtottari.reason, style: Type.bodySoft),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: Gap.sm),
                Text(
                  'Kalachakra is deliberately absent. Its rashi groups and '
                  'year counts vary enough between schools that shipping one '
                  'version would be asserting a position rather than computing '
                  'a result.',
                  style: Type.micro,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.xl),
        ProvenancePanel(chart: chart),
        const SizedBox(height: Gap.md),
        BlocBuilder<SettingsCubit, AppSettings>(
          builder: (context, settings) => OutlinedButton.icon(
            onPressed: () => _open(
                context, SettingsScreen(sampleChart: chart)),
            icon: const Icon(Icons.tune, size: 18),
            label: Text(settings.isDefault
                ? 'Calculation settings'
                : 'Calculation settings — changed'),
          ),
        ),
      ],
    );
  }
}

class _TechniqueCard extends StatelessWidget {
  const _TechniqueCard({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.disabledReason = '',
  });

  final String title;
  final String subtitle;
  final String body;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final String disabledReason;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: paperRaised,
          borderRadius: BorderRadius.circular(Radii.card),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(Radii.card),
            child: Container(
              padding: const EdgeInsets.all(Gap.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: hairline),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(Radii.chip),
                    ),
                    child: Icon(icon, size: 19, color: navy),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Type.title),
                        Text(subtitle, style: Type.micro),
                        const SizedBox(height: Gap.xs),
                        Text(
                          enabled ? body : '$body $disabledReason',
                          style: Type.bodySoft,
                        ),
                      ],
                    ),
                  ),
                  if (enabled)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.chevron_right, color: inkFaint),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gap G-39 — how the app behaves when the birth time is unknown.
///
/// The old build set every house to zero and cast a noon chart, so a reader
/// got a chart that silently omitted a third of its meaning. The professional
/// convention is to say what is *still* true, and to mark what is not.
class UnknownTimeNotice extends StatelessWidget {
  const UnknownTimeNotice({super.key, this.chart});
  final NatalChart? chart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: strainedTint,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border(left: BorderSide(color: strainedColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 18, color: strainedColor),
              const SizedBox(width: Gap.sm),
              Text('No birth time',
                  style: Type.title.copyWith(color: strainedColor)),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'This chart is cast for noon. That makes the houses, the '
            'ascendant, the divisional lagnas and everything measured from '
            'them unavailable — not approximate, unavailable.',
            style: Type.bodySoft,
          ),
          const SizedBox(height: Gap.sm),
          Text('What still holds:', style: Type.caption.copyWith(
              fontWeight: FontWeight.w700, color: ink)),
          const SizedBox(height: Gap.xs),
          const _Holds('Every graha’s sign, unless it changed sign that day.'),
          const _Holds('The aspects between grahas, within a degree or so.'),
          const _Holds(
              'The Moon’s nakshatra, if it did not cross a boundary — and with '
              'it the whole Vimshottari sequence.'),
          if (chart != null) ...[
            const SizedBox(height: Gap.sm),
            _AscendantRange(chart: chart!),
          ],
        ],
      ),
    );
  }
}

class _Holds extends StatelessWidget {
  const _Holds(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.check, size: 13, color: beneficColor),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text(text, style: Type.caption)),
        ],
      ),
    );
  }
}

/// Which ascendants were possible on the day — the honest alternative to
/// pretending there is one.
class _AscendantRange extends StatelessWidget {
  const _AscendantRange({required this.chart});
  final NatalChart chart;

  @override
  Widget build(BuildContext context) {
    final midnight = DateTime.utc(
        chart.utc.year, chart.utc.month, chart.utc.day);
    final signsSeen = <int>{};
    for (var h = 0; h < 24; h++) {
      final sky = computeSky(
        utc: midnight.add(Duration(hours: h)),
        latitude: chart.input.place.latitude,
        longitudeEast: chart.input.place.longitude,
        settings: chart.settings,
        bodyNames: const ['Sun'],
      );
      signsSeen.add(signIndex(sky.siderealAscendant));
    }

    return Text(
      'On this date at ${chart.input.place.label} the lagna passed through '
      '${signsSeen.length} signs. Any of them is possible. Rectification, or a '
      'prashna chart cast for the moment the question is asked, is the way '
      'forward here.',
      style: Type.caption.copyWith(fontStyle: FontStyle.italic),
    );
  }
}

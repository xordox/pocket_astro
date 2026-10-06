import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../data/pdf_export.dart';
import '../domain/models.dart';
import '../engine/astronomy.dart';
import '../engine/forecast.dart';
import '../engine/house_quality.dart';
import '../engine/interpret.dart';
import '../engine/learn.dart';
import '../engine/nature.dart';
import '../engine/tables.dart';
import '../engine/today.dart';
import '../engine/yoga.dart';
import '../l10n/engine_strings.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/library_bloc.dart';
import '../state/settings_cubit.dart';
import '../theme/tokens.dart';
import 'learn_tab.dart';
import 'today_tab.dart';
import 'widgets/ask_panel.dart';
import 'widgets/atoms.dart';
import 'techniques_tab.dart';
import 'wheel_screen.dart';
import 'widgets/charts.dart';
import 'widgets/kundali.dart';
import 'widgets/provenance.dart';

class ChartScreen extends StatelessWidget {
  const ChartScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LibraryBloc, LibraryState>(
      builder: (context, state) {
        BirthInput? input;
        for (final e in state.profiles) {
          if (e.id == id) input = e;
        }
        if (input == null) {
          return Scaffold(
            appBar: AppBar(title: Text(L.of(context).tabKundali)),
            body: Center(
              child: state is LibraryReady
                  ? Text(L.of(context).notFound)
                  : const CircularProgressIndicator(),
            ),
          );
        }
        final resolved = input;
        return BlocBuilder<SettingsCubit, AppSettings>(
          builder: (context, settings) =>
              _ChartBody(input: resolved, settings: settings.chart),
        );
      },
    );
  }
}

/// Everything derived from the birth data is computed once and held, rather
/// than recomputed on every rebuild. Building a chart runs an ephemeris, a
/// dasha tree, 77 yoga conditions and an ashtakavarga; that is not work to
/// repeat when a tab changes.
class _ChartBody extends StatefulWidget {
  const _ChartBody({required this.input, required this.settings});
  final BirthInput input;

  /// The reader's calculation choices. Held on the widget rather than read
  /// from context inside [_recompute] so that a settings change rebuilds the
  /// chart through [didUpdateWidget] instead of silently going stale (G-46).
  final ChartSettings settings;

  @override
  State<_ChartBody> createState() => _ChartBodyState();
}

class _ChartBodyState extends State<_ChartBody> {
  late NatalChart chart;
  late DateTime now;
  late List<LifeArea> areas;
  late ForecastReport forecast;
  late List<HouseReading> houses;
  late YogaReport yogas;
  late TodayReport today;
  late Syllabus syllabus;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void didUpdateWidget(covariant _ChartBody old) {
    super.didUpdateWidget(old);
    if (old.input != widget.input || old.settings != widget.settings) {
      _recompute();
    }
  }

  void _recompute() {
    now = DateTime.now().toUtc();
    chart = chartFor(widget.input, settings: widget.settings);
    areas = interpretChart(chart, now: now);
    forecast = forecastChart(chart, now: now);
    houses = readHouses(chart);
    yogas = yogaReport(chart);
    today = todayFor(chart, now: now);
    syllabus = syllabusFor(chart);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return DefaultTabController(
      length: 8,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.input.name),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l.tabOverview),
              Tab(text: l.tabToday),
              Tab(text: l.tabKundali),
              Tab(text: l.tabLifeAreas),
              Tab(text: l.tabTiming),
              const Tab(text: 'Techniques'),
              Tab(text: l.tabAsk),
              Tab(text: l.tabLearn),
            ],
          ),
          actions: [
            IconButton(
              tooltip: l.savePdf,
              onPressed: () async {
                final bytes = await buildReportPdf(chart: chart);
                await Printing.layoutPdf(onLayout: (_) async => bytes);
              },
              icon: const Icon(Icons.ios_share_rounded),
            ),
            IconButton(
              tooltip: l.editChart,
              onPressed: () => context.push('/edit/${widget.input.id}'),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _OverviewTab(
              chart: chart,
              now: now,
              houses: houses,
              yogas: yogas,
            ),
            TodayTab(report: today),
            _KundaliTab(chart: chart, houses: houses),
            _LifeTab(houses: houses, areas: areas),
            _TimingTab(chart: chart, now: now, forecast: forecast),
            TechniquesTab(chart: chart),
            AskPanel(chart: chart),
            LearnTab(syllabus: syllabus),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Overview
// ===========================================================================

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.chart,
    required this.now,
    required this.houses,
    required this.yogas,
  });

  final NatalChart chart;
  final DateTime now;
  final List<HouseReading> houses;
  final YogaReport yogas;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final md = chart.mahadashaAt(now);
    final ad = chart.antardashaAt(now);
    final moon = chart.graha('Moon');
    final noTime = chart.input.timeUnknown;

    final supported = houses.where((h) => h.band == HouseBand.prosperous).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final strained = houses.where((h) => h.band == HouseBand.strained).toList()
      ..sort((a, b) => a.score.compareTo(b.score));
    final standout = yogas.standing.where((y) => y.weight >= 4).take(3).toList();

    return ListView(
      key: const PageStorageKey('overview'),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
      children: [
        _IdentityCard(chart: chart, moon: moon),
        const SizedBox(height: Gap.md),
        if (md != null) ...[
          _PeriodCard(md: md, ad: ad, now: now),
          const SizedBox(height: Gap.md),
        ],
        if (noTime) ...[
          QuietNote(l.noTimeNote, icon: Icons.schedule_outlined),
          const SizedBox(height: Gap.md),
        ],
        if (supported.isNotEmpty || strained.isNotEmpty) ...[
          SectionHeader(l.whatSupports, subtitle: l.whatSupportsSub),
          if (supported.isNotEmpty)
            _HouseStrip(readings: supported.take(3).toList()),
          if (supported.isNotEmpty && strained.isNotEmpty)
            const SizedBox(height: Gap.sm),
          if (strained.isNotEmpty)
            _HouseStrip(readings: strained.take(2).toList()),
          const SizedBox(height: Gap.lg),
        ],
        if (standout.isNotEmpty) ...[
          SectionHeader(l.standoutPatterns, subtitle: l.standoutPatternsSub),
          for (final y in standout) ...[
            ExplainCard(
              title: y.name,
              lead: y.effect,
              detail: '${y.detail}\n\n${y.strength ?? ''}\n\nSource: ${y.source}',
              accent: prosperousColor,
            ),
            const SizedBox(height: Gap.sm),
          ],
          const SizedBox(height: Gap.sm),
        ],
        QuietNote(l.disclaimerOffline, icon: Icons.shield_outlined),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.chart, required this.moon});

  final NatalChart chart;
  final GrahaRow moon;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final noTime = chart.input.timeUnknown;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              noTime
                  ? l.moonTitle(signNameOf(moon.sign))
                  : l.risingTitle(signName(signIndex(chart.lagnaSidereal))),
              style: Type.display,
            ),
            const SizedBox(height: Gap.xs),
            Text(
              noTime
                  ? l.noTimeLead
                  : l.moonSunLine(
                      signNameOf(moon.sign),
                      signNameOf(chart.graha('Sun').sign),
                    ),
              style: Type.lead,
            ),
            const SizedBox(height: Gap.md),
            const Divider(),
            const SizedBox(height: Gap.md),
            _MetaRow(
              icon: Icons.event_outlined,
              text: DateFormat('d MMMM yyyy').format(chart.input.localDateTime) +
                  (noTime
                      ? ''
                      : ', ${DateFormat('HH:mm').format(chart.input.localDateTime)}'),
            ),
            const SizedBox(height: 6),
            _MetaRow(
              icon: Icons.place_outlined,
              text: chart.input.place.label,
            ),
            const SizedBox(height: 6),
            _MetaRow(
              icon: Icons.nightlight_outlined,
              text: l.birthStarLine(
                nakshatraName(moon.nakshatra),
                '${moon.pada}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: inkFaint),
        const SizedBox(width: Gap.sm),
        Expanded(child: Text(text, style: Type.bodySoft)),
      ],
    );
  }
}

/// The running mahadasha, with how far through it you are.
class _PeriodCard extends StatelessWidget {
  const _PeriodCard({required this.md, required this.ad, required this.now});

  final DashaSpan md;
  final DashaSpan? ad;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final total = md.end.difference(md.start).inDays;
    final used = now.difference(md.start).inDays;
    final progress = total <= 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    final years = (md.end.difference(now).inDays / 365.25);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: grahaColor(md.lord).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    shortName(md.lord),
                    style: Type.glyph.copyWith(color: grahaColor(md.lord)),
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.periodTitle(grahaName(md.lord)),
                          style: Type.title),
                      Text(
                        ad == null
                            ? l.periodRange(
                                DateFormat.y().format(md.start),
                                DateFormat.y().format(md.end),
                              )
                            : l.periodSub(
                                grahaName(ad!.lord),
                                DateFormat.yMMM().format(ad!.end),
                              ),
                        style: Type.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: hairline,
                valueColor: AlwaysStoppedAnimation(grahaColor(md.lord)),
              ),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              years < 0
                  ? l.periodClosed
                  : l.periodProgress(
                      '${(progress * 100).round()}',
                      years.toStringAsFixed(1),
                    ),
              style: Type.caption,
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact row of house cards used on the overview.
class _HouseStrip extends StatelessWidget {
  const _HouseStrip({required this.readings});

  final List<HouseReading> readings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final r in readings)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: _HouseTile(reading: r),
          ),
      ],
    );
  }
}

class _HouseTile extends StatelessWidget {
  const _HouseTile({required this.reading});

  final HouseReading reading;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = BandPill.colorsFor(reading.band);
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.card),
      onTap: () => showHouseSheet(context, reading),
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: fg.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '${reading.house}',
                style: Type.glyph.copyWith(color: fg),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reading.plainTitle, style: Type.body.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
                  Text(reading.summary, style: Type.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: inkFaint, size: 20),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Kundali
// ===========================================================================

class _KundaliTab extends StatefulWidget {
  const _KundaliTab({required this.chart, required this.houses});

  final NatalChart chart;
  final List<HouseReading> houses;

  @override
  State<_KundaliTab> createState() => _KundaliTabState();
}

class _KundaliTabState extends State<_KundaliTab> {
  KundaliStyle _style = KundaliStyle.north;
  String? _selected;
  bool _quality = true;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final chart = widget.chart;
    final nature = GrahaNature({
      for (final g in chart.grahas)
        if (navagraha.contains(g.name)) g.name: g.siderealLon,
    });

    return ListView(
      key: const PageStorageKey('kundali'),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
      children: [
        SegmentedButton<KundaliStyle>(
          segments: [
            ButtonSegment(
              value: KundaliStyle.north,
              label: Text(l.northIndian),
              icon: const Icon(Icons.change_history_rounded, size: 16),
            ),
            ButtonSegment(
              value: KundaliStyle.south,
              label: Text(l.southIndian),
              icon: const Icon(Icons.grid_4x4_rounded, size: 16),
            ),
          ],
          selected: {_style},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _style = s.first),
        ),
        const SizedBox(height: Gap.sm),
        Text(
          _style == KundaliStyle.north ? l.hintNorth : l.hintSouth,
          style: Type.caption,
        ),
        const SizedBox(height: Gap.lg),
        Center(
          child: KundaliChart(
            chart: chart,
            style: _style,
            readings: widget.houses,
            selectedPlanet: _selected,
            showQuality: _quality,
            onPlanetTap: (p) => setState(
              () => _selected = _selected == p ? null : p,
            ),
            onHouseTap: (h) {
              final r = widget.houses.where((x) => x.house == h).firstOrNull;
              if (r != null) showHouseSheet(context, r);
            },
          ),
        ),
        const SizedBox(height: Gap.lg),
        Row(
          children: [
            Expanded(child: ChartLegend(showQuality: _quality)),
            IconButton(
              tooltip: _quality ? l.hideShading : l.showShading,
              onPressed: () => setState(() => _quality = !_quality),
              icon: Icon(
                _quality ? Icons.palette_rounded : Icons.palette_outlined,
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        SectionHeader(l.tapGraha, subtitle: l.tapGrahaSub),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final name in navagraha)
              if (chart.grahas.any((g) => g.name == name))
                _GrahaChip(
                  name: name,
                  benefic: nature.isBenefic(name),
                  selected: _selected == name,
                  onTap: () => setState(
                    () => _selected = _selected == name ? null : name,
                  ),
                ),
          ],
        ),
        if (_selected != null) ...[
          const SizedBox(height: Gap.md),
          _GrahaDetail(
            chart: chart,
            planet: _selected!,
            nature: nature,
            houses: widget.houses,
          ),
        ],
        const SizedBox(height: Gap.xl),
        _AdvancedPanel(chart: chart),
      ],
    );
  }
}

class _GrahaChip extends StatelessWidget {
  const _GrahaChip({
    required this.name,
    required this.benefic,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool benefic;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = benefic ? beneficColor : maleficColor;
    return Material(
      color: selected ? color : (benefic ? beneficTint : maleficTint),
      borderRadius: BorderRadius.circular(Radii.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.chip),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : grahaColor(name),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                grahaName(name),
                style: Type.caption.copyWith(
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrahaDetail extends StatelessWidget {
  const _GrahaDetail({
    required this.chart,
    required this.planet,
    required this.nature,
    required this.houses,
  });

  final NatalChart chart;
  final String planet;
  final GrahaNature nature;
  final List<HouseReading> houses;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final row = chart.graha(planet);
    final benefic = nature.isBenefic(planet);
    final reached = aspectedHouses(chart, planet);

    return ExplainCard(
      title: grahaName(planet),
      accent: benefic ? beneficColor : maleficColor,
      lead: row.house == 0
          ? '${signNameOf(row.sign)} · ${nakshatraName(row.nakshatra)} '
              '${row.pada}'
          : '${signNameOf(row.sign)} · ${l.houseNumber('${row.house}')} — '
              '${houseTopic(row.house)}',
      badge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (benefic ? beneficColor : maleficColor).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          benefic ? l.helpfulHere : l.demandingHere,
          style: Type.micro.copyWith(
            color: benefic ? beneficColor : maleficColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      detail: '${nature.reasonFor(planet)}\n\n${aspectExplanation(planet)}'
          '${row.dignity.isEmpty ? '' : '\n\n${l.colDignity}: ${row.dignity}.'}',
      detailLabel: l.whyColour,
      child: reached.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.influencesHouses('${reached.length}'),
                  style: Type.caption.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: Gap.sm),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    for (final h in reached)
                      _AspectTarget(
                        house: h,
                        label: houses
                                .where((r) => r.house == h)
                                .map((r) => r.plainTitle)
                                .firstOrNull ??
                            houseTopic(h),
                        band: houses
                            .where((r) => r.house == h)
                            .map((r) => r.band)
                            .firstOrNull,
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _AspectTarget extends StatelessWidget {
  const _AspectTarget({
    required this.house,
    required this.label,
    required this.band,
  });

  final int house;
  final String label;
  final HouseBand? band;

  @override
  Widget build(BuildContext context) {
    final color = band == null ? inkSoft : BandPill.colorsFor(band!).$1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 5),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$house', style: Type.glyph.copyWith(color: color)),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              label,
              style: Type.micro.copyWith(color: ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The old developer tables, folded away. They are still exact and still
/// available; they simply are not the first thing a reader meets.
class _AdvancedPanel extends StatelessWidget {
  const _AdvancedPanel({required this.chart});

  final NatalChart chart;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return DisclosurePanel(
      title: l.advancedTitle,
      subtitle: l.advancedSub,
      children: [
          const SizedBox(height: Gap.sm),
          Text(chart.engineStamp, style: Type.micro),
          const SizedBox(height: Gap.md),
          SingleChildScrollView(
            // Its own storage key, so its offset can never share a bucket
            // entry with an ancestor's state.
            key: const PageStorageKey('positions-table'),
            scrollDirection: Axis.horizontal,
            child: BlocBuilder<SettingsCubit, AppSettings>(
              builder: (context, settings) {
                final showChalit = settings.showChalit &&
                    chart.grahas.any((g) => g.chalitHouse != 0);
                return DataTable(
                  headingTextStyle:
                      Type.micro.copyWith(fontWeight: FontWeight.w700),
                  dataTextStyle: Type.caption.copyWith(color: ink),
                  columnSpacing: 16,
                  columns: [
                    DataColumn(label: Text(l.colGraha)),
                    DataColumn(label: Text(l.colSidereal)),
                    // Motion was not knowable before G-01; it is the first
                    // thing a jyotishi looks for after the sign.
                    const DataColumn(label: Text('Motion')),
                    DataColumn(label: Text(l.colHouse)),
                    if (showChalit) const DataColumn(label: Text('Chalit')),
                    DataColumn(label: Text(l.colNakshatra)),
                    DataColumn(label: Text(l.colDignity)),
                  ],
                  rows: [
                    for (final g in chart.grahas)
                      DataRow(cells: [
                        DataCell(Text(
                          grahaName(g.name),
                          style: Type.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: grahaColor(g.name),
                          ),
                        )),
                        DataCell(Text(
                            '${signNameOf(g.sign)} ${formatDms(g.siderealLon)}')),
                        DataCell(_MotionCell(graha: g)),
                        DataCell(Text(g.house == 0 ? '—' : '${g.house}')),
                        if (showChalit)
                          DataCell(_ChalitCell(graha: g)),
                        DataCell(
                            Text('${nakshatraName(g.nakshatra)} ${g.pada}')),
                        DataCell(Text(g.dignity.isEmpty ? '—' : g.dignity)),
                      ]),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: Gap.sm),
          const _ChalitFootnote(),
          const SizedBox(height: Gap.lg),
          Text(l.westernWheelTitle, style: Type.title),
          const SizedBox(height: Gap.sm),
          Center(child: WesternWheel(chart: chart)),
          const SizedBox(height: Gap.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => WheelScreen(chart: chart)),
              ),
              icon: const Icon(Icons.donut_large, size: 18),
              label: const Text('Open the full wheel'),
            ),
          ),
          const SizedBox(height: Gap.sm),
          for (final a in chart.westernAspects.take(10))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${grahaName(a.a)} ${a.name} ${grahaName(a.b)} · orb '
                '${a.orb.toStringAsFixed(1)}° · ${a.motion}',
                style: Type.caption,
              ),
            ),
          const SizedBox(height: Gap.lg),
          ProvenancePanel(chart: chart),
      ],
    );
  }
}

// ===========================================================================
// House detail sheet
// ===========================================================================

Future<void> showHouseSheet(BuildContext context, HouseReading r) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (context, controller) => ListView(
        key: const PageStorageKey('house-sheet'),
        controller: controller,
        padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.xxl),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  L.of(context).houseNumber('${r.house}'),
                  style: Type.caption,
                ),
              ),
              BandPill(r.band),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(r.plainTitle, style: Type.display),
          const SizedBox(height: Gap.sm),
          Text(r.summary, style: Type.lead),
          const SizedBox(height: Gap.lg),
          _SheetFact(
            label: L.of(context).sheetSign,
            value: '${signName(r.sign)} (${signs[r.sign].sanskrit})',
          ),
          _SheetFact(
            label: L.of(context).sheetRuledBy,
            value: r.lordHouse == 0
                ? grahaName(r.lord)
                : L.of(context)
                    .sheetRulerIn(grahaName(r.lord), '${r.lordHouse}'),
          ),
          _SheetFact(
            label: L.of(context).sheetGrahasHere,
            value: r.occupants.isEmpty
                ? L.of(context).sheetNoGrahas
                : r.occupants.map(grahaName).join(', '),
          ),
          if (r.aspectedBy.isNotEmpty)
            _SheetFact(
              label: L.of(context).sheetInfluencedBy,
              value: r.aspectedBy.map(grahaName).join(', '),
            ),
          if (r.savBindus != null)
            _SheetFact(
              label: L.of(context).sheetPointCount,
              value: L.of(context).sheetPointValue('${r.savBindus}'),
            ),
          _SheetFact(label: L.of(context).sheetTopics, value: r.topic),
          const SizedBox(height: Gap.lg),
          if (r.supporting.isNotEmpty) ...[
            Text(L.of(context).whatHelps, style: Type.title),
            const SizedBox(height: Gap.sm),
            for (final reason in r.supporting)
              _ReasonRow(text: reason.text, positive: true),
            const SizedBox(height: Gap.md),
          ],
          if (r.pressures.isNotEmpty) ...[
            Text(L.of(context).whatPresses, style: Type.title),
            const SizedBox(height: Gap.sm),
            for (final reason in r.pressures)
              _ReasonRow(text: reason.text, positive: false),
            const SizedBox(height: Gap.md),
          ],
          QuietNote(L.of(context).houseSheetNote),
        ],
      ),
    ),
  );
}

class _SheetFact extends StatelessWidget {
  const _SheetFact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: Type.caption),
          ),
          Expanded(child: Text(value, style: Type.body)),
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({required this.text, required this.positive});
  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? prosperousColor : strainedColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(
              positive
                  ? Icons.add_circle_outline_rounded
                  : Icons.remove_circle_outline_rounded,
              size: 15,
              color: color,
            ),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text(text, style: Type.body)),
        ],
      ),
    );
  }
}

// ===========================================================================
// Life areas
// ===========================================================================

class _LifeTab extends StatelessWidget {
  const _LifeTab({required this.houses, required this.areas});

  final List<HouseReading> houses;
  final List<LifeArea> areas;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (houses.isEmpty) {
      return ListView(
        key: const PageStorageKey('life-no-time'),
        padding: const EdgeInsets.all(Gap.lg),
        children: [
          QuietNote(l.lifeNoTimeNote, icon: Icons.schedule_outlined),
          const SizedBox(height: Gap.lg),
          for (final a in areas.where(_readableArea)) ...[
            ExplainCard(
              title: a.title,
              lead: _leadOf(a.body),
              detail: a.body,
              badge: ConfidenceMeter(a.confidence),
            ),
            const SizedBox(height: Gap.sm),
          ],
        ],
      );
    }

    return ListView(
      key: const PageStorageKey('life'),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
      children: [
        SectionHeader(l.twelveAreas, subtitle: l.twelveAreasSub),
        for (final r in houses) ...[
          _HouseTile(reading: r),
          const SizedBox(height: Gap.sm),
        ],
        const SizedBox(height: Gap.lg),
        SectionHeader(l.readingsInFull, subtitle: l.readingsInFullSub),
        for (final a in areas.where(_readableArea)) ...[
          ExplainCard(
            title: a.title,
            lead: _leadOf(a.body),
            detail: a.body,
            badge: ConfidenceMeter(a.confidence),
          ),
          const SizedBox(height: Gap.sm),
        ],
      ],
    );
  }

  /// The engine emits a couple of machine-facing areas; a reader does not need
  /// the ephemeris stamp or the forecast duplicated here.
  static bool _readableArea(LifeArea a) =>
      a.title != 'Engine' && !a.title.startsWith('Predict · ');

  /// First sentence as the lead, the rest folded away.
  static String _leadOf(String body) {
    final cut = body.indexOf('. ');
    if (cut <= 0 || cut > 220) {
      return body.length > 200 ? '${body.substring(0, 200)}…' : body;
    }
    return body.substring(0, cut + 1);
  }
}

// ===========================================================================
// Timing
// ===========================================================================

class _TimingTab extends StatelessWidget {
  const _TimingTab({
    required this.chart,
    required this.now,
    required this.forecast,
  });

  final NatalChart chart;
  final DateTime now;
  final ForecastReport forecast;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final md = chart.mahadashaAt(now);
    final ad = chart.antardashaAt(now);
    final subs =
        chart.antardashas.where((a) => a.parent == md?.lord).toList();

    return ListView(
      key: const PageStorageKey('timing'),
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xxl),
      children: [
        if (md != null) ...[
          _PeriodCard(md: md, ad: ad, now: now),
          const SizedBox(height: Gap.lg),
        ],
        SectionHeader(l.lifeInPeriods, subtitle: l.lifeInPeriodsSub),
        _DashaTimeline(chart: chart, now: now),
        const SizedBox(height: Gap.lg),
        if (subs.isNotEmpty) ...[
          SectionHeader(
            l.insidePeriod(grahaName(md!.lord)),
            subtitle: l.insidePeriodSub,
          ),
          for (final s in subs)
            _SubPeriodRow(span: s, current: s.contains(now)),
          const SizedBox(height: Gap.lg),
        ],
        SectionHeader(
          l.nextTwoYears,
          subtitle: forecast.windows.isEmpty
              ? l.nextTwoYearsNone
              : l.nextTwoYearsSub,
        ),
        if (forecast.windows.isEmpty) QuietNote(l.noWindowNote),
        for (final w in forecast.windows.take(8)) ...[
          _WindowCard(hit: w),
          const SizedBox(height: Gap.sm),
        ],
        const SizedBox(height: Gap.lg),
        SectionHeader(l.whereThingsStand),
        for (final h in forecast.hits) ...[
          _WindowCard(hit: h),
          const SizedBox(height: Gap.sm),
        ],
      ],
    );
  }
}

/// A life-long dasha strip. Width is proportional to the length of each
/// period, so a 20-year Venus chapter looks like one.
class _DashaTimeline extends StatelessWidget {
  const _DashaTimeline({required this.chart, required this.now});

  final NatalChart chart;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final spans = chart.dasha;
    if (spans.isEmpty) return const SizedBox.shrink();
    final total = spans.last.end.difference(spans.first.start).inDays;
    if (total <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 34,
            child: Row(
              children: [
                for (final s in spans)
                  Expanded(
                    flex: s.end.difference(s.start).inDays.clamp(1, 1 << 30),
                    child: Tooltip(
                      message: '${grahaName(s.lord)}  '
                          '${DateFormat.y().format(s.start)}–'
                          '${DateFormat.y().format(s.end)}',
                      child: Container(
                        decoration: BoxDecoration(
                          color: grahaColor(s.lord).withValues(
                            alpha: s.contains(now) ? 1.0 : 0.30,
                          ),
                          border: Border(
                            right: BorderSide(color: paper.withValues(alpha: 0.6)),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              shortName(s.lord),
                              style: Type.micro.copyWith(
                                color: s.contains(now) ? Colors.white : ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat.y().format(spans.first.start), style: Type.micro),
            Text(L.of(context).nowLabel,
                style: Type.micro.copyWith(color: navy)),
            Text(DateFormat.y().format(spans.last.end), style: Type.micro),
          ],
        ),
      ],
    );
  }
}

class _SubPeriodRow extends StatelessWidget {
  const _SubPeriodRow({required this.span, required this.current});

  final DashaSpan span;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      decoration: BoxDecoration(
        color: current ? grahaColor(span.lord).withValues(alpha: 0.10) : null,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(
          color: current ? grahaColor(span.lord).withValues(alpha: 0.4) : hairline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: grahaColor(span.lord),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              grahaName(span.lord),
              style: Type.body.copyWith(
                fontWeight: current ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${DateFormat.yMMM().format(span.start)} – '
            '${DateFormat.yMMM().format(span.end)}',
            style: Type.caption,
          ),
          if (current) ...[
            const SizedBox(width: Gap.sm),
            Text(
              L.of(context).nowLabel,
              style: Type.micro.copyWith(
                color: grahaColor(span.lord),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WindowCard extends StatelessWidget {
  const _WindowCard({required this.hit});

  final ForecastHit hit;

  @override
  Widget build(BuildContext context) {
    return ExplainCard(
      title: hit.title,
      accent: VerdictBadge.colorFor(hit.verdict),
      lead: _plainLead(hit),
      detail: '${hit.body}\n\n${hit.techniques.join(' · ')}',
      badge: VerdictBadge(hit.verdict),
      footnote: L.of(context).confidenceFootnote('${hit.confidence}'),
    );
  }

  /// A sentence a reader can stop at, instead of the engine's full trace.
  ///
  /// The lead is localised; the classical detail behind it is whatever the
  /// knowledge base carries for the active locale.
  static String _plainLead(ForecastHit hit) {
    final body = hit.body;
    final cut = body.indexOf('. ');
    final first = cut > 0 && cut < 200 ? body.substring(0, cut + 1) : '';
    return '${tr('verdict.lead.${hit.verdict}')} $first'.trim();
  }
}


// ===========================================================================
// Table cells added for retrogradation and bhava chalit
// ===========================================================================

/// Direct, retrograde or stationary.
///
/// Gap G-01 in the place a reader actually looks. The nodes are always
/// retrograde, so marking them would be noise; they get a dash instead.
class _MotionCell extends StatelessWidget {
  const _MotionCell({required this.graha});
  final GrahaRow graha;

  @override
  Widget build(BuildContext context) {
    if (graha.name == 'Lagna' ||
        graha.name == 'Rahu' ||
        graha.name == 'Ketu') {
      return Text('—', style: Type.caption.copyWith(color: inkFaint));
    }
    final retro = graha.isRetrograde;
    final stationary = graha.isStationary;
    final colour = stationary
        ? gold
        : retro
            ? maleficColor
            : inkSoft;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          stationary ? 'S' : (retro ? '℞' : 'D'),
          style: Type.caption.copyWith(
            color: colour,
            fontWeight: retro || stationary ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${graha.speed.abs() < 10 ? graha.speed.toStringAsFixed(2) : graha.speed.toStringAsFixed(1)}°',
          style: Type.micro,
        ),
      ],
    );
  }
}

/// The chalit house, marked when it disagrees with the whole-sign one.
///
/// Gap G-16. The disagreement is the information: it is the commonest reason
/// two astrologers read the same kundali differently.
class _ChalitCell extends StatelessWidget {
  const _ChalitCell({required this.graha});
  final GrahaRow graha;

  @override
  Widget build(BuildContext context) {
    if (graha.chalitHouse == 0) {
      return Text('—', style: Type.caption.copyWith(color: inkFaint));
    }
    final differs = graha.chalitDiffers;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${graha.chalitHouse}',
          style: Type.caption.copyWith(
            color: differs ? strainedColor : ink,
            fontWeight: differs ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        if (differs) ...[
          const SizedBox(width: 3),
          const Icon(Icons.swap_vert, size: 12, color: strainedColor),
        ],
      ],
    );
  }
}

class _ChalitFootnote extends StatelessWidget {
  const _ChalitFootnote();

  @override
  Widget build(BuildContext context) {
    return Text(
      '℞ retrograde · S stationary · the number after it is degrees per day. '
      'Where the chalit column differs from the house column, the graha sits '
      'in one bhava by sign and another by cusp — which is worth knowing '
      'before reading either.',
      style: Type.micro,
    );
  }
}

/// The ephemeris.
///
/// Gap G-44. Every number here was already computable; only the view was
/// missing. That matters more than it sounds: half of what a printed ephemeris
/// gets used for is idle scanning — noticing that three planets change sign in
/// the same week, or that Mercury stations two days before a client's
/// birthday. A table you can only query one date at a time does not support
/// that at all.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import '../engine/astro/ephemeris.dart';
import '../engine/panchanga.dart';
import '../engine/tables.dart';
import '../engine/transits.dart';
import '../theme/tokens.dart';
import 'widgets/atoms.dart';

final _dayLabel = DateFormat('EEE d');
final _monthLabel = DateFormat('MMMM yyyy');
final _clock = DateFormat('HH:mm');

const _columns = [
  'Sun', 'Moon', 'Mercury', 'Venus', 'Mars',
  'Jupiter', 'Saturn', 'Uranus', 'Neptune', 'Pluto', 'Rahu',
];

class EphemerisScreen extends StatefulWidget {
  const EphemerisScreen({super.key, required this.place, this.settings});

  final Place place;
  final ChartSettings? settings;

  @override
  State<EphemerisScreen> createState() => _EphemerisScreenState();
}

class _EphemerisScreenState extends State<EphemerisScreen> {
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  bool sidereal = true;

  ChartSettings get _settings => widget.settings ?? const ChartSettings();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ephemeris'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Positions'),
              Tab(text: 'Events'),
              Tab(text: 'Rise & set'),
            ],
          ),
        ),
        body: Column(
          children: [
            _MonthBar(
              month: month,
              sidereal: sidereal,
              onMonth: (m) => setState(() => month = m),
              onZodiac: (v) => setState(() => sidereal = v),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _PositionsTab(
                      month: month, sidereal: sidereal, settings: _settings),
                  _EventsTab(month: month, settings: _settings),
                  _RiseSetTab(month: month, place: widget.place),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.sidereal,
    required this.onMonth,
    required this.onZodiac,
  });

  final DateTime month;
  final bool sidereal;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<bool> onZodiac;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              _monthLabel.format(month),
              textAlign: TextAlign.center,
              style: Type.title,
            ),
          ),
          IconButton(
            onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
            icon: const Icon(Icons.chevron_right),
          ),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Sid')),
              ButtonSegment(value: false, label: Text('Trop')),
            ],
            selected: {sidereal},
            onSelectionChanged: (s) => onZodiac(s.first),
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PositionsTab extends StatelessWidget {
  const _PositionsTab({
    required this.month,
    required this.sidereal,
    required this.settings,
  });

  final DateTime month;
  final bool sidereal;
  final ChartSettings settings;

  @override
  Widget build(BuildContext context) {
    final days = DateTime(month.year, month.month + 1, 0).day;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowHeight: 34,
          dataRowMinHeight: 28,
          dataRowMaxHeight: 30,
          columnSpacing: 14,
          headingTextStyle:
              Type.micro.copyWith(fontWeight: FontWeight.w700, color: ink),
          dataTextStyle: Type.glyph.copyWith(fontWeight: FontWeight.w400),
          columns: [
            const DataColumn(label: Text('Day')),
            for (final name in _columns)
              DataColumn(
                label: Text(
                  name.substring(0, name.length >= 3 ? 3 : name.length),
                  style: Type.micro.copyWith(
                    fontWeight: FontWeight.w700,
                    color: grahaColors[name] ?? ink,
                  ),
                ),
              ),
          ],
          rows: [
            for (var d = 1; d <= days; d++)
              _row(DateTime.utc(month.year, month.month, d)),
          ],
        ),
      ),
    );
  }

  DataRow _row(DateTime at) {
    // Positions are conventionally tabulated for midnight UT, which is what
    // makes an ephemeris comparable between publishers.
    final sky = computeSky(
      utc: at,
      latitude: 0,
      longitudeEast: 0,
      settings: settings,
      bodyNames: _columns,
    );

    return DataRow(
      cells: [
        DataCell(Text(_dayLabel.format(at), style: Type.micro)),
        for (final name in _columns)
          DataCell(_Cell(
            body: sky.bodies[name]!,
            longitude: sidereal ? sky.sidereal(name) : sky.bodies[name]!.longitude,
          )),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.body, required this.longitude});
  final BodyPosition body;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    final sign = signIndex(longitude);
    final retro = body.isRetrograde && body.name != 'Rahu' && body.name != 'Ketu';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${formatDms(longitude)} ${signs[sign].sanskrit.substring(0, 2)}',
          style: Type.glyph.copyWith(
            color: grahaColors[body.name] ?? ink,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (retro)
          Text('℞', style: Type.glyph.copyWith(color: maleficColor)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _EventsTab extends StatefulWidget {
  const _EventsTab({required this.month, required this.settings});
  final DateTime month;
  final ChartSettings settings;

  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab> {
  List<TransitEvent>? events;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _EventsTab old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month) _load();
  }

  Future<void> _load() async {
    setState(() => events = null);
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final from = DateTime.utc(widget.month.year, widget.month.month, 1);
    final to = DateTime.utc(widget.month.year, widget.month.month + 1, 1);
    final found = <TransitEvent>[
      ...ingresses(from: from, to: to, settings: widget.settings),
      ...stations(from: from, to: to),
      ...lunations(from: from, to: to),
      ...nakshatraChanges(from: from, to: to, settings: widget.settings),
    ]..sort((a, b) => a.at.compareTo(b.at));
    if (!mounted) return;
    setState(() => events = found);
  }

  @override
  Widget build(BuildContext context) {
    if (events == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (events!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(Gap.lg),
        child: QuietNote('No ingresses, stations or lunations this month.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
      children: [
        for (final e in events!)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 62,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${e.at.toLocal().day}',
                          style: Type.title.copyWith(fontSize: 17)),
                      Text(_clock.format(e.at.toLocal()), style: Type.micro),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title,
                          style: Type.body
                              .copyWith(fontWeight: FontWeight.w600)),
                      if (e.detail.isNotEmpty)
                        Text(e.detail, style: Type.caption),
                    ],
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

class _RiseSetTab extends StatelessWidget {
  const _RiseSetTab({required this.month, required this.place});
  final DateTime month;
  final Place place;

  @override
  Widget build(BuildContext context) {
    final days = DateTime(month.year, month.month + 1, 0).day;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xxl),
      children: [
        Text('For ${place.label}.', style: Type.caption),
        const SizedBox(height: Gap.sm),
        for (var d = 1; d <= days; d++) _row(DateTime.utc(month.year, month.month, d)),
      ],
    );
  }

  Widget _row(DateTime at) {
    final day = panchangaFor(
      at: at,
      latitude: place.latitude,
      longitudeEast: place.longitude,
      timezone: place.timezone,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(_dayLabel.format(at), style: Type.caption)),
          SizedBox(
            width: 64,
            child: Text(_clock.format(day.daylight.sunrise), style: Type.body),
          ),
          SizedBox(
            width: 64,
            child: Text(_clock.format(day.daylight.sunset), style: Type.body),
          ),
          Expanded(
            child: Text(
              '${day.tithi.name} · ${day.nakshatra.name}'
              '${day.daylight.estimated ? ' · estimated' : ''}',
              style: Type.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

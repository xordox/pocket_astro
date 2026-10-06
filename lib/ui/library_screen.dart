import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/atlas.dart';
import '../engine/learn.dart';
import '../engine/rashifal.dart';
import '../engine/today.dart' show DayGradeText;
import '../l10n/engine_strings.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/locale_cubit.dart';
import '../domain/models.dart';
import '../engine/tz_lookup.dart';
import '../engine/zone_offset.dart';
import '../state/library_bloc.dart';
import '../theme/tokens.dart';
import '../state/learn_cubit.dart';
import '../state/place_lookup_cubit.dart';
import 'widgets/atoms.dart';
import 'widgets/library_filter.dart';
import 'widgets/library_menu.dart';
import 'widgets/place_field.dart';
import 'widgets/tag_field.dart';
import 'widgets/zone_confirmation.dart';

/// Home.
///
/// Three jobs, in the order a returning reader wants them: tell me about today,
/// let me open a chart, offer me somewhere to go next. The old screen did only
/// the second, and hid compatibility behind an unlabelled heart icon in the app
/// bar — a destination nobody finds by accident. Every destination now has a
/// word on it.
///
/// The daily card is deliberately first. It is the only part of the app that
/// changes without the reader doing anything, which makes it the only honest
/// reason to open the app on a day when you are not reading a chart.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  /// Free-text filter across name, place, tags and notes (G-42).
  String _query = '';
  final Set<String> _activeTags = {};

  /// The day's readings, computed once per build of the profile list rather
  /// than on every rebuild — it runs an ephemeris and a sunrise solve.
  List<RashiDay>? _days;
  int? _yourRashi;
  String? _yourChartId;
  String? _computedFor;

  void _recompute(List<BirthInput> profiles) {
    final key = '${DateTime.now().toIso8601String().substring(0, 10)}'
        '|${profiles.map((e) => e.id).join(',')}';
    if (_computedFor == key) return;
    _computedFor = key;
    final place = profiles.isEmpty ? kathmandu : profiles.first.place;
    try {
      _days = rashifalForAll(place: place);
    } catch (_) {
      _days = null; // A bad place costs the card, not the screen.
    }
    _yourRashi = null;
    _yourChartId = null;
    for (final p in profiles) {
      try {
        _yourRashi = moonRashiOf(p);
        _yourChartId = p.id;
        break;
      } catch (_) {
        continue;
      }
    }
  }

  /// Every tag in use, most-used first, so the chips are worth tapping.
  List<String> _allTagsIn(List<BirthInput> profiles) {
    final counts = <String, int>{};
    for (final p in profiles) {
      for (final t in p.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final tags = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return tags;
  }

  List<BirthInput> _filter(List<BirthInput> profiles) {
    final q = _query.trim().toLowerCase();
    return profiles.where((p) {
      if (_activeTags.isNotEmpty && !_activeTags.every(p.tags.contains)) {
        return false;
      }
      if (q.isEmpty) return true;
      // Searching the notes too is the point: "the client I saw about the
      // house move" is a phrase from a note, not from a name.
      return p.name.toLowerCase().contains(q) ||
          p.place.label.toLowerCase().contains(q) ||
          p.notes.toLowerCase().contains(q) ||
          p.tags.any((t) => t.contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          const LibraryMenuButton(),
          IconButton(
            tooltip: 'Calculation settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.tune),
          ),
          const LanguageButton(),
        ],
      ),
      body: BlocBuilder<LibraryBloc, LibraryState>(
        builder: (context, state) {
          if (state is LibraryFailure) {
            return Center(child: Text(state.message));
          }
          if (state is! LibraryReady) {
            return const Center(child: CircularProgressIndicator());
          }
          final profiles = state.profiles;
          _recompute(profiles);

          return ListView(
            key: const PageStorageKey('library'),
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, 96),
            children: [
              _DailyCard(
                days: _days,
                rashi: _yourRashi,
                chartId: _yourChartId,
              ),
              const SizedBox(height: Gap.lg),
              const _Destinations(),
              const SizedBox(height: Gap.lg),
              if (profiles.isEmpty)
                _Empty(
                  onDemo: () =>
                      context.read<LibraryBloc>().add(const LibraryLoadDemo()),
                )
              else ...[
                SectionHeader(l.homeYourCharts, subtitle: l.homeYourChartsSub),
                // A practice carries hundreds of charts. Past a couple of
                // dozen a flat list stops being a library and starts being a
                // scroll, so the filter appears when it starts to earn its
                // place (G-42).
                if (profiles.length >= 6) ...[
                  LibraryFilter(
                    query: _query,
                    activeTags: _activeTags,
                    allTags: _allTagsIn(profiles),
                    onQuery: (q) => setState(() => _query = q),
                    onToggleTag: (t) => setState(() {
                      _activeTags.contains(t)
                          ? _activeTags.remove(t)
                          : _activeTags.add(t);
                    }),
                  ),
                  const SizedBox(height: Gap.md),
                ],
                for (final p in _filter(profiles)) _ProfileCard(profile: p),
                if (_filter(profiles).isEmpty)
                  const QuietNote(
                    'No chart matches that. Clear the filter to see them all.',
                    icon: Icons.search_off,
                  ),
              ],
              const SizedBox(height: Gap.lg),
              QuietNote(l.storedOnDevice, icon: Icons.lock_outline_rounded),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/new'),
        icon: const Icon(Icons.add),
        label: Text(l.newChart),
      ),
    );
  }
}

/// Today, at a glance. Works with no charts saved: the panchanga is true for
/// everybody, and the rashi grid is one tap away.
class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.days,
    required this.rashi,
    required this.chartId,
  });

  final List<RashiDay>? days;
  final int? rashi;
  final String? chartId;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final all = days;
    final mine = (all != null && rashi != null) ? all[rashi!] : null;
    final accent = mine == null ? navy : gradeColor(mine.grade);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/rashifal'),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    l.homeToday.toUpperCase(),
                    style: Type.micro.copyWith(
                      letterSpacing: 0.8,
                      color: accent,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat.MMMEd().format(DateTime.now()),
                    style: Type.micro,
                  ),
                ],
              ),
              const SizedBox(height: Gap.xs),
              if (mine != null) ...[
                Text(mine.grade.label, style: Type.display),
                const SizedBox(height: 2),
                Text(
                  '${mine.name} · ${l.rashifalMoonSign}',
                  style: Type.caption.copyWith(color: accent),
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  mine.headline,
                  style: Type.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else ...[
                Text(l.rashifalTitle, style: Type.display),
                const SizedBox(height: Gap.sm),
                Text(l.rashifalSub, style: Type.body),
              ],
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  Text(
                    l.navRashifal,
                    style: Type.caption.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: accent),
                  const Spacer(),
                  if (chartId != null)
                    TextButton(
                      onPressed: () => context.push('/chart/$chartId'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(l.homeReadYourDay),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Learn and Compatibility, as labelled tiles rather than app-bar glyphs.
class _Destinations extends StatelessWidget {
  const _Destinations();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return BlocBuilder<LearnCubit, Set<String>>(
      builder: (context, done) {
        final total = syllabusFor(null).lessonCount;
        return Row(
          children: [
            Expanded(
              child: _DestinationTile(
                icon: Icons.school_outlined,
                title: l.navLearn,
                subtitle: total == 0
                    ? ''
                    : l.homeLearnProgress('${done.length}', '$total'),
                onTap: () => context.push('/learn'),
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: _DestinationTile(
                icon: Icons.favorite_outline,
                title: l.navCompatibility,
                subtitle: '',
                onTap: () => context.push('/match'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.chip),
      child: Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: paperRaised,
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(color: hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: navy),
            const SizedBox(height: Gap.sm),
            Text(
              title,
              style: Type.body.copyWith(fontWeight: FontWeight.w700),
              maxLines: 2,
            ),
            if (subtitle.isNotEmpty)
              Text(subtitle, style: Type.micro, maxLines: 1),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});
  final BirthInput profile;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final noTime = profile.timeSource == TimeSource.unknown;
    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: navy.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            profile.name.isEmpty
                ? '?'
                : profile.name.characters.first.toUpperCase(),
            style: Type.title.copyWith(color: navy),
          ),
        ),
        title: Text(
          profile.name,
          style: Type.body.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          noTime
              ? '${DateFormat('d MMM yyyy').format(profile.localDateTime)} · '
                  '${profile.place.name} · ${l.timeUnknownShort}'
              : '${DateFormat('d MMM yyyy, HH:mm').format(profile.localDateTime)} · '
                  '${profile.place.name}',
        ),
        trailing:
            const Icon(Icons.chevron_right_rounded, color: inkFaint),
        onTap: () => context.push('/chart/${profile.id}'),
        onLongPress: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(l.deleteTitle),
              content: Text(l.deleteBody(profile.name)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: Text(l.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(l.delete),
                ),
              ],
            ),
          );
          if (ok == true && context.mounted) {
            context.read<LibraryBloc>().add(LibraryRemove(profile.id));
          }
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onDemo});
  final VoidCallback onDemo;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.lg),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: navy.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.nights_stay_rounded, size: 34, color: navy),
          ),
          const SizedBox(height: Gap.lg),
          Text(l.emptyTitle, style: Type.display, textAlign: TextAlign.center),
          const SizedBox(height: Gap.sm),
          Text(l.emptyBody, style: Type.bodySoft, textAlign: TextAlign.center),
          const SizedBox(height: Gap.xl),
          FilledButton(
            onPressed: () => context.push('/new'),
            child: Text(l.enterBirthDetails),
          ),
          const SizedBox(height: Gap.sm),
          TextButton(onPressed: onDemo, child: Text(l.loadDemo)),
        ],
      ),
    );
  }
}

class BirthFormScreen extends StatefulWidget {
  const BirthFormScreen({
    super.key,
    this.existing,
    this.onSaved,
    this.saveLabel,
    this.title,
  });

  final BirthInput? existing;

  /// Where the saved chart goes next.
  ///
  /// Null is the normal case: save, then open the chart. The compatibility
  /// screen passes a callback instead, so a reader adding a second person gets
  /// handed straight back to the comparison they were in the middle of rather
  /// than being dropped into a chart they did not ask to read. The chart is
  /// still written to the library either way.
  final ValueChanged<BirthInput>? onSaved;

  /// Overrides the save button's wording, so the button can name the thing the
  /// reader is actually about to get.
  final String? saveLabel;

  /// Overrides the app-bar title. The compatibility screen names the slot
  /// being filled, so a reader adding the second person can see which one.
  final String? title;

  @override
  State<BirthFormScreen> createState() => _BirthFormScreenState();
}

class _BirthFormScreenState extends State<BirthFormScreen> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late DateTime _when = widget.existing?.localDateTime ?? DateTime(1992, 4, 14, 3, 57);
  /// Nullable, unlike before. Once the field is free text there is no honest
  /// default — a chart built against a silently pre-filled Kathmandu would be
  /// wrong in a way the reader could not see.
  late Place? _place = widget.existing?.place;
  late TimeSource _source = widget.existing?.timeSource ?? TimeSource.hospital;
  late TimeStandard _standard =
      widget.existing?.timeStandard ?? TimeStandard.zone;
  late List<String> _tags = [...?widget.existing?.tags];

  @override
  void initState() {
    super.initState();
    // The cubit is app-scoped, so a second visit would otherwise inherit the
    // first visit's results. The geocoder's own cache stays warm.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PlaceLookupCubit>().reset();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title ??
              (widget.existing == null ? l.newChart : l.editChart),
        ),
      ),
      body: ListView(
        key: const PageStorageKey('birth-form'),
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l.fieldName),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.fieldDateTime),
            subtitle: Text(DateFormat('d MMMM yyyy, HH:mm').format(_when)),
            trailing: const Icon(Icons.event),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _when,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
              );
              if (d == null || !context.mounted) return;
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_when),
              );
              setState(() {
                _when = DateTime(d.year, d.month, d.day, t?.hour ?? _when.hour, t?.minute ?? _when.minute);
              });
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.switchTimeUnknown),
            subtitle: Text(l.switchTimeUnknownSub),
            value: _source == TimeSource.unknown,
            onChanged: (v) => setState(() => _source = v ? TimeSource.unknown : TimeSource.hospital),
          ),
          if (_source != TimeSource.unknown)
            DropdownButtonFormField<TimeSource>(
              initialValue: _source,
              decoration: InputDecoration(labelText: l.fieldTimeSource),
              items: TimeSource.values
                  .where((e) => e != TimeSource.unknown)
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                  .toList(),
              onChanged: (v) => setState(() => _source = v ?? _source),
            ),
          const SizedBox(height: 12),
          PlaceField(
            value: _place,
            lookup: context.read<PlaceLookupCubit>().lookup,
            onChanged: (p) => setState(() => _place = p),
          ),
          if (_place != null && isKnownZone(_place!.timezone)) ...[
            const SizedBox(height: 12),
            ZoneConfirmation(
              place: _place!,
              localDateTime: _when,
              standard: _standard,
              onStandard: (v) => setState(() => _standard = v),
            ),
          ],
          const SizedBox(height: 12),
          TagField(
            tags: _tags,
            onChanged: (t) => setState(() => _tags = t),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final name = _name.text.trim();
              if (name.isEmpty) return;
              // The form used to guarantee a place by construction. Free text
              // removes that guarantee, so the check moves here — and an
              // unresolvable zone is caught before it can reach the engine.
              final messenger = ScaffoldMessenger.of(context);
              final place = _place;
              if (place == null ||
                  !place.isWellFormed ||
                  !isKnownZone(place.timezone)) {
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(l.invalidLocation)));
                return;
              }
              final input = BirthInput(
                id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                localDateTime: _when,
                place: place,
                timeSource: _source,
                timeStandard: _standard,
                tags: _tags,
              );
              final bloc = context.read<LibraryBloc>();
              final ready = bloc.stream.firstWhere((s) => s is LibraryReady);
              bloc.add(LibraryUpsert(input));
              await ready;
              if (!context.mounted) return;
              final handOff = widget.onSaved;
              if (handOff != null) {
                handOff(input);
              } else {
                context.go('/chart/${input.id}');
              }
            },
            child: Text(widget.saveLabel ?? l.saveAndRead),
          ),
        ],
      ),
    );
  }
}


/// Language picker. Switching swaps the widget strings, the engine's own
/// string table and the knowledge-base overlay together, so the whole app
/// changes language at once rather than in pieces.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.watch<LocaleCubit>().state.languageCode;
    return PopupMenuButton<String>(
      tooltip: L.of(context).navLanguage,
      icon: const Icon(Icons.translate_rounded),
      onSelected: (code) => context.read<LocaleCubit>().select(code),
      itemBuilder: (context) => [
        for (final code in supportedLocaleCodes)
          PopupMenuItem(
            value: code,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: code == current
                      ? const Icon(Icons.check_rounded, size: 18, color: navy)
                      : null,
                ),
                Text(localeNames[code] ?? code, style: Type.body),
              ],
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../data/place_lookup.dart';
import '../../domain/models.dart';
import '../../engine/tz_lookup.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../state/place_lookup_cubit.dart';
import '../../theme/tokens.dart';
import 'atoms.dart';

/// Birthplace entry: free text, matched on-device first and online on request.
///
/// The ordering is the product decision made visible. Typing filters places
/// already on the device and opens no socket; the network is reached only from
/// an explicit "Search online" tap or by submitting the field. That makes the
/// offline guarantee a property of the call graph rather than of a debounce
/// interval, and it means a reader with no connectivity still has a working
/// picker rather than a spinner that never resolves.
///
/// The coordinates expander at the foot is not a power-user affordance. It is
/// the only way a reader who is offline and outside the 25 bundled cities can
/// create a chart at all, so it ships with the feature, not after it.
class PlaceField extends StatefulWidget {
  const PlaceField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.lookup,
  });

  /// The chosen place, or null before the reader has picked one.
  final Place? value;
  final ValueChanged<Place> onChanged;
  final PlaceLookup lookup;

  @override
  State<PlaceField> createState() => _PlaceFieldState();
}

class _PlaceFieldState extends State<PlaceField> {
  final _query = TextEditingController();
  List<Place> _local = const [];

  @override
  void initState() {
    super.initState();
    // Remembered places load from disk once; until they arrive the bundled
    // atlas answers on its own, so the field is never blocked on IO.
    widget.lookup.start().then((_) {
      if (mounted) setState(() => _local = widget.lookup.localMatches(_query.text));
    });
    _local = widget.lookup.localMatches('');
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _onTyped(String q) {
    // Synchronous by design. Nothing here can reach the network.
    setState(() => _local = widget.lookup.localMatches(q));
  }

  void _searchOnline() {
    final q = _query.text.trim();
    if (q.length < PlaceLookup.minOnlineChars) return;
    // Submitting the field bypasses the button, so the guard lives here too.
    if (context.read<PlaceLookupCubit>().state is PlaceSearching) return;
    FocusScope.of(context).unfocus();
    context.read<PlaceLookupCubit>().search(
          q,
          language: Localizations.localeOf(context).languageCode,
        );
  }

  void _choose(Place place) {
    widget.lookup.remember(place);
    widget.onChanged(place);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final canSearch = _query.text.trim().length >= PlaceLookup.minOnlineChars;

    return BlocListener<PlaceLookupCubit, PlaceLookupState>(
      // The required snackbar fires when the service answered and had nothing
      // usable. A transport failure is shown inline instead — telling someone
      // with the wifi off that they misspelled their birthplace sends them to
      // fix the wrong thing.
      listenWhen: (a, b) => b is PlaceNotFound,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.invalidLocation)));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _query,
            decoration: InputDecoration(
              labelText: l.fieldBirthPlace,
              hintText: l.hintTypePlace,
              prefixIcon: const Icon(Icons.place_outlined),
            ),
            textInputAction: TextInputAction.search,
            textCapitalization: TextCapitalization.words,
            onChanged: _onTyped,
            onSubmitted: (_) => _searchOnline(),
          ),
          const SizedBox(height: Gap.sm),
          if (widget.value != null)
            _SelectedPlace(place: widget.value!)
          else
            Text(l.hintTypePlace, style: Type.caption),
          const SizedBox(height: Gap.md),

          if (_local.isNotEmpty) ...[
            Text(
              l.sectionOnDevice.toUpperCase(),
              style: Type.micro.copyWith(letterSpacing: 0.8),
            ),
            const SizedBox(height: Gap.xs),
            for (final p in _local)
              _PlaceRow(
                place: p,
                selected: p.label == widget.value?.label,
                onTap: () => _choose(p),
              ),
            const SizedBox(height: Gap.md),
          ],

          // The button has to see the in-flight state, or an impatient reader
          // fires one request per tap at a free service.
          BlocBuilder<PlaceLookupCubit, PlaceLookupState>(
            buildWhen: (a, b) => (a is PlaceSearching) != (b is PlaceSearching),
            builder: (context, state) {
              final busy = state is PlaceSearching;
              return Row(
                children: [
                  TextButton.icon(
                    onPressed: canSearch && !busy ? _searchOnline : null,
                    icon: const Icon(Icons.travel_explore_outlined, size: 18),
                    label: Text(l.searchOnline),
                  ),
                  if (!canSearch)
                    Expanded(
                      child: Text(l.placeSearchMinChars, style: Type.micro),
                    ),
                ],
              );
            },
          ),

          BlocBuilder<PlaceLookupCubit, PlaceLookupState>(
            builder: (context, state) => switch (state) {
              PlaceIdle() => const SizedBox.shrink(),
              PlaceSearching() => Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gap.md),
                  child: Row(
                    children: [
                      const SizedBox(
                        key: Key('place-search-progress'),
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: Gap.md),
                      Text(l.searchingPlaces, style: Type.caption),
                    ],
                  ),
                ),
              PlaceFound(:final hits) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: Gap.sm),
                    Text(
                      l.sectionOnlineResults.toUpperCase(),
                      style: Type.micro.copyWith(letterSpacing: 0.8),
                    ),
                    const SizedBox(height: Gap.xs),
                    for (final p in hits)
                      _PlaceRow(
                        place: p,
                        selected: p.label == widget.value?.label,
                        onTap: () => _choose(p),
                      ),
                    const SizedBox(height: Gap.xs),
                    Text(l.placeOnlineNote, style: Type.micro),
                    // Attribution required by the data licence. A proper noun
                    // in every language, so deliberately not an ARB value.
                    Text(
                      'Place data © GeoNames (CC BY 4.0) · Open-Meteo',
                      style: Type.micro,
                    ),
                  ],
                ),
              // Answered, nothing usable. The snackbar above already fired;
              // this keeps the reason on screen after it dismisses.
              PlaceNotFound() => Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                  child: QuietNote(l.invalidLocation,
                      icon: Icons.search_off_outlined),
                ),
              PlaceUnreachable() => Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      QuietNote(l.placeLookupOffline,
                          icon: Icons.cloud_off_outlined),
                      TextButton(
                        onPressed: () =>
                            context.read<PlaceLookupCubit>().retry(),
                        child: Text(l.placeLookupRetry),
                      ),
                    ],
                  ),
                ),
            },
          ),

          const SizedBox(height: Gap.sm),
          DisclosurePanel(
            title: l.useCoordinates,
            children: [
              _ManualPlace(
                // The reader has already typed a name in the field above;
                // asking for it twice is the kind of duplication that makes a
                // fallback path feel like a punishment.
                name: _query.text.trim(),
                onChanged: _choose,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectedPlace extends StatelessWidget {
  const _SelectedPlace({required this.place});
  final Place place;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border(left: BorderSide(color: navy, width: 3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: navy),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              L.of(context).selectedPlace(place.label, place.timezone),
              style: Type.body,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.place,
    required this.selected,
    required this.onTap,
  });

  final Place place;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.chip),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? navy.withValues(alpha: 0.08) : paperRaised,
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(
            color: selected ? navy.withValues(alpha: 0.4) : hairline,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.label, style: Type.body),
                  Text(
                    '${place.latitude.toStringAsFixed(2)}, '
                    '${place.longitude.toStringAsFixed(2)} · ${place.timezone}',
                    style: Type.micro,
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, size: 16, color: navy),
          ],
        ),
      ),
    );
  }
}

/// Coordinates typed by hand, for a reader offline and off the bundled list.
///
/// The timezone is an [Autocomplete] over the loaded database rather than a
/// free-text box: every id it can produce is one `tz.getLocation` accepts, so
/// this path cannot manufacture the broken state the geocoder is gated against.
class _ManualPlace extends StatefulWidget {
  const _ManualPlace({required this.name, required this.onChanged});

  /// Whatever the reader typed in the search field above.
  final String name;
  final ValueChanged<Place> onChanged;

  @override
  State<_ManualPlace> createState() => _ManualPlaceState();
}

class _ManualPlaceState extends State<_ManualPlace> {
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  String _zone = '';
  bool _invalid = false;

  @override
  void dispose() {
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  void _apply() {
    final place = Place(
      name: widget.name.isEmpty ? '—' : widget.name,
      region: '',
      latitude: double.tryParse(_lat.text.trim()) ?? double.nan,
      longitude: double.tryParse(_lon.text.trim()) ?? double.nan,
      timezone: _zone,
    );
    final ok = place.isWellFormed && isKnownZone(place.timezone);
    setState(() => _invalid = !ok);
    if (ok) widget.onChanged(place);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _lat,
                decoration: InputDecoration(labelText: l.fieldLatitude),
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true, decimal: true),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: TextField(
                controller: _lon,
                decoration: InputDecoration(labelText: l.fieldLongitude),
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true, decimal: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.sm),
        Autocomplete<String>(
          optionsBuilder: (value) {
            final q = value.text.trim().toLowerCase();
            if (q.length < 2) return const Iterable<String>.empty();
            return tz.timeZoneDatabase.locations.keys
                .where((id) => id.toLowerCase().contains(q))
                .take(8);
          },
          onSelected: (id) => setState(() => _zone = id),
          fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
            controller: controller,
            focusNode: focus,
            decoration: InputDecoration(
              labelText: l.fieldTimezone,
              hintText: l.hintTimezone,
            ),
            onChanged: (v) => _zone = v.trim(),
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        if (_invalid) ...[
          const SizedBox(height: Gap.sm),
          Text(
            l.invalidCoordinates,
            style: Type.caption.copyWith(color: strainedColor),
          ),
        ],
        const SizedBox(height: Gap.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            onPressed: _apply,
            child: Text(l.useThisPlace),
          ),
        ),
      ],
    );
  }
}

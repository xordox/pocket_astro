/// The one place the app asks the timezone database a question.
///
/// This exists because a birthplace can now come from a geocoder rather than
/// from a curated list, and `tz.getLocation` throws on an id it does not know.
/// A thrown `LocationNotFoundException` deep inside chart building would
/// surface as a blank screen; nothing in this codebase catches it today.
///
/// Two guarantees are built on top of this file:
///
/// * [isKnownZone] is the gate `placeFromGeoJson` applies before a remote row
///   is allowed to become a [Place]. It is a map lookup, not a try/catch, so
///   validating a hundred search hits costs nothing.
/// * [locationFor] turns the package's untyped failure into [UnknownTimezone],
///   which names the offending id. Defence in depth: if a bad id ever reaches
///   the engine, the crash says which one.
library;

import 'package:timezone/timezone.dart' as tz;

/// Thrown when a stored or supplied IANA id is not in the loaded database.
///
/// Carries the id because the useful debugging question is always *which*
/// zone, and the raw package exception does not reliably survive to the log.
class UnknownTimezone implements Exception {
  const UnknownTimezone(this.id);

  final String id;

  @override
  String toString() => 'UnknownTimezone: "$id" is not in the timezone database';
}

/// True when the loaded database can resolve [id].
///
/// `timeZoneDatabase.locations` is a public `Map<String, Location>`, so this is
/// O(1) and has no exception path. Note that the app loads `latest_all`, not
/// `latest`: the geocoder emits GeoNames ids, which include legacy aliases like
/// `Asia/Calcutta` and `Europe/Kiev`. Those are valid IANA ids that `latest`
/// omits, and rejecting them would tell a reader in Kolkata that their city
/// does not exist.
bool isKnownZone(String id) =>
    id.isNotEmpty && tz.timeZoneDatabase.locations.containsKey(id);

/// [tz.getLocation], with a typed failure that names the id.
tz.Location locationFor(String id) {
  try {
    return tz.getLocation(id);
  } on tz.LocationNotFoundException {
    throw UnknownTimezone(id);
  }
}

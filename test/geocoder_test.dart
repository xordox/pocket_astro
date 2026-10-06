import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocket_astro/data/geocoder.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/engine/time_convert.dart';
import 'package:pocket_astro/engine/tz_lookup.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The geocoder's job is not to find places. It is to refuse to produce a
/// [Place] the chart engine cannot use.
///
/// `Place.timezone` is fed to `tz.getLocation`, so a row carrying a timezone
/// the database does not know would either throw inside chart building or —
/// worse — be stored and throw on every subsequent launch. [placeFromGeoJson]
/// is the single gate against that, and most of this file is aimed at it.

Map<String, dynamic> _row({
  Object? name = 'Kathmandu',
  Object? country = 'Nepal',
  Object? admin1 = 'Bagmati Province',
  Object? latitude = 27.70169,
  Object? longitude = 85.3206,
  Object? timezone = 'Asia/Kathmandu',
}) =>
    {
      'name': ?name,
      'country': ?country,
      'admin1': ?admin1,
      'latitude': ?latitude,
      'longitude': ?longitude,
      'timezone': ?timezone,
    };

String _payload(List<Map<String, dynamic>> rows) =>
    jsonEncode({'results': rows, 'generationtime_ms': 0.4});

Geocoder _serving(String body, {int status = 200, List<Uri>? seen}) =>
    OpenMeteoGeocoder(
      client: MockClient((req) async {
        seen?.add(req.url);
        return http.Response(body, status, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      }),
    );

void main() {
  tzdata.initializeTimeZones();

  group('placeFromGeoJson', () {
    test('maps a real Open-Meteo row, and the result builds a chart', () {
      final place = placeFromGeoJson(_row());
      expect(place, isNotNull);
      expect(place!.name, 'Kathmandu');
      expect(place.region, 'Nepal');
      expect(place.timezone, 'Asia/Kathmandu');
      expect(place.isWellFormed, isTrue);

      // The property that matters: the mapped place survives the conversion
      // the engine actually performs.
      final utc = toUtc(BirthInput(
        id: 'g',
        name: 'Geocoded',
        localDateTime: DateTime(1992, 4, 14, 3, 57),
        place: place,
        timeSource: TimeSource.hospital,
      ));
      expect(utc.isUtc, isTrue);
    });

    test('every zone it emits is one the database can resolve', () {
      for (final id in const [
        'Asia/Kathmandu',
        'Europe/London',
        'America/New_York',
        'Australia/Sydney',
      ]) {
        final place = placeFromGeoJson(_row(timezone: id));
        expect(place, isNotNull, reason: id);
        expect(() => tz.getLocation(place!.timezone), returnsNormally,
            reason: id);
      }
    });

    test('a legacy IANA alias is accepted, not rejected as a bad place', () {
      // GeoNames emits backward-compatibility ids. These are valid IANA zones
      // that the `latest` database omits and `latest_all` carries — which is
      // the whole reason the app loads `latest_all`. Under `latest` this row
      // would be dropped and a reader in Kyiv would be told their city does
      // not exist.
      for (final legacy in const ['Europe/Kiev', 'Asia/Calcutta']) {
        expect(isKnownZone(legacy), isTrue,
            reason: '$legacy must resolve under latest_all');
        expect(placeFromGeoJson(_row(timezone: legacy)), isNotNull,
            reason: legacy);
      }
    });

    test('a row with no timezone is dropped', () {
      expect(placeFromGeoJson(_row(timezone: null)), isNull);
      expect(placeFromGeoJson(_row(timezone: '')), isNull);
    });

    test('a row with an unknown timezone is dropped', () {
      for (final bad in const [
        'Mars/Olympus',
        'Asia/Nowhere',
        'GMT+5:45',
        'not a zone',
      ]) {
        expect(placeFromGeoJson(_row(timezone: bad)), isNull, reason: bad);
      }
    });

    test('out-of-range or missing coordinates are dropped', () {
      expect(placeFromGeoJson(_row(latitude: 91)), isNull);
      expect(placeFromGeoJson(_row(latitude: -90.5)), isNull);
      expect(placeFromGeoJson(_row(longitude: 181)), isNull);
      expect(placeFromGeoJson(_row(latitude: null)), isNull);
      expect(placeFromGeoJson(_row(longitude: null)), isNull);
    });

    test('a nameless row, or one with no country and no admin1, is dropped', () {
      expect(placeFromGeoJson(_row(name: null)), isNull);
      expect(placeFromGeoJson(_row(name: '   ')), isNull);
      // An empty region would render Place.label with a trailing comma in six
      // display sites and the PDF export.
      expect(placeFromGeoJson(_row(country: null, admin1: null)), isNull);
    });

    test('admin1 stands in when country is absent', () {
      final place = placeFromGeoJson(_row(country: null));
      expect(place?.region, 'Bagmati Province');
    });

    test('it is total: no input shape makes it throw', () {
      for (final junk in <Map<String, dynamic>>[
        {},
        {'name': 42},
        {'name': 'X', 'latitude': 'not a number'},
        {'name': 'X', 'country': 'Y', 'latitude': 1, 'longitude': 2, 'timezone': 9},
      ]) {
        expect(() => placeFromGeoJson(junk), returnsNormally,
            reason: junk.toString());
      }
    });
  });

  group('OpenMeteoGeocoder', () {
    test('a good payload yields hits', () async {
      final result = await _serving(_payload([
        _row(),
        _row(name: 'London', country: 'United Kingdom', timezone: 'Europe/London'),
      ])).search('kath');
      expect(result, isA<GeocodeHits>());
      expect((result as GeocodeHits).places, hasLength(2));
    });

    test('a payload whose rows are all rejected is Empty, not Hits([])', () async {
      // The distinction the UI depends on: "we looked and found nothing
      // usable" must never render as an empty results list.
      final result = await _serving(_payload([
        _row(timezone: 'Mars/Olympus'),
        _row(latitude: 999),
      ])).search('nowhere');
      expect(result, isA<GeocodeEmpty>());
    });

    test('no results key, or an empty list, is Empty', () async {
      expect(await _serving(jsonEncode({'generationtime_ms': 0.1})).search('zz z'),
          isA<GeocodeEmpty>());
      expect(await _serving(_payload([])).search('zz z'), isA<GeocodeEmpty>());
    });

    test('a server error is Unreachable, not Empty', () async {
      final result = await _serving('nope', status: 500).search('london');
      expect(result, isA<GeocodeUnreachable>());
    });

    test('a dead socket is Unreachable and never escapes as an exception',
        () async {
      final geocoder = OpenMeteoGeocoder(
        client: MockClient((_) => throw const SocketException('no route')),
      );
      final result = await geocoder.search('london');
      expect(result, isA<GeocodeUnreachable>());
    });

    test('a timeout is Unreachable', () async {
      final geocoder = OpenMeteoGeocoder(
        client: MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 40),
      );
      expect(await geocoder.search('london'), isA<GeocodeUnreachable>());
    });

    test('malformed JSON is Unreachable, not a crash', () async {
      expect(await _serving('<html>502</html>').search('london'),
          isA<GeocodeUnreachable>());
    });

    test('a repeated query is served from cache', () async {
      final seen = <Uri>[];
      final geocoder = _serving(_payload([_row()]), seen: seen);
      await geocoder.search('kathmandu');
      await geocoder.search('  Kathmandu  ');
      expect(seen, hasLength(1), reason: 'the second query should not go out');
    });

    test('a transport failure is not cached', () async {
      var calls = 0;
      final geocoder = OpenMeteoGeocoder(
        client: MockClient((_) async {
          calls++;
          if (calls == 1) throw const SocketException('down');
          return http.Response(_payload([_row()]), 200);
        }),
      );
      expect(await geocoder.search('kathmandu'), isA<GeocodeUnreachable>());
      // The reader may have turned the wifi back on.
      expect(await geocoder.search('kathmandu'), isA<GeocodeHits>());
      expect(calls, 2);
    });

    test('the request carries the documented query and a User-Agent', () async {
      Uri? url;
      Map<String, String>? headers;
      final geocoder = OpenMeteoGeocoder(
        client: MockClient((req) async {
          url = req.url;
          headers = req.headers;
          return http.Response(_payload([_row()]), 200);
        }),
      );
      await geocoder.search('kathmandu', language: 'ne');
      expect(url!.host, 'geocoding-api.open-meteo.com');
      expect(url!.queryParameters['name'], 'kathmandu');
      expect(url!.queryParameters['language'], 'ne');
      expect(url!.scheme, 'https');
      expect(headers!['User-Agent'], contains('PocketAstro'));
    });

    test('an empty query never goes out', () async {
      final seen = <Uri>[];
      expect(await _serving(_payload([_row()]), seen: seen).search('   '),
          isA<GeocodeEmpty>());
      expect(seen, isEmpty);
    });
  });

  group('OfflineGeocoder', () {
    test('never resolves anything, and never throws', () async {
      expect(await const OfflineGeocoder().search('Kathmandu'),
          isA<GeocodeUnreachable>());
    });
  });

  group('tz_lookup', () {
    test('isKnownZone agrees with what getLocation will accept', () {
      expect(isKnownZone('Asia/Kathmandu'), isTrue);
      expect(isKnownZone('Mars/Olympus'), isFalse);
      expect(isKnownZone(''), isFalse);
    });

    test('locationFor names the id it could not resolve', () {
      expect(() => locationFor('Mars/Olympus'),
          throwsA(isA<UnknownTimezone>()));
      try {
        locationFor('Mars/Olympus');
      } on UnknownTimezone catch (e) {
        expect(e.id, 'Mars/Olympus');
        expect(e.toString(), contains('Mars/Olympus'));
      }
    });
  });
}

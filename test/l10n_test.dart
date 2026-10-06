import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/data/geocoder.dart';
import 'package:pocket_astro/engine/house_quality.dart';
import 'package:pocket_astro/engine/kb.dart';
import 'package:pocket_astro/engine/matching.dart';
import 'package:pocket_astro/engine/nature.dart';
import 'package:pocket_astro/engine/qa.dart';
import 'package:pocket_astro/engine/tables.dart';
import 'package:pocket_astro/l10n/engine_strings.dart';
import 'package:pocket_astro/l10n/generated/app_localizations.dart';
import 'package:pocket_astro/state/library_bloc.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Localisation has two halves that must stay in step: the generated widget
/// strings and the engine's own table. These tests check both, and check that
/// a partial knowledge-base translation degrades to English rather than to a
/// blank or a raw lookup key.

const _place = Place(
  name: 'Kathmandu',
  region: 'Nepal',
  latitude: 27.7172,
  longitude: 85.3240,
  timezone: 'Asia/Kathmandu',
);

BirthInput _chartInput() => BirthInput(
      id: 'l10n',
      name: 'Localised',
      localDateTime: DateTime(1992, 4, 14, 3, 57),
      place: _place,
      timeSource: TimeSource.hospital,
    );

/// Devanagari occupies U+0900–U+097F.
bool isDevanagari(String s) =>
    s.runes.any((r) => r >= 0x0900 && r <= 0x097F);

void main() {
  tzdata.initializeTimeZones();

  setUpAll(() {
    PredictionKb.loadFromMap(
      jsonDecode(File('assets/kb/prediction.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    PredictionKb.loadMatchingFromMap(
      jsonDecode(File('assets/kb/ashtakoota.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    for (final e in PredictionKb.moduleAssets.entries) {
      PredictionKb.loadModuleFromMap(
        e.key,
        jsonDecode(File(e.value).readAsStringSync()) as Map<String, dynamic>,
      );
    }
    for (final code in supportedLocaleCodes) {
      if (code == 'en') continue;
      EngineStrings.register(
        code,
        File('assets/kb/i18n/$code/engine.json').readAsStringSync(),
      );
    }
  });

  tearDown(() => EngineStrings.install('en'));

  group('widget strings', () {
    test('every ARB carries exactly the template\'s keys', () {
      Map<String, dynamic> arb(String code) => jsonDecode(
            File('lib/l10n/arb/app_$code.arb').readAsStringSync(),
          ) as Map<String, dynamic>;

      final template = arb('en').keys
          .where((k) => !k.startsWith('@'))
          .toSet();
      expect(template, isNotEmpty);

      for (final code in supportedLocaleCodes) {
        final keys = arb(code).keys.where((k) => !k.startsWith('@')).toSet();
        expect(keys.difference(template), isEmpty,
            reason: '$code has keys the English template does not');
        expect(template.difference(keys), isEmpty,
            reason: '$code is missing keys the English template has');
      }
    });

    test('the required invalid-location wording is exactly as specified', () {
      // The product specifies this sentence verbatim. Pinning it here rather
      // than hardcoding it in the widget keeps the string inside the l10n
      // suite — hardcoding would hide it from exactly the checks below.
      final en = jsonDecode(File('lib/l10n/arb/app_en.arb').readAsStringSync())
          as Map<String, dynamic>;
      expect(en['invalidLocation'], kInvalidLocationMessage);

      // And it must still be a real translation in the other two.
      for (final code in ['ne', 'hi']) {
        final loc = jsonDecode(
          File('lib/l10n/arb/app_$code.arb').readAsStringSync(),
        ) as Map<String, dynamic>;
        expect(isDevanagari(loc['invalidLocation'] as String), isTrue,
            reason: '$code must not ship the English sentence');
      }
    });

    test('translations are actually translated, not copied English', () {
      final en = jsonDecode(File('lib/l10n/arb/app_en.arb').readAsStringSync())
          as Map<String, dynamic>;
      for (final code in ['ne', 'hi']) {
        final loc = jsonDecode(
          File('lib/l10n/arb/app_$code.arb').readAsStringSync(),
        ) as Map<String, dynamic>;
        var identical = 0;
        for (final key in en.keys.where((k) => !k.startsWith('@'))) {
          if (en[key] == loc[key]) identical++;
        }
        // A handful of short labels legitimately match; a wholesale copy does
        // not. PDF is a loanword, for instance.
        expect(identical, lessThan(5),
            reason: '$code looks like copied English ($identical identical)');
      }
    });

    testWidgets('every supported locale resolves without falling back',
        (tester) async {
      for (final code in supportedLocaleCodes) {
        late L l;
        await tester.pumpWidget(MaterialApp(
          locale: Locale(code),
          supportedLocales: L.supportedLocales,
          localizationsDelegates: const [
            L.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(builder: (context) {
            l = L.of(context);
            return const SizedBox();
          }),
        ));
        expect(l.localeName, code);
        if (code != 'en') {
          expect(isDevanagari(l.tabOverview), isTrue,
              reason: '$code tab label is not in Devanagari');
          expect(isDevanagari(l.twelveAreas), isTrue);
        }
      }
    });
  });

  group('engine strings', () {
    test('every locale covers the whole English baseline', () {
      final baseline = EngineStrings.baselineKeys;
      expect(baseline.length, greaterThan(200));
      for (final code in supportedLocaleCodes) {
        if (code == 'en') continue;
        final keys = EngineStrings.keysFor(code);
        final missing = baseline.difference(keys);
        expect(missing, isEmpty,
            reason: '$code engine table is missing: '
                '${missing.take(8).join(', ')}');
        final extra = keys.difference(baseline);
        expect(extra, isEmpty,
            reason: '$code engine table has stray keys: '
                '${extra.take(8).join(', ')}');
        EngineStrings.install(code);
        expect(EngineStrings.current.coverage, 1.0);
      }
    });

    test('a missing key is returned visibly, never as blank', () {
      EngineStrings.install('ne');
      expect(tr('no.such.key'), 'no.such.key');
      expect(tr('no.such.key'), isNotEmpty);
    });

    test('placeholders substitute in every locale', () {
      for (final code in supportedLocaleCodes) {
        EngineStrings.install(code);
        final out = tr('hq.sav.above', {'n': 31});
        expect(out, contains('31'));
        expect(out, isNot(contains('{n}')));
      }
    });
  });

  group('engine output changes language', () {
    test('names, bands and verdicts switch script', () {
      for (final code in ['ne', 'hi']) {
        EngineStrings.install(code);
        expect(isDevanagari(grahaName('Saturn')), isTrue);
        expect(isDevanagari(signName(0)), isTrue);
        expect(isDevanagari(nakshatraName('Rohini')), isTrue);
        expect(isDevanagari(houseTopic(7)), isTrue);
        expect(isDevanagari(housePlainTitle(10)), isTrue);
        expect(isDevanagari(ordinal(4)), isTrue);
        for (final band in HouseBand.values) {
          expect(isDevanagari(band.label), isTrue);
          expect(isDevanagari(band.summary), isTrue);
        }
        for (final k in kootaNames) {
          expect(isDevanagari(kootaPlain(k).title), isTrue, reason: '$k in $code');
          expect(isDevanagari(kootaPlain(k).means), isTrue);
        }
        expect(isDevanagari(matchVerdict(30, 36)), isTrue);
      }
    });

    test('house readings are produced in the reader\'s language', () {
      final chart = chartFor(_chartInput());
      for (final code in ['ne', 'hi']) {
        EngineStrings.install(code);
        final readings = readHouses(chart);
        expect(readings, hasLength(12));
        for (final r in readings) {
          expect(isDevanagari(r.plainTitle), isTrue, reason: 'house ${r.house}');
          expect(isDevanagari(r.summary), isTrue);
          expect(isDevanagari(r.topic), isTrue);
          for (final reason in r.reasons) {
            expect(isDevanagari(reason.text), isTrue,
                reason: 'house ${r.house}: ${reason.text}');
            // A missing template would surface as a bare lookup key.
            expect(reason.text, isNot(startsWith('hq.')));
          }
        }
      }
    });

    test('the Q&A trace is produced in the reader\'s language', () {
      final chart = chartFor(_chartInput());
      for (final code in ['ne', 'hi']) {
        EngineStrings.install(code);
        final a = answerQuestion(chart, 'When is a good time to marry?');
        expect(a.steps, isNotEmpty);
        expect(isDevanagari(a.headline), isTrue);
        for (final s in a.steps) {
          expect(isDevanagari(s.label), isTrue, reason: '${s.kind} label');
          expect(s.label, isNot(startsWith('qa.')));
          expect(s.detail, isNot(startsWith('qa.')));
        }
        expect(isDevanagari(intentLabel('career')), isTrue);
      }
    });

    test('graha nature reasons switch language', () {
      final chart = chartFor(_chartInput());
      final nature = GrahaNature({
        for (final g in chart.grahas)
          if (navagraha.contains(g.name)) g.name: g.siderealLon,
      });
      for (final code in ['ne', 'hi']) {
        EngineStrings.install(code);
        for (final p in navagraha) {
          final reason = nature.reasonFor(p);
          expect(isDevanagari(reason), isTrue, reason: '$p in $code');
          expect(reason, isNot(startsWith('nature.')));
        }
        expect(isDevanagari(aspectExplanation('Mars')), isTrue);
      }
    });
  });

  group('knowledge-base overlays', () {
    test('an overlay replaces only leaves it carries', () {
      final base = <String, dynamic>{
        'title': 'English title',
        'count': 7,
        'nested': {'a': 'English a', 'b': 'English b'},
        'list': ['one', 'two'],
      };
      final merged = PredictionKb.mergeOverlay(base, {
        'title': 'अनुवाद',
        'nested': {'a': 'अनुवाद a'},
        'list': ['एक'],
      });
      expect(merged['title'], 'अनुवाद');
      expect(merged['nested']['a'], 'अनुवाद a');
      // Untranslated leaves keep their English, which is the whole point.
      expect(merged['nested']['b'], 'English b');
      expect(merged['list'], ['एक', 'two']);
      expect(merged['count'], 7);
    });

    test('an overlay can never add a key or change a number', () {
      final merged = PredictionKb.mergeOverlay(
        <String, dynamic>{'kept': 'base', 'number': 42},
        <String, dynamic>{'kept': 'new', 'sneaked': 'in', 'number': 99},
      );
      expect(merged['kept'], 'new');
      expect(merged.containsKey('sneaked'), isFalse);
      expect(merged['number'], 42);
    });

    test('a shape mismatch is ignored rather than corrupting the base', () {
      final merged = PredictionKb.mergeOverlay(
        <String, dynamic>{'houses': [1, 2, 3], 'note': 'text'},
        <String, dynamic>{'houses': 'not a list', 'note': 99},
      );
      expect(merged['houses'], [1, 2, 3]);
      expect(merged['note'], 'text');
    });

    test('every shipped overlay is structurally valid against its base', () {
      for (final code in ['ne', 'hi']) {
        final dir = Directory('assets/kb/i18n/$code');
        expect(dir.existsSync(), isTrue, reason: '$code overlay directory');
        for (final f in dir.listSync().whereType<File>()) {
          final name = f.uri.pathSegments.last;
          if (name == 'engine.json') continue;
          final basePath = File('assets/kb/$name');
          expect(basePath.existsSync(), isTrue,
              reason: '$code/$name has no base module');
          final base =
              jsonDecode(basePath.readAsStringSync()) as Map<String, dynamic>;
          final over = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
          // Merging must not change the shape: same key count at the top.
          final merged = PredictionKb.mergeOverlay(base, over);
          expect(merged.keys.length, base.keys.length,
              reason: '$code/$name changed the module shape');
        }
      }
    });

    test('a translated yoga effect reaches the reading, untranslated stays English',
        () {
      final base =
          jsonDecode(File('assets/kb/yogas.json').readAsStringSync())
              as Map<String, dynamic>;
      final over =
          jsonDecode(File('assets/kb/i18n/ne/yogas.json').readAsStringSync())
              as Map<String, dynamic>;
      final merged = PredictionKb.mergeOverlay(base, over);
      final yogas = (merged['yogas'] as List).cast<Map<String, dynamic>>();

      final gaja = yogas.firstWhere((y) => y['id'] == 'gaja_kesari');
      expect(isDevanagari(gaja['effect'] as String), isTrue);
      // Structure survives the merge untouched.
      expect(gaja['weight'], isA<int>());
      expect(gaja['conditions'], isA<List>());

      // An untranslated yoga keeps its English rather than going blank.
      final untranslated = yogas.firstWhere((y) => y['id'] == 'yoopa');
      expect(untranslated['effect'], isNotEmpty);
      expect(isDevanagari(untranslated['effect'] as String), isFalse);
    });
  });

  group('scalability', () {
    test('adding a locale needs an ARB file and an asset directory only', () {
      for (final code in supportedLocaleCodes) {
        expect(File('lib/l10n/arb/app_$code.arb').existsSync(), isTrue,
            reason: '$code has no ARB');
        if (code == 'en') continue;
        expect(File('assets/kb/i18n/$code/engine.json').existsSync(), isTrue,
            reason: '$code has no engine table');
      }
      expect(localeNames.keys.toSet(), supportedLocaleCodes.toSet());
    });

    test('an unknown locale degrades to English rather than breaking', () {
      EngineStrings.install('xx');
      expect(EngineStrings.current.locale, 'xx');
      // English is compiled in, so nothing is blank.
      expect(grahaName('Saturn'), 'Saturn');
      expect(housePlainTitle(1), isNotEmpty);
      expect(housePlainTitle(1), isNot(startsWith('house.')));
    });
  });
}

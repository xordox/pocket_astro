import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_astro/domain/models.dart';
import 'package:pocket_astro/engine/kb.dart';
import 'package:pocket_astro/engine/tables.dart';
import 'package:pocket_astro/engine/yoga.dart';

/// Coverage test for the yoga evaluator.
///
/// Every yoga in `assets/kb/yogas.json` gets a synthetic chart built to satisfy
/// its classical definition, and must be detected on it. A yoga that ships in
/// the catalogue but can never fire is a dead rule, so this test enumerates the
/// catalogue rather than a fixed list — adding a yoga without a fixture fails.

// Mid-sign longitudes, kept away from cusps so nothing lands on a boundary.
const ari = 5.0, tau = 35.0, gem = 65.0, can = 95.0;
const leo = 125.0, vir = 155.0, lib = 185.0, sco = 215.0;
const sag = 245.0, cap = 275.0, aqu = 305.0, pis = 335.0;

/// Builds graha rows from sidereal longitudes.
///
/// [day] only matters for Maha Bhagya, which needs the Sun above the horizon;
/// equal-from-ascendant houses 7 to 12 are the visible half.
List<GrahaRow> rows(double lagna, Map<String, double> lons, {bool day = true}) {
  final lagnaSign = signIndex(lagna);
  final all = <String, double>{'Rahu': tau + 10, 'Ketu': sco + 10, ...lons};
  final out = <GrahaRow>[
    GrahaRow(
      name: 'Lagna',
      tropicalLon: lagna,
      siderealLon: lagna,
      sign: signOf(lagna).name,
      house: 1,
      nakshatra: nakshatraOf(lagna).name,
      pada: padaOf(lagna),
      dignity: '',
      westernHouse: 1,
    ),
  ];
  all.forEach((name, lon) {
    out.add(
      GrahaRow(
        name: name,
        tropicalLon: lon,
        siderealLon: lon,
        sign: signOf(lon).name,
        house: wholeSignHouse(lagnaSign, signIndex(lon)),
        nakshatra: nakshatraOf(lon).name,
        pada: padaOf(lon),
        dignity: dignityLabel(name, lon),
        westernHouse: name == 'Sun' ? (day ? 10 : 4) : 1,
      ),
    );
  });
  return out;
}

/// Spreads the seven classical grahas across the given longitudes, cycling if
/// fewer are supplied than grahas.
Map<String, double> spread(List<double> lons) {
  const seven = ['Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn'];
  return {
    for (var i = 0; i < seven.length; i++) seven[i]: lons[i % lons.length],
  };
}

class Fixture {
  const Fixture(this.lagna, this.lons, {this.day = true, this.mustStand = true});
  final double lagna;
  final Map<String, double> lons;
  final bool day;

  /// False when the fixture only has to be *detected* — some yogas are, by
  /// classical design, superseded or cancelled whenever they form.
  final bool mustStand;
}

/// One chart per yoga, each built to the classical definition.
final fixtures = <String, Fixture>{
  // --- Pancha Mahapurusha: dignified in a kendra, with benefic support -----
  'ruchaka': Fixture(ari, {
    'Mars': ari + 15, // own sign, house 1
    'Jupiter': sag, // aspects Aries by its 5th
    'Sun': leo, 'Moon': can, 'Mercury': vir, 'Venus': lib, 'Saturn': aqu,
  }),
  'bhadra': Fixture(sag, {
    'Mercury': vir, // exalted + own, house 10 from Sagittarius
    'Jupiter': tau, // aspects Virgo by its 5th
    'Sun': aqu, 'Moon': can, 'Mars': ari, 'Venus': pis, 'Saturn': lib,
  }),
  'hamsa': Fixture(ari, {
    'Jupiter': can, // exalted, house 4
    'Mercury': can, // a benefic joins it, so the yoga is not malefic-only
    'Venus': pis, 'Sun': leo, 'Moon': lib, 'Mars': sco, 'Saturn': aqu,
    'Rahu': gem, 'Ketu': sag, // off the Cancer axis
  }),
  'malavya': Fixture(sag, {
    'Venus': pis, // exalted, house 4 from Sagittarius
    'Jupiter': sco, // aspects Pisces by its 5th
    'Sun': aqu, 'Moon': can, 'Mars': ari, 'Mercury': gem, 'Saturn': lib,
  }),
  'shasha': Fixture(ari, {
    'Saturn': lib, // exalted, house 7
    'Jupiter': gem, // aspects Libra by its 5th
    'Sun': leo, 'Moon': can, 'Mars': sco, 'Mercury': vir, 'Venus': pis,
  }),

  // --- Chandra yogas -------------------------------------------------------
  'sunapha': Fixture(ari, {
    'Moon': ari, 'Mars': tau, // 2nd from Moon
    'Sun': sco, 'Mercury': vir, 'Jupiter': sag, 'Venus': leo, 'Saturn': cap,
  }),
  'anapha': Fixture(ari, {
    'Moon': tau, 'Mars': ari, // 12th from Moon
    'Sun': sco, 'Mercury': vir, 'Jupiter': sag, 'Venus': leo, 'Saturn': cap,
  }),
  'durudhara': Fixture(ari, {
    'Moon': tau, 'Mars': ari, 'Mercury': gem, // 12th and 2nd from Moon
    'Sun': sco, 'Jupiter': sag, 'Venus': leo, 'Saturn': cap,
  }),
  // Kemadruma forms constantly and is cancelled almost as often; the
  // cancellation behaviour is asserted separately below.
  'kemadruma': Fixture(ari, {
    'Moon': ari,
    'Sun': leo, 'Mars': leo, 'Mercury': leo, 'Jupiter': leo, 'Venus': leo,
    'Saturn': leo,
  }, mustStand: false),
  'adhi': Fixture(ari, {
    'Moon': ari,
    'Mercury': vir, 'Jupiter': lib, 'Venus': sco, // 6th, 7th, 8th from Moon
    'Sun': leo, 'Mars': cap, 'Saturn': aqu,
    'Rahu': gem, 'Ketu': sag, // keep the nodes out of the 6th to 8th
  }),
  'chandra_dhana': Fixture(ari, {
    'Moon': ari,
    'Mercury': gem, 'Jupiter': vir, 'Venus': aqu, // 3rd, 6th, 11th from Moon
    'Sun': leo, 'Mars': cap, 'Saturn': sco,
  }),
  'gaja_kesari': Fixture(ari, {
    'Moon': ari, 'Jupiter': can, // 4th from Moon
    'Sun': leo, 'Mars': sco, 'Mercury': vir, 'Venus': tau, 'Saturn': aqu,
  }),
  'shakata': Fixture(ari, {
    'Moon': ari, 'Jupiter': vir, // 6th from Moon, house 6 (not a kendra)
    'Sun': leo, 'Mars': sco, 'Mercury': gem, 'Venus': tau, 'Saturn': aqu,
  }),

  // --- Ravi yogas ----------------------------------------------------------
  'veshi': Fixture(ari, {
    'Sun': ari, 'Mars': tau, // 2nd from Sun
    'Moon': sco, 'Mercury': vir, 'Jupiter': sag, 'Venus': leo, 'Saturn': cap,
  }),
  'voshi': Fixture(ari, {
    'Sun': tau, 'Mars': ari, // 12th from Sun
    'Moon': sco, 'Mercury': vir, 'Jupiter': sag, 'Venus': leo, 'Saturn': cap,
  }),
  'ubhayachari': Fixture(ari, {
    'Sun': tau, 'Mars': ari, 'Mercury': gem,
    'Moon': sco, 'Jupiter': sag, 'Venus': leo, 'Saturn': cap,
  }),
  'budhaditya': Fixture(ari, {
    'Sun': leo, 'Mercury': leo,
    'Moon': ari, 'Mars': sco, 'Jupiter': sag, 'Venus': tau, 'Saturn': cap,
  }),

  // --- Raja yogas (Aries lagna: 4L Moon, 5L Sun, 9L Jupiter, 10L Saturn) ---
  'raja_kendra_trikona': Fixture(ari, {
    'Moon': leo, 'Sun': leo, // 4th and 5th lords conjunct
    'Mars': ari, 'Mercury': gem, 'Jupiter': sag, 'Venus': tau, 'Saturn': aqu,
  }),
  'raja_5_9': Fixture(ari, {
    'Sun': leo, 'Jupiter': leo, // 5th and 9th lords conjunct
    'Moon': can, 'Mars': ari, 'Mercury': gem, 'Venus': tau, 'Saturn': aqu,
  }),
  'raja_9_10': Fixture(ari, {
    'Jupiter': leo, 'Saturn': leo, // 9th and 10th lords conjunct
    'Sun': can, 'Moon': can, 'Mars': ari, 'Mercury': gem, 'Venus': tau,
  }),
  'raja_4_10_exchange': Fixture(ari, {
    'Moon': cap, 'Saturn': can, // 4th and 10th lords exchange
    'Sun': leo, 'Mars': ari, 'Mercury': gem, 'Jupiter': sag, 'Venus': tau,
  }),
  'neecha_bhanga': Fixture(ari, {
    'Mercury': pis, // debilitated
    'Jupiter': can, // debilitation lord in a kendra from the lagna
    'Sun': leo, 'Moon': lib, 'Mars': sco, 'Venus': tau, 'Saturn': aqu,
  }),

  // --- Dhana yogas ---------------------------------------------------------
  'dhana_core': Fixture(ari, {
    'Mars': leo, 'Sun': leo, // 1st and 5th lords conjunct
    'Moon': can, 'Mercury': gem, 'Jupiter': sag, 'Venus': tau, 'Saturn': aqu,
  }),
  'dhana_2_11': Fixture(ari, {
    'Venus': leo, 'Saturn': leo, // 2nd and 11th lords conjunct
    'Sun': can, 'Moon': can, 'Mars': ari, 'Mercury': gem, 'Jupiter': sag,
  }),
  'chandra_mangala': Fixture(ari, {
    'Moon': leo, 'Mars': leo,
    'Sun': can, 'Mercury': gem, 'Jupiter': sag, 'Venus': tau, 'Saturn': aqu,
  }),
  'lakshmi': Fixture(ari, {
    'Jupiter': can, // 9th lord exalted in a kendra
    'Sun': leo, 'Moon': lib, 'Mars': ari, 'Mercury': gem, 'Venus': tau,
    'Saturn': aqu,
  }),
  'amala': Fixture(ari, {
    'Venus': cap, // benefic in the 10th
    'Sun': leo, 'Moon': can, 'Mars': ari, 'Mercury': gem, 'Jupiter': sag,
    'Saturn': aqu,
  }),

  // --- Structural ----------------------------------------------------------
  'shubha_kartari': Fixture(ari, {
    'Venus': tau, 'Jupiter': pis, // benefics in the 2nd and 12th
    'Sun': leo, 'Moon': can, 'Mars': sco, 'Mercury': gem, 'Saturn': aqu,
  }),
  'papa_kartari': Fixture(ari, {
    'Saturn': tau, 'Mars': pis, // malefics in the 2nd and 12th
    'Sun': leo, 'Moon': can, 'Mercury': gem, 'Jupiter': sag, 'Venus': lib,
  }),
  'parvata': Fixture(ari, {
    'Jupiter': can, 'Venus': lib, // benefics in two kendras
    'Sun': leo, 'Moon': gem, 'Mars': sag, 'Mercury': aqu, 'Saturn': tau,
    'Rahu': leo, 'Ketu': aqu, // keep the nodes out of the 6th and 8th
  }),
  'chamara': Fixture(ari, {
    'Mars': cap, // lagna lord exalted in a kendra
    'Jupiter': vir, // aspects Capricorn by its 5th
    'Sun': leo, 'Moon': can, 'Mercury': gem, 'Venus': tau, 'Saturn': aqu,
  }),
  'chatussagara': Fixture(ari, spread([ari, can, lib, cap])),
  'maha_bhagya': Fixture(ari, {
    'Sun': leo, 'Moon': sag, // odd lagna, odd Sun, odd Moon, day birth
    'Mars': ari, 'Mercury': gem, 'Jupiter': aqu, 'Venus': lib, 'Saturn': lib,
  }),
  'vargottama': Fixture(ari, {
    // Aries 5° falls in the second navamsa of Aries, which is Taurus; the
    // first navamsa (0°–3°20') is Aries itself and therefore vargottama.
    'Sun': 1.0,
    'Moon': can, 'Mars': sco, 'Mercury': gem, 'Jupiter': sag, 'Venus': tau,
    'Saturn': aqu,
  }),
  'parivartana_maha': Fixture(ari, {
    'Mars': tau, 'Venus': ari, // 1st and 2nd lords exchange
    'Sun': leo, 'Moon': can, 'Mercury': gem, 'Jupiter': sag, 'Saturn': aqu,
  }),
  'parivartana_dainya': Fixture(ari, {
    'Mercury': ari, 'Mars': vir, // 6th and 1st lords exchange
    'Sun': leo, 'Moon': can, 'Jupiter': sag, 'Venus': tau, 'Saturn': aqu,
  }),

  // --- Vipreeta raja -------------------------------------------------------
  'vipreeta_harsha': Fixture(ari, {
    'Mercury': sco, // 6th lord in the 8th
    'Sun': leo, 'Moon': can, 'Mars': ari, 'Jupiter': sag, 'Venus': tau,
    'Saturn': aqu,
  }),
  'vipreeta_sarala': Fixture(ari, {
    'Mars': vir, // 8th lord in the 6th
    'Sun': leo, 'Moon': can, 'Mercury': gem, 'Jupiter': sag, 'Venus': tau,
    'Saturn': aqu,
  }),
  'vipreeta_vimala': Fixture(ari, {
    'Jupiter': vir, // 12th lord in the 6th
    'Sun': leo, 'Moon': can, 'Mars': ari, 'Mercury': gem, 'Venus': tau,
    'Saturn': aqu,
  }),

  // --- Spiritual -----------------------------------------------------------
  'pravrajya_kendra': Fixture(ari, {
    // Four grahas including the 10th lord gather in the 10th.
    'Saturn': cap, 'Sun': cap, 'Mercury': cap, 'Venus': cap,
    'Moon': can, 'Mars': ari, 'Jupiter': sag,
  }),
  'ketu_12_moksha': Fixture(ari, {
    'Sun': leo, 'Moon': can, 'Mars': ari, 'Mercury': gem, 'Jupiter': sag,
    'Venus': tau, 'Saturn': aqu, 'Ketu': pis, 'Rahu': vir,
  }),

  // --- Arishta -------------------------------------------------------------
  'arishta_trik_link': Fixture(ari, {
    'Mars': leo, 'Mercury': leo, // 1st and 6th lords conjunct
    'Sun': can, 'Moon': can, 'Jupiter': sag, 'Venus': tau, 'Saturn': aqu,
  }),
  'daridra_1_12': Fixture(ari, {
    'Mars': pis, 'Jupiter': ari, // 1st and 12th lords exchange
    'Venus': pis, // maraka (2nd/7th lord) joins the lagna lord
    'Sun': leo, 'Moon': can, 'Mercury': gem, 'Saturn': aqu,
  }),
  'kala_sarpa': Fixture(ari, {
    'Rahu': 0.0, 'Ketu': 180.0,
    // Strictly inside the arc, and none sharing a sign with either node.
    'Sun': 35.0, 'Moon': 50.0, 'Mars': 80.0, 'Mercury': 110.0,
    'Jupiter': 130.0, 'Venus': 150.0, 'Saturn': 170.0,
  }),
  'hatha_hanta': Fixture(ari, {
    'Moon': aqu, // house 11
    'Sun': can, // Cancer
    'Mars': ari, 'Mercury': gem, 'Jupiter': sag, 'Venus': tau, 'Saturn': lib,
  }),

  // --- Nabhasa Aashraya (superseded by an Aakriti whenever both form) ------
  'rajju': Fixture(tau, spread([ari, can, lib, cap]), mustStand: false),
  'musala': Fixture(ari, spread([tau, leo, sco, aqu]), mustStand: false),
  'nala': Fixture(ari, spread([gem, vir, sag, pis]), mustStand: false),

  // --- Nabhasa Dala --------------------------------------------------------
  'maala': Fixture(ari, {
    'Jupiter': ari, 'Venus': can, 'Mercury': lib, // benefics in three kendras
    'Sun': tau, 'Mars': gem, 'Saturn': leo, 'Moon': vir,
  }),
  'sarpa': Fixture(ari, {
    'Sun': ari, 'Mars': can, 'Saturn': lib, // malefics in three kendras
    'Jupiter': tau, 'Venus': gem, 'Mercury': leo, 'Moon': vir,
  }),

  // --- Nabhasa Aakriti -----------------------------------------------------
  'gada': Fixture(ari, spread([ari, can])),
  'shakata_nabhasa': Fixture(ari, spread([ari, lib])),
  'pakshi': Fixture(ari, spread([can, cap])),
  'vajra': Fixture(ari, {
    'Jupiter': ari, // benefics in 1 and 7
    'Venus': lib, 'Mercury': lib,
    'Sun': can, 'Mars': can, 'Saturn': cap, // malefics in 4 and 10
    'Moon': ari,
  }),
  'yava': Fixture(ari, {
    'Sun': ari, 'Mars': lib, 'Saturn': lib, // malefics in 1 and 7
    'Jupiter': can, 'Venus': cap, 'Mercury': cap, // benefics in 4 and 10
    'Moon': can,
  }),
  'kamala': Fixture(ari, spread([ari, can, lib, cap])),
  'vaapi': Fixture(ari, spread([tau, gem, leo, vir, sco, sag])),
  'shringataka': Fixture(ari, spread([ari, leo, sag])),
  'hala': Fixture(ari, spread([tau, vir, cap])),
  'yoopa': Fixture(ari, spread([ari, tau, gem, can])),
  'shara': Fixture(ari, spread([can, leo, vir, lib])),
  'shakti': Fixture(ari, spread([lib, sco, sag, cap])),
  'danda': Fixture(ari, spread([cap, aqu, pis, ari])),
  'nauka': Fixture(ari, {
    'Sun': ari, 'Moon': tau, 'Mars': gem, 'Mercury': can, 'Jupiter': leo,
    'Venus': vir, 'Saturn': lib,
  }),
  'koota': Fixture(ari, {
    'Sun': can, 'Moon': leo, 'Mars': vir, 'Mercury': lib, 'Jupiter': sco,
    'Venus': sag, 'Saturn': cap,
  }),
  'chhatra': Fixture(ari, {
    'Sun': lib, 'Moon': sco, 'Mars': sag, 'Mercury': cap, 'Jupiter': aqu,
    'Venus': pis, 'Saturn': ari,
  }),
  'chaapa': Fixture(ari, {
    'Sun': cap, 'Moon': aqu, 'Mars': pis, 'Mercury': ari, 'Jupiter': tau,
    'Venus': gem, 'Saturn': can,
  }),
  'ardha_chandra': Fixture(ari, {
    // Seven contiguous houses starting at the 2nd.
    'Sun': tau, 'Moon': gem, 'Mars': can, 'Mercury': leo, 'Jupiter': vir,
    'Venus': lib, 'Saturn': sco,
  }),
  'chakra': Fixture(ari, spread([ari, gem, leo, lib, sag, aqu])),
  'samudra': Fixture(ari, spread([tau, can, vir, sco, cap, pis])),

  // --- Nabhasa Sankhya (yield to any Aakriti or Aashraya yoga) -------------
  'veena': Fixture(ari, {
    'Sun': ari, 'Moon': tau, 'Mars': gem, 'Mercury': can, 'Jupiter': leo,
    'Venus': vir, 'Saturn': sco,
  }),
  'daama': Fixture(ari, {
    'Sun': ari, 'Moon': tau, 'Mars': gem, 'Mercury': can, 'Jupiter': leo,
    'Venus': sco, 'Saturn': sco,
  }),
  'paasha': Fixture(ari, {
    'Sun': ari, 'Moon': tau, 'Mars': gem, 'Mercury': can, 'Jupiter': sco,
    'Venus': sco, 'Saturn': sco,
  }),
  'kedaara': Fixture(ari, {
    'Sun': ari, 'Moon': tau, 'Mars': gem, 'Mercury': sco, 'Jupiter': sco,
    'Venus': sco, 'Saturn': sco,
  }),
  'shoola': Fixture(ari, {
    'Sun': ari, 'Moon': ari, 'Mars': gem, 'Mercury': gem, 'Jupiter': sco,
    'Venus': sco, 'Saturn': sco,
  }),
  'yuga': Fixture(ari, {
    'Sun': ari, 'Moon': ari, 'Mars': ari, 'Mercury': sco, 'Jupiter': sco,
    'Venus': sco, 'Saturn': sco,
  }),
  'gola': Fixture(ari, spread([leo])),
};

YogaReport reportFor(Fixture f) => detectYogas(
      grahas: rows(f.lagna, f.lons, day: f.day),
      lagnaSidereal: f.lagna,
      noLagna: false,
    );

void main() {
  late List<Map<String, dynamic>> catalogue;

  setUpAll(() {
    PredictionKb.loadFromMap(
      jsonDecode(File('assets/kb/prediction.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    for (final e in PredictionKb.moduleAssets.entries) {
      PredictionKb.loadModuleFromMap(
        e.key,
        jsonDecode(File(e.value).readAsStringSync()) as Map<String, dynamic>,
      );
    }
    catalogue = PredictionKb.current.yogas;
  });

  test('every catalogued yoga has a fixture', () {
    final ids = catalogue.map((y) => y['id'] as String).toSet();
    expect(ids.length, 77);
    final missing = ids.difference(fixtures.keys.toSet());
    expect(missing, isEmpty,
        reason: 'no detection fixture for: ${missing.join(', ')}');
    final stray = fixtures.keys.toSet().difference(ids);
    expect(stray, isEmpty, reason: 'fixture for unknown yoga: $stray');
  });

  group('detection', () {
    for (final entry in fixtures.entries) {
      test(entry.key, () {
        final report = reportFor(entry.value);
        final hit =
            report.hits.where((h) => h.id == entry.key).toList();
        expect(hit, hasLength(1),
            reason: '${entry.key} not detected on its own fixture. '
                'Detected: ${report.hits.map((h) => h.id).join(', ')}');
        expect(hit.single.detail, isNotEmpty,
            reason: '${entry.key} must say what formed it');
        if (entry.value.mustStand) {
          expect(hit.single.stands, isTrue,
              reason: '${entry.key} was cancelled or superseded: '
                  '${hit.single.cancelledBy.join(' ')}'
                  '${hit.single.supersededBy ?? ''}');
        }
      });
    }
  });

  test('detail names the actual placements, not the definition', () {
    final r = reportFor(fixtures['raja_9_10']!);
    final hit = r.hits.firstWhere((h) => h.id == 'raja_9_10');
    expect(hit.detail, contains('Jupiter'));
    expect(hit.detail, contains('Saturn'));
    expect(hit.detail, contains('conjunct'));
  });

  group('cancellations', () {
    test('Kemadruma falls to grahas in kendras', () {
      // Moon alone with the 2nd and 12th from it empty, but other grahas
      // sitting in kendras from the lagna — the commonest real configuration.
      final r = detectYogas(
        grahas: rows(ari, {
          'Moon': ari,
          'Sun': leo, 'Mars': can, 'Mercury': leo, 'Jupiter': lib,
          'Venus': leo, 'Saturn': leo,
        }),
        lagnaSidereal: ari,
        noLagna: false,
      );
      final k = r.hits.firstWhere((h) => h.id == 'kemadruma');
      expect(k.stands, isFalse);
      expect(k.cancelledBy, isNotEmpty);
      expect(k.line, contains('Cancelled'));
    });

    test('Gaja Kesari is reported as not standing when Jupiter is combust', () {
      final r = detectYogas(
        grahas: rows(ari, {
          'Moon': ari, 'Jupiter': can + 2, 'Sun': can, // Jupiter inside 11°
          'Mars': sco, 'Mercury': vir, 'Venus': tau, 'Saturn': aqu,
        }),
        lagnaSidereal: ari,
        noLagna: false,
      );
      final g = r.hits.firstWhere((h) => h.id == 'gaja_kesari');
      expect(g.stands, isFalse);
      expect(g.cancelledBy.join(' '), contains('combust'));
    });

    test('Shakata is inoperative when Jupiter and the Moon are both strong', () {
      // Moon in Cancer (own), Jupiter in Sagittarius (own) is the 6th from it.
      final r = detectYogas(
        grahas: rows(lib, {
          'Moon': can, 'Jupiter': sag,
          'Sun': tau, 'Mars': ari, 'Mercury': gem, 'Venus': aqu,
          'Saturn': pis,
        }),
        lagnaSidereal: lib,
        noLagna: false,
      );
      final s = r.hits.firstWhere((h) => h.id == 'shakata');
      expect(s.stands, isFalse);
      expect(s.cancelledBy.join(' '), contains('Both Jupiter and the Moon'));
    });

    test('Kala Sarpa breaks when a graha shares a sign with a node', () {
      final r = detectYogas(
        grahas: rows(ari, {
          'Rahu': 0.0, 'Ketu': 180.0,
          'Sun': 2.0, // same sign as Rahu
          'Moon': 50.0, 'Mars': 80.0, 'Mercury': 110.0, 'Jupiter': 130.0,
          'Venus': 150.0, 'Saturn': 170.0,
        }),
        lagnaSidereal: ari,
        noLagna: false,
      );
      final k = r.hits.firstWhere((h) => h.id == 'kala_sarpa');
      expect(k.stands, isFalse);
      expect(k.cancelledBy.join(' '), contains('breaks the enclosure'));
    });

    test('a mahapurusha yoga reached only by malefics does not stand', () {
      final r = detectYogas(
        grahas: rows(ari, {
          'Saturn': lib, // exalted in a kendra: Shasha
          'Mars': ari, // aspects Libra by its 7th
          'Sun': aqu, // aspects Libra by its 7th
          'Moon': can, 'Mercury': gem, 'Jupiter': tau, 'Venus': vir,
        }),
        lagnaSidereal: ari,
        noLagna: false,
      );
      final s = r.hits.firstWhere((h) => h.id == 'shasha');
      expect(s.stands, isFalse);
      expect(s.cancelledBy.join(' '), contains('Only malefics'));
    });
  });

  group('Nabhasa precedence (Charak XX)', () {
    test('an Aakriti yoga supersedes a Sankhya yoga', () {
      // All seven in the four kendras: Kamala (Aakriti) and Kedaara (Sankhya).
      final r = reportFor(fixtures['kamala']!);
      final kamala = r.hits.firstWhere((h) => h.id == 'kamala');
      final kedaara = r.hits.firstWhere((h) => h.id == 'kedaara');
      expect(kamala.stands, isTrue);
      expect(kedaara.stands, isFalse);
      expect(kedaara.supersededBy, 'Kamala Yoga');
      expect(kedaara.line, contains('precedence'));
    });

    test('Gola survives and cancels the Aashraya yoga instead', () {
      // All seven in Leo: Gola (Sankhya) with Musala (Aashraya, fixed signs).
      final r = reportFor(fixtures['gola']!);
      final gola = r.hits.firstWhere((h) => h.id == 'gola');
      final musala = r.hits.firstWhere((h) => h.id == 'musala');
      expect(gola.stands, isTrue, reason: 'Gola is the stated exception');
      expect(musala.stands, isFalse);
      expect(musala.supersededBy, 'Gola Yoga');
    });
  });

  group('no birth time', () {
    test('lagna-bound yogas are skipped, Moon-based ones still run', () {
      final f = fixtures['gaja_kesari']!;
      final r = detectYogas(
        grahas: rows(f.lagna, f.lons),
        lagnaSidereal: f.lagna,
        noLagna: true,
      );
      expect(r.skippedForNoBirthTime, greaterThan(40));
      expect(r.hits.any((h) => h.id == 'gaja_kesari'), isTrue);
      for (final h in r.hits) {
        final def =
            catalogue.firstWhere((y) => y['id'] == h.id);
        expect(def['requires_lagna'], isFalse,
            reason: '${h.id} needs a lagna but ran without one');
      }
    });
  });

  test('an empty catalogue yields an empty report rather than throwing', () {
    final saved = Map<String, dynamic>.from(
      PredictionKb.modules['yogas'] ?? const {},
    );
    PredictionKb.loadModuleFromMap('yogas', const {});
    final r = detectYogas(
      grahas: rows(ari, fixtures['kamala']!.lons),
      lagnaSidereal: ari,
      noLagna: false,
    );
    expect(r.hits, isEmpty);
    PredictionKb.loadModuleFromMap('yogas', saved);
  });
}

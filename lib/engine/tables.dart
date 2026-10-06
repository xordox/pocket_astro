import '../l10n/engine_strings.dart';

class SignInfo {
  const SignInfo({
    required this.index,
    required this.name,
    required this.sanskrit,
    required this.element,
    required this.mode,
    required this.ruler,
  });

  final int index; // 0..11
  final String name;
  final String sanskrit;
  final String element;
  final String mode;
  final String ruler;
}

const signs = <SignInfo>[
  SignInfo(index: 0, name: 'Aries', sanskrit: 'Mesha', element: 'Fire', mode: 'Cardinal', ruler: 'Mars'),
  SignInfo(index: 1, name: 'Taurus', sanskrit: 'Vrisha', element: 'Earth', mode: 'Fixed', ruler: 'Venus'),
  SignInfo(index: 2, name: 'Gemini', sanskrit: 'Mithuna', element: 'Air', mode: 'Mutable', ruler: 'Mercury'),
  SignInfo(index: 3, name: 'Cancer', sanskrit: 'Karka', element: 'Water', mode: 'Cardinal', ruler: 'Moon'),
  SignInfo(index: 4, name: 'Leo', sanskrit: 'Simha', element: 'Fire', mode: 'Fixed', ruler: 'Sun'),
  SignInfo(index: 5, name: 'Virgo', sanskrit: 'Kanya', element: 'Earth', mode: 'Mutable', ruler: 'Mercury'),
  SignInfo(index: 6, name: 'Libra', sanskrit: 'Tula', element: 'Air', mode: 'Cardinal', ruler: 'Venus'),
  SignInfo(index: 7, name: 'Scorpio', sanskrit: 'Vrischika', element: 'Water', mode: 'Fixed', ruler: 'Mars'),
  SignInfo(index: 8, name: 'Sagittarius', sanskrit: 'Dhanu', element: 'Fire', mode: 'Mutable', ruler: 'Jupiter'),
  SignInfo(index: 9, name: 'Capricorn', sanskrit: 'Makara', element: 'Earth', mode: 'Cardinal', ruler: 'Saturn'),
  SignInfo(index: 10, name: 'Aquarius', sanskrit: 'Kumbha', element: 'Air', mode: 'Fixed', ruler: 'Saturn'),
  SignInfo(index: 11, name: 'Pisces', sanskrit: 'Meena', element: 'Water', mode: 'Mutable', ruler: 'Jupiter'),
];

SignInfo signOf(double lon) => signs[(lon / 30).floor() % 12];

int signIndex(double lon) => (lon / 30).floor() % 12;

String formatDms(double lon) {
  final n = lon % 30;
  final d = n.floor();
  final m = ((n - d) * 60).floor();
  return "$d°${m.toString().padLeft(2, '0')}'";
}

class NakshatraInfo {
  const NakshatraInfo({
    required this.index,
    required this.name,
    required this.lord,
    required this.yoni,
    required this.gana,
    required this.nadi,
    required this.deity,
    required this.meaning,
  });

  final int index;
  final String name;
  final String lord;
  final String yoni;
  final String gana;
  final String nadi;
  final String deity;
  final String meaning;
}

const nakshatras = <NakshatraInfo>[
  NakshatraInfo(index: 0, name: 'Ashwini', lord: 'Ketu', yoni: 'Horse', gana: 'deva', nadi: 'adya', deity: 'Ashvini Kumaras', meaning: 'start, heal, speed'),
  NakshatraInfo(index: 1, name: 'Bharani', lord: 'Venus', yoni: 'Elephant', gana: 'manushya', nadi: 'madhya', deity: 'Yama', meaning: 'carry, birth, restraint'),
  NakshatraInfo(index: 2, name: 'Krittika', lord: 'Sun', yoni: 'Goat', gana: 'rakshasa', nadi: 'antya', deity: 'Agni', meaning: 'cut, purify, ambition'),
  NakshatraInfo(index: 3, name: 'Rohini', lord: 'Moon', yoni: 'Serpent', gana: 'manushya', nadi: 'antya', deity: 'Brahma', meaning: 'grow, beauty, fertility'),
  NakshatraInfo(index: 4, name: 'Mrigashira', lord: 'Mars', yoni: 'Serpent', gana: 'deva', nadi: 'madhya', deity: 'Soma', meaning: 'search, quest'),
  NakshatraInfo(index: 5, name: 'Ardra', lord: 'Rahu', yoni: 'Dog', gana: 'manushya', nadi: 'adya', deity: 'Rudra', meaning: 'storm, intellect'),
  NakshatraInfo(index: 6, name: 'Punarvasu', lord: 'Jupiter', yoni: 'Cat', gana: 'deva', nadi: 'adya', deity: 'Aditi', meaning: 'return, renew'),
  NakshatraInfo(index: 7, name: 'Pushya', lord: 'Saturn', yoni: 'Goat', gana: 'deva', nadi: 'madhya', deity: 'Brihaspati', meaning: 'nourish, dharma'),
  NakshatraInfo(index: 8, name: 'Ashlesha', lord: 'Mercury', yoni: 'Cat', gana: 'rakshasa', nadi: 'antya', deity: 'Nagas', meaning: 'coil, research'),
  NakshatraInfo(index: 9, name: 'Magha', lord: 'Ketu', yoni: 'Rat', gana: 'rakshasa', nadi: 'antya', deity: 'Pitris', meaning: 'throne, ancestors'),
  NakshatraInfo(index: 10, name: 'Purva Phalguni', lord: 'Venus', yoni: 'Rat', gana: 'manushya', nadi: 'madhya', deity: 'Bhaga', meaning: 'pleasure, romance'),
  NakshatraInfo(index: 11, name: 'Uttara Phalguni', lord: 'Sun', yoni: 'Cow', gana: 'manushya', nadi: 'adya', deity: 'Aryaman', meaning: 'vows, patronage'),
  NakshatraInfo(index: 12, name: 'Hasta', lord: 'Moon', yoni: 'Buffalo', gana: 'deva', nadi: 'adya', deity: 'Savitar', meaning: 'hands, craft'),
  NakshatraInfo(index: 13, name: 'Chitra', lord: 'Mars', yoni: 'Tiger', gana: 'rakshasa', nadi: 'madhya', deity: 'Tvashtar', meaning: 'design, brilliance'),
  NakshatraInfo(index: 14, name: 'Swati', lord: 'Rahu', yoni: 'Buffalo', gana: 'deva', nadi: 'antya', deity: 'Vayu', meaning: 'independence'),
  NakshatraInfo(index: 15, name: 'Vishakha', lord: 'Jupiter', yoni: 'Tiger', gana: 'rakshasa', nadi: 'antya', deity: 'Indra-Agni', meaning: 'forked drive'),
  NakshatraInfo(index: 16, name: 'Anuradha', lord: 'Saturn', yoni: 'Deer', gana: 'deva', nadi: 'madhya', deity: 'Mitra', meaning: 'devotion, ally'),
  NakshatraInfo(index: 17, name: 'Jyeshtha', lord: 'Mercury', yoni: 'Deer', gana: 'rakshasa', nadi: 'adya', deity: 'Indra', meaning: 'seniority'),
  NakshatraInfo(index: 18, name: 'Mula', lord: 'Ketu', yoni: 'Dog', gana: 'rakshasa', nadi: 'adya', deity: 'Nirriti', meaning: 'uproot, root'),
  NakshatraInfo(index: 19, name: 'Purva Ashadha', lord: 'Venus', yoni: 'Monkey', gana: 'manushya', nadi: 'madhya', deity: 'Apas', meaning: 'early victory'),
  NakshatraInfo(index: 20, name: 'Uttara Ashadha', lord: 'Sun', yoni: 'Mongoose', gana: 'manushya', nadi: 'antya', deity: 'Vishvedevas', meaning: 'lasting victory'),
  NakshatraInfo(index: 21, name: 'Shravana', lord: 'Moon', yoni: 'Monkey', gana: 'deva', nadi: 'antya', deity: 'Vishnu', meaning: 'listen, path'),
  NakshatraInfo(index: 22, name: 'Dhanishta', lord: 'Mars', yoni: 'Lion', gana: 'rakshasa', nadi: 'madhya', deity: 'Vasus', meaning: 'rhythm, wealth'),
  NakshatraInfo(index: 23, name: 'Shatabhisha', lord: 'Rahu', yoni: 'Horse', gana: 'rakshasa', nadi: 'adya', deity: 'Varuna', meaning: 'veil, heal, solitude'),
  NakshatraInfo(index: 24, name: 'Purva Bhadrapada', lord: 'Jupiter', yoni: 'Lion', gana: 'manushya', nadi: 'adya', deity: 'Aja Ekapada', meaning: 'intensity'),
  NakshatraInfo(index: 25, name: 'Uttara Bhadrapada', lord: 'Saturn', yoni: 'Cow', gana: 'manushya', nadi: 'madhya', deity: 'Ahirbudhnya', meaning: 'depth, finish'),
  NakshatraInfo(index: 26, name: 'Revati', lord: 'Mercury', yoni: 'Elephant', gana: 'deva', nadi: 'antya', deity: 'Pushan', meaning: 'nourish, crossing'),
];

const nakshatraWidth = 360.0 / 27.0; // 13°20'

NakshatraInfo nakshatraOf(double siderealLon) {
  final i = (siderealLon / nakshatraWidth).floor() % 27;
  return nakshatras[i];
}

int padaOf(double siderealLon) {
  final within = siderealLon % nakshatraWidth;
  return (within / (nakshatraWidth / 4)).floor() + 1;
}

class Dignity {
  const Dignity({
    required this.exaltSign,
    required this.exaltDeg,
    required this.debilSign,
    required this.own,
  });
  final int exaltSign;
  final double exaltDeg;
  final int debilSign;
  final List<int> own;
}

/// Vedic exaltation, debilitation and own signs.
///
/// Aliased as `dignityTable` for readers that also import the Western dignity
/// module, where the bare name `dignity` would collide.
const dignity = <String, Dignity>{
  'Sun': Dignity(exaltSign: 0, exaltDeg: 10, debilSign: 6, own: [4]),
  'Moon': Dignity(exaltSign: 1, exaltDeg: 3, debilSign: 7, own: [3]),
  'Mars': Dignity(exaltSign: 9, exaltDeg: 28, debilSign: 3, own: [0, 7]),
  'Mercury': Dignity(exaltSign: 5, exaltDeg: 15, debilSign: 11, own: [2, 5]),
  'Jupiter': Dignity(exaltSign: 3, exaltDeg: 5, debilSign: 9, own: [8, 11]),
  'Venus': Dignity(exaltSign: 11, exaltDeg: 27, debilSign: 5, own: [1, 6]),
  'Saturn': Dignity(exaltSign: 6, exaltDeg: 20, debilSign: 0, own: [9, 10]),
};

/// The same table under a non-colliding name.
const dignityTable = dignity;

String dignityLabel(String planet, double siderealLon) {
  final d = dignity[planet];
  if (d == null) return '';
  final s = signIndex(siderealLon);
  if (s == d.exaltSign) return 'exalted';
  if (s == d.debilSign) return 'debilitated';
  if (d.own.contains(s)) return 'own sign';
  return '';
}

/// Whole-sign house 1..12 from lagna sign index.
int wholeSignHouse(int lagnaSign, int bodySign) =>
    ((bodySign - lagnaSign) % 12) + 1;

/// Parashara navamsa sign index 0..11.
int navamsaSign(double siderealLon) {
  final sign = signIndex(siderealLon);
  final pos = siderealLon % 30.0;
  final n = (pos / (10.0 / 3.0)).floor(); // 0..8
  final int start;
  switch (sign % 3) {
    case 0:
      start = sign;
    case 1:
      start = (sign + 8) % 12;
    default:
      start = (sign + 4) % 12;
  }
  return (start + n) % 12;
}

/// Parashara dashamsa (D10) sign index 0..11.
int dashamsaSign(double siderealLon) {
  final sign = signIndex(siderealLon);
  final part = ((siderealLon % 30.0) / 3.0).floor(); // 0..9
  final oddNumbered = sign % 2 == 0; // Aries = 1
  final start = oddNumbered ? sign : (sign + 8) % 12;
  return (start + part) % 12;
}

const vimshottariYears = <String, double>{
  'Ketu': 7,
  'Venus': 20,
  'Sun': 6,
  'Moon': 10,
  'Mars': 7,
  'Rahu': 18,
  'Jupiter': 16,
  'Saturn': 19,
  'Mercury': 17,
};

const vimshottariOrder = [
  'Ketu',
  'Venus',
  'Sun',
  'Moon',
  'Mars',
  'Rahu',
  'Jupiter',
  'Saturn',
  'Mercury',
];

const houseTopics = <int, String>{
  1: 'self, body, fame',
  2: 'speech, family, savings',
  3: 'courage, siblings, craft',
  4: 'home, mother, vehicles, land',
  5: 'children, intellect, romance',
  6: 'work, illness, enemies, debt',
  7: 'spouse, partner, the other',
  8: 'transformation, tax, in-laws, occult',
  9: 'dharma, father, luck, long travel',
  10: 'career, status, public name',
  11: 'gains, friends, networks',
  12: 'loss, sleep, foreign, retreat',
};

const planetKaraka = <String, String>{
  'Sun': 'vitality, father, authority, title',
  'Moon': 'mind, mother, public, home mood',
  'Mars': 'courage, land, conflict, effort',
  'Mercury': 'speech, documents, trade, skill',
  'Jupiter': 'teacher, spouse-grace, children, dharma',
  'Venus': 'marriage, art, vehicles, comfort',
  'Saturn': 'delay, duty, structure, longevity',
  'Rahu': 'hunger, foreign, unconventional scale',
  'Ketu': 'cutting, moksha, spiritual reset',
  'Uranus': 'awakening, rupture, invention',
  'Neptune': 'imagination, dissolve, leak',
  'Pluto': 'compulsion, purge, power',
};

Set<String> yogakarakaFor(int lagnaSign) {
  final lords = <int, Set<String>>{};
  for (final e in dignity.entries) {
    for (final s in e.value.own) {
      lords.putIfAbsent(s, () => {}).add(e.key);
    }
  }
  String lordOf(int house) {
    final sign = (lagnaSign + house - 1) % 12;
    return signs[sign].ruler;
  }

  final kendra = {lordOf(4), lordOf(7), lordOf(10)};
  final trikona = {lordOf(5), lordOf(9)};
  return kendra.intersection(trikona);
}

const friends = <String, Set<String>>{
  'Sun': {'Moon', 'Mars', 'Jupiter'},
  'Moon': {'Sun', 'Mercury'},
  'Mars': {'Sun', 'Moon', 'Jupiter'},
  'Mercury': {'Sun', 'Venus'},
  'Jupiter': {'Sun', 'Moon', 'Mars'},
  'Venus': {'Mercury', 'Saturn'},
  'Saturn': {'Mercury', 'Venus'},
};

const enemies = <String, Set<String>>{
  'Sun': {'Venus', 'Saturn'},
  'Moon': {},
  'Mars': {'Mercury'},
  'Mercury': {'Moon'},
  'Jupiter': {'Mercury', 'Venus'},
  'Venus': {'Sun', 'Moon'},
  'Saturn': {'Sun', 'Moon', 'Mars'},
};

String relation(String a, String b) {
  if (a == b) return 'same';
  if (friends[a]?.contains(b) ?? false) return 'friend';
  if (enemies[a]?.contains(b) ?? false) return 'enemy';
  return 'neutral';
}

const vedicAspects = <String, List<int>>{
  'Mars': [4, 7, 8],
  'Jupiter': [5, 7, 9],
  'Saturn': [3, 7, 10],
  'Rahu': [5, 7, 9],
  'Ketu': [5, 7, 9],
};

List<int> aspectsFrom(String planet) =>
    vedicAspects[planet] ?? const [7];

// ---------------------------------------------------------------------------
// Localised names
// ---------------------------------------------------------------------------

/// The reader's name for a graha. The English identifiers above stay the keys
/// the engine and the knowledge base are written against; these are what gets
/// shown.
String grahaName(String planet) => tr('graha.$planet');

String signName(int index) => tr('sign.${signs[index % 12].name}');

String signNameOf(String english) => tr('sign.$english');

String nakshatraName(String english) => tr('nakshatra.$english');

/// House topics, localised.
String houseTopic(int house) => tr('house.topic.$house');

/// "1st", "2nd", ... in the reader's language.
String ordinal(int n) => n >= 1 && n <= 12 ? tr('ord.$n') : '$n';

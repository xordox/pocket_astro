import '../domain/models.dart';
import '../l10n/engine_strings.dart';
import 'forecast.dart';
import 'house_quality.dart';
import 'interpret.dart';
import 'kb.dart';
import 'tables.dart';

/// One step of the reasoning the engine actually performed.
///
/// These are not progress decorations. Each step carries the value the engine
/// read at that point, so a user watching the trace sees the real chain: this
/// house, ruled by this graha, sitting here, under this dasha. If a step
/// cannot report a value it is not emitted.
class QaStep {
  const QaStep({
    required this.kind,
    required this.label,
    required this.detail,
    this.source,
  });

  /// `question`, `chart`, `house`, `dasha`, `transit`, `bindu`, `library` or
  /// `answer`. The UI maps this to an icon; the engine never names an icon.
  final String kind;

  /// What the engine is doing, in the present tense.
  final String label;

  /// What it found.
  final String detail;

  /// Where the rule came from, when there is one to cite.
  final String? source;
}

class QaAnswer {
  const QaAnswer({
    required this.intent,
    required this.question,
    required this.answer,
    required this.confidence,
    this.headline = '',
    this.steps = const [],
  });
  final String intent;
  final String question;
  final String answer;
  final int confidence;

  /// One plain sentence, shown before the detail.
  final String headline;

  /// The reasoning trace, in the order it was performed.
  final List<QaStep> steps;
}

/// Plain-language name for what the engine decided a question was about,
/// in the reader's language.
String intentLabel(String intent) => tr('qa.intent.$intent');

const questionBank = <String, String>{
  'birth_time_ok': 'Is my birth time accurate enough for lagna and navamsa?',
  'system': 'Which system is PocketAstro using?',
  'not_promised': 'What is this chart not promising as an easy default?',
  'now_dasha': 'What dasha am I in, and what is it for?',
  'next_window': 'When is a better window to marry, move, or launch work?',
  'career': 'Is this chart better as named work or as employment?',
  'money': 'How does money actually arrive in this chart?',
  'marriage_if': 'Is marriage promised, or a significant partnership?',
  'spouse_type': 'What kind of partner does the 7th house describe?',
  'manglik': 'Am I manglik, and should I fear it?',
  'children': 'What about children and romance?',
  'home': 'When do home, a vehicle, or land become likely?',
  'foreign': 'Foreign income, or actually living abroad?',
  'health': 'What should I take seriously in the body — without diagnosing?',
  'psychology': 'Where do I get in my own way?',
  'remedy': 'Which remedies actually match, and what will a gem not fix?',
  '90_days': 'What should I do in the next 90 days?',
};

QaAnswer answerQuestion(NatalChart chart, String raw, {DateTime? now}) {
  now ??= DateTime.now().toUtc();
  final q = raw.trim();
  final intent = _intent(q);
  if (intent == 'refused_crisis') {
    return QaAnswer(
      intent: 'refused_crisis',
      question: q,
      headline: tr('qa.head.refused_crisis'),
      answer:
          'If you are in crisis, please talk to a person who can help. In the US call or text 988. PocketAstro cannot help with that.',
      confidence: 100,
      steps: [
        QaStep(
          kind: 'question',
          label: tr('qa.step.question'),
          detail: tr('qa.detail.refused_crisis'),
        ),
      ],
    );
  }
  if (intent == 'refused_death') {
    return QaAnswer(
      intent: 'refused_death',
      question: q,
      headline: tr('qa.head.refused_death'),
      answer:
          'PocketAstro will not predict death, a spouse’s death, or a date of dying. '
          'Classical longevity language is read as caution about health, conflict, or authority — not a sentence.',
      confidence: 100,
      steps: [
        QaStep(
          kind: 'question',
          label: tr('qa.step.question'),
          detail: tr('qa.detail.refused_death'),
        ),
        QaStep(
          kind: 'library',
          label: tr('qa.step.refusal'),
          detail: tr('qa.detail.refused_list'),
          source: 'interpretation.json → refusals',
        ),
      ],
    );
  }
  final areas = interpretChart(chart, now: now);
  LifeArea area(String title) =>
      areas.firstWhere((a) => a.title.toLowerCase().contains(title), orElse: () => areas.first);

  final md = chart.mahadashaAt(now);
  final ad = chart.antardashaAt(now);
  String text;
  var conf = 55;

  switch (intent) {
    case 'birth_time_ok':
      if (chart.input.timeUnknown) {
        text =
            'There is no usable clock time. Lagna, navamsa, and houses are withheld. '
            'Dasha from the Moon still runs. Rectify before treating D9 as law.';
        conf = 80;
      } else {
        final lagna = chart.lagnaSidereal % 30;
        final toNext = 30 - lagna;
        text =
            'Sidereal lagna is ${signOf(chart.lagnaSidereal).name} ${formatDms(chart.lagnaSidereal)}. '
            'About ${toNext.toStringAsFixed(1)}° remain in this sign — roughly ${ (toNext * 4).toStringAsFixed(0)} minutes of clock if the ASC moves ~1°/4 min. '
            'Navamsa lagna (${signs[chart.navamsaLagna].name}) can flip in a few minutes. '
            'If spouse details feel wrong, rectify before you treat D9 as law.';
        conf = 70;
      }
    case 'system':
      text =
          '${chart.engineStamp}. Uncertain points are flagged. '
          'A sitting that will not name the ayanamsa is already leaky.';
      conf = 90;
    case 'now_dasha':
      text = area('current').body;
      conf = area('current').confidence;
    case 'not_promised':
      text = area('not promised').body;
      conf = area('not promised').confidence;
    case 'career':
      text = area('career').body;
    case 'money':
      text = area('money').body;
    case 'marriage_if':
    case 'spouse_type':
      text = area('marriage').body;
    case 'home':
      text = area('home').body;
    case 'children':
      text = area('children').body;
    case 'health':
      text = area('health').body;
      conf = 35;
    case 'foreign':
      text = chart.input.timeUnknown
          ? 'Need lagna. Rahu and the 9th/12th significators still hint at foreign themes from the planets themselves.'
          : 'Read the 9th and 12th lords plus Rahu. Saturn in the 12th (if present) supports foreign work or unseen hours; Rahu in the 11th supports foreign or unconventional gains. Dasha must agree.';
    case 'manglik':
      final mars = chart.graha('Mars');
      text =
          'Mars is in ${mars.sign}, house ${mars.house == 0 ? '(unknown without time)' : mars.house}. '
          'Classical Kuja dosha uses houses 1, 4, 7, 8, 12 from lagna and Moon. '
          'PocketAstro will not predict a spouse’s death. Heat on marriage is a counselling flag. '
          'Some schools cancel Mars in Leo or Aquarius — shown as a school toggle in matching, not as a curse.';
    case 'psychology':
      text =
          'The 12th house is either spiritual opening or a leak: sleep, one more revision, disappearing after a win. '
          'Mercury over-researches until the Mars moment dies. '
          'Name the pattern, then use the current dasha calendar — fear is not a graha.';
    case 'remedy':
      text =
          'Ranked: (1) behaviour that matches the dasha lord, (2) schedule and sleep, (3) dana/mantra if you want ritual, (4) gemstones last and only for a functional benefic. '
          'A gemstone will not fix what a calendar, a contract, and a gym will.';
    case 'next_window':
    case '90_days':
      final f = forecastChart(chart, now: now);
      final focus = intent == '90_days'
          ? f.hits.where((h) => h.title.contains('dasha') || h.title.contains('Gochara') || h.title.contains('Career') || h.title.contains('Money'))
          : f.hits.where((h) => h.title.contains('Marriage') || h.title.contains('Career') || h.title.contains('dasha') || h.title.contains('Gochara'));
      final upcoming = f.windows.take(4).map((w) => '${w.title} — ${w.verdict}').join('; ');
      text =
          '${focus.map((h) => h.body).join(' ')} '
          '${upcoming.isEmpty ? '' : 'Windows: $upcoming. '}'
          'Stay inside ${md?.lord ?? 'the current'} mahadasha'
          '${ad == null ? '' : ', ${ad.lord} antardasha until ${_fmt(ad.end)}'}. '
          'Do not solemnize in a Ketu AD. Saturn and Rahu transits charge a toll — they do not delete a yoga.';
    default:
      text =
          'I can answer from this chart’s houses, dasha, and yogas. Try one of the suggested questions, '
          'or ask about career, money, marriage, timing, or matching.';
  }

  final steps = _trace(chart, intent, now);
  final headline = _headline(chart, intent, now, conf);
  text +=
      '\n\nConfidence $conf/100. Two techniques must agree before an event is called likely.';
  return QaAnswer(
    intent: intent,
    question: q,
    answer: text,
    confidence: conf,
    headline: headline,
    steps: steps,
  );
}

/// The reasoning trace. Every step reports a value the engine actually read;
/// a step with nothing to report is dropped rather than faked.
List<QaStep> _trace(NatalChart chart, String intent, DateTime now) {
  final kb = PredictionKb.current;
  final steps = <QaStep>[
    QaStep(
      kind: 'question',
      label: tr('qa.step.question'),
      detail: tr('qa.detail.subject', {'subject': intentLabel(intent)}),
    ),
  ];

  if (chart.input.timeUnknown) {
    steps.add(QaStep(
      kind: 'chart',
      label: tr('qa.step.chart'),
      detail: tr('qa.detail.no_time'),
      source: 'interpretation.json → birth_time',
    ));
  } else {
    final moon = chart.graha('Moon');
    steps.add(QaStep(
      kind: 'chart',
      label: tr('qa.step.chart'),
      detail: tr('qa.detail.chart', {
        'rising': signName(signIndex(chart.lagnaSidereal)),
        'moonSign': signNameOf(moon.sign),
        'nakshatra': nakshatraName(moon.nakshatra),
      }),
    ));
  }

  final topic = kb.topic(_topicFor(intent));
  if (topic.isNotEmpty && !chart.input.timeUnknown) {
    final houses = ((topic['houses'] as List?) ?? const [])
        .map((e) => (e as num).toInt())
        .toList();
    if (houses.isNotEmpty) {
      final readings = readHouses(chart);
      final focus = readings.where((r) => houses.contains(r.house)).toList();
      if (focus.isNotEmpty) {
        final f = focus.first;
        steps.add(QaStep(
          kind: 'house',
          label: tr('qa.step.house'),
          detail: tr('qa.detail.house', {
            'houses': houses.join(', '),
            'ord': ordinal(f.house),
            'lord': grahaName(f.lord),
            'lordOrd': ordinal(f.lordHouse),
            'band': f.band.label.toLowerCase(),
          }),
          source: 'interpretation.json → topics.${topic['key']}',
        ));
      }
    }
    final karakas = ((topic['karakas'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    if (karakas.isNotEmpty) {
      steps.add(QaStep(
        kind: 'chart',
        label: tr('qa.step.karakas'),
        detail: karakas
            .map((k) {
              final row =
                  chart.grahas.where((g) => g.name == k).firstOrNull;
              return row == null
                  ? grahaName(k)
                  : '${grahaName(k)} · ${signNameOf(row.sign)}';
            })
            .join(', '),
        source: 'planets.json → karaka',
      ));
    }
  }

  final md = chart.mahadashaAt(now);
  final ad = chart.antardashaAt(now);
  if (md != null) {
    steps.add(QaStep(
      kind: 'dasha',
      label: tr('qa.step.dasha'),
      detail: tr('qa.detail.dasha', {
        'md': grahaName(md.lord),
        'ad': ad == null
            ? ''
            : tr('qa.detail.dasha_sub', {'ad': grahaName(ad.lord)}),
        'end': _fmt((ad ?? md).end),
      }),
      source: 'dashas.json → mahadasha',
    ));
  }

  final f = forecastChart(chart, now: now);
  final satHouse = f.now.fromMoon['Saturn'];
  final jupHouse = f.now.fromMoon['Jupiter'];
  if (satHouse != null && jupHouse != null) {
    steps.add(QaStep(
      kind: 'transit',
      label: tr('qa.step.transit'),
      detail: tr('qa.detail.transit', {
        'satOrd': ordinal(satHouse),
        'jupOrd': ordinal(jupHouse),
        'extra': '${f.now.sadeSati ? tr('qa.detail.sade_sati') : ''}'
            '${f.now.ashtamaShani ? tr('qa.detail.ashtama') : ''}',
      }),
      source: 'transits.json → gochara',
    ));
  }

  final av = f.now.av;
  if (av != null) {
    final jup = f.now.bindusFor('Jupiter');
    if (jup != null) {
      steps.add(QaStep(
        kind: 'bindu',
        label: tr('qa.step.bindu'),
        detail: tr('qa.detail.bindu', {
          'n': jup,
          'note': tr(jup >= 5
              ? 'qa.detail.bindu.delivers'
              : jup == 4
                  ? 'qa.detail.bindu.mixed'
                  : 'qa.detail.bindu.withholds'),
        }),
        source: 'ashtakavarga.json → transit_rule',
      ));
    }
  }

  steps.add(QaStep(
    kind: 'library',
    label: tr('qa.step.library'),
    detail: tr('qa.detail.rules'),
    source: tr('qa.source.books', {'n': kb.sourceCount}),
  ));

  return steps;
}

/// One plain sentence to lead the answer with.
String _headline(NatalChart chart, String intent, DateTime now, int conf) {
  final md = chart.mahadashaAt(now);
  final ad = chart.antardashaAt(now);
  final period = md == null
      ? ''
      : '${grahaName(md.lord)}${ad == null ? '' : '/${grahaName(ad.lord)}'}';
  switch (intent) {
    case 'now_dasha':
      return md == null
          ? tr('qa.head.period_unknown')
          : tr('qa.head.period', {'period': period});
    case 'next_window':
    case '90_days':
      final f = forecastChart(chart, now: now);
      final best = f.windows.where((w) => w.verdict == 'likely').toList();
      return best.isEmpty
          ? tr('qa.head.no_window')
          : tr('qa.head.window', {'title': best.first.title.toLowerCase()});
    case 'health':
      return tr('qa.head.health');
    case 'remedy':
      return tr('qa.head.remedy');
    case 'manglik':
      return tr('qa.head.manglik');
    default:
      if (chart.input.timeUnknown) return tr('qa.head.no_time');
      return tr('qa.head.default', {
        'rising': signName(signIndex(chart.lagnaSidereal)),
        'period': period,
      });
  }
}

/// Maps a question intent onto a topic recipe in `interpretation.json`.
String _topicFor(String intent) => switch (intent) {
      'marriage_if' || 'spouse_type' || 'manglik' => 'marriage',
      'career' => 'career',
      'money' => 'money',
      'home' => 'home',
      'children' => 'children',
      'foreign' => 'foreign',
      'health' => 'health',
      'next_window' || '90_days' => 'career',
      _ => '',
    };


String _intent(String q) {
  final s = q.toLowerCase();
  bool any(List<String> k) => k.any(s.contains);
  if (any(['kill myself', 'suicide', 'want to die', 'self-harm', 'self harm', 'end my life'])) {
    return 'refused_crisis';
  }
  if (any([
        'when will i die',
        'when do i die',
        'date of death',
        'death of spouse',
        'spouse will die',
        'how long will i live',
        'lifespan date',
        'predict death',
      ])) {
    return 'refused_death';
  }
  if (any(['time accurate', 'birth time', 'rectif', 'lagna enough'])) return 'birth_time_ok';
  if (any(['which system', 'ayanamsa', 'vedic or western'])) return 'system';
  if (any(['not promis', 'stop chasing'])) return 'not_promised';
  if (any(['dasha', 'period am i', 'what year is this'])) return 'now_dasha';
  if (any(['marry', 'marriage', 'spouse', 'wife', 'husband', 'partner'])) {
    if (any(['when', 'window', 'best time'])) return 'next_window';
    if (any(['like', 'describe', 'kind'])) return 'spouse_type';
    return 'marriage_if';
  }
  if (any(['manglik', 'kuja', 'mangal'])) return 'manglik';
  if (any(['job', 'career', 'business', 'profession', 'work'])) return 'career';
  if (any(['money', 'wealth', 'income', 'rich'])) return 'money';
  if (any(['child', 'baby', 'romance'])) return 'children';
  if (any(['home', 'house', 'vehicle', 'land', 'mother'])) return 'home';
  if (any(['foreign', 'abroad', 'visa'])) return 'foreign';
  if (any(['health', 'body', 'illness', 'sick'])) return 'health';
  if (any(['gem', 'remedy', 'upay', 'mantra'])) return 'remedy';
  if (any(['90 day', 'what now', 'next month', 'calendar'])) return '90_days';
  if (any(['window', 'when should', 'timing', 'launch'])) return 'next_window';
  if (any(['sabotage', 'in my way', 'psychology', 'fear'])) return 'psychology';
  return 'general';
}

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

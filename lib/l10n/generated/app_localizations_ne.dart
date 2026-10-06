// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Nepali (`ne`).
class LNe extends L {
  LNe([String locale = 'ne']) : super(locale);

  @override
  String get appTitle => 'पकेटएस्ट्रो';

  @override
  String get navCompatibility => 'अनुकूलता';

  @override
  String get navLanguage => 'भाषा';

  @override
  String get navLearn => 'ज्योतिष सिक्नुहोस्';

  @override
  String get navRashifal => 'दैनिक राशिफल';

  @override
  String get homeToday => 'आज';

  @override
  String get homeYourCharts => 'तपाईंका कुण्डली';

  @override
  String get homeYourChartsSub => 'पूरै कुण्डली पढ्न नाममा थिच्नुहोस्।';

  @override
  String get homeReadYourDay => 'आफ्नो दिन पढ्नुहोस्';

  @override
  String get homeLearnCard => 'ज्योतिष सिक्नुहोस्';

  @override
  String get homeLearnCardSub =>
      'पन्ध्र पाठ — कुण्डली के हो, देखि त्यसले के भन्न सक्दैन सम्म।';

  @override
  String homeLearnProgress(String done, String total) {
    return '$total मध्ये $done पाठ';
  }

  @override
  String get homeLearnStart => 'सिक्न सुरु गर्नुहोस्';

  @override
  String get rashifalTitle => 'दैनिक राशिफल';

  @override
  String get rashifalSub => 'आज ग्रहहरू कहाँ छन्, हरेक चन्द्रराशिबाट गनेर।';

  @override
  String get rashifalPickSign => 'आफ्नो चन्द्रराशि छान्नुहोस्';

  @override
  String get rashifalYours => 'तपाईंको';

  @override
  String rashifalYoursFor(String name) {
    return 'तपाईंको · $name';
  }

  @override
  String get rashifalMoonSign => 'चन्द्रराशि';

  @override
  String get rashifalWhatMoves => 'आज के चलिरहेको छ';

  @override
  String rashifalLineTitle(String graha, String house) {
    return '$graha · $house भाव';
  }

  @override
  String get rashifalObstructed => 'वेधले रोकेको';

  @override
  String get rashifalHelps => 'सहयोगी';

  @override
  String get rashifalPresses => 'दबाब';

  @override
  String get rashifalQuiet => 'शान्त';

  @override
  String get rashifalBetterRead => 'यसलाई आफ्नै कुण्डलीसँग राखेर पढ्नुहोस्';

  @override
  String get rashifalBetterReadSub =>
      'तपाईंको कुण्डलीले यिनै गोचरलाई तपाईंको जन्म चन्द्र, दशा र अष्टकवर्गसँग जोडेर पढ्छ।';

  @override
  String get rashifalNoChart =>
      'आफ्नो चन्द्रराशि थाहा छैन? एउटा कुण्डली थप्नुहोस्, एपले आफैं निकाल्छ।';

  @override
  String panchangaToday(String tithi, String nakshatra, String vara) {
    return '$tithi · $nakshatra · $vara';
  }

  @override
  String get storedOnDevice =>
      'तपाईंका कुण्डली यही यन्त्रमा रहन्छन्। जन्मस्थानको खोज मात्र अनलाइन जान्छ, त्यो पनि तपाईंले भनेपछि मात्र।';

  @override
  String get emptyTitle => 'जन्मकुण्डली पढ्नुहोस्, अफलाइन';

  @override
  String get emptyBody =>
      'जन्म मिति, समय र स्थान थप्नुहोस्। खाता चाहिँदैन; तपाईंका कुण्डलीले यो यन्त्र कहिल्यै छोड्दैनन्।';

  @override
  String get enterBirthDetails => 'जन्म विवरण हाल्नुहोस्';

  @override
  String get loadDemo => 'नमुना हेर्नुहोस्: १४ अप्रिल १९९२, काठमाडौँ';

  @override
  String get newChart => 'नयाँ कुण्डली';

  @override
  String get editChart => 'कुण्डली सम्पादन';

  @override
  String get deleteTitle => 'यो कुण्डली मेटाउने?';

  @override
  String deleteBody(String name) {
    return '$name लाई यस यन्त्रबाट हटाउने।';
  }

  @override
  String get cancel => 'रद्द';

  @override
  String get delete => 'मेटाउनुहोस्';

  @override
  String get timeUnknownShort => 'समय अज्ञात';

  @override
  String get notFound => 'भेटिएन';

  @override
  String get fieldName => 'नाम';

  @override
  String get fieldDateTime => 'मिति र समय (जन्मस्थानको स्थानीय)';

  @override
  String get switchTimeUnknown => 'जन्मसमय थाहा छैन';

  @override
  String get switchTimeUnknownSub =>
      'लग्न र बाह्रै भाव अनुमान नगरी रोकिनेछन्। चन्द्रमाबाटको पाठ भने चल्छ।';

  @override
  String get fieldTimeSource => 'समयको स्रोत';

  @override
  String get fieldBirthPlace => 'जन्मस्थान';

  @override
  String get invalidLocation =>
      'स्थानको विवरण अमान्य छ। कृपया मान्य स्थानको नाम लेख्नुहोस्।';

  @override
  String get hintTypePlace => 'कुनै पनि सहर वा नगर लेख्नुहोस्';

  @override
  String get searchOnline => 'अनलाइन खोज्नुहोस्';

  @override
  String get searchingPlaces => 'खोज्दै…';

  @override
  String get placeSearchMinChars => 'कम्तीमा तीन अक्षर लेखेर खोज्नुहोस्।';

  @override
  String get placeLookupOffline =>
      'स्थान खोजसम्म पुग्न सकिएन। सुरक्षित गरिएका र अन्तर्निहित स्थानहरू अझै काम गर्छन्।';

  @override
  String get placeLookupRetry => 'फेरि प्रयास गर्नुहोस्';

  @override
  String get sectionOnDevice => 'यस यन्त्रका स्थानहरू';

  @override
  String get sectionOnlineResults => 'अनलाइन नतिजा';

  @override
  String get placeOnlineNote =>
      'यो खोज मात्र तपाईंको यन्त्रबाट बाहिर जान्छ। तपाईंको कुण्डली कतै पठाइँदैन।';

  @override
  String get useCoordinates => 'यसको सट्टा निर्देशाङ्क लेख्नुहोस्';

  @override
  String get fieldLatitude => 'अक्षांश';

  @override
  String get fieldLongitude => 'देशान्तर';

  @override
  String get fieldTimezone => 'समय क्षेत्र';

  @override
  String get hintTimezone => 'IANA जोन आईडी, जस्तै Asia/Kathmandu';

  @override
  String get invalidCoordinates =>
      'अक्षांश −90 देखि 90, देशान्तर −180 देखि 180, र जोन वास्तविक IANA आईडी हुनुपर्छ।';

  @override
  String get useThisPlace => 'यही स्थान प्रयोग गर्नुहोस्';

  @override
  String selectedPlace(String place, String zone) {
    return 'छानिएको: $place ($zone)';
  }

  @override
  String get saveAndRead => 'सुरक्षित गरी कुण्डली पढ्नुहोस्';

  @override
  String get tabOverview => 'सारांश';

  @override
  String get tabKundali => 'कुण्डली';

  @override
  String get tabLifeAreas => 'जीवनका क्षेत्र';

  @override
  String get tabTiming => 'समय';

  @override
  String get tabAsk => 'सोध्नुहोस्';

  @override
  String get tabLearn => 'सिक्नुहोस्';

  @override
  String get learnTitle => 'ज्योतिष सिक्नुहोस्';

  @override
  String get learnSub =>
      'सुरुदेखि पन्ध्र पाठ, र हरेक पाठको अन्त्य तपाईंकै कुण्डलीमा।';

  @override
  String learnProgress(String done, String total) {
    return '$total मध्ये $done पाठ सकियो';
  }

  @override
  String get learnContinue => 'जारी राख्नुहोस्';

  @override
  String get learnStart => 'पाठ्यक्रम सुरु गर्नुहोस्';

  @override
  String get learnNextUp => 'अर्को पाठ';

  @override
  String get learnFinished => 'तपाईंले पूरै पाठ्यक्रम पढिसक्नुभयो।';

  @override
  String get learnFinishedSub =>
      'जुनसुकै पाठमा जहिले पनि फर्कन सक्नुहुन्छ। यहाँ केही पनि सकिँदैन।';

  @override
  String learnLevelProgress(String done, String total) {
    return '$done/$total';
  }

  @override
  String learnMinutes(String minutes) {
    return '$minutes मिनेट';
  }

  @override
  String learnLessonOf(String number, String total) {
    return '$total मध्ये पाठ $number';
  }

  @override
  String get learnInYourChart => 'तपाईंको कुण्डलीमा';

  @override
  String get learnCheck => 'आफैंलाई जाँच्नुहोस्';

  @override
  String get learnShowAnswer => 'उत्तर देखाउनुहोस्';

  @override
  String get learnHideAnswer => 'उत्तर लुकाउनुहोस्';

  @override
  String get learnMarkDone => 'पढेको चिन्ह लगाउनुहोस्';

  @override
  String get learnMarkNotDone => 'पढियो';

  @override
  String get learnNextLesson => 'अर्को पाठ';

  @override
  String get learnReset => 'प्रगति मेटाउनुहोस्';

  @override
  String get learnResetTitle => 'पाठ्यक्रम फेरि सुरु गर्ने?';

  @override
  String get learnResetBody =>
      'यसले पढेको चिन्ह लगाइएका सबै पाठ मेटाउँछ। पाठहरू आफैं भने जहाँ छन् त्यहीं रहन्छन्।';

  @override
  String get learnEmpty => 'पाठ्यक्रम लोड हुन सकेन।';

  @override
  String get learnFootnote =>
      'यो पाठ्यक्रम हो, प्रमाणपत्र होइन। पकेटएस्ट्रोले शास्त्रीय विधि सिकाउँछ र त्यो विधि कहाँ रोकिन्छ भन्ने पनि स्पष्ट भन्छ।';

  @override
  String get tabToday => 'आज';

  @override
  String todayReckoned(String place) {
    return '$placeको सूर्योदयबाट गणना';
  }

  @override
  String todaySunTimes(String sunrise, String sunset) {
    return 'सूर्योदय $sunrise · सूर्यास्त $sunset';
  }

  @override
  String get todayEstimatedLight =>
      'यो मितिमा यहाँ सूर्यले क्षितिज नाघ्दैन, त्यसैले दिनका समयहरू बिहान ६ देखि साँझ ६ को प्रचलनमा लिइएका छन्।';

  @override
  String get todayPanchanga => 'पञ्चाङ्गका पाँच अङ्ग';

  @override
  String get todayPanchangaSub =>
      'तपाईंबारे केही भन्नुअघि आजको दिन आफैं के हो।';

  @override
  String todayUntil(String time) {
    return '$time सम्म';
  }

  @override
  String get todayAllDay => 'भोलि सूर्योदयसम्म';

  @override
  String get todayMoonStrength => 'आज तपाईंको चन्द्रमा';

  @override
  String get todayMoonStrengthSub =>
      'आजको चन्द्रमा तपाईंको जन्म चन्द्रसँग तुलना गरेर।';

  @override
  String get todayTarabala => 'ताराबल';

  @override
  String todayTarabalaValue(String name, String count) {
    return '$name — 27 मध्ये $count औं तारा';
  }

  @override
  String get todayChandrabala => 'चन्द्रबल';

  @override
  String todayChandrabalaValue(String house) {
    return 'जन्म चन्द्रबाट $house भाव';
  }

  @override
  String get todayKakshya => 'कक्ष्या गणना';

  @override
  String todayKakshyaValue(String score) {
    return '7 मध्ये $score ग्रहले बिन्दु बोकेका छन्';
  }

  @override
  String get todayNoKakshya =>
      'कक्ष्या गणनाका लागि जन्म समय चाहिन्छ — अष्टकवर्गको आठौं योगदानकर्ता लग्न नै हो।';

  @override
  String get todayLeanInto => 'यता झुक्नुहोस्';

  @override
  String get todayLeanIntoSub => 'शास्त्रअनुसार आजको दिन केका लागि उपयुक्त छ।';

  @override
  String get todayHoldOff => 'अहिलेलाई रोक्नुहोस्';

  @override
  String get todayHoldOffSub =>
      'शास्त्रअनुसार आजको दिन केका लागि अनुपयुक्त छ। यीमध्ये कुनै पनि निषेध होइन।';

  @override
  String get todayWindows => 'दिनभित्रका समय';

  @override
  String get todayWindowsSub => 'सूर्योदयबाट गनिएका दिनमानका अंश।';

  @override
  String get todayWindowNow => 'अहिले चलिरहेको';

  @override
  String get todayGuidance => 'मार्गनिर्देश';

  @override
  String get todayPeriodToday => 'आज तपाईंको दशा';

  @override
  String get todayCarrying => 'आजको भार कसमा';

  @override
  String get todayFootnote =>
      'मुहूर्त अन्तिम छन्नी हो, पहिलो होइन। के सम्भव छ भन्ने तपाईंको कुण्डली र चलिरहेको दशाले तय गर्छ; दिनले त्यो कस्तो अनुभव हुन्छ भन्ने मात्र तय गर्छ।';

  @override
  String get todayWorkingOut => 'आजको मूल्याङ्कन कसरी भयो';

  @override
  String todayScoreLine(String score) {
    return 'सबै छन्नीको जोड $score भयो।';
  }

  @override
  String get savePdf => 'PDF मा सुरक्षित';

  @override
  String risingTitle(String sign) {
    return '$sign लग्न';
  }

  @override
  String moonTitle(String sign) {
    return 'चन्द्रमा $sign मा';
  }

  @override
  String get noTimeLead => 'तपाईंको मन र सहज प्रवृत्ति चन्द्रमाबाट पढिन्छ।';

  @override
  String moonSunLine(String moon, String sun) {
    return 'चन्द्रमा $moon मा · सूर्य $sun मा';
  }

  @override
  String birthStarLine(String nakshatra, String pada) {
    return 'जन्मनक्षत्र $nakshatra, चरण $pada';
  }

  @override
  String periodTitle(String lord) {
    return 'तपाईं $lord को दशामा हुनुहुन्छ';
  }

  @override
  String periodSub(String lord, String date) {
    return 'हाल $lord अन्तर्दशा, $date सम्म';
  }

  @override
  String periodRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String periodProgress(String percent, String years) {
    return '$percent% बितिसक्यो · करिब $years वर्ष बाँकी। दशा एउटा अध्याय हो, सजाय होइन।';
  }

  @override
  String get periodClosed => 'यो दशा सकियो।';

  @override
  String get whatSupports => 'यो कुण्डलीले केलाई साथ दिन्छ';

  @override
  String get whatSupportsSub => 'कहाँ कुण्डलीले सघाउँछ, र कहाँ मेहनत माग्छ।';

  @override
  String get standoutPatterns => 'विशेष योग';

  @override
  String get standoutPatternsSub =>
      'शास्त्रले तपाईंको कुण्डलीमा विशेष रूपमा औँल्याएका संयोग।';

  @override
  String get disclaimerOffline =>
      'पकेटएस्ट्रोले ५६ शास्त्रीय र आधुनिक स्रोतबाट तपाईंको कुण्डली अफलाइन पढ्छ। यो व्याख्यात्मक हो — चिकित्सा, कानुनी वा वित्तीय सल्लाह होइन; यसले मृत्युको भविष्यवाणी वा रोग निदान गर्दैन।';

  @override
  String get noTimeNote =>
      'जन्मसमय अभिलेखमा छैन, त्यसैले लग्न, बाह्रै भाव र तीमाथि आधारित सबै कुरा रोकिएका छन्। चन्द्रमाले भने पूरा पाठ बोक्छ। बाँकी खोल्न समय थप्नुहोस्।';

  @override
  String get northIndian => 'उत्तर भारतीय';

  @override
  String get southIndian => 'दक्षिण भारतीय';

  @override
  String get hintNorth =>
      'भाव स्थिर रहन्छन्; राशिहरू तपाईंको लग्नअनुसार सर्छन्।';

  @override
  String get hintSouth =>
      'राशिहरू स्थिर रहन्छन्; तपाईंको लग्न “लग्न” भनी चिनो लगाइएको छ।';

  @override
  String get showShading => 'भावको रङ देखाउनुहोस्';

  @override
  String get hideShading => 'भावको रङ लुकाउनुहोस्';

  @override
  String get tapGraha =>
      'कुन ग्रहले केलाई प्रभाव पार्छ हेर्न ग्रहमा थिच्नुहोस्';

  @override
  String get tapGrahaSub => 'यसका दृष्टिहरू पुग्ने भावमा रेखाङ्कित हुन्छन्।';

  @override
  String influencesHouses(String count) {
    return 'यसले $count भावलाई प्रभाव पार्छ';
  }

  @override
  String get whyColour => 'यो रङ किन?';

  @override
  String get advancedTitle => 'सटीक स्थिति र पाश्चात्य चक्र';

  @override
  String get advancedSub => 'अंश, नक्षत्र, बलाबल र दृष्टि';

  @override
  String get colGraha => 'ग्रह';

  @override
  String get colSidereal => 'निरयण';

  @override
  String get colHouse => 'भाव';

  @override
  String get colNakshatra => 'नक्षत्र';

  @override
  String get colDignity => 'बलाबल';

  @override
  String get westernWheelTitle => 'पाश्चात्य चक्र (सायन)';

  @override
  String houseNumber(String number) {
    return 'भाव $number';
  }

  @override
  String get sheetSign => 'राशि';

  @override
  String get sheetRuledBy => 'स्वामी';

  @override
  String sheetRulerIn(String lord, String house) {
    return '$lord, जुन $house भावमा छ';
  }

  @override
  String get sheetGrahasHere => 'यहाँका ग्रह';

  @override
  String get sheetNoGrahas => 'कोही छैन — फल स्वामीमार्फत आउँछ, जुन सामान्य हो';

  @override
  String get sheetInfluencedBy => 'दृष्टि दिने';

  @override
  String get sheetPointCount => 'बिन्दु';

  @override
  String sheetPointValue(String count) {
    return '५६ मध्ये $count, औसत २८ को तुलनामा';
  }

  @override
  String get sheetTopics => 'शास्त्रीय विषय';

  @override
  String get whatHelps => 'यहाँ केले सघाउँछ';

  @override
  String get whatPresses => 'केले दबाब दिन्छ';

  @override
  String get houseSheetNote =>
      'भावको पाठ कुण्डलीले कहाँ सघाउँछ भन्ने मार्गदर्शन हो, भविष्यवाणी होइन। दबाबको कारण र उपाय हुन्छ; यो तपाईंको जीवनको फैसला कहिल्यै होइन।';

  @override
  String get twelveAreas => 'तपाईंको जीवनका बाह्र क्षेत्र';

  @override
  String get twelveAreasSub =>
      'कुनै एकमा थिचेर त्यसलाई के कुराले बनाउँछ हेर्नुहोस्।';

  @override
  String get readingsInFull => 'पूरा पाठ';

  @override
  String get readingsInFullSub => 'उही कुण्डली, शास्त्रीय भाषामा।';

  @override
  String get lifeNoTimeNote =>
      'बाह्र भावका लागि जन्मसमय चाहिन्छ। नभएमा, पकेटएस्ट्रोले सटीक देखिने तर नभएको कुरा देखाउनुभन्दा रोक्छ।';

  @override
  String get lifeInPeriods => 'दशाहरूमा तपाईंको जीवन';

  @override
  String get lifeInPeriodsSub =>
      'विंशोत्तरी चक्र, तपाईंको चन्द्रमाबाट नापिएको।';

  @override
  String insidePeriod(String lord) {
    return '$lord दशाभित्र';
  }

  @override
  String get insidePeriodSub =>
      'अन्तर्दशाले अध्यायलाई केही महिनामा साँघुर्‍याउँछ।';

  @override
  String get nextTwoYears => 'आउँदो दुई वर्ष कस्तो देखिन्छ';

  @override
  String get nextTwoYearsSub => 'दुई विधि मिल्ने अनुकूल समय।';

  @override
  String get nextTwoYearsNone => 'विशेष केही देखिँदैन। यो सामान्य नतिजा हो।';

  @override
  String get noWindowNote =>
      'आउँदो चौबीस महिनामा विशेष अनुकूल समय छैन। यसको अर्थ केही हुँदैन भन्ने होइन — पकेटएस्ट्रोले भन्न सक्ने गरी दुई विधि बलियोसँग मिलेका छैनन्।';

  @override
  String get whereThingsStand => 'अहिलेको अवस्था';

  @override
  String get nowLabel => 'अहिले';

  @override
  String confidenceFootnote(String value) {
    return 'विश्वास ७५ मध्ये $value।';
  }

  @override
  String get askHint => 'यो कुण्डलीबारे जे पनि सोध्नुहोस्…';

  @override
  String get askAction => 'सोध्नुहोस्';

  @override
  String get readingYourChart => 'तपाईंको कुण्डली पढ्दै';

  @override
  String howWorkedOut(String count) {
    return 'यो कसरी निकालियो ($count चरण)';
  }

  @override
  String get hideSteps => 'चरणहरू लुकाउनुहोस्';

  @override
  String get readFullAnswer => 'पूरा उत्तर पढ्नुहोस्';

  @override
  String get askEmptyNote =>
      'आफ्नै शब्दमा सोध्नुहोस्, वा माथिका सुझावमध्ये कुनै थिच्नुहोस्। पाठको हरेक चरण हुँदै गर्दा देख्नुहुनेछ, र हरेक नियम कुन स्रोत पुस्तकबाट आयो भन्ने पनि।';

  @override
  String get askFootnote =>
      'कुनै कुरालाई सम्भावना बलियो भन्नुअघि दुई विधि मिल्नैपर्छ। यो विधिले १०० मध्ये ७५ भन्दा बढी कहिल्यै दाबी गर्दैन।';

  @override
  String get twoChartsNeeded => 'दुई कुण्डली चाहिन्छ';

  @override
  String get twoChartsNeededSub =>
      'दुवै व्यक्तिलाई यहीं थप्नुहोस्, वा पहिले सुरक्षित गरेका कुण्डलीबाट छान्नुहोस्।';

  @override
  String get firstPerson => 'पहिलो व्यक्ति';

  @override
  String get secondPerson => 'दोस्रो व्यक्ति';

  @override
  String get choosePerson => 'छान्नुहोस्';

  @override
  String get matchAddNew => 'नयाँ कुण्डली थप्नुहोस्';

  @override
  String get matchChooseSaved => 'सुरक्षित कुण्डली छान्नुहोस्';

  @override
  String get matchNoSaved => 'अहिलेसम्म कुनै कुण्डली सुरक्षित छैन।';

  @override
  String get matchSavedNote =>
      'यहाँ थपिएको व्यक्ति तपाईंका कुण्डलीमा पनि सुरक्षित हुन्छ।';

  @override
  String get matchClear => 'हटाउनुहोस्';

  @override
  String get saveAndCompare => 'सुरक्षित गरी मिलान गर्नुहोस्';

  @override
  String get swap => 'साट्नुहोस्';

  @override
  String get pickTwoNote =>
      'तुलना गर्न दुई फरक व्यक्ति छान्नुहोस्। सबै गणना यही यन्त्रमा हुन्छ।';

  @override
  String outOfMax(String max) {
    return '$max मध्ये';
  }

  @override
  String traditionallyBand(String band) {
    return 'परम्परागत रूपमा $band';
  }

  @override
  String pairTitle(String first, String second) {
    return '$first र $second';
  }

  @override
  String get eightParameters => 'आठ कूट';

  @override
  String get eightParametersSub => 'हरेकले के तौल्छ, र यी दुईले कति अंक पाए।';

  @override
  String get whatChartSaid => 'कुण्डलीले के भन्यो';

  @override
  String get beyondScore => 'अंकभन्दा पर';

  @override
  String get beyondScoreSub => 'दुवै पूरा कुण्डलीले एकअर्काबारे के भन्छन्।';

  @override
  String get matchNote =>
      'अंकले शास्त्रीय मापदण्ड बताउँछ, दुई व्यक्तिलाई होइन। चलिरहेको, दुवैको सहमतिको सम्बन्ध यस पर्दाको कुनै पनि अंकभन्दा माथि छ; पकेटएस्ट्रोले कसैलाई छोड्न भन्दैन र जीवनसाथीलाई हानिको भविष्यवाणी गर्दैन।';

  @override
  String get saveComparison => 'यो तुलना PDF मा सुरक्षित गर्नुहोस्';

  @override
  String get manglikTitle => 'मङ्गलिक (कुज दोष)';

  @override
  String get manglikNone =>
      'कुनै पनि कुण्डलीमा कुज दोष छैन, त्यसैले यो मापदण्ड यहाँ लागू हुँदैन।';

  @override
  String get manglikBoth =>
      'दुवै कुण्डलीमा छ, जसले शास्त्रअनुसार यसलाई निष्क्रिय पार्छ। यही सबैभन्दा सामान्य र स्पष्ट समाधान हो।';

  @override
  String manglikOne(String name) {
    return '$name को कुण्डलीमा कुज दोष छ। यसले घनिष्ठतामा धेरै बल ल्याउने व्यक्ति जनाउँछ — यो अनुकूलताको एउटा मापदण्ड हो, दोष होइन, र प्रायः निष्क्रिय भइहाल्छ।';
  }

  @override
  String get manglikBadgeNone => 'लागू हुँदैन';

  @override
  String get manglikBadgeCancelled => 'निष्क्रिय';

  @override
  String get manglikBadgeOne => 'एक कुण्डली';

  @override
  String get manglikCancellations => 'शास्त्रअनुसार यो निष्क्रिय हुने तरिका:';

  @override
  String get howCancelled => 'यो कसरी निष्क्रिय हुन्छ';

  @override
  String get manglikFootnote =>
      'पकेटएस्ट्रोले मङ्गलिकलाई जीवनसाथीको हानि भन्ने भविष्यवाणीमा कहिल्यै प्रयोग गर्दैन, र विवाह असफल हुन्छ भन्दैन।';

  @override
  String get whyThis => 'किन?';

  @override
  String get hideDetail => 'विवरण लुकाउनुहोस्';

  @override
  String confidenceSemantic(String value) {
    return 'विश्वास ७५ मध्ये $value, यो विधिले दिन सक्ने अधिकतम';
  }

  @override
  String get legendBenefic => 'सहयोगी ग्रह';

  @override
  String get legendMalefic => 'कठोर ग्रह';

  @override
  String get legendSupported => 'अनुकूल क्षेत्र';

  @override
  String get legendSteady => 'सामान्य क्षेत्र';

  @override
  String get legendStrained => 'दबाबमा रहेको क्षेत्र';

  @override
  String get helpfulHere => 'यहाँ सहयोगी';

  @override
  String get demandingHere => 'यहाँ कठोर';
}

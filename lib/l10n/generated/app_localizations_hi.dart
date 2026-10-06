// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class LHi extends L {
  LHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'पॉकेटएस्ट्रो';

  @override
  String get navCompatibility => 'अनुकूलता';

  @override
  String get navLanguage => 'भाषा';

  @override
  String get navLearn => 'ज्योतिष सीखें';

  @override
  String get navRashifal => 'दैनिक राशिफल';

  @override
  String get homeToday => 'आज';

  @override
  String get homeYourCharts => 'आपकी कुंडलियाँ';

  @override
  String get homeYourChartsSub => 'पूरी कुंडली पढ़ने के लिए नाम पर टैप करें।';

  @override
  String get homeReadYourDay => 'अपना दिन पढ़ें';

  @override
  String get homeLearnCard => 'ज्योतिष सीखें';

  @override
  String get homeLearnCardSub =>
      'पंद्रह पाठ — कुंडली क्या है, से लेकर वह क्या नहीं कह सकती तक।';

  @override
  String homeLearnProgress(String done, String total) {
    return '$total में से $done पाठ';
  }

  @override
  String get homeLearnStart => 'सीखना शुरू करें';

  @override
  String get rashifalTitle => 'दैनिक राशिफल';

  @override
  String get rashifalSub => 'आज ग्रह कहाँ हैं, हर चंद्रराशि से गिनकर।';

  @override
  String get rashifalPickSign => 'अपनी चंद्रराशि चुनें';

  @override
  String get rashifalYours => 'आपकी';

  @override
  String rashifalYoursFor(String name) {
    return 'आपकी · $name';
  }

  @override
  String get rashifalMoonSign => 'चंद्रराशि';

  @override
  String get rashifalWhatMoves => 'आज क्या चल रहा है';

  @override
  String rashifalLineTitle(String graha, String house) {
    return '$graha · $house भाव';
  }

  @override
  String get rashifalObstructed => 'वेध से रुका';

  @override
  String get rashifalHelps => 'सहायक';

  @override
  String get rashifalPresses => 'दबाव';

  @override
  String get rashifalQuiet => 'शांत';

  @override
  String get rashifalBetterRead => 'इसे अपनी कुंडली के सामने पढ़ें';

  @override
  String get rashifalBetterReadSub =>
      'आपकी कुंडली इन्हीं गोचरों को आपके जन्म चंद्र, दशा और अष्टकवर्ग के साथ पढ़ती है।';

  @override
  String get rashifalNoChart =>
      'अपनी चंद्रराशि निश्चित नहीं? एक कुंडली जोड़िए, ऐप स्वयं निकाल लेगा।';

  @override
  String panchangaToday(String tithi, String nakshatra, String vara) {
    return '$tithi · $nakshatra · $vara';
  }

  @override
  String get storedOnDevice =>
      'आपकी कुंडलियाँ इसी डिवाइस पर रहती हैं। केवल जन्मस्थान की खोज ऑनलाइन जाती है, और तभी जब आप कहें।';

  @override
  String get emptyTitle => 'जन्मकुंडली पढ़ें, ऑफ़लाइन';

  @override
  String get emptyBody =>
      'जन्म तिथि, समय और स्थान जोड़ें। किसी खाते की ज़रूरत नहीं; आपकी कुंडलियाँ यह डिवाइस कभी नहीं छोड़तीं।';

  @override
  String get enterBirthDetails => 'जन्म विवरण दर्ज करें';

  @override
  String get loadDemo => 'नमूना देखें: १४ अप्रैल १९९२, काठमांडू';

  @override
  String get newChart => 'नई कुंडली';

  @override
  String get editChart => 'कुंडली संपादित करें';

  @override
  String get deleteTitle => 'यह कुंडली मिटाएँ?';

  @override
  String deleteBody(String name) {
    return '$name को इस डिवाइस से हटाएँ।';
  }

  @override
  String get cancel => 'रद्द करें';

  @override
  String get delete => 'मिटाएँ';

  @override
  String get timeUnknownShort => 'समय अज्ञात';

  @override
  String get notFound => 'नहीं मिला';

  @override
  String get fieldName => 'नाम';

  @override
  String get fieldDateTime => 'तिथि और समय (जन्मस्थान का स्थानीय)';

  @override
  String get switchTimeUnknown => 'जन्म समय ज्ञात नहीं';

  @override
  String get switchTimeUnknownSub =>
      'लग्न और बारहों भाव अनुमान लगाए बिना रोक दिए जाएँगे। चंद्रमा से पाठ फिर भी चलता है।';

  @override
  String get fieldTimeSource => 'समय का स्रोत';

  @override
  String get fieldBirthPlace => 'जन्म स्थान';

  @override
  String get invalidLocation =>
      'स्थान की जानकारी अमान्य है। कृपया कोई मान्य स्थान नाम दर्ज करें।';

  @override
  String get hintTypePlace => 'कोई भी शहर या कस्बा लिखें';

  @override
  String get searchOnline => 'ऑनलाइन खोजें';

  @override
  String get searchingPlaces => 'खोजा जा रहा है…';

  @override
  String get placeSearchMinChars => 'कम से कम तीन अक्षर लिखकर खोजें।';

  @override
  String get placeLookupOffline =>
      'स्थान खोज तक नहीं पहुँच सके। सहेजे हुए और अंतर्निहित स्थान अब भी काम करते हैं।';

  @override
  String get placeLookupRetry => 'फिर कोशिश करें';

  @override
  String get sectionOnDevice => 'इस डिवाइस के स्थान';

  @override
  String get sectionOnlineResults => 'ऑनलाइन परिणाम';

  @override
  String get placeOnlineNote =>
      'केवल यह खोज आपके डिवाइस से बाहर जाती है। आपकी कुंडली कहीं नहीं भेजी जाती।';

  @override
  String get useCoordinates => 'इसके बजाय निर्देशांक दर्ज करें';

  @override
  String get fieldLatitude => 'अक्षांश';

  @override
  String get fieldLongitude => 'देशांतर';

  @override
  String get fieldTimezone => 'समय क्षेत्र';

  @override
  String get hintTimezone => 'एक IANA ज़ोन आईडी, जैसे Asia/Kathmandu';

  @override
  String get invalidCoordinates =>
      'अक्षांश −90 से 90, देशांतर −180 से 180, और ज़ोन एक वास्तविक IANA आईडी होना चाहिए।';

  @override
  String get useThisPlace => 'यही स्थान लें';

  @override
  String selectedPlace(String place, String zone) {
    return 'चयनित: $place ($zone)';
  }

  @override
  String get saveAndRead => 'सहेजें और कुंडली पढ़ें';

  @override
  String get tabOverview => 'सारांश';

  @override
  String get tabKundali => 'कुंडली';

  @override
  String get tabLifeAreas => 'जीवन क्षेत्र';

  @override
  String get tabTiming => 'समय';

  @override
  String get tabAsk => 'पूछें';

  @override
  String get tabLearn => 'सीखें';

  @override
  String get learnTitle => 'ज्योतिष सीखें';

  @override
  String get learnSub =>
      'शुरू से पंद्रह पाठ, और हर पाठ का अंत आपकी अपनी कुंडली में।';

  @override
  String learnProgress(String done, String total) {
    return '$total में से $done पाठ पूरे';
  }

  @override
  String get learnContinue => 'जारी रखें';

  @override
  String get learnStart => 'पाठ्यक्रम शुरू करें';

  @override
  String get learnNextUp => 'अगला पाठ';

  @override
  String get learnFinished => 'आप पूरा पाठ्यक्रम पढ़ चुके हैं।';

  @override
  String get learnFinishedSub =>
      'किसी भी पाठ पर कभी भी लौट सकते हैं। यहाँ कुछ भी समाप्त नहीं होता।';

  @override
  String learnLevelProgress(String done, String total) {
    return '$done/$total';
  }

  @override
  String learnMinutes(String minutes) {
    return '$minutes मिनट';
  }

  @override
  String learnLessonOf(String number, String total) {
    return '$total में से पाठ $number';
  }

  @override
  String get learnInYourChart => 'आपकी कुंडली में';

  @override
  String get learnCheck => 'स्वयं जाँचें';

  @override
  String get learnShowAnswer => 'उत्तर दिखाएँ';

  @override
  String get learnHideAnswer => 'उत्तर छिपाएँ';

  @override
  String get learnMarkDone => 'पढ़ा हुआ चिह्नित करें';

  @override
  String get learnMarkNotDone => 'पढ़ लिया';

  @override
  String get learnNextLesson => 'अगला पाठ';

  @override
  String get learnReset => 'प्रगति मिटाएँ';

  @override
  String get learnResetTitle => 'पाठ्यक्रम फिर से शुरू करें?';

  @override
  String get learnResetBody =>
      'इससे पढ़े हुए चिह्नित सभी पाठ मिट जाएँगे। पाठ स्वयं जहाँ हैं वहीं रहेंगे।';

  @override
  String get learnEmpty => 'पाठ्यक्रम लोड नहीं हो सका।';

  @override
  String get learnFootnote =>
      'यह पाठ्यक्रम है, प्रमाणपत्र नहीं। पॉकेटएस्ट्रो शास्त्रीय विधि सिखाता है और यह भी स्पष्ट कहता है कि वह विधि कहाँ रुक जाती है।';

  @override
  String get tabToday => 'आज';

  @override
  String todayReckoned(String place) {
    return '$place के सूर्योदय से गणना';
  }

  @override
  String todaySunTimes(String sunrise, String sunset) {
    return 'सूर्योदय $sunrise · सूर्यास्त $sunset';
  }

  @override
  String get todayEstimatedLight =>
      'इस तिथि को यहाँ सूर्य क्षितिज पार नहीं करता, इसलिए दिन की खिड़कियाँ प्रातः ६ से सायं ६ की परिपाटी पर ली गई हैं।';

  @override
  String get todayPanchanga => 'पंचांग के पाँच अंग';

  @override
  String get todayPanchangaSub =>
      'आपसे कुछ कहने से पहले आज का दिन स्वयं क्या है।';

  @override
  String todayUntil(String time) {
    return '$time तक';
  }

  @override
  String get todayAllDay => 'कल सूर्योदय तक';

  @override
  String get todayMoonStrength => 'आज आपका चंद्रमा';

  @override
  String get todayMoonStrengthSub =>
      'आज का चंद्रमा आपके जन्म चंद्र के सामने तौला गया।';

  @override
  String get todayTarabala => 'ताराबल';

  @override
  String todayTarabalaValue(String name, String count) {
    return '$name — 27 में से $countवाँ तारा';
  }

  @override
  String get todayChandrabala => 'चंद्रबल';

  @override
  String todayChandrabalaValue(String house) {
    return 'जन्म चंद्र से $house भाव';
  }

  @override
  String get todayKakshya => 'कक्ष्या गणना';

  @override
  String todayKakshyaValue(String score) {
    return '7 में से $score ग्रह बिंदु लिए हैं';
  }

  @override
  String get todayNoKakshya =>
      'कक्ष्या गणना के लिए जन्म समय चाहिए — अष्टकवर्ग का आठवाँ दाता लग्न ही है।';

  @override
  String get todayLeanInto => 'इस ओर झुकें';

  @override
  String get todayLeanIntoSub =>
      'शास्त्र के अनुसार आज का दिन किसके लिए उपयुक्त है।';

  @override
  String get todayHoldOff => 'अभी रोकें';

  @override
  String get todayHoldOffSub =>
      'शास्त्र के अनुसार आज का दिन किसके लिए अनुपयुक्त है। इनमें से कुछ भी निषेध नहीं है।';

  @override
  String get todayWindows => 'दिन की खिड़कियाँ';

  @override
  String get todayWindowsSub => 'सूर्योदय से गिने गए दिनमान के अंश।';

  @override
  String get todayWindowNow => 'अभी चल रही';

  @override
  String get todayGuidance => 'मार्गदर्शन';

  @override
  String get todayPeriodToday => 'आज आपकी दशा';

  @override
  String get todayCarrying => 'आज का भार किस पर';

  @override
  String get todayFootnote =>
      'मुहूर्त अंतिम छलनी है, पहली नहीं। क्या संभव है यह आपकी कुंडली और चल रही दशा तय करती है; दिन केवल यह तय करता है कि वह कैसा लगेगा।';

  @override
  String get todayWorkingOut => 'आज का आकलन कैसे हुआ';

  @override
  String todayScoreLine(String score) {
    return 'सभी छलनियों का जोड़ $score रहा।';
  }

  @override
  String get savePdf => 'PDF में सहेजें';

  @override
  String risingTitle(String sign) {
    return '$sign लग्न';
  }

  @override
  String moonTitle(String sign) {
    return 'चंद्रमा $sign में';
  }

  @override
  String get noTimeLead => 'आपका मन और सहज प्रवृत्ति चंद्रमा से पढ़ी जाती है।';

  @override
  String moonSunLine(String moon, String sun) {
    return 'चंद्रमा $moon में · सूर्य $sun में';
  }

  @override
  String birthStarLine(String nakshatra, String pada) {
    return 'जन्म नक्षत्र $nakshatra, चरण $pada';
  }

  @override
  String periodTitle(String lord) {
    return 'आप $lord की दशा में हैं';
  }

  @override
  String periodSub(String lord, String date) {
    return 'वर्तमान में $lord अंतर्दशा, $date तक';
  }

  @override
  String periodRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String periodProgress(String percent, String years) {
    return '$percent% बीत चुका · लगभग $years वर्ष शेष। दशा एक अध्याय है, दंड नहीं।';
  }

  @override
  String get periodClosed => 'यह दशा समाप्त हो चुकी है।';

  @override
  String get whatSupports => 'यह कुंडली किसका साथ देती है';

  @override
  String get whatSupportsSub =>
      'कहाँ कुंडली सहायता करती है, और कहाँ मेहनत माँगती है।';

  @override
  String get standoutPatterns => 'विशेष योग';

  @override
  String get standoutPatternsSub =>
      'शास्त्र आपकी कुंडली में जिन संयोगों को विशेष बताते हैं।';

  @override
  String get disclaimerOffline =>
      'पॉकेटएस्ट्रो ५६ शास्त्रीय और आधुनिक स्रोतों से आपकी कुंडली ऑफ़लाइन पढ़ता है। यह व्याख्यात्मक है — चिकित्सा, कानूनी या वित्तीय सलाह नहीं; यह मृत्यु की भविष्यवाणी या रोग-निदान नहीं करता।';

  @override
  String get noTimeNote =>
      'जन्म समय दर्ज नहीं है, इसलिए लग्न, बारहों भाव और उन पर आधारित सब कुछ रोक दिया गया है। चंद्रमा फिर भी पूरा पाठ देता है। शेष खोलने के लिए समय जोड़ें।';

  @override
  String get northIndian => 'उत्तर भारतीय';

  @override
  String get southIndian => 'दक्षिण भारतीय';

  @override
  String get hintNorth =>
      'भाव स्थिर रहते हैं; राशियाँ आपके लग्न के अनुसार बदलती हैं।';

  @override
  String get hintSouth =>
      'राशियाँ स्थिर रहती हैं; आपका लग्न “लग्न” से चिह्नित है।';

  @override
  String get showShading => 'भाव का रंग दिखाएँ';

  @override
  String get hideShading => 'भाव का रंग छिपाएँ';

  @override
  String get tapGraha =>
      'कौन-सा ग्रह किसे प्रभावित करता है देखने के लिए ग्रह पर टैप करें';

  @override
  String get tapGrahaSub =>
      'इसकी दृष्टियाँ जिन भावों तक पहुँचती हैं, वे रेखांकित होती हैं।';

  @override
  String influencesHouses(String count) {
    return 'यह $count भावों को प्रभावित करता है';
  }

  @override
  String get whyColour => 'यह रंग क्यों?';

  @override
  String get advancedTitle => 'सटीक स्थिति और पाश्चात्य चक्र';

  @override
  String get advancedSub => 'अंश, नक्षत्र, बलाबल और दृष्टि';

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
    return '$lord, जो $house भाव में है';
  }

  @override
  String get sheetGrahasHere => 'यहाँ के ग्रह';

  @override
  String get sheetNoGrahas =>
      'कोई नहीं — फल स्वामी के माध्यम से आता है, जो सामान्य है';

  @override
  String get sheetInfluencedBy => 'दृष्टि डालने वाले';

  @override
  String get sheetPointCount => 'बिंदु';

  @override
  String sheetPointValue(String count) {
    return '५६ में से $count, औसत २८ की तुलना में';
  }

  @override
  String get sheetTopics => 'शास्त्रीय विषय';

  @override
  String get whatHelps => 'यहाँ क्या सहायता करता है';

  @override
  String get whatPresses => 'क्या दबाव डालता है';

  @override
  String get houseSheetNote =>
      'भाव का पाठ यह मार्गदर्शन है कि कुंडली कहाँ सहायता करती है, भविष्यवाणी नहीं। दबाव का कारण और उपाय होता है; यह आपके जीवन का फैसला कभी नहीं है।';

  @override
  String get twelveAreas => 'आपके जीवन के बारह क्षेत्र';

  @override
  String get twelveAreasSub =>
      'किसी एक पर टैप करके देखें कि उसे क्या आकार देता है।';

  @override
  String get readingsInFull => 'पूरा पाठ';

  @override
  String get readingsInFullSub => 'वही कुंडली, शास्त्रीय भाषा में।';

  @override
  String get lifeNoTimeNote =>
      'बारह भावों के लिए जन्म समय चाहिए। न होने पर, पॉकेटएस्ट्रो सटीक दिखने वाली गलत बात दिखाने के बजाय उसे रोक देता है।';

  @override
  String get lifeInPeriods => 'दशाओं में आपका जीवन';

  @override
  String get lifeInPeriodsSub => 'विंशोत्तरी चक्र, आपके चंद्रमा से मापा गया।';

  @override
  String insidePeriod(String lord) {
    return '$lord दशा के भीतर';
  }

  @override
  String get insidePeriodSub =>
      'अंतर्दशा अध्याय को कुछ महीनों तक सीमित कर देती है।';

  @override
  String get nextTwoYears => 'आगामी दो वर्ष कैसे दिखते हैं';

  @override
  String get nextTwoYearsSub => 'जहाँ दो विधियाँ सहमत होती हैं।';

  @override
  String get nextTwoYearsNone => 'कुछ विशेष नहीं दिखता। यह सामान्य परिणाम है।';

  @override
  String get noWindowNote =>
      'आगामी चौबीस महीनों में कोई विशेष अनुकूल समय नहीं है। इसका अर्थ यह नहीं कि कुछ नहीं होगा — बस दो विधियाँ इतनी मजबूती से नहीं मिलतीं कि पॉकेटएस्ट्रो कुछ कह सके।';

  @override
  String get whereThingsStand => 'अभी की स्थिति';

  @override
  String get nowLabel => 'अभी';

  @override
  String confidenceFootnote(String value) {
    return 'विश्वास ७५ में से $value।';
  }

  @override
  String get askHint => 'इस कुंडली के बारे में कुछ भी पूछें…';

  @override
  String get askAction => 'पूछें';

  @override
  String get readingYourChart => 'आपकी कुंडली पढ़ी जा रही है';

  @override
  String howWorkedOut(String count) {
    return 'यह कैसे निकाला गया ($count चरण)';
  }

  @override
  String get hideSteps => 'चरण छिपाएँ';

  @override
  String get readFullAnswer => 'पूरा उत्तर पढ़ें';

  @override
  String get askEmptyNote =>
      'अपने शब्दों में पूछें, या ऊपर दिए सुझावों में से कोई चुनें। पाठ का हर चरण होते हुए दिखेगा, और हर नियम किस स्रोत पुस्तक से आया यह भी।';

  @override
  String get askFootnote =>
      'किसी बात को प्रबल कहने से पहले दो विधियों का सहमत होना आवश्यक है। यह विधि १०० में से ७५ से अधिक कभी दावा नहीं करती।';

  @override
  String get twoChartsNeeded => 'दो कुंडलियाँ चाहिए';

  @override
  String get twoChartsNeededSub =>
      'दोनों व्यक्तियों को यहीं जोड़ें, या पहले से सहेजी कुंडलियों में से चुनें।';

  @override
  String get firstPerson => 'पहला व्यक्ति';

  @override
  String get secondPerson => 'दूसरा व्यक्ति';

  @override
  String get choosePerson => 'चुनें';

  @override
  String get matchAddNew => 'नई कुंडली जोड़ें';

  @override
  String get matchChooseSaved => 'सहेजी हुई कुंडली चुनें';

  @override
  String get matchNoSaved => 'अभी कोई कुंडली सहेजी नहीं है।';

  @override
  String get matchSavedNote =>
      'यहाँ जोड़ा गया व्यक्ति आपकी कुंडलियों में भी सहेजा जाता है।';

  @override
  String get matchClear => 'हटाएँ';

  @override
  String get saveAndCompare => 'सहेजें और मिलान करें';

  @override
  String get swap => 'बदलें';

  @override
  String get pickTwoNote =>
      'तुलना के लिए दो अलग व्यक्ति चुनें। सारी गणना इसी डिवाइस में होती है।';

  @override
  String outOfMax(String max) {
    return '$max में से';
  }

  @override
  String traditionallyBand(String band) {
    return 'परंपरागत रूप से $band';
  }

  @override
  String pairTitle(String first, String second) {
    return '$first और $second';
  }

  @override
  String get eightParameters => 'आठ कूट';

  @override
  String get eightParametersSub =>
      'प्रत्येक क्या तौलता है, और इन दोनों को कितने अंक मिले।';

  @override
  String get whatChartSaid => 'कुंडली ने क्या कहा';

  @override
  String get beyondScore => 'अंक से परे';

  @override
  String get beyondScoreSub =>
      'दोनों पूरी कुंडलियाँ एक-दूसरे के बारे में क्या कहती हैं।';

  @override
  String get matchNote =>
      'अंक शास्त्रीय मापदंड बताता है, दो व्यक्तियों को नहीं। चलता हुआ, सहमति वाला संबंध इस स्क्रीन के किसी भी अंक से ऊपर है; पॉकेटएस्ट्रो कभी किसी को छोड़ने को नहीं कहता और न जीवनसाथी को हानि की भविष्यवाणी करता है।';

  @override
  String get saveComparison => 'इस तुलना को PDF में सहेजें';

  @override
  String get manglikTitle => 'मांगलिक (कुज दोष)';

  @override
  String get manglikNone =>
      'किसी भी कुंडली में कुज दोष नहीं है, इसलिए यह मापदंड यहाँ लागू नहीं होता।';

  @override
  String get manglikBoth =>
      'दोनों कुंडलियों में है, जो शास्त्र के अनुसार इसे निष्प्रभावी कर देता है। यही सबसे सामान्य और स्पष्ट समाधान है।';

  @override
  String manglikOne(String name) {
    return '$name की कुंडली में कुज दोष है। यह ऐसे व्यक्ति को बताता है जो निकटता में अधिक बल लाता है — यह अनुकूलता का एक मापदंड है, दोष नहीं, और प्रायः निष्प्रभावी हो जाता है।';
  }

  @override
  String get manglikBadgeNone => 'लागू नहीं';

  @override
  String get manglikBadgeCancelled => 'निष्प्रभावी';

  @override
  String get manglikBadgeOne => 'एक कुंडली';

  @override
  String get manglikCancellations =>
      'शास्त्र के अनुसार यह जिन तरीकों से निष्प्रभावी होता है:';

  @override
  String get howCancelled => 'यह कैसे निष्प्रभावी होता है';

  @override
  String get manglikFootnote =>
      'पॉकेटएस्ट्रो मांगलिक का उपयोग जीवनसाथी को हानि की भविष्यवाणी के लिए कभी नहीं करता, और यह नहीं कहता कि विवाह असफल होगा।';

  @override
  String get whyThis => 'क्यों?';

  @override
  String get hideDetail => 'विवरण छिपाएँ';

  @override
  String confidenceSemantic(String value) {
    return 'विश्वास ७५ में से $value, इस विधि की अधिकतम सीमा';
  }

  @override
  String get legendBenefic => 'सहायक ग्रह';

  @override
  String get legendMalefic => 'कठोर ग्रह';

  @override
  String get legendSupported => 'अनुकूल क्षेत्र';

  @override
  String get legendSteady => 'सामान्य क्षेत्र';

  @override
  String get legendStrained => 'दबाव में क्षेत्र';

  @override
  String get helpfulHere => 'यहाँ सहायक';

  @override
  String get demandingHere => 'यहाँ कठोर';
}

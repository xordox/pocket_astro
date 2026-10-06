// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PocketAstro';

  @override
  String get navCompatibility => 'Compatibility';

  @override
  String get navLanguage => 'Language';

  @override
  String get navLearn => 'Learn astrology';

  @override
  String get navRashifal => 'Daily reading';

  @override
  String get homeToday => 'Today';

  @override
  String get homeYourCharts => 'Your charts';

  @override
  String get homeYourChartsSub => 'Tap a name to read the whole chart.';

  @override
  String get homeReadYourDay => 'Read your day';

  @override
  String get homeLearnCard => 'Learn astrology';

  @override
  String get homeLearnCardSub =>
      'Fifteen lessons, from what a chart is to what it cannot say.';

  @override
  String homeLearnProgress(String done, String total) {
    return '$done of $total lessons';
  }

  @override
  String get homeLearnStart => 'Start learning';

  @override
  String get rashifalTitle => 'Daily reading';

  @override
  String get rashifalSub =>
      'Where the grahas are today, counted from each moon sign.';

  @override
  String get rashifalPickSign => 'Choose your moon sign';

  @override
  String get rashifalYours => 'Yours';

  @override
  String rashifalYoursFor(String name) {
    return 'Yours · $name';
  }

  @override
  String get rashifalMoonSign => 'Moon sign';

  @override
  String get rashifalWhatMoves => 'What is moving today';

  @override
  String rashifalLineTitle(String graha, String house) {
    return '$graha · $house house';
  }

  @override
  String get rashifalObstructed => 'Obstructed';

  @override
  String get rashifalHelps => 'Helps';

  @override
  String get rashifalPresses => 'Presses';

  @override
  String get rashifalQuiet => 'Quiet';

  @override
  String get rashifalBetterRead => 'Read this against your own chart';

  @override
  String get rashifalBetterReadSub =>
      'Your chart reads the same transits against your birth Moon, your period and your ashtakavarga.';

  @override
  String get rashifalNoChart =>
      'Not sure of your moon sign? Add a birth chart and the app will work it out.';

  @override
  String panchangaToday(String tithi, String nakshatra, String vara) {
    return '$tithi · $nakshatra · $vara';
  }

  @override
  String get storedOnDevice =>
      'Your charts stay on this device. Only birthplace search goes online, and only when you ask.';

  @override
  String get emptyTitle => 'Read a birth chart, offline';

  @override
  String get emptyBody =>
      'Add a birth date, time and place. No account needed; your charts never leave this device.';

  @override
  String get enterBirthDetails => 'Enter birth details';

  @override
  String get loadDemo => 'Load demo: 14 Apr 1992, Kathmandu';

  @override
  String get newChart => 'New chart';

  @override
  String get editChart => 'Edit chart';

  @override
  String get deleteTitle => 'Delete this chart?';

  @override
  String deleteBody(String name) {
    return 'Remove $name from this device.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get timeUnknownShort => 'time unknown';

  @override
  String get notFound => 'Not found';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldDateTime => 'Date and time (local at birth)';

  @override
  String get switchTimeUnknown => 'Birth time unknown';

  @override
  String get switchTimeUnknownSub =>
      'The rising sign and the twelve houses will be withheld rather than guessed. Your Moon reading still works.';

  @override
  String get fieldTimeSource => 'Time source';

  @override
  String get fieldBirthPlace => 'Birth place';

  @override
  String get invalidLocation =>
      'Invalid location data. Please enter a valid place name.';

  @override
  String get hintTypePlace => 'Type any town or city';

  @override
  String get searchOnline => 'Search online';

  @override
  String get searchingPlaces => 'Searching…';

  @override
  String get placeSearchMinChars => 'Type at least three letters, then search.';

  @override
  String get placeLookupOffline =>
      'Could not reach the place search. Saved and built-in places still work.';

  @override
  String get placeLookupRetry => 'Try again';

  @override
  String get sectionOnDevice => 'Places on this device';

  @override
  String get sectionOnlineResults => 'Online results';

  @override
  String get placeOnlineNote =>
      'Only this search leaves your device. Your chart is never sent anywhere.';

  @override
  String get useCoordinates => 'Enter coordinates instead';

  @override
  String get fieldLatitude => 'Latitude';

  @override
  String get fieldLongitude => 'Longitude';

  @override
  String get fieldTimezone => 'Time zone';

  @override
  String get hintTimezone => 'An IANA zone id, such as Asia/Kathmandu';

  @override
  String get invalidCoordinates =>
      'Latitude runs −90 to 90, longitude −180 to 180, and the zone must be a real IANA id.';

  @override
  String get useThisPlace => 'Use this place';

  @override
  String selectedPlace(String place, String zone) {
    return 'Selected: $place ($zone)';
  }

  @override
  String get saveAndRead => 'Save and read the chart';

  @override
  String get tabOverview => 'Overview';

  @override
  String get tabKundali => 'Kundali';

  @override
  String get tabLifeAreas => 'Life areas';

  @override
  String get tabTiming => 'Timing';

  @override
  String get tabAsk => 'Ask';

  @override
  String get tabLearn => 'Learn';

  @override
  String get learnTitle => 'Learn astrology';

  @override
  String get learnSub =>
      'Fifteen lessons from the ground up, each one ending in your own chart.';

  @override
  String learnProgress(String done, String total) {
    return '$done of $total lessons done';
  }

  @override
  String get learnContinue => 'Continue';

  @override
  String get learnStart => 'Start the course';

  @override
  String get learnNextUp => 'Next up';

  @override
  String get learnFinished => 'You have been through the whole course.';

  @override
  String get learnFinishedSub =>
      'Go back to any lesson at any time. Nothing here expires.';

  @override
  String learnLevelProgress(String done, String total) {
    return '$done/$total';
  }

  @override
  String learnMinutes(String minutes) {
    return '$minutes min read';
  }

  @override
  String learnLessonOf(String number, String total) {
    return 'Lesson $number of $total';
  }

  @override
  String get learnInYourChart => 'In your chart';

  @override
  String get learnCheck => 'Check yourself';

  @override
  String get learnShowAnswer => 'Show the answer';

  @override
  String get learnHideAnswer => 'Hide the answer';

  @override
  String get learnMarkDone => 'Mark as read';

  @override
  String get learnMarkNotDone => 'Read';

  @override
  String get learnNextLesson => 'Next lesson';

  @override
  String get learnReset => 'Reset progress';

  @override
  String get learnResetTitle => 'Start the course again?';

  @override
  String get learnResetBody =>
      'This clears every lesson you have marked as read. The lessons themselves stay where they are.';

  @override
  String get learnEmpty => 'The syllabus could not be loaded.';

  @override
  String get learnFootnote =>
      'A syllabus, not a certification. PocketAstro teaches the classical method and is explicit about where that method stops.';

  @override
  String get tabToday => 'Today';

  @override
  String todayReckoned(String place) {
    return 'Reckoned from sunrise at $place';
  }

  @override
  String todaySunTimes(String sunrise, String sunset) {
    return 'Sunrise $sunrise · Sunset $sunset';
  }

  @override
  String get todayEstimatedLight =>
      'The Sun does not cross the horizon here on this date, so the day’s windows fall back to a 6am–6pm convention.';

  @override
  String get todayPanchanga => 'The five limbs';

  @override
  String get todayPanchangaSub =>
      'What today is, before it is anything about you.';

  @override
  String todayUntil(String time) {
    return 'until $time';
  }

  @override
  String get todayAllDay => 'until sunrise tomorrow';

  @override
  String get todayMoonStrength => 'Your Moon today';

  @override
  String get todayMoonStrengthSub =>
      'Today’s Moon measured against the Moon you were born under.';

  @override
  String get todayTarabala => 'Tarabala';

  @override
  String todayTarabalaValue(String name, String count) {
    return '$name — star $count of 27';
  }

  @override
  String get todayChandrabala => 'Chandrabala';

  @override
  String todayChandrabalaValue(String house) {
    return '$house house from your birth Moon';
  }

  @override
  String get todayKakshya => 'Kakshya count';

  @override
  String todayKakshyaValue(String score) {
    return '$score of 7 grahas carry a bindu';
  }

  @override
  String get todayNoKakshya =>
      'The kakshya count needs a birth time — the ascendant is the eighth contributor to the ashtakavarga.';

  @override
  String get todayLeanInto => 'Lean into';

  @override
  String get todayLeanIntoSub => 'What today is classically suited to.';

  @override
  String get todayHoldOff => 'Hold off on';

  @override
  String get todayHoldOffSub =>
      'What today is classically unsuited to. None of it is a prohibition.';

  @override
  String get todayWindows => 'Windows in the day';

  @override
  String get todayWindowsSub =>
      'Fractions of the daylight, counted from sunrise.';

  @override
  String get todayWindowNow => 'on now';

  @override
  String get todayGuidance => 'Guidance';

  @override
  String get todayPeriodToday => 'Your period today';

  @override
  String get todayCarrying => 'Carrying today';

  @override
  String get todayFootnote =>
      'Muhurta is the last filter, not the first. Your chart and your running period decide what is possible; the day only decides how it feels.';

  @override
  String get todayWorkingOut => 'How today was graded';

  @override
  String todayScoreLine(String score) {
    return 'Filters tallied to $score.';
  }

  @override
  String get savePdf => 'Save as PDF';

  @override
  String risingTitle(String sign) {
    return '$sign rising';
  }

  @override
  String moonTitle(String sign) {
    return 'Moon in $sign';
  }

  @override
  String get noTimeLead => 'Your mind and instincts are read from the Moon.';

  @override
  String moonSunLine(String moon, String sun) {
    return 'Moon in $moon · Sun in $sun';
  }

  @override
  String birthStarLine(String nakshatra, String pada) {
    return 'Birth star $nakshatra, pada $pada';
  }

  @override
  String periodTitle(String lord) {
    return 'You are in a $lord period';
  }

  @override
  String periodSub(String lord, String date) {
    return 'Currently the $lord sub-period, to $date';
  }

  @override
  String periodRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String periodProgress(String percent, String years) {
    return '$percent% through · about $years years left. A period is a chapter, not a sentence.';
  }

  @override
  String get periodClosed => 'This period has closed.';

  @override
  String get whatSupports => 'What this chart supports';

  @override
  String get whatSupportsSub =>
      'Where the chart helps, and where it asks for effort.';

  @override
  String get standoutPatterns => 'Standout patterns';

  @override
  String get standoutPatternsSub =>
      'Combinations the classics single out in your chart.';

  @override
  String get disclaimerOffline =>
      'PocketAstro reads your chart offline from 56 classical and modern sources. It is interpretive, not medical, legal or financial advice, and it will not predict death or diagnose illness.';

  @override
  String get noTimeNote =>
      'No birth time on file, so the rising sign, the twelve houses and everything built on them are withheld. The Moon still carries a full reading. Add a time to unlock the rest.';

  @override
  String get northIndian => 'North Indian';

  @override
  String get southIndian => 'South Indian';

  @override
  String get hintNorth =>
      'Houses stay in place; the signs move with your rising sign.';

  @override
  String get hintSouth =>
      'Signs stay in place; your rising sign is marked “Asc”.';

  @override
  String get showShading => 'Show house shading';

  @override
  String get hideShading => 'Hide house shading';

  @override
  String get tapGraha => 'Tap a graha to see what it influences';

  @override
  String get tapGrahaSub => 'Its aspects are drawn onto the houses it reaches.';

  @override
  String influencesHouses(String count) {
    return 'It influences $count houses';
  }

  @override
  String get whyColour => 'Why this colour?';

  @override
  String get advancedTitle => 'Exact positions and the Western wheel';

  @override
  String get advancedSub => 'Degrees, nakshatras, dignities and aspects';

  @override
  String get colGraha => 'Graha';

  @override
  String get colSidereal => 'Sidereal';

  @override
  String get colHouse => 'House';

  @override
  String get colNakshatra => 'Nakshatra';

  @override
  String get colDignity => 'Dignity';

  @override
  String get westernWheelTitle => 'Western wheel (tropical)';

  @override
  String houseNumber(String number) {
    return 'House $number';
  }

  @override
  String get sheetSign => 'Sign';

  @override
  String get sheetRuledBy => 'Ruled by';

  @override
  String sheetRulerIn(String lord, String house) {
    return '$lord, sitting in house $house';
  }

  @override
  String get sheetGrahasHere => 'Grahas here';

  @override
  String get sheetNoGrahas =>
      'None — the result runs through its ruler, which is normal';

  @override
  String get sheetInfluencedBy => 'Influenced by';

  @override
  String get sheetPointCount => 'Point count';

  @override
  String sheetPointValue(String count) {
    return '$count of 56, against an average of 28';
  }

  @override
  String get sheetTopics => 'Classical topics';

  @override
  String get whatHelps => 'What helps here';

  @override
  String get whatPresses => 'What presses on it';

  @override
  String get houseSheetNote =>
      'A house reading is a guide to where the chart helps, not a prediction. Pressure has a cause and a remedy; it is never a verdict on how your life turns out.';

  @override
  String get twelveAreas => 'The twelve areas of your life';

  @override
  String get twelveAreasSub => 'Tap any one to see exactly what shapes it.';

  @override
  String get readingsInFull => 'Readings in full';

  @override
  String get readingsInFullSub => 'The same chart, in the classical language.';

  @override
  String get lifeNoTimeNote =>
      'The twelve houses need a birth time. Without one, PocketAstro withholds them rather than showing something that looks precise and is not.';

  @override
  String get lifeInPeriods => 'Your life in periods';

  @override
  String get lifeInPeriodsSub =>
      'The Vimshottari cycle, measured from your Moon.';

  @override
  String insidePeriod(String lord) {
    return 'Inside the $lord period';
  }

  @override
  String get insidePeriodSub => 'Sub-periods narrow a chapter to a few months.';

  @override
  String get nextTwoYears => 'What the next two years look like';

  @override
  String get nextTwoYearsSub => 'Windows where two techniques agree.';

  @override
  String get nextTwoYearsNone => 'Nothing stands out. That is a normal result.';

  @override
  String get noWindowNote =>
      'No standout window in the next twenty-four months. This does not mean nothing happens — it means no two techniques line up strongly enough for PocketAstro to call one.';

  @override
  String get whereThingsStand => 'Where things stand now';

  @override
  String get nowLabel => 'now';

  @override
  String confidenceFootnote(String value) {
    return 'Confidence $value of a possible 75.';
  }

  @override
  String get askHint => 'Ask anything about this chart…';

  @override
  String get askAction => 'Ask';

  @override
  String get readingYourChart => 'Reading your chart';

  @override
  String howWorkedOut(String count) {
    return 'How this was worked out ($count steps)';
  }

  @override
  String get hideSteps => 'Hide the steps';

  @override
  String get readFullAnswer => 'Read the full answer';

  @override
  String get askEmptyNote =>
      'Ask in your own words, or tap one of the suggestions above. You will see each step of the reading as it happens, and which of the source books each rule came from.';

  @override
  String get askFootnote =>
      'Two techniques must agree before anything is called likely. This method never claims more than 75 out of 100.';

  @override
  String get twoChartsNeeded => 'Two charts needed';

  @override
  String get twoChartsNeededSub =>
      'Add both people right here, or pick from charts you have already saved.';

  @override
  String get firstPerson => 'First person';

  @override
  String get secondPerson => 'Second person';

  @override
  String get choosePerson => 'Choose';

  @override
  String get matchAddNew => 'Add a new chart';

  @override
  String get matchChooseSaved => 'Choose a saved chart';

  @override
  String get matchNoSaved => 'No charts saved yet.';

  @override
  String get matchSavedNote =>
      'Anyone you add here is saved to your charts too.';

  @override
  String get matchClear => 'Remove';

  @override
  String get saveAndCompare => 'Save and compare';

  @override
  String get swap => 'Swap';

  @override
  String get pickTwoNote =>
      'Pick two different people to compare. Everything is computed on this device.';

  @override
  String outOfMax(String max) {
    return 'of $max';
  }

  @override
  String traditionallyBand(String band) {
    return 'Traditionally $band';
  }

  @override
  String pairTitle(String first, String second) {
    return '$first and $second';
  }

  @override
  String get eightParameters => 'The eight parameters';

  @override
  String get eightParametersSub =>
      'What each one weighs, and how these two scored.';

  @override
  String get whatChartSaid => 'What the chart said';

  @override
  String get beyondScore => 'Beyond the score';

  @override
  String get beyondScoreSub =>
      'What the two whole charts say about each other.';

  @override
  String get matchNote =>
      'A score describes classical parameters, not two people. A living, consensual relationship outranks any number on this screen, and PocketAstro will never tell you to leave someone or predict harm to a partner.';

  @override
  String get saveComparison => 'Save this comparison as a PDF';

  @override
  String get manglikTitle => 'Manglik (Kuja dosha)';

  @override
  String get manglikNone =>
      'Neither chart carries Kuja dosha, so this parameter does not apply here.';

  @override
  String get manglikBoth =>
      'Both charts carry it, which classically cancels it. This is the commonest resolution, and it is a clean one.';

  @override
  String manglikOne(String name) {
    return '$name’s chart carries Kuja dosha. It describes someone who brings a lot of force into intimacy — a compatibility setting, not a defect, and one that is cancelled more often than not.';
  }

  @override
  String get manglikBadgeNone => 'Does not apply';

  @override
  String get manglikBadgeCancelled => 'Cancelled';

  @override
  String get manglikBadgeOne => 'One chart';

  @override
  String get manglikCancellations => 'Classical ways this is cancelled:';

  @override
  String get howCancelled => 'How it is cancelled';

  @override
  String get manglikFootnote =>
      'PocketAstro will never use Manglik to predict harm to a partner, and will never tell you a marriage will fail.';

  @override
  String get whyThis => 'Why this?';

  @override
  String get hideDetail => 'Hide detail';

  @override
  String confidenceSemantic(String value) {
    return 'Confidence $value out of 75, the highest this method allows';
  }

  @override
  String get legendBenefic => 'Helpful graha';

  @override
  String get legendMalefic => 'Demanding graha';

  @override
  String get legendSupported => 'Supported area';

  @override
  String get legendSteady => 'Steady area';

  @override
  String get legendStrained => 'Area under pressure';

  @override
  String get helpfulHere => 'Helpful here';

  @override
  String get demandingHere => 'Demanding here';
}

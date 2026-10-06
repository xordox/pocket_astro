import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ne.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('ne'),
  ];

  /// PocketAstro
  ///
  /// In en, this message translates to:
  /// **'PocketAstro'**
  String get appTitle;

  /// Compatibility
  ///
  /// In en, this message translates to:
  /// **'Compatibility'**
  String get navCompatibility;

  /// Language
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get navLanguage;

  /// Learn astrology
  ///
  /// In en, this message translates to:
  /// **'Learn astrology'**
  String get navLearn;

  /// Daily reading
  ///
  /// In en, this message translates to:
  /// **'Daily reading'**
  String get navRashifal;

  /// Today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get homeToday;

  /// Your charts
  ///
  /// In en, this message translates to:
  /// **'Your charts'**
  String get homeYourCharts;

  /// Tap a name to read the whole chart.
  ///
  /// In en, this message translates to:
  /// **'Tap a name to read the whole chart.'**
  String get homeYourChartsSub;

  /// Read your day
  ///
  /// In en, this message translates to:
  /// **'Read your day'**
  String get homeReadYourDay;

  /// Learn astrology
  ///
  /// In en, this message translates to:
  /// **'Learn astrology'**
  String get homeLearnCard;

  /// Fifteen lessons, from what a chart is to what it cannot say.
  ///
  /// In en, this message translates to:
  /// **'Fifteen lessons, from what a chart is to what it cannot say.'**
  String get homeLearnCardSub;

  /// {done} of {total} lessons
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} lessons'**
  String homeLearnProgress(String done, String total);

  /// Start learning
  ///
  /// In en, this message translates to:
  /// **'Start learning'**
  String get homeLearnStart;

  /// Daily reading
  ///
  /// In en, this message translates to:
  /// **'Daily reading'**
  String get rashifalTitle;

  /// Where the grahas are today, counted from each moon sign.
  ///
  /// In en, this message translates to:
  /// **'Where the grahas are today, counted from each moon sign.'**
  String get rashifalSub;

  /// Choose your moon sign
  ///
  /// In en, this message translates to:
  /// **'Choose your moon sign'**
  String get rashifalPickSign;

  /// Yours
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get rashifalYours;

  /// Yours · {name}
  ///
  /// In en, this message translates to:
  /// **'Yours · {name}'**
  String rashifalYoursFor(String name);

  /// Moon sign
  ///
  /// In en, this message translates to:
  /// **'Moon sign'**
  String get rashifalMoonSign;

  /// What is moving today
  ///
  /// In en, this message translates to:
  /// **'What is moving today'**
  String get rashifalWhatMoves;

  /// rashifalLineTitle
  ///
  /// In en, this message translates to:
  /// **'{graha} · {house} house'**
  String rashifalLineTitle(String graha, String house);

  /// Obstructed
  ///
  /// In en, this message translates to:
  /// **'Obstructed'**
  String get rashifalObstructed;

  /// Helps
  ///
  /// In en, this message translates to:
  /// **'Helps'**
  String get rashifalHelps;

  /// Presses
  ///
  /// In en, this message translates to:
  /// **'Presses'**
  String get rashifalPresses;

  /// Quiet
  ///
  /// In en, this message translates to:
  /// **'Quiet'**
  String get rashifalQuiet;

  /// Read this against your own chart
  ///
  /// In en, this message translates to:
  /// **'Read this against your own chart'**
  String get rashifalBetterRead;

  /// rashifalBetterReadSub
  ///
  /// In en, this message translates to:
  /// **'Your chart reads the same transits against your birth Moon, your period and your ashtakavarga.'**
  String get rashifalBetterReadSub;

  /// rashifalNoChart
  ///
  /// In en, this message translates to:
  /// **'Not sure of your moon sign? Add a birth chart and the app will work it out.'**
  String get rashifalNoChart;

  /// {tithi} · {nakshatra} · {vara}
  ///
  /// In en, this message translates to:
  /// **'{tithi} · {nakshatra} · {vara}'**
  String panchangaToday(String tithi, String nakshatra, String vara);

  /// storedOnDevice
  ///
  /// In en, this message translates to:
  /// **'Your charts stay on this device. Only birthplace search goes online, and only when you ask.'**
  String get storedOnDevice;

  /// Read a birth chart, offline
  ///
  /// In en, this message translates to:
  /// **'Read a birth chart, offline'**
  String get emptyTitle;

  /// emptyBody
  ///
  /// In en, this message translates to:
  /// **'Add a birth date, time and place. No account needed; your charts never leave this device.'**
  String get emptyBody;

  /// Enter birth details
  ///
  /// In en, this message translates to:
  /// **'Enter birth details'**
  String get enterBirthDetails;

  /// Load demo: 14 Apr 1992, Kathmandu
  ///
  /// In en, this message translates to:
  /// **'Load demo: 14 Apr 1992, Kathmandu'**
  String get loadDemo;

  /// New chart
  ///
  /// In en, this message translates to:
  /// **'New chart'**
  String get newChart;

  /// Edit chart
  ///
  /// In en, this message translates to:
  /// **'Edit chart'**
  String get editChart;

  /// Delete this chart?
  ///
  /// In en, this message translates to:
  /// **'Delete this chart?'**
  String get deleteTitle;

  /// Remove {name} from this device.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from this device.'**
  String deleteBody(String name);

  /// Cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Delete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// time unknown
  ///
  /// In en, this message translates to:
  /// **'time unknown'**
  String get timeUnknownShort;

  /// Not found
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get notFound;

  /// Name
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// Date and time (local at birth)
  ///
  /// In en, this message translates to:
  /// **'Date and time (local at birth)'**
  String get fieldDateTime;

  /// Birth time unknown
  ///
  /// In en, this message translates to:
  /// **'Birth time unknown'**
  String get switchTimeUnknown;

  /// The rising sign and the twelve houses will be withheld rather than guessed. Your Moon r...
  ///
  /// In en, this message translates to:
  /// **'The rising sign and the twelve houses will be withheld rather than guessed. Your Moon reading still works.'**
  String get switchTimeUnknownSub;

  /// Time source
  ///
  /// In en, this message translates to:
  /// **'Time source'**
  String get fieldTimeSource;

  /// Birth place
  ///
  /// In en, this message translates to:
  /// **'Birth place'**
  String get fieldBirthPlace;

  /// Invalid location data. Please enter a valid place name.
  ///
  /// In en, this message translates to:
  /// **'Invalid location data. Please enter a valid place name.'**
  String get invalidLocation;

  /// Type any town or city
  ///
  /// In en, this message translates to:
  /// **'Type any town or city'**
  String get hintTypePlace;

  /// Search online
  ///
  /// In en, this message translates to:
  /// **'Search online'**
  String get searchOnline;

  /// Searching…
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get searchingPlaces;

  /// Type at least three letters, then search.
  ///
  /// In en, this message translates to:
  /// **'Type at least three letters, then search.'**
  String get placeSearchMinChars;

  /// placeLookupOffline
  ///
  /// In en, this message translates to:
  /// **'Could not reach the place search. Saved and built-in places still work.'**
  String get placeLookupOffline;

  /// Try again
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get placeLookupRetry;

  /// Places on this device
  ///
  /// In en, this message translates to:
  /// **'Places on this device'**
  String get sectionOnDevice;

  /// Online results
  ///
  /// In en, this message translates to:
  /// **'Online results'**
  String get sectionOnlineResults;

  /// placeOnlineNote
  ///
  /// In en, this message translates to:
  /// **'Only this search leaves your device. Your chart is never sent anywhere.'**
  String get placeOnlineNote;

  /// Enter coordinates instead
  ///
  /// In en, this message translates to:
  /// **'Enter coordinates instead'**
  String get useCoordinates;

  /// Latitude
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get fieldLatitude;

  /// Longitude
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get fieldLongitude;

  /// Time zone
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get fieldTimezone;

  /// An IANA zone id, such as Asia/Kathmandu
  ///
  /// In en, this message translates to:
  /// **'An IANA zone id, such as Asia/Kathmandu'**
  String get hintTimezone;

  /// invalidCoordinates
  ///
  /// In en, this message translates to:
  /// **'Latitude runs −90 to 90, longitude −180 to 180, and the zone must be a real IANA id.'**
  String get invalidCoordinates;

  /// Use this place
  ///
  /// In en, this message translates to:
  /// **'Use this place'**
  String get useThisPlace;

  /// Selected: {place} ({zone})
  ///
  /// In en, this message translates to:
  /// **'Selected: {place} ({zone})'**
  String selectedPlace(String place, String zone);

  /// Save and read the chart
  ///
  /// In en, this message translates to:
  /// **'Save and read the chart'**
  String get saveAndRead;

  /// Overview
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get tabOverview;

  /// Kundali
  ///
  /// In en, this message translates to:
  /// **'Kundali'**
  String get tabKundali;

  /// Life areas
  ///
  /// In en, this message translates to:
  /// **'Life areas'**
  String get tabLifeAreas;

  /// Timing
  ///
  /// In en, this message translates to:
  /// **'Timing'**
  String get tabTiming;

  /// Ask
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get tabAsk;

  /// Learn
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get tabLearn;

  /// Learn astrology
  ///
  /// In en, this message translates to:
  /// **'Learn astrology'**
  String get learnTitle;

  /// learnSub
  ///
  /// In en, this message translates to:
  /// **'Fifteen lessons from the ground up, each one ending in your own chart.'**
  String get learnSub;

  /// {done} of {total} lessons done
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} lessons done'**
  String learnProgress(String done, String total);

  /// Continue
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get learnContinue;

  /// Start the course
  ///
  /// In en, this message translates to:
  /// **'Start the course'**
  String get learnStart;

  /// Next up
  ///
  /// In en, this message translates to:
  /// **'Next up'**
  String get learnNextUp;

  /// You have been through the whole course.
  ///
  /// In en, this message translates to:
  /// **'You have been through the whole course.'**
  String get learnFinished;

  /// Go back to any lesson at any time. Nothing here expires.
  ///
  /// In en, this message translates to:
  /// **'Go back to any lesson at any time. Nothing here expires.'**
  String get learnFinishedSub;

  /// {done}/{total}
  ///
  /// In en, this message translates to:
  /// **'{done}/{total}'**
  String learnLevelProgress(String done, String total);

  /// {minutes} min read
  ///
  /// In en, this message translates to:
  /// **'{minutes} min read'**
  String learnMinutes(String minutes);

  /// Lesson {number} of {total}
  ///
  /// In en, this message translates to:
  /// **'Lesson {number} of {total}'**
  String learnLessonOf(String number, String total);

  /// In your chart
  ///
  /// In en, this message translates to:
  /// **'In your chart'**
  String get learnInYourChart;

  /// Check yourself
  ///
  /// In en, this message translates to:
  /// **'Check yourself'**
  String get learnCheck;

  /// Show the answer
  ///
  /// In en, this message translates to:
  /// **'Show the answer'**
  String get learnShowAnswer;

  /// Hide the answer
  ///
  /// In en, this message translates to:
  /// **'Hide the answer'**
  String get learnHideAnswer;

  /// Mark as read
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get learnMarkDone;

  /// Read
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get learnMarkNotDone;

  /// Next lesson
  ///
  /// In en, this message translates to:
  /// **'Next lesson'**
  String get learnNextLesson;

  /// Reset progress
  ///
  /// In en, this message translates to:
  /// **'Reset progress'**
  String get learnReset;

  /// Start the course again?
  ///
  /// In en, this message translates to:
  /// **'Start the course again?'**
  String get learnResetTitle;

  /// learnResetBody
  ///
  /// In en, this message translates to:
  /// **'This clears every lesson you have marked as read. The lessons themselves stay where they are.'**
  String get learnResetBody;

  /// The syllabus could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'The syllabus could not be loaded.'**
  String get learnEmpty;

  /// learnFootnote
  ///
  /// In en, this message translates to:
  /// **'A syllabus, not a certification. PocketAstro teaches the classical method and is explicit about where that method stops.'**
  String get learnFootnote;

  /// Today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tabToday;

  /// Reckoned from sunrise at {place}
  ///
  /// In en, this message translates to:
  /// **'Reckoned from sunrise at {place}'**
  String todayReckoned(String place);

  /// Sunrise {sunrise} · Sunset {sunset}
  ///
  /// In en, this message translates to:
  /// **'Sunrise {sunrise} · Sunset {sunset}'**
  String todaySunTimes(String sunrise, String sunset);

  /// todayEstimatedLight
  ///
  /// In en, this message translates to:
  /// **'The Sun does not cross the horizon here on this date, so the day’s windows fall back to a 6am–6pm convention.'**
  String get todayEstimatedLight;

  /// The five limbs
  ///
  /// In en, this message translates to:
  /// **'The five limbs'**
  String get todayPanchanga;

  /// What today is, before it is anything about you.
  ///
  /// In en, this message translates to:
  /// **'What today is, before it is anything about you.'**
  String get todayPanchangaSub;

  /// until {time}
  ///
  /// In en, this message translates to:
  /// **'until {time}'**
  String todayUntil(String time);

  /// until sunrise tomorrow
  ///
  /// In en, this message translates to:
  /// **'until sunrise tomorrow'**
  String get todayAllDay;

  /// Your Moon today
  ///
  /// In en, this message translates to:
  /// **'Your Moon today'**
  String get todayMoonStrength;

  /// Today’s Moon measured against the Moon you were born under.
  ///
  /// In en, this message translates to:
  /// **'Today’s Moon measured against the Moon you were born under.'**
  String get todayMoonStrengthSub;

  /// Tarabala
  ///
  /// In en, this message translates to:
  /// **'Tarabala'**
  String get todayTarabala;

  /// {name} — star {count} of 27
  ///
  /// In en, this message translates to:
  /// **'{name} — star {count} of 27'**
  String todayTarabalaValue(String name, String count);

  /// Chandrabala
  ///
  /// In en, this message translates to:
  /// **'Chandrabala'**
  String get todayChandrabala;

  /// {house} house from your birth Moon
  ///
  /// In en, this message translates to:
  /// **'{house} house from your birth Moon'**
  String todayChandrabalaValue(String house);

  /// Kakshya count
  ///
  /// In en, this message translates to:
  /// **'Kakshya count'**
  String get todayKakshya;

  /// {score} of 7 grahas carry a bindu
  ///
  /// In en, this message translates to:
  /// **'{score} of 7 grahas carry a bindu'**
  String todayKakshyaValue(String score);

  /// todayNoKakshya
  ///
  /// In en, this message translates to:
  /// **'The kakshya count needs a birth time — the ascendant is the eighth contributor to the ashtakavarga.'**
  String get todayNoKakshya;

  /// Lean into
  ///
  /// In en, this message translates to:
  /// **'Lean into'**
  String get todayLeanInto;

  /// What today is classically suited to.
  ///
  /// In en, this message translates to:
  /// **'What today is classically suited to.'**
  String get todayLeanIntoSub;

  /// Hold off on
  ///
  /// In en, this message translates to:
  /// **'Hold off on'**
  String get todayHoldOff;

  /// What today is classically unsuited to. None of it is a prohibition.
  ///
  /// In en, this message translates to:
  /// **'What today is classically unsuited to. None of it is a prohibition.'**
  String get todayHoldOffSub;

  /// Windows in the day
  ///
  /// In en, this message translates to:
  /// **'Windows in the day'**
  String get todayWindows;

  /// Fractions of the daylight, counted from sunrise.
  ///
  /// In en, this message translates to:
  /// **'Fractions of the daylight, counted from sunrise.'**
  String get todayWindowsSub;

  /// on now
  ///
  /// In en, this message translates to:
  /// **'on now'**
  String get todayWindowNow;

  /// Guidance
  ///
  /// In en, this message translates to:
  /// **'Guidance'**
  String get todayGuidance;

  /// Your period today
  ///
  /// In en, this message translates to:
  /// **'Your period today'**
  String get todayPeriodToday;

  /// Carrying today
  ///
  /// In en, this message translates to:
  /// **'Carrying today'**
  String get todayCarrying;

  /// todayFootnote
  ///
  /// In en, this message translates to:
  /// **'Muhurta is the last filter, not the first. Your chart and your running period decide what is possible; the day only decides how it feels.'**
  String get todayFootnote;

  /// How today was graded
  ///
  /// In en, this message translates to:
  /// **'How today was graded'**
  String get todayWorkingOut;

  /// Filters tallied to {score}.
  ///
  /// In en, this message translates to:
  /// **'Filters tallied to {score}.'**
  String todayScoreLine(String score);

  /// Save as PDF
  ///
  /// In en, this message translates to:
  /// **'Save as PDF'**
  String get savePdf;

  /// {sign} rising
  ///
  /// In en, this message translates to:
  /// **'{sign} rising'**
  String risingTitle(String sign);

  /// Moon in {sign}
  ///
  /// In en, this message translates to:
  /// **'Moon in {sign}'**
  String moonTitle(String sign);

  /// Your mind and instincts are read from the Moon.
  ///
  /// In en, this message translates to:
  /// **'Your mind and instincts are read from the Moon.'**
  String get noTimeLead;

  /// Moon in {moon} · Sun in {sun}
  ///
  /// In en, this message translates to:
  /// **'Moon in {moon} · Sun in {sun}'**
  String moonSunLine(String moon, String sun);

  /// Birth star {nakshatra}, pada {pada}
  ///
  /// In en, this message translates to:
  /// **'Birth star {nakshatra}, pada {pada}'**
  String birthStarLine(String nakshatra, String pada);

  /// You are in a {lord} period
  ///
  /// In en, this message translates to:
  /// **'You are in a {lord} period'**
  String periodTitle(String lord);

  /// Currently the {lord} sub-period, to {date}
  ///
  /// In en, this message translates to:
  /// **'Currently the {lord} sub-period, to {date}'**
  String periodSub(String lord, String date);

  /// {start} – {end}
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String periodRange(String start, String end);

  /// {percent}% through · about {years} years left. A period is a chapter, not a sentence.
  ///
  /// In en, this message translates to:
  /// **'{percent}% through · about {years} years left. A period is a chapter, not a sentence.'**
  String periodProgress(String percent, String years);

  /// This period has closed.
  ///
  /// In en, this message translates to:
  /// **'This period has closed.'**
  String get periodClosed;

  /// What this chart supports
  ///
  /// In en, this message translates to:
  /// **'What this chart supports'**
  String get whatSupports;

  /// Where the chart helps, and where it asks for effort.
  ///
  /// In en, this message translates to:
  /// **'Where the chart helps, and where it asks for effort.'**
  String get whatSupportsSub;

  /// Standout patterns
  ///
  /// In en, this message translates to:
  /// **'Standout patterns'**
  String get standoutPatterns;

  /// Combinations the classics single out in your chart.
  ///
  /// In en, this message translates to:
  /// **'Combinations the classics single out in your chart.'**
  String get standoutPatternsSub;

  /// PocketAstro reads your chart offline from 56 classical and modern sources. It is interp...
  ///
  /// In en, this message translates to:
  /// **'PocketAstro reads your chart offline from 56 classical and modern sources. It is interpretive, not medical, legal or financial advice, and it will not predict death or diagnose illness.'**
  String get disclaimerOffline;

  /// No birth time on file, so the rising sign, the twelve houses and everything built on th...
  ///
  /// In en, this message translates to:
  /// **'No birth time on file, so the rising sign, the twelve houses and everything built on them are withheld. The Moon still carries a full reading. Add a time to unlock the rest.'**
  String get noTimeNote;

  /// North Indian
  ///
  /// In en, this message translates to:
  /// **'North Indian'**
  String get northIndian;

  /// South Indian
  ///
  /// In en, this message translates to:
  /// **'South Indian'**
  String get southIndian;

  /// Houses stay in place; the signs move with your rising sign.
  ///
  /// In en, this message translates to:
  /// **'Houses stay in place; the signs move with your rising sign.'**
  String get hintNorth;

  /// Signs stay in place; your rising sign is marked “Asc”.
  ///
  /// In en, this message translates to:
  /// **'Signs stay in place; your rising sign is marked “Asc”.'**
  String get hintSouth;

  /// Show house shading
  ///
  /// In en, this message translates to:
  /// **'Show house shading'**
  String get showShading;

  /// Hide house shading
  ///
  /// In en, this message translates to:
  /// **'Hide house shading'**
  String get hideShading;

  /// Tap a graha to see what it influences
  ///
  /// In en, this message translates to:
  /// **'Tap a graha to see what it influences'**
  String get tapGraha;

  /// Its aspects are drawn onto the houses it reaches.
  ///
  /// In en, this message translates to:
  /// **'Its aspects are drawn onto the houses it reaches.'**
  String get tapGrahaSub;

  /// It influences {count} houses
  ///
  /// In en, this message translates to:
  /// **'It influences {count} houses'**
  String influencesHouses(String count);

  /// Why this colour?
  ///
  /// In en, this message translates to:
  /// **'Why this colour?'**
  String get whyColour;

  /// Exact positions and the Western wheel
  ///
  /// In en, this message translates to:
  /// **'Exact positions and the Western wheel'**
  String get advancedTitle;

  /// Degrees, nakshatras, dignities and aspects
  ///
  /// In en, this message translates to:
  /// **'Degrees, nakshatras, dignities and aspects'**
  String get advancedSub;

  /// Graha
  ///
  /// In en, this message translates to:
  /// **'Graha'**
  String get colGraha;

  /// Sidereal
  ///
  /// In en, this message translates to:
  /// **'Sidereal'**
  String get colSidereal;

  /// House
  ///
  /// In en, this message translates to:
  /// **'House'**
  String get colHouse;

  /// Nakshatra
  ///
  /// In en, this message translates to:
  /// **'Nakshatra'**
  String get colNakshatra;

  /// Dignity
  ///
  /// In en, this message translates to:
  /// **'Dignity'**
  String get colDignity;

  /// Western wheel (tropical)
  ///
  /// In en, this message translates to:
  /// **'Western wheel (tropical)'**
  String get westernWheelTitle;

  /// House {number}
  ///
  /// In en, this message translates to:
  /// **'House {number}'**
  String houseNumber(String number);

  /// Sign
  ///
  /// In en, this message translates to:
  /// **'Sign'**
  String get sheetSign;

  /// Ruled by
  ///
  /// In en, this message translates to:
  /// **'Ruled by'**
  String get sheetRuledBy;

  /// {lord}, sitting in house {house}
  ///
  /// In en, this message translates to:
  /// **'{lord}, sitting in house {house}'**
  String sheetRulerIn(String lord, String house);

  /// Grahas here
  ///
  /// In en, this message translates to:
  /// **'Grahas here'**
  String get sheetGrahasHere;

  /// None — the result runs through its ruler, which is normal
  ///
  /// In en, this message translates to:
  /// **'None — the result runs through its ruler, which is normal'**
  String get sheetNoGrahas;

  /// Influenced by
  ///
  /// In en, this message translates to:
  /// **'Influenced by'**
  String get sheetInfluencedBy;

  /// Point count
  ///
  /// In en, this message translates to:
  /// **'Point count'**
  String get sheetPointCount;

  /// {count} of 56, against an average of 28
  ///
  /// In en, this message translates to:
  /// **'{count} of 56, against an average of 28'**
  String sheetPointValue(String count);

  /// Classical topics
  ///
  /// In en, this message translates to:
  /// **'Classical topics'**
  String get sheetTopics;

  /// What helps here
  ///
  /// In en, this message translates to:
  /// **'What helps here'**
  String get whatHelps;

  /// What presses on it
  ///
  /// In en, this message translates to:
  /// **'What presses on it'**
  String get whatPresses;

  /// A house reading is a guide to where the chart helps, not a prediction. Pressure has a c...
  ///
  /// In en, this message translates to:
  /// **'A house reading is a guide to where the chart helps, not a prediction. Pressure has a cause and a remedy; it is never a verdict on how your life turns out.'**
  String get houseSheetNote;

  /// The twelve areas of your life
  ///
  /// In en, this message translates to:
  /// **'The twelve areas of your life'**
  String get twelveAreas;

  /// Tap any one to see exactly what shapes it.
  ///
  /// In en, this message translates to:
  /// **'Tap any one to see exactly what shapes it.'**
  String get twelveAreasSub;

  /// Readings in full
  ///
  /// In en, this message translates to:
  /// **'Readings in full'**
  String get readingsInFull;

  /// The same chart, in the classical language.
  ///
  /// In en, this message translates to:
  /// **'The same chart, in the classical language.'**
  String get readingsInFullSub;

  /// The twelve houses need a birth time. Without one, PocketAstro withholds them rather tha...
  ///
  /// In en, this message translates to:
  /// **'The twelve houses need a birth time. Without one, PocketAstro withholds them rather than showing something that looks precise and is not.'**
  String get lifeNoTimeNote;

  /// Your life in periods
  ///
  /// In en, this message translates to:
  /// **'Your life in periods'**
  String get lifeInPeriods;

  /// The Vimshottari cycle, measured from your Moon.
  ///
  /// In en, this message translates to:
  /// **'The Vimshottari cycle, measured from your Moon.'**
  String get lifeInPeriodsSub;

  /// Inside the {lord} period
  ///
  /// In en, this message translates to:
  /// **'Inside the {lord} period'**
  String insidePeriod(String lord);

  /// Sub-periods narrow a chapter to a few months.
  ///
  /// In en, this message translates to:
  /// **'Sub-periods narrow a chapter to a few months.'**
  String get insidePeriodSub;

  /// What the next two years look like
  ///
  /// In en, this message translates to:
  /// **'What the next two years look like'**
  String get nextTwoYears;

  /// Windows where two techniques agree.
  ///
  /// In en, this message translates to:
  /// **'Windows where two techniques agree.'**
  String get nextTwoYearsSub;

  /// Nothing stands out. That is a normal result.
  ///
  /// In en, this message translates to:
  /// **'Nothing stands out. That is a normal result.'**
  String get nextTwoYearsNone;

  /// No standout window in the next twenty-four months. This does not mean nothing happens —...
  ///
  /// In en, this message translates to:
  /// **'No standout window in the next twenty-four months. This does not mean nothing happens — it means no two techniques line up strongly enough for PocketAstro to call one.'**
  String get noWindowNote;

  /// Where things stand now
  ///
  /// In en, this message translates to:
  /// **'Where things stand now'**
  String get whereThingsStand;

  /// now
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get nowLabel;

  /// Confidence {value} of a possible 75.
  ///
  /// In en, this message translates to:
  /// **'Confidence {value} of a possible 75.'**
  String confidenceFootnote(String value);

  /// Ask anything about this chart…
  ///
  /// In en, this message translates to:
  /// **'Ask anything about this chart…'**
  String get askHint;

  /// Ask
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get askAction;

  /// Reading your chart
  ///
  /// In en, this message translates to:
  /// **'Reading your chart'**
  String get readingYourChart;

  /// How this was worked out ({count} steps)
  ///
  /// In en, this message translates to:
  /// **'How this was worked out ({count} steps)'**
  String howWorkedOut(String count);

  /// Hide the steps
  ///
  /// In en, this message translates to:
  /// **'Hide the steps'**
  String get hideSteps;

  /// Read the full answer
  ///
  /// In en, this message translates to:
  /// **'Read the full answer'**
  String get readFullAnswer;

  /// Ask in your own words, or tap one of the suggestions above. You will see each step of t...
  ///
  /// In en, this message translates to:
  /// **'Ask in your own words, or tap one of the suggestions above. You will see each step of the reading as it happens, and which of the source books each rule came from.'**
  String get askEmptyNote;

  /// Two techniques must agree before anything is called likely. This method never claims mo...
  ///
  /// In en, this message translates to:
  /// **'Two techniques must agree before anything is called likely. This method never claims more than 75 out of 100.'**
  String get askFootnote;

  /// Two charts needed
  ///
  /// In en, this message translates to:
  /// **'Two charts needed'**
  String get twoChartsNeeded;

  /// twoChartsNeededSub
  ///
  /// In en, this message translates to:
  /// **'Add both people right here, or pick from charts you have already saved.'**
  String get twoChartsNeededSub;

  /// First person
  ///
  /// In en, this message translates to:
  /// **'First person'**
  String get firstPerson;

  /// Second person
  ///
  /// In en, this message translates to:
  /// **'Second person'**
  String get secondPerson;

  /// Choose
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get choosePerson;

  /// Add a new chart
  ///
  /// In en, this message translates to:
  /// **'Add a new chart'**
  String get matchAddNew;

  /// Choose a saved chart
  ///
  /// In en, this message translates to:
  /// **'Choose a saved chart'**
  String get matchChooseSaved;

  /// No charts saved yet.
  ///
  /// In en, this message translates to:
  /// **'No charts saved yet.'**
  String get matchNoSaved;

  /// Anyone you add here is saved to your charts too.
  ///
  /// In en, this message translates to:
  /// **'Anyone you add here is saved to your charts too.'**
  String get matchSavedNote;

  /// Remove
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get matchClear;

  /// Save and compare
  ///
  /// In en, this message translates to:
  /// **'Save and compare'**
  String get saveAndCompare;

  /// Swap
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get swap;

  /// Pick two different people to compare. Everything is computed on this device.
  ///
  /// In en, this message translates to:
  /// **'Pick two different people to compare. Everything is computed on this device.'**
  String get pickTwoNote;

  /// of {max}
  ///
  /// In en, this message translates to:
  /// **'of {max}'**
  String outOfMax(String max);

  /// Traditionally {band}
  ///
  /// In en, this message translates to:
  /// **'Traditionally {band}'**
  String traditionallyBand(String band);

  /// {first} and {second}
  ///
  /// In en, this message translates to:
  /// **'{first} and {second}'**
  String pairTitle(String first, String second);

  /// The eight parameters
  ///
  /// In en, this message translates to:
  /// **'The eight parameters'**
  String get eightParameters;

  /// What each one weighs, and how these two scored.
  ///
  /// In en, this message translates to:
  /// **'What each one weighs, and how these two scored.'**
  String get eightParametersSub;

  /// What the chart said
  ///
  /// In en, this message translates to:
  /// **'What the chart said'**
  String get whatChartSaid;

  /// Beyond the score
  ///
  /// In en, this message translates to:
  /// **'Beyond the score'**
  String get beyondScore;

  /// What the two whole charts say about each other.
  ///
  /// In en, this message translates to:
  /// **'What the two whole charts say about each other.'**
  String get beyondScoreSub;

  /// A score describes classical parameters, not two people. A living, consensual relationsh...
  ///
  /// In en, this message translates to:
  /// **'A score describes classical parameters, not two people. A living, consensual relationship outranks any number on this screen, and PocketAstro will never tell you to leave someone or predict harm to a partner.'**
  String get matchNote;

  /// Save this comparison as a PDF
  ///
  /// In en, this message translates to:
  /// **'Save this comparison as a PDF'**
  String get saveComparison;

  /// Manglik (Kuja dosha)
  ///
  /// In en, this message translates to:
  /// **'Manglik (Kuja dosha)'**
  String get manglikTitle;

  /// Neither chart carries Kuja dosha, so this parameter does not apply here.
  ///
  /// In en, this message translates to:
  /// **'Neither chart carries Kuja dosha, so this parameter does not apply here.'**
  String get manglikNone;

  /// Both charts carry it, which classically cancels it. This is the commonest resolution, a...
  ///
  /// In en, this message translates to:
  /// **'Both charts carry it, which classically cancels it. This is the commonest resolution, and it is a clean one.'**
  String get manglikBoth;

  /// {name}’s chart carries Kuja dosha. It describes someone who brings a lot of force into ...
  ///
  /// In en, this message translates to:
  /// **'{name}’s chart carries Kuja dosha. It describes someone who brings a lot of force into intimacy — a compatibility setting, not a defect, and one that is cancelled more often than not.'**
  String manglikOne(String name);

  /// Does not apply
  ///
  /// In en, this message translates to:
  /// **'Does not apply'**
  String get manglikBadgeNone;

  /// Cancelled
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get manglikBadgeCancelled;

  /// One chart
  ///
  /// In en, this message translates to:
  /// **'One chart'**
  String get manglikBadgeOne;

  /// Classical ways this is cancelled:
  ///
  /// In en, this message translates to:
  /// **'Classical ways this is cancelled:'**
  String get manglikCancellations;

  /// How it is cancelled
  ///
  /// In en, this message translates to:
  /// **'How it is cancelled'**
  String get howCancelled;

  /// PocketAstro will never use Manglik to predict harm to a partner, and will never tell yo...
  ///
  /// In en, this message translates to:
  /// **'PocketAstro will never use Manglik to predict harm to a partner, and will never tell you a marriage will fail.'**
  String get manglikFootnote;

  /// Why this?
  ///
  /// In en, this message translates to:
  /// **'Why this?'**
  String get whyThis;

  /// Hide detail
  ///
  /// In en, this message translates to:
  /// **'Hide detail'**
  String get hideDetail;

  /// Confidence {value} out of 75, the highest this method allows
  ///
  /// In en, this message translates to:
  /// **'Confidence {value} out of 75, the highest this method allows'**
  String confidenceSemantic(String value);

  /// Helpful graha
  ///
  /// In en, this message translates to:
  /// **'Helpful graha'**
  String get legendBenefic;

  /// Demanding graha
  ///
  /// In en, this message translates to:
  /// **'Demanding graha'**
  String get legendMalefic;

  /// Supported area
  ///
  /// In en, this message translates to:
  /// **'Supported area'**
  String get legendSupported;

  /// Steady area
  ///
  /// In en, this message translates to:
  /// **'Steady area'**
  String get legendSteady;

  /// Area under pressure
  ///
  /// In en, this message translates to:
  /// **'Area under pressure'**
  String get legendStrained;

  /// Helpful here
  ///
  /// In en, this message translates to:
  /// **'Helpful here'**
  String get helpfulHere;

  /// Demanding here
  ///
  /// In en, this message translates to:
  /// **'Demanding here'**
  String get demandingHere;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'ne'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return LEn();
    case 'hi':
      return LHi();
    case 'ne':
      return LNe();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

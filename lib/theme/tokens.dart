/// PocketAstro design tokens.
///
/// One rule governs this file: a colour means the same thing everywhere in the
/// app. Green is never "brand green" in one place and "benefic" in another.
/// Every semantic colour below is paired with an `on*` foreground that meets
/// WCAG AA at body sizes, and with a text label, because colour alone is not
/// an accessible encoding.
library;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Base palette
// ---------------------------------------------------------------------------

const ink = Color(0xFF1C1917);
const inkSoft = Color(0xFF57534E);
const inkFaint = Color(0xFF8A827C);
const paper = Color(0xFFFAF9F7);
const paperRaised = Color(0xFFFFFFFF);
const hairline = Color(0xFFE7E2DC);

const navy = Color(0xFF1E3A5F);
const rust = Color(0xFF8C3A1B);
const gold = Color(0xFFB8934F);

// ---------------------------------------------------------------------------
// Semantic: the nature of a graha
// ---------------------------------------------------------------------------

/// Natural benefic — Jupiter, Venus, an unafflicted Mercury, a Moon with
/// paksha bala.
const beneficColor = Color(0xFF1B6B4A);
const beneficTint = Color(0xFFE4F1EA);
const onBenefic = Color(0xFFFFFFFF);

/// Natural malefic — Saturn, Mars, the Sun, the nodes, a waning Moon.
const maleficColor = Color(0xFFA32F1E);
const maleficTint = Color(0xFFFBE8E4);
const onMalefic = Color(0xFFFFFFFF);

/// Shadow grahas and anything the engine will not classify.
const neutralColor = Color(0xFF5B6673);
const neutralTint = Color(0xFFECEEF1);
const onNeutral = Color(0xFFFFFFFF);

// ---------------------------------------------------------------------------
// Semantic: the quality of a bhava
// ---------------------------------------------------------------------------

/// A house the chart supports: the payout is structurally available.
const prosperousColor = Color(0xFF14724F);
const prosperousTint = Color(0xFFE8F4EE);

/// A house that works, with effort or unevenly.
const steadyColor = Color(0xFF6B7280);
const steadyTint = Color(0xFFF2F3F5);

/// A house under pressure. Never "bad" — pressure has a cause and a remedy.
const strainedColor = Color(0xFFB4541F);
const strainedTint = Color(0xFFFDEEE3);

// ---------------------------------------------------------------------------
// Semantic: a forecast verdict
// ---------------------------------------------------------------------------

const verdictLikely = Color(0xFF14724F);
const verdictPossible = Color(0xFF1E3A5F);
const verdictCaution = Color(0xFFB4541F);
const verdictQuiet = Color(0xFF6B7280);

// ---------------------------------------------------------------------------
// Graha identity colours, for the wheel, the timeline and the legend
// ---------------------------------------------------------------------------

const grahaColors = <String, Color>{
  'Sun': Color(0xFFC2410C),
  'Moon': Color(0xFF64748B),
  'Mars': Color(0xFFB91C1C),
  'Mercury': Color(0xFF047857),
  'Jupiter': Color(0xFFB45309),
  'Venus': Color(0xFFBE185D),
  'Saturn': Color(0xFF334155),
  'Rahu': Color(0xFF6B7280),
  'Ketu': Color(0xFF78350F),
  'Lagna': Color(0xFF1E3A5F),
  'Uranus': Color(0xFF0E7490),
  'Neptune': Color(0xFF4F46E5),
  'Pluto': Color(0xFF7C2D12),
};

Color grahaColor(String name) => grahaColors[name] ?? neutralColor;

/// Two-letter labels, the convention every printed kundali uses.
const grahaShort = <String, String>{
  'Lagna': 'As',
  'Sun': 'Su',
  'Moon': 'Mo',
  'Mars': 'Ma',
  'Mercury': 'Me',
  'Jupiter': 'Ju',
  'Venus': 'Ve',
  'Saturn': 'Sa',
  'Rahu': 'Ra',
  'Ketu': 'Ke',
  'Uranus': 'Ur',
  'Neptune': 'Ne',
  'Pluto': 'Pl',
};

String shortName(String name) =>
    grahaShort[name] ?? (name.length > 2 ? name.substring(0, 2) : name);

// ---------------------------------------------------------------------------
// Spacing and shape
// ---------------------------------------------------------------------------

abstract final class Gap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class Radii {
  static const card = 16.0;
  static const chip = 10.0;
  static const sheet = 24.0;
}

// ---------------------------------------------------------------------------
// Type scale
// ---------------------------------------------------------------------------

abstract final class Type {
  /// A screen or section headline. One per view.
  static const display = TextStyle(
    fontSize: 26, fontWeight: FontWeight.w700, height: 1.2, color: ink,
  );

  /// A card title.
  static const title = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w700, height: 1.3, color: ink,
  );

  /// The one-line plain-language answer. This is the most-read style in the
  /// app, so it is set larger than body.
  static const lead = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w500, height: 1.45, color: ink,
  );

  static const body = TextStyle(fontSize: 14.5, height: 1.5, color: ink);

  static const bodySoft = TextStyle(fontSize: 14, height: 1.5, color: inkSoft);

  /// Labels, metadata, source notes.
  static const caption = TextStyle(fontSize: 12, height: 1.4, color: inkSoft);

  static const micro = TextStyle(
    fontSize: 11, height: 1.3, color: inkFaint, letterSpacing: 0.2,
  );

  /// Numbers in a chart cell.
  static const glyph = TextStyle(
    fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.1,
  );
}

ThemeData pocketTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: navy,
    brightness: Brightness.light,
    primary: navy,
    secondary: rust,
    surface: paper,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: paper,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w700, color: ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: paperRaised,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: const BorderSide(color: hairline),
      ),
    ),
    dividerTheme: const DividerThemeData(color: hairline, space: 1, thickness: 1),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: navy,
      foregroundColor: Colors.white,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: paperRaised,
      selectedColor: navy.withValues(alpha: 0.10),
      side: const BorderSide(color: hairline),
      labelStyle: Type.caption.copyWith(color: ink),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(Type.caption.copyWith(color: ink)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      titleTextStyle: Type.body,
      subtitleTextStyle: Type.caption,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: paperRaised,
      hintStyle: Type.bodySoft,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        borderSide: const BorderSide(color: hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        borderSide: const BorderSide(color: hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        borderSide: const BorderSide(color: navy, width: 1.6),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: navy,
      unselectedLabelColor: inkSoft,
      indicatorColor: navy,
      dividerColor: hairline,
      labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      unselectedLabelStyle:
          const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
    ),
  );
}

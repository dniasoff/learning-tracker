import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AppTextStyles provides typography styles for Hebrew and English content.
///
/// Key principles:
/// - Hebrew text uses RTL text direction
/// - English text uses LTR text direction
/// - Font sizes optimized for readability
/// - Supports bidirectional content
///
/// The English/base getters below are built on [GoogleFonts.plusJakartaSans]
/// — the same family [AppTheme.themeFor]'s real Material typography
/// (`AppTheme._buildTextTheme`) uses — so this table can no longer drift from
/// the app's actual themed font (AUD-core-theme-01: it previously hardcoded
/// the literal 'Roboto', a font this app never bundles).
class AppTextStyles {
  AppTextStyles._();

  // Base font families
  // 'Noto Sans Hebrew' ships as a bundled asset: all 5 weights are declared
  // under pubspec.yaml's `flutter: fonts:` section and their TTF files live
  // in assets/fonts/, so the family is available at runtime on every
  // platform (no system-fallback gap).
  static const String hebrewFontFamily = 'Noto Sans Hebrew';

  /// Headline styles (for page titles, section headers)
  static TextStyle get headlineLarge => GoogleFonts.plusJakartaSans(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  static TextStyle get headlineMedium => GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    height: 1.3,
  );

  static TextStyle get headlineSmall => GoogleFonts.plusJakartaSans(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  /// Title styles (for cards, list items)
  static TextStyle get titleLarge => GoogleFonts.plusJakartaSans(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static TextStyle get titleMedium => GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static TextStyle get titleSmall => GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  /// Body styles (for main content)
  static TextStyle get bodyLarge => GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  static TextStyle get bodyMedium => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  static TextStyle get bodySmall => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  /// Label styles (for buttons, form labels)
  static TextStyle get labelLarge => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static TextStyle get labelMedium => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static TextStyle get labelSmall => GoogleFonts.plusJakartaSans(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// Hebrew text styles - same sizes but with Hebrew font and RTL direction
  static TextStyle get hebrewHeadlineLarge =>
      headlineLarge.copyWith(fontFamily: hebrewFontFamily);

  static TextStyle get hebrewHeadlineMedium =>
      headlineMedium.copyWith(fontFamily: hebrewFontFamily);

  static TextStyle get hebrewHeadlineSmall =>
      headlineSmall.copyWith(fontFamily: hebrewFontFamily);

  static TextStyle get hebrewTitleLarge =>
      titleLarge.copyWith(fontFamily: hebrewFontFamily);

  static TextStyle get hebrewTitleMedium =>
      titleMedium.copyWith(fontFamily: hebrewFontFamily);

  static TextStyle get hebrewTitleSmall =>
      titleSmall.copyWith(fontFamily: hebrewFontFamily);

  static TextStyle get hebrewBodyLarge => bodyLarge.copyWith(
    fontFamily: hebrewFontFamily,
    fontSize: 18, // Slightly larger for Hebrew readability
    height: 1.6,
  );

  static TextStyle get hebrewBodyMedium => bodyMedium.copyWith(
    fontFamily: hebrewFontFamily,
    fontSize: 16, // Slightly larger for Hebrew readability
    height: 1.6,
  );

  static TextStyle get hebrewBodySmall => bodySmall.copyWith(
    fontFamily: hebrewFontFamily,
    fontSize: 14, // Slightly larger for Hebrew readability
    height: 1.6,
  );
}

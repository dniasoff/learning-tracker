import 'package:flutter/material.dart';

/// AppTextStyles provides typography styles for Hebrew and English content.
///
/// Key principles:
/// - Hebrew text uses RTL text direction
/// - English text uses LTR text direction
/// - Font sizes optimized for readability
/// - Supports bidirectional content
class AppTextStyles {
  AppTextStyles._();

  // Base font families
  static const String _hebrewFontFamily = 'Roboto'; // System default for now
  static const String _englishFontFamily = 'Roboto';

  /// Headline styles (for page titles, section headers)
  static TextStyle get headlineLarge => const TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
    fontFamily: _englishFontFamily,
  );

  static TextStyle get headlineMedium => const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    height: 1.3,
    fontFamily: _englishFontFamily,
  );

  static TextStyle get headlineSmall => const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.4,
    fontFamily: _englishFontFamily,
  );

  /// Title styles (for cards, list items)
  static TextStyle get titleLarge => const TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.3,
    fontFamily: _englishFontFamily,
  );

  static TextStyle get titleMedium => const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    fontFamily: _englishFontFamily,
  );

  static TextStyle get titleSmall => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    fontFamily: _englishFontFamily,
  );

  /// Body styles (for main content)
  static TextStyle get bodyLarge => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.5,
    fontFamily: _englishFontFamily,
  );

  static TextStyle get bodyMedium => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
    fontFamily: _englishFontFamily,
  );

  static TextStyle get bodySmall => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.5,
    fontFamily: _englishFontFamily,
  );

  /// Label styles (for buttons, form labels)
  static TextStyle get labelLarge => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    fontFamily: _englishFontFamily,
  );

  static TextStyle get labelMedium => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    fontFamily: _englishFontFamily,
  );

  static TextStyle get labelSmall => const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    fontFamily: _englishFontFamily,
  );

  /// Hebrew text styles - same sizes but with Hebrew font and RTL direction
  static TextStyle get hebrewHeadlineLarge =>
      headlineLarge.copyWith(fontFamily: _hebrewFontFamily);

  static TextStyle get hebrewHeadlineMedium =>
      headlineMedium.copyWith(fontFamily: _hebrewFontFamily);

  static TextStyle get hebrewHeadlineSmall =>
      headlineSmall.copyWith(fontFamily: _hebrewFontFamily);

  static TextStyle get hebrewTitleLarge =>
      titleLarge.copyWith(fontFamily: _hebrewFontFamily);

  static TextStyle get hebrewTitleMedium =>
      titleMedium.copyWith(fontFamily: _hebrewFontFamily);

  static TextStyle get hebrewTitleSmall =>
      titleSmall.copyWith(fontFamily: _hebrewFontFamily);

  static TextStyle get hebrewBodyLarge => bodyLarge.copyWith(
    fontFamily: _hebrewFontFamily,
    fontSize: 18, // Slightly larger for Hebrew readability
    height: 1.6,
  );

  static TextStyle get hebrewBodyMedium => bodyMedium.copyWith(
    fontFamily: _hebrewFontFamily,
    fontSize: 16, // Slightly larger for Hebrew readability
    height: 1.6,
  );

  static TextStyle get hebrewBodySmall => bodySmall.copyWith(
    fontFamily: _hebrewFontFamily,
    fontSize: 14, // Slightly larger for Hebrew readability
    height: 1.6,
  );

  /// Helper method to get text direction for content
  static TextDirection getTextDirection(String text) {
    if (text.isEmpty) return TextDirection.ltr;

    // Check if text contains Hebrew characters
    final hebrewPattern = RegExp(r'[\u0590-\u05FF]');
    return hebrewPattern.hasMatch(text) ? TextDirection.rtl : TextDirection.ltr;
  }

  /// Helper method to get appropriate text style based on content language
  static TextStyle getStyleForContent(String text, TextStyle baseStyle) {
    final isHebrew = getTextDirection(text) == TextDirection.rtl;
    if (isHebrew) {
      return baseStyle.copyWith(
        fontFamily: _hebrewFontFamily,
        fontSize: (baseStyle.fontSize ?? 14) + 2, // Slightly larger
      );
    }
    return baseStyle;
  }
}

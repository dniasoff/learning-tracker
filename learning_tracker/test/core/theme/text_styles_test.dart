// Tests for AppTextStyles — covers Hebrew text style getters (lines 112-139)
// and helper methods (lines 146-164).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/text_styles.dart';

void main() {
  // =========================================================================
  // Hebrew text style getters
  // =========================================================================

  group('AppTextStyles Hebrew getters', () {
    test('hebrewHeadlineMedium uses Hebrew font family', () {
      final style = AppTextStyles.hebrewHeadlineMedium;
      expect(style.fontFamily, AppTextStyles.hebrewFontFamily);
    });

    test('hebrewHeadlineSmall uses Hebrew font family', () {
      final style = AppTextStyles.hebrewHeadlineSmall;
      expect(style.fontFamily, AppTextStyles.hebrewFontFamily);
    });

    test('hebrewTitleLarge uses Hebrew font family', () {
      final style = AppTextStyles.hebrewTitleLarge;
      expect(style.fontFamily, AppTextStyles.hebrewFontFamily);
    });

    test('hebrewTitleMedium uses Hebrew font family', () {
      final style = AppTextStyles.hebrewTitleMedium;
      expect(style.fontFamily, AppTextStyles.hebrewFontFamily);
    });

    test('hebrewTitleSmall uses Hebrew font family', () {
      final style = AppTextStyles.hebrewTitleSmall;
      expect(style.fontFamily, AppTextStyles.hebrewFontFamily);
    });

    test('hebrewBodyMedium uses Hebrew font family and larger fontSize', () {
      final style = AppTextStyles.hebrewBodyMedium;
      expect(style.fontFamily, AppTextStyles.hebrewFontFamily);
      expect(style.fontSize, greaterThan(AppTextStyles.bodyMedium.fontSize!));
    });

    test('hebrewBodySmall uses Hebrew font family and larger fontSize', () {
      final style = AppTextStyles.hebrewBodySmall;
      expect(style.fontFamily, AppTextStyles.hebrewFontFamily);
      expect(style.fontSize, greaterThan(AppTextStyles.bodySmall.fontSize!));
    });
  });

  // =========================================================================
  // getTextDirection
  // =========================================================================

  group('AppTextStyles.getTextDirection', () {
    test('returns ltr for empty string', () {
      expect(AppTextStyles.getTextDirection(''), TextDirection.ltr);
    });

    test('returns ltr for English text', () {
      expect(AppTextStyles.getTextDirection('Hello'), TextDirection.ltr);
    });

    test('returns rtl for Hebrew text', () {
      expect(AppTextStyles.getTextDirection('שלום'), TextDirection.rtl);
    });

    test('returns rtl for mixed English+Hebrew text', () {
      expect(AppTextStyles.getTextDirection('Hello שלום'), TextDirection.rtl);
    });
  });

  // =========================================================================
  // getStyleForContent
  // =========================================================================

  group('AppTextStyles.getStyleForContent', () {
    const baseStyle = TextStyle(fontSize: 14, fontFamily: 'Roboto');

    test('returns base style unchanged for English text', () {
      final style = AppTextStyles.getStyleForContent('Hello', baseStyle);
      expect(style.fontFamily, 'Roboto');
      expect(style.fontSize, 14);
    });

    test('returns Hebrew style for Hebrew text', () {
      final style = AppTextStyles.getStyleForContent('שלום', baseStyle);
      expect(style.fontFamily, AppTextStyles.hebrewFontFamily);
      expect(style.fontSize, 16); // 14 + 2
    });
  });
}

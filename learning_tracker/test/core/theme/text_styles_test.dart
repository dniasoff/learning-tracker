// Tests for AppTextStyles — covers Hebrew text style getters.
//
// AUD-core-theme-01: getTextDirection/getStyleForContent were removed as
// dead code (zero callers anywhere outside this file and the Story 25.20
// acceptance test — see AC2), so their test groups were removed with them
// per that finding's acceptance criteria.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/theme/text_styles.dart';

void main() {
  // AppTextStyles' English getters build on GoogleFonts.plusJakartaSans
  // (AUD-core-theme-01), which checks the asset bundle via
  // ServicesBinding.instance as a side effect — needs a binding even though
  // these are otherwise-plain (non-widget-pumping) unit tests.
  TestWidgetsFlutterBinding.ensureInitialized();

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
}

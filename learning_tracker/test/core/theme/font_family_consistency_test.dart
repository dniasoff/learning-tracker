// Regression test for AUD-core-theme-01.
//
// AppTheme's real Material typography (AppTheme._buildTextTheme) is built on
// GoogleFonts Plus Jakarta Sans, but AppTextStyles — a second, parallel
// static typography table consumed directly by
// text_display_screen.dart (6 call sites) and hebrew_text.dart — hardcoded
// its English family to the literal 'Roboto', a font this app never bundles
// (only "Noto Sans Hebrew" is declared under pubspec's `flutter: fonts:`).
// That meant text_display_screen.dart visibly rendered in a different
// typeface family than the rest of the themed app.
//
// AC1: "text_display_screen.dart and hebrew_text.dart render with the same
// font family as the rest of the themed app (Plus Jakarta Sans), verified by
// a widget test reading the resolved TextStyle.fontFamily."
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/theme/text_styles.dart';
import 'package:learning_tracker/core/widgets/hebrew_text.dart';

void main() {
  group('AUD-core-theme-01 — AppTextStyles/HebrewText font-family drift', () {
    testWidgets('AppTextStyles.bodyLarge (text_display_screen.dart call site) '
        'resolves to Plus Jakarta Sans, not Roboto', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(),
          home: Scaffold(
            body: Text('Bereishit bara Elohim', style: AppTextStyles.bodyLarge),
          ),
        ),
      );

      final rendered = tester.widget<Text>(find.text('Bereishit bara Elohim'));
      final resolvedFamily = rendered.style!.fontFamily;

      // The literal regression this finding describes: AppTextStyles used
      // to hardcode 'Roboto' — a font not bundled anywhere in this app.
      expect(resolvedFamily, isNot('Roboto'));

      // Must match the family the theme's own Plus Jakarta Sans typography
      // resolves to for the same weight/style variant (GoogleFonts encodes
      // the specific weight into the resolved family string).
      final expectedFamily = GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.normal,
      ).fontFamily;
      expect(resolvedFamily, expectedFamily);
      expect(resolvedFamily, startsWith('PlusJakartaSans'));
    });

    testWidgets(
      'AppTextStyles.titleMedium (text_display_screen.dart call site) '
      'resolves to Plus Jakarta Sans, not Roboto',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(),
            home: Scaffold(
              body: Text('Text unavailable', style: AppTextStyles.titleMedium),
            ),
          ),
        );

        final rendered = tester.widget<Text>(find.text('Text unavailable'));
        final resolvedFamily = rendered.style!.fontFamily;

        expect(resolvedFamily, isNot('Roboto'));
        expect(resolvedFamily, startsWith('PlusJakartaSans'));
      },
    );

    testWidgets(
      'HebrewText with no explicit style keeps the ambient themed font '
      '(Plus Jakarta Sans) as its primary family, adding the Hebrew font '
      'only as a glyph-coverage fallback — not an outright override',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const Scaffold(body: HebrewText('שלום')),
          ),
        );

        final rendered = tester.widget<Text>(find.text('שלום'));
        final resolvedFamily = rendered.style!.fontFamily;

        // Previously this overrode fontFamily outright to 'Noto Sans Hebrew',
        // discarding the ambient theme's Plus Jakarta Sans entirely.
        expect(resolvedFamily, isNot(AppTextStyles.hebrewFontFamily));
        expect(resolvedFamily, startsWith('PlusJakartaSans'));

        // Hebrew glyph coverage is preserved via the fallback chain, not by
        // replacing the primary family.
        expect(
          rendered.style!.fontFamilyFallback,
          contains(AppTextStyles.hebrewFontFamily),
        );
      },
    );
  });
}

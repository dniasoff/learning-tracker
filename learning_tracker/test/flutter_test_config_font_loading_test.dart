/// Regression test for AUD-t-cross-51 (TQ-5).
///
/// `flutter_test_config.dart` runs before every test file but historically
/// never loaded a real font — it only disabled `google_fonts` runtime
/// fetching (`GoogleFonts.config.allowRuntimeFetching = false`). Without a
/// loaded typeface, `flutter test`'s software renderer paints text as
/// either nothing at all (blank) or an opaque fallback "tofu" glyph box,
/// making every `goldenTest()` / `matchesGoldenFile()` assertion in the
/// suite compare meaningless pixels — which is exactly why all 10 current
/// `goldenTest()` call sites under `test/story_acceptance/` passed
/// `skipGolden: true` before this fix.
///
/// This uses `goldenTest()` itself (the helper this finding is about) with
/// `skipGolden: false` and real text content — the same probe shape used
/// in the audit's own evidence (`goldenTest('probe', builder: (l) =>
/// const Text('Probe'))`, run with `--update-goldens` and eyeballed). It
/// deliberately does NOT call `loadFonts()`/`loadHebrewFont()` itself —
/// the whole point is to exercise ONLY the global font-loading step in
/// `flutter_test_config.dart` (TQ-5: "fonts loaded in
/// `flutter_test_config.dart`"), which every test file in the suite gets
/// for free. If that global step ever regresses (e.g. someone deletes the
/// `loadFonts()`/`loadHebrewFont()` calls added for this finding), this
/// golden comparison fails because the checked-in baseline PNGs have
/// legible glyphs and the regressed render would be blank/tofu again.
///
/// Covers both locale variants goldenTest() always produces: the `en`
/// glyphs exercise [golden_font_loader.loadFonts]'s Roboto, and the `he`
/// glyphs exercise [golden_font_loader.loadHebrewFont]'s Noto Sans Hebrew
/// — the only family declared under pubspec's `flutter: fonts:` section.
///
/// Both baseline PNGs were captured with `--update-goldens` and eyeballed
/// (see AUD-t-cross-51's `evidence`/`why` fields for the failure modes
/// being guarded against) to confirm they show real, legible text rather
/// than a blank canvas or a solid tofu smear.
@Tags(['golden_infra'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/golden_runner.dart';

void main() {
  goldenTest(
    'font_loading_probe',
    builder: (locale) {
      final isHebrew = locale.languageCode == 'he';
      return Center(
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              // Real, locale-appropriate text content (not a placeholder
              // glyph) — Hebrew glyphs specifically require Noto Sans
              // Hebrew; Latin glyphs specifically require Roboto. Neither
              // family renders legibly under `--use-test-fonts` unless
              // explicitly loaded AND explicitly referenced via
              // `fontFamily` (Flutter's test harness substitutes any
              // unmatched family with the built-in block-glyph "Ahem"
              // test font).
              isHebrew ? 'בדיקה' : 'Probe',
              style: TextStyle(
                color: const Color(0xFF000000),
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFamily: isHebrew ? 'Noto Sans Hebrew' : 'Roboto',
              ),
            ),
          ),
        ),
      );
    },
  );
}

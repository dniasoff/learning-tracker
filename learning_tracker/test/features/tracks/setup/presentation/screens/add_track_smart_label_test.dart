/// Regression test for R1 finding (1):
/// The track-created toast showed "Genesis" (English translation from Sefaria
/// bundled data) instead of "Bereishis" / "Bereshit" (transliterated Hebrew
/// name) when the user created a Chumash track with scope "Genesis".
///
/// Fix: [smartTrackLabelForScope] passes the raw scope value through
/// [CurriculumLabels.transliterateNamedValue] so the label uses the correct
/// transliterated form.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';

/// Pure helper extracted from [AddTrackFlow._getSmartDefault].
/// Returns the user-visible track label for the given scope selection,
/// transliterating raw Sefaria data names (like "Genesis") to Hebrew-mode
/// names ("Bereishis" or "Bereshit") via [CurriculumLabels.transliterateNamedValue].
String smartTrackLabelForScope(
  String rawScopeValue, {
  TransliterationVariant variant = TransliterationVariant.ashkenazi,
}) {
  return CurriculumLabels.transliterateNamedValue(
    rawScopeValue,
    variant: variant,
  );
}

void main() {
  group('R1-(1) track toast label transliterates scope value', () {
    test('Genesis → Bereishis (Ashkenazi)', () {
      final label = smartTrackLabelForScope(
        'Genesis',
        variant: TransliterationVariant.ashkenazi,
      );
      expect(
        label,
        equals('Bereishis'),
        reason:
            'R1-(1): "Genesis" (raw Sefaria key) must map to "Bereishis" '
            'so the toast reads "Track Bereishis created" not "Track Genesis created".',
      );
    });

    test('Genesis → Bereshit (Sephardi)', () {
      final label = smartTrackLabelForScope(
        'Genesis',
        variant: TransliterationVariant.sephardi,
      );
      expect(
        label,
        equals('Bereshit'),
        reason: 'R1-(1): Sephardi variant must map "Genesis" → "Bereshit".',
      );
    });

    test('unknown key passes through unchanged', () {
      // Names not in the translation table pass through as-is.
      final label = smartTrackLabelForScope('SomeUnknownRef');
      expect(label, equals('SomeUnknownRef'));
    });

    test('Exodus → Shemos (Ashkenazi)', () {
      final label = smartTrackLabelForScope(
        'Exodus',
        variant: TransliterationVariant.ashkenazi,
      );
      expect(label, equals('Shemos'));
    });
  });
}

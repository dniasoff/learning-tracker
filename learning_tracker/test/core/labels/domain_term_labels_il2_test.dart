// Regression tests for IL-2 (nusach/transliteration leaks).
//
// Root-cause in our owned scope: the `chazaros` getter in DomainTermLabels
// ignores TransliterationVariant so it always returns "Chazaros" (Ashkenazi)
// even for Sephardi users who should see "Chazarot".
//
// Fix: add a [chazarosFor] method to DomainTermLabels that accepts an optional
// [variant] parameter, and update [totalChazaros] to accept the same parameter.
// The original [chazaros] getter is preserved for backward compatibility.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';

void main() {
  group('IL-2 — DomainTermLabels.chazarosFor variant-awareness', () {
    test('chazarosFor Ashkenazi (default) returns "Chazaros"', () {
      const terms = DomainTermLabels(false); // English mode
      expect(
        terms.chazarosFor(),
        'Chazaros',
        reason: 'Ashkenazi default should be "Chazaros"',
      );
    });

    test('chazarosFor Sephardi returns "Chazarot"', () {
      const terms = DomainTermLabels(false); // English mode
      expect(
        terms.chazarosFor(variant: TransliterationVariant.sephardi),
        'Chazarot',
        reason: 'Sephardi should be "Chazarot" not "Chazaros"',
      );
    });

    test('chazarosFor Hebrew mode returns Hebrew regardless of variant', () {
      const terms = DomainTermLabels(true); // Hebrew mode
      expect(
        terms.chazarosFor(variant: TransliterationVariant.sephardi),
        'חזרות',
        reason: 'Hebrew mode is nusach-independent',
      );
      expect(
        terms.chazarosFor(variant: TransliterationVariant.ashkenazi),
        'חזרות',
      );
    });

    test('totalChazaros Sephardi uses "Chazarot" in the phrase', () {
      const terms = DomainTermLabels(false);
      final result = terms.totalChazaros(
        5,
        variant: TransliterationVariant.sephardi,
      );
      expect(
        result.contains('Chazarot'),
        isTrue,
        reason: 'totalChazaros should use Sephardi form with sephardi variant',
      );
      expect(result.contains('Chazaros'), isFalse);
    });

    test('totalChazaros Ashkenazi (default) uses "Chazaros" in the phrase', () {
      const terms = DomainTermLabels(false);
      final result = terms.totalChazaros(5);
      expect(result.contains('Chazaros'), isTrue);
    });

    // Backward-compat: original getter must still work for existing callers.
    test('chazaros getter (backward compat) still returns Ashkenazi form', () {
      const terms = DomainTermLabels(false);
      expect(terms.chazaros, 'Chazaros');
    });
  });
}

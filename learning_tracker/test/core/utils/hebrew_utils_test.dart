import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/utils/hebrew_utils.dart';

void main() {
  group('HebrewUtils - stripNikud', () {
    test('removes vowel points from Hebrew text', () {
      // "me'eimasai" with nikud -> without nikud
      expect(HebrewUtils.stripNikud('מֵאֵימָתַי'), equals('מאימתי'));
    });

    test('preserves consonants and spaces', () {
      // "shema yisrael" with nikud
      expect(HebrewUtils.stripNikud('שְׁמַע יִשְׂרָאֵל'), equals('שמע ישראל'));
    });

    test('handles empty string', () {
      expect(HebrewUtils.stripNikud(''), equals(''));
    });

    test('handles text without nikud (no-op)', () {
      const plain = 'שלום עולם';
      expect(HebrewUtils.stripNikud(plain), equals(plain));
    });

    test('handles mixed Hebrew/English text', () {
      expect(
        HebrewUtils.stripNikud('The word שָׁלוֹם means peace'),
        equals('The word שלום means peace'),
      );
    });

    test('removes cantillation marks', () {
      // Etnachta (U+0591) and other cantillation marks
      // "bereishis" with cantillation: etnachta under resh
      expect(HebrewUtils.stripNikud('בְּרֵאשִׁ֑ית'), equals('בראשית'));
    });

    test('preserves punctuation and maqaf (U+05BE)', () {
      // Maqaf is the Hebrew hyphen (U+05BE), should NOT be stripped
      // "al-pi" with nikud and maqaf
      expect(HebrewUtils.stripNikud('עַל־פִּי'), equals('על־פי'));
    });
  });

  group('HebrewUtils - hasNikud', () {
    test('returns true for text with nikud', () {
      expect(HebrewUtils.hasNikud('שָׁלוֹם'), isTrue);
    });

    test('returns false for text without nikud', () {
      expect(HebrewUtils.hasNikud('שלום'), isFalse);
    });

    test('returns false for empty string', () {
      expect(HebrewUtils.hasNikud(''), isFalse);
    });
  });
}

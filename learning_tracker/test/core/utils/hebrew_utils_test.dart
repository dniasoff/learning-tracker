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

  group('HebrewUtils - Sefaria footnote markup (BUG-5)', () {
    test('removes footnote marker AND footnote body whole — no glued '
        'letters, no duplicated lemma', () {
      // Exact raw shape returned by Sefaria v3 API for Genesis 1:1 (en).
      const raw =
          'When God began to create'
          '<sup class="footnote-marker">a</sup>'
          '<i class="footnote"><b>When God began to create </b>'
          'In contrast to others “In the beginning God created.”</i>'
          ' heaven and earth— ';

      final cleaned = HebrewUtils.cleanSefariaText(raw);

      // The readable verse: footnote marker ("a") and the entire footnote
      // body removed. Trailing/leading collapse handled; trim for assert.
      expect(cleaned.trim(), 'When God began to create heaven and earth—');
      // Regression guards for the on-device symptoms:
      expect(cleaned, isNot(contains('In contrast to others')));
      expect(cleaned, isNot(contains('createa'))); // marker glued to word
      // No duplicated lemma ("When God began to create" must appear once).
      expect(RegExp('When God began to create').allMatches(cleaned).length, 1);
      // No leftover tags.
      expect(cleaned, isNot(contains('<')));
    });

    test('numeric footnote markers are removed (Mishneh Torah shape)', () {
      const raw =
          'From the time of Ezra'
          '<sup class="footnote-marker">1</sup>'
          '<i class="footnote">when the Jews who returned from the '
          'Babylonian exile did not speak Hebrew fluently.</i>'
          ' it was customary to read';

      final cleaned = HebrewUtils.cleanSefariaText(raw);

      expect(cleaned.trim(), 'From the time of Ezra it was customary to read');
      expect(cleaned, isNot(contains('Ezra1')));
      expect(cleaned, isNot(contains('Babylonian')));
    });

    test('multiple footnotes in one segment are each removed', () {
      const raw =
          'Alpha'
          '<sup class="footnote-marker">a</sup>'
          '<i class="footnote">first note</i>'
          ' and Beta'
          '<sup class="footnote-marker">b</sup>'
          '<i class="footnote">second note</i>'
          ' end';

      final cleaned = HebrewUtils.cleanSefariaText(raw);

      expect(cleaned.trim(), 'Alpha and Beta end');
    });

    test('collapses the double space left where footnote markup sat', () {
      const raw =
          'create'
          '<sup class="footnote-marker">a</sup>'
          '<i class="footnote">note</i>'
          ' heaven';
      final cleaned = HebrewUtils.cleanSefariaText(raw);
      expect(cleaned, isNot(contains('  '))); // no double space
      expect(cleaned.trim(), 'create heaven');
    });

    test('plain text without footnotes is unchanged', () {
      const plain = 'In the beginning God created the heaven and the earth.';
      expect(HebrewUtils.cleanSefariaText(plain), plain);
    });

    test('still strips ordinary (non-footnote) HTML tags', () {
      expect(HebrewUtils.cleanSefariaText('a <b>bold</b> word'), 'a bold word');
    });

    test(
      'decodeHtmlEntities applies the same footnote handling for Hebrew',
      () {
        const raw =
            'בְּרֵאשִׁית'
            '<sup class="footnote-marker">א</sup>'
            '<i class="footnote">הערה</i>'
            ' בָּרָא';
        final cleaned = HebrewUtils.decodeHtmlEntities(raw);
        expect(cleaned, isNot(contains('הערה')));
        expect(cleaned, isNot(contains('<')));
        expect(cleaned.trim(), 'בְּרֵאשִׁית בָּרָא');
      },
    );
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

// Product decision (2026-06-11): when the device UI language is Hebrew, Jewish
// domain terms render in Hebrew SCRIPT automatically — independent of the
// per-profile Hebrew-Terms toggle (which is hidden in Hebrew UI). In a
// non-Hebrew locale the toggle is the user's choice.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';

void main() {
  group('resolveUseHebrewTerms — Hebrew script follows the device locale', () {
    test(
      'Hebrew device locale forces Hebrew script even when toggle is off',
      () {
        expect(
          resolveUseHebrewTerms(localeIsHebrew: true, toggleOn: false),
          isTrue,
          reason:
              'A Hebrew device must show Hebrew-script terms regardless of the '
              'hidden Hebrew-Terms toggle.',
        );
      },
    );

    test('Hebrew device locale stays Hebrew when toggle is on', () {
      expect(
        resolveUseHebrewTerms(localeIsHebrew: true, toggleOn: true),
        isTrue,
      );
    });

    test('non-Hebrew locale respects the toggle (on → Hebrew script)', () {
      expect(
        resolveUseHebrewTerms(localeIsHebrew: false, toggleOn: true),
        isTrue,
      );
    });

    test('non-Hebrew locale respects the toggle (off → transliteration)', () {
      expect(
        resolveUseHebrewTerms(localeIsHebrew: false, toggleOn: false),
        isFalse,
        reason:
            'An English device with the toggle off must show transliteration.',
      );
    });
  });
}

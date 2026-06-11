/// Regression test for TS-12 — aggregateSiyumLabel must not duplicate the
/// "Seder" word when the raw aggregate key already contains it.
///
/// Root cause: content data stores Bavli/Mishnayos/Yerushalmi level-1 keys
/// WITH the level word ("Seder Zeraim", "Seder Moed", …).
/// [aggregateSiyumLabel] previously composed "Siyum Seder " + "Seder Zeraim"
/// → "Siyum Seder Seder Zeraim".  The fix strips the leading "Seder " from
/// [aggregateName] before prepending [terms.siyumSeder].
@Tags(['progress', 'siyumim_milestones', 'ts12'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/siyum_milestone_label.dart';

void main() {
  // English-terms (transliteration) mode.
  const termsEn = DomainTermLabels(false);
  // Hebrew-script mode.
  const termsHe = DomainTermLabels(true);

  // TS-12 red→green: duplicate "Seder" suppressed
  group('aggregateSiyumLabel — no duplicate Seder word', () {
    test(
      'Bavli "Seder Zeraim" → "Siyum Seder Zeraim" (not "Siyum Seder Seder Zeraim")',
      () {
        final result = aggregateSiyumLabel(
          curriculumId: CurriculumId.bavli,
          aggregateName: 'Seder Zeraim',
          terms: termsEn,
        );
        expect(result, 'Siyum Seder Zeraim');
        // Must not contain the duplicated word.
        expect(result, isNot(contains('Seder Seder')));
      },
    );

    test(
      'Bavli "Seder Moed" → "Siyum Seder Moed" (not "Siyum Seder Seder Moed")',
      () {
        final result = aggregateSiyumLabel(
          curriculumId: CurriculumId.bavli,
          aggregateName: 'Seder Moed',
          terms: termsEn,
        );
        expect(result, 'Siyum Seder Moed');
        expect(result, isNot(contains('Seder Seder')));
      },
    );

    test('Mishnayos "Seder Tahorot" → "Siyum Seder Tahorot" (en-terms)', () {
      final result = aggregateSiyumLabel(
        curriculumId: CurriculumId.mishnayos,
        aggregateName: 'Seder Tahorot',
        terms: termsEn,
      );
      expect(result, 'Siyum Seder Tahorot');
      expect(result, isNot(contains('Seder Seder')));
    });

    test(
      'Hebrew-script mode: "Seder Zeraim" → Hebrew siyum seder label without duplication',
      () {
        final result = aggregateSiyumLabel(
          curriculumId: CurriculumId.bavli,
          aggregateName: 'Seder Zeraim',
          terms: termsHe,
        );
        // Must not contain the English "Seder" word at all (Hebrew mode uses
        // the Hebrew "סדר").
        expect(result, isNot(contains('Seder')));
        // Must not duplicate the Hebrew "סדר".
        expect(result.split('סדר').length - 1, lessThanOrEqualTo(1));
      },
    );

    test(
      'Bare aggregate key without "Seder " prefix passes through unchanged',
      () {
        // A hypothetical key with no leading "Seder " must still produce the
        // correct label — stripping must only remove the leading "Seder "
        // prefix, not the word anywhere in the string.
        final result = aggregateSiyumLabel(
          curriculumId: CurriculumId.mishnayos,
          aggregateName: 'Zeraim',
          terms: termsEn,
        );
        expect(result, 'Siyum Seder Zeraim');
      },
    );
  });
}

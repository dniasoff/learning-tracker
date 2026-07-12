/// Regression tests for R1 finding (5):
/// EditTrackScreen accepted an empty track name with no error, and allowed 0
/// study days per week with no warning.
///
/// Fix:
/// - [validateTrackName] returns false when the name is blank/whitespace-only.
/// - [studyDayCount] is used in _save() to warn before saving with 0 study days.
///
/// AUD-tracks-24: [validateTrackName] was changed from returning a
/// hardcoded English error message (`String?`) to returning a plain `bool` —
/// a validator that hands back natural-language text invites a future bug
/// where that raw string gets displayed unlocalized. The caller now derives
/// its (localized) error copy from the bool result instead.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/edit_track_screen.dart';

void main() {
  group('R1-(5) edit-track validation', () {
    group('validateTrackName', () {
      test('empty string is invalid', () {
        expect(
          validateTrackName(''),
          isFalse,
          reason: 'R1-(5): empty name must fail validation.',
        );
      });

      test('whitespace-only string is invalid', () {
        expect(
          validateTrackName('   '),
          isFalse,
          reason: 'R1-(5): whitespace-only name must fail validation.',
        );
      });

      test('non-empty name is valid', () {
        expect(
          validateTrackName('Bereishis'),
          isTrue,
          reason: 'R1-(5): a non-empty name must pass validation.',
        );
      });

      test('does not return a String (AUD-tracks-24)', () {
        // Guards against regressing to a hardcoded natural-language message.
        expect(validateTrackName(''), isA<bool>());
        expect(validateTrackName('Bereishis'), isA<bool>());
      });
    });

    group('studyDayCount', () {
      test('all study days counts correctly', () {
        final days = {
          1: 'study',
          2: 'study',
          3: 'study',
          4: 'study',
          5: 'study',
          6: 'review',
          7: 'review',
        };
        expect(studyDayCount(days), equals(5));
      });

      test('zero study days returns 0', () {
        final days = {
          1: 'review',
          2: 'review',
          3: 'review',
          4: 'review',
          5: 'review',
          6: 'review',
          7: 'review',
        };
        expect(
          studyDayCount(days),
          equals(0),
          reason: 'R1-(5): studyDayCount must detect zero study days.',
        );
      });
    });
  });
}

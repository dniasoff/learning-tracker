/// Regression tests for R1 finding (5):
/// EditTrackScreen accepted an empty track name with no error, and allowed 0
/// study days per week with no warning.
///
/// Fix:
/// - [validateTrackName] returns an error message when the name is blank.
/// - [studyDayCount] is used in _save() to warn before saving with 0 study days.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/edit_track_screen.dart';

void main() {
  group('R1-(5) edit-track validation', () {
    group('validateTrackName', () {
      test('empty string returns error', () {
        final error = validateTrackName('');
        expect(
          error,
          isNotNull,
          reason: 'R1-(5): empty name must produce a validation error.',
        );
        expect(error, isA<String>());
        expect(
          (error as String).isNotEmpty,
          isTrue,
          reason: 'Error message must be non-empty.',
        );
      });

      test('whitespace-only string returns error', () {
        final error = validateTrackName('   ');
        expect(
          error,
          isNotNull,
          reason:
              'R1-(5): whitespace-only name must produce a validation error.',
        );
      });

      test('non-empty name returns null', () {
        final error = validateTrackName('Bereishis');
        expect(
          error,
          isNull,
          reason:
              'R1-(5): a non-empty name must not produce a validation error.',
        );
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

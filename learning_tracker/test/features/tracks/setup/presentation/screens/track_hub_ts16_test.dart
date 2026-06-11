/// Regression test for TS-16:
/// The Archive/Delete track dialog must NOT offer destructive actions when
/// the current track is the only active curriculum for the profile.
///
/// Before the fix: the dialog always shows Archive/Delete options, and the
/// error is only surfaced AFTER the user commits (post-dialog snackbar).
///
/// After the fix: [trackDeletionAllowed] is a pure function that the dialog
/// uses to pre-check whether Archive/Delete should be offered. When it returns
/// false, the dialog shows an explanation rather than the destructive actions.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/track_management_hub_screen.dart';

void main() {
  group('TS-16 — trackDeletionAllowed guards last-active curriculum', () {
    test('returns false when only one curriculum is active', () {
      // A profile with exactly one active curriculum must not be offered
      // Archive/Delete — doing so surfaces an error only post-commit.
      final allowed = trackDeletionAllowed(activeCurriculumCount: 1);
      expect(
        allowed,
        isFalse,
        reason:
            'TS-16: deletion must not be offered for the last active curriculum',
      );
    });

    test('returns true when multiple curricula are active', () {
      final allowed = trackDeletionAllowed(activeCurriculumCount: 3);
      expect(
        allowed,
        isTrue,
        reason: 'Deletion is allowed when other curricula remain active',
      );
    });

    test('returns false when active count is 0 (defensive)', () {
      // Should never happen in practice, but guard against it.
      final allowed = trackDeletionAllowed(activeCurriculumCount: 0);
      expect(allowed, isFalse);
    });

    test('returns true when exactly 2 curricula are active', () {
      final allowed = trackDeletionAllowed(activeCurriculumCount: 2);
      expect(allowed, isTrue);
    });
  });
}

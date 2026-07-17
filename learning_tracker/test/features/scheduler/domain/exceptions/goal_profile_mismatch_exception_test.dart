// Tests for GoalProfileMismatchException (AUD-scheduler-03) — the
// repository-layer backstop thrown by GoalRepositoryImpl.createGoal /
// updateGoal / deleteGoal when a caller-supplied or existing-row profileId
// disagrees with the repository instance's own profile.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';
import 'package:learning_tracker/features/scheduler/domain/exceptions/goal_profile_mismatch_exception.dart';

void main() {
  group('GoalProfileMismatchException', () {
    test('carries the given message', () {
      const ex = GoalProfileMismatchException('profile mismatch on goal 7');
      expect(ex.message, 'profile mismatch on goal 7');
    });

    test('is a PermissionException (caller-not-authorised category)', () {
      const ex = GoalProfileMismatchException('mismatch');
      expect(ex, isA<PermissionException>());
    });

    test('is an AppException (root of the typed-exception hierarchy)', () {
      const ex = GoalProfileMismatchException('mismatch');
      expect(ex, isA<AppException>());
    });

    test('is an Exception, never an Error (EH-4 — only_throw_errors)', () {
      const ex = GoalProfileMismatchException('mismatch');
      expect(ex, isA<Exception>());
      expect(ex, isNot(isA<Error>()));
    });

    test('toString includes the type name and message', () {
      const ex = GoalProfileMismatchException('goal 7 belongs to profile 2');
      expect(ex.toString(), contains('GoalProfileMismatchException'));
      expect(ex.toString(), contains('goal 7 belongs to profile 2'));
    });
  });
}

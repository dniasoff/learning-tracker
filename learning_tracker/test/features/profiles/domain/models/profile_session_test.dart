// Regression test for AUD-profiles-12: profile_session.dart hand-wrote
// `operator ==`/`hashCode` instead of using `@freezed` like its sibling
// `profile_model.dart` (both live under features/profiles/domain/models/).
// Hand-rolled equality is exactly the class of bug (forgotten field,
// inconsistent hashCode) the @freezed rule exists to prevent.
//
// Fix: ProfileSession is now an `@freezed` class (single constructor shape,
// matching ProfileModel's pattern), with generated `==`/`hashCode`/
// `toString`. `.none()` becomes a body-based convenience factory that
// delegates to the primary const constructor with `profileId: null` —
// mirroring the existing `ReminderPreferences.defaults()` convention
// elsewhere in the codebase.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_session.dart';

void main() {
  group('AUD-profiles-12 — ProfileSession value semantics', () {
    test('two sessions with the same profileId are equal and share a '
        'hashCode', () {
      const a = ProfileSession(profileId: 7);
      const b = ProfileSession(profileId: 7);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('sessions with different profileIds are not equal', () {
      const a = ProfileSession(profileId: 7);
      const b = ProfileSession(profileId: 8);
      expect(a, isNot(equals(b)));
    });

    test('.none() is active-false and equal to another .none()', () {
      final none1 = ProfileSession.none();
      final none2 = ProfileSession.none();
      expect(none1.isActive, isFalse);
      expect(none1, equals(none2));
    });

    test('a session with a profileId is active', () {
      const session = ProfileSession(profileId: 1);
      expect(session.isActive, isTrue);
    });

    test('.none() is equal to an explicit null-profileId session '
        '(same underlying shape)', () {
      final none = ProfileSession.none();
      const explicitNull = ProfileSession(profileId: null);
      expect(none, equals(explicitNull));
    });
  });

  group('AUD-profiles-12 — source check (no hand-rolled equality)', () {
    // The bug this finding names: profile_session.dart hand-writes
    // operator==/hashCode instead of using @freezed like ProfileModel.
    // Assert the class is declared @freezed and no longer hand-rolls
    // equality — this is the AC-named checker for a hygiene/naming finding
    // (today's hand-rolled implementation is already behaviorally correct,
    // so there is no runtime symptom to reproduce; the defect is the
    // inconsistent, drift-prone pattern itself).
    test('ProfileSession is declared @freezed and does not hand-roll '
        'operator==/hashCode', () {
      final candidates = [
        File('lib/features/profiles/domain/models/profile_session.dart'),
        File('../lib/features/profiles/domain/models/profile_session.dart'),
      ];
      final file = candidates.firstWhere(
        (f) => f.existsSync(),
        orElse: () => throw TestFailure(
          'Could not locate '
          'lib/features/profiles/domain/models/profile_session.dart.',
        ),
      );
      final source = file.readAsStringSync();

      expect(
        source.contains('@freezed'),
        isTrue,
        reason:
            'ProfileSession must be declared @freezed, matching the sibling '
            'ProfileModel in the same directory.',
      );

      expect(
        source.contains('operator =='),
        isFalse,
        reason:
            'ProfileSession must not hand-write operator== — hand-rolled '
            'equality is exactly the class of bug (forgotten field, '
            'inconsistent hashCode) the @freezed rule exists to prevent.',
      );

      expect(
        RegExp(r'int\s+get\s+hashCode').hasMatch(source),
        isFalse,
        reason:
            'ProfileSession must not hand-write a hashCode getter — '
            'equality/hashCode must come from @freezed generation.',
      );
    });
  });
}

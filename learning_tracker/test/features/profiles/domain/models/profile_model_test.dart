// Regression test for AUD-core-domain-04: profile_model.dart's
// `profileMode` getter re-implemented ProfileMode's own string↔enum mapping
// with a hand-rolled `switch (mode) { 'child' => ...; _ => adult }` instead
// of delegating to a ProfileMode accessor — a second, unlinked
// representation of the same storage-key mapping that the compiler cannot
// keep in sync with `lib/core/domain/value_objects/profile_mode.dart`.
//
// Fix: the getter now delegates to `ProfileMode.tryFromStorageKey`
// (`profile_mode.dart`'s EH-4-compliant non-throwing accessor — see that
// file's doc comment), preserving the existing defensive "unknown → adult"
// fallback behaviour without re-switching on the raw string.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';

ProfileModel _profileWithMode(String mode) => ProfileModel(
  id: 1,
  ulid: 'ulid-1',
  accountId: 1,
  displayName: 'Test',
  mode: mode,
  avatarIndex: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  group('AUD-core-domain-04 — ProfileModel.profileMode', () {
    test('"adult" maps to ProfileMode.adult', () {
      expect(_profileWithMode('adult').profileMode, ProfileMode.adult);
    });

    test('"child" maps to ProfileMode.child', () {
      expect(_profileWithMode('child').profileMode, ProfileMode.child);
    });

    test('an unrecognised mode falls back to ProfileMode.adult (defensive, '
        'unchanged behaviour)', () {
      expect(_profileWithMode('bogus').profileMode, ProfileMode.adult);
    });

    test('agrees with ProfileMode.tryFromStorageKey for every known key', () {
      for (final mode in ProfileMode.values) {
        expect(
          _profileWithMode(mode.storageKey).profileMode,
          ProfileMode.tryFromStorageKey(mode.storageKey),
        );
      }
    });
  });

  group('AUD-core-domain-04 — source check (no re-implemented switch)', () {
    // The bug this finding names: profile_model.dart re-switches on the raw
    // `mode` string instead of calling into ProfileMode's own storage-key
    // parser. Assert the getter delegates instead of hand-rolling the
    // mapping — this is the AC-named checker for a hygiene/duplication
    // finding (no runtime symptom to reproduce; the defect is the
    // duplicated mapping itself).
    test('profileMode getter delegates to a ProfileMode.*StorageKey accessor '
        'and does not re-switch on the raw mode string', () {
      final candidates = [
        File('lib/features/profiles/domain/models/profile_model.dart'),
        File('../lib/features/profiles/domain/models/profile_model.dart'),
      ];
      final file = candidates.firstWhere(
        (f) => f.existsSync(),
        orElse: () => throw TestFailure(
          'Could not locate '
          'lib/features/profiles/domain/models/profile_model.dart.',
        ),
      );
      final source = file.readAsStringSync();

      final delegatesToProfileMode =
          source.contains('ProfileMode.tryFromStorageKey(') ||
          source.contains('ProfileMode.fromStorageKey(');
      expect(
        delegatesToProfileMode,
        isTrue,
        reason:
            'profileMode getter must delegate to ProfileMode.tryFromStorageKey '
            '(or ProfileMode.fromStorageKey) instead of re-implementing the '
            'string↔enum mapping.',
      );

      // The old anti-pattern: a switch expression pattern-matching the
      // raw storage-key literals directly (`switch (mode) { 'child' =>`).
      final hasHandRolledSwitch = RegExp(
        r"switch\s*\(\s*mode\s*\)\s*\{[^}]*'child'\s*=>",
      ).hasMatch(source);
      expect(
        hasHandRolledSwitch,
        isFalse,
        reason:
            "profileMode must not re-switch on the raw 'mode' string — that "
            'is exactly the duplicated mapping AUD-core-domain-04 flags.',
      );
    });
  });
}

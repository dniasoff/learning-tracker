/// Unit tests for
/// `lib/features/profiles/domain/models/learner_profile_entity.dart` — the
/// entity mirrored test required by audit check 29/40 (AG-5) alongside
/// `firestore_learner_profile_repository_test.dart`. Covers: `toFirestore`/
/// `fromFirestore` round-trip for both `ProfileMode`s, `profileId` never
/// appearing in the write map, the `avatar` empty-string default (never
/// null — see the class doc comment for why), the `mode` unknown-value
/// fallback to `ProfileMode.adult`, and the documented throw-on-missing-
/// timestamp decode failure.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';

void main() {
  group('toFirestore / fromFirestore round-trip', () {
    test('round-trips a child profile with an avatar set', () {
      final profile = LearnerProfileEntity(
        profileId: 'profile-ulid-1',
        displayName: 'Yossi',
        mode: ProfileMode.child,
        avatar: 'bear',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
      );

      final decoded = LearnerProfileEntity.fromFirestore(
        'profile-ulid-1',
        profile.toFirestore(),
      );

      expect(decoded, profile);
    });

    test('round-trips an adult profile with the default empty avatar', () {
      final profile = LearnerProfileEntity(
        profileId: 'profile-ulid-2',
        displayName: 'Daniel',
        mode: ProfileMode.adult,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      expect(profile.avatar, '');
      final data = profile.toFirestore();
      expect(data['avatar'], ''); // never omitted — see class doc comment.

      final decoded = LearnerProfileEntity.fromFirestore(
        'profile-ulid-2',
        data,
      );
      expect(decoded.avatar, '');
    });

    test('toFirestore never includes a profile_id or account_id field — '
        'the path already carries identity', () {
      final profile = LearnerProfileEntity(
        profileId: 'profile-ulid-3',
        displayName: 'Someone',
        mode: ProfileMode.adult,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      final data = profile.toFirestore();
      expect(data, isNot(contains('profile_id')));
      expect(data, isNot(contains('account_id')));
    });

    test('fromFirestore uses the caller-supplied profileId, not any '
        'document field', () {
      final data = LearnerProfileEntity(
        profileId: 'ignored',
        displayName: 'Someone',
        mode: ProfileMode.adult,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ).toFirestore();

      final decoded = LearnerProfileEntity.fromFirestore('real-ulid', data);

      expect(decoded.profileId, 'real-ulid');
    });
  });

  group('mode — decode fallback', () {
    test('falls back to ProfileMode.adult for an unrecognised mode value', () {
      final decoded = LearnerProfileEntity.fromFirestore('profile-ulid-1', {
        'display_name': 'Someone',
        'mode': 'not-a-real-mode',
        'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
      });

      expect(decoded.mode, ProfileMode.adult);
    });

    test('falls back to ProfileMode.adult when mode is entirely missing', () {
      final decoded = LearnerProfileEntity.fromFirestore('profile-ulid-1', {
        'display_name': 'Someone',
        'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
      });

      expect(decoded.mode, ProfileMode.adult);
    });
  });

  group('fromFirestore — decode failures', () {
    test('throws FormatException when created_at is missing', () {
      expect(
        () => LearnerProfileEntity.fromFirestore('profile-ulid-1', {
          'display_name': 'Someone',
          'mode': 'adult',
          'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when updated_at is missing', () {
      expect(
        () => LearnerProfileEntity.fromFirestore('profile-ulid-1', {
          'display_name': 'Someone',
          'mode': 'adult',
          'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

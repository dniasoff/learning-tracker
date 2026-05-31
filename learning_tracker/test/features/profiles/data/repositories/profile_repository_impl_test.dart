import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/learner_profile_codec.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';

import '../../../../helpers/test_database.dart';

/// [SyncWriteFacade] that captures the payload passed to [pushLearnerProfile].
///
/// All other operations are no-ops so the test only exercises the profile push.
class _CapturingProfileFacade implements SyncWriteFacade {
  final List<Map<String, dynamic>> capturedPayloads = [];

  @override
  Future<void> pushLearnerProfile(Map<String, dynamic> profile) async {
    capturedPayloads.add(Map<String, dynamic>.from(profile));
  }

  @override
  Future<void> deleteLearnerProfile(int profileId) async {}
  @override
  Future<void> pushGamificationSettingsSnapshot() async {}
  @override
  Future<void> pushUiPreferencesSnapshot() async {}
  @override
  Future<void> pushBookmark(Map<String, dynamic> bookmark) async {}
  @override
  Future<void> pushSettings(Map<String, dynamic> settings) async {}
  @override
  Future<void> pushGoal(Map<String, dynamic> goal) async {}
  @override
  Future<void> deleteGoal(Map<String, dynamic> payload) async {}
  @override
  Future<void> pushCurriculumTrack(Map<String, dynamic> trackData) async {}
  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required String curriculumId,
    required List<Map<String, dynamic>> items,
    required DateTime updatedAt,
  }) async {}
  @override
  Future<void> pushStageDefinitions({
    required int trackId,
    required String curriculumId,
    required List<Map<String, dynamic>> stages,
    required DateTime updatedAt,
  }) async {}
  @override
  Future<void> pushStudyDayConfig(Map<String, dynamic> payload) async {}
  @override
  Future<void> deleteCompletion(String completionId) async {}
  @override
  Future<void> pushProfileProgram(Map<String, dynamic> payload) async {}
}

void main() {
  late UserDatabase db;
  late ProfileRepositoryImpl repo;

  setUp(() async {
    db = createTestDatabase();
    repo = ProfileRepositoryImpl(db);
    // Seed accounts 1 and 2 for FK constraint on learner_profiles.account_id.
    for (final email in ['account1@test.com', 'account2@test.com']) {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: email,
              tier: 'localBorn',
              displayName: 'Test Account',
              createdAt: DateTimeFactory.nowUtc(),
              updatedAt: DateTimeFactory.nowUtc(),
            ),
          );
    }
  });

  tearDown(() async {
    await db.close();
  });

  group('ProfileRepositoryImpl', () {
    test('createProfile creates and returns a profile', () async {
      final profile = await repo.createProfile(
        accountId: 1,
        displayName: 'Test User',
        mode: 'adult',
      );

      expect(profile.id, isPositive);
      expect(profile.accountId, 1);
      expect(profile.displayName, 'Test User');
      expect(profile.mode, 'adult');
      expect(profile.avatarIndex, 0);
    });

    test('getProfileById returns created profile', () async {
      final created = await repo.createProfile(
        accountId: 1,
        displayName: 'User',
        mode: 'child',
        avatarIndex: 3,
      );

      final fetched = await repo.getProfileById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.displayName, 'User');
      expect(fetched.mode, 'child');
      expect(fetched.avatarIndex, 3);
    });

    test('getProfileById returns null for non-existent id', () async {
      final result = await repo.getProfileById(999);
      expect(result, isNull);
    });

    test('getProfilesByAccount returns all profiles for account', () async {
      await repo.createProfile(accountId: 1, displayName: 'A', mode: 'adult');
      await repo.createProfile(accountId: 1, displayName: 'B', mode: 'child');
      await repo.createProfile(accountId: 2, displayName: 'C', mode: 'adult');

      final account1Profiles = await repo.getProfilesByAccount(1);
      expect(account1Profiles, hasLength(2));

      final account2Profiles = await repo.getProfilesByAccount(2);
      expect(account2Profiles, hasLength(1));
    });

    test('updateProfile updates specified fields', () async {
      final created = await repo.createProfile(
        accountId: 1,
        displayName: 'Original',
        mode: 'adult',
      );

      final updated = await repo.updateProfile(
        id: created.id,
        displayName: 'Updated',
        avatarIndex: 5,
      );

      expect(updated.displayName, 'Updated');
      expect(updated.avatarIndex, 5);
      expect(updated.mode, 'adult'); // unchanged
    });

    test('updateProfile throws for non-existent profile', () async {
      expect(
        () => repo.updateProfile(id: 999, displayName: 'X'),
        throwsStateError,
      );
    });

    test('deleteProfile removes profile and cascaded data', () async {
      // Need 2 profiles — can't delete the last one
      await repo.createProfile(
        accountId: 1,
        displayName: 'Keeper',
        mode: 'adult',
      );
      final profile = await repo.createProfile(
        accountId: 1,
        displayName: 'To Delete',
        mode: 'adult',
      );

      await repo.deleteProfile(profile.id);

      final result = await repo.getProfileById(profile.id);
      expect(result, isNull);
    });

    test('countProfilesForAccount returns correct count', () async {
      expect(await repo.countProfilesForAccount(1), 0);

      await repo.createProfile(accountId: 1, displayName: 'A', mode: 'adult');
      expect(await repo.countProfilesForAccount(1), 1);

      await repo.createProfile(accountId: 1, displayName: 'B', mode: 'child');
      expect(await repo.countProfilesForAccount(1), 2);
    });

    test(
      'createProfile throws MaxProfilesExceededException at limit',
      () async {
        for (var i = 0; i < 10; i++) {
          await repo.createProfile(
            accountId: 1,
            displayName: 'Profile $i',
            mode: 'adult',
          );
        }

        expect(
          () => repo.createProfile(
            accountId: 1,
            displayName: 'Too Many',
            mode: 'adult',
          ),
          throwsA(isA<MaxProfilesExceededException>()),
        );
      },
    );

    // ── Duplicate name prevention (DNI-174) ──────────────────────────────────

    test('AT-1: rejects exact duplicate name', () async {
      await repo.createProfile(
        accountId: 1,
        displayName: 'Daniel',
        mode: 'adult',
      );

      expect(
        () => repo.createProfile(
          accountId: 1,
          displayName: 'Daniel',
          mode: 'adult',
        ),
        throwsA(isA<DuplicateProfileNameException>()),
      );
    });

    test('AT-2: rejects case-insensitive duplicate', () async {
      await repo.createProfile(
        accountId: 1,
        displayName: 'Daniel',
        mode: 'adult',
      );

      expect(
        () => repo.createProfile(
          accountId: 1,
          displayName: 'daniel',
          mode: 'adult',
        ),
        throwsA(isA<DuplicateProfileNameException>()),
      );

      expect(
        () => repo.createProfile(
          accountId: 1,
          displayName: 'DANIEL',
          mode: 'adult',
        ),
        throwsA(isA<DuplicateProfileNameException>()),
      );
    });

    test('AT-3: rejects whitespace-padded duplicate', () async {
      await repo.createProfile(
        accountId: 1,
        displayName: 'Daniel',
        mode: 'adult',
      );

      expect(
        () => repo.createProfile(
          accountId: 1,
          displayName: '  Daniel  ',
          mode: 'adult',
        ),
        throwsA(isA<DuplicateProfileNameException>()),
      );
    });

    test('AT-4: different accounts can have same name', () async {
      await repo.createProfile(
        accountId: 1,
        displayName: 'Daniel',
        mode: 'adult',
      );

      final profile2 = await repo.createProfile(
        accountId: 2,
        displayName: 'Daniel',
        mode: 'adult',
      );
      expect(profile2.displayName, 'Daniel');
    });

    test('AT-5: rename blocked when name conflicts', () async {
      await repo.createProfile(
        accountId: 1,
        displayName: 'Daniel',
        mode: 'adult',
      );
      final sarah = await repo.createProfile(
        accountId: 1,
        displayName: 'Sarah',
        mode: 'adult',
      );

      expect(
        () => repo.updateProfile(id: sarah.id, displayName: 'Daniel'),
        throwsA(isA<DuplicateProfileNameException>()),
      );

      // Verify Sarah's name is unchanged
      final unchanged = await repo.getProfileById(sarah.id);
      expect(unchanged!.displayName, 'Sarah');
    });

    test('AT-6: rename to same name (self-match) allowed', () async {
      final daniel = await repo.createProfile(
        accountId: 1,
        displayName: 'Daniel',
        mode: 'adult',
      );

      final updated = await repo.updateProfile(
        id: daniel.id,
        displayName: 'Daniel',
      );
      expect(updated.displayName, 'Daniel');
    });

    test('AT-8: deleted profile name is reusable', () async {
      // Need 2 profiles — can't delete the last one
      await repo.createProfile(
        accountId: 1,
        displayName: 'Keeper',
        mode: 'adult',
      );
      final profile = await repo.createProfile(
        accountId: 1,
        displayName: 'Daniel',
        mode: 'adult',
      );
      await repo.deleteProfile(profile.id);

      final newProfile = await repo.createProfile(
        accountId: 1,
        displayName: 'Daniel',
        mode: 'adult',
      );
      expect(newProfile.displayName, 'Daniel');
    });

    test('createProfile trims stored name', () async {
      final profile = await repo.createProfile(
        accountId: 1,
        displayName: '  Trimmed  ',
        mode: 'adult',
      );
      expect(profile.displayName, 'Trimmed');
    });
  });

  // ── R6-18 regression: _toFirestorePayload key alignment ──────────────────
  //
  // ProfileRepositoryImpl._toFirestorePayload previously wrote the profile id
  // under the key `'id'`, but LearnerProfileCodec.decode() reads `'profile_id'`.
  // The mismatch caused decode() to return null, silently dropping the profile
  // from every pull-merge.  This test verifies the full write→decode round-trip.

  group(
    'R6-18 regression: _toFirestorePayload round-trips through LearnerProfileCodec',
    () {
      late UserDatabase db;
      late _CapturingProfileFacade facade;
      late ProfileRepositoryImpl repoWithSync;

      setUp(() async {
        db = createTestDatabase();
        facade = _CapturingProfileFacade();
        repoWithSync = ProfileRepositoryImpl(db, syncEngine: facade);
        await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                email: 'sync@test.com',
                tier: 'cloudBorn',
                displayName: 'Sync Account',
                createdAt: DateTimeFactory.nowUtc(),
                updatedAt: DateTimeFactory.nowUtc(),
              ),
            );
      });

      tearDown(() => db.close());

      test(
        'createProfile payload decodes back to the same profile id',
        () async {
          const codec = LearnerProfileCodec();

          final created = await repoWithSync.createProfile(
            accountId: 1,
            displayName: 'Alice',
            mode: 'child',
            avatarIndex: 2,
          );

          expect(
            facade.capturedPayloads,
            hasLength(1),
            reason: 'pushLearnerProfile should have been called once',
          );

          final payload = facade.capturedPayloads.first;
          final decoded = codec.decode(payload);

          expect(
            decoded,
            isNotNull,
            reason:
                'LearnerProfileCodec.decode() must not return null — '
                'if it does the payload key for the profile id is wrong',
          );
          expect(
            decoded!.profileId,
            equals(created.id),
            reason: 'decoded profileId must match the created profile id',
          );
          expect(decoded.accountId, equals(created.accountId));
          expect(decoded.displayName, equals(created.displayName));
          expect(decoded.mode, equals(created.mode));
          expect(decoded.avatarIndex, equals(created.avatarIndex));
        },
      );

      test('updateProfile payload decodes back to the same profile id', () async {
        const codec = LearnerProfileCodec();

        final created = await repoWithSync.createProfile(
          accountId: 1,
          displayName: 'Bob',
          mode: 'adult',
        );
        facade.capturedPayloads.clear(); // ignore the create push

        await repoWithSync.updateProfile(
          id: created.id,
          displayName: 'Bobby',
          avatarIndex: 5,
        );

        expect(
          facade.capturedPayloads,
          hasLength(1),
          reason: 'pushLearnerProfile should have been called once on update',
        );

        final payload = facade.capturedPayloads.first;
        final decoded = codec.decode(payload);

        expect(
          decoded,
          isNotNull,
          reason:
              'LearnerProfileCodec.decode() must not return null on update payload',
        );
        expect(decoded!.profileId, equals(created.id));
        expect(decoded.displayName, equals('Bobby'));
        expect(decoded.avatarIndex, equals(5));
      });
    },
  );
}

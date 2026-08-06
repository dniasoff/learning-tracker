import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/codec/learner_profile_codec.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
import 'package:learning_tracker/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_database.dart';

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

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

/// [SyncWriteFacade] whose [pushLearnerProfile] always fails the way a
/// tutor-routed [TutoredWriteRouter] does on a Cloud Function error — used by
/// the AUD-profiles-02 regression group below. All other operations are
/// no-ops; the test only exercises the profile push.
class _TutorRoutedFailingFacade implements SyncWriteFacade {
  @override
  Future<void> pushLearnerProfile(Map<String, dynamic> profile) async {
    throw const TutorWriteException(
      'permission denied',
      code: 'permission-denied',
    );
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

/// [SyncWriteFacade] whose [pushLearnerProfile] always fails with a plain
/// (non-tutor-routed) exception — used by the AUD-profiles-16 regression
/// group below to exercise the generic offline-first "swallow but log"
/// catch branch (as opposed to [_TutorRoutedFailingFacade]'s
/// `TutorWriteException`, which takes the separate rethrow branch). All
/// other operations are no-ops; the test only exercises the profile push.
class _GenericFailingFacade implements SyncWriteFacade {
  @override
  Future<void> pushLearnerProfile(Map<String, dynamic> profile) async {
    throw Exception('simulated cloud push failure');
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

    test(
      'deleteProfile succeeds when the profile owns a track with a '
      'curriculum_scope and study_day_config (FK ordering regression)',
      () async {
        // Regression: curriculum_scopes and study_day_configs hold a
        // non-nullable (RESTRICT) FK to curriculum_tracks. If the delete
        // transaction removes curriculum_tracks before those children, SQLite
        // raises FOREIGN KEY constraint failed (787), the transaction rolls
        // back, and the profile is never deleted — the user just sees the
        // confirm dialog dismiss with nothing happening. Production runs with
        // PRAGMA foreign_keys = ON, so this must hold here too.
        final now = DateTimeFactory.nowUtc();
        await repo.createProfile(
          accountId: 1,
          displayName: 'Keeper',
          mode: 'adult',
        );
        final profile = await repo.createProfile(
          accountId: 1,
          displayName: 'Has Track',
          mode: 'child',
        );

        final trackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: profile.id,
                curriculumId: 'mishnayos',
                stateChangedAt: now,
                activatedAt: now,
              ),
            );
        await db
            .into(db.curriculumScopes)
            .insert(
              CurriculumScopesCompanion.insert(
                profileId: profile.id,
                curriculumId: 'mishnayos',
                trackId: trackId,
                scopeLevel: 1,
                scopeValue: 'Seder Zeraim',
                createdAt: now,
              ),
            );
        await db
            .into(db.studyDayConfigs)
            .insert(
              StudyDayConfigsCompanion.insert(
                profileId: profile.id,
                curriculumId: 'mishnayos',
                trackId: trackId,
                dayOfWeek: 1,
                updatedAt: now,
              ),
            );

        await repo.deleteProfile(profile.id);

        expect(await repo.getProfileById(profile.id), isNull);
        // The track and its FK-bearing children are gone too.
        final tracks = await (db.select(
          db.curriculumTracks,
        )..where((t) => t.profileId.equals(profile.id))).get();
        expect(tracks, isEmpty);
        final scopes = await (db.select(
          db.curriculumScopes,
        )..where((t) => t.profileId.equals(profile.id))).get();
        expect(scopes, isEmpty);
        final studyDays = await (db.select(
          db.studyDayConfigs,
        )..where((t) => t.profileId.equals(profile.id))).get();
        expect(studyDays, isEmpty);
      },
    );

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

  // ── BUG D1: ensureDefaultProfile self-heal ─────────────────────────────────
  //
  // Crux of the bug: a signed-in account had ZERO rows in `learner_profiles`,
  // yet an orphaned track existed at `profile_id = 0` (curriculum_tracks has no
  // FK so the row was physically present). Any `stage_definitions` insert at
  // profile 0 then fails with SqliteException(787). `ensureDefaultProfile` must
  // create a real profile, adopt the orphaned profile_id=0 rows, and leave the
  // DB in a state where a stage_definitions insert succeeds.
  group('ensureDefaultProfile (BUG D1)', () {
    test('no-op when the account already has a profile', () async {
      final existing = await repo.createProfile(
        accountId: 1,
        displayName: 'Existing',
        mode: 'adult',
      );

      final healedId = await repo.ensureDefaultProfile(
        accountId: 1,
        defaultDisplayName: 'Ignored',
      );

      expect(healedId, existing.id);
      expect(await repo.countProfilesForAccount(1), 1);
    });

    test('creates a default adult profile, adopts the orphaned profile_id=0 '
        'track, and makes a stage_definitions insert succeed', () async {
      final now = DateTimeFactory.nowUtc();

      // Simulate the broken state: a track was created while no profile
      // existed, so it sits at profile_id = 0.
      final orphanTrackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 0,
              curriculumId: 'mishnayos',
              stateChangedAt: now,
              activatedAt: now,
            ),
          );

      // Pre-condition: account owns no profile.
      expect(await repo.countProfilesForAccount(1), 0);

      final healedId = await repo.ensureDefaultProfile(
        accountId: 1,
        defaultDisplayName: 'Daniel',
      );

      // A real, non-zero profile now exists for the account.
      expect(healedId, isPositive);
      expect(healedId, isNot(0));
      expect(await repo.countProfilesForAccount(1), 1);
      final healed = await repo.getProfileById(healedId);
      expect(healed, isNotNull);
      expect(healed!.mode, 'adult');
      expect(healed.displayName, 'Daniel');

      // The orphaned profile_id=0 track was re-parented onto the new profile.
      final adoptedTrack = await (db.select(
        db.curriculumTracks,
      )..where((t) => t.id.equals(orphanTrackId))).getSingle();
      expect(adoptedTrack.profileId, healedId);

      // The original failing operation now succeeds: a stage_definitions
      // insert under the healed (non-zero) profile id no longer FK-fails.
      final stageId = await db
          .into(db.stageDefinitions)
          .insert(
            StageDefinitionsCompanion.insert(
              profileId: healedId,
              curriculumId: 'mishnayos',
              trackId: orphanTrackId,
              stageOrder: 1,
              stageName: 'לימוד',
            ),
          );
      expect(stageId, isPositive);
    });
  });

  // ── AUD-profiles-02: tutor-routed pushLearnerProfile failures must not be
  // swallowed — see profile_edit_delete_actions.dart's `on TutorWriteException`
  // handler, which was unreachable while ProfileRepositoryImpl caught every
  // pushLearnerProfile failure with a blanket `catch (_) {}`.

  group(
    'AUD-profiles-02 — TutorWriteException from pushLearnerProfile propagates',
    () {
      late UserDatabase db;
      late _TutorRoutedFailingFacade facade;
      late ProfileRepositoryImpl repoWithTutorRouter;

      setUp(() async {
        db = createTestDatabase();
        facade = _TutorRoutedFailingFacade();
        repoWithTutorRouter = ProfileRepositoryImpl(db, syncEngine: facade);
        await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                email: 'tutor-routed@test.com',
                tier: 'cloudBorn',
                displayName: 'Tutor-Routed Account',
                createdAt: DateTimeFactory.nowUtc(),
                updatedAt: DateTimeFactory.nowUtc(),
              ),
            );
      });

      tearDown(() => db.close());

      test(
        'updateProfile propagates TutorWriteException instead of swallowing it',
        () async {
          // Seed the profile directly (bypassing createProfile, which would
          // also hit the tutor-routed facade and throw on the initial push).
          final now = DateTimeFactory.nowUtc();
          final id = await db
              .into(db.learnerProfiles)
              .insert(
                LearnerProfilesCompanion.insert(
                  accountId: 1,
                  displayName: 'Original',
                  mode: 'child',
                  createdAt: now,
                  updatedAt: now,
                ),
              );

          // `expectLater` + `await` (not the sync `expect(closure, ...)`
          // idiom) so the update's local write has actually completed before
          // the follow-up read below — otherwise the read can race ahead of
          // the still-pending `updateProfile` future.
          await expectLater(
            repoWithTutorRouter.updateProfile(id: id, displayName: 'Renamed'),
            throwsA(isA<TutorWriteException>()),
            reason:
                'a tutor-routed push failure must reach the caller so '
                'editProfileFlow\'s TutorWriteException handler can surface '
                'a snackbar — silently swallowing it strands the tutor with '
                'no feedback and a local mirror that disagrees with the '
                'owner\'s actual Firestore profile',
          );

          // Local write still stands (offline-first) even though the push
          // failed — only the push failure must be surfaced, not the local
          // mutation rolled back.
          final local = await repoWithTutorRouter.getProfileById(id);
          expect(local!.displayName, 'Renamed');
        },
      );

      test(
        'createProfile propagates TutorWriteException instead of swallowing it',
        () async {
          await expectLater(
            repoWithTutorRouter.createProfile(
              accountId: 1,
              displayName: 'New Learner',
              mode: 'child',
            ),
            throwsA(isA<TutorWriteException>()),
          );
        },
      );
    },
  );

  // ── AUD-profiles-16 (EH-3): non-fatal cloud-push catch blocks must log ────
  //
  // createProfile/updateProfile/ensureDefaultProfile all swallow a generic
  // (non-tutor-routed) pushLearnerProfile failure as part of the
  // offline-first design — the local write must stand regardless. Previously
  // that `catch (_) { ... }` carried only a code comment and made zero
  // AppLogger call, so a real production failure pattern (e.g. outbox writes
  // silently failing on a subset of devices) left no telemetry trail. These
  // three tests assert the offline-first behaviour is preserved (the
  // operation still succeeds) AND that the failure is now logged.

  group('AUD-profiles-16 — log-less catch: cloud push failures now log', () {
    late UserDatabase db;
    late _GenericFailingFacade facade;
    late ProfileRepositoryImpl repoWithFailingPush;

    setUp(() async {
      db = createTestDatabase();
      facade = _GenericFailingFacade();
      repoWithFailingPush = ProfileRepositoryImpl(db, syncEngine: facade);
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'push-fail@test.com',
              tier: 'cloudBorn',
              displayName: 'Push-Fail Account',
              createdAt: DateTimeFactory.nowUtc(),
              updatedAt: DateTimeFactory.nowUtc(),
            ),
          );
      // Deliberately NOT calling AppLogger.init() here: ProfileRepositoryImpl
      // caches `final _log = AppLogger.instance;` as a top-level field, bound
      // once on the file's first access within this test process — an
      // AppLogger.init() call afterwards (as stage_definition_codec_test.dart
      // does, since its call site reads `AppLogger.instance` fresh on every
      // invocation instead of caching it) would swap in a new Talker that
      // `_log` never picks up, and history assertions below would silently
      // read the wrong (empty) Talker. Instead, each assertion below matches
      // on a marker string unique to this finding, so accumulated history
      // from earlier tests in this file is harmless.
    });

    tearDown(() => db.close());

    test('createProfile still succeeds offline-first AND logs the cloud push '
        'failure via AppLogger', () async {
      final created = await repoWithFailingPush.createProfile(
        accountId: 1,
        displayName: 'Offline Kid',
        mode: 'child',
      );

      expect(created.displayName, 'Offline Kid');

      final history = AppLogger.instance.talker.history
          .map((e) => e.generateTextMessage())
          .toList();
      expect(
        history.any((m) => m.contains('profile_repo_create_cloud_push_failed')),
        isTrue,
        reason:
            'A non-fatal cloud push failure must still be logged via '
            'AppLogger so it leaves a diagnostic trail (EH-3, '
            'AUD-profiles-16). Talker history: $history',
      );
    });

    test('updateProfile still succeeds offline-first AND logs the cloud push '
        'failure via AppLogger', () async {
      final now = DateTimeFactory.nowUtc();
      final id = await db
          .into(db.learnerProfiles)
          .insert(
            LearnerProfilesCompanion.insert(
              accountId: 1,
              displayName: 'Original',
              mode: 'adult',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final updated = await repoWithFailingPush.updateProfile(
        id: id,
        displayName: 'Renamed',
      );
      expect(updated.displayName, 'Renamed');

      final history = AppLogger.instance.talker.history
          .map((e) => e.generateTextMessage())
          .toList();
      expect(
        history.any((m) => m.contains('profile_repo_update_cloud_push_failed')),
        isTrue,
        reason:
            'A non-fatal cloud push failure must still be logged via '
            'AppLogger so it leaves a diagnostic trail (EH-3, '
            'AUD-profiles-16). Talker history: $history',
      );
    });

    test('ensureDefaultProfile still succeeds offline-first AND logs the cloud '
        'push failure via AppLogger', () async {
      final healedId = await repoWithFailingPush.ensureDefaultProfile(
        accountId: 1,
        defaultDisplayName: 'Healed',
      );
      expect(healedId, isPositive);

      final history = AppLogger.instance.talker.history
          .map((e) => e.generateTextMessage())
          .toList();
      expect(
        history.any((m) => m.contains('profile_self_heal_cloud_push_failed')),
        isTrue,
        reason:
            'A non-fatal cloud push failure must still be logged via '
            'AppLogger so it leaves a diagnostic trail (EH-3, '
            'AUD-profiles-16). Talker history: $history',
      );
    });
  });

  group('FirestoreProfileRepositoryAdapter', () {
    const uid = 'uid-profiles-1';

    AccountFirebaseHandles handles(FakeFirebaseFirestore firestore) {
      return AccountFirebaseHandles(
        app: MockFirebaseApp(),
        firestore: firestore,
        auth: MockFirebaseAuthHandle(),
        uid: uid,
      );
    }

    // Constructing FirestoreProfileRepositoryAdapter requires a Ref
    // (Riverpod's Ref is sealed — it can only come from inside a provider
    // callback), so tests obtain one the same way production does: read a
    // throwaway Provider that builds the adapter from the container's ref.
    // Mirrors FirestoreBookmarkRepositoryAdapter's test helper
    // (bookmark_repository_impl_test.dart).
    FirestoreProfileRepositoryAdapter buildAdapter(
      ProviderContainer container,
      ProfileRepositoryImpl driftRepository,
    ) {
      final adapterProvider = Provider<FirestoreProfileRepositoryAdapter>(
        (ref) => FirestoreProfileRepositoryAdapter(
          ref: ref,
          driftRepository: driftRepository,
        ),
      );
      return container.read(adapterProvider);
    }

    group('not ready (no active account)', () {
      late UserDatabase localDb;
      late FirestoreProfileRepositoryAdapter adapter;
      late ProviderContainer container;

      setUp(() async {
        localDb = createTestDatabase();
        await localDb
            .into(localDb.accounts)
            .insert(
              AccountsCompanion.insert(
                email: 'not-ready@test.com',
                tier: 'localBorn',
                displayName: 'Test Account',
                createdAt: DateTimeFactory.nowUtc(),
                updatedAt: DateTimeFactory.nowUtc(),
              ),
            );
        container = ProviderContainer();
        adapter = buildAdapter(container, ProfileRepositoryImpl(localDb));
      });

      tearDown(() async {
        container.dispose();
        await localDb.close();
      });

      test('createProfile still succeeds locally (offline-first) and leaves '
          'activeProfileDocIdProvider unset', () async {
        final profile = await adapter.createProfile(
          accountId: 1,
          displayName: 'Yosef',
          mode: 'adult',
        );

        expect(profile.displayName, 'Yosef');
        expect(container.read(activeProfileDocIdProvider), isNull);
      });

      test('ensureDefaultProfile still self-heals locally and leaves '
          'activeProfileDocIdProvider unset', () async {
        final id = await adapter.ensureDefaultProfile(
          accountId: 1,
          defaultDisplayName: 'Healed',
        );

        expect(id, isPositive);
        expect(container.read(activeProfileDocIdProvider), isNull);
      });
    });

    group('ready (active account)', () {
      late UserDatabase localDb;
      late FakeFirebaseFirestore firestore;
      late ProviderContainer container;
      late FirestoreProfileRepositoryAdapter adapter;

      setUp(() async {
        localDb = createTestDatabase();
        await localDb
            .into(localDb.accounts)
            .insert(
              AccountsCompanion.insert(
                email: 'ready@test.com',
                tier: 'localBorn',
                displayName: 'Test Account',
                createdAt: DateTimeFactory.nowUtc(),
                updatedAt: DateTimeFactory.nowUtc(),
              ),
            );
        firestore = FakeFirebaseFirestore();
        container = ProviderContainer(
          overrides: [
            activeAccountFirebaseProvider.overrideWith(
              (ref) async => handles(firestore),
            ),
          ],
        );
        adapter = buildAdapter(container, ProfileRepositoryImpl(localDb));
      });

      tearDown(() async {
        container.dispose();
        await localDb.close();
      });

      test('createProfile mints a Firestore doc, activates it, and '
          'PERSISTS the ULID onto the Drift row (survives beyond this '
          'adapter instance)', () async {
        final profile = await adapter.createProfile(
          accountId: 1,
          displayName: 'Devorah',
          mode: 'adult',
        );

        final activeUlid = container.read(activeProfileDocIdProvider);
        expect(activeUlid, isNotNull);
        // The returned model already carries it...
        expect(profile.ulid, activeUlid);
        // ...and so does a completely fresh read of the SAME Drift row,
        // proving the pairing is durable, not held only in memory.
        final reread = await ProfileRepositoryImpl(
          localDb,
        ).getProfileById(profile.id);
        expect(reread?.ulid, activeUlid);

        final doc = await firestore
            .collection('users')
            .doc(uid)
            .collection('learner_profiles')
            .doc(activeUlid)
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['display_name'], 'Devorah');
      });

      test('a profile minted in one adapter instance still resolves its ULID '
          'through a BRAND NEW adapter over the same Drift database — the '
          'restart case the persisted column exists for', () async {
        final created = await adapter.createProfile(
          accountId: 1,
          displayName: 'Restart Case',
          mode: 'adult',
        );
        final mintedUlid = created.ulid;
        expect(mintedUlid, isNotNull);

        // Simulate an app restart: a fresh Ref/container (so nothing
        // in-memory survives) wrapping a NEW ProfileRepositoryImpl, but
        // over the SAME underlying Drift database file/connection.
        final restartContainer = ProviderContainer(
          overrides: [
            activeAccountFirebaseProvider.overrideWith(
              (ref) async => handles(firestore),
            ),
          ],
        );
        addTearDown(restartContainer.dispose);
        final restartedAdapter = buildAdapter(
          restartContainer,
          ProfileRepositoryImpl(localDb),
        );

        final reread = await restartedAdapter.getProfileById(created.id);
        expect(
          reread?.ulid,
          mintedUlid,
          reason:
              'ulid is read from the Drift column, not an in-memory '
              'cache scoped to the adapter/container that minted it',
        );
      });

      test('ensureDefaultProfile mints exactly one Firestore doc on the '
          'self-heal branch, and none on a subsequent already-has-a-profile '
          'call (no duplicate document)', () async {
        final firstId = await adapter.ensureDefaultProfile(
          accountId: 1,
          defaultDisplayName: 'Healed',
        );
        final healed = await adapter.getProfileById(firstId);
        expect(healed?.ulid, isNotNull);

        final collection = firestore
            .collection('users')
            .doc(uid)
            .collection('learner_profiles');
        expect((await collection.get()).docs, hasLength(1));

        // Account already has a profile now — the fast (no-op) branch of
        // ensureDefaultProfile must NOT mint a second Firestore document,
        // and must NOT backfill the existing profile's ulid either (that's
        // updateProfile's job — see the next group).
        final secondId = await adapter.ensureDefaultProfile(
          accountId: 1,
          defaultDisplayName: 'Healed',
        );
        expect(secondId, firstId);
        expect((await collection.get()).docs, hasLength(1));
      });

      test('ensureDefaultProfile fast path (account already has a profile) '
          'does NOT touch that profile\'s missing ulid', () async {
        // Simulate a profile that predates the P2-2 eager-mint policy:
        // inserted directly (bypassing createProfile), so ulid is NULL.
        final preExistingId = await localDb.profileDao.insertProfile(
          LearnerProfilesCompanion.insert(
            accountId: 1,
            displayName: 'Pre-existing',
            mode: 'adult',
            createdAt: DateTimeFactory.nowUtc(),
            updatedAt: DateTimeFactory.nowUtc(),
          ),
        );

        final id = await adapter.ensureDefaultProfile(
          accountId: 1,
          defaultDisplayName: 'unused — fast path',
        );

        expect(id, preExistingId);
        final profile = await adapter.getProfileById(id);
        expect(
          profile?.ulid,
          isNull,
          reason:
              'the fast (no-op) path never mints — see the class doc '
              'comment, "Identity policy": P2-2 mints eagerly at creation '
              'only, there is no lazy backfill path left at all',
        );
      });

      test('updateProfile does NOT backfill a missing ulid for a pre-P2-2 '
          'profile — the lazy backfill path is deleted (P2-2)', () async {
        // Simulate a profile that predates the P2-2 eager-mint policy:
        // inserted directly (bypassing createProfile), so ulid is NULL,
        // exactly like every profile that existed before schema v38
        // shipped, before this adapter shipped, or before P2-2 made
        // minting eager.
        final preExistingId = await localDb.profileDao.insertProfile(
          LearnerProfilesCompanion.insert(
            accountId: 1,
            displayName: 'Old Name',
            mode: 'adult',
            createdAt: DateTimeFactory.nowUtc(),
            updatedAt: DateTimeFactory.nowUtc(),
          ),
        );
        expect((await adapter.getProfileById(preExistingId))?.ulid, isNull);

        final updated = await adapter.updateProfile(
          id: preExistingId,
          displayName: 'New Name',
        );

        // P2-2 deleted the lazy on-edit backfill (see
        // FirestoreProfileRepositoryAdapter.updateProfile): under the
        // greenfield ruling a pre-existing null ulid is never healed by
        // this method anymore — wipe-and-reseed is the remedy.
        expect(updated.displayName, 'New Name');
        expect(updated.ulid, isNull);
        expect(container.read(activeProfileDocIdProvider), isNull);

        final collection = firestore
            .collection('users')
            .doc(uid)
            .collection('learner_profiles');
        expect((await collection.get()).docs, isEmpty);
      });

      test('updateProfile does NOT mint a second Firestore doc for a profile '
          'that already has a ulid', () async {
        final created = await adapter.createProfile(
          accountId: 1,
          displayName: 'Already Migrated',
          mode: 'adult',
        );
        final collection = firestore
            .collection('users')
            .doc(uid)
            .collection('learner_profiles');
        expect((await collection.get()).docs, hasLength(1));

        final updated = await adapter.updateProfile(
          id: created.id,
          displayName: 'Renamed',
        );

        expect(updated.ulid, created.ulid);
        expect((await collection.get()).docs, hasLength(1));
      });

      test('deleteProfile delegates through to the Drift row (its ulid, '
          'if any, is gone along with the row itself)', () async {
        final first = await adapter.createProfile(
          accountId: 1,
          displayName: 'A',
          mode: 'adult',
        );
        // A second profile so deleting the first doesn't trip
        // LastProfileException (deleteProfile refuses to leave the account
        // with zero profiles by default) — irrelevant to what this test
        // actually checks.
        await adapter.createProfile(
          accountId: 1,
          displayName: 'B',
          mode: 'adult',
        );
        expect(first.ulid, isNotNull);

        await adapter.deleteProfile(first.id);

        expect(await adapter.getProfileById(first.id), isNull);
      });
    });
  });
}

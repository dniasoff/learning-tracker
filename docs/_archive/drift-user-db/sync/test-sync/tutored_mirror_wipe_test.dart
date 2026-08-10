/// T5.lifecycle regression tests — mirror wipe on revoke/resign/sign-out.
///
/// Three triggers, three cases:
///   (T) Revoke/resign — wipeMirrorForGrant deletes the synthetic profile and
///       ALL child rows (via FK cascade); tutor's own profiles are untouched.
///   (S) Sign-out — wipeAllMirrors deletes every tutored mirror for the account;
///       tutor's own profiles and a mirror for a DIFFERENT account are untouched.
///   (P) Permission-denied pull — TutoredPullService auto-wipes the mirror when
///       Firestore returns permission-denied (grant revoked server-side).
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/exceptions/firestore_permission_denied_exception.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/pull_pipeline.dart';
import 'package:learning_tracker/core/sync/tutored_mirror_wipe_service.dart';
import 'package:learning_tracker/core/sync/tutored_pull_service.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

import '../helpers/no_op_firestore_gateway.dart';
import '../helpers/test_database.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<int> _seedAccount(
  UserDatabase db, {
  String email = 'tutor@example.com',
}) async {
  return db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: email,
          tier: 'localBorn',
          displayName: 'Tutor',
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
}

Future<int> _seedOwnProfile(UserDatabase db, int accountId) async {
  return db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion.insert(
          accountId: accountId,
          displayName: 'Own Profile',
          mode: 'adult',
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
}

Future<int> _seedTutoredMirror(
  UserDatabase db, {
  required int accountId,
  required String grantId,
  String parentUid = 'parent-uid',
  String remoteProfileId = 'remote-child',
}) async {
  return db.profileDao.upsertTutoredProfile(
    accountId: accountId,
    parentUid: parentUid,
    remoteChildProfileId: remoteProfileId,
    grantId: grantId,
    displayName: 'Child',
    mode: 'child',
    now: DateTimeFactory.nowUtc(),
  );
}

// Inserts a completion_events row keyed to [profileId] so we can verify cascade.
Future<void> _seedCompletionEvent(UserDatabase db, int profileId) async {
  await db
      .into(db.completionEvents)
      .insert(
        CompletionEventsCompanion.insert(
          profileId: profileId,
          sefariaRef: 'Berakhot.1.1',
          stageId: 1,
          trackType: 'daily',
          curriculumId: 'test',
          eventTimestamp: DateTimeFactory.nowUtc(),
        ),
      );
}

// Count completion_events rows for a profile.
Future<int> _countCompletionEvents(UserDatabase db, int profileId) async {
  final count = db.completionEvents.id.count();
  final query = db.selectOnly(db.completionEvents)
    ..addColumns([count])
    ..where(db.completionEvents.profileId.equals(profileId));
  final row = await query.getSingle();
  return row.read(count) ?? 0;
}

// ---------------------------------------------------------------------------
// AUD-core-database-01 — the 6 tables with no FK `ON DELETE CASCADE` on
// `profileId` (curriculum_tracks, daily_plans, outbox, point_configs,
// profile_programs, study_day_configs). Seeds one row per table for
// [profileId] so wipe regression tests can assert they are actually purged
// instead of silently surviving a mirror wipe.
// ---------------------------------------------------------------------------

/// Seeds one row in each of the 6 non-cascading tables for [profileId].
/// Returns the `curriculum_tracks.id` created, since point_configs and
/// study_day_configs hold a non-nullable FK to it.
Future<int> _seedNonCascadingRows(UserDatabase db, int profileId) async {
  final now = DateTimeFactory.nowUtc();
  final trackId = await db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: 'test-curriculum',
          stateChangedAt: now,
          activatedAt: now,
        ),
      );
  await db
      .into(db.dailyPlans)
      .insert(
        DailyPlansCompanion.insert(
          profileId: profileId,
          curriculumId: 'test-curriculum',
          planDate: now,
          sefariaRef: 'Berakhot.1.1',
          stageOrder: 1,
          stageDefinitionId: 1,
          trackId: trackId,
          priority: 'overdueChazara',
          createdAt: now,
        ),
      );
  await db
      .into(db.outbox)
      .insert(
        OutboxCompanion.insert(
          profileId: profileId,
          entityKind: 'completion',
          entityKey: 'test-entity-key',
          payload: '{}',
          createdAt: now,
        ),
      );
  await db
      .into(db.pointConfigs)
      .insert(
        PointConfigsCompanion.insert(
          profileId: profileId,
          curriculumId: 'test-curriculum',
          trackId: trackId,
          stageOrder: 1,
          points: 1,
        ),
      );
  await db
      .into(db.profilePrograms)
      .insert(
        ProfileProgramsCompanion.insert(
          profileId: profileId,
          curriculumType: 'test-curriculum',
          programId: 1,
        ),
      );
  await db
      .into(db.studyDayConfigs)
      .insert(
        StudyDayConfigsCompanion.insert(
          profileId: profileId,
          curriculumId: 'test-curriculum',
          trackId: trackId,
          dayOfWeek: 1,
          updatedAt: now,
        ),
      );
  return trackId;
}

Future<int> _countCurriculumTracks(UserDatabase db, int profileId) async {
  final count = db.curriculumTracks.id.count();
  final query = db.selectOnly(db.curriculumTracks)
    ..addColumns([count])
    ..where(db.curriculumTracks.profileId.equals(profileId));
  return (await query.getSingle()).read(count) ?? 0;
}

Future<int> _countDailyPlans(UserDatabase db, int profileId) async {
  final count = db.dailyPlans.id.count();
  final query = db.selectOnly(db.dailyPlans)
    ..addColumns([count])
    ..where(db.dailyPlans.profileId.equals(profileId));
  return (await query.getSingle()).read(count) ?? 0;
}

Future<int> _countOutbox(UserDatabase db, int profileId) async {
  final count = db.outbox.id.count();
  final query = db.selectOnly(db.outbox)
    ..addColumns([count])
    ..where(db.outbox.profileId.equals(profileId));
  return (await query.getSingle()).read(count) ?? 0;
}

Future<int> _countPointConfigs(UserDatabase db, int profileId) async {
  final count = db.pointConfigs.id.count();
  final query = db.selectOnly(db.pointConfigs)
    ..addColumns([count])
    ..where(db.pointConfigs.profileId.equals(profileId));
  return (await query.getSingle()).read(count) ?? 0;
}

Future<int> _countProfilePrograms(UserDatabase db, int profileId) async {
  final count = db.profilePrograms.id.count();
  final query = db.selectOnly(db.profilePrograms)
    ..addColumns([count])
    ..where(db.profilePrograms.profileId.equals(profileId));
  return (await query.getSingle()).read(count) ?? 0;
}

Future<int> _countStudyDayConfigs(UserDatabase db, int profileId) async {
  final count = db.studyDayConfigs.profileId.count();
  final query = db.selectOnly(db.studyDayConfigs)
    ..addColumns([count])
    ..where(db.studyDayConfigs.profileId.equals(profileId));
  return (await query.getSingle()).read(count) ?? 0;
}

/// Asserts all 6 non-cascading tables have zero rows for [profileId].
Future<void> _expectNonCascadingRowsGone(UserDatabase db, int profileId) async {
  expect(
    await _countCurriculumTracks(db, profileId),
    0,
    reason: 'curriculum_tracks rows must be purged on mirror wipe',
  );
  expect(
    await _countDailyPlans(db, profileId),
    0,
    reason: 'daily_plans rows must be purged on mirror wipe',
  );
  expect(
    await _countOutbox(db, profileId),
    0,
    reason: 'outbox rows must be purged on mirror wipe',
  );
  expect(
    await _countPointConfigs(db, profileId),
    0,
    reason: 'point_configs rows must be purged on mirror wipe',
  );
  expect(
    await _countProfilePrograms(db, profileId),
    0,
    reason: 'profile_programs rows must be purged on mirror wipe',
  );
  expect(
    await _countStudyDayConfigs(db, profileId),
    0,
    reason: 'study_day_configs rows must be purged on mirror wipe',
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _NoOpDispatcher implements MergeDispatcher {
  @override
  Future<MergeOutcome> dispatch({
    required int profileId,
    required String kind,
    required List<Map<String, dynamic>> rows,
  }) async => MergeOutcome.continueNext;
}

/// Shared base for [_RevokedGateway] and [_ErrorGateway] (AUD-t-cross-19):
/// both fakes model the same pull-only [TutoredPullService] surface, where
/// every method other than the two child-scoped fetches is either a genuine
/// no-op (this test's pull path never calls it — [NoOpFirestoreGateway]
/// throws if it's wrong about that) or, for the four "own-data" fetch
/// methods below, a guard that fails loudly if [TutoredPullService] ever
/// strays onto the tutor's own-profile path while pulling a tutored mirror.
/// Only `fetchChildPage`/`fetchChildDocument` differ between the two
/// subclasses — see each for its distinct failure mode.
abstract class _PullGuardGateway extends NoOpFirestoreGateway {
  // Own-data stubs — should not be called.
  @override
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async => throw StateError('must not call own-data path');
  @override
  Future<Map<String, dynamic>?> fetchDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) async => throw StateError('must not call own-data path');
  @override
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async =>
      throw StateError('must not call own-data path');
  @override
  Future<List<Map<String, dynamic>>> fetchAll({
    required int profileId,
    required String collection,
  }) async => throw StateError('must not call own-data path');
}

/// Gateway that throws [FirestorePermissionDeniedException] on every
/// child-page fetch — simulates a revoked grant.
class _RevokedGateway extends _PullGuardGateway {
  @override
  Future<FirestorePage> fetchChildPage({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async => throw const FirestorePermissionDeniedException(
    'permission-denied',
    collection: 'completions',
  );

  @override
  Future<Map<String, dynamic>?> fetchChildDocument({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required String docId,
  }) async => throw const FirestorePermissionDeniedException(
    'permission-denied',
    collection: 'completions',
  );
}

/// Gateway that throws a generic (non-permission-denied) error on every
/// child-page fetch — the pull must NOT treat this as a revocation.
class _ErrorGateway extends _PullGuardGateway {
  @override
  Future<FirestorePage> fetchChildPage({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async => throw Exception('network error');

  @override
  Future<Map<String, dynamic>?> fetchChildDocument({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required String docId,
  }) async => throw Exception('network error');
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late UserDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  group('T5.lifecycle — mirror wipe', () {
    // ── (T) Revoke / resign trigger ────────────────────────────────────────

    group('wipeMirrorForGrant (revoke/resign)', () {
      test(
        'deletes the tutored profile row and cascades to child rows',
        () async {
          final accountId = await _seedAccount(db);
          final ownId = await _seedOwnProfile(db, accountId);
          final mirrorId = await _seedTutoredMirror(
            db,
            accountId: accountId,
            grantId: 'grant-001',
          );
          await _seedCompletionEvent(db, mirrorId);

          // Sanity: mirror exists and has a child row.
          expect(await db.profileDao.getProfileById(mirrorId), isNotNull);
          expect(await _countCompletionEvents(db, mirrorId), 1);

          final svc = TutoredMirrorWipeService(profileDao: db.profileDao);
          await svc.wipeMirrorForGrant('grant-001');

          // Mirror row gone.
          expect(await db.profileDao.getProfileById(mirrorId), isNull);
          // Child rows cascaded.
          expect(await _countCompletionEvents(db, mirrorId), 0);
          // Own profile untouched.
          expect(await db.profileDao.getProfileById(ownId), isNotNull);
        },
      );

      test('idempotent — safe to call when no mirror exists', () async {
        final accountId = await _seedAccount(db);
        await _seedOwnProfile(db, accountId);

        final svc = TutoredMirrorWipeService(profileDao: db.profileDao);
        // Should not throw.
        await svc.wipeMirrorForGrant('grant-nonexistent');
      });

      test('fires onWipe callback with the grantId', () async {
        final accountId = await _seedAccount(db);
        await _seedTutoredMirror(db, accountId: accountId, grantId: 'grant-cb');

        final wiped = <String>[];
        final svc = TutoredMirrorWipeService(
          profileDao: db.profileDao,
          onWipe: wiped.add,
        );
        await svc.wipeMirrorForGrant('grant-cb');

        expect(wiped, ['grant-cb']);
      });

      test(
        'does NOT fire onWipe when no mirror exists for the grantId',
        () async {
          final accountId = await _seedAccount(db);
          await _seedOwnProfile(db, accountId);

          final wiped = <String>[];
          final svc = TutoredMirrorWipeService(
            profileDao: db.profileDao,
            onWipe: wiped.add,
          );
          await svc.wipeMirrorForGrant('grant-missing');

          // onWipe must NOT fire for a non-existent mirror.
          expect(wiped, isEmpty);
        },
      );

      test("tutor's own profiles are untouched after wipe", () async {
        final accountId = await _seedAccount(db);
        final ownId = await _seedOwnProfile(db, accountId);
        await _seedTutoredMirror(
          db,
          accountId: accountId,
          grantId: 'grant-002',
        );

        final svc = TutoredMirrorWipeService(profileDao: db.profileDao);
        await svc.wipeMirrorForGrant('grant-002');

        final own = await db.profileDao.getProfileById(ownId);
        expect(own, isNotNull);
        expect(own!.isTutored, isFalse);
      });

      // AUD-core-database-01 — curriculum_tracks, daily_plans, outbox,
      // point_configs, profile_programs, study_day_configs carry NO FK
      // `ON DELETE CASCADE` on profileId, unlike completion_events/bookmarks/
      // etc. above. Without an explicit compensating delete, a revoked
      // tutoring grant leaves the child's mirrored curriculum/schedule data
      // on the tutor's device forever.
      test(
        'purges the 6 non-cascading tables (curriculum_tracks, daily_plans, '
        'outbox, point_configs, profile_programs, study_day_configs)',
        () async {
          final accountId = await _seedAccount(db);
          await _seedOwnProfile(db, accountId);
          final mirrorId = await _seedTutoredMirror(
            db,
            accountId: accountId,
            grantId: 'grant-noncascade',
          );
          await _seedNonCascadingRows(db, mirrorId);

          // Sanity: rows exist before wipe.
          expect(await _countCurriculumTracks(db, mirrorId), 1);
          expect(await _countDailyPlans(db, mirrorId), 1);
          expect(await _countOutbox(db, mirrorId), 1);
          expect(await _countPointConfigs(db, mirrorId), 1);
          expect(await _countProfilePrograms(db, mirrorId), 1);
          expect(await _countStudyDayConfigs(db, mirrorId), 1);

          final svc = TutoredMirrorWipeService(profileDao: db.profileDao);
          await svc.wipeMirrorForGrant('grant-noncascade');

          await _expectNonCascadingRowsGone(db, mirrorId);
        },
      );
    });

    // ── (S) Sign-out trigger ───────────────────────────────────────────────

    group('wipeAllMirrors (sign-out)', () {
      test(
        'deletes all tutored mirrors for the account and their child rows',
        () async {
          final accountId = await _seedAccount(db);
          await _seedOwnProfile(db, accountId);
          final mirror1 = await _seedTutoredMirror(
            db,
            accountId: accountId,
            grantId: 'grant-A',
            parentUid: 'parent-1',
            remoteProfileId: 'child-1',
          );
          final mirror2 = await _seedTutoredMirror(
            db,
            accountId: accountId,
            grantId: 'grant-B',
            parentUid: 'parent-2',
            remoteProfileId: 'child-2',
          );
          await _seedCompletionEvent(db, mirror1);
          await _seedCompletionEvent(db, mirror2);

          final svc = TutoredMirrorWipeService(profileDao: db.profileDao);
          await svc.wipeAllMirrors(accountId);

          expect(await db.profileDao.getProfileById(mirror1), isNull);
          expect(await db.profileDao.getProfileById(mirror2), isNull);
          expect(await _countCompletionEvents(db, mirror1), 0);
          expect(await _countCompletionEvents(db, mirror2), 0);
        },
      );

      test("tutor's own profiles are untouched after wipeAllMirrors", () async {
        final accountId = await _seedAccount(db);
        final ownId = await _seedOwnProfile(db, accountId);
        await _seedTutoredMirror(db, accountId: accountId, grantId: 'grant-C');

        final svc = TutoredMirrorWipeService(profileDao: db.profileDao);
        await svc.wipeAllMirrors(accountId);

        final own = await db.profileDao.getProfileById(ownId);
        expect(own, isNotNull);
        expect(own!.isTutored, isFalse);
      });

      test('mirrors for a different account are untouched', () async {
        final accountId1 = await _seedAccount(db, email: 'tutor1@example.com');
        final accountId2 = await _seedAccount(db, email: 'tutor2@example.com');

        await _seedOwnProfile(db, accountId1);
        final mirror1 = await _seedTutoredMirror(
          db,
          accountId: accountId1,
          grantId: 'grant-X',
        );
        await _seedOwnProfile(db, accountId2);
        final mirror2 = await _seedTutoredMirror(
          db,
          accountId: accountId2,
          grantId: 'grant-Y',
          parentUid: 'parent-other',
          remoteProfileId: 'child-other',
        );

        final svc = TutoredMirrorWipeService(profileDao: db.profileDao);
        await svc.wipeAllMirrors(accountId1);

        // Account 1 mirror gone.
        expect(await db.profileDao.getProfileById(mirror1), isNull);
        // Account 2 mirror intact.
        expect(await db.profileDao.getProfileById(mirror2), isNotNull);
      });

      // AUD-core-database-01 — same non-cascading-table coverage as the
      // wipeMirrorForGrant case above, but exercised through the bulk
      // sign-out path (deleteAllTutoredMirrors), which has its own delete
      // statement and must not skip the compensating cleanup.
      test(
        'purges the 6 non-cascading tables for every wiped mirror',
        () async {
          final accountId = await _seedAccount(db);
          await _seedOwnProfile(db, accountId);
          final mirror1 = await _seedTutoredMirror(
            db,
            accountId: accountId,
            grantId: 'grant-F',
            parentUid: 'parent-1',
            remoteProfileId: 'child-1',
          );
          final mirror2 = await _seedTutoredMirror(
            db,
            accountId: accountId,
            grantId: 'grant-G',
            parentUid: 'parent-2',
            remoteProfileId: 'child-2',
          );
          await _seedNonCascadingRows(db, mirror1);
          await _seedNonCascadingRows(db, mirror2);

          final svc = TutoredMirrorWipeService(profileDao: db.profileDao);
          await svc.wipeAllMirrors(accountId);

          await _expectNonCascadingRowsGone(db, mirror1);
          await _expectNonCascadingRowsGone(db, mirror2);
        },
      );

      test('fires onWipe for each deleted mirror grant', () async {
        final accountId = await _seedAccount(db);
        await _seedTutoredMirror(db, accountId: accountId, grantId: 'grant-D');
        await _seedTutoredMirror(
          db,
          accountId: accountId,
          grantId: 'grant-E',
          parentUid: 'parent-2',
          remoteProfileId: 'child-2',
        );

        final wiped = <String>[];
        final svc = TutoredMirrorWipeService(
          profileDao: db.profileDao,
          onWipe: wiped.add,
        );
        await svc.wipeAllMirrors(accountId);

        expect(wiped, containsAll(['grant-D', 'grant-E']));
        expect(wiped.length, 2);
      });
    });

    // ── (P) Permission-denied pull trigger ─────────────────────────────────

    group('TutoredPullService — permission-denied auto-wipe', () {
      test(
        'wipes mirror on permission-denied and returns permissionDenied',
        () async {
          final accountId = await _seedAccount(db);
          await _seedOwnProfile(db, accountId);

          // Pre-create the mirror row so we can verify it's wiped.
          final mirrorId = await _seedTutoredMirror(
            db,
            accountId: accountId,
            grantId: 'grant-revoked',
          );
          await _seedCompletionEvent(db, mirrorId);

          final wipeSvc = TutoredMirrorWipeService(profileDao: db.profileDao);
          final pullSvc = TutoredPullService(
            gateway: _RevokedGateway(),
            dispatcher: _NoOpDispatcher(),
            profileDao: db.profileDao,
            wipeService: wipeSvc,
          );

          final result = await pullSvc.pull(
            accountId: accountId,
            parentUid: 'parent-uid',
            remoteProfileId: 'remote-child',
            grantId: 'grant-revoked',
            childDisplayName: 'Child',
            childMode: 'child',
          );

          expect(result.result, TutoredPullResult.permissionDenied);

          // Mirror and child rows must be gone.
          expect(await db.profileDao.getProfileById(mirrorId), isNull);
          expect(await _countCompletionEvents(db, mirrorId), 0);
        },
      );

      test(
        "tutor's own profiles intact after permission-denied auto-wipe",
        () async {
          final accountId = await _seedAccount(db);
          final ownId = await _seedOwnProfile(db, accountId);

          await _seedTutoredMirror(
            db,
            accountId: accountId,
            grantId: 'grant-revoked-2',
          );

          final wipeSvc = TutoredMirrorWipeService(profileDao: db.profileDao);
          final pullSvc = TutoredPullService(
            gateway: _RevokedGateway(),
            dispatcher: _NoOpDispatcher(),
            profileDao: db.profileDao,
            wipeService: wipeSvc,
          );

          await pullSvc.pull(
            accountId: accountId,
            parentUid: 'parent-uid',
            remoteProfileId: 'remote-child',
            grantId: 'grant-revoked-2',
            childDisplayName: 'Child',
            childMode: 'child',
          );

          final own = await db.profileDao.getProfileById(ownId);
          expect(own, isNotNull);
          expect(own!.isTutored, isFalse);
        },
      );

      test('no wipe on generic error (non-permission-denied)', () async {
        // A generic error does not indicate revocation — mirror must be kept.
        // This is the non-permission-denied path; TutoredPullService only
        // wipes on FirestorePermissionDeniedException.
        final accountId = await _seedAccount(db);
        await _seedOwnProfile(db, accountId);
        final mirrorId = await _seedTutoredMirror(
          db,
          accountId: accountId,
          grantId: 'grant-error',
        );

        // Gateway that throws a generic exception (not permission-denied).
        final errorGateway = _ErrorGateway();
        final wipeSvc = TutoredMirrorWipeService(profileDao: db.profileDao);
        final pullSvc = TutoredPullService(
          gateway: errorGateway,
          dispatcher: _NoOpDispatcher(),
          profileDao: db.profileDao,
          wipeService: wipeSvc,
        );

        final result = await pullSvc.pull(
          accountId: accountId,
          parentUid: 'parent-uid',
          remoteProfileId: 'remote-child',
          grantId: 'grant-error',
          childDisplayName: 'Child',
          childMode: 'child',
        );

        expect(result.result, TutoredPullResult.error);
        // Mirror must still exist — generic errors don't mean revocation.
        expect(await db.profileDao.getProfileById(mirrorId), isNotNull);
      });
    });
  });
}

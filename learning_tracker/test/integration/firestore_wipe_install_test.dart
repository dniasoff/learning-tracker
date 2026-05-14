/// Integration test for the wipe-install round-trip (DNI-343 / Story 25.22).
///
/// Verifies that data pushed to Firestore on one device can be pulled and
/// merged into a brand-new local database on a fresh install — the core
/// guarantee of the cloud-restore path.
///
/// Scenario:
///   1. "Device A" pushes two completion-event documents and one
///      curriculum-track document to [FakeFirebaseFirestore] via
///      [FirestoreGatewayImpl]. Learner-profile data is seeded directly into
///      the fake (the same path [FirestoreDataSource.pushLearnerProfile] takes
///      in production, but without wiring the full data-source stack).
///   2. The local Drift database is "wiped" — a fresh [inMemoryDb] instance
///      replaces the old one, identical to a clean install.
///   3. [FirestoreGatewayImpl.fetchPage] pulls both sub-collections back.
///   4. Pulled rows are merged into the new DB via [CompletionEventDao.appendEvent]
///      (which uses INSERT OR IGNORE, mirroring [CompletionEventMerger]).
///   5. Assertions confirm every pushed document survives the round-trip and
///      that a second pull is idempotent (no duplicate rows inserted).
///
/// This test is kept deliberately narrow — it exercises the
/// [FirestoreGatewayImpl] + [FakeFirebaseFirestore] + Drift layer without
/// spinning up [SyncEngine] or [DeviceRestoreService] (which depend on
/// [SharedPreferences] and plugin channels). Higher-level orchestration is
/// covered by the mock-based suite in `epic_25_story_22_firewall_test.dart`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/firestore_gateway_impl.dart';
import 'package:learning_tracker/features/auth/domain/models/app_user.dart';
import 'package:learning_tracker/features/auth/domain/repositories/auth_repository.dart';

import '../helpers/drift_memory.dart';
import '../helpers/firestore_fake.dart';

// ── Minimal stub AuthRepository ───────────────────────────────────────────────

/// Returns a fixed [AppUser] from [currentUser].
/// [FirestoreGatewayImpl] only ever reads [currentUser.uid]; all other
/// methods throw [UnimplementedError] so accidental calls surface quickly.
class _StubAuthRepository implements AuthRepository {
  const _StubAuthRepository(this._uid);

  final String _uid;

  @override
  AppUser? get currentUser => AppUser(
    uid: _uid,
    email: 'test@example.com',
    displayName: 'Test User',
    emailVerified: true,
    providers: const ['password'],
  );

  @override
  Stream<AppUser?> onAuthStateChanged() => Stream.value(currentUser);

  @override
  Future<void> signInWithEmail(String e, String p) =>
      throw UnimplementedError();
  @override
  Future<void> signInWithGoogle() => throw UnimplementedError();
  @override
  Future<void> signUp(String e, String p, String n) =>
      throw UnimplementedError();
  @override
  Future<void> sendEmailVerification() => throw UnimplementedError();
  @override
  Future<void> sendSignInLinkToEmail(String e) => throw UnimplementedError();
  @override
  Future<AppUser?> signInWithEmailLink(String e, String l) =>
      throw UnimplementedError();
  @override
  bool isSignInWithEmailLink(String l) => throw UnimplementedError();
  @override
  Future<void> sendPasswordResetEmail(String e) => throw UnimplementedError();
  @override
  Future<void> signOut() => throw UnimplementedError();
  @override
  Future<void> deleteAccount() => throw UnimplementedError();
  @override
  Future<void> changePassword(String p) => throw UnimplementedError();
  @override
  Future<void> reauthenticateWithEmail(String e, String p) =>
      throw UnimplementedError();
  @override
  Future<void> reauthenticateWithGoogle() => throw UnimplementedError();
  @override
  Future<void> linkGoogleProvider() => throw UnimplementedError();
  @override
  Future<void> linkEmailProvider(String e, String p) =>
      throw UnimplementedError();
  @override
  List<String> getLinkedProviders() => throw UnimplementedError();
  @override
  Future<AppUser?> reloadCurrentUser() => throw UnimplementedError();
  @override
  Future<void> checkActionCode(String c) => throw UnimplementedError();
  @override
  Future<void> applyActionCode(String c) => throw UnimplementedError();
  @override
  Future<String> createUserAccount(String e, String p) =>
      throw UnimplementedError();
  @override
  Future<AppUser?> signInAndGetUser(String e, String p) =>
      throw UnimplementedError();
  @override
  Future<void> updateDisplayName(String n) => throw UnimplementedError();
  @override
  Future<void> deleteCurrentFirebaseUser() => throw UnimplementedError();
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _uid = 'uid_wipe_install_343';
const _profileId = 1;
const _curriculumId = 'mishnayos';

/// Inserts one completion-event row using the DAO's idempotent
/// `INSERT OR IGNORE` path (mirrors [CompletionEventMerger]).
Future<void> _appendEvent(
  UserDatabase db,
  Map<String, dynamic> row,
) => db.completionEventDao.appendEvent(
  CompletionEventsCompanion.insert(
    profileId: _profileId,
    curriculumId: row['curriculum_id'] as String,
    sefariaRef: row['sefaria_ref'] as String,
    stageId: row['stage_id'] as int,
    trackType: row['track_type'] as String,
    eventTimestamp: DateTime.parse(row['completed_at'] as String),
  ),
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group(
    'DNI-343 — Firestore wipe-install round-trip',
    () {
      // ── AC1: full round-trip ─────────────────────────────────────────────

      test(
        'completions pushed on device A are fully restored on device B '
        'after a local DB wipe',
        () async {
          // Phase 1: Device A — push data to fake Firestore.

          final fakeFs = createFakeFirestore(authenticatedUid: _uid);
          const authRepo = _StubAuthRepository(_uid);
          final gatewayA = FirestoreGatewayImpl(
            firestore: fakeFs,
            authRepository: authRepo,
          );

          // Push two completion events via the gateway.
          final completionFixtures = [
            {
              'curriculum_id': _curriculumId,
              'sefaria_ref': 'Mishnah Berakhot 1:1',
              'stage_id': 1,
              'track_type': 'programmed',
              'completed_at': DateTime.utc(2026, 5, 10, 8).toIso8601String(),
              'points': 10,
            },
            {
              'curriculum_id': _curriculumId,
              'sefaria_ref': 'Mishnah Berakhot 1:2',
              'stage_id': 1,
              'track_type': 'programmed',
              'completed_at': DateTime.utc(2026, 5, 11, 9).toIso8601String(),
              'points': 10,
            },
          ];
          for (final c in completionFixtures) {
            await gatewayA.pushCompletion(profileId: _profileId, data: c);
          }

          // Push one curriculum track (simulates track activation).
          await gatewayA.pushTrack(
            profileId: _profileId,
            data: {
              'curriculum_id': _curriculumId,
              'track_type': 'programmed',
              'is_active': true,
              'activated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
            },
          );

          // Seed learner-profile document at the path
          // users/{uid}/learner_profiles/{profileId} — this is where
          // FirestoreDataSource.pushLearnerProfile writes in production.
          await fakeFs
              .collection('users')
              .doc(_uid)
              .collection('learner_profiles')
              .doc(_profileId.toString())
              .set({
                'id': _profileId,
                'account_id': 1,
                'display_name': 'Wipe-Install User',
                'mode': 'adult',
                'avatar_index': 0,
                'created_at': DateTime.utc(2026, 5, 1).toIso8601String(),
                'updated_at': DateTime.utc(2026, 5, 1).toIso8601String(),
              });

          // Phase 2: Wipe — discard device-A DB; fresh install.

          // Device B starts with a completely empty in-memory database.
          final dbB = inMemoryDb();
          addTearDown(() => dbB.close());

          final preEvents = await dbB.select(dbB.completionEvents).get();
          expect(
            preEvents,
            isEmpty,
            reason: 'fresh install must have no completion_events rows',
          );

          // Phase 3: Device B — pull from the same fake Firestore.

          final gatewayB = FirestoreGatewayImpl(
            firestore: fakeFs,
            authRepository: authRepo,
          );

          // Pull completions sub-collection.
          final completionsPage = await gatewayB.fetchPage(
            profileId: _profileId,
            collection: 'completions',
            pageSize: 200,
            cursor: null,
          );
          expect(
            completionsPage.rows,
            hasLength(2),
            reason: 'fetchPage must return both pushed completion docs',
          );

          // Pull curriculum_tracks sub-collection.
          final tracksPage = await gatewayB.fetchPage(
            profileId: _profileId,
            collection: 'curriculum_tracks',
            pageSize: 200,
            cursor: null,
          );
          expect(
            tracksPage.rows,
            hasLength(1),
            reason: 'fetchPage must return the pushed curriculum_tracks doc',
          );

          // Verify learner profile document is present.
          final profileSnap = await fakeFs
              .collection('users')
              .doc(_uid)
              .collection('learner_profiles')
              .doc(_profileId.toString())
              .get();
          expect(
            profileSnap.exists,
            isTrue,
            reason: 'learner_profile document must survive the round-trip',
          );

          // Phase 4: Merge pulled rows into device B's fresh local DB.

          // Merge completion events via the DAO (INSERT OR IGNORE semantics,
          // mirroring CompletionEventMerger through the MergeStore seam).
          for (final row in completionsPage.rows) {
            await _appendEvent(dbB, row);
          }

          // Merge learner profile (upsert / LWW).
          final profileData = profileSnap.data()!;
          final createdAt = profileData['created_at'] is DateTime
              ? profileData['created_at'] as DateTime
              : DateTime.parse(profileData['created_at'] as String);
          final updatedAt = profileData['updated_at'] is DateTime
              ? profileData['updated_at'] as DateTime
              : DateTime.parse(profileData['updated_at'] as String);
          await dbB
              .into(dbB.learnerProfiles)
              .insertOnConflictUpdate(
                LearnerProfilesCompanion.insert(
                  accountId: (profileData['account_id'] as num).toInt(),
                  displayName: profileData['display_name'] as String,
                  mode: profileData['mode'] as String? ?? 'adult',
                  createdAt: createdAt,
                  updatedAt: updatedAt,
                ),
              );

          // Phase 5: Assert restored state matches what was pushed.

          final restoredEvents = await dbB.select(dbB.completionEvents).get();
          expect(
            restoredEvents,
            hasLength(2),
            reason:
                'both completion events must survive the wipe-install '
                'round-trip',
          );
          final refs = restoredEvents.map((e) => e.sefariaRef).toSet();
          expect(refs, contains('Mishnah Berakhot 1:1'));
          expect(refs, contains('Mishnah Berakhot 1:2'));
          expect(
            restoredEvents.every((e) => e.curriculumId == _curriculumId),
            isTrue,
          );

          final restoredProfiles = await dbB.select(dbB.learnerProfiles).get();
          expect(restoredProfiles, hasLength(1));
          expect(
            restoredProfiles.first.displayName,
            equals('Wipe-Install User'),
            reason: 'display_name must survive the cloud round-trip',
          );
        },
      );

      // ── AC2: idempotency ─────────────────────────────────────────────────

      test(
        'second pull is idempotent — duplicate fetchPage does not insert '
        'duplicate completion_events rows (INSERT OR IGNORE)',
        () async {
          final db = inMemoryDb();
          addTearDown(() => db.close());

          final fakeFs = createFakeFirestore(authenticatedUid: _uid);
          final gateway = FirestoreGatewayImpl(
            firestore: fakeFs,
            authRepository: const _StubAuthRepository(_uid),
          );

          await gateway.pushCompletion(
            profileId: _profileId,
            data: {
              'curriculum_id': _curriculumId,
              'sefaria_ref': 'Mishnah Berakhot 2:1',
              'stage_id': 1,
              'track_type': 'programmed',
              'completed_at': DateTime.utc(2026, 5, 12, 8).toIso8601String(),
              'points': 10,
            },
          );

          Future<void> pullAndMerge() async {
            final page = await gateway.fetchPage(
              profileId: _profileId,
              collection: 'completions',
              pageSize: 200,
              cursor: null,
            );
            for (final row in page.rows) {
              await _appendEvent(db, row);
            }
          }

          // First pull.
          await pullAndMerge();
          final afterFirst = await db.select(db.completionEvents).get();
          expect(afterFirst, hasLength(1));

          // Second pull — simulates retry or double-restore.
          await pullAndMerge();
          final afterSecond = await db.select(db.completionEvents).get();
          expect(
            afterSecond,
            hasLength(1),
            reason:
                'completion_events UNIQUE constraint + INSERT OR IGNORE must '
                'collapse duplicate pulls to a single row',
          );
        },
      );

      // ── AC3: isolation between two devices ───────────────────────────────

      test(
        'two in-memory DB instances are independent — device B starts clean '
        'regardless of data in device A',
        () async {
          // Device A writes a track.
          final dbA = inMemoryDb();
          await dbA.into(dbA.curriculumTracks).insert(
            CurriculumTracksCompanion.insert(
              profileId: _profileId,
              curriculumId: _curriculumId,
              trackType: 'personal',
              activatedAt: DateTime.utc(2026, 5, 1),
            ),
          );
          await dbA.close();

          // Device B opens a fresh in-memory DB — completely isolated.
          final dbB = inMemoryDb();
          addTearDown(() => dbB.close());

          final tracks = await dbB.select(dbB.curriculumTracks).get();
          expect(
            tracks,
            isEmpty,
            reason:
                'device B must be isolated from device A — '
                'no data leakage between in-memory DB instances',
          );
        },
      );
    },
  );
}

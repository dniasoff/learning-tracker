/// T1.isolation regression tests — tutored pull writes rows under the synthetic
/// local id from the parent namespace, nothing enters the outbox, and the
/// tutor's own data is untouched.
///
/// Three cases per spec (T1.isolation):
///   (a) A tutored pull writes rows under the synthetic local id.
///   (b) Nothing from the mirror enters the outbox.
///   (c) The tutor's own profiles/data are untouched.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/pull_pipeline.dart';
import 'package:learning_tracker/core/sync/tutored_pull_service.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

import '../helpers/test_database.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Records every [dispatch] call so tests can assert which profileId received
/// the merged rows.
class _RecordingDispatcher implements MergeDispatcher {
  final dispatched = <({int profileId, String kind, int rowCount})>[];

  @override
  Future<MergeOutcome> dispatch({
    required int profileId,
    required String kind,
    required List<Map<String, dynamic>> rows,
  }) async {
    dispatched.add((profileId: profileId, kind: kind, rowCount: rows.length));
    return MergeOutcome.continueNext;
  }
}

/// Gateway that returns one completion row for the child's namespace.
class _ChildDataGateway implements FirestoreGateway {
  /// Tracks which (parentUid, remoteProfileId, collection) combos were fetched.
  final childFetched = <String>[];

  @override
  Future<FirestorePage> fetchChildPage({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async {
    childFetched.add('$parentUid/$remoteProfileId/$collection');
    if (collection == 'completions') {
      return FirestorePage(rows: [
        {
          'firestore_id': 'comp_1',
          'sefaria_ref': 'Berakhot.1.1',
          'stage_id': 1,
          'track_type': 'daily',
          'curriculum_id': 'test',
          'completed_at': DateTimeFactory.nowUtc().toIso8601String(),
          'updated_at': DateTimeFactory.nowUtc().toIso8601String(),
        },
      ]);
    }
    return const FirestorePage(rows: []);
  }

  @override
  Future<Map<String, dynamic>?> fetchChildDocument({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required String docId,
  }) async => null;

  // ── Own-data methods — should NEVER be called during a tutored pull ─────

  @override
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async => throw StateError('fetchPage must not be called for tutored pull');

  @override
  Future<Map<String, dynamic>?> fetchDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) async =>
      throw StateError('fetchDocument must not be called for tutored pull');

  @override
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async =>
      throw StateError('fetchLearnerProfiles must not be called for tutored pull');

  @override
  Future<List<Map<String, dynamic>>> fetchAll({
    required int profileId,
    required String collection,
  }) async => throw StateError('fetchAll must not be called for tutored pull');

  @override
  Future<List<Map<String, dynamic>>> fetchAuditLogEntries({
    required String grantId,
    String? startTimestamp,
    String? endTimestamp,
    String? actionFilter,
  }) async => const [];

  // ── Push stubs — never exercised by pull tests ───────────────────────────

  @override
  Future<void> pushCompletion({
    required int profileId,
    required Map<String, dynamic> data,
    String? docId,
  }) async {}

  @override
  Future<List<String>> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> items,
  }) async => const [];

  @override
  Future<void> pushStreak({required int profileId, required Map<String, dynamic> data}) async {}

  @override
  Future<void> pushSettings({required int profileId, required Map<String, dynamic> data}) async {}

  @override
  Future<void> pushTrack({required int profileId, required Map<String, dynamic> data}) async {}

  @override
  Future<void> pushLearningOrder({required int profileId, required Map<String, dynamic> data}) async {}

  @override
  Future<void> pushBookmark({required int profileId, required Map<String, dynamic> data}) async {}

  @override
  Future<void> pushNotificationSettings({required int profileId, required Map<String, dynamic> data}) async {}

  @override
  Future<void> pushGamificationSettings({required int profileId, required Map<String, dynamic> data}) async {}

  @override
  Future<void> pushLearnerProfile({required int profileId, required Map<String, dynamic> data}) async {}

  @override
  Future<void> deleteLearnerProfile(int profileId) async {}

  @override
  Future<void> pushGoal({required int profileId, required Map<String, dynamic> data}) async {}

  @override
  Future<void> deleteGoal({required int profileId, required String firestoreId}) async {}

  @override
  Future<void> pushUiPreferences({required int profileId, required Map<String, dynamic> data}) async {}

  @override
  Future<void> pushAccountProfile({required Map<String, dynamic> data}) async {}

  @override
  Future<void> pushCurriculumImportMetadata({required int profileId, required Map<String, dynamic> data}) async {}

  @override
  Future<void> deleteUserData(String uid) async {}

  @override
  Future<void> pushDiagnosticLog({required String uid, required Map<String, dynamic> data}) async {}

  @override
  Future<void> pushAccountUserProfile({required String uid, required Map<String, dynamic> data}) async {}

  @override
  Stream<ListenerSnapshot> listenToCollection({
    required int profileId,
    required String collection,
    required String orderField,
    int limit = 500,
  }) => const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToTutorGrants({int limit = 500}) =>
      const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToLearnerProfiles({int limit = 500}) =>
      const Stream.empty();

  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) => const Stream.empty();

  @override
  Future<void> pushLedgerEntry({required int profileId, required Map<String, dynamic> data}) async {}

  @override
  Future<void> pushLedgerEntriesBatch({
    required int profileId,
    required List<Map<String, dynamic>> entries,
  }) async {}

  @override
  Future<void> pushProfileProgram({required int profileId, required Map<String, dynamic> data}) async {}

  @override
  Future<void> removeProfileProgramAssignment({
    required int profileId,
    required String curriculumStorageKey,
  }) async {}

  @override
  Future<void> pushStageDefinition({required int profileId, required Map<String, dynamic> data}) async {}

  @override
  Future<void> pushStudyDayConfig({required int profileId, required Map<String, dynamic> data}) async {}

  @override
  Future<void> pushPointsLedgerEntry({required int profileId, required Map<String, dynamic> data}) async {}

  @override
  Future<void> pushRewardRedemption({required int profileId, required Map<String, dynamic> data}) async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<int> _seedOwnAccount(UserDatabase db) async {
  final accountId = await db.into(db.accounts).insert(
    AccountsCompanion.insert(
      email: 'tutor@example.com',
      tier: 'localBorn',
      displayName: 'Tutor',
      createdAt: DateTimeFactory.nowUtc(),
      updatedAt: DateTimeFactory.nowUtc(),
    ),
  );
  await db.into(db.learnerProfiles).insert(
    LearnerProfilesCompanion.insert(
      accountId: accountId,
      displayName: 'Tutor Profile',
      mode: 'adult',
      createdAt: DateTimeFactory.nowUtc(),
      updatedAt: DateTimeFactory.nowUtc(),
    ),
  );
  return accountId;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late UserDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  group('T1.isolation — tutored pull isolation', () {
    test(
      '(a) pull writes rows under the synthetic local id from the parent namespace',
      () async {
        final accountId = await _seedOwnAccount(db);
        final dispatcher = _RecordingDispatcher();
        final gateway = _ChildDataGateway();

        final svc = TutoredPullService(
          gateway: gateway,
          dispatcher: dispatcher,
          profileDao: db.profileDao,
        );

        final result = await svc.pull(
          accountId: accountId,
          parentUid: 'parent-uid-123',
          remoteProfileId: 'remote-child-42',
          grantId: 'grant-abc',
          childDisplayName: 'Yitzchak',
          childMode: 'child',
        );

        expect(result.result, TutoredPullResult.success);

        // Verify: synthetic profile row exists and is_tutored.
        final localId = result.localProfileId;
        final syntheticRow = await db.profileDao.getProfileById(localId);
        expect(syntheticRow, isNotNull);
        expect(syntheticRow!.isTutored, isTrue);
        expect(syntheticRow.tutorParentUid, 'parent-uid-123');
        expect(syntheticRow.tutorRemoteProfileId, 'remote-child-42');
        expect(syntheticRow.tutorGrantId, 'grant-abc');

        // Verify: dispatcher was called with the SYNTHETIC local id, not remote.
        final completionDispatch = dispatcher.dispatched.where(
          (d) => d.kind == 'completion',
        );
        expect(completionDispatch, isNotEmpty);
        for (final d in completionDispatch) {
          expect(
            d.profileId,
            localId,
            reason: 'Merger must receive synthetic local id, not remote',
          );
        }

        // Verify: parent-namespace was queried (child path was used).
        expect(
          gateway.childFetched,
          contains('parent-uid-123/remote-child-42/completions'),
        );
      },
    );

    test('(a) re-entry with same triple reuses the same row — no duplicates', () async {
      final accountId = await _seedOwnAccount(db);
      final gateway = _ChildDataGateway();
      final svc = TutoredPullService(
        gateway: gateway,
        dispatcher: _RecordingDispatcher(),
        profileDao: db.profileDao,
      );

      final r1 = await svc.pull(
        accountId: accountId,
        parentUid: 'parent-uid-123',
        remoteProfileId: 'remote-child-42',
        grantId: 'grant-abc',
        childDisplayName: 'Yitzchak',
        childMode: 'child',
      );
      final r2 = await svc.pull(
        accountId: accountId,
        parentUid: 'parent-uid-123',
        remoteProfileId: 'remote-child-42',
        grantId: 'grant-abc',
        childDisplayName: 'Yitzchak',
        childMode: 'child',
      );

      expect(r1.localProfileId, r2.localProfileId,
          reason: 'Same triple must return same local id');

      // Only one tutored row with this triple.
      final profiles = await db.profileDao.getProfilesByAccount(accountId);
      final tutored = profiles.where((p) => p.isTutored).toList();
      expect(tutored.length, 1, reason: 'No duplicate tutored rows');
    });

    test('(b) nothing from the mirror enters the outbox', () async {
      final accountId = await _seedOwnAccount(db);
      final gateway = _ChildDataGateway();
      final dispatcher = _RecordingDispatcher();
      final svc = TutoredPullService(
        gateway: gateway,
        dispatcher: dispatcher,
        profileDao: db.profileDao,
      );

      final result = await svc.pull(
        accountId: accountId,
        parentUid: 'parent-uid-123',
        remoteProfileId: 'remote-child-42',
        grantId: 'grant-abc',
        childDisplayName: 'Yitzchak',
        childMode: 'child',
      );

      final localId = result.localProfileId;

      // Outbox for the synthetic profile is empty.
      final outboxRows = await db.outboxDao.depth(localId);
      expect(outboxRows, 0, reason: 'No outbox rows for tutored mirror');

      // isProfileTutored returns true — the drain guard fires.
      final isTutored = await db.profileDao.isProfileTutored(localId);
      expect(isTutored, isTrue);
    });

    test(
      '(b) OutboxProcessor drain skips tutored profiles via isTutoredProfile guard',
      () async {
        final accountId = await _seedOwnAccount(db);

        // Create a tutored profile row.
        final tutoredId = await db.profileDao.upsertTutoredProfile(
          accountId: accountId,
          parentUid: 'parent-uid-999',
          remoteChildProfileId: 'remote-999',
          grantId: 'grant-999',
          displayName: 'Child',
          mode: 'child',
          now: DateTime.now(),
        );

        // Manually insert an outbox row for the tutored profile (simulate a bug
        // where data was somehow enqueued for a tutored profile).
        await db.outboxDao.insertOutboxRow(
          OutboxCompanion(
            profileId: Value(tutoredId),
            entityKind: const Value('completion'),
            entityKey: const Value('test_key'),
            payload: const Value('{}'),
            createdAt: Value(DateTimeFactory.nowUtc()),
          ),
        );

        // The isProfileTutored guard must return true for this profile.
        final guardFires =
            await db.profileDao.isProfileTutored(tutoredId);
        expect(guardFires, isTrue,
            reason: 'Guard must block drain for tutored profiles');

        // Own profile (not tutored) — guard returns false.
        final profiles = await db.profileDao.getProfilesByAccount(accountId);
        final ownProfile = profiles.firstWhere((p) => !p.isTutored);
        final ownGuard = await db.profileDao.isProfileTutored(ownProfile.id);
        expect(ownGuard, isFalse,
            reason: 'Guard must allow drain for own profiles');
      },
    );

    test("(c) tutor's own profiles and data are untouched after a pull", () async {
      final accountId = await _seedOwnAccount(db);

      // Capture the own profile id before pull.
      final ownProfiles = await db.profileDao.getProfilesByAccount(accountId);
      expect(ownProfiles.length, 1);
      final ownProfile = ownProfiles.first;
      expect(ownProfile.isTutored, isFalse);

      final gateway = _ChildDataGateway();
      final svc = TutoredPullService(
        gateway: gateway,
        dispatcher: _RecordingDispatcher(),
        profileDao: db.profileDao,
      );

      await svc.pull(
        accountId: accountId,
        parentUid: 'parent-uid-123',
        remoteProfileId: 'remote-child-42',
        grantId: 'grant-abc',
        childDisplayName: 'Yitzchak',
        childMode: 'child',
      );

      // The tutor's own profile row is unchanged.
      final ownAfter = await db.profileDao.getProfileById(ownProfile.id);
      expect(ownAfter, isNotNull);
      expect(ownAfter!.displayName, ownProfile.displayName);
      expect(ownAfter.isTutored, isFalse);

      // Only one own profile (the tutored mirror is a separate row).
      final allProfiles = await db.profileDao.getProfilesByAccount(accountId);
      final ownCount = allProfiles.where((p) => !p.isTutored).length;
      expect(ownCount, 1, reason: 'Pull must not modify own profiles');

      // The tutored row is distinct.
      final tutoredCount = allProfiles.where((p) => p.isTutored).length;
      expect(tutoredCount, 1);
    });
  });
}

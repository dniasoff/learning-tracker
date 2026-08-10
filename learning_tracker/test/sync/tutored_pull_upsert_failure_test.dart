/// AUD-core-sync-04 regression test.
///
/// `TutoredPullService.pull()` used to await `profileDao.upsertTutoredProfile`
/// *before* the method's try block opened, while the `on Exception` handler's
/// own comment claimed to cover "the synthetic-profile upsert". In reality an
/// upsert failure (DB busy, unique-constraint violation on grantId, disk I/O)
/// propagated straight out of `pull()` uncaught — unlike every other failure
/// path in this method, which returns `TutoredPullResult.error` (EH-2: a raw
/// exception must never propagate into presentation). The sole production
/// caller (`tutored_children_section.dart`) only catches `on StateError` and
/// promises the flow "never crashes" / "shows an error snackbar" — an upsert
/// failure broke that invariant (stuck loading dialog, no snackbar, no
/// selection-clear).
///
/// This test asserts `pull()` degrades softly (returns
/// `TutoredPullResult.error`) when the synthetic-profile upsert throws, the
/// same as every other failure path in the method.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/profile_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/pull_pipeline.dart';
import 'package:learning_tracker/core/sync/tutored_pull_service.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

import '../helpers/test_database.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// A [ProfileDao] whose `upsertTutoredProfile` always throws, simulating a DB
/// failure (busy, unique-constraint violation, disk I/O) during the
/// synthetic-profile upsert step of [TutoredPullService.pull].
class _ThrowingUpsertProfileDao extends ProfileDao {
  _ThrowingUpsertProfileDao(super.db);

  @override
  Future<int> upsertTutoredProfile({
    required int accountId,
    required String parentUid,
    required String remoteChildProfileId,
    required String grantId,
    required String displayName,
    required String mode,
    required DateTime now,
  }) async {
    throw Exception('simulated upsert failure (AUD-core-sync-04)');
  }
}

/// Dispatcher that must NEVER be called — the pull must fail before the
/// pipeline ever reaches the merge step, since the upsert (which supplies
/// the synthetic local id) fails first.
class _UnreachableDispatcher implements MergeDispatcher {
  @override
  Future<MergeOutcome> dispatch({
    required int profileId,
    required String kind,
    required List<Map<String, dynamic>> rows,
  }) async => throw StateError('dispatch must not be reached');
}

/// Gateway that must NEVER be called for the same reason as above.
class _UnreachableGateway implements FirestoreGateway {
  @override
  Future<FirestorePage> fetchChildPage({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async => throw StateError('gateway must not be reached');

  @override
  Future<Map<String, dynamic>?> fetchChildDocument({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required String docId,
  }) async => throw StateError('gateway must not be reached');

  @override
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async => throw StateError('gateway must not be reached');

  @override
  Future<Map<String, dynamic>?> fetchDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) async => throw StateError('gateway must not be reached');

  @override
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async =>
      throw StateError('gateway must not be reached');

  @override
  Future<List<Map<String, dynamic>>> fetchAll({
    required int profileId,
    required String collection,
  }) async => throw StateError('gateway must not be reached');

  @override
  Future<List<Map<String, dynamic>>> fetchAuditLogEntries({
    required String grantId,
    String? startTimestamp,
    String? endTimestamp,
    String? actionFilter,
  }) async => const [];

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
  Future<void> pushStreak({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushTrack({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushBookmark({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushNotificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushGamificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushLearnerProfile({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> deleteLearnerProfile(String profileUlid) async {}

  @override
  Future<void> pushGoal({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> deleteGoal({
    required int profileId,
    required String firestoreId,
  }) async {}

  @override
  Future<void> pushUiPreferences({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushAccountProfile({required Map<String, dynamic> data}) async {}

  @override
  Future<void> pushCurriculumImportMetadata({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> deleteUserData(String uid) async {}

  @override
  Future<void> pushDiagnosticLog({
    required String uid,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushAccountUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {}

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
  Stream<ListenerSnapshot> listenToChildCollection({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required String orderField,
    int limit = 500,
  }) => const Stream.empty();

  @override
  Stream<Map<String, dynamic>?> listenToChildDocument({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required String docId,
  }) => const Stream.empty();

  @override
  Future<void> pushLedgerEntry({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushLedgerEntriesBatch({
    required int profileId,
    required List<Map<String, dynamic>> entries,
  }) async {}

  @override
  Future<void> pushProfileProgram({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> removeProfileProgramAssignment({
    required int profileId,
    required String curriculumStorageKey,
  }) async {}

  @override
  Future<void> pushStageDefinition({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushStudyDayConfig({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushPointsLedgerEntry({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushRewardRedemption({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<int> _seedOwnAccount(UserDatabase db) async {
  return db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: 'tutor@example.com',
          tier: 'localBorn',
          displayName: 'Tutor',
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late UserDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  group('AUD-core-sync-04 — synthetic-profile upsert failure', () {
    test('pull() returns TutoredPullResult.error (not an uncaught exception) '
        'when profileDao.upsertTutoredProfile throws', () async {
      final accountId = await _seedOwnAccount(db);
      final svc = TutoredPullService(
        gateway: _UnreachableGateway(),
        dispatcher: _UnreachableDispatcher(),
        profileDao: _ThrowingUpsertProfileDao(db),
      );

      // Must not throw — the exception must be caught inside pull() and
      // converted to a TutoredPullResult.error, consistent with every
      // other failure path in this method (EH-2: a raw exception must
      // never propagate into presentation).
      final result = await svc.pull(
        accountId: accountId,
        parentUid: 'parent-uid-123',
        remoteProfileId: 'remote-child-42',
        grantId: 'grant-abc',
        childDisplayName: 'Yitzchak',
        childMode: 'child',
      );

      expect(result.result, TutoredPullResult.error);
    });
  });
}

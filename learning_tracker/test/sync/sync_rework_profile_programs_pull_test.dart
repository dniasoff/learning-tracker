/// F-H3 regression tests — profile_programs pulled on launch before
/// markInitialSyncComplete.
///
/// Before the fix, `pullOnLaunch` did not include `profile_programs` in its
/// pull sequence. The realtime listener provided the anchor eventually, but
/// `markInitialSyncComplete` was already set by the time the listener fired,
/// leaving a window where the dashboard projection ran on stale data.
///
/// These two tests verify:
///
///   1. After `pullOnLaunch` completes, the local DB has the `profile_programs`
///      row that the fake Firestore returned.
///
///   2. If `pullOnLaunch` fails (the gateway throws during the profile_programs
///      fetch), `markInitialSyncComplete` is NOT written — the gate remains open
///      so the next pull can retry with a complete anchor.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/initial_sync_state.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/merge/profile_program_merger.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/drift_memory.dart' show inMemoryDb, seedProfile;

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// A [FirestoreGateway] that serves exactly one `profile_programs` doc and
/// empty pages for every other collection.
///
/// On the first call to `fetchPage` for `profile_programs`, it returns a page
/// containing [_profileProgramRow]. Every other call returns an empty page so
/// the PullPipeline pagination loop terminates.
class _ProfileProgramsGateway implements FirestoreGateway {
  /// When true, the `profile_programs` fetch throws an exception to simulate a
  /// network/auth failure so we can verify the sync-complete gate stays open.
  bool failProfileProgramsFetch = false;

  @override
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async {
    if (collection == 'profile_programs') {
      if (failProfileProgramsFetch) {
        throw Exception('F-H3: simulated profile_programs fetch failure');
      }
      // Return one row on the first call (cursor == null), empty on the second
      // (cursor != null, meaning we just returned the last row).
      if (cursor == null) {
        return const FirestorePage(
          rows: [
            {
              'curriculum_id': 'mishnayos',
              'program_id': 3,
              'profile_id': 1,
              'tracking_start_date': null,
              'tracking_start_ref': null,
              'firestore_id': 'mishnayos',
            },
          ],
        );
      }
    }
    return const FirestorePage(rows: []);
  }

  // ── Stubs for other gateway operations ─────────────────────────────────────

  @override
  Stream<List<Map<String, dynamic>>> listenToCollection({
    required int profileId,
    required String collection,
  }) => const Stream.empty();

  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) => const Stream.empty();

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
  Future<void> deleteLearnerProfile(int profileId) async {}
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
  Future<List<Map<String, dynamic>>> fetchAll({
    required int profileId,
    required String collection,
  }) async => [];
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
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async => [];
  @override
  Future<Map<String, dynamic>?> fetchDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) async => null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

SyncOrchestratorImpl _buildOrchestrator(
  UserDatabase db,
  _ProfileProgramsGateway gateway,
) {
  final store = DriftMergeStore(db);
  final router = MergeRouter(
    mergers: {EntityKind.profileProgram: ProfileProgramMerger(store: store)},
  );
  return SyncOrchestratorImpl(
    resolveEngine: () =>
        throw StateError('F-H3: pullOnLaunch must not touch the engine'),
    resolveMergeRouter: () => router,
    resolveGateway: () => gateway,
    resolveProfileId: () => 1,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('F-H3 — profile_programs pulled on launch before sync-complete gate', () {
    late UserDatabase db;
    late _ProfileProgramsGateway gateway;
    late SyncOrchestratorImpl orchestrator;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      db = inMemoryDb();
      await seedProfile(db);
      gateway = _ProfileProgramsGateway();
      orchestrator = _buildOrchestrator(db, gateway);
    });

    tearDown(() async {
      await db.close();
    });

    // ── F-H3.1 ───────────────────────────────────────────────────────────────
    //
    // pullOnLaunch must write the profile_programs row to the local DB BEFORE
    // setting markInitialSyncComplete — anchors are present when the gate opens.
    test('F-H3.1: after pullOnLaunch the local DB has the profile_programs row '
        'and the sync-complete flag is set', () async {
      await orchestrator.pullOnLaunch();

      // The profile_programs row from the fake gateway must be in the DB.
      final programs = await db.profileProgramDao.getProgramsForProfile(1);
      expect(
        programs,
        hasLength(1),
        reason:
            'F-H3: pullOnLaunch must pull profile_programs and write the '
            'row to the local DB before marking sync complete',
      );
      expect(
        programs.first.curriculumType,
        equals('mishnayos'),
        reason: 'F-H3: curriculum_type must round-trip from the gateway row',
      );
      expect(
        programs.first.programId,
        equals(3),
        reason: 'F-H3: program_id must round-trip from the gateway row',
      );

      // The sync-complete flag must be set after a successful pull.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(kInitialSyncCompleteKey),
        isTrue,
        reason:
            'F-H3: markInitialSyncComplete must be called after all pulls '
            'including profile_programs complete successfully',
      );
    });

    // ── F-H3.2 ───────────────────────────────────────────────────────────────
    //
    // If the profile_programs fetch throws, pullOnLaunch must rethrow and must
    // NOT write markInitialSyncComplete.  The gate remains open so the next
    // pull can complete with all anchors present.
    test('F-H3.2: if the profile_programs pull throws, markInitialSyncComplete '
        'is NOT set — the gate remains open', () async {
      gateway.failProfileProgramsFetch = true;

      await expectLater(
        orchestrator.pullOnLaunch(),
        throwsA(isA<Exception>()),
        reason:
            'F-H3: a failing profile_programs pull must propagate — pullOnLaunch '
            'must rethrow so the caller can detect and retry',
      );

      // The sync-complete flag must NOT be set when the pull failed.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(kInitialSyncCompleteKey),
        isNot(isTrue),
        reason:
            'F-H3: markInitialSyncComplete must NOT be called when the '
            'profile_programs pull fails — the gate must remain open',
      );
    });
  });
}

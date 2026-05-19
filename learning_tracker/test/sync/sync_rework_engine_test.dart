/// Firebase Sync Rework — engine-level invariant tests.
///
/// These tests drive REAL production code — a real [SyncEngine] over an
/// in-memory database, the real completions debounce/merge path, and the real
/// [SyncOrchestratorImpl.pullOnLaunch] — so they genuinely catch regressions:
///
/// S5: two concurrent background-flush triggers → only one drain executes.
/// S6: a completion already present locally is not re-merged; a genuinely new
///     remote completion is.
/// S8: `pullOnLaunch` runs once per launch; a resume pull is throttled.
/// I1: a debounced completions snapshot is NOT lost when a merge is in flight.
/// I6: a remote completion with the snake_case keys the production outbox
///     payload now emits merges (insertedCount increments).
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/connectivity_service.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/pull_pipeline.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/sync/data/firestore_data_source.dart';
import 'package:learning_tracker/features/sync/data/offline_queue.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

import '../helpers/drift_memory.dart' show seedCompletion, seedProfile;

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _MockFirestoreDataSource extends Mock implements FirestoreDataSource {}

class _MockConnectivityService extends Mock implements ConnectivityService {}

/// [FirestoreGateway] that instruments the S5 single-flight guard.
///
/// The guard (`_flushInProgress` / `_rerunRequested` in
/// `SyncEngine._runBackgroundFlush`) coalesces overlapping flush triggers into
/// one drain. Two signals make the guard observable, and BOTH fail if the guard
/// is removed:
///
/// * [maxConcurrentPushes] — the high-water mark of `pushSettings` calls in
///   flight at one instant. With the guard exactly 1; without it, two drains
///   run their `OfflineQueue.flush()` loops concurrently and their pushes
///   interleave, so this reaches 2.
/// * [pushSettingsCalls] — `OfflineQueue.flush()` removes a queue row only
///   AFTER its push succeeds (see `offline_queue.dart`). With the guard each of
///   the two queued rows is pushed exactly once (total 2). Without the guard
///   two concurrent drains each call `getAllPending()` before either has
///   removed a row, so each drain re-pushes both rows (total 4).
///
/// Each push is held open long enough that, absent the guard, a second drain's
/// pushes genuinely overlap the first.
class _ConcurrencyTrackingGateway implements FirestoreGateway {
  int pushSettingsCalls = 0;
  int _inFlight = 0;
  int maxConcurrentPushes = 0;

  @override
  Future<void> pushSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    pushSettingsCalls++;
    _inFlight++;
    if (_inFlight > maxConcurrentPushes) maxConcurrentPushes = _inFlight;
    // Hold the push open long enough that a second concurrent drain would
    // overlap if the single-flight guard were broken.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    _inFlight--;
  }

  // ── Unused stubs ──────────────────────────────────────────────────────────
  @override
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async => const FirestorePage(rows: []);
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
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async => [];
  @override
  Future<Map<String, dynamic>?> fetchDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) async => null;
}

/// [FirestoreGateway] that counts `fetchPage` calls and always returns one
/// empty page so the [PullPipeline] pagination loop terminates immediately.
/// `pullOnLaunch` issues a fixed number of `fetchPage` calls (one per pulled
/// collection), so the count is an observable proxy for "pullOnLaunch ran".
class _FetchPageCountingGateway implements FirestoreGateway {
  int fetchPageCalls = 0;

  @override
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async {
    fetchPageCalls++;
    return const FirestorePage(rows: []);
  }

  // ── Unused stubs ──────────────────────────────────────────────────────────
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

UserDatabase _inMemoryDb() => UserDatabase(NativeDatabase.memory());

Future<int> _insertTrack(UserDatabase db) async {
  final row = await db
      .into(db.curriculumTracks)
      .insertReturning(
        CurriculumTracksCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackType: 'personal',
          activatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
  return row.id;
}

void main() {
  // The completions debounce/merge path and SharedPreferences both require a
  // Flutter test binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  // I8: the suite drives time through the project clock abstraction
  // (FakeLocalDayClock) — never DateTime.now() — so timestamps are
  // deterministic. The clock is installed per test and reset in tearDown.
  late FakeLocalDayClock clock;

  setUp(() {
    clock = FakeLocalDayClock(DateTime.utc(2026, 5, 18, 9));
    useLocalDayClock(clock);
  });

  tearDown(resetLocalDayClock);

  group('S5 — concurrent background flush drains exactly once', () {
    late UserDatabase database;
    late _MockFirestoreDataSource firestore;
    late _MockConnectivityService connectivity;
    late _ConcurrencyTrackingGateway gateway;
    late OfflineQueue offlineQueue;
    late SyncEngine engine;

    setUp(() async {
      database = _inMemoryDb();
      await seedProfile(database);
      await _insertTrack(database);
      gateway = _ConcurrencyTrackingGateway();
      firestore = _MockFirestoreDataSource();
      connectivity = _MockConnectivityService();
      when(() => connectivity.isOnline).thenAnswer((_) async => true);
      when(() => firestore.isAuthenticated).thenReturn(true);
      when(() => firestore.profileId).thenReturn(1);
      offlineQueue = OfflineQueue(
        database: database,
        firestoreGateway: gateway,
        logger: AppLogger(Talker()),
      );
      engine = SyncEngine(
        database: database,
        firestoreDataSource: firestore,
        offlineQueue: offlineQueue,
        logger: AppLogger(Talker()),
        connectivityService: connectivity,
      );
    });

    tearDown(() async {
      await engine.dispose();
      await database.close();
    });

    test(
      'S5: two genuinely-overlapping flush triggers run as ONE drain — each '
      'queued row pushed exactly once, never two concurrent drains',
      () async {
        // Write 1 enqueues row A and kicks off drain 1, which starts pushing A
        // (the gateway holds each push open ~60 ms).
        await engine.pushSettings({
          'curriculum_id': 'mishnayos',
          'stages': <dynamic>[],
        });

        // Wait long enough for drain 1 to have entered the gateway push for
        // row A (well inside its 60 ms hold), but not long enough for that
        // push to have finished. Write 2 then enqueues row B and fires
        // _runBackgroundFlush again WHILE drain 1 is still pushing — the exact
        // overlap the _flushInProgress / _rerunRequested single-flight guard
        // must coalesce. Without the guard this second trigger spawns a
        // concurrent drain that re-pushes the not-yet-removed row A.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await engine.pushSettings({
          'curriculum_id': 'shabbos',
          'stages': <dynamic>[],
        });

        // Let every drain (and the re-run the guard schedules) finish.
        await Future<void>.delayed(const Duration(milliseconds: 400));

        // Guard-specific signal #1: the drains never overlap. Without the
        // guard, drain 2 runs its OfflineQueue.flush() loop concurrently with
        // drain 1 and their pushes interleave, so this would reach 2.
        expect(
          gateway.maxConcurrentPushes,
          equals(1),
          reason:
              'S5: the single-flight guard serialises drains — at no instant '
              'may two drains have pushes in flight at once. Removing the '
              'guard lets a second concurrent drain run, so this reaches 2.',
        );
        // Guard-specific signal #2: each queued row is pushed exactly once.
        // OfflineQueue.flush() removes a row only after its push succeeds, so
        // two concurrent drains each call getAllPending() before either has
        // removed a row and both re-push the SAME rows — total 4. Only the
        // single-flight guard keeps this at exactly 2 (one push per row).
        expect(
          gateway.pushSettingsCalls,
          equals(2),
          reason:
              'S5: with the guard each of the two queued rows is pushed once '
              '(total 2). Without the guard two concurrent drains both see '
              'the not-yet-removed rows and re-push them (total 4).',
        );
        expect(
          await database.syncQueueDao.getPendingCount(),
          equals(0),
          reason: 'S5: the drain must empty the queue',
        );
      },
    );
  });

  group('S6 — completions merge dedups already-present completions', () {
    late UserDatabase database;
    late _MockFirestoreDataSource firestore;
    late _MockConnectivityService connectivity;
    late StreamController<List<Map<String, dynamic>>> completionsController;
    late OfflineQueue offlineQueue;
    late SyncEngine engine;
    late int trackId;

    setUp(() async {
      database = _inMemoryDb();
      await seedProfile(database);
      trackId = await _insertTrack(database);
      completionsController =
          StreamController<List<Map<String, dynamic>>>.broadcast();
      firestore = _MockFirestoreDataSource();
      connectivity = _MockConnectivityService();
      when(() => connectivity.isOnline).thenAnswer((_) async => true);
      when(() => firestore.isAuthenticated).thenReturn(true);
      when(() => firestore.profileId).thenReturn(1);
      // Only the completions listener is exercised; the rest stay empty.
      when(
        () => firestore.listenToCompletions(),
      ).thenAnswer((_) => completionsController.stream);
      when(
        () => firestore.listenToBookmarks(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToSettings(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToStreak(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToGoals(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToProfilePrograms(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToLedgerEntries(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToCurriculumTracks(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToNotificationSettings(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToGamificationSettings(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToUiPreferences(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToLearningOrder(),
      ).thenAnswer((_) => const Stream.empty());
      offlineQueue = OfflineQueue(
        database: database,
        firestoreGateway: _ConcurrencyTrackingGateway(),
        logger: AppLogger(Talker()),
      );
      engine = SyncEngine(
        database: database,
        firestoreDataSource: firestore,
        offlineQueue: offlineQueue,
        logger: AppLogger(Talker()),
        connectivityService: connectivity,
      );
    });

    tearDown(() async {
      await engine.dispose();
      await completionsController.close();
      await database.close();
    });

    test('S6: a completion already present locally is not re-merged; a new '
        'remote completion is merged', () async {
      // Seed a completion that already exists locally — this models a
      // "local echo" the engine must defend against by existence-checking
      // rather than blindly re-inserting.
      await seedCompletion(
        database,
        CompletionsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          sefariaRef: 'Berakhot 1:1',
          stageId: 1,
          trackType: 'personal',
          trackId: trackId,
          completedAt: DateTime.utc(2026, 5, 17, 8),
        ),
      );
      final eventsBefore =
          (await database.completionEventDao.getEventsByProfile(1)).length;

      await engine.attachListeners();

      // A snapshot containing the already-present completion plus one
      // genuinely-new remote completion.
      completionsController.add([
        {
          'profile_id': 1,
          'curriculum_id': 'mishnayos',
          'sefaria_ref': 'Berakhot 1:1',
          'stage_id': 1,
          'track_type': 'personal',
          'track_id': trackId,
          'completed_at': DateTime.utc(2026, 5, 17, 8).toIso8601String(),
        },
        {
          'profile_id': 1,
          'curriculum_id': 'mishnayos',
          'sefaria_ref': 'Berakhot 2:1',
          'stage_id': 1,
          'track_type': 'personal',
          'track_id': trackId,
          'completed_at': DateTime.utc(2026, 5, 17, 9).toIso8601String(),
        },
      ]);

      // Wait past the 300 ms debounce window and the merge.
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final eventsAfter = await database.completionEventDao.getEventsByProfile(
        1,
      );
      expect(
        eventsAfter.length,
        equals(eventsBefore + 1),
        reason:
            'S6: only the new remote completion (Berakhot 2:1) is inserted; '
            'the already-present one (Berakhot 1:1) is deduped, not '
            're-merged',
      );
      expect(
        eventsAfter.any((e) => e.sefariaRef == 'Berakhot 2:1'),
        isTrue,
        reason: 'S6: the genuinely-new remote completion must be merged',
      );
    });
  });

  group('I1 — debounced completions snapshot survives an in-flight merge', () {
    late UserDatabase database;
    late _MockFirestoreDataSource firestore;
    late _MockConnectivityService connectivity;
    late StreamController<List<Map<String, dynamic>>> completionsController;
    late OfflineQueue offlineQueue;
    late SyncEngine engine;
    late int trackId;

    setUp(() async {
      database = _inMemoryDb();
      await seedProfile(database);
      trackId = await _insertTrack(database);
      completionsController =
          StreamController<List<Map<String, dynamic>>>.broadcast();
      firestore = _MockFirestoreDataSource();
      connectivity = _MockConnectivityService();
      when(() => connectivity.isOnline).thenAnswer((_) async => true);
      when(() => firestore.isAuthenticated).thenReturn(true);
      when(() => firestore.profileId).thenReturn(1);
      when(
        () => firestore.listenToCompletions(),
      ).thenAnswer((_) => completionsController.stream);
      when(
        () => firestore.listenToBookmarks(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToSettings(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToStreak(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToGoals(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToProfilePrograms(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToLedgerEntries(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToCurriculumTracks(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToNotificationSettings(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToGamificationSettings(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToUiPreferences(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToLearningOrder(),
      ).thenAnswer((_) => const Stream.empty());
      offlineQueue = OfflineQueue(
        database: database,
        firestoreGateway: _ConcurrencyTrackingGateway(),
        logger: AppLogger(Talker()),
      );
      engine = SyncEngine(
        database: database,
        firestoreDataSource: firestore,
        offlineQueue: offlineQueue,
        logger: AppLogger(Talker()),
        connectivityService: connectivity,
      );
    });

    tearDown(() async {
      await engine.dispose();
      await completionsController.close();
      await database.close();
    });

    Map<String, dynamic> remoteCompletion(String ref, DateTime at) => {
      'profile_id': 1,
      'curriculum_id': 'mishnayos',
      'sefaria_ref': ref,
      'stage_id': 1,
      'track_type': 'personal',
      'track_id': trackId,
      'completed_at': at.toIso8601String(),
    };

    test('I1: every snapshot in a rapid burst is merged — none is silently '
        'dropped across overlapping debounce/merge cycles', () async {
      await engine.attachListeners();

      // Drive the REAL completions listener path: a burst of distinct
      // snapshots, each spaced just past the 300 ms debounce window so each
      // one triggers its own _drainPendingCompletionsSnapshot → merge cycle.
      // The pre-fix _drainPendingCompletionsSnapshot nulled the pending
      // snapshot before checking the merge lock, so any snapshot whose
      // debounce timer fired while a prior merge had not yet released the
      // lock was silently dropped. The fix re-arms the timer instead, so
      // EVERY snapshot in the burst must end up merged.
      const burst = 12;
      for (var i = 0; i < burst; i++) {
        completionsController.add([
          remoteCompletion(
            'Burst $i',
            DateTime.utc(2026, 5, 17, 8).add(Duration(minutes: i)),
          ),
        ]);
        await Future<void>.delayed(const Duration(milliseconds: 330));
      }

      // Poll until every burst snapshot has merged rather than waiting a
      // fixed window: a fixed delay is flaky on a loaded CI box where the
      // final debounce window + merge tail (plus any re-armed timer) can run
      // long. Poll every 50 ms for a bounded number of iterations (a ~10 s
      // ceiling), stopping as soon as all `burst` refs are present — so the
      // test waits exactly as long as needed and no longer. A bounded
      // iteration count keeps the deadline wall-clock-independent without
      // reaching for DateTime.now().
      const pollInterval = Duration(milliseconds: 50);
      const maxPollIterations = 200; // 200 * 50 ms = 10 s ceiling.
      final expected = <String>{for (var i = 0; i < burst; i++) 'Burst $i'};
      var refs = <String>{};
      for (var poll = 0; poll < maxPollIterations; poll++) {
        refs = (await database.completionEventDao.getEventsByProfile(
          1,
        )).map((e) => e.sefariaRef).toSet();
        if (refs.containsAll(expected)) break;
        await Future<void>.delayed(pollInterval);
      }

      expect(
        refs,
        containsAll(expected),
        reason:
            'I1: every snapshot delivered in the burst must be merged — no '
            'snapshot may be dropped because a prior merge had not yet '
            'released the completions merge lock',
      );
      expect(
        refs.length,
        equals(burst),
        reason: 'I1: exactly the burst completions are merged, no more',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('I6 — snake_case remote completion merges', () {
    late UserDatabase database;
    late _MockFirestoreDataSource firestore;
    late _MockConnectivityService connectivity;
    late StreamController<List<Map<String, dynamic>>> completionsController;
    late OfflineQueue offlineQueue;
    late SyncEngine engine;
    late int trackId;

    setUp(() async {
      database = _inMemoryDb();
      await seedProfile(database);
      trackId = await _insertTrack(database);
      completionsController =
          StreamController<List<Map<String, dynamic>>>.broadcast();
      firestore = _MockFirestoreDataSource();
      connectivity = _MockConnectivityService();
      when(() => connectivity.isOnline).thenAnswer((_) async => true);
      when(() => firestore.isAuthenticated).thenReturn(true);
      when(() => firestore.profileId).thenReturn(1);
      when(
        () => firestore.listenToCompletions(),
      ).thenAnswer((_) => completionsController.stream);
      when(
        () => firestore.listenToBookmarks(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToSettings(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToStreak(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToGoals(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToProfilePrograms(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToLedgerEntries(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToCurriculumTracks(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToNotificationSettings(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToGamificationSettings(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToUiPreferences(),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => firestore.listenToLearningOrder(),
      ).thenAnswer((_) => const Stream.empty());
      offlineQueue = OfflineQueue(
        database: database,
        firestoreGateway: _ConcurrencyTrackingGateway(),
        logger: AppLogger(Talker()),
      );
      engine = SyncEngine(
        database: database,
        firestoreDataSource: firestore,
        offlineQueue: offlineQueue,
        logger: AppLogger(Talker()),
        connectivityService: connectivity,
      );
    });

    tearDown(() async {
      await engine.dispose();
      await completionsController.close();
      await database.close();
    });

    test(
      'I6: a remote completion with the exact snake_case keys the production '
      'outbox payload now emits is merged (insertedCount increments)',
      () async {
        await engine.attachListeners();

        // The EXACT key set the reworked outbox `payload` emits:
        // profile_id, curriculum_id, sefaria_ref, stage_id, track_type,
        // track_id, completed_at, points — all snake_case.
        completionsController.add([
          {
            'profile_id': 1,
            'curriculum_id': 'mishnayos',
            'sefaria_ref': 'Berakhot 3:1',
            'stage_id': 2,
            'track_type': 'personal',
            'track_id': trackId,
            'completed_at': DateTime.utc(2026, 5, 17, 10).toIso8601String(),
            'points': 5,
          },
        ]);

        await Future<void>.delayed(const Duration(milliseconds: 500));

        final events = await database.completionEventDao.getEventsByProfile(1);
        expect(
          events.length,
          equals(1),
          reason:
              'I6: the snake_case remote completion must merge — it must not '
              'be skipped as invalid because a key was unrecognised',
        );
        final event = events.single;
        expect(event.sefariaRef, equals('Berakhot 3:1'));
        expect(
          event.stageId,
          equals(2),
          reason: 'I6: stage_id must be read from the snake_case key',
        );
      },
    );

    test(
      'I6: a legacy camelCase `stageId` key still merges (fallback chain)',
      () async {
        await engine.attachListeners();

        // A lingering legacy Firestore doc using camelCase `stageId`.
        completionsController.add([
          {
            'profileId': 1,
            'curriculumId': 'mishnayos',
            'sefariaRef': 'Berakhot 4:1',
            'stageId': 3,
            'trackType': 'personal',
            'trackId': trackId,
            'completedAt': DateTime.utc(2026, 5, 17, 11).toIso8601String(),
          },
        ]);

        await Future<void>.delayed(const Duration(milliseconds: 500));

        final events = await database.completionEventDao.getEventsByProfile(1);
        expect(
          events.length,
          equals(1),
          reason:
              'I6: the camelCase `stageId` fallback must let legacy docs '
              'still merge',
        );
        expect(events.single.stageId, equals(3));
      },
    );

    test('a remote completion for a non-existent profile is skipped, not '
        'orphan-inserted (no FK 787 crash)', () async {
      await engine.attachListeners();

      // profile_id 999 has no learner_profiles row. completion_events.profileId
      // is an FK to learner_profiles — after an account/profile deletion the
      // parent row is gone. The merge must skip the row, never crash on the
      // foreign-key constraint.
      completionsController.add([
        {
          'profile_id': 999,
          'curriculum_id': 'mishnayos',
          'sefaria_ref': 'Berakhot 5:1',
          'stage_id': 1,
          'track_type': 'personal',
          'completed_at': DateTime.utc(2026, 5, 17, 12).toIso8601String(),
          'points': 5,
        },
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(
        await database.completionEventDao.getEventsByProfile(999),
        isEmpty,
        reason:
            'a completion whose profile has no learner_profiles row '
            'must be skipped, never orphan-inserted',
      );
      // The engine survived — a subsequent valid completion still merges.
      completionsController.add([
        {
          'profile_id': 1,
          'curriculum_id': 'mishnayos',
          'sefaria_ref': 'Berakhot 5:2',
          'stage_id': 1,
          'track_type': 'personal',
          'track_id': trackId,
          'completed_at': DateTime.utc(2026, 5, 17, 13).toIso8601String(),
          'points': 5,
        },
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(
        (await database.completionEventDao.getEventsByProfile(1)).length,
        equals(1),
        reason: 'the orphan skip must not poison later valid merges',
      );
    });
  });

  group(
    'S8 — SyncOrchestratorImpl.pullOnLaunch once-per-launch + throttle',
    () {
      late _FetchPageCountingGateway gateway;
      late SyncOrchestratorImpl orchestrator;

      /// `fetchPage` calls issued by one full `pullOnLaunch` — one empty page
      /// per pulled collection (completions, bookmarks, settings, tracks,
      /// learner_profiles, learning_order, profile_programs).
      const fetchesPerPull = 7;

      setUp(() {
        // pullOnLaunch reads/writes SharedPreferences for the resume throttle.
        SharedPreferences.setMockInitialValues(<String, Object>{});
        gateway = _FetchPageCountingGateway();
        orchestrator = SyncOrchestratorImpl(
          resolveEngine: () =>
              throw StateError('S8: pullOnLaunch must not touch the engine'),
          resolveMergeRouter: () =>
              MergeRouter(mergers: const <String, EntityMerger>{}),
          resolveGateway: () => gateway,
          resolveProfileId: () => 1,
        );
      });

      test(
        'S8: a second cold-start pullOnLaunch in the same launch is a no-op',
        () async {
          await orchestrator.pullOnLaunch();
          expect(
            gateway.fetchPageCalls,
            equals(fetchesPerPull),
            reason: 'S8: the first cold-start pullOnLaunch must run',
          );

          // A second non-resume call — e.g. the sign-in screen and the
          // lifecycle observer both firing on the same launch.
          await orchestrator.pullOnLaunch();
          expect(
            gateway.fetchPageCalls,
            equals(fetchesPerPull),
            reason:
                'S8: the once-per-launch guard must make the second cold-start '
                'pullOnLaunch a no-op (no further fetches)',
          );
        },
      );

      test(
        'S8: a resume-triggered pull within the throttle window is skipped',
        () async {
          await orchestrator.pullOnLaunch();
          expect(gateway.fetchPageCalls, equals(fetchesPerPull));

          // A resume pull immediately after — within the 5-minute throttle.
          await orchestrator.pullOnLaunch(triggeredFromResume: true);
          expect(
            gateway.fetchPageCalls,
            equals(fetchesPerPull),
            reason:
                'S8: a resume pull inside pullOnResumeMinInterval must be '
                'throttled — no extra fetches',
          );
        },
      );

      test(
        'S8: DeviceRestoreService.retry path — a failed cold-start pull resets '
        'the guard so a subsequent pull re-runs',
        () async {
          // A gateway whose first pull throws, then succeeds — models a
          // transient failure followed by a retry.
          final flakyGateway = _FlakyFetchGateway();
          final retryOrchestrator = SyncOrchestratorImpl(
            resolveEngine: () =>
                throw StateError('S8: pullOnLaunch must not touch the engine'),
            resolveMergeRouter: () =>
                MergeRouter(mergers: const <String, EntityMerger>{}),
            resolveGateway: () => flakyGateway,
            resolveProfileId: () => 1,
          );

          // First pull fails — pullOnLaunch rethrows.
          await expectLater(
            retryOrchestrator.pullOnLaunch(),
            throwsA(isA<Exception>()),
          );

          // The guard was reset on failure, so a retry genuinely re-pulls
          // (this is the DeviceRestoreService.retry() path).
          flakyGateway.failNextPull = false;
          await retryOrchestrator.pullOnLaunch();
          expect(
            flakyGateway.successfulPullCount,
            equals(1),
            reason:
                'S8 / I4: after a failed cold-start pull the once-per-launch '
                'guard must reset so DeviceRestoreService.retry() can re-pull',
          );
        },
      );
    },
  );
}

/// [FirestoreGateway] whose `fetchPage` throws on the first pull when
/// [failNextPull] is true, and otherwise returns empty pages. Tracks how many
/// `pullOnLaunch` runs completed without an error.
class _FlakyFetchGateway implements FirestoreGateway {
  bool failNextPull = true;
  int _fetchesThisPull = 0;
  int successfulPullCount = 0;

  @override
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async {
    if (failNextPull) {
      throw Exception('S8: simulated transient pull failure');
    }
    _fetchesThisPull++;
    // A full pullOnLaunch issues 6 collection pulls; count one successful run
    // once every collection has been fetched.
    if (_fetchesThisPull == 6) {
      successfulPullCount++;
      _fetchesThisPull = 0;
    }
    return const FirestorePage(rows: []);
  }

  // ── Unused stubs ──────────────────────────────────────────────────────────
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
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async => [];
  @override
  Future<Map<String, dynamic>?> fetchDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) async => null;
}

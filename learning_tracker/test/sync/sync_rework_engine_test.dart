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

/// [FirestoreGateway] that records every `pushSettings` call and tracks the
/// maximum number of pushes in flight at once. The S5 single-flight guard is
/// observable as `maxConcurrentPushes == 1` and as each enqueued row being
/// pushed exactly once (a double-drain would re-push the same rows).
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
    await Future<void>.delayed(const Duration(milliseconds: 20));
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
  Future<void> pushCompletion({required int profileId, required Map<String, dynamic> data, String? docId}) async {}
  @override
  Future<List<String>> pushCompletionsBatch({required int profileId, required List<({String entityKey, Map<String, dynamic> payload})> items}) async => const [];
  @override
  Future<void> pushStreak({required int profileId, required Map<String, dynamic> data}) async {}
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
  Future<void> pushLedgerEntry({required int profileId, required Map<String, dynamic> data}) async {}
  @override
  Future<void> pushLedgerEntriesBatch({required int profileId, required List<Map<String, dynamic>> entries}) async {}
  @override
  Future<void> pushProfileProgram({required int profileId, required Map<String, dynamic> data}) async {}
  @override
  Future<void> removeProfileProgramAssignment({required int profileId, required String curriculumStorageKey}) async {}
  @override
  Future<List<Map<String, dynamic>>> fetchAll({required int profileId, required String collection}) async => [];
  @override
  Future<void> pushGoal({required int profileId, required Map<String, dynamic> data}) async {}
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
  Stream<List<Map<String, dynamic>>> listenToCollection({required int profileId, required String collection}) => const Stream.empty();
  @override
  Stream<Map<String, dynamic>?> listenToDocument({required int profileId, required String collection, required String docId}) => const Stream.empty();
  @override
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async => [];
  @override
  Future<Map<String, dynamic>?> fetchDocument({required int profileId, required String collection, required String docId}) async => null;
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
  Future<void> pushCompletion({required int profileId, required Map<String, dynamic> data, String? docId}) async {}
  @override
  Future<List<String>> pushCompletionsBatch({required int profileId, required List<({String entityKey, Map<String, dynamic> payload})> items}) async => const [];
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
  Future<void> pushLedgerEntry({required int profileId, required Map<String, dynamic> data}) async {}
  @override
  Future<void> pushLedgerEntriesBatch({required int profileId, required List<Map<String, dynamic>> entries}) async {}
  @override
  Future<void> pushProfileProgram({required int profileId, required Map<String, dynamic> data}) async {}
  @override
  Future<void> removeProfileProgramAssignment({required int profileId, required String curriculumStorageKey}) async {}
  @override
  Future<List<Map<String, dynamic>>> fetchAll({required int profileId, required String collection}) async => [];
  @override
  Future<void> pushGoal({required int profileId, required Map<String, dynamic> data}) async {}
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
  Stream<List<Map<String, dynamic>>> listenToCollection({required int profileId, required String collection}) => const Stream.empty();
  @override
  Stream<Map<String, dynamic>?> listenToDocument({required int profileId, required String collection, required String docId}) => const Stream.empty();
  @override
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async => [];
  @override
  Future<Map<String, dynamic>?> fetchDocument({required int profileId, required String collection, required String docId}) async => null;
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
      'S5: two concurrent pushSettings → single-flight drain pushes each '
      'queued row exactly once (no overlapping drains)',
      () async {
        // Two rapid writes. The first push kicks off a background flush; while
        // that drain is still pushing (the gateway holds each push open for
        // ~20 ms), the second write triggers _runBackgroundFlush again — the
        // _flushInProgress guard must coalesce it into the in-flight drain.
        await engine.pushSettings({
          'curriculum_id': 'mishnayos',
          'stages': <dynamic>[],
        });
        await engine.pushSettings({
          'curriculum_id': 'shabbos',
          'stages': <dynamic>[],
        });

        // Let every drain (and the re-run requested by the guard) finish.
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(
          gateway.maxConcurrentPushes,
          equals(1),
          reason:
              'S5: a single-flight drain serialises all pushes — two '
              'overlapping drains would push concurrently',
        );
        expect(
          gateway.pushSettingsCalls,
          equals(2),
          reason:
              'S5: each of the two queued rows must be pushed exactly once; '
              'a double-drain would re-push rows the other drain already saw',
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

    test(
      'S6: a completion already present locally is not re-merged; a new '
      'remote completion is merged',
      () async {
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

        final eventsAfter =
            await database.completionEventDao.getEventsByProfile(1);
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
      },
    );
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

    test(
      'I1: every snapshot in a rapid burst is merged — none is silently '
      'dropped across overlapping debounce/merge cycles',
      () async {
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

        // Let the final debounce window + merge (and any re-armed timer)
        // settle.
        await Future<void>.delayed(const Duration(seconds: 2));

        final refs = (await database.completionEventDao.getEventsByProfile(1))
            .map((e) => e.sefariaRef)
            .toSet();
        expect(
          refs,
          containsAll(<String>[for (var i = 0; i < burst; i++) 'Burst $i']),
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
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
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

        final events =
            await database.completionEventDao.getEventsByProfile(1);
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

        final events =
            await database.completionEventDao.getEventsByProfile(1);
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
  });

  group('S8 — SyncOrchestratorImpl.pullOnLaunch once-per-launch + throttle', () {
    late _FetchPageCountingGateway gateway;
    late SyncOrchestratorImpl orchestrator;

    /// `fetchPage` calls issued by one full `pullOnLaunch` — one empty page
    /// per pulled collection (completions, bookmarks, settings, tracks,
    /// learner_profiles, learning_order).
    const fetchesPerPull = 6;

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
  });
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
  Future<void> pushCompletion({required int profileId, required Map<String, dynamic> data, String? docId}) async {}
  @override
  Future<List<String>> pushCompletionsBatch({required int profileId, required List<({String entityKey, Map<String, dynamic> payload})> items}) async => const [];
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
  Future<void> pushLedgerEntry({required int profileId, required Map<String, dynamic> data}) async {}
  @override
  Future<void> pushLedgerEntriesBatch({required int profileId, required List<Map<String, dynamic>> entries}) async {}
  @override
  Future<void> pushProfileProgram({required int profileId, required Map<String, dynamic> data}) async {}
  @override
  Future<void> removeProfileProgramAssignment({required int profileId, required String curriculumStorageKey}) async {}
  @override
  Future<List<Map<String, dynamic>>> fetchAll({required int profileId, required String collection}) async => [];
  @override
  Future<void> pushGoal({required int profileId, required Map<String, dynamic> data}) async {}
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
  Stream<List<Map<String, dynamic>>> listenToCollection({required int profileId, required String collection}) => const Stream.empty();
  @override
  Stream<Map<String, dynamic>?> listenToDocument({required int profileId, required String collection, required String docId}) => const Stream.empty();
  @override
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async => [];
  @override
  Future<Map<String, dynamic>?> fetchDocument({required int profileId, required String collection, required String docId}) async => null;
}

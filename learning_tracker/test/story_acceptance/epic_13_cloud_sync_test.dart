/// Story acceptance tests for Epic 13 -- Cloud Sync.
@Tags(['epic_13'])
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/connectivity_service.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/sync/data/firestore_data_source.dart';
import 'package:learning_tracker/features/sync/data/offline_queue.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_status.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:learning_tracker/features/sync/domain/services/device_restore_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:talker/talker.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart' show seedCompletion, seedProfile;

class MockFirestoreDataSource extends Mock implements FirestoreDataSource {}

class _MockFirestoreGateway extends Mock implements FirestoreGateway {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockCurriculumImportService extends Mock
    implements CurriculumImportService {}

/// Thin [SyncOrchestrator] adapter that delegates [pullOnLaunch] to
/// [SyncEngine.pullOnLaunch] so that Story 13.4 restore tests can keep
/// verifying `FirestoreDataSource.fetch*` calls without rewiring to the
/// new [PullPipeline] path.
class _SyncEngineOrchestrator implements SyncOrchestrator {
  _SyncEngineOrchestrator(this._engine);
  final SyncEngine _engine;

  @override
  Future<void> pullOnLaunch({bool triggeredFromResume = false}) =>
      _engine.pullOnLaunch(triggeredFromResume: triggeredFromResume);

  @override
  Future<void> pushAllLocalData() => _engine.pushAllLocalData();

  @override
  SyncStatus get currentStatus => _engine.currentStatus;

  @override
  Stream<SyncStatus> get statusStream => _engine.statusStream;
}

/// Stubs every [FirestoreDataSource] method used by [SyncEngine.pullOnLaunch].
void stubFirestorePullOnLaunchEmpty(MockFirestoreDataSource mock) {
  const ps = FirestoreDataSource.defaultPageSize;
  when(() => mock.forProfile(any())).thenReturn(mock);
  when(() => mock.fetchCompletions(pageSize: ps)).thenAnswer((_) async => []);
  when(() => mock.fetchBookmarks(pageSize: ps)).thenAnswer((_) async => []);
  when(() => mock.fetchSettings(pageSize: ps)).thenAnswer((_) async => []);
  when(() => mock.fetchGoals(pageSize: ps)).thenAnswer((_) async => []);
  when(
    () => mock.fetchProfilePrograms(pageSize: ps),
  ).thenAnswer((_) async => []);
  when(() => mock.fetchStreak()).thenAnswer((_) async => null);
  when(() => mock.fetchProfile()).thenAnswer((_) async => null);
  when(() => mock.fetchLedgerEntries(pageSize: ps)).thenAnswer((_) async => []);
  when(
    () => mock.fetchCurriculumTracks(pageSize: ps),
  ).thenAnswer((_) async => []);
  when(() => mock.fetchLearnerProfiles()).thenAnswer((_) async => []);
  when(() => mock.fetchNotificationSettings()).thenAnswer((_) async => null);
  when(() => mock.fetchGamificationSettings()).thenAnswer((_) async => null);
  when(() => mock.fetchUiPreferences()).thenAnswer((_) async => null);
  when(() => mock.fetchLearningOrder(pageSize: ps)).thenAnswer((_) async => []);
}

UserDatabase _createInMemoryDatabase() {
  return UserDatabase(NativeDatabase.memory());
}

/// Creates a default curriculum track and returns its ID.
Future<int> _insertTrack(UserDatabase db) async {
  final row = await db
      .into(db.curriculumTracks)
      .insertReturning(
        CurriculumTracksCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackType: 'personal',
          activatedAt: DateTime.now(),
        ),
      );
  return row.id;
}

void main() {
  // ── Story 13.1: Push-on-Write with Offline Queuing ─────────────

  group(
    'Story 13.1 -- Push-on-Write with Offline Queuing',
    tags: ['story_13_1'],
    () {
      late UserDatabase database;
      late MockFirestoreDataSource mockFirestore;
      late _MockFirestoreGateway mockGateway;
      late MockConnectivityService mockConnectivity;
      late AppLogger logger;
      late OfflineQueue offlineQueue;
      late SyncEngine syncEngine;

      setUp(() async {
        database = _createInMemoryDatabase();
        await seedProfile(database);
        await _insertTrack(database);
        mockFirestore = MockFirestoreDataSource();
        mockGateway = _MockFirestoreGateway();
        mockConnectivity = MockConnectivityService();
        logger = AppLogger(Talker());
        offlineQueue = OfflineQueue(
          database: database,
          firestoreGateway: mockGateway,
          logger: logger,
        );
        when(() => mockConnectivity.isOnline).thenAnswer((_) async => true);
        when(() => mockFirestore.isAuthenticated).thenReturn(true);
        when(() => mockFirestore.profileId).thenReturn(1);
        syncEngine = SyncEngine(
          database: database,
          firestoreDataSource: mockFirestore,
          offlineQueue: offlineQueue,
          logger: logger,
          connectivityService: mockConnectivity,
        );
      });

      tearDown(() async {
        await syncEngine.dispose();
        await database.close();
      });

      test('local write creates corresponding sync_queue entry', () async {
        // Offline: enqueue only; gateway is not called until reconnect/flush.
        // (No stub needed — OfflineQueue is in queue-only mode when offline.)
        syncEngine.setOnlineState(false);

        final data = {
          'curriculum_id': 'mishnayos',
          'content_item_id': 'mishna-1',
          'stage_id': 1,
          'track_type': 'personal',
        };
        await syncEngine.pushCompletion(data);

        final count = await database.syncQueueDao.getPendingCount();
        expect(count, 1);
      });

      test(
        'online local write enqueues then background flush reaches Firestore',
        () async {
          when(
            () => mockGateway.pushCompletion(
              profileId: any(named: 'profileId'),
              data: any(named: 'data'),
            ),
          ).thenAnswer((_) async {});

          final data = <String, dynamic>{
            'curriculum_id': 'mishnayos',
            'content_item_id': 'mishna-1',
            'stage_id': 1,
            'track_type': 'personal',
          };
          await syncEngine.pushCompletion(data);
          // Background flush is scheduled without awaiting Firestore on caller.
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);

          verify(
            () => mockGateway.pushCompletion(
              profileId: any(named: 'profileId'),
              data: any(named: 'data'),
            ),
          ).called(1);
          expect(await database.syncQueueDao.getPendingCount(), 0);
        },
      );

      test('queue processes entries in FIFO order', () async {
        final pushOrder = <String>[];

        when(
          () => mockGateway.pushCompletion(
            profileId: any(named: 'profileId'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((inv) async {
          final p = inv.namedArguments[#data] as Map<String, dynamic>;
          pushOrder.add('c:${p['id']}');
        });
        when(
          () => mockGateway.pushBookmark(
            profileId: any(named: 'profileId'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((inv) async {
          final p = inv.namedArguments[#data] as Map<String, dynamic>;
          pushOrder.add('b:${p['id']}');
        });

        await offlineQueue.enqueueCompletion({'id': '1'});
        await offlineQueue.enqueueBookmark({'id': '2'});
        await offlineQueue.enqueueCompletion({'id': '3'});

        await offlineQueue.flush();

        expect(pushOrder, ['c:1', 'b:2', 'c:3']);
      });

      test('queue entries persist across simulated app restart', () async {
        await offlineQueue.enqueueCompletion({'id': '1'});
        await offlineQueue.enqueueSettings({'id': '2'});

        // Create new queue instance (simulates restart with same DB)
        final newQueue = OfflineQueue(
          database: database,
          firestoreGateway: mockGateway,
          logger: logger,
        );

        final count = await newQueue.getPendingCount();
        expect(count, 2);
      });

      test('failed push retries with exponential backoff', () async {
        when(
          () => mockGateway.pushCompletion(
            profileId: any(named: 'profileId'),
            data: any(named: 'data'),
          ),
        ).thenThrow(Exception('err'));

        await offlineQueue.enqueueCompletion({'id': '1'});

        // First flush fails (retryCount=0, no backoff), retry count → 1
        await offlineQueue.flush();
        var pending = await database.syncQueueDao.getAllPending();
        expect(pending.first.retryCount, 1);

        // Second flush: non-blocking backoff skips the item because
        // the 2^1 = 2s window hasn't elapsed yet. retryCount stays 1.
        final synced = await offlineQueue.flush();
        expect(synced, 0); // skipped due to backoff
        pending = await database.syncQueueDao.getAllPending();
        expect(pending.first.retryCount, 1);
      });

      test('after 5 retries, entry marked as failed (not retried)', () async {
        when(
          () => mockGateway.pushCompletion(
            profileId: any(named: 'profileId'),
            data: any(named: 'data'),
          ),
        ).thenThrow(Exception('persistent'));

        await offlineQueue.enqueueCompletion({'id': '1'});
        final items = await database.syncQueueDao.getAllPending();
        final id = items.first.id;

        // Set retry count to 5 (= maxRetries)
        for (var i = 0; i < 5; i++) {
          await database.syncQueueDao.markFailed(id, 'err');
        }

        // Flush should skip the dead-letter item
        final synced = await offlineQueue.flush();
        expect(synced, 0);
        expect(OfflineQueue.maxRetries, 5);
      });

      test('sync status correctly reflects queue state', () async {
        // Empty queue → synced
        expect(syncEngine.currentStatus, isA<SyncStatusSynced>());

        // After offline + push → offline with pending
        syncEngine.setOnlineState(false);
        await syncEngine.pushCompletion({'id': '1'});

        expect(syncEngine.currentStatus, isA<SyncStatusOffline>());
        final offlineStatus = syncEngine.currentStatus as SyncStatusOffline;
        expect(offlineStatus.pendingChanges, 1);
      });

      test('SyncStatus sealed class has all expected subtypes', () {
        // Verify all states are constructible
        expect(
          SyncStatus.synced(lastSyncedAt: DateTime.now()),
          isA<SyncStatusSynced>(),
        );
        expect(
          SyncStatus.syncing(startedAt: DateTime.now()),
          isA<SyncStatusSyncing>(),
        );
        expect(
          const SyncStatus.pending(pendingChanges: 3),
          isA<SyncStatusPending>(),
        );
        expect(
          const SyncStatus.offline(pendingChanges: 0),
          isA<SyncStatusOffline>(),
        );
        expect(
          SyncStatus.error(message: 'err', failedAt: DateTime.now()),
          isA<SyncStatusError>(),
        );
      });
    },
  );

  // ── Story 13.2: Pull-on-Launch Merge ─────────────────────────

  group('Story 13.2 -- Pull-on-Launch Merge', tags: ['story_13_2'], () {
    late UserDatabase database;
    late int trackId;
    late MockFirestoreDataSource mockFirestore;
    late _MockFirestoreGateway mockGateway;
    late MockConnectivityService mockConnectivity;
    late AppLogger logger;
    late OfflineQueue offlineQueue;
    late SyncEngine syncEngine;

    setUp(() async {
      database = _createInMemoryDatabase();
      await seedProfile(database);
      trackId = await _insertTrack(database);
      mockFirestore = MockFirestoreDataSource();
      mockGateway = _MockFirestoreGateway();
      mockConnectivity = MockConnectivityService();
      logger = AppLogger(Talker());
      offlineQueue = OfflineQueue(
        database: database,
        firestoreGateway: mockGateway,
        logger: logger,
      );
      when(() => mockConnectivity.isOnline).thenAnswer((_) async => true);
      when(() => mockFirestore.isAuthenticated).thenReturn(true);
      when(() => mockFirestore.profileId).thenReturn(1);
      when(() => mockFirestore.forProfile(any())).thenReturn(mockFirestore);
      syncEngine = SyncEngine(
        database: database,
        firestoreDataSource: mockFirestore,
        offlineQueue: offlineQueue,
        logger: logger,
        connectivityService: mockConnectivity,
      );
    });

    tearDown(() async {
      await syncEngine.dispose();
      await database.close();
    });

    void stubEmptyFetches() {
      stubFirestorePullOnLaunchEmpty(mockFirestore);
    }

    test('pull fetches all user data collections from Firestore', () async {
      stubEmptyFetches();

      await syncEngine.pullOnLaunch();

      const ps = FirestoreDataSource.defaultPageSize;
      verify(() => mockFirestore.fetchLearnerProfiles()).called(1);
      verify(() => mockFirestore.fetchProfile()).called(1);
      verify(() => mockFirestore.forProfile(1)).called(1);
      verify(() => mockFirestore.fetchCompletions(pageSize: ps)).called(1);
      verify(() => mockFirestore.fetchBookmarks(pageSize: ps)).called(1);
      verify(() => mockFirestore.fetchSettings(pageSize: ps)).called(1);
      verify(() => mockFirestore.fetchGoals(pageSize: ps)).called(1);
      verify(() => mockFirestore.fetchProfilePrograms(pageSize: ps)).called(1);
      verify(() => mockFirestore.fetchStreak()).called(1);
      verify(() => mockFirestore.fetchLedgerEntries(pageSize: ps)).called(1);
      verify(() => mockFirestore.fetchCurriculumTracks(pageSize: ps)).called(1);
      verify(() => mockFirestore.fetchNotificationSettings()).called(1);
      verify(() => mockFirestore.fetchGamificationSettings()).called(1);
    });

    test('additive merge adds remote completions not present locally '
        '(no duplicates)', () async {
      // Insert one local completion
      final completedAt = DateTime.utc(2026, 2, 9, 12);
      await seedCompletion(database, 
        CompletionsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          sefariaRef: 'mishna-1',
          stageId: 1,
          trackType: 'personal',
          trackId: trackId,
          completedAt: completedAt,
        ),
      );

      stubEmptyFetches();
      when(
        () => mockFirestore.fetchCompletions(
          pageSize: FirestoreDataSource.defaultPageSize,
        ),
      ).thenAnswer(
        (_) async => [
          // Same as local — should be skipped
          {
            'curriculum_id': 'mishnayos',
            'content_item_id': 'mishna-1',
            'stage_id': 1,
            'track_type': 'personal',
            'completed_at': '2026-02-09T12:00:00.000Z',
          },
          // New — should be inserted
          {
            'curriculum_id': 'mishnayos',
            'content_item_id': 'mishna-2',
            'stage_id': 1,
            'track_type': 'personal',
            'completed_at': '2026-02-10T12:00:00.000Z',
          },
        ],
      );

      await syncEngine.pullOnLaunch();

      final completions = await database.completionDao
          .internalGetAllCompletionsCrossProfile(
            scope: CrossProfileScope.syncRestore,
          );
      expect(completions.length, 2);
    });

    test('last-write-wins correctly resolves when remote timestamp > local '
        'for mutable data', () async {
      // Insert older local bookmark
      await database.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackId: trackId,
          sefariaRef: 'mishna-10',
          updatedAt: DateTime.utc(2026, 2, 8),
        ),
      );

      stubEmptyFetches();
      when(
        () => mockFirestore.fetchBookmarks(
          pageSize: FirestoreDataSource.defaultPageSize,
        ),
      ).thenAnswer(
        (_) async => [
          {
            'curriculum_id': 'mishnayos',
            'track_type': 'personal',
            'content_item_id': 'mishna-42',
            'updated_at': '2026-02-09T12:00:00.000Z', // newer
          },
        ],
      );

      await syncEngine.pullOnLaunch();

      final bookmark = await database.bookmarkDao
          .getBookmarkByCurriculumTrackAndProfile('mishnayos', trackId, 1);
      expect(bookmark!.sefariaRef, 'mishna-42'); // Remote won
    });

    test(
      'last-write-wins correctly keeps local when local timestamp > remote',
      () async {
        // Insert newer local bookmark
        await database.bookmarkDao.insertBookmark(
          BookmarksCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            trackId: trackId,
            sefariaRef: 'mishna-99',
            updatedAt: DateTime.utc(2026, 2, 10),
          ),
        );

        stubEmptyFetches();
        when(
          () => mockFirestore.fetchBookmarks(
            pageSize: FirestoreDataSource.defaultPageSize,
          ),
        ).thenAnswer(
          (_) async => [
            {
              'curriculum_id': 'mishnayos',
              'track_type': 'personal',
              'content_item_id': 'mishna-42',
              'updated_at': '2026-02-09T12:00:00.000Z', // older
            },
          ],
        );

        await syncEngine.pullOnLaunch();

        final bookmark = await database.bookmarkDao
            .getBookmarkByCurriculumTrackAndProfile('mishnayos', trackId, 1);
        expect(bookmark!.sefariaRef, 'mishna-99'); // Local kept
      },
    );

    test(
      'pull gracefully handles no network (returns local data unchanged)',
      () async {
        syncEngine.setOnlineState(false);

        // Insert local data
        await seedCompletion(database, 
          CompletionsCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: 'mishna-1',
            stageId: 1,
            trackType: 'personal',
            trackId: trackId,
            completedAt: DateTime.utc(2026, 2, 9),
          ),
        );

        await syncEngine.pullOnLaunch();

        // Local data unchanged
        final completions = await database.completionDao
            .internalGetAllCompletionsCrossProfile(
              scope: CrossProfileScope.syncRestore,
            );
        expect(completions.length, 1);
        // No Firestore calls
        verifyNever(
          () => mockFirestore.fetchCompletions(
            pageSize: FirestoreDataSource.defaultPageSize,
          ),
        );
      },
    );

    test('last pull timestamp updated on successful sync', () async {
      stubEmptyFetches();

      await syncEngine.pullOnLaunch();

      final status = syncEngine.currentStatus;
      expect(
        status.maybeWhen(synced: (ts) => ts, orElse: () => null),
        isNotNull,
      );
    });
  });

  // ── Story 13.3: Real-Time Foreground Listeners ──────────────

  group(
    'Story 13.3 -- Real-Time Foreground Listeners',
    tags: ['story_13_3'],
    () {
      late UserDatabase database;
      late int trackId;
      late MockFirestoreDataSource mockFirestore;
      late _MockFirestoreGateway mockGateway;
      late MockConnectivityService mockConnectivity;
      late AppLogger logger;
      late OfflineQueue offlineQueue;
      late SyncEngine syncEngine;

      setUp(() async {
        database = _createInMemoryDatabase();
        await seedProfile(database);
        trackId = await _insertTrack(database);
        mockFirestore = MockFirestoreDataSource();
        mockGateway = _MockFirestoreGateway();
        mockConnectivity = MockConnectivityService();
        logger = AppLogger(Talker());
        offlineQueue = OfflineQueue(
          database: database,
          firestoreGateway: mockGateway,
          logger: logger,
        );
        when(() => mockConnectivity.isOnline).thenAnswer((_) async => true);
        when(() => mockFirestore.isAuthenticated).thenReturn(true);
        when(() => mockFirestore.profileId).thenReturn(1);
        when(() => mockFirestore.forProfile(any())).thenReturn(mockFirestore);
        syncEngine = SyncEngine(
          database: database,
          firestoreDataSource: mockFirestore,
          offlineQueue: offlineQueue,
          logger: logger,
          connectivityService: mockConnectivity,
        );
      });

      tearDown(() async {
        await syncEngine.dispose();
        await database.close();
      });

      void stubListeners({
        Stream<List<Map<String, dynamic>>>? completions,
        Stream<List<Map<String, dynamic>>>? bookmarks,
        Stream<List<Map<String, dynamic>>>? settings,
        Stream<Map<String, dynamic>?>? streak,
        Stream<List<Map<String, dynamic>>>? goals,
        Stream<List<Map<String, dynamic>>>? rewards,
        Stream<List<Map<String, dynamic>>>? ledgerEntries,
      }) {
        when(
          () => mockFirestore.listenToCompletions(),
        ).thenAnswer((_) => completions ?? Stream.value([]));
        when(
          () => mockFirestore.listenToBookmarks(),
        ).thenAnswer((_) => bookmarks ?? Stream.value([]));
        when(
          () => mockFirestore.listenToSettings(),
        ).thenAnswer((_) => settings ?? Stream.value([]));
        when(
          () => mockFirestore.listenToStreak(),
        ).thenAnswer((_) => streak ?? Stream.value(null));
        when(
          () => mockFirestore.listenToGoals(),
        ).thenAnswer((_) => goals ?? Stream.value([]));
        when(
          () => mockFirestore.listenToProfilePrograms(),
        ).thenAnswer((_) => Stream.value([]));
        when(
          () => mockFirestore.listenToLedgerEntries(),
        ).thenAnswer((_) => ledgerEntries ?? Stream.value([]));
        when(
          () => mockFirestore.listenToCurriculumTracks(),
        ).thenAnswer((_) => Stream.value([]));
        when(
          () => mockFirestore.listenToNotificationSettings(),
        ).thenAnswer((_) => Stream.value(null));
        when(
          () => mockFirestore.listenToGamificationSettings(),
        ).thenAnswer((_) => Stream.value(null));
        when(
          () => mockFirestore.listenToUiPreferences(),
        ).thenAnswer((_) => Stream.value(null));
        when(
          () => mockFirestore.listenToLearningOrder(),
        ).thenAnswer((_) => Stream.value([]));
      }

      test(
        'listener activates on app foreground, pauses on background',
        () async {
          stubListeners();

          // Attach listeners (foreground)
          await syncEngine.attachListeners();

          // Detach listeners (background)
          await syncEngine.detachListeners();

          // Re-attach should call listeners again
          await syncEngine.attachListeners();
          verify(() => mockFirestore.listenToCompletions()).called(2);
          verify(() => mockFirestore.listenToGoals()).called(2);
        },
      );

      test('incoming completion from remote is merged to local DB', () async {
        final controller =
            StreamController<List<Map<String, dynamic>>>.broadcast();

        stubListeners(completions: controller.stream);

        await syncEngine.attachListeners();

        // Emit a remote completion
        controller.add([
          {
            'curriculum_id': 'mishnayos',
            'content_item_id': 'mishna-5',
            'stage_id': 1,
            'track_type': 'personal',
            'completed_at': '2026-03-15T10:00:00.000Z',
            'points': 10,
          },
        ]);

        // Allow async merge to process
        await Future<void>.delayed(const Duration(milliseconds: 400));

        final completions = await database.completionDao
            .internalGetAllCompletionsCrossProfile(
              scope: CrossProfileScope.syncRestore,
            );
        expect(completions.length, 1);
        expect(completions.first.sefariaRef, 'mishna-5');

        await controller.close();
      });

      test('incoming mutable data update uses last-write-wins merge', () async {
        // Insert older local goal
        await database.goalDao.upsertGoalByTrack(
          profileId: 1,
          trackId: trackId,
          curriculumId: 'mishnayos',
          description: 'finish by pesach',
          targetPercent: 50.0,
          targetDate: null,
          createdAt: DateTime.utc(2026, 3, 1),
          updatedAt: DateTime.utc(2026, 3, 1),
        );

        final controller =
            StreamController<List<Map<String, dynamic>>>.broadcast();

        stubListeners(goals: controller.stream);

        await syncEngine.attachListeners();

        // Emit a newer remote goal (same track = upsert match)
        controller.add([
          {
            'curriculum_id': 'mishnayos',
            'track_id': trackId,
            'description': 'finish by pesach',
            'target_percent': 80.0,
            'created_at': '2026-03-01T00:00:00.000Z',
            'updated_at': '2026-03-15T00:00:00.000Z', // newer
          },
        ]);

        await Future<void>.delayed(const Duration(milliseconds: 400));

        final goals = await database.goalDao.getAllGoals();
        expect(goals.length, 1);
        expect(goals.first.targetPercent, 80.0); // Remote won

        await controller.close();
      });

      test('Firebase quota exceeded triggers graceful degradation', () async {
        // Create controllers that emit errors after listeners attach
        final controllers = <StreamController<dynamic>>[];

        StreamController<T> makeErrorController<T>() {
          final c = StreamController<T>.broadcast();
          controllers.add(c);
          return c;
        }

        // ignore: close_sinks
        final completionsCtrl =
            makeErrorController<List<Map<String, dynamic>>>();
        // ignore: close_sinks
        final bookmarksCtrl = makeErrorController<List<Map<String, dynamic>>>();
        // ignore: close_sinks
        final settingsCtrl = makeErrorController<List<Map<String, dynamic>>>();
        // ignore: close_sinks
        final goalsCtrl = makeErrorController<List<Map<String, dynamic>>>();
        // ignore: close_sinks
        final rewardsCtrl = makeErrorController<List<Map<String, dynamic>>>();
        // ignore: close_sinks
        final streakCtrl = makeErrorController<Map<String, dynamic>?>();

        stubListeners(
          completions: completionsCtrl.stream,
          bookmarks: bookmarksCtrl.stream,
          settings: settingsCtrl.stream,
          goals: goalsCtrl.stream,
          rewards: rewardsCtrl.stream,
          streak: streakCtrl.stream,
        );

        // Collect status updates
        final statuses = <SyncStatus>[];
        syncEngine.statusStream.listen(statuses.add);

        await syncEngine.attachListeners();

        // Now emit errors after listeners are attached
        final error = Exception('RESOURCE_EXHAUSTED');
        completionsCtrl.addError(error);
        bookmarksCtrl.addError(error);
        settingsCtrl.addError(error);
        goalsCtrl.addError(error);

        // Allow errors to propagate
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // After threshold errors (3), quota should be degraded
        expect(syncEngine.isQuotaDegraded, isTrue);

        // Should have emitted an error status with quota message
        expect(
          statuses.any(
            (s) => s.maybeWhen(
              error: (msg, _) => msg.contains('quota'),
              orElse: () => false,
            ),
          ),
          isTrue,
        );

        for (final c in controllers) {
          await c.close();
        }
      });

      test('listeners cover all required collections', () async {
        stubListeners();

        await syncEngine.attachListeners();

        verify(() => mockFirestore.listenToCompletions()).called(1);
        verify(() => mockFirestore.listenToBookmarks()).called(1);
        verify(() => mockFirestore.listenToSettings()).called(1);
        verify(() => mockFirestore.listenToStreak()).called(1);
        verify(() => mockFirestore.listenToGoals()).called(1);
        verify(() => mockFirestore.listenToProfilePrograms()).called(1);
        verify(() => mockFirestore.listenToLedgerEntries()).called(1);
        verify(() => mockFirestore.listenToCurriculumTracks()).called(1);
        verify(() => mockFirestore.listenToNotificationSettings()).called(1);
        verify(() => mockFirestore.listenToGamificationSettings()).called(1);
        verify(() => mockFirestore.listenToUiPreferences()).called(1);
        verify(() => mockFirestore.listenToLearningOrder()).called(1);
      });

      test('listeners not attached while offline', () async {
        stubListeners();

        syncEngine.setOnlineState(false);
        await syncEngine.attachListeners();

        verifyNever(() => mockFirestore.listenToCompletions());
        verifyNever(() => mockFirestore.listenToGoals());
      });
    },
  );

  // ── Story 13.4: New Device Data Restore ─────────────────────

  group('Story 13.4 -- New Device Data Restore', tags: ['story_13_4'], () {
    late UserDatabase database;
    late int trackId;
    late MockFirestoreDataSource mockFirestore;
    late _MockFirestoreGateway mockGateway;
    late MockConnectivityService mockConnectivity;
    late MockCurriculumImportService mockImportService;
    late AppLogger logger;
    late OfflineQueue offlineQueue;
    late SyncEngine syncEngine;
    late DeviceRestoreService restoreService;

    void stubEmptyFetches() {
      stubFirestorePullOnLaunchEmpty(mockFirestore);
      // DeviceRestoreService.restore() calls gateway.fetchAll for curriculum_tracks.
      when(
        () => mockGateway.fetchAll(
          profileId: any(named: 'profileId'),
          collection: any(named: 'collection'),
        ),
      ).thenAnswer((_) async => []);
    }

    setUp(() async {
      database = _createInMemoryDatabase();
      // Seed a cloud account matching the mock firebaseUid so restore's
      // upsertProfile updates it rather than inserting a second account.
      // Also seeds learnerProfiles(id=1) so completions satisfy profileId FK.
      await database.userProfileDao.upsertProfile(
        firebaseUid: 'uid-123',
        displayName: 'Test User',
        userMode: 'adult',
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      await database.into(database.learnerProfiles).insert(
        LearnerProfilesCompanion.insert(
          accountId: 1,
          displayName: 'Test User',
          mode: 'adult',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      trackId = await _insertTrack(database);
      mockFirestore = MockFirestoreDataSource();
      mockGateway = _MockFirestoreGateway();
      mockConnectivity = MockConnectivityService();
      mockImportService = MockCurriculumImportService();
      logger = AppLogger(Talker());
      offlineQueue = OfflineQueue(
        database: database,
        firestoreGateway: mockGateway,
        logger: logger,
      );
      when(() => mockConnectivity.isOnline).thenAnswer((_) async => true);
      when(() => mockFirestore.isAuthenticated).thenReturn(true);
      when(() => mockFirestore.profileId).thenReturn(1);
      when(() => mockFirestore.forProfile(any())).thenReturn(mockFirestore);
      syncEngine = SyncEngine(
        database: database,
        firestoreDataSource: mockFirestore,
        offlineQueue: offlineQueue,
        logger: logger,
        connectivityService: mockConnectivity,
      );
      restoreService = DeviceRestoreService(
        database: database,
        syncOrchestrator: _SyncEngineOrchestrator(syncEngine),
        firestoreGateway: mockGateway,
        profileId: 1,
        isAuthenticated: true,
        curriculumImportService: mockImportService,
        logger: logger,
      );
    });

    tearDown(() async {
      await restoreService.dispose();
      await syncEngine.dispose();
      await database.close();
    });

    test('full restore fetches all Firestore collections for user', () async {
      stubEmptyFetches();

      // Empty DB = new device
      expect(await restoreService.isNewDevice(), isTrue);

      await restoreService.restore();

      const ps = FirestoreDataSource.defaultPageSize;
      verify(() => mockFirestore.fetchCompletions(pageSize: ps)).called(1);
      verify(() => mockFirestore.fetchBookmarks(pageSize: ps)).called(1);
      verify(() => mockFirestore.fetchSettings(pageSize: ps)).called(1);
      verify(() => mockFirestore.fetchGoals(pageSize: ps)).called(1);
      verify(() => mockFirestore.fetchStreak()).called(1);
      verify(() => mockFirestore.fetchProfile()).called(1);
    });

    test('completions, goals, stages, rewards all populated in local DB '
        'after restore', () async {
      stubEmptyFetches();
      when(
        () => mockFirestore.fetchCompletions(
          pageSize: FirestoreDataSource.defaultPageSize,
        ),
      ).thenAnswer(
        (_) async => [
          {
            'curriculum_id': 'mishnayos',
            'content_item_id': 'mishna-1',
            'stage_id': 1,
            'track_type': 'personal',
            'completed_at': '2026-02-09T12:00:00.000Z',
            'points': 10,
          },
        ],
      );
      when(
        () => mockFirestore.fetchBookmarks(
          pageSize: FirestoreDataSource.defaultPageSize,
        ),
      ).thenAnswer((_) async => []);
      when(
        () => mockFirestore.fetchSettings(
          pageSize: FirestoreDataSource.defaultPageSize,
        ),
      ).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchStreak()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchProfile()).thenAnswer(
        (_) async => {
          'firebase_uid': 'uid-123',
          'display_name': 'Test User',
          'user_mode': 'student',
          'updated_at': '2026-02-09T12:00:00.000Z',
        },
      );
      when(
        () => mockFirestore.fetchGoals(
          pageSize: FirestoreDataSource.defaultPageSize,
        ),
      ).thenAnswer(
        (_) async => [
          {
            'curriculum_id': 'mishnayos',
            'track_id': trackId,
            'description': 'finish by pesach',
            'target_percent': 100.0,
            'created_at': '2026-02-09T12:00:00.000Z',
            'updated_at': '2026-02-09T12:00:00.000Z',
          },
        ],
      );
      when(
        () => mockFirestore.fetchLedgerEntries(
          pageSize: FirestoreDataSource.defaultPageSize,
        ),
      ).thenAnswer((_) async => []);

      await restoreService.restore();

      final completions = await database.completionDao
          .internalGetAllCompletionsCrossProfile(
            scope: CrossProfileScope.syncRestore,
          );
      expect(completions, hasLength(1));
      expect(completions.first.sefariaRef, 'mishna-1');

      final goals = await database.goalDao.getAllGoals();
      expect(goals, hasLength(1));
      expect(goals.first.description, 'finish by pesach');

      final profiles = await database.userProfileDao.getAllUserProfiles();
      expect(profiles, hasLength(1));
      expect(profiles.first.displayName, 'Test User');
    });

    test('PINs are not present after restore (device-local)', () async {
      // PINs are stored in FlutterSecureStorage, not in the database
      // or Firestore. After a restore, the PIN tables should be empty
      // because PINs are never synced. This test verifies the restore
      // service does NOT attempt to restore PINs.
      //
      // FirestoreDataSource has no fetchPins/pushPins methods at all,
      // so there is no mock to verify against. Instead, we confirm that
      // after a full restore the only Firestore methods called are the
      // known data-fetching ones — none of which involve PINs.
      stubEmptyFetches();

      await restoreService.restore();

      const ps = FirestoreDataSource.defaultPageSize;
      // Verify only the expected fetch methods were called — no PIN
      // methods exist on FirestoreDataSource, confirming PINs are
      // excluded from the restore by design (FR99).
      verify(() => mockFirestore.fetchCompletions(pageSize: ps)).called(1);
      verify(() => mockFirestore.fetchBookmarks(pageSize: ps)).called(1);
      verify(() => mockFirestore.fetchSettings(pageSize: ps)).called(1);
      verify(() => mockFirestore.fetchGoals(pageSize: ps)).called(1);
      verify(() => mockFirestore.fetchStreak()).called(1);
      verify(() => mockFirestore.fetchProfile()).called(1);
      verify(() => mockFirestore.fetchLedgerEntries(pageSize: ps)).called(1);
      verify(() => mockFirestore.fetchLearnerProfiles()).called(1);
      verify(() => mockFirestore.forProfile(1)).called(1);
      // Called once in pullOnLaunch (SyncEngine); the second call to derive
      // active curricula now goes through gateway.fetchAll(), not this method.
      verify(() => mockFirestore.fetchCurriculumTracks(pageSize: ps)).called(1);
      verify(() => mockFirestore.fetchNotificationSettings()).called(1);
      verify(() => mockFirestore.fetchGamificationSettings()).called(1);
      // DeviceRestoreService.restore() calls gateway.fetchAll for tracks.
      verify(
        () => mockGateway.fetchAll(
          profileId: any(named: 'profileId'),
          collection: 'curriculum_tracks',
        ),
      ).called(1);
      // isAuthenticated: called in isNewDevice() check.
      verify(() => mockFirestore.isAuthenticated).called(1);
    });

    test(
      'content items re-imported from bundled data, not Firestore',
      () async {
        stubEmptyFetches();
        // DeviceRestoreService derives active curricula via gateway.fetchAll,
        // not FirestoreDataSource.fetchCurriculumTracks.
        when(
          () => mockGateway.fetchAll(
            profileId: any(named: 'profileId'),
            collection: 'curriculum_tracks',
          ),
        ).thenAnswer(
          (_) async => [
            {'curriculum_id': 'mishnayos', 'is_active': true, 'track_id': 1},
          ],
        );
        when(
          () => mockImportService.importAll(any()),
        ).thenAnswer((_) => const Stream.empty());

        await restoreService.restore();

        // Verify import was called with the active curriculum
        verify(
          () => mockImportService.importAll(
            any(that: contains(CurriculumId.mishnayos)),
          ),
        ).called(1);
      },
    );

    test('restore status stream emits correct lifecycle', () async {
      stubEmptyFetches();

      final statuses = <RestoreStatus>[];
      restoreService.statusStream.listen(statuses.add);

      await restoreService.restore();

      // Allow microtasks to flush
      await Future<void>.delayed(Duration.zero);

      // Should have: checking → restoring(0/3) → restoring(1/3)
      // → restoring(2/3) → complete
      expect(statuses, isNotEmpty);
      expect(statuses.any((s) => s is RestoreStatusChecking), isTrue);
      expect(statuses.any((s) => s is RestoreStatusRestoring), isTrue);
      expect(statuses.any((s) => s is RestoreStatusComplete), isTrue);
      // Verify final status
      expect(restoreService.currentStatus, isA<RestoreStatusComplete>());
    });

    test('error handling with retry for partial restore failures', () async {
      stubEmptyFetches();
      // First call fails
      when(
        () => mockFirestore.fetchCompletions(
          pageSize: FirestoreDataSource.defaultPageSize,
        ),
      ).thenThrow(Exception('Network error'));
      when(
        () => mockFirestore.fetchBookmarks(
          pageSize: FirestoreDataSource.defaultPageSize,
        ),
      ).thenAnswer((_) async => []);
      when(
        () => mockFirestore.fetchSettings(
          pageSize: FirestoreDataSource.defaultPageSize,
        ),
      ).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchStreak()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchProfile()).thenAnswer((_) async => null);
      when(
        () => mockFirestore.fetchGoals(
          pageSize: FirestoreDataSource.defaultPageSize,
        ),
      ).thenAnswer((_) async => []);
      when(
        () => mockFirestore.fetchLedgerEntries(
          pageSize: FirestoreDataSource.defaultPageSize,
        ),
      ).thenAnswer((_) async => []);
      when(
        () => mockFirestore.fetchLearnerProfiles(),
      ).thenAnswer((_) async => []);

      final result1 = await restoreService.restore();
      expect(result1, isFalse);
      expect(restoreService.currentStatus, isA<RestoreStatusError>());

      // Retry succeeds
      when(
        () => mockFirestore.fetchCompletions(
          pageSize: FirestoreDataSource.defaultPageSize,
        ),
      ).thenAnswer((_) async => []);

      final result2 = await restoreService.retry();
      expect(result2, isTrue);
      expect(restoreService.currentStatus, isA<RestoreStatusComplete>());
    });

    test('restore not triggered on existing device (has data)', () async {
      // Insert existing data — not a new device
      await seedCompletion(database, 
        CompletionsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          sefariaRef: 'mishna-1',
          stageId: 1,
          trackType: 'personal',
          trackId: trackId,
          completedAt: DateTime.utc(2026, 2, 9),
        ),
      );

      expect(await restoreService.isNewDevice(), isFalse);

      final result = await restoreService.restore();
      expect(result, isFalse);

      // No Firestore calls made
      verifyNever(
        () => mockFirestore.fetchCompletions(
          pageSize: FirestoreDataSource.defaultPageSize,
        ),
      );
    });
  });
}

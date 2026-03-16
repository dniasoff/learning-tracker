/// Story acceptance tests for Epic 13 -- Cloud Sync.
@Tags(['epic_13'])
library;

import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/features/sync/data/firestore_data_source.dart';
import 'package:learning_tracker/features/sync/data/offline_queue.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:mocktail/mocktail.dart';
import 'package:talker/talker.dart';
import 'package:test/test.dart';

class MockFirestoreDataSource extends Mock implements FirestoreDataSource {}

AppDatabase _createInMemoryDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

void main() {
  // ── Story 13.1: Push-on-Write with Offline Queuing ─────────────

  group(
    'Story 13.1 -- Push-on-Write with Offline Queuing',
    tags: ['story_13_1'],
    () {
      late AppDatabase database;
      late MockFirestoreDataSource mockFirestore;
      late Talker logger;
      late OfflineQueue offlineQueue;
      late SyncEngine syncEngine;

      setUp(() {
        database = _createInMemoryDatabase();
        mockFirestore = MockFirestoreDataSource();
        logger = Talker();
        offlineQueue = OfflineQueue(
          database: database,
          firestoreDataSource: mockFirestore,
          logger: logger,
        );
        syncEngine = SyncEngine(
          database: database,
          firestoreDataSource: mockFirestore,
          offlineQueue: offlineQueue,
          logger: logger,
        );
      });

      tearDown(() async {
        await syncEngine.dispose();
        await database.close();
      });

      test('local write creates corresponding sync_queue entry', () async {
        // Go offline so pushCompletion queues instead of pushing
        when(
          () => mockFirestore.pushCompletion(any()),
        ).thenThrow(Exception('offline'));

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

      test('queue processes entries in FIFO order', () async {
        final pushOrder = <String>[];

        when(() => mockFirestore.pushCompletion(any())).thenAnswer((inv) async {
          final p = inv.positionalArguments[0] as Map<String, dynamic>;
          pushOrder.add('c:${p['id']}');
        });
        when(() => mockFirestore.pushBookmark(any())).thenAnswer((inv) async {
          final p = inv.positionalArguments[0] as Map<String, dynamic>;
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
          firestoreDataSource: mockFirestore,
          logger: logger,
        );

        final count = await newQueue.getPendingCount();
        expect(count, 2);
      });

      test('failed push retries with exponential backoff', () async {
        when(
          () => mockFirestore.pushCompletion(any()),
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
          () => mockFirestore.pushCompletion(any()),
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
    late AppDatabase database;
    late MockFirestoreDataSource mockFirestore;
    late Talker logger;
    late OfflineQueue offlineQueue;
    late SyncEngine syncEngine;

    setUp(() {
      database = _createInMemoryDatabase();
      mockFirestore = MockFirestoreDataSource();
      logger = Talker();
      offlineQueue = OfflineQueue(
        database: database,
        firestoreDataSource: mockFirestore,
        logger: logger,
      );
      syncEngine = SyncEngine(
        database: database,
        firestoreDataSource: mockFirestore,
        offlineQueue: offlineQueue,
        logger: logger,
      );
    });

    tearDown(() async {
      await syncEngine.dispose();
      await database.close();
    });

    void stubEmptyFetches() {
      when(() => mockFirestore.fetchCompletions()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchBookmarks()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchSettings()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchStreak()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchProfile()).thenAnswer((_) async => null);
      when(() => mockFirestore.fetchGoals()).thenAnswer((_) async => []);
      when(() => mockFirestore.fetchRewards()).thenAnswer((_) async => []);
    }

    test('pull fetches all user data collections from Firestore', () async {
      stubEmptyFetches();

      await syncEngine.pullOnLaunch();

      verify(() => mockFirestore.fetchCompletions()).called(1);
      verify(() => mockFirestore.fetchBookmarks()).called(1);
      verify(() => mockFirestore.fetchSettings()).called(1);
      verify(() => mockFirestore.fetchGoals()).called(1);
      verify(() => mockFirestore.fetchRewards()).called(1);
      verify(() => mockFirestore.fetchStreak()).called(1);
      verify(() => mockFirestore.fetchProfile()).called(1);
    });

    test('additive merge adds remote completions not present locally '
        '(no duplicates)', () async {
      // Insert one local completion
      final completedAt = DateTime.utc(2026, 2, 9, 12);
      await database.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'mishnayos',
          sefariaRef: 'mishna-1',
          stageId: 1,
          trackType: 'personal',
          completedAt: completedAt,
        ),
      );

      stubEmptyFetches();
      when(() => mockFirestore.fetchCompletions()).thenAnswer(
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

      final completions = await database.completionDao.getAllCompletions();
      expect(completions.length, 2);
    });

    test('last-write-wins correctly resolves when remote timestamp > local '
        'for mutable data', () async {
      // Insert older local bookmark
      await database.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          curriculumId: 'mishnayos',
          trackType: 'personal',
          sefariaRef: 'mishna-10',
          updatedAt: DateTime.utc(2026, 2, 8),
        ),
      );

      stubEmptyFetches();
      when(() => mockFirestore.fetchBookmarks()).thenAnswer(
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
          .getBookmarkByCurriculumAndTrack('mishnayos', 'personal');
      expect(bookmark!.sefariaRef, 'mishna-42'); // Remote won
    });

    test(
      'last-write-wins correctly keeps local when local timestamp > remote',
      () async {
        // Insert newer local bookmark
        await database.bookmarkDao.insertBookmark(
          BookmarksCompanion.insert(
            curriculumId: 'mishnayos',
            trackType: 'personal',
            sefariaRef: 'mishna-99',
            updatedAt: DateTime.utc(2026, 2, 10),
          ),
        );

        stubEmptyFetches();
        when(() => mockFirestore.fetchBookmarks()).thenAnswer(
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
            .getBookmarkByCurriculumAndTrack('mishnayos', 'personal');
        expect(bookmark!.sefariaRef, 'mishna-99'); // Local kept
      },
    );

    test(
      'pull gracefully handles no network (returns local data unchanged)',
      () async {
        syncEngine.setOnlineState(false);

        // Insert local data
        await database.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: 'mishnayos',
            sefariaRef: 'mishna-1',
            stageId: 1,
            trackType: 'personal',
            completedAt: DateTime.utc(2026, 2, 9),
          ),
        );

        await syncEngine.pullOnLaunch();

        // Local data unchanged
        final completions = await database.completionDao.getAllCompletions();
        expect(completions.length, 1);
        // No Firestore calls
        verifyNever(() => mockFirestore.fetchCompletions());
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

  // ── Story 13.3: Backup & restore ──────────────────────────────

  group(
    'Story 13.3 -- Backup & restore',
    tags: ['story_13_3'],
    skip: 'Backlog: backup and restore not yet implemented',
    () {
      test('user can export a full database backup', () {
        // TODO: verify export produces valid JSON
      });

      test('user can restore from a backup file', () {
        // TODO: verify restore overwrites local data
      });
    },
  );
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/sync/data/firestore_data_source.dart';
import 'package:learning_tracker/features/sync/data/offline_queue.dart';
import 'package:mocktail/mocktail.dart';
import 'package:talker/talker.dart';

class MockFirestoreDataSource extends Mock implements FirestoreDataSource {}

UserDatabase _createInMemoryDatabase() {
  return UserDatabase(NativeDatabase.memory());
}

void main() {
  late UserDatabase database;
  late MockFirestoreDataSource mockFirestore;
  late Talker logger;
  late OfflineQueue offlineQueue;

  setUp(() {
    database = _createInMemoryDatabase();
    mockFirestore = MockFirestoreDataSource();
    logger = Talker();

    offlineQueue = OfflineQueue(
      database: database,
      firestoreDataSource: mockFirestore,
      logger: logger,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('OfflineQueue enqueue operations', () {
    test('enqueues a completion', () async {
      final data = {'curriculum_id': 'mishnayos', 'content_item_id': 1};
      await offlineQueue.enqueueCompletion(data);

      final count = await offlineQueue.getPendingCount();
      expect(count, 1);
    });

    test('enqueues a bookmark', () async {
      final data = {
        'curriculum_id': 'mishnayos',
        'track_type': 'personal',
        'content_item_id': 42,
      };
      await offlineQueue.enqueueBookmark(data);

      final count = await offlineQueue.getPendingCount();
      expect(count, 1);
    });

    test('enqueues settings', () async {
      final data = {'curriculum_id': 'mishnayos', 'stages': <dynamic>[]};
      await offlineQueue.enqueueSettings(data);

      final count = await offlineQueue.getPendingCount();
      expect(count, 1);
    });

    test('enqueues streak', () async {
      final data = {'current_count': 5, 'max_count': 10};
      await offlineQueue.enqueueStreak(data);

      final count = await offlineQueue.getPendingCount();
      expect(count, 1);
    });

    test('enqueues profile', () async {
      final data = {
        'firebase_uid': 'uid-123',
        'display_name': 'Test',
        'user_mode': 'child',
      };
      await offlineQueue.enqueueProfile(data);

      final count = await offlineQueue.getPendingCount();
      expect(count, 1);
    });

    test('enqueues curriculum import metadata', () async {
      final data = {
        'curriculum_id': 'mishnayos',
        'item_count': 4192,
        'imported_at': '2026-02-09T00:00:00.000Z',
      };
      await offlineQueue.enqueueCurriculumImportMetadata(data);

      final count = await offlineQueue.getPendingCount();
      expect(count, 1);
    });

    test('getPendingCount returns correct count for multiple items', () async {
      await offlineQueue.enqueueCompletion({'id': '1'});
      await offlineQueue.enqueueBookmark({'id': '2'});
      await offlineQueue.enqueueSettings({'id': '3'});

      final count = await offlineQueue.getPendingCount();
      expect(count, 3);
    });
  });

  group('OfflineQueue flush', () {
    test('flush returns 0 when queue is empty', () async {
      final count = await offlineQueue.flush();
      expect(count, 0);
    });

    test('flush pushes completions to Firestore', () async {
      when(() => mockFirestore.pushCompletion(any())).thenAnswer((_) async {});

      final data = {'curriculum_id': 'mishnayos', 'content_item_id': 1};
      await offlineQueue.enqueueCompletion(data);

      final syncedCount = await offlineQueue.flush();
      expect(syncedCount, 1);

      verify(
        () => mockFirestore.pushCompletion(
          any(
            that: predicate<Map<String, dynamic>>(
              (m) => m['curriculum_id'] == 'mishnayos',
            ),
          ),
        ),
      ).called(1);

      // Queue should be empty now
      final remaining = await offlineQueue.getPendingCount();
      expect(remaining, 0);
    });

    test('flush pushes bookmarks to Firestore', () async {
      when(() => mockFirestore.pushBookmark(any())).thenAnswer((_) async {});

      await offlineQueue.enqueueBookmark({
        'curriculum_id': 'bavli',
        'track_type': 'school',
      });

      final syncedCount = await offlineQueue.flush();
      expect(syncedCount, 1);
      verify(() => mockFirestore.pushBookmark(any())).called(1);
    });

    test('flush pushes settings to Firestore', () async {
      when(() => mockFirestore.pushSettings(any())).thenAnswer((_) async {});

      await offlineQueue.enqueueSettings({'curriculum_id': 'mishnayos'});

      final syncedCount = await offlineQueue.flush();
      expect(syncedCount, 1);
      verify(() => mockFirestore.pushSettings(any())).called(1);
    });

    test('flush pushes streak to Firestore', () async {
      when(() => mockFirestore.pushStreak(any())).thenAnswer((_) async {});

      await offlineQueue.enqueueStreak({'current_count': 3});

      final syncedCount = await offlineQueue.flush();
      expect(syncedCount, 1);
      verify(() => mockFirestore.pushStreak(any())).called(1);
    });

    test('flush pushes profile to Firestore', () async {
      when(() => mockFirestore.pushProfile(any())).thenAnswer((_) async {});

      await offlineQueue.enqueueProfile({'firebase_uid': 'uid-123'});

      final syncedCount = await offlineQueue.flush();
      expect(syncedCount, 1);
      verify(() => mockFirestore.pushProfile(any())).called(1);
    });

    test('flush pushes curriculum import metadata to Firestore', () async {
      when(
        () => mockFirestore.pushCurriculumImportMetadata(any()),
      ).thenAnswer((_) async {});

      await offlineQueue.enqueueCurriculumImportMetadata({
        'curriculum_id': 'mishnayos',
        'item_count': 4192,
      });

      final syncedCount = await offlineQueue.flush();
      expect(syncedCount, 1);
      verify(() => mockFirestore.pushCurriculumImportMetadata(any())).called(1);
    });

    test('flush handles mixed operation types', () async {
      when(() => mockFirestore.pushCompletion(any())).thenAnswer((_) async {});
      when(() => mockFirestore.pushBookmark(any())).thenAnswer((_) async {});
      when(() => mockFirestore.pushSettings(any())).thenAnswer((_) async {});

      await offlineQueue.enqueueCompletion({'id': '1'});
      await offlineQueue.enqueueBookmark({'id': '2'});
      await offlineQueue.enqueueSettings({'id': '3'});

      final syncedCount = await offlineQueue.flush();
      expect(syncedCount, 3);

      final remaining = await offlineQueue.getPendingCount();
      expect(remaining, 0);
    });

    test('flush marks failed operations and continues', () async {
      when(
        () => mockFirestore.pushCompletion(any()),
      ).thenThrow(Exception('Network error'));
      when(() => mockFirestore.pushBookmark(any())).thenAnswer((_) async {});

      await offlineQueue.enqueueCompletion({'id': '1'});
      await offlineQueue.enqueueBookmark({'id': '2'});

      final syncedCount = await offlineQueue.flush();
      expect(syncedCount, 1); // Only bookmark succeeded

      // Failed completion should still be in queue (with incremented retry count)
      final remaining = await offlineQueue.getPendingCount();
      expect(remaining, 1);
    });
  });

  group('OfflineQueue clearAll', () {
    test('clears all queued operations', () async {
      await offlineQueue.enqueueCompletion({'id': '1'});
      await offlineQueue.enqueueBookmark({'id': '2'});
      await offlineQueue.enqueueSettings({'id': '3'});

      await offlineQueue.clearAll();

      final count = await offlineQueue.getPendingCount();
      expect(count, 0);
    });
  });

  group('OfflineQueue FIFO ordering', () {
    test('flush processes entries in FIFO order', () async {
      final pushOrder = <String>[];

      when(() => mockFirestore.pushCompletion(any())).thenAnswer((inv) async {
        final payload = inv.positionalArguments[0] as Map<String, dynamic>;
        pushOrder.add('completion:${payload['id']}');
      });
      when(() => mockFirestore.pushBookmark(any())).thenAnswer((inv) async {
        final payload = inv.positionalArguments[0] as Map<String, dynamic>;
        pushOrder.add('bookmark:${payload['id']}');
      });
      when(() => mockFirestore.pushSettings(any())).thenAnswer((inv) async {
        final payload = inv.positionalArguments[0] as Map<String, dynamic>;
        pushOrder.add('settings:${payload['id']}');
      });

      await offlineQueue.enqueueCompletion({'id': '1'});
      await offlineQueue.enqueueBookmark({'id': '2'});
      await offlineQueue.enqueueSettings({'id': '3'});

      await offlineQueue.flush();

      expect(pushOrder, ['completion:1', 'bookmark:2', 'settings:3']);
    });
  });

  group('OfflineQueue persistence', () {
    test('queue entries persist across simulated app restart', () async {
      // Enqueue items
      await offlineQueue.enqueueCompletion({'id': '1'});
      await offlineQueue.enqueueBookmark({'id': '2'});

      // Create a new OfflineQueue instance pointing to the same database
      // (simulates app restart with same persistent DB).
      // Note: This uses the same in-memory DB instance, so it validates
      // object re-instantiation over the same backing store rather than
      // true disk persistence. A full persistence test would require an
      // on-disk SQLite file.
      final newQueue = OfflineQueue(
        database: database,
        firestoreDataSource: mockFirestore,
        logger: logger,
      );

      final count = await newQueue.getPendingCount();
      expect(count, 2);
    });
  });

  group('OfflineQueue retry with exponential backoff', () {
    test('failed push increments retry count', () async {
      when(
        () => mockFirestore.pushCompletion(any()),
      ).thenThrow(Exception('Network error'));

      await offlineQueue.enqueueCompletion({'id': '1'});

      // First flush: fails, marks retry count = 1
      await offlineQueue.flush();
      expect(await offlineQueue.getPendingCount(), 1);

      final pending = await database.syncQueueDao.getAllPending();
      expect(pending.first.retryCount, 1);
      expect(pending.first.lastError, contains('Network error'));
    });

    test('after 5 retries, entry marked as failed (not retried)', () async {
      when(
        () => mockFirestore.pushCompletion(any()),
      ).thenThrow(Exception('persistent error'));

      // Enqueue and manually set retryCount to 5 (= maxRetries)
      await offlineQueue.enqueueCompletion({'id': '1'});
      final pending = await database.syncQueueDao.getAllPending();
      final id = pending.first.id;

      for (var i = 0; i < 5; i++) {
        await database.syncQueueDao.markFailed(id, 'error $i');
      }

      // Flush should skip the dead-letter item (retryCount >= maxRetries)
      final synced = await offlineQueue.flush();
      expect(synced, 0);

      final updated = await database.syncQueueDao.getAllPending();
      expect(updated.first.retryCount, 5);
    });

    test('maxRetries is 5 per FR93', () {
      expect(OfflineQueue.maxRetries, 5);
    });
  });

  group('OfflineQueue batch processing', () {
    test('flush with batchSize processes all items in batches', () async {
      when(() => mockFirestore.pushCompletion(any())).thenAnswer((_) async {});
      when(() => mockFirestore.pushBookmark(any())).thenAnswer((_) async {});
      when(() => mockFirestore.pushSettings(any())).thenAnswer((_) async {});

      await offlineQueue.enqueueCompletion({'id': '1'});
      await offlineQueue.enqueueBookmark({'id': '2'});
      await offlineQueue.enqueueSettings({'id': '3'});

      // With batchSize=2, items are processed in two batches (2 + 1)
      // with an inter-batch delay to reduce sustained network activity.
      final synced = await offlineQueue.flush(batchSize: 2);
      expect(synced, 3);

      final remaining = await offlineQueue.getPendingCount();
      expect(remaining, 0);
    });
  });

  group('OfflineQueue sync status reflects queue state', () {
    test('empty queue means synced (count = 0)', () async {
      final count = await offlineQueue.getPendingCount();
      expect(count, 0);
    });

    test('non-empty queue means pending', () async {
      await offlineQueue.enqueueCompletion({'id': '1'});
      final count = await offlineQueue.getPendingCount();
      expect(count, greaterThan(0));
    });
  });
}

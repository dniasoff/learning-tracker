import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

void main() {
  late UserDatabase database;

  setUp(() {
    database = UserDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('SyncQueueDao', () {
    test('enqueue adds an operation and getAllPending retrieves it', () async {
      await database.syncQueueDao.enqueue('completion', '{"id": 1}');

      final pending = await database.syncQueueDao.getAllPending();
      expect(pending, hasLength(1));
      expect(pending.first.operationType, 'completion');
      expect(pending.first.payload, '{"id": 1}');
      expect(pending.first.retryCount, 0);
      expect(pending.first.lastError, isNull);
    });

    test('getAllPending returns items ordered FIFO', () async {
      await database.syncQueueDao.enqueue('first', '{}');
      // Small delay to ensure different queuedAt timestamps
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await database.syncQueueDao.enqueue('second', '{}');

      final pending = await database.syncQueueDao.getAllPending();
      expect(pending, hasLength(2));
      expect(pending[0].operationType, 'first');
      expect(pending[1].operationType, 'second');
    });

    test('getPendingCount returns correct count', () async {
      expect(await database.syncQueueDao.getPendingCount(), 0);

      await database.syncQueueDao.enqueue('a', '{}');
      await database.syncQueueDao.enqueue('b', '{}');

      expect(await database.syncQueueDao.getPendingCount(), 2);
    });

    test('markFailed increments retryCount and sets lastError', () async {
      final id = await database.syncQueueDao.enqueue('completion', '{}');

      await database.syncQueueDao.markFailed(id, 'network error');

      final pending = await database.syncQueueDao.getAllPending();
      final item = pending.firstWhere((e) => e.id == id);
      expect(item.retryCount, 1);
      expect(item.lastError, 'network error');
    });

    test('markFailed increments retryCount on subsequent failures', () async {
      final id = await database.syncQueueDao.enqueue('completion', '{}');

      await database.syncQueueDao.markFailed(id, 'error 1');
      await database.syncQueueDao.markFailed(id, 'error 2');

      final pending = await database.syncQueueDao.getAllPending();
      final item = pending.firstWhere((e) => e.id == id);
      expect(item.retryCount, 2);
      expect(item.lastError, 'error 2');
    });

    test('markFailed does nothing for non-existent id', () async {
      // Should not throw
      await database.syncQueueDao.markFailed(999, 'error');

      expect(await database.syncQueueDao.getPendingCount(), 0);
    });

    test('remove deletes an operation from the queue', () async {
      final id = await database.syncQueueDao.enqueue('completion', '{}');

      final deleted = await database.syncQueueDao.remove(id);
      expect(deleted, 1);

      expect(await database.syncQueueDao.getPendingCount(), 0);
    });

    test('clearAll removes all operations', () async {
      await database.syncQueueDao.enqueue('a', '{}');
      await database.syncQueueDao.enqueue('b', '{}');
      await database.syncQueueDao.enqueue('c', '{}');

      final deleted = await database.syncQueueDao.clearAll();
      expect(deleted, 3);

      expect(await database.syncQueueDao.getPendingCount(), 0);
    });
  });
}

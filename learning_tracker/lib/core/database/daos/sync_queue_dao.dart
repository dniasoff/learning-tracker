import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/sync_queue.dart';

part 'sync_queue_dao.g.dart';

@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  /// Get all pending operations in the queue.
  Future<List<SyncQueueData>> getAllPending() {
    return select(syncQueue).get();
  }

  /// Get count of pending operations.
  Future<int> getPendingCount() async {
    final count = await (select(syncQueue)..limit(1000)).get();
    return count.length;
  }

  /// Enqueue a new operation.
  Future<int> enqueue(String operationType, String payload) {
    return into(syncQueue).insert(
      SyncQueueCompanion.insert(
        operationType: operationType,
        payload: payload,
        queuedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Mark an operation as failed with error message.
  Future<void> markFailed(int id, String error) async {
    final current = await (select(
      syncQueue,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (current == null) return;

    await (update(syncQueue)..where((t) => t.id.equals(id))).write(
      SyncQueueCompanion(
        retryCount: Value(current.retryCount + 1),
        lastError: Value(error),
      ),
    );
  }

  /// Remove an operation from the queue after successful sync.
  Future<int> remove(int id) {
    return (delete(syncQueue)..where((t) => t.id.equals(id))).go();
  }

  /// Clear all operations from the queue.
  Future<int> clearAll() {
    return delete(syncQueue).go();
  }
}

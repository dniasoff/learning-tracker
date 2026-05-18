import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/sync_queue.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

part 'sync_queue_dao.g.dart';

@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<UserDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  /// Get all pending operations in the queue, ordered FIFO by queued time.
  Future<List<SyncQueueData>> getAllPending() {
    return (select(
      syncQueue,
    )..orderBy([(t) => OrderingTerm.asc(t.queuedAt)])).get();
  }

  /// Get count of pending operations.
  Future<int> getPendingCount() async {
    final countExpr = syncQueue.id.count();
    final query = selectOnly(syncQueue)..addColumns([countExpr]);
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  /// Enqueue a new operation.
  Future<int> enqueue(String operationType, String payload) {
    return into(syncQueue).insert(
      SyncQueueCompanion.insert(
        operationType: operationType,
        payload: payload,
        queuedAt: DateTimeFactory.nowUtc(),
      ),
    );
  }

  /// Enqueue with a dedup key (I-5).
  ///
  /// Uses INSERT OR REPLACE so that a second call with the same [entityKey]
  /// replaces the previous pending row, keeping only the latest payload.
  /// NULL [entityKey] values are never considered equal in SQLite, so callers
  /// without a meaningful key should use [enqueue] instead.
  Future<int> enqueueWithKey(
    String operationType,
    String payload,
    String entityKey,
  ) {
    return into(syncQueue).insert(
      SyncQueueCompanion.insert(
        operationType: operationType,
        payload: payload,
        queuedAt: DateTimeFactory.nowUtc(),
        entityKey: Value(entityKey),
      ),
      mode: InsertMode.insertOrReplace,
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
        // Update queuedAt so exponential backoff is relative to last failure.
        queuedAt: Value(DateTimeFactory.nowUtc()),
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

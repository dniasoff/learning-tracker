import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/outbox_table.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

part 'outbox_dao.g.dart';

/// DAO for the outbox table.
///
/// All write paths that queue a Firestore mutation must call
/// [insertOutboxRow] **inside the same DB transaction** as the local write,
/// ensuring the two either both commit or both roll back.
@DriftAccessor(tables: [Outbox])
class OutboxDao extends DatabaseAccessor<UserDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  /// Insert a new outbox row.
  ///
  /// Must be called inside the same transaction as the triggering write so
  /// that an outbox insert failure rolls back the entire transaction.
  Future<int> insertOutboxRow(OutboxCompanion companion) =>
      into(outbox).insert(companion);

  /// Return all pending rows for a given [entityKind] and [profileId],
  /// ordered oldest-first (FIFO drain).
  ///
  /// At most [limit] rows are returned (default: 50).
  Future<List<OutboxData>> getPendingByKind(
    String entityKind,
    int profileId, {
    int limit = 50,
  }) =>
      (select(outbox)
            ..where(
              (t) =>
                  t.entityKind.equals(entityKind) &
                  t.profileId.equals(profileId),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
            ..limit(limit))
          .get();

  /// Increment the attempt counter and record an optional error.
  ///
  /// Sets [lastAttemptAt] to the current UTC time.
  Future<void> markAttempted(int id, {String? error}) async {
    final row = await (select(
      outbox,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    await (update(outbox)..where((t) => t.id.equals(id))).write(
      OutboxCompanion(
        attempts: Value(row.attempts + 1),
        lastError: Value(error),
        lastAttemptAt: Value(DateTimeFactory.nowUtc()),
      ),
    );
  }

  /// Batch-insert multiple outbox rows in the caller's current transaction.
  ///
  /// Queues the rows onto [batch]; the actual write happens when the
  /// enclosing [DatabaseAccessor.batch] block flushes. Must be called inside
  /// a `db.batch()` block within an enclosing `db.transaction()`.
  ///
  /// The `outbox` table has no UNIQUE index, so callers MUST de-duplicate
  /// [rows] (and guard against re-pushing already-persisted entities)
  /// themselves before calling this method.
  ///
  /// This method only enqueues onto the [batch] object and performs no async
  /// work — hence the synchronous `void` return.
  void batchInsertOutboxRows(Batch batch, List<OutboxCompanion> rows) {
    batch.insertAll(outbox, rows);
  }

  /// Delete a successfully-pushed outbox row.
  Future<int> deleteRow(int id) =>
      (delete(outbox)..where((t) => t.id.equals(id))).go();

  /// Total number of pending outbox rows for [profileId] across every kind.
  ///
  /// Used by the orchestrator to compute the `pending` / `degraded` /
  /// `offline` sync-status counts (Phase 4 deliverable 2). Cheap: a single
  /// COUNT(*) — the orchestrator queries this every drain attempt, so
  /// O(rows) work would be a regression.
  Future<int> depth(int profileId) async {
    final countExpr = outbox.id.count();
    final row =
        await (selectOnly(outbox)
              ..addColumns([countExpr])
              ..where(outbox.profileId.equals(profileId)))
            .getSingle();
    return row.read(countExpr) ?? 0;
  }

  /// Timestamp of the OLDEST pending outbox row for [profileId], or null when
  /// the outbox is empty for this profile.
  ///
  /// Used alongside [depth] for the `outbox_depth` observability event so
  /// dashboards can graph stuck-backlog age.
  Future<DateTime?> oldestPendingAt(int profileId) async {
    final row =
        await (select(outbox)
              ..where((t) => t.profileId.equals(profileId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    return row?.createdAt;
  }

  /// Number of pending rows for [profileId] that have already been retried
  /// [minAttempts] or more times without success — i.e. rows the orchestrator
  /// should classify as "stuck" / `degraded`.
  Future<int> stuckCount(int profileId, {required int minAttempts}) async {
    final countExpr = outbox.id.count();
    final row =
        await (selectOnly(outbox)
              ..addColumns([countExpr])
              ..where(
                outbox.profileId.equals(profileId) &
                    outbox.attempts.isBiggerOrEqualValue(minAttempts),
              ))
            .getSingle();
    return row.read(countExpr) ?? 0;
  }
}

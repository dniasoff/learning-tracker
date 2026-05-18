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
  /// Uses [InsertMode.insertOrIgnore] so duplicate natural-key entries are
  /// silently dropped rather than throwing. Must be called inside a
  /// [DatabaseAccessor.batch] or an enclosing `db.transaction()`.
  Future<void> batchInsertOutboxRows(
    Batch batch,
    List<OutboxCompanion> rows,
  ) {
    batch.insertAll(outbox, rows, mode: InsertMode.insertOrIgnore);
    return Future.value();
  }

  /// Delete a successfully-pushed outbox row.
  Future<int> deleteRow(int id) =>
      (delete(outbox)..where((t) => t.id.equals(id))).go();
}

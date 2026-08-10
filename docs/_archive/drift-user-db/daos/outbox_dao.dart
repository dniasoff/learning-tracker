import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/outbox.dart';
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

  /// Delete every row in [ids] in a single `DELETE ... WHERE id IN (...)`
  /// statement, instead of one `deleteRow` round trip per id.
  ///
  /// AUD-core-sync-17 (DB-3): `pushCompletionsBatch` exists specifically to
  /// eliminate the N-round-trip problem for the Firestore push, but the
  /// local cleanup after a large committed group still ran one awaited
  /// `deleteRow` per outbox row — reintroducing the exact per-row
  /// round-trip cost DB-3 exists to prevent, now against the local DB, on
  /// every large backlog / bulk-mark commit. A no-op (returns 0) for an
  /// empty list.
  Future<int> deleteRows(List<int> ids) {
    if (ids.isEmpty) return Future.value(0);
    return (delete(outbox)..where((t) => t.id.isIn(ids))).go();
  }

  /// Increment the attempt counter and record [error] for every row in
  /// [ids] in a single `batch()` round trip, instead of one awaited
  /// `markAttempted` call per row (AUD-core-sync-17 / DB-3).
  ///
  /// Mirrors [markAttempted]'s semantics exactly (attempts + 1, `lastError`
  /// set to [error], `lastAttemptAt` stamped to now) — just applied to a
  /// whole commit/failure group at once. A no-op for an empty list.
  Future<void> markAttemptedBulk(List<int> ids, {String? error}) async {
    if (ids.isEmpty) return;
    final rows = await (select(outbox)..where((t) => t.id.isIn(ids))).get();
    if (rows.isEmpty) return;
    final now = DateTimeFactory.nowUtc();
    await batch((b) {
      for (final row in rows) {
        b.update(
          outbox,
          OutboxCompanion(
            attempts: Value(row.attempts + 1),
            lastError: Value(error),
            lastAttemptAt: Value(now),
          ),
          where: (t) => t.id.equals(row.id),
        );
      }
    });
  }

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

  /// Total number of pending outbox rows across EVERY profile in this DB
  /// file, regardless of [entityKind].
  ///
  /// Used by [AccountLifecycleService.removeCloudFromDevice] (AUD-account-01)
  /// to refuse deleting the local DB file while any profile under the
  /// account still has mutations that have not reached Firestore.
  Future<int> totalDepth() async {
    final countExpr = outbox.id.count();
    final row = await (selectOnly(outbox)..addColumns([countExpr])).getSingle();
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

  /// Revive rows for [profileId] that dead-lettered with an identity/permission
  /// failure, by resetting their retry budget so the next drain attempts them
  /// again under the current Firebase identity.
  ///
  /// A row that hit the dead-letter ceiling ([minAttempts], mirrors
  /// `OutboxProcessor._maxAttempts`) with a `permission-denied` or
  /// `unauthenticated` error failed under a condition that may since have been
  /// resolved — the wrong cloud account was signed in, or the Firestore rules
  /// for that collection had not been deployed. Once the correct identity is
  /// active, those writes deserve a fresh attempt instead of being silently
  /// stranded forever. Rows that dead-lettered for ANY other reason (malformed
  /// payload, etc.) are left untouched.
  ///
  /// Callers MUST bound how often this runs (e.g. once per app launch) so a
  /// genuinely-doomed row does not churn through its retry budget every drain.
  /// Returns the number of rows revived.
  Future<int> reviveIdentityDeadLetters(int profileId, {int minAttempts = 10}) {
    return (update(outbox)..where(
          (t) =>
              t.profileId.equals(profileId) &
              t.attempts.isBiggerOrEqualValue(minAttempts) &
              (t.lastError.like('%permission-denied%') |
                  t.lastError.like('%nauthenticated%')),
        ))
        .write(
          const OutboxCompanion(
            attempts: Value(0),
            lastError: Value<String?>(null),
            lastAttemptAt: Value<DateTime?>(null),
          ),
        );
  }
}

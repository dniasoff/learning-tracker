import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/sync_kv.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'sync_kv_dao.g.dart';

/// DAO for the [SyncKv] table — persisted LWW timestamps per
/// `(kind, entityKey)`.
///
/// Used exclusively by [DriftMergeStore] to read/write the last-applied
/// remote `updated_at` for each entity kind that uses LWW conflict
/// resolution. Centralising the timestamp lookup makes [remoteIsNewer]
/// symmetric — without this DAO, [DriftMergeStore.currentUpdatedAt]
/// returned `null` for several kinds and remote unconditionally won.
@DriftAccessor(tables: [SyncKv])
class SyncKvDao extends DatabaseAccessor<UserDatabase> with _$SyncKvDaoMixin {
  SyncKvDao(super.db);

  /// Read the persisted `updated_at` for `(kind, entityKey)`, if any.
  ///
  /// Returns `null` when the merger has never applied a row for this
  /// natural key — callers treat that as "remote always wins on first
  /// sync" (a safe default for new entities).
  Future<DateTime?> get(String kind, String entityKey) async {
    final row =
        await (select(syncKv)..where(
              (t) => t.kind.equals(kind) & t.entityKey.equals(entityKey),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(row.updatedAtMs, isUtc: true);
  }

  /// Read the persisted Firestore server timestamp (`synced_at`) for
  /// `(kind, entityKey)`, if any.
  ///
  /// Used by [DriftMergeStore.remoteIsNewer] as the tie-breaker when
  /// client `updated_at` values are within ±5 s on two devices.
  Future<DateTime?> getSyncedAt(String kind, String entityKey) async {
    final row =
        await (select(syncKv)..where(
              (t) => t.kind.equals(kind) & t.entityKey.equals(entityKey),
            ))
            .getSingleOrNull();
    final ms = row?.syncedAtMs;
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  /// Persist the last-applied `updated_at` (and optional `synced_at`) for
  /// `(kind, entityKey)`. Called by every LWW merger after a successful
  /// apply.
  Future<void> upsert(
    String kind,
    String entityKey,
    DateTime updatedAt, {
    DateTime? syncedAt,
  }) async {
    await into(syncKv).insert(
      SyncKvCompanion.insert(
        kind: kind,
        entityKey: entityKey,
        updatedAtMs: updatedAt.toUtc().millisecondsSinceEpoch,
        syncedAtMs: Value(syncedAt?.toUtc().millisecondsSinceEpoch),
      ),
      onConflict: DoUpdate(
        (_) => SyncKvCompanion(
          updatedAtMs: Value(updatedAt.toUtc().millisecondsSinceEpoch),
          syncedAtMs: Value(syncedAt?.toUtc().millisecondsSinceEpoch),
        ),
        target: [syncKv.kind, syncKv.entityKey],
      ),
    );
  }
}

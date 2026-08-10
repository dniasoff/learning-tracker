import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/sacred_window_entries.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'sacred_window_dao.g.dart';

/// DAO for the [SacredWindowEntries] table (DNI-367, Story 26.24).
///
/// The table is used as a write-through cache: [clearAll] + [insertAll]
/// are called together (atomically, via [replaceAll]) whenever
/// [ZmanimWindowService] recomputes windows. [getAll] is used on cold-start
/// to seed the in-memory cache without recomputing.
@DriftAccessor(tables: [SacredWindowEntries])
class SacredWindowDao extends DatabaseAccessor<UserDatabase>
    with _$SacredWindowDaoMixin {
  SacredWindowDao(super.db);

  /// Deletes every row. Called before [insertAll] to replace the full cache.
  ///
  /// Prefer [replaceAll] for a clear+insert cycle — calling this directly
  /// followed by a separate [insertAll] is not atomic (AUD-core-database-04).
  Future<void> clearAll() => delete(sacredWindowEntries).go();

  /// Batch-inserts [entries]. Expects the caller to have called [clearAll]
  /// first so the table stays coherent.
  ///
  /// Prefer [replaceAll] for a clear+insert cycle — calling this directly
  /// after a separate [clearAll] is not atomic (AUD-core-database-04).
  Future<void> insertAll(List<SacredWindowEntriesCompanion> entries) =>
      batch((b) => b.insertAll(sacredWindowEntries, entries));

  /// Atomically replaces the full cache with [entries]: [clearAll] then
  /// [insertAll], both inside one [transaction] (DB-2).
  ///
  /// If [insertAll] throws partway through the batch (e.g. a constraint
  /// violation), the whole transaction rolls back — the table is left
  /// holding its PREVIOUS rows, never a half-cleared or half-written state
  /// (AUD-core-database-04).
  Future<void> replaceAll(List<SacredWindowEntriesCompanion> entries) {
    return transaction(() async {
      await clearAll();
      await insertAll(entries);
    });
  }

  /// Returns every persisted window, unordered.
  Future<List<SacredWindowEntry>> getAll() => select(sacredWindowEntries).get();
}

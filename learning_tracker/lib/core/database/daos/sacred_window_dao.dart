import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/sacred_window_entries.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'sacred_window_dao.g.dart';

/// DAO for the [SacredWindowEntries] table (DNI-367, Story 26.24).
///
/// The table is used as a write-through cache: [clearAll] + [insertAll]
/// are called together whenever [ZmanimWindowService] recomputes windows.
/// [getAll] is used on cold-start to seed the in-memory cache without
/// recomputing.
@DriftAccessor(tables: [SacredWindowEntries])
class SacredWindowDao extends DatabaseAccessor<UserDatabase>
    with _$SacredWindowDaoMixin {
  SacredWindowDao(super.db);

  /// Deletes every row. Called before [insertAll] to replace the full cache.
  Future<void> clearAll() => delete(sacredWindowEntries).go();

  /// Batch-inserts [entries]. Expects the caller to have called [clearAll]
  /// first so the table stays coherent.
  Future<void> insertAll(List<SacredWindowEntriesCompanion> entries) =>
      batch((b) => b.insertAll(sacredWindowEntries, entries));

  /// Returns every persisted window, unordered.
  Future<List<SacredWindowEntry>> getAll() => select(sacredWindowEntries).get();
}

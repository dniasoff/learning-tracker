import 'package:drift/drift.dart';

/// Generic Drift DAO mixin providing the four query shapes that every
/// profile-scoped DAO previously re-implemented: [getById], [getByProfile],
/// [count], [exists] (DNI-338, FR1, NFR9).
///
/// To use, mix in to a `DatabaseAccessor<DB>`-derived DAO and provide:
///
///   * [table]            — the generated `$XxxTable` info.
///   * [idColumn]         — projects a row's `id` column from [table].
///   * [profileIdColumn]  — projects a row's `profileId` column from [table].
///
/// Example:
/// ```dart
/// class StreakDao extends DatabaseAccessor<UserDatabase>
///     with _$StreakDaoMixin, BaseDao<$StreaksTable, Streak> {
///   StreakDao(super.db);
///
///   @override
///   TableInfo<$StreaksTable, Streak> get table => streaks;
///
///   @override
///   Expression<int> idColumn($StreaksTable t) => t.id;
///
///   @override
///   Expression<int> profileIdColumn($StreaksTable t) => t.profileId;
/// }
/// ```
mixin BaseDao<Tbl extends Table, Row, DB extends GeneratedDatabase>
    on DatabaseAccessor<DB> {
  /// The Drift table info this DAO operates on.
  TableInfo<Tbl, Row> get table;

  /// Returns the table's `id` column for use in WHERE clauses.
  Expression<int> idColumn(Tbl t);

  /// Returns the table's `profileId` column for use in WHERE clauses.
  Expression<int> profileIdColumn(Tbl t);

  // ── Common query shapes ──────────────────────────────────────────────────

  /// Fetch a single row by primary key, or null if not found.
  Future<Row?> getById(int id) {
    final query = select(table)
      ..where((t) => idColumn(t).equals(id))
      ..limit(1);
    return query.getSingleOrNull();
  }

  /// Fetch every row scoped to [profileId].
  Future<List<Row>> getByProfile(int profileId) {
    final query = select(table)
      ..where((t) => profileIdColumn(t).equals(profileId));
    return query.get();
  }

  /// Number of rows in [table] scoped to [profileId].
  Future<int> count({required int profileId}) async {
    final countExpr = idColumn(table.asDslTable).count();
    final query = selectOnly(table)
      ..addColumns([countExpr])
      ..where(profileIdColumn(table.asDslTable).equals(profileId));
    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  /// Whether any row exists in [table] scoped to [profileId].
  Future<bool> exists({required int profileId}) async {
    final query = select(table)
      ..where((t) => profileIdColumn(t).equals(profileId))
      ..limit(1);
    final result = await query.get();
    return result.isNotEmpty;
  }
}

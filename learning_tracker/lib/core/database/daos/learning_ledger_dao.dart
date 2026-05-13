import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/learning_ledger.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'learning_ledger_dao.g.dart';

/// DAO for the learning_ledger table.
///
/// Learning ledger entries are append-only: only insert operations are exposed.
/// No update or delete methods are provided to enforce immutability.
@DriftAccessor(tables: [LearningLedger])
class LearningLedgerDao extends DatabaseAccessor<UserDatabase>
    with _$LearningLedgerDaoMixin {
  LearningLedgerDao(super.db);

  /// Insert a ledger entry. This is the only write operation allowed.
  ///
  /// Idempotent on `(profileId, ulid)`: duplicate inserts of the same logical
  /// entry collapse via `INSERT OR IGNORE` and return the existing row id
  /// (Story 25.2 / DNI-323).
  Future<int> insertEntry(LearningLedgerCompanion entry) async {
    final newId = await into(
      learningLedger,
    ).insert(entry, mode: InsertMode.insertOrIgnore);
    if (newId != 0) return newId;
    // `INSERT OR IGNORE` collapsed onto an existing row. The companion's
    // ulid must be present for the dedup to have triggered — look the row
    // up by (profileId, ulid) and return its id.
    if (!entry.ulid.present) {
      throw StateError(
        'INSERT OR IGNORE collided but the companion has no ulid set — '
        'cannot resolve the existing row id',
      );
    }
    final row =
        await (select(learningLedger)
              ..where(
                (t) =>
                    t.profileId.equals(entry.profileId.value) &
                    t.ulid.equals(entry.ulid.value),
              )
              ..limit(1))
            .getSingle();
    return row.id;
  }

  /// Fetch a single row by primary key (used after insert instead of loading
  /// the full profile ledger — avoids O(n²) when recording many units).
  Future<LearningLedgerData?> getEntryById(int id) =>
      (select(learningLedger)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Get all ledger entries for a specific profile.
  Future<List<LearningLedgerData>> getEntriesByProfile(int profileId) =>
      (select(learningLedger)
            ..where((t) => t.profileId.equals(profileId))
            ..orderBy([(t) => OrderingTerm.desc(t.completedAt)]))
          .get();

  /// Get ledger entries filtered by curriculum for a profile.
  Future<List<LearningLedgerData>> getEntriesByCurriculum(
    int profileId,
    String curriculumId,
  ) =>
      (select(learningLedger)
            ..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.curriculumId.equals(curriculumId),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.completedAt)]))
          .get();

  /// Get the completion count for a specific unit (for auto-numbering).
  Future<int> getCompletionCount(
    int profileId,
    String curriculumId,
    String unitIdentifier,
  ) async {
    final query = selectOnly(learningLedger)
      ..addColumns([learningLedger.id.count()])
      ..where(
        learningLedger.profileId.equals(profileId) &
            learningLedger.curriculumId.equals(curriculumId) &
            learningLedger.unitIdentifier.equals(unitIdentifier),
      );

    final result = await query.getSingle();
    return result.read(learningLedger.id.count()) ?? 0;
  }

  /// Get entries grouped by curriculum for a profile.
  ///
  /// Returns all entries ordered by curriculum, then by completedAt desc.
  Future<Map<String, List<LearningLedgerData>>> getEntriesGroupedByCurriculum(
    int profileId,
  ) async {
    final entries =
        await (select(learningLedger)
              ..where((t) => t.profileId.equals(profileId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.curriculumId),
                (t) => OrderingTerm.desc(t.completedAt),
              ]))
            .get();

    final grouped = <String, List<LearningLedgerData>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(entry.curriculumId, () => []).add(entry);
    }
    return grouped;
  }

  /// Get latest ledger entries for a profile (chronological view).
  Future<List<LearningLedgerData>> getLatestEntries(
    int profileId, {
    int limit = 50,
  }) =>
      (select(learningLedger)
            ..where((t) => t.profileId.equals(profileId))
            ..orderBy([(t) => OrderingTerm.desc(t.completedAt)])
            ..limit(limit))
          .get();

  // ========== Track-Scoped Queries (Story 20.2) ==========

  /// Get ledger entries for a specific track and profile.
  Future<List<LearningLedgerData>> getEntriesByTrack(
    int trackId,
    int profileId,
  ) =>
      (select(learningLedger)
            ..where(
              (t) => t.trackId.equals(trackId) & t.profileId.equals(profileId),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.completedAt)]))
          .get();

  /// Get completion count for a specific track, curriculum, and unit.
  Future<int> getCompletionCountByTrack(
    int trackId,
    int profileId,
    String curriculumId,
    String unitIdentifier,
  ) async {
    final query = selectOnly(learningLedger)
      ..addColumns([learningLedger.id.count()])
      ..where(
        learningLedger.trackId.equals(trackId) &
            learningLedger.profileId.equals(profileId) &
            learningLedger.curriculumId.equals(curriculumId) &
            learningLedger.unitIdentifier.equals(unitIdentifier),
      );
    final result = await query.getSingle();
    return result.read(learningLedger.id.count()) ?? 0;
  }

  /// Check if a ledger entry already exists (for dedup during sync merge).
  Future<bool> entryExists({
    required int profileId,
    required String curriculumId,
    required String unitIdentifier,
    required String trackType,
    required DateTime completedAt,
  }) async {
    final result =
        await (select(learningLedger)
              ..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.curriculumId.equals(curriculumId) &
                    t.unitIdentifier.equals(unitIdentifier) &
                    t.trackType.equals(trackType) &
                    t.completedAt.equals(completedAt),
              )
              ..limit(1))
            .get();
    return result.isNotEmpty;
  }
}

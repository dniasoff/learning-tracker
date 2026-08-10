import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/prior_completion_imports.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'prior_completion_import_dao.g.dart';

/// DAO for the [PriorCompletionImports] table.
///
/// Provides targeted insert / query / delete operations for the W4.26 B1
/// bulkInTrack tracking path. See [PriorCompletionImports] for the full
/// lifecycle description.
@DriftAccessor(tables: [PriorCompletionImports])
class PriorCompletionImportDao extends DatabaseAccessor<UserDatabase>
    with _$PriorCompletionImportDaoMixin {
  PriorCompletionImportDao(super.db);

  /// Record a batch of prior-import keys in a single DB batch call.
  ///
  /// Each [entries] companion must supply at minimum:
  ///  - [profileId], [curriculumId], [sefariaRef], [stageId], [trackType],
  ///    [source].
  ///
  /// Uses [InsertMode.insertOrIgnore] so duplicate calls (e.g., from
  /// idempotent retries) do not fail.
  Future<void> batchInsertImports(
    List<PriorCompletionImportsCompanion> entries,
  ) {
    return batch((b) {
      b.insertAll(
        priorCompletionImports,
        entries,
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  /// Returns `true` when a row with the given natural key exists in this table.
  ///
  /// Used by [CompletionWriter] to decide whether to delete the import record
  /// after a real-learning event hits the same key (the B8 upgrade path).
  Future<bool> isImported({
    required int profileId,
    required String curriculumId,
    required String sefariaRef,
    required int stageId,
    required String trackType,
  }) async {
    final row =
        await (select(priorCompletionImports)
              ..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.curriculumId.equals(curriculumId) &
                    t.sefariaRef.equals(sefariaRef) &
                    t.stageId.equals(stageId) &
                    t.trackType.equals(trackType),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Removes all prior-import records matching [profileId] + [sefariaRef] +
  /// [curriculumId] + [trackType].
  ///
  /// Called by [BulkPriorCompletionService.expungePriorCompletions] AFTER
  /// tombstoning the corresponding `completion_events` rows.  Also called by
  /// [CompletionWriter] when a real-learning event promotes a prior import to
  /// a genuine completion (B8 upgrade path).
  Future<void> deleteImportsForItem({
    required int profileId,
    required String sefariaRef,
    required String curriculumId,
    required String trackType,
  }) {
    return (delete(priorCompletionImports)..where(
          (t) =>
              t.profileId.equals(profileId) &
              t.sefariaRef.equals(sefariaRef) &
              t.curriculumId.equals(curriculumId) &
              t.trackType.equals(trackType),
        ))
        .go();
  }

  /// Removes a single prior-import record by its full natural key.
  ///
  /// Used by [CompletionWriter] when upgrading exactly one prior-import row
  /// to a real-learning event (the single-command [CompletionWriter.commit]
  /// path).
  Future<void> deleteImport({
    required int profileId,
    required String curriculumId,
    required String sefariaRef,
    required int stageId,
    required String trackType,
  }) {
    return (delete(priorCompletionImports)..where(
          (t) =>
              t.profileId.equals(profileId) &
              t.curriculumId.equals(curriculumId) &
              t.sefariaRef.equals(sefariaRef) &
              t.stageId.equals(stageId) &
              t.trackType.equals(trackType),
        ))
        .go();
  }
}

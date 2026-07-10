import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/stage_definitions.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'stage_dao.g.dart';

@DriftAccessor(tables: [StageDefinitions])
class StageDao extends DatabaseAccessor<UserDatabase> with _$StageDaoMixin {
  StageDao(super.db);

  Future<List<StageDefinition>> getAllStageDefinitions() =>
      select(stageDefinitions).get();

  Future<StageDefinition?> getStageDefinitionById(int id) => (select(
    stageDefinitions,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Returns stage definitions for a curriculum, ordered by stageOrder.
  ///
  /// W3.29: supersededAt dropped — all rows for the curriculum are returned.
  /// The edit-track flow now deletes-and-recreates rather than superseding.
  Future<List<StageDefinition>> getStageDefinitionsByCurriculum(
    String curriculumId,
  ) =>
      (select(stageDefinitions)
            ..where((t) => t.curriculumId.equals(curriculumId))
            ..orderBy([(t) => OrderingTerm.asc(t.stageOrder)]))
          .get();

  Future<int> insertStageDefinition(StageDefinitionsCompanion entry) =>
      into(stageDefinitions).insert(entry);

  Future<bool> updateStageDefinition(StageDefinitionsCompanion entry) =>
      update(stageDefinitions).replace(entry);

  /// Partial update of the sync-mutable fields on an existing stage
  /// definition, keyed by its local [id]. Leaves profileId/curriculumId/
  /// trackId/stageOrder untouched.
  ///
  /// AUD-core-sync-22 (DB-1): extracted from DriftMergeStore, which
  /// previously wrote `_db.update(_db.stageDefinitions)` directly for a
  /// remote sync row's update branch. [updateStageDefinition] above can't
  /// be reused as-is — it uses `.replace()`, which requires every column
  /// (would silently null out the FK/key columns this update must leave
  /// alone); this mirrors the exact partial-write shape the sync path uses.
  Future<void> updateStageDefinitionFields({
    required int id,
    required String stageName,
    required bool isDefault,
    required String schedule,
    required DateTime updatedAt,
  }) => (update(stageDefinitions)..where((t) => t.id.equals(id))).write(
    StageDefinitionsCompanion(
      stageName: Value(stageName),
      isDefault: Value(isDefault),
      schedule: Value(schedule),
      updatedAt: Value(updatedAt),
    ),
  );

  Future<int> deleteStageDefinition(int id) =>
      (delete(stageDefinitions)..where((t) => t.id.equals(id))).go();

  Future<int> deleteAllForCurriculum(String curriculumId) => (delete(
    stageDefinitions,
  )..where((t) => t.curriculumId.equals(curriculumId))).go();

  /// Returns the maximum stageOrder for a curriculum, or null if no stages exist.
  Future<int?> getMaxStageOrder(String curriculumId) async {
    final maxCol = stageDefinitions.stageOrder.max();
    final query = selectOnly(stageDefinitions)
      ..addColumns([maxCol])
      ..where(stageDefinitions.curriculumId.equals(curriculumId));
    final row = await query.getSingleOrNull();
    return row?.read(maxCol);
  }

  /// Returns the count of stages for a curriculum.
  Future<int> countStagesForCurriculum(String curriculumId) async {
    final countCol = stageDefinitions.id.count();
    final query = selectOnly(stageDefinitions)
      ..addColumns([countCol])
      ..where(stageDefinitions.curriculumId.equals(curriculumId));
    final row = await query.getSingleOrNull();
    return row?.read(countCol) ?? 0;
  }

  // ========== Track-Scoped Queries ==========

  /// Get stage definitions for a specific track, ordered by stageOrder.
  ///
  /// W3.29: supersededAt dropped; all rows for the track are returned.
  Future<List<StageDefinition>> getStagesByTrack(int trackId) =>
      (select(stageDefinitions)
            ..where((t) => t.trackId.equals(trackId))
            ..orderBy([(t) => OrderingTerm.asc(t.stageOrder)]))
          .get();

  /// Delete all stage definitions for a specific track.
  Future<int> deleteStagesForTrack(int trackId) =>
      (delete(stageDefinitions)..where((t) => t.trackId.equals(trackId))).go();

  /// Replace all stage definitions for a track.
  ///
  /// W3.29: replaces the old supersede-then-insert approach with a simple
  /// delete-and-recreate. stageId FKs on completion_events are plain integers
  /// (no DB constraint) so hard-deleting is safe.
  Future<void> replaceStagesForTrack(
    int trackId,
    List<StageDefinitionsCompanion> stages,
  ) async {
    await db.transaction(() async {
      await deleteStagesForTrack(trackId);
      for (final stage in stages) {
        await insertStageDefinition(stage);
      }
    });
  }

  /// Count stages for a specific track.
  Future<int> countStagesForTrack(int trackId) async {
    final countCol = stageDefinitions.id.count();
    final query = selectOnly(stageDefinitions)
      ..addColumns([countCol])
      ..where(stageDefinitions.trackId.equals(trackId));
    final row = await query.getSingleOrNull();
    return row?.read(countCol) ?? 0;
  }

  /// Get max stage order for a specific track.
  Future<int?> getMaxStageOrderForTrack(int trackId) async {
    final maxCol = stageDefinitions.stageOrder.max();
    final query = selectOnly(stageDefinitions)
      ..addColumns([maxCol])
      ..where(stageDefinitions.trackId.equals(trackId));
    final row = await query.getSingleOrNull();
    return row?.read(maxCol);
  }

  /// Runs [body] inside a database transaction.
  Future<T> runTransaction<T>(Future<T> Function() body) =>
      db.transaction(body);

  /// Replace all stage definitions for a curriculum with remote data.
  ///
  /// Used during sync merge (last-write-wins per D4).
  Future<void> replaceStagesForCurriculum(
    String curriculumId,
    List<StageDefinitionsCompanion> stages,
  ) async {
    await db.transaction(() async {
      await deleteAllForCurriculum(curriculumId);
      for (final stage in stages) {
        await insertStageDefinition(stage);
      }
    });
  }
}

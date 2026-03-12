import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/stage_definitions.dart';

part 'stage_dao.g.dart';

@DriftAccessor(tables: [StageDefinitions])
class StageDao extends DatabaseAccessor<AppDatabase> with _$StageDaoMixin {
  StageDao(super.db);

  Future<List<StageDefinition>> getAllStageDefinitions() =>
      select(stageDefinitions).get();

  Future<StageDefinition?> getStageDefinitionById(int id) => (select(
    stageDefinitions,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

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

  /// Replace all stage definitions for a curriculum with remote data.
  ///
  /// Used during sync merge (last-write-wins per D4).
  /// Deletes existing stages for the curriculum and inserts the new ones.
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

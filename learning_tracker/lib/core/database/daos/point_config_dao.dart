import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/point_configs.dart';

part 'point_config_dao.g.dart';

@DriftAccessor(tables: [PointConfigs])
class PointConfigDao extends DatabaseAccessor<AppDatabase>
    with _$PointConfigDaoMixin {
  PointConfigDao(super.db);

  /// Get all point configs for a curriculum, ordered by stage.
  Future<List<PointConfig>> getConfigsByCurriculum(String curriculumId) =>
      (select(pointConfigs)
            ..where((t) => t.curriculumId.equals(curriculumId))
            ..orderBy([(t) => OrderingTerm.asc(t.stageOrder)]))
          .get();

  /// Get the point value for a specific curriculum + stage.
  Future<PointConfig?> getConfig(String curriculumId, int stageOrder) =>
      (select(pointConfigs)
            ..where(
              (t) =>
                  t.curriculumId.equals(curriculumId) &
                  t.stageOrder.equals(stageOrder),
            )
            ..limit(1))
          .getSingleOrNull();

  /// Insert or update a point config (upsert by curriculum_id + stage_order).
  Future<int> upsertConfig(PointConfigsCompanion entry) =>
      into(pointConfigs).insertOnConflictUpdate(entry);

  /// Insert a point config.
  Future<int> insertConfig(PointConfigsCompanion entry) =>
      into(pointConfigs).insert(entry);

  /// Delete all configs for a curriculum.
  Future<int> deleteAllForCurriculum(String curriculumId) => (delete(
    pointConfigs,
  )..where((t) => t.curriculumId.equals(curriculumId))).go();

  /// Seed default point configs for a curriculum.
  ///
  /// Default values: Learn=10, Chazara1=5, Chazara2=3.
  Future<void> seedDefaults(String curriculumId) async {
    const defaults = [
      (stageOrder: 1, points: 10), // Learn
      (stageOrder: 2, points: 5), // Chazara 1
      (stageOrder: 3, points: 3), // Chazara 2
    ];

    for (final d in defaults) {
      await insertConfig(
        PointConfigsCompanion.insert(
          curriculumId: curriculumId,
          stageOrder: d.stageOrder,
          points: d.points,
        ),
      );
    }
  }
}

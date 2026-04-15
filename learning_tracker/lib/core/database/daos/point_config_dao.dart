import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/point_configs.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'point_config_dao.g.dart';

@DriftAccessor(tables: [PointConfigs])
class PointConfigDao extends DatabaseAccessor<UserDatabase>
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
  Future<void> upsertConfig(PointConfigsCompanion entry) async {
    final currId = entry.curriculumId.value;
    final stage = entry.stageOrder.value;
    final existing = await getConfig(currId, stage);
    if (existing != null) {
      await (update(pointConfigs)..where(
            (t) => t.curriculumId.equals(currId) & t.stageOrder.equals(stage),
          ))
          .write(PointConfigsCompanion(points: entry.points));
    } else {
      await insertConfig(entry);
    }
  }

  /// Insert a point config.
  Future<int> insertConfig(PointConfigsCompanion entry) =>
      into(pointConfigs).insert(entry);

  /// Delete all configs for a curriculum.
  Future<int> deleteAllForCurriculum(String curriculumId) => (delete(
    pointConfigs,
  )..where((t) => t.curriculumId.equals(curriculumId))).go();

  /// Seed default point configs for a curriculum.
  ///
  /// Queries stage definitions for the curriculum to determine how many stages
  /// exist, then assigns descending point values: first stage gets 10 points,
  /// subsequent stages get decreasing values (minimum 1).
  Future<void> seedDefaults(String curriculumId, int trackId) async {
    final stages = await db.stageDao.getStageDefinitionsByCurriculum(
      curriculumId,
    );

    // Fallback to 3 hardcoded stages if no stage definitions exist yet
    if (stages.isEmpty) {
      const fallbackDefaults = [
        (stageOrder: 1, points: 10),
        (stageOrder: 2, points: 5),
        (stageOrder: 3, points: 3),
      ];
      for (final d in fallbackDefaults) {
        await insertConfig(
          PointConfigsCompanion.insert(
            curriculumId: curriculumId,
            trackId: trackId,
            stageOrder: d.stageOrder,
            points: d.points,
          ),
        );
      }
      return;
    }

    // Assign descending point values based on stage order
    const defaultPoints = [10, 5, 3, 2, 1];
    for (final stage in stages) {
      final pointIndex = stage.stageOrder - 1;
      final points = pointIndex < defaultPoints.length
          ? defaultPoints[pointIndex]
          : 1;
      await insertConfig(
        PointConfigsCompanion.insert(
          curriculumId: curriculumId,
          trackId: trackId,
          stageOrder: stage.stageOrder,
          points: points,
        ),
      );
    }
  }

  // ========== Track-Scoped Queries (Story 20.2) ==========

  /// Get all point configs for a specific track, ordered by stage.
  Future<List<PointConfig>> getConfigsByTrack(int trackId) =>
      (select(pointConfigs)
            ..where((t) => t.trackId.equals(trackId))
            ..orderBy([(t) => OrderingTerm.asc(t.stageOrder)]))
          .get();

  /// Delete all point configs for a specific track.
  Future<int> deleteAllForTrack(int trackId) =>
      (delete(pointConfigs)..where((t) => t.trackId.equals(trackId))).go();
}

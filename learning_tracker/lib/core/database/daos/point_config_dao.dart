import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/base_dao.dart';
import 'package:learning_tracker/core/database/tables/point_configs.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'point_config_dao.g.dart';

@DriftAccessor(tables: [PointConfigs])
class PointConfigDao extends DatabaseAccessor<UserDatabase>
    with
        _$PointConfigDaoMixin,
        BaseDao<$PointConfigsTable, PointConfig, UserDatabase> {
  PointConfigDao(super.db);

  @override
  TableInfo<$PointConfigsTable, PointConfig> get table => pointConfigs;

  @override
  Expression<int> idColumn($PointConfigsTable t) => t.id;

  @override
  Expression<int> profileIdColumn($PointConfigsTable t) => t.profileId;

  /// Get all point configs for a curriculum, ordered by stage.
  ///
  /// Optional [profileId] and [trackId] filters allow strict track-scoped
  /// configuration reads.
  Future<List<PointConfig>> getConfigsByCurriculum(
    String curriculumId, {
    int? profileId,
    int? trackId,
  }) {
    final query = select(pointConfigs)
      ..where((t) => t.curriculumId.equals(curriculumId))
      ..orderBy([(t) => OrderingTerm.asc(t.stageOrder)]);

    if (profileId != null) {
      query.where((t) => t.profileId.equals(profileId));
    }
    if (trackId != null) {
      query.where((t) => t.trackId.equals(trackId));
    }
    return query.get();
  }

  /// Get the point value for a specific curriculum + stage + track.
  Future<PointConfig?> getConfig(
    String curriculumId,
    int stageOrder, {
    required int profileId,
    required int trackId,
  }) =>
      (select(pointConfigs)
            ..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.trackId.equals(trackId) &
                  t.curriculumId.equals(curriculumId) &
                  t.stageOrder.equals(stageOrder),
            )
            ..limit(1))
          .getSingleOrNull();

  /// Insert or update a point config (upsert by
  /// profile_id + track_id + curriculum_id + stage_order).
  Future<void> upsertConfig(PointConfigsCompanion entry) async {
    final currId = entry.curriculumId.value;
    final stage = entry.stageOrder.value;
    final profileId = entry.profileId.value;
    final trackId = entry.trackId.value;
    final existing = await getConfig(
      currId,
      stage,
      profileId: profileId,
      trackId: trackId,
    );
    if (existing != null) {
      await (update(pointConfigs)..where(
            (t) =>
                t.profileId.equals(profileId) &
                t.trackId.equals(trackId) &
                t.curriculumId.equals(currId) &
                t.stageOrder.equals(stage),
          ))
          .write(
            PointConfigsCompanion(
              profileId: Value(profileId),
              trackId: Value(trackId),
              points: entry.points,
            ),
          );
    } else {
      await insertConfig(entry);
    }
  }

  /// Insert a point config.
  Future<int> insertConfig(PointConfigsCompanion entry) =>
      into(pointConfigs).insert(entry);

  /// Delete all configs for a curriculum + profile.
  Future<int> deleteAllForCurriculum(
    String curriculumId, {
    required int profileId,
  }) =>
      (delete(pointConfigs)..where(
            (t) =>
                t.curriculumId.equals(curriculumId) &
                t.profileId.equals(profileId),
          ))
          .go();

  /// Seed default point configs for a curriculum.
  ///
  /// Uses [trackId]-scoped stage definitions only. Querying by curriculum alone
  /// would include other profiles' tracks and duplicate [stageOrder] rows when
  /// inserting for this track, violating the unique key on point_configs.
  Future<void> seedDefaults(
    String curriculumId,
    int trackId, {
    required int profileId,
  }) async {
    final stages = await db.stageDao.getStagesByTrack(trackId);

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
            profileId: profileId,
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
          profileId: profileId,
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

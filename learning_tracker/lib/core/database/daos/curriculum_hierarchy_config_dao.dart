import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/curriculum_hierarchy_config.dart';

part 'curriculum_hierarchy_config_dao.g.dart';

@DriftAccessor(tables: [CurriculumHierarchyConfig])
class CurriculumHierarchyConfigDao extends DatabaseAccessor<AppDatabase>
    with _$CurriculumHierarchyConfigDaoMixin {
  CurriculumHierarchyConfigDao(super.db);

  /// Get hierarchy configuration for a specific curriculum.
  Future<CurriculumHierarchyConfigData?> getConfigForCurriculum(
    String curriculumId,
  ) =>
      (select(curriculumHierarchyConfig)
            ..where((t) => t.curriculumId.equals(curriculumId)))
          .getSingleOrNull();

  /// Get all curriculum hierarchy configurations.
  Future<List<CurriculumHierarchyConfigData>> getAllConfigs() =>
      select(curriculumHierarchyConfig).get();

  /// Insert or update a curriculum hierarchy configuration.
  Future<int> upsertConfig(CurriculumHierarchyConfigCompanion config) =>
      into(curriculumHierarchyConfig).insertOnConflictUpdate(config);

  /// Get the label for a specific level in a curriculum.
  /// Returns null if the level doesn't exist for this curriculum.
  Future<String?> getLevelLabel(String curriculumId, int level) async {
    final config = await getConfigForCurriculum(curriculumId);
    if (config == null) return null;

    return switch (level) {
      0 => config.level1Label,
      1 => config.level2Label,
      2 => config.level3Label,
      3 => config.level4Label,
      _ => null,
    };
  }

  /// Get all level labels for a curriculum as a list.
  /// Returns labels only for levels that exist (up to maxLevels).
  Future<List<String>> getLevelLabels(String curriculumId) async {
    final config = await getConfigForCurriculum(curriculumId);
    if (config == null) return [];

    final labels = <String>[];
    if (config.level1Label.isNotEmpty) labels.add(config.level1Label);
    if (config.level2Label != null && config.level2Label!.isNotEmpty) {
      labels.add(config.level2Label!);
    }
    if (config.level3Label != null && config.level3Label!.isNotEmpty) {
      labels.add(config.level3Label!);
    }
    if (config.level4Label != null && config.level4Label!.isNotEmpty) {
      labels.add(config.level4Label!);
    }

    return labels.take(config.maxLevels).toList();
  }
}

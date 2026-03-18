import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Default curriculum configuration constants per D3.
///
/// Default learning cycle: Learn > Chazara 1 (+1 day) > Chazara 2 (+7 days).
/// Users can customize stage count, names, and timing per curriculum.
class CurriculumDefaults {
  CurriculumDefaults._();

  /// Default stage definitions applied to all curricula.
  /// Stage order is 0-indexed; stage names are lowercase identifiers.
  static const List<DefaultStageDefinition> defaultStages = [
    DefaultStageDefinition(stageOrder: 0, stageName: 'learn', delayDays: 0),
    DefaultStageDefinition(stageOrder: 1, stageName: 'chazara1', delayDays: 1),
    DefaultStageDefinition(stageOrder: 2, stageName: 'chazara2', delayDays: 7),
  ];

  /// Points awarded per stage completion (keyed by stageOrder).
  static const Map<int, int> defaultPointsPerStage = {
    0: 10, // learn
    1: 5, // chazara1
    2: 3, // chazara2
  };

  /// Hierarchy label configs per curriculum (maps to curriculum_hierarchy_config table).
  static const Map<CurriculumId, CurriculumHierarchyDefaults> hierarchyConfigs =
      {
        CurriculumId.mishnayos: CurriculumHierarchyDefaults(
          level1Label: 'Seder',
          level2Label: 'Masechta',
          level3Label: 'Perek',
          level4Label: 'Mishna',
          maxLevels: 4,
        ),
        CurriculumId.bavli: CurriculumHierarchyDefaults(
          level1Label: 'Masechta',
          level2Label: 'Daf',
          level3Label: 'Amud',
          maxLevels: 3,
        ),
        CurriculumId.yerushalmi: CurriculumHierarchyDefaults(
          level1Label: 'Masechta',
          level2Label: 'Daf',
          level3Label: 'Halacha',
          maxLevels: 3,
        ),
        CurriculumId.mishnaBerurah: CurriculumHierarchyDefaults(
          level1Label: 'Siman',
          level2Label: 'Seif',
          level3Label: 'Seif Katan',
          maxLevels: 3,
        ),
        CurriculumId.chumash: CurriculumHierarchyDefaults(
          level1Label: 'Sefer',
          level2Label: 'Parsha',
          level3Label: 'Perek',
          level4Label: 'Pasuk',
          maxLevels: 4,
        ),
        CurriculumId.torah: CurriculumHierarchyDefaults(
          level1Label: 'Sefer',
          level2Label: 'Parsha',
          level3Label: 'Perek',
          level4Label: 'Pasuk',
          maxLevels: 4,
        ),
        CurriculumId.tanach: CurriculumHierarchyDefaults(
          level1Label: 'Section',
          level2Label: 'Sefer',
          level3Label: 'Perek',
          level4Label: 'Pasuk',
          maxLevels: 4,
        ),
        CurriculumId.nach: CurriculumHierarchyDefaults(
          level1Label: 'Section',
          level2Label: 'Sefer',
          level3Label: 'Perek',
          level4Label: 'Pasuk',
          maxLevels: 4,
        ),
        CurriculumId.mussar: CurriculumHierarchyDefaults(
          level1Label: 'Sefer',
          level2Label: 'Section',
          level3Label: 'Chapter',
          maxLevels: 3,
        ),
      };

  /// Default daily learning targets per curriculum (items per day).
  static const Map<CurriculumId, int> defaultDailyTargets = {
    CurriculumId.mishnayos: 3,
    CurriculumId.bavli: 1,
    CurriculumId.yerushalmi: 1,
    CurriculumId.mishnaBerurah: 2,
    CurriculumId.chumash: 5,
    CurriculumId.torah: 5,
    CurriculumId.tanach: 3,
    CurriculumId.nach: 3,
    CurriculumId.mussar: 1,
  };
}

/// A default stage definition template.
class DefaultStageDefinition {
  const DefaultStageDefinition({
    required this.stageOrder,
    required this.stageName,
    required this.delayDays,
  });

  final int stageOrder;
  final String stageName;
  final int delayDays;
}

/// Default hierarchy labels for a curriculum.
class CurriculumHierarchyDefaults {
  const CurriculumHierarchyDefaults({
    required this.level1Label,
    this.level2Label,
    this.level3Label,
    this.level4Label,
    required this.maxLevels,
  });

  final String level1Label;
  final String? level2Label;
  final String? level3Label;
  final String? level4Label;
  final int maxLevels;
}

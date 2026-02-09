/// Describes the hierarchy structure for a curriculum.
///
/// Each curriculum has a different number of levels with different labels.
/// This config tells the UI how to display navigation breadcrumbs and
/// hierarchy selectors.
class CurriculumHierarchyConfig {
  const CurriculumHierarchyConfig({
    required this.curriculumId,
    required this.levelLabels,
    required this.totalItems,
  });

  /// Which curriculum this config describes (uses CurriculumId.storageKey).
  final String curriculumId;

  /// Human-readable labels for each hierarchy level, ordered from top to bottom.
  /// e.g., ['Seder', 'Masechta', 'Perek', 'Mishna'] for Mishnayos.
  final List<String> levelLabels;

  /// Total number of leaf-level items in this curriculum.
  final int totalItems;

  /// Number of hierarchy levels.
  int get depth => levelLabels.length;

  @override
  String toString() =>
      'CurriculumHierarchyConfig($curriculumId, $levelLabels, $totalItems items)';
}

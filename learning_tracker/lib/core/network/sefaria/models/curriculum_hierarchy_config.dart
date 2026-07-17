import 'package:freezed_annotation/freezed_annotation.dart';

part 'curriculum_hierarchy_config.freezed.dart';

/// Describes the hierarchy structure for a curriculum.
///
/// Each curriculum has a different number of levels with different labels.
/// This config tells the UI how to display navigation breadcrumbs and
/// hierarchy selectors.
///
/// `@freezed` generates field-wise `==`/`hashCode`/`copyWith`/`toString`
/// (previously this class had no `==` at all and fell back to identity, so
/// two field-identical instances were never equal — AUD-core-network-01).
/// It also wraps the generated [levelLabels] getter in an
/// `EqualUnmodifiableListView`, so the list cannot be mutated in place
/// through the public API: `ContentRepositoryImpl._configCache` caches a
/// single instance and hands the same object to every reader, and without
/// this a mutable list would let one caller's in-place mutation
/// (`.add`/`.removeAt`/etc.) corrupt the value seen by every other reader.
@freezed
abstract class CurriculumHierarchyConfig with _$CurriculumHierarchyConfig {
  const factory CurriculumHierarchyConfig({
    /// Which curriculum this config describes (uses CurriculumId.storageKey).
    required String curriculumId,

    /// Human-readable labels for each hierarchy level, ordered from top to
    /// bottom. e.g., ['Seder', 'Masechta', 'Perek', 'Mishna'] for Mishnayos.
    required List<String> levelLabels,

    /// Total number of leaf-level items in this curriculum.
    required int totalItems,
  }) = _CurriculumHierarchyConfig;

  const CurriculumHierarchyConfig._();

  /// Number of hierarchy levels.
  int get depth => levelLabels.length;
}

/// Test fixtures for CurriculumId and related enums
/// Factory methods for creating test data with sensible defaults
library;

import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Factory for curriculum-related test data
class CurriculumFixtures {
  /// Returns the default test curriculum (Mishnayos)
  static CurriculumId get defaultCurriculum => CurriculumId.mishnayos;

  /// Returns all curriculum IDs for exhaustive testing
  static List<CurriculumId> get allCurricula => CurriculumId.values;

  /// Returns a curriculum by its storage key
  static CurriculumId fromStorageKey(String key) {
    return CurriculumId.values.firstWhere(
      (c) => c.storageKey == key,
      orElse: () => throw ArgumentError('Unknown curriculum key: $key'),
    );
  }

  /// Returns storage keys for all curricula
  static List<String> get allStorageKeys =>
      CurriculumId.values.map((c) => c.storageKey).toList();
}

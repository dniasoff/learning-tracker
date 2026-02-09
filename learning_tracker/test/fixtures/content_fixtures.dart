/// Test fixtures for ContentItem
/// Factory methods for creating test data with sensible defaults
library;

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';

/// Factory for creating test ContentItem instances
class ContentItemFixtures {
  /// Creates a test mishna (Mishnayos curriculum, leaf item)
  static ContentItem mishna({
    String? curriculumId,
    String level1 = 'Seder Zeraim',
    String level2 = 'Berachos',
    String level3 = '1',
    String level4 = '1',
    String? displayNameHe,
    String? displayNameEn,
    String? sefariaRef,
    int sortOrder = 1,
    bool isLeaf = true,
  }) {
    return ContentItem(
      curriculumId: curriculumId ?? CurriculumId.mishnayos.storageKey,
      level1: level1,
      level2: level2,
      level3: level3,
      level4: level4,
      displayNameHe: displayNameHe ?? 'ברכות $level3:$level4',
      displayNameEn: displayNameEn ?? '$level2 $level3:$level4',
      sefariaRef: sefariaRef ?? 'Mishnah $level2 $level3.$level4',
      sortOrder: sortOrder,
      isLeaf: isLeaf,
    );
  }

  /// Creates a test daf (Bavli curriculum, leaf item)
  static ContentItem daf({
    String? curriculumId,
    String level1 = 'Seder Zeraim',
    String level2 = 'Berachos',
    String level3 = '2a',
    String? level4,
    String? displayNameHe,
    String? displayNameEn,
    String? sefariaRef,
    int sortOrder = 1,
    bool isLeaf = true,
  }) {
    return ContentItem(
      curriculumId: curriculumId ?? CurriculumId.bavli.storageKey,
      level1: level1,
      level2: level2,
      level3: level3,
      level4: level4,
      displayNameHe: displayNameHe ?? '$level2 $level3',
      displayNameEn: displayNameEn ?? '$level2 $level3',
      sefariaRef: sefariaRef ?? '$level2 $level3',
      sortOrder: sortOrder,
      isLeaf: isLeaf,
    );
  }

  /// Creates a test pasuk (Chumash curriculum, leaf item)
  static ContentItem pasuk({
    String? curriculumId,
    String level1 = 'Torah',
    String level2 = 'Bereishis',
    String level3 = 'Bereishis',
    String level4 = '1:1',
    String? displayNameHe,
    String? displayNameEn,
    String? sefariaRef,
    int sortOrder = 1,
    bool isLeaf = true,
  }) {
    return ContentItem(
      curriculumId: curriculumId ?? CurriculumId.chumash.storageKey,
      level1: level1,
      level2: level2,
      level3: level3,
      level4: level4,
      displayNameHe: displayNameHe ?? 'בראשית $level4',
      displayNameEn: displayNameEn ?? '$level3 $level4',
      sefariaRef: sefariaRef ?? 'Genesis $level4',
      sortOrder: sortOrder,
      isLeaf: isLeaf,
    );
  }

  /// Creates a test container (non-leaf item like a seder or masechta)
  static ContentItem container({
    String? curriculumId,
    required String level1,
    String? level2,
    String? level3,
    String? level4,
    String? displayNameHe,
    String? displayNameEn,
    String? sefariaRef,
    int sortOrder = 0,
  }) {
    return ContentItem(
      curriculumId: curriculumId ?? CurriculumId.mishnayos.storageKey,
      level1: level1,
      level2: level2,
      level3: level3,
      level4: level4,
      displayNameHe: displayNameHe ?? level2 ?? level1,
      displayNameEn: displayNameEn ?? level2 ?? level1,
      sefariaRef: sefariaRef ?? level2 ?? level1,
      sortOrder: sortOrder,
      isLeaf: false,
    );
  }
}

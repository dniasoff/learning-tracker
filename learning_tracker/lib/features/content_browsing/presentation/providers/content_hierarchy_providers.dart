import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/content_items.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'content_hierarchy_providers.g.dart';

/// Data class representing a curriculum with metadata for the list screen.
class CurriculumInfo {
  const CurriculumInfo({
    required this.curriculum,
    required this.itemCount,
  });

  final CurriculumId curriculum;
  final int itemCount;
}

/// Simple DTO for content hierarchy items to avoid Drift-generated type issues.
class HierarchyItemDTO {
  const HierarchyItemDTO({
    required this.id,
    required this.curriculumId,
    required this.level1,
    this.level2,
    this.level3,
    this.level4,
    required this.displayNameHe,
    required this.displayNameEn,
    this.sefariaRef,
    required this.sortOrder,
    required this.isLeaf,
  });

  final int id;
  final String curriculumId;
  final String level1;
  final String? level2;
  final String? level3;
  final String? level4;
  final String displayNameHe;
  final String displayNameEn;
  final String? sefariaRef;
  final int sortOrder;
  final bool isLeaf;

  /// Convert from Drift ContentItem.
  factory HierarchyItemDTO.fromContentItem(ContentItem item) {
    return HierarchyItemDTO(
      id: item.id,
      curriculumId: item.curriculumId,
      level1: item.level1,
      level2: item.level2,
      level3: item.level3,
      level4: item.level4,
      displayNameHe: item.displayNameHe,
      displayNameEn: item.displayNameEn,
      sefariaRef: item.sefariaRef,
      sortOrder: item.sortOrder,
      isLeaf: item.isLeaf,
    );
  }
}

/// Parameters for querying hierarchy items.
/// Encodes the hierarchy position as simple properties for Riverpod family.
class HierarchyQueryParams {
  const HierarchyQueryParams({
    required this.curriculumId,
    this.level1,
    this.level2,
    this.level3,
  });

  final String curriculumId;
  final String? level1;
  final String? level2;
  final String? level3;

  /// Get the current depth (0-3, representing which level we're viewing children of).
  int get depth {
    if (level3 != null) return 3;
    if (level2 != null) return 2;
    if (level1 != null) return 1;
    return 0;
  }

  /// Create a provider key for this query.
  /// Format: "curriculumId" or "curriculumId/level1" or "curriculumId/level1/level2" etc.
  String toKey() {
    final parts = [curriculumId];
    if (level1 != null) parts.add(level1!);
    if (level2 != null) parts.add(level2!);
    if (level3 != null) parts.add(level3!);
    return parts.join('/');
  }

  /// Parse a key back into params.
  factory HierarchyQueryParams.fromKey(String key) {
    final parts = key.split('/');
    return HierarchyQueryParams(
      curriculumId: parts[0],
      level1: parts.length > 1 ? parts[1] : null,
      level2: parts.length > 2 ? parts[2] : null,
      level3: parts.length > 3 ? parts[3] : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HierarchyQueryParams &&
          curriculumId == other.curriculumId &&
          level1 == other.level1 &&
          level2 == other.level2 &&
          level3 == other.level3;

  @override
  int get hashCode => Object.hash(curriculumId, level1, level2, level3);
}

/// Provider for all active curricula with item counts.
/// Used by the curriculum list screen.
@riverpod
Future<List<CurriculumInfo>> curriculumList(CurriculumListRef ref) async {
  final db = ref.watch(appDatabaseProvider);
  final contentDao = db.contentDao;

  final curricula = CurriculumId.values;
  final results = <CurriculumInfo>[];

  for (final curriculum in curricula) {
    final count = await contentDao.getCurriculumItemCount(curriculum.storageKey);
    if (count > 0) {
      results.add(CurriculumInfo(curriculum: curriculum, itemCount: count));
    }
  }

  return results;
}

/// Provider for hierarchy configuration labels for a curriculum.
/// Uses family pattern per P3 requirements.
@riverpod
Future<List<String>> hierarchyLabels(
  HierarchyLabelsRef ref,
  String curriculumId,
) async {
  final db = ref.watch(appDatabaseProvider);
  final configDao = db.curriculumHierarchyConfigDao;
  return configDao.getLevelLabels(curriculumId);
}

/// Provider for content items at a specific hierarchy path.
/// Uses family pattern per P3 requirements.
/// Pass a hierarchy key in format "curriculumId/level1/level2/..." or just "curriculumId" for top level.
@riverpod
Future<List<HierarchyItemDTO>> hierarchyItems(
  HierarchyItemsRef ref,
  String hierarchyKey,
) async {
  final params = HierarchyQueryParams.fromKey(hierarchyKey);
  final db = ref.watch(appDatabaseProvider);
  final contentDao = db.contentDao;

  final items = await switch (params.depth) {
    0 => contentDao.getTopLevelItems(params.curriculumId),
    1 => contentDao.getLevel2Items(params.curriculumId, params.level1!),
    2 => contentDao.getLevel3Items(
        params.curriculumId,
        params.level1!,
        params.level2!,
      ),
    3 => contentDao.getLevel4Items(
        params.curriculumId,
        params.level1!,
        params.level2!,
        params.level3!,
      ),
    _ => <ContentItem>[],
  };

  return items.map(HierarchyItemDTO.fromContentItem).toList();
}

/// Provider for getting a specific content item's details by path.
/// Used for breadcrumb display names.
@riverpod
Future<HierarchyItemDTO?> contentItemByPath(
  ContentItemByPathRef ref,
  String hierarchyKey,
) async {
  final params = HierarchyQueryParams.fromKey(hierarchyKey);
  if (params.depth == 0) return null; // No item at root level

  final db = ref.watch(appDatabaseProvider);
  final contentDao = db.contentDao;

  final item = await contentDao.getItemByPath(
    params.curriculumId,
    params.level1!,
    params.depth >= 2 ? params.level2 : null,
    params.depth >= 3 ? params.level3 : null,
    null, // level4 not supported in path (leaf items don't have children)
  );

  return item != null ? HierarchyItemDTO.fromContentItem(item) : null;
}

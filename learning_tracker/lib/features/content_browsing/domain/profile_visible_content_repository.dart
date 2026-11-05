import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/domain/hidden_content.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';

/// Profile-keyed view over the raw bundled content repository.
class ProfileVisibleContentRepository
    implements ContentRepository, LifetimeUnionLeafSource {
  ProfileVisibleContentRepository(this._raw, this.hiddenRefs);

  final ContentRepository _raw;
  final Set<String> hiddenRefs;

  /// Preserve the bounded lifetime-total path through the profile view.
  ///
  /// The visibility wrapper must not hide the raw repository's transient
  /// loading capability: doing so would make lifetime totals fall back to
  /// permanently materializing every curriculum.
  @override
  Future<List<ContentItem>> loadLeavesTransient(
    CurriculumId curriculumId,
  ) async {
    final leaves = _raw is LifetimeUnionLeafSource
        ? await (_raw as LifetimeUnionLeafSource).loadLeavesTransient(
            curriculumId,
          )
        : (await _raw.getContentForCurriculum(
            curriculumId,
          )).where((item) => item.isLeaf).toList();
    if (hiddenRefs.isEmpty) return leaves;
    return HiddenContentFilter.visible(leaves, hiddenRefs);
  }

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async => hiddenRefs.isEmpty
      ? _raw.getContentForCurriculum(curriculumId)
      : HiddenContentFilter.visible(
          await _raw.getContentForCurriculum(curriculumId),
          hiddenRefs,
        );

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) async {
    if (hiddenRefs.isEmpty) return _raw.getHierarchyConfig(curriculumId);
    final config = await _raw.getHierarchyConfig(curriculumId);
    final visible = await getContentForCurriculum(curriculumId);
    return config.copyWith(totalItems: visible.where((i) => i.isLeaf).length);
  }

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async {
    if (hiddenRefs.isEmpty) {
      return _raw.filterByLevel(
        curriculumId: curriculumId,
        level1: level1,
        level2: level2,
        level3: level3,
        level4: level4,
      );
    }
    final items = await getContentForCurriculum(curriculumId);
    return items.where((item) {
      if (level1 != null && item.level1 != level1) return false;
      if (level2 != null && item.level2 != level2) return false;
      if (level3 != null && item.level3 != level3) return false;
      if (level4 != null && item.level4 != level4) return false;
      return true;
    }).toList();
  }

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async {
    if (hiddenRefs.isEmpty) {
      return _raw.getScopedContent(
        curriculumId: curriculumId,
        scopeLevel: scopeLevel,
        scopeValues: scopeValues,
      );
    }
    final items = await getContentForCurriculum(curriculumId);
    if (scopeValues.isEmpty) return items;
    final values = scopeValues.toSet();
    return items.where((item) {
      final value = switch (scopeLevel) {
        1 => item.level1,
        2 => item.level2,
        3 => item.level3,
        4 => item.level4,
        _ => null,
      };
      return value != null && values.contains(value);
    }).toList();
  }

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) async {
    if (query.isEmpty) return [];
    if (hiddenRefs.isEmpty) {
      return _raw.search(curriculumId: curriculumId, query: query);
    }
    final visible = await getContentForCurriculum(curriculumId);
    final raw = await _raw.search(curriculumId: curriculumId, query: query);
    final visibleRefs = visible.map((item) => item.sefariaRef).toSet();
    return [
      for (final item in raw)
        if (visibleRefs.contains(item.sefariaRef)) item,
    ];
  }

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async {
    if (hiddenRefs.isEmpty) {
      return _raw.getContentByRef(
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
      );
    }
    final visible = await getContentForCurriculum(curriculumId);
    for (final item in visible) {
      if (item.sefariaRef == sefariaRef) return item;
    }
    return null;
  }
}

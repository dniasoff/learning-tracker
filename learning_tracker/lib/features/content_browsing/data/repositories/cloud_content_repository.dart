import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/utils/hebrew_utils.dart';
import 'package:learning_tracker/features/content_browsing/data/services/cloud_content_service.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';

/// Implementation of [ContentRepository] that fetches content from
/// Firebase Cloud Storage instead of bundled assets.
///
/// Content is downloaded on first access per curriculum/language and cached
/// in memory. Falls back to the cloud service for initial fetch.
class CloudContentRepository implements ContentRepository {
  CloudContentRepository({
    required CloudContentService cloudContentService,
    this.languageCode = 'he',
  }) : _cloudContentService = cloudContentService;

  final CloudContentService _cloudContentService;
  final String languageCode;

  /// Cache of loaded content, keyed by curriculum storage key.
  final _contentCache = <String, List<ContentItem>>{};

  /// Cache of hierarchy configs, keyed by curriculum storage key.
  final _configCache = <String, CurriculumHierarchyConfig>{};

  /// Whether content has been downloaded for a curriculum.
  bool isDownloaded(CurriculumId curriculumId) {
    return _contentCache.containsKey(curriculumId.storageKey);
  }

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async {
    final key = curriculumId.storageKey;

    if (_contentCache.containsKey(key)) {
      return _contentCache[key]!;
    }

    try {
      final result = await _cloudContentService.parseContent(
        curriculum: curriculumId,
        languageCode: languageCode,
      );

      _contentCache[key] = result.items;
      _configCache[key] = result.config;
      return result.items;
    } catch (e) {
      throw ContentLoadException(
        'Failed to load content for ${curriculumId.displayNameEn} from cloud',
        cause: e,
      );
    }
  }

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) async {
    final key = curriculumId.storageKey;

    if (_configCache.containsKey(key)) {
      return _configCache[key]!;
    }

    await getContentForCurriculum(curriculumId);
    return _configCache[key]!;
  }

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async {
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
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) async {
    if (query.isEmpty) {
      return [];
    }

    final items = await getContentForCurriculum(curriculumId);
    final normalizedQuery = HebrewUtils.stripNikud(query.toLowerCase().trim());

    return items.where((item) {
      final normalizedHe = HebrewUtils.stripNikud(item.displayNameHe);
      final normalizedEn = item.displayNameEn.toLowerCase();
      return normalizedHe.contains(normalizedQuery) ||
          normalizedEn.contains(normalizedQuery);
    }).toList();
  }

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async {
    final items = await getContentForCurriculum(curriculumId);
    final matches = items.where((item) => item.sefariaRef == sefariaRef);
    return matches.isNotEmpty ? matches.first : null;
  }
}

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/utils/hebrew_utils.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';

/// In-memory implementation of [ContentRepository].
///
/// Loads JSON content from assets on first access and caches in memory.
/// All operations are synchronous after initial load.
class ContentRepositoryImpl implements ContentRepository {
  /// Cache of loaded content, keyed by curriculum storage key.
  final _contentCache = <String, List<ContentItem>>{};

  /// Cache of hierarchy configs, keyed by curriculum storage key.
  final _configCache = <String, CurriculumHierarchyConfig>{};

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async {
    final key = curriculumId.storageKey;

    // Return cached if available
    if (_contentCache.containsKey(key)) {
      return _contentCache[key]!;
    }

    // Load and parse JSON
    try {
      final jsonString = await rootBundle.loadString(
        'assets/content/${_getFilename(curriculumId)}',
      );

      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      // Parse hierarchy config
      final configJson = json['hierarchyConfig'] as Map<String, dynamic>;
      final config = CurriculumHierarchyConfig(
        curriculumId: configJson['curriculumId'] as String,
        levelLabels: (configJson['levelLabels'] as List)
            .map((e) => e as String)
            .toList(),
        totalItems: configJson['totalItems'] as int,
      );
      _configCache[key] = config;

      // Parse items
      final itemsJson = json['items'] as List;
      final items = itemsJson.map((itemJson) {
        final item = itemJson as Map<String, dynamic>;
        return ContentItem(
          curriculumId: item['curriculumId'] as String,
          level1: item['level1'] as String,
          level2: item['level2'] as String?,
          level3: item['level3'] as String?,
          level4: item['level4'] as String?,
          displayNameHe: item['displayNameHe'] as String,
          displayNameEn: item['displayNameEn'] as String,
          sefariaRef: item['sefariaRef'] as String,
          sortOrder: item['sortOrder'] as int,
          isLeaf: item['isLeaf'] as bool,
        );
      }).toList();

      _contentCache[key] = items;
      return items;
    } catch (e) {
      // Intentional catch-all: wraps any load failure (network, parse, IO)
      // into a typed ContentLoadException for callers to handle uniformly.
      throw ContentLoadException(
        'Failed to load content for ${curriculumId.displayNameEn}',
        cause: e,
      );
    }
  }

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) async {
    final key = curriculumId.storageKey;

    // Return cached if available
    if (_configCache.containsKey(key)) {
      return _configCache[key]!;
    }

    // Load content (which also loads config)
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

    // Normalize the query: lowercase for Latin, strip nikud for Hebrew.
    // Hebrew toLowerCase() is a no-op, so we strip diacritics (nikud) from
    // both query and item names to enable nikud-insensitive Hebrew matching.
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

  /// Maps curriculum ID to JSON filename.
  String _getFilename(CurriculumId curriculumId) {
    switch (curriculumId) {
      case CurriculumId.mishnayos:
        return 'mishnayos.json';
      case CurriculumId.bavli:
        return 'bavli.json';
      case CurriculumId.yerushalmi:
        return 'yerushalmi.json';
      case CurriculumId.chumash:
        return 'chumash.json';
      case CurriculumId.mishnaBerurah:
        return 'mishna_berurah.json';
      case CurriculumId.nach:
        return 'nach.json';
      case CurriculumId.mussar:
        return 'mussar.json';
    }
  }
}

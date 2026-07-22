import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/utils/hebrew_utils.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/strategies/composite_curriculum_strategy.dart';

/// Asset-backed implementation of [ContentRepository].
///
/// Loads hierarchy content from bundled JSON assets on first access
/// and caches in memory. All operations are synchronous after initial load.
///
/// Assets are at: assets/content/hierarchy/{curriculum_id}.json
class ContentRepositoryImpl implements ContentRepository {
  /// Cache of loaded content, keyed by curriculum storage key.
  final _contentCache = <String, List<ContentItem>>{};

  /// Cache of hierarchy configs, keyed by curriculum storage key.
  final _configCache = <String, CurriculumHierarchyConfig>{};

  /// Cache of pre-stripped Hebrew display names, keyed by curriculum storage
  /// key. Built once when content is first loaded and reused on every
  /// [search] call so nikud stripping is not recomputed per keystroke (T2.10).
  final _strippedHeCache = <String, List<String>>{};

  /// Cache of pre-rendered English leaf-segment names (lowercased), keyed by
  /// curriculum storage key. Built once alongside [_strippedHeCache] so the
  /// per-item renderer is not re-invoked on every keystroke.
  ///
  /// Uses the leaf-segment-only rendering (fullPath: false) so that ancestor
  /// path words (e.g. "Numbers" embedded in "Numbers 1:1") do not cause every
  /// descendant to match a search for the ancestor's name.
  final _leafEnCache = <String, List<String>>{};

  /// Cache of raw (un-rendered) English names (lowercased), keyed by
  /// curriculum storage key. This is [ContentItem.displayNameEn] as shipped
  /// in the bundled JSON — the Sephardic/standard spelling (e.g. "Berakhot")
  /// rather than [_leafEnCache]'s Ashkenazi-transliterated rendering (e.g.
  /// "Berakhos"). Searched alongside [_leafEnCache] so a query typed in
  /// either transliteration dialect resolves, regardless of which spelling
  /// the UI happens to display (AUD-t-content_browsing-02).
  final _rawEnCache = <String, List<String>>{};

  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async {
    final key = curriculumId.storageKey;

    if (_contentCache.containsKey(key)) {
      return _contentCache[key]!;
    }

    // Composite curricula: assemble from source asset(s) using strategy.
    final strategy = CompositeCurriculumStrategy.forKey(key);
    if (strategy != null) {
      final allItems = <ContentItem>[...strategy.preamble];
      for (final source in strategy.sources) {
        final sourceId = CurriculumId.values.firstWhere(
          (c) => c.storageKey == source,
        );
        final sourceItems = await getContentForCurriculum(sourceId);
        allItems.addAll(
          sourceItems.map(
            (item) => strategy.remap(
              item: item,
              source: source,
              offset: allItems.length,
            ),
          ),
        );
      }
      _contentCache[key] = allItems;

      _configCache[key] = CurriculumHierarchyConfig(
        curriculumId: key,
        levelLabels: CurriculumLabels.labelsEn(curriculumId),
        totalItems: allItems.where((i) => i.isLeaf).length,
      );

      return allItems;
    }

    try {
      final jsonString = await loadRawContentJson(key);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      _parseAndCache(key, json);
      return _contentCache[key]!;
    } on Exception catch (e) {
      // Typed so a bad-cast/logic-bug Error (TypeError, StateError) inside
      // _parseAndCache propagates raw instead of being folded into a
      // generic ContentLoadException that hides the real defect
      // (AUD-content_browsing-09, EH-4).
      throw ContentLoadException(
        'Failed to load content for ${curriculumId.displayNameEn}',
        cause: e,
      );
    }
  }

  /// Loads the raw JSON string for a leaf-source curriculum asset.
  ///
  /// Extracted as an overridable seam so [getContentForCurriculum] and
  /// [countLeavesForCurriculum] load through ONE identical path, and so tests
  /// (which have no asset bundle) can supply the on-disk JSON. Do not call
  /// from outside this class in production code.
  @visibleForTesting
  Future<String> loadRawContentJson(String key) =>
      rootBundle.loadString('assets/content/hierarchy/$key.json');

  /// Counts the leaf [ContentItem]s for [curriculumId] WITHOUT retaining the
  /// full materialized content list in [_contentCache].
  ///
  /// R8 (OOM): the header/denominator on the Lifetime Knowledge screen needs
  /// each curriculum's total leaf count, but routing that through
  /// [getContentForCurriculum] force-loads and PERMANENTLY caches every
  /// curriculum's full ~N-item hierarchy — ~70k ContentItems across all 9,
  /// which OOM-kills the process on a 512 MB heap. This method returns the
  /// same number without that cost: on the cold path it parses the asset JSON
  /// transiently and counts `isLeaf` flags (no ContentItem objects retained);
  /// on an already-warm curriculum it counts from the existing cache.
  ///
  /// INVARIANT (asserted by the equivalence test for every [CurriculumId]):
  ///   countLeavesForCurriculum(c)
  ///     == (await getContentForCurriculum(c)).where((i) => i.isLeaf).length
  ///
  /// NOTE: intentionally NOT on the [ContentRepository] interface yet —
  /// promoting it would force ~16 plain `implements ContentRepository` test
  /// doubles to implement it. It is added here (and consumed via the concrete
  /// type) pending the deferred Lifetime-header denominator rewiring; see the
  /// note in lifetime_knowledge_providers.dart.
  Future<int> countLeavesForCurriculum(CurriculumId curriculumId) async {
    final key = curriculumId.storageKey;

    // Already materialized → count from the cache (identical, no re-parse and
    // no new allocation).
    final cached = _contentCache[key];
    if (cached != null) {
      return cached.where((i) => i.isLeaf).length;
    }

    // Composite curricula: getContentForCurriculum prepends `strategy.preamble`
    // verbatim then appends each source's items via `remap`, which preserves
    // `isLeaf`. So the composite leaf count == (leaf rows in the preamble) +
    // (sum of each source's leaf count). Recursing through this method — rather
    // than getContentForCurriculum — keeps the transient, no-retain property.
    final strategy = CompositeCurriculumStrategy.forKey(key);
    if (strategy != null) {
      var total = strategy.preamble.where((i) => i.isLeaf).length;
      for (final source in strategy.sources) {
        final sourceId = CurriculumId.values.firstWhere(
          (c) => c.storageKey == source,
        );
        total += await countLeavesForCurriculum(sourceId);
      }
      return total;
    }

    // Leaf-source curriculum: parse the asset JSON transiently and count the
    // `isLeaf` flags directly off the raw maps — no ContentItem construction,
    // nothing written to _contentCache.
    try {
      final jsonString = await loadRawContentJson(key);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final itemsJson = json['items'] as List;
      var count = 0;
      for (final itemJson in itemsJson) {
        if ((itemJson as Map<String, dynamic>)['isLeaf'] as bool) count++;
      }
      return count;
    } on Exception catch (e) {
      // Mirror getContentForCurriculum's typed catch (AUD-content_browsing-09,
      // EH-4): a logic-bug Error propagates raw; only genuine load/parse
      // Exceptions fold into ContentLoadException.
      throw ContentLoadException(
        'Failed to count leaves for ${curriculumId.displayNameEn}',
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
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async {
    if (scopeValues.isEmpty) {
      return getContentForCurriculum(curriculumId);
    }

    final items = await getContentForCurriculum(curriculumId);
    final valueSet = scopeValues.toSet();

    return items.where((item) {
      final levelValue = switch (scopeLevel) {
        1 => item.level1,
        2 => item.level2,
        3 => item.level3,
        4 => item.level4,
        _ => null,
      };
      return levelValue != null && valueSet.contains(levelValue);
    }).toList();
  }

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) async {
    if (query.isEmpty) return [];

    final items = await getContentForCurriculum(curriculumId);
    final normalizedQuery = HebrewUtils.stripNikud(query.toLowerCase().trim());

    // Build the per-curriculum caches on first search so that subsequent
    // keystrokes never recompute per-item work (T2.10).
    final key = curriculumId.storageKey;
    if (!_strippedHeCache.containsKey(key)) {
      _strippedHeCache[key] = items
          .map(
            (item) => HebrewUtils.stripNikud(
              CurriculumLabelRenderer.hebrewNameOf(item) ?? '',
            ),
          )
          .toList();
    }
    if (!_leafEnCache.containsKey(key)) {
      // Use leaf-segment-only rendering so ancestor names embedded in the
      // full-path displayNameEn (e.g. "Numbers" in "Numbers 1:1") do not
      // cause every descendant to match a search for the ancestor's name.
      _leafEnCache[key] = items
          .map(
            (item) => CurriculumLabelRenderer.renderForItem(
              item,
              useHebrew: false,
            ).toLowerCase(),
          )
          .toList();
    }
    if (!_rawEnCache.containsKey(key)) {
      // Raw (un-transliterated) English name straight from the bundled
      // data, so a query in the Sephardic/standard spelling (e.g.
      // "Berakhot") still matches when the UI is rendering the Ashkenazi
      // spelling ("Berakhos") via _leafEnCache above.
      _rawEnCache[key] = items
          .map((item) => item.displayNameEn.toLowerCase())
          .toList();
    }
    final strippedHeNames = _strippedHeCache[key]!;
    final leafEnNames = _leafEnCache[key]!;
    final rawEnNames = _rawEnCache[key]!;

    final results = <ContentItem>[];
    for (var i = 0; i < items.length; i++) {
      if (strippedHeNames[i].contains(normalizedQuery) ||
          leafEnNames[i].contains(normalizedQuery) ||
          rawEnNames[i].contains(normalizedQuery)) {
        results.add(items[i]);
      }
    }
    return results;
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

  void _parseAndCache(String key, Map<String, dynamic> json) {
    final configJson = json['hierarchyConfig'] as Map<String, dynamic>;
    // Always use the central label source; the JSON's levelLabels field
    // is ignored so the in-app labels can never drift from CurriculumLabels.
    final curriculumId = CurriculumId.values.firstWhere(
      (c) => c.storageKey == key,
    );
    _configCache[key] = CurriculumHierarchyConfig(
      curriculumId: configJson['curriculumId'] as String,
      levelLabels: CurriculumLabels.labelsEn(curriculumId),
      totalItems: configJson['totalItems'] as int,
    );

    final itemsJson = json['items'] as List;
    _contentCache[key] = itemsJson.map((itemJson) {
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
  }
}

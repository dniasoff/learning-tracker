/// The real ContentIndex corpora for engine tests (DNI-494): the bundled
/// `assets/content/hierarchy/<curriculum>.json` built through the
/// production adapter, so fixture leaf counts come from ContentIndex, not
/// from hand-written trees. Cached per curriculum (the corpus is
/// immutable).
library;

import 'dart:convert';
import 'dart:io';

import 'package:learning_tracker/core/content/content_index_corpus.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';

final Map<String, Corpus> _cache = {};

/// The unscoped ContentIndex corpus of [curriculumId].
Corpus bundledCorpus(String curriculumId) =>
    _cache[curriculumId] ??= _load(curriculumId);

Corpus _load(String curriculumId) {
  final file = File('assets/content/hierarchy/$curriculumId.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final config = json['hierarchyConfig']! as Map<String, Object?>;
  final items = [
    for (final raw in json['items']! as List<Object?>)
      if (raw case final Map<String, Object?> m)
        ContentItem(
          curriculumId: m['curriculumId']! as String,
          level1: m['level1']! as String,
          level2: m['level2'] as String?,
          level3: m['level3'] as String?,
          level4: m['level4'] as String?,
          displayNameHe: m['displayNameHe']! as String,
          displayNameEn: m['displayNameEn']! as String,
          sefariaRef: m['sefariaRef']! as String,
          sortOrder: m['sortOrder']! as int,
          isLeaf: m['isLeaf']! as bool,
        ),
  ];
  return contentIndexCorpus(
    curriculumId: curriculumId,
    items: items,
    levelLabels: (config['levelLabels']! as List<Object?>).cast<String>(),
  );
}

/// Display names for ground-picker nodes and level units, from the
/// curriculum's ContentIndex and its level metadata — never Mishnayos
/// constants (`prd-deviations` #12, Story 2.7 / DNI-498 AC-2).
library;

import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

/// Resolves node names and level units for one curriculum.
final class GroundPickerLabels {
  /// Creates the resolver.
  GroundPickerLabels({
    required this.curriculum,
    required this.curriculumId,
    required this.index,
    required this.corpus,
    required this.useHebrew,
    required this.variant,
  });

  /// The curriculum, when the app knows it.
  final CurriculumId? curriculum;

  /// The curriculum's storage key.
  final String curriculumId;

  /// ContentIndex lookups.
  final ContentIndex index;

  /// The curriculum's tree.
  final Corpus corpus;

  /// The Hebrew Terms setting.
  final bool useHebrew;

  /// The transliteration nusach.
  final TransliterationVariant variant;

  final Map<NodeEntry, List<String>> _search = {};

  /// The ContentIndex row of [node] in this curriculum, if any.
  ContentItem? itemOf(NodeEntry node) {
    final item = index.lookup(node.ref);
    return item != null && item.curriculumId == curriculumId ? item : null;
  }

  /// The display name of [node] in the current language setting; its ref
  /// when ContentIndex has no row for it.
  String nameOf(NodeEntry node) {
    final item = itemOf(node);
    if (item == null) return node.ref;
    return CurriculumLabelRenderer.renderForItem(
      item,
      useHebrew: useHebrew,
      transliterationVariant: variant,
    );
  }

  /// Every searchable label of [node]: English and Hebrew names and its
  /// ref (cached).
  List<String> searchLabelsOf(NodeEntry node) => _search.putIfAbsent(node, () {
    final item = itemOf(node);
    if (item == null) return [node.ref];
    return [
      CurriculumLabelRenderer.renderForItem(
        item,
        useHebrew: false,
        transliterationVariant: variant,
      ),
      CurriculumLabelRenderer.renderForItem(item, useHebrew: true),
      node.ref,
    ];
  });

  /// The unit word of [sample]'s level, for [count] units: the level's
  /// ContentIndex label (matched by its level key, else by depth); the raw
  /// level key when the curriculum's levels do not name it.
  String unitOf(NodeEntry sample, int count) {
    final levels = curriculum == null
        ? const <LevelLabels>[]
        : CurriculumLabels.levels(curriculum!);
    var at = levels.indexWhere((l) => l.en.toLowerCase() == sample.level);
    if (at < 0) {
      final depth = _depthOf(sample);
      if (depth != null && depth <= levels.length) at = depth - 1;
    }
    if (at < 0) return sample.level;
    return levels[at].inLanguage(
      useHebrew: useHebrew,
      plural: count != 1,
      variant: variant,
    );
  }

  int? _depthOf(NodeEntry node) {
    if (corpus.leavesUnder(node).isEmpty) return null;
    var depth = 1;
    for (var p = corpus.parentOf(node); p != null; p = corpus.parentOf(p)) {
      depth++;
    }
    return depth;
  }
}

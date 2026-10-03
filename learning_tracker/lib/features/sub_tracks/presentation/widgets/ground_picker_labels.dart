/// Display names for ground-picker nodes and level units, from the
/// sub-track curriculum's own ContentIndex rows and its hierarchy level
/// metadata — never Mishnayos constants and never another curriculum's row
/// (`prd-deviations` #12, Story 2.7 / DNI-498 AC-2).
library;

import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ground_picker_content.dart';

/// Resolves node names and level units for one curriculum.
final class GroundPickerLabels {
  /// Creates the resolver.
  GroundPickerLabels({
    required this.content,
    required this.useHebrew,
    required this.variant,
  });

  /// The curriculum's ContentIndex rows and level metadata.
  final GroundPickerContent content;

  /// The Hebrew Terms setting.
  final bool useHebrew;

  /// The transliteration nusach.
  final TransliterationVariant variant;

  final Map<NodeEntry, List<String>> _search = {};

  /// The ContentIndex row of [node] in this curriculum, if any.
  ContentItem? itemOf(NodeEntry node) => content.itemOf(node);

  /// The display name of [node] in the current language setting; its ref
  /// when this curriculum's ContentIndex has no row for it.
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

  /// The unit word of [sample]'s level, for [count] units: the curriculum's
  /// hierarchy label for the node's depth (with its book's override). A
  /// node the level metadata does not name keeps its raw level key, so an
  /// unrecognised level never crashes the picker.
  String unitOf(NodeEntry sample, int count) {
    final level = content.levelOf(sample);
    if (level == null) return sample.level;
    return level.inLanguage(
      useHebrew: useHebrew,
      plural: count != 1,
      variant: variant,
    );
  }
}

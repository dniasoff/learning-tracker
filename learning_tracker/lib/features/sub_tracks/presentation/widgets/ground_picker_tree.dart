/// The ground picker's search / filter / tree composition (Story 2.7 /
/// DNI-498 AC-2, AC-3): the curriculum's ContentIndex tree at every level,
/// flattened in tree order, narrowed by the search and *Available only*,
/// with the exact empty copy when nothing is left.
library;

import 'package:flutter/material.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ground_selection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ground_picker_labels.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/ground_picker_row.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The tree of one picker.
class GroundPickerTree extends StatelessWidget {
  /// Creates the tree.
  const GroundPickerTree({
    super.key,
    required this.model,
    required this.draft,
    required this.labels,
    required this.trackName,
    required this.query,
    required this.availableOnly,
    required this.expanded,
    required this.onToggleSelected,
    required this.onToggleExpanded,
  });

  /// The picker model.
  final GroundPickerModel model;

  /// The pending draft.
  final GroundDraft draft;

  /// Name and unit resolution.
  final GroundPickerLabels labels;

  /// The receiving sub-track's name.
  final String trackName;

  /// The search text.
  final String query;

  /// *Available only*.
  final bool availableOnly;

  /// Expanded nodes.
  final Set<NodeEntry> expanded;

  /// Toggles a node's selection.
  final ValueChanged<NodeEntry> onToggleSelected;

  /// Expands or collapses a node.
  final ValueChanged<NodeEntry> onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final corpus = model.corpus;
    final searching = query.trim().isNotEmpty;
    final matches = searching
        ? nodesMatching(
            corpus,
            (n) => groundLabelMatches(query, labels.searchLabelsOf(n)),
          )
        : null;
    bool visible(NodeEntry node) =>
        (matches == null || matches.contains(node)) &&
        (!availableOnly || model.isAvailable(node));
    final rows = flattenGroundTree(
      corpus,
      expanded: expanded,
      visible: visible,
      expandAll: searching,
    );
    if (rows.isEmpty) {
      final String message;
      if (corpus.roots.isEmpty) {
        message = l10n.contentHierarchyNoContent;
      } else if (searching) {
        message = l10n.groundPickerNoMatches(query.trim());
      } else {
        message = l10n.groundPickerFilterEmpty;
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.colors.brandInkMuted,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final (:node, :depth) = rows[i];
        final children = corpus.childrenOf(node);
        final item = labels.itemOf(node);
        return GroundPickerRow(
          key: ValueKey(node),
          state: model.rowOf(node, draft),
          depth: depth,
          name: labels.nameOf(node),
          label: item == null ? null : CurriculumLabel.item(item),
          trackName: trackName,
          countText: children.isEmpty
              ? null
              : l10n.groundPickerUnitCount(
                  children.length,
                  labels.unitOf(children.first, children.length),
                ),
          expanded: children.isEmpty
              ? null
              : searching || expanded.contains(node),
          onToggleExpanded: searching ? null : () => onToggleExpanded(node),
          onToggleSelected: () => onToggleSelected(node),
        );
      },
    );
  }
}

/// The sub-track detail's "Ground (in order)" list (Story 2.6 / DNI-497,
/// AC-3, AC-4, AC-7).
library;

import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_detail.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_ground_projection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_ground_row.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The ground of [detail] in stored entry order, as the engine expands it.
///
/// Each stored entry is one tri-state row; a non-leaf row expands into its
/// ContentIndex children (indented 20dp per depth), a leaf's label opens
/// its history through [onOpenLeaf]. A groundless sub-track shows the
/// groundless state (UX-DR-122); *+ Add ground* is Story 2.7's.
class SubTrackGroundTree extends StatefulWidget {
  /// Creates the tree.
  const SubTrackGroundTree({
    super.key,
    required this.detail,
    required this.onOpenLeaf,
  });

  /// The detail to render.
  final SubTrackDetail detail;

  /// Opens the Mishna history of a leaf (Story 1.13).
  final ValueChanged<LeafRef> onOpenLeaf;

  @override
  State<SubTrackGroundTree> createState() => _SubTrackGroundTreeState();
}

class _SubTrackGroundTreeState extends State<SubTrackGroundTree> {
  /// Expanded rows by `depth:ref`.
  final Set<String> _expanded = {};

  static String _key(SubTrackGroundRow row) => '${row.depth}:${row.node.ref}';

  void _toggle(SubTrackGroundRow row) => setState(() {
    final key = _key(row);
    if (!_expanded.remove(key)) _expanded.add(key);
  });

  @override
  Widget build(BuildContext context) {
    final ground = widget.detail.ground;
    if (ground.isGroundless) return const _GroundlessState();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final entry in ground.entries) ..._block(ground, entry)],
    );
  }

  /// [row] and, when expanded, its descendants.
  List<Widget> _block(SubTrackGroundProjection ground, SubTrackGroundRow row) {
    final expanded = _expanded.contains(_key(row));
    return [
      SubTrackGroundRowTile(
        row: row,
        expanded: expanded,
        onToggle: () => _toggle(row),
        onOpenLeaf: () => widget.onOpenLeaf(row.node.ref),
      ),
      if (expanded)
        for (final child in ground.childrenOf(row)) ..._block(ground, child),
    ];
  }
}

/// The groundless state: the list is empty and says so.
class _GroundlessState extends StatelessWidget {
  const _GroundlessState();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      key: const ValueKey('subTrackGroundless'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 20),
      decoration: BoxDecoration(
        color: colors.brandCreamCard,
        border: Border.all(color: colors.brandOutline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.layers_clear_outlined, color: colors.brandInkMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.subTrackDetailGroundEmpty,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.brandInkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

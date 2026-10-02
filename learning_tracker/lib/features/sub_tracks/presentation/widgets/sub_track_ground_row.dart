/// One row of a sub-track's ground (Story 2.6 / DNI-497, AC-3, AC-8;
/// UX-DR-19, UX-DR-27, UX-DR-73, UX-DR-91, UX-DR-92, UX-DR-157;
/// DESIGN.md `ground-row`, `ground-tag-in-use`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_ground_projection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_detail_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Start indent per tree depth (UX-DR-19).
const double subTrackGroundIndentPerDepth = 20;

/// Opacity of the complete/partial state tint over the row (UX-DR-19).
const double subTrackGroundStateTint = 0.12;

/// The screen-reader announcement of a row's tri-state (UX-DR-157):
/// "complete", "partially learnt, {learnt} of {total}" or "not learnt".
String subTrackTriStateLabel(AppLocalizations l10n, SubTrackGroundRow row) =>
    switch (row.state) {
      TriState.complete => l10n.subTrackDetailTriComplete,
      TriState.partial => l10n.subTrackDetailTriPartial(row.learnt, row.total),
      TriState.empty => l10n.subTrackDetailTriEmpty,
    };

/// A tri-state ground row: state box, label, "{learnt} of {total} learnt",
/// the learnt-at source, "In use" tags and a direction-aware chevron.
///
/// Tapping a leaf's label calls [onOpenLeaf] (Mishna history); tapping a
/// non-leaf's label calls [onToggle] (expand / collapse). [leading] (drag
/// handle) and [trailing] (⋮ menu) are the parent's edit controls; the
/// read-only child and tutor pass neither.
class SubTrackGroundRowTile extends ConsumerWidget {
  /// Creates the row.
  const SubTrackGroundRowTile({
    super.key,
    required this.row,
    required this.expanded,
    this.onToggle,
    this.onOpenLeaf,
    this.leading,
    this.trailing,
  });

  /// The projected row.
  final SubTrackGroundRow row;

  /// Whether a non-leaf row shows its children.
  final bool expanded;

  /// Expands or collapses a non-leaf row.
  final VoidCallback? onToggle;

  /// Opens a leaf's history.
  final VoidCallback? onOpenLeaf;

  /// The drag handle, for the parent.
  final Widget? leading;

  /// The ⋮ menu, for the parent.
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final ref0 = row.node.ref;
    final label = row.depth == 0
        ? ref.watch(subTrackRefLabelProvider(ref0))
        : ref.watch(subTrackNodeNameProvider(ref0));
    final tinted = row.state != TriState.empty;
    final background = tinted
        ? Color.alphaBlend(
            colors.brandBlue.withValues(alpha: subTrackGroundStateTint),
            colors.brandCreamCard,
          )
        : colors.brandCreamCard;
    final details = <String>[
      l10n.subTrackDetailLearntOf(row.learnt, row.total),
      if (row.learntAt case final at?)
        at.isHome
            ? l10n.subTrackDetailLearntAtHome
            : l10n.subTrackDetailLearntAt(at.subTrackName!),
    ];
    final tap = row.isLeaf ? onOpenLeaf : (row.expandable ? onToggle : null);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.titleSmall?.copyWith(color: colors.brandInk)),
        const SizedBox(height: 2),
        Text(
          details.join(' • '),
          style: text.bodySmall?.copyWith(color: colors.brandInkMuted),
        ),
        if (row.inUseBy.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final name in row.inUseBy)
                Container(
                  key: ValueKey('subTrackInUse:${row.node.ref}:$name'),
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 2, 8, 2),
                  decoration: BoxDecoration(
                    color: colors.brandCreamSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.subTrackDetailInUse(name),
                    style: text.labelSmall?.copyWith(
                      color: colors.brandInkMuted,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );

    return Container(
      key: ValueKey('subTrackGroundRow:${row.depth}:${row.node.ref}'),
      margin: const EdgeInsetsDirectional.only(bottom: 8),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: colors.brandOutline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        key: ValueKey('subTrackGroundIndent:${row.depth}:${row.node.ref}'),
        padding: EdgeInsetsDirectional.only(
          start: subTrackGroundIndentPerDepth * row.depth,
        ),
        child: Row(
          children: [
            ?leading,
            if (leading == null) const SizedBox(width: 12),
            _TriStateBox(row: row, label: subTrackTriStateLabel(l10n, row)),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                button: tap != null,
                expanded: row.expandable ? expanded : null,
                hint: row.isLeaf ? l10n.subTrackDetailOpenHistory : null,
                child: InkWell(
                  key: ValueKey('subTrackGroundLabel:${row.node.ref}'),
                  onTap: tap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: body,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (tap != null)
              ExcludeSemantics(
                child: AnimatedRotation(
                  turns: row.isLeaf || !expanded ? 0 : 0.25,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    Icons.chevron_right,
                    key: ValueKey('subTrackGroundChevron:${row.node.ref}'),
                    color: colors.brandInkMuted,
                  ),
                ),
              ),
            ?trailing,
            if (trailing == null) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// The tri-state box: filled with a check (complete), filled with a dash
/// (partial) or outlined (empty). It announces its state (UX-DR-157).
class _TriStateBox extends StatelessWidget {
  const _TriStateBox({required this.row, required this.label});

  final SubTrackGroundRow row;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filled = row.state != TriState.empty;
    return Semantics(
      key: ValueKey('subTrackTriState:${row.node.ref}'),
      container: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: filled ? colors.brandBlue : null,
          border: Border.all(
            color: filled ? colors.brandBlue : colors.brandOutline,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        // The mark reads brand-cream-card on brand-blue in both themes
        // (brand-blue lightens in dark, the card darkens).
        child: switch (row.state) {
          TriState.complete => Icon(
            Icons.check,
            size: 16,
            color: colors.brandCreamCard,
          ),
          TriState.partial => Icon(
            Icons.remove,
            size: 16,
            color: colors.brandCreamCard,
          ),
          TriState.empty => null,
        },
      ),
    );
  }
}

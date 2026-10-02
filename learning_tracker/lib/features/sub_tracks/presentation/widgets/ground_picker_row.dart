/// One ground-picker tree row (Story 2.7 / DNI-498 AC-2, AC-3, AC-9).
///
/// Two independent indicators, never one checkbox encoding both: a
/// learnt-progress mark (complete / partial / empty, FR-15, with a text
/// count and spoken state, never colour alone) and the assignment
/// selection checkbox (checked / mixed / unchecked). Tags name another
/// holding sub-track ("{name} · In use"), learnt ground ("Chazara") and
/// ground already in this sub-track (pre-checked and disabled).
library;

import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart'
    show TriState;
import 'package:learning_tracker/features/sub_tracks/domain/ground_selection.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The start indent per tree depth (`{spacing.tree-indent}`).
const double groundPickerTreeIndent = 20;

/// A ground-picker row.
class GroundPickerRow extends StatelessWidget {
  /// Creates a row.
  const GroundPickerRow({
    super.key,
    required this.state,
    required this.depth,
    required this.name,
    required this.trackName,
    required this.onToggleSelected,
    this.label,
    this.countText,
    this.expanded,
    this.onToggleExpanded,
  });

  /// The derived row state.
  final GroundRowState state;

  /// Tree depth (0 for a root).
  final int depth;

  /// The node's display name (also spoken).
  final String name;

  /// The name widget, when richer than [name] (e.g. a curriculum label).
  final Widget? label;

  /// The receiving sub-track's name.
  final String trackName;

  /// The row's count in the curriculum's own unit, e.g. "9 Perakim".
  final String? countText;

  /// Expanded, collapsed, or null for a leaf.
  final bool? expanded;

  /// Expands or collapses the row.
  final VoidCallback? onToggleExpanded;

  /// Toggles the row's selection.
  final VoidCallback onToggleSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final progress = switch (state.progress) {
      TriState.complete => l10n.groundPickerProgressComplete,
      TriState.partial => l10n.groundPickerProgressPartial,
      TriState.empty => l10n.groundPickerProgressEmpty,
    };
    final selection = state.inThisTrack
        ? l10n.groundPickerAlreadyIn(trackName)
        : switch (state.mark) {
            GroundSelectionMark.checked => l10n.groundPickerSelected,
            GroundSelectionMark.partial => l10n.groundPickerPartlySelected,
            GroundSelectionMark.unchecked => l10n.groundPickerNotSelected,
          };
    final tags = <Widget>[
      if (state.inThisTrack)
        GroundPickerTag(
          text: l10n.groundPickerAlreadyIn(trackName),
          fill: colors.brandOutlineMuted,
          ink: colors.brandInkMuted,
        ),
      for (final holder in state.inUseBy)
        GroundPickerTag(
          text: l10n.groundPickerInUse(holder),
          fill: colors.brandBlueSoft,
          ink: colors.brandInk,
        ),
      if (state.isChazara)
        GroundPickerTag(
          text: l10n.groundPickerChazara,
          fill: colors.statusSuccessMuted,
          ink: colors.brandInk,
        ),
    ];
    final enabled = state.enabled;
    return Semantics(
      container: true,
      label: [name, ?countText, progress].join(', '),
      child: InkWell(
        onTap: enabled ? onToggleSelected : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: 8 + depth * groundPickerTreeIndent,
              end: 4,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: expanded == null
                      ? null
                      : IconButton(
                          tooltip: expanded!
                              ? l10n.groundPickerCollapse(name)
                              : l10n.groundPickerExpand(name),
                          onPressed: onToggleExpanded,
                          icon: Icon(
                            expanded! ? Icons.expand_more : Icons.chevron_right,
                          ),
                        ),
                ),
                GroundProgressMark(state: state.progress),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DefaultTextStyle.merge(
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: enabled ? null : colors.brandInkMuted,
                          ),
                          child: ExcludeSemantics(child: label ?? Text(name)),
                        ),
                        if (countText != null)
                          ExcludeSemantics(
                            child: Text(
                              countText!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.brandInkMuted,
                              ),
                            ),
                          ),
                        if (tags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: tags,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Checkbox(
                  tristate: true,
                  value: switch (state.mark) {
                    GroundSelectionMark.checked => true,
                    GroundSelectionMark.partial => null,
                    GroundSelectionMark.unchecked => false,
                  },
                  semanticLabel: selection,
                  onChanged: enabled ? (_) => onToggleSelected() : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The learnt-progress mark of a row or the legend: green check for
/// complete, amber dash for partial, muted ring for empty. Decorative: the
/// row speaks the state in words.
class GroundProgressMark extends StatelessWidget {
  /// Creates the mark.
  const GroundProgressMark({super.key, required this.state});

  /// The tri-state.
  final TriState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (IconData icon, Color color) = switch (state) {
      TriState.complete => (Icons.check_circle, colors.statusSuccess),
      TriState.partial => (Icons.remove_circle, colors.statusWarning),
      TriState.empty => (Icons.radio_button_unchecked, colors.brandOutline),
    };
    return ExcludeSemantics(child: Icon(icon, size: 20, color: color));
  }
}

/// A small rounded tag (`{rounded.tag}`).
class GroundPickerTag extends StatelessWidget {
  /// Creates a tag.
  const GroundPickerTag({
    super.key,
    required this.text,
    required this.fill,
    required this.ink,
  });

  /// The tag text.
  final String text;

  /// Its fill.
  final Color fill;

  /// Its text colour.
  final Color ink;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

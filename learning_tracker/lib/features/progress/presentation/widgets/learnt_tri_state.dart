/// The FR-15 tri-state of a corpus node (UX-DR-19 / UX-DR-157): a
/// read-only tristate checkbox (checked / dash / empty), a decorative 12%
/// row tint, a count ("3/12") and a semantics label carrying the state as
/// text ("Berakhot, partial, 3 of 12 learnt"). Colour is never the only
/// state cue.
///
/// The state itself comes from the engine (DNI-474); these widgets only
/// render it.
library;

import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The decorative row-tint alpha (DESIGN.md: tints are 12%).
const double learntTriStateTintAlpha = 0.12;

/// The state word of [state] for semantics.
String learntTriStateWord(AppLocalizations l10n, TriState state) =>
    switch (state) {
      TriState.complete => l10n.learnerProgressStateComplete,
      TriState.partial => l10n.learnerProgressStatePartial,
      TriState.empty => l10n.learnerProgressStateEmpty,
    };

/// The screen-reader label of a node: "{name}, {state}, {learnt} of
/// {total} learnt".
String learntTriStateSemantics(
  AppLocalizations l10n, {
  required String name,
  required TriState state,
  required int learnt,
  required int total,
}) => l10n.learnerProgressNodeSemantics(
  name,
  learntTriStateWord(l10n, state),
  learnt,
  total,
);

/// The state colour of [state]: complete green, partial amber, empty
/// neutral (DESIGN.md § Colors, Tri-state).
Color learntTriStateColor(BuildContext context, TriState state) =>
    switch (state) {
      TriState.complete => context.colors.statusSuccessMuted,
      TriState.partial => context.colors.progressLifetimePartial,
      TriState.empty => context.colors.progressLifetimeNoneOnLight,
    };

/// The tri-state derived from a learnt / total count (a node with no leaf
/// is empty).
TriState triStateFromCounts(int learnt, int total) {
  if (learnt <= 0 || total <= 0) return TriState.empty;
  return learnt >= total ? TriState.complete : TriState.partial;
}

/// A read-only tristate checkbox: checked when complete, a dash when
/// partial, empty otherwise. Excluded from semantics: the row's label
/// carries the state.
class LearntTriStateBox extends StatelessWidget {
  /// Creates the box.
  const LearntTriStateBox({required this.state, this.size = 20, super.key});

  /// The node state.
  final TriState state;

  /// The icon size.
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (state) {
      TriState.complete => (
        Icons.check_box_rounded,
        context.colors.statusSuccessMuted,
      ),
      TriState.partial => (
        Icons.indeterminate_check_box_rounded,
        context.colors.tristatePartialAccent,
      ),
      TriState.empty => (
        Icons.check_box_outline_blank_rounded,
        context.colors.brandInkSoft,
      ),
    };
    return ExcludeSemantics(
      child: Icon(
        icon,
        key: ValueKey('learnt-tri-state-${state.name}'),
        size: size,
        color: color,
      ),
    );
  }
}

/// A count label ("3/12"), excluded from semantics (the row label reads
/// "3 of 12 learnt").
class LearntCountLabel extends StatelessWidget {
  /// Creates the label.
  const LearntCountLabel({
    required this.learnt,
    required this.total,
    this.style,
    super.key,
  });

  /// Learnt leaves.
  final int learnt;

  /// All leaves.
  final int total;

  /// Text style.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ExcludeSemantics(
      child: Text(l10n.learnerProgressCountShort(learnt, total), style: style),
    );
  }
}

/// One sub-track row under today's tasks on the Learn tab (Story 2.9,
/// DNI-500; DESIGN.md `subtrack-row`, UX-DR-16/17/53/88).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_home_projection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_session.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_read_only.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The rendered position for a leaf ref: the ContentIndex display with its
/// leading seder segment dropped (the same rule the main-track task card
/// uses), falling back to the raw ref while the label loads.
String subTrackPositionLabel(WidgetRef ref, String leafRef) {
  final rendered =
      ref.watch(renderedDisplayForRefProvider(leafRef)).asData?.value ??
      leafRef.replaceAll('_', ' ');
  const separator = ' › ';
  final cut = rendered.indexOf(separator);
  return cut == -1 ? rendered : rendered.substring(cut + separator.length);
}

/// An outlined row: name, "Next: {position}" (or the groundless /
/// all-recorded line) and exactly *Up to…* and *+1* — or, for a parent on a
/// groundless or fully recorded track, *Add ground*. No source, rate or pace
/// badge (UX-DR-16). The body opens the detail (AC-7); each action keeps its
/// own handler.
///
/// Role gating (AC-3, AC-4, AC-9):
/// * child — groundless / all recorded: *Up to…* and *+1* disabled;
/// * parent — groundless / all recorded: *Add ground* only;
/// * tutor — every write control visible and disabled; groundless shows a
///   disabled *Add ground*, all recorded a disabled *Up to…* / *+1*.
class SubTrackHomeRow extends ConsumerWidget {
  /// Creates the row for [item] as seen by [role].
  const SubTrackHomeRow({
    super.key,
    required this.item,
    required this.role,
    required this.onOpen,
    this.onPlusOne,
    this.onUpTo,
    this.onAddGround,
    this.capturing = false,
  });

  /// The engine projection of the track.
  final SubTrackHomeItem item;

  /// The viewer.
  final SubTrackViewerRole role;

  /// Body tap: opens the detail.
  final VoidCallback onOpen;

  /// *+1* (owner, active row).
  final VoidCallback? onPlusOne;

  /// *Up to…* (owner, active row).
  final VoidCallback? onUpTo;

  /// *Add ground* (parent, groundless or all recorded).
  final VoidCallback? onAddGround;

  /// A *+1* for this row is in flight: *+1* is held disabled so a rapid
  /// second tap cannot record the same leaf twice.
  final bool capturing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final position = item.position;
    final positionText = position == null
        ? null
        : subTrackPositionLabel(ref, position);

    final (String line, String rowLabel) = switch (item.kind) {
      SubTrackRowKind.active => (
        l10n.subTrackHomeNext(positionText!),
        l10n.subTrackHomeRowSemantics(item.name, positionText),
      ),
      SubTrackRowKind.groundless => (
        l10n.subTrackHomeNoGround,
        l10n.subTrackHomeRowNoGroundSemantics(item.name),
      ),
      SubTrackRowKind.allRecorded => (
        l10n.subTrackHomeAllRecorded,
        l10n.subTrackHomeRowAllRecordedSemantics(item.name),
      ),
    };

    final text = Semantics(
      label: rowLabel,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.name,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.brandInk,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              line,
              key: Key('subTrackHomeRowLine-${item.subTrackId}'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.brandInkMuted,
              ),
            ),
          ],
        ),
      ),
    );

    final actions = Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: _actions(context, l10n),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('subTrackHomeRow-${item.subTrackId}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Ink(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
          decoration: BoxDecoration(
            color: colors.brandCreamCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.brandOutline),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // AC-10: at large text or on a narrow row, name and position
              // stack above the actions instead of being squeezed.
              final stacked =
                  MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
                  constraints.maxWidth < 280;
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    text,
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: actions,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: text),
                  const SizedBox(width: 8),
                  actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, AppLocalizations l10n) {
    final isTutor = role == SubTrackViewerRole.tutor;
    final showAddGround = switch (item.kind) {
      SubTrackRowKind.active => false,
      SubTrackRowKind.groundless => role != SubTrackViewerRole.child,
      SubTrackRowKind.allRecorded => role == SubTrackViewerRole.parent,
    };
    if (showAddGround) {
      return [
        _AddGroundButton(
          key: Key('subTrackHomeAddGround-${item.subTrackId}'),
          label: l10n.subTrackHomeAddGround,
          onPressed: isTutor ? null : onAddGround,
        ),
      ];
    }
    final canCapture = item.canCapture && !isTutor;
    return [
      _UpToButton(
        key: Key('subTrackHomeUpTo-${item.subTrackId}'),
        label: l10n.subTrackHomeUpTo,
        semanticsLabel: l10n.subTrackHomeUpToSemantics(item.name),
        onPressed: canCapture ? onUpTo : null,
      ),
      _PlusOneButton(
        key: Key('subTrackHomePlusOne-${item.subTrackId}'),
        label: l10n.subTrackHomePlusOne,
        semanticsLabel: l10n.subTrackHomePlusOneSemantics(
          item.curriculumId,
          item.name,
        ),
        // A +1 in flight keeps its full look and swallows further taps (it
        // is busy, not a `Disabled action`), so a rapid second tap neither
        // records the same leaf again nor falls through to the row body.
        onPressed: canCapture ? (capturing ? _ignoreTap : onPlusOne) : null,
      ),
    ];
  }
}

void _ignoreTap() {}

/// Minimum touch target (DESIGN.md `spacing.touch-target`).
const Size _touchTarget = Size(48, 48);

class _UpToButton extends StatelessWidget {
  const _UpToButton({
    super.key,
    required this.label,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final String label;
  final String semanticsLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: _touchTarget,
        foregroundColor: colors.brandBlue,
        disabledForegroundColor: colors.brandInkMuted,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Semantics(
        label: semanticsLabel,
        child: ExcludeSemantics(child: Text(label)),
      ),
    );
    return onPressed == null ? SubTrackDisabledAction(child: button) : button;
  }
}

class _PlusOneButton extends StatelessWidget {
  const _PlusOneButton({
    super.key,
    required this.label,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final String label;
  final String semanticsLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final button = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: _touchTarget,
        shape: const StadiumBorder(),
        backgroundColor: colors.brandBlue,
        foregroundColor: colors.introCtaLabel,
        disabledBackgroundColor: colors.brandBlue,
        disabledForegroundColor: colors.introCtaLabel,
        padding: const EdgeInsets.symmetric(horizontal: 18),
      ),
      child: Semantics(
        label: semanticsLabel,
        // "+1" is a number: keep it LTR so an RTL row never shows "1+".
        child: ExcludeSemantics(
          child: Text(label, textDirection: TextDirection.ltr),
        ),
      ),
    );
    return onPressed == null ? SubTrackDisabledAction(child: button) : button;
  }
}

class _AddGroundButton extends StatelessWidget {
  const _AddGroundButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: _touchTarget,
        shape: const StadiumBorder(),
        foregroundColor: colors.brandBlue,
        disabledForegroundColor: colors.brandInkMuted,
        side: BorderSide(color: colors.brandOutline),
      ),
      child: Text(label),
    );
    return onPressed == null ? SubTrackDisabledAction(child: button) : button;
  }
}

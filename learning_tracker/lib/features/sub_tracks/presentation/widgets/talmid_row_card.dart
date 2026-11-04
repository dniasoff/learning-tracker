/// One My talmidim row (Story 4.3, DNI-511, T3; DESIGN.md "Talmid row",
/// UX-DR-24, UX-DR-39, UX-DR-83, UX-DR-156, UX-DR-157).
///
/// An outlined card: initials avatar, name, status chip, the detail line
/// ("Rebbe: next Beitzah 3:1" or "Rebbe: no ground yet" with *Add ground*)
/// and a chevron. Status is text and an icon on a theme status role, never
/// colour alone. A locked or not-yet-judged learner shows nothing of
/// himself: only "Shabbos / Yom Tov" (or a neutral placeholder), with no
/// action, and a tap does nothing (AC-4).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/sub_tracks/domain/models/talmid_row_state.dart';
import 'package:learning_tracker/features/sub_tracks/domain/repositories/tutor_roster_repository.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_home_row.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart'
    show TutorDisabledControl;
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The learner's display name, or the localized fallback (never an id).
String talmidName(AppLocalizations l10n, TalmidRosterEntry entry) =>
    entry.displayName ?? l10n.talmidimUnnamed;

/// Up to two initials of [name].
String talmidInitials(String name) {
  final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '';
  final first = words.first.characters.first;
  if (words.length == 1) return first.toUpperCase();
  return '$first${words[1].characters.first}'.toUpperCase();
}

/// The status chip label of [status].
String talmidStatusLabel(AppLocalizations l10n, TalmidStatus status) =>
    switch (status) {
      TalmidStatus.onTrack => l10n.onTrackOnTrack,
      TalmidStatus.behindPace => l10n.onTrackBehindPace,
      TalmidStatus.tooEarly => l10n.onTrackTooEarly,
    };

/// The detail line of [line], with positions rendered for the locale.
String talmidLineText(
  WidgetRef ref,
  AppLocalizations l10n,
  TalmidTrackLine line,
) => switch (line) {
  TalmidTrackNext(:final name, :final position) => l10n.talmidimTrackNext(
    name,
    subTrackPositionLabel(ref, position),
  ),
  TalmidTrackNoGround(:final name) => l10n.talmidimTrackNoGround(name),
  TalmidTrackAllRecorded(:final name) => l10n.talmidimTrackAllRecorded(name),
  TalmidMainTrackNext(:final position) => l10n.subTrackHomeNext(
    subTrackPositionLabel(ref, position),
  ),
};

/// The `status-chip-*` pill (DESIGN.md): the on-track card's three
/// treatments, as text with an icon.
class TalmidStatusChip extends StatelessWidget {
  /// Creates the chip.
  const TalmidStatusChip({super.key, required this.status});

  /// The status shown.
  final TalmidStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final (
      IconData icon,
      Color foreground,
      Color background,
    ) = switch (status) {
      TalmidStatus.onTrack => (
        Icons.check_circle_rounded,
        colors.statusSuccessSoftText,
        colors.statusSuccessSoftBg,
      ),
      TalmidStatus.behindPace => (
        Icons.warning_amber_rounded,
        colors.brandWarningDeep,
        colors.brandWarningSoft,
      ),
      TalmidStatus.tooEarly => (
        Icons.hourglass_empty_rounded,
        colors.brandInkMuted,
        colors.brandCreamSoft,
      ),
    };
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 3, 10, 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              talmidStatusLabel(l10n, status),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The outlined talmid row.
class TalmidRowCard extends ConsumerWidget {
  /// Creates the row for [entry] in [row].
  const TalmidRowCard({
    super.key,
    required this.entry,
    required this.row,
    this.selected = false,
    this.addGroundEnabled = false,
    this.onOpen,
    this.onAddGround,
    this.onRetry,
  });

  /// The roster entry (identity, permissions).
  final TalmidRosterEntry entry;

  /// The row's engine projection.
  final TalmidRowState row;

  /// Whether the row is the tablet pane's selection.
  final bool selected;

  /// Whether *Add ground* may be used now: the grant's `can_edit_learning`
  /// and a positive connectivity probe (AC-3).
  final bool addGroundEnabled;

  /// Tap on the row body; ignored unless the row may open its learner.
  final VoidCallback? onOpen;

  /// *Add ground* on a groundless row.
  final VoidCallback? onAddGround;

  /// Inline retry of a timed-out or failed row.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final theme = Theme.of(context);

    if (!row.identityVisible && row is! TalmidRowTimedOut) {
      return _RedactedRow(locked: row is TalmidRowLocked);
    }

    final name = talmidName(l10n, entry);
    final identity = row.identityVisible;
    final status = row is TalmidRowReady
        ? (row as TalmidRowReady).status
        : null;
    final line = row is TalmidRowReady ? (row as TalmidRowReady).line : null;
    final lineText = line == null ? null : talmidLineText(ref, l10n, line);
    final groundless = line is TalmidTrackNoGround;
    final retry = switch (row) {
      TalmidRowTimedOut() => true,
      TalmidRowFailed(:final retryable) => retryable,
      _ => false,
    };
    final failedText = switch (row) {
      TalmidRowTimedOut() || TalmidRowFailed() => l10n.talmidimRowLoadFailed,
      _ => null,
    };
    final opens = row.opensLearner && onOpen != null;

    final label = [
      if (identity) name,
      if (status != null) talmidStatusLabel(l10n, status),
      ?lineText,
      if (row is TalmidRowLoading) l10n.onTrackLoading,
      ?failedText,
    ].join(', ');

    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(text: identity ? talmidInitials(name) : null),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (identity)
                    Text(
                      name,
                      key: Key('talmidRowName-${entry.grantId}'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.brandInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (status != null)
                    TalmidStatusChip(
                      key: Key('talmidStatusChip-${entry.grantId}'),
                      status: status,
                    ),
                ],
              ),
              if (lineText != null) ...[
                const SizedBox(height: 4),
                Text(
                  lineText,
                  key: Key('talmidRowLine-${entry.grantId}'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.brandInkMuted,
                  ),
                ),
              ],
              if (row is TalmidRowLoading) ...[
                const SizedBox(height: 8),
                Container(
                  key: Key('talmidRowLoading-${entry.grantId}'),
                  height: 12,
                  width: 140,
                  decoration: BoxDecoration(
                    color: colors.brandOutlineMuted,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
              if (failedText != null) ...[
                const SizedBox(height: 4),
                Text(
                  failedText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.brandInkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (opens)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, top: 8),
            child: Icon(
              Icons.chevron_right_rounded,
              color: colors.brandInkMuted,
              textDirection: Directionality.of(context),
            ),
          ),
      ],
    );

    final actions = <Widget>[
      if (groundless)
        TutorDisabledControl(
          blocked: !addGroundEnabled,
          child: TextButton.icon(
            key: Key('talmidAddGround-${entry.grantId}'),
            onPressed: addGroundEnabled ? onAddGround : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.subTrackHomeAddGround),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          ),
        ),
      if (retry && onRetry != null)
        TextButton.icon(
          key: Key('talmidRowRetry-${entry.grantId}'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(l10n.actionRetry),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
    ];

    return Material(
      key: Key('talmidRow-${entry.grantId}'),
      color: selected ? colors.brandBlueSoft : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? colors.brandBlue : colors.brandOutline,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            button: opens,
            selected: selected,
            label: label,
            excludeSemantics: true,
            child: InkWell(
              onTap: opens ? onOpen : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
                  child: body,
                ),
              ),
            ),
          ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(60, 0, 8, 6),
              child: Wrap(spacing: 4, children: actions),
            ),
        ],
      ),
    );
  }
}

/// A row that shows nothing of its learner: "Shabbos / Yom Tov" while he is
/// locked, a neutral placeholder while his lock is not yet known. Inert.
class _RedactedRow extends StatelessWidget {
  const _RedactedRow({required this.locked});

  final bool locked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final theme = Theme.of(context);
    final text = locked ? l10n.talmidimLocked : l10n.onTrackLoading;
    return Semantics(
      container: true,
      label: text,
      excludeSemantics: true,
      child: Material(
        key: Key(locked ? 'talmidRowLocked' : 'talmidRowPending'),
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.brandOutline),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
            child: Row(
              children: [
                _Avatar(icon: locked ? Icons.nights_stay_outlined : null),
                const SizedBox(width: 12),
                if (locked)
                  Expanded(
                    child: Text(
                      text,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.brandInkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Container(
                    height: 12,
                    width: 120,
                    decoration: BoxDecoration(
                      color: colors.brandOutlineMuted,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.text, this.icon});

  final String? text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CircleAvatar(
      radius: 20,
      backgroundColor: colors.brandBlueSoft,
      child: text != null && text!.isNotEmpty
          ? Text(
              text!,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.brandBlueDeep,
                fontWeight: FontWeight.w700,
              ),
            )
          : icon != null
          ? Icon(icon, size: 20, color: colors.brandBlueDeep)
          : null,
    );
  }
}

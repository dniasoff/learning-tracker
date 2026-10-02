/// The sub-track detail's "Capacity vs Path" bar (Story 2.6 / DNI-497,
/// AC-2; UX-DR-26, UX-DR-97; DESIGN.md `capacity-bar`).
library;

import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_detail.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The `progress-bar-height` token: the capacity bar is 6dp tall.
const double subTrackCapacityBarHeight = 6;

/// Renders the engine's Story 2.3 capacity values for [detail].
///
/// * With a deadline: "Capacity vs Path", "{remaining path} / {capacity}",
///   a 6dp bar and "Remaining path: {p} · Total capacity: {c}". A zero
///   shortfall shows the "No shortfall" success tag; a positive shortfall
///   shows its count in a warning tag to the parent (and tutor) only. The
///   child sees the bar and caption with no tag or count (NFR-9).
/// * Without a deadline (engine capacity null, AD-44): no bar. The parent
///   sees the Story 2.4 no-deadline note; its link calls
///   [onSetDeadline], and is left out while that is null.
///
/// The bar's fill is display only (`path / capacity`, clamped); every
/// number shown is the engine's.
class SubTrackCapacityBar extends StatelessWidget {
  /// Creates the bar.
  const SubTrackCapacityBar({
    super.key,
    required this.detail,
    this.onSetDeadline,
  });

  /// The detail whose engine values render.
  final SubTrackDetail detail;

  /// Opens the curriculum's goal setup from the no-deadline note.
  final VoidCallback? onSetDeadline;

  @override
  Widget build(BuildContext context) {
    final capacity = detail.capacity;
    if (capacity == null) {
      if (detail.role != SubTrackDetailRole.parent) {
        return const SizedBox.shrink();
      }
      return _NoDeadlineNote(onSetDeadline: onSetDeadline);
    }
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final path = detail.remainingPath;
    final fill = capacity <= 0 ? 1.0 : (path / capacity).clamp(0.0, 1.0);
    final caption = l10n.subTrackDetailCapacityCaption(path, capacity);
    return Container(
      key: const ValueKey('subTrackCapacityBar'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.brandCreamCard,
        border: Border.all(color: colors.brandOutline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.speed, size: 20, color: colors.brandBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.subTrackDetailCapacityTitle,
                  style: text.titleSmall?.copyWith(color: colors.brandInk),
                ),
              ),
              Text(
                l10n.subTrackDetailCapacityValue(path, capacity),
                style: text.titleSmall?.copyWith(
                  color: colors.brandInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            label: caption,
            child: ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  key: const ValueKey('subTrackCapacityBarTrack'),
                  height: subTrackCapacityBarHeight,
                  child: LinearProgressIndicator(
                    value: fill,
                    minHeight: subTrackCapacityBarHeight,
                    color: colors.brandBlue,
                    backgroundColor: colors.brandCreamSoft,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: Text(
              caption,
              style: text.bodySmall?.copyWith(color: colors.brandInkMuted),
            ),
          ),
          if (_tag(context, l10n) case final tag?) ...[
            const SizedBox(height: 10),
            Align(alignment: AlignmentDirectional.centerStart, child: tag),
          ],
        ],
      ),
    );
  }

  /// The status tag: success at zero shortfall; the parent/tutor-only
  /// warning count above zero; nothing for the child then.
  Widget? _tag(BuildContext context, AppLocalizations l10n) {
    final colors = context.colors;
    if (detail.shortfall <= 0) {
      return _StatusTag(
        key: const ValueKey('subTrackNoShortfallTag'),
        icon: Icons.check,
        label: l10n.subTrackDetailNoShortfall,
        background: colors.statusSuccessSoftBg,
        foreground: colors.statusSuccessSoftText,
      );
    }
    if (!detail.showsShortfall) return null;
    return _StatusTag(
      key: const ValueKey('subTrackShortfallTag'),
      icon: Icons.warning_amber_rounded,
      label: l10n.subTrackDetailShortfall(detail.shortfall),
      background: colors.statusWarningSoft,
      foreground: colors.statusWarningSoftText,
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({
    super.key,
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The Story 2.4 no-deadline note, drawn as the DESIGN.md `info-note`
/// (info icon and one sentence on `brand-blue-soft`, 12dp radius). The
/// shared `InfoNote` widget arrives with DNI-495; this stays local until
/// then (follow-up bead).
class _NoDeadlineNote extends StatelessWidget {
  const _NoDeadlineNote({required this.onSetDeadline});

  final VoidCallback? onSetDeadline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final onTap = onSetDeadline;
    return Container(
      key: const ValueKey('subTrackNoDeadlineNote'),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: colors.brandBlueSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: colors.brandBlueDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.subTrackDetailNoDeadlineNote,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.brandInk),
                ),
                if (onTap != null)
                  TextButton(
                    key: const ValueKey('subTrackNoDeadlineLink'),
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: EdgeInsetsDirectional.zero,
                    ),
                    child: Text(l10n.subTrackDetailNoDeadlineLink),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One Change history entry (DESIGN "Change-history entry"; Story 4.5 /
/// DNI-513 AC-3 – AC-6): actor avatar, name, role tag and time; the
/// plain-language sentence; the AD-39 bell; Undone / lock / date tags; and
/// a trailing Undo
/// when the row allows it and Story 4.6 supplies the action.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/change_history/domain/models/change_history_row.dart';
import 'package:learning_tracker/features/change_history/presentation/widgets/change_history_text.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The initials avatar of an actor.
class ChangeHistoryAvatar extends StatelessWidget {
  /// Creates the avatar for [name].
  const ChangeHistoryAvatar({required this.name, super.key});

  /// The shown actor name.
  final String name;

  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = [
      for (final w in words.take(2))
        if (w.isNotEmpty) w.characters.first,
    ].join().toUpperCase();
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: 18,
        backgroundColor: context.colors.brandBlueSoft,
        foregroundColor: context.colors.brandBlue,
        child: Text(
          initials,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// A small outlined tag ("Tutor", "Undone", "catch-up").
class ChangeHistoryTag extends StatelessWidget {
  /// Creates a tag reading [label].
  const ChangeHistoryTag({required this.label, this.muted = false, super.key});

  /// The tag text.
  final String label;

  /// Uses the muted ink (the *Undone* tag, DESIGN `undone-label`).
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: colors.brandOutline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: muted ? colors.brandInkMuted : colors.brandInk2,
        ),
      ),
    );
  }
}

/// The AD-39 bell: this tutor change notified the parent. Display only;
/// it mirrors the `onChangeLogCreated` allowlist and never sends a push.
class ChangeHistoryBell extends StatelessWidget {
  /// Creates the bell, announced as [label].
  const ChangeHistoryBell({required this.label, super.key});

  /// The accessible label ("Parent notified").
  final String label;

  @override
  Widget build(BuildContext context) => Icon(
    Icons.notifications_active_outlined,
    key: const ValueKey('changeHistoryBell'),
    size: 18,
    color: context.colors.brandBlue,
    semanticLabel: label,
  );
}

/// One history row.
class ChangeHistoryRowTile extends ConsumerWidget {
  /// Creates the tile for [row].
  const ChangeHistoryRowTile({
    required this.row,
    required this.onTap,
    this.selected = false,
    this.onUndo,
    super.key,
  });

  /// The row.
  final ChangeHistoryRow row;

  /// Opens the row's details.
  final VoidCallback onTap;

  /// Highlighted as the details pane's row (tablet).
  final bool selected;

  /// Undo, when Story 4.6 supplies it; shown only if [ChangeHistoryRow.canUndo].
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final formats = ChangeHistoryFormats.of(context);
    final name = changeHistoryActorName(l10n, row.stamp.actor);
    final summary = row.summary;
    final others = summary is GovernedSummary ? summary.others.length : 0;
    final dateTag = changeHistoryDateTag(l10n, formats, row);
    final voided = changeHistoryVoidedText(l10n, formats, row);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.brandInkMuted,
    );
    final undo = onUndo != null && row.canUndo ? onUndo : null;

    return Semantics(
      container: true,
      selected: selected,
      child: Material(
        color: selected ? colors.brandBlueSoft : colors.brandCreamCard,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.brandOutline),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChangeHistoryAvatar(name: name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            ChangeHistoryTag(
                              label: changeHistoryRoleLabel(
                                l10n,
                                row.stamp.actor.role,
                              ),
                            ),
                            Text(
                              '· ${formats.time(row.stamp.localTime)}',
                              style: muted,
                            ),
                            if (row.notifiesParent)
                              ChangeHistoryBell(
                                label: l10n.changeHistoryNotified,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          changeHistorySentence(l10n, formats, ref, row),
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (others > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            l10n.changeHistoryAlsoChanged(others),
                            style: muted,
                          ),
                        ],
                        if (row.undoneBy != null ||
                            row.lockIgnored ||
                            dateTag != null) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (row.undoneBy != null)
                                ChangeHistoryTag(
                                  label: l10n.changeHistoryUndone,
                                  muted: true,
                                ),
                              if (dateTag != null)
                                ChangeHistoryTag(label: dateTag),
                              if (row.lockIgnored)
                                Text(
                                  l10n.changeHistoryLockIgnored,
                                  style: muted,
                                ),
                            ],
                          ),
                        ],
                        if (voided != null) ...[
                          const SizedBox(height: 4),
                          Text(voided, style: muted),
                        ],
                      ],
                    ),
                  ),
                  if (undo != null)
                    TextButton(
                      onPressed: undo,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      child: Text(l10n.changeHistoryUndo),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

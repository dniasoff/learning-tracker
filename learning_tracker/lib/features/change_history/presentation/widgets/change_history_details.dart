/// The details of one Change history row (Story 4.5 / DNI-513 AC-10;
/// tablet detail pane and phone bottom sheet): who, when, every part of
/// the action, and its undo, void and lock state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/change_history/domain/models/change_history_row.dart';
import 'package:learning_tracker/features/change_history/presentation/widgets/change_history_row_tile.dart';
import 'package:learning_tracker/features/change_history/presentation/widgets/change_history_text.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The details of [row].
class ChangeHistoryDetails extends ConsumerWidget {
  /// Creates the details of [row].
  const ChangeHistoryDetails({required this.row, this.onUndo, super.key});

  /// The row.
  final ChangeHistoryRow row;

  /// Undo, when Story 4.6 supplies it; shown only if [ChangeHistoryRow.canUndo].
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.colors;
    final formats = ChangeHistoryFormats.of(context);
    final actor = row.stamp.actor;
    final name = changeHistoryActorName(l10n, actor);
    final summary = row.summary;
    final caption = theme.textTheme.labelMedium?.copyWith(
      color: colors.brandInkMuted,
      letterSpacing: 0.6,
    );
    final undoneBy = row.undoneBy;
    final voided = changeHistoryVoidedText(l10n, formats, row);
    final dateTag = changeHistoryDateTag(l10n, formats, row);

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title.toUpperCase(), style: caption),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.changeHistoryDetailsTitle,
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          changeHistorySentence(l10n, formats, ref, row),
          style: theme.textTheme.bodyLarge,
        ),
        section(l10n.changeHistoryDetailsWho, [
          Row(
            children: [
              ChangeHistoryAvatar(name: name),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '$name (${changeHistoryRoleLabel(l10n, actor.role)})',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ]),
        section(l10n.changeHistoryDetailsWhen, [
          Text(formats.stamp(row.stamp), style: theme.textTheme.bodyMedium),
          if (row.notifiesParent) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                ExcludeSemantics(
                  child: ChangeHistoryBell(label: l10n.changeHistoryNotified),
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.changeHistoryNotified,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ]),
        section(l10n.changeHistoryDetailsWhat, [
          if (summary is GovernedSummary)
            for (final part in [summary.primary, ...summary.others])
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  governedPartSentence(l10n, formats, part),
                  style: theme.textTheme.bodyMedium,
                ),
              )
          else
            Text(
              changeHistorySentence(l10n, formats, ref, row),
              style: theme.textTheme.bodyMedium,
            ),
          if (dateTag != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ChangeHistoryTag(label: dateTag),
            ),
          ],
        ]),
        if (undoneBy != null || voided != null || row.lockIgnored) ...[
          const SizedBox(height: 16),
          if (undoneBy != null)
            Text(
              l10n.changeHistoryUndoneBy(
                changeHistoryActorName(l10n, undoneBy.actor),
                formats.stamp(undoneBy),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.brandInkMuted,
              ),
            ),
          if (voided != null)
            Text(
              voided,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.brandInkMuted,
              ),
            ),
          if (row.lockIgnored)
            Text(
              l10n.changeHistoryLockIgnored,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.brandInkMuted,
              ),
            ),
        ],
        if (onUndo != null && row.canUndo) ...[
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton(
              onPressed: onUndo,
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(l10n.changeHistoryUndo),
            ),
          ),
        ],
      ],
    );
  }
}

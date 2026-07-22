import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_helpers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/task_category_stat_box.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Reusable stat grid for active-track cards.
///
/// When [chazaraLabel] is non-null the grid shows three columns:
///   chazara | due today | overdue
///
/// When [chazaraLabel] is null (track has no chazara — Rule 8) the grid
/// shows two columns:
///   due today | overdue
///
/// Counts come from [buckets]; tapping a box jumps to the first task in
/// that category.
class TrackStatGrid extends StatelessWidget {
  const TrackStatGrid({
    super.key,
    required this.buckets,
    required this.l10n,
    this.chazaraLabel,
  });

  final TrackTaskBuckets buckets;
  final AppLocalizations l10n;

  /// Resolved label for the chazara column.
  ///
  /// Null when the track does not have chazara enabled (Rule 8).  The column
  /// is omitted entirely — not zeroed-out or greyed-out.
  final String? chazaraLabel;

  @override
  Widget build(BuildContext context) {
    final showChazara = chazaraLabel != null;
    return Row(
      children: [
        if (showChazara) ...[
          Expanded(
            child: TaskCategoryStatBox(
              count: buckets.review.length,
              label: chazaraLabel!,
              valueColor: buckets.review.isNotEmpty
                  ? context.colors.goldAmber
                  : context.colors.brandInk,
              valueBg: context.colors.brandWarningSoft,
              onTap: buckets.review.isNotEmpty
                  ? () => _openFirst(context, buckets.review)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: TaskCategoryStatBox(
            count: buckets.dueTodayLane.length,
            label: l10n.activeTrackMetricDueToday,
            valueColor: buckets.dueTodayLane.isNotEmpty
                ? kActiveTrackPrimaryBlue(context)
                : context.colors.brandInk,
            valueBg: context.colors.brandBlueSoft,
            onTap: buckets.dueTodayLane.isNotEmpty
                ? () => _openFirst(context, buckets.dueTodayLane)
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TaskCategoryStatBox(
            count: buckets.missedProgram.length,
            label: l10n.activeTrackMetricOverdue,
            valueColor: context.colors.statusError,
            valueBg: context.colors.statusErrorSoft,
            countMutedWhenZero: true,
            onTap: buckets.missedProgram.isNotEmpty
                ? () => _openFirst(context, buckets.missedProgram)
                : null,
          ),
        ),
      ],
    );
  }

  void _openFirst(BuildContext context, List<DailyTask> tasks) {
    if (tasks.isEmpty) return;
    context.router.push(
      TextDisplayRoute(sefariaRef: tasks.first.contentItemSefariaRef),
    );
  }
}

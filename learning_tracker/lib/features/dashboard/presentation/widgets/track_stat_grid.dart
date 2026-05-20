import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_helpers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/task_category_stat_box.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Reusable 3-box stat grid for active-track cards. One layout for every
/// track variant — counts come from [buckets]; tapping a box jumps to the
/// first task in that category.
class TrackStatGrid extends StatelessWidget {
  const TrackStatGrid({
    super.key,
    required this.buckets,
    required this.l10n,
    required this.chazaraLabel,
  });

  final TrackTaskBuckets buckets;
  final AppLocalizations l10n;
  final String chazaraLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TaskCategoryStatBox(
            count: buckets.review.length,
            label: chazaraLabel,
            valueColor: buckets.review.isNotEmpty
                ? const Color(0xFFB45309)
                : AppTheme.brandInk,
            valueBg: const Color(0xFFFFE7D1),
            onTap: buckets.review.isNotEmpty
                ? () => _openFirst(context, buckets.review)
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TaskCategoryStatBox(
            count: buckets.dueTodayLane.length,
            label: l10n.activeTrackMetricDueToday,
            valueColor: buckets.dueTodayLane.isNotEmpty
                ? kActiveTrackPrimaryBlue
                : AppTheme.brandInk,
            valueBg: const Color(0xFFDFE9FD),
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
            valueColor: AppColors.statusError,
            valueBg: const Color(0xFFFFE0EB),
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

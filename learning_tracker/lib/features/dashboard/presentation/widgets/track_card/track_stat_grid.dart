import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/dashboard/domain/models/track_card_view_model.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_helpers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/task_category_stat_box.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Three-column stat grid for [TrackCard].
///
/// Displays review / due-today / overdue counts from [vm]. Tapping a non-zero
/// bucket navigates to the first task in that category via
/// [firstTaskInTrackForCategoryProvider].
class TrackStatGrid extends ConsumerWidget {
  const TrackStatGrid({super.key, required this.vm, required this.l10n});

  final TrackCardViewModel vm;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // ── Review / Chazara ────────────────────────────────────────────────
        Expanded(
          child: TaskCategoryStatBox(
            count: vm.reviewCount,
            label: vm.chazaraLabel,
            valueColor: vm.reviewCount > 0
                ? const Color(0xFFB45309)
                : AppTheme.brandInk,
            valueBg: const Color(0xFFFFE7D1),
            labelStyle: theme.textTheme.labelSmall,
            onTap: vm.reviewCount > 0
                ? () => _navigateToCategory(
                    context,
                    ref,
                    TrackTaskCategory.review,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 8),
        // ── Due Today ───────────────────────────────────────────────────────
        Expanded(
          child: TaskCategoryStatBox(
            count: vm.dueTodayCount,
            label: l10n.activeTrackMetricDueToday,
            valueColor: vm.dueTodayCount > 0
                ? kActiveTrackPrimaryBlue
                : AppTheme.brandInk,
            valueBg: const Color(0xFFDFE9FD),
            labelStyle: theme.textTheme.labelSmall,
            onTap: vm.dueTodayCount > 0
                ? () => _navigateToCategory(
                    context,
                    ref,
                    TrackTaskCategory.dueToday,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 8),
        // ── Overdue ─────────────────────────────────────────────────────────
        Expanded(
          child: TaskCategoryStatBox(
            count: vm.overdueCount,
            label: l10n.activeTrackMetricOverdue,
            valueColor: const Color(0xFFD63C3C),
            valueBg: const Color(0xFFFFE0EB),
            labelStyle: theme.textTheme.labelSmall,
            countMutedWhenZero: true,
            onTap: vm.overdueCount > 0
                ? () => _navigateToCategory(
                    context,
                    ref,
                    TrackTaskCategory.overdue,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Future<void> _navigateToCategory(
    BuildContext context,
    WidgetRef ref,
    TrackTaskCategory category,
  ) async {
    final task = await ref.read(
      firstTaskInTrackForCategoryProvider(
        trackId: vm.trackId,
        category: category,
      ).future,
    );
    if (task != null && context.mounted) {
      unawaited(
        context.router.push(
          TextDisplayRoute(sefariaRef: task.contentItemSefariaRef),
        ),
      );
    }
  }
}

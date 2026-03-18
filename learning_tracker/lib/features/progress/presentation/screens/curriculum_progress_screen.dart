import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/error_display.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/hierarchy_progress_card.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/overall_stats_card.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/pace_indicator.dart';

@RoutePage()
class CurriculumProgressScreen extends ConsumerWidget {
  const CurriculumProgressScreen({
    super.key,
    @PathParam('curriculumId') required this.curriculumId,
  });

  final String curriculumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculumName = _getCurriculumName(curriculumId);
    final progressAsync = ref.watch(curriculumProgressProvider(curriculumId));
    final paceAsync = ref.watch(curriculumPaceStatusProvider(curriculumId));
    final curriculumColor = AppTheme.getCurriculumColorByKey(curriculumId);

    return Scaffold(
      appBar: AppBar(title: AppBarTitle(text: 'Progress - $curriculumName')),
      body: SafeArea(top: false, child: progressAsync.when(
        data: (progressData) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pace indicator (if goal exists)
              paceAsync.when(
                data: (pace) => pace != null
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: PaceIndicator(paceStatus: pace),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Overall stats card
              OverallStatsCard(stats: progressData.overallStats),
              const SizedBox(height: 16),

              // Hierarchy breakdown
              Text(
                'Breakdown by Level',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...progressData.hierarchyLevels.map(
                (level) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: HierarchyProgressCard(
                    level: level,
                    curriculumColor: curriculumColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        loading: () => const LoadingIndicator(message: 'Loading progress...'),
        error: (error, _) => ErrorDisplay(
          message: 'Failed to load progress: $error',
          onRetry: () => ref.invalidate(curriculumProgressProvider),
        ),
      )),
    );
  }

  String _getCurriculumName(String curriculumId) {
    final matches = CurriculumId.values.where(
      (c) => c.storageKey == curriculumId,
    );
    return matches.isNotEmpty ? matches.first.displayNameEn : curriculumId;
  }
}

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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

  CurriculumId? _curriculumEnum() {
    for (final c in CurriculumId.values) {
      if (c.storageKey == curriculumId) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculum = _curriculumEnum();
    final titleEn = curriculum?.displayNameEn ?? curriculumId;
    final titleHe = curriculum?.displayNameHe;
    final progressAsync = ref.watch(curriculumProgressProvider(curriculumId));
    final paceAsync = ref.watch(curriculumPaceStatusProvider(curriculumId));
    final curriculumColor = AppTheme.getCurriculumColorByKey(curriculumId);
    final baseTheme = Theme.of(context);
    final plusJakartaTheme = baseTheme.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(baseTheme.textTheme),
    );

    Widget bodyChild(Widget child) {
      return Theme(data: plusJakartaTheme, child: child);
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppTheme.brandCream,
        foregroundColor: AppTheme.brandInk,
        title: AppBarTitle(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titleEn,
                style: plusJakartaTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.brandInk,
                ),
              ),
              if (titleHe != null && titleHe.isNotEmpty)
                Text(
                  titleHe,
                  style: plusJakartaTheme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.brandInkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.brandCreamCard,
              AppTheme.brandBlueSoft.withValues(alpha: 0.22),
              AppTheme.brandCream,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: progressAsync.when(
            data: (progressData) => bodyChild(
              ListView(
                padding: const EdgeInsets.fromLTRB(25, 10, 25, 32),
                children: [
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
                  OverallStatsCard(stats: progressData.overallStats),
                  const SizedBox(height: 24),
                  Text(
                    'Breakdown by Level',
                    style: plusJakartaTheme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 28,
                      color: AppTheme.brandInk,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...progressData.hierarchyLevels.map(
                    (level) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: HierarchyProgressCard(
                        level: level,
                        curriculumColor: curriculumColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            loading: () => bodyChild(
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: LoadingIndicator(message: 'Loading progress...'),
                ),
              ),
            ),
            error: (error, _) => bodyChild(
              Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorDisplay(
                  message: 'Failed to load progress: $error',
                  onRetry: () =>
                      ref.invalidate(curriculumProgressProvider(curriculumId)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

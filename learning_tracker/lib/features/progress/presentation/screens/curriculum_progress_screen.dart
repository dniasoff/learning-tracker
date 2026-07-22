import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/error_display.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/hierarchy_progress_card.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/overall_stats_card.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/pace_indicator.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class CurriculumProgressScreen extends ConsumerWidget {
  const CurriculumProgressScreen({
    super.key,
    @PathParam('curriculumId') required this.curriculumId,
  });

  final String curriculumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculum = CurriculumId.fromStorageKey(curriculumId);
    final terms = domainTermLabels(ref);
    final l10n = AppLocalizations.of(context)!;
    final progressAsync = ref.watch(curriculumProgressProvider(curriculumId));
    final paceAsync = ref.watch(curriculumPaceStatusProvider(curriculumId));
    final profileId = ref.watch(activeProfileIdProvider);
    // Lifetime % for this curriculum — used by the new dual-stats row in
    // OverallStatsCard. Null while loading / when the curriculum has no
    // content asset so the row falls back to an em-dash on that side.
    final lifetimeAsync = curriculum == null
        ? const AsyncValue<CurriculumLifetimeSummary?>.data(null)
        : ref.watch(
            lifetimeDataProvider((
              profileId: profileId,
              curriculumId: curriculum,
            )),
          );
    final curriculumColor = context.colors.curriculumForKey(curriculumId);
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
        foregroundColor: context.colors.brandInk,
        actions: [
          if (curriculum != null)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: l10n.curriculumProgressSettingsTooltip,
              onPressed: () => context.router.push(
                CurriculumSettingsRoute(curriculumId: curriculumId),
              ),
            ),
        ],
        title: AppBarTitle(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (curriculum != null)
                CurriculumLabel.curriculum(
                  curriculum,
                  style: plusJakartaTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.colors.brandInk,
                  ),
                )
              else
                // Unknown storage key (no matching CurriculumId) — never leak
                // the raw key (e.g. 'bavli') into the title. Show a localized
                // unknown-curriculum label instead.
                Text(
                  l10n.errorUnknownCurriculum(curriculumId),
                  style: plusJakartaTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.colors.brandInk,
                  ),
                ),
              if (curriculum != null && !terms.isHebrew)
                Text(
                  curriculumHebrewName(curriculum),
                  style: plusJakartaTheme.textTheme.labelSmall?.copyWith(
                    color: context.colors.brandInkMuted,
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
              context.colors.brandCreamCard,
              context.colors.brandBlueSoft.withValues(alpha: 0.22),
              context.colors.brandCream,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: progressAsync.when(
            data: (progressData) {
              // Track progress = current-cycle achievement: % of items that
              // have completed every stage (the existing "completedAllStages"
              // bucket). Lifetime = % of items ever touched (live + bulk +
              // lifetimeOnly), sourced from lifetimeDataProvider.
              final totalItems = progressData.overallStats.totalItems;
              final trackProgressFraction = totalItems == 0
                  ? 0.0
                  : progressData.overallStats.completedAllStages / totalItems;
              final lifetimeFraction = lifetimeAsync.asData?.value == null
                  ? null
                  : (lifetimeAsync.asData!.value!.totalLeafCount == 0
                        ? 0.0
                        : lifetimeAsync.asData!.value!.learnedLeafCount /
                              lifetimeAsync.asData!.value!.totalLeafCount);

              return bodyChild(
                ListView(
                  padding: const EdgeInsets.fromLTRB(25, 10, 25, 32),
                  children: [
                    paceAsync.when(
                      data: (pace) => pace != null
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: ProgressPaceIndicator(
                                pace: pace,
                                subtitleCaption:
                                    l10n.paceLiveLearningOnlyCaption,
                              ),
                            )
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    OverallStatsCard(
                      stats: progressData.overallStats,
                      trackProgressFraction: trackProgressFraction,
                      lifetimeFraction: lifetimeFraction,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.curriculumProgressBreakdownByLevel,
                      style: plusJakartaTheme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        color: context.colors.brandInk,
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
              );
            },
            loading: () => bodyChild(
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: LoadingIndicator(
                    message: l10n.curriculumProgressLoading,
                  ),
                ),
              ),
            ),
            error: (error, _) => bodyChild(
              Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorDisplay(
                  message: l10n.curriculumProgressLoadFailed,
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

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/curriculum_visuals.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/core/widgets/empty_state.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_lens_refresh_tick_provider.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/progress_tier_counter_row.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Progress hub — the bottom-nav landing page for the three-lens IA.
///
/// Top-down structure (per `docs/planning/progress-ia-redesign.md` §2):
///
///   1. "Progress" title header.
///   2. [ProgressTierCounterRow] — engagement / achievement / lifetime
///      counters; child mode adds a fourth ⭐ points counter.
///   3. Three lens tiles — Recent Activity / Siyumim & Milestones /
///      Lifetime Knowledge — each navigating to the respective screen.
///   4. Per-track section — compact list of the active tracks with dual
///      track-progress / lifetime % labels; tap pushes the curriculum
///      progress detail screen.
///
/// The legacy 4-card stat grid (ITEMS LEARNED · TASKS DONE · DAY STREAK ·
/// ACTIVE TRACKS) and the inline Learning Lifetime tree have been retired —
/// the streak + items info now live in the counter row, the lifetime tree
/// moved into the Lifetime Knowledge screen.
@RoutePage()
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseTheme = Theme.of(context);
    final interTextTheme = GoogleFonts.interTextTheme(baseTheme.textTheme)
        .apply(
          bodyColor: baseTheme.colorScheme.onSurface,
          displayColor: baseTheme.colorScheme.onSurface,
        );
    final activeCurriculaAsync = ref.watch(
      dashboardActiveCurriculaStreamProvider,
    );
    final profileId = ref.watch(activeProfileIdProvider);
    final userMode =
        ref.watch(dashboardUserModeProvider).asData?.value ?? ProfileMode.adult;

    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surfaceF4b,
      body: Theme(
        data: baseTheme.copyWith(
          textTheme: interTextTheme,
          primaryTextTheme: interTextTheme,
        ),
        child: SafeArea(
          child: activeCurriculaAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(l10n.errorWithMessage)),
            data: (activeCurricula) {
              if (activeCurricula.isEmpty) {
                return EmptyState(
                  message: l10n.progressNoDataTitle,
                  subtitle: l10n.progressNoDataSubtitle,
                  icon: Icons.trending_up_outlined,
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  // F25: Bump the lens refresh tick so lens-screen providers
                  // (Recent Activity / Siyumim & Milestones / Lifetime
                  // Knowledge) — which live in trees the hub doesn't directly
                  // compose — also re-fetch on pull-to-refresh. Lens
                  // providers participate by `ref.watch`ing the tick (see
                  // progress_lens_refresh_tick_provider.dart).
                  ref.read(progressLensRefreshTickProvider.notifier).bump();

                  // Direct invalidation of hub-owned providers — kept as a
                  // safety net so the refresh remains effective even before
                  // the lens providers wire the tick (sibling W7-B / W7-D
                  // follow-up).
                  ref.invalidate(dashboardActiveCurriculaStreamProvider);
                  ref.invalidate(dashboardStreakProvider);
                  ref.invalidate(dashboardGlobalPointsProvider);
                  ref.invalidate(journeyViewModelProvider(profileId));
                  ref.invalidate(
                    lifetimeTotalsAcrossAllCurriculaProvider(profileId),
                  );
                  ref.invalidate(trackDualProgressMetricsProvider(profileId));
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    Text(
                      l10n.progress,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),
                    ProgressTierCounterRow(showPoints: userMode.isChild),
                    const SizedBox(height: 18),
                    const _RecentActivityLensTile(),
                    const SizedBox(height: 10),
                    const _SiyumimMilestonesLensTile(),
                    const SizedBox(height: 10),
                    const _LifetimeKnowledgeLensTile(),
                    const SizedBox(height: 22),
                    _PerTrackSection(profileId: profileId),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Lens tiles ─────────────────────────────────────────────────────────────

/// Shared visual shell for the three lens tiles. The icon + title + subtitle
/// are passed in so each tile can wire its own emoji, route, and l10n keys
/// while inheriting the InkWell-on-rounded-card chrome.
class _LensTile extends StatelessWidget {
  const _LensTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.blueNavy.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.brandInkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.brandInkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityLensTile extends ConsumerWidget {
  const _RecentActivityLensTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return _LensTile(
      icon: Icons.local_fire_department_rounded,
      iconBgColor: const Color(0xFFFFE9EB),
      iconColor: const Color(0xFFFF6F77),
      title: l10n.tierLensRecentActivity,
      subtitle: l10n.progressChartsTileSubtitle,
      onTap: () => context.router.push(const RecentActivityRoute()),
    );
  }
}

class _SiyumimMilestonesLensTile extends ConsumerWidget {
  const _SiyumimMilestonesLensTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return _LensTile(
      icon: Icons.emoji_events_outlined,
      iconBgColor: const Color(0xFFFFF4E0),
      iconColor: AppColors.chartAmber,
      title: l10n.tierLensSiyumimMilestones,
      subtitle: l10n.myLearningJourneySubtitle,
      onTap: () => context.router.push(SiyumimMilestonesRoute()),
    );
  }
}

class _LifetimeKnowledgeLensTile extends ConsumerWidget {
  const _LifetimeKnowledgeLensTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return _LensTile(
      icon: Icons.menu_book_outlined,
      iconBgColor: const Color(0xFFEEF3FF),
      iconColor: AppTheme.brandBlue,
      title: l10n.tierLensLifetimeKnowledge,
      subtitle: l10n.itemsLearnedSubtitle,
      onTap: () => context.router.push(const LifetimeKnowledgeRoute()),
    );
  }
}

// ── Per-track section ─────────────────────────────────────────────────────

/// Compact list of the active tracks — one row per track, each showing the
/// per-track achievement % + lifetime %.
///
/// Reads [trackDualProgressMetricsProvider] (already used by Dashboard) so
/// the two screens share the same numbers and a single cached future.
class _PerTrackSection extends ConsumerWidget {
  const _PerTrackSection({required this.profileId});

  final int profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final metricsAsync = ref.watch(trackDualProgressMetricsProvider(profileId));
    final theme = Theme.of(context);

    return metricsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(l10n.errorWithMessage),
      ),
      data: (metrics) {
        if (metrics.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(
                l10n.activeTracksLabel.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.brandInkMuted,
                ),
              ),
            ),
            for (var i = 0; i < metrics.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _PerTrackRow(metric: metrics[i]),
            ],
          ],
        );
      },
    );
  }
}

class _PerTrackRow extends ConsumerWidget {
  const _PerTrackRow({required this.metric});

  final TrackDualProgressMetric metric;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final curriculum = metric.curriculumId;
    // Adaptive precision via the shared formatter so a small non-zero fraction
    // (e.g. 7/5846) reads "0.1%" here exactly as it does on Lifetime Knowledge
    // and track-detail — previously `.round()` floored it to "0%" (Bug 3).
    final trackPct = formatFractionAsPercent(metric.currentCyclePercentage);
    final lifetimePct = formatFractionAsPercent(metric.lifetimePercentage);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.router.push(
        CurriculumProgressRoute(curriculumId: curriculum.storageKey),
      ),
      child: Ink(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.blueNavy.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF3FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                curriculumIcon(curriculum),
                color: AppTheme.brandBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    curriculumLabelText(ref, curriculum: curriculum),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 2,
                    children: [
                      Text(
                        '${l10n.trackProgress}: $trackPct',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.brandInkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${l10n.lifetimeLabel}: $lifetimePct',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.brandInkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.brandInkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/sync/providers/sync_status_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_body.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';

@RoutePage()
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  /// Invalidates every dashboard data provider so it re-reads from Drift.
  ///
  /// This is the single source of truth for "make the dashboard fresh". It is
  /// reused by BOTH the pull-to-refresh [RefreshIndicator.onRefresh] AND the
  /// auto-refresh-on-launch-pull listener below, so the two paths can never
  /// drift apart.
  ///
  /// [activeTracks] scopes the per-track invalidations to the tracks currently
  /// on screen (track completion %, last completion, pace status per curriculum).
  static void invalidateDashboardData(
    WidgetRef ref,
    List<CurriculumTrack> activeTracks,
  ) {
    final profileId = ref.read(activeProfileIdProvider);
    ref.invalidate(dashboardActiveTracksStreamProvider);
    ref.invalidate(dashboardUserModeProvider);
    ref.invalidate(dashboardStreakProvider);
    ref.invalidate(dashboardGlobalPointsProvider);
    ref.invalidate(dashboardChildNextRewardProvider);
    ref.invalidate(allDailyTasksProvider);
    ref.invalidate(lifetimeTotalsAcrossAllCurriculaProvider(profileId));
    ref.invalidate(lifetimeSummariesProvider(profileId));
    // ignore: deprecated_member_use
    ref.invalidate(globalLifetimeCurriculaProvider(profileId));
    for (final c in CurriculumId.all) {
      ref.invalidate(
        lifetimeDataProvider((profileId: profileId, curriculumId: c)),
      );
    }
    ref.invalidate(trackDualProgressMetricsProvider(profileId));
    for (final t in activeTracks) {
      ref.invalidate(dashboardTrackCompletionPercentageProvider(t.id));
      final c = CurriculumId.values.firstWhere(
        (cv) => cv.storageKey == t.curriculumId,
        orElse: () => CurriculumId.mishnayos,
      );
      ref.invalidate(dashboardLastCompletionProvider(c));
      ref.invalidate(dashboardPaceStatusProvider(c));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTracksAsync = ref.watch(dashboardActiveTracksStreamProvider);

    // Auto-refresh on launch-pull completion. The launch sync pull
    // (SyncOrchestrator.pullOnLaunch) merges fresh cloud data into the local
    // Drift DB and THEN emits SyncStatus.synced — but it does not invalidate
    // the dashboard's one-shot FutureProviders, so on cold/warm open they have
    // already resolved against the pre-pull (stale/empty) Drift state. Without
    // this listener the user has to pull-to-refresh to see points / streak /
    // today's tasks / projection.
    //
    // We invalidate the same provider set as the manual pull, but ONLY on the
    // transition INTO a `synced` status (previous != synced). That keeps it to
    // one refresh per completed pull — it does not fire on every rebuild, and a
    // `synced → synced` re-emit (impossible in practice, but defensive) is
    // ignored — so there is no refresh loop.
    ref.listen<SyncStatus>(syncStatusProvider, (previous, next) {
      if (next is SyncStatusSynced && previous is! SyncStatusSynced) {
        final tracks =
            ref.read(dashboardActiveTracksStreamProvider).asData?.value ??
            const <CurriculumTrack>[];
        invalidateDashboardData(ref, tracks);
      }
    });

    final userModeAsync = ref.watch(dashboardUserModeProvider);
    final streakAsync = ref.watch(dashboardStreakProvider);
    // BUG-NEW-2: the greeting identity must reflect the ACTIVE profile, not the
    // signed-in user's own selected profile. In a tutored session the active
    // profile is the talmid's mirror, so the dashboard greets the talmid (e.g.
    // "Tttt") with the talmid's data — never the tutor's name.
    final activeProfileAsync = ref.watch(activeProfileProvider);
    final profileName = activeProfileAsync.asData?.value?.displayName;
    return Scaffold(
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
          child: activeTracksAsync.when(
            // Keep the previous tracks visible while the stream re-subscribes
            // on launch (auth settling). Without this the screen flashes a
            // spinner — then DashboardBody — on every reload.
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => AppErrorView(
              error: e,
              stackTrace: s,
              onRetry: () => ref.refresh(dashboardActiveTracksStreamProvider),
            ),
            data: (activeTracks) {
              final userMode = userModeAsync.asData?.value ?? ProfileMode.adult;
              final streakData = streakAsync.asData?.value;
              final currentStreak = streakData?.currentStreak ?? 0;

              return RefreshIndicator(
                onRefresh: () async =>
                    invalidateDashboardData(ref, activeTracks),
                child: DashboardBody(
                  activeTracks: activeTracks,
                  userMode: userMode,
                  currentStreak: currentStreak,
                  profileName: profileName,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

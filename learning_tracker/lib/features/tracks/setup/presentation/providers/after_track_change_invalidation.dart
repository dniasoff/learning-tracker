import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/calendar_position_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';

/// Canonical set of providers that must be invalidated after a track is
/// created, archived, or otherwise changed.
///
/// This is the **single source of truth** for after-track-change invalidation.
/// All call sites (add-track flow, track deletion, prior-completion bulk mark)
/// use [onTrackChanged] rather than maintaining their own ad-hoc invalidation
/// lists.
///
/// Every invalidation that genuinely needed a profile identity (the
/// daily-plan-snapshot clear, and every `lifetime_knowledge_providers.dart`/
/// `calendar_position_providers.dart` provider) resolves the CURRENTLY
/// ACTIVE profile internally via `Ref` (AD-24) rather than taking one as a
/// parameter — there is no "invalidate for another profile" use case.
Future<void> onTrackChanged(WidgetRef ref) async {
  // Rebuild track lists first so dashboard/hub show the new row without waiting
  // on the broad invalidation sweep below.
  ref.invalidate(dashboardActiveTracksStreamProvider);
  ref.invalidate(activeTracksProvider);

  // TODO(scheduler-daily-plan-cluster): db.dailyPlanDao.deletePlanForDay
  // used to force the day's cached plan to rebuild here so a new/changed
  // track shows up immediately instead of waiting for the next local day.
  // scheduler_providers.dart's allDailyTasksProvider is itself still
  // Drift-dependent (`ref.watch(userDatabaseProvider)`) and
  // DailyPlanRepository.getOrSnapshotPlan/rebuildPlan both still require an
  // `int profileId` this file has no live value for post-AD-24 — a
  // separate, already-broken cluster, not fixed here.
  ref.invalidate(allDailyTasksProvider);
  ref.invalidate(dashboardActiveCurriculaStreamProvider);
  ref.invalidate(trackDualProgressMetricsProvider);
  ref.invalidate(dashboardChildNextRewardProvider);
  ref.invalidate(dashboardStreakProvider);
  ref.invalidate(dashboardGlobalPointsProvider);
  ref.invalidate(lifetimeTotalsAcrossAllCurriculaProvider);
  ref.invalidate(lifetimeSummariesProvider);
  ref.invalidate(progressOverviewStatsProvider);

  for (final c in CurriculumId.all) {
    ref.invalidate(dashboardCompletionPercentageProvider(c));
    ref.invalidate(dashboardLastCompletionProvider(c));
    ref.invalidate(dashboardPaceStatusProvider(c));
    ref.invalidate(dashboardHasProgramEnrollmentProvider(c));
    ref.invalidate(scopedCurriculumContentProvider(c));
    ref.invalidate(scopedItemCountProvider(c));
    ref.invalidate(curriculumScopeSummaryProvider(c));
    ref.invalidate(lifetimeDataProvider(c));
  }

  // ref.read(...), not a direct FirestoreCurriculumTrackRepositoryAdapter(ref:
  // ref) construction: this function is called with a WidgetRef (from
  // screens), which does not implement Ref the way an @riverpod function's
  // Ref does — going through the already-built dashboardActiveCurriculaProvider
  // avoids that mismatch and reuses the same resolution dashboard_providers.dart
  // itself uses.
  final activeCurricula = await ref.read(
    dashboardActiveCurriculaProvider.future,
  );
  for (final c in activeCurricula) {
    ref.invalidate(dashboardTrackCompletionPercentageProvider(c));
    ref.invalidate(programCalendarPositionProvider(c));
  }
}

/// Deprecated alias for [onTrackChanged].
///
/// Prefer calling [onTrackChanged] directly. This alias is kept temporarily
/// so existing call sites (add_track_flow, track_management_body,
/// track_detail_screen) continue to compile without changes.
@Deprecated('Use onTrackChanged instead')
Future<void> invalidateAfterTrackDataChange(WidgetRef ref) =>
    onTrackChanged(ref);

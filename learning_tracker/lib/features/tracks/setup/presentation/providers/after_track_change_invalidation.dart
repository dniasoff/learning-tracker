import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
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
/// [profileId] is currently UNUSED internally — kept only so the 9 existing
/// call sites across 5 files (several of which still hold the pre-AD-25
/// Drift `CurriculumTrack` type with a real `.profileId` field, and are
/// outside this pass's scope) do not all need to change signature together.
/// Every invalidation that genuinely needed it (the daily-plan-snapshot
/// clear, and every `lifetime_knowledge_providers.dart`/
/// `calendar_position_providers.dart` provider) is stripped below with a
/// TODO — each is blocked on a separate, already-broken cluster (see the
/// module's fix-script doc comment / task tracker #19 for what's blocking
/// them), not something to half-fix here.
Future<void> onTrackChanged(WidgetRef ref, int profileId) async {
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
  // TODO(task-19): trackDualProgressMetricsProvider is a deliberate
  // throw-stub (lifetime_knowledge_providers.dart) blocked on task #5/#19.
  ref.invalidate(dashboardChildNextRewardProvider);
  ref.invalidate(dashboardStreakProvider);
  ref.invalidate(dashboardGlobalPointsProvider);
  // TODO(task-19): lifetimeTotalsAcrossAllCurriculaProvider /
  // lifetimeSummariesProvider / globalLifetimeCurriculaProvider /
  // lifetimeDataProvider are all still `int profileId`-keyed in
  // lifetime_knowledge_providers.dart — blocked on task #19.
  ref.invalidate(progressOverviewStatsProvider);

  for (final c in CurriculumId.all) {
    ref.invalidate(dashboardCompletionPercentageProvider(c));
    ref.invalidate(dashboardLastCompletionProvider(c));
    ref.invalidate(dashboardPaceStatusProvider(c));
    ref.invalidate(dashboardHasProgramEnrollmentProvider(c));
    ref.invalidate(scopedCurriculumContentProvider(c));
    ref.invalidate(scopedItemCountProvider(c));
    ref.invalidate(curriculumScopeSummaryProvider(c));
  }

  // ref.read(...), not a direct FirestoreCurriculumTrackRepositoryAdapter(ref:
  // ref) construction: this function is called with a WidgetRef (from
  // screens), which does not implement Ref the way an @riverpod function's
  // Ref does — going through the already-built dashboardActiveCurriculaProvider
  // avoids that mismatch and reuses the same resolution dashboard_providers.dart
  // itself uses.
  final activeCurricula = await ref.read(dashboardActiveCurriculaProvider.future);
  for (final c in activeCurricula) {
    ref.invalidate(dashboardTrackCompletionPercentageProvider(c));
    // TODO(task-19): programCalendarPositionProvider(t.id) used to also be
    // invalidated per track here — calendar_position_providers.dart is
    // itself still Drift-dependent (confirmed via dart analyze:
    // "Undefined name 'userDatabaseProvider'"), blocked on task #19.
  }
}

/// Deprecated alias for [onTrackChanged].
///
/// Prefer calling [onTrackChanged] directly. This alias is kept temporarily
/// so existing call sites (add_track_flow, track_management_body,
/// track_detail_screen) continue to compile without changes.
@Deprecated('Use onTrackChanged instead')
Future<void> invalidateAfterTrackDataChange(WidgetRef ref, int profileId) =>
    onTrackChanged(ref, profileId);

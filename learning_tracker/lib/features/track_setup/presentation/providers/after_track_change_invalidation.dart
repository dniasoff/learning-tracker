import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/program_calendar_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/track_progress_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/track_setup/presentation/providers/track_management_providers.dart';

/// Call after a track is created, archived, or otherwise changed in a way that
/// should refresh dashboard, scheduler, and program placement.
///
/// [Daily plans are snapshotted once per local day]. Adding a track does not
/// change the active-curriculum guard in [allDailyTasks] (same curriculum can
/// already be active), so the frozen snapshot would otherwise miss the new
/// track until the next day — we clear **today’s** plan rows for [profileId]
/// so the next read rebuilds the task list.
Future<void> invalidateAfterTrackDataChange(
  WidgetRef ref,
  int profileId,
) async {
  final now = ref.read(clockProvider);
  final planDate = DateUtils.extractLocalDate(now);
  final db = ref.read(userDatabaseProvider);

  // Rebuild track lists first so dashboard/hub show the new row without waiting
  // on daily-plan deletion and the broad invalidation sweep below.
  ref.invalidate(dashboardActiveTracksStreamProvider);
  ref.invalidate(activeTracksProvider);

  await db.dailyPlanDao.deletePlanForDay(
    profileId: profileId,
    planDate: planDate,
  );

  ref.invalidate(allDailyTasksProvider);
  ref.invalidate(dashboardActiveCurriculaStreamProvider);
  ref.invalidate(trackDualProgressMetricsProvider(profileId));
  ref.invalidate(dashboardChildNextRewardProvider);
  ref.invalidate(dashboardStreakProvider);
  ref.invalidate(dashboardGlobalPointsProvider);
  ref.invalidate(lifetimeTotalsAcrossAllCurriculaProvider(profileId));
  ref.invalidate(globalLifetimeCurriculaProvider(profileId));

  for (final c in CurriculumId.values) {
    ref.invalidate(dashboardCompletionPercentageProvider(c));
    ref.invalidate(dashboardLastCompletionProvider(c));
    ref.invalidate(dashboardPaceStatusProvider(c));
    ref.invalidate(dashboardHasProgramEnrollmentProvider(c));
    ref.invalidate(scopedCurriculumContentProvider(c));
    ref.invalidate(scopedItemCountProvider(c));
    ref.invalidate(curriculumScopeSummaryProvider(c));
  }

  final tracks = await db.trackDao.getActiveTracksForProfile(profileId);
  for (final t in tracks) {
    ref.invalidate(dashboardTrackCompletionPercentageProvider(t.id));
    ref.invalidate(programCalendarPositionProvider(t.id));
    ref.invalidate(trackProgressProvider(t.id));
  }
}

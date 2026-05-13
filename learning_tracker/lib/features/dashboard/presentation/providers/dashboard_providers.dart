import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/learning/completion_writer_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/services/cross_curriculum_aggregator.dart';
import 'package:learning_tracker/core/streak/streak_state_provider.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/models/streak_recovery_info.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/services/pace_calculator.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_providers.g.dart';

/// Closest upcoming reward milestone for the child dashboard mystery card.
class DashboardChildNextReward {
  const DashboardChildNextReward({
    required this.trackId,
    required this.trackPoints,
    required this.threshold,
    required this.title,
    this.isGlobal = false,
  });

  final int trackId;

  /// Progress numerator: per-track points or global total when [isGlobal].
  final int trackPoints;
  final int threshold;
  final String title;
  final bool isGlobal;
}

/// Provider for the CrossCurriculumAggregator instance.
@riverpod
CrossCurriculumAggregator crossCurriculumAggregator(Ref ref) {
  return CrossCurriculumAggregator();
}

/// Provider for the active profile's user mode, resolved from the
/// [Profiles] table.
///
/// Defaults to [UserMode.adult] if no profile row is found. This is what
/// gates child-only gamification UI (points, streaks, celebrations).
@riverpod
Future<UserMode> dashboardUserMode(Ref ref) async {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final profile = await db.profileDao.getProfileById(profileId);
  if (profile == null) return UserMode.adult;
  return profile.mode == 'child' ? UserMode.child : UserMode.adult;
}

/// Provider for list of active curricula IDs, scoped to active profile.
@riverpod
Future<List<CurriculumId>> dashboardActiveCurricula(Ref ref) async {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final storageKeys = await db.activeCurriculumDao.getActiveCurriculaByProfile(
    profileId,
  );
  return storageKeys
      .map<CurriculumId?>((key) {
        final matches = CurriculumId.values.where((c) => c.storageKey == key);
        return matches.isNotEmpty ? matches.first : null;
      })
      .whereType<CurriculumId>()
      .toList();
}

/// Stream provider for watching active curricula changes, scoped to active profile.
@riverpod
Stream<List<CurriculumId>> dashboardActiveCurriculaStream(Ref ref) {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return db.activeCurriculumDao.watchActiveCurriculaByProfile(profileId).map((
    storageKeys,
  ) {
    return storageKeys
        .map<CurriculumId?>((key) {
          final matches = CurriculumId.values.where((c) => c.storageKey == key);
          return matches.isNotEmpty ? matches.first : null;
        })
        .whereType<CurriculumId>()
        .toList();
  });
}

/// Stage-based completion for one track (same denominator as
/// [dashboardCompletionPercentage] for the curriculum, completions from this track only).
@riverpod
Future<double> dashboardTrackCompletionPercentage(Ref ref, int trackId) async {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final track = await db.trackDao.getTrackById(trackId);
  if (track == null) return 0.0;
  final curriculum = CurriculumId.values.firstWhere(
    (c) => c.storageKey == track.curriculumId,
    orElse: () => CurriculumId.mishnayos,
  );
  final completions = await db.completionDao.getCompletionsByTrackAndProfile(
    trackId,
    profileId,
  );
  final stages = await db.stageDao.getStageDefinitionsByCurriculum(
    curriculum.storageKey,
  );
  if (stages.isEmpty) return 0.0;
  final totalItems = await ref.watch(
    scopedItemCountProvider(curriculum).future,
  );
  final denominator = totalItems * stages.length;
  if (denominator == 0) return 0.0;
  return (completions.length / denominator).clamp(0.0, 1.0);
}

/// Per-curriculum completion percentage, scoped to active profile.
///
/// Formula: `completions.length / (totalLeafItems * totalStages)`.
/// Every stage completion nudges the bar, and the denominator is the
/// scoped total leaf items (not items touched) so the bar never regresses
/// when a new item is started.
@riverpod
Future<double> dashboardCompletionPercentage(
  Ref ref,
  CurriculumId curriculum,
) async {
  ref.watch<int>(completionCommittedProvider);
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final completions = await db.completionDao
      .getCompletionsByCurriculumAndProfile(curriculum.storageKey, profileId);
  final stages = await db.stageDao.getStageDefinitionsByCurriculum(
    curriculum.storageKey,
  );
  if (stages.isEmpty) return 0.0;

  final totalItems = await ref.watch(
    scopedItemCountProvider(curriculum).future,
  );
  final denominator = totalItems * stages.length;
  if (denominator == 0) return 0.0;

  return (completions.length / denominator).clamp(0.0, 1.0);
}

/// Per-curriculum last completion timestamp, scoped to active profile.
@riverpod
Future<DateTime?> dashboardLastCompletion(
  Ref ref,
  CurriculumId curriculum,
) async {
  ref.watch<int>(completionCommittedProvider);
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final completions = await db.completionDao
      .getCompletionsByCurriculumAndProfile(curriculum.storageKey, profileId);
  if (completions.isEmpty) return null;
  // Completions are returned in insertion order; find the latest
  var latest = completions.first.completedAt;
  for (final c in completions) {
    if (c.completedAt.isAfter(latest)) latest = c.completedAt;
  }
  return latest;
}

/// Streak data provider, scoped to the active profile.
///
/// Reads streak state through `core/streak/StreakStateProvider` — the
/// only read path post-DNI-337. The provider replays the append-only
/// `streak_events` log through `StreakReducer` (UTC day boundaries),
/// restoring from `completions` on a new-device empty-log first launch.
@riverpod
Stream<({int currentStreak, int maxStreak})> dashboardStreak(Ref ref) async* {
  ref.watch<int>(completionCommittedProvider);
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final stateProvider = StreakStateProvider(
    db: db,
    clock: const SystemLocalDayClock(),
  );
  yield* stateProvider
      .watch(profileId: profileId)
      .map(
        (state) =>
            (currentStreak: state.currentStreak, maxStreak: state.maxStreak),
      );
}

/// Global points total, scoped to active profile.
///
/// Only completions on reward-eligible tracks (programmed or self-paced with a
/// goal); excludes onboarding bulk prior marks and browse-only tracks.
@riverpod
Future<int> dashboardGlobalPoints(Ref ref) async {
  ref.watch<int>(completionCommittedProvider);
  final userMode = ref.watch(dashboardUserModeProvider).asData?.value;
  if (userMode != UserMode.child) return 0;

  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final service = PointsService(db, profileId: profileId);
  return service.getGlobalTotal();
}

/// Next reward milestone for the child dashboard (closest threshold not yet met).
@riverpod
Future<DashboardChildNextReward?> dashboardChildNextReward(Ref ref) async {
  ref.watch<int>(completionCommittedProvider);
  final userMode = ref.watch(dashboardUserModeProvider).asData?.value;
  if (userMode != UserMode.child) return null;

  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final service = RewardMilestoneService(db, profileId: profileId);

  if (await service.stripStockTemplateMilestones()) {
    await ref.read(syncEngineProvider)?.pushGamificationSettingsSnapshot();
  }

  final tracks = await db.trackDao.getActiveTracksForProfile(profileId);

  DashboardChildNextReward? best;
  var bestGap = 1 << 30;

  void consider({
    required int trackId,
    required int progressPoints,
    required int threshold,
    required String title,
    required bool isGlobal,
  }) {
    if (progressPoints >= threshold) return;
    final gap = threshold - progressPoints;
    if (gap < bestGap) {
      bestGap = gap;
      best = DashboardChildNextReward(
        trackId: trackId,
        trackPoints: progressPoints,
        threshold: threshold,
        title: title,
        isGlobal: isGlobal,
      );
    }
  }

  for (final track in tracks) {
    final trackPoints = await service.getTrackPointsTotalForRewards(track.id);
    final milestones = await service.getMilestonesForTrack(track.id);
    for (final m in milestones) {
      if (!m.isEnabled) continue;
      consider(
        trackId: track.id,
        progressPoints: trackPoints,
        threshold: m.thresholdPoints,
        title: m.title,
        isGlobal: false,
      );
    }
  }

  final globalPoints = await service.getGlobalPointsForRewards();
  final globalMilestones = await service.getGlobalMilestones();
  for (final m in globalMilestones) {
    if (!m.isEnabled) continue;
    consider(
      trackId: RewardMilestone.kGlobalTrackSentinel,
      progressPoints: globalPoints,
      threshold: m.thresholdPoints,
      title: m.title,
      isGlobal: true,
    );
  }

  return best;
}

/// Streak recovery info — whether the streak was just saved by grace period.
@riverpod
Future<StreakRecoveryInfo> dashboardStreakRecovery(Ref ref) async {
  final userMode = ref.watch(dashboardUserModeProvider).asData?.value;
  if (userMode != UserMode.child) {
    return const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0);
  }

  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final streakService = StreakService(db, profileId: profileId);
  return streakService.getRecoveryInfo();
}

/// Per-curriculum pace status for the dashboard.
///
/// Fetches goal data and computes pace internally so the dashboard
/// doesn't need to know goal details.
@riverpod
Future<PaceStatus?> dashboardPaceStatus(
  Ref ref,
  CurriculumId curriculum,
) async {
  ref.watch<int>(completionCommittedProvider);
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final now = ref.watch(clockProvider);

  final goals = await db.goalDao.getGoalsByCurriculumAndProfile(
    curriculum.storageKey,
    profileId,
  );
  if (goals.isEmpty) return null;

  final goal = goals.first;

  // Get personal-track completions for daily counts
  final allCompletions = await db.completionDao
      .getCompletionsByCurriculumAndProfile(curriculum.storageKey, profileId);
  final personalCompletions = allCompletions
      .where((c) => c.trackType == TrackType.personal.storageKey)
      .toList();

  final dailyCounts = <DateTime, int>{};
  for (final c in personalCompletions) {
    final date = DateTime.utc(
      c.completedAt.year,
      c.completedAt.month,
      c.completedAt.day,
    );
    dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
  }

  // Real total-item count from the scoped content tree (DNI-345).
  final totalItems = await ref.watch(
    scopedItemCountProvider(curriculum).future,
  );

  // Pace-based goal
  if (goal.goalType == 'pace' &&
      goal.paceValue != null &&
      goal.paceUnit != null) {
    final dailyRate = PaceCalculator.paceToDaily(
      goal.paceValue!,
      goal.paceUnit!,
    );
    return PaceCalculator.calculateForPaceGoal(
      targetPacePerDay: dailyRate,
      totalItems: totalItems,
      completedItems: personalCompletions.length,
      dailyCompletionCounts: dailyCounts,
      today: now,
    );
  }

  // Deadline-based goal
  if (goal.targetDate == null) return null;

  return PaceCalculator.calculate(
    goalStartDate: goal.createdAt,
    goalDeadline: goal.targetDate!,
    totalItems: totalItems,
    completedItems: personalCompletions.length,
    dailyCompletionCounts: dailyCounts,
    today: now,
  );
}

/// Whether the active profile has a programmed enrollment for a curriculum.
final dashboardHasProgramEnrollmentProvider = FutureProvider.autoDispose
    .family<bool, CurriculumId>((ref, curriculum) async {
      final db = ref.watch(userDatabaseProvider);
      final profileId = ref.watch(activeProfileIdProvider);
      final enrollment = await db.profileProgramDao
          .getProgramForProfileAndCurriculum(profileId, curriculum.storageKey);
      return enrollment != null;
    });

/// Active (non-archived) profile tracks for the dashboard carousel.
///
/// Implemented as a hand-written [StreamProvider] because
/// [CurriculumTrack] (Drift) is not supported as an `@riverpod` return type.
final dashboardActiveTracksStreamProvider =
    StreamProvider.autoDispose<List<CurriculumTrack>>((ref) {
      final db = ref.watch(userDatabaseProvider);
      final profileId = ref.watch(activeProfileIdProvider);
      return db.trackDao.watchActiveTracksForProfile(profileId);
    });

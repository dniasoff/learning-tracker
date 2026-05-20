import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/services/cross_curriculum_aggregator.dart';
import 'package:learning_tracker/core/streak/streak_state_provider.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/core/utils/pace_derivation.dart';
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
import 'package:learning_tracker/features/stages/presentation/providers/stage_providers.dart';
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

/// Item-based completion for one track.
///
/// An item is "done" when ALL of the track's required stages have a
/// completion record for it.  Required stages = every non-superseded
/// stage defined for the track (stageOrder 1 = learn, 2+ = chazara).
///
/// Formula: `(items where all required stages are done) / totalItems`.
@riverpod
Future<double> dashboardTrackCompletionPercentage(Ref ref, int trackId) async {
  ref.watch<int>(completionCommittedProvider);
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final track = await db.trackDao.getTrackById(trackId);
  if (track == null) return 0.0;
  final curriculum = CurriculumId.values
      .where((c) => c.storageKey == track.curriculumId)
      .firstOrNull;
  if (curriculum == null) {
    AppLogger.instance.warning(
      'dashboardTrackCompletionPercentage: unknown curriculumId '
      '"${track.curriculumId}" for track $trackId — skipping',
    );
    return 0.0;
  }
  final stageRepository = ref.watch(globalStageRepositoryProvider);
  final stages = await stageRepository.getStagesByTrack(trackId);
  if (stages.isEmpty) return 0.0;
  // Use stageOrder (1 = learn, 2 = chazara 1, …) — the value stored in
  // completion_events.stageId — NOT the stage definition's database primary key.
  final requiredStageIds = stages.map((s) => s.stageOrder).toSet();

  final completions = await db.completionDao.getCompletionsByTrackAndProfile(
    trackId,
    profileId,
  );

  // Build a map of sefariaRef → set of completed stageIds for this track.
  final completedStagesByRef = <String, Set<int>>{};
  for (final c in completions) {
    completedStagesByRef.putIfAbsent(c.sefariaRef, () => {}).add(c.stageId);
  }

  // Count items where every required stage has a completion record.
  final doneItems = completedStagesByRef.values
      .where((doneStages) => requiredStageIds.every(doneStages.contains))
      .length;

  final totalItems = await ref.watch(
    scopedItemCountProvider(curriculum).future,
  );
  if (totalItems == 0) return 0.0;
  return (doneItems / totalItems).clamp(0.0, 1.0);
}

/// Per-curriculum item-based completion percentage, scoped to active profile.
///
/// An item (sefariaRef) is "done" when every required stage for its track has
/// a completion record.  Required stages = the non-superseded stages defined
/// for that track.  An item that is fully done in any of its tracks counts
/// once toward the numerator.
///
/// Formula: `(distinct sefariaRefs fully done in any track) / totalLeafItems`.
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

  final totalItems = await ref.watch(
    scopedItemCountProvider(curriculum).future,
  );
  if (totalItems == 0) return 0.0;
  if (completions.isEmpty) return 0.0;

  // Group completed stageIds by (trackId → sefariaRef → Set<stageId>).
  final byTrack = <int, Map<String, Set<int>>>{};
  for (final c in completions) {
    byTrack
        .putIfAbsent(c.trackId, () => {})
        .putIfAbsent(c.sefariaRef, () => {})
        .add(c.stageId);
  }

  // Fetch required stages for each track encountered, then count done items.
  final stageRepository = ref.watch(globalStageRepositoryProvider);
  final doneRefs = <String>{};
  for (final entry in byTrack.entries) {
    final trackId = entry.key;
    final refStages = entry.value;
    if (trackId == 0) continue; // bulk-mark sentinel — skip
    final stages = await stageRepository.getStagesByTrack(trackId);
    if (stages.isEmpty) {
      AppLogger.instance.warning(
        'dashboardCompletionPercentage: no stages for curriculum '
        '${curriculum.storageKey}, skipping — track may be misconfigured',
      );
      continue;
    }
    // Use stageOrder (1 = learn, 2 = chazara 1, …) — the value stored in
    // completion_events.stageId — NOT the stage definition's database primary key.
    final requiredStageIds = stages.map((s) => s.stageOrder).toSet();
    for (final refEntry in refStages.entries) {
      if (requiredStageIds.every(refEntry.value.contains)) {
        doneRefs.add(refEntry.key);
      }
    }
  }

  return (doneRefs.length / totalItems).clamp(0.0, 1.0);
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
///
/// Performance note: `completionCommittedProvider` is intentionally NOT
/// watched here. [CompletionRepositoryImpl._createCompletion] writes a
/// `streak_events` row on each completion, which Drift surfaces via the
/// reactive `watch()` query below — no manual trigger needed.
/// Watching `completionCommittedProvider` would tear down and rebuild the
/// entire stream subscription on every completion, causing unnecessary
/// work on every task mark.
@riverpod
Stream<({int currentStreak, int maxStreak})> dashboardStreak(Ref ref) async* {
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

  // Pick the most recently created goal — defends against a stale row from
  // an earlier track setup outliving a re-add (the projection must reflect
  // the goal the user just set, not whichever row the DB returns first).
  final goal = goals.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);

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
      goal.pacePeriod != null) {
    final dailyRate = PaceCalculator.paceToDaily(
      goal.paceValue!,
      goal.pacePeriod!,
    );
    return PaceCalculator.calculateForPaceGoal(
      targetPacePerDay: dailyRate,
      totalItems: totalItems,
      completedItems: personalCompletions.length,
      dailyCompletionCounts: dailyCounts,
      today: now,
    );
  }

  // Deadline-based goal. A deadline goal ALWAYS yields a projection: prefer
  // the explicit pace the wizard stored, otherwise derive one from the
  // deadline + scope + study-day density. `calculateForPaceGoal` projects
  // deterministically from the target pace (no completion history needed),
  // so "No projection" can never appear for a track that has a deadline —
  // unlike `PaceCalculator.calculate`, whose rolling-average projection is
  // null on day one.
  if (goal.targetDate == null) return null;

  var paceValue = goal.paceValue;
  var pacePeriod = goal.pacePeriod;
  if (paceValue == null || pacePeriod == null) {
    final start = DateUtils.extractLocalDate(now);
    final end = DateUtils.extractLocalDate(goal.targetDate!.toLocal());
    final studyDaysInWindow = end.isBefore(start)
        ? 0
        : await db.studyDayConfigDao.countStudyDaysInInclusiveDateRangeForTrack(
            trackId: goal.trackId,
            startInclusive: start,
            endInclusive: end,
          );
    final studyDaysPerWeek = await db.studyDayConfigDao
        .getStudyDaysPerWeekForTrack(trackId: goal.trackId);
    final derived = derivePaceFromDeadline(
      totalScopeItems: totalItems,
      studyDaysInWindow: studyDaysInWindow,
      studyDaysPerWeek: studyDaysPerWeek,
    );
    paceValue = derived.paceValue;
    pacePeriod = derived.pacePeriod;
  }

  final dailyRate = PaceCalculator.paceToDaily(paceValue, pacePeriod);
  return PaceCalculator.calculateForPaceGoal(
    targetPacePerDay: dailyRate,
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

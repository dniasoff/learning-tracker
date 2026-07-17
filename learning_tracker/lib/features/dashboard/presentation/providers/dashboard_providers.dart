import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/dashboard/domain/services/next_reward_selector.dart';
import 'package:learning_tracker/features/dashboard/domain/services/track_completion_service.dart';
import 'package:learning_tracker/features/dashboard/domain/use_cases/compute_pace_status_use_case.dart';
import 'package:learning_tracker/features/gamification/gamification.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tracks/domain/services/track_progress_service.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
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

/// Provider for the active profile's mode, resolved from the [LearnerProfiles]
/// table.
///
/// Defaults to [ProfileMode.adult] if no profile row is found. This is what
/// gates child-only gamification UI (points, streaks, celebrations).
///
/// WS9.enum: unified — formerly returned [UserMode]; now returns [ProfileMode]
/// directly. [UserMode] enum has been deleted.
@riverpod
Future<ProfileMode> dashboardUserMode(Ref ref) async {
  // This provider gates child-only gamification UI (points, streaks, rewards,
  // celebrations). Per the tutor product model ("a tutor sees everything the
  // child sees"), the gating must follow the ACTIVE PROFILE's mode — which in
  // a tutored session is the synthetic talmid mirror (a child). Resolving via
  // [activeProfileIdProvider] therefore yields:
  //   - own adult profile  -> adult (points hidden)
  //   - own child profile   -> child (points shown)
  //   - tutored child mirror -> child (talmid's points/rewards shown to tutor)
  // Management access (parent portal, adjust points) is gated independently by
  // route/PIN guards, so showing the child's gamification UI here does NOT
  // grant or revoke any management capability.
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final profile = await db.profileDao.getProfileById(profileId);
  if (profile == null) return ProfileMode.adult;
  return ProfileMode.fromStorageKey(profile.mode);
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

/// Track completion percentage for the Manage Tracks card.
///
/// Uses [CompletionTierFilter.trackAchievement] (live + bulkInTrack) — matching
/// the "I learnt it" intent of the Manage Tracks display. Lifetime-only imports
/// are excluded because they do not represent in-track learning activity.
///
/// An item is "done" when ALL of the track's required stages have a
/// completion record.  Formula: `(done items) / totalItems`.
///
/// Delegates computation to [TrackProgressService] (Layer 3 unification).
///
/// **Why this differs from [trackDualProgressMetricsProvider].currentCyclePercentage:**
/// This answers "how complete is this track overall?" (all-time, multi-stage gate).
/// The cycle metric answers "how many items has the user touched since the last
/// track activation?" (time-gated, single-ref check).
///
/// See also: [trackDualProgressMetricsProvider] (lifetime_knowledge_providers.dart).
@riverpod
Future<double> dashboardTrackCompletionPercentage(Ref ref, int trackId) async {
  ref.watch<int>(completionCommittedProvider);
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final service = ref.watch(trackProgressServiceProvider);
  final track = await db.trackDao.getTrackById(trackId);
  // Guard: this autoDispose provider may have been disposed during the async
  // gap above (e.g. the user swiped the active-tracks carousel past this
  // card, or left the dashboard mid-load) — see dashboardChildNextReward's
  // identical guard (SM-4, AUD-dashboard-06).
  if (!ref.mounted) return 0.0;
  if (track == null) return 0.0;
  final curriculum = CurriculumId.values
      .where((c) => c.storageKey == track.curriculumId)
      .firstOrNull;
  if (curriculum == null) {
    AppLogger.instance.warning(
      event:
          'dashboardTrackCompletionPercentage: unknown curriculumId '
          '"${track.curriculumId}" for track $trackId — skipping',
    );
    return 0.0;
  }
  final totalItems = await ref.watch(
    scopedItemCountProvider(curriculum).future,
  );
  return service.completionPercent(
    trackId: trackId,
    profileId: profileId,
    tier: CompletionTierFilter.trackAchievement,
    totalItems: totalItems,
  );
}

/// Per-curriculum item-based completion percentage, scoped to active profile.
///
/// An item (sefariaRef) is "done" when every required stage for its track has
/// a completion record.  Required stages = the non-superseded stages defined
/// for that track.  An item that is fully done in any of its tracks counts
/// once toward the numerator.
///
/// Formula: `(distinct sefariaRefs fully done in any track) / totalLeafItems`.
///
/// Delegates computation to [TrackCompletionService].
@riverpod
Future<double> dashboardCompletionPercentage(
  Ref ref,
  CurriculumId curriculum,
) async {
  ref.watch<int>(completionCommittedProvider);
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final stageRepository = ref.watch(globalStageRepositoryProvider);

  final completions = await db.completionDao
      .getCompletionsByCurriculumAndProfile(curriculum.storageKey, profileId);
  // Guard: this autoDispose provider may have been disposed during the async
  // gap above (e.g. the user navigated away from the dashboard mid-load) —
  // see dashboardChildNextReward's identical guard (SM-4, AUD-dashboard-06).
  if (!ref.mounted) return 0.0;

  final totalItems = await ref.watch(
    scopedItemCountProvider(curriculum).future,
  );
  if (totalItems == 0) return 0.0;
  if (completions.isEmpty) return 0.0;

  // Group completions by trackId.
  final completionsByTrack = <int, List<Completion>>{};
  for (final c in completions) {
    completionsByTrack.putIfAbsent(c.trackId, () => []).add(c);
  }

  // Fetch required stages for each track encountered.
  final byTrack = <int, TrackEntry>{};
  for (final trackId in completionsByTrack.keys) {
    if (trackId == 0) continue; // bulk-mark sentinel — skip
    final stages = await stageRepository.getStagesByTrack(trackId);
    if (stages.isEmpty) {
      AppLogger.instance.warning(
        event:
            'dashboardCompletionPercentage: no stages for curriculum '
            '${curriculum.storageKey}, skipping — track may be misconfigured',
      );
      continue;
    }
    byTrack[trackId] = TrackEntry(
      stages: stages,
      completions: completionsByTrack[trackId]!,
    );
  }

  const service = TrackCompletionService();
  return service.computeCurriculumPercentage(
    byTrack: byTrack,
    totalItems: totalItems,
  );
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
/// Reads streak state through `core/streak/StreakStateService` — the
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
  final profileId = ref.watch(activeProfileIdProvider);
  final stateProvider = ref.watch(streakStateProvider);
  yield* stateProvider
      .watch(profileId: profileId)
      .map(
        (state) =>
            (currentStreak: state.currentStreak, maxStreak: state.maxStreak),
      );
}

/// Stored debitable points balance, scoped to active child profile (WS7.balance).
///
/// Reads from [PointsBalanceDao] — the spend-economy source of truth (DEC-32).
/// Returns 0 for adult profiles (Rule 3: adults have no points).
@riverpod
Stream<int> dashboardGlobalPoints(Ref ref) async* {
  // Establish sync dependencies before the async gap (Riverpod: no ref.watch
  // after await).
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  // Await the resolved mode via `.future` (does NOT rebuild on loading→data,
  // unlike watching the AsyncValue — avoids a premature stream that gets
  // disposed mid-load).
  final userMode = await ref.watch(dashboardUserModeProvider.future);
  if (userMode != ProfileMode.child) {
    yield 0; // adults have no points (product rule)
    return;
  }
  // Reactive stream (watchBalance), NOT a one-shot getBalance future: the
  // dashboard star counter must reflect EVERY balance mutation — completion
  // credits, redemption debits, and parent decline-refunds — without waiting
  // for a pull-to-refresh. Previously a Future<int> that only re-ran on
  // completionCommittedProvider / pull-to-refresh, so a redemption debit (or
  // refund) left the counter STALE while the dashboard stayed mounted under
  // the pushed redemption route (D2, on-device F8). watchBalance emits the
  // current balance on subscribe and on every PointsBalance row change.
  yield* db.pointsBalanceDao.watchBalance(profileId);
}

/// Write-path effect: strips legacy stock-template milestones for the current
/// profile and pushes updated gamification settings to Firestore if any rows
/// were removed.
///
/// This is intentionally separate from the read providers below so that a
/// mutation (delete + cloud push) never runs inside a provider that is
/// re-evaluated on every widget rebuild.  Callers that depend on the post-strip
/// state should watch this provider to ensure it completes before reading
/// milestone data.
@riverpod
Future<void> stripStockMilestonesEffect(Ref ref) async {
  final milestoneService = ref.watch(rewardMilestoneServiceProvider);

  final stripped = await milestoneService.stripStockTemplateMilestones();
  // Guard: this autoDispose provider may have been disposed during the async
  // gap above (e.g. the user navigated away before the strip completed) —
  // see dashboardChildNextReward's identical guard (SM-4, AUD-dashboard-06).
  if (!ref.mounted) return;
  if (stripped) {
    await ref.read(syncWriteFacadeProvider)?.pushGamificationSettingsSnapshot();
  }
}

/// Next reward milestone for the child dashboard (closest threshold not yet met).
///
/// Delegates selection to [NextRewardSelector].
@riverpod
Future<DashboardChildNextReward?> dashboardChildNextReward(Ref ref) async {
  ref.watch<int>(completionCommittedProvider);
  final userMode = ref.watch(dashboardUserModeProvider).asData?.value;
  if (userMode != ProfileMode.child) return null;

  // Ensure stock template milestones are purged before reading reward state.
  // The actual strip + cloud push runs in [stripStockMilestonesEffectProvider]
  // (a separate write-path provider) so this read provider stays side-effect-free.
  await ref.watch(stripStockMilestonesEffectProvider.future);

  // Guard: if this autoDispose provider was disposed during the async gap above
  // (e.g. user navigated away), the subsequent ref.watch calls would throw.
  if (!ref.mounted) return null;

  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final milestoneService = ref.watch(rewardMilestoneServiceProvider);

  final tracks = await db.trackDao.getActiveTracksForProfile(profileId);

  // Build track entries for the selector.
  final trackEntries = <TrackMilestoneEntry>[];
  for (final track in tracks) {
    final points = await milestoneService.getTrackPointsTotalForRewards(
      track.id,
    );
    final milestones = await milestoneService.getMilestonesForTrack(track.id);
    trackEntries.add(
      TrackMilestoneEntry(
        trackId: track.id,
        points: points,
        milestones: milestones,
      ),
    );
  }

  final globalPoints = await milestoneService.getGlobalPointsForRewards();
  final globalMilestones = await milestoneService.getGlobalMilestones();

  const selector = NextRewardSelector();
  final result = selector.select(
    trackEntries: trackEntries,
    globalPoints: globalPoints,
    globalMilestones: globalMilestones,
  );
  if (result == null) return null;

  return DashboardChildNextReward(
    trackId: result.trackId,
    trackPoints: result.trackPoints,
    threshold: result.threshold,
    title: result.title,
    isGlobal: result.isGlobal,
  );
}

/// Streak recovery info — whether the streak was just saved by grace period.
@riverpod
Future<StreakRecoveryInfo> dashboardStreakRecovery(Ref ref) async {
  final userMode = ref.watch(dashboardUserModeProvider).asData?.value;
  if (userMode != ProfileMode.child) {
    return const StreakRecoveryInfo(wasRecovered: false, currentStreak: 0);
  }

  final streakService = ref.watch(streakServiceProvider);
  return streakService.getRecoveryInfo();
}

/// Per-curriculum pace status for the dashboard.
///
/// Fetches goal data and computes pace internally so the dashboard
/// doesn't need to know goal details.
///
/// Delegates computation to [ComputePaceStatusUseCase].
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

  // Rule-7 (no track types): all tracks are implicitly personal now, so the
  // `trackType == personal` filter was a no-op that could wrongly drop rows.
  // Use every completion for the daily counts.
  final allCompletions = await db.completionDao
      .getCompletionsByCurriculumAndProfile(curriculum.storageKey, profileId);

  final dailyCounts = ComputePaceStatusUseCase.buildDailyCounts(
    allCompletions.map((c) => c.completedAt),
  );

  // Guard: this autoDispose provider may have been disposed during the async
  // gap above (e.g. the user navigated away from the dashboard mid-load) —
  // see dashboardChildNextReward's identical guard (SM-4, AUD-dashboard-06).
  if (!ref.mounted) return null;

  // Real total-item count from the scoped content tree (DNI-345).
  final totalItems = await ref.watch(
    scopedItemCountProvider(curriculum).future,
  );

  // Reconstruct PaceTarget from the raw Drift Goal row.
  final PaceTarget? paceTarget;
  if (goal.goalType == 'deadline' && goal.targetDate != null) {
    paceTarget = DeadlineTarget(goal.targetDate!.toUtc());
  } else if (goal.goalType == 'pace' &&
      goal.paceValue != null &&
      goal.pacePeriod != null) {
    paceTarget = PacePeriodTarget(
      rate: goal.paceValue!,
      period: goal.pacePeriod!,
    );
  } else {
    paceTarget = null;
  }

  // Resolve study-day counts for deadline goals (pace always derived from
  // scope + study-day density — see ComputePaceStatusUseCase).
  int? studyDaysInWindow;
  int? studyDaysPerWeek;
  if (paceTarget is DeadlineTarget) {
    final start = LocalDayUtils.extractLocalDate(now);
    final end = LocalDayUtils.extractLocalDate(paceTarget.dueDate.toLocal());
    studyDaysInWindow = end.isBefore(start)
        ? 0
        : await db.studyDayConfigDao.countStudyDaysInInclusiveDateRangeForTrack(
            trackId: goal.trackId,
            startInclusive: start,
            endInclusive: end,
          );
    studyDaysPerWeek = await db.studyDayConfigDao.getStudyDaysPerWeekForTrack(
      trackId: goal.trackId,
    );
  }

  const useCase = ComputePaceStatusUseCase();
  return useCase.execute(
    PaceStatusInput(
      paceTarget: paceTarget,
      completedItems: allCompletions.length,
      dailyCompletionCounts: dailyCounts,
      totalItems: totalItems,
      today: now,
      studyDaysInWindow: studyDaysInWindow,
      studyDaysPerWeek: studyDaysPerWeek,
    ),
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

/// Whether a specific track has chazara stages (stage count > 1).
///
/// A track with a single stage (learn-only / [SingleStageConfiguration])
/// returns false; any track with 2+ stages (wizard or schedule-spec chazara)
/// returns true.  Used to gate chazara UI per Rule 8.
final trackHasChazaraProvider = FutureProvider.autoDispose.family<bool, int>((
  ref,
  trackId,
) async {
  final db = ref.watch(userDatabaseProvider);
  final count = await db.stageDao.countStagesForTrack(trackId);
  return count > 1;
});

/// Whether ANY active track for the current profile has chazara enabled.
///
/// True when at least one active track has more than one stage definition.
/// Used by the dashboard to gate cross-track chazara UI (Rule 8).
final anyActiveTrackHasChazaraProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final tracks = await db.trackDao.getActiveTracksForProfile(profileId);
  for (final track in tracks) {
    final count = await db.stageDao.countStagesForTrack(track.id);
    if (count > 1) return true;
  }
  return false;
});

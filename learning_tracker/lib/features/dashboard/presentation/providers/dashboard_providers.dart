import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/dashboard/data/repositories/firestore_profile_program_reader_adapter.dart';
import 'package:learning_tracker/features/dashboard/data/repositories/firestore_study_day_reader_adapter.dart';
import 'package:learning_tracker/features/dashboard/domain/services/next_reward_selector.dart';
import 'package:learning_tracker/features/dashboard/domain/use_cases/compute_pace_status_use_case.dart';
import 'package:learning_tracker/features/gamification/gamification.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
// Cross-feature deep import (Rule 2, DNI-386) — warn-only per
// learning_tracker/CLAUDE.md ("pending legacy cleanup"), and progress.dart's
// own barrel doc comment restricts its exports to types already demonstrably
// consumed elsewhere. FirestoreChartDataRepositoryAdapter/ChartDataRepository
// have exactly one other cross-feature consumer today
// (features/tracks/presentation/providers/track_progress_providers.dart),
// which reaches them the same deep way.
import 'package:learning_tracker/features/progress/data/repositories/firestore_chart_data_repository_adapter.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/presentation/providers/track_progress_providers.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:learning_tracker/features/tracks/tracks.dart';
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

/// Provider for the active profile's mode, resolved from the profile
/// repository.
///
/// Defaults to [ProfileMode.adult] if no profile is active or found. This is
/// what gates child-only gamification UI (points, streaks, celebrations).
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
  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) return ProfileMode.adult;
  final repository = ref.watch(profileRepositoryProvider);
  final profile = await repository.getProfileById(profileId);
  if (profile == null) return ProfileMode.adult;
  return profile.mode;
}

/// Provider for list of active curricula IDs, scoped to active profile.
@riverpod
Future<List<CurriculumId>> dashboardActiveCurricula(Ref ref) async {
  final repo = FirestoreCurriculumTrackRepositoryAdapter(ref: ref);
  final storageKeys = await repo.getActiveCurriculumIds();
  return storageKeys
      .map(CurriculumId.fromStorageKey)
      .whereType<CurriculumId>()
      .toList();
}

/// Stream provider for watching active curricula changes, scoped to active profile.
@riverpod
Stream<List<CurriculumId>> dashboardActiveCurriculaStream(Ref ref) {
  final repo = FirestoreCurriculumTrackRepositoryAdapter(ref: ref);
  return repo.watchActiveCurriculumIds().map(
    (storageKeys) => storageKeys
        .map(CurriculumId.fromStorageKey)
        .whereType<CurriculumId>()
        .toList(),
  );
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
/// AD-25: one track per curriculum — [curriculumId] IS the track identity,
/// there is no separate Drift track row to resolve it from any more.
///
/// **Why this differs from [trackDualProgressMetricsProvider].currentCyclePercentage:**
/// This answers "how complete is this track overall?" (all-time, multi-stage gate).
/// The cycle metric answers "how many items has the user touched since the last
/// track activation?" (time-gated, single-ref check).
///
/// See also: [trackDualProgressMetricsProvider] (lifetime_knowledge_providers.dart).
@riverpod
Future<double> dashboardTrackCompletionPercentage(
  Ref ref,
  CurriculumId curriculumId,
) async {
  ref.watch<int>(completionCommittedProvider);
  final service = ref.watch(trackProgressServiceProvider);
  final totalItems = await ref.watch(
    scopedItemCountProvider(curriculumId).future,
  );
  // Guard: this autoDispose provider may have been disposed during the async
  // gap above (e.g. the user swiped the active-tracks carousel past this
  // card, or left the dashboard mid-load) — see dashboardChildNextReward's
  // identical guard (SM-4, AUD-dashboard-06).
  if (!ref.mounted) return 0.0;
  return service.completionPercent(
    curriculumId: curriculumId,
    tier: CompletionTierFilter.trackAchievement,
    totalItems: totalItems,
  );
}

/// Per-curriculum item-based completion percentage, scoped to active profile.
///
/// AD-25: one track per curriculum, so this is now identical to
/// [dashboardTrackCompletionPercentage] — both delegate to the same
/// [TrackProgressService] (Layer 3 unification). Kept as a separate provider
/// because callers ask two conceptually different questions today even
/// though the answer is computed the same way.
@riverpod
Future<double> dashboardCompletionPercentage(
  Ref ref,
  CurriculumId curriculum,
) async {
  ref.watch<int>(completionCommittedProvider);
  final service = ref.watch(trackProgressServiceProvider);
  final totalItems = await ref.watch(
    scopedItemCountProvider(curriculum).future,
  );
  // Guard: this autoDispose provider may have been disposed during the async
  // gap above (e.g. the user navigated away from the dashboard mid-load) —
  // see dashboardChildNextReward's identical guard (SM-4, AUD-dashboard-06).
  if (!ref.mounted) return 0.0;
  return service.completionPercent(
    curriculumId: curriculum,
    tier: CompletionTierFilter.trackAchievement,
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
  final repository = FirestoreChartDataRepositoryAdapter(ref: ref);
  final completions = await repository.getCompletionsByTier(
    tier: CompletionTierFilter.trackAchievement,
    curriculumId: curriculum,
  );
  if (completions.isEmpty) return null;
  var latest = completions.first.completedAt;
  for (final c in completions) {
    if (c.completedAt.isAfter(latest)) latest = c.completedAt;
  }
  return latest;
}

/// Streak data provider, scoped to the active profile.
///
/// Reads streak state through [StreakStateService] — the only read path.
/// [StreakStateService] delegates to [FirestoreStreakStateRepository], which
/// derives state from the synced Firestore event log directly (D-E: throws
/// when the backend isn't ready rather than returning a fabricated zero
/// streak).
@riverpod
Stream<({int currentStreak, int maxStreak})> dashboardStreak(Ref ref) async* {
  final stateProvider = ref.watch(streakStateProvider);
  yield* stateProvider.watch().map(
    (state) => (currentStreak: state.currentStreak, maxStreak: state.maxStreak),
  );
}

/// Stored debitable points balance, scoped to active child profile (WS7.balance).
///
/// Reads from [FirestorePointsBalanceReaderAdapter] — the spend-economy
/// source of truth (DEC-32). Returns 0 for adult profiles (Rule 3: adults
/// have no points).
///
/// **Not a live stream, unlike the Drift-era `watchBalance`.** No Firestore
/// equivalent exists or can cheaply exist: `firestore.rules` caps every
/// `points_ledger` list/query at `request.query.limit <= 500` (SR-4), so an
/// unbounded `.snapshots()` listener over the whole ledger is rejected by
/// the security rules outright — there is no single-listener way to watch
/// an arbitrarily-long append-only ledger's derived sum live. This re-reads
/// the balance whenever [completionCommittedProvider] fires (the dominant
/// mutation path today) or an explicit `ref.invalidate` fires (see
/// `dashboard_screen.dart`, `progress_screen.dart`,
/// `after_track_change_invalidation.dart`). A redemption debit/refund or a
/// parent points adjustment that doesn't itself invalidate this provider
/// will leave the counter stale until one of those does — a real,
/// disclosed regression from the Drift-era live stream, tracked rather than
/// silently accepted (see the phase's task list — the redemption write
/// path this would need to hook into does not exist in production code
/// yet either).
@riverpod
Future<int> dashboardGlobalPoints(Ref ref) async {
  ref.watch<int>(completionCommittedProvider);
  // Await the resolved mode via `.future` (does NOT rebuild on loading→data,
  // unlike watching the AsyncValue — avoids a premature read that gets
  // disposed mid-load).
  final userMode = await ref.watch(dashboardUserModeProvider.future);
  if (userMode != ProfileMode.child) {
    return 0; // adults have no points (product rule)
  }
  final reader = FirestorePointsBalanceReaderAdapter(ref: ref);
  return reader.getBalance();
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

  await milestoneService.stripStockTemplateMilestones();
  // Guard: this autoDispose provider may have been disposed during the async
  // gap above (e.g. the user navigated away before the strip completed) —
  // see dashboardChildNextReward's identical guard (SM-4, AUD-dashboard-06).
  if (!ref.mounted) return;
  // TODO(gamification-settings-sync): the strip above is a local
  // (SharedPreferences) write only — it used to also push a cloud snapshot
  // via the now-archived SyncWriteFacade (lib/core/database + lib/features/
  // sync were deliberately deleted wholesale, commit 04897ebc; see
  // docs/planning task tracker #22). RewardMilestoneService has no
  // Firestore mirror yet, so a stripped stock milestone stays local-only
  // until a real (non-outbox) settings-sync replacement is built — a real,
  // disclosed gap, not silently dropped.
}

/// Next reward milestone for the child dashboard (closest threshold not yet met).
///
/// Delegates selection to [NextRewardSelector].
///
/// DEC-32/GA-3: per-track rewards were removed from the spend economy —
/// every reward is now a single global priced spend-item, so [trackEntries]
/// is always empty. [NextRewardSelector.select] already handles that
/// gracefully (falls straight through to the global ladder); see its own
/// doc comment.
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

  final milestoneService = ref.watch(rewardMilestoneServiceProvider);

  final globalPoints = await milestoneService
      .getGlobalLifetimeEarnedForRewards();
  final globalMilestones = await milestoneService.getMilestones();

  const selector = NextRewardSelector();
  final result = selector.select(
    trackEntries: const [],
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
  final now = ref.watch(clockProvider);

  final goalRepo = FirestoreGoalRepositoryAdapter(ref: ref);
  final goals = await goalRepo.getGoals(curriculum);
  if (goals.isEmpty) return null;

  // Pick the most recently created goal — defends against a stale row from
  // an earlier track setup outliving a re-add (the projection must reflect
  // the goal the user just set, not whichever row the repository returns
  // first).
  final goal = goals.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);

  final chartData = FirestoreChartDataRepositoryAdapter(ref: ref);
  final allCompletions = await chartData.getCompletionsByTier(
    tier: CompletionTierFilter.trackAchievement,
    curriculumId: curriculum,
  );

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

  // GoalEntity.paceTarget already reconstructs DeadlineTarget/PacePeriodTarget
  // from the raw goal fields — no need to hand-roll that here.
  final paceTarget = goal.paceTarget;

  // Resolve study-day counts for deadline goals (pace always derived from
  // scope + study-day density — see ComputePaceStatusUseCase).
  int? studyDaysInWindow;
  int? studyDaysPerWeek;
  if (paceTarget is DeadlineTarget) {
    final studyDayReader = FirestoreStudyDayReaderAdapter(ref: ref);
    final start = LocalDayUtils.extractLocalDate(now);
    final end = LocalDayUtils.extractLocalDate(paceTarget.dueDate.toLocal());
    studyDaysInWindow = end.isBefore(start)
        ? 0
        : await studyDayReader.countStudyDaysInInclusiveDateRange(
            curriculumId: curriculum,
            startInclusive: start,
            endInclusive: end,
          );
    studyDaysPerWeek = await studyDayReader.studyDaysPerWeek(curriculum);
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
      final reader = FirestoreProfileProgramReaderAdapter(ref: ref);
      return reader.hasProgram(curriculum);
    });

/// Active (non-archived) profile tracks for the dashboard carousel.
final dashboardActiveTracksStreamProvider =
    StreamProvider.autoDispose<List<CurriculumTrackEntity>>((ref) {
      final repo = FirestoreCurriculumTrackRepositoryAdapter(ref: ref);
      return repo.watchActiveTracks();
    });

/// Whether a specific track has chazara stages (stage count > 1).
///
/// A track with a single stage (learn-only / [SingleStageConfiguration])
/// returns false; any track with 2+ stages (wizard or schedule-spec chazara)
/// returns true.  Used to gate chazara UI per Rule 8.
///
/// AD-25: keyed on [CurriculumId], not an `int` track id — a curriculum
/// track has no separate id any more.
final trackHasChazaraProvider = FutureProvider.autoDispose
    .family<bool, CurriculumId>((ref, curriculumId) async {
      final stageRepo = ref.watch(globalStageRepositoryProvider);
      final stages = await stageRepo.getStagesForCurriculum(curriculumId);
      return stages.length > 1;
    });

/// Whether ANY active track for the current profile has chazara enabled.
///
/// True when at least one active track has more than one stage definition.
/// Used by the dashboard to gate cross-track chazara UI (Rule 8).
final anyActiveTrackHasChazaraProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final trackRepo = FirestoreCurriculumTrackRepositoryAdapter(ref: ref);
  final storageKeys = await trackRepo.getActiveCurriculumIds();
  final stageRepo = ref.watch(globalStageRepositoryProvider);
  for (final key in storageKeys) {
    final curriculumId = CurriculumId.fromStorageKey(key);
    if (curriculumId == null) continue;
    final stages = await stageRepo.getStagesForCurriculum(curriculumId);
    if (stages.length > 1) return true;
  }
  return false;
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/repositories/firestore_reward_settings_repository.dart';
import 'package:learning_tracker/features/dashboard/data/repositories/firestore_profile_program_reader_adapter.dart';
import 'package:learning_tracker/features/dashboard/domain/services/next_reward_selector.dart';
import 'package:learning_tracker/features/gamification/gamification.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/progress/domain/services/learner_progress.dart';
import 'package:learning_tracker/features/progress/presentation/providers/learner_progress_providers.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/presentation/providers/track_progress_providers.dart';
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
  ref.watch(curriculumTrackRepositoryReadinessProvider);
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
  ref.watch(curriculumTrackRepositoryReadinessProvider);
  final repo = FirestoreCurriculumTrackRepositoryAdapter(ref: ref);
  return repo.watchActiveCurriculumIds().map(
    (storageKeys) => storageKeys
        .map(CurriculumId.fromStorageKey)
        .whereType<CurriculumId>()
        .toList(),
  );
}

/// Track completion percentage for the Manage Tracks card (DNI-474).
///
/// Goal progress (FR-14): the engine's distinct learnt leaves of the
/// curriculum — every source and date state, repeats once — over the
/// learner's scoped leaf count. AD-25: [curriculumId] IS the track.
@riverpod
Future<double> dashboardTrackCompletionPercentage(
  Ref ref,
  CurriculumId curriculumId,
) async {
  final state = await watchActiveLearnerState(ref);
  final totalItems = await ref.watch(
    scopedItemCountProvider(curriculumId).future,
  );
  return ref
      .watch(trackProgressServiceProvider)
      .completionPercent(
        state: state,
        curriculumId: curriculumId,
        totalItems: totalItems,
      );
}

/// Per-curriculum completion percentage, scoped to the active learner.
///
/// AD-25: one track per curriculum, so this is the same engine number as
/// [dashboardTrackCompletionPercentage]; kept as a separate provider
/// because callers ask two conceptually different questions.
@riverpod
Future<double> dashboardCompletionPercentage(
  Ref ref,
  CurriculumId curriculum,
) async {
  final state = await watchActiveLearnerState(ref);
  final totalItems = await ref.watch(
    scopedItemCountProvider(curriculum).future,
  );
  return ref
      .watch(trackProgressServiceProvider)
      .completionPercent(
        state: state,
        curriculumId: curriculum,
        totalItems: totalItems,
      );
}

/// The `effectiveAt` of the curriculum's latest counted learn event, from
/// the engine (DNI-474); null when nothing counts.
@riverpod
Future<DateTime?> dashboardLastCompletion(
  Ref ref,
  CurriculumId curriculum,
) async {
  final state = await watchActiveLearnerState(ref);
  return lastLearntAt(state, curricula: {curriculum.storageKey});
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
  ref.watch(activeProfileIdProvider);
  ref.watch(profileRepositoryReadinessProvider);

  final stateProvider = ref.watch(streakStateProvider);
  yield* stateProvider.watch().map(
    (state) => (currentStreak: state.currentStreak, maxStreak: state.maxStreak),
  );
}

/// Stored debitable points balance, scoped to active child profile (WS7.balance).
///
/// Reads the AD-50 filtered ledger balance ([watchActivePointsTotals],
/// DNI-480) — the spend-economy source of truth (DEC-32); it re-reads when
/// the engine's earning set changes. Returns 0 for adult profiles (Rule 3: adults
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
  return (await watchActivePointsTotals(ref)).balance;
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

  final changed = await milestoneService.stripStockTemplateMilestones();
  if (!ref.mounted) return;
  if (changed) {
    final repository = await ref.read(
      firestoreRewardSettingsRepositoryProvider.future,
    );
    if (repository != null) {
      await repository.writeRewardSettings(
        await milestoneService.exportCloudPayload(),
      );
    }
  }
  // Guard: this autoDispose provider may have been disposed during the async
  // gap above (e.g. the user navigated away before the strip completed) —
  // see dashboardChildNextReward's identical guard (SM-4, AUD-dashboard-06).
  if (!ref.mounted) return;
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

  final repository = await ref.read(
    firestoreRewardSettingsRepositoryProvider.future,
  );
  await milestoneService.mergeCloudPayload(
    await repository?.readRewardSettings(),
  );
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

/// Whether the active profile has a programmed enrollment for a curriculum.
final dashboardHasProgramEnrollmentProvider = FutureProvider.autoDispose
    .family<bool, CurriculumId>((ref, curriculum) async {
      final reader = FirestoreProfileProgramReaderAdapter(ref: ref);
      return reader.hasProgram(curriculum);
    });

/// Active (non-archived) profile tracks for the dashboard carousel.
final dashboardActiveTracksStreamProvider =
    StreamProvider.autoDispose<List<CurriculumTrackEntity>>((ref) {
      ref.watch(curriculumTrackRepositoryReadinessProvider);
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

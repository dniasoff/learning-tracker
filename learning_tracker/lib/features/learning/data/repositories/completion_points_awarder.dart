import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';

/// Firestore-backed [CompletionPointsPort] — the storage-specific implementation
/// [CompletionOrchestrator] is wired against today.
///
/// Relocated and port-forwarded from the deleted Drift-backed
/// `DriftCompletionPointsAwarder` (`docs/firestore-rewrite-map.md`, owner
/// decision 1): the Drift `UserDatabase`/`pointConfigDao`/`pointsBalanceDao`/
/// `profileDao`/`curriculumTracks` and the drift-sync `SyncWriteFacade` backing
/// that class are all gone with the user-DB deletion, so the class could not
/// compile in place. This is its Firestore-shaped successor, built on the
/// repositories the migration brief names as the live seams:
///   - child-profile gating  → `firestoreLearnerProfileRepositoryProvider`
///   - reward eligibility     → `firestoreGoalRepositoryProvider`
///     (a Goal row for the curriculum ⇒ reward-eligible, the Firestore
///      analogue of `RewardMilestoneService.curriculumCountsTowardRewardPoints`
///      / the now-deprecated, throws-`UnsupportedError`
///      `trackCountsTowardRewardPoints(int trackId)` — AD-25 keyes eligibility
///      by curriculum, and a profile has at most one track per curriculum, so
///      "goal exists for curriculum" ⟺ "track is reward-eligible")
///   - points credit          → `firestorePointsLedgerRepositoryProvider`
///     (appends a `+delta` `points_ledger` row — owner decision 5: the stored
///      `PointsBalance` counter is retired; the balance is derived by
///      summing the append-only ledger at read time by
///      `FirestorePointsLedgerRepository.getBalance`)
///
/// The adapter lives under `data/repositories/` so, per AD-23/AD-28, it is
/// exempt from `tool/check_dependency_direction.dart` and may import the
/// `lib/data/firestore/` ring directly — exactly the shape
/// `FirestoreCompletionStreakRecorder` (this directory) takes. The three-tier
/// credit policy is preserved here, not at the call site:
///
///   - `points are child-only`        → `LearnerProfileEntity.mode == child`
///   - `points are engagement-only`   → the orchestrator only invokes this
///     port when its `awardGamificationPoints` gate is true, which is the
///     engagement gate (equivalent to
///     [CompletionSourceX.creditsEngagement] === true, i.e. `live`). The
///     ledger write below stamps `source: CompletionSource.live` so that
///     intent is baked into the durable row and auditable downstream.
///   - `no program/goal ⇒ not eligible` → `getGoals(curriculumId).isEmpty`
///
/// Behaviour changes from the Drift original (each deliberate, none a
/// fabrication or a silent skip):
///   1. `point_configs` row lookup is GONE — there is no Firestore
///      `point_configs` table (it was a Drift-only table, retired with the
///      user DB). The original fell back to its hardcoded ladder anyway
///      whenever no config row existed; this adapter applies that ladder
///      directly, preserving the `Learn=10, Chazara1=5, Chazara2=3, else 1`
///      values verbatim. Per-curriculum point overrides therefore no longer
///      apply on the Firestore path — a real `point_configs` Firestore table
///      would be the separate task to restore them.
///   2. `creditCompletion`'s fire-and-forget `SyncWriteFacade` gamification-
///      settings snapshot push is dropped: `SyncWriteFacade` is deleted, and
///      the migratory successors (`FirestoreCompletionStreakRecorder` in this
///      directory, the gamification Firestore repos) write only their own
///      collection and perform no sync-engine push — milestone state still
///      lives in SharedPreferences via `RewardMilestoneService`, reached
///      through its own adapter, not through a points-credit side effect.
///   3. `trackCountsTowardRewardPoints(int trackId)` (deprecated, throws
///      `UnsupportedError`) is replaced by goal-presence eligibility per
///      AD-25's curriculum-keying.
class FirestoreCompletionPointsAwarder implements CompletionPointsPort {
  FirestoreCompletionPointsAwarder({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Default fallback ladder applied when no per-stage point configuration
  /// exists — mirrors `CompletionRepositoryImpl._calculatePoints`'s prior
  /// fallback ladder verbatim (Learn=10, Chazara1=5, Chazara2=3, else 1).
  static int pointsForStage(int stageOrder) => switch (stageOrder) {
        1 => 10,
        2 => 5,
        3 => 3,
        _ => 1,
      };

  @override
  Future<int> calculatePoints({
    required String curriculumId,
    required int stageOrder,
    required String? profileId,
  }) async {
    // Engagement tier gate (B1): only `live` completions earn points. The
    // orchestrator only calls this method when `awardGamificationPoints` is
    // true — the engagement gate, equivalent to
    // `CompletionSourceX.creditsEngagement` (=== true for `live`). Arrival
    // here therefore already means "this is a live completion"; we do not
    // re-derive a `CompletionSource` because the port interface does not
    // carry one, and re-adding that is an orchestrator change. `creditCompletion`
    // below stamps `source: CompletionSource.live` on the ledger row so the
    // tier policy is durable and auditable rather than inferred.

    // --- Child-profile gate (faithful to Drift `_isChildProfile`) ---
    final learnerProfileRepository =
        await _ref.read(firestoreLearnerProfileRepositoryProvider.future);
    final profileUlid = _ref.read(activeProfileDocIdProvider);
    if (learnerProfileRepository == null || profileUlid == null) {
      // NOT a legitimate zero — a CONTRADICTORY state.
      //
      // This runs only while a completion is being recorded, and the completion
      // write is itself profile-scoped by its Firestore collection path, so an
      // active profile provably exists by the time control reaches here. A null
      // repository or null profile ULID is therefore an inconsistency, not
      // "this learner earns nothing".
      //
      // Returning 0 would be the defect this migration keeps finding: a value
      // that is VALID standing in for one that is CORRECT, with the award
      // silently not happening. A warning log does not close it — nothing
      // downstream can distinguish "earned nothing" from "we could not tell".
      //
      // Safe to throw: `CompletionOrchestrator._safeStep` wraps this call, so
      // the already-durable completion write is not rolled back; only the
      // missed credit is surfaced.
      throw UnsupportedError(
        'FirestoreCompletionPointsAwarder.calculatePoints: cannot determine '
        'the award for profileId=$profileId — '
        'learnerProfileRepository resolved '
        '${learnerProfileRepository == null ? "null" : "ok"}, '
        'activeProfileDocId=$profileUlid. A completion is being recorded, so '
        'an active profile must exist; refusing to report 0 points when the '
        'true award is unknown.',
      );
    }
    final profile = await learnerProfileRepository.getProfile(profileUlid);
    if (profile == null) {
      // No profile document — not a child learner with anything to award.
      // Faithful to the Drift original's `profile != null && ...child`.
      return 0;
    }
    if (profile.mode != ProfileMode.child) return 0;

    // --- Reward-eligibility gate (B1 / AD-25) ---
    final curriculum = CurriculumId.fromStorageKey(curriculumId);
    if (curriculum == null) {
      // Unknown curriculum storage key — no goal/track can exist for it, so
      // "nothing to credit." Faithful to the Drift original's
      // `_resolveTrackId == null ⇒ 0`.
      return 0;
    }
    final goalRepository = await _ref.read(firestoreGoalRepositoryProvider.future);
    if (goalRepository == null) {
      // Same reasoning as the profile branch above: an account is provably
      // active here, so a null goal repository is a not-ready inconsistency,
      // NOT "this learner has no goals". The genuinely empty case is
      // `hasGoal == false` immediately below, which correctly returns 0.
      throw UnsupportedError(
        'FirestoreCompletionPointsAwarder.calculatePoints: the goal repository '
        'resolved to null while computing an award for '
        'curriculumId=$curriculumId, profileId=$profileId; refusing to report '
        '0 points when reward eligibility could not be evaluated.',
      );
    }
    final hasGoal = (await goalRepository.getGoals(curriculum)).isNotEmpty;
    if (!hasGoal) return 0;

    // --- Point value (no Firestore `point_configs` — see class doc) ---
    return pointsForStage(stageOrder);
  }

  @override
  Future<void> creditCompletion({
    required String? profileId,
    required int points,
    required String note,
  }) async {
    // The orchestrator only reaches this after `calculatePoints` returned a
    // positive value for a `live` completion, so `points > 0` and the only
    // engagement tier that earns points is `live`. The ledger row is stamped
    // `source: CompletionSource.live` explicitly — not as a guess, but as the
    // durable record of the tier policy that gated arrival here.
    final repository = await _ref.read(firestorePointsLedgerRepositoryProvider.future);
    if (repository == null) {
      // An award IS owed (points > 0 was computed) but there is no ledger to
      // write against. This is the exact defect class the migration brief
      // warns about ("streak tee receiving null and doing nothing at all"):
      // silently falling through here would silently drop a live-completion
      // award — invisible and permanent. Fail loud instead. This call is
      // wrapped in `CompletionOrchestrator._safeStep` (event
      // `completion_points_credit_failed`), so the already-durable completion
      // write is NOT rolled back; only the missed credit is surfaced.
      throw UnsupportedError(
        'FirestoreCompletionPointsAwarder.creditCompletion: the '
        'points_ledger repository resolved to null (no active account/profile) '
        'while an award of $points points is owed for profileId=$profileId; '
        'refusing to silently drop the award.',
      );
    }
    await repository.append(
      entryKind: 'completion',
      delta: points,
      createdAt: DateTimeFactory.nowUtc(),
      note: note,
      source: CompletionSource.live,
    );
  }
}

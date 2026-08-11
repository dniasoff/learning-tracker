import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/mark_completion_result.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';

/// Storage-only implementation of [CompletionRepository] over Drift.
///
/// **Post completion-orchestrator lift (`docs/firestore-rewrite-map.md`,
/// owner decision 1, 2026-08-03).** This class used to own all five
/// completion side effects (order validation, points, siyum detection,
/// bookmark advance, streak) directly. They now live in
/// `CompletionOrchestrator`
/// (`lib/features/learning/domain/services/completion_orchestrator.dart`),
/// which sits above this repository (and above
/// [FirestoreCompletionRepositoryAdapter], its sibling below) and is the
/// path every real caller (`MarkCompletionUseCase`,
/// `BulkMarkCompletionUseCase`, `BulkPriorCompletionService`) now goes
/// through. What remains here is genuinely storage-only:
///   - natural-key duplicate/idempotency detection (a storage concern —
///     re-committing the same `(profileId, sefariaRef, stageId, trackType,
///     curriculumId)` key must return the existing row, not error or
///     double-insert);
///   - `trackId` resolution (a Drift schema detail — the `completion_events`
///     row carries it; Firestore has no equivalent, see AD-25);
///   - the actual write, via [CompletionWriter] (FR15: completion_events +
///     outbox row in one transaction);
///   - the two read methods `isStageCompleted` (with its Drift-only legacy
///     stage-id/stage-order reconciliation) and `getCompletionsByCurriculum`
///     / `getCompletionsForContentItem`.
///
/// `awardGamificationPoints` / `creditsAchievement` are no longer "should
/// side effects run" flags — that gating now happens one layer up. Here
/// they mean exactly what they mean at rest: whether to tag the stored row
/// `priorMarkOnly` (used by `BulkPriorCompletionService.expungePriorCompletions`
/// to target only bulk-import rows) and which `CompletionSource` to persist
/// into `prior_completion_imports.source`. [CompletionRequest.points] /
/// [BulkCompletionRequest.points] are the points value to persist — already
/// computed by the orchestrator before this repository is ever called.

/// Sentinel value for [Completion.id] / [Completion.profileId] /
/// [Completion.trackId] on completions synthesized by
/// [FirestoreCompletionRepositoryAdapter] from a Firestore [CompletionEntity].
///
/// Mirrors `kFirestoreUnmappedStageId`'s reasoning
/// (`lib/features/tracks/stages/domain/models/stage_definition.dart`): Drift
/// autoincrement primary keys are always positive, so a negative sentinel
/// can never collide with a real Drift-sourced value. See
/// [FirestoreCompletionRepositoryAdapter]'s class doc comment ("`id` /
/// `profileId` / `trackId` are sentinel, not real") for why there is no real
/// value to put here: a Firestore [CompletionEntity] has no autoincrement
/// id, no Drift-local `int profileId` (the profile is a ULID `String` — see
/// `repository_providers.dart`'s library doc comment), and no `trackId`
/// (AD-25 retired the per-device track id; `curriculumId` is the sole
/// canonical stable track key, per `docs/firestore-rewrite-map.md`).
///
/// **Never pass one of these three fields from a Firestore-sourced
/// [Completion] into a method that expects a real Drift row/profile/track
/// id.** Audited (2026-08-03): none of [CompletionRepository]'s current
/// callers read `.id`, `.profileId`, or `.trackId` off the objects it
/// returns — they only read `.sefariaRef`, `.completedAt`, `.curriculumId`,
/// `.trackType`, and list `.length` (see the class doc comment for the
/// callers audited). A new caller that starts reading one of those three
/// fields off a completion returned through this adapter would silently get
/// -1 instead of a real id.
const int kFirestoreUnmappedCompletionRowId = -1;

/// Thrown by [FirestoreCompletionRepositoryAdapter]'s write methods
/// (`markComplete`, `bulkMarkComplete`) when
/// `firestoreCompletionRepositoryProvider` resolves to `null` — i.e. no
/// account is active yet, or no learner profile is active yet. Same shape
/// and reasoning as [BookmarkRepositoryNotReadyException]
/// (`bookmark_repository_impl.dart`): the three read methods
/// (`getCompletionsByCurriculum`, `getCompletionsForContentItem`,
/// `isStageCompleted`) reuse their already-empty-shaped "nothing yet" return
/// value (`[]` / `false`) instead of throwing — see that exception's doc
/// comment for the read-vs-write split this class copies exactly.
class CompletionRepositoryNotReadyException implements Exception {
  const CompletionRepositoryNotReadyException();

  @override
  String toString() =>
      'CompletionRepositoryNotReadyException: '
      'firestoreCompletionRepositoryProvider resolved to null (no active '
      'account, or no active learner profile, yet) — cannot complete a '
      'completion write until one is active.';
}

/// Thrown when a caller passes a non-null `profileId` to
/// [FirestoreCompletionRepositoryAdapter.getCompletionsByCurriculum] — the
/// delegated-profile read path used by
/// `completion_detection_service.dart:276`. There is no corresponding write
/// path any more: [BulkCompletionRequest] carries no `profileId` field, and
/// [CompletionOrchestrator] (`completion_orchestrator.dart`) writes only for
/// the active profile — see that class's doc comment for the invariant
/// ("to write for a profile, make it active") that makes a delegated bulk
/// write unreachable by construction, not merely unsupported here.
///
/// [CompletionRepositoryImpl] can serve a delegated read because `profileId`
/// is the same Drift `int` primary key its own session profile id is —
/// swapping in a different int just points the same DAO at a different row.
/// This adapter has no such option: it is resolved from a single "active
/// profile" seam (`activeProfileDocIdProvider`, a Firestore ULID `String`)
/// with no stored mapping from an arbitrary Drift `int` to a Firestore
/// profile handle — see `repository_providers.dart`'s library doc comment,
/// "The active-profile bridge is a new, deliberately separate seam," for why
/// inventing one here would be fabricating a fact, not reading one. There is
/// no way to tell whether a given `profileId` even means the active
/// profile, so silently serving the active profile's data regardless —
/// right or wrong — would be worse than refusing outright.
class CompletionRepositoryDelegatedProfileUnsupportedException
    implements Exception {
  const CompletionRepositoryDelegatedProfileUnsupportedException();

  @override
  String toString() =>
      'CompletionRepositoryDelegatedProfileUnsupportedException: this '
      'adapter cannot resolve a Firestore repository for a Drift int '
      'profileId other than the active profile — delegated/cross-profile '
      'completion reads are not supported.';
}

/// Firestore-backed [CompletionRepository] adapter — the third application
/// of the pattern [FirestoreBookmarkRepositoryAdapter]
/// (`bookmark_repository_impl.dart`) establishes and
/// `FirestoreProfileRepositoryAdapter`
/// (`lib/features/profiles/data/repositories/profile_repository_impl.dart`)
/// applies second. Read those two class doc comments first; this one only
/// calls out what is DIFFERENT — and there is a lot, because
/// [CompletionRepository] is the largest and most business-logic-heavy
/// surface in the app.
///
/// ## Construction: a [Ref], re-resolved every call — same as bookmarks
///
/// See [FirestoreBookmarkRepositoryAdapter]'s doc comment, points 2–3.
/// [firestoreCompletionRepositoryProvider] is the same nullable-async,
/// non-family shape as `firestoreBookmarkRepositoryProvider` minus the
/// `ContentRepository` family parameter (this repository needs no local
/// content-order collaborator), so [_resolve] / [_resolveOrNull] mirror that
/// adapter's helpers exactly.
///
/// ## `source` is a pure function of the two existing boolean gates — no
/// per-call-site guessing needed
///
/// [CompletionRepository.markComplete] and
/// [CompletionRepository.bulkMarkComplete] do not take a [CompletionSource]
/// parameter — every caller already expresses it as the two independent B1
/// gates, `awardGamificationPoints` (engagement) and `creditsAchievement`
/// (achievement), which exactly mirror [CompletionSourceX.creditsEngagement]
/// / [CompletionSourceX.creditsAchievement]. [CompletionSourceX.fromCredits]
/// is the single canonical inverse of those two getters (formerly
/// duplicated here as a private `_sourceFor` and in
/// [CompletionRepositoryImpl] as `_bulkSourceFor` — both now call the one
/// shared function). Every currently-live call site was audited
/// (2026-08-03):
///   - `MarkCompletionUseCase` (only caller: `text_display_screen.dart`,
///     the "Mark Complete" button, via `CompletionOrchestrator`) → default
///     `source = live` → `(true, true)` → [CompletionSource.live].
///   - `BulkMarkCompletionUseCase` and `BulkPriorCompletionService` (the
///     onboarding "I already learned this" bulk-mark wizard, via
///     `CompletionOrchestrator`) → always `(false, true)` →
///     [CompletionSource.bulkInTrack].
///   - No call site passes `(false, false)`
///     ([CompletionSource.lifetimeOnly]) today — see "`lifetimeOnly` is
///     rejected, not silently downgraded" below for what happens if one
///     ever does.
///   - No call site passes `(true, false)` — the one combination
///     [CompletionSourceX.fromCredits] cannot losslessly represent (it
///     collapses to `live`, silently granting achievement credit alongside
///     engagement credit). Flagged, not fixed: fixing it would mean
///     widening [CompletionSource] itself, out of this file's scope.
///
/// ## `lifetimeOnly` is rejected, not silently downgraded
///
/// `FirestoreCompletionRepository.recordCompletion`/`recordCompletionsBatch`
/// throw [ArgumentError] for [CompletionSource.lifetimeOnly] — by design,
/// per `docs/firestore-rewrite-map.md`: a lifetime-only import writes ONLY a
/// `learning_ledger` entry, never a `completions` document. This adapter
/// does not catch that error; it propagates unchanged out of `markComplete`/
/// `bulkMarkComplete`, matching point 5 of
/// [FirestoreBookmarkRepositoryAdapter]'s doc comment ("a genuine resolution
/// failure is never swallowed"). Since no current call site reaches
/// `(false, false)`, this is a defensive path, not a live one today — but it
/// is a REAL behavior difference from [CompletionRepositoryImpl], which
/// happily writes a `priorMarkOnly` Drift row for `lifetimeOnly`. Writing
/// the matching `learning_ledger` entry for a `lifetimeOnly` mark is
/// `FirestoreLearningLedgerRepository`'s job, not this adapter's — out of
/// scope here.
///
/// ## Storage-only by construction — the orchestration gap this class used
/// to warn about is now closed one layer up
///
/// `FirestoreCompletionRepository`
/// (`lib/data/repositories/firestore_completion_repository.dart`) is a thin
/// CRUD/read layer with no stage-progression validation, no points
/// calculation, no siyum/achievement detection, no bookmark advancement, and
/// no streak-event teeing — and neither does this adapter. That used to be
/// a documented gap relative to [CompletionRepositoryImpl] (which did all
/// five inline); it no longer is, because [CompletionRepositoryImpl] does
/// not do them either any more. `CompletionOrchestrator`
/// (`lib/features/learning/domain/services/completion_orchestrator.dart`)
/// is the one place all five behaviors live now, and it is written against
/// the [CompletionRepository] interface — either this adapter or
/// [CompletionRepositoryImpl] can sit beneath it. **What is still missing
/// is NOT orchestration — it's two of the orchestrator's storage-specific
/// collaborators**: no Firestore-backed `CompletionPointsPort` or
/// `CompletionStreakPort` exists yet (see those classes' doc comments in
/// `completion_orchestrator.dart` for what's needed and why it's out of
/// this file's scope — `points_ledger`/`streak_events` Firestore
/// repositories are separate, not-yet-landed work). Wiring
/// `completionRepositoryProvider` to construct this class is therefore
/// still gated on that separate work landing, not on this file.
///
/// ## `id` / `profileId` / `trackId` are sentinel, not real
///
/// See [kFirestoreUnmappedCompletionRowId]'s doc comment.
///
/// ## `getCompletionsByCurriculum`/`getCompletionsForContentItem` are
/// faithful reads; `isStageCompleted` is simpler than Drift's, not weaker
///
/// Drift's `isStageCompleted` carries a legacy stage-id/stage-order
/// reconciliation branch for rows written before stage ids were normalized
/// to stage order (see [CompletionRepositoryImpl.isStageCompleted]). Every
/// Firestore [CompletionEntity.stageId] is a `stage_order` value by
/// construction (see that class's doc comment) — there is no legacy shape to
/// reconcile, so this adapter's [isStageCompleted] is a plain equality
/// check, not a reduced one.
///
/// ## Delegated-profile reads are unsupported (writes have no such channel
/// any more)
///
/// See [CompletionRepositoryDelegatedProfileUnsupportedException]'s doc
/// comment. `getCompletionsByCurriculum`'s `profileId` parameter still has a
/// live caller (`completion_detection_service.dart:276`) and throws under
/// this adapter when it is non-null. `bulkMarkComplete` has no equivalent
/// guard because it has no equivalent parameter: `BulkCompletionRequest`
/// carries no `profileId` field, and `BulkPriorCompletionService` (the
/// onboarding bulk-mark-prior wizard) switches the active profile to the
/// child before it runs rather than delegating around it — see
/// `bulk_prior_completion_service.dart`'s doc comment.
class FirestoreCompletionRepositoryAdapter implements CompletionRepository {
  FirestoreCompletionRepositoryAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Re-reads `firestoreCompletionRepositoryProvider`, resolving to `null`
  /// exactly when it does (no active account, or no active learner
  /// profile). See the class doc comment ("Construction") for why this
  /// re-reads on every call rather than caching.
  Future<FirestoreCompletionRepository?> _resolveOrNull() {
    return _ref.read(firestoreCompletionRepositoryProvider.future);
  }

  /// Like [_resolveOrNull], but throws [CompletionRepositoryNotReadyException]
  /// instead of returning `null` — for the two write methods, which have no
  /// nullable "not ready" value of their own to return.
  Future<FirestoreCompletionRepository> _resolve() async {
    final repo = await _resolveOrNull();
    if (repo == null) {
      throw const CompletionRepositoryNotReadyException();
    }
    return repo;
  }

  static CurriculumId _curriculumFor(String storageKey) =>
      CurriculumId.values.firstWhere(
        (c) => c.storageKey == storageKey,
        orElse: () => throw ArgumentError('Unknown curriculumId: $storageKey'),
      );

  @override
  Future<MarkCompletionResult> markComplete(
    CompletionRequest request, {
    bool awardGamificationPoints = true,
    bool creditsAchievement = true,
  }) async {
    final repo = await _resolve();
    final curriculum = _curriculumFor(request.curriculumId);
    final now = DateTimeFactory.nowUtc(); // P5: UTC timestamps
    final source = CompletionSourceX.fromCredits(
      awardGamificationPoints: awardGamificationPoints,
      creditsAchievement: creditsAchievement,
    );

    // Idempotency guard: SR-1 permits `update` only as a byte-identical
    // replay, so a genuine re-mark computing a fresh `now` would be
    // rules-denied in production. This pre-check exists for that reason, not
    // merely to save a write.
    //
    // It MUST route through `getCompletion`, never through a list read:
    // `getCompletionsForContent` decodes via `_decodeAll`, which drops
    // tombstoned documents (D-L). A purged completion would therefore look
    // ABSENT here, and the create below would hit an existing document and be
    // denied. `getCompletion` deliberately bypasses the tombstone filter so
    // this path can tell "absent" from "purged".
    final existing = await repo.getCompletion(
      curriculumId: curriculum,
      sefariaRef: request.sefariaRef,
      stageId: request.stageId,
    );

    if (existing != null) {
      if (existing.purgedAt != null) {
        // Re-mark after expunge: resurrect rather than create, and report
        // isNew = true — matching the Drift writer's H1 behaviour exactly,
        // where a resurrected tombstone counted as new.
        await repo.restoreCompletion(
          curriculumId: curriculum,
          sefariaRef: request.sefariaRef,
          stageId: request.stageId,
          completedAt: now,
        );
        return MarkCompletionResult(
          completion: CompletionEntity(
            curriculumId: existing.curriculumId,
            sefariaRef: existing.sefariaRef,
            stageId: existing.stageId,
            trackType: existing.trackType,
            source: existing.source,
            completedAt: now,
            points: existing.points,
          ),
          isNew: true,
        );
      }

      // B8: a bulk-imported row hit by real learning is UPGRADED in place, not
      // duplicated. `isNew` stays FALSE — the completion already existed, so
      // points, streak, siyum detection and bookmark advance must not fire a
      // second time. This replaces the Drift writer's `_upgradePriorMarkRow`,
      // which deleted a `prior_completion_imports` row; provenance now lives on
      // the document itself, so an upgraded row is invisible to expunge purely
      // because its `source` is no longer `bulkInTrack`.
      if (existing.source == CompletionSource.bulkInTrack &&
          source == CompletionSource.live) {
        await repo.upgradeSourceToLive(
          curriculumId: curriculum,
          sefariaRef: request.sefariaRef,
          stageId: request.stageId,
          completedAt: now,
        );
        return MarkCompletionResult(
          completion: CompletionEntity(
            curriculumId: existing.curriculumId,
            sefariaRef: existing.sefariaRef,
            stageId: existing.stageId,
            trackType: existing.trackType,
            source: CompletionSource.live,
            completedAt: now,
            points: existing.points,
          ),
          isNew: false,
        );
      }

      return MarkCompletionResult(completion: existing, isNew: false);
    }

    final entity = CompletionEntity(
      curriculumId: curriculum,
      sefariaRef: request.sefariaRef,
      stageId: request.stageId,
      trackType: request.trackType,
      source: source,
      completedAt: now,
      points: request.points,
    );
    // Transactional create-if-absent rather than exists-then-write. `isNew`
    // gates points, streak, siyum detection AND bookmark advance (see
    // MarkCompletionResult's doc comment), so losing this race would
    // double-credit all four.
    final created = await repo.recordCompletionIfAbsent(entity);
    return MarkCompletionResult(completion: entity, isNew: created);
  }

  @override
  Future<List<CompletionEntity>> bulkMarkComplete(
    BulkCompletionRequest request,
  ) async {
    if (request.sefariaRefs.isEmpty) return const [];

    final repo = await _resolve();
    final curriculum = _curriculumFor(request.curriculumId);
    final source = CompletionSourceX.fromCredits(
      awardGamificationPoints: request.awardGamificationPoints,
      creditsAchievement: request.creditsAchievement,
    );
    // No per-item existing-check pass here (unlike markComplete) — every
    // current call site (BulkPriorCompletionService) always supplies the
    // fixed kBulkPriorSentinelDate for prior-mark requests, so a retry is a
    // byte-identical replay and SR-1 accepts it without a pre-check. A
    // hypothetical live-source bulk call that left completedAt null would
    // mint a fresh timestamp per retry and could hit the same replay
    // rejection markComplete's pre-check exists to avoid — flagged in the
    // class doc comment, not guarded here (no current call site reaches it).
    final completedAt = request.completedAt ?? DateTimeFactory.nowUtc();
    final entities = request.sefariaRefs
        .map(
          (sefariaRef) => CompletionEntity(
            curriculumId: curriculum,
            sefariaRef: sefariaRef,
            stageId: request.stageId,
            trackType: request.trackType,
            source: source,
            completedAt: completedAt,
            points: request.points,
          ),
        )
        .toList();
    final recorded = await repo.recordCompletionsBatch(entities);
    return recorded;
  }

  @override
  Future<List<CompletionEntity>> getCompletionsByCurriculum(
    String curriculumId, {
    int? profileId,
  }) async {
    if (profileId != null) {
      throw const CompletionRepositoryDelegatedProfileUnsupportedException();
    }
    // Not-ready reads as "nothing to show yet" rather than an exception —
    // see CompletionRepositoryNotReadyException's doc comment.
    // D-E: completions are achievement data — an empty list here is
    // indistinguishable from a learner who has completed nothing.
    final repo = await _resolve();
    final curriculum = _curriculumFor(curriculumId);
    final entities = await repo.getCompletionsForCurriculum(curriculum);
    return entities;
  }

  @override
  Future<List<CompletionEntity>> getCompletionsForContentItem(
    String sefariaRef,
  ) async {
    // D-E: completions are achievement data — an empty list here is
    // indistinguishable from a learner who has completed nothing.
    final repo = await _resolve();
    final entities = await repo.getCompletionsForContent(sefariaRef);
    return entities;
  }

  @override
  Future<bool> isStageCompleted({
    required String sefariaRef,
    required int stageId,
    required String trackType,
  }) async {
    final repo = await _resolveOrNull();
    if (repo == null) return false;
    final entities = await repo.getCompletionsForContent(sefariaRef);
    return entities.any(
      (e) => e.trackType == trackType && e.stageId == stageId,
    );
  }

  @override
  Future<void> purgeCompletion({
    required CurriculumId curriculumId,
    required String sefariaRef,
    required int stageId,
    required DateTime purgedAt,
  }) async {
    final repo = await _resolve();
    await repo.purgeCompletion(
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
      purgedAt: purgedAt,
    );
  }
}

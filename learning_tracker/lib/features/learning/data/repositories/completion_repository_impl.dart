import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/features/learning/data/completion_writer.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_command.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/mark_completion_result.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart'
    as stage_model;
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';

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
class CompletionRepositoryImpl implements CompletionRepository {
  final UserDatabase _database;
  final int _activeProfileId;
  final CompletionWriter _completionWriter;
  final StageDefinitionRepository? _stageRepository;

  CompletionRepositoryImpl({
    required UserDatabase database,
    int activeProfileId = 0,
    CompletionWriter? completionWriter,
    StageDefinitionRepository? stageRepository,
  }) : _database = database,
       _activeProfileId = activeProfileId,
       _completionWriter = completionWriter ?? CompletionWriter(database),
       _stageRepository = stageRepository;

  @override
  Future<MarkCompletionResult> markComplete(
    CompletionRequest request, {
    bool awardGamificationPoints = true,
    bool creditsAchievement = true,
  }) async {
    // Single Drift transaction covering only the storage-level idempotency
    // check + the write itself — order validation, points calculation,
    // siyum detection, bookmark advance and streak recording all now run
    // above this repository (see the class doc comment).
    final (:completion, :isNew) = await _database.transaction(() async {
      final completions = await _database.completionDao
          .getCompletionsForContentAndProfile(
            request.sefariaRef,
            _activeProfileId,
          );

      // Duplicate check (idempotent) — match on the full natural key
      // including curriculumId so a completion for the same
      // (sefariaRef, stageId, trackType) in a DIFFERENT curriculum is not
      // mis-identified as a duplicate. R6-19.
      final existing = completions
          .where(
            (c) =>
                c.curriculumId == request.curriculumId &&
                c.stageId == request.stageId &&
                c.trackType == request.trackType,
          )
          .firstOrNull;
      if (existing != null) {
        return (completion: existing, isNew: false);
      }

      final trackId = await _resolveTrackId(
        curriculumId: request.curriculumId,
        trackType: request.trackType,
        profileId: _activeProfileId,
      );

      final created = await _createCompletion(
        request: request,
        trackId: trackId,
        profileId: _activeProfileId,
        // B1: pass priorMarkOnly = !awardGamificationPoints so expunge can
        // distinguish bulk-prior rows from live-learning rows.
        priorMarkOnly: !awardGamificationPoints,
      );

      return (completion: created, isNew: true);
    });

    return MarkCompletionResult(completion: completion, isNew: isNew);
  }

  @override
  Future<List<Completion>> bulkMarkComplete(
    BulkCompletionRequest request,
  ) async {
    if (request.sefariaRefs.isEmpty) return const [];
    final effectiveProfileId = request.profileId ?? _activeProfileId;

    final trackId = await _resolveTrackId(
      curriculumId: request.curriculumId,
      trackType: request.trackType,
      profileId: effectiveProfileId,
    );

    final now = request.completedAt ?? DateTimeFactory.nowUtc();
    final source = CompletionSourceX.fromCredits(
      awardGamificationPoints: request.awardGamificationPoints,
      creditsAchievement: request.creditsAchievement,
    );
    // Storage tagging only (see the class doc comment) — NOT an engagement
    // gate here. `priorMarkOnly` flags a row so
    // `BulkPriorCompletionService.expungePriorCompletions` can target it.
    final priorMarkOnly = !request.awardGamificationPoints;

    // De-duplicate the caller's ref list — mirrors the prior optimized
    // bulk-prior path's dedup (now the single, unified bulk-write path:
    // per-item order validation moved above this repository, so there is no
    // remaining reason to loop single-item transactions the way the old
    // "slow path" did).
    final uniqueRefs = <String>[];
    final seenRefs = <String>{};
    for (final ref in request.sefariaRefs) {
      if (seenRefs.add(ref)) uniqueRefs.add(ref);
    }

    // FR15 / RC1: route all writes through CompletionWriter.commitBatch so
    // every completion in the batch lands in a SINGLE Drift transaction.
    // commitBatch's own natural-key pre-check handles idempotency for
    // refs already completed — no separate existence pre-filter needed here.
    final commands = uniqueRefs
        .map(
          (ref) => CompletionCommand(
            profileId: effectiveProfileId,
            curriculumId: request.curriculumId,
            sefariaRef: ref,
            stageId: request.stageId,
            trackType: request.trackType,
            trackId: trackId,
            completedAt: now,
            points: request.points,
            priorMarkOnly: priorMarkOnly,
            source: source,
          ),
        )
        .toList();
    await _completionWriter.commitBatch(commands);

    final rows = await _database.completionDao.getCompletionsForRefsBulkStage(
      profileId: effectiveProfileId,
      curriculumId: request.curriculumId,
      stageId: request.stageId,
      trackType: request.trackType,
      sefariaRefs: uniqueRefs,
    );
    final byRef = <String, Completion>{for (final c in rows) c.sefariaRef: c};

    // Return in the caller's original (possibly-duplicated) ref order.
    return request.sefariaRefs.map((r) => byRef[r]!).toList();
  }

  /// Look up the curriculum_tracks.id for a given curriculum + trackType.
  Future<int> _resolveTrackId({
    required String curriculumId,
    required String trackType,
    required int profileId,
  }) async {
    // W3.22: trackType dropped — one track per {profileId, curriculumId}.
    final track =
        await (_database.select(_database.curriculumTracks)
              ..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.curriculumId.equals(curriculumId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (track == null) {
      throw StateError(
        'No curriculum track found for profile=$profileId, '
        'curriculum=$curriculumId',
      );
    }
    return track.id;
  }

  /// Create the completion record in the database.
  ///
  /// Delegates to [CompletionWriter] (FR15) so the completion row + outbox
  /// row are written in one transaction. [request.points] is persisted
  /// as-is — see the class doc comment for why point calculation is not
  /// this repository's job any more.
  ///
  /// [priorMarkOnly] — set to true for bulkInTrack / lifetimeOnly sources
  /// so the `completion_events` row is flagged and expunge can target only
  /// prior-mark rows.
  Future<Completion> _createCompletion({
    required CompletionRequest request,
    required int trackId,
    required int profileId,
    bool priorMarkOnly = false,
  }) async {
    final now = DateTimeFactory.nowUtc(); // P5: Store as UTC

    final result = await _completionWriter.commit(
      CompletionCommand(
        profileId: profileId,
        curriculumId: request.curriculumId,
        sefariaRef: request.sefariaRef,
        stageId: request.stageId,
        trackType: request.trackType,
        trackId: trackId,
        completedAt: now,
        points: request.points,
        priorMarkOnly: priorMarkOnly,
      ),
    );

    return result.completion;
  }

  @override
  Future<List<Completion>> getCompletionsByCurriculum(
    String curriculumId, {
    int? profileId,
  }) async {
    final pid = profileId ?? _activeProfileId;
    return await _database.completionDao.getCompletionsByCurriculumAndProfile(
      curriculumId,
      pid,
    );
  }

  @override
  Future<List<Completion>> getCompletionsForContentItem(
    String sefariaRef,
  ) async {
    return await _database.completionDao.getCompletionsForContentAndProfile(
      sefariaRef,
      _activeProfileId,
    );
  }

  @override
  Future<bool> isStageCompleted({
    required String sefariaRef,
    required int stageId,
    required String trackType,
  }) async {
    final completions = await _database.completionDao
        .getCompletionsForContentAndProfile(sefariaRef, _activeProfileId);

    final trackCompletions = completions
        .where((c) => c.trackType == trackType)
        .toList();
    if (trackCompletions.isEmpty) return false;

    // Fast path: exact stage id/order match.
    if (trackCompletions.any((c) => c.stageId == stageId)) return true;

    // Backward-compat: some rows store stage definition id, while newer rows
    // store stage order directly. Resolve both representations to stage order.
    final stageOrderByCurriculum = <String, Map<int, int>>{};
    final knownOrdersByCurriculum = <String, Set<int>>{};

    for (final completion in trackCompletions) {
      final curriculumId = completion.curriculumId;
      if (!stageOrderByCurriculum.containsKey(curriculumId)) {
        final curriculumEnum = CurriculumId.values.firstWhere(
          (c) => c.storageKey == curriculumId,
          orElse: () => CurriculumId.mishnayos,
        );
        final stages = _stageRepository == null
            ? <stage_model.StageDefinition>[]
            : await _stageRepository.getStagesForCurriculum(curriculumEnum);
        stageOrderByCurriculum[curriculumId] = {
          for (final s in stages) s.id: s.stageOrder,
        };
        knownOrdersByCurriculum[curriculumId] = {
          for (final s in stages) s.stageOrder,
        };
      }

      final knownOrders = knownOrdersByCurriculum[curriculumId]!;
      final idToOrder = stageOrderByCurriculum[curriculumId]!;
      final normalizedStage = knownOrders.contains(completion.stageId)
          ? completion.stageId
          : idToOrder[completion.stageId];
      if (normalizedStage == stageId) return true;
    }

    return false;
  }
}

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
/// [FirestoreCompletionRepositoryAdapter.getCompletionsByCurriculum], or a
/// non-null [BulkCompletionRequest.profileId] to
/// [FirestoreCompletionRepositoryAdapter.bulkMarkComplete] — the
/// delegated-profile path used by e.g. a parent bulk-marking a child's track
/// during onboarding (`bulk_prior_completion_service.dart`).
///
/// [CompletionRepositoryImpl] can serve this because `profileId` is the same
/// Drift `int` primary key its own session profile id is — swapping in a
/// different int just points the same DAO at a different row. This adapter
/// has no such option: it is resolved from a single "active profile" seam
/// (`activeProfileDocIdProvider`, a Firestore ULID `String`) with no stored
/// mapping from an arbitrary Drift `int` to a Firestore profile handle — see
/// `repository_providers.dart`'s library doc comment, "The active-profile
/// bridge is a new, deliberately separate seam," for why inventing one here
/// would be fabricating a fact, not reading one. There is no way to tell
/// whether a given `profileId` even means the active profile, so silently
/// serving the active profile's data regardless — right or wrong — would be
/// worse than refusing outright.
class CompletionRepositoryDelegatedProfileUnsupportedException
    implements Exception {
  const CompletionRepositoryDelegatedProfileUnsupportedException();

  @override
  String toString() =>
      'CompletionRepositoryDelegatedProfileUnsupportedException: this '
      'adapter cannot resolve a Firestore repository for a Drift int '
      'profileId other than the active profile — delegated/cross-profile '
      'completion reads and bulk-writes are not supported.';
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
/// ## Delegated-profile reads/writes are unsupported
///
/// See [CompletionRepositoryDelegatedProfileUnsupportedException]'s doc
/// comment. **This is reachable today, not theoretical**:
/// `BulkPriorCompletionService` (the onboarding bulk-mark-prior wizard)
/// passes a non-null `profileId` whenever it runs for a delegated profile
/// (e.g. a parent adding a track for a child), so both
/// `getCompletionsByCurriculum` and `bulkMarkComplete` throw for that flow
/// under this adapter.
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

  /// Maps a Firestore [CompletionEntity] onto the Drift-shaped [Completion]
  /// the interface still returns. See [kFirestoreUnmappedCompletionRowId]'s
  /// doc comment for the sentinel `id`/`profileId`/`trackId`.
  static Completion _toDriftCompletion(CompletionEntity entity) => Completion(
    id: kFirestoreUnmappedCompletionRowId,
    profileId: kFirestoreUnmappedCompletionRowId,
    curriculumId: entity.curriculumId.storageKey,
    sefariaRef: entity.sefariaRef,
    stageId: entity.stageId,
    trackType: entity.trackType,
    trackId: kFirestoreUnmappedCompletionRowId,
    completedAt: entity.completedAt,
    points: entity.points,
    // Every Firestore completion's stageId is a stage_order value by
    // construction — see CompletionEntity's class doc comment.
    stageIdFormat: 'stageOrder',
  );

  @override
  Future<MarkCompletionResult> markComplete(
    CompletionRequest request, {
    bool awardGamificationPoints = true,
    bool creditsAchievement = true,
  }) async {
    final repo = await _resolve();
    final curriculum = _curriculumFor(request.curriculumId);

    // Idempotency guard: SR-1 permits `update` only as a byte-identical
    // replay. A genuine re-mark of an already-completed stage would compute
    // a fresh DateTimeFactory.nowUtc() below and get rules-denied as a
    // non-identical replay in production — this is the single-item analogue
    // of CompletionRepositoryImpl.markComplete's own duplicate check
    // ("existing != null → return existing"), needed here for the same
    // idempotency reason, not merely to save a write.
    final existing = await _findExisting(
      repo,
      curriculum: curriculum,
      stageId: request.stageId,
      sefariaRef: request.sefariaRef,
      trackType: request.trackType,
    );
    if (existing != null) {
      return MarkCompletionResult(
        completion: _toDriftCompletion(existing),
        isNew: false,
      );
    }

    final entity = CompletionEntity(
      curriculumId: curriculum,
      sefariaRef: request.sefariaRef,
      stageId: request.stageId,
      trackType: request.trackType,
      source: CompletionSourceX.fromCredits(
        awardGamificationPoints: awardGamificationPoints,
        creditsAchievement: creditsAchievement,
      ),
      completedAt: DateTimeFactory.nowUtc(), // P5: UTC timestamps
      points: request.points,
    );
    final recorded = await repo.recordCompletion(entity);
    return MarkCompletionResult(completion: _toDriftCompletion(recorded));
  }

  @override
  Future<List<Completion>> bulkMarkComplete(
    BulkCompletionRequest request,
  ) async {
    if (request.profileId != null) {
      throw const CompletionRepositoryDelegatedProfileUnsupportedException();
    }
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
    return recorded.map(_toDriftCompletion).toList();
  }

  @override
  Future<List<Completion>> getCompletionsByCurriculum(
    String curriculumId, {
    int? profileId,
  }) async {
    if (profileId != null) {
      throw const CompletionRepositoryDelegatedProfileUnsupportedException();
    }
    // Not-ready reads as "nothing to show yet" rather than an exception —
    // see CompletionRepositoryNotReadyException's doc comment.
    final repo = await _resolveOrNull();
    if (repo == null) return const [];
    final curriculum = _curriculumFor(curriculumId);
    final entities = await repo.getCompletionsForCurriculum(curriculum);
    return entities.map(_toDriftCompletion).toList();
  }

  @override
  Future<List<Completion>> getCompletionsForContentItem(
    String sefariaRef,
  ) async {
    final repo = await _resolveOrNull();
    if (repo == null) return const [];
    final entities = await repo.getCompletionsForContent(sefariaRef);
    return entities.map(_toDriftCompletion).toList();
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

  /// Finds an existing completion matching the natural key, if any — see
  /// [markComplete]'s doc comment for why this pre-check exists.
  /// [FirestoreCompletionRepository] has no direct-by-key read; this filters
  /// [FirestoreCompletionRepository.getCompletionsForContent]'s result
  /// (already scoped to [sefariaRef]) client-side instead of adding a new
  /// method to that repository, which is out of this file's scope.
  Future<CompletionEntity?> _findExisting(
    FirestoreCompletionRepository repo, {
    required CurriculumId curriculum,
    required int stageId,
    required String sefariaRef,
    required String trackType,
  }) async {
    final candidates = await repo.getCompletionsForContent(sefariaRef);
    for (final c in candidates) {
      if (c.curriculumId == curriculum &&
          c.stageId == stageId &&
          c.trackType == trackType) {
        return c;
      }
    }
    return null;
  }
}

import 'dart:async';

import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/mark_completion_result.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';

/// Points-award collaborator for [CompletionOrchestrator].
///
/// Injected so the orchestrator has no storage-specific dependency of its
/// own. `lib/features/learning/data/completion_points_awarder.dart` provides
/// the Drift-backed implementation — a straight relocation of what
/// `CompletionRepositoryImpl.markComplete` computed inline before this lift
/// (point_configs lookup, child/track-eligibility gating,
/// `PointsBalanceDao.creditCompletion`). No Firestore-backed implementation
/// exists yet: `docs/firestore-rewrite-map.md`'s owner decision 5 assigns
/// "points balance is derived and clamped at zero" (summing `points_ledger`)
/// to a separate, not-yet-landed repository. Wiring one is out of this
/// file's scope — see this class's construction site in
/// `completion_providers.dart` for the current (Drift-only) wiring, and the
/// completion-orchestrator report for why that gap is deliberate, not an
/// oversight.
abstract class CompletionPointsPort {
  /// Points to award for completing [stageOrder] of [curriculumId] for
  /// [profileId]. Returns 0 when this profile/track does not earn
  /// gamification points at all (an adult profile, or a momentum-only/
  /// browse track with no program or goal) — the caller does not need to
  /// know why; 0 always means "nothing to credit."
  Future<int> calculatePoints({
    required String curriculumId,
    required int stageOrder,
    required int profileId,
  });

  /// Credits [points] (always > 0 — callers only invoke this after checking
  /// [calculatePoints] returned a positive value) to [profileId]'s balance
  /// for this completion. [note] is a short human-readable provenance
  /// string (mirrors `CompletionRepositoryImpl`'s prior
  /// `'$curriculumId:$sefariaRef'` note).
  Future<void> creditCompletion({
    required int profileId,
    required int points,
    required String note,
  });
}

/// Streak-recording collaborator for [CompletionOrchestrator].
///
/// Injected for the same reason as [CompletionPointsPort] — see that
/// class's doc comment. `lib/features/learning/data/
/// completion_streak_recorder.dart` provides the Drift-backed
/// implementation (local `streak_events` row + outbox tee), relocated
/// verbatim from `CompletionRepositoryImpl._appendStreakEvent`.
abstract class CompletionStreakPort {
  /// Records that [profileId] studied on [at] (records the day for the
  /// streak). Implementations must be idempotent per (profileId, calendar
  /// day) — a duplicate call for the same day is expected (e.g. a second
  /// completion later the same day) and must be a silent no-op, not an
  /// error.
  Future<void> recordStudyDay({required int profileId, required DateTime at});
}

/// Owns the five app-rule side effects that fire when a completion is
/// recorded, sitting ABOVE the storage layer (`CompletionRepository`) so
/// either a Drift or a Firestore-backed repository can sit beneath it —
/// `docs/firestore-rewrite-map.md`, owner decision 1 (2026-08-03):
///
/// 1. **Order validation** — stage N+1 cannot be marked before stage N.
///    Runs BEFORE the write (see "Ordering" below).
/// 2. **Points** — computes and credits gamification points
///    ([CompletionPointsPort]).
/// 3. **Achievement (siyum) detection** — dispatches
///    [CompletionDetectionService] so a finished masechta/sefer/seder lands
///    in the learning ledger.
/// 4. **Bookmark advance** — moves the reading-order bookmark forward past
///    the completed item.
/// 5. **Streak** — records the study day ([CompletionStreakPort]).
///
/// Previously all five lived only inside `CompletionRepositoryImpl`
/// (Drift) — `FirestoreCompletionRepositoryAdapter` had none of them (see
/// that class's former doc comment, now superseded by this one existing).
/// A single implementation, used by both storage backends, means a `live`
/// completion — permanent by owner decision, never deletable or
/// correctable — gets the same five behaviors no matter which repository
/// wrote it.
///
/// ## Ordering: validate → write → best-effort post-write side effects
///
/// Order validation runs as a READ before [CompletionRepository.markComplete]
/// / [CompletionRepository.bulkMarkComplete] is ever called. This matters
/// more under Firestore than it did under Drift: Drift validated and wrote
/// inside one transaction, so a validation failure never left a row behind.
/// Firestore's `completions` collection is append-only — `firestore.rules`
/// denies `delete` unconditionally — so a completion written out of order
/// could never be un-written. Validating first, unconditionally, for both
/// backends closes that gap. See "Atomicity" below for the residual TOCTOU
/// window this ordering does NOT close.
///
/// The four remaining behaviors (points, streak, siyum, bookmark) run AFTER
/// the write, only when it produced a genuinely new row
/// ([MarkCompletionResult.isNew] / a non-empty write in the bulk path), and
/// each is independently caught and logged rather than chained — one
/// failing must not prevent the others from running, and none of them may
/// roll back or retract the already-durable completion (which, for `live`
/// sources, cannot be undone by design).
///
/// ## Atomicity — the answer this class exists to give, not guess at
///
/// The completion write itself is the one atomic, durable step: Drift wraps
/// it in a real transaction (`CompletionWriter.commit`/`commitBatch`);
/// Firestore's per-document write is inherently atomic. Everything else —
/// order validation (a read before the write) and the four post-write side
/// effects — is NOT part of that transaction and cannot be, once Firestore
/// is the backing store (batches cap at 500 ops and still can't span an
/// arbitrary read-modify-write across `points_ledger`, `streak_events`,
/// `learning_ledger`, and `bookmarks`).
///
/// Concretely, if the completion write succeeds and a later step throws:
///   - **The completion is durable and correct.** It exists, it is
///     permanent (for `live`), and it is exactly what the learner did.
///   - **Points/streak/siyum/bookmark are best-effort and independently
///     retriable-by-nature**, not compensating writes: a missed points
///     credit is invisible in the balance until the *next* successful
///     completion nudges it (the ledger is append-only and additive — nothing
///     to reconcile against a "should have been" state); a missed streak day
///     is corrected by the next day's completion recording normally; a missed
///     siyum is a real gap until `CompletionDetectionService` is re-dispatched
///     for that unit (today: never automatically — a known, pre-existing
///     limitation this lift does not fix, matching how
///     `_completionDetectionService` was already fire-and-forget with a
///     logged catch before this change); a missed bookmark advance leaves the
///     reader on the just-completed item, which is a visible-but-harmless
///     "here you are" outcome, not a correctness defect — the app already
///     tolerates the bookmark not moving (`advanceBookmark`'s own doc comment:
///     "Does nothing if the completed item is the last item").
///   - **No compensating delete is invented.** A `live` completion cannot be
///     deleted (`docs/firestore-rewrite-map.md`'s owner decision, "Completion
///     side effects move ABOVE the data layer") — retracting the record to
///     "undo" a downstream failure is not an option this class implements,
///     was told explicitly not to invent one, and would be worse than the
///     gap it would paper over (a silently vanished completion the learner
///     genuinely earned).
///
/// **Order validation's own residual gap**: validating via a read before the
/// write (rather than inside the write's transaction, as Drift did before
/// this lift) opens a TOCTOU window — a second concurrent call for the same
/// (profile, item, track) between the read and the write could both pass
/// validation. This app has no concurrent-writer scenario in practice (one
/// device, one UI action at a time; the `completions` natural-key dedup
/// still prevents a literal duplicate row), so the window is real but not
/// believed to be reachable — flagged here rather than silently accepted.
///
/// ## Regression this lift knowingly accepts: Drift bookmark-write
/// atomicity is now best-effort, not transactional
///
/// Before this lift, `CompletionRepositoryImpl.markComplete` advanced the
/// bookmark INSIDE the same Drift transaction as the completion insert —
/// Story 27.9 / DNI-385 made this an explicit, tested guarantee (a
/// `BookmarkRepository` that throws rolled back the completion). This class
/// intentionally does NOT reproduce that coupling: bookmark advance is one
/// of the five behaviors moving above storage, Firestore cannot offer the
/// same guarantee, and having Drift silently keep a stronger contract than
/// Firestore would mean the two storage backends behave differently under
/// this one orchestrator — the opposite of "written once." The dedicated
/// AC3 test (`epic_27_integration_lockout_redaction_atomic_test.dart`) that
/// asserted the old transactional guarantee has been updated to assert the
/// new one instead (bookmark failure is caught, logged, and does NOT roll
/// back or retract the completion). This is a deliberate design decision
/// surfaced for the owner, not a silently-dropped guarantee.
class CompletionOrchestrator {
  CompletionOrchestrator({
    required CompletionRepository repository,
    required ContentRepository contentRepository,
    required int activeProfileId,
    BookmarkRepository? bookmarkRepository,
    BookmarkRepository Function(int profileId)? bookmarkRepositoryFactory,
    CompletionDetectionService? completionDetectionService,
    CompletionPointsPort? pointsPort,
    CompletionStreakPort? streakPort,
  }) : _repository = repository,
       _contentRepository = contentRepository,
       _activeProfileId = activeProfileId,
       _bookmarkRepository = bookmarkRepository,
       _bookmarkRepositoryFactory = bookmarkRepositoryFactory,
       _completionDetectionService = completionDetectionService,
       _pointsPort = pointsPort,
       _streakPort = streakPort;

  final CompletionRepository _repository;
  final ContentRepository _contentRepository;
  final int _activeProfileId;
  final BookmarkRepository? _bookmarkRepository;
  final BookmarkRepository Function(int profileId)? _bookmarkRepositoryFactory;
  final CompletionDetectionService? _completionDetectionService;
  final CompletionPointsPort? _pointsPort;
  final CompletionStreakPort? _streakPort;

  // ───────────────────────────── Single-item ─────────────────────────────

  /// Mark a single content item complete, running all five behaviors above
  /// [CompletionRepository]. Mirrors [CompletionRepository.markComplete]'s
  /// parameter shape exactly — `awardGamificationPoints` is the engagement
  /// gate, `creditsAchievement` is the achievement gate (B1 three-tier
  /// policy; see `CompletionSourceX.creditsEngagement`/`.creditsAchievement`,
  /// the canonical source of these two booleans for every real caller).
  ///
  /// Throws [StageProgressionException] if stage progression is violated —
  /// BEFORE any write (see the class doc comment, "Ordering").
  Future<MarkCompletionResult> markComplete(
    CompletionRequest request, {
    bool awardGamificationPoints = true,
    bool creditsAchievement = true,
  }) async {
    // 1. Order validation — before any write.
    final existing = await _repository.getCompletionsForContentItem(
      request.sefariaRef,
    );
    _validateOrder(
      existing: existing,
      trackType: request.trackType,
      stageId: request.stageId,
    );

    // 2. Points — computed before the write so it lands on the stored row.
    var points = 0;
    if (awardGamificationPoints && _pointsPort != null) {
      points = await _pointsPort.calculatePoints(
        curriculumId: request.curriculumId,
        stageOrder: request.stageId,
        profileId: _activeProfileId,
      );
    }

    final writeRequest = points == 0
        ? request
        : CompletionRequest(
            curriculumId: request.curriculumId,
            sefariaRef: request.sefariaRef,
            stageId: request.stageId,
            trackType: request.trackType,
            points: points,
          );

    final result = await _repository.markComplete(
      writeRequest,
      awardGamificationPoints: awardGamificationPoints,
      creditsAchievement: creditsAchievement,
    );

    if (!result.isNew) return result;
    final completion = result.completion;

    // 3–5. Post-write side effects — best-effort, independently caught (see
    // the class doc comment, "Atomicity"). None may roll back the write.
    final source = CompletionSourceX.fromCredits(
      awardGamificationPoints: awardGamificationPoints,
      creditsAchievement: creditsAchievement,
    );

    if (creditsAchievement) {
      unawaited(
        _dispatchSiyumDetection(
          curriculumId: completion.curriculumId,
          sefariaRef: completion.sefariaRef,
          trackType: completion.trackType,
          source: source,
        ),
      );
    }

    await _safeStep(
      'completion_points_credit_failed',
      {'profileId': _activeProfileId, 'sefariaRef': completion.sefariaRef},
      () => _creditPointsIfAny(profileId: _activeProfileId, points: points),
    );

    if (awardGamificationPoints) {
      await _safeStep(
        'completion_streak_record_failed',
        {'profileId': _activeProfileId},
        () async {
          await _streakPort?.recordStudyDay(
            profileId: _activeProfileId,
            at: completion.completedAt,
          );
        },
      );
    }

    await _safeStep(
      'completion_bookmark_advance_failed',
      {
        'curriculumId': completion.curriculumId,
        'sefariaRef': completion.sefariaRef,
      },
      () => _advanceBookmark(
        curriculumId: completion.curriculumId,
        completedSefariaRef: completion.sefariaRef,
        profileId: _activeProfileId,
      ),
    );

    return result;
  }

  Future<void> _creditPointsIfAny({
    required int profileId,
    required int points,
  }) async {
    final port = _pointsPort;
    if (port == null || points <= 0) return;
    await port.creditCompletion(
      profileId: profileId,
      points: points,
      note: 'completion',
    );
  }

  // ──────────────────────────────── Bulk ─────────────────────────────────

  /// Mark multiple content items complete, running the same five behaviors
  /// as [markComplete] above [CompletionRepository.bulkMarkComplete].
  ///
  /// Order validation runs for every ref in [request.sefariaRefs] before any
  /// write (one batched read, not one query per ref — see the private
  /// [_validateBulkOrder] doc comment).
  Future<List<Completion>> bulkMarkComplete(
    BulkCompletionRequest request,
  ) async {
    if (request.sefariaRefs.isEmpty) return const [];
    final effectiveProfileId = request.profileId ?? _activeProfileId;

    await _validateBulkOrder(
      curriculumId: request.curriculumId,
      trackType: request.trackType,
      stageId: request.stageId,
      sefariaRefs: request.sefariaRefs,
      profileId: effectiveProfileId,
    );

    var points = 0;
    if (request.awardGamificationPoints && _pointsPort != null) {
      points = await _pointsPort.calculatePoints(
        curriculumId: request.curriculumId,
        stageOrder: request.stageId,
        profileId: effectiveProfileId,
      );
    }

    final writeRequest = points == request.points
        ? request
        : BulkCompletionRequest(
            curriculumId: request.curriculumId,
            sefariaRefs: request.sefariaRefs,
            stageId: request.stageId,
            trackType: request.trackType,
            profileId: request.profileId,
            awardGamificationPoints: request.awardGamificationPoints,
            creditsAchievement: request.creditsAchievement,
            completedAt: request.completedAt,
            points: points,
          );

    final completions = await _repository.bulkMarkComplete(writeRequest);
    if (completions.isEmpty) return completions;

    final source = CompletionSourceX.fromCredits(
      awardGamificationPoints: request.awardGamificationPoints,
      creditsAchievement: request.creditsAchievement,
    );

    // Awaited (not fire-and-forget, unlike the single-item path above) —
    // relocated verbatim from `CompletionRepositoryImpl.bulkMarkComplete`'s
    // own doc comment: "Each call is awaited so test code (and the live
    // UI's invalidation) sees a synchronous 'bulk insert + siyum ledger
    // update' boundary." Still independently caught (see [_safeStep]-style
    // handling inside [_dispatchSiyumDetectionForRefs] itself) so a siyum
    // failure cannot roll back the already-durable bulk write.
    if (request.creditsAchievement) {
      await _dispatchSiyumDetectionForRefs(
        curriculumId: request.curriculumId,
        sefariaRefs: completions.map((c) => c.sefariaRef).toList(),
        trackType: request.trackType,
        profileId: effectiveProfileId,
        source: source,
      );
    }

    // NOTE: unlike the single-item path, the bulk path never credited the
    // points BALANCE even before this lift — `_markCompleteSingleInTransaction`
    // stamped `points` onto each row (preserved above via [writeRequest]) but
    // `CompletionRepositoryImpl.bulkMarkComplete` never called
    // `PointsBalanceDao.creditCompletion`. No current caller reaches this
    // gate (`BulkPriorCompletionService` always passes
    // `awardGamificationPoints: false`), so this is a pre-existing gap in a
    // dead code path, preserved as-is rather than silently "fixed" here.
    if (request.awardGamificationPoints) {
      await _safeStep(
        'completion_streak_record_failed',
        {'profileId': effectiveProfileId},
        () async {
          await _streakPort?.recordStudyDay(
            profileId: effectiveProfileId,
            at: request.completedAt ?? completions.first.completedAt,
          );
        },
      );
    }

    await _safeStep(
      'completion_bookmark_advance_failed',
      {
        'curriculumId': request.curriculumId,
        'sefariaRef': request.sefariaRefs.last,
      },
      () => _advanceBookmark(
        curriculumId: request.curriculumId,
        completedSefariaRef: request.sefariaRefs.last,
        profileId: effectiveProfileId,
      ),
    );

    return completions;
  }

  // ───────────────────────────── Order validation ────────────────────────

  /// Throws [StageProgressionException] when [stageId] skips ahead of the
  /// highest stage already completed for [trackType] within [existing].
  void _validateOrder({
    required List<Completion> existing,
    required String trackType,
    required int stageId,
  }) {
    final trackCompletions = existing
        .where((c) => c.trackType == trackType)
        .toList();
    if (trackCompletions.isEmpty) {
      if (stageId != 1) {
        throw StageProgressionException(
          message: 'Must complete stage 1 before stage $stageId',
          attemptedStage: stageId,
          lastCompletedStage: null,
        );
      }
      return;
    }
    final completedStageIds = trackCompletions.map((c) => c.stageId).toList()
      ..sort();
    final lastCompleted = completedStageIds.last;
    if (stageId > lastCompleted + 1) {
      throw StageProgressionException(
        message:
            'Must complete stage ${lastCompleted + 1} before stage $stageId',
        attemptedStage: stageId,
        lastCompletedStage: lastCompleted,
      );
    }
  }

  /// Validates every ref in [sefariaRefs] against [stageId] using ONE
  /// batched read (`getCompletionsByCurriculum`) rather than one query per
  /// ref — mirrors the batching discipline `CompletionWriter`/`BulkPrior
  /// CompletionService` already use elsewhere in this codebase for the same
  /// reason (a full-masechta bulk-mark can touch hundreds of refs).
  Future<void> _validateBulkOrder({
    required String curriculumId,
    required String trackType,
    required int stageId,
    required List<String> sefariaRefs,
    required int profileId,
  }) async {
    final refSet = sefariaRefs.toSet();
    final existing = await _repository.getCompletionsByCurriculum(
      curriculumId,
      profileId: profileId,
    );
    final byRef = <String, List<Completion>>{};
    for (final c in existing) {
      if (c.trackType != trackType || !refSet.contains(c.sefariaRef)) {
        continue;
      }
      byRef.putIfAbsent(c.sefariaRef, () => []).add(c);
    }
    for (final ref in refSet) {
      _validateOrder(
        existing: byRef[ref] ?? const [],
        trackType: trackType,
        stageId: stageId,
      );
    }
  }

  // ───────────────────────────── Achievement (siyum) ─────────────────────

  Future<void> _dispatchSiyumDetection({
    required String curriculumId,
    required String sefariaRef,
    required String trackType,
    required CompletionSource source,
  }) async {
    final svc = _completionDetectionService;
    if (svc == null) return;
    try {
      await svc.checkAndRecordCompletions(
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        trackType: trackType,
        profileId: _activeProfileId,
        markedBy: _activeProfileId,
        source: source,
      );
    } catch (error, stackTrace) {
      AppLogger.instance.error(
        event: 'completion_siyum_detection_failed',
        fields: {
          'curriculumId': curriculumId,
          'sefariaRef': sefariaRef,
          'trackType': trackType,
        },
        exception: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Dispatches [CompletionDetectionService.checkAndRecordCompletions] for
  /// the distinct parent units (level1 + level2) reached by [sefariaRefs] —
  /// relocated verbatim from
  /// `CompletionRepositoryImpl._dispatchSiyumDetectionForRefs` (see that
  /// method's former doc comment in git history for the P0 duplicate/
  /// collision bugs this exact dedup-by-parent shape fixes).
  Future<void> _dispatchSiyumDetectionForRefs({
    required String curriculumId,
    required List<String> sefariaRefs,
    required String trackType,
    required int profileId,
    required CompletionSource source,
  }) async {
    final svc = _completionDetectionService;
    if (svc == null) return;

    final curriculum = CurriculumId.values.firstWhere(
      (c) => c.storageKey == curriculumId,
      orElse: () => throw ArgumentError('Unknown curriculumId: $curriculumId'),
    );
    final hasUnitLevel = hasNamedLevel2Unit(curriculum);

    final seenUnitKeys = <String>{};
    final unitLevelRefs = <String>[];
    final seenAggregateKeys = <String>{};
    final aggregateLevelRefs = <String>[];
    for (final ref in sefariaRefs) {
      final item = await _contentRepository.getContentByRef(
        curriculumId: curriculum,
        sefariaRef: ref,
      );
      if (item == null) continue;
      if (hasUnitLevel && item.level2 != null) {
        final unitKey = '${item.level1}::${item.level2}';
        if (seenUnitKeys.add(unitKey)) {
          unitLevelRefs.add(ref);
        }
      }
      if (seenAggregateKeys.add(item.level1)) {
        aggregateLevelRefs.add(ref);
      }
    }

    try {
      for (final ref in unitLevelRefs) {
        await svc.checkAndRecordCompletions(
          curriculumId: curriculumId,
          sefariaRef: ref,
          trackType: trackType,
          profileId: profileId,
          markedBy: profileId,
          source: source,
          includeAggregateLevelCheck: false,
        );
      }
      for (final ref in aggregateLevelRefs) {
        await svc.checkAndRecordCompletions(
          curriculumId: curriculumId,
          sefariaRef: ref,
          trackType: trackType,
          profileId: profileId,
          markedBy: profileId,
          source: source,
          includeUnitLevelCheck: false,
        );
      }
    } catch (error, stackTrace) {
      AppLogger.instance.error(
        event: 'completion_siyum_detection_failed',
        fields: {
          'curriculumId': curriculumId,
          'trackType': trackType,
          'itemCount': sefariaRefs.length,
        },
        exception: error,
        stackTrace: stackTrace,
      );
    }
  }

  // ───────────────────────────── Bookmark ─────────────────────────────────

  Future<void> _advanceBookmark({
    required String curriculumId,
    required String completedSefariaRef,
    required int profileId,
  }) async {
    final injected = _bookmarkRepository;
    final factory = _bookmarkRepositoryFactory;
    final BookmarkRepository? bookmarkRepo;
    if (injected != null && profileId == _activeProfileId) {
      bookmarkRepo = injected;
    } else if (factory != null) {
      bookmarkRepo = factory(profileId);
    } else {
      bookmarkRepo = injected;
    }
    if (bookmarkRepo == null) return;

    final curriculum = CurriculumId.values.firstWhere(
      (c) => c.storageKey == curriculumId,
      orElse: () => throw ArgumentError('Unknown curriculumId: $curriculumId'),
    );
    await bookmarkRepo.advanceBookmark(
      curriculumId: curriculum,
      completedSefariaRef: completedSefariaRef,
    );
  }

  // ───────────────────────────── Shared helpers ───────────────────────────

  /// Runs [step], logging (not rethrowing) any failure — see the class doc
  /// comment, "Atomicity": none of the post-write side effects may block or
  /// roll back the already-durable completion write.
  Future<void> _safeStep(
    String event,
    Map<String, Object?> fields,
    Future<void> Function() step,
  ) async {
    try {
      await step();
    } catch (error, stackTrace) {
      AppLogger.instance.error(
        event: event,
        fields: fields,
        exception: error,
        stackTrace: stackTrace,
      );
    }
  }
}

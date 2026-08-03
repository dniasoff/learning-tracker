import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/codec/streak_event_codec.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/learning/data/completion_writer.dart';
import 'package:learning_tracker/features/learning/data/repositories/bookmark_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_command.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/mark_completion_result.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart'
    as stage_model;
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';

/// Implementation of [CompletionRepository] using Drift database and sync engine.
class CompletionRepositoryImpl implements CompletionRepository {
  final UserDatabase _database;
  final SyncWriteFacade? _syncEngine;
  final OutboxSyncWriteFacade? _outboxFacade;
  final ContentRepository _contentRepository;
  final BookmarkRepository? _bookmarkRepository;
  final BookmarkRepository Function(int profileId)? _bookmarkRepositoryFactory;
  final CompletionDetectionService? _completionDetectionService;
  final int _activeProfileId;
  final CompletionWriter _completionWriter;
  final StageDefinitionRepository? _stageRepository;
  final RewardMilestoneService Function(int profileId)
  _rewardMilestoneServiceFactory;

  CompletionRepositoryImpl({
    required UserDatabase database,
    required SyncWriteFacade? syncEngine,
    required ContentRepository contentRepository,
    OutboxSyncWriteFacade? outboxFacade,
    BookmarkRepository? bookmarkRepository,
    BookmarkRepository Function(int profileId)? bookmarkRepositoryFactory,
    CompletionDetectionService? completionDetectionService,
    int activeProfileId = 0,
    CompletionWriter? completionWriter,
    StageDefinitionRepository? stageRepository,
    RewardMilestoneService Function(int profileId)?
    rewardMilestoneServiceFactory,
  }) : _database = database,
       _syncEngine = syncEngine,
       _outboxFacade = outboxFacade,
       _contentRepository = contentRepository,
       _bookmarkRepository = bookmarkRepository,
       _bookmarkRepositoryFactory = bookmarkRepositoryFactory,
       _completionDetectionService = completionDetectionService,
       _activeProfileId = activeProfileId,
       _completionWriter = completionWriter ?? CompletionWriter(database),
       _stageRepository = stageRepository,
       // AUD-learning-10 (SM-7): default preserves the prior ad-hoc-per-call
       // construction exactly (same `database`, per-call `profileId` — the
       // service is genuinely profile-scoped, e.g. bulk completions for a
       // delegated profile != activeProfileId, so a single shared instance
       // would be a correctness regression, not just a DI cleanup). Tests
       // gain a seam to inject a fake without exercising the real
       // Drift-backed service.
       _rewardMilestoneServiceFactory =
           rewardMilestoneServiceFactory ??
           ((profileId) =>
               RewardMilestoneService(database, profileId: profileId));

  @override
  Future<MarkCompletionResult> markComplete(
    CompletionRequest request, {
    bool awardGamificationPoints = true,
    bool creditsAchievement = true,
  }) async {
    final isChildProfile = await _isChildProfile();

    // Perform DB operations in a single transaction for atomicity.
    // Returns a record indicating whether the completion was newly created.
    final (:completion, :isNew) = await _database.transaction(() async {
      // 1. Get existing completions for this item (single query for both
      //    stage validation and duplicate check) — scoped to active profile
      //    so profiles cannot block each other's stage progression.
      final completions = await _database.completionDao
          .getCompletionsForContentAndProfile(
            request.sefariaRef,
            _activeProfileId,
          );

      // 2. Check for duplicate (idempotent) — match on the full natural key
      //    including curriculumId so a completion for the same
      //    (sefariaRef, stageId, trackType) in a DIFFERENT curriculum is not
      //    mis-identified as a duplicate. R6-19.
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

      // 3. Validate stage progression using already-fetched completions
      final trackCompletions = completions
          .where((c) => c.trackType == request.trackType)
          .toList();
      if (trackCompletions.isEmpty && request.stageId != 1) {
        throw StageProgressionException(
          message: 'Must complete stage 1 before stage ${request.stageId}',
          attemptedStage: request.stageId,
          lastCompletedStage: null,
        );
      }
      if (trackCompletions.isNotEmpty) {
        final completedStageIds =
            trackCompletions.map((c) => c.stageId).toList()..sort();
        final lastCompleted = completedStageIds.last;
        if (request.stageId > lastCompleted + 1) {
          throw StageProgressionException(
            message:
                'Must complete stage ${lastCompleted + 1} before stage ${request.stageId}',
            attemptedStage: request.stageId,
            lastCompletedStage: lastCompleted,
          );
        }
      }

      final trackId = await _resolveTrackId(
        curriculumId: request.curriculumId,
        trackType: request.trackType,
        profileId: _activeProfileId,
      );

      // 4. Calculate points for this stage (child only; programmed or self-paced
      //    tracks with a goal — not momentum-only / browse tracks.)
      //    B1: skip point calculation when awardGamificationPoints is false
      //    (bulkInTrack / lifetimeOnly sources — engagement tier suppressed).
      var points = 0;
      if (awardGamificationPoints) {
        final rewardService = _rewardMilestoneServiceFactory(_activeProfileId);
        final eligible = await rewardService.trackCountsTowardRewardPoints(
          trackId,
        );
        if (isChildProfile && eligible) {
          points = await _calculatePoints(
            curriculumId: request.curriculumId,
            stageOrder: request.stageId,
            trackId: trackId,
            profileId: _activeProfileId,
          );
        }
      }

      // 5. Create completion record. `_createCompletion` tees the
      //    write into `streak_events` (the append-only log) so the
      //    streak reducer in `core/streak/` derives state on read.
      //    No `StreakService.recordCompletion` call — DNI-337 removed
      //    the synchronous cached-table write path.
      //    B1: pass priorMarkOnly = !awardGamificationPoints so expunge
      //    can distinguish bulk-prior rows from live-learning rows.
      final created = await _createCompletion(
        request: request,
        trackId: trackId,
        points: points,
        profileId: _activeProfileId,
        priorMarkOnly: !awardGamificationPoints,
      );

      // 6. Advance bookmark INSIDE the same transaction (FR20; Story 27.9 /
      //    DNI-385; AUD-t-story-acceptance-01): a failure here must roll
      //    back the completion insert, not leave a persisted completion
      //    paired with an uncaught exception and a stale bookmark. This is
      //    safe because `_advanceBookmark`'s `BookmarkRepository` (injected,
      //    factory-built, or the ad-hoc fallback) is always constructed over
      //    this same `_database` instance in production — see
      //    `completionRepositoryProvider` / `bookmarkRepositoryProvider`,
      //    which both watch `userDatabaseProvider` — so its queries
      //    participate in this transaction instead of opening a second one.
      await _advanceBookmark(
        curriculumId: request.curriculumId,
        completedSefariaRef: request.sefariaRef,
      );

      return (completion: created, isNew: true);
    });

    var newMilestoneUnlocks = <RewardUnlockRecord>[];

    // Only run side effects for genuinely new completions
    if (isNew) {
      // 7. Auto-detect unit completions (fire-and-forget).
      // B1 three-tier policy: CompletionDetectionService creates siyum
      // ledger entries — an achievement-tier side-effect. Gate on
      // [creditsAchievement] (NOT on [awardGamificationPoints] — that's the
      // engagement gate). The two flags are independent:
      //   - live           → engagement=true,  achievement=true
      //   - bulkInTrack    → engagement=false, achievement=true  (still earns siyum)
      //   - lifetimeOnly   → engagement=false, achievement=false
      // Per completion_source.dart, bulkInTrack credits achievement so a
      // learner who bulk-marks a complete masechta still earns the siyum.
      if (_completionDetectionService != null && creditsAchievement) {
        // AUD-learning-01 / EH-3: this call is intentionally fire-and-forget
        // (a slow siyum scan must never block or fail the primary completion
        // write), but completion_detection_service.dart has no try/catch of
        // its own. Without a local catch path here, any failure (closed DB
        // mid profile-switch, a malformed content lookup, …) permanently and
        // silently drops the B1 siyum credit for this unit, surfaced only as
        // a generic "fatal" report by the global zone handler with no
        // domain context. Log it here instead so the failure — and which
        // completion caused it — is visible without depending on that
        // catch-all.
        unawaited(
          _completionDetectionService
              .checkAndRecordCompletions(
                curriculumId: request.curriculumId,
                sefariaRef: request.sefariaRef,
                trackType: request.trackType,
                profileId: _activeProfileId,
                markedBy: _activeProfileId,
              )
              .catchError((Object error, StackTrace stackTrace) {
                AppLogger.instance.error(
                  event: 'completion_siyum_detection_failed',
                  fields: {
                    'curriculumId': request.curriculumId,
                    'sefariaRef': request.sefariaRef,
                    'trackType': request.trackType,
                  },
                  exception: error,
                  stackTrace: stackTrace,
                );
              }),
        );
      }

      // B1: gamification credit is engagement-tier — skip for bulkInTrack /
      // lifetimeOnly sources (awardGamificationPoints = false).
      if (isChildProfile && awardGamificationPoints) {
        // WS7.balance: credit the stored debitable balance for every point
        // earned on a live completion. Awaited (Drift is in-process/fast; no
        // meaningful UI delay, and awaiting avoids DB-closed races in tests).
        if (completion.points > 0) {
          await _database.pointsBalanceDao.creditCompletion(
            _activeProfileId,
            completion.points,
            note: '${completion.curriculumId}:${completion.sefariaRef}',
          );
        }

        // R4o-C1 / DEC-32: the auto-unlock achievement ladder was replaced by
        // the spend economy — rewards are priced spend-items, not cumulative
        // auto-unlocks. No unlock evaluation runs on completion any more.
        newMilestoneUnlocks = const <RewardUnlockRecord>[];
        unawaited(_syncEngine?.pushGamificationSettingsSnapshot());
      }
    }

    return MarkCompletionResult(
      completion: completion,
      newMilestoneUnlocks: newMilestoneUnlocks,
    );
  }

  @override
  Future<List<Completion>> bulkMarkComplete(
    BulkCompletionRequest request,
  ) async {
    final effectiveProfileId = request.profileId ?? _activeProfileId;
    final isChildProfile = await _isProfileChild(effectiveProfileId);

    // Route ALL bulk-mark-prior writes (awardGamificationPoints == false)
    // through the streak-suppressing optimised path regardless of stage.
    // Previously the guard included `request.stageId == 1`, which caused
    // stages 2 and 3 to fall through to the slow path and wrongly insert a
    // streak event via `_createCompletion → _appendStreakEvent`.
    // See DNI-370 / Story 26.27.
    if (!request.awardGamificationPoints && request.sefariaRefs.isNotEmpty) {
      return _bulkMarkCompletePriorOptimized(
        request,
        effectiveProfileId: effectiveProfileId,
      );
    }

    final completions = await _database.transaction(() async {
      final completions = <Completion>[];

      for (final sefariaRef in request.sefariaRefs) {
        final singleRequest = CompletionRequest(
          curriculumId: request.curriculumId,
          sefariaRef: sefariaRef,
          stageId: request.stageId,
          trackType: request.trackType,
        );

        final completion = await _markCompleteSingleInTransaction(
          singleRequest,
          isChildProfile: isChildProfile,
          profileId: effectiveProfileId,
          awardGamificationPoints: request.awardGamificationPoints,
        );
        completions.add(completion);
      }

      return completions;
    });

    // RC2 fix: outbox is the ONLY completion queue. The legacy
    // pushCompletionsBatch (sync_queue) call has been removed; completions
    // are already enqueued via outbox inside _createCompletion → CompletionWriter.

    if (completions.isNotEmpty) {
      await _advanceBookmark(
        curriculumId: request.curriculumId,
        completedSefariaRef: request.sefariaRefs.last,
        bookmarkProfileId: effectiveProfileId,
      );
    }

    // R4o-C1 / DEC-32: the auto-unlock achievement ladder was replaced by the
    // spend economy. No unlock evaluation runs on the bulk path any more; we
    // still push the gamification snapshot so reward config stays in sync.
    if (isChildProfile &&
        completions.isNotEmpty &&
        request.awardGamificationPoints) {
      await _syncEngine?.pushGamificationSettingsSnapshot();
    }

    // F1 (W7-A): dispatch siyum detection after the bulk insert. The slow
    // path doesn't gate on `awardGamificationPoints` (engagement) — it gates
    // on `creditsAchievement` so bulkInTrack still earns siyumim even
    // though engagement is suppressed.
    if (request.creditsAchievement && completions.isNotEmpty) {
      await _dispatchSiyumDetectionForRefs(
        curriculumId: request.curriculumId,
        sefariaRefs: completions.map((c) => c.sefariaRef).toList(),
        trackType: request.trackType,
        profileId: effectiveProfileId,
        source: _bulkSourceFor(request),
      );
    }

    return completions;
  }

  Future<List<Completion>> _bulkMarkCompletePriorOptimized(
    BulkCompletionRequest request, {
    required int effectiveProfileId,
  }) async {
    final trackId = await _resolveTrackId(
      curriculumId: request.curriculumId,
      trackType: request.trackType,
      profileId: effectiveProfileId,
    );

    final existingRefs = await _database.completionDao
        .getExistingSefariaRefsForBulkStage(
          profileId: effectiveProfileId,
          curriculumId: request.curriculumId,
          stageId: request.stageId,
          trackType: request.trackType,
          sefariaRefs: request.sefariaRefs,
        );

    final toInsertUnique = <String>[];
    final dedupe = <String>{};
    for (final r in request.sefariaRefs) {
      if (existingRefs.contains(r)) continue;
      if (!dedupe.add(r)) continue;
      toInsertUnique.add(r);
    }

    final now = request.completedAt ?? DateTimeFactory.nowUtc();

    // FR15 / RC1 fix: route all writes through CompletionWriter.commitBatch
    // so ALL N completions land in a SINGLE Drift transaction (not N).
    // The list is already de-duplicated above via toInsertUnique.
    final commands = toInsertUnique
        .map(
          (ref) => CompletionCommand(
            profileId: effectiveProfileId,
            curriculumId: request.curriculumId,
            sefariaRef: ref,
            stageId: request.stageId,
            trackType: request.trackType,
            trackId: trackId,
            completedAt: now,
            points: 0,
            // B8: flag these rows as prior-marks so expunge can distinguish
            // them from genuine in-app learning events.
            priorMarkOnly: true,
            // B1: carry the real provenance (bulkInTrack vs lifetimeOnly) so the
            // writer persists prior_completion_imports.source correctly instead
            // of mis-tagging every import as 'bulkInTrack'.
            source: _bulkSourceFor(request),
          ),
        )
        .toList();
    await _completionWriter.commitBatch(commands);

    // Bulk-mark-prior is "I learned this in the past" — these completions
    // belong to historical learning, not today. They must NOT credit a
    // streak event (which would otherwise show "1 Day Streak" on fresh
    // install for anyone who used onboarding's bulk-mark step).

    final uniqueRefs = request.sefariaRefs.toSet().toList();
    final allRows = await _database.completionDao
        .getCompletionsForRefsBulkStage(
          profileId: effectiveProfileId,
          curriculumId: request.curriculumId,
          stageId: request.stageId,
          trackType: request.trackType,
          sefariaRefs: uniqueRefs,
        );
    final byRef = <String, Completion>{
      for (final c in allRows) c.sefariaRef: c,
    };

    // RC2 fix: outbox is now the ONLY completion queue. The legacy
    // pushCompletionsBatch call to sync_queue has been removed — each
    // completion_event written above already has a corresponding outbox row
    // committed atomically by CompletionWriter.commitBatch.

    final ordered = request.sefariaRefs.map((r) => byRef[r]!).toList();

    if (ordered.isNotEmpty) {
      await _advanceBookmark(
        curriculumId: request.curriculumId,
        completedSefariaRef: request.sefariaRefs.last,
        bookmarkProfileId: effectiveProfileId,
      );
    }

    // F1 (W7-A): dispatch siyum detection after the optimised bulk-prior
    // path completes. bulkInTrack credits achievement — without this call,
    // a learner who bulk-marks an entire masechta during onboarding would
    // see zero siyum entries in their journey ledger.
    if (request.creditsAchievement && ordered.isNotEmpty) {
      await _dispatchSiyumDetectionForRefs(
        curriculumId: request.curriculumId,
        sefariaRefs: ordered.map((c) => c.sefariaRef).toList(),
        trackType: request.trackType,
        profileId: effectiveProfileId,
        source: _bulkSourceFor(request),
      );
    }

    return ordered;
  }

  /// F1 (W7-A) — Dispatch [CompletionDetectionService.checkAndRecordCompletions]
  /// for the distinct parent units (level1 + level2) reached by [sefariaRefs].
  ///
  /// The detection service exits early when a parent unit has any leaves that
  /// are not yet fully completed — so it's safe to fire for every parent
  /// touched by a bulk insert. We dedupe by parent so the service runs at most
  /// once per `(curriculumId, level1)` and once per `(curriculumId, level2)`,
  /// not once per leaf.
  ///
  /// P0 fix: the unit-level (level2) check and the aggregate-level (level1)
  /// check are dispatched in two INDEPENDENT deduped passes, each calling
  /// [CompletionDetectionService.checkAndRecordCompletions] with only the
  /// half it needs (`includeUnitLevelCheck` / `includeAggregateLevelCheck`).
  /// Previously a single pass, deduped only by `(level1, level2)`, dispatched
  /// the ALWAYS-RUN aggregate check once per distinct level2 touched under a
  /// level1 — so bulk-marking 3 sefarim of Chumash (which have no real level2
  /// unit; see [hasNamedLevel2Unit]) fired the sefer-level check once per
  /// chapter instead of once per sefer, and a whole-seder Mishnayos bulk-mark
  /// would have fired the seder-level check once per masechta. The aggregate
  /// check now dispatches exactly once per distinct level1 in the batch.
  ///
  /// The unit-level pass is also skipped entirely for curricula whose level2
  /// is a bare positional chapter number rather than a real named unit
  /// (Chumash / Nach / Tanach / Mussar) — dispatching it there previously
  /// recorded a `masechta`-scoped ledger entry keyed by a bare chapter
  /// number (e.g. `'1'`), which collides across sefarim (Genesis ch. 1 and
  /// Shemos ch. 1 both read `'1'`) once aggregated in
  /// `journey_providers.dart`'s `_detectMilestones` — corrupting the total-
  /// units denominator and, in the case this fix addresses, firing a false
  /// "Chumash complete!" curriculum-level milestone after only 3 of 5
  /// sefarim (61.6%) were actually done.
  ///
  /// Each call is awaited so test code (and the live UI's invalidation) sees
  /// a synchronous "bulk insert + siyum ledger update" boundary.
  Future<void> _dispatchSiyumDetectionForRefs({
    required String curriculumId,
    required List<String> sefariaRefs,
    required String trackType,
    required int profileId,
    CompletionSource source = CompletionSource.live,
  }) async {
    final svc = _completionDetectionService;
    if (svc == null) return;

    final curriculum = CurriculumId.values.firstWhere(
      (c) => c.storageKey == curriculumId,
      orElse: () => throw ArgumentError('Unknown curriculumId: $curriculumId'),
    );
    final hasUnitLevel = hasNamedLevel2Unit(curriculum);

    // Resolve each ref into its content item once, feeding two independent
    // dedupe sets: one keyed by (level1, level2) for the unit-level check
    // (only populated when the curriculum has a real, named level2 unit),
    // one keyed by level1 alone for the aggregate-level check.
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
  }

  /// Derive the [CompletionSource] for a bulk request from its engagement /
  /// achievement gates (B1 three-tier policy). A bulk-in-track mark suppresses
  /// engagement but credits achievement → [CompletionSource.bulkInTrack]; a
  /// lifetime-only import credits neither → [CompletionSource.lifetimeOnly].
  static CompletionSource _bulkSourceFor(BulkCompletionRequest request) {
    if (request.awardGamificationPoints) return CompletionSource.live;
    if (request.creditsAchievement) return CompletionSource.bulkInTrack;
    return CompletionSource.lifetimeOnly;
  }

  /// Internal method used by the slow [bulkMarkComplete] path only.
  Future<Completion> _markCompleteSingleInTransaction(
    CompletionRequest request, {
    required bool isChildProfile,
    required int profileId,
    bool awardGamificationPoints = true,
  }) async {
    await _validateStageProgression(
      sefariaRef: request.sefariaRef,
      stageId: request.stageId,
      trackType: request.trackType,
      profileId: profileId,
    );

    final existing = await _getExistingCompletion(
      curriculumId: request.curriculumId,
      sefariaRef: request.sefariaRef,
      stageId: request.stageId,
      trackType: request.trackType,
      profileId: profileId,
    );
    if (existing != null) {
      return existing;
    }

    final trackId = await _resolveTrackId(
      curriculumId: request.curriculumId,
      trackType: request.trackType,
      profileId: profileId,
    );

    final rewardService = _rewardMilestoneServiceFactory(profileId);
    final eligibleForRewards = await rewardService
        .trackCountsTowardRewardPoints(trackId);
    final allowPoints =
        awardGamificationPoints && isChildProfile && eligibleForRewards;
    final points = allowPoints
        ? await _calculatePoints(
            curriculumId: request.curriculumId,
            stageOrder: request.stageId,
            trackId: trackId,
            profileId: profileId,
          )
        : 0;

    final completion = await _createCompletion(
      request: request,
      trackId: trackId,
      points: points,
      profileId: profileId,
      // Bulk-mark-prior ("I learned this in the past") opts out of
      // gamification; those completions are historical, so they must
      // not produce a `streak_events` row and must not credit a streak
      // (NFR13 / DNI-381).
      appendStreakEvent: awardGamificationPoints,
    );
    // No `StreakService.recordCompletion` — DNI-337: streak state is
    // derived from `streak_events` by `core/streak/StreakReducer`. The
    // event was teed in by `_createCompletion → _appendStreakEvent`.
    return completion;
  }

  /// Validate that stage progression rules are followed.
  ///
  /// Throws [StageProgressionException] if attempting to complete stage N+1
  /// before stage N.
  Future<void> _validateStageProgression({
    required String sefariaRef,
    required int stageId,
    required String trackType,
    required int profileId,
  }) async {
    // Get completions scoped to the active profile — stage progression
    // must not be blocked by another profile's history for the same item.
    final completions = await _database.completionDao
        .getCompletionsForContentAndProfile(sefariaRef, profileId);

    final trackCompletions = completions
        .where((c) => c.trackType == trackType)
        .toList();

    if (trackCompletions.isEmpty) {
      // First completion for this item+track, must be stage 1
      if (stageId != 1) {
        throw StageProgressionException(
          message: 'Must complete stage 1 before stage $stageId',
          attemptedStage: stageId,
          lastCompletedStage: null,
        );
      }
      return;
    }

    // Get the highest completed stage
    final completedStageIds = trackCompletions.map((c) => c.stageId).toList();
    completedStageIds.sort();
    final lastCompletedStage = completedStageIds.last;

    // Can only complete the next stage in sequence
    if (stageId > lastCompletedStage + 1) {
      throw StageProgressionException(
        message:
            'Must complete stage ${lastCompletedStage + 1} before stage $stageId',
        attemptedStage: stageId,
        lastCompletedStage: lastCompletedStage,
      );
    }
  }

  /// Check if this exact completion already exists (for idempotency),
  /// scoped to the active profile.
  ///
  /// [curriculumId] is included in the match so that a completion for the same
  /// (sefariaRef, stageId, trackType) in a DIFFERENT curriculum is not
  /// treated as a duplicate. R6-19.
  Future<Completion?> _getExistingCompletion({
    required String curriculumId,
    required String sefariaRef,
    required int stageId,
    required String trackType,
    required int profileId,
  }) async {
    final completions = await _database.completionDao
        .getCompletionsForContentAndProfile(sefariaRef, profileId);

    final matches = completions.where(
      (c) =>
          c.curriculumId == curriculumId &&
          c.stageId == stageId &&
          c.trackType == trackType,
    );
    return matches.isEmpty ? null : matches.first;
  }

  /// Calculate points for completing this stage.
  ///
  /// Queries point_configs table for configured point values per curriculum
  /// and stage. Falls back to default values (Learn=10, Chazara1=5, Chazara2=3)
  /// when no configuration exists.
  Future<int> _calculatePoints({
    required String curriculumId,
    required int stageOrder,
    required int trackId,
    required int profileId,
  }) async {
    // Check point_configs table for configured value
    final config = await _database.pointConfigDao.getConfig(
      curriculumId,
      stageOrder,
      profileId: profileId,
      trackId: trackId,
    );
    if (config != null) return config.points;

    // Default values when no config is present
    return switch (stageOrder) {
      1 => 10, // Learn
      2 => 5, // Chazara 1
      3 => 3, // Chazara 2
      _ => 1, // Any additional stages
    };
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
  /// row are written in one transaction.
  ///
  /// [priorMarkOnly] — set to true for bulkInTrack / lifetimeOnly sources
  /// so the `completion_events` row is flagged and expunge can target only
  /// prior-mark rows. When true, [appendStreakEvent] is implicitly false.
  Future<Completion> _createCompletion({
    required CompletionRequest request,
    required int trackId,
    required int points,
    required int profileId,
    bool appendStreakEvent = true,
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
        points: points,
        // B1: flag prior-mark rows so expunge (and the credit policy) can
        // distinguish them from live-learning rows.
        priorMarkOnly: priorMarkOnly,
      ),
    );

    // Tee the completion into the append-only streak event log
    // so the streak reducer can derive state independent of the
    // cached Streaks table. Unique keys swallow duplicates silently.
    // Skipped for prior-learning bulk marks (NFR13 / DNI-381).
    // B1: also skip for any source where priorMarkOnly = true (engagement
    // tier suppressed).
    // (Moves into CompletionWriter in DNI-337 / Story 25.16.)
    if (appendStreakEvent && !priorMarkOnly) {
      await _appendStreakEvent(profileId: profileId, at: now);
    }

    return result.completion;
  }

  /// Append a streak event locally and tee it into the outbox for cloud sync.
  ///
  /// The natural key `(profileId, dayUtc, eventType)` is UNIQUE (DNI-323),
  /// so the same completion teed twice in one day is an EXPECTED, benign
  /// conflict — `insertOrIgnore` below makes SQLite silently skip that row
  /// instead of throwing. There is nothing to catch or log for that specific
  /// case; it never reaches [_appendStreakEvent]'s catch clause at all.
  ///
  /// Phase 1 — streak events used to be local-only on completion; only the
  /// once-per-upgrade `LocalDataUploadService.pushAllLocalData` shipped them
  /// to Firestore, so day-to-day streaks never replicated and a second
  /// device saw a frozen streak. The outbox enqueue closes that gap: the
  /// payload is built via [StreakEventCodec.encode] so the push shape is
  /// canonical and the gateway writes to `streak_events/{ulid}`.
  static const _streakCodec = StreakEventCodec();

  Future<void> _appendStreakEvent({
    required int profileId,
    required DateTime at,
  }) async {
    try {
      final dayUtc = DateTime.utc(at.year, at.month, at.day);
      await _database
          .into(_database.streakEvents)
          .insert(
            StreakEventsCompanion.insert(
              profileId: profileId,
              eventType: 'completion',
              dayUtc: dayUtc,
              eventTimestamp: at,
            ),
            mode: drift.InsertMode.insertOrIgnore,
          );

      // Phase 1 — sync the streak event via the outbox. ULID encodes the
      // event timestamp so duplicate enqueues across two devices on the same
      // logical day collapse to one Firestore doc.
      final facade = _outboxFacade;
      if (facade != null) {
        final payload = _streakCodec.encode(
          StreakEventRow(
            profileId: profileId,
            eventType: 'completion',
            studyDate: dayUtc,
            createdAt: at,
            ulid: newUlid(at),
          ),
        );
        await facade.enqueueStreakPayload(payload);
      }
    } on Exception catch (e, stackTrace) {
      // AUD-learning-06 / EH-3 / EH-4: narrowed from a bare `catch (_)`,
      // which also trapped programming-error Errors (masking real bugs) and
      // logged nothing — a codec bug, closed-DB race, or genuine outbox
      // failure was indistinguishable from the benign duplicate-key case
      // documented above (which, per insertOrIgnore, never actually reaches
      // here). Every Exception that does reach this point is unexpected:
      // still never let this "telemetry tee" block or roll back the primary
      // completion write (this runs inside markComplete's transaction), but
      // always log it so the gap is visible in Crashlytics/Talker instead of
      // silently dropped.
      AppLogger.instance.error(
        event: 'completion_streak_tee_failed',
        fields: {'profileId': profileId},
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// True when the session active profile is child mode.
  Future<bool> _isChildProfile() async => _isProfileChild(_activeProfileId);

  Future<bool> _isProfileChild(int profileId) async {
    final profile = await _database.profileDao.getProfileById(profileId);
    // Serialisation layer (Drift row) — use fromStorageKey so the comparison
    // is enum-driven rather than a raw string comparison.
    return profile != null &&
        ProfileMode.fromStorageKey(profile.mode) == ProfileMode.child;
  }

  /// Advance the bookmark to the next item in learning order.
  ///
  /// Uses the injected [BookmarkRepository] when it matches [bookmarkProfileId]
  /// (or the session active profile). For delegated flows (e.g. parent +
  /// child track, bulk-mark-prior during onboarding) where the target
  /// profile differs, prefers [_bookmarkRepositoryFactory] — injected by
  /// `completionRepositoryProvider` with the same [BookmarkRepositoryImpl]
  /// wiring (including `ContentIndex`) as `bookmarkRepositoryProvider`, so
  /// delegated advances keep the O(1) adjacent-item fast path instead of
  /// silently falling back to an O(N) scan (AUD-learning-04). Only when
  /// neither is supplied (e.g. a test constructing this repository
  /// directly) does this build an ad-hoc, non-indexed
  /// [BookmarkRepositoryImpl] itself.
  Future<void> _advanceBookmark({
    required String curriculumId,
    required String completedSefariaRef,
    int? bookmarkProfileId,
  }) async {
    final pid = bookmarkProfileId ?? _activeProfileId;

    final injected = _bookmarkRepository;
    final factory = _bookmarkRepositoryFactory;
    late final BookmarkRepository bookmarkRepo;
    if (injected != null && pid == _activeProfileId) {
      bookmarkRepo = injected;
    } else if (factory != null) {
      bookmarkRepo = factory(pid);
    } else {
      bookmarkRepo = BookmarkRepositoryImpl(
        database: _database,
        syncEngine: _syncEngine,
        contentRepository: _contentRepository,
        profileId: pid,
      );
    }

    final curriculum = CurriculumId.values.firstWhere(
      (c) => c.storageKey == curriculumId,
      orElse: () => throw ArgumentError('Unknown curriculumId: $curriculumId'),
    );
    await bookmarkRepo.advanceBookmark(
      curriculumId: curriculum,
      completedSefariaRef: completedSefariaRef,
    );
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
/// / [CompletionSourceX.creditsAchievement]. [_sourceFor] is the inverse of
/// those two getters — the same derivation
/// [CompletionRepositoryImpl._bulkSourceFor] already uses for the bulk path,
/// generalized here to also cover the single-item path (Drift's own
/// `markComplete` does not need it there, since Drift stores a
/// `priorMarkOnly` bool rather than a `source` enum). Every currently-live
/// call site was audited (2026-08-03):
///   - `MarkCompletionUseCase` (only caller: `text_display_screen.dart`,
///     the "Mark Complete" button) → default `source = live` → `(true,
///     true)` → [CompletionSource.live].
///   - `BulkMarkCompletionUseCase` and `BulkPriorCompletionService` (the
///     onboarding "I already learned this" bulk-mark wizard) → always
///     `(false, true)` → [CompletionSource.bulkInTrack].
///   - No call site passes `(false, false)`
///     ([CompletionSource.lifetimeOnly]) today — see "`lifetimeOnly` is
///     rejected, not silently downgraded" below for what happens if one
///     ever does.
///   - No call site passes `(true, false)` — the one combination
///     [_sourceFor] cannot losslessly represent (it collapses to `live`,
///     silently granting achievement credit alongside engagement credit).
///     Flagged, not fixed: fixing it would mean widening [CompletionSource]
///     itself, out of this file's scope.
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
/// ## What this adapter does NOT do — read before ever flipping
/// `completionRepositoryProvider`
///
/// `FirestoreCompletionRepository`
/// (`lib/data/repositories/firestore_completion_repository.dart`) is a thin
/// CRUD/read layer — unlike `FirestoreBookmarkRepository`, which already
/// carries the bookmark feature's equivalent business logic
/// (`advanceBookmark`, `initializeBookmark`, next-item resolution), it has
/// no stage-progression validation, no points calculation, no
/// siyum/achievement detection, no bookmark advancement, and no
/// streak-event teeing. Those five behaviors are exactly what
/// [CompletionRepositoryImpl.markComplete] /
/// [CompletionRepositoryImpl.bulkMarkComplete] spend most of their body
/// doing, and none of them exist as a Firestore-repository primitive today.
/// This adapter's `markComplete`/`bulkMarkComplete` therefore do exactly one
/// thing: derive `source`, write the `completions` document(s), and return.
/// They do **not**:
///   - validate stage progression (a stage-3 mark with no stage-1/2 history
///     silently succeeds here, where Drift throws
///     [StageProgressionException]);
///   - calculate or award gamification points (`CompletionEntity.points` is
///     always written as `0`);
///   - advance the learner's bookmark;
///   - run `CompletionDetectionService`'s siyum/achievement detection;
///   - write a `streak_events` row.
///
/// **This matters more than the usual "not feature-complete yet" gap**
/// because a `live`-source completion is *permanent* —
/// `docs/firestore-rewrite-map.md`'s owner decision treats it as undoable.
/// A mis-ordered stage mark written through this adapter today could not be
/// corrected later. Closing this gap needs a deliberate design decision
/// (build the orchestration into a new layer above
/// `FirestoreCompletionRepository`, or fold it into
/// `MarkCompletionUseCase`/`BulkMarkCompletionUseCase`, which already own
/// the B1 gating and sit above whichever [CompletionRepository] is
/// injected) — not something to improvise inside this file. **Do not flip
/// `completionRepositoryProvider` to construct this class until that
/// decision is made and built.**
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

  /// Inverse of [CompletionSourceX.creditsEngagement] /
  /// [CompletionSourceX.creditsAchievement] — see the class doc comment,
  /// "`source` is a pure function of the two existing boolean gates."
  static CompletionSource _sourceFor({
    required bool awardGamificationPoints,
    required bool creditsAchievement,
  }) {
    if (awardGamificationPoints) return CompletionSource.live;
    if (creditsAchievement) return CompletionSource.bulkInTrack;
    return CompletionSource.lifetimeOnly;
  }

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
      return MarkCompletionResult(completion: _toDriftCompletion(existing));
    }

    final entity = CompletionEntity(
      curriculumId: curriculum,
      sefariaRef: request.sefariaRef,
      stageId: request.stageId,
      trackType: request.trackType,
      source: _sourceFor(
        awardGamificationPoints: awardGamificationPoints,
        creditsAchievement: creditsAchievement,
      ),
      completedAt: DateTimeFactory.nowUtc(), // P5: UTC timestamps
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
    final source = _sourceFor(
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

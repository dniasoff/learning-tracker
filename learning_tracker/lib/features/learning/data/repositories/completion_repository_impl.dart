import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/learning/completion_command.dart';
import 'package:learning_tracker/core/learning/completion_writer.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';
import 'package:learning_tracker/features/learning/data/repositories/bookmark_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/mark_completion_result.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';

/// Implementation of [CompletionRepository] using Drift database and sync engine.
class CompletionRepositoryImpl implements CompletionRepository {
  final UserDatabase _database;
  final SyncEngine? _syncEngine;
  final ContentRepository _contentRepository;
  final BookmarkRepository? _bookmarkRepository;
  final CompletionDetectionService? _completionDetectionService;
  final StreakService? _streakService;
  final RewardMilestoneService? _rewardMilestoneService;
  final int _activeProfileId;
  final CompletionWriter _completionWriter;

  CompletionRepositoryImpl({
    required UserDatabase database,
    required SyncEngine? syncEngine,
    required ContentRepository contentRepository,
    BookmarkRepository? bookmarkRepository,
    CompletionDetectionService? completionDetectionService,
    StreakService? streakService,
    RewardMilestoneService? rewardMilestoneService,
    int activeProfileId = 0,
    CompletionWriter? completionWriter,
  }) : _database = database,
       _syncEngine = syncEngine,
       _contentRepository = contentRepository,
       _bookmarkRepository = bookmarkRepository,
       _completionDetectionService = completionDetectionService,
       _streakService = streakService,
       _rewardMilestoneService = rewardMilestoneService,
       _activeProfileId = activeProfileId,
       _completionWriter = completionWriter ?? CompletionWriter(database);

  @override
  Future<MarkCompletionResult> markComplete(CompletionRequest request) async {
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

      // 2. Check for duplicate (idempotent)
      final existing = completions
          .where(
            (c) =>
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
      final rewardService = RewardMilestoneService(
        _database,
        profileId: _activeProfileId,
      );
      final eligibleForRewards = await rewardService
          .trackCountsTowardRewardPoints(trackId);
      final points = isChildProfile && eligibleForRewards
          ? await _calculatePoints(
              curriculumId: request.curriculumId,
              stageOrder: request.stageId,
              trackId: trackId,
              profileId: _activeProfileId,
            )
          : 0;

      // 5. Create completion record
      final created = await _createCompletion(
        request: request,
        trackId: trackId,
        points: points,
        profileId: _activeProfileId,
      );

      // 6. Update cached streak table so the dashboard reflects the new
      //    streak immediately — applies to both child and adult profiles.
      await _streakService?.recordCompletion(created.completedAt);

      return (completion: created, isNew: true);
    });

    var newMilestoneUnlocks = <RewardUnlockRecord>[];

    // Only run side effects for genuinely new completions
    if (isNew) {
      // 6. Advance bookmark (outside transaction — uses content repo cache)
      await _advanceBookmark(
        curriculumId: request.curriculumId,
        trackType: request.trackType,
        completedSefariaRef: request.sefariaRef,
      );

      // 7. Push to Firestore sync queue (fire-and-forget)
      unawaited(_syncCompletion(completion));

      // 8. Auto-detect unit completions (fire-and-forget)
      if (_completionDetectionService != null) {
        unawaited(
          _completionDetectionService.checkAndRecordCompletions(
            curriculumId: request.curriculumId,
            sefariaRef: request.sefariaRef,
            trackType: request.trackType,
            profileId: _activeProfileId,
            markedBy: _activeProfileId,
          ),
        );
      }

      if (isChildProfile) {
        final trackUnlocks =
            await _rewardMilestoneService?.evaluateUnlocksForTrack(
              completion.trackId,
            ) ??
            const <RewardUnlockRecord>[];
        final globalUnlocks =
            await _rewardMilestoneService?.evaluateUnlocksForGlobal() ??
            const <RewardUnlockRecord>[];
        newMilestoneUnlocks = [...trackUnlocks, ...globalUnlocks];
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

    if (!request.awardGamificationPoints &&
        request.stageId == 1 &&
        request.sefariaRefs.isNotEmpty) {
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

    final syncEngine = _syncEngine;
    if (completions.isNotEmpty && syncEngine != null) {
      await syncEngine.pushCompletionsBatch(
        completions.map(_completionToSyncPayload).toList(),
      );
    }

    if (completions.isNotEmpty) {
      await _advanceBookmark(
        curriculumId: request.curriculumId,
        trackType: request.trackType,
        completedSefariaRef: request.sefariaRefs.last,
        bookmarkProfileId: effectiveProfileId,
      );
    }

    if (isChildProfile &&
        completions.isNotEmpty &&
        request.awardGamificationPoints) {
      final RewardMilestoneService? rewardSvc;
      if (request.profileId != null && request.profileId != _activeProfileId) {
        rewardSvc = RewardMilestoneService(
          _database,
          profileId: effectiveProfileId,
        );
      } else {
        rewardSvc = _rewardMilestoneService;
      }
      if (rewardSvc != null) {
        final affectedTrackIds = completions.map((c) => c.trackId).toSet();
        for (final trackId in affectedTrackIds) {
          await rewardSvc.evaluateUnlocksForTrack(trackId);
        }
        await rewardSvc.evaluateUnlocksForGlobal();
        await _syncEngine?.pushGamificationSettingsSnapshot();
      }
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

    final now = DateTimeFactory.nowUtc();

    // FR15: route all writes through CompletionWriter so each completion
    // gets its own atomic (completion + outbox) transaction.
    for (final ref in toInsertUnique) {
      await _completionWriter.commit(
        CompletionCommand(
          profileId: effectiveProfileId,
          curriculumId: request.curriculumId,
          sefariaRef: ref,
          stageId: request.stageId,
          trackType: request.trackType,
          trackId: trackId,
          completedAt: now,
          points: 0,
        ),
      );
    }

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

    final insertedRefSet = toInsertUnique.toSet();
    final toSync = <Completion>[];
    for (final c in allRows) {
      if (insertedRefSet.contains(c.sefariaRef)) {
        toSync.add(c);
      }
    }
    final syncEngine = _syncEngine;
    if (toSync.isNotEmpty && syncEngine != null) {
      await syncEngine.pushCompletionsBatch(
        toSync.map(_completionToSyncPayload).toList(),
      );
    }

    final ordered = request.sefariaRefs.map((r) => byRef[r]!).toList();

    if (ordered.isNotEmpty) {
      await _advanceBookmark(
        curriculumId: request.curriculumId,
        trackType: request.trackType,
        completedSefariaRef: request.sefariaRefs.last,
        bookmarkProfileId: effectiveProfileId,
      );
    }

    return ordered;
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

    final rewardService = RewardMilestoneService(
      _database,
      profileId: profileId,
    );
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
    );

    final streak = StreakService(_database, profileId: profileId);
    await streak.recordCompletion(completion.completedAt);

    return completion;
  }

  Map<String, dynamic> _completionToSyncPayload(Completion completion) => {
    'profile_id': completion.profileId,
    'curriculum_id': completion.curriculumId,
    'content_item_id': completion.sefariaRef,
    'stage_id': completion.stageId,
    'track_type': completion.trackType,
    'track_id': completion.trackId,
    'completed_at': completion.completedAt.toIso8601String(),
    'points': completion.points,
  };

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
  Future<Completion?> _getExistingCompletion({
    required String sefariaRef,
    required int stageId,
    required String trackType,
    required int profileId,
  }) async {
    final completions = await _database.completionDao
        .getCompletionsForContentAndProfile(sefariaRef, profileId);

    final matches = completions.where(
      (c) => c.stageId == stageId && c.trackType == trackType,
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
    final track =
        await (_database.select(_database.curriculumTracks)
              ..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.curriculumId.equals(curriculumId) &
                    t.trackType.equals(trackType),
              )
              ..limit(1))
            .getSingleOrNull();
    if (track == null) {
      throw StateError(
        'No curriculum track found for profile=$profileId, '
        'curriculum=$curriculumId, trackType=$trackType',
      );
    }
    return track.id;
  }

  /// Create the completion record in the database.
  ///
  /// Delegates to [CompletionWriter] (FR15) so the completion row + outbox
  /// row are written in one transaction.
  Future<Completion> _createCompletion({
    required CompletionRequest request,
    required int trackId,
    required int points,
    required int profileId,
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
      ),
    );

    // Tee the completion into the append-only streak event log
    // so the streak reducer can derive state independent of the
    // cached Streaks table. Unique keys swallow duplicates silently.
    // (Moves into CompletionWriter in DNI-337 / Story 25.16.)
    await _appendStreakEvent(profileId: profileId, at: now);

    return result.completion;
  }

  /// Append a streak event. Silently ignores the unique-key conflict
  /// that happens when the same completion is teed twice (idempotent).
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
    } catch (_) {
      // Defensive: never let a telemetry tee block the primary write.
    }
  }

  /// True when the session active profile is child mode.
  Future<bool> _isChildProfile() async => _isProfileChild(_activeProfileId);

  Future<bool> _isProfileChild(int profileId) async {
    final profile = await _database.profileDao.getProfileById(profileId);
    return profile?.mode == 'child';
  }

  /// Advance the bookmark to the next item in learning order.
  ///
  /// Uses the injected [BookmarkRepository] when it matches [bookmarkProfileId]
  /// (or the session active profile); otherwise builds a profile-scoped
  /// [BookmarkRepositoryImpl] so delegated flows (e.g. parent + child track) sync
  /// the correct bookmark.
  Future<void> _advanceBookmark({
    required String curriculumId,
    required String trackType,
    required String completedSefariaRef,
    int? bookmarkProfileId,
  }) async {
    final pid = bookmarkProfileId ?? _activeProfileId;

    final injected = _bookmarkRepository;
    late final BookmarkRepository bookmarkRepo;
    if (injected != null && pid == _activeProfileId) {
      bookmarkRepo = injected;
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
    final track = TrackType.fromStorageKey(trackType);
    await bookmarkRepo.advanceBookmark(
      curriculumId: curriculum,
      trackType: track,
      completedSefariaRef: completedSefariaRef,
    );
  }

  /// Queue completion for Firestore sync.
  Future<void> _syncCompletion(Completion completion) async {
    await _syncEngine?.pushCompletion(_completionToSyncPayload(completion));
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
        final stages = await _database.stageDao.getStageDefinitionsByCurriculum(
          curriculumId,
        );
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

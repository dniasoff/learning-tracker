import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
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
  final int _activeProfileId;

  CompletionRepositoryImpl({
    required UserDatabase database,
    required SyncEngine? syncEngine,
    required ContentRepository contentRepository,
    BookmarkRepository? bookmarkRepository,
    CompletionDetectionService? completionDetectionService,
    StreakService? streakService,
    int activeProfileId = 0,
  }) : _database = database,
       _syncEngine = syncEngine,
       _contentRepository = contentRepository,
       _bookmarkRepository = bookmarkRepository,
       _completionDetectionService = completionDetectionService,
       _streakService = streakService,
       _activeProfileId = activeProfileId;

  @override
  Future<Completion> markComplete(CompletionRequest request) async {
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

      // 4. Calculate points for this stage
      final points = isChildProfile
          ? await _calculatePoints(
              curriculumId: request.curriculumId,
              stageOrder: request.stageId,
            )
          : 0;

      // 5. Create completion record
      final created = await _createCompletion(
        request: request,
        points: points,
        isChildProfile: isChildProfile,
      );

      // 6. Update cached streak table so the dashboard reflects the new
      //    streak immediately — applies to both child and adult profiles.
      await _streakService?.recordCompletion(created.completedAt);

      return (completion: created, isNew: true);
    });

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
    }

    return completion;
  }

  @override
  Future<List<Completion>> bulkMarkComplete(
    BulkCompletionRequest request,
  ) async {
    // Perform all operations in a single transaction
    final isChildProfile = await _isChildProfile();
    final completions = await _database.transaction(() async {
      final completions = <Completion>[];

      for (final sefariaRef in request.sefariaRefs) {
        final singleRequest = CompletionRequest(
          curriculumId: request.curriculumId,
          sefariaRef: sefariaRef,
          stageId: request.stageId,
          trackType: request.trackType,
        );

        // Use the same logic as single completion
        // Note: We're already in a transaction, so nested transactions
        // will be handled by Drift's transaction management
        final completion = await _markCompleteSingleInTransaction(
          singleRequest,
          isChildProfile: isChildProfile,
        );
        completions.add(completion);
      }

      return completions;
    });

    // Bulk flows (e.g. prior-learning mark) should not advance/sync bookmark
    // on every item. Advance once after the batch to keep UX responsive.
    if (completions.isNotEmpty) {
      await _advanceBookmark(
        curriculumId: request.curriculumId,
        trackType: request.trackType,
        completedSefariaRef: request.sefariaRefs.last,
      );
    }

    return completions;
  }

  /// Internal method to mark a single completion within an existing transaction.
  Future<Completion> _markCompleteSingleInTransaction(
    CompletionRequest request, {
    required bool isChildProfile,
  }) async {
    // Same logic as markComplete but assumes we're already in a transaction
    await _validateStageProgression(
      sefariaRef: request.sefariaRef,
      stageId: request.stageId,
      trackType: request.trackType,
    );

    final existing = await _getExistingCompletion(
      sefariaRef: request.sefariaRef,
      stageId: request.stageId,
      trackType: request.trackType,
    );
    if (existing != null) {
      return existing;
    }

    final points = isChildProfile
        ? await _calculatePoints(
            curriculumId: request.curriculumId,
            stageOrder: request.stageId,
          )
        : 0;

    final completion = await _createCompletion(
      request: request,
      points: points,
      isChildProfile: isChildProfile,
    );

    await _streakService?.recordCompletion(completion.completedAt);

    // Offline-first: do not block bulk-mark UX on network push.
    // SyncEngine will queue/push in the background.
    unawaited(_syncCompletion(completion));

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
  }) async {
    // Get completions scoped to the active profile — stage progression
    // must not be blocked by another profile's history for the same item.
    final completions = await _database.completionDao
        .getCompletionsForContentAndProfile(sefariaRef, _activeProfileId);

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
  }) async {
    final completions = await _database.completionDao
        .getCompletionsForContentAndProfile(sefariaRef, _activeProfileId);

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
  }) async {
    // Check point_configs table for configured value
    final config = await _database.pointConfigDao.getConfig(
      curriculumId,
      stageOrder,
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
  }) async {
    final track =
        await (_database.select(_database.curriculumTracks)
              ..where(
                (t) =>
                    t.profileId.equals(_activeProfileId) &
                    t.curriculumId.equals(curriculumId) &
                    t.trackType.equals(trackType),
              )
              ..limit(1))
            .getSingleOrNull();
    if (track == null) {
      throw StateError(
        'No curriculum track found for profile=$_activeProfileId, '
        'curriculum=$curriculumId, trackType=$trackType',
      );
    }
    return track.id;
  }

  /// Create the completion record in the database.
  Future<Completion> _createCompletion({
    required CompletionRequest request,
    required int points,
    required bool isChildProfile,
  }) async {
    final now = DateTimeFactory.nowUtc(); // P5: Store as UTC
    final trackId = await _resolveTrackId(
      curriculumId: request.curriculumId,
      trackType: request.trackType,
    );

    final id = await _database.completionDao.insertCompletion(
      CompletionsCompanion.insert(
        profileId: drift.Value(_activeProfileId),
        curriculumId: request.curriculumId,
        sefariaRef: request.sefariaRef,
        stageId: request.stageId,
        trackType: request.trackType,
        trackId: trackId,
        completedAt: now,
        points: drift.Value(points),
      ),
    );

    // Tee the completion into the append-only streak event log
    // so the streak reducer can derive state independent of the
    // cached Streaks table. Unique keys swallow duplicates silently.
    await _appendStreakEvent(profileId: _activeProfileId, at: now);

    // Retrieve the created completion
    final completion = await _database.completionDao.getCompletionById(id);
    if (completion == null) {
      throw StateError('Failed to retrieve created completion');
    }

    return completion;
  }

  /// Append a streak event. Silently ignores the unique-key conflict
  /// that happens when the same completion is teed twice (idempotent).
  Future<void> _appendStreakEvent({
    required int profileId,
    required DateTime at,
  }) async {
    try {
      await _database
          .into(_database.streakEvents)
          .insert(
            StreakEventsCompanion.insert(
              profileId: profileId,
              eventType: 'completion',
              eventTimestamp: at,
            ),
            mode: drift.InsertMode.insertOrIgnore,
          );
    } catch (_) {
      // Defensive: never let a telemetry tee block the primary write.
    }
  }

  /// True when the active profile is child mode.
  Future<bool> _isChildProfile() async {
    final profile = await _database.profileDao.getProfileById(_activeProfileId);
    return profile?.mode == 'child';
  }

  /// Advance the bookmark to the next item in learning order.
  ///
  /// Delegates to [BookmarkRepository] when available so that Firestore sync
  /// is triggered. Falls back to direct DAO access when no repository is
  /// injected (e.g. during tests that don't need sync).
  Future<void> _advanceBookmark({
    required String curriculumId,
    required String trackType,
    required String completedSefariaRef,
  }) async {
    if (_bookmarkRepository != null) {
      // Use BookmarkRepository so Firestore sync is triggered
      final curriculum = CurriculumId.values.firstWhere(
        (c) => c.storageKey == curriculumId,
        orElse: () =>
            throw ArgumentError('Unknown curriculumId: $curriculumId'),
      );
      final track = TrackType.fromStorageKey(trackType);
      await _bookmarkRepository.advanceBookmark(
        curriculumId: curriculum,
        trackType: track,
        completedSefariaRef: completedSefariaRef,
      );
      return;
    }

    // Fallback: direct DAO access scoped to active profile (no Firestore sync)
    final bookmark = await _database.bookmarkDao
        .getBookmarkByCurriculumTrackAndProfile(
          curriculumId,
          trackType,
          _activeProfileId,
        );

    if (bookmark == null) {
      final nextSefariaRef = await _getNextItemId(
        curriculumId: curriculumId,
        currentSefariaRef: completedSefariaRef,
      );

      if (nextSefariaRef != null) {
        await _database.bookmarkDao.insertBookmark(
          BookmarksCompanion.insert(
            profileId: drift.Value(_activeProfileId),
            curriculumId: curriculumId,
            sefariaRef: nextSefariaRef,
            trackType: trackType,
            updatedAt: DateTimeFactory.nowUtc(),
          ),
        );
      }
    } else if (bookmark.sefariaRef == completedSefariaRef) {
      final nextSefariaRef = await _getNextItemId(
        curriculumId: curriculumId,
        currentSefariaRef: completedSefariaRef,
      );

      if (nextSefariaRef != null) {
        await _database.bookmarkDao.updateBookmark(
          BookmarksCompanion(
            id: drift.Value(bookmark.id),
            profileId: drift.Value(bookmark.profileId),
            curriculumId: drift.Value(bookmark.curriculumId),
            trackType: drift.Value(bookmark.trackType),
            sefariaRef: drift.Value(nextSefariaRef),
            updatedAt: drift.Value(DateTimeFactory.nowUtc()),
          ),
        );
      }
    }
    // else: bookmark is on a different item, don't change it
  }

  /// Get the next content item sefariaRef in learning order.
  Future<String?> _getNextItemId({
    required String curriculumId,
    required String currentSefariaRef,
  }) async {
    // Parse curriculumId string to CurriculumId enum
    final curriculum = CurriculumId.values.firstWhere(
      (c) => c.storageKey == curriculumId,
    );

    // Get all leaf items for this curriculum from ContentRepository
    final allItems = await _contentRepository.getContentForCurriculum(
      curriculum,
    );

    // Filter to only leaf items and sort by sortOrder
    final leafItems = allItems.where((item) => item.isLeaf).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Find current item's position
    final currentIndex = leafItems.indexWhere(
      (item) => item.sefariaRef == currentSefariaRef,
    );
    if (currentIndex == -1 || currentIndex == leafItems.length - 1) {
      return null; // Current item not found or is the last item
    }

    return leafItems[currentIndex + 1].sefariaRef;
  }

  /// Queue completion for Firestore sync.
  Future<void> _syncCompletion(Completion completion) async {
    // Convert to Firestore document format (snake_case to match merge logic)
    final completionData = {
      'profile_id': completion.profileId,
      'curriculum_id': completion.curriculumId,
      'content_item_id': completion.sefariaRef,
      'stage_id': completion.stageId,
      'track_type': completion.trackType,
      'track_id': completion.trackId,
      'completed_at': completion.completedAt.toIso8601String(),
      'points': completion.points,
    };

    await _syncEngine?.pushCompletion(completionData);
  }

  @override
  Future<List<Completion>> getCompletionsByCurriculum(
    String curriculumId,
  ) async {
    return await _database.completionDao.getCompletionsByCurriculumAndProfile(
      curriculumId,
      _activeProfileId,
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
      final normalizedStage =
          knownOrders.contains(completion.stageId)
              ? completion.stageId
              : idToOrder[completion.stageId];
      if (normalizedStage == stageId) return true;
    }

    return false;
  }
}

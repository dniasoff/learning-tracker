import 'package:drift/drift.dart' as drift;
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';

/// Implementation of [CompletionRepository] using Drift database and sync engine.
class CompletionRepositoryImpl implements CompletionRepository {
  final AppDatabase _database;
  final SyncEngine _syncEngine;
  final ContentRepository _contentRepository;
  final BookmarkRepository? _bookmarkRepository;

  CompletionRepositoryImpl({
    required AppDatabase database,
    required SyncEngine syncEngine,
    required ContentRepository contentRepository,
    BookmarkRepository? bookmarkRepository,
  }) : _database = database,
       _syncEngine = syncEngine,
       _contentRepository = contentRepository,
       _bookmarkRepository = bookmarkRepository;

  @override
  Future<Completion> markComplete(CompletionRequest request) async {
    // Perform all operations in a single transaction for atomicity
    return await _database.transaction(() async {
      // 1. Validate stage progression
      await _validateStageProgression(
        sefariaRef: request.sefariaRef,
        stageId: request.stageId,
        trackType: request.trackType,
      );

      // 2. Check for duplicate (idempotent)
      final existing = await _getExistingCompletion(
        sefariaRef: request.sefariaRef,
        stageId: request.stageId,
        trackType: request.trackType,
      );
      if (existing != null) {
        return existing; // Already completed, return existing record
      }

      // 3. Calculate points for this stage
      final points = await _calculatePoints(
        curriculumId: request.curriculumId,
        stageId: request.stageId,
      );

      // 4. Create completion record
      final completion = await _createCompletion(
        request: request,
        points: points,
      );

      // 5. Advance bookmark to next item
      await _advanceBookmark(
        curriculumId: request.curriculumId,
        trackType: request.trackType,
        completedSefariaRef: request.sefariaRef,
      );

      // 6. Push to Firestore sync queue
      await _syncCompletion(completion);

      return completion;
    });
  }

  @override
  Future<List<Completion>> bulkMarkComplete(
    BulkCompletionRequest request,
  ) async {
    // Perform all operations in a single transaction
    return await _database.transaction(() async {
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
        final completion = await _markCompleteSingleInTransaction(singleRequest);
        completions.add(completion);
      }

      return completions;
    });
  }

  /// Internal method to mark a single completion within an existing transaction.
  Future<Completion> _markCompleteSingleInTransaction(
    CompletionRequest request,
  ) async {
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

    final points = await _calculatePoints(
      curriculumId: request.curriculumId,
      stageId: request.stageId,
    );

    final completion = await _createCompletion(
      request: request,
      points: points,
    );

    await _advanceBookmark(
      curriculumId: request.curriculumId,
      trackType: request.trackType,
      completedSefariaRef: request.sefariaRef,
    );

    await _syncCompletion(completion);

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
    // Get all stages for this curriculum (ordered by stageOrder)
    final completions = await _database.completionDao.getCompletionsForContent(
      sefariaRef,
    );

    // Filter to this track type
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

  /// Check if this exact completion already exists (for idempotency).
  Future<Completion?> _getExistingCompletion({
    required String sefariaRef,
    required int stageId,
    required String trackType,
  }) async {
    final completions = await _database.completionDao.getCompletionsForContent(
      sefariaRef,
    );

    final matches = completions.where(
      (c) => c.stageId == stageId && c.trackType == trackType,
    );
    return matches.isEmpty ? null : matches.first; // null if not found
  }

  /// Calculate points for completing this stage.
  ///
  /// Queries stage definitions for this curriculum and returns points based
  /// on the stage order (higher stages are worth more). Falls back to a
  /// default of 10 × stageOrder when no stage definitions are configured.
  Future<int> _calculatePoints({
    required String curriculumId,
    required int stageId,
  }) async {
    final stages = await _database.stageDao.getStageDefinitionsByCurriculum(
      curriculumId,
    );

    if (stages.isEmpty) {
      // No stage definitions configured — use stageId × 10 as a sensible default
      return stageId * 10;
    }

    // Match by stageOrder (stageId corresponds to the 1-based stageOrder)
    final matching = stages.where((s) => s.stageOrder == stageId);
    if (matching.isNotEmpty) {
      // Award stageOrder × 10 points (later stages worth more)
      return matching.first.stageOrder * 10;
    }

    // Fallback: multiply by 10
    return stageId * 10;
  }

  /// Create the completion record in the database.
  Future<Completion> _createCompletion({
    required CompletionRequest request,
    required int points,
  }) async {
    final now = DateTimeFactory.nowUtc(); // P5: Store as UTC

    final id = await _database.completionDao.insertCompletion(
      CompletionsCompanion.insert(
        curriculumId: request.curriculumId,
        sefariaRef: request.sefariaRef,
        stageId: request.stageId,
        trackType: request.trackType,
        completedAt: now,
        points: drift.Value(points),
      ),
    );

    // Retrieve the created completion
    final completion = await _database.completionDao.getCompletionById(id);
    if (completion == null) {
      throw StateError('Failed to retrieve created completion');
    }

    return completion;
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
        orElse: () => throw ArgumentError('Unknown curriculumId: $curriculumId'),
      );
      final track = TrackType.fromStorageKey(trackType);
      await _bookmarkRepository.advanceBookmark(
        curriculumId: curriculum,
        trackType: track,
        completedSefariaRef: completedSefariaRef,
      );
      return;
    }

    // Fallback: direct DAO access (no Firestore sync)
    final bookmark = await _database.bookmarkDao
        .getBookmarkByCurriculumAndTrack(curriculumId, trackType);

    if (bookmark == null) {
      final nextSefariaRef = await _getNextItemId(
        curriculumId: curriculumId,
        currentSefariaRef: completedSefariaRef,
      );

      if (nextSefariaRef != null) {
        await _database.bookmarkDao.insertBookmark(
          BookmarksCompanion.insert(
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
    // Convert to Firestore document format
    final completionData = {
      'curriculumId': completion.curriculumId,
      'sefariaRef': completion.sefariaRef,
      'stageId': completion.stageId,
      'trackType': completion.trackType,
      'completedAt': completion.completedAt.toIso8601String(),
      'points': completion.points,
    };

    await _syncEngine.pushCompletion(completionData);
  }

  @override
  Future<List<Completion>> getCompletionsByCurriculum(
    String curriculumId,
  ) async {
    return await _database.completionDao.getCompletionsByCurriculum(
      curriculumId,
    );
  }

  @override
  Future<List<Completion>> getCompletionsForContentItem(
    String sefariaRef,
  ) async {
    return await _database.completionDao.getCompletionsForContent(sefariaRef);
  }

  @override
  Future<bool> isStageCompleted({
    required String sefariaRef,
    required int stageId,
    required String trackType,
  }) async {
    final completions = await _database.completionDao.getCompletionsForContent(
      sefariaRef,
    );

    return completions.any(
      (c) => c.stageId == stageId && c.trackType == trackType,
    );
  }
}

import 'package:drift/drift.dart' as drift;
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';

/// Implementation of [CompletionRepository] using Drift database and sync engine.
class CompletionRepositoryImpl implements CompletionRepository {
  final AppDatabase _database;
  final SyncEngine _syncEngine;

  CompletionRepositoryImpl({
    required AppDatabase database,
    required SyncEngine syncEngine,
  })  : _database = database,
        _syncEngine = syncEngine;

  @override
  Future<Completion> markComplete(CompletionRequest request) async {
    // Perform all operations in a single transaction for atomicity
    return await _database.transaction(() async {
      // 1. Validate stage progression
      await _validateStageProgression(
        contentItemId: request.contentItemId,
        stageId: request.stageId,
        trackType: request.trackType,
      );

      // 2. Check for duplicate (idempotent)
      final existing = await _getExistingCompletion(
        contentItemId: request.contentItemId,
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
        completedItemId: request.contentItemId,
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

      for (final contentItemId in request.contentItemIds) {
        final singleRequest = CompletionRequest(
          curriculumId: request.curriculumId,
          contentItemId: contentItemId,
          stageId: request.stageId,
          trackType: request.trackType,
        );

        // Use the same logic as single completion
        // Note: We're already in a transaction, so nested transactions
        // will be handled by Drift's transaction management
        try {
          final completion = await _markCompleteSingleInTransaction(
            singleRequest,
          );
          completions.add(completion);
        } catch (e) {
          // If any item fails, the entire transaction will be rolled back
          rethrow;
        }
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
      contentItemId: request.contentItemId,
      stageId: request.stageId,
      trackType: request.trackType,
    );

    final existing = await _getExistingCompletion(
      contentItemId: request.contentItemId,
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
      completedItemId: request.contentItemId,
    );

    await _syncCompletion(completion);

    return completion;
  }

  /// Validate that stage progression rules are followed.
  ///
  /// Throws [StageProgressionException] if attempting to complete stage N+1
  /// before stage N.
  Future<void> _validateStageProgression({
    required int contentItemId,
    required int stageId,
    required String trackType,
  }) async {
    // Get all stages for this curriculum (ordered by stageOrder)
    final completions = await _database.completionDao
        .getCompletionsForContentItem(contentItemId);

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
    required int contentItemId,
    required int stageId,
    required String trackType,
  }) async {
    final completions = await _database.completionDao
        .getCompletionsForContentItem(contentItemId);

    try {
      return completions.firstWhere(
        (c) => c.stageId == stageId && c.trackType == trackType,
      );
    } catch (e) {
      return null; // Not found
    }
  }

  /// Calculate points for completing this stage.
  ///
  /// TODO: Get points from curriculum configuration or stage definitions.
  /// For now, uses a default value of 10 points per stage.
  Future<int> _calculatePoints({
    required String curriculumId,
    required int stageId,
  }) async {
    // TODO: Implement proper points calculation from curriculum config
    // For now, return a default value
    return 10;
  }

  /// Create the completion record in the database.
  Future<Completion> _createCompletion({
    required CompletionRequest request,
    required int points,
  }) async {
    final now = DateTime.now().toUtc(); // P5: Store as UTC

    final id = await _database.completionDao.insertCompletion(
      CompletionsCompanion.insert(
        curriculumId: request.curriculumId,
        contentItemId: request.contentItemId,
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
  Future<void> _advanceBookmark({
    required String curriculumId,
    required String trackType,
    required int completedItemId,
  }) async {
    // Get current bookmark
    final bookmark = await _database.bookmarkDao
        .getBookmarkByCurriculumAndTrack(curriculumId, trackType);

    if (bookmark == null) {
      // No bookmark exists yet, create one pointing to the next item
      final nextItemId = await _getNextItemId(
        curriculumId: curriculumId,
        currentItemId: completedItemId,
      );

      if (nextItemId != null) {
        await _database.bookmarkDao.insertBookmark(
          BookmarksCompanion.insert(
            curriculumId: curriculumId,
            contentItemId: nextItemId,
            trackType: trackType,
            lastUpdated: drift.Value(DateTime.now().toUtc()),
          ),
        );
      }
    } else if (bookmark.contentItemId == completedItemId) {
      // Bookmark is on this item, advance it
      final nextItemId = await _getNextItemId(
        curriculumId: curriculumId,
        currentItemId: completedItemId,
      );

      if (nextItemId != null) {
        await _database.bookmarkDao.updateBookmark(
          bookmark.copyWith(
            contentItemId: nextItemId,
            lastUpdated: drift.Value(DateTime.now().toUtc()),
          ),
        );
      }
    }
    // else: bookmark is on a different item, don't change it
  }

  /// Get the next content item ID in learning order.
  Future<int?> _getNextItemId({
    required String curriculumId,
    required int currentItemId,
  }) async {
    // Get all leaf items for this curriculum, ordered by learning_order
    final allItems = await (_database.select(_database.contentItems)
          ..where((t) =>
              t.curriculumId.equals(curriculumId) & t.isLeaf.equals(true))
          ..orderBy([(t) => drift.OrderingTerm.asc(t.learningOrder)]))
        .get();

    // Find current item's position
    final currentIndex = allItems.indexWhere((item) => item.id == currentItemId);
    if (currentIndex == -1 || currentIndex == allItems.length - 1) {
      return null; // Current item not found or is the last item
    }

    return allItems[currentIndex + 1].id;
  }

  /// Queue completion for Firestore sync.
  Future<void> _syncCompletion(Completion completion) async {
    // Convert to Firestore document format
    final completionData = {
      'curriculumId': completion.curriculumId,
      'contentItemId': completion.contentItemId,
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
    return await _database.completionDao.getCompletionsByCurriculum(curriculumId);
  }

  @override
  Future<List<Completion>> getCompletionsForContentItem(
    int contentItemId,
  ) async {
    return await _database.completionDao
        .getCompletionsForContentItem(contentItemId);
  }

  @override
  Future<bool> isStageCompleted({
    required int contentItemId,
    required int stageId,
    required String trackType,
  }) async {
    final completions = await _database.completionDao
        .getCompletionsForContentItem(contentItemId);

    return completions.any(
      (c) => c.stageId == stageId && c.trackType == trackType,
    );
  }
}

import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';

/// Implementation of [CompletionRepository] using Drift database and sync engine.
class CompletionRepositoryImpl implements CompletionRepository {
  final AppDatabase _database;
  final SyncEngine _syncEngine;
  final ContentRepository _contentRepository;
  final BookmarkRepository? _bookmarkRepository;
  final CompletionDetectionService? _completionDetectionService;
  final int _activeProfileId;

  CompletionRepositoryImpl({
    required AppDatabase database,
    required SyncEngine syncEngine,
    required ContentRepository contentRepository,
    BookmarkRepository? bookmarkRepository,
    CompletionDetectionService? completionDetectionService,
    int activeProfileId = 0,
  }) : _database = database,
       _syncEngine = syncEngine,
       _contentRepository = contentRepository,
       _bookmarkRepository = bookmarkRepository,
       _completionDetectionService = completionDetectionService,
       _activeProfileId = activeProfileId;

  @override
  Future<Completion> markComplete(CompletionRequest request) async {
    // Perform DB operations in a single transaction for atomicity
    final completion = await _database.transaction(() async {
      // 1. Get existing completions for this item (single query for both
      //    stage validation and duplicate check)
      final completions =
          await _database.completionDao.getCompletionsForContent(
        request.sefariaRef,
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
        return existing;
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
      final points = await _calculatePoints(
        curriculumId: request.curriculumId,
        stageOrder: request.stageId,
      );

      // 5. Create completion record
      return await _createCompletion(request: request, points: points);
    });

    // 6. Advance bookmark (outside transaction — uses content repo cache)
    unawaited(_advanceBookmark(
      curriculumId: request.curriculumId,
      trackType: request.trackType,
      completedSefariaRef: request.sefariaRef,
    ));

    // 7. Push to Firestore sync queue (fire-and-forget)
    unawaited(_syncCompletion(completion));

    return completion;
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
        final completion = await _markCompleteSingleInTransaction(
          singleRequest,
        );
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
      stageOrder: request.stageId,
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

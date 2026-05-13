import 'dart:async';

import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/bookmark_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';

/// Result of a bulk prior completion operation.
class BulkPriorCompletionResult {
  final int itemCount;
  final int completionCount;
  final String? bookmarkSefariaRef;

  const BulkPriorCompletionResult({
    required this.itemCount,
    required this.completionCount,
    this.bookmarkSefariaRef,
  });
}

/// Service for bulk-marking prior completions during onboarding.
///
/// Resolves hierarchy selections (e.g., "all of Seder Zeraim") into
/// individual leaf items, creates completion records for selected stages,
/// and sets the bookmark to the first uncompleted item.
class BulkPriorCompletionService {
  final ContentRepository _contentRepository;
  final CompletionRepository _completionRepository;
  final BookmarkRepository _bookmarkRepository;
  final UserDatabase _database;
  final SyncEngine? _syncEngine;
  final AnalyticsService _analytics;

  /// Cached content items from the last [resolveSelections] call.
  List<ContentItem>? _cachedAllItems;
  CurriculumId? _cachedCurriculumId;

  BulkPriorCompletionService({
    required ContentRepository contentRepository,
    required CompletionRepository completionRepository,
    required BookmarkRepository bookmarkRepository,
    required UserDatabase database,
    SyncEngine? syncEngine,
    AnalyticsService? analytics,
  }) : _contentRepository = contentRepository,
       _completionRepository = completionRepository,
       _bookmarkRepository = bookmarkRepository,
       _database = database,
       _syncEngine = syncEngine,
       _analytics = analytics ?? const NullAnalyticsService();

  /// Resolve hierarchy selections into leaf-level sefariaRefs.
  ///
  /// Each selection can be at any level (seder, masechta, perek, or individual
  /// mishna). Container selections expand to all leaf items within.
  Future<List<ContentItem>> resolveSelections({
    required CurriculumId curriculumId,
    required List<HierarchySelection> selections,
  }) async {
    final allItems = await _contentRepository.getContentForCurriculum(
      curriculumId,
    );
    _cachedAllItems = allItems;
    _cachedCurriculumId = curriculumId;
    final leafItems = allItems.where((item) => item.isLeaf).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final selectedRefs = <String>{};

    for (final selection in selections) {
      // Filter all items matching this selection's hierarchy levels
      final matchingLeaves = leafItems.where((item) {
        if (selection.level1 != null && item.level1 != selection.level1) {
          return false;
        }
        if (selection.level2 != null && item.level2 != selection.level2) {
          return false;
        }
        if (selection.level3 != null && item.level3 != selection.level3) {
          return false;
        }
        if (selection.level4 != null && item.level4 != selection.level4) {
          return false;
        }
        return true;
      });

      for (final item in matchingLeaves) {
        selectedRefs.add(item.sefariaRef);
      }
    }

    return leafItems
        .where((item) => selectedRefs.contains(item.sefariaRef))
        .toList();
  }

  /// Execute bulk mark of prior completions.
  ///
  /// Creates completion records for all resolved leaf items at the specified
  /// stages, using the personal track. Runs as a single transaction.
  /// After completion, sets the bookmark to the first uncompleted item.
  Future<BulkPriorCompletionResult> execute({
    required CurriculumId curriculumId,
    required List<ContentItem> resolvedItems,
    required List<int> stageIds,
    int? profileId,
    bool awardGamificationPoints = false,
  }) async {
    final sefariaRefs = resolvedItems.map((item) => item.sefariaRef).toList();
    var totalCompletions = 0;

    // Create completions for each stage
    for (final stageId in stageIds) {
      final request = BulkCompletionRequest(
        curriculumId: curriculumId.storageKey,
        sefariaRefs: sefariaRefs,
        stageId: stageId,
        trackType: TrackType.personal.storageKey,
        profileId: profileId,
        awardGamificationPoints: awardGamificationPoints,
      );
      final completions = await _completionRepository.bulkMarkComplete(request);
      totalCompletions += completions.length;
    }

    // Query DB for all existing completions for this curriculum
    final existingCompletions = await _completionRepository
        .getCompletionsByCurriculum(
          curriculumId.storageKey,
          profileId: profileId,
        );
    final allCompletedRefs = {
      ...sefariaRefs,
      ...existingCompletions.map((c) => c.sefariaRef),
    };

    // Set bookmark to first uncompleted item
    final bookmarkRef = await _findFirstUncompletedItem(
      curriculumId: curriculumId,
      completedRefs: allCompletedRefs,
    );

    if (bookmarkRef != null) {
      final bookmarkRepo = profileId != null
          ? BookmarkRepositoryImpl(
              database: _database,
              syncEngine: _syncEngine,
              contentRepository: _contentRepository,
              profileId: profileId,
            )
          : _bookmarkRepository;
      await bookmarkRepo.setBookmark(
        curriculumId: curriculumId,
        trackType: TrackType.personal,
        sefariaRef: bookmarkRef,
      );
    }

    // Story 27.14 (DNI-390): fire analytics event when bulk-mark-prior completes.
    unawaited(
      _analytics.logBulkMarkPriorUsed(
        itemCount: sefariaRefs.length,
        completionCount: totalCompletions,
      ),
    );

    return BulkPriorCompletionResult(
      itemCount: sefariaRefs.length,
      completionCount: totalCompletions,
      bookmarkSefariaRef: bookmarkRef,
    );
  }

  /// Find the first uncompleted leaf item in learning order.
  Future<String?> _findFirstUncompletedItem({
    required CurriculumId curriculumId,
    required Set<String> completedRefs,
  }) async {
    final allItems =
        (_cachedCurriculumId == curriculumId && _cachedAllItems != null)
        ? _cachedAllItems!
        : await _contentRepository.getContentForCurriculum(curriculumId);
    final leafItems = allItems.where((item) => item.isLeaf).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (final item in leafItems) {
      if (!completedRefs.contains(item.sefariaRef)) {
        return item.sefariaRef;
      }
    }
    return null; // All items completed
  }
}

/// Represents a hierarchy-level selection (e.g., "Seder Zeraim" or
/// "Masechta Berachos" or individual "Berachos 1:1").
class HierarchySelection {
  final String? level1;
  final String? level2;
  final String? level3;
  final String? level4;

  const HierarchySelection({
    this.level1,
    this.level2,
    this.level3,
    this.level4,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HierarchySelection &&
          level1 == other.level1 &&
          level2 == other.level2 &&
          level3 == other.level3 &&
          level4 == other.level4;

  @override
  int get hashCode => Object.hash(level1, level2, level3, level4);
}

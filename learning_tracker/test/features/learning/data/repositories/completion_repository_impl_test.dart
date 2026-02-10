import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_database.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  late AppDatabase database;
  late MockSyncEngine mockSyncEngine;
  late CompletionRepositoryImpl repository;

  setUp(() {
    database = createTestDatabase();
    mockSyncEngine = MockSyncEngine();
    repository = CompletionRepositoryImpl(
      database: database,
      syncEngine: mockSyncEngine,
    );

    // Set up mock for sync engine
    when(
      () => mockSyncEngine.pushCompletion(any()),
    ).thenAnswer((_) async => Future.value());
  });

  tearDown(() async {
    await database.close();
  });

  group('markComplete', () {
    test('creates completion record with correct data', () async {
      // Arrange: Create prerequisite data
      const curriculumId = 'mishna';
      final sefariaRef = await _createContentItem(database, curriculumId);
      const stageId = 1;

      final request = CompletionRequest(
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        stageId: stageId,
        trackType: 'personal',
      );

      // Act
      final completion = await repository.markComplete(request);

      // Assert
      expect(completion.curriculumId, curriculumId);
      expect(completion.sefariaRef, sefariaRef);
      expect(completion.stageId, stageId);
      expect(completion.trackType, 'personal');
      expect(completion.points, 10); // Default points
      expect(completion.id, greaterThan(0)); // Record was created

      // Verify sync was triggered
      verify(() => mockSyncEngine.pushCompletion(any())).called(1);
    });

    test('throws StageProgressionException when skipping stages', () async {
      // Arrange: Create item and complete stage 1
      const curriculumId = 'mishna';
      final sefariaRef = await _createContentItem(database, curriculumId);

      final stage1Request = CompletionRequest(
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        stageId: 1,
        trackType: 'personal',
      );
      await repository.markComplete(stage1Request);

      // Try to complete stage 3 before stage 2
      final stage3Request = CompletionRequest(
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        stageId: 3,
        trackType: 'personal',
      );

      // Act & Assert
      expect(
        () => repository.markComplete(stage3Request),
        throwsA(isA<StageProgressionException>()),
      );
    });

    test('is idempotent - returns existing completion', () async {
      // Arrange: Create and complete an item
      const curriculumId = 'mishna';
      final sefariaRef = await _createContentItem(database, curriculumId);

      final request = CompletionRequest(
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        stageId: 1,
        trackType: 'personal',
      );

      final firstCompletion = await repository.markComplete(request);

      // Act: Try to complete the same item/stage again
      final secondCompletion = await repository.markComplete(request);

      // Assert: Should return the same completion
      expect(secondCompletion.id, firstCompletion.id);
      expect(secondCompletion.completedAt, firstCompletion.completedAt);

      // Sync should only be called once (for first completion, not for returning existing)
      verify(() => mockSyncEngine.pushCompletion(any())).called(1);
    });

    test('advances bookmark to next item', () async {
      // Arrange: Create two content items
      const curriculumId = 'mishna';
      final item1 = await _createContentItem(
        database,
        curriculumId,
        sortOrder: 1,
      );
      final item2 = await _createContentItem(
        database,
        curriculumId,
        sortOrder: 2,
      );

      // Create bookmark on item1
      await database.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          curriculumId: curriculumId,
          sefariaRef: item1,
          trackType: 'personal',
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      final request = CompletionRequest(
        curriculumId: curriculumId,
        sefariaRef: item1,
        stageId: 1,
        trackType: 'personal',
      );

      // Act
      await repository.markComplete(request);

      // Assert: Bookmark should now point to item2
      final bookmark = await database.bookmarkDao
          .getBookmarkByCurriculumAndTrack(curriculumId, 'personal');
      expect(bookmark?.sefariaRef, item2);
    });

    test('enforces stage progression per track', () async {
      // Arrange: Complete stage 1 on personal track
      const curriculumId = 'mishna';
      final sefariaRef = await _createContentItem(database, curriculumId);

      final personalRequest = CompletionRequest(
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        stageId: 1,
        trackType: 'personal',
      );
      await repository.markComplete(personalRequest);

      // Act: Should be able to complete stage 1 on chavrusa track
      final chavrusaRequest = CompletionRequest(
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        stageId: 1,
        trackType: 'chavrusa',
      );

      // Assert: Should not throw
      final completion = await repository.markComplete(chavrusaRequest);
      expect(completion.trackType, 'chavrusa');
    });
  });

  group('bulkMarkComplete', () {
    test('marks multiple items in single transaction', () async {
      // Arrange: Create multiple items
      const curriculumId = 'mishna';
      final item1 = await _createContentItem(database, curriculumId);
      final item2 = await _createContentItem(database, curriculumId);
      final item3 = await _createContentItem(database, curriculumId);

      final request = BulkCompletionRequest(
        curriculumId: curriculumId,
        sefariaRefs: [item1, item2, item3],
        stageId: 1,
        trackType: 'personal',
      );

      // Act
      final completions = await repository.bulkMarkComplete(request);

      // Assert
      expect(completions.length, 3);
      expect(completions[0].sefariaRef, item1);
      expect(completions[1].sefariaRef, item2);
      expect(completions[2].sefariaRef, item3);

      // Verify all were synced
      verify(() => mockSyncEngine.pushCompletion(any())).called(3);
    });

    test('rolls back on error', () async {
      // Arrange: Create items, but set up one to fail
      const curriculumId = 'mishna';
      final item1 = await _createContentItem(database, curriculumId);

      // Complete stage 1 for item1, then try bulk complete stage 3
      final stage1Request = CompletionRequest(
        curriculumId: curriculumId,
        sefariaRef: item1,
        stageId: 1,
        trackType: 'personal',
      );
      await repository.markComplete(stage1Request);

      final item2 = await _createContentItem(database, curriculumId);

      // Bulk request with stage 3 (should fail for item1 due to progression)
      final bulkRequest = BulkCompletionRequest(
        curriculumId: curriculumId,
        sefariaRefs: [item1, item2],
        stageId: 3,
        trackType: 'personal',
      );

      // Act & Assert: Should throw and not create any completions
      expect(
        () => repository.bulkMarkComplete(bulkRequest),
        throwsA(isA<StageProgressionException>()),
      );

      // Verify item2 was not completed (transaction rolled back)
      final item2Completions = await repository.getCompletionsForContentItem(
        item2,
      );
      expect(item2Completions, isEmpty);
    });
  });

  group('isStageCompleted', () {
    test('returns true for completed stage', () async {
      // Arrange
      const curriculumId = 'mishna';
      final sefariaRef = await _createContentItem(database, curriculumId);

      final request = CompletionRequest(
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        stageId: 1,
        trackType: 'personal',
      );
      await repository.markComplete(request);

      // Act
      final isCompleted = await repository.isStageCompleted(
        sefariaRef: sefariaRef,
        stageId: 1,
        trackType: 'personal',
      );

      // Assert
      expect(isCompleted, true);
    });

    test('returns false for non-completed stage', () async {
      // Arrange
      const curriculumId = 'mishna';
      final sefariaRef = await _createContentItem(database, curriculumId);

      // Act
      final isCompleted = await repository.isStageCompleted(
        sefariaRef: sefariaRef,
        stageId: 1,
        trackType: 'personal',
      );

      // Assert
      expect(isCompleted, false);
    });
  });
}

/// Helper to create a test content item
Future<int> _createContentItem(
  AppDatabase database,
  String curriculumId, {
  int sortOrder = 1,
}) async {
  return await database
      .into(database.contentItems)
      .insert(
        ContentItemsCompanion.insert(
          curriculumId: curriculumId,
          level1: 'Berachos',
          displayNameHe: 'ברכות',
          displayNameEn: 'Berachos',
          sortOrder: sortOrder,
          isLeaf: true,
        ),
      );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_database.dart';

class MockSyncEngine extends Mock implements SyncEngine {}

class MockContentRepository extends Mock implements ContentRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });
  late UserDatabase database;
  late MockSyncEngine mockSyncEngine;
  late MockContentRepository mockContentRepository;
  late CompletionRepositoryImpl repository;
  late int trackId;

  setUp(() async {
    database = createTestDatabase();
    mockSyncEngine = MockSyncEngine();
    mockContentRepository = MockContentRepository();

    final trackRow = await database
        .into(database.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            curriculumId: 'mishnayos',
            trackType: 'personal',
            activatedAt: DateTime.now(),
          ),
        );
    trackId = trackRow.id;

    // Also create a school track for tests that use it
    await database
        .into(database.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            curriculumId: 'mishnayos',
            trackType: 'school',
            activatedAt: DateTime.now(),
          ),
        );

    repository = CompletionRepositoryImpl(
      database: database,
      syncEngine: mockSyncEngine,
      contentRepository: mockContentRepository,
    );

    // Default: no content items (bookmark advance is a no-op)
    when(
      () => mockContentRepository.getContentForCurriculum(any()),
    ).thenAnswer((_) async => []);

    // Sync engine stubs
    when(
      () => mockSyncEngine.pushCompletion(any()),
    ).thenAnswer((_) async => Future.value());
  });

  tearDown(() async {
    await database.close();
  });

  group('markComplete', () {
    test('creates completion record with correct data', () async {
      const curriculumId = 'mishnayos';
      const sefariaRef = 'Mishnah Berachot 1:1';
      const stageId = 1;

      const request = CompletionRequest(
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        stageId: stageId,
        trackType: 'personal',
      );

      final completion = await repository.markComplete(request);

      expect(completion.curriculumId, curriculumId);
      expect(completion.sefariaRef, sefariaRef);
      expect(completion.stageId, stageId);
      expect(completion.trackType, 'personal');
      expect(completion.points, greaterThan(0));
      expect(completion.id, greaterThan(0));

      verify(() => mockSyncEngine.pushCompletion(any())).called(1);
    });

    test('throws StageProgressionException when skipping stages', () async {
      const curriculumId = 'mishnayos';
      const sefariaRef = 'Mishnah Berachot 1:1';

      // Complete stage 1 first
      await repository.markComplete(
        const CompletionRequest(
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: 1,
          trackType: 'personal',
        ),
      );

      // Try stage 3, skipping stage 2
      expect(
        () => repository.markComplete(
          const CompletionRequest(
            curriculumId: curriculumId,
            sefariaRef: sefariaRef,
            stageId: 3,
            trackType: 'personal',
          ),
        ),
        throwsA(isA<StageProgressionException>()),
      );
    });

    test('is idempotent — returns existing completion on duplicate', () async {
      const curriculumId = 'mishnayos';
      const sefariaRef = 'Mishnah Berachot 1:1';
      const request = CompletionRequest(
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        stageId: 1,
        trackType: 'personal',
      );

      final first = await repository.markComplete(request);
      final second = await repository.markComplete(request);

      expect(second.id, first.id);
      expect(second.completedAt, first.completedAt);

      // Sync only called once (for the first completion)
      verify(() => mockSyncEngine.pushCompletion(any())).called(1);
    });

    test('enforces stage progression per track independently', () async {
      const curriculumId = 'mishnayos';
      const sefariaRef = 'Mishnah Berachot 1:1';

      await repository.markComplete(
        const CompletionRequest(
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: 1,
          trackType: 'personal',
        ),
      );

      // Stage 1 on a different track should succeed without requiring
      // stage 1 to be completed on that track first.
      final chavrusaCompletion = await repository.markComplete(
        const CompletionRequest(
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: 1,
          trackType: 'school',
        ),
      );
      expect(chavrusaCompletion.trackType, 'school');
    });

    test(
      'points scale with stage order when stage definitions are present',
      () async {
        const curriculumId = 'mishnayos';

        // Insert stage definitions so _calculatePoints can find them
        await database.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            curriculumId: curriculumId,
            trackId: trackId,
            stageOrder: 1,
            stageName: 'Learning',
            delayDays: 0,
          ),
        );
        await database.stageDao.insertStageDefinition(
          StageDefinitionsCompanion.insert(
            curriculumId: curriculumId,
            trackId: trackId,
            stageOrder: 2,
            stageName: 'Chazara 1',
            delayDays: 1,
          ),
        );

        // Stage 1 completion
        final c1 = await repository.markComplete(
          const CompletionRequest(
            curriculumId: curriculumId,
            sefariaRef: 'Mishnah Berachot 1:1',
            stageId: 1,
            trackType: 'personal',
          ),
        );

        // Stage 2 completion (same ref, different stage)
        final c2 = await repository.markComplete(
          const CompletionRequest(
            curriculumId: curriculumId,
            sefariaRef: 'Mishnah Berachot 1:1',
            stageId: 2,
            trackType: 'personal',
          ),
        );

        // Points differ by stage: Learn=10, Chazara1=5 (default config)
        expect(c1.points, isNot(equals(c2.points)));
      },
    );
  });

  group('bulkMarkComplete', () {
    test('marks multiple items in a single transaction', () async {
      const curriculumId = 'mishnayos';
      final refs = [
        'Mishnah Berachot 1:1',
        'Mishnah Berachot 1:2',
        'Mishnah Berachot 1:3',
      ];

      final completions = await repository.bulkMarkComplete(
        BulkCompletionRequest(
          curriculumId: curriculumId,
          sefariaRefs: refs,
          stageId: 1,
          trackType: 'personal',
        ),
      );

      expect(completions.length, 3);
      expect(completions.map((c) => c.sefariaRef).toList(), refs);
      verify(() => mockSyncEngine.pushCompletion(any())).called(3);
    });
  });

  group('isStageCompleted', () {
    test('returns true for a completed stage', () async {
      const sefariaRef = 'Mishnah Berachot 1:1';
      await repository.markComplete(
        const CompletionRequest(
          curriculumId: 'mishnayos',
          sefariaRef: sefariaRef,
          stageId: 1,
          trackType: 'personal',
        ),
      );

      final result = await repository.isStageCompleted(
        sefariaRef: sefariaRef,
        stageId: 1,
        trackType: 'personal',
      );
      expect(result, isTrue);
    });

    test('returns false for a non-completed stage', () async {
      const sefariaRef = 'Mishnah Berachot 1:1';

      final result = await repository.isStageCompleted(
        sefariaRef: sefariaRef,
        stageId: 1,
        trackType: 'personal',
      );
      expect(result, isFalse);
    });
  });

  group('advances bookmark', () {
    test('advances bookmark when content repository returns items', () async {
      const curriculumId = 'mishnayos';
      const ref1 = 'Mishnah Berachot 1:1';
      const ref2 = 'Mishnah Berachot 1:2';

      // Stub content repository to return two leaf items in order
      when(
        () => mockContentRepository.getContentForCurriculum(any()),
      ).thenAnswer(
        (_) async => [
          const ContentItem(
            curriculumId: 'mishnayos',
            sefariaRef: ref1,
            displayNameEn: 'Berachot 1:1',
            displayNameHe: '',
            isLeaf: true,
            sortOrder: 1,
            level1: 'Seder Zeraim',
          ),
          const ContentItem(
            curriculumId: 'mishnayos',
            sefariaRef: ref2,
            displayNameEn: 'Berachot 1:2',
            displayNameHe: '',
            isLeaf: true,
            sortOrder: 2,
            level1: 'Seder Zeraim',
          ),
        ],
      );

      // Create a bookmark on ref1
      await database.bookmarkDao.insertBookmark(
        BookmarksCompanion.insert(
          curriculumId: curriculumId,
          sefariaRef: ref1,
          trackType: 'personal',
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      await repository.markComplete(
        const CompletionRequest(
          curriculumId: curriculumId,
          sefariaRef: ref1,
          stageId: 1,
          trackType: 'personal',
        ),
      );

      final bookmark = await database.bookmarkDao
          .getBookmarkByCurriculumAndTrack(curriculumId, 'personal');
      expect(bookmark?.sefariaRef, ref2);
    });
  });
}

/// Story acceptance tests for Epic 3 -- Learning Cycle.
@Tags(['epic_3'])
library;

import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/test_database.dart';

class _MockSyncEngine extends Mock implements SyncEngine {}

class _MockContentRepository extends Mock implements ContentRepository {}

AppDatabase _db() => createTestDatabase();

CompletionRepositoryImpl _repo(
  AppDatabase db,
  SyncEngine engine,
  ContentRepository content,
) => CompletionRepositoryImpl(
  database: db,
  syncEngine: engine,
  contentRepository: content,
);

/// Five-item default stub for ContentRepository.
List<ContentItem> _fiveItems() => List.generate(
  5,
  (i) => ContentItem(
    curriculumId: 'mishnayos',
    sefariaRef: 'Ref ${i + 1}',
    displayNameEn: 'Item ${i + 1}',
    displayNameHe: '',
    isLeaf: true,
    sortOrder: i + 1,
    level1: 'Level',
  ),
);

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  // ── Story 3.1: Record completion ──────────────────────────────

  group('Story 3.1 -- Record completion', tags: ['story_3_1'], () {
    late AppDatabase db;
    late _MockSyncEngine syncEngine;
    late _MockContentRepository contentRepo;
    late CompletionRepositoryImpl repo;

    setUp(() {
      db = _db();
      syncEngine = _MockSyncEngine();
      contentRepo = _MockContentRepository();
      repo = _repo(db, syncEngine, contentRepo);

      when(() => syncEngine.pushCompletion(any())).thenAnswer((_) async {});
      when(
        () => contentRepo.getContentForCurriculum(any()),
      ).thenAnswer((_) async => []);
    });

    tearDown(() async => db.close());

    test(
      'completing a content item records a DB row with correct fields',
      () async {
        const sefariaRef = 'Mishnah Berachot 1:1';
        final completion = await repo.markComplete(
          const CompletionRequest(
            curriculumId: 'mishnayos',
            sefariaRef: sefariaRef,
            stageId: 1,
            trackType: 'personal',
          ),
        );

        expect(completion.id, greaterThan(0));
        expect(completion.curriculumId, 'mishnayos');
        expect(completion.sefariaRef, sefariaRef);
        expect(completion.stageId, 1);
        expect(completion.trackType, 'personal');
        // completedAt should be close to now (within 5 seconds)
        expect(
          DateTime.now().difference(completion.completedAt).abs().inSeconds,
          lessThan(5),
        );
      },
    );

    test('completion emits points based on stage', () async {
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: 1,
          stageName: 'Learning',
          delayDays: 0,
        ),
      );
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: 2,
          stageName: 'Chazara 1',
          delayDays: 1,
        ),
      );

      final c1 = await repo.markComplete(
        const CompletionRequest(
          curriculumId: 'mishnayos',
          sefariaRef: 'Mishnah Berachot 1:1',
          stageId: 1,
          trackType: 'personal',
        ),
      );
      final c2 = await repo.markComplete(
        const CompletionRequest(
          curriculumId: 'mishnayos',
          sefariaRef: 'Mishnah Berachot 1:1',
          stageId: 2,
          trackType: 'personal',
        ),
      );

      // Points differ by stage: Learn=10, Chazara1=5 (default config)
      expect(c1.points, isNot(equals(c2.points)));
    });

    test('duplicate completion for same stage is idempotent', () async {
      const request = CompletionRequest(
        curriculumId: 'mishnayos',
        sefariaRef: 'Mishnah Berachot 1:1',
        stageId: 1,
        trackType: 'personal',
      );

      final first = await repo.markComplete(request);
      final second = await repo.markComplete(request);

      expect(second.id, first.id);
      verify(() => syncEngine.pushCompletion(any())).called(1);
    });
  });

  // ── Story 3.2: Chazara stages ─────────────────────────────────

  group('Story 3.2 -- Chazara stages', tags: ['story_3_2'], () {
    late AppDatabase db;
    late _MockSyncEngine syncEngine;
    late _MockContentRepository contentRepo;
    late CompletionRepositoryImpl repo;

    setUp(() {
      db = _db();
      syncEngine = _MockSyncEngine();
      contentRepo = _MockContentRepository();
      repo = _repo(db, syncEngine, contentRepo);

      when(() => syncEngine.pushCompletion(any())).thenAnswer((_) async {});
      when(
        () => contentRepo.getContentForCurriculum(any()),
      ).thenAnswer((_) async => []);
    });

    tearDown(() async => db.close());

    test('stage definitions are loaded for each curriculum', () async {
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: 1,
          stageName: 'Learning',
          delayDays: 0,
        ),
      );
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: 2,
          stageName: 'Chazara 1',
          delayDays: 7,
        ),
      );

      final stages = await db.stageDao.getStageDefinitionsByCurriculum(
        'mishnayos',
      );

      expect(stages.length, 2);
      expect(stages[0].delayDays, 0);
      expect(stages[1].delayDays, 7);
    });

    test(
      'completing stage N unlocks the ability to complete stage N+1',
      () async {
        const sefariaRef = 'Mishnah Berachot 1:1';

        await repo.markComplete(
          const CompletionRequest(
            curriculumId: 'mishnayos',
            sefariaRef: sefariaRef,
            stageId: 1,
            trackType: 'personal',
          ),
        );

        final c2 = await repo.markComplete(
          const CompletionRequest(
            curriculumId: 'mishnayos',
            sefariaRef: sefariaRef,
            stageId: 2,
            trackType: 'personal',
          ),
        );
        expect(c2.stageId, 2);
      },
    );

    test('replaceStagesForCurriculum replaces all stage definitions', () async {
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: 1,
          stageName: 'Old Stage',
          delayDays: 5,
        ),
      );

      await db.stageDao.replaceStagesForCurriculum('mishnayos', [
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: 1,
          stageName: 'New Stage 1',
          delayDays: 0,
        ),
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: 2,
          stageName: 'New Stage 2',
          delayDays: 14,
        ),
      ]);

      final stages = await db.stageDao.getStageDefinitionsByCurriculum(
        'mishnayos',
      );
      expect(stages.length, 2);
      expect(stages[0].stageName, 'New Stage 1');
      expect(stages[1].stageName, 'New Stage 2');
    });
  });

  // ── Story 3.3: Progress tracking ──────────────────────────────

  group('Story 3.3 -- Progress tracking', tags: ['story_3_3'], () {
    late AppDatabase db;
    late _MockSyncEngine syncEngine;
    late _MockContentRepository contentRepo;
    late CompletionRepositoryImpl repo;

    setUp(() {
      db = _db();
      syncEngine = _MockSyncEngine();
      contentRepo = _MockContentRepository();
      repo = _repo(db, syncEngine, contentRepo);

      when(() => syncEngine.pushCompletion(any())).thenAnswer((_) async {});
      when(
        () => contentRepo.getContentForCurriculum(any()),
      ).thenAnswer((_) async => _fiveItems());
    });

    tearDown(() async => db.close());

    test(
      'getCompletionsByCurriculum returns all recorded completions',
      () async {
        const curriculumId = 'mishnayos';
        for (var i = 1; i <= 3; i++) {
          await repo.markComplete(
            CompletionRequest(
              curriculumId: curriculumId,
              sefariaRef: 'Ref $i',
              stageId: 1,
              trackType: 'personal',
            ),
          );
        }

        final completions = await repo.getCompletionsByCurriculum(curriculumId);
        expect(completions.length, 3);
      },
    );

    test(
      'progress percentage can be derived from completions vs total items',
      () async {
        const curriculumId = 'mishnayos';
        // Complete 2 of the 5 available items
        for (var i = 1; i <= 2; i++) {
          await repo.markComplete(
            CompletionRequest(
              curriculumId: curriculumId,
              sefariaRef: 'Ref $i',
              stageId: 1,
              trackType: 'personal',
            ),
          );
        }

        final progressRepo = ProgressRepositoryImpl(database: db);
        final totalCompleted = await progressRepo.getAggregateCount(
          curriculumId,
        );

        // AC: 2 completions recorded
        expect(totalCompleted, 2);

        // AC: 5 items in the curriculum
        final allItems = await contentRepo.getContentForCurriculum(
          CurriculumId.mishnayos,
        );
        expect(allItems.length, 5);

        // AC: progress = 40%
        final pct = totalCompleted / allItems.length;
        expect(pct, closeTo(0.4, 0.01));
      },
    );
  });
}

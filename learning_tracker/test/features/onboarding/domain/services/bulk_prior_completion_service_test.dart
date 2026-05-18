import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/stages/domain/models/stage_definition.dart'
    as stage_model;
import 'package:learning_tracker/features/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockContentRepository extends Mock implements ContentRepository {}

class MockCompletionRepository extends Mock implements CompletionRepository {}

class MockBookmarkRepository extends Mock implements BookmarkRepository {}

class MockStageDefinitionRepository extends Mock
    implements StageDefinitionRepository {}

ContentItem _leaf({
  required String ref,
  required int sortOrder,
  String level1 = 'L1',
  String? level2,
  String? level3,
  String? level4,
}) {
  return ContentItem(
    curriculumId: 'mishnayos',
    level1: level1,
    level2: level2,
    level3: level3,
    level4: level4,
    displayNameHe: ref,
    displayNameEn: ref,
    sefariaRef: ref,
    sortOrder: sortOrder,
    isLeaf: true,
  );
}

ContentItem _container({
  required String ref,
  required int sortOrder,
  String level1 = 'L1',
}) {
  return ContentItem(
    curriculumId: 'mishnayos',
    level1: level1,
    displayNameHe: ref,
    displayNameEn: ref,
    sefariaRef: ref,
    sortOrder: sortOrder,
    isLeaf: false,
  );
}

/// Minimal [stage_model.StageDefinition] for tests — only [stageOrder] matters.
stage_model.StageDefinition _stageDef(int order) => stage_model.StageDefinition(
  id: order,
  curriculumId: CurriculumId.mishnayos,
  stageOrder: order,
  stageName: order == 1 ? 'Learn' : 'Chazara $order',
  delayDays: 0,
  isDefault: true,
);

void main() {
  late MockContentRepository contentRepo;
  late MockCompletionRepository completionRepo;
  late MockBookmarkRepository bookmarkRepo;
  late UserDatabase memoryDb;
  late BulkPriorCompletionService service;

  const curriculum = CurriculumId.mishnayos;

  setUpAll(() {
    registerFallbackValue(
      const BulkCompletionRequest(
        curriculumId: '',
        sefariaRefs: [],
        stageId: 0,
        trackType: '',
      ),
    );
    registerFallbackValue(CurriculumId.mishnayos);
    registerFallbackValue(TrackType.personal);
  });

  setUp(() {
    memoryDb = UserDatabase(NativeDatabase.memory());
    contentRepo = MockContentRepository();
    completionRepo = MockCompletionRepository();
    bookmarkRepo = MockBookmarkRepository();
    service = BulkPriorCompletionService(
      contentRepository: contentRepo,
      completionRepository: completionRepo,
      bookmarkRepository: bookmarkRepo,
      database: memoryDb,
      syncEngine: null,
    );
  });

  tearDown(() async {
    await memoryDb.close();
  });

  group('resolveSelections', () {
    test('returns leaf items matching level1 selection', () async {
      when(() => contentRepo.getContentForCurriculum(curriculum)).thenAnswer(
        (_) async => [
          _container(ref: 'seder_a', sortOrder: 0, level1: 'Zeraim'),
          _leaf(ref: 'z_1', sortOrder: 1, level1: 'Zeraim', level2: 'Berachos'),
          _leaf(ref: 'z_2', sortOrder: 2, level1: 'Zeraim', level2: 'Peah'),
          _leaf(ref: 'm_1', sortOrder: 3, level1: 'Moed', level2: 'Shabbos'),
        ],
      );

      final result = await service.resolveSelections(
        curriculumId: curriculum,
        selections: [const HierarchySelection(level1: 'Zeraim')],
      );

      expect(result.length, 2);
      expect(result.map((e) => e.sefariaRef), ['z_1', 'z_2']);
    });

    test('returns leaf items matching level2 selection', () async {
      when(() => contentRepo.getContentForCurriculum(curriculum)).thenAnswer(
        (_) async => [
          _leaf(
            ref: 'z_b_1',
            sortOrder: 1,
            level1: 'Zeraim',
            level2: 'Berachos',
          ),
          _leaf(
            ref: 'z_b_2',
            sortOrder: 2,
            level1: 'Zeraim',
            level2: 'Berachos',
          ),
          _leaf(ref: 'z_p_1', sortOrder: 3, level1: 'Zeraim', level2: 'Peah'),
        ],
      );

      final result = await service.resolveSelections(
        curriculumId: curriculum,
        selections: [
          const HierarchySelection(level1: 'Zeraim', level2: 'Berachos'),
        ],
      );

      expect(result.length, 2);
      expect(result.map((e) => e.sefariaRef), ['z_b_1', 'z_b_2']);
    });

    test('deduplicates across overlapping selections', () async {
      when(() => contentRepo.getContentForCurriculum(curriculum)).thenAnswer(
        (_) async => [
          _leaf(
            ref: 'z_b_1',
            sortOrder: 1,
            level1: 'Zeraim',
            level2: 'Berachos',
          ),
          _leaf(ref: 'z_p_1', sortOrder: 2, level1: 'Zeraim', level2: 'Peah'),
        ],
      );

      final result = await service.resolveSelections(
        curriculumId: curriculum,
        selections: [
          const HierarchySelection(level1: 'Zeraim'),
          const HierarchySelection(level1: 'Zeraim', level2: 'Berachos'),
        ],
      );

      expect(result.length, 2); // no duplicates
    });

    test('excludes containers from results', () async {
      when(() => contentRepo.getContentForCurriculum(curriculum)).thenAnswer(
        (_) async => [
          _container(ref: 'seder', sortOrder: 0, level1: 'Zeraim'),
          _leaf(ref: 'leaf1', sortOrder: 1, level1: 'Zeraim'),
        ],
      );

      final result = await service.resolveSelections(
        curriculumId: curriculum,
        selections: [const HierarchySelection(level1: 'Zeraim')],
      );

      expect(result.length, 1);
      expect(result.first.sefariaRef, 'leaf1');
    });
  });

  group('execute', () {
    final items = [
      _leaf(ref: 'ref_0', sortOrder: 0),
      _leaf(ref: 'ref_1', sortOrder: 1),
    ];

    test('creates completions for all items and stages', () async {
      when(() => completionRepo.bulkMarkComplete(any())).thenAnswer(
        (_) async => [
          // Return fake Completion objects - we just need the length
          _fakeCompletion('ref_0'),
          _fakeCompletion('ref_1'),
        ],
      );
      when(
        () => completionRepo.getCompletionsByCurriculum(any()),
      ).thenAnswer((_) async => []);
      when(
        () => contentRepo.getContentForCurriculum(curriculum),
      ).thenAnswer((_) async => [...items, _leaf(ref: 'ref_2', sortOrder: 2)]);
      when(
        () => bookmarkRepo.setBookmark(
          curriculumId: any(named: 'curriculumId'),
          trackType: any(named: 'trackType'),
          sefariaRef: any(named: 'sefariaRef'),
        ),
      ).thenAnswer((_) async => _fakeBookmarkEntity());

      final result = await service.execute(
        curriculumId: curriculum,
        resolvedItems: items,
        stageIds: [1, 2],
      );

      expect(result.itemCount, 2);
      expect(result.completionCount, 4); // 2 items x 2 stages
      verify(() => completionRepo.bulkMarkComplete(any())).called(2);
    });

    test('sets bookmark to first uncompleted item', () async {
      when(() => completionRepo.bulkMarkComplete(any())).thenAnswer(
        (_) async => [_fakeCompletion('ref_0'), _fakeCompletion('ref_1')],
      );
      when(
        () => completionRepo.getCompletionsByCurriculum(any()),
      ).thenAnswer((_) async => []);
      when(() => contentRepo.getContentForCurriculum(curriculum)).thenAnswer(
        (_) async => [
          ...items,
          _leaf(ref: 'ref_2', sortOrder: 2),
          _leaf(ref: 'ref_3', sortOrder: 3),
        ],
      );
      when(
        () => bookmarkRepo.setBookmark(
          curriculumId: any(named: 'curriculumId'),
          trackType: any(named: 'trackType'),
          sefariaRef: any(named: 'sefariaRef'),
        ),
      ).thenAnswer((_) async => _fakeBookmarkEntity());

      final result = await service.execute(
        curriculumId: curriculum,
        resolvedItems: items,
        stageIds: [1],
      );

      // ref_0 and ref_1 are completed, so bookmark should be ref_2
      expect(result.bookmarkSefariaRef, 'ref_2');
      verify(
        () => bookmarkRepo.setBookmark(
          curriculumId: curriculum,
          trackType: TrackType.personal,
          sefariaRef: 'ref_2',
        ),
      ).called(1);
    });

    test('returns null bookmark when all items completed', () async {
      when(() => completionRepo.bulkMarkComplete(any())).thenAnswer(
        (_) async => [_fakeCompletion('ref_0'), _fakeCompletion('ref_1')],
      );
      when(
        () => completionRepo.getCompletionsByCurriculum(any()),
      ).thenAnswer((_) async => []);
      // Only the items we're completing exist
      when(
        () => contentRepo.getContentForCurriculum(curriculum),
      ).thenAnswer((_) async => items);

      final result = await service.execute(
        curriculumId: curriculum,
        resolvedItems: items,
        stageIds: [1],
      );

      expect(result.bookmarkSefariaRef, isNull);
      verifyNever(
        () => bookmarkRepo.setBookmark(
          curriculumId: any(named: 'curriculumId'),
          trackType: any(named: 'trackType'),
          sefariaRef: any(named: 'sefariaRef'),
        ),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // B6 — execute() writes learn + ALL configured chazara stages
  // ──────────────────────────────────────────────────────────────────────────

  group('B6 — execute writes all track stages, not just learn', () {
    /// 2 items × 3 stages (learn + 2 chazara) = 6 completion_events.
    test(
      'writes learn + every chazara stage when stageRepository has 3 stages',
      () async {
        final stageRepo = MockStageDefinitionRepository();
        // Track configured: stages 1, 2, 3.
        when(
          () => stageRepo.getStagesForCurriculum(curriculum),
        ).thenAnswer((_) async => [_stageDef(1), _stageDef(2), _stageDef(3)]);

        final svc = BulkPriorCompletionService(
          contentRepository: contentRepo,
          completionRepository: completionRepo,
          bookmarkRepository: bookmarkRepo,
          database: memoryDb,
          syncEngine: null,
          stageRepository: stageRepo,
        );

        final items = [
          _leaf(ref: 'ref_0', sortOrder: 0),
          _leaf(ref: 'ref_1', sortOrder: 1),
        ];

        // For each bulkMarkComplete call, return 2 completions (one per item).
        when(() => completionRepo.bulkMarkComplete(any())).thenAnswer(
          (_) async => [_fakeCompletion('ref_0'), _fakeCompletion('ref_1')],
        );
        when(
          () => completionRepo.getCompletionsByCurriculum(any()),
        ).thenAnswer((_) async => []);
        when(() => contentRepo.getContentForCurriculum(curriculum)).thenAnswer(
          (_) async => [...items, _leaf(ref: 'ref_2', sortOrder: 2)],
        );
        when(
          () => bookmarkRepo.setBookmark(
            curriculumId: any(named: 'curriculumId'),
            trackType: any(named: 'trackType'),
            sefariaRef: any(named: 'sefariaRef'),
          ),
        ).thenAnswer((_) async => _fakeBookmarkEntity());

        // Caller passes only stageIds: [1]. B6 must union with [1, 2, 3].
        final result = await svc.execute(
          curriculumId: curriculum,
          resolvedItems: items,
          stageIds: [1],
        );

        // 2 items × 3 stages = 6 total (3 bulkMarkComplete calls × 2 each).
        expect(result.completionCount, 6);
        // bulkMarkComplete must be called once per effective stage (1, 2, 3).
        verify(() => completionRepo.bulkMarkComplete(any())).called(3);
      },
    );

    test('caller-supplied stageIds are unioned with configured stages '
        '— no duplicate stage calls', () async {
      final stageRepo = MockStageDefinitionRepository();
      // Track has 2 stages.
      when(
        () => stageRepo.getStagesForCurriculum(curriculum),
      ).thenAnswer((_) async => [_stageDef(1), _stageDef(2)]);

      final svc = BulkPriorCompletionService(
        contentRepository: contentRepo,
        completionRepository: completionRepo,
        bookmarkRepository: bookmarkRepo,
        database: memoryDb,
        syncEngine: null,
        stageRepository: stageRepo,
      );

      final items = [_leaf(ref: 'ref_0', sortOrder: 0)];

      when(
        () => completionRepo.bulkMarkComplete(any()),
      ).thenAnswer((_) async => [_fakeCompletion('ref_0')]);
      when(
        () => completionRepo.getCompletionsByCurriculum(any()),
      ).thenAnswer((_) async => []);
      when(
        () => contentRepo.getContentForCurriculum(curriculum),
      ).thenAnswer((_) async => [...items, _leaf(ref: 'ref_1', sortOrder: 1)]);
      when(
        () => bookmarkRepo.setBookmark(
          curriculumId: any(named: 'curriculumId'),
          trackType: any(named: 'trackType'),
          sefariaRef: any(named: 'sefariaRef'),
        ),
      ).thenAnswer((_) async => _fakeBookmarkEntity());

      // Caller passes [1, 2] — same as configured. Should call twice, not 4.
      final result = await svc.execute(
        curriculumId: curriculum,
        resolvedItems: items,
        stageIds: [1, 2],
      );

      expect(result.completionCount, 2); // 1 item × 2 stages
      verify(() => completionRepo.bulkMarkComplete(any())).called(2);
    });

    test(
      'falls back to caller stageIds when stageRepository returns empty list',
      () async {
        final stageRepo = MockStageDefinitionRepository();
        when(
          () => stageRepo.getStagesForCurriculum(curriculum),
        ).thenAnswer((_) async => []);

        final svc = BulkPriorCompletionService(
          contentRepository: contentRepo,
          completionRepository: completionRepo,
          bookmarkRepository: bookmarkRepo,
          database: memoryDb,
          syncEngine: null,
          stageRepository: stageRepo,
        );

        final items = [_leaf(ref: 'ref_0', sortOrder: 0)];

        when(
          () => completionRepo.bulkMarkComplete(any()),
        ).thenAnswer((_) async => [_fakeCompletion('ref_0')]);
        when(
          () => completionRepo.getCompletionsByCurriculum(any()),
        ).thenAnswer((_) async => []);
        when(() => contentRepo.getContentForCurriculum(curriculum)).thenAnswer(
          (_) async => [...items, _leaf(ref: 'ref_1', sortOrder: 1)],
        );
        when(
          () => bookmarkRepo.setBookmark(
            curriculumId: any(named: 'curriculumId'),
            trackType: any(named: 'trackType'),
            sefariaRef: any(named: 'sefariaRef'),
          ),
        ).thenAnswer((_) async => _fakeBookmarkEntity());

        final result = await svc.execute(
          curriculumId: curriculum,
          resolvedItems: items,
          stageIds: [1],
        );

        // Falls back: only stage 1 → 1 call.
        expect(result.completionCount, 1);
        verify(() => completionRepo.bulkMarkComplete(any())).called(1);
      },
    );

    test(
      'falls back to caller stageIds when no stageRepository is injected',
      () async {
        // service was created without stageRepository in setUp.
        final items = [_leaf(ref: 'ref_0', sortOrder: 0)];

        when(
          () => completionRepo.bulkMarkComplete(any()),
        ).thenAnswer((_) async => [_fakeCompletion('ref_0')]);
        when(
          () => completionRepo.getCompletionsByCurriculum(any()),
        ).thenAnswer((_) async => []);
        when(() => contentRepo.getContentForCurriculum(curriculum)).thenAnswer(
          (_) async => [...items, _leaf(ref: 'ref_1', sortOrder: 1)],
        );
        when(
          () => bookmarkRepo.setBookmark(
            curriculumId: any(named: 'curriculumId'),
            trackType: any(named: 'trackType'),
            sefariaRef: any(named: 'sefariaRef'),
          ),
        ).thenAnswer((_) async => _fakeBookmarkEntity());

        final result = await service.execute(
          curriculumId: curriculum,
          resolvedItems: items,
          stageIds: [1, 2],
        );

        expect(result.completionCount, 2);
        verify(() => completionRepo.bulkMarkComplete(any())).called(2);
      },
    );
  });
}

Completion _fakeCompletion(String ref) {
  return Completion(
    id: 0,
    profileId: 0,
    curriculumId: 'mishnayos',
    sefariaRef: ref,
    stageId: 1,
    trackType: 'personal',
    trackId: 1,
    completedAt: DateTime.now(),
    points: 10,
    derivedFromEvents: false,
  );
}

BookmarkEntity _fakeBookmarkEntity() {
  return BookmarkEntity(
    curriculumId: CurriculumId.mishnayos,
    trackType: TrackType.personal,
    sefariaRef: 'ref',
    updatedAt: DateTime.now(),
  );
}

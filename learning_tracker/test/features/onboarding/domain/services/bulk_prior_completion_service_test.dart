import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart'
    show Completion;
import 'package:learning_tracker/core/database/daos/outbox_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart'
    as stage_model;
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

/// An [OutboxDao] whose [insertOutboxRow] always throws, simulating a
/// mid-sequence crash so tests can assert
/// [BulkPriorCompletionService.expungePriorCompletions] rolls back
/// atomically (AUD-onboarding-06, DB-2) instead of leaving a
/// half-tombstoned state (completion_events tombstoned but
/// prior_completion_imports already deleted, with no outbox row to
/// propagate the tombstone to Firestore).
class _ThrowingOutboxDao extends OutboxDao {
  _ThrowingOutboxDao(super.db);

  @override
  Future<int> insertOutboxRow(OutboxCompanion companion) {
    throw Exception(
      'AUD-onboarding-06 fixture: simulated outbox insert failure',
    );
  }
}

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
          sefariaRef: 'ref_2',
        ),
      ).called(1);
    });

    // ── AUD-onboarding-08 (SM-7) — profileId branch uses the injected seam ──

    test('execute(profileId: X) routes the bookmark write through the '
        'injected bookmarkRepositoryFactory(X), not the session bookmarkRepo '
        'and not a bare BookmarkRepositoryImpl construction', () async {
      const targetProfileId = 42;
      final factoryRepo = MockBookmarkRepository();
      when(
        () => factoryRepo.setBookmark(
          curriculumId: any(named: 'curriculumId'),
          sefariaRef: any(named: 'sefariaRef'),
        ),
      ).thenAnswer((_) async => _fakeBookmarkEntity());

      final factoryCalledWith = <int>[];
      BookmarkRepository factory(int pid) {
        factoryCalledWith.add(pid);
        return factoryRepo;
      }

      final profiledService = BulkPriorCompletionService(
        contentRepository: contentRepo,
        completionRepository: completionRepo,
        // The session-scoped repo must NOT receive this call — asserted
        // below via verifyNever.
        bookmarkRepository: bookmarkRepo,
        bookmarkRepositoryFactory: factory,
        database: memoryDb,
        syncEngine: null,
      );

      when(() => completionRepo.bulkMarkComplete(any())).thenAnswer(
        (_) async => [_fakeCompletion('ref_0'), _fakeCompletion('ref_1')],
      );
      when(
        () => completionRepo.getCompletionsByCurriculum(
          any(),
          profileId: any(named: 'profileId'),
        ),
      ).thenAnswer((_) async => []);
      when(() => contentRepo.getContentForCurriculum(curriculum)).thenAnswer(
        (_) async => [
          ...items,
          _leaf(ref: 'ref_2', sortOrder: 2),
          _leaf(ref: 'ref_3', sortOrder: 3),
        ],
      );

      final result = await profiledService.execute(
        curriculumId: curriculum,
        resolvedItems: items,
        stageIds: [1],
        profileId: targetProfileId,
      );

      expect(result.bookmarkSefariaRef, 'ref_2');
      expect(
        factoryCalledWith,
        [targetProfileId],
        reason:
            'the factory must be invoked with exactly the caller-'
            'supplied profileId, not the session profile',
      );
      // The "read" proving the write landed under profile X: the
      // factory-scoped repository (the one execute() builds specifically
      // for profile X) recorded the setBookmark call.
      verify(
        () => factoryRepo.setBookmark(
          curriculumId: curriculum,
          sefariaRef: 'ref_2',
        ),
      ).called(1);
      verifyNever(
        () => bookmarkRepo.setBookmark(
          curriculumId: any(named: 'curriculumId'),
          sefariaRef: any(named: 'sefariaRef'),
        ),
      );
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

    test('Finding 10: only configured stages are used (caller stageIds ignored) '
        '— no extra calls when caller mirrors configured set', () async {
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
          sefariaRef: any(named: 'sefariaRef'),
        ),
      ).thenAnswer((_) async => _fakeBookmarkEntity());

      // Caller passes [1, 2] — same as configured. Finding 10: only configured
      // set [1, 2] is used. Should call exactly twice.
      final result = await svc.execute(
        curriculumId: curriculum,
        resolvedItems: items,
        stageIds: [1, 2],
      );

      expect(result.completionCount, 2); // 1 item × 2 configured stages
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

    test(
      'Finding 10: caller-supplied extra stageId is NOT added to configured set '
      '— superseded-stage bypass is blocked',
      () async {
        final stageRepo = MockStageDefinitionRepository();
        // Track has only 2 active stages; stage 99 is a stale/superseded id
        // that the caller should not be able to re-admit.
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
        when(() => contentRepo.getContentForCurriculum(curriculum)).thenAnswer(
          (_) async => [...items, _leaf(ref: 'ref_1', sortOrder: 1)],
        );
        when(
          () => bookmarkRepo.setBookmark(
            curriculumId: any(named: 'curriculumId'),
            sefariaRef: any(named: 'sefariaRef'),
          ),
        ).thenAnswer((_) async => _fakeBookmarkEntity());

        // Caller attempts to pass stage 99 (a stale/superseded id). Finding 10
        // must ensure only [1, 2] are used — stage 99 must be discarded.
        final result = await svc.execute(
          curriculumId: curriculum,
          resolvedItems: items,
          stageIds: [1, 99], // 99 is NOT in the configured set
        );

        // Only 2 configured stages → 2 calls, not 3.
        expect(
          result.completionCount,
          2,
          reason:
              'Finding 10: stale caller stageId 99 must be discarded; '
              'only configured stages [1, 2] produce completions',
        );
        verify(() => completionRepo.bulkMarkComplete(any())).called(2);
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // AUD-onboarding-06 (DB-2) — expungePriorCompletions atomicity
  // ──────────────────────────────────────────────────────────────────────────

  group('expungePriorCompletions — DB-2 transaction atomicity', () {
    // completion_events.profile_id / prior_completion_imports.profile_id
    // are FK-constrained to learner_profiles(id) — seed profile 1 (the id
    // every test below hardcodes) before any direct table insert.
    setUp(() async {
      final now = DateTime.utc(2026, 1, 1);
      final accountId = await memoryDb
          .into(memoryDb.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'expunge@example.com',
              tier: 'localBorn',
              displayName: 'Expunge Test',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await memoryDb
          .into(memoryDb.learnerProfiles)
          .insert(
            LearnerProfilesCompanion.insert(
              accountId: accountId,
              displayName: 'Expunge Test',
              mode: 'adult',
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    /// Seeds a prior-mark row into BOTH completion_events AND
    /// prior_completion_imports, mirroring the production write path
    /// (CompletionWriter.commitBatch with priorMarkOnly = true) that
    /// expungePriorCompletions expects to find.
    Future<void> insertPriorMark({
      required int stageId,
      required String sefariaRef,
    }) async {
      await memoryDb
          .into(memoryDb.completionEvents)
          .insert(
            CompletionEventsCompanion.insert(
              profileId: 1,
              curriculumId: curriculum.storageKey,
              sefariaRef: sefariaRef,
              stageId: stageId,
              trackType: 'personal',
              eventTimestamp: kBulkPriorSentinelDate,
            ),
          );
      await memoryDb
          .into(memoryDb.priorCompletionImports)
          .insert(
            PriorCompletionImportsCompanion.insert(
              profileId: 1,
              curriculumId: curriculum.storageKey,
              sefariaRef: sefariaRef,
              stageId: stageId,
              trackType: 'personal',
              source: 'bulkInTrack',
            ),
          );
    }

    test('rolls back the tombstone AND the import-row delete when the outbox '
        'insert throws — prior_completion_imports row still exists instead '
        'of a half-tombstoned state', () async {
      await insertPriorMark(stageId: 1, sefariaRef: 'ref_expunge');

      final throwingOutboxDao = _ThrowingOutboxDao(memoryDb);
      final throwingService = BulkPriorCompletionService(
        contentRepository: contentRepo,
        completionRepository: completionRepo,
        bookmarkRepository: bookmarkRepo,
        database: memoryDb,
        syncEngine: null,
        outboxDao: throwingOutboxDao,
      );

      await expectLater(
        () => throwingService.expungePriorCompletions(
          profileId: 1,
          sefariaRef: 'ref_expunge',
          curriculumId: curriculum,
        ),
        throwsException,
      );

      // The import row must still exist — the delete (step 3) must have
      // rolled back along with the tombstone UPDATE (step 2) and the
      // failed outbox insert (step 4), all inside one transaction().
      final importRows = await memoryDb
          .select(memoryDb.priorCompletionImports)
          .get();
      expect(
        importRows.where((r) => r.sefariaRef == 'ref_expunge'),
        hasLength(1),
        reason:
            'DB-2: a crash in the outbox-propagation step must roll back '
            'the whole tombstone sequence, not leave '
            'prior_completion_imports deleted with completion_events '
            'un-tombstoned/tombstoned inconsistently',
      );

      // The completion_events row must NOT be tombstoned either — same
      // atomic unit.
      final events = await (memoryDb.select(
        memoryDb.completionEvents,
      )..where((t) => t.sefariaRef.equals('ref_expunge'))).get();
      expect(
        events.single.purgedAt,
        isNull,
        reason:
            'DB-2: the tombstone UPDATE must roll back too — a device '
            'reading the row after the crash must still see it active, '
            'not half-tombstoned with the import record already gone',
      );
    });

    test('succeeds normally (no outbox DAO throwing) — tombstone and import '
        'delete both commit together', () async {
      await insertPriorMark(stageId: 1, sefariaRef: 'ref_normal');

      final service = BulkPriorCompletionService(
        contentRepository: contentRepo,
        completionRepository: completionRepo,
        bookmarkRepository: bookmarkRepo,
        database: memoryDb,
        syncEngine: null,
      );

      await service.expungePriorCompletions(
        profileId: 1,
        sefariaRef: 'ref_normal',
        curriculumId: curriculum,
      );

      final importRows = await memoryDb
          .select(memoryDb.priorCompletionImports)
          .get();
      expect(importRows.where((r) => r.sefariaRef == 'ref_normal'), isEmpty);

      final events = await (memoryDb.select(
        memoryDb.completionEvents,
      )..where((t) => t.sefariaRef.equals('ref_normal'))).get();
      expect(events.single.purgedAt, isNotNull);
    });
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
    sefariaRef: 'ref',
    updatedAt: DateTime.now(),
  );
}

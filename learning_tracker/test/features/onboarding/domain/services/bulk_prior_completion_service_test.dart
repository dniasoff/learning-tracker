import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart'
    as stage_model;
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockContentRepository extends Mock implements ContentRepository {}

class MockCompletionRepository extends Mock implements CompletionRepository {}

class MockBookmarkRepository extends Mock implements BookmarkRepository {}

class MockStageDefinitionRepository extends Mock
    implements StageDefinitionRepository {}

/// List-backed, stateful fake — a mocktail stub cannot express the
/// post-purge world (`purgeCompletion` must actually flip `purgedAt` so a
/// subsequent `getCompletionsByCurriculum` read reflects it, matching
/// `FirestoreCompletionRepository`'s D-L tombstone-filters-at-read-time
/// contract). Extends [Mock] purely so unrelated [CompletionRepository]
/// methods this suite never calls fall back to mocktail's noSuchMethod
/// (loud failure) instead of requiring a full interface implementation.
class _FakeCompletionRepository extends Mock implements CompletionRepository {
  final List<CompletionEntity> rows = [];
  final List<({CurriculumId curriculumId, String sefariaRef, int stageId})>
  purgeCalls = [];

  @override
  Future<List<CompletionEntity>> getCompletionsByCurriculum(
    String curriculumId, {
    int? profileId,
  }) async {
    return rows
        .where(
          (r) =>
              r.curriculumId.storageKey == curriculumId && r.purgedAt == null,
        )
        .toList();
  }

  @override
  Future<List<CompletionEntity>> getCompletionsForContentItem(
    String sefariaRef,
  ) async {
    // Mirrors FirestoreCompletionRepositoryAdapter.getCompletionsForContentItem:
    // NOT tombstone-filtered here — expungePriorCompletions applies its own
    // `purgedAt == null` filter on top, same as production.
    return rows.where((r) => r.sefariaRef == sefariaRef).toList();
  }

  @override
  Future<void> purgeCompletion({
    required CurriculumId curriculumId,
    required String sefariaRef,
    required int stageId,
    required DateTime purgedAt,
  }) async {
    purgeCalls.add((
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
    ));
    final idx = rows.indexWhere(
      (r) =>
          r.curriculumId == curriculumId &&
          r.sefariaRef == sefariaRef &&
          r.stageId == stageId &&
          r.purgedAt == null,
    );
    if (idx == -1) {
      throw StateError(
        'fixture error: no active completion row to purge for '
        '$curriculumId/$sefariaRef/stage $stageId',
      );
    }
    final old = rows[idx];
    rows[idx] = CompletionEntity(
      curriculumId: old.curriculumId,
      sefariaRef: old.sefariaRef,
      stageId: old.stageId,
      trackType: old.trackType,
      source: old.source,
      completedAt: old.completedAt,
      points: old.points,
      purgedAt: purgedAt,
    );
  }
}

/// Same rationale as [_FakeCompletionRepository] — [isUnitLimudComplete]
/// (via a REAL [CompletionDetectionService]) reads back through
/// [filterByLevel]/[getContentByRef], so the fixture must actually hold and
/// filter content items rather than stub one canned answer.
class _FakeContentRepository extends Mock implements ContentRepository {
  final List<ContentItem> items = [];

  /// Counts [filterByLevel] calls — used by the Fix 4 batched-dedupe test to
  /// prove the coverage check runs once per DISTINCT affected unit, not once
  /// per ref ([isUnitLimudComplete] calls this exactly once per invocation).
  int filterByLevelCallCount = 0;

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async {
    filterByLevelCallCount++;
    return items.where((item) {
      if (level1 != null && item.level1 != level1) return false;
      if (level2 != null && item.level2 != level2) return false;
      if (level3 != null && item.level3 != level3) return false;
      if (level4 != null && item.level4 != level4) return false;
      return true;
    }).toList();
  }

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async {
    for (final item in items) {
      if (item.sefariaRef == sefariaRef) return item;
    }
    return null;
  }
}

/// D-M retraction fixture: real [purgeEntry]/[getLedgerByCurriculum]/
/// [getLedgerByCurriculumIncludingTombstoned] semantics (tombstone-on-purge,
/// throw when the ulid is absent — mirroring
/// `LearningLedgerRepository.purgeEntry`'s own documented contract; and,
/// critically, [getLedgerByCurriculum] excludes tombstoned entries while
/// [getLedgerByCurriculumIncludingTombstoned] does not — mirroring
/// `FirestoreLearningLedgerRepository._decodeAll`'s `includeTombstoned`
/// choke point exactly) so the expunge tests exercise the real
/// filter/sort/retract logic, not a stub that happens to diverge from
/// production on exactly the field the epoch rule depends on.
class _FakeLearningLedgerRepository extends Mock
    implements LearningLedgerRepository {
  final List<LearningLedgerEntry> entries = [];
  final List<String> purgedUlids = [];

  /// Counts [getLedgerByCurriculumIncludingTombstoned] calls — used by the
  /// Fix 4 batched-dedupe test to prove the whole ledger is fetched ONCE per
  /// [BulkPriorCompletionService.expungePriorCompletions] call, not once per
  /// affected unit. This is the method production's epoch-rule retraction
  /// step actually reads from (see that method's doc comment for why it
  /// cannot use the tombstone-filtering [getLedgerByCurriculum] instead).
  int getLedgerByCurriculumIncludingTombstonedCallCount = 0;

  @override
  Future<List<LearningLedgerEntry>> getLedgerByCurriculum(
    CurriculumId curriculumId,
  ) async {
    return entries
        .where((e) => e.curriculumId == curriculumId && e.purgedAt == null)
        .toList();
  }

  @override
  Future<List<LearningLedgerEntry>> getLedgerByCurriculumIncludingTombstoned(
    CurriculumId curriculumId,
  ) async {
    getLedgerByCurriculumIncludingTombstonedCallCount++;
    return entries.where((e) => e.curriculumId == curriculumId).toList();
  }

  @override
  Future<void> purgeEntry({
    required String ulid,
    required DateTime purgedAt,
  }) async {
    final idx = entries.indexWhere((e) => e.ulid == ulid);
    if (idx == -1) {
      throw StateError('purgeEntry: no learning_ledger entry with ulid $ulid');
    }
    purgedUlids.add(ulid);
    final old = entries[idx];
    entries[idx] = LearningLedgerEntry(
      ulid: old.ulid,
      curriculumId: old.curriculumId,
      entryScope: old.entryScope,
      unitIdentifier: old.unitIdentifier,
      unitDisplayNameHe: old.unitDisplayNameHe,
      unitDisplayNameEn: old.unitDisplayNameEn,
      trackType: old.trackType,
      completedAt: old.completedAt,
      completionNumber: old.completionNumber,
      markedBy: old.markedBy,
      isManual: old.isManual,
      source: old.source,
      purgedAt: purgedAt,
    );
  }
}

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

CompletionEntity _completion({
  required String ref,
  required int stageId,
  CompletionSource source = CompletionSource.bulkInTrack,
  CurriculumId curriculumId = CurriculumId.mishnayos,
  DateTime? purgedAt,
}) {
  return CompletionEntity(
    curriculumId: curriculumId,
    sefariaRef: ref,
    stageId: stageId,
    trackType: 'personal',
    source: source,
    completedAt: DateTime.utc(2000, 1, 1),
    purgedAt: purgedAt,
  );
}

LearningLedgerEntry _ledgerEntry({
  required String ulid,
  required String entryScope,
  required String unitIdentifier,
  required int completionNumber,
  CompletionSource source = CompletionSource.bulkInTrack,
  CurriculumId curriculumId = CurriculumId.mishnayos,
  DateTime? purgedAt,
}) {
  return LearningLedgerEntry(
    ulid: ulid,
    curriculumId: curriculumId,
    entryScope: entryScope,
    unitIdentifier: unitIdentifier,
    unitDisplayNameHe: unitIdentifier,
    unitDisplayNameEn: unitIdentifier,
    trackType: 'personal',
    completedAt: DateTime.utc(2000, 1, 1),
    completionNumber: completionNumber,
    markedBy: 'profile_ulid',
    isManual: false,
    source: source,
    purgedAt: purgedAt,
  );
}

void main() {
  late MockContentRepository contentRepo;
  late MockCompletionRepository completionRepo;
  late MockBookmarkRepository bookmarkRepo;
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
    contentRepo = MockContentRepository();
    completionRepo = MockCompletionRepository();
    bookmarkRepo = MockBookmarkRepository();
    service = BulkPriorCompletionService(
      contentRepository: contentRepo,
      completionRepository: completionRepo,
      bookmarkRepository: bookmarkRepo,
    );
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
          _completion(ref: 'ref_0', stageId: 1),
          _completion(ref: 'ref_1', stageId: 1),
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
        (_) async => [
          _completion(ref: 'ref_0', stageId: 1),
          _completion(ref: 'ref_1', stageId: 1),
        ],
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

    test('returns null bookmark when all items completed', () async {
      when(() => completionRepo.bulkMarkComplete(any())).thenAnswer(
        (_) async => [
          _completion(ref: 'ref_0', stageId: 1),
          _completion(ref: 'ref_1', stageId: 1),
        ],
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
          stageRepository: stageRepo,
        );

        final items = [
          _leaf(ref: 'ref_0', sortOrder: 0),
          _leaf(ref: 'ref_1', sortOrder: 1),
        ];

        // For each bulkMarkComplete call, return 2 completions (one per item).
        when(() => completionRepo.bulkMarkComplete(any())).thenAnswer(
          (_) async => [
            _completion(ref: 'ref_0', stageId: 1),
            _completion(ref: 'ref_1', stageId: 1),
          ],
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
        stageRepository: stageRepo,
      );

      final items = [_leaf(ref: 'ref_0', sortOrder: 0)];

      when(
        () => completionRepo.bulkMarkComplete(any()),
      ).thenAnswer((_) async => [_completion(ref: 'ref_0', stageId: 1)]);
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
          stageRepository: stageRepo,
        );

        final items = [_leaf(ref: 'ref_0', sortOrder: 0)];

        when(
          () => completionRepo.bulkMarkComplete(any()),
        ).thenAnswer((_) async => [_completion(ref: 'ref_0', stageId: 1)]);
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
        ).thenAnswer((_) async => [_completion(ref: 'ref_0', stageId: 1)]);
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
          stageRepository: stageRepo,
        );

        final items = [_leaf(ref: 'ref_0', sortOrder: 0)];

        when(
          () => completionRepo.bulkMarkComplete(any()),
        ).thenAnswer((_) async => [_completion(ref: 'ref_0', stageId: 1)]);
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
  // D-M — expungePriorCompletions: tombstone + siyum retraction
  // ──────────────────────────────────────────────────────────────────────────
  //
  // These tests wire a REAL CompletionDetectionService (not a mock) on top of
  // stateful list-backed fakes for ContentRepository/CompletionRepository/
  // LearningLedgerRepository, so `isUnitLimudComplete`'s post-purge coverage
  // re-check is genuinely exercised end-to-end, not stubbed to a canned
  // answer. Owner ruling (2026-08-11): retract the HIGHEST-completionNumber
  // non-purged entry for the affected unit, and ONLY when the remaining
  // non-purged completions no longer cover it — regardless of that entry's
  // `source` (retraction keys on coverage, not provenance; see
  // `expungePriorCompletions`'s doc comment). [expungePriorCompletions]
  // takes a BATCH of refs (Fix 4): every match across every ref is
  // tombstoned first, then one coverage-check-and-retract pass runs per
  // DISTINCT affected unit — not per ref.
  group('expungePriorCompletions — D-M tombstone + siyum retraction', () {
    late _FakeContentRepository fakeContentRepo;
    late _FakeCompletionRepository fakeCompletionRepo;
    late _FakeLearningLedgerRepository fakeLedgerRepo;
    late MockStageDefinitionRepository stageRepo;
    late CompletionDetectionService detectionService;

    setUp(() {
      fakeContentRepo = _FakeContentRepository();
      fakeCompletionRepo = _FakeCompletionRepository();
      fakeLedgerRepo = _FakeLearningLedgerRepository();
      stageRepo = MockStageDefinitionRepository();
      when(
        () => stageRepo.getStagesForCurriculum(curriculum),
      ).thenAnswer((_) async => [_stageDef(1), _stageDef(2)]);
      detectionService = CompletionDetectionService(
        completionRepository: fakeCompletionRepo,
        contentRepository: fakeContentRepo,
        ledgerRepository: fakeLedgerRepo,
        stageRepository: stageRepo,
      );
    });

    BulkPriorCompletionService buildService({
      CompletionDetectionService? detection,
      LearningLedgerRepository? ledger,
    }) {
      return BulkPriorCompletionService(
        contentRepository: fakeContentRepo,
        completionRepository: fakeCompletionRepo,
        bookmarkRepository: bookmarkRepo,
        completionDetectionService: detection ?? detectionService,
        ledgerRepository: ledger ?? fakeLedgerRepo,
      );
    }

    test('(a) toExpunge empty → no purge calls, returns silently', () async {
      fakeContentRepo.items.addAll([
        _leaf(ref: 'z_b_1', sortOrder: 0, level1: 'Zeraim', level2: 'Berachos'),
      ]);
      // No completion rows at all for this ref.
      final svc = buildService();

      await svc.expungePriorCompletions(
        sefariaRefs: ['z_b_1'],
        curriculumId: curriculum,
      );

      expect(fakeCompletionRepo.purgeCalls, isEmpty);
      expect(fakeLedgerRepo.purgedUlids, isEmpty);
    });

    test(
      '(b) unit still covered by remaining completions → siyum NOT retracted',
      () async {
        // Single-leaf unit. The leaf has a `live` stage-1 (limud) completion
        // — unaffected by expunge — plus a `bulkInTrack` stage-2 (chazara)
        // completion, which IS what gets un-ticked/purged. Coverage (which
        // only gates on stage 1 / limud) is unaffected by the purge.
        fakeContentRepo.items.add(
          _leaf(
            ref: 'z_b_1',
            sortOrder: 0,
            level1: 'Zeraim',
            level2: 'Berachos',
          ),
        );
        fakeCompletionRepo.rows.addAll([
          _completion(ref: 'z_b_1', stageId: 1, source: CompletionSource.live),
          _completion(
            ref: 'z_b_1',
            stageId: 2,
            source: CompletionSource.bulkInTrack,
          ),
        ]);
        fakeLedgerRepo.entries.add(
          _ledgerEntry(
            ulid: 'siyum_masechta_berachos',
            entryScope: 'masechta',
            unitIdentifier: 'Berachos',
            completionNumber: 1,
          ),
        );
        final svc = buildService();

        await svc.expungePriorCompletions(
          sefariaRefs: ['z_b_1'],
          curriculumId: curriculum,
        );

        // The bulkInTrack stage-2 row was purged...
        expect(fakeCompletionRepo.purgeCalls, [
          (curriculumId: curriculum, sefariaRef: 'z_b_1', stageId: 2),
        ]);
        // ...but the unit is still covered (stage-1 `live` completion
        // survives) so the siyum must NOT be retracted.
        expect(fakeLedgerRepo.purgedUlids, isEmpty);
      },
    );

    test('(c) unit no longer covered, one matching bulkInTrack ledger entry → '
        'both purgeCompletion and purgeEntry are called', () async {
      fakeContentRepo.items.add(
        _leaf(ref: 'z_b_1', sortOrder: 0, level1: 'Zeraim', level2: 'Berachos'),
      );
      fakeCompletionRepo.rows.add(
        _completion(
          ref: 'z_b_1',
          stageId: 1,
          source: CompletionSource.bulkInTrack,
        ),
      );
      fakeLedgerRepo.entries.add(
        _ledgerEntry(
          ulid: 'siyum_masechta_berachos',
          entryScope: 'masechta',
          unitIdentifier: 'Berachos',
          completionNumber: 1,
        ),
      );
      // Also seed the level-1 aggregate siyum for 'Zeraim' — the single
      // leaf is also the whole seder's only content, so both scopes are
      // affected; this test focuses on asserting (c) at the masechta
      // scope, (h) below asserts BOTH scopes explicitly.
      fakeLedgerRepo.entries.add(
        _ledgerEntry(
          ulid: 'siyum_seder_zeraim',
          entryScope: 'seder',
          unitIdentifier: 'Zeraim',
          completionNumber: 1,
        ),
      );
      final svc = buildService();

      await svc.expungePriorCompletions(
        sefariaRefs: ['z_b_1'],
        curriculumId: curriculum,
      );

      expect(fakeCompletionRepo.purgeCalls, [
        (curriculumId: curriculum, sefariaRef: 'z_b_1', stageId: 1),
      ]);
      expect(
        fakeLedgerRepo.purgedUlids,
        containsAll(['siyum_masechta_berachos', 'siyum_seder_zeraim']),
      );
    });

    test('(d) unit no longer covered and the highest-completionNumber ledger '
        'entry is source==live → it IS retracted anyway (owner ruling '
        '2026-08-11: retraction keys on coverage, not provenance — supersedes '
        'the earlier mixed-provenance fail-safe)', () async {
      fakeContentRepo.items.add(
        _leaf(ref: 'z_b_1', sortOrder: 0, level1: 'Zeraim', level2: 'Berachos'),
      );
      fakeCompletionRepo.rows.add(
        _completion(
          ref: 'z_b_1',
          stageId: 1,
          source: CompletionSource.bulkInTrack,
        ),
      );
      fakeLedgerRepo.entries.addAll([
        _ledgerEntry(
          ulid: 'siyum_masechta_berachos',
          entryScope: 'masechta',
          unitIdentifier: 'Berachos',
          completionNumber: 1,
          source: CompletionSource.live,
        ),
        _ledgerEntry(
          ulid: 'siyum_seder_zeraim',
          entryScope: 'seder',
          unitIdentifier: 'Zeraim',
          completionNumber: 1,
          source: CompletionSource.live,
        ),
      ]);
      final svc = buildService();

      await svc.expungePriorCompletions(
        sefariaRefs: ['z_b_1'],
        curriculumId: curriculum,
      );

      expect(fakeCompletionRepo.purgeCalls, isNotEmpty);
      // The unit is no longer covered, and these `live` entries are the
      // HIGHEST (only) completionNumber for their units — the owner
      // ruling retracts them regardless of `source`.
      expect(
        fakeLedgerRepo.purgedUlids,
        containsAll(['siyum_masechta_berachos', 'siyum_seder_zeraim']),
      );
    });

    test(
      '(e) two candidate entries for the same unit with different '
      'completionNumbers → the HIGHER one is purged, the lower untouched',
      () async {
        fakeContentRepo.items.add(
          _leaf(
            ref: 'z_b_1',
            sortOrder: 0,
            level1: 'Zeraim',
            level2: 'Berachos',
          ),
        );
        fakeCompletionRepo.rows.add(
          _completion(
            ref: 'z_b_1',
            stageId: 1,
            source: CompletionSource.bulkInTrack,
          ),
        );
        fakeLedgerRepo.entries.addAll([
          _ledgerEntry(
            ulid: 'low',
            entryScope: 'masechta',
            unitIdentifier: 'Berachos',
            completionNumber: 1,
          ),
          _ledgerEntry(
            ulid: 'high',
            entryScope: 'masechta',
            unitIdentifier: 'Berachos',
            completionNumber: 2,
          ),
        ]);
        final svc = buildService();

        await svc.expungePriorCompletions(
          sefariaRefs: ['z_b_1'],
          curriculumId: curriculum,
        );

        expect(fakeLedgerRepo.purgedUlids, ['high']);
      },
    );

    test(
      '(f) collaborators omitted (null) and toExpunge non-empty → throws '
      'StateError BEFORE any completion is tombstoned (fail-before-mutate)',
      () async {
        fakeContentRepo.items.add(
          _leaf(
            ref: 'z_b_1',
            sortOrder: 0,
            level1: 'Zeraim',
            level2: 'Berachos',
          ),
        );
        fakeCompletionRepo.rows.add(
          _completion(
            ref: 'z_b_1',
            stageId: 1,
            source: CompletionSource.bulkInTrack,
          ),
        );
        final svc = BulkPriorCompletionService(
          contentRepository: fakeContentRepo,
          completionRepository: fakeCompletionRepo,
          bookmarkRepository: bookmarkRepo,
          // completionDetectionService / ledgerRepository intentionally omitted.
        );

        await expectLater(
          () => svc.expungePriorCompletions(
            sefariaRefs: ['z_b_1'],
            curriculumId: curriculum,
          ),
          throwsA(isA<StateError>()),
        );

        // Fail-before-mutate: the missing-collaborator check now runs BEFORE
        // the tombstone loop, so a misconfigured caller leaves the
        // completion(s) untouched instead of tombstoning them with no way to
        // retract the siyum they were backing.
        expect(fakeCompletionRepo.purgeCalls, isEmpty);
      },
    );

    test('(f2) collaborators omitted (null) and toExpunge EMPTY (nothing '
        'matched) → still throws StateError — the D-E collaborator check is '
        'unconditional, not gated on there being something to tombstone '
        '(part of Fix 3a\'s retry-safety: the coverage-check step always '
        'runs)', () async {
      fakeContentRepo.items.add(
        _leaf(ref: 'z_b_1', sortOrder: 0, level1: 'Zeraim', level2: 'Berachos'),
      );
      // No completion rows at all — toExpunge will be empty.
      final svc = BulkPriorCompletionService(
        contentRepository: fakeContentRepo,
        completionRepository: fakeCompletionRepo,
        bookmarkRepository: bookmarkRepo,
        // completionDetectionService / ledgerRepository intentionally omitted.
      );

      await expectLater(
        () => svc.expungePriorCompletions(
          sefariaRefs: ['z_b_1'],
          curriculumId: curriculum,
        ),
        throwsA(isA<StateError>()),
      );

      expect(fakeCompletionRepo.purgeCalls, isEmpty);
    });

    test('(g) getContentByRef returns null → throws StateError', () async {
      // No content item registered for this ref, but a bulkInTrack
      // completion row exists — an inconsistent state.
      fakeCompletionRepo.rows.add(
        _completion(
          ref: 'ghost_ref',
          stageId: 1,
          source: CompletionSource.bulkInTrack,
        ),
      );
      final svc = buildService();

      await expectLater(
        () => svc.expungePriorCompletions(
          sefariaRefs: ['ghost_ref'],
          curriculumId: curriculum,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      '(g2) coverage indeterminate (no stage definitions for the curriculum) '
      '→ throws StateError, never silently treated as "not covered"',
      () async {
        // Content item resolves fine and a bulkInTrack completion exists, so
        // purging proceeds — but the stage-definition lookup comes back
        // empty, so isUnitLimudComplete cannot determine coverage (tri-state
        // `null`). That must fail loudly, not be read as "uncovered" (which
        // would silently retract a real siyum on missing stage data).
        fakeContentRepo.items.add(
          _leaf(
            ref: 'z_b_1',
            sortOrder: 0,
            level1: 'Zeraim',
            level2: 'Berachos',
          ),
        );
        fakeCompletionRepo.rows.add(
          _completion(
            ref: 'z_b_1',
            stageId: 1,
            source: CompletionSource.bulkInTrack,
          ),
        );
        // Override the group setUp's stage stub for this test only.
        when(
          () => stageRepo.getStagesForCurriculum(curriculum),
        ).thenAnswer((_) async => []);
        final svc = buildService();

        await expectLater(
          () => svc.expungePriorCompletions(
            sefariaRefs: ['z_b_1'],
            curriculumId: curriculum,
          ),
          throwsA(isA<StateError>()),
        );

        // Purge still happens first (D-L); the siyum ledger is untouched
        // because retraction never got a definite answer.
        expect(fakeCompletionRepo.purgeCalls, isNotEmpty);
        expect(fakeLedgerRepo.purgedUlids, isEmpty);
      },
    );

    test(
      '(h) last leaf of a masechta that is also the last leaf of its seder → '
      'both the level2 (masechta) and level1 (seder) siyumim are '
      'independently checked and retracted',
      () async {
        // The ONLY leaf in the whole 'Zeraim' seder, and the only leaf in
        // its 'Berachos' masechta — untying it un-covers both scopes.
        fakeContentRepo.items.add(
          _leaf(
            ref: 'z_b_1',
            sortOrder: 0,
            level1: 'Zeraim',
            level2: 'Berachos',
          ),
        );
        fakeCompletionRepo.rows.add(
          _completion(
            ref: 'z_b_1',
            stageId: 1,
            source: CompletionSource.bulkInTrack,
          ),
        );
        fakeLedgerRepo.entries.addAll([
          _ledgerEntry(
            ulid: 'siyum_masechta_berachos',
            entryScope: 'masechta',
            unitIdentifier: 'Berachos',
            completionNumber: 1,
          ),
          _ledgerEntry(
            ulid: 'siyum_seder_zeraim',
            entryScope: 'seder',
            unitIdentifier: 'Zeraim',
            completionNumber: 1,
          ),
        ]);
        final svc = buildService();

        await svc.expungePriorCompletions(
          sefariaRefs: ['z_b_1'],
          curriculumId: curriculum,
        );

        expect(
          fakeLedgerRepo.purgedUlids,
          containsAll(['siyum_masechta_berachos', 'siyum_seder_zeraim']),
        );
        expect(fakeLedgerRepo.purgedUlids, hasLength(2));
      },
    );

    test('(i) batched: two different refs under the SAME masechta+seder in one '
        'call → the coverage-check-and-retract step runs ONCE per distinct '
        'unit, not once per ref (Fix 4)', () async {
      fakeContentRepo.items.addAll([
        _leaf(ref: 'z_b_1', sortOrder: 0, level1: 'Zeraim', level2: 'Berachos'),
        _leaf(ref: 'z_b_2', sortOrder: 1, level1: 'Zeraim', level2: 'Berachos'),
      ]);
      fakeCompletionRepo.rows.addAll([
        _completion(
          ref: 'z_b_1',
          stageId: 1,
          source: CompletionSource.bulkInTrack,
        ),
        _completion(
          ref: 'z_b_2',
          stageId: 1,
          source: CompletionSource.bulkInTrack,
        ),
      ]);
      fakeLedgerRepo.entries.addAll([
        _ledgerEntry(
          ulid: 'siyum_masechta_berachos',
          entryScope: 'masechta',
          unitIdentifier: 'Berachos',
          completionNumber: 1,
        ),
        _ledgerEntry(
          ulid: 'siyum_seder_zeraim',
          entryScope: 'seder',
          unitIdentifier: 'Zeraim',
          completionNumber: 1,
        ),
      ]);
      final svc = buildService();

      await svc.expungePriorCompletions(
        sefariaRefs: ['z_b_1', 'z_b_2'],
        curriculumId: curriculum,
      );

      // Both completions tombstoned...
      expect(fakeCompletionRepo.purgeCalls, hasLength(2));
      // ...and both siyumim retracted, each exactly once (a per-ref pass
      // would attempt the same unit twice; the fake's purgeEntry does not
      // itself guard against a double-call, so this alone would not catch
      // a regression — the call-count assertions below do).
      expect(
        fakeLedgerRepo.purgedUlids,
        containsAll(['siyum_masechta_berachos', 'siyum_seder_zeraim']),
      );
      expect(fakeLedgerRepo.purgedUlids, hasLength(2));
      // The review-flagged redundant-reads cost: the tombstone-including
      // ledger read is fetched ONCE for the whole batch, not once per
      // unit/ref.
      expect(
        fakeLedgerRepo.getLedgerByCurriculumIncludingTombstonedCallCount,
        1,
      );
      // Coverage is checked once per DISTINCT unit (masechta + seder = 2),
      // not once per ref (which would be 4: 2 refs × 2 units each).
      expect(fakeContentRepo.filterByLevelCallCount, 2);
    });

    test('(j) resumable: a prior call already tombstoned the only completion '
        '(toExpunge is EMPTY this call) but the siyum was never retracted → '
        'this call still retracts it — an empty match must not short-circuit '
        'the coverage-check-and-retract step (Fix 3a)', () async {
      fakeContentRepo.items.add(
        _leaf(ref: 'z_b_1', sortOrder: 0, level1: 'Zeraim', level2: 'Berachos'),
      );
      // The completion is ALREADY tombstoned (simulating a prior partial
      // attempt) — getCompletionsForContentItem returns it, but the
      // `purgedAt == null` filter excludes it from toExpunge.
      fakeCompletionRepo.rows.add(
        _completion(
          ref: 'z_b_1',
          stageId: 1,
          source: CompletionSource.bulkInTrack,
          purgedAt: DateTime.utc(2026, 1, 2),
        ),
      );
      // The siyum from that earlier (interrupted) attempt is still live —
      // this is exactly the stuck state Fix 3a exists to unstick.
      fakeLedgerRepo.entries.add(
        _ledgerEntry(
          ulid: 'siyum_masechta_berachos',
          entryScope: 'masechta',
          unitIdentifier: 'Berachos',
          completionNumber: 1,
        ),
      );
      final svc = buildService();

      await svc.expungePriorCompletions(
        sefariaRefs: ['z_b_1'],
        curriculumId: curriculum,
      );

      // Nothing new to tombstone this call...
      expect(fakeCompletionRepo.purgeCalls, isEmpty);
      // ...but the coverage-check-and-retract step still ran and found the
      // unit uncovered (no non-purged completions at all), retracting the
      // stranded siyum.
      expect(fakeLedgerRepo.purgedUlids, ['siyum_masechta_berachos']);
    });

    test('(k) epoch idempotency: two non-purged entries for the same unit '
        '(completionNumber 1 and 2) with coverage staying false across two '
        'calls → call 1 retracts the highest (#2), call 2 finds #2 already '
        'purged and does NOT reach down to #1 — the older entry survives both '
        'calls (this is the core review fix: repeated calls must not walk '
        'down the whole stack of historical entries for a unit)', () async {
      fakeContentRepo.items.add(
        _leaf(ref: 'z_b_1', sortOrder: 0, level1: 'Zeraim', level2: 'Berachos'),
      );
      fakeCompletionRepo.rows.add(
        _completion(
          ref: 'z_b_1',
          stageId: 1,
          source: CompletionSource.bulkInTrack,
        ),
      );
      fakeLedgerRepo.entries.addAll([
        _ledgerEntry(
          ulid: 'low',
          entryScope: 'masechta',
          unitIdentifier: 'Berachos',
          completionNumber: 1,
        ),
        _ledgerEntry(
          ulid: 'high',
          entryScope: 'masechta',
          unitIdentifier: 'Berachos',
          completionNumber: 2,
        ),
      ]);
      final svc = buildService();

      // Call 1: tombstones the one bulkInTrack completion, unit becomes
      // uncovered, retracts the TRUE highest entry ('high', #2).
      await svc.expungePriorCompletions(
        sefariaRefs: ['z_b_1'],
        curriculumId: curriculum,
      );
      expect(fakeLedgerRepo.purgedUlids, ['high']);
      expect(
        fakeLedgerRepo.entries.firstWhere((e) => e.ulid == 'low').purgedAt,
        isNull,
      );

      // Call 2: nothing new to tombstone (already purged), unit is still
      // uncovered — but the true-highest entry ('high') is ALREADY purged,
      // so this call must stop there and NOT reach down to 'low'.
      await svc.expungePriorCompletions(
        sefariaRefs: ['z_b_1'],
        curriculumId: curriculum,
      );

      expect(fakeLedgerRepo.purgedUlids, ['high']); // unchanged — no 'low'.
      expect(
        fakeLedgerRepo.entries.firstWhere((e) => e.ulid == 'low').purgedAt,
        isNull,
      );
      expect(
        fakeLedgerRepo.entries.firstWhere((e) => e.ulid == 'high').purgedAt,
        isNotNull,
      );
    });

    test('(l) restore-then-new-coverage-loss: a retracted entry that is later '
        'restored (purgedAt cleared, mirroring recordCompletion re-earning the '
        'SAME deterministic-ulid doc) is correctly retracted again on a fresh, '
        'independent coverage-loss epoch', () async {
      fakeContentRepo.items.add(
        _leaf(ref: 'z_b_1', sortOrder: 0, level1: 'Zeraim', level2: 'Berachos'),
      );
      fakeCompletionRepo.rows.add(
        _completion(
          ref: 'z_b_1',
          stageId: 1,
          source: CompletionSource.bulkInTrack,
        ),
      );
      fakeLedgerRepo.entries.add(
        _ledgerEntry(
          ulid: 'siyum_masechta_berachos',
          entryScope: 'masechta',
          unitIdentifier: 'Berachos',
          completionNumber: 1,
        ),
      );
      final svc = buildService();

      // Epoch 1: coverage lost → retract.
      await svc.expungePriorCompletions(
        sefariaRefs: ['z_b_1'],
        curriculumId: curriculum,
      );
      expect(fakeLedgerRepo.purgedUlids, ['siyum_masechta_berachos']);

      // Simulate re-earn: FirestoreLearningLedgerRepository.recordCompletion
      // restores the SAME deterministic-ulid doc (clears purged_at, keeps
      // completionNumber) instead of writing a new one, and a fresh
      // bulkInTrack completion is written for the leaf again.
      final idx = fakeLedgerRepo.entries.indexWhere(
        (e) => e.ulid == 'siyum_masechta_berachos',
      );
      fakeLedgerRepo.entries[idx] = _ledgerEntry(
        ulid: 'siyum_masechta_berachos',
        entryScope: 'masechta',
        unitIdentifier: 'Berachos',
        completionNumber: 1,
        purgedAt: null,
      );
      fakeCompletionRepo.rows.add(
        _completion(
          ref: 'z_b_1',
          stageId: 1,
          source: CompletionSource.bulkInTrack,
        ),
      );

      // Epoch 2: a fresh, independent coverage loss — the restored (now
      // non-purged again) entry is the true-highest for the unit and must
      // be retracted again.
      await svc.expungePriorCompletions(
        sefariaRefs: ['z_b_1'],
        curriculumId: curriculum,
      );

      expect(fakeLedgerRepo.purgedUlids, [
        'siyum_masechta_berachos',
        'siyum_masechta_berachos',
      ]);
      expect(
        fakeLedgerRepo.entries
            .firstWhere((e) => e.ulid == 'siyum_masechta_berachos')
            .purgedAt,
        isNotNull,
      );
    });
  });
}

BookmarkEntity _fakeBookmarkEntity() {
  return BookmarkEntity(
    curriculumId: CurriculumId.mishnayos,
    sefariaRef: 'ref',
    updatedAt: DateTime.now(),
  );
}

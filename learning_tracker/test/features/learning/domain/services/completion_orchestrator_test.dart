/// Unit tests for [CompletionOrchestrator] — the layer that owns the five
/// completion side effects above storage (`docs/firestore-rewrite-map.md`,
/// owner decision 1, 2026-08-03): order validation, points, achievement
/// (siyum) detection, bookmark advance, and streak.
///
/// Deliberately DB-free: every collaborator is a hand-rolled fake or a
/// mocktail mock of [CompletionDetectionService] (a concrete class, mockable
/// without a real `UserDatabase`). This proves the orchestrator's
/// SEQUENCING and GATING logic is correct independent of any storage
/// backend — the companion Drift-backed integration coverage
/// (`mark_completion_use_case_siyum_routing_test.dart`,
/// `completion_repository_impl_test.dart`,
/// `epic_27_integration_lockout_redaction_atomic_test.dart`, and others)
/// proves the real Drift adapters wire correctly into it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/mark_completion_result.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';
import 'package:mocktail/mocktail.dart';

// ─── Fakes ───────────────────────────────────────────────────────────────

/// Hand-rolled in-memory [CompletionRepository] — proves
/// [CompletionOrchestrator] needs NOTHING beyond this interface's four
/// methods to fully drive a write ("the storage layer beneath is genuinely
/// storage-only"): this fake has no notion of points, streaks, siyumim, or
/// bookmarks at all, and every test below still passes.
class _FakeCompletionRepository implements CompletionRepository {
  final List<Completion> rows = [];
  int _nextId = 1;

  /// Every [markComplete] request this fake received, in call order — lets
  /// tests assert on exactly what the orchestrator handed to storage (e.g.
  /// the pre-computed `points` value) without needing a real DB.
  final List<CompletionRequest> markCompleteRequests = [];
  final List<BulkCompletionRequest> bulkMarkCompleteRequests = [];

  @override
  Future<MarkCompletionResult> markComplete(
    CompletionRequest request, {
    bool awardGamificationPoints = true,
    bool creditsAchievement = true,
  }) async {
    markCompleteRequests.add(request);
    final existing = _find(
      curriculumId: request.curriculumId,
      sefariaRef: request.sefariaRef,
      stageId: request.stageId,
      trackType: request.trackType,
    );
    if (existing != null) {
      return MarkCompletionResult(completion: existing, isNew: false);
    }
    final created = Completion(
      id: _nextId++,
      profileId: 1,
      curriculumId: request.curriculumId,
      sefariaRef: request.sefariaRef,
      stageId: request.stageId,
      trackType: request.trackType,
      trackId: 1,
      completedAt: DateTime.utc(2026, 6, 1),
      points: request.points,
    );
    rows.add(created);
    return MarkCompletionResult(completion: created);
  }

  @override
  Future<List<Completion>> bulkMarkComplete(
    BulkCompletionRequest request,
  ) async {
    bulkMarkCompleteRequests.add(request);
    final result = <Completion>[];
    for (final ref in request.sefariaRefs) {
      final existing = _find(
        curriculumId: request.curriculumId,
        sefariaRef: ref,
        stageId: request.stageId,
        trackType: request.trackType,
      );
      if (existing != null) {
        result.add(existing);
        continue;
      }
      final created = Completion(
        id: _nextId++,
        profileId: 1,
        curriculumId: request.curriculumId,
        sefariaRef: ref,
        stageId: request.stageId,
        trackType: request.trackType,
        trackId: 1,
        completedAt: request.completedAt ?? DateTime.utc(2026, 6, 1),
        points: request.points,
      );
      rows.add(created);
      result.add(created);
    }
    return result;
  }

  @override
  Future<List<Completion>> getCompletionsByCurriculum(
    String curriculumId, {
    int? profileId,
  }) async => rows.where((c) => c.curriculumId == curriculumId).toList();

  @override
  Future<List<Completion>> getCompletionsForContentItem(
    String sefariaRef,
  ) async => rows.where((c) => c.sefariaRef == sefariaRef).toList();

  @override
  Future<bool> isStageCompleted({
    required String sefariaRef,
    required int stageId,
    required String trackType,
  }) async =>
      _find(
        curriculumId: rows.firstOrNull?.curriculumId ?? '',
        sefariaRef: sefariaRef,
        stageId: stageId,
        trackType: trackType,
      ) !=
      null;

  Completion? _find({
    required String curriculumId,
    required String sefariaRef,
    required int stageId,
    required String trackType,
  }) {
    for (final c in rows) {
      if (c.curriculumId == curriculumId &&
          c.sefariaRef == sefariaRef &&
          c.stageId == stageId &&
          c.trackType == trackType) {
        return c;
      }
    }
    return null;
  }
}

class _FakeContentRepository implements ContentRepository {
  @override
  Future<List<ContentItem>> getContentForCurriculum(
    CurriculumId curriculumId,
  ) async => const [];

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) async => const CurriculumHierarchyConfig(
    curriculumId: 'mishnayos',
    levelLabels: [],
    totalItems: 0,
  );

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async => const [];

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async => const [];

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) async => const [];

  // Bulk siyum dispatch (CompletionOrchestrator._dispatchSiyumDetectionForRefs)
  // groups refs by parent unit via a content lookup before dispatching —
  // return a plausible leaf so that grouping has something to work with.
  // (The single-item dispatch path does not depend on this at all.)
  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async => ContentItem(
    curriculumId: curriculumId.storageKey,
    level1: 'Zeraim',
    level2: 'Berakhot',
    displayNameHe: sefariaRef,
    displayNameEn: sefariaRef,
    sefariaRef: sefariaRef,
    sortOrder: 0,
    isLeaf: true,
  );
}

/// Records every credit/award call — never touches a real balance.
class _FakePointsPort implements CompletionPointsPort {
  int nextPoints = 10;
  final List<({int profileId, int points, String note})> creditCalls = [];

  @override
  Future<int> calculatePoints({
    required String curriculumId,
    required int stageOrder,
    required int profileId,
  }) async => nextPoints;

  @override
  Future<void> creditCompletion({
    required int profileId,
    required int points,
    required String note,
  }) async {
    creditCalls.add((profileId: profileId, points: points, note: note));
  }
}

class _FakeStreakPort implements CompletionStreakPort {
  final List<({int profileId, DateTime at})> recordCalls = [];

  @override
  Future<void> recordStudyDay({
    required int profileId,
    required DateTime at,
  }) async {
    recordCalls.add((profileId: profileId, at: at));
  }
}

class _FakeBookmarkRepository implements BookmarkRepository {
  final List<({CurriculumId curriculumId, String completedSefariaRef})>
  advanceCalls = [];
  Error? throwOnAdvance;

  @override
  Future<void> advanceBookmark({
    required CurriculumId curriculumId,
    required String completedSefariaRef,
  }) async {
    advanceCalls.add((
      curriculumId: curriculumId,
      completedSefariaRef: completedSefariaRef,
    ));
    final err = throwOnAdvance;
    if (err != null) throw err;
  }

  @override
  Future<BookmarkEntity?> getBookmark({required CurriculumId curriculumId}) =>
      throw UnimplementedError();

  @override
  Future<BookmarkEntity> setBookmark({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) => throw UnimplementedError();

  @override
  Future<BookmarkEntity> initializeBookmark({
    required CurriculumId curriculumId,
  }) => throw UnimplementedError();
}

class _MockCompletionDetectionService extends Mock
    implements CompletionDetectionService {}

// ─── Shared fixtures ────────────────────────────────────────────────────

const _curriculumId = 'mishnayos';
const _sefariaRef = 'Mishnah Berachot 1:1';
const _stage1 = CompletionRequest(
  curriculumId: _curriculumId,
  sefariaRef: _sefariaRef,
  stageId: 1,
  trackType: 'personal',
);

void main() {
  setUpAll(() {
    registerFallbackValue(CompletionSource.live);
  });

  late _FakeCompletionRepository repository;
  late _FakePointsPort pointsPort;
  late _FakeStreakPort streakPort;
  late _FakeBookmarkRepository bookmarkRepository;
  late _MockCompletionDetectionService detectionService;

  CompletionOrchestrator buildOrchestrator({bool withCollaborators = true}) {
    return CompletionOrchestrator(
      repository: repository,
      contentRepository: _FakeContentRepository(),
      activeProfileId: 1,
      bookmarkRepository: withCollaborators ? bookmarkRepository : null,
      completionDetectionService: withCollaborators ? detectionService : null,
      pointsPort: withCollaborators ? pointsPort : null,
      streakPort: withCollaborators ? streakPort : null,
    );
  }

  setUp(() {
    repository = _FakeCompletionRepository();
    pointsPort = _FakePointsPort();
    streakPort = _FakeStreakPort();
    bookmarkRepository = _FakeBookmarkRepository();
    detectionService = _MockCompletionDetectionService();
    when(
      () => detectionService.checkAndRecordCompletions(
        curriculumId: any(named: 'curriculumId'),
        sefariaRef: any(named: 'sefariaRef'),
        trackType: any(named: 'trackType'),
        profileId: any(named: 'profileId'),
        markedBy: any(named: 'markedBy'),
        source: any(named: 'source'),
        includeUnitLevelCheck: any(named: 'includeUnitLevelCheck'),
        includeAggregateLevelCheck: any(named: 'includeAggregateLevelCheck'),
      ),
    ).thenAnswer((_) async {});
  });

  group('live — all five behaviors fire', () {
    test(
      'order validation, points, streak, siyum, and bookmark all fire',
      () async {
        final orchestrator = buildOrchestrator();

        final result = await orchestrator.markComplete(_stage1);

        expect(result.completion.sefariaRef, _sefariaRef);
        expect(
          result.completion.points,
          pointsPort.nextPoints,
          reason: 'points computed by the port must land on the stored row',
        );
        expect(
          pointsPort.creditCalls,
          hasLength(1),
          reason: 'live must credit the computed points',
        );
        expect(pointsPort.creditCalls.single.points, pointsPort.nextPoints);
        expect(
          streakPort.recordCalls,
          hasLength(1),
          reason: 'live must record the study day',
        );
        verify(
          () => detectionService.checkAndRecordCompletions(
            curriculumId: _curriculumId,
            sefariaRef: _sefariaRef,
            trackType: 'personal',
            profileId: 1,
            markedBy: 1,
            source: CompletionSource.live,
          ),
        ).called(1);
        expect(
          bookmarkRepository.advanceCalls,
          hasLength(1),
          reason: 'bookmark must advance past the completed item',
        );
        expect(
          bookmarkRepository.advanceCalls.single.completedSefariaRef,
          _sefariaRef,
        );
      },
    );
  });

  group(
    'bulkInTrack — engagement suppressed, achievement and bookmark still fire',
    () {
      test(
        'points and streak do NOT fire, but siyum detection and bookmark do',
        () async {
          final orchestrator = buildOrchestrator();

          await orchestrator.markComplete(
            _stage1,
            awardGamificationPoints: false,
            creditsAchievement: true,
          );

          expect(
            pointsPort.creditCalls,
            isEmpty,
            reason: 'bulkInTrack must suppress engagement (points)',
          );
          expect(
            streakPort.recordCalls,
            isEmpty,
            reason: 'bulkInTrack must suppress engagement (streak)',
          );
          verify(
            () => detectionService.checkAndRecordCompletions(
              curriculumId: any(named: 'curriculumId'),
              sefariaRef: any(named: 'sefariaRef'),
              trackType: any(named: 'trackType'),
              profileId: any(named: 'profileId'),
              markedBy: any(named: 'markedBy'),
              source: CompletionSource.bulkInTrack,
            ),
          ).called(1);
          expect(
            bookmarkRepository.advanceCalls,
            hasLength(1),
            reason:
                'bookmark advance is source-independent — it is a reading-'
                'position pointer, not a credit-tier side effect',
          );
        },
      );
    },
  );

  group('lifetimeOnly — engagement and achievement both suppressed', () {
    test(
      'points, streak, and siyum all skip; bookmark still advances',
      () async {
        final orchestrator = buildOrchestrator();

        await orchestrator.markComplete(
          _stage1,
          awardGamificationPoints: false,
          creditsAchievement: false,
        );

        expect(pointsPort.creditCalls, isEmpty);
        expect(streakPort.recordCalls, isEmpty);
        verifyNever(
          () => detectionService.checkAndRecordCompletions(
            curriculumId: any(named: 'curriculumId'),
            sefariaRef: any(named: 'sefariaRef'),
            trackType: any(named: 'trackType'),
            profileId: any(named: 'profileId'),
            markedBy: any(named: 'markedBy'),
            source: any(named: 'source'),
          ),
        );
        expect(bookmarkRepository.advanceCalls, hasLength(1));
      },
    );
  });

  group('order validation — before any write', () {
    test('stage 2 with no prior stage 1 throws BEFORE the repository is '
        'ever asked to write', () async {
      final orchestrator = buildOrchestrator();

      await expectLater(
        orchestrator.markComplete(
          const CompletionRequest(
            curriculumId: _curriculumId,
            sefariaRef: _sefariaRef,
            stageId: 2,
            trackType: 'personal',
          ),
        ),
        throwsA(isA<StageProgressionException>()),
      );

      expect(
        repository.markCompleteRequests,
        isEmpty,
        reason:
            'the repository must never be asked to write an out-of-order '
            'mark — validation runs before the write, not after (see '
            'CompletionOrchestrator\'s class doc comment, "Ordering")',
      );
      expect(repository.rows, isEmpty);
    });

    test(
      'stage 1 then stage 3 (skipping stage 2) throws on the second call',
      () async {
        final orchestrator = buildOrchestrator();
        await orchestrator.markComplete(_stage1);

        await expectLater(
          orchestrator.markComplete(
            const CompletionRequest(
              curriculumId: _curriculumId,
              sefariaRef: _sefariaRef,
              stageId: 3,
              trackType: 'personal',
            ),
          ),
          throwsA(isA<StageProgressionException>()),
        );

        // Only the valid stage-1 write landed.
        expect(repository.rows, hasLength(1));
      },
    );

    test('bulk path validates every ref before writing any of them', () async {
      final orchestrator = buildOrchestrator();
      // ref A already has stage 1; ref B has nothing yet. A bulk stage-3
      // request must reject the whole batch before writing either ref.
      await orchestrator.markComplete(
        const CompletionRequest(
          curriculumId: _curriculumId,
          sefariaRef: 'ref-a',
          stageId: 1,
          trackType: 'personal',
        ),
      );

      await expectLater(
        orchestrator.bulkMarkComplete(
          const BulkCompletionRequest(
            curriculumId: _curriculumId,
            sefariaRefs: ['ref-a', 'ref-b'],
            stageId: 3,
            trackType: 'personal',
          ),
        ),
        throwsA(isA<StageProgressionException>()),
      );

      expect(
        repository.bulkMarkCompleteRequests,
        isEmpty,
        reason: 'bulk order validation must reject before any bulk write',
      );
    });
  });

  group('storage layer beneath is genuinely storage-only', () {
    test('markComplete succeeds with every optional collaborator omitted — '
        'the repository alone is sufficient for a write', () async {
      final orchestrator = buildOrchestrator(withCollaborators: false);

      final result = await orchestrator.markComplete(_stage1);

      expect(result.completion.sefariaRef, _sefariaRef);
      expect(
        result.completion.points,
        0,
        reason: 'no points port wired → 0 points, not a crash',
      );
      // The fake repository has no field, method, or concept of points,
      // streaks, siyumim, or bookmarks — its interface is the entire
      // contract CompletionOrchestrator needs from storage.
    });

    test('the write request carries the orchestrator-computed points value, '
        'not a repository-computed one', () async {
      pointsPort.nextPoints = 42;
      final orchestrator = buildOrchestrator();

      await orchestrator.markComplete(_stage1);

      expect(
        repository.markCompleteRequests.single.points,
        42,
        reason:
            'points must be computed by CompletionPointsPort before the '
            'repository is called — the repository only ever persists a '
            'number it was handed (see CompletionRequest.points\'s doc '
            'comment)',
      );
    });
  });

  group(
    'post-write side effects are best-effort — none roll back the write',
    () {
      test('a throwing bookmark repository does not fail markComplete or '
          'retract the completion', () async {
        bookmarkRepository.throwOnAdvance = StateError('simulated failure');
        final orchestrator = buildOrchestrator();

        final result = await orchestrator.markComplete(_stage1);

        expect(result.completion.sefariaRef, _sefariaRef);
        expect(
          repository.rows,
          hasLength(1),
          reason:
              'a live completion is permanent — a downstream bookmark-advance '
              'failure must never retract it (see CompletionOrchestrator\'s '
              'class doc comment, "Atomicity")',
        );
      });
    },
  );

  group('bulk siyum dispatch is awaited, not fire-and-forget', () {
    test(
      'bulkMarkComplete does not return until siyum dispatch settles',
      () async {
        final orchestrator = buildOrchestrator();
        var dispatchCompleted = false;
        when(
          () => detectionService.checkAndRecordCompletions(
            curriculumId: any(named: 'curriculumId'),
            sefariaRef: any(named: 'sefariaRef'),
            trackType: any(named: 'trackType'),
            profileId: any(named: 'profileId'),
            markedBy: any(named: 'markedBy'),
            source: any(named: 'source'),
            includeUnitLevelCheck: any(named: 'includeUnitLevelCheck'),
            includeAggregateLevelCheck: any(
              named: 'includeAggregateLevelCheck',
            ),
          ),
        ).thenAnswer((_) async {
          dispatchCompleted = true;
        });

        await orchestrator.bulkMarkComplete(
          const BulkCompletionRequest(
            curriculumId: _curriculumId,
            sefariaRefs: [_sefariaRef],
            stageId: 1,
            trackType: 'personal',
            creditsAchievement: true,
          ),
        );

        expect(
          dispatchCompleted,
          isTrue,
          reason:
              'unlike the single-item path, bulk siyum dispatch is awaited so '
              'callers observe a synchronous "bulk insert + siyum ledger '
              'update" boundary',
        );
      },
    );
  });
}

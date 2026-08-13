/// Unit tests for [TrackProgressService] — Layer 3 architectural unification.
///
/// Covers all three tier filters ([liveOnly], [trackAchievement], [lifetime])
/// plus edge cases (empty profile, only-bulk profile, mixed profile).
@Tags(['tracks', 'track_progress_service'])
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart'
    show ChartDataRepository;
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/tracks/domain/services/track_progress_service.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _uid = 'track-progress-uid';
const _profileId = '01J6Q2H4A8M7K3P9R5T6V8WXY2';
const _lifetimeUlid = '01J6Q2H4A8M7K3P9R5T6V8WXYA';
final _liveAt = DateTime.utc(2026, 5, 1, 12);
final _liveAt2 = DateTime.utc(2026, 5, 2, 12);
final _bulkAt = DateTime.utc(2000, 1, 1); // sentinel

/// Seeds a live completion event (not in prior_completion_imports).
Future<void> seedLive(
  FakeFirebaseFirestore firestore, {
  required String sefariaRef,
  int stageId = 1,
  DateTime? completedAt,
}) async {
  await seedCompletion(
    firestore,
    uid: _uid,
    profileId: _profileId,
    sefariaRef: sefariaRef,
    stageId: stageId,
    trackType: 'personal',
    source: CompletionSource.live,
    completedAt: completedAt ?? _liveAt,
  );
}

/// Seeds a bulk-in-track completion (completion_events + prior_completion_imports).
Future<void> seedBulkInTrack(
  FakeFirebaseFirestore firestore, {
  required String sefariaRef,
  int stageId = 1,
}) async {
  await seedCompletion(
    firestore,
    uid: _uid,
    profileId: _profileId,
    sefariaRef: sefariaRef,
    stageId: stageId,
    trackType: 'personal',
    source: CompletionSource.bulkInTrack,
    completedAt: _bulkAt,
  );
}

/// Seeds a lifetime-only completion in the append-only learning ledger.
Future<void> seedLifetimeOnly(
  FakeFirebaseFirestore firestore, {
  required String sefariaRef,
}) async {
  await seedLedgerEntry(
    firestore,
    uid: _uid,
    profileId: _profileId,
    ulid: _lifetimeUlid,
    unitIdentifier: sefariaRef,
    curriculumId: CurriculumId.mishnayos,
    trackType: 'personal',
    source: CompletionSource.lifetimeOnly,
    completedAt: _bulkAt,
  );
}

class _FirestoreChartDataRepository implements ChartDataRepository {
  _FirestoreChartDataRepository(this._completions);

  final FirestoreCompletionRepository _completions;

  @override
  Future<List<CompletionEntity>> getCompletionsByTier({
    required CompletionTierFilter tier,
    CurriculumId? curriculumId,
    DateTime? since,
    DateTime? until,
  }) => _completions.getCompletionsByTier(
    tier: tier,
    curriculumId: curriculumId,
    since: since,
    until: until,
  );

  @override
  Future<List<CompletionEntity>> getCompletionsByCurriculum(
    CurriculumId curriculumId,
  ) => _completions.getCompletionsForCurriculum(curriculumId);

  @override
  Future<List<GoalEntity>> getGoals(CurriculumId curriculumId) async => [];
}

class _FirestoreStageRepository extends Mock
    implements StageDefinitionRepository {
  _FirestoreStageRepository(this._repository);

  final FirestoreStageDefinitionRepository _repository;

  @override
  Future<List<StageDefinition>> getStagesForCurriculum(CurriculumId id) =>
      _repository.getStagesForCurriculum(id);
}

/// Seeds stage definitions for [trackId] with [stageCount] sequential stages
/// (stageOrders 1..N) using the repository's initializeDefaults then
/// supplementing extra stages if needed.
///
/// Uses direct DB insert with the JSON-encoded schedule column (W3.27).
Future<void> seedStages(
  FakeFirebaseFirestore firestore, {
  int stageCount = 1,
  CurriculumId curriculum = CurriculumId.mishnayos,
}) async {
  await seedStageDefinitions(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: curriculum,
    stages: [
      for (var i = 1; i <= stageCount; i++)
        StageDefinition(
          id: kFirestoreUnmappedStageId,
          curriculumId: curriculum,
          stageOrder: i,
          stageName: i == 1 ? 'Learn' : 'Chazara $i',
          delayDays: 0,
          isDefault: true,
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeFirebaseFirestore firestore;
  late TrackProgressService service;

  setUp(() async {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    await seedProfile(firestore, uid: _uid, profileId: _profileId);
    final completions = FirestoreCompletionRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
    final stages = FirestoreStageDefinitionRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
    service = TrackProgressService(
      repository: _FirestoreChartDataRepository(completions),
      stageRepo: _FirestoreStageRepository(stages),
    );
  });

  // ── Edge case: empty profile ─────────────────────────────────────────────

  group('completionPercent — empty profile', () {
    test('returns 0.0 when no completions exist (liveOnly)', () async {
      await seedStages(firestore);
      final pct = await service.completionPercent(
        curriculumId: CurriculumId.mishnayos,
        tier: CompletionTierFilter.liveOnly,
        totalItems: 10,
      );
      expect(pct, 0.0);
    });

    test('returns 0.0 when no completions exist (trackAchievement)', () async {
      await seedStages(firestore);
      final pct = await service.completionPercent(
        curriculumId: CurriculumId.mishnayos,
        tier: CompletionTierFilter.trackAchievement,
        totalItems: 10,
      );
      expect(pct, 0.0);
    });

    test('returns 0.0 when no completions exist (lifetime)', () async {
      await seedStages(firestore);
      final pct = await service.completionPercent(
        curriculumId: CurriculumId.mishnayos,
        tier: CompletionTierFilter.lifetime,
        totalItems: 10,
      );
      expect(pct, 0.0);
    });

    test('returns 0.0 when totalItems is 0', () async {
      final pct = await service.completionPercent(
        curriculumId: CurriculumId.mishnayos,
        tier: CompletionTierFilter.lifetime,
        totalItems: 0,
      );
      expect(pct, 0.0);
    });
  });

  // ── Only-bulk profile ─────────────────────────────────────────────────────

  group('completionPercent — only-bulk profile', () {
    test(
      'liveOnly returns 0.0 when only bulkInTrack completions exist',
      () async {
        await seedStages(firestore);
        await seedBulkInTrack(firestore, sefariaRef: 'ref1');
        await seedBulkInTrack(firestore, sefariaRef: 'ref2');

        final pct = await service.completionPercent(
          curriculumId: CurriculumId.mishnayos,
          tier: CompletionTierFilter.liveOnly,
          totalItems: 10,
        );
        expect(pct, 0.0, reason: 'Bulk-only profile: liveOnly tier must be 0');
      },
    );

    test('trackAchievement counts bulkInTrack completions', () async {
      await seedStages(firestore);
      await seedBulkInTrack(firestore, sefariaRef: 'ref1');
      await seedBulkInTrack(firestore, sefariaRef: 'ref2');

      final pct = await service.completionPercent(
        curriculumId: CurriculumId.mishnayos,
        tier: CompletionTierFilter.trackAchievement,
        totalItems: 10,
      );
      expect(
        pct,
        closeTo(0.2, 1e-9),
        reason: '2/10 items done via bulkInTrack',
      );
    });

    test('lifetime counts bulkInTrack completions', () async {
      await seedStages(firestore);
      await seedBulkInTrack(firestore, sefariaRef: 'ref1');

      final pct = await service.completionPercent(
        curriculumId: CurriculumId.mishnayos,
        tier: CompletionTierFilter.lifetime,
        totalItems: 4,
      );
      expect(pct, closeTo(0.25, 1e-9));
    });

    test(
      'liveOnly returns 0.0 when only lifetimeOnly completions exist',
      () async {
        await seedStages(firestore);
        await seedLifetimeOnly(firestore, sefariaRef: 'ref1');

        final pct = await service.completionPercent(
          curriculumId: CurriculumId.mishnayos,
          tier: CompletionTierFilter.liveOnly,
          totalItems: 10,
        );
        expect(pct, 0.0);
      },
    );

    test('trackAchievement returns 0.0 for lifetimeOnly completions', () async {
      await seedStages(firestore);
      await seedLifetimeOnly(firestore, sefariaRef: 'ref1');

      final pct = await service.completionPercent(
        curriculumId: CurriculumId.mishnayos,
        tier: CompletionTierFilter.trackAchievement,
        totalItems: 10,
      );
      expect(
        pct,
        0.0,
        reason: 'lifetimeOnly must NOT credit trackAchievement tier',
      );
    });

    test('lifetime counts lifetimeOnly completions', () async {
      await seedStages(firestore);
      await seedLifetimeOnly(firestore, sefariaRef: 'ref1');

      final pct = await service.completionPercent(
        curriculumId: CurriculumId.mishnayos,
        tier: CompletionTierFilter.lifetime,
        totalItems: 5,
      );
      expect(pct, closeTo(0.2, 1e-9));
    });
  });

  // ── Mixed profile ─────────────────────────────────────────────────────────

  group('completionPercent — mixed profile (live + bulk + lifetime)', () {
    test('tier isolation: liveOnly < trackAchievement <= lifetime', () async {
      await seedStages(firestore);
      await seedLive(firestore, sefariaRef: 'ref_live');
      await seedBulkInTrack(firestore, sefariaRef: 'ref_bulk');
      await seedLifetimeOnly(firestore, sefariaRef: 'ref_lt');

      const totalItems = 10;
      final liveOnlyPct = await service.completionPercent(
        curriculumId: CurriculumId.mishnayos,
        tier: CompletionTierFilter.liveOnly,
        totalItems: totalItems,
      );
      final achievePct = await service.completionPercent(
        curriculumId: CurriculumId.mishnayos,
        tier: CompletionTierFilter.trackAchievement,
        totalItems: totalItems,
      );
      final lifetimePct = await service.completionPercent(
        curriculumId: CurriculumId.mishnayos,
        tier: CompletionTierFilter.lifetime,
        totalItems: totalItems,
      );

      expect(liveOnlyPct, closeTo(0.1, 1e-9), reason: '1/10 live');
      expect(achievePct, closeTo(0.2, 1e-9), reason: '2/10 live+bulk');
      expect(lifetimePct, closeTo(0.3, 1e-9), reason: '3/10 all sources');
      expect(
        liveOnlyPct,
        lessThanOrEqualTo(achievePct),
        reason: 'liveOnly ≤ trackAchievement',
      );
      expect(
        achievePct,
        lessThanOrEqualTo(lifetimePct),
        reason: 'trackAchievement ≤ lifetime',
      );
    });

    test('multi-stage gate: item requires all stages to be done', () async {
      await seedStages(firestore, stageCount: 2);

      // ref1 has stage1 + stage2 (fully done)
      await seedLive(firestore, sefariaRef: 'ref1', stageId: 1);
      await seedLive(
        firestore,
        sefariaRef: 'ref1',
        stageId: 2,
        completedAt: _liveAt2,
      );
      // ref2 has only stage1 (partially done — not counted)
      await seedLive(firestore, sefariaRef: 'ref2', stageId: 1);

      final pct = await service.completionPercent(
        curriculumId: CurriculumId.mishnayos,
        tier: CompletionTierFilter.liveOnly,
        totalItems: 10,
      );
      expect(pct, closeTo(0.1, 1e-9), reason: 'Only ref1 is fully done: 1/10');
    });

    test('requireAllStages=false counts any single-ref', () async {
      await seedStages(firestore, stageCount: 2);
      await seedLive(firestore, sefariaRef: 'ref1', stageId: 1);
      await seedLive(firestore, sefariaRef: 'ref2', stageId: 1);

      final pct = await service.completionPercent(
        curriculumId: CurriculumId.mishnayos,
        tier: CompletionTierFilter.liveOnly,
        totalItems: 10,
        requireAllStages: false,
      );
      expect(
        pct,
        closeTo(0.2, 1e-9),
        reason: '2/10 refs touched, ignoring stage-gate',
      );
    });

    test('since filter excludes pre-activation completions', () async {
      await seedStages(firestore);
      final activatedAt = DateTime.utc(2026, 3, 1);
      await seedLive(
        firestore,
        sefariaRef: 'old_ref',
        completedAt: DateTime.utc(2026, 2, 1),
      );
      await seedLive(
        firestore,
        sefariaRef: 'new_ref',
        completedAt: DateTime.utc(2026, 4, 1),
      );

      final pct = await service.completionPercent(
        curriculumId: CurriculumId.mishnayos,
        tier: CompletionTierFilter.liveOnly,
        totalItems: 10,
        since: activatedAt,
      );
      expect(
        pct,
        closeTo(0.1, 1e-9),
        reason: 'Only new_ref (after activatedAt) counts: 1/10',
      );
    });
  });

  // ── dailyCounts ────────────────────────────────────────────────────────────

  group('dailyCounts', () {
    test(
      'liveOnly returns zero counts when only bulk completions exist',
      () async {
        await seedBulkInTrack(firestore, sefariaRef: 'ref1');
        final start = DateTime(2026, 5, 1);
        final end = DateTime(2026, 5, 3);

        final data = await service.dailyCounts(
          tier: CompletionTierFilter.liveOnly,
          startDate: start,
          endDate: end,
        );

        expect(data, hasLength(3));
        expect(
          data.every((d) => d.count == 0),
          isTrue,
          reason: 'Bulk-only profile: liveOnly daily chart must be all-zero',
        );
      },
    );

    test('liveOnly counts live completions by date', () async {
      await seedLive(
        firestore,
        sefariaRef: 'ref1',
        completedAt: DateTime.utc(2026, 5, 1, 12),
      );
      await seedLive(
        firestore,
        sefariaRef: 'ref2',
        completedAt: DateTime.utc(2026, 5, 1, 14),
      );
      await seedLive(
        firestore,
        sefariaRef: 'ref3',
        completedAt: DateTime.utc(2026, 5, 3, 10),
      );

      final start = DateTime(2026, 5, 1);
      final end = DateTime(2026, 5, 3);
      final data = await service.dailyCounts(
        tier: CompletionTierFilter.liveOnly,
        startDate: start,
        endDate: end,
      );

      expect(data, hasLength(3));
      expect(data[0].count, 2, reason: 'May 1: 2 live');
      expect(data[1].count, 0, reason: 'May 2: none');
      expect(data[2].count, 1, reason: 'May 3: 1 live');
    });
  });

  // ── cumulativeProgress ─────────────────────────────────────────────────────

  group('cumulativeProgress', () {
    test('liveOnly starts at 0 and accumulates live completions', () async {
      await seedLive(
        firestore,
        sefariaRef: 'ref1',
        completedAt: DateTime.utc(2026, 5, 2, 10),
      );

      final start = DateTime(2026, 5, 1);
      final end = DateTime(2026, 5, 3);
      final data = await service.cumulativeProgress(
        tier: CompletionTierFilter.liveOnly,
        startDate: start,
        endDate: end,
      );

      expect(data, hasLength(3));
      expect(data[0].total, 0, reason: 'May 1: no completions yet');
      expect(data[1].total, 1, reason: 'May 2: +1 live');
      expect(data[2].total, 1, reason: 'May 3: unchanged');
    });

    test('liveOnly excludes bulk completions from cumulative', () async {
      await seedBulkInTrack(firestore, sefariaRef: 'ref_bulk');

      final start = DateTime(2026, 5, 1);
      final end = DateTime(2026, 5, 2);
      final data = await service.cumulativeProgress(
        tier: CompletionTierFilter.liveOnly,
        startDate: start,
        endDate: end,
      );

      expect(
        data.last.total,
        0,
        reason: 'Bulk-only profile: liveOnly cumulative must be 0',
      );
    });
  });
}

/// Unit tests for [TrackProgressService] — Layer 3 architectural unification.
///
/// Covers all three tier filters ([liveOnly], [trackAchievement], [lifetime])
/// plus edge cases (empty profile, only-bulk profile, mixed profile).
@Tags(['tracks', 'track_progress_service'])
library;

import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/tracks/domain/services/track_progress_service.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';

import '../../../../helpers/drift_memory.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _profileId = 1;
const _curriculumId = 'mishnayos';
final _liveAt = DateTime.utc(2026, 5, 1, 12);
final _liveAt2 = DateTime.utc(2026, 5, 2, 12);
final _bulkAt = DateTime.utc(2000, 1, 1); // sentinel

/// Seeds a live completion event (not in prior_completion_imports).
Future<void> seedLive(
  UserDatabase db, {
  required int trackId,
  required String sefariaRef,
  int stageId = 1,
  DateTime? completedAt,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: completedAt ?? _liveAt,
    ),
  );
}

/// Seeds a bulk-in-track completion (completion_events + prior_completion_imports).
Future<void> seedBulkInTrack(
  UserDatabase db, {
  required int trackId,
  required String sefariaRef,
  int stageId = 1,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: _bulkAt,
    ),
  );
  await db.priorCompletionImportDao.batchInsertImports([
    PriorCompletionImportsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: 'personal',
      source: 'bulkInTrack',
    ),
  ]);
}

/// Seeds a lifetime-only completion (completion_events + prior_completion_imports
/// with source = 'lifetimeOnly').
Future<void> seedLifetimeOnly(
  UserDatabase db, {
  required int trackId,
  required String sefariaRef,
  int stageId = 1,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: 'personal',
      trackId: Value(trackId),
      eventTimestamp: _bulkAt,
    ),
  );
  await db.priorCompletionImportDao.batchInsertImports([
    PriorCompletionImportsCompanion.insert(
      profileId: _profileId,
      curriculumId: _curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: 'personal',
      source: 'lifetimeOnly',
    ),
  ]);
}

/// Creates a minimal single-stage [StageDefinitionRepository] backed by [db].
StageDefinitionRepository makeStageRepo(UserDatabase db) =>
    StageDefinitionRepositoryImpl(
      stageDao: db.stageDao,
      completionDao: db.completionDao,
      pushSettings: null,
    );

/// Seeds stage definitions for [trackId] with [stageCount] sequential stages
/// (stageOrders 1..N) using the repository's initializeDefaults then
/// supplementing extra stages if needed.
///
/// Uses direct DB insert with the JSON-encoded schedule column (W3.27).
Future<void> seedStages(
  UserDatabase db, {
  required int trackId,
  int stageCount = 1,
  CurriculumId curriculum = CurriculumId.mishnayos,
}) async {
  for (var i = 1; i <= stageCount; i++) {
    await db
        .into(db.stageDefinitions)
        .insert(
          StageDefinitionsCompanion.insert(
            curriculumId: curriculum.storageKey,
            trackId: trackId,
            profileId: _profileId,
            stageOrder: i,
            stageName: i == 1 ? 'Learn' : 'Chazara $i',
            isDefault: const Value(true),
            // JSON schedule column: {"type":"delay","delay_days":0}
            schedule: const Value('{"type":"delay","delay_days":0}'),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late UserDatabase db;
  late int trackId;
  late TrackProgressService service;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    trackId = await seedTrack(
      db,
      profileId: _profileId,
      curriculumId: _curriculumId,
    );
    service = TrackProgressService(
      dao: db.completionDao,
      stageRepo: makeStageRepo(db),
    );
  });

  tearDown(() => db.close());

  // ── Edge case: empty profile ─────────────────────────────────────────────

  group('completionPercent — empty profile', () {
    test('returns 0.0 when no completions exist (liveOnly)', () async {
      await seedStages(db, trackId: trackId);
      final pct = await service.completionPercent(
        trackId: trackId,
        profileId: _profileId,
        tier: CompletionTierFilter.liveOnly,
        totalItems: 10,
      );
      expect(pct, 0.0);
    });

    test('returns 0.0 when no completions exist (trackAchievement)', () async {
      await seedStages(db, trackId: trackId);
      final pct = await service.completionPercent(
        trackId: trackId,
        profileId: _profileId,
        tier: CompletionTierFilter.trackAchievement,
        totalItems: 10,
      );
      expect(pct, 0.0);
    });

    test('returns 0.0 when no completions exist (lifetime)', () async {
      await seedStages(db, trackId: trackId);
      final pct = await service.completionPercent(
        trackId: trackId,
        profileId: _profileId,
        tier: CompletionTierFilter.lifetime,
        totalItems: 10,
      );
      expect(pct, 0.0);
    });

    test('returns 0.0 when totalItems is 0', () async {
      await seedStages(db, trackId: trackId);
      await seedLive(db, trackId: trackId, sefariaRef: 'ref1');
      final pct = await service.completionPercent(
        trackId: trackId,
        profileId: _profileId,
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
        await seedStages(db, trackId: trackId);
        await seedBulkInTrack(db, trackId: trackId, sefariaRef: 'ref1');
        await seedBulkInTrack(db, trackId: trackId, sefariaRef: 'ref2');

        final pct = await service.completionPercent(
          trackId: trackId,
          profileId: _profileId,
          tier: CompletionTierFilter.liveOnly,
          totalItems: 10,
        );
        expect(pct, 0.0, reason: 'Bulk-only profile: liveOnly tier must be 0');
      },
    );

    test('trackAchievement counts bulkInTrack completions', () async {
      await seedStages(db, trackId: trackId);
      await seedBulkInTrack(db, trackId: trackId, sefariaRef: 'ref1');
      await seedBulkInTrack(db, trackId: trackId, sefariaRef: 'ref2');

      final pct = await service.completionPercent(
        trackId: trackId,
        profileId: _profileId,
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
      await seedStages(db, trackId: trackId);
      await seedBulkInTrack(db, trackId: trackId, sefariaRef: 'ref1');

      final pct = await service.completionPercent(
        trackId: trackId,
        profileId: _profileId,
        tier: CompletionTierFilter.lifetime,
        totalItems: 4,
      );
      expect(pct, closeTo(0.25, 1e-9));
    });

    test(
      'liveOnly returns 0.0 when only lifetimeOnly completions exist',
      () async {
        await seedStages(db, trackId: trackId);
        await seedLifetimeOnly(db, trackId: trackId, sefariaRef: 'ref1');

        final pct = await service.completionPercent(
          trackId: trackId,
          profileId: _profileId,
          tier: CompletionTierFilter.liveOnly,
          totalItems: 10,
        );
        expect(pct, 0.0);
      },
    );

    test('trackAchievement returns 0.0 for lifetimeOnly completions', () async {
      await seedStages(db, trackId: trackId);
      await seedLifetimeOnly(db, trackId: trackId, sefariaRef: 'ref1');

      final pct = await service.completionPercent(
        trackId: trackId,
        profileId: _profileId,
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
      await seedStages(db, trackId: trackId);
      await seedLifetimeOnly(db, trackId: trackId, sefariaRef: 'ref1');

      final pct = await service.completionPercent(
        trackId: trackId,
        profileId: _profileId,
        tier: CompletionTierFilter.lifetime,
        totalItems: 5,
      );
      expect(pct, closeTo(0.2, 1e-9));
    });
  });

  // ── Mixed profile ─────────────────────────────────────────────────────────

  group('completionPercent — mixed profile (live + bulk + lifetime)', () {
    test('tier isolation: liveOnly < trackAchievement <= lifetime', () async {
      await seedStages(db, trackId: trackId);
      await seedLive(db, trackId: trackId, sefariaRef: 'ref_live');
      await seedBulkInTrack(db, trackId: trackId, sefariaRef: 'ref_bulk');
      await seedLifetimeOnly(db, trackId: trackId, sefariaRef: 'ref_lt');

      const totalItems = 10;
      final liveOnlyPct = await service.completionPercent(
        trackId: trackId,
        profileId: _profileId,
        tier: CompletionTierFilter.liveOnly,
        totalItems: totalItems,
      );
      final achievePct = await service.completionPercent(
        trackId: trackId,
        profileId: _profileId,
        tier: CompletionTierFilter.trackAchievement,
        totalItems: totalItems,
      );
      final lifetimePct = await service.completionPercent(
        trackId: trackId,
        profileId: _profileId,
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
      await seedStages(db, trackId: trackId, stageCount: 2);

      // ref1 has stage1 + stage2 (fully done)
      await seedLive(db, trackId: trackId, sefariaRef: 'ref1', stageId: 1);
      await seedLive(
        db,
        trackId: trackId,
        sefariaRef: 'ref1',
        stageId: 2,
        completedAt: _liveAt2,
      );
      // ref2 has only stage1 (partially done — not counted)
      await seedLive(db, trackId: trackId, sefariaRef: 'ref2', stageId: 1);

      final pct = await service.completionPercent(
        trackId: trackId,
        profileId: _profileId,
        tier: CompletionTierFilter.liveOnly,
        totalItems: 10,
      );
      expect(pct, closeTo(0.1, 1e-9), reason: 'Only ref1 is fully done: 1/10');
    });

    test('requireAllStages=false counts any single-ref', () async {
      await seedStages(db, trackId: trackId, stageCount: 2);
      await seedLive(db, trackId: trackId, sefariaRef: 'ref1', stageId: 1);
      await seedLive(db, trackId: trackId, sefariaRef: 'ref2', stageId: 1);

      final pct = await service.completionPercent(
        trackId: trackId,
        profileId: _profileId,
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
      await seedStages(db, trackId: trackId);
      final activatedAt = DateTime.utc(2026, 3, 1);
      await seedLive(
        db,
        trackId: trackId,
        sefariaRef: 'old_ref',
        completedAt: DateTime.utc(2026, 2, 1),
      );
      await seedLive(
        db,
        trackId: trackId,
        sefariaRef: 'new_ref',
        completedAt: DateTime.utc(2026, 4, 1),
      );

      final pct = await service.completionPercent(
        trackId: trackId,
        profileId: _profileId,
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
        await seedBulkInTrack(db, trackId: trackId, sefariaRef: 'ref1');
        final start = DateTime(2026, 5, 1);
        final end = DateTime(2026, 5, 3);

        final data = await service.dailyCounts(
          profileId: _profileId,
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
        db,
        trackId: trackId,
        sefariaRef: 'ref1',
        completedAt: DateTime.utc(2026, 5, 1, 12),
      );
      await seedLive(
        db,
        trackId: trackId,
        sefariaRef: 'ref2',
        completedAt: DateTime.utc(2026, 5, 1, 14),
      );
      await seedLive(
        db,
        trackId: trackId,
        sefariaRef: 'ref3',
        completedAt: DateTime.utc(2026, 5, 3, 10),
      );

      final start = DateTime(2026, 5, 1);
      final end = DateTime(2026, 5, 3);
      final data = await service.dailyCounts(
        profileId: _profileId,
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
        db,
        trackId: trackId,
        sefariaRef: 'ref1',
        completedAt: DateTime.utc(2026, 5, 2, 10),
      );

      final start = DateTime(2026, 5, 1);
      final end = DateTime(2026, 5, 3);
      final data = await service.cumulativeProgress(
        profileId: _profileId,
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
      await seedBulkInTrack(db, trackId: trackId, sefariaRef: 'ref_bulk');

      final start = DateTime(2026, 5, 1);
      final end = DateTime(2026, 5, 2);
      final data = await service.cumulativeProgress(
        profileId: _profileId,
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

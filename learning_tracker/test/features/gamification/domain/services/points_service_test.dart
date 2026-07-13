import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:test/test.dart';

import '../../../../helpers/drift_memory.dart';
import '../../../../helpers/test_database.dart';

// Sentinel date used by bulk-prior / lifetime-only imports.
final _sentinelDate = DateTime.utc(2000, 1, 1);

void main() {
  late UserDatabase db;
  late PointsService service;
  late int trackId;

  setUp(() async {
    db = createTestDatabase();
    await seedProfileZero(db);
    service = PointsService(db);

    final trackRow = await db
        .into(db.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            profileId: 0,
            curriculumId: 'mishnayos',
            stateChangedAt: DateTime.now(),
            activatedAt: DateTime.now(),
          ),
        );
    trackId = trackRow.id;
    final now = DateTime.now();
    await db.goalDao.insertGoal(
      GoalsCompanion.insert(
        profileId: 0,
        curriculumId: 'mishnayos',
        trackId: trackId,
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// Helper to insert a completion with points.
  Future<void> insertCompletion({
    required String curriculumId,
    required String sefariaRef,
    required int stageId,
    required int points,
    String trackType = 'personal',
    DateTime? completedAt,
    int? completionTrackId,
  }) async {
    await seedCompletion(
      db,
      CompletionEventsCompanion.insert(
        profileId: 0,
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        stageId: stageId,
        trackType: trackType,
        trackId: Value(completionTrackId ?? trackId),
        eventTimestamp: completedAt ?? DateTime.now(),
        points: Value(points),
      ),
    );
  }

  group('PointsService', () {
    test(
      'awards correct points when Learn stage is completed (default 10)',
      () async {
        final points = await service.getPointsForStage(
          curriculumId: CurriculumId.mishnayos.storageKey,
          stageOrder: 1,
          trackId: trackId,
        );
        expect(points, 10);
      },
    );

    test('awards different point values for different stages', () async {
      final learn = await service.getPointsForStage(
        curriculumId: CurriculumId.mishnayos.storageKey,
        stageOrder: 1,
        trackId: trackId,
      );
      final chazara1 = await service.getPointsForStage(
        curriculumId: CurriculumId.mishnayos.storageKey,
        stageOrder: 2,
        trackId: trackId,
      );
      final chazara2 = await service.getPointsForStage(
        curriculumId: CurriculumId.mishnayos.storageKey,
        stageOrder: 3,
        trackId: trackId,
      );
      expect(learn, 10);
      expect(chazara1, 5);
      expect(chazara2, 3);
    });

    test(
      'respects custom point values configured per curriculum per stage',
      () async {
        // Seed custom config: Learn=20 for mishnayos
        await db.pointConfigDao.insertConfig(
          PointConfigsCompanion.insert(
            profileId: 0,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackId: trackId,
            stageOrder: 1,
            points: 20,
          ),
        );

        final points = await service.getPointsForStage(
          curriculumId: CurriculumId.mishnayos.storageKey,
          stageOrder: 1,
          trackId: trackId,
        );
        expect(points, 20);

        // Bavli still uses default
        final bavliPoints = await service.getPointsForStage(
          curriculumId: CurriculumId.bavli.storageKey,
          stageOrder: 1,
          trackId: trackId,
        );
        expect(bavliPoints, 10);
      },
    );

    test('per-curriculum total correctly sums all points', () async {
      await insertCompletion(
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: 'Mishnah Berachos 1.1',
        stageId: 1,
        points: 10,
      );
      await insertCompletion(
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: 'Mishnah Berachos 1.2',
        stageId: 1,
        points: 10,
      );

      final total = await service.getCurriculumTotal(
        CurriculumId.mishnayos.storageKey,
      );
      expect(total, 20);
    });

    test(
      'getDerivedTotal correctly sums points across all curricula (derived sum)',
      () async {
        await insertCompletion(
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Mishnah Berachos 1.1',
          stageId: 1,
          points: 10,
        );
        await insertCompletion(
          curriculumId: CurriculumId.bavli.storageKey,
          sefariaRef: 'Berakhot 2a',
          stageId: 1,
          points: 10,
        );

        final total = await service.getDerivedTotal();
        expect(total, 20);
      },
    );

    test(
      'getGlobalTotal reads stored balance (WS7.balance — 0 until credited)',
      () async {
        await insertCompletion(
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Mishnah Berachos 1.1',
          stageId: 1,
          points: 10,
        );

        // Balance is 0 because no creditCompletion was called.
        expect(await service.getGlobalTotal(), 0);

        // After crediting, the balance reflects the credit.
        await db.pointsBalanceDao.creditCompletion(0, 10);
        expect(await service.getGlobalTotal(), 10);
      },
    );

    test('points history log records correct data per event', () async {
      final now = DateTime.utc(2026, 3, 15, 12, 0);
      await insertCompletion(
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: 'Mishnah Berachos 1.1',
        stageId: 1,
        points: 10,
        completedAt: now,
      );

      final history = await service.getPointsHistory();
      expect(history, hasLength(1));
      expect(history.first.curriculumId, CurriculumId.mishnayos.storageKey);
      expect(history.first.stageId, 1);
      expect(history.first.points, 10);
      expect(history.first.sefariaRef, 'Mishnah Berachos 1.1');
      expect(history.first.timestamp.toUtc(), now);
    });

    test('points history filters by curriculum', () async {
      await insertCompletion(
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: 'Mishnah Berachos 1.1',
        stageId: 1,
        points: 10,
      );
      await insertCompletion(
        curriculumId: CurriculumId.bavli.storageKey,
        sefariaRef: 'Berakhot 2a',
        stageId: 1,
        points: 10,
      );

      final history = await service.getPointsHistory(
        curriculumId: CurriculumId.mishnayos.storageKey,
      );
      expect(history, hasLength(1));
      expect(history.first.curriculumId, CurriculumId.mishnayos.storageKey);
    });

    test('curriculum breakdown returns per-curriculum map', () async {
      await insertCompletion(
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: 'Mishnah Berachos 1.1',
        stageId: 1,
        points: 10,
      );
      await insertCompletion(
        curriculumId: CurriculumId.bavli.storageKey,
        sefariaRef: 'Berakhot 2a',
        stageId: 1,
        points: 15,
      );

      final breakdown = await service.getCurriculumBreakdown();
      expect(breakdown[CurriculumId.mishnayos], 10);
      expect(breakdown[CurriculumId.bavli], 15);
      expect(breakdown.containsKey(CurriculumId.chumash), isFalse);
    });

    test(
      'global total excludes browse-only track completions (no goal)',
      () async {
        final browseTrack = await db
            .into(db.curriculumTracks)
            .insertReturning(
              CurriculumTracksCompanion.insert(
                profileId: 0,
                curriculumId: CurriculumId.bavli.storageKey,
                stateChangedAt: DateTime.now(),
                activatedAt: DateTime.now(),
              ),
            );
        await insertCompletion(
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Mishnah Berachos 1.1',
          stageId: 1,
          points: 10,
        );
        await seedCompletion(
          db,
          CompletionEventsCompanion.insert(
            profileId: 0,
            curriculumId: CurriculumId.bavli.storageKey,
            sefariaRef: 'Berakhot 2a',
            stageId: 1,
            trackType: 'personal',
            trackId: Value(browseTrack.id),
            eventTimestamp: DateTime.now(),
            points: const Value(99),
          ),
        );

        expect(await service.getDerivedTotal(), 10);
      },
    );

    test('ensureDefaultConfigs seeds configs only when empty', () async {
      final currId = CurriculumId.mishnayos.storageKey;

      await service.ensureDefaultConfigs(currId, trackId: trackId);
      var configs = await db.pointConfigDao.getConfigsByCurriculum(currId);
      expect(configs, hasLength(3));
      expect(configs[0].points, 10); // Learn
      expect(configs[1].points, 5); // Chazara 1
      expect(configs[2].points, 3); // Chazara 2

      // Calling again doesn't duplicate
      await service.ensureDefaultConfigs(currId, trackId: trackId);
      configs = await db.pointConfigDao.getConfigsByCurriculum(currId);
      expect(configs, hasLength(3));
    });

    // R3-9 regression: getPointsHistory must use liveOnly tier filtering so
    // that bulk-prior completions (sentinel date ~2000-01-01, written with
    // points=0 today but possibly points>0 in future) are NEVER surfaced in
    // the points history log.
    test(
      'R3-9: getPointsHistory excludes bulk-prior (sentinel-date) completions '
      'via liveOnly tier filter',
      () async {
        final liveAt = DateTime.utc(2026, 3, 15, 12, 0);

        // 1. Live completion — points > 0, real timestamp → must appear.
        await seedCompletion(
          db,
          CompletionEventsCompanion.insert(
            profileId: 0,
            curriculumId: CurriculumId.mishnayos.storageKey,
            sefariaRef: 'Mishnah Berachos 1.1',
            stageId: 1,
            trackType: 'personal',
            trackId: Value(trackId),
            eventTimestamp: liveAt,
            points: const Value(10),
          ),
        );

        // 2. Bulk-prior completion — sentinel date, points > 0 to simulate the
        //    future risk scenario where a bulk import carries points. This row
        //    is also recorded in prior_completion_imports (source=lifetimeOnly)
        //    so the liveOnly filter excludes it.
        await seedCompletion(
          db,
          CompletionEventsCompanion.insert(
            profileId: 0,
            curriculumId: CurriculumId.mishnayos.storageKey,
            sefariaRef: 'Mishnah Berachos 1.2',
            stageId: 1,
            trackType: 'personal',
            trackId: Value(trackId),
            eventTimestamp: _sentinelDate,
            points: const Value(
              10,
            ), // non-zero to prove it's the tier that filters it
          ),
        );
        await db.priorCompletionImportDao.batchInsertImports([
          PriorCompletionImportsCompanion.insert(
            profileId: 0,
            curriculumId: CurriculumId.mishnayos.storageKey,
            sefariaRef: 'Mishnah Berachos 1.2',
            stageId: 1,
            trackType: 'personal',
            source: 'lifetimeOnly',
          ),
        ]);

        final history = await service.getPointsHistory();

        // Only the live completion should appear in the history.
        expect(history, hasLength(1));
        expect(history.first.sefariaRef, 'Mishnah Berachos 1.1');
        expect(history.first.points, 10);
        expect(history.first.timestamp.toUtc(), liveAt);
      },
    );

    // R3-9 variant: same exclusion applies when filtering by curriculum.
    test('R3-9: getPointsHistory with curriculumId filter still excludes '
        'bulk-prior completions', () async {
      final liveAt = DateTime.utc(2026, 4, 1, 9, 0);

      await seedCompletion(
        db,
        CompletionEventsCompanion.insert(
          profileId: 0,
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Mishnah Berachos 2.1',
          stageId: 1,
          trackType: 'personal',
          trackId: Value(trackId),
          eventTimestamp: liveAt,
          points: const Value(10),
        ),
      );

      await seedCompletion(
        db,
        CompletionEventsCompanion.insert(
          profileId: 0,
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Mishnah Berachos 2.2',
          stageId: 1,
          trackType: 'personal',
          trackId: Value(trackId),
          eventTimestamp: _sentinelDate,
          points: const Value(10),
        ),
      );
      await db.priorCompletionImportDao.batchInsertImports([
        PriorCompletionImportsCompanion.insert(
          profileId: 0,
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Mishnah Berachos 2.2',
          stageId: 1,
          trackType: 'personal',
          source: 'bulkInTrack',
        ),
      ]);

      final history = await service.getPointsHistory(
        curriculumId: CurriculumId.mishnayos.storageKey,
      );

      expect(history, hasLength(1));
      expect(history.first.sefariaRef, 'Mishnah Berachos 2.1');
    });
  });
}

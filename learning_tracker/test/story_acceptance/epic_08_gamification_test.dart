/// Story acceptance tests for Epic 8 -- Gamification.
@Tags(['epic_8'])
library;

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:test/test.dart';

import '../helpers/test_database.dart';

void main() {
  // ── Story 8.1: Points system ──────────────────────────────────

  group('Story 8.1 -- Points system', tags: ['story_8_1'], () {
    late AppDatabase db;
    late PointsService pointsService;

    setUp(() {
      db = createTestDatabase();
      pointsService = PointsService(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertCompletion({
      required String curriculumId,
      required String sefariaRef,
      required int stageId,
      required int points,
      String trackType = 'personal',
    }) async {
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: stageId,
          trackType: trackType,
          completedAt: DateTime.now(),
          points: Value(points),
        ),
      );
    }

    test('completing a content item awards points', () async {
      await insertCompletion(
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: 'Mishnah Berachos 1.1',
        stageId: 1,
        points: 10,
      );

      final total = await pointsService.getCurriculumTotal(
        CurriculumId.mishnayos.storageKey,
      );
      expect(total, 10);
    });

    test('points vary by stage (later stages worth more)', () async {
      // Default: Learn=10, Chazara1=5, Chazara2=3
      final learn = await pointsService.getPointsForStage(
        curriculumId: CurriculumId.mishnayos.storageKey,
        stageOrder: 1,
      );
      final chazara1 = await pointsService.getPointsForStage(
        curriculumId: CurriculumId.mishnayos.storageKey,
        stageOrder: 2,
      );
      final chazara2 = await pointsService.getPointsForStage(
        curriculumId: CurriculumId.mishnayos.storageKey,
        stageOrder: 3,
      );

      expect(learn, 10);
      expect(chazara1, 5);
      expect(chazara2, 3);
    });

    test('total points aggregated across all curricula', () async {
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
      await insertCompletion(
        curriculumId: CurriculumId.mishnayos.storageKey,
        sefariaRef: 'Mishnah Berachos 1.2',
        stageId: 1,
        points: 10,
      );

      // Per-curriculum
      final mishnayosTotal = await pointsService.getCurriculumTotal(
        CurriculumId.mishnayos.storageKey,
      );
      expect(mishnayosTotal, 20);

      final bavliTotal = await pointsService.getCurriculumTotal(
        CurriculumId.bavli.storageKey,
      );
      expect(bavliTotal, 10);

      // Global
      final globalTotal = await pointsService.getGlobalTotal();
      expect(globalTotal, 30);
    });
  });

  // ── Story 8.2: Rewards & badges ───────────────────────────────

  group(
    'Story 8.2 -- Rewards & badges',
    tags: ['story_8_2'],
    skip: 'Backlog: rewards and badges not yet implemented',
    () {
      test('reward is revealed when point threshold reached', () {});

      test('reward is earned when user claims it', () {});

      test('curriculum-specific rewards filter correctly', () {});
    },
  );

  // ── Story 8.3: Child mode animations ──────────────────────────

  group(
    'Story 8.3 -- Child mode animations',
    tags: ['story_8_3'],
    skip: 'Backlog: child mode animations not yet implemented',
    () {
      test('child mode shows celebratory animation on completion', () {});

      test('adult mode shows subtle confirmation instead', () {});
    },
  );
}

/// Story acceptance tests for Epic 8 -- Gamification.
@Tags(['epic_8'])
library;

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';
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

  // ── Story 8.2: Global Streak Tracking ────────────────────────

  group('Story 8.2 -- Global Streak Tracking', tags: ['story_8_2'], () {
    late AppDatabase db;
    late StreakService streakService;

    setUp(() {
      db = createTestDatabase();
      streakService = StreakService(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('complete items on 3 consecutive days, verify streak=3; '
        'skip a day, complete again, verify streak=1 and max=3', () async {
      final day1 = DateTimeFactory.utc(2026, 3, 10, 12);
      final day2 = DateTimeFactory.utc(2026, 3, 11, 14);
      final day3 = DateTimeFactory.utc(2026, 3, 12, 9);

      await streakService.recordCompletion(day1);
      await streakService.recordCompletion(day2);
      var streak = await streakService.recordCompletion(day3);
      expect(streak.currentStreak, 3);
      expect(streak.maxStreak, 3);

      // Skip day 4 (March 13), complete on day 5
      final day5 = DateTimeFactory.utc(2026, 3, 14, 12);
      streak = await streakService.recordCompletion(day5);
      expect(streak.currentStreak, 1);
      expect(streak.maxStreak, 3);
    });

    test('streak does not double-increment on same day', () async {
      final morning = DateTimeFactory.utc(2026, 3, 10, 8);
      final evening = DateTimeFactory.utc(2026, 3, 10, 20);

      await streakService.recordCompletion(morning);
      final streak = await streakService.recordCompletion(evening);
      expect(streak.currentStreak, 1);
    });

    test('streak calendar returns active dates for range', () async {
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'test',
          sefariaRef: 'Genesis.1',
          stageId: 1,
          trackType: 'primary',
          completedAt: DateTimeFactory.utc(2026, 3, 10, 12),
        ),
      );
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'test',
          sefariaRef: 'Genesis.2',
          stageId: 1,
          trackType: 'primary',
          completedAt: DateTimeFactory.utc(2026, 3, 12, 12),
        ),
      );

      final calendar = await streakService.getStreakCalendar(
        startUtc: DateTimeFactory.utc(2026, 3, 9),
        endUtc: DateTimeFactory.utc(2026, 3, 13),
      );
      expect(calendar.length, 2);
    });
  });

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

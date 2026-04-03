/// Tests for track-scoped DAO methods added in Story 20.2.
@Tags(['epic_20', 'story_20_2'])
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:test/test.dart';

void main() {
  late UserDatabase db;
  late int track1Id;
  late int track2Id;

  setUp(() async {
    db = UserDatabase(NativeDatabase.memory());
    final t1 = await db.into(db.curriculumTracks).insertReturning(
      CurriculumTracksCompanion.insert(
        curriculumId: 'mishnayos',
        trackType: 'personal',
        activatedAt: DateTime.now(),
      ),
    );
    track1Id = t1.id;
    final t2 = await db.into(db.curriculumTracks).insertReturning(
      CurriculumTracksCompanion.insert(
        curriculumId: 'mishnayos',
        trackType: 'school',
        activatedAt: DateTime.now(),
      ),
    );
    track2Id = t2.id;
  });

  tearDown(() => db.close());

  // ── CompletionDao ──

  group('CompletionDao track-scoped', () {
    Future<void> insertCompletion(int trackId, String ref) async {
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'mishnayos',
          sefariaRef: ref,
          stageId: 1,
          trackType: 'personal',
          trackId: trackId,
          completedAt: DateTime.now(),
        ),
      );
    }

    test('getCompletionsByTrack returns only that track', () async {
      await insertCompletion(track1Id, 'ref1');
      await insertCompletion(track1Id, 'ref2');
      await insertCompletion(track1Id, 'ref3');
      await insertCompletion(track2Id, 'ref4');
      await insertCompletion(track2Id, 'ref5');

      final t1 = await db.completionDao.getCompletionsByTrack(track1Id);
      expect(t1, hasLength(3));
      expect(t1.every((c) => c.trackId == track1Id), isTrue);

      final t2 = await db.completionDao.getCompletionsByTrack(track2Id);
      expect(t2, hasLength(2));
    });

    test('getAggregateCountByTrack returns correct count', () async {
      await insertCompletion(track1Id, 'ref1');
      await insertCompletion(track1Id, 'ref2');
      await insertCompletion(track2Id, 'ref3');

      final count = await db.completionDao.getAggregateCountByTrack(track1Id, 0);
      expect(count, 2);
    });

    test('cross-track query still returns all tracks', () async {
      await insertCompletion(track1Id, 'ref1');
      await insertCompletion(track2Id, 'ref2');

      final all = await db.completionDao.getCompletionsByCurriculumAndProfile(
        'mishnayos',
        0,
      );
      expect(all, hasLength(2));
    });
  });

  // ── StageDao ──

  group('StageDao track-scoped', () {
    Future<void> insertStage(int trackId, int order, String name) async {
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          trackId: trackId,
          stageOrder: order,
          stageName: name,
          delayDays: 0,
        ),
      );
    }

    test('getStagesByTrack returns only that track', () async {
      await insertStage(track1Id, 1, 'Learn');
      await insertStage(track1Id, 2, 'Review');
      await insertStage(track2Id, 1, 'Learn2');

      final stages = await db.stageDao.getStagesByTrack(track1Id);
      expect(stages, hasLength(2));
      expect(stages.every((s) => s.trackId == track1Id), isTrue);
    });

    test('deleteStagesForTrack removes only that track', () async {
      await insertStage(track1Id, 1, 'Learn');
      await insertStage(track2Id, 1, 'Learn2');

      await db.stageDao.deleteStagesForTrack(track1Id);

      final t1 = await db.stageDao.getStagesByTrack(track1Id);
      expect(t1, isEmpty);

      final t2 = await db.stageDao.getStagesByTrack(track2Id);
      expect(t2, hasLength(1));
    });

    test('countStagesForTrack returns correct count', () async {
      await insertStage(track1Id, 1, 'Learn');
      await insertStage(track1Id, 2, 'Review');

      final count = await db.stageDao.countStagesForTrack(track1Id);
      expect(count, 2);
    });
  });

  // ── GoalDao ──

  group('GoalDao track-scoped', () {
    test('getGoalByTrack returns only that track goal', () async {
      final now = DateTime.now();
      await db.goalDao.insertGoal(
        GoalsCompanion.insert(
          curriculumId: 'mishnayos',
          trackId: track1Id,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.goalDao.insertGoal(
        GoalsCompanion.insert(
          curriculumId: 'mishnayos',
          trackId: track2Id,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final goal = await db.goalDao.getGoalByTrack(track1Id);
      expect(goal, isNotNull);
      expect(goal!.trackId, track1Id);
    });

    test('deleteGoalsForTrack removes only that track', () async {
      final now = DateTime.now();
      await db.goalDao.insertGoal(
        GoalsCompanion.insert(
          curriculumId: 'mishnayos',
          trackId: track1Id,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.goalDao.insertGoal(
        GoalsCompanion.insert(
          curriculumId: 'mishnayos',
          trackId: track2Id,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await db.goalDao.deleteGoalsForTrack(track1Id);

      final t1 = await db.goalDao.getGoalByTrack(track1Id);
      expect(t1, isNull);

      final t2 = await db.goalDao.getGoalByTrack(track2Id);
      expect(t2, isNotNull);
    });
  });

  // ── StudyDayConfigDao ──

  group('StudyDayConfigDao track-scoped', () {
    test('getConfigsByTrack returns only that track configs', () async {
      await db.studyDayConfigDao.seedDefaults(
        profileId: 0,
        curriculumId: 'mishnayos',
        trackId: track1Id,
      );

      final configs = await db.studyDayConfigDao.getConfigsByTrack(track1Id);
      expect(configs, hasLength(7));
      expect(configs.every((c) => c.trackId == track1Id), isTrue);

      final other = await db.studyDayConfigDao.getConfigsByTrack(track2Id);
      expect(other, isEmpty);
    });

    test('isStudyDayForTrack returns correct value', () async {
      await db.studyDayConfigDao.upsertDayConfig(
        profileId: 0,
        curriculumId: 'mishnayos',
        trackId: track1Id,
        dayOfWeek: 6,
        dayType: 'review',
      );

      final isStudy = await db.studyDayConfigDao.isStudyDayForTrack(
        trackId: track1Id,
        dayOfWeek: 6,
      );
      expect(isStudy, isFalse);

      // Day 1 has no config, defaults to study
      final isStudyDefault = await db.studyDayConfigDao.isStudyDayForTrack(
        trackId: track1Id,
        dayOfWeek: 1,
      );
      expect(isStudyDefault, isTrue);
    });
  });

  // ── CurriculumScopeDao ──

  group('CurriculumScopeDao track-scoped', () {
    test('getScopesByTrack returns only that track scopes', () async {
      // Insert scopes directly to avoid setScopes clearing by curriculum
      final now = DateTime.now().toUtc();
      await db.into(db.curriculumScopes).insert(
        CurriculumScopesCompanion.insert(
          curriculumId: 'mishnayos',
          trackId: track1Id,
          scopeLevel: 1,
          scopeValue: 'Seder Zeraim',
          createdAt: now,
        ),
      );
      await db.into(db.curriculumScopes).insert(
        CurriculumScopesCompanion.insert(
          curriculumId: 'mishnayos',
          trackId: track2Id,
          scopeLevel: 1,
          scopeValue: 'Seder Moed',
          createdAt: now,
        ),
      );
      await db.into(db.curriculumScopes).insert(
        CurriculumScopesCompanion.insert(
          curriculumId: 'mishnayos',
          trackId: track2Id,
          scopeLevel: 1,
          scopeValue: 'Seder Nashim',
          createdAt: now,
        ),
      );

      final t1 = await db.curriculumScopeDao.getScopesByTrack(track1Id);
      expect(t1, hasLength(1));

      final t2 = await db.curriculumScopeDao.getScopesByTrack(track2Id);
      expect(t2, hasLength(2));
    });

    test('hasScopesForTrack returns correct value', () async {
      expect(await db.curriculumScopeDao.hasScopesForTrack(track1Id), isFalse);

      await db.curriculumScopeDao.setScopes(
        0,
        CurriculumId.mishnayos,
        track1Id,
        1,
        ['Seder Zeraim'],
      );

      expect(await db.curriculumScopeDao.hasScopesForTrack(track1Id), isTrue);
    });

    test('clearScopesForTrack removes only that track', () async {
      await db.curriculumScopeDao.setScopes(
        0,
        CurriculumId.mishnayos,
        track1Id,
        1,
        ['Seder Zeraim'],
      );
      await db.curriculumScopeDao.setScopes(
        0,
        CurriculumId.mishnayos,
        track2Id,
        1,
        ['Seder Moed'],
      );

      await db.curriculumScopeDao.clearScopesForTrack(track1Id);

      expect(await db.curriculumScopeDao.hasScopesForTrack(track1Id), isFalse);
      expect(await db.curriculumScopeDao.hasScopesForTrack(track2Id), isTrue);
    });
  });

  // ── PointConfigDao ──

  group('PointConfigDao track-scoped', () {
    test('getConfigsByTrack returns only that track configs', () async {
      await db.pointConfigDao.insertConfig(
        PointConfigsCompanion.insert(
          curriculumId: 'mishnayos',
          trackId: track1Id,
          stageOrder: 1,
          points: 10,
        ),
      );
      await db.pointConfigDao.insertConfig(
        PointConfigsCompanion.insert(
          curriculumId: 'mishnayos',
          trackId: track2Id,
          stageOrder: 1,
          points: 5,
        ),
      );

      final t1 = await db.pointConfigDao.getConfigsByTrack(track1Id);
      expect(t1, hasLength(1));
      expect(t1.first.points, 10);
    });

    test('deleteAllForTrack removes only that track', () async {
      await db.pointConfigDao.insertConfig(
        PointConfigsCompanion.insert(
          curriculumId: 'mishnayos',
          trackId: track1Id,
          stageOrder: 1,
          points: 10,
        ),
      );
      await db.pointConfigDao.insertConfig(
        PointConfigsCompanion.insert(
          curriculumId: 'mishnayos',
          trackId: track2Id,
          stageOrder: 1,
          points: 5,
        ),
      );

      await db.pointConfigDao.deleteAllForTrack(track1Id);

      final t1 = await db.pointConfigDao.getConfigsByTrack(track1Id);
      expect(t1, isEmpty);

      final t2 = await db.pointConfigDao.getConfigsByTrack(track2Id);
      expect(t2, hasLength(1));
    });
  });

  // ── LearningLedgerDao ──

  group('LearningLedgerDao track-scoped', () {
    test('getEntriesByTrack returns only that track entries', () async {
      final now = DateTime.now();
      await db.learningLedgerDao.insertEntry(
        LearningLedgerCompanion.insert(
          curriculumId: 'mishnayos',
          unitType: 'masechta',
          unitIdentifier: 'Berachos',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berachos',
          trackType: 'personal',
          trackId: Value(track1Id),
          completedAt: now,
          completionNumber: 1,
          markedBy: 0,
        ),
      );
      await db.learningLedgerDao.insertEntry(
        LearningLedgerCompanion.insert(
          curriculumId: 'mishnayos',
          unitType: 'masechta',
          unitIdentifier: 'Shabbos',
          unitDisplayNameHe: 'שבת',
          unitDisplayNameEn: 'Shabbos',
          trackType: 'school',
          trackId: Value(track2Id),
          completedAt: now,
          completionNumber: 1,
          markedBy: 0,
        ),
      );

      final t1 = await db.learningLedgerDao.getEntriesByTrack(track1Id, 0);
      expect(t1, hasLength(1));
      expect(t1.first.unitIdentifier, 'Berachos');

      // Cross-track query still returns all
      final all = await db.learningLedgerDao.getEntriesByProfile(0);
      expect(all, hasLength(2));
    });
  });
}

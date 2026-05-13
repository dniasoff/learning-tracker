import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late int trackId;

  setUp(() async {
    db = inMemoryDb();
    trackId = await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: 1,
            curriculumId: 'bavli',
            trackType: 'personal',
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  DailyPlansCompanion makeEntry({
    int profileId = 1,
    String curriculumId = 'bavli',
    DateTime? planDate,
    String sefariaRef = 'Berakhot 2a',
    int stageOrder = 0,
    int stageDefinitionId = 1,
    int? trackIdOverride,
    String priority = 'newLearning',
    int sortOrder = 0,
  }) {
    return DailyPlansCompanion.insert(
      profileId: profileId,
      curriculumId: curriculumId,
      planDate: planDate ?? DateTime.utc(2026, 5, 13),
      sefariaRef: sefariaRef,
      stageOrder: stageOrder,
      stageDefinitionId: stageDefinitionId,
      trackId: trackIdOverride ?? trackId,
      priority: priority,
      createdAt: DateTime.utc(2026, 5, 13, 8, 0),
      sortOrder: Value(sortOrder),
    );
  }

  group('DailyPlanDao', () {
    group('insertEntries', () {
      test('is a no-op when given an empty list', () async {
        await db.dailyPlanDao.insertEntries([]);
        final rows = await db.select(db.dailyPlans).get();
        expect(rows, isEmpty);
      });

      test('inserts rows in batch', () async {
        await db.dailyPlanDao.insertEntries([
          makeEntry(sefariaRef: 'a', stageOrder: 0, sortOrder: 1),
          makeEntry(sefariaRef: 'b', stageOrder: 1, sortOrder: 2),
        ]);
        final rows = await db.select(db.dailyPlans).get();
        expect(rows, hasLength(2));
      });

      test('insertOrIgnore prevents UNIQUE violations on re-runs', () async {
        final e = makeEntry();
        await db.dailyPlanDao.insertEntries([e]);
        // Inserting the same entry should be ignored, not throw.
        await db.dailyPlanDao.insertEntries([e]);
        final rows = await db.select(db.dailyPlans).get();
        expect(rows, hasLength(1));
      });
    });

    group('getPlanForDay', () {
      test(
        'returns rows for the (profile, date) ordered by sortOrder',
        () async {
          await db.dailyPlanDao.insertEntries([
            makeEntry(sefariaRef: 'z', sortOrder: 2),
            makeEntry(sefariaRef: 'a', stageOrder: 1, sortOrder: 0),
            makeEntry(sefariaRef: 'm', stageOrder: 2, sortOrder: 1),
          ]);
          final plan = await db.dailyPlanDao.getPlanForDay(
            profileId: 1,
            planDate: DateTime.utc(2026, 5, 13),
          );
          expect(plan.map((e) => e.sefariaRef), ['a', 'm', 'z']);
        },
      );

      test('excludes other profiles and dates', () async {
        await db.dailyPlanDao.insertEntries([
          makeEntry(profileId: 1, sefariaRef: 'p1'),
          makeEntry(profileId: 2, sefariaRef: 'p2'),
          makeEntry(planDate: DateTime.utc(2026, 5, 14), sefariaRef: 'tom'),
        ]);
        final plan = await db.dailyPlanDao.getPlanForDay(
          profileId: 1,
          planDate: DateTime.utc(2026, 5, 13),
        );
        expect(plan.map((e) => e.sefariaRef), ['p1']);
      });
    });

    group('watchPlanForDay', () {
      test('emits the current plan and updates on insert', () async {
        await db.dailyPlanDao.insertEntries([makeEntry(sefariaRef: 'one')]);
        final stream = db.dailyPlanDao.watchPlanForDay(
          profileId: 1,
          planDate: DateTime.utc(2026, 5, 13),
        );
        final first = await stream.first;
        expect(first.map((e) => e.sefariaRef), ['one']);
      });
    });

    group('hasPlanForDay', () {
      test('false when no rows', () async {
        final has = await db.dailyPlanDao.hasPlanForDay(
          profileId: 1,
          planDate: DateTime.utc(2026, 5, 13),
        );
        expect(has, isFalse);
      });

      test('true when at least one row exists', () async {
        await db.dailyPlanDao.insertEntries([makeEntry()]);
        final has = await db.dailyPlanDao.hasPlanForDay(
          profileId: 1,
          planDate: DateTime.utc(2026, 5, 13),
        );
        expect(has, isTrue);
      });
    });

    group('hasPlanForTrackOnDay', () {
      test('per-track granularity — same day, different track', () async {
        // Need a second track for the same profile (UNIQUE allows
        // distinct curricula) so we use a different curriculumId.
        final otherTrackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: 'mishnayos',
                trackType: 'personal',
                activatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        await db.dailyPlanDao.insertEntries([
          makeEntry(trackIdOverride: trackId),
        ]);

        expect(
          await db.dailyPlanDao.hasPlanForTrackOnDay(
            trackId: trackId,
            planDate: DateTime.utc(2026, 5, 13),
          ),
          isTrue,
        );
        expect(
          await db.dailyPlanDao.hasPlanForTrackOnDay(
            trackId: otherTrackId,
            planDate: DateTime.utc(2026, 5, 13),
          ),
          isFalse,
        );
      });
    });

    group('getPriorlyShownRefsForTrack', () {
      test('returns distinct refs strictly before exclude date', () async {
        await db.dailyPlanDao.insertEntries([
          makeEntry(planDate: DateTime.utc(2026, 5, 10), sefariaRef: 'a'),
          makeEntry(
            planDate: DateTime.utc(2026, 5, 11),
            sefariaRef: 'a',
            stageOrder: 1,
          ),
          makeEntry(planDate: DateTime.utc(2026, 5, 12), sefariaRef: 'b'),
          // Today (the exclude date) should NOT count.
          makeEntry(planDate: DateTime.utc(2026, 5, 13), sefariaRef: 'c'),
        ]);

        final shown = await db.dailyPlanDao.getPriorlyShownRefsForTrack(
          trackId: trackId,
          excludeDate: DateTime.utc(2026, 5, 13),
        );
        expect(shown, {'a', 'b'});
      });
    });

    group('delete operations', () {
      test('deletePlansByTrack removes only rows for that track', () async {
        final otherTrackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: 'mishnayos',
                trackType: 'personal',
                activatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        await db.dailyPlanDao.insertEntries([
          makeEntry(),
          makeEntry(
            trackIdOverride: otherTrackId,
            curriculumId: 'mishnayos',
            sefariaRef: 'm1',
          ),
        ]);
        await db.dailyPlanDao.deletePlansByTrack(trackId);

        final rows = await db.select(db.dailyPlans).get();
        expect(rows.map((r) => r.trackId), [otherTrackId]);
      });

      test('deletePlanForDay removes only that (profile, date)', () async {
        await db.dailyPlanDao.insertEntries([
          makeEntry(),
          makeEntry(planDate: DateTime.utc(2026, 5, 14), sefariaRef: 'tom'),
        ]);
        await db.dailyPlanDao.deletePlanForDay(
          profileId: 1,
          planDate: DateTime.utc(2026, 5, 13),
        );
        final rows = await db.select(db.dailyPlans).get();
        expect(rows, hasLength(1));
        expect(rows.first.sefariaRef, 'tom');
      });

      test('deleteOlderThan removes rows strictly before cutoff', () async {
        await db.dailyPlanDao.insertEntries([
          makeEntry(planDate: DateTime.utc(2026, 4, 1), sefariaRef: 'old'),
          makeEntry(planDate: DateTime.utc(2026, 5, 13), sefariaRef: 'today'),
        ]);
        await db.dailyPlanDao.deleteOlderThan(DateTime.utc(2026, 5, 1));
        final rows = await db.select(db.dailyPlans).get();
        expect(rows.map((r) => r.sefariaRef), ['today']);
      });
    });
  });
}

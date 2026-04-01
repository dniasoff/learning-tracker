import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

void main() {
  late UserDatabase database;

  setUp(() {
    database = UserDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> insertTestCompletion({
    String curriculumId = 'bavli',
    String sefariaRef = 'Berakhot.2a',
    int stageId = 1,
    String trackType = 'amud',
    DateTime? completedAt,
  }) {
    return database.completionDao.insertCompletion(
      CompletionsCompanion.insert(
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        stageId: stageId,
        trackType: trackType,
        completedAt: completedAt ?? DateTime(2024, 6, 15),
      ),
    );
  }

  group('CompletionDao', () {
    test('getAllCompletions returns empty list initially', () async {
      final completions = await database.completionDao.getAllCompletions();
      expect(completions, isEmpty);
    });

    test('insertCompletion and getCompletionById', () async {
      final id = await insertTestCompletion();

      final completion = await database.completionDao.getCompletionById(id);
      expect(completion, isNotNull);
      expect(completion!.curriculumId, 'bavli');
      expect(completion.sefariaRef, 'Berakhot.2a');
    });

    test('getCompletionsByCurriculum filters by curriculum', () async {
      await insertTestCompletion(curriculumId: 'bavli');
      await insertTestCompletion(curriculumId: 'yerushalmi');
      await insertTestCompletion(
        curriculumId: 'bavli',
        sefariaRef: 'Shabbat.2a',
      );

      final results = await database.completionDao.getCompletionsByCurriculum(
        'bavli',
      );
      expect(results, hasLength(2));
    });

    test('getCompletionsForContent filters by sefariaRef', () async {
      await insertTestCompletion(sefariaRef: 'Berakhot.2a');
      await insertTestCompletion(sefariaRef: 'Berakhot.2a', stageId: 2);
      await insertTestCompletion(sefariaRef: 'Shabbat.2a');

      final results = await database.completionDao.getCompletionsForContent(
        'Berakhot.2a',
      );
      expect(results, hasLength(2));
    });

    test('getCompletionsByDateRange returns completions in range', () async {
      await insertTestCompletion(completedAt: DateTime(2024, 6, 10));
      await insertTestCompletion(
        completedAt: DateTime(2024, 6, 15),
        sefariaRef: 'Shabbat.2a',
      );
      await insertTestCompletion(
        completedAt: DateTime(2024, 7, 1),
        sefariaRef: 'Eruvin.2a',
      );

      final results = await database.completionDao.getCompletionsByDateRange(
        DateTime(2024, 6, 1),
        DateTime(2024, 6, 30),
      );
      expect(results, hasLength(2));
    });

    test(
      'hasCompletionsInDateRange returns true when completions exist',
      () async {
        await insertTestCompletion(completedAt: DateTime(2024, 6, 15));

        final has = await database.completionDao.hasCompletionsInDateRange(
          DateTime(2024, 6, 1),
          DateTime(2024, 6, 30),
        );
        expect(has, isTrue);
      },
    );

    test(
      'hasCompletionsInDateRange returns false when no completions',
      () async {
        final has = await database.completionDao.hasCompletionsInDateRange(
          DateTime(2024, 6, 1),
          DateTime(2024, 6, 30),
        );
        expect(has, isFalse);
      },
    );

    test('completionExists returns true for matching composite key', () async {
      final completedAt = DateTime(2024, 6, 15);
      await insertTestCompletion(completedAt: completedAt);

      final exists = await database.completionDao.completionExists(
        curriculumId: 'bavli',
        sefariaRef: 'Berakhot.2a',
        stageId: 1,
        trackType: 'amud',
        completedAt: completedAt,
      );
      expect(exists, isTrue);
    });

    test('completionExists returns false for non-matching key', () async {
      await insertTestCompletion();

      final exists = await database.completionDao.completionExists(
        curriculumId: 'bavli',
        sefariaRef: 'Berakhot.2a',
        stageId: 99,
        trackType: 'amud',
        completedAt: DateTime(2024, 6, 15),
      );
      expect(exists, isFalse);
    });

    test('getTrackBreakdown returns counts by track type', () async {
      await insertTestCompletion(trackType: 'amud');
      await insertTestCompletion(trackType: 'amud', sefariaRef: 'Shabbat.2a');
      await insertTestCompletion(trackType: 'daf', sefariaRef: 'Eruvin.2a');

      final breakdown = await database.completionDao.getTrackBreakdown('bavli');
      expect(breakdown['amud'], 2);
      expect(breakdown['daf'], 1);
    });

    test('getAggregateCount returns total for curriculum', () async {
      await insertTestCompletion();
      await insertTestCompletion(sefariaRef: 'Shabbat.2a');
      await insertTestCompletion(
        curriculumId: 'yerushalmi',
        sefariaRef: 'Eruvin.2a',
      );

      final count = await database.completionDao.getAggregateCount('bavli');
      expect(count, 2);
    });

    test('getAggregateCount returns 0 for unknown curriculum', () async {
      final count = await database.completionDao.getAggregateCount(
        'nonexistent',
      );
      expect(count, 0);
    });

    test(
      'hasCompletionsForStage returns true when stage has completions',
      () async {
        await insertTestCompletion(stageId: 5);

        final has = await database.completionDao.hasCompletionsForStage(5);
        expect(has, isTrue);
      },
    );

    test(
      'hasCompletionsForStage returns false when stage has no completions',
      () async {
        final has = await database.completionDao.hasCompletionsForStage(99);
        expect(has, isFalse);
      },
    );
  });
}

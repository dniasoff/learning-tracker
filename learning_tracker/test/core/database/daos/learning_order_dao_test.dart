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

  group('LearningOrderDao', () {
    test('upsertLearningOrder inserts a new row', () async {
      await database.learningOrderDao.upsertLearningOrder(
        LearningOrderCompanion.insert(
          curriculumId: 'mishnayos',
          sefariaRef: 'Berakhot',
          userSortOrder: 0,
        ),
      );

      final rows = await database.learningOrderDao.getLearningOrderByCurriculum(
        'mishnayos',
      );
      expect(rows, hasLength(1));
      expect(rows.first.sefariaRef, 'Berakhot');
      expect(rows.first.userSortOrder, 0);
    });

    test(
      'upsertLearningOrder updates an existing row on (curriculumId, sefariaRef) conflict',
      () async {
        await database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot',
            userSortOrder: 0,
          ),
        );
        // Upsert with new sort order
        await database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot',
            userSortOrder: 5,
          ),
        );

        final rows = await database.learningOrderDao
            .getLearningOrderByCurriculum('mishnayos');
        expect(rows, hasLength(1));
        expect(rows.first.userSortOrder, 5);
      },
    );

    test(
      'getLearningOrderByCurriculum returns rows ordered by userSortOrder ASC',
      () async {
        await database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            curriculumId: 'mishnayos',
            sefariaRef: 'Shabbat',
            userSortOrder: 2,
          ),
        );
        await database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot',
            userSortOrder: 0,
          ),
        );
        await database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            curriculumId: 'mishnayos',
            sefariaRef: 'Peah',
            userSortOrder: 1,
          ),
        );

        final rows = await database.learningOrderDao
            .getLearningOrderByCurriculum('mishnayos');
        expect(rows.map((r) => r.sefariaRef).toList(), [
          'Berakhot',
          'Peah',
          'Shabbat',
        ]);
      },
    );

    test(
      'deleteAllForCurriculum removes all rows for that curriculum and leaves others untouched',
      () async {
        await database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot',
            userSortOrder: 0,
          ),
        );
        await database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            curriculumId: 'bavli',
            sefariaRef: 'Berakhot',
            userSortOrder: 0,
          ),
        );

        await database.learningOrderDao.deleteAllForCurriculum('mishnayos');

        final mishnayosRows = await database.learningOrderDao
            .getLearningOrderByCurriculum('mishnayos');
        final bavliRows = await database.learningOrderDao
            .getLearningOrderByCurriculum('bavli');

        expect(mishnayosRows, isEmpty);
        expect(bavliRows, hasLength(1));
      },
    );
  });
}

// Extra coverage for LearningOrderDao — getLearningOrderById,
// getAllLearningOrders, updateLearningOrder, deleteLearningOrder, and
// upsertLearningOrderIfNewer were not exercised by the baseline test.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db); // required: learning_order.profileId FK
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

  Future<int> insertRow({
    int profileId = 1,
    String curriculumId = 'bavli',
    String sefariaRef = 'Berakhot',
    int userSortOrder = 0,
    DateTime? updatedAt,
  }) {
    final entry = LearningOrderCompanion.insert(
      profileId: profileId,
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      userSortOrder: userSortOrder,
      updatedAt: updatedAt != null ? Value(updatedAt) : const Value.absent(),
    );
    return db.learningOrderDao.insertLearningOrder(entry);
  }

  // ---------------------------------------------------------------------------
  // getLearningOrderById
  // ---------------------------------------------------------------------------

  group('LearningOrderDao.getLearningOrderById', () {
    test('returns the row for a known id', () async {
      final id = await insertRow(sefariaRef: 'Berakhot');
      final row = await db.learningOrderDao.getLearningOrderById(id);
      expect(row, isNotNull);
      expect(row!.sefariaRef, 'Berakhot');
    });

    test('returns null for an unknown id', () async {
      final row = await db.learningOrderDao.getLearningOrderById(9999);
      expect(row, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // getAllLearningOrders
  // ---------------------------------------------------------------------------

  group('LearningOrderDao.getAllLearningOrders', () {
    test('returns empty list when table is empty', () async {
      final rows = await db.learningOrderDao.getAllLearningOrders();
      expect(rows, isEmpty);
    });

    test('returns all rows across curricula', () async {
      await insertRow(curriculumId: 'bavli', sefariaRef: 'Berakhot');
      await insertRow(curriculumId: 'mishnayos', sefariaRef: 'Peah');

      final rows = await db.learningOrderDao.getAllLearningOrders();
      expect(rows, hasLength(2));
    });
  });

  // ---------------------------------------------------------------------------
  // updateLearningOrder
  // ---------------------------------------------------------------------------

  group('LearningOrderDao.updateLearningOrder', () {
    test('updates an existing row', () async {
      final id = await insertRow(sefariaRef: 'Berakhot', userSortOrder: 0);
      final inserted = await db.learningOrderDao.getLearningOrderById(id);
      expect(inserted, isNotNull);

      final updated = inserted!
          .toCompanion(true)
          .copyWith(userSortOrder: const Value(99));
      final success = await db.learningOrderDao.updateLearningOrder(updated);
      expect(success, isTrue);

      final after = await db.learningOrderDao.getLearningOrderById(id);
      expect(after!.userSortOrder, 99);
    });
  });

  // ---------------------------------------------------------------------------
  // deleteLearningOrder
  // ---------------------------------------------------------------------------

  group('LearningOrderDao.deleteLearningOrder', () {
    test('deletes the row by id', () async {
      final id = await insertRow(sefariaRef: 'Berakhot');
      final deleted = await db.learningOrderDao.deleteLearningOrder(id);
      expect(deleted, 1);

      final row = await db.learningOrderDao.getLearningOrderById(id);
      expect(row, isNull);
    });

    test('returns 0 when id does not exist', () async {
      final deleted = await db.learningOrderDao.deleteLearningOrder(9999);
      expect(deleted, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // upsertLearningOrderIfNewer
  // ---------------------------------------------------------------------------

  group('LearningOrderDao.upsertLearningOrderIfNewer', () {
    test('inserts a row when none exists', () async {
      final now = DateTime.utc(2026, 5, 1);
      final written = await db.learningOrderDao.upsertLearningOrderIfNewer(
        LearningOrderCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          sefariaRef: 'Berakhot',
          userSortOrder: 5,
        ),
        updatedAt: now,
      );
      expect(written, isTrue);

      final rows = await db.learningOrderDao.getLearningOrderByCurriculum(
        'bavli',
        profileId: 1,
      );
      expect(rows, hasLength(1));
      expect(rows.first.userSortOrder, 5);
    });

    test('updates the row when incoming timestamp is newer', () async {
      final t1 = DateTime.utc(2026, 1, 1);
      final t2 = DateTime.utc(2026, 6, 1);

      await db.learningOrderDao.upsertLearningOrderIfNewer(
        LearningOrderCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          sefariaRef: 'Berakhot',
          userSortOrder: 0,
        ),
        updatedAt: t1,
      );

      final written = await db.learningOrderDao.upsertLearningOrderIfNewer(
        LearningOrderCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          sefariaRef: 'Berakhot',
          userSortOrder: 10,
        ),
        updatedAt: t2,
      );
      expect(written, isTrue);

      final rows = await db.learningOrderDao.getLearningOrderByCurriculum(
        'bavli',
        profileId: 1,
      );
      expect(rows.first.userSortOrder, 10);
    });

    test('skips update when incoming timestamp is equal to existing', () async {
      final t = DateTime.utc(2026, 3, 15);

      await db.learningOrderDao.upsertLearningOrderIfNewer(
        LearningOrderCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          sefariaRef: 'Berakhot',
          userSortOrder: 7,
        ),
        updatedAt: t,
      );

      final written = await db.learningOrderDao.upsertLearningOrderIfNewer(
        LearningOrderCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          sefariaRef: 'Berakhot',
          userSortOrder: 99,
        ),
        updatedAt: t, // same timestamp — should skip
      );
      expect(written, isFalse);

      final rows = await db.learningOrderDao.getLearningOrderByCurriculum(
        'bavli',
        profileId: 1,
      );
      expect(rows.first.userSortOrder, 7); // unchanged
    });

    test(
      'skips update when incoming timestamp is older than existing',
      () async {
        final older = DateTime.utc(2025, 12, 1);
        final newer = DateTime.utc(2026, 4, 1);

        // Insert with the newer timestamp first.
        await db.learningOrderDao.upsertLearningOrderIfNewer(
          LearningOrderCompanion.insert(
            profileId: 1,
            curriculumId: 'bavli',
            sefariaRef: 'Berakhot',
            userSortOrder: 3,
          ),
          updatedAt: newer,
        );

        // Attempt to apply an older remote record — should be rejected.
        final written = await db.learningOrderDao.upsertLearningOrderIfNewer(
          LearningOrderCompanion.insert(
            profileId: 1,
            curriculumId: 'bavli',
            sefariaRef: 'Berakhot',
            userSortOrder: 1,
          ),
          updatedAt: older,
        );
        expect(written, isFalse);

        final rows = await db.learningOrderDao.getLearningOrderByCurriculum(
          'bavli',
          profileId: 1,
        );
        expect(rows.first.userSortOrder, 3); // still the newer value
      },
    );
  });

  // ---------------------------------------------------------------------------
  // countByCurriculum
  // ---------------------------------------------------------------------------

  group('LearningOrderDao.countByCurriculum', () {
    test('returns 0 when empty', () async {
      expect(await db.learningOrderDao.countByCurriculum('bavli'), 0);
    });

    test('returns correct count', () async {
      await insertRow(curriculumId: 'bavli', sefariaRef: 'Berakhot');
      await insertRow(
        curriculumId: 'bavli',
        sefariaRef: 'Shabbat',
        userSortOrder: 1,
      );
      await insertRow(curriculumId: 'mishnayos', sefariaRef: 'Peah');

      expect(await db.learningOrderDao.countByCurriculum('bavli'), 2);
      expect(await db.learningOrderDao.countByCurriculum('mishnayos'), 1);
    });
  });
}

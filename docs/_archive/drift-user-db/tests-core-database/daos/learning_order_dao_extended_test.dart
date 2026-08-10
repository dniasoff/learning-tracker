/// Extended tests for LearningOrderDao covering methods not exercised by
/// learning_order_dao_test.dart:
/// - getAllLearningOrders
/// - getLearningOrderById
/// - insertLearningOrder
/// - updateLearningOrder
/// - deleteLearningOrder
/// - deleteAllForCurriculum
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  setUp(() async {
    db = inMemoryDb();
    // W3.25: learning_orders.profileId has a FK to learner_profiles(id).
    await seedProfile(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── helpers ───────────────────────────────────────────────────────────────

  Future<int> insert({
    int profileId = 1,
    String curriculumId = 'mishnayos',
    String sefariaRef = 'Berakhot',
    int sortOrder = 0,
  }) => db.learningOrderDao.insertLearningOrder(
    LearningOrderCompanion.insert(
      profileId: profileId,
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      userSortOrder: sortOrder,
    ),
  );

  // ── getAllLearningOrders ───────────────────────────────────────────────────

  group('LearningOrderDao.getAllLearningOrders', () {
    test('returns empty list initially', () async {
      expect(await db.learningOrderDao.getAllLearningOrders(), isEmpty);
    });

    test('returns all inserted rows across curricula', () async {
      await insert(curriculumId: 'mishnayos', sefariaRef: 'A');
      await insert(curriculumId: 'bavli', sefariaRef: 'B');

      final all = await db.learningOrderDao.getAllLearningOrders();
      expect(all, hasLength(2));
    });
  });

  // ── getLearningOrderById ──────────────────────────────────────────────────

  group('LearningOrderDao.getLearningOrderById', () {
    test('returns the row with the given id', () async {
      final id = await insert(sefariaRef: 'Shabbat');
      final row = await db.learningOrderDao.getLearningOrderById(id);
      expect(row, isNotNull);
      expect(row!.id, id);
      expect(row.sefariaRef, 'Shabbat');
    });

    test('returns null for non-existent id', () async {
      final row = await db.learningOrderDao.getLearningOrderById(9999);
      expect(row, isNull);
    });
  });

  // ── insertLearningOrder ───────────────────────────────────────────────────

  group('LearningOrderDao.insertLearningOrder', () {
    test('inserts a row and returns an id > 0', () async {
      final id = await insert();
      expect(id, greaterThan(0));
    });

    test('multiple inserts return distinct ids', () async {
      final id1 = await insert(sefariaRef: 'A');
      final id2 = await insert(sefariaRef: 'B');
      expect(id1, isNot(id2));
    });
  });

  // ── updateLearningOrder ───────────────────────────────────────────────────

  group('LearningOrderDao.updateLearningOrder', () {
    test('updates the userSortOrder of an existing row', () async {
      final id = await insert(sefariaRef: 'Berakhot', sortOrder: 0);
      final row = await db.learningOrderDao.getLearningOrderById(id);
      expect(row, isNotNull);

      final updated = await db.learningOrderDao.updateLearningOrder(
        LearningOrderCompanion(
          id: Value(id),
          profileId: const Value(1),
          curriculumId: const Value('mishnayos'),
          sefariaRef: const Value('Berakhot'),
          userSortOrder: const Value(99),
        ),
      );
      expect(updated, isTrue);

      final after = await db.learningOrderDao.getLearningOrderById(id);
      expect(after!.userSortOrder, 99);
    });
  });

  // ── deleteLearningOrder ───────────────────────────────────────────────────

  group('LearningOrderDao.deleteLearningOrder', () {
    test('removes the row with the given id', () async {
      final id = await insert(sefariaRef: 'Berakhot');
      await insert(sefariaRef: 'Shabbat');

      final deleted = await db.learningOrderDao.deleteLearningOrder(id);
      expect(deleted, 1);

      final all = await db.learningOrderDao.getAllLearningOrders();
      expect(all, hasLength(1));
      expect(all.first.sefariaRef, 'Shabbat');
    });

    test('returns 0 when id does not exist', () async {
      final deleted = await db.learningOrderDao.deleteLearningOrder(9999);
      expect(deleted, 0);
    });
  });

  // ── deleteAllForCurriculum ────────────────────────────────────────────────

  group('LearningOrderDao.deleteAllForCurriculum', () {
    test('removes all rows for the specified curriculum', () async {
      await insert(curriculumId: 'mishnayos', sefariaRef: 'A');
      await insert(curriculumId: 'mishnayos', sefariaRef: 'B');
      await insert(curriculumId: 'bavli', sefariaRef: 'C');

      final deleted = await db.learningOrderDao.deleteAllForCurriculum(
        'mishnayos',
        profileId: 1,
      );
      expect(deleted, 2);

      final remaining = await db.learningOrderDao.getAllLearningOrders();
      expect(remaining, hasLength(1));
      expect(remaining.first.curriculumId, 'bavli');
    });

    test('returns 0 when no rows for curriculum', () async {
      final deleted = await db.learningOrderDao.deleteAllForCurriculum(
        'no_such_curriculum',
        profileId: 1,
      );
      expect(deleted, 0);
    });
  });
}

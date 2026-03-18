import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/test_dates.dart';

part 'test_date_dao.g.dart';

@DriftAccessor(tables: [TestDates])
class TestDateDao extends DatabaseAccessor<AppDatabase>
    with _$TestDateDaoMixin {
  TestDateDao(super.db);

  Future<List<TestDate>> getAllTestDates() => select(testDates).get();

  Future<List<TestDate>> getTestDatesForProgram(int programId) =>
      (select(testDates)..where((t) => t.programId.equals(programId))).get();

  Future<TestDate?> getNextTestDateForProgram(int programId) =>
      (select(testDates)
            ..where(
              (t) =>
                  t.programId.equals(programId) &
                  t.testDate.isBiggerThanValue(DateTime.now().toUtc()),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.testDate)])
            ..limit(1))
          .getSingleOrNull();

  Future<List<TestDate>> getUpcomingTestDates() => (select(testDates)
        ..where(
          (t) => t.testDate.isBiggerThanValue(DateTime.now().toUtc()),
        )
        ..orderBy([(t) => OrderingTerm.asc(t.testDate)]))
      .get();

  Future<int> insertTestDate(TestDatesCompanion entry) =>
      into(testDates).insert(entry);

  Future<void> insertMultipleTestDates(List<TestDatesCompanion> entries) =>
      batch((b) => b.insertAll(testDates, entries));
}

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/tables/test_dates.dart';

part 'test_date_dao.g.dart';

/// Read-only DAO for test dates in the ContentDatabase.
@DriftAccessor(tables: [TestDates])
class ContentTestDateDao extends DatabaseAccessor<ContentDatabase>
    with _$ContentTestDateDaoMixin {
  ContentTestDateDao(super.db);

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

  Future<List<TestDate>> getUpcomingTestDates() =>
      (select(testDates)
            ..where((t) => t.testDate.isBiggerThanValue(DateTime.now().toUtc()))
            ..orderBy([(t) => OrderingTerm.asc(t.testDate)]))
          .get();
}

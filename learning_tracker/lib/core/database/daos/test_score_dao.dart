import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/test_scores.dart';

part 'test_score_dao.g.dart';

@DriftAccessor(tables: [TestScores])
class TestScoreDao extends DatabaseAccessor<AppDatabase>
    with _$TestScoreDaoMixin {
  TestScoreDao(super.db);

  Future<List<TestScore>> getAllScores() => select(testScores).get();

  Future<List<TestScore>> getScoresByProfile(int profileId) =>
      (select(testScores)..where((t) => t.profileId.equals(profileId))).get();

  Future<List<TestScore>> getScoresByProfileAndProgram(
    int profileId,
    int programId,
  ) =>
      (select(testScores)
            ..where(
              (t) =>
                  t.profileId.equals(profileId) & t.programId.equals(programId),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// Returns the most recent N scores for trend analysis.
  Future<List<TestScore>> getRecentScores(
    int profileId,
    int programId, {
    int limit = 3,
  }) =>
      (select(testScores)
            ..where(
              (t) =>
                  t.profileId.equals(profileId) & t.programId.equals(programId),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .get();

  Future<int> insertScore(TestScoresCompanion entry) =>
      into(testScores).insert(entry);
}

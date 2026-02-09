import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/completions.dart';

part 'completion_dao.g.dart';

/// DAO for the completions table.
///
/// Completions are append-only: only insert operations are exposed.
/// No update or delete methods are provided to enforce immutability.
@DriftAccessor(tables: [Completions])
class CompletionDao extends DatabaseAccessor<AppDatabase>
    with _$CompletionDaoMixin {
  CompletionDao(super.db);

  Future<List<Completion>> getAllCompletions() =>
      select(completions).get();

  Future<Completion?> getCompletionById(int id) =>
      (select(completions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Completion>> getCompletionsByCurriculum(
    String curriculumId,
  ) =>
      (select(completions)..where((t) => t.curriculumId.equals(curriculumId)))
          .get();

  Future<List<Completion>> getCompletionsForContentItem(
    int contentItemId,
  ) =>
      (select(completions)
            ..where((t) => t.contentItemId.equals(contentItemId)))
          .get();

  /// Insert a completion record. This is the only write operation allowed.
  Future<int> insertCompletion(CompletionsCompanion entry) =>
      into(completions).insert(entry);
}

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/tables/learning_programs.dart';

part 'learning_program_dao.g.dart';

/// Read-only DAO for learning programs in the ContentDatabase.
@DriftAccessor(tables: [LearningPrograms])
class ContentLearningProgramDao extends DatabaseAccessor<ContentDatabase>
    with _$ContentLearningProgramDaoMixin {
  ContentLearningProgramDao(super.db);

  Future<List<LearningProgram>> getAllPrograms() =>
      select(learningPrograms).get();

  Future<List<LearningProgram>> getActivePrograms() =>
      (select(learningPrograms)..where((t) => t.isActive.equals(true))).get();

  Future<LearningProgram?> getProgramById(int id) => (select(
    learningPrograms,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<LearningProgram?> getProgramByName(String name) => (select(
    learningPrograms,
  )..where((t) => t.name.equals(name))).getSingleOrNull();

  Future<List<LearningProgram>> getProgramsByCurriculumType(
    String curriculumType,
  ) => (select(
    learningPrograms,
  )..where((t) => t.curriculumType.equals(curriculumType))).get();
}

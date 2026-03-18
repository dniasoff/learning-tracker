import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/learning_programs.dart';

part 'learning_program_dao.g.dart';

@DriftAccessor(tables: [LearningPrograms])
class LearningProgramDao extends DatabaseAccessor<AppDatabase>
    with _$LearningProgramDaoMixin {
  LearningProgramDao(super.db);

  Future<List<LearningProgram>> getAllPrograms() =>
      select(learningPrograms).get();

  Future<List<LearningProgram>> getActivePrograms() =>
      (select(learningPrograms)..where((t) => t.isActive.equals(true))).get();

  Future<LearningProgram?> getProgramById(int id) =>
      (select(learningPrograms)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<LearningProgram?> getProgramByName(String name) =>
      (select(learningPrograms)..where((t) => t.name.equals(name)))
          .getSingleOrNull();

  Future<List<LearningProgram>> getProgramsByCurriculumType(
    String curriculumType,
  ) =>
      (select(learningPrograms)
            ..where((t) => t.curriculumType.equals(curriculumType)))
          .get();

  Future<int> insertProgram(LearningProgramsCompanion entry) =>
      into(learningPrograms).insert(entry);

  Future<void> deprecateProgram(int id) =>
      (update(learningPrograms)..where((t) => t.id.equals(id)))
          .write(const LearningProgramsCompanion(isActive: Value(false)));
}

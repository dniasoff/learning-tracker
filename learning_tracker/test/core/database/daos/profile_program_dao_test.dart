import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:test/test.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  final programRepo = LearningProgramRepository.instance;

  setUp(() {
    db = inMemoryDb();
  });

  tearDown(() async {
    await db.close();
  });

  group('ProfileProgramDao', () {
    test('setProfileProgram creates association', () async {
      final programs = programRepo.getAllPrograms();
      final program = programs.first;

      await db.profileProgramDao.setProfileProgram(
        profileId: 1,
        curriculumType: program.curriculumType,
        programId: program.id,
      );

      final result = await db.profileProgramDao
          .getProgramForProfileAndCurriculum(1, program.curriculumType);
      expect(result, isNotNull);
      expect(result!.programId, program.id);
    });

    test('setProfileProgram upserts on duplicate', () async {
      final programs = programRepo.getProgramsByCurriculumType('bavli');
      expect(programs.length, greaterThanOrEqualTo(2));

      await db.profileProgramDao.setProfileProgram(
        profileId: 1,
        curriculumType: 'bavli',
        programId: programs[0].id,
      );

      // Change to different program
      await db.profileProgramDao.setProfileProgram(
        profileId: 1,
        curriculumType: 'bavli',
        programId: programs[1].id,
      );

      final result = await db.profileProgramDao
          .getProgramForProfileAndCurriculum(1, 'bavli');
      expect(result!.programId, programs[1].id);

      // Only one entry
      final all = await db.profileProgramDao.getProgramsForProfile(1);
      expect(all.length, 1);
    });

    test('getProgramsForProfile returns all for a profile', () async {
      final programs = programRepo.getAllPrograms();
      final bavli = programs.firstWhere((p) => p.curriculumType == 'bavli');
      final nach = programs.firstWhere((p) => p.curriculumType == 'nach');

      await db.profileProgramDao.setProfileProgram(
        profileId: 1,
        curriculumType: 'bavli',
        programId: bavli.id,
      );
      await db.profileProgramDao.setProfileProgram(
        profileId: 1,
        curriculumType: 'nach',
        programId: nach.id,
      );

      final result = await db.profileProgramDao.getProgramsForProfile(1);
      expect(result.length, 2);
    });

    test('different profiles can have different programs', () async {
      final programs = programRepo.getProgramsByCurriculumType('bavli');

      await db.profileProgramDao.setProfileProgram(
        profileId: 1,
        curriculumType: 'bavli',
        programId: programs[0].id,
      );
      await db.profileProgramDao.setProfileProgram(
        profileId: 2,
        curriculumType: 'bavli',
        programId: programs[1].id,
      );

      final p1 = await db.profileProgramDao.getProgramForProfileAndCurriculum(
        1,
        'bavli',
      );
      final p2 = await db.profileProgramDao.getProgramForProfileAndCurriculum(
        2,
        'bavli',
      );
      expect(p1!.programId, programs[0].id);
      expect(p2!.programId, programs[1].id);
    });

    test('deleteForProfile removes all associations', () async {
      final programs = programRepo.getAllPrograms();
      await db.profileProgramDao.setProfileProgram(
        profileId: 1,
        curriculumType: 'bavli',
        programId: programs[0].id,
      );
      await db.profileProgramDao.setProfileProgram(
        profileId: 1,
        curriculumType: 'nach',
        programId: programs.last.id,
      );

      await db.profileProgramDao.deleteForProfile(1);

      final result = await db.profileProgramDao.getProgramsForProfile(1);
      expect(result, isEmpty);
    });
  });
}

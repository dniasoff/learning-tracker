import 'package:learning_tracker/core/database/app_database.dart';
import 'package:test/test.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('LearningProgramDao', () {
    test('getAllPrograms returns seeded programs', () async {
      final programs = await db.learningProgramDao.getAllPrograms();
      expect(programs.length, 9);
    });

    test('getActivePrograms returns only active programs', () async {
      final programs = await db.learningProgramDao.getActivePrograms();
      expect(programs.length, 9); // all seeded programs are active

      // Deprecate one
      await db.learningProgramDao.deprecateProgram(programs.first.id);
      final active = await db.learningProgramDao.getActivePrograms();
      expect(active.length, 8);
    });

    test('getProgramByName finds a specific program', () async {
      final program = await db.learningProgramDao.getProgramByName('oraysa');
      expect(program, isNotNull);
      expect(program!.displayName, 'Oraysa');
      expect(program.curriculumType, 'bavli');
    });

    test('getProgramsByCurriculumType filters correctly', () async {
      final bavliPrograms = await db.learningProgramDao
          .getProgramsByCurriculumType('bavli');
      expect(
        bavliPrograms.length,
        4,
      ); // oraysa, dirshu_kinyan_torah, dirshu_amud_hayomi, daf_yomi

      final nachPrograms = await db.learningProgramDao
          .getProgramsByCurriculumType('nach');
      expect(nachPrograms.length, 1);
      expect(nachPrograms.first.name, 'nach_yomi');
    });

    test('getProgramById returns correct program', () async {
      final all = await db.learningProgramDao.getAllPrograms();
      final first = all.first;
      final found = await db.learningProgramDao.getProgramById(first.id);
      expect(found, isNotNull);
      expect(found!.name, first.name);
    });

    test('deprecateProgram marks program inactive', () async {
      final program = await db.learningProgramDao.getProgramByName('daf_yomi');
      expect(program!.isActive, isTrue);

      await db.learningProgramDao.deprecateProgram(program.id);

      final updated = await db.learningProgramDao.getProgramById(program.id);
      expect(updated!.isActive, isFalse);
    });

    test('all seeded programs have non-empty stagesConfig', () async {
      final programs = await db.learningProgramDao.getAllPrograms();
      for (final p in programs) {
        expect(p.stagesConfig, isNotEmpty);
        expect(p.stagesConfig, startsWith('['));
      }
    });

    test('programs with tests have non-empty testConfig', () async {
      final programs = await db.learningProgramDao.getAllPrograms();
      final withTests = programs.where((p) => p.hasTests).toList();
      expect(withTests, isNotEmpty);
      for (final p in withTests) {
        expect(p.testConfig, isNot('{}'));
      }
    });
  });
}

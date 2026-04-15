import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:test/test.dart';

import '../../../helpers/test_database.dart';

void main() {
  late ContentDatabase db;

  setUp(() {
    db = createTestContentDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('ContentLearningProgramDao', () {
    test('getAllPrograms returns seeded programs', () async {
      final programs = await db.contentLearningProgramDao.getAllPrograms();
      expect(programs.length, 18);
    });

    test('getActivePrograms returns only active programs', () async {
      final programs = await db.contentLearningProgramDao.getActivePrograms();
      expect(programs.length, 18); // all seeded programs are active
    });

    test('getProgramByName finds a specific program', () async {
      final program = await db.contentLearningProgramDao.getProgramByName(
        'oraysa',
      );
      expect(program, isNotNull);
      expect(program!.displayName, 'Oraysa');
      expect(program.curriculumType, 'bavli');
    });

    test('getProgramsByCurriculumType filters correctly', () async {
      final bavliPrograms = await db.contentLearningProgramDao
          .getProgramsByCurriculumType('bavli');
      expect(
        bavliPrograms.length,
        5,
      ); // oraysa, dirshu_kinyan_torah, dirshu_amud_hayomi, daf_yomi, daf_a_week

      final nachPrograms = await db.contentLearningProgramDao
          .getProgramsByCurriculumType('nach');
      expect(nachPrograms.length, 1);
      expect(nachPrograms.first.name, 'nach_yomi');
    });

    test('getProgramById returns correct program', () async {
      final all = await db.contentLearningProgramDao.getAllPrograms();
      final first = all.first;
      final found = await db.contentLearningProgramDao.getProgramById(first.id);
      expect(found, isNotNull);
      expect(found!.name, first.name);
    });

    test('all seeded programs have non-empty stagesConfig', () async {
      final programs = await db.contentLearningProgramDao.getAllPrograms();
      for (final p in programs) {
        expect(p.stagesConfig, isNotEmpty);
        expect(p.stagesConfig, startsWith('['));
      }
    });

    test('programs with tests have non-empty testConfig', () async {
      final programs = await db.contentLearningProgramDao.getAllPrograms();
      final withTests = programs.where((p) => p.hasTests).toList();
      expect(withTests, isNotEmpty);
      for (final p in withTests) {
        expect(p.testConfig, isNot('{}'));
      }
    });
  });
}

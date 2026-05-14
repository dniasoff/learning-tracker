// Tests for LearningProgramRepository — covers getActivePrograms,
// getProgramById, getProgramByName, and getProgramsByCurriculumType.
/// Tests for LearningProgramRepository — pure in-memory class with no
/// external dependencies.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/services/learning_program_service.dart';

void main() {
  // LearningProgramRepository is a singleton; use it directly.
  final repo = LearningProgramRepository.instance;

  group('LearningProgramRepository.getAllPrograms', () {
    test('returns non-empty list', () {
      final programs = repo.getAllPrograms();
      expect(programs, isNotEmpty);
    });

    test('each program has a non-empty name', () {
      for (final p in repo.getAllPrograms()) {
        expect(p.name, isNotEmpty);
      }
    });

    test('all programs have non-empty name and displayName', () {
      for (final p in repo.getAllPrograms()) {
        expect(p.name, isNotEmpty);
        expect(p.displayName, isNotEmpty);
      }
    });

    test('each program has a non-empty curriculumType', () {
      for (final p in repo.getAllPrograms()) {
        expect(p.curriculumType, isNotEmpty);
      }
    });

    test('program ids are sequential starting from 1', () {
      final programs = repo.getAllPrograms();
      for (var i = 0; i < programs.length; i++) {
        expect(programs[i].id, i + 1);
      }
    });
  });

  group('LearningProgramRepository.getActivePrograms', () {
    test('returns only active programs', () {
      final active = repo.getActivePrograms();
      expect(active, isNotEmpty);
      for (final p in active) {
        expect(p.isActive, isTrue);
      }
    });

    test('active programs are a subset of all programs', () {
      final all = repo.getAllPrograms();
      final active = repo.getActivePrograms();
      expect(active.length, lessThanOrEqualTo(all.length));
    });
  });

  group('LearningProgramRepository.getProgramById', () {
    test('returns the first program for id 1', () {
      final program = repo.getProgramById(1);
      expect(program, isNotNull);
      expect(program!.id, 1);
    });

    test('returns null for id 0', () {
      expect(repo.getProgramById(0), isNull);
    });

    test('returns null for id beyond range', () {
      final count = repo.getAllPrograms().length;
      expect(repo.getProgramById(count + 1), isNull);
    });

    test('returns the last program correctly', () {
      final count = repo.getAllPrograms().length;
      final last = repo.getProgramById(count);
      expect(last, isNotNull);
      expect(last!.id, count);
    });
  });

  group('LearningProgramRepository.getProgramByName', () {
    test('returns null for unknown name', () {
      final result = repo.getProgramByName('no_such_program_xyz');
      expect(result, isNull);
    });

    test('returns program for known name', () {
      final allPrograms = repo.getAllPrograms();
      if (allPrograms.isNotEmpty) {
        final first = allPrograms.first;
        final result = repo.getProgramByName(first.name);
        expect(result, isNotNull);
        expect(result!.name, first.name);
      }
    });

    test('returns program matching name "daf_yomi"', () {
      final program = repo.getProgramByName('daf_yomi');
      expect(program, isNotNull);
      expect(program!.name, 'daf_yomi');
    });

    test('returns null for empty string', () {
      expect(repo.getProgramByName(''), isNull);
    });

    test('each program can be found by its own name', () {
      for (final p in repo.getAllPrograms()) {
        final found = repo.getProgramByName(p.name);
        expect(found, isNotNull);
        expect(found!.name, p.name);
      }
    });
  });

  group('LearningProgramRepository.getProgramsByCurriculumType', () {
    test('returns only programs matching the curriculum type', () {
      final programs = repo.getProgramsByCurriculumType('mishnayos');
      for (final p in programs) {
        expect(p.curriculumType, 'mishnayos');
      }
    });

    test('returns empty for unknown curriculum type', () {
      final programs = repo.getProgramsByCurriculumType('no_such_type_xyz');
      expect(programs, isEmpty);
    });

    test('returns programs for curriculum type "bavli"', () {
      final programs = repo.getProgramsByCurriculumType('bavli');
      expect(programs, isNotEmpty);
      expect(programs.every((p) => p.curriculumType == 'bavli'), isTrue);
    });

    test('all programs for a curriculum type have matching curriculumType', () {
      for (final p in repo.getAllPrograms()) {
        final found = repo.getProgramsByCurriculumType(p.curriculumType);
        expect(found.any((q) => q.name == p.name), isTrue);
      }
    });
  });

  group('LearningProgramRepository.getActiveProgramsByCurriculumType', () {
    test('returns only active programs for the curriculum type', () {
      final programs = repo.getActiveProgramsByCurriculumType('mishnayos');
      for (final p in programs) {
        expect(p.curriculumType, 'mishnayos');
        expect(p.isActive, isTrue);
      }
    });

    test('returns only active programs for a curriculum type (bavli)', () {
      final programs = repo.getActiveProgramsByCurriculumType('bavli');
      expect(
        programs.every((p) => p.isActive && p.curriculumType == 'bavli'),
        isTrue,
      );
    });

    test('returns empty list for unknown curriculum type', () {
      final programs = repo.getActiveProgramsByCurriculumType(
        'no_such_curriculum',
      );
      expect(programs, isEmpty);
    });

    test('is a subset of getProgramsByCurriculumType for same type', () {
      const type = 'bavli';
      final all = repo.getProgramsByCurriculumType(type);
      final active = repo.getActiveProgramsByCurriculumType(type);
      expect(active.length, lessThanOrEqualTo(all.length));
    });
  });

  group('LearningProgramData fields', () {
    test('program has stagesConfig that is a non-empty string', () {
      final program = repo.getProgramById(1)!;
      expect(program.stagesConfig, isNotEmpty);
    });

    test('testConfig is never null', () {
      for (final p in repo.getAllPrograms()) {
        expect(p.testConfig, isNotNull);
      }
    });

    test('displayName is non-empty for all programs', () {
      for (final p in repo.getAllPrograms()) {
        expect(p.displayName, isNotEmpty);
      }
    });
  });
}

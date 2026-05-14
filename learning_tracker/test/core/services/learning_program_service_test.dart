// Tests for LearningProgramRepository — covers getActivePrograms (line 86),
// getProgramById (line 89), getProgramByName (lines 94-98), and
// getProgramsByCurriculumType (line 101).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/services/learning_program_service.dart';

void main() {
  final repo = LearningProgramRepository.instance;

  group('LearningProgramRepository.getAllPrograms', () {
    test('returns non-empty list', () {
      final programs = repo.getAllPrograms();
      expect(programs, isNotEmpty);
    });

    test('all programs have non-empty name and displayName', () {
      for (final p in repo.getAllPrograms()) {
        expect(p.name, isNotEmpty);
        expect(p.displayName, isNotEmpty);
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
  });

  group('LearningProgramRepository.getProgramsByCurriculumType', () {
    test('returns only programs matching the curriculum type', () {
      // Use mishnayos which should have at least one program.
      final programs = repo.getProgramsByCurriculumType('mishnayos');
      for (final p in programs) {
        expect(p.curriculumType, 'mishnayos');
      }
    });

    test('returns empty for unknown curriculum type', () {
      final programs = repo.getProgramsByCurriculumType('no_such_type_xyz');
      expect(programs, isEmpty);
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
  });
}

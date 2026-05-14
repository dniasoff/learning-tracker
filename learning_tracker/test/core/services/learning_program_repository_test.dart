/// Tests for [LearningProgramRepository] — pure in-memory service, no DB.
///
/// Covers:
///  - getAllPrograms / getActivePrograms
///  - getProgramById (valid / out-of-range)
///  - getProgramByName (existing / missing)
///  - getProgramsByCurriculumType
///  - getActiveProgramsByCurriculumType
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/services/learning_program_service.dart';

void main() {
  late LearningProgramRepository repo;

  setUp(() {
    repo = LearningProgramRepository.instance;
  });

  group('LearningProgramRepository', () {
    test('getAllPrograms returns non-empty list', () {
      final programs = repo.getAllPrograms();
      expect(programs, isNotEmpty);
    });

    test('programs have sequential ids starting at 1', () {
      final programs = repo.getAllPrograms();
      for (var i = 0; i < programs.length; i++) {
        expect(programs[i].id, i + 1);
      }
    });

    test('getActivePrograms returns only active programs', () {
      final all = repo.getAllPrograms();
      final active = repo.getActivePrograms();
      // All active programs must be present in all programs.
      for (final p in active) {
        expect(p.isActive, isTrue);
        expect(all.any((a) => a.id == p.id), isTrue);
      }
    });

    test('getProgramById returns correct program for valid id', () {
      final programs = repo.getAllPrograms();
      for (final program in programs) {
        final found = repo.getProgramById(program.id);
        expect(found, isNotNull);
        expect(found!.id, program.id);
        expect(found.name, program.name);
      }
    });

    test('getProgramById returns null for id 0', () {
      final result = repo.getProgramById(0);
      expect(result, isNull);
    });

    test('getProgramById returns null for id beyond list size', () {
      final count = repo.getAllPrograms().length;
      final result = repo.getProgramById(count + 100);
      expect(result, isNull);
    });

    test('getProgramByName finds program by exact name', () {
      final first = repo.getAllPrograms().first;
      final found = repo.getProgramByName(first.name);
      expect(found, isNotNull);
      expect(found!.id, first.id);
    });

    test('getProgramByName returns null for unknown name', () {
      final result = repo.getProgramByName('__nonexistent__program__');
      expect(result, isNull);
    });

    test('getProgramsByCurriculumType returns programs matching type', () {
      final all = repo.getAllPrograms();
      // Get a curriculumType that exists.
      final types = all.map((p) => p.curriculumType).toSet();
      for (final type in types) {
        final filtered = repo.getProgramsByCurriculumType(type);
        for (final p in filtered) {
          expect(p.curriculumType, type);
        }
      }
    });

    test('getProgramsByCurriculumType returns empty for unknown type', () {
      final result = repo.getProgramsByCurriculumType('__unknown__');
      expect(result, isEmpty);
    });

    test(
      'getActiveProgramsByCurriculumType returns only active programs of that type',
      () {
        final all = repo.getAllPrograms();
        final types = all.map((p) => p.curriculumType).toSet();
        for (final type in types) {
          final filtered = repo.getActiveProgramsByCurriculumType(type);
          for (final p in filtered) {
            expect(p.curriculumType, type);
            expect(p.isActive, isTrue);
          }
        }
      },
    );

    test(
      'getActiveProgramsByCurriculumType returns empty for unknown type',
      () {
        final result = repo.getActiveProgramsByCurriculumType('__no_such__');
        expect(result, isEmpty);
      },
    );

    test('programs have non-empty name and stagesConfig', () {
      for (final p in repo.getAllPrograms()) {
        expect(p.name, isNotEmpty);
        expect(p.stagesConfig, isNotEmpty);
      }
    });

    test('singleton instance returns same list on repeated calls', () {
      final a = repo.getAllPrograms();
      final b = LearningProgramRepository.instance.getAllPrograms();
      expect(a, same(b));
    });
  });
}

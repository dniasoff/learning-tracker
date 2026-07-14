/// Tests for [LearningProgramRepository] — pure in-memory service, no DB.
///
/// Covers:
///  - getAllPrograms / getActivePrograms
///  - getProgramById (valid / out-of-range / boundary ids)
///  - getProgramByName (existing / missing / empty / fixture literal)
///  - getProgramsByCurriculumType / getActiveProgramsByCurriculumType
///  - LearningProgramData field invariants (name, displayName,
///    curriculumType, stagesConfig, testConfig)
///
/// Merged from the former `test/core/services/learning_program_repository_test.dart`
/// and `test/core/services/learning_program_service_test.dart`
/// (AUD-t-cross-76) — both files independently covered
/// [LearningProgramRepository] at an unmirrored path; this is now the
/// single suite, at the AG-5 mirrored path for
/// `lib/features/scheduler/domain/services/learning_program_service.dart`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';

void main() {
  late LearningProgramRepository repo;

  setUp(() {
    repo = LearningProgramRepository.instance;
  });

  group('getAllPrograms', () {
    test('returns non-empty list', () {
      final programs = repo.getAllPrograms();
      expect(programs, isNotEmpty);
    });

    test('programs have sequential ids starting at 1', () {
      final programs = repo.getAllPrograms();
      for (var i = 0; i < programs.length; i++) {
        expect(programs[i].id, i + 1);
      }
    });

    test('singleton instance returns same list on repeated calls', () {
      final a = repo.getAllPrograms();
      final b = LearningProgramRepository.instance.getAllPrograms();
      expect(a, same(b));
    });
  });

  group('getActivePrograms', () {
    test('returns only active programs, all present in getAllPrograms', () {
      final all = repo.getAllPrograms();
      final active = repo.getActivePrograms();
      expect(active, isNotEmpty);
      for (final p in active) {
        expect(p.isActive, isTrue);
        expect(all.any((a) => a.id == p.id), isTrue);
      }
    });

    test('active programs are a subset of all programs', () {
      final all = repo.getAllPrograms();
      final active = repo.getActivePrograms();
      expect(active.length, lessThanOrEqualTo(all.length));
    });
  });

  group('getProgramById', () {
    test('returns correct program for every valid id', () {
      final programs = repo.getAllPrograms();
      for (final program in programs) {
        final found = repo.getProgramById(program.id);
        expect(found, isNotNull);
        expect(found!.id, program.id);
        expect(found.name, program.name);
      }
    });

    test('returns null for id 0', () {
      expect(repo.getProgramById(0), isNull);
    });

    test('returns null for id beyond list size', () {
      final count = repo.getAllPrograms().length;
      expect(repo.getProgramById(count + 100), isNull);
    });

    test('returns the last program correctly', () {
      final count = repo.getAllPrograms().length;
      final last = repo.getProgramById(count);
      expect(last, isNotNull);
      expect(last!.id, count);
    });
  });

  group('getProgramByName', () {
    test('finds every program by its own exact name', () {
      for (final p in repo.getAllPrograms()) {
        final found = repo.getProgramByName(p.name);
        expect(found, isNotNull);
        expect(found!.id, p.id);
        expect(found.name, p.name);
      }
    });

    test('returns null for unknown name', () {
      expect(repo.getProgramByName('__nonexistent__program__'), isNull);
    });

    test('returns null for empty string', () {
      expect(repo.getProgramByName(''), isNull);
    });

    test('returns program matching name "daf_yomi"', () {
      final program = repo.getProgramByName('daf_yomi');
      expect(program, isNotNull);
      expect(program!.name, 'daf_yomi');
    });
  });

  group('getProgramsByCurriculumType', () {
    test('returns only programs matching the curriculum type', () {
      final all = repo.getAllPrograms();
      final types = all.map((p) => p.curriculumType).toSet();
      for (final type in types) {
        final filtered = repo.getProgramsByCurriculumType(type);
        for (final p in filtered) {
          expect(p.curriculumType, type);
        }
      }
    });

    test('every program is found under its own curriculum type', () {
      for (final p in repo.getAllPrograms()) {
        final found = repo.getProgramsByCurriculumType(p.curriculumType);
        expect(found.any((q) => q.name == p.name), isTrue);
      }
    });

    test('returns empty for unknown type', () {
      expect(repo.getProgramsByCurriculumType('__unknown__'), isEmpty);
    });

    test('returns programs for curriculum type "bavli"', () {
      final programs = repo.getProgramsByCurriculumType('bavli');
      expect(programs, isNotEmpty);
      expect(programs.every((p) => p.curriculumType == 'bavli'), isTrue);
    });
  });

  group('getActiveProgramsByCurriculumType', () {
    test('returns only active programs of that type', () {
      final all = repo.getAllPrograms();
      final types = all.map((p) => p.curriculumType).toSet();
      for (final type in types) {
        final filtered = repo.getActiveProgramsByCurriculumType(type);
        for (final p in filtered) {
          expect(p.curriculumType, type);
          expect(p.isActive, isTrue);
        }
      }
    });

    test('returns only active programs for curriculum type "bavli"', () {
      final programs = repo.getActiveProgramsByCurriculumType('bavli');
      expect(
        programs.every((p) => p.isActive && p.curriculumType == 'bavli'),
        isTrue,
      );
    });

    test('is a subset of getProgramsByCurriculumType for same type', () {
      const type = 'bavli';
      final all = repo.getProgramsByCurriculumType(type);
      final active = repo.getActiveProgramsByCurriculumType(type);
      expect(active.length, lessThanOrEqualTo(all.length));
    });

    test('returns empty for unknown curriculum type', () {
      expect(repo.getActiveProgramsByCurriculumType('__no_such__'), isEmpty);
    });
  });

  group('LearningProgramData field invariants', () {
    test('name, displayName, curriculumType, stagesConfig are non-empty', () {
      for (final p in repo.getAllPrograms()) {
        expect(p.name, isNotEmpty);
        expect(p.displayName, isNotEmpty);
        expect(p.curriculumType, isNotEmpty);
        expect(p.stagesConfig, isNotEmpty);
      }
    });

    test('testConfig is never empty', () {
      // testConfig is a non-nullable String, so isNotNull is a tautology
      // (the type system already guarantees it). isNotEmpty actually
      // exercises the '{}' fallback applied for seeds that omit
      // test_config (learning_program_service.dart:_buildPrograms).
      for (final p in repo.getAllPrograms()) {
        expect(p.testConfig, isNotEmpty);
      }
    });
  });
}

/// Additional tests for [CurriculumLabels] and [LevelLabels] utilities
/// that were not covered by the existing curriculum_label tests.
///
/// Covers:
///  - [LevelLabels.bilingualPlural]
///  - [LevelLabels.bilingualSingular]
///  - [LevelLabels.inLanguage]
///  - [CurriculumLabels.labelsEnPlural]
///  - [CurriculumLabels.labelsHe]
///  - [CurriculumLabels.labelsHePlural]
///  - [CurriculumLabels.container]
///  - [CurriculumLabels.containerSectionHeader]
///  - [CurriculumLabels.valueWithLabel]
///  - [CurriculumLabels.fullPath]
///  - [CurriculumLabels.level] out-of-range error
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

void main() {
  // ─── LevelLabels ──────────────────────────────────────────────────────────

  group('LevelLabels', () {
    late LevelLabels leaf;

    setUp(() {
      leaf = CurriculumLabels.leaf(CurriculumId.mishnayos);
    });

    test('bilingualPlural includes Hebrew plural and English plural separated by bullet', () {
      final bilingual = leaf.bilingualPlural;
      expect(bilingual, contains('•'));
      expect(bilingual, contains(leaf.hePlural));
      expect(bilingual, contains(leaf.enPlural));
    });

    test('bilingualSingular includes Hebrew singular and English singular separated by bullet', () {
      final bilingual = leaf.bilingualSingular;
      expect(bilingual, contains('•'));
      expect(bilingual, contains(leaf.he));
      expect(bilingual, contains(leaf.en));
    });

    test('inLanguage with useHebrew=false plural returns enPlural', () {
      final result = leaf.inLanguage(useHebrew: false, plural: true);
      expect(result, leaf.enPlural);
    });

    test('inLanguage with useHebrew=false singular returns en', () {
      final result = leaf.inLanguage(useHebrew: false, plural: false);
      expect(result, leaf.en);
    });

    test('inLanguage with useHebrew=true plural returns hePlural', () {
      final result = leaf.inLanguage(useHebrew: true, plural: true);
      expect(result, leaf.hePlural);
    });

    test('inLanguage with useHebrew=true singular returns he', () {
      final result = leaf.inLanguage(useHebrew: true, plural: false);
      expect(result, leaf.he);
    });
  });

  // ─── CurriculumLabels.labelsXxx ──────────────────────────────────────────

  group('CurriculumLabels labels collections', () {
    test('labelsEnPlural returns non-empty list for all curricula', () {
      for (final id in CurriculumId.values) {
        final labels = CurriculumLabels.labelsEnPlural(id);
        expect(labels, isNotEmpty, reason: '$id should have labelsEnPlural');
      }
    });

    test('labelsHe returns non-empty list for all curricula', () {
      for (final id in CurriculumId.values) {
        final labels = CurriculumLabels.labelsHe(id);
        expect(labels, isNotEmpty, reason: '$id should have labelsHe');
      }
    });

    test('labelsHePlural returns non-empty list for all curricula', () {
      for (final id in CurriculumId.values) {
        final labels = CurriculumLabels.labelsHePlural(id);
        expect(labels, isNotEmpty, reason: '$id should have labelsHePlural');
      }
    });

    test('labelsEnPlural length matches depth for each curriculum', () {
      for (final id in CurriculumId.values) {
        expect(
          CurriculumLabels.labelsEnPlural(id).length,
          CurriculumLabels.depth(id),
        );
      }
    });
  });

  // ─── CurriculumLabels.container ──────────────────────────────────────────

  group('CurriculumLabels.container', () {
    test('returns non-null for curricula with 2+ hierarchy levels', () {
      for (final id in CurriculumId.values) {
        if (CurriculumLabels.depth(id) >= 2) {
          expect(
            CurriculumLabels.container(id),
            isNotNull,
            reason: '$id has depth >= 2 so container should be non-null',
          );
        }
      }
    });

    test('mishnayos container is the second-from-leaf level (Perek)', () {
      final c = CurriculumLabels.container(CurriculumId.mishnayos);
      expect(c, isNotNull);
      // The container is level depth-1, which is Perek for Mishnayos.
      final levels = CurriculumLabels.levels(CurriculumId.mishnayos);
      expect(c!.en, levels[levels.length - 2].en);
    });
  });

  // ─── CurriculumLabels.containerSectionHeader ─────────────────────────────

  group('CurriculumLabels.containerSectionHeader', () {
    test('returns non-null for curricula with 2+ levels', () {
      for (final id in CurriculumId.values) {
        if (CurriculumLabels.depth(id) >= 2) {
          final header = CurriculumLabels.containerSectionHeader(
            id,
            useHebrew: false,
          );
          expect(header, isNotNull);
          expect(header, isNotEmpty);
        }
      }
    });

    test('returns English label when useHebrew is false', () {
      final header = CurriculumLabels.containerSectionHeader(
        CurriculumId.mishnayos,
        useHebrew: false,
      );
      expect(header, isNotNull);
      // Should be English (no Hebrew characters at the start).
      expect(header!.codeUnitAt(0) < 0x5D0, isTrue);
    });

    test('returns Hebrew label when useHebrew is true', () {
      final header = CurriculumLabels.containerSectionHeader(
        CurriculumId.mishnayos,
        useHebrew: true,
      );
      expect(header, isNotNull);
      // Should start with a Hebrew character (Unicode range 0x5D0-0x5EA).
      final firstChar = header!.codeUnitAt(0);
      expect(firstChar >= 0x5D0 && firstChar <= 0x5EA, isTrue);
    });
  });

  // ─── CurriculumLabels.level error case ───────────────────────────────────

  group('CurriculumLabels.level', () {
    test('throws RangeError for level 0', () {
      expect(
        () => CurriculumLabels.level(CurriculumId.mishnayos, 0),
        throwsA(isA<RangeError>()),
      );
    });

    test('throws RangeError for level exceeding depth', () {
      final depth = CurriculumLabels.depth(CurriculumId.mishnayos);
      expect(
        () => CurriculumLabels.level(CurriculumId.mishnayos, depth + 1),
        throwsA(isA<RangeError>()),
      );
    });

    test('returns correct label for level 1 of all curricula', () {
      for (final id in CurriculumId.values) {
        final l = CurriculumLabels.level(id, 1);
        expect(l.en, isNotEmpty);
      }
    });
  });

  // ─── CurriculumLabels.valueWithLabel ─────────────────────────────────────

  group('CurriculumLabels.valueWithLabel', () {
    test('English format: "Daf 2a" for bavli level 3', () {
      final result = CurriculumLabels.valueWithLabel(
        CurriculumId.bavli,
        3,
        '2a',
        useHebrew: false,
      );
      // Should be "Daf 2a" or similar pattern
      expect(result, contains('2a'));
      expect(result.codeUnitAt(0) < 0x5D0, isTrue); // starts with Latin
    });

    test('Hebrew format contains the value for any curriculum', () {
      final result = CurriculumLabels.valueWithLabel(
        CurriculumId.mishnayos,
        1,
        'ברכות',
        useHebrew: true,
      );
      expect(result, contains('ברכות'));
    });
  });

  // ─── CurriculumLabels.fullPath ────────────────────────────────────────────

  group('CurriculumLabels.fullPath', () {
    test('builds path with default separator for mishnayos', () {
      final path = CurriculumLabels.fullPath(
        CurriculumId.mishnayos,
        ['Zeraim', 'Berakhot', '1'],
        useHebrew: false,
      );
      expect(path, contains('→'));
      expect(path, contains('Zeraim'));
      expect(path, contains('Berakhot'));
      expect(path, contains('1'));
    });

    test('skips null entries in path segments', () {
      final path = CurriculumLabels.fullPath(
        CurriculumId.mishnayos,
        ['Zeraim', null, '3'],
        useHebrew: false,
      );
      // Should contain Zeraim and 3 but skip the null segment.
      expect(path, contains('Zeraim'));
      expect(path, contains('3'));
    });

    test('uses custom separator when provided', () {
      final path = CurriculumLabels.fullPath(
        CurriculumId.bavli,
        ['Zeraim', 'Berakhot'],
        useHebrew: false,
        separator: ' / ',
      );
      expect(path, contains('/'));
    });

    test('returns empty string for all-null segments', () {
      final path = CurriculumLabels.fullPath(
        CurriculumId.mishnayos,
        [null, null],
        useHebrew: false,
      );
      expect(path, isEmpty);
    });

    test('excludes level labels when includeLevelLabel is false', () {
      // Get the level 1 English label for mishnayos
      final l1 = CurriculumLabels.level(CurriculumId.mishnayos, 1);
      final path = CurriculumLabels.fullPath(
        CurriculumId.mishnayos,
        ['Zeraim'],
        useHebrew: false,
        includeLevelLabel: false,
      );
      // Should only contain the value, not the label
      expect(path, 'Zeraim');
      expect(path.contains(l1.en), isFalse);
    });
  });

  // ─── CurriculumLabels.stripStructuralPrefix ───────────────────────────────

  group('CurriculumLabels.stripStructuralPrefix', () {
    test('strips mishneh torah prefix from Hebrew string', () {
      final stripped = CurriculumLabels.stripStructuralPrefix(
        'משנה תורה, הלכות גירושין',
        curriculumId: CurriculumId.mishnehTorah,
      );
      // 'משנה תורה, ' should be stripped.
      expect(stripped.startsWith('משנה תורה'), isFalse);
    });

    test('returns unchanged string when no prefix matches', () {
      const input = 'ברכות';
      final result = CurriculumLabels.stripStructuralPrefix(
        input,
        curriculumId: CurriculumId.mishnayos,
      );
      expect(result, input);
    });
  });

  // ─── CurriculumDefaults ───────────────────────────────────────────────────

  group('CurriculumDefaults', () {
    test('defaultStages has 3 stages', () {
      expect(CurriculumDefaults.defaultStages.length, 3);
    });

    test('first default stage is Learn with 0 delay', () {
      final learn = CurriculumDefaults.defaultStages.first;
      expect(learn.stageOrder, 0);
      expect(learn.delayDays, 0);
    });

    test('defaultPointsPerStage has 3 entries', () {
      expect(CurriculumDefaults.defaultPointsPerStage.length, 3);
      expect(CurriculumDefaults.defaultPointsPerStage[0], 10);
      expect(CurriculumDefaults.defaultPointsPerStage[1], 5);
      expect(CurriculumDefaults.defaultPointsPerStage[2], 3);
    });

    test('defaultDailyTargets covers all 9 curricula', () {
      for (final id in CurriculumId.values) {
        expect(
          CurriculumDefaults.defaultDailyTargets.containsKey(id),
          isTrue,
          reason: '$id should have a default daily target',
        );
      }
    });
  });
}

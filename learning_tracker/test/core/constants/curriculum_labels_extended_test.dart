/// Tests for [CurriculumLabels] formatting/behavior methods and the
/// [LevelLabels] value type they return.
///
/// Partition (AUD-t-cross-11 dedup): this file owns LevelLabels +
/// CurriculumLabels formatting methods (labelsXxx collections, container,
/// containerSectionHeader, level, valueWithLabel, fullPath,
/// stripStructuralPrefix, primaryUnitLabelPlural, containerCountLabelPlural).
/// curriculum_defaults_test.dart owns CurriculumDefaults plus the curriculum
/// hierarchy shape (levels/depth) tests. curriculum_label_variant_test.dart
/// owns transliteration-variant (nusach) behavior — no overlap with this
/// file. Previously this coverage was split near-verbatim across this file
/// and curriculum_defaults_extended_test.dart (now removed); see the finding
/// for the duplicate groups that were merged.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

void main() {
  // ─── LevelLabels ──────────────────────────────────────────────────────────

  group('LevelLabels', () {
    const labels = LevelLabels(
      en: 'Masechta',
      enPlural: 'Masechtos',
      he: 'מסכת',
      hePlural: 'מסכתות',
      valueKind: LevelValueKind.named,
      prefixLabelInDisplay: true,
    );

    test('bilingualPlural returns "hePlural • enPlural"', () {
      expect(labels.bilingualPlural, 'מסכתות • Masechtos');
    });

    test('bilingualSingular returns "he • en"', () {
      expect(labels.bilingualSingular, 'מסכת • Masechta');
    });

    test(
      'inLanguage returns Hebrew singular when useHebrew=true, plural=false',
      () {
        expect(labels.inLanguage(useHebrew: true), 'מסכת');
      },
    );

    test(
      'inLanguage returns Hebrew plural when useHebrew=true, plural=true',
      () {
        expect(labels.inLanguage(useHebrew: true, plural: true), 'מסכתות');
      },
    );

    test('inLanguage returns English singular when useHebrew=false', () {
      expect(labels.inLanguage(useHebrew: false), 'Masechta');
    });

    test(
      'inLanguage returns English plural when useHebrew=false, plural=true',
      () {
        expect(labels.inLanguage(useHebrew: false, plural: true), 'Masechtos');
      },
    );
  });

  // ─── CurriculumLabels.labelsXxx collections ───────────────────────────────

  group('CurriculumLabels labels collections', () {
    test('labelsEnPlural returns non-empty list for all curricula', () {
      for (final id in CurriculumId.values) {
        final lbls = CurriculumLabels.labelsEnPlural(id);
        expect(lbls, isNotEmpty, reason: '$id should have labelsEnPlural');
      }
    });

    test('labelsHe returns non-empty list for all curricula', () {
      for (final id in CurriculumId.values) {
        final lbls = CurriculumLabels.labelsHe(id);
        expect(lbls, isNotEmpty, reason: '$id should have labelsHe');
      }
    });

    test('labelsHePlural returns non-empty list for all curricula', () {
      for (final id in CurriculumId.values) {
        final lbls = CurriculumLabels.labelsHePlural(id);
        expect(lbls, isNotEmpty, reason: '$id should have labelsHePlural');
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

  // ─── CurriculumLabels.level ────────────────────────────────────────────────

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

      // Also confirm the label surfaces for a differently-shaped curriculum
      // (named leaf value rather than numeric) so both value kinds covered.
      final named = CurriculumLabels.valueWithLabel(
        CurriculumId.mishnayos,
        2,
        'Berakhot',
        useHebrew: false,
      );
      expect(named, contains('Berakhot'));
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
      final path = CurriculumLabels.fullPath(CurriculumId.mishnayos, [
        'Zeraim',
        'Berakhot',
        '1',
      ], useHebrew: false);
      expect(path, contains('→'));
      expect(path, contains('Zeraim'));
      expect(path, contains('Berakhot'));
      expect(path, contains('1'));
    });

    test('skips null entries anywhere in the path segments', () {
      // A null in the middle of the segment list is dropped, not rendered
      // as an empty slot.
      final midNull = CurriculumLabels.fullPath(CurriculumId.mishnayos, [
        'Zeraim',
        null,
        '3',
      ], useHebrew: false);
      expect(midNull, contains('Zeraim'));
      expect(midNull, contains('3'));

      // Trailing nulls collapse the path to just the leading real segment.
      final trailingNulls = CurriculumLabels.fullPath(CurriculumId.mishnayos, [
        'Zeraim',
        null,
        null,
        null,
      ], useHebrew: false);
      expect(trailingNulls.split(' → '), hasLength(1));
    });

    test('uses custom separator when provided', () {
      final path = CurriculumLabels.fullPath(
        CurriculumId.bavli,
        ['Zeraim', 'Berakhot'],
        useHebrew: false,
        separator: ' / ',
      );
      expect(path, contains(' / '));
    });

    test('returns empty string for all-null segments', () {
      final path = CurriculumLabels.fullPath(CurriculumId.mishnayos, [
        null,
        null,
      ], useHebrew: false);
      expect(path, isEmpty);
    });

    test('excludes level labels when includeLevelLabel is false', () {
      final l1 = CurriculumLabels.level(CurriculumId.mishnayos, 1);
      final withLabel = CurriculumLabels.fullPath(
        CurriculumId.mishnayos,
        ['Zeraim'],
        useHebrew: false,
        includeLevelLabel: true,
      );
      final withoutLabel = CurriculumLabels.fullPath(
        CurriculumId.mishnayos,
        ['Zeraim'],
        useHebrew: false,
        includeLevelLabel: false,
      );
      // Should only contain the value, not the label.
      expect(withLabel, isNot(equals(withoutLabel)));
      expect(withoutLabel, 'Zeraim');
      expect(withoutLabel.contains(l1.en), isFalse);
    });
  });

  // ─── CurriculumLabels.stripStructuralPrefix ───────────────────────────────

  group('CurriculumLabels.stripStructuralPrefix', () {
    test('strips mishneh torah prefix scoped to CurriculumId.mishnehTorah', () {
      // Without scoping, the legacy global strip would chop off "משנה " (the
      // Mishnayos level label) and leave a leading "תורה, " — the exact bug
      // that produced "תורה, הלכות גירושין" on the Mishneh Torah browse.
      expect(
        CurriculumLabels.stripStructuralPrefix(
          'משנה תורה, הלכות גירושין',
          curriculumId: CurriculumId.mishnehTorah,
        ),
        'גירושין',
      );
      expect(
        CurriculumLabels.stripStructuralPrefix(
          'משנה תורה, הלכות אישות',
          curriculumId: CurriculumId.mishnehTorah,
        ),
        'אישות',
      );
    });

    test('removes known Hebrew prefixes outside Mishneh Torah scope', () {
      expect(CurriculumLabels.stripStructuralPrefix('מסכת ברכות'), 'ברכות');
      expect(CurriculumLabels.stripStructuralPrefix('ספר בראשית'), 'בראשית');
    });

    test('returns unchanged string when no prefix matches', () {
      const input = 'ברכות';
      expect(CurriculumLabels.stripStructuralPrefix(input), input);
    });
  });

  // ─── CurriculumLabels.primaryUnitLabelPlural ──────────────────────────────

  group('CurriculumLabels.primaryUnitLabelPlural', () {
    test('returns non-empty string for all curricula', () {
      for (final id in CurriculumId.values) {
        final label = CurriculumLabels.primaryUnitLabelPlural(id);
        expect(label, isNotEmpty, reason: '${id.name} should have a label');
      }
    });
  });

  // ─── CurriculumLabels.containerCountLabelPlural ───────────────────────────

  group('CurriculumLabels.containerCountLabelPlural', () {
    test('returns non-empty string for all curricula', () {
      for (final id in CurriculumId.values) {
        final label = CurriculumLabels.containerCountLabelPlural(id);
        expect(label, isNotEmpty, reason: '${id.name} should have a label');
      }
    });
  });
}

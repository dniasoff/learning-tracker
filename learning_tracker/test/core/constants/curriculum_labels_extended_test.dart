/// Extended tests for [CurriculumLabels] covering methods not yet tested
/// in curriculum_defaults_test.dart.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

void main() {
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

  group('CurriculumLabels.labelsEnPlural', () {
    test('returns list of English plural labels', () {
      final plurals = CurriculumLabels.labelsEnPlural(CurriculumId.mishnayos);
      expect(plurals, isNotEmpty);
      expect(plurals, isA<List<String>>());
    });
  });

  group('CurriculumLabels.labelsHe', () {
    test('returns list of Hebrew singular labels', () {
      final heLabels = CurriculumLabels.labelsHe(CurriculumId.mishnayos);
      expect(heLabels, isNotEmpty);
      // Hebrew labels should be non-empty strings
      expect(heLabels.every((l) => l.isNotEmpty), isTrue);
    });
  });

  group('CurriculumLabels.labelsHePlural', () {
    test('returns list of Hebrew plural labels', () {
      final hePlurals = CurriculumLabels.labelsHePlural(CurriculumId.mishnayos);
      expect(hePlurals, isNotEmpty);
    });
  });

  group('CurriculumLabels.container', () {
    test('returns non-null for Mishnayos (4-level curriculum)', () {
      final cont = CurriculumLabels.container(CurriculumId.mishnayos);
      expect(cont, isNotNull);
    });

    test('container for Bavli (3-level) is non-null', () {
      final cont = CurriculumLabels.container(CurriculumId.bavli);
      expect(cont, isNotNull);
    });
  });

  group('CurriculumLabels.level — RangeError', () {
    test('throws RangeError when level is out of range', () {
      expect(
        () => CurriculumLabels.level(CurriculumId.mishnayos, 99),
        throwsA(isA<RangeError>()),
      );
    });

    test('throws RangeError for level 0', () {
      expect(
        () => CurriculumLabels.level(CurriculumId.mishnayos, 0),
        throwsA(isA<RangeError>()),
      );
    });
  });

  group('CurriculumLabels.containerSectionHeader', () {
    test('returns non-null for multi-level curriculum', () {
      final header = CurriculumLabels.containerSectionHeader(
        CurriculumId.mishnayos,
        useHebrew: false,
      );
      expect(header, isNotNull);
      expect(header, isNotEmpty);
    });

    test('returns Hebrew form when useHebrew=true', () {
      final header = CurriculumLabels.containerSectionHeader(
        CurriculumId.mishnayos,
        useHebrew: true,
      );
      expect(header, isNotNull);
      // Should be different from the English form
      final headerEn = CurriculumLabels.containerSectionHeader(
        CurriculumId.mishnayos,
        useHebrew: false,
      );
      expect(header, isNot(equals(headerEn)));
    });
  });

  group('CurriculumLabels.valueWithLabel', () {
    test('formats with English label when useHebrew=false', () {
      final result = CurriculumLabels.valueWithLabel(
        CurriculumId.mishnayos,
        2,
        'Berakhot',
        useHebrew: false,
      );
      // Should be "Masechta Berakhot" or similar
      expect(result, contains('Berakhot'));
    });

    test('formats with Hebrew label when useHebrew=true', () {
      final result = CurriculumLabels.valueWithLabel(
        CurriculumId.mishnayos,
        2,
        'ברכות',
        useHebrew: true,
      );
      expect(result, contains('ברכות'));
    });
  });

  group('CurriculumLabels.fullPath', () {
    test('builds full path with labels in English', () {
      final path = CurriculumLabels.fullPath(CurriculumId.mishnayos, [
        'Zeraim',
        'Berakhot',
        null,
        null,
      ], useHebrew: false);
      expect(path, contains('Zeraim'));
      expect(path, contains('Berakhot'));
      expect(path, contains(' → '));
    });

    test('skips null segments', () {
      final path = CurriculumLabels.fullPath(CurriculumId.mishnayos, [
        'Zeraim',
        null,
        null,
        null,
      ], useHebrew: false);
      expect(path.split(' → '), hasLength(1));
    });

    test('uses custom separator', () {
      final path = CurriculumLabels.fullPath(
        CurriculumId.mishnayos,
        ['Zeraim', 'Berakhot'],
        useHebrew: false,
        separator: ' / ',
      );
      expect(path, contains(' / '));
    });

    test('excludes level labels when includeLevelLabel=false', () {
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
      expect(withLabel, isNot(equals(withoutLabel)));
      expect(withoutLabel, equals('Zeraim'));
    });
  });

  group('CurriculumLabels.primaryUnitLabelPlural', () {
    test('returns non-empty string for all curricula', () {
      for (final id in CurriculumId.values) {
        final label = CurriculumLabels.primaryUnitLabelPlural(id);
        expect(label, isNotEmpty, reason: '${id.name} should have a label');
      }
    });
  });

  group('CurriculumLabels.containerCountLabelPlural', () {
    test('returns non-empty string for all curricula', () {
      for (final id in CurriculumId.values) {
        final label = CurriculumLabels.containerCountLabelPlural(id);
        expect(label, isNotEmpty, reason: '${id.name} should have a label');
      }
    });
  });
}

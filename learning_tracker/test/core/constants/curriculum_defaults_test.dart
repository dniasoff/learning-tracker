import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

void main() {
  group('CurriculumDefaults - default stage definitions', () {
    test('has exactly 3 default stages', () {
      expect(CurriculumDefaults.defaultStages.length, 3);
    });

    test('stage 0 is learn with 0 delay days', () {
      final learn = CurriculumDefaults.defaultStages[0];
      expect(learn.stageOrder, 0);
      expect(learn.stageName, 'learn');
      expect(learn.delayDays, 0);
    });

    test('stage 1 is chazara1 with 1 delay day', () {
      final chazara1 = CurriculumDefaults.defaultStages[1];
      expect(chazara1.stageOrder, 1);
      expect(chazara1.stageName, 'chazara1');
      expect(chazara1.delayDays, 1);
    });

    test('stage 2 is chazara2 with 7 delay days', () {
      final chazara2 = CurriculumDefaults.defaultStages[2];
      expect(chazara2.stageOrder, 2);
      expect(chazara2.stageName, 'chazara2');
      expect(chazara2.delayDays, 7);
    });

    test('stage orders are sequential starting from 0', () {
      for (var i = 0; i < CurriculumDefaults.defaultStages.length; i++) {
        expect(CurriculumDefaults.defaultStages[i].stageOrder, i);
      }
    });
  });

  group('CurriculumDefaults - hierarchy configs', () {
    test('hierarchy configs exist for all 5 curricula', () {
      for (final curriculum in CurriculumId.values) {
        expect(
          CurriculumDefaults.hierarchyConfigs.containsKey(curriculum),
          isTrue,
          reason: 'Missing hierarchy config for ${curriculum.storageKey}',
        );
      }
    });

    test('Mishnayos has 4-level hierarchy', () {
      final config =
          CurriculumDefaults.hierarchyConfigs[CurriculumId.mishnayos]!;
      expect(config.maxLevels, 4);
      expect(config.level1Label, 'Seder');
      expect(config.level2Label, 'Masechta');
      expect(config.level3Label, 'Perek');
      expect(config.level4Label, 'Mishna');
    });

    test('Bavli has 3-level hierarchy', () {
      final config = CurriculumDefaults.hierarchyConfigs[CurriculumId.bavli]!;
      expect(config.maxLevels, 3);
      expect(config.level1Label, 'Masechta');
      expect(config.level2Label, 'Daf');
      expect(config.level3Label, 'Amud');
    });

    test('Yerushalmi has 3-level hierarchy', () {
      final config =
          CurriculumDefaults.hierarchyConfigs[CurriculumId.yerushalmi]!;
      expect(config.maxLevels, 3);
      expect(config.level1Label, 'Masechta');
      expect(config.level2Label, 'Daf');
      expect(config.level3Label, 'Halacha');
    });

    test('Mishna Berurah has 3-level hierarchy', () {
      final config =
          CurriculumDefaults.hierarchyConfigs[CurriculumId.mishnaBerurah]!;
      expect(config.maxLevels, 3);
      expect(config.level1Label, 'Siman');
      expect(config.level2Label, 'Seif');
      expect(config.level3Label, 'Seif Katan');
    });

    test('Chumash has 4-level hierarchy', () {
      final config = CurriculumDefaults.hierarchyConfigs[CurriculumId.chumash]!;
      expect(config.maxLevels, 4);
      expect(config.level1Label, 'Sefer');
      expect(config.level2Label, 'Parsha');
      expect(config.level3Label, 'Perek');
      expect(config.level4Label, 'Pasuk');
    });

    test('Nach has 3-level hierarchy', () {
      final config = CurriculumDefaults.hierarchyConfigs[CurriculumId.nach]!;
      expect(config.maxLevels, 3);
      expect(config.level1Label, 'Sefer');
      expect(config.level2Label, 'Perek');
      expect(config.level3Label, 'Pasuk');
    });

    test('Mussar has 2-level hierarchy', () {
      final config = CurriculumDefaults.hierarchyConfigs[CurriculumId.mussar]!;
      expect(config.maxLevels, 2);
      expect(config.level1Label, 'Sefer');
      expect(config.level2Label, 'Section');
    });
  });

  group('CurriculumDefaults - daily targets', () {
    test('daily targets exist for all 5 curricula', () {
      for (final curriculum in CurriculumId.values) {
        expect(
          CurriculumDefaults.defaultDailyTargets.containsKey(curriculum),
          isTrue,
          reason: 'Missing daily target for ${curriculum.storageKey}',
        );
      }
    });

    test('all daily targets are positive', () {
      for (final entry in CurriculumDefaults.defaultDailyTargets.entries) {
        expect(
          entry.value,
          greaterThan(0),
          reason: '${entry.key.storageKey} should have positive daily target',
        );
      }
    });
  });
}

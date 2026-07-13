/// Tests for [CurriculumDefaults] and the curriculum hierarchy shape
/// (levels/depth) exposed via [CurriculumLabels].
///
/// Partition (AUD-t-cross-11 dedup): this file owns CurriculumDefaults plus
/// hierarchy-shape tests. curriculum_labels_extended_test.dart owns
/// LevelLabels + CurriculumLabels formatting methods (container,
/// containerSectionHeader, level, valueWithLabel, fullPath,
/// stripStructuralPrefix, etc). curriculum_label_variant_test.dart owns
/// transliteration-variant (nusach) behavior — no overlap with this file.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

void main() {
  group('CurriculumDefaults - default stage definitions', () {
    test('has exactly 3 default stages', () {
      expect(CurriculumDefaults.defaultStages.length, 3);
    });

    test('stage 0 is לימוד with 0 delay days', () {
      final learn = CurriculumDefaults.defaultStages[0];
      expect(learn.stageOrder, 0);
      expect(learn.stageName, 'לימוד');
      expect(learn.delayDays, 0);
    });

    test('stage 1 is חזרה א׳ with 1 delay day', () {
      final chazara1 = CurriculumDefaults.defaultStages[1];
      expect(chazara1.stageOrder, 1);
      expect(chazara1.stageName, 'חזרה א׳');
      expect(chazara1.delayDays, 1);
    });

    test('stage 2 is חזרה ב׳ with 7 delay days', () {
      final chazara2 = CurriculumDefaults.defaultStages[2];
      expect(chazara2.stageOrder, 2);
      expect(chazara2.stageName, 'חזרה ב׳');
      expect(chazara2.delayDays, 7);
    });

    test('stage orders are sequential starting from 0', () {
      for (var i = 0; i < CurriculumDefaults.defaultStages.length; i++) {
        expect(CurriculumDefaults.defaultStages[i].stageOrder, i);
      }
    });

    test('defaultPointsPerStage has 3 entries matching stage order', () {
      expect(CurriculumDefaults.defaultPointsPerStage.length, 3);
      expect(CurriculumDefaults.defaultPointsPerStage[0], 10);
      expect(CurriculumDefaults.defaultPointsPerStage[1], 5);
      expect(CurriculumDefaults.defaultPointsPerStage[2], 3);
    });
  });

  group('CurriculumLabels - hierarchy labels', () {
    test('labels exist for all curricula', () {
      for (final curriculum in CurriculumId.values) {
        expect(
          () => CurriculumLabels.levels(curriculum),
          returnsNormally,
          reason: 'Missing label set for ${curriculum.storageKey}',
        );
        expect(CurriculumLabels.levels(curriculum), isNotEmpty);
      }
    });

    test('Mishnayos has 4-level hierarchy', () {
      expect(CurriculumLabels.depth(CurriculumId.mishnayos), 4);
      expect(CurriculumLabels.labelsEn(CurriculumId.mishnayos), [
        'Seder',
        'Masechta',
        'Perek',
        'Mishna',
      ]);
    });

    test('Bavli has 4-level hierarchy', () {
      expect(CurriculumLabels.depth(CurriculumId.bavli), 4);
      expect(CurriculumLabels.labelsEn(CurriculumId.bavli), [
        'Seder',
        'Masechta',
        'Daf',
        'Amud',
      ]);
    });

    test('Yerushalmi has 3-level hierarchy (Seder/Masechta/Daf)', () {
      expect(CurriculumLabels.depth(CurriculumId.yerushalmi), 3);
      expect(CurriculumLabels.labelsEn(CurriculumId.yerushalmi), [
        'Seder',
        'Masechta',
        'Daf',
      ]);
    });

    test('Mishna Berurah has 3-level hierarchy (Sefer/Siman/Seif)', () {
      expect(CurriculumLabels.depth(CurriculumId.mishnaBerurah), 3);
      expect(CurriculumLabels.labelsEn(CurriculumId.mishnaBerurah), [
        'Sefer',
        'Siman',
        'Seif',
      ]);
    });

    test('Chumash has 3-level hierarchy (no Parsha level in data)', () {
      expect(CurriculumLabels.depth(CurriculumId.chumash), 3);
      expect(CurriculumLabels.labelsEn(CurriculumId.chumash), [
        'Sefer',
        'Perek',
        'Pasuk',
      ]);
    });

    test('Nach has 4-level hierarchy', () {
      expect(CurriculumLabels.depth(CurriculumId.nach), 4);
      expect(CurriculumLabels.labelsEn(CurriculumId.nach), [
        'Section',
        'Sefer',
        'Perek',
        'Pasuk',
      ]);
    });

    test(
      'Mussar has 4-level hierarchy (Sefer/Perek/Pasuk/Pasuk) — Tanya uses 4 levels',
      () {
        expect(CurriculumLabels.depth(CurriculumId.mussar), 4);
        // L3 + L4 are both Pasuk by default; 3-level books (Mesillat
        // Yesharim, Orchot Tzadikim, Tomer Devorah, Shaarei Teshuvah)
        // simply don't use L4. Tanya uses the Part override at L2 and
        // Perek override at L3.
        expect(CurriculumLabels.labelsEn(CurriculumId.mussar), [
          'Sefer',
          'Perek',
          'Pasuk',
          'Pasuk',
        ]);
      },
    );

    test('Mussar per-book L2 override: Shaarei Teshuvah uses Shaar', () {
      final l2 = CurriculumLabels.level(
        CurriculumId.mussar,
        2,
        parentL1Value: 'Shaarei Teshuvah',
      );
      expect(l2.en, 'Shaar');
      expect(l2.he, 'שער');
    });

    test('Mussar per-book L2 override: Tanya uses Part', () {
      final l2 = CurriculumLabels.level(
        CurriculumId.mussar,
        2,
        parentL1Value: 'Tanya',
      );
      expect(l2.en, 'Part');
      expect(l2.valueKind, LevelValueKind.named);
    });

    test('Mussar L2 default (no parentL1Value) is Perek', () {
      final l2 = CurriculumLabels.level(CurriculumId.mussar, 2);
      expect(l2.en, 'Perek');
    });

    test('every level has Hebrew + plural variants', () {
      for (final curriculum in CurriculumId.values) {
        for (final label in CurriculumLabels.levels(curriculum)) {
          expect(label.en, isNotEmpty);
          expect(label.enPlural, isNotEmpty);
          expect(label.he, isNotEmpty);
          expect(label.hePlural, isNotEmpty);
        }
      }
    });

    test('topSectionHeader switches script with useHebrew flag', () {
      expect(
        CurriculumLabels.topSectionHeader(CurriculumId.bavli, useHebrew: true),
        'סדרים',
      );
      expect(
        CurriculumLabels.topSectionHeader(CurriculumId.bavli, useHebrew: false),
        'Sedarim',
      );
      expect(
        CurriculumLabels.topSectionHeader(
          CurriculumId.chumash,
          useHebrew: true,
        ),
        'חומשים',
      );
    });

    // stripStructuralPrefix is a CurriculumLabels formatting method, not a
    // hierarchy-shape one — its coverage lives in
    // curriculum_labels_extended_test.dart (AUD-t-cross-11 partition).

    test('hasReorderableLevel2 hides chapter list for chumash/tanach', () {
      expect(
        CurriculumLabels.hasReorderableLevel2(CurriculumId.chumash),
        isFalse,
      );
      expect(
        CurriculumLabels.hasReorderableLevel2(CurriculumId.tanach),
        isFalse,
      );
      expect(CurriculumLabels.hasReorderableLevel2(CurriculumId.bavli), isTrue);
    });
  });

  group('CurriculumDefaults - daily targets', () {
    test('daily targets exist for all curricula', () {
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

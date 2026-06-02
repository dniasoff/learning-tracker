import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';

void main() {
  group('LevelLabels.inLanguage - nusach variant', () {
    test('Mishnayos leaf plural: ashkenazi vs sephardi vs hebrew', () {
      final mishna = CurriculumLabels.leaf(CurriculumId.mishnayos);
      expect(mishna.inLanguage(useHebrew: false, plural: true), 'Mishnayos');
      expect(
        mishna.inLanguage(
          useHebrew: false,
          plural: true,
          variant: TransliterationVariant.sephardi,
        ),
        'Mishnayot',
      );
      expect(mishna.inLanguage(useHebrew: true, plural: true), 'משניות');
    });

    test('Masechta singular + plural sephardi', () {
      final masechta = CurriculumLabels.level(CurriculumId.bavli, 2);
      expect(
        masechta.inLanguage(
          useHebrew: false,
          variant: TransliterationVariant.sephardi,
        ),
        'Masekhet',
      );
      expect(
        masechta.inLanguage(
          useHebrew: false,
          plural: true,
          variant: TransliterationVariant.sephardi,
        ),
        'Masekhtot',
      );
      // Ashkenazi default unchanged.
      expect(masechta.inLanguage(useHebrew: false, plural: true), 'Masechtos');
    });

    test('Dafim sephardi → Dapim, ashkenazi → Dafim, hebrew → דפים', () {
      final daf = CurriculumLabels.level(CurriculumId.bavli, 3);
      expect(daf.inLanguage(useHebrew: false, plural: true), 'Dafim');
      expect(
        daf.inLanguage(
          useHebrew: false,
          plural: true,
          variant: TransliterationVariant.sephardi,
        ),
        'Dapim',
      );
      expect(daf.inLanguage(useHebrew: true, plural: true), 'דפים');
    });

    test(
      'Halacha/Halachos sephardi → Halakha/Halakhot (Mishneh Torah leaf)',
      () {
        final halacha = CurriculumLabels.leaf(CurriculumId.mishnehTorah);
        expect(halacha.inLanguage(useHebrew: false), 'Halacha');
        expect(
          halacha.inLanguage(
            useHebrew: false,
            variant: TransliterationVariant.sephardi,
          ),
          'Halakha',
        );
        expect(
          halacha.inLanguage(
            useHebrew: false,
            plural: true,
            variant: TransliterationVariant.sephardi,
          ),
          'Halakhot',
        );
        expect(halacha.inLanguage(useHebrew: false, plural: true), 'Halachos');
      },
    );

    test('Seforim/Seferim sephardi both collapse to Sefarim', () {
      final mtSefer = CurriculumLabels.level(CurriculumId.mishnehTorah, 1);
      expect(
        mtSefer.inLanguage(
          useHebrew: false,
          plural: true,
          variant: TransliterationVariant.sephardi,
        ),
        'Sefarim',
      );
      final chumashSefer = CurriculumLabels.level(CurriculumId.chumash, 1);
      expect(chumashSefer.enPlural, 'Seferim');
      expect(
        chumashSefer.inLanguage(
          useHebrew: false,
          plural: true,
          variant: TransliterationVariant.sephardi,
        ),
        'Sefarim',
      );
    });

    test(
      'pass-through words unchanged in sephardi (Daf, Perek, Pasuk, Seder)',
      () {
        final daf = CurriculumLabels.level(CurriculumId.bavli, 3);
        expect(
          daf.inLanguage(
            useHebrew: false,
            variant: TransliterationVariant.sephardi,
          ),
          'Daf',
        );
        final perek = CurriculumLabels.level(CurriculumId.chumash, 2);
        expect(
          perek.inLanguage(
            useHebrew: false,
            variant: TransliterationVariant.sephardi,
          ),
          'Perek',
        );
        final pasuk = CurriculumLabels.leaf(CurriculumId.chumash);
        expect(
          pasuk.inLanguage(
            useHebrew: false,
            variant: TransliterationVariant.sephardi,
          ),
          'Pasuk',
        );
        final seder = CurriculumLabels.level(CurriculumId.mishnayos, 1);
        expect(
          seder.inLanguage(
            useHebrew: false,
            variant: TransliterationVariant.sephardi,
          ),
          'Seder',
        );
      },
    );
  });

  group('Toggle helpers honour the variant', () {
    test('containerCountLabel: Mishnayos → Masechtos / Masekhtot / מסכתות', () {
      expect(
        CurriculumLabels.containerCountLabel(
          CurriculumId.mishnayos,
          useHebrew: false,
        ),
        'Masechtos',
      );
      expect(
        CurriculumLabels.containerCountLabel(
          CurriculumId.mishnayos,
          useHebrew: false,
          variant: TransliterationVariant.sephardi,
        ),
        'Masekhtot',
      );
      expect(
        CurriculumLabels.containerCountLabel(
          CurriculumId.mishnayos,
          useHebrew: true,
        ),
        'מסכתות',
      );
    });

    test('primaryUnitLabel: Bavli → Dafim / Dapim', () {
      expect(
        CurriculumLabels.primaryUnitLabel(CurriculumId.bavli, useHebrew: false),
        'Dafim',
      );
      expect(
        CurriculumLabels.primaryUnitLabel(
          CurriculumId.bavli,
          useHebrew: false,
          variant: TransliterationVariant.sephardi,
        ),
        'Dapim',
      );
    });

    test('primaryUnitLabel: Mishnayos leaf → Mishnayos / Mishnayot', () {
      expect(
        CurriculumLabels.primaryUnitLabel(
          CurriculumId.mishnayos,
          useHebrew: false,
        ),
        'Mishnayos',
      );
      expect(
        CurriculumLabels.primaryUnitLabel(
          CurriculumId.mishnayos,
          useHebrew: false,
          variant: TransliterationVariant.sephardi,
        ),
        'Mishnayot',
      );
    });

    test('levelLabel + labelsForVariant render the per-level words', () {
      expect(
        CurriculumLabels.levelLabel(
          CurriculumId.bavli,
          2,
          useHebrew: false,
          plural: true,
          variant: TransliterationVariant.sephardi,
        ),
        'Masekhtot',
      );
      final words = CurriculumLabels.labelsForVariant(
        CurriculumId.mishnehTorah,
        useHebrew: false,
        variant: TransliterationVariant.sephardi,
      );
      // Sefer / Hilchos / Perek / Halacha → Sefer / Hilchos / Perek / Halakha.
      expect(words.first, 'Sefer');
      expect(words.last, 'Halakha');
    });
  });

  group('Renderer breadcrumb honours the variant', () {
    test(
      'ordinal prefix where it differs: Bavli Daf vs sephardi (pass-through)',
      () {
        // Daf is identical across nuschaos; assert prefix renders cleanly.
        final ashk = CurriculumLabelRenderer.renderValue(
          curriculumId: CurriculumId.bavli,
          level: 3,
          rawValue: '2',
          useHebrew: false,
        );
        expect(ashk, 'Daf 2');
        final seph = CurriculumLabelRenderer.renderValue(
          curriculumId: CurriculumId.bavli,
          level: 3,
          rawValue: '2',
          useHebrew: false,
          transliterationVariant: TransliterationVariant.sephardi,
        );
        expect(seph, 'Daf 2');
      },
    );

    test(
      'ordinal prefix where it differs: Mishneh Torah Halacha → Halakha',
      () {
        final ashk = CurriculumLabelRenderer.renderValue(
          curriculumId: CurriculumId.mishnehTorah,
          level: 4,
          rawValue: '3',
          useHebrew: false,
        );
        expect(ashk, 'Halacha 3');
        final seph = CurriculumLabelRenderer.renderValue(
          curriculumId: CurriculumId.mishnehTorah,
          level: 4,
          rawValue: '3',
          useHebrew: false,
          transliterationVariant: TransliterationVariant.sephardi,
        );
        expect(seph, 'Halakha 3');
      },
    );
  });
}

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

  group('Masechta-name transliteration (transliterateNamedValue)', () {
    // raw data value -> (ashkenazi, sephardi). The raw value is the Sefaria
    // spelling, which is also the Sephardi form.
    const cases = <String, (String, String)>{
      'Berakhot': ('Berakhos', 'Berakhot'),
      'Shabbat': ('Shabbos', 'Shabbat'),
      'Ketubot': ('Kesubos', 'Ketubot'),
      'Makkot': ('Makkos', 'Makkot'),
      'Bava Batra': ('Bava Basra', 'Bava Batra'),
      'Sukkah': ('Succah', 'Sukkah'),
      'Taanit': ('Taanis', 'Taanit'),
      'Yevamot': ('Yevamos', 'Yevamot'),
      // Sheviit has no bare Bavli form in the data — only the Mishnah /
      // Yerushalmi prefixed keys exist.
      'Mishnah Sheviit': ('Sheviis', 'Sheviit'),
      // Seder (order) names — only Tahoros differs by nusach; "Seder" prefix
      // is kept, other sedarim pass through unchanged.
      'Tahorot': ('Taharos', 'Tahorot'),
      'Seder Tahorot': ('Seder Taharos', 'Seder Tahorot'),
      'Seder Zeraim': ('Seder Zeraim', 'Seder Zeraim'),
      'Seder Moed': ('Seder Moed', 'Seder Moed'),
    };

    cases.forEach((raw, forms) {
      test('$raw → ${forms.$1} (ashk) / ${forms.$2} (seph)', () {
        expect(
          CurriculumLabels.transliterateNamedValue(
            raw,
            variant: TransliterationVariant.ashkenazi,
          ),
          forms.$1,
        );
        expect(
          CurriculumLabels.transliterateNamedValue(
            raw,
            variant: TransliterationVariant.sephardi,
          ),
          forms.$2,
        );
      });
    });

    test('Mishnah- and Yerushalmi-prefixed raw forms also resolve', () {
      // Mishnayos data ships "Mishnah Berakhot"; Yerushalmi "Jerusalem Talmud
      // Berakhot". Both must hit the same nusach-sensitive name.
      expect(
        CurriculumLabels.transliterateNamedValue(
          'Mishnah Berakhot',
          variant: TransliterationVariant.ashkenazi,
        ),
        'Berakhos',
      );
      expect(
        CurriculumLabels.transliterateNamedValue(
          'Jerusalem Talmud Shabbat',
          variant: TransliterationVariant.ashkenazi,
        ),
        'Shabbos',
      );
      // Mishnah-only apostrophe form of Taanit.
      expect(
        CurriculumLabels.transliterateNamedValue(
          "Mishnah Ta'anit",
          variant: TransliterationVariant.ashkenazi,
        ),
        'Taanis',
      );
    });
  });

  group('Curriculum-name transliteration (transliterateNamedValue)', () {
    // CurriculumId.displayNameEn (Ashkenazi) -> (ashkenazi, sephardi).
    // Only Mishnayos / Tanach / Nach differ by nusach; the others pass
    // through to the raw Ashkenazi value.
    const cases = <String, (String, String)>{
      'Mishnayos': ('Mishnayos', 'Mishnayot'),
      'Tanach': ('Tanach', 'Tanakh'),
      'Nach': ('Nach', 'Nakh'),
    };

    cases.forEach((raw, forms) {
      test('$raw → ${forms.$1} (ashk) / ${forms.$2} (seph)', () {
        expect(
          CurriculumLabels.transliterateNamedValue(
            raw,
            variant: TransliterationVariant.ashkenazi,
          ),
          forms.$1,
        );
        expect(
          CurriculumLabels.transliterateNamedValue(
            raw,
            variant: TransliterationVariant.sephardi,
          ),
          forms.$2,
        );
      });
    });

    test('nusach-invariant curriculum names pass through unchanged', () {
      for (final name in const [
        'Talmud Bavli',
        'Talmud Yerushalmi',
        'Mishna Berurah',
        'Chumash',
        'Mishneh Torah',
        'Mussar',
      ]) {
        expect(
          CurriculumLabels.transliterateNamedValue(
            name,
            variant: TransliterationVariant.ashkenazi,
          ),
          name,
        );
        expect(
          CurriculumLabels.transliterateNamedValue(
            name,
            variant: TransliterationVariant.sephardi,
          ),
          name,
        );
      }
    });
  });

  group('Mishnayos masechta breadcrumb renders per-nusach (L2 name)', () {
    test('Mishnah Ketubot → Kesubos (ashk) vs Ketubot (seph)', () {
      // Masechta is a named level with no level-word prefix, so the rendered
      // L2 segment is the bare nusach name.
      final ashk = CurriculumLabelRenderer.renderValue(
        curriculumId: CurriculumId.mishnayos,
        level: 2,
        rawValue: 'Mishnah Ketubot',
        useHebrew: false,
      );
      expect(ashk, 'Kesubos');
      final seph = CurriculumLabelRenderer.renderValue(
        curriculumId: CurriculumId.mishnayos,
        level: 2,
        rawValue: 'Mishnah Ketubot',
        useHebrew: false,
        transliterationVariant: TransliterationVariant.sephardi,
      );
      expect(seph, 'Ketubot');
      expect(ashk, isNot(equals(seph)));
    });
  });
}

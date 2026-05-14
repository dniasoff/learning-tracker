import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';

void main() {
  group('CurriculumLabelRenderer.renderValue — named levels (no prefix)', () {
    test('Mishnayos Seder (Hebrew)', () {
      expect(
        CurriculumLabelRenderer.renderValue(
          curriculumId: CurriculumId.mishnayos,
          level: 1,
          rawValue: 'Seder Zeraim',
          useHebrew: true,
          hebrewName: 'סדר זרעים',
        ),
        'זרעים',
      );
    });

    test('Mishnayos Masechta (Hebrew strips structural prefix)', () {
      expect(
        CurriculumLabelRenderer.renderValue(
          curriculumId: CurriculumId.mishnayos,
          level: 2,
          rawValue: 'Berakhot',
          useHebrew: true,
          hebrewName: 'מסכת ברכות',
        ),
        'ברכות',
      );
    });

    test('Chumash Sefer (Hebrew)', () {
      expect(
        CurriculumLabelRenderer.renderValue(
          curriculumId: CurriculumId.chumash,
          level: 1,
          rawValue: 'Genesis',
          useHebrew: true,
          hebrewName: 'בראשית',
        ),
        'בראשית',
      );
    });

    test('Chumash Sefer (English mode → Ashkenazi transliteration)', () {
      // English mode renders the transliterated Hebrew name, not the
      // English translation. Ashkenazi by default.
      expect(
        CurriculumLabelRenderer.renderValue(
          curriculumId: CurriculumId.chumash,
          level: 1,
          rawValue: 'Genesis',
          useHebrew: false,
          hebrewName: 'בראשית',
        ),
        'Bereishis',
      );
    });

    test('Chumash Sefer (English mode → Sephardi transliteration)', () {
      expect(
        CurriculumLabelRenderer.renderValue(
          curriculumId: CurriculumId.chumash,
          level: 1,
          rawValue: 'Genesis',
          useHebrew: false,
          hebrewName: 'בראשית',
          transliterationVariant: TransliterationVariant.sephardi,
        ),
        'Bereshit',
      );
    });

    test('Mussar Sefer (Hebrew Mesillat Yesharim)', () {
      expect(
        CurriculumLabelRenderer.renderValue(
          curriculumId: CurriculumId.mussar,
          level: 1,
          rawValue: 'Mesillat Yesharim',
          useHebrew: true,
          hebrewName: 'מסילת ישרים',
        ),
        'מסילת ישרים',
      );
    });
  });

  group(
    'CurriculumLabelRenderer.renderValue — ordinal levels (with prefix)',
    () {
      test('Chumash Perek 3 (Hebrew) → "פרק ג"', () {
        // Chumash hierarchy is Sefer (1) / Perek (2) / Pasuk (3).
        expect(
          CurriculumLabelRenderer.renderValue(
            curriculumId: CurriculumId.chumash,
            level: 2,
            rawValue: '3',
            useHebrew: true,
          ),
          'פרק ג',
        );
      });

      test('Chumash Perek 3 (English) → "Perek 3"', () {
        expect(
          CurriculumLabelRenderer.renderValue(
            curriculumId: CurriculumId.chumash,
            level: 2,
            rawValue: '3',
            useHebrew: false,
          ),
          'Perek 3',
        );
      });

      test('Mishnayos Perek 11 (Hebrew) → "פרק יא"', () {
        expect(
          CurriculumLabelRenderer.renderValue(
            curriculumId: CurriculumId.mishnayos,
            level: 3,
            rawValue: '11',
            useHebrew: true,
          ),
          'פרק יא',
        );
      });

      test('Bavli Daf 2 (Hebrew) → "דף ב"', () {
        expect(
          CurriculumLabelRenderer.renderValue(
            curriculumId: CurriculumId.bavli,
            level: 3,
            rawValue: '2',
            useHebrew: true,
          ),
          'דף ב',
        );
      });

      test('Bavli Amud a/b (Hebrew → א/ב; English → a/b)', () {
        expect(
          CurriculumLabelRenderer.renderValue(
            curriculumId: CurriculumId.bavli,
            level: 4,
            rawValue: 'a',
            useHebrew: true,
          ),
          'עמוד א',
        );
        expect(
          CurriculumLabelRenderer.renderValue(
            curriculumId: CurriculumId.bavli,
            level: 4,
            rawValue: 'b',
            useHebrew: true,
          ),
          'עמוד ב',
        );
        expect(
          CurriculumLabelRenderer.renderValue(
            curriculumId: CurriculumId.bavli,
            level: 4,
            rawValue: 'a',
            useHebrew: false,
          ),
          'Amud a',
        );
      });

      test(
        'Mussar Perek (default) — Mesillat Yesharim chapter 1 → "פרק א"',
        () {
          expect(
            CurriculumLabelRenderer.renderValue(
              curriculumId: CurriculumId.mussar,
              level: 2,
              rawValue: '1',
              useHebrew: true,
              parentL1Value: 'Mesillat Yesharim',
            ),
            'פרק א',
          );
        },
      );

      test('Mussar Shaar (override) — Shaarei Teshuvah gate 1 → "שער א"', () {
        expect(
          CurriculumLabelRenderer.renderValue(
            curriculumId: CurriculumId.mussar,
            level: 2,
            rawValue: '1',
            useHebrew: true,
            parentL1Value: 'Shaarei Teshuvah',
          ),
          'שער א',
        );
        expect(
          CurriculumLabelRenderer.renderValue(
            curriculumId: CurriculumId.mussar,
            level: 2,
            rawValue: '1',
            useHebrew: false,
            parentL1Value: 'Shaarei Teshuvah',
          ),
          'Shaar 1',
        );
      });

      test(
        'Hebrew letter value passes through in Hebrew, parses back in English',
        () {
          expect(
            CurriculumLabelRenderer.renderValue(
              curriculumId: CurriculumId.chumash,
              level: 2,
              rawValue: 'יא',
              useHebrew: true,
            ),
            'פרק יא',
          );
          expect(
            CurriculumLabelRenderer.renderValue(
              curriculumId: CurriculumId.chumash,
              level: 2,
              rawValue: 'יא',
              useHebrew: false,
            ),
            'Perek 11',
          );
        },
      );

      test('Corrupt "h" value renders as-is with prefix (loud failure)', () {
        // Confirms we don't paper over bad data.
        expect(
          CurriculumLabelRenderer.renderValue(
            curriculumId: CurriculumId.mussar,
            level: 2,
            rawValue: 'h',
            useHebrew: true,
            parentL1Value: 'Shaarei Teshuvah',
          ),
          'שער h',
        );
      });
    },
  );

  group('CurriculumLabelRenderer.renderBreadcrumb', () {
    test('Mishnayos Berakhot 1:1 (Hebrew)', () {
      expect(
        CurriculumLabelRenderer.renderBreadcrumb(
          curriculumId: CurriculumId.mishnayos,
          rawSegmentValues: ['Seder Zeraim', 'Berakhot', '1', '1'],
          useHebrew: true,
          hebrewNamesPerSegment: ['סדר זרעים', 'מסכת ברכות', null, null],
        ),
        ['זרעים', 'ברכות', 'פרק א', 'משנה א'],
      );
    });

    test('Chumash Genesis 3 (Hebrew)', () {
      expect(
        CurriculumLabelRenderer.renderBreadcrumb(
          curriculumId: CurriculumId.chumash,
          rawSegmentValues: ['Genesis', '3'],
          useHebrew: true,
          hebrewNamesPerSegment: ['בראשית', null],
        ),
        ['בראשית', 'פרק ג'],
      );
    });

    test('Bavli Berakhot 2a (Hebrew)', () {
      expect(
        CurriculumLabelRenderer.renderBreadcrumb(
          curriculumId: CurriculumId.bavli,
          rawSegmentValues: ['Seder Zeraim', 'Berakhot', '2', 'a'],
          useHebrew: true,
          hebrewNamesPerSegment: ['סדר זרעים', 'מסכת ברכות', null, null],
        ),
        ['זרעים', 'ברכות', 'דף ב', 'עמוד א'],
      );
    });
  });

  group('CurriculumLabelRenderer.renderForItem', () {
    test('Chumash pasuk leaf — leaf-only render gives gematriya pasuk', () {
      const item = ContentItem(
        curriculumId: 'chumash',
        level1: 'Genesis',
        level2: '3',
        level3: '5',
        displayNameHe: 'בראשית ג:ה',
        displayNameEn: 'Genesis 3:5',
        sefariaRef: 'Genesis 3:5',
        sortOrder: 0,
        isLeaf: true,
      );
      expect(
        CurriculumLabelRenderer.renderForItem(item, useHebrew: true),
        'פסוק ה',
      );
    });

    test('Chumash chapter ContentItem renders leaf perek', () {
      const item = ContentItem(
        curriculumId: 'chumash',
        level1: 'Genesis',
        level2: '3',
        displayNameHe: 'בראשית ג',
        displayNameEn: 'Genesis 3',
        sefariaRef: 'Genesis 3',
        sortOrder: 0,
        isLeaf: false,
      );
      expect(
        CurriculumLabelRenderer.renderForItem(item, useHebrew: true),
        'פרק ג',
      );
    });

    test('renderParentForItem on a chapter returns the Sefer (Hebrew)', () {
      const item = ContentItem(
        curriculumId: 'chumash',
        level1: 'Genesis',
        level2: '3',
        displayNameHe: 'בראשית ג',
        displayNameEn: 'Genesis 3',
        sefariaRef: 'Genesis 3',
        sortOrder: 0,
        isLeaf: false,
      );
      // Parent of "Genesis 3" (a perek) is the Sefer level. No hebrewName
      // is carried on the item for the Sefer segment, so the renderer
      // returns the raw level1 value as the parent display string.
      expect(
        CurriculumLabelRenderer.renderParentForItem(item, useHebrew: true),
        'Genesis',
      );
    });

    test('Mishnayos perek ContentItem renders "פרק א"', () {
      const item = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Seder Zeraim',
        level2: 'Berakhot',
        level3: '1',
        displayNameHe: 'משנה ברכות א',
        displayNameEn: 'Mishnah Berakhot 1',
        sefariaRef: 'Mishnah_Berakhot.1',
        sortOrder: 0,
        isLeaf: false,
      );
      expect(
        CurriculumLabelRenderer.renderForItem(item, useHebrew: true),
        'פרק א',
      );
    });
  });

  // =========================================================================
  // CurriculumLabelRenderer.renderForItem — edge cases (uncovered paths)
  // =========================================================================

  group('CurriculumLabelRenderer.renderForItem — edge cases', () {
    test('unknown curriculumId falls back to displayNameEn (English)', () {
      const item = ContentItem(
        curriculumId: 'unknown_curriculum_xyz',
        level1: 'SomeLevel',
        displayNameHe: 'שם עברי',
        displayNameEn: 'English Name',
        sefariaRef: 'SomeRef',
        sortOrder: 0,
        isLeaf: true,
      );
      expect(
        CurriculumLabelRenderer.renderForItem(item, useHebrew: false),
        'English Name',
      );
    });

    test('unknown curriculumId falls back to displayNameHe (Hebrew)', () {
      const item = ContentItem(
        curriculumId: 'unknown_curriculum_xyz',
        level1: 'SomeLevel',
        displayNameHe: 'שם עברי',
        displayNameEn: 'English Name',
        sefariaRef: 'SomeRef',
        sortOrder: 0,
        isLeaf: true,
      );
      expect(
        CurriculumLabelRenderer.renderForItem(item, useHebrew: true),
        'שם עברי',
      );
    });

    test('fullPath=true returns breadcrumb joined by separator', () {
      const item = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Seder Zeraim',
        level2: 'Berakhot',
        level3: '1',
        displayNameHe: 'משנה ברכות א',
        displayNameEn: 'Mishnah Berakhot 1',
        sefariaRef: 'Mishnah_Berakhot.1',
        sortOrder: 0,
        isLeaf: false,
      );
      final result = CurriculumLabelRenderer.renderForItem(
        item,
        useHebrew: false,
        fullPath: true,
      );
      // Full breadcrumb should contain multiple segments joined by ' › '.
      expect(result, contains(' › '));
    });
  });

  // =========================================================================
  // CurriculumLabelRenderer.hebrewNameOf
  // =========================================================================

  group('CurriculumLabelRenderer.hebrewNameOf', () {
    test('returns null when item is null', () {
      expect(CurriculumLabelRenderer.hebrewNameOf(null), isNull);
    });

    test('returns displayNameHe when item is non-null', () {
      const item = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Seder Zeraim',
        displayNameHe: 'זרעים',
        displayNameEn: 'Zeraim',
        sefariaRef: 'Zeraim',
        sortOrder: 0,
        isLeaf: false,
      );
      expect(CurriculumLabelRenderer.hebrewNameOf(item), 'זרעים');
    });
  });
}
